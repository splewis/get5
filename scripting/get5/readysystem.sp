/**
 * Ready System
 */

public void ResetReadyStatus() {
  SetAllTeamsForcedReady(false);
  SetAllClientsReady(false);
}

public bool IsReadyGameState() {
  return (g_GameState == Get5State_PreVeto || g_GameState == Get5State_Warmup) && !g_MapChangePending;
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

public bool IsTeamForcedReady(Get5Team team) {
  return g_TeamReadyOverride[team] == true;
}

public void SetTeamForcedReady(Get5Team team, bool ready) {
  g_TeamReadyOverride[team] = ready;
}

public void SetAllTeamsForcedReady(bool ready) {
  LOOP_TEAMS(team) {
    SetTeamForcedReady(team, ready);
  }
}

// Team ready status

public bool IsTeamsReady() {
  return IsTeamReady(Get5Team_1) && IsTeamReady(Get5Team_2);
}

public bool IsSpectatorsReady() {
  return IsTeamReady(Get5Team_Spec);
}

public bool IsTeamReady(Get5Team team) {
  if (g_GameState == Get5State_Live) {
    return true;
  }

  if (team == Get5Team_None) {
    return true;
  }

  int minPlayers = GetPlayersPerTeam(team);
  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team);
  int readyCount = GetTeamReadyCount(team);

  if (team == Get5Team_Spec && minReady == 0) {
    return true;
  }

  if (playerCount == readyCount && playerCount >= minPlayers) {
    return true;
  }

  if (IsTeamForcedReady(team) && readyCount >= minReady) {
    return true;
  }

  return false;
}

public int GetTeamReadyCount(Get5Team team) {
  int readyCount = 0;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team && !IsClientCoaching(i) && IsClientReady(i)) {
      readyCount++;
    }
  }
  return readyCount;
}

public int GetTeamPlayerCount(Get5Team team) {
  int playerCount = 0;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team && !IsClientCoaching(i)) {
      playerCount++;
    }
  }
  return playerCount;
}

public int GetTeamMinReady(Get5Team team) {
  if (team == Get5Team_1 || team == Get5Team_2) {
    return g_MinPlayersToReady;
  } else if (team == Get5Team_Spec) {
    return g_MinSpectatorsToReady;
  } else {
    return 0;
  }
}

public int GetPlayersPerTeam(Get5Team team) {
  if (team == Get5Team_1 || team == Get5Team_2) {
    return g_PlayersPerTeam;
  } else if (team == Get5Team_Spec) {
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
// Re-used to automatically ready players on warmup-activity, hence the helper-method.
public void HandleReadyCommand(int client, bool autoReady) {
  if (!IsReadyGameState()) {
    return;
  }

  Get5Team team = GetClientMatchTeam(client);
  if (team == Get5Team_None || IsClientReady(client)) {
    return;
  }

  Get5_Message(client, "%t", "YouAreReady");

  if (autoReady) {
    // We cannot color text in hints, so no formatting the command.
    PrintHintText(client, "%t", "YouAreReadyAuto", "!unready");
  }

  SetClientReady(client, true);
  if (IsTeamReady(team)) {
    SetMatchTeamCvars();
    HandleReadyMessage(team);
  }
}

public Action Command_Ready(int client, int args) {
  HandleReadyCommand(client, false);
  return Plugin_Handled;
}

public Action Command_NotReady(int client, int args) {
  Get5Team team = GetClientMatchTeam(client);
  if (!IsReadyGameState() || team == Get5Team_None || !IsClientReady(client)) {
    return Plugin_Handled;
  }

  Get5_Message(client, "%t", "YouAreNotReady");

  bool teamWasReady = IsTeamReady(team);
  SetClientReady(client, false);
  SetTeamForcedReady(team, false);
  if (teamWasReady) {
    Get5TeamReadyStatusChangedEvent readyEvent =
        new Get5TeamReadyStatusChangedEvent(g_MatchID, team, false, Get5_GetGameState());

    LogDebug("Calling Get5_OnTeamReadyStatusChanged()");

    Call_StartForward(g_OnTeamReadyStatusChanged);
    Call_PushCell(readyEvent);
    Call_Finish();

    SetMatchTeamCvars();
    Get5_MessageToAll("%t", "TeamNotReadyInfoMessage", g_FormattedTeamNames[team]);
  }

  return Plugin_Handled;
}

public Action Command_ForceReadyClient(int client, int args) {
  Get5Team team = GetClientMatchTeam(client);
  if (!IsReadyGameState() || team == Get5Team_None || IsTeamReady(team)) {
    return Plugin_Handled;
  }

  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team);

  if (playerCount < minReady) {
    Get5_Message(client, "%t", "TeamFailToReadyMinPlayerCheck", minReady);
    return Plugin_Handled;
  }
  char formattedClientName[MAX_NAME_LENGTH];
  FormatPlayerName(formattedClientName, sizeof(formattedClientName), client);
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team) {
      SetClientReady(i, true);
      Get5_Message(i, "%t", "TeammateForceReadied", formattedClientName);
    }
  }
  SetTeamForcedReady(team, true);
  SetMatchTeamCvars();
  HandleReadyMessage(team);

  return Plugin_Handled;
}

// Messages

static void HandleReadyMessage(Get5Team team) {
  CheckTeamNameStatus(team);

  Get5TeamReadyStatusChangedEvent readyEvent =
      new Get5TeamReadyStatusChangedEvent(g_MatchID, team, true, Get5_GetGameState());

  LogDebug("Calling Get5_OnTeamReadyStatusChanged()");

  Call_StartForward(g_OnTeamReadyStatusChanged);
  Call_PushCell(readyEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(readyEvent);

  if (g_GameState == Get5State_PreVeto) {
    Get5_MessageToAll("%t", "TeamReadyToVetoInfoMessage", g_FormattedTeamNames[team]);
  } else if (g_GameState == Get5State_Warmup) {
    if (g_WaitingForRoundBackup) {
      Get5_MessageToAll("%t", "TeamReadyToRestoreBackupInfoMessage", g_FormattedTeamNames[team]);
    } else if (view_as<SideChoice>(g_MapSides.Get(g_MapNumber)) == SideChoice_KnifeRound) {
      Get5_MessageToAll("%t", "TeamReadyToKnifeInfoMessage", g_FormattedTeamNames[team]);
    } else {
      Get5_MessageToAll("%t", "TeamReadyToBeginInfoMessage", g_FormattedTeamNames[team]);
    }
  }
}

public void MissingPlayerInfoMessage() {
  MissingPlayerInfoMessageTeam(Get5Team_1);
  MissingPlayerInfoMessageTeam(Get5Team_2);
  MissingPlayerInfoMessageTeam(Get5Team_Spec);
}

public void MissingPlayerInfoMessageTeam(Get5Team team) {
  if (IsTeamForcedReady(team)) {
    return;
  }

  int minPlayers = GetPlayersPerTeam(team);
  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team);
  int readyCount = GetTeamReadyCount(team);

  if (playerCount == readyCount && playerCount < minPlayers && readyCount >= minReady && minPlayers > 1) {
    char minPlayersFormatted[32];
    Format(minPlayersFormatted, sizeof(minPlayersFormatted), "{GREEN}%d{NORMAL}", minPlayers);
    char forceReadyFormatted[64];
    FormatChatCommand(forceReadyFormatted, sizeof(forceReadyFormatted), "!forceready");
    Get5_MessageToTeam(team, "%t", "ForceReadyInfoMessage", forceReadyFormatted, minPlayersFormatted);
  }
}

// Helpers

public void UpdateClanTags() {
  if (!g_SetClientClanTagCvar.BoolValue) {
    LogDebug("Not setting client clan tags because get5_set_client_clan_tags is 0");
    return;
  }

  char readyTag[32], notReadyTag[32];
  Format(readyTag, sizeof(readyTag), "%T", "ReadyTag", LANG_SERVER);
  Format(notReadyTag, sizeof(notReadyTag), "%T", "NotReadyTag", LANG_SERVER);

  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      if (GetClientTeam(i) == CS_TEAM_SPECTATOR) {
        if (GetTeamMinReady(Get5Team_Spec) > 0 && IsReadyGameState()) {
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
