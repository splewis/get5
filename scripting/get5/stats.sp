void Stats_PluginStart() {
  HookEvent("bomb_defused", Stats_BombDefusedEvent);
  HookEvent("bomb_exploded", Stats_BombExplodedEvent);
  HookEvent("bomb_planted", Stats_BombPlantedEvent);
  HookEvent("decoy_started", Stats_DecoyStartedEvent);
  HookEvent("flashbang_detonate", Stats_FlashbangDetonateEvent);
  HookEvent("grenade_thrown", Stats_GrenadeThrownEvent);
  HookEvent("hegrenade_detonate", Stats_HEGrenadeDetonateEvent);
  HookEvent("inferno_expire", Stats_MolotovEndedEvent);
  HookEvent("inferno_extinguish", Stats_MolotovExtinguishedEvent);
  HookEvent("inferno_startburn", Stats_MolotovStartBurnEvent);
  HookEvent("molotov_detonate", Stats_MolotovDetonateEvent);
  HookEvent("player_blind", Stats_PlayerBlindEvent);
  HookEvent("player_death", Stats_PlayerDeathEvent);
  HookEvent("round_mvp", Stats_RoundMVPEvent);
  HookEvent("smokegrenade_detonate", Stats_SmokeGrenadeDetonateEvent);
}

static Action HandlePlayerDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return Plugin_Continue;
  }
  LogDebug("HandlePlayerDamage(victim=%d, attacker=%d, inflictor=%d, damage=%f, damageType=%d)", victim, attacker,
           inflictor, damage, damagetype);
  if (!IsValidClient(attacker) || !IsValidClient(victim)) {
    return Plugin_Continue;
  }

  int playerHealth = GetClientHealth(victim);
  int damageUncapped = RoundToFloor(damage);  // Only used for damage report in chat; not sent to forwards or events.
  int damageAsIntCapped = damageUncapped;     // Set to player health if >= that. See below.
  bool isDecoy = false;
  bool victimKilled = false;

  // Decoy also deals damage type 64, but we don't want that to count as utility damage, as the
  // in-game scoreboard does not, so we filter it out.
  if (damagetype == 64) {
    char entityName[32];
    GetEntityClassname(inflictor, entityName, sizeof(entityName));
    isDecoy = StrEqual(entityName, "decoy_projectile");
  }

  bool isUtilityDamage = !isDecoy && (damagetype == 64 || damagetype == 8);

  if (playerHealth - damageUncapped <= 0) {
    damageAsIntCapped = playerHealth;  // Cap damage at what health player has left.
    victimKilled = true;
  }

  bool helpful = HelpfulAttack(attacker, victim);

  if (helpful) {
    if (g_DamagePrintExcessCvar.IntValue > 0) {
      g_DamageDone[attacker][victim] += damageUncapped;
    } else {
      g_DamageDone[attacker][victim] += damageAsIntCapped;
    }
    g_DamageDoneHits[attacker][victim]++;

    AddToPlayerStat(attacker, STAT_DAMAGE, damageAsIntCapped);
    if (isUtilityDamage) {
      AddToPlayerStat(attacker, STAT_UTILITY_DAMAGE, damageAsIntCapped);
    }
  }

  if (!isUtilityDamage) {
    return Plugin_Continue;
  }

  if (damagetype == 64) {
    // HE grenade is 64
    char grenadeKey[16];
    IntToString(inflictor, grenadeKey, sizeof(grenadeKey));

    Get5VictimWithDamageGrenadeEvent grenadeObject;
    if (g_HEGrenadeContainer.GetValue(grenadeKey, grenadeObject)) {
      if (helpful) {
        grenadeObject.DamageEnemies = grenadeObject.DamageEnemies + damageAsIntCapped;
      } else {
        grenadeObject.DamageFriendlies = grenadeObject.DamageFriendlies + damageAsIntCapped;
      }

      grenadeObject.Victims.PushObject(
        new Get5DamageGrenadeVictim(GetPlayerObject(victim), !helpful, victimKilled, damageAsIntCapped));
    }

  } else if (damagetype == 8) {
    // molotov is 8
    char molotovKey[16];
    IntToString(inflictor, molotovKey, sizeof(molotovKey));

    Get5VictimWithDamageGrenadeEvent molotovObject;
    if (g_MolotovContainer.GetValue(molotovKey, molotovObject)) {
      if (helpful) {
        molotovObject.DamageEnemies = molotovObject.DamageEnemies + damageAsIntCapped;
      } else {
        molotovObject.DamageFriendlies = molotovObject.DamageFriendlies + damageAsIntCapped;
      }

      int victimUserId = GetClientUserId(victim);

      int length = molotovObject.Victims.Length;
      for (int i = 0; i < length; i++) {
        Get5DamageGrenadeVictim victimObject = view_as<Get5DamageGrenadeVictim>(molotovObject.Victims.GetObject(i));

        if (victimObject.Player.UserId == victimUserId) {
          victimObject.Damage = victimObject.Damage + damageAsIntCapped;
          victimObject.Killed = victimKilled;
          return Plugin_Continue;
        }
      }

      molotovObject.Victims.PushObject(
        new Get5DamageGrenadeVictim(GetPlayerObject(victim), !helpful, victimKilled, damageAsIntCapped));
    }
  }

  return Plugin_Continue;
}

Get5Player GetPlayerObject(int client) {
  if (client == 0) {
    return new Get5Player(0, "", view_as<Get5Side>(CS_TEAM_NONE), "Console", false);
  }

  if (IsClientSourceTV(client)) {
    return new Get5Player(0, "", view_as<Get5Side>(CS_TEAM_NONE), "GOTV", false);
  }

  // In cases where users disconnect (Get5PlayerDisconnectedEvent) without being on a team, they
  // might error out on GetClientTeam(), so we check that they're in-game before we attempt to
  // determine their team. Avoids "Client x is not in game" exception.
  Get5Side side = view_as<Get5Side>(IsClientInGame(client) ? GetClientTeam(client) : CS_TEAM_NONE);

  char name[MAX_NAME_LENGTH];
  GetClientName(client, name, sizeof(name));

  int userId = GetClientUserId(client);

  if (IsAuthedPlayer(client)) {
    char auth[AUTH_LENGTH];
    GetAuth(client, auth, sizeof(auth));
    return new Get5Player(userId, auth, side, name, false);
  } else {
    char botId[16];
    FormatEx(botId, sizeof(botId), "BOT-%d", userId);
    return new Get5Player(userId, botId, side, name, true);
  }
}

void Stats_HookDamageForClient(int client) {
  SDKHook(client, SDKHook_OnTakeDamageAlive, HandlePlayerDamage);
  LogDebug("Hooked client %d to SDKHook_OnTakeDamageAlive", client);
}

void Stats_Reset() {
  if (g_StatsKv != null) {
    delete g_StatsKv;
  }
  g_StatsKv = new KeyValues("Stats");
}

void Stats_InitSeries() {
  Stats_Reset();
  char seriesType[32];
  FormatEx(seriesType, sizeof(seriesType), "bo%d", g_NumberOfMapsInSeries);
  g_StatsKv.SetString(STAT_SERIESTYPE, seriesType);
  g_StatsKv.SetString(STAT_SERIES_TEAM1NAME, g_TeamNames[Get5Team_1]);
  g_StatsKv.SetString(STAT_SERIES_TEAM2NAME, g_TeamNames[Get5Team_2]);
  DumpToFile();
}

void Stats_ResetRoundValues() {
  g_FirstKillDone = false;
  g_FirstDeathDone = false;
  g_SetTeamClutching[CS_TEAM_CT] = false;
  g_SetTeamClutching[CS_TEAM_T] = false;

  LOOP_CLIENTS(i) {
    Stats_ResetClientRoundValues(i);
  }
}

void Stats_ResetClientRoundValues(int client) {
  g_RoundKills[client] = 0;
  g_RoundClutchingEnemyCount[client] = 0;
  g_PlayerKilledBy[client] = -1;
  g_PlayerKilledByTime[client] = 0.0;
  g_PlayerRoundKillOrAssistOrTradedDeath[client] = false;
  g_PlayerSurvived[client] = true;

  LOOP_CLIENTS(i) {
    g_DamageDone[client][i] = 0;
    g_DamageDoneHits[client][i] = 0;
    g_DamageDoneKill[client][i] = false;
    g_DamageDoneAssist[client][i] = false;
    g_DamageDoneFlashAssist[client][i] = false;
  }
}

void Stats_ResetGrenadeContainers() {
  LogDebug("Clearing out any lingering events in grenade StringMaps...");

  // If any molotovs were active on the previous round when it ended (or on halftime/game end), we
  // need to fetch those and end the events, as their extinguish event will never fire. They are not
  // on a timer like flashes and HEs.
  StringMapSnapshot molotovSnap = g_MolotovContainer.Snapshot();
  for (int i = 0; i < molotovSnap.Length; i++) {
    int keySize = molotovSnap.KeyBufferSize(i);
    char[] key = new char[keySize];
    molotovSnap.GetKey(i, key, keySize);
    LogDebug("Ending molotov grenade entity %s.", key);
    EndMolotovEvent(key);
  }
  delete molotovSnap;

  // Due to timer race-conditions (SourceMod minimum timer is 100ms), we might have grenades that
  // blinded or damaged enemies after a round ended, so we loop these containers and make sure that
  // all events in them are fired and removed. These are only here to ensure that grenade events
  // don't actually fire in the wrong round. In the vast majority of cases, these snapshots will be
  // empty at this stage.

  StringMapSnapshot heSnap = g_HEGrenadeContainer.Snapshot();
  for (int i = 0; i < heSnap.Length; i++) {
    int keySize = heSnap.KeyBufferSize(i);
    char[] key = new char[keySize];
    heSnap.GetKey(i, key, keySize);
    LogDebug("Ending HE grenade entity %s.", key);
    EndHEEvent(key);
  }
  delete heSnap;

  StringMapSnapshot flashSnap = g_FlashbangContainer.Snapshot();
  for (int i = 0; i < flashSnap.Length; i++) {
    int keySize = flashSnap.KeyBufferSize(i);
    char[] key = new char[keySize];
    flashSnap.GetKey(i, key, keySize);
    LogDebug("Ending flashbang grenade entity %s.", key);
    EndFlashbangEvent(key);
  }
  delete flashSnap;

  g_LatestUserIdToDetonateMolotov = 0;
  g_LatestMolotovToExtinguishBySmoke = 0;
}

void Stats_RoundStart() {
  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      // Ensures that each player has zero-filled stats on freeze-time end.
      // Since joining the game after freeze-time will render you dead, you cannot obtain stats
      // until next round.
      Get5Side side = view_as<Get5Side>(GetClientTeam(i));
      if (side == Get5Side_None) {
        continue;  // Don't do anything to players pending team join.
      }
      Get5Team team = GetClientMatchTeam(i);
      if (team == Get5Team_1 || team == Get5Team_2) {
        InitPlayerStats(i, side);
        if (side == Get5Side_Spec) {
          continue;  // exclude coaches from STAT_ROUNDSPLAYED.
        }
        IncrementPlayerStat(i, STAT_ROUNDSPLAYED);
      }
    }
  }
}

void Stats_RoundEnd(int csTeamWinner) {
  // Update team scores.
  GoToMap();
  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  g_StatsKv.SetString(STAT_MAPNAME, mapName);
  GoBackFromMap();

  GoToTeam(Get5Team_1);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1)));
  GoBackFromTeam();

  GoToTeam(Get5Team_2);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2)));
  GoBackFromTeam();

  // Update player 1vx, x-kill, and KAST values.
  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      Get5Team team = GetClientMatchTeam(i);
      if (team == Get5Team_1 || team == Get5Team_2) {
        switch (g_RoundKills[i]) {
          case 1:
            IncrementPlayerStat(i, STAT_1K);
          case 2:
            IncrementPlayerStat(i, STAT_2K);
          case 3:
            IncrementPlayerStat(i, STAT_3K);
          case 4:
            IncrementPlayerStat(i, STAT_4K);
          case 5:
            IncrementPlayerStat(i, STAT_5K);
        }

        if (GetClientTeam(i) == csTeamWinner) {
          switch (g_RoundClutchingEnemyCount[i]) {
            case 1:
              IncrementPlayerStat(i, STAT_V1);
            case 2:
              IncrementPlayerStat(i, STAT_V2);
            case 3:
              IncrementPlayerStat(i, STAT_V3);
            case 4:
              IncrementPlayerStat(i, STAT_V4);
            case 5:
              IncrementPlayerStat(i, STAT_V5);
          }
        }

        if (g_PlayerRoundKillOrAssistOrTradedDeath[i] || g_PlayerSurvived[i]) {
          IncrementPlayerStat(i, STAT_KAST);
        }

        GoToPlayer(i);
        g_StatsKv.SetNum(STAT_CONTRIBUTION_SCORE, CS_GetClientContributionScore(i));
        GoBackFromPlayer();
      }
    }
  }
}

void Stats_UpdateMapScore(Get5Team winner) {
  GoToMap();
  char winnerString[16];
  GetTeamString(winner, winnerString, sizeof(winnerString));
  g_StatsKv.SetString(STAT_MAPWINNER, winnerString);
  GoBackFromMap();
  DumpToFile();
}

void Stats_SetDemoName(const char[] demoFileName) {
  GoToMap();
  g_StatsKv.SetString(STAT_DEMOFILENAME, demoFileName);
  GoBackFromMap();
  DumpToFile();
}

void Stats_Forfeit() {
  g_StatsKv.SetNum(STAT_SERIES_FORFEIT, 1);
}

void Stats_SeriesEnd(Get5Team winner) {
  char winnerString[16];
  GetTeamString(winner, winnerString, sizeof(winnerString));
  g_StatsKv.SetString(STAT_SERIESWINNER, winnerString);
  DumpToFile();
}

static void EndMolotovEvent(const char[] molotovKey) {
  // Since a molotov can be active when the round is ending, we need to grab the information from it
  // on both RoundStart
  // **and** on its expire event.

  Get5MolotovDetonatedEvent molotovObject;
  if (g_MolotovContainer.GetValue(molotovKey, molotovObject)) {
    if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
      delete molotovObject;
    } else {
      molotovObject.EndTime = GetRoundTime();
      LogDebug("Calling Get5_OnMolotovDetonated()");
      Call_StartForward(g_OnMolotovDetonated);
      Call_PushCell(molotovObject);
      Call_Finish();
      EventLogger_LogAndDeleteEvent(molotovObject);
    }
    g_MolotovContainer.Remove(molotovKey);
  }
}

static void EndHEEvent(const char[] grenadeKey) {
  Get5HEDetonatedEvent heObject;
  if (g_HEGrenadeContainer.GetValue(grenadeKey, heObject)) {
    if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
      delete heObject;
    } else {
      LogDebug("Calling Get5_OnHEGrenadeDetonated()");
      Call_StartForward(g_OnHEGrenadeDetonated);
      Call_PushCell(heObject);
      Call_Finish();
      EventLogger_LogAndDeleteEvent(heObject);
    }
    g_HEGrenadeContainer.Remove(grenadeKey);
  }
}

static void EndFlashbangEvent(const char[] flashKey) {
  Get5FlashbangDetonatedEvent flashEvent;
  if (g_FlashbangContainer.GetValue(flashKey, flashEvent)) {
    if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
      delete flashEvent;
    } else {
      LogDebug("Calling Get5_OnFlashbangDetonated()");
      Call_StartForward(g_OnFlashbangDetonated);
      Call_PushCell(flashEvent);
      Call_Finish();
      EventLogger_LogAndDeleteEvent(flashEvent);
    }
    g_FlashbangContainer.Remove(flashKey);
  }
}

static Action Stats_DecoyStartedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return;
  }

  Get5DecoyStartedEvent decoyObject =
    new Get5DecoyStartedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), GetPlayerObject(attacker));

  LogDebug("Calling Get5_OnDecoyStarted()");

  Call_StartForward(g_OnDecoyStarted);
  Call_PushCell(decoyObject);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(decoyObject);
}

static Action Stats_SmokeGrenadeDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    g_LatestMolotovToExtinguishBySmoke = 0;  // If someone disconnects after throwing grenade.
    return;
  }

  Get5SmokeDetonatedEvent smokeEvent =
    new Get5SmokeDetonatedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), GetPlayerObject(attacker),
                                g_LatestMolotovToExtinguishBySmoke > 0);

  Call_StartForward(g_OnSmokeGrenadeDetonated);
  Call_PushCell(smokeEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(smokeEvent);

  // Reset this so other smokes don't get extinguish attribution.
  g_LatestMolotovToExtinguishBySmoke = 0;
}

static Action Stats_MolotovStartBurnEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  if (g_LatestUserIdToDetonateMolotov == 0) {
    // If user disconnected after throwing the molotov, this will be 0.
    return;
  }

  int entityId = event.GetInt("entityid");

  LogDebug("Molotov Event: %s, %d", name, entityId);

  char molotovKey[16];
  IntToString(entityId, molotovKey, sizeof(molotovKey));

  g_MolotovContainer.SetValue(
    molotovKey,
    new Get5MolotovDetonatedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(),
                                  GetPlayerObject(g_LatestUserIdToDetonateMolotov)  // Set in molotov detonate event
                                  ),
    true);
}

static Action Stats_MolotovExtinguishedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int entityId = event.GetInt("entityid");

  // We need this for molotov extinguish event to determine if the molotov was extinguished by a
  // smoke. Event order is: molotov extinguished, smoke detonate, molotov ended (for some reason).
  g_LatestMolotovToExtinguishBySmoke = entityId;

  LogDebug("Molotov Event: %s, %d", name, entityId);
}

static Action Stats_MolotovEndedEvent(Event event, const char[] name, bool dontBroadcast) {
  int entityId = event.GetInt("entityid");

  LogDebug("Molotov Event: %s, %d", name, entityId);

  char molotovKey[16];
  IntToString(entityId, molotovKey, sizeof(molotovKey));

  EndMolotovEvent(molotovKey);
}

static Action Stats_MolotovDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  LogDebug("Molotov Event: %s, detonated by client %d", name, attacker);

  if (!IsValidClient(attacker)) {
    // Could happen if someone disconnects after throwing a grenade, but before it pops.
    g_LatestUserIdToDetonateMolotov = 0;
    return;
  }

  g_LatestUserIdToDetonateMolotov = attacker;
}

static Action Stats_FlashbangDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return;
  }

  int entityId = event.GetInt("entityid");

  Get5FlashbangDetonatedEvent flashEvent =
    new Get5FlashbangDetonatedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), GetPlayerObject(attacker));

  char flashKey[16];
  IntToString(entityId, flashKey, sizeof(flashKey));
  g_FlashbangContainer.SetValue(flashKey, flashEvent, true);

  CreateTimer(0.001, Timer_HandleFlashbang, entityId, TIMER_FLAG_NO_MAPCHANGE);
}

static Action Timer_HandleFlashbang(Handle timer, int entityId) {
  char flashKey[16];
  IntToString(entityId, flashKey, sizeof(flashKey));

  EndFlashbangEvent(flashKey);

  return Plugin_Handled;
}

static Action Stats_HEGrenadeDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return;
  }

  int entityId = event.GetInt("entityid");

  Get5HEDetonatedEvent grenadeObject =
    new Get5HEDetonatedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), GetPlayerObject(attacker));

  char grenadeKey[16];
  IntToString(entityId, grenadeKey, sizeof(grenadeKey));
  g_HEGrenadeContainer.SetValue(grenadeKey, grenadeObject, true);

  CreateTimer(0.001, Timer_HandleHEGrenade, entityId, TIMER_FLAG_NO_MAPCHANGE);
}

static Action Timer_HandleHEGrenade(Handle timer, int entityId) {
  char grenadeKey[16];
  IntToString(entityId, grenadeKey, sizeof(grenadeKey));

  EndHEEvent(grenadeKey);

  return Plugin_Handled;
}

static Action Stats_GrenadeThrownEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return;
  }

  char weapon[32];
  event.GetString("weapon", weapon, sizeof(weapon));

  Get5GrenadeThrownEvent grenadeEvent =
    new Get5GrenadeThrownEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), GetPlayerObject(attacker),
                               new Get5Weapon(weapon, CS_AliasToWeaponID(weapon)));

  LogDebug("Calling Get5_OnGrenadeThrown()");

  Call_StartForward(g_OnGrenadeThrown);
  Call_PushCell(grenadeEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(grenadeEvent);
}

static Action Stats_PlayerDeathEvent(Event event, const char[] name, bool dontBroadcast) {
  if (IsDoingRestoreOrMapChange()) {
    return;
  }
  int attacker = GetClientOfUserId(event.GetInt("attacker"));
  int victim = GetClientOfUserId(event.GetInt("userid"));

  if (g_GameState != Get5State_Live) {
    if (attacker != victim && g_AutoReadyActivePlayersCvar.BoolValue && IsAuthedPlayer(attacker)) {
      // HandleReadyCommand checks for game state, so we don't need to do that here as well.
      HandleReadyCommand(attacker, true);
    }
    return;
  }

  int assister = GetClientOfUserId(event.GetInt("assister"));

  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);
  bool validAssister = IsValidClient(assister);

  if (!validVictim) {
    return;  // Not sure how this would happen, but it's not something we care about.
  }

  // Update "clutch" (1vx) data structures to check if the clutcher wins the round
  int tCount = CountAlivePlayersOnTeam(CS_TEAM_T);
  int ctCount = CountAlivePlayersOnTeam(CS_TEAM_CT);

  if (tCount == 1 && !g_SetTeamClutching[CS_TEAM_T]) {
    g_SetTeamClutching[CS_TEAM_T] = true;
    int clutcher = GetClutchingClient(CS_TEAM_T);
    g_RoundClutchingEnemyCount[clutcher] = ctCount;
  }

  if (ctCount == 1 && !g_SetTeamClutching[CS_TEAM_CT]) {
    g_SetTeamClutching[CS_TEAM_CT] = true;
    int clutcher = GetClutchingClient(CS_TEAM_CT);
    g_RoundClutchingEnemyCount[clutcher] = tCount;
  }

  bool headshot = event.GetBool("headshot");

  char weapon[32];
  event.GetString("weapon", weapon, sizeof(weapon));

  CSWeaponID weaponId = CS_AliasToWeaponID(weapon);

  int attackerTeam = validAttacker ? GetClientTeam(attacker) : 0;
  int victimTeam = GetClientTeam(victim);

  // suicide (kill console) is attacker == victim, weapon id 0, weapon "world"
  // fall damage is weapon id 0, attacker 0, weapon "worldspawn"
  // falling from vertigo is attacker 0, weapon id 0, weapon "trigger_hurt"
  // c4 is attacker 0, weapon id 0, weapon planted_c4
  // killing self with weapons is attacker == victim
  // some weapons, such as unsilenced USP or M4A1S and molotov fire are also weapon 0, so weapon ID
  // is unreliable. with those in mind, we can determine that suicide must be true if attacker is 0
  // or attacker == victim and it was **not** the bomb.
  bool killedByBomb = StrEqual("planted_c4", weapon);
  bool isSuicide = (!validAttacker || attacker == victim) && !killedByBomb;

  IncrementPlayerStat(victim, STAT_DEATHS);
  // used for calculating round KAST
  g_PlayerSurvived[victim] = false;

  if (!g_FirstDeathDone) {
    g_FirstDeathDone = true;
    IncrementPlayerStat(victim, (victimTeam == CS_TEAM_CT) ? STAT_FIRSTDEATH_CT : STAT_FIRSTDEATH_T);
  }

  if (isSuicide) {
    IncrementPlayerStat(victim, STAT_SUICIDES);
  } else if (!killedByBomb) {
    if (attackerTeam == victimTeam) {
      IncrementPlayerStat(attacker, STAT_TEAMKILLS);
    } else {
      if (!g_FirstKillDone) {
        g_FirstKillDone = true;
        IncrementPlayerStat(attacker, (attackerTeam == CS_TEAM_CT) ? STAT_FIRSTKILL_CT : STAT_FIRSTKILL_T);
      }

      g_RoundKills[attacker]++;

      g_PlayerKilledBy[victim] = attacker;
      g_PlayerKilledByTime[victim] = GetGameTime();
      g_DamageDoneKill[attacker][victim] = true;
      UpdateTradeStat(attacker, victim);

      IncrementPlayerStat(attacker, STAT_KILLS);
      g_PlayerRoundKillOrAssistOrTradedDeath[attacker] = true;

      if (headshot) {
        IncrementPlayerStat(attacker, STAT_HEADSHOT_KILLS);
      }

      // Other than these constants, all knives can be found after CSWeapon_MAX_WEAPONS_NO_KNIFES.
      // See https://sourcemod.dev/#/cstrike/enumeration.CSWeaponID
      if (weaponId == CSWeapon_KNIFE || weaponId == CSWeapon_KNIFE_GG || weaponId == CSWeapon_KNIFE_T ||
          weaponId == CSWeapon_KNIFE_GHOST || weaponId > CSWeapon_MAX_WEAPONS_NO_KNIFES) {
        IncrementPlayerStat(attacker, STAT_KNIFE_KILLS);
      }
    }
  }

  Get5PlayerDeathEvent playerDeathEvent = new Get5PlayerDeathEvent(
    g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), GetPlayerObject(victim), new Get5Weapon(weapon, weaponId),
    headshot, validAttacker ? attackerTeam == victimTeam : false, event.GetBool("thrusmoke"), event.GetBool("noscope"),
    event.GetBool("attackerblind"), isSuicide, event.GetInt("penetrated"), killedByBomb);

  if (validAttacker) {
    playerDeathEvent.Attacker = GetPlayerObject(attacker);
  }

  if (validAssister) {
    bool assistedFlash = event.GetBool("assistedflash");
    bool friendlyFire = GetClientTeam(assister) == victimTeam;

    playerDeathEvent.Assist = new Get5AssisterObject(GetPlayerObject(assister), assistedFlash, friendlyFire);

    // Assists should only count towards opposite team
    if (!friendlyFire) {
      // You cannot flash-assist and regular-assist for the same kill.
      if (assistedFlash) {
        IncrementPlayerStat(assister, STAT_FLASHBANG_ASSISTS);
        g_DamageDoneFlashAssist[assister][victim] = true;
      } else {
        IncrementPlayerStat(assister, STAT_ASSISTS);
        g_PlayerRoundKillOrAssistOrTradedDeath[assister] = true;
        g_DamageDoneAssist[assister][victim] = true;
      }
    }
  }

  LogDebug("Calling Get5_OnPlayerDeath()");

  Call_StartForward(g_OnPlayerDeath);
  Call_PushCell(playerDeathEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(playerDeathEvent);
}

static void UpdateTradeStat(int attacker, int victim) {
  int attackerTeam = GetClientTeam(attacker);
  // Look to see if victim killed any of attacker's teammates recently.
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && g_PlayerKilledBy[i] == victim && GetClientTeam(i) == attackerTeam) {
      float dt = GetGameTime() - g_PlayerKilledByTime[i];
      if (dt < 1.5) {  // "Time to trade" window fixed to 1.5 seconds.
        IncrementPlayerStat(attacker, STAT_TRADEKILL);
        // teammate (i) was traded
        g_PlayerRoundKillOrAssistOrTradedDeath[i] = true;
      }
    }
  }
}

static Action Stats_BombPlantedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  g_BombPlantedTime = GetEngineTime();

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (IsValidClient(client)) {
    g_BombSiteLastPlanted = GetNearestBombsite(client);
    IncrementPlayerStat(client, STAT_BOMBPLANTS);

    Get5BombPlantedEvent bombEvent = new Get5BombPlantedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(),
                                                              GetPlayerObject(client), g_BombSiteLastPlanted);

    LogDebug("Calling Get5_OnBombPlanted()");

    Call_StartForward(g_OnBombPlanted);
    Call_PushCell(bombEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(bombEvent);
  }
}

static Action Stats_BombDefusedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_BOMBDEFUSES);

    int timeRemaining = (GetCvarIntSafe("mp_c4timer") * 1000) - GetMilliSecondsPassedSince(g_BombPlantedTime);
    if (timeRemaining < 0) {
      timeRemaining = 0;  // fail-safe in case of race conditions between events or if the timer
                          // value is changed after plant.
    }

    Get5BombDefusedEvent defuseEvent =
      new Get5BombDefusedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), GetPlayerObject(client),
                               g_BombSiteLastPlanted, timeRemaining);

    LogDebug("Calling Get5_OnBombDefused()");

    Call_StartForward(g_OnBombDefused);
    Call_PushCell(defuseEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(defuseEvent);
  }
}

static Action Stats_BombExplodedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  Get5BombExplodedEvent bombExplodedEvent =
    new Get5BombExplodedEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), g_BombSiteLastPlanted);

  LogDebug("Calling Get5_OnBombExploded()");

  Call_StartForward(g_OnBombExploded);
  Call_PushCell(bombExplodedEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(bombExplodedEvent);
}

static Action Stats_PlayerBlindEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  float duration = event.GetFloat("blind_duration");
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (!IsValidClient(attacker) || !IsValidClient(victim)) {
    return;
  }

  int victimTeam = GetClientTeam(victim);
  if (victimTeam == CS_TEAM_SPECTATOR || victimTeam == CS_TEAM_NONE) {
    return;
  }

  bool friendlyFire = GetClientTeam(attacker) == victimTeam;

  if (duration >= 2.5) {
    // 2.5 is an arbitrary value that closely matches the "enemies flashed" column of the in-game
    // scoreboard.
    friendlyFire ? IncrementPlayerStat(attacker, STAT_FRIENDLIES_FLASHED)
                 : IncrementPlayerStat(attacker, STAT_ENEMIES_FLASHED);
  }

  if (duration >= 0.5) {
    // Anything less than half a second is not worth storing as a victim.
    int entityId = event.GetInt("entityid");
    char flashKey[16];
    IntToString(entityId, flashKey, sizeof(flashKey));
    Get5FlashbangDetonatedEvent flashEvent;
    if (g_FlashbangContainer.GetValue(flashKey, flashEvent)) {
      flashEvent.Victims.PushObject(new Get5BlindedGrenadeVictim(GetPlayerObject(victim), friendlyFire, duration));
    }
  }
}

static Action Stats_RoundMVPEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live || IsDoingRestoreOrMapChange()) {
    return;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_MVP);

    Get5RoundMVPEvent mvpEvent =
      new Get5RoundMVPEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetPlayerObject(client), event.GetInt("reason"));

    LogDebug("Calling Get5_OnPlayerBecameMVP()");

    Call_StartForward(g_OnPlayerBecameMVP);
    Call_PushCell(mvpEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(mvpEvent);
  }
}

static int IncrementPlayerStatByValue(int client, const char[] field, int incrementBy) {
  GoToPlayer(client);
  int current = g_StatsKv.GetNum(field, 0);
  int newValue = current + incrementBy;
  g_StatsKv.SetNum(field, newValue);
  GoBackFromPlayer();
  return newValue;
}

static void InitPlayerStats(int client, Get5Side side) {
  if (!GoToPlayer(client)) {
    return;
  }

  // Always update the name.
  char name[MAX_NAME_LENGTH];
  GetClientName(client, name, sizeof(name));
  g_StatsKv.SetString(STAT_NAME, name);

  // Update if client is coaching. Spectators are excluded as their match team is spec; this checks
  // side only.
  g_StatsKv.SetNum(STAT_COACHING, side == Get5Side_Spec);

  // If the player already had their stats set, don't override them.
  if (g_StatsKv.GetNum(STAT_INIT, 0) > 0) {
    GoBackFromPlayer();
    return;
  }

  char keys[][] = {STAT_KILLS,
                   STAT_DEATHS,
                   STAT_ASSISTS,
                   STAT_FLASHBANG_ASSISTS,
                   STAT_TEAMKILLS,
                   STAT_SUICIDES,
                   STAT_DAMAGE,
                   STAT_UTILITY_DAMAGE,
                   STAT_ENEMIES_FLASHED,
                   STAT_FRIENDLIES_FLASHED,
                   STAT_KNIFE_KILLS,
                   STAT_HEADSHOT_KILLS,
                   STAT_ROUNDSPLAYED,
                   STAT_BOMBDEFUSES,
                   STAT_BOMBPLANTS,
                   STAT_1K,
                   STAT_2K,
                   STAT_3K,
                   STAT_4K,
                   STAT_5K,
                   STAT_V1,
                   STAT_V2,
                   STAT_V3,
                   STAT_V4,
                   STAT_V5,
                   STAT_FIRSTKILL_T,
                   STAT_FIRSTKILL_CT,
                   STAT_FIRSTDEATH_T,
                   STAT_FIRSTDEATH_CT,
                   STAT_TRADEKILL,
                   STAT_KAST,
                   STAT_CONTRIBUTION_SCORE,
                   STAT_MVP};

  int length = sizeof(keys);
  for (int i = 0; i < length; i++) {
    g_StatsKv.SetNum(keys[i], 0);
  }

  g_StatsKv.SetNum(STAT_INIT, 1);

  GoBackFromPlayer();
}

int AddToPlayerStat(int client, const char[] field, int delta) {
  if (IsFakeClient(client)) {
    return 0;
  }
  LogDebug("Updating player stat %s for %L", field, client);
  return IncrementPlayerStatByValue(client, field, delta);
}

static int IncrementPlayerStat(int client, const char[] field) {
  return AddToPlayerStat(client, field, 1);
}

static void GoToMap() {
  char mapNumberString[32];
  FormatEx(mapNumberString, sizeof(mapNumberString), "map%d", g_MapNumber);
  g_StatsKv.JumpToKey(mapNumberString, true);
}

static void GoBackFromMap() {
  g_StatsKv.GoBack();
}

static bool GoToTeam(Get5Team team) {
  GoToMap();

  if (team == Get5Team_1) {
    g_StatsKv.JumpToKey("team1", true);
    return true;
  } else if (team == Get5Team_2) {
    g_StatsKv.JumpToKey("team2", true);
    return true;
  }
  return false;
}

static void GoBackFromTeam() {
  GoBackFromMap();
  g_StatsKv.GoBack();
}

static bool GoToPlayer(int client) {
  Get5Team team = GetClientMatchTeam(client);
  if (!GoToTeam(team)) {
    return false;
  }

  char auth[AUTH_LENGTH];
  if (GetAuth(client, auth, sizeof(auth))) {
    g_StatsKv.JumpToKey(auth, true);
    return true;
  }
  return false;
}

static void GoBackFromPlayer() {
  GoBackFromTeam();
  g_StatsKv.GoBack();
}

static int GetClutchingClient(int csTeam) {
  int client = -1;
  int count = 0;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == csTeam) {
      client = i;
      count++;
    }
  }

  if (count == 1) {
    return client;
  } else {
    return -1;
  }
}

static void DumpToFile() {
  char path[PLATFORM_MAX_PATH + 1];
  if (FormatCvarString(g_StatsPathFormatCvar, path, sizeof(path))) {
    DumpToFilePath(path);
  }
}

bool DumpToFilePath(const char[] path) {
  return IsJSONPath(path) ? DumpToJSONFile(path) : g_StatsKv.ExportToFile(path);
}

static bool DumpToJSONFile(const char[] path) {
  g_StatsKv.Rewind();
  g_StatsKv.GotoFirstSubKey(false);
  JSON_Object stats = EncodeKeyValue(g_StatsKv);
  g_StatsKv.Rewind();

  File stats_file = OpenFile(path, "w");
  if (stats_file == null) {
    LogError("Failed to open stats file");
    return false;
  }

  // Mark the JSON buffer static to avoid running into limited haep/stack space, see
  // https://forums.alliedmods.net/showpost.php?p=2620835&postcount=6
  static char jsonBuffer[65536];  // 64 KiB
  stats.Encode(jsonBuffer, sizeof(jsonBuffer));
  json_cleanup_and_delete(stats);
  stats_file.WriteString(jsonBuffer, false);

  stats_file.Flush();
  stats_file.Close();

  return true;
}

static JSON_Object EncodeKeyValue(KeyValues kv) {
  char keyBuffer[256];
  char valBuffer[256];
  char sectionName[256];
  JSON_Object json_kv = new JSON_Object();

  do {
    if (kv.GotoFirstSubKey(false)) {
      // Current key is a section. Browse it recursively.
      JSON_Object obj = EncodeKeyValue(kv);
      kv.GoBack();
      kv.GetSectionName(sectionName, sizeof(sectionName));
      json_kv.SetObject(sectionName, obj);
    } else {
      // Current key is a regular key, or an empty section.
      KvDataTypes keyType = kv.GetDataType(NULL_STRING);
      kv.GetSectionName(keyBuffer, sizeof(keyBuffer));
      if (keyType == KvData_String) {
        kv.GetString(NULL_STRING, valBuffer, sizeof(valBuffer));
        json_kv.SetString(keyBuffer, valBuffer);
      } else if (keyType == KvData_Int) {
        json_kv.SetInt(keyBuffer, kv.GetNum(NULL_STRING));
      } else if (keyType == KvData_Float) {
        json_kv.SetFloat(keyBuffer, kv.GetFloat(NULL_STRING));
      } else {
        LogDebug("Can't JSON encode key '%s' with type %d", keyBuffer, keyType);
      }
    }
  } while (kv.GotoNextKey(false));

  return json_kv;
}

void PrintDamageInfo(int client) {
  if (!IsPlayer(client)) {
    return;
  }

  int team = GetClientTeam(client);
  if (team != CS_TEAM_T && team != CS_TEAM_CT) {
    return;
  }

  char message[256];
  int msgSize = sizeof(message);
  int replacedNameIndex;
  int otherTeam = (team == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;

  LOOP_CLIENTS(i) {
    if (IsValidClient(i) && GetClientTeam(i) == otherTeam) {
      int health = IsPlayerAlive(i) ? GetClientHealth(i) : 0;

      g_DamagePrintFormatCvar.GetString(message, msgSize);
      ReplaceStringWithInt(message, msgSize, "{DMG_TO}", g_DamageDone[client][i]);
      ReplaceStringWithInt(message, msgSize, "{HITS_TO}", g_DamageDoneHits[client][i]);

      if (g_DamageDoneKill[client][i]) {
        ReplaceStringEx(message, msgSize, "{KILL_TO}", "{GREEN}X{NORMAL}");
      } else if (g_DamageDoneAssist[client][i]) {
        ReplaceStringEx(message, msgSize, "{KILL_TO}", "{YELLOW}A{NORMAL}");
      } else if (g_DamageDoneFlashAssist[client][i]) {
        ReplaceStringEx(message, msgSize, "{KILL_TO}", "{YELLOW}F{NORMAL}");
      } else {
        ReplaceStringEx(message, msgSize, "{KILL_TO}", "–");
      }

      ReplaceStringWithInt(message, msgSize, "{DMG_FROM}", g_DamageDone[i][client]);
      ReplaceStringWithInt(message, msgSize, "{HITS_FROM}", g_DamageDoneHits[i][client]);

      if (g_DamageDoneKill[i][client]) {
        ReplaceStringEx(message, msgSize, "{KILL_FROM}", "{DARK_RED}X{NORMAL}");
      } else if (g_DamageDoneAssist[i][client]) {
        ReplaceStringEx(message, msgSize, "{KILL_FROM}", "{YELLOW}A{NORMAL}");
      } else if (g_DamageDoneFlashAssist[i][client]) {
        ReplaceStringEx(message, msgSize, "{KILL_FROM}", "{YELLOW}F{NORMAL}");
      } else {
        ReplaceStringEx(message, msgSize, "{KILL_FROM}", "–");
      }

      if (IsFakeClient(i)) {
        replacedNameIndex = ReplaceStringEx(message, msgSize, "{NAME}", "BOT %N");
      } else {
        replacedNameIndex = ReplaceStringEx(message, msgSize, "{NAME}", "%N");
      }

      ReplaceStringWithInt(message, msgSize, "{HEALTH}", health);

      Colorize(message, msgSize);
      if (replacedNameIndex != -1) {
        PrintToChat(client, message, i);  // Replaces %N with player name.
      } else {
        PrintToChat(client, message);  // {NAME} was not part of the string.
      }
    }
  }
}
