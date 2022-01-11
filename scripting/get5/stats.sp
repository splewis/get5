const float kTimeGivenToTrade = 1.5;

public void Stats_PluginStart() {
  HookEvent("bomb_defused", Stats_BombDefusedEvent);
  HookEvent("bomb_exploded", Stats_BombExplodedEvent);
  HookEvent("bomb_planted", Stats_BombPlantedEvent);
  HookEvent("decoy_detonate", Stats_DecoyDetonateEvent);
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

public Action HandlePlayerDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
  LogDebug("HandlePlayerDamage(victim=%d, attacker=%d, inflictor=%d, damage=%f, damageType=%d)", victim, attacker, inflictor, damage, damagetype);
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  if (attacker == victim || !IsValidClient(attacker) || !IsValidClient(victim)) {
    return Plugin_Continue;
  }

  int playerHealth = GetClientHealth(victim);
  int damageAsInt = RoundToFloor(damage);
  // HE and decoy explosion both deal damage type 64 and molotov deals type 8.
  bool isUtilityDamage = (damagetype == 64 || damagetype == 8);

  if (playerHealth - damageAsInt < 0) {
    damageAsInt = playerHealth; // Cap damage at what health player has left.
  }

  bool helpful = HelpfulAttack(attacker, victim);

  if (helpful) {
    g_DamageDone[attacker][victim] += damageAsInt;
    g_DamageDoneHits[attacker][victim]++;

    AddToPlayerStat(attacker, STAT_DAMAGE, damageAsInt);
    if (isUtilityDamage) {
      AddToPlayerStat(attacker, STAT_UTILITY_DAMAGE, damageAsInt);
    }
  }

  if (damagetype == 64) {
    // HE grenade and decoy are 64
    char grenadeKey[16];
    IntToString(inflictor, grenadeKey, sizeof(grenadeKey));

    Get5VictimGrenadeEvent grenadeObject;
    if (g_HEAndDecoyGrenadeContainer.GetValue(grenadeKey, grenadeObject)) {

       grenadeObject.Victims.PushObject(new Get5DamageGrenadeVictim(
         GetPlayerObject(victim),
         !helpful,
         damageAsInt
       ));
    }

  } else if (damagetype == 8) {
    // molotov is 8
    char molotovKey[16];
    IntToString(inflictor, molotovKey, sizeof(molotovKey));

    char victimSteamId[64];
    GetAuth(victim, victimSteamId, sizeof(victimSteamId));
    
    Get5VictimGrenadeEvent molotovEvent;
    if (g_MolotovContainer.GetValue(molotovKey, molotovEvent)) {

      int length = molotovEvent.Victims.Length;
      for (int i = 0; i < length; i++) {

        Get5DamageGrenadeVictim victimObject = view_as<Get5DamageGrenadeVictim>(molotovEvent.Victims.GetObject(i));

        if (victimObject.Player.IsEqualToPlayerId(victimSteamId)) {
          victimObject.Damage = victimObject.Damage + damageAsInt;
          return Plugin_Continue;
        }
      }

      molotovEvent.Victims.PushObject(new Get5DamageGrenadeVictim(
        GetPlayerObject(victim),
        !helpful,
        damageAsInt
      ));

    }
  }

  return Plugin_Continue;

}

public Get5Player GetPlayerObject(int client) {

  char auth[64];
  if (IsAuthedPlayer(client)) {
    GetAuth(client, auth, sizeof(auth));
  } else {
    auth = "";
  }

  return new Get5Player(auth, view_as<Side>(GetClientTeam(client)));

}

public void Stats_HookDamageForClient(int client) {
  SDKHook(client, SDKHook_OnTakeDamageAlive, HandlePlayerDamage);
  LogDebug("Hooked client %d to SDKHook_OnTakeDamageAlive", client);
}

public void Stats_Reset() {
  if (g_StatsKv != null) {
    delete g_StatsKv;
  }
  g_StatsKv = new KeyValues("Stats");
}

public void Stats_InitSeries() {
  Stats_Reset();
  char seriesType[32];
  Format(seriesType, sizeof(seriesType), "bo%d", MaxMapsToPlay(g_MapsToWin));
  g_StatsKv.SetString(STAT_SERIESTYPE, seriesType);
  g_StatsKv.SetString(STAT_SERIES_TEAM1NAME, g_TeamNames[MatchTeam_Team1]);
  g_StatsKv.SetString(STAT_SERIES_TEAM2NAME, g_TeamNames[MatchTeam_Team2]);
  DumpToFile();
}

public void Stats_ResetRoundValues() {
  g_SetTeamClutching[CS_TEAM_CT] = false;
  g_SetTeamClutching[CS_TEAM_T] = false;
  g_TeamFirstKillDone[CS_TEAM_CT] = false;
  g_TeamFirstKillDone[CS_TEAM_T] = false;
  g_TeamFirstDeathDone[CS_TEAM_CT] = false;
  g_TeamFirstDeathDone[CS_TEAM_T] = false;

  for (int i = 1; i <= MaxClients; i++) {
    Stats_ResetClientRoundValues(i);
  }
}

public void Stats_ResetClientRoundValues(int client) {
  g_RoundKills[client] = 0;
  g_RoundClutchingEnemyCount[client] = 0;
  g_PlayerKilledBy[client] = -1;
  g_PlayerKilledByTime[client] = 0.0;
  g_PlayerRoundKillOrAssistOrTradedDeath[client] = false;
  g_PlayerSurvived[client] = true;

  for (int i = 1; i <= MaxClients; i++) {
    g_DamageDone[client][i] = 0;
    g_DamageDoneHits[client][i] = 0;
    g_DamageDoneKill[client][i] = false;
    g_DamageDoneAssist[client][i] = false;
    g_DamageDoneFlashAssist[client][i] = false;
  }
}

public void CleanGrenadeContainer(const StringMap container) {

  StringMapSnapshot snap = container.Snapshot();

  for (int i = 0; i < snap.Length; i++) {

    char key[16];
    snap.GetKey(i, key, sizeof(key));

    StringMap event;
    if (container.GetValue(key, event)) {
      ArrayList victims;
      if (event.GetValue("victims", victims)) {
        event.Remove("victims");
        EmptyArrayList(victims);
      }
      event.Remove(key);
      delete event;
    }
  }

  delete snap;

}

public void Stats_ResetGrenadeContainers() {

  // If any molotovs were active on the previous round when it ended, we need to fetch those and end the events.
  StringMapSnapshot molotovSnap = g_MolotovContainer.Snapshot();
  for (int i = 0; i < molotovSnap.Length; i++) {
    char key[16];
    molotovSnap.GetKey(i, key, sizeof(key));
    EndMolotovEvent(key); // this function cleans the molotov container after firing the events.
  }
  delete molotovSnap;

  // Decoys may also be active (waiting to detonate) when the round ends.
  StringMapSnapshot decoySnap = g_HEAndDecoyGrenadeContainer.Snapshot();
  for (int i = 0; i < decoySnap.Length; i++) {
    char key[16];
    decoySnap.GetKey(i, key, sizeof(key));
    EndDecoyEvent(key); // this function cleans the decoy container after firing the events.
  }
  delete decoySnap;

  // The other containers only need to be emptied (all handles closed etc).
  CleanGrenadeContainer(g_FlashbangContainer);
  CleanGrenadeContainer(g_SmokeGrenadeContainer);

  g_LatestUserIdToDetonateMolotov = 0;
  g_LatestSmokeGrenadeToDetonateOnMolotov = 0;

}

public void Stats_RoundStart() {
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      MatchTeam team = GetClientMatchTeam(i);
      if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
        IncrementPlayerStat(i, STAT_ROUNDSPLAYED);

        GoToPlayer(i);
        char name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));
        g_StatsKv.SetString(STAT_NAME, name);
        GoBackFromPlayer();
      }
    }
  }
}

public void Stats_RoundEnd(int csTeamWinner) {
  // Update team scores.
  GoToMap();
  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  g_StatsKv.SetString(STAT_MAPNAME, mapName);
  GoBackFromMap();

  GoToTeam(MatchTeam_Team1);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  GoBackFromTeam();

  GoToTeam(MatchTeam_Team2);
  g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  GoBackFromTeam();

  // Update player 1vx, x-kill, and KAST values.
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i)) {
      MatchTeam team = GetClientMatchTeam(i);
      if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
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
        char name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));
        g_StatsKv.SetString(STAT_NAME, name);

        g_StatsKv.SetNum(STAT_CONTRIBUTION_SCORE, CS_GetClientContributionScore(i));

        GoBackFromPlayer();
      }
    }
  }

  if (g_DamagePrintCvar.BoolValue) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i)) {
        PrintDamageInfo(i);
      }
    }
  }
}

public void Stats_UpdateMapScore(MatchTeam winner) {
  GoToMap();

  char winnerString[16];
  GetTeamString(winner, winnerString, sizeof(winnerString));

  g_StatsKv.SetString(STAT_MAPWINNER, winnerString);
  g_StatsKv.SetString(STAT_DEMOFILENAME, g_DemoFileName);

  GoBackFromMap();

  DumpToFile();
}

public void Stats_Forfeit(MatchTeam team) {
  g_StatsKv.SetNum(STAT_SERIES_FORFEIT, 1);
  if (team == MatchTeam_Team1) {
    Stats_SeriesEnd(MatchTeam_Team2);
  } else if (team == MatchTeam_Team2) {
    Stats_SeriesEnd(MatchTeam_Team1);
  } else {
    Stats_SeriesEnd(MatchTeam_TeamNone);
  }
}

public void Stats_SeriesEnd(MatchTeam winner) {
  char winnerString[16];
  GetTeamString(winner, winnerString, sizeof(winnerString));
  g_StatsKv.SetString(STAT_SERIESWINNER, winnerString);
  DumpToFile();
}

public void StartMolotovEvent(const char[] molotovKey) {
  // Because a molotov does not provide an entity ID when detonating (gg SourceMod), we have to rely on *either*
  // the start-burn or the extinguish event; if a molotov is thrown directly at a smoke, it will explode and immediately
  // extinguish without triggering the start-burn event. However, it may also detonate, start burning and *then* be
  // extinguished. Hence, we use this helper to create the entity only once and avoid code repetition.

  Get5MolotovEvent discardThis;
  if (g_MolotovContainer.GetValue(molotovKey, discardThis)) {
    // Already created.
    return;
  }

  g_MolotovContainer.SetValue(molotovKey,
    new Get5MolotovEvent(
      g_MatchID,
      Get5_GetMapNumber(),
      g_RoundNumber,
      GetRoundTime(),
      GetPlayerObject(g_LatestUserIdToDetonateMolotov) // set in molotov detonate event
    ),
    true
  );

}

public void EndDecoyEvent(const char[] decoyKey) {

  Get5DecoyGrenadeEvent decoyObject;
  if (g_HEAndDecoyGrenadeContainer.GetValue(decoyKey, decoyObject)) {

    decoyObject.DetonatedTime = GetRoundTime();

    LogDebug("Calling Get5_OnDecoyEnded()");

    Call_StartForward(g_OnDecoyEnded);
    Call_PushCell(decoyObject);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(decoyObject);

    g_HEAndDecoyGrenadeContainer.Remove(decoyKey);

  }
}

public void EndMolotovEvent(const char[] molotovKey) {
  // Since a molotov can be active when the round is ending, we need to grab the information from it on both RoundStart
  // **and** on its expire event.

  Get5MolotovEvent molotovObject;
  if (g_MolotovContainer.GetValue(molotovKey, molotovObject)) {

    molotovObject.EndTime = GetRoundTime();

    LogDebug("Calling Get5_OnMolotovEnded()");

    Call_StartForward(g_OnMolotovEnded);
    Call_PushCell(molotovObject);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(molotovObject);

    g_MolotovContainer.Remove(molotovKey);

  }
}

public Action Stats_DecoyDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  char decoyKey[16];
  IntToString(entityId, decoyKey, sizeof(decoyKey));

  EndDecoyEvent(decoyKey);

  return Plugin_Continue;

}

public Action Stats_DecoyStartedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  char decoyKey[16];
  IntToString(entityId, decoyKey, sizeof(decoyKey));

  g_HEAndDecoyGrenadeContainer.SetValue(decoyKey,
    new Get5DecoyGrenadeEvent(
      g_MatchID,
      Get5_GetMapNumber(),
      g_RoundNumber,
      GetRoundTime(),
      GetPlayerObject(attacker)
    ),
    true
  );

  return Plugin_Continue;

}

public Action Stats_SmokeGrenadeDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  // We need this for molotov extinguish event to determine if this smoke extinguished a molotov.
  g_LatestSmokeGrenadeToDetonateOnMolotov = entityId;

  char smokeKey[16];
  IntToString(entityId, smokeKey, sizeof(smokeKey));

  g_SmokeGrenadeContainer.SetValue(
    smokeKey,
    new Get5SmokeGrenadeEvent(
      g_MatchID,
      Get5_GetMapNumber(),
      g_RoundNumber,
      GetRoundTime(),
      GetPlayerObject(attacker)
    ),
    true
  );

  CreateTimer(0.001, Timer_HandleSmokeGrenade, entityId, TIMER_FLAG_NO_MAPCHANGE);

  return Plugin_Continue;

}

public Action Timer_HandleSmokeGrenade(Handle timer, int entityId) {

  char smokeKey[16];
  IntToString(entityId, smokeKey, sizeof(smokeKey));

  Get5SmokeGrenadeEvent smokeObject;
  if (g_SmokeGrenadeContainer.GetValue(smokeKey, smokeObject)) {

    LogDebug("Calling Get5_OnSmokeGrenadeDetonated()");

    Call_StartForward(g_OnSmokeGrenadeDetonated);
    Call_PushCell(smokeObject);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(smokeObject);

    g_SmokeGrenadeContainer.Remove(smokeKey);

  }

}

public Action Stats_MolotovStartBurnEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  char molotovKey[16];
  IntToString(entityId, molotovKey, sizeof(molotovKey));

  StartMolotovEvent(molotovKey);

  return Plugin_Continue;

}

public Action Stats_MolotovExtinguishedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  LogDebug("Molotov Event: %s", name);

  char molotovKey[16];
  IntToString(entityId, molotovKey, sizeof(molotovKey));

  // Creates the JSON_Object *if* it was not created by start-burn.
  // molotov end event always comes after this event!
  StartMolotovEvent(molotovKey);

  if (g_LatestSmokeGrenadeToDetonateOnMolotov < 1) {
    // No smoke grenade is pending extinguish attribution.
    return Plugin_Continue;
  }

  // Set extinguished to true for the smoke grenade that extinguished the molotov.
  char smokeKey[16];
  IntToString(g_LatestSmokeGrenadeToDetonateOnMolotov, smokeKey, sizeof(smokeKey));

  Get5SmokeGrenadeEvent smokeObject;
  if (g_SmokeGrenadeContainer.GetValue(smokeKey, smokeObject)) {
    smokeObject.ExtinguishedMolotov = true;
  }

  return Plugin_Continue;

}

public Action Stats_MolotovEndedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  LogDebug("Molotov Event: %s", name);

  char molotovKey[16];
  IntToString(entityId, molotovKey, sizeof(molotovKey));

  EndMolotovEvent(molotovKey);

  return Plugin_Continue;

}

public Action Stats_MolotovDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  LogDebug("Molotov Event: %s", name);

  if (!IsValidClient(attacker)) {
    return Plugin_Continue;
  }

  g_LatestUserIdToDetonateMolotov = attacker;
  // Resetting the smoke grenade entity on molotov detonate is quite important, as throwing a molotov *into* a smoke
  // that has been around for a while could otherwise attribute the extinguish of that molotov to another smoke thrown
  // at a later time. Since extinguish by throwing a smoke into a molly immediately calls smoke detonate + molly
  // extinguish, this variable is of no use after those two events have fired in succession. When we clear it out here
  // we prevent the latest active smoke from interfering when throwing a new molotov.
  g_LatestSmokeGrenadeToDetonateOnMolotov = 0;

  return Plugin_Continue;

}

public Action Stats_FlashbangDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  Get5FlashbangGrenadeEvent flashEvent = new Get5FlashbangGrenadeEvent(
    g_MatchID,
    Get5_GetMapNumber(),
    g_RoundNumber,
    GetRoundTime(),
    GetPlayerObject(attacker)
  );

  char flashKey[16];
  IntToString(entityId, flashKey, sizeof(flashKey));
  g_FlashbangContainer.SetValue(flashKey, flashEvent, true);

  CreateTimer(0.001, Timer_HandleFlashbang, entityId, TIMER_FLAG_NO_MAPCHANGE);

  return Plugin_Continue;

}

public Action Timer_HandleFlashbang(Handle timer, int entityId) {

  char flashKey[16];
  IntToString(entityId, flashKey, sizeof(flashKey));

  Get5FlashbangGrenadeEvent flashEvent;
  if (g_FlashbangContainer.GetValue(flashKey, flashEvent)) {

    LogDebug("Calling Get5_OnFlashBangDetonated()");

    Call_StartForward(g_OnFlashbangDetonated);
    Call_PushCell(flashEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(flashEvent);

    g_FlashbangContainer.Remove(flashKey);

  }

  return Plugin_Continue;

}

public Action Stats_HEGrenadeDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return Plugin_Continue;
  }

  int entityId = event.GetInt("entityid");

  Get5HEGrenadeEvent grenadeObject = new Get5HEGrenadeEvent(
    g_MatchID,
    Get5_GetMapNumber(),
    g_RoundNumber,
    GetRoundTime(),
    GetPlayerObject(attacker)
  );

  char grenadeKey[16];
  IntToString(entityId, grenadeKey, sizeof(grenadeKey));
  g_HEAndDecoyGrenadeContainer.SetValue(grenadeKey, grenadeObject, true);

  CreateTimer(0.001, Timer_HandleHEGrenade, entityId, TIMER_FLAG_NO_MAPCHANGE);

  return Plugin_Continue;

}

public Action Timer_HandleHEGrenade(Handle timer, int entityId) {

  char grenadeKey[16];
  IntToString(entityId, grenadeKey, sizeof(grenadeKey));

  Get5HEGrenadeEvent heObject;
  if (g_HEAndDecoyGrenadeContainer.GetValue(grenadeKey, heObject)) {

    LogDebug("Calling Get5_OnHEGrenadeDetonated()");

    Call_StartForward(g_OnHEGrenadeDetonated);
    Call_PushCell(heObject);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(heObject);

    g_HEAndDecoyGrenadeContainer.Remove(grenadeKey);

  }

  return Plugin_Handled;

}


public Action Stats_GrenadeThrownEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int attacker = GetClientOfUserId(event.GetInt("userid"));

  if (!IsValidClient(attacker)) {
    return Plugin_Continue;
  }

  char weapon[32];
  event.GetString("weapon", weapon, sizeof(weapon));

  Get5GrenadeThrownEvent grenadeEvent = new Get5GrenadeThrownEvent(
    g_MatchID,
    Get5_GetMapNumber(),
    g_RoundNumber,
    GetRoundTime(),
    GetPlayerObject(attacker),
    CS_AliasToWeaponID(weapon),
    weapon
  );

  LogDebug("Calling Get5_OnGrenadeThrown()");

  Call_StartForward(g_OnGrenadeThrown);
  Call_PushCell(grenadeEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(grenadeEvent);

  return Plugin_Continue;
}

public Action Stats_PlayerDeathEvent(Event event, const char[] name, bool dontBroadcast) {
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (g_GameState != Get5State_Live || g_DoingBackupRestoreNow) {
    if (g_AutoReadyActivePlayersCvar.BoolValue) {
      // HandleReadyCommand checks for game state, so we don't need to do that here as well.
      HandleReadyCommand(attacker, true);
    }
    return Plugin_Continue;
  }

  int victim = GetClientOfUserId(event.GetInt("userid"));
  int assister = GetClientOfUserId(event.GetInt("assister"));

  bool validAttacker = IsValidClient(attacker);
  bool validVictim = IsValidClient(victim);
  bool validAssister = assister > 0 && IsValidClient(assister);

  if (!validVictim) {
    return Plugin_Continue; // Not sure how this would happen, but it's not something we care about.
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

  int attackerTeam = GetClientTeam(attacker);
  int victimTeam = GetClientTeam(victim);
  bool isSuicide = false;

  IncrementPlayerStat(victim, STAT_DEATHS);
  // used for calculating round KAST
  g_PlayerSurvived[victim] = false;

  if (!g_TeamFirstDeathDone[victimTeam]) {
    g_TeamFirstDeathDone[victimTeam] = true;
    IncrementPlayerStat(victim, (victimTeam == CS_TEAM_CT) ? STAT_FIRSTDEATH_CT : STAT_FIRSTDEATH_T);
  }

  // We need the weapon ID to reliably translate to a knife. The regular "bayonet" - as the only
  // knife - is not prefixed with "knife" for whatever reason, so searching weapon name strings
  // is unsafe.

  char translatedWeapon[32];
  CS_GetTranslatedWeaponAlias(weapon, translatedWeapon, sizeof(translatedWeapon));
  CSWeaponID weaponId = CS_AliasToWeaponID(translatedWeapon);

  if (!validAttacker || attacker == victim) {
    isSuicide = true;
  } else {
    if (HelpfulAttack(attacker, victim)) {
      if (!g_TeamFirstKillDone[attackerTeam]) {
        g_TeamFirstKillDone[attackerTeam] = true;
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
      if (weaponId == CSWeapon_KNIFE || weaponId == CSWeapon_KNIFE_GG ||
          weaponId == CSWeapon_KNIFE_T || weaponId == CSWeapon_KNIFE_GHOST ||
          weaponId > CSWeapon_MAX_WEAPONS_NO_KNIFES) {
        IncrementPlayerStat(attacker, STAT_KNIFE_KILLS);
      }
    } else {
      IncrementPlayerStat(attacker, STAT_TEAMKILLS);
    }
  }

  Get5PlayerDeathEvent playerDeathEvent = new Get5PlayerDeathEvent(
    g_MatchID,
    Get5_GetMapNumber(),
    g_RoundNumber,
    GetRoundTime(),
    weaponId,
    weapon,
    GetPlayerObject(victim),
    GetPlayerObject(attacker),
    headshot,
    validAttacker ? attackerTeam == victimTeam : false,
    event.GetBool("thrusmoke"),
    event.GetBool("noscope"),
    event.GetBool("attackerblind"),
    isSuicide,
    event.GetInt("penetrated")
  );

  if (validAssister) {

    bool assistedFlash = event.GetBool("assistedflash");
    bool friendlyFire = GetClientTeam(assister) == victimTeam;

    playerDeathEvent.Assist = new Get5AssisterObject(
      GetPlayerObject(assister),
      assistedFlash,
      friendlyFire
    );

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

  return Plugin_Continue;
}

static void UpdateTradeStat(int attacker, int victim) {
  // Look to see if victim killed any of attacker's teammates recently.
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && g_PlayerKilledBy[i] == victim &&
        GetClientTeam(i) == GetClientTeam(attacker)) {
      float dt = GetGameTime() - g_PlayerKilledByTime[i];
      if (dt < kTimeGivenToTrade) {
        IncrementPlayerStat(attacker, STAT_TRADEKILL);
        // teammate (i) was traded
        g_PlayerRoundKillOrAssistOrTradedDeath[i] = true;
      }
    }
  }
}

public Action Stats_BombPlantedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  g_BombPlantedTime = GetEngineTime();

  int client = GetClientOfUserId(event.GetInt("userid"));
  
  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_BOMBPLANTS);

    Get5BombPlantedEvent bombEvent = new Get5BombPlantedEvent(
      g_MatchID,
      Get5_GetMapNumber(),
      g_RoundNumber,
      GetRoundTime(),
      GetPlayerObject(client),
      event.GetInt("site")
    );

    LogDebug("Calling Get5_OnBombPlanted()");

    Call_StartForward(g_OnBombPlanted);
    Call_PushCell(bombEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(bombEvent);

  }

  return Plugin_Continue;
}

public Action Stats_BombDefusedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_BOMBDEFUSES);

    int timeRemaining = (GetCvarIntSafe("mp_c4timer") * 1000) - GetMilliSecondsPassedSince(g_BombPlantedTime);
    if (timeRemaining < 0) {
      timeRemaining = 0; // fail-safe in case of race conditions between events or if the timer value is changed after plant.
    }

    Get5BombDefusedEvent defuseEvent = new Get5BombDefusedEvent(
      g_MatchID,
      Get5_GetMapNumber(),
      g_RoundNumber,
      GetRoundTime(),
      GetPlayerObject(client),
      event.GetInt("site"),
      timeRemaining
    );

    LogDebug("Calling Get5_OnBombDefused()");

    Call_StartForward(g_OnBombDefused);
    Call_PushCell(defuseEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(defuseEvent);

  }

  return Plugin_Continue;
}

public Action Stats_BombExplodedEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  Get5BombExplodedEvent bombExplodedEvent = new Get5BombExplodedEvent(
    g_MatchID,
    Get5_GetMapNumber(),
    g_RoundNumber,
    GetRoundTime(),
    event.GetInt("site")
  );

  LogDebug("Calling Get5_OnBombExploded()");

  Call_StartForward(g_OnBombExploded);
  Call_PushCell(bombExplodedEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(bombExplodedEvent);

  return Plugin_Continue;
}

public Action Stats_PlayerBlindEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  float duration = event.GetFloat("blind_duration");
  int victim = GetClientOfUserId(event.GetInt("userid"));
  int attacker = GetClientOfUserId(event.GetInt("attacker"));

  if (attacker == victim || !IsValidClient(attacker) || !IsValidClient(victim)) {
    return Plugin_Continue;
  }

  int victimTeam = GetClientTeam(victim);
  if (victimTeam == CS_TEAM_SPECTATOR || victimTeam == CS_TEAM_NONE) {
    return Plugin_Continue;
  }

  bool friendlyFire = GetClientTeam(attacker) == victimTeam;

  if (duration >= 2.5) {
    // 2.5 is an arbitrary value that closely matches the "enemies flashed" column of the in-game
    // scoreboard.
    friendlyFire ? IncrementPlayerStat(attacker, STAT_FRIENDLIES_FLASHED) : IncrementPlayerStat(attacker, STAT_ENEMIES_FLASHED);
  }

  if (duration >= 0.5) {
    // Anything less than half a second is not worth storing as a victim.
    int entityId = event.GetInt("entityid");
    char flashKey[16];
    IntToString(entityId, flashKey, sizeof(flashKey));
    Get5FlashbangGrenadeEvent flashEvent;
    if (g_FlashbangContainer.GetValue(flashKey, flashEvent)) {

      flashEvent.Victims.PushObject(new Get5BlindedGrenadeVictim(
        GetPlayerObject(victim),
        friendlyFire,
        duration
      ));
  }

  }

  return Plugin_Continue;
}

public Action Stats_RoundMVPEvent(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (IsValidClient(client)) {
    IncrementPlayerStat(client, STAT_MVP);

    Get5RoundMVPEvent mvpEvent = new Get5RoundMVPEvent(
      g_MatchID,
      Get5_GetMapNumber(),
      g_RoundNumber,
      GetPlayerObject(client),
      event.GetInt("reason")
    );

    LogDebug("Calling Get5_OnPlayerBecameMVP()");

    Call_StartForward(g_OnPlayerBecameMVP);
    Call_PushCell(mvpEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(mvpEvent);

  }

  return Plugin_Continue;
}

static int GetPlayerStat(int client, const char[] field) {
  GoToPlayer(client);
  int value = g_StatsKv.GetNum(field);
  GoBackFromPlayer();
  return value;
}

static int SetPlayerStat(int client, const char[] field, int newValue) {
  GoToPlayer(client);
  g_StatsKv.SetNum(field, newValue);
  GoBackFromPlayer();
  return newValue;
}

public int AddToPlayerStat(int client, const char[] field, int delta) {
  int value = GetPlayerStat(client, field);
  return SetPlayerStat(client, field, value + delta);
}

static int IncrementPlayerStat(int client, const char[] field) {
  LogDebug("Incrementing player stat %s for %L", field, client);
  return AddToPlayerStat(client, field, 1);
}

static void GoToMap() {
  char mapNumberString[32];
  Format(mapNumberString, sizeof(mapNumberString), "map%d", GetMapStatsNumber());
  g_StatsKv.JumpToKey(mapNumberString, true);
}

static void GoBackFromMap() {
  g_StatsKv.GoBack();
}

static void GoToTeam(MatchTeam team) {
  GoToMap();

  if (team == MatchTeam_Team1)
    g_StatsKv.JumpToKey("team1", true);
  else
    g_StatsKv.JumpToKey("team2", true);
}

static void GoBackFromTeam() {
  GoBackFromMap();
  g_StatsKv.GoBack();
}

static void GoToPlayer(int client) {
  MatchTeam team = GetClientMatchTeam(client);
  GoToTeam(team);

  char auth[AUTH_LENGTH];
  if (GetAuth(client, auth, sizeof(auth))) {
    g_StatsKv.JumpToKey(auth, true);
  }
}

static void GoBackFromPlayer() {
  GoBackFromTeam();
  g_StatsKv.GoBack();
}

public int GetMapStatsNumber() {
  int x = Get5_GetMapNumber();
  if (g_MapChangePending) {
    x--;
  }
  return x;
}

static int GetClutchingClient(int csTeam) {
  int client = -1;
  int count = 0;
  for (int i = 1; i <= MaxClients; i++) {
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

public void DumpToFile() {
  char path[PLATFORM_MAX_PATH + 1];
  if (FormatCvarString(g_StatsPathFormatCvar, path, sizeof(path))) {
    DumpToFilePath(path);
  }
}

public bool DumpToFilePath(const char[] path) {
  return IsJSONPath(path) ? DumpToJSONFile(path) : g_StatsKv.ExportToFile(path);
}

public bool DumpToJSONFile(const char[] path) {
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

JSON_Object EncodeKeyValue(KeyValues kv) {
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

static void PrintDamageInfo(int client) {
  if (!IsPlayer(client))
    return;

  int team = GetClientTeam(client);
  if (team != CS_TEAM_T && team != CS_TEAM_CT)
    return;

  char message[256];

  int otherTeam = (team == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && GetClientTeam(i) == otherTeam) {
      int health = IsPlayerAlive(i) ? GetClientHealth(i) : 0;
      char name[64];
      GetClientName(i, name, sizeof(name));

      g_DamagePrintFormat.GetString(message, sizeof(message));
      ReplaceStringWithInt(message, sizeof(message), "{DMG_TO}", g_DamageDone[client][i], false);
      ReplaceStringWithInt(message, sizeof(message), "{HITS_TO}", g_DamageDoneHits[client][i], false);

      if (g_DamageDoneKill[client][i]) {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "{GREEN}X{NORMAL}", false);
      } else if (g_DamageDoneAssist[client][i]) {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "{YELLOW}A{NORMAL}", false);
      } else if (g_DamageDoneFlashAssist[client][i]) {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "{YELLOW}F{NORMAL}", false);
      } else {
          ReplaceString(message, sizeof(message), "{KILL_TO}", "–", false);
      }

      ReplaceStringWithInt(message, sizeof(message), "{DMG_FROM}", g_DamageDone[i][client], false);
      ReplaceStringWithInt(message, sizeof(message), "{HITS_FROM}", g_DamageDoneHits[i][client], false);

      if (g_DamageDoneKill[i][client]) {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "{DARK_RED}X{NORMAL}", false);
      } else if (g_DamageDoneAssist[i][client]) {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "{YELLOW}A{NORMAL}", false);
      } else if (g_DamageDoneFlashAssist[i][client]) {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "{YELLOW}F{NORMAL}", false);
      } else {
          ReplaceString(message, sizeof(message), "{KILL_FROM}", "–", false);
      }

      ReplaceString(message, sizeof(message), "{NAME}", name, false);
      ReplaceStringWithInt(message, sizeof(message), "{HEALTH}", health, false);

      Colorize(message, sizeof(message));
      PrintToChat(client, message);
    }
  }
}
