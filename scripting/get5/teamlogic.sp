public Action Command_JoinGame(int client, const char[] command, int argc) {
  if (g_GameState != Get5State_None && g_CheckAuthsCvar.BoolValue && IsPlayer(client) && !g_PendingSideSwap) {
    // In order to avoid duplication of team-join logic, we directly call the same handle that would be called
    // if the user selected any team after joining. Since Command_JoinTeam handles the actual joining using a
    // FakeClientCommand, we don't have to do any team-logic here and it won't matter what we pass to Command_JoinTeam.
    // The only thing that's important is that the command argument is empty, as that avoids a call to GetCmdArg in that function.
    CreateTimer(0.1, Timer_PlacePlayerOnJoin, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
  }
  return Plugin_Continue;
}

public Action Timer_PlacePlayerOnJoin(Handle timer, int userId) {
  int client = GetClientOfUserId(userId);
  if (client) { // Client might have disconnected between timer and callback.
    Command_JoinTeam(client, "", 1);
  }
}

public void CheckClientTeam(int client) {
  Get5Team correctTeam = GetClientMatchTeam(client);
  char auth[AUTH_LENGTH];
  int csTeam = Get5TeamToCSTeam(correctTeam);
  int currentTeam = GetClientTeam(client);

  if (csTeam != currentTeam) {
    if (IsClientCoaching(client)) {
      UpdateCoachTarget(client, csTeam);
    } else if (GetAuth(client, auth, sizeof(auth))) {
      char steam64[AUTH_LENGTH];
      ConvertAuthToSteam64(auth, steam64);
      if (IsAuthOnTeamCoach(steam64, correctTeam)) {
        UpdateCoachTarget(client, csTeam);
      }
    }

    SwitchPlayerTeam(client, csTeam);
  }
}

public Action Command_JoinTeam(int client, const char[] command, int argc) {
  if (!IsAuthedPlayer(client) || argc < 1)
    return Plugin_Stop;

  // Don't do anything if not live/not in startup phase.
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  // Don't enforce team joins.
  if (!g_CheckAuthsCvar.BoolValue) {
    return Plugin_Continue;
  }

  if (g_PendingSideSwap) {
    LogDebug("Blocking teamjoin due to pending swap");
    return Plugin_Stop;
  }

  Get5Team correctTeam = GetClientMatchTeam(client);
  int csTeam = Get5TeamToCSTeam(correctTeam);

  // This is required as it avoids an exception due to calling this function
  // from Timer_PlacePlayerOnJoin, which gets called from Command_JoinGame.
  if (!StrEqual("", command)) {
    char arg[4];
    int team_to;
    GetCmdArg(1, arg, sizeof(arg));
    team_to = StringToInt(arg);

    LogDebug("%L jointeam command, from %d to %d", client, GetClientTeam(client), team_to);

    // don't let someone change to a "none" team (e.g. using auto-select)
    if (team_to == CS_TEAM_NONE) {
      return Plugin_Stop;
    }

    if (csTeam == team_to) {
      if (CheckIfClientCoachingAndMoveToCoach(client, correctTeam)) {
        return Plugin_Stop;
      } else {
        return Plugin_Continue;
      }
    }
  }

  LogDebug("jointeam, gamephase = %d", GetGamePhase());

  if (csTeam != GetClientTeam(client)) {
    int count = CountPlayersOnCSTeam(csTeam);

    if (count >= g_PlayersPerTeam) {
      if (!g_CoachingEnabledCvar.BoolValue) {
        KickClient(client, "%t", "TeamIsFullInfoMessage");
      } else {
        // Only attempt to move to coach if we are not full on coaches already.
        if (GetTeamCoaches(correctTeam).Length <= g_CoachesPerTeam) {
          char auth[AUTH_LENGTH];
          LogDebug("Forcing player %N to coach", client);
          GetAuth(client, auth, sizeof(auth));
          // Only output MoveToCoachInfoMessage if we are not
          // in the coach array already.
          if (!IsAuthOnTeamCoach(auth, correctTeam)) {
            Get5_Message(client, "%t", "MoveToCoachInfoMessage");
          }
          MoveClientToCoach(client);
        } else {
          KickClient(client, "%t", "TeamIsFullInfoMessage");
        }
      }
    } else if (!CheckIfClientCoachingAndMoveToCoach(client, correctTeam)) {
      LogDebug("Forcing player %N onto %d", client, csTeam);
      FakeClientCommand(client, "jointeam %d", csTeam);
    }

    return Plugin_Stop;
  }

  return Plugin_Stop;
}

public bool CheckIfClientCoachingAndMoveToCoach(int client, Get5Team team) {
  if (!g_CoachingEnabledCvar.BoolValue) {
    return false;
  }
  // Force user to join the coach if specified by config or reconnect.
  char clientAuth64[AUTH_LENGTH];
  GetAuth(client, clientAuth64, AUTH_LENGTH);
  if (IsAuthOnTeamCoach(clientAuth64, team)) {
    LogDebug("Forcing player %N to coach as they were previously.", client);
    MoveClientToCoach(client);
    return true;
  }
  return false;
}

public void MoveClientToCoach(int client) {
  LogDebug("MoveClientToCoach %L", client);
  Get5Team matchTeam = GetClientMatchTeam(client);
  if (matchTeam != Get5Team_1 && matchTeam != Get5Team_2) {
    return;
  }

  if (!g_CoachingEnabledCvar.BoolValue) {
    return;
  }

  int csTeam = Get5TeamToCSTeam(matchTeam);

  if (g_PendingSideSwap) {
    LogDebug("Blocking coach move due to pending swap");
    return;
  }

  char teamString[4];
  char clientAuth[64];
  CSTeamString(csTeam, teamString, sizeof(teamString));
  GetAuth(client, clientAuth, AUTH_LENGTH);
  if (!IsAuthOnTeamCoach(clientAuth, matchTeam)) {
    AddCoachToTeam(clientAuth, matchTeam, "");
    // If we're already on the team, make sure we remove ourselves
    // to ensure data is correct in the backups.
    int index = GetTeamAuths(matchTeam).FindString(clientAuth);
    if (index >= 0) {
      GetTeamAuths(matchTeam).Erase(index);
    }
  }

  // If we're in warmup we use the in-game
  // coaching command. Otherwise we manually move them to spec
  // and set the coaching target.
  // If in freeze time, we have to manually move as well.
  if (!InWarmup() && InFreezeTime()) {
    LogDebug("Moving %L directly to coach slot", client);
    SwitchPlayerTeam(client, CS_TEAM_SPECTATOR);
    UpdateCoachTarget(client, csTeam);
    // Need to set to avoid third person view bug.
    SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
  } else {
    LogDebug("Moving %L indirectly to coach slot via coach cmd", client);
    g_MovingClientToCoach[client] = true;
    FakeClientCommand(client, "coach %s", teamString);
    g_MovingClientToCoach[client] = false;
  }
}

public Action Command_SmCoach(int client, int args) {
  char auth[AUTH_LENGTH];
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  if (!g_CoachingEnabledCvar.BoolValue) {
    return Plugin_Handled;
  }

  GetAuth(client, auth, sizeof(auth));
  Get5Team matchTeam = GetClientMatchTeam(client);
  // Don't allow a new coach if spots are full.
  if (GetTeamCoaches(matchTeam).Length > g_CoachesPerTeam) {
    return Plugin_Stop;
  }

  MoveClientToCoach(client);
  // Update the backup structure as well for round restores, covers edge
  // case of users joining, coaching, stopping, and getting 16k cash as player.
  WriteBackup();
  return Plugin_Handled;
}

public Action Command_Coach(int client, const char[] command, int argc) {
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  if (!g_CoachingEnabledCvar.BoolValue) {
    return Plugin_Handled;
  }

  if (!IsAuthedPlayer(client)) {
    return Plugin_Stop;
  }

  if (InHalftimePhase()) {
    return Plugin_Stop;
  }

  if (g_MovingClientToCoach[client] || !g_CheckAuthsCvar.BoolValue) {
    LogDebug("Command_Coach: %L, letting pass-through", client);
    return Plugin_Continue;
  }

  MoveClientToCoach(client);
  // Update the backup structure as well for round restores, covers edge
  // case of users joining, coaching, stopping, and getting 16k cash as player.
  WriteBackup();
  return Plugin_Stop;
}

public Get5Team GetClientMatchTeam(int client) {
  if (!g_CheckAuthsCvar.BoolValue) {
    return CSTeamToGet5Team(GetClientTeam(client));
  } else {
    char auth[AUTH_LENGTH];
    if (GetAuth(client, auth, sizeof(auth))) {
      Get5Team playerTeam = GetAuthMatchTeam(auth);
      if (playerTeam == Get5Team_None) {
        playerTeam = GetAuthMatchTeamCoach(auth);
      }
      return playerTeam;
    } else {
      return Get5Team_None;
    }
  }
}

public int Get5TeamToCSTeam(Get5Team t) {
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

public Get5Team CSTeamToGet5Team(int csTeam) {
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

public Get5Team GetAuthMatchTeam(const char[] steam64) {
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

public Get5Team GetAuthMatchTeamCoach(const char[] steam64) {
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

stock int CountPlayersOnCSTeam(int team, int exclude = -1) {
  int count = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (i != exclude && IsAuthedPlayer(i) && GetClientTeam(i) == team) {
      count++;
    }
  }
  return count;
}

stock int CountPlayersOnMatchTeam(Get5Team team, int exclude = -1) {
  int count = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (i != exclude && IsAuthedPlayer(i) && GetClientMatchTeam(i) == team) {
      count++;
    }
  }
  return count;
}

// Returns the match team a client is the captain of, or MatchTeam_None.
public Get5Team GetCaptainTeam(int client) {
  if (client == GetTeamCaptain(Get5Team_1)) {
    return Get5Team_1;
  } else if (client == GetTeamCaptain(Get5Team_2)) {
    return Get5Team_2;
  } else {
    return Get5Team_None;
  }
}

public int GetTeamCaptain(Get5Team team) {
  // If not forcing auths, take the 1st client on the team.
  if (!g_CheckAuthsCvar.BoolValue) {
    for (int i = 1; i <= MaxClients; i++) {
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

public int GetNextTeamCaptain(int client) {
  if (client == g_VetoCaptains[Get5Team_1]) {
    return g_VetoCaptains[Get5Team_2];
  } else {
    return g_VetoCaptains[Get5Team_1];
  }
}

public ArrayList GetTeamAuths(Get5Team team) {
  return g_TeamAuths[team];
}

public ArrayList GetTeamCoaches(Get5Team team) {
  return g_TeamCoaches[team];
}

public bool IsAuthOnTeam(const char[] auth, Get5Team team) {
  return GetTeamAuths(team).FindString(auth) >= 0;
}

public bool IsAuthOnTeamCoach(const char[] auth, Get5Team team) {
  return GetTeamCoaches(team).FindString(auth) >= 0;
}

public void SetStartingTeams() {
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

public void AddMapScore() {
  int currentMapNumber = Get5_GetMapNumber();

  g_TeamScoresPerMap.Set(currentMapNumber, CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1)),
                         view_as<int>(Get5Team_1));

  g_TeamScoresPerMap.Set(currentMapNumber, CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2)),
                         view_as<int>(Get5Team_2));
}

public int GetMapScore(int mapNumber, Get5Team team) {
  return g_TeamScoresPerMap.Get(mapNumber, view_as<int>(team));
}

public bool HasMapScore(int mapNumber) {
  return GetMapScore(mapNumber, Get5Team_1) != 0 || GetMapScore(mapNumber, Get5Team_2) != 0;
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

  if (GetAuthMatchTeamCoach(steam64) == Get5Team_None) {
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

public void LoadPlayerNames() {
  KeyValues namesKv = new KeyValues("Names");
  int numNames = 0;
  LOOP_TEAMS(team) {
    char id[AUTH_LENGTH + 1];
    char name[MAX_NAME_LENGTH + 1];
    ArrayList ids = GetTeamAuths(team);
    ArrayList coachIds = GetTeamCoaches(team);
    for (int i = 0; i < ids.Length; i++) {
      ids.GetString(i, id, sizeof(id));
      if (g_PlayerNames.GetString(id, name, sizeof(name)) && !StrEqual(name, "") &&
          !StrEqual(name, KEYVALUE_STRING_PLACEHOLDER)) {
        namesKv.SetString(id, name);
        numNames++;
      }
    }
    for (int i = 0; i < coachIds.Length; i++) {
      // There's a way to push an array of cells into the end, however, it
      // becomes a single element, rather than pushing individually.
      coachIds.GetString(i, id, sizeof(id));
      if (g_PlayerNames.GetString(id, name, sizeof(name)) && !StrEqual(name, "") &&
          !StrEqual(name, KEYVALUE_STRING_PLACEHOLDER)) {
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
    } else {
      LogError("Failed to write names keyvalue file to %s", nameFile);
    }
  }

  delete namesKv;
}

public void SwapScrimTeamStatus(int client) {
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
  }
  CheckClientTeam(client);
}
