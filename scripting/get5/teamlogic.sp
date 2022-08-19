public Action Command_JoinGame(int client, const char[] command, int argc) {
  if (g_GameState != Get5State_None && g_CheckAuthsCvar.BoolValue && IsPlayer(client)) {
    CreateTimer(0.1, Timer_PlacePlayerOnJoin, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
  }
  return Plugin_Continue;
}

public Action Timer_PlacePlayerOnJoin(Handle timer, int userId) {
  int client = GetClientOfUserId(userId);
  if (client) {  // Client might have disconnected between timer and callback.
    PlacePlayerOnTeam(client);
  }
}

void CheckClientTeam(int client, bool useDefaultTeamSelection = true) {
  if (!g_CheckAuthsCvar.BoolValue) {
    // Teams are not enforced; do nothing.
    return;
  }

  Get5Team correctTeam = GetClientMatchTeam(client);
  if (correctTeam == Get5Team_None) {
    RememberAndKickClient(client, "%t", "YouAreNotAPlayerInfoMessage");
    return;
  }

  Get5Side correctSide = view_as<Get5Side>(Get5TeamToCSTeam(correctTeam));
  if (correctSide == Get5Side_None) {
    // This should not be possible.
    LogError("Client %d belongs to no side. This is an unexpected error and should be reported.", client);
    return;
  }

  int coachesOnTeam = CountCoachesOnTeam(correctTeam, client);
  // If the player is fixed to coaching, always ensure they end there and on the correct side.
  if (g_CoachingEnabledCvar.BoolValue && IsClientCoachForTeam(client, correctTeam)) {
    // If there are free coach spots on the team, send the player there
    if (coachesOnTeam < g_CoachesPerTeam) {
      SetClientCoaching(client, correctSide);
    } else {
      KickClient(client, "%t", "TeamIsFullInfoMessage");
    }
    return;
  }

  // If player was not locked to coaching, check if their team's current size -self is less than the max.
  if (CountPlayersOnTeam(correctTeam, client) < g_PlayersPerTeam) {
    SwitchPlayerTeam(client, correctSide, useDefaultTeamSelection);
    return;
  }

  // We end here if a player was not a predefined coach while there was no space as a regular player. If coaching is
  // enabled, we drop the player in coach, and if not, they must be kicked.
  if (g_CoachingEnabledCvar.BoolValue && coachesOnTeam < g_CoachesPerTeam) {
    Get5_Message(client, "%t", "MoveToCoachInfoMessage");
    // In scrim mode, we don't put coaches or players of the "away" team into any auth arrays; they default to the
    // opposite of the home team. If a full team's coach disconnects or leaves and rejoins, they should be placed on the
    // coach team if their team is full. In a regular match, they will have called .coach before the map starts and will
    // be placed by auth above.
    if (!g_InScrimMode) {
      MovePlayerToCoachInConfig(client, correctTeam);
    }
    SetClientCoaching(client, correctSide);
    return;
  }
  KickClient(client, "%t", "TeamIsFullInfoMessage");
}

static void PlacePlayerOnTeam(int client) {
  if (g_PendingSideSwap || InHalftimePhase()) {
    LogDebug("Blocking attempt to join a team due to halftime or pending team swap.");
    g_AssignTeamNonePlayersOnRoundStart = true;
    return;
  }
  CheckClientTeam(client);
}

public Action Command_JoinTeam(int client, const char[] command, int argc) {
  if (g_GameState == Get5State_None || !g_CheckAuthsCvar.BoolValue) {
    return Plugin_Continue;
  }
  // If, in some odd case, a player should find themselves on no team while g_CheckAuthsCvar is true, we want to let
  // them trigger the PlacePlayerOnTeam logic when clicking any team. In any other case, we just block.
  // Blocking ensures that coaches in scrim-mode will not stop coaching if they select a team in the menu.
  if (IsAuthedPlayer(client) && GetClientTeam(client) == CS_TEAM_NONE) {
    PlacePlayerOnTeam(client);
  }
  return Plugin_Stop;
}

static bool IsClientCoachForTeam(int client, Get5Team team) {
  char clientAuth64[AUTH_LENGTH];
  return GetAuth(client, clientAuth64, AUTH_LENGTH) && IsAuthOnTeamCoach(clientAuth64, team);
}

void SetClientCoaching(int client, Get5Side side) {
  if (GetClientCoachingSide(client) == side) {
    return;
  }
  LogDebug("Setting client %d as spectator and coach for side %d.", client, side);
  SwitchPlayerTeam(client, Get5Side_Spec);
  SetEntProp(client, Prop_Send, "m_iCoachingTeam", side);
  SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
  SetEntProp(client, Prop_Send, "m_iAccount", 0); // Ensures coaches have no money if they were to rejoin the game.

  char formattedPlayerName[MAX_NAME_LENGTH];
  FormatPlayerName(formattedPlayerName, sizeof(formattedPlayerName), client, side);
  Get5_MessageToAll("%t", "PlayerIsCoachingTeam", formattedPlayerName, g_FormattedTeamNames[GetClientMatchTeam(client)]);
}

public void CoachingChangedHook(ConVar convar, const char[] oldValue, const char[] newValue) {
  if (g_GameState == Get5State_None) {
    return;
  }
  // If disabling coaching, make sure we swap coaches to team or kick them, as they are now regular spectators.
  if (StringToInt(oldValue) != 0 && !convar.BoolValue) {
    LogDebug("Detected sv_coaching_enabled was disabled. Checking for coaches.");
    LOOP_CLIENTS(i) {
      if (IsAuthedPlayer(i) && IsClientCoaching(i)) {
        CheckClientTeam(i);
      }
    }
  }
}

public Action Command_SmCoach(int client, int args) {
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  if (!g_CoachingEnabledCvar.BoolValue) {
    Get5_Message(client, "%t", "CoachingNotEnabled", "sv_coaching_enabled");
    return Plugin_Continue;
  }

  Get5Team matchTeam = GetClientMatchTeam(client);

  if (matchTeam == Get5Team_None) {
    return Plugin_Continue;
  }

  if (g_GameState > Get5State_Warmup) {
    Get5_Message(client, "%t", "CanOnlyCoachDuringWarmup");
    return Plugin_Continue;
  }

  // These counts are excluding the client, so >=.
  bool coachSlotsFull = CountCoachesOnTeam(matchTeam, client) >= g_CoachesPerTeam;
  bool playerSlotsFull = CountPlayersOnTeam(matchTeam, client) >= g_PlayersPerTeam;

  // If we're in scrim mode, we don't update the coaches auth array ever.
  if (g_InScrimMode) {
    if (IsClientCoaching(client)) {
      if (playerSlotsFull) {
        Get5_Message(client, "%t", "CannotLeaveCoachingTeamIsFull");
        return Plugin_Continue;
      }
      // Fall-through to CheckClientTeam(i) below, which moves the player back on the team because they are not
      // defined as a coach in auth.
    } else {
      if (coachSlotsFull) {
        Get5_Message(client, "%t", "AllCoachSlotsFilledForTeam", g_CoachesPerTeam);
        return Plugin_Continue;
      }
      // We use SetClientCoaching instead of fall-though because of missing auth.
      SetClientCoaching(client, view_as<Get5Side>(Get5TeamToCSTeam(matchTeam)));
      return Plugin_Continue;
    }
  } else {
    if (IsClientCoachForTeam(client, matchTeam)) {
      if (playerSlotsFull) {
        Get5_Message(client, "%t", "CannotLeaveCoachingTeamIsFull");
        return Plugin_Continue;
      }
      MoveCoachToPlayerInConfig(client, matchTeam);
    } else {
      if (coachSlotsFull) {
        Get5_Message(client, "%t", "AllCoachSlotsFilledForTeam", g_CoachesPerTeam);
        return Plugin_Continue;
      }
      MovePlayerToCoachInConfig(client, matchTeam);
    }
  }
  // Move the player. This would potentially kick them if we did not perform above checks.
  CheckClientTeam(client);
  return Plugin_Continue;
}

static void MovePlayerToCoachInConfig(const int client, const Get5Team team) {
  char auth[AUTH_LENGTH];
  GetAuth(client, auth, sizeof(auth));
  if (AddCoachToTeam(auth, team, "")) {
    // If we're already on the team, make sure we remove ourselves
    // to ensure data is correct in the backups.
    int index = GetTeamAuths(team).FindString(auth);
    if (index >= 0) {
      LogDebug("Removing client %d from player team auth array for team %d.", client, team);
      GetTeamAuths(team).Erase(index);
    }
  }
}

static void MoveCoachToPlayerInConfig(const int client, const Get5Team team) {
  char auth[AUTH_LENGTH];
  GetAuth(client, auth, sizeof(auth));
  AddPlayerToTeam(auth, team, "");
  // This differs from MovePlayerToCoachInConfig because being in coach array + player array will make coaching
  // take precedence, so if you're being added from coach to player, and you're already defined as a player, the above
  // function will return false, so we always remove from the coach array when moving from coach to player.
  int index = GetTeamCoaches(team).FindString(auth);
  if (index >= 0) {
    LogDebug("Removing client %d from coach team auth array for team %d", client, team);
    GetTeamCoaches(team).Erase(index);
  }
}

public Action Command_Coach(int client, const char[] command, int argc) {
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }
  ReplyToCommand(client, "Please use .coach in chat or sm_coach instead of the built-in console coach command.");
  return Plugin_Stop;
}

Get5Team GetClientMatchTeam(int client) {
  if (!g_CheckAuthsCvar.BoolValue) {
    return CSTeamToGet5Team(GetClientTeam(client));
  } else {
    char auth[AUTH_LENGTH];
    if (GetAuth(client, auth, sizeof(auth))) {
      Get5Team playerTeam = GetAuthMatchTeam(auth);
      if (playerTeam == Get5Team_None) {
        playerTeam = GetAuthMatchCoachTeam(auth);
      }
      return playerTeam;
    } else {
      return Get5Team_None;
    }
  }
}

int Get5TeamToCSTeam(Get5Team t) {
  if (t == Get5Team_1) {
    return g_TeamSide[Get5Team_1];
  } else if (t == Get5Team_2) {
    return g_TeamSide[Get5Team_2];
  } else if (t == Get5Team_Spec) {
    return CS_TEAM_SPECTATOR;
  } else {
    return CS_TEAM_NONE;
  }
}

Get5Team CSTeamToGet5Team(int csTeam) {
  if (csTeam == g_TeamSide[Get5Team_1]) {
    return Get5Team_1;
  } else if (csTeam == g_TeamSide[Get5Team_2]) {
    return Get5Team_2;
  } else if (csTeam == CS_TEAM_SPECTATOR) {
    return Get5Team_Spec;
  } else {
    return Get5Team_None;
  }
}

Get5Team GetAuthMatchTeam(const char[] steam64) {
  if (g_GameState == Get5State_None) {
    return Get5Team_None;
  }

  if (g_InScrimMode) {
    return IsAuthOnTeam(steam64, Get5Team_1) ? Get5Team_1 : Get5Team_2;
  }

  for (int i = 0; i < MATCHTEAM_COUNT; i++) {
    Get5Team team = view_as<Get5Team>(i);
    if (IsAuthOnTeam(steam64, team)) {
      return team;
    }
  }
  return Get5Team_None;
}

Get5Team GetAuthMatchCoachTeam(const char[] steam64) {
  if (g_GameState == Get5State_None) {
    return Get5Team_None;
  }

  if (g_InScrimMode) {
    return IsAuthOnTeamCoach(steam64, Get5Team_1) ? Get5Team_1 : Get5Team_2;
  }

  for (int i = 0; i < MATCHTEAM_COUNT; i++) {
    Get5Team team = view_as<Get5Team>(i);
    if (IsAuthOnTeamCoach(steam64, team)) {
      return team;
    }
  }
  return Get5Team_None;
}

int CountCoachesOnTeam(Get5Team team, int exclude = -1) {
  int count = 0;
  Get5Side side = view_as<Get5Side>(Get5TeamToCSTeam(team));
  LOOP_CLIENTS(i) {
    if (i != exclude && IsAuthedPlayer(i) && GetClientMatchTeam(i) == team && GetClientCoachingSide(i) == side) {
      count++;
    }
  }
  return count;
}

int CountPlayersOnTeam(Get5Team team, int exclude = -1) {
  int count = 0;
  Get5Side side = view_as<Get5Side>(Get5TeamToCSTeam(team));
  LOOP_CLIENTS(i) {
    if (i != exclude && IsAuthedPlayer(i) && GetClientMatchTeam(i) == team && view_as<Get5Side>(GetClientTeam(i)) == side) {
      count++;
    }
  }
  return count;
}

Get5Side GetClientCoachingSide(int client) {
  if (GetClientTeam(client) != CS_TEAM_SPECTATOR) {
   return Get5Side_None;
  }
  int side = GetEntProp(client, Prop_Send, "m_iCoachingTeam");
  if (side == CS_TEAM_CT) {
    return Get5Side_CT;
  } else if (side == CS_TEAM_T) {
    return Get5Side_T;
  }
  return Get5Side_None;
}

int GetTeamCaptain(Get5Team team) {
  // If not forcing auths, take the 1st client on the team.
  if (!g_CheckAuthsCvar.BoolValue) {
    LOOP_CLIENTS(i) {
      if (IsAuthedPlayer(i) && GetClientMatchTeam(i) == team) {
        return i;
      }
    }
    return -1;
  }

  // For consistency, always take the 1st auth on the list.
  ArrayList auths = GetTeamAuths(team);
  char buffer[AUTH_LENGTH];
  for (int i = 0; i < auths.Length; i++) {
    auths.GetString(i, buffer, sizeof(buffer));
    int client = AuthToClient(buffer);
    if (IsAuthedPlayer(client)) {
      return client;
    }
  }
  return -1;
}

int GetNextTeamCaptain(int client) {
  if (client == g_VetoCaptains[Get5Team_1]) {
    return g_VetoCaptains[Get5Team_2];
  } else {
    return g_VetoCaptains[Get5Team_1];
  }
}

ArrayList GetTeamAuths(Get5Team team) {
  return g_TeamAuths[team];
}

ArrayList GetTeamCoaches(Get5Team team) {
  return g_TeamCoaches[team];
}

bool IsAuthOnTeam(const char[] auth, Get5Team team) {
  return GetTeamAuths(team).FindString(auth) >= 0;
}

bool IsAuthOnTeamCoach(const char[] auth, Get5Team team) {
  return GetTeamCoaches(team).FindString(auth) >= 0;
}

void SetStartingTeams() {
  int mapNumber = Get5_GetMapNumber();
  if (mapNumber >= g_MapSides.Length || g_MapSides.Get(mapNumber) == SideChoice_KnifeRound) {
    g_TeamSide[Get5Team_1] = TEAM1_STARTING_SIDE;
    g_TeamSide[Get5Team_2] = TEAM2_STARTING_SIDE;
  } else {
    if (g_MapSides.Get(mapNumber) == SideChoice_Team1CT) {
      g_TeamSide[Get5Team_1] = CS_TEAM_CT;
      g_TeamSide[Get5Team_2] = CS_TEAM_T;
    } else {
      g_TeamSide[Get5Team_1] = CS_TEAM_T;
      g_TeamSide[Get5Team_2] = CS_TEAM_CT;
    }
  }

  g_TeamStartingSide[Get5Team_1] = g_TeamSide[Get5Team_1];
  g_TeamStartingSide[Get5Team_2] = g_TeamSide[Get5Team_2];
}

int GetMapScore(int mapNumber, Get5Team team) {
  return g_TeamScoresPerMap.Get(mapNumber, view_as<int>(team));
}

bool AddPlayerToTeam(const char[] auth, Get5Team team, const char[] name) {
  char steam64[AUTH_LENGTH];
  if (!ConvertAuthToSteam64(auth, steam64)) {
    return false;
  }

  if (GetAuthMatchTeam(steam64) == Get5Team_None) {
    GetTeamAuths(team).PushString(steam64);
    Get5_SetPlayerName(auth, name);
    return true;
  } else {
    return false;
  }
}

bool AddCoachToTeam(const char[] auth, Get5Team team, const char[] name) {
  if (team == Get5Team_Spec) {
    LogDebug("Not allowed to coach a spectator team.");
    return false;
  }

  char steam64[AUTH_LENGTH];
  if (!ConvertAuthToSteam64(auth, steam64)) {
    return false;
  }

  if (GetAuthMatchCoachTeam(steam64) == Get5Team_None) {
    GetTeamCoaches(team).PushString(steam64);
    Get5_SetPlayerName(auth, name);
    return true;
  } else {
    return false;
  }
}

bool RemovePlayerFromTeams(const char[] auth) {
  char steam64[AUTH_LENGTH];
  if (!ConvertAuthToSteam64(auth, steam64)) {
    return false;
  }

  for (int i = 0; i < MATCHTEAM_COUNT; i++) {
    Get5Team team = view_as<Get5Team>(i);
    int index = GetTeamAuths(team).FindString(steam64);
    if (index >= 0) {
      GetTeamAuths(team).Erase(index);
    } else {
      index = GetTeamCoaches(team).FindString(steam64);
      if (index >= 0) {
        GetTeamCoaches(team).Erase(index);
      }
    }
    if (index >= 0) {
      int target = AuthToClient(steam64);
      if (IsAuthedPlayer(target) && !g_InScrimMode) {
        RememberAndKickClient(target, "%t", "YouAreNotAPlayerInfoMessage");
      }
      return true;
    }
  }
  return false;
}

void LoadPlayerNames() {
  KeyValues namesKv = new KeyValues("Names");
  int numNames = 0;
  LOOP_TEAMS(team) {
    char id[AUTH_LENGTH + 1];
    char name[MAX_NAME_LENGTH + 1];
    ArrayList ids = GetTeamAuths(team);
    ArrayList coachIds = GetTeamCoaches(team);
    for (int i = 0; i < ids.Length; i++) {
      ids.GetString(i, id, sizeof(id));
      if (g_PlayerNames.GetString(id, name, sizeof(name)) && !StrEqual(name, "")) {
        namesKv.SetString(id, name);
        numNames++;
      }
    }
    for (int i = 0; i < coachIds.Length; i++) {
      // There's a way to push an array of cells into the end, however, it
      // becomes a single element, rather than pushing individually.
      coachIds.GetString(i, id, sizeof(id));
      if (g_PlayerNames.GetString(id, name, sizeof(name)) && !StrEqual(name, "")) {
        namesKv.SetString(id, name);
        numNames++;
      }
    }
  }

  if (numNames > 0) {
    char nameFile[] = "get5_names.txt";
    DeleteFile(nameFile);
    if (namesKv.ExportToFile(nameFile)) {
      ServerCommand("sv_load_forced_client_names_file %s", nameFile);
      LogDebug("Wrote %d fixed player name(s) to %s.", numNames, nameFile);
    } else {
      LogError("Failed to write fixed player names to %s.", nameFile);
    }
  }

  delete namesKv;
}

void SwapScrimTeamStatus(int client) {
  // If we're in any team -> remove from any team list.
  // If we're not in any team -> add to team1.
  char auth[AUTH_LENGTH];
  if (GetAuth(client, auth, sizeof(auth))) {
    bool alreadyInList = RemovePlayerFromTeams(auth);
    if (!alreadyInList) {
      char steam64[AUTH_LENGTH];
      ConvertAuthToSteam64(auth, steam64);
      GetTeamAuths(Get5Team_1).PushString(steam64);
    }
    CheckClientTeam(client);
  }
}
