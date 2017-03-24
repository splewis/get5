/**
 * Ready System
 */

public void ResetReadyStatus() {
  SetAllTeamsForcedReady(false);
  SetAllClientsReady(false);
}

public bool IsReadyGameState() {
  return g_GameState == GameState_PreVeto || g_GameState == GameState_Warmup;
}

// Client ready status

public bool IsClientReady(int client) {
  return g_ClientReady[client] == true;
}

public void SetClientReady(int client, bool ready) {
  g_ClientReady[client] = ready;
}

public void SetAllClientsReady(bool ready) {
  LOOP_CLIENTS(i) {
    SetClientReady(i, ready);
  }
}

// Team ready override

public bool IsTeamForcedReady(MatchTeam team) {
  return g_TeamReadyOverride[team] == true;
}

public void SetTeamForcedReady(MatchTeam team, bool ready) {
  g_TeamReadyOverride[team] = ready;
}

public void SetAllTeamsForcedReady(bool ready) {
  LOOP_TEAMS(team) {
    SetTeamForcedReady(team, ready);
  }
}

// Team ready status

public bool IsAllReady() {
  return IsTeamsReady() && IsSpectatorsReady();
}

public bool IsTeamsReady() {
  return IsTeamReady(MatchTeam_Team1) && IsTeamReady(MatchTeam_Team2);
}

public bool IsSpectatorsReady() {
  return IsTeamReady(MatchTeam_TeamSpec);
}

public bool IsTeamReady(MatchTeam team) {
  if (g_GameState == GameState_Live) {
    return true;
  }

  if (team == MatchTeam_TeamNone) {
    return true;
  }

  int minPlayers = GetPlayersPerTeam(team);
  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team);
  int readyCount = GetTeamReadyCount(team);

  if (playerCount == readyCount && playerCount >= minPlayers) {
    return true;
  }

  if (IsTeamForcedReady(team) && readyCount >= minReady) {
    return true;
  }

  return false;
}

public int GetTeamReadyCount(MatchTeam team) {
  int readyCount = 0;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team && !IsClientCoaching(i) && IsClientReady(i)) {
      readyCount++;
    }
  }
  return readyCount;
}

public int GetTeamPlayerCount(MatchTeam team) {
  int playerCount = 0;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team && !IsClientCoaching(i)) {
      playerCount++;
    }
  }
  return playerCount;
}

public int GetTeamMinReady(MatchTeam team) {
  if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
    return g_MinPlayersToReady;
  } else if (team == MatchTeam_TeamSpec) {
    return g_MinSpectatorsToReady;
  } else {
    return 0;
  }
}

public int GetPlayersPerTeam(MatchTeam team) {
  if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
    return g_PlayersPerTeam;
  } else if (team == MatchTeam_TeamSpec) {
    // TODO: maybe this should be specified separately in a config?
    return g_MinSpectatorsToReady;
  } else {
    return 0;
  }
}

// Admin commands

public Action Command_AdminForceReady(int client, int args) {
  if (!IsReadyGameState()) {
    return Plugin_Handled;
  }

  Get5_MessageToAll("%t", "AdminForceReadyInfoMessage");
  SetAllTeamsForcedReady(true);
  SetAllClientsReady(true);
  SetMatchTeamCvars();

  return Plugin_Handled;
}

// Client commands

public Action Command_Ready(int client, int args) {
  MatchTeam team = GetClientMatchTeam(client);
  if (!IsReadyGameState() || team == MatchTeam_TeamNone) {
    return Plugin_Handled;
  }

  Get5_Message(client, "%t", "YouAreReady");

  SetClientReady(client, true);
  if (IsTeamReady(team)) {
    SetMatchTeamCvars();
    PrintReadyMessage(team);
  }

  return Plugin_Handled;
}

public Action Command_NotReady(int client, int args) {
  MatchTeam team = GetClientMatchTeam(client);
  if (!IsReadyGameState() || team == MatchTeam_TeamNone) {
    return Plugin_Handled;
  }

  Get5_Message(client, "%t", "YouAreNotReady");

  bool teamWasReady = IsTeamReady(team);
  SetClientReady(client, false);
  SetTeamForcedReady(team, false);
  if (teamWasReady) {
    SetMatchTeamCvars();
    Get5_MessageToAll("%t", "TeamNotReadyInfoMessage", g_FormattedTeamNames[team]);
  }

  return Plugin_Handled;
}

public Action Command_ForceReadyClient(int client, int args) {
  MatchTeam team = GetClientMatchTeam(client);
  if (!IsReadyGameState() || team == MatchTeam_TeamNone || IsTeamReady(team)) {
    return Plugin_Handled;
  }

  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team);

  if (playerCount < minReady) {
    Get5_Message(client, "%t", "TeamFailToReadyMinPlayerCheck", minReady);
    return Plugin_Handled;
  }

  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team) {
      SetClientReady(i, true);
      Get5_Message(i, "%t", "TeammateForceReadied", client);
    }
  }
  SetTeamForcedReady(team, true);
  SetMatchTeamCvars();
  PrintReadyMessage(team);

  return Plugin_Handled;
}

// Messages

static void PrintReadyMessage(MatchTeam team) {
  CheckTeamNameStatus(team);

  if (g_GameState == GameState_PreVeto) {
    Get5_MessageToAll("%t", "TeamReadyToVetoInfoMessage", g_FormattedTeamNames[team]);
  } else if (g_GameState == GameState_Warmup) {
    SideChoice sides = view_as<SideChoice>(g_MapSides.Get(GetMapNumber()));
    if (g_WaitingForRoundBackup)
      Get5_MessageToAll("%t", "TeamReadyToRestoreBackupInfoMessage", g_FormattedTeamNames[team]);
    else if (sides == SideChoice_KnifeRound)
      Get5_MessageToAll("%t", "TeamReadyToKnifeInfoMessage", g_FormattedTeamNames[team]);
    else
      Get5_MessageToAll("%t", "TeamReadyToBeginInfoMessage", g_FormattedTeamNames[team]);
  }
}

public void MissingPlayerInfoMessage() {
  MissingPlayerInfoMessageTeam(MatchTeam_Team1);
  MissingPlayerInfoMessageTeam(MatchTeam_Team2);
  MissingPlayerInfoMessageTeam(MatchTeam_TeamSpec);
}

public void MissingPlayerInfoMessageTeam(MatchTeam team) {
  if (IsTeamForcedReady(team)) {
    return;
  }

  int minPlayers = GetPlayersPerTeam(team);
  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team);
  int readyCount = GetTeamReadyCount(team);

  if (playerCount == readyCount && playerCount < minPlayers && readyCount >= minReady) {
    Get5_MessageToTeam(team, "%t", "ForceReadyInfoMessage", minPlayers);
  }
}

// Helpers

public void UpdateClanTags() {
  char readyTag[32], notReadyTag[32];
  Format(readyTag, sizeof(readyTag), "%T", "ReadyTag", LANG_SERVER);
  Format(notReadyTag, sizeof(notReadyTag), "%T", "NotReadyTag", LANG_SERVER);

  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      if (GetClientTeam(i) == CS_TEAM_SPECTATOR) {
        if (GetTeamMinReady(MatchTeam_TeamSpec) > 0 && IsReadyGameState()) {
          CS_SetClientClanTag(i, IsClientReady(i) ? readyTag : notReadyTag);
        } else {
          CS_SetClientClanTag(i, "");
        }
      } else {
        if (IsReadyGameState()) {
          CS_SetClientClanTag(i, IsClientReady(i) ? readyTag : notReadyTag);
        } else {
          CS_SetClientClanTag(i, g_TeamTags[GetClientMatchTeam(i)]);
        }
      }
    }
  }
}
