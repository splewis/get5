/**
 * Ready System
 */

void ResetReadyStatus() {
  SetAllTeamsForcedReady(false);
  SetAllClientsReady(false);
}

bool IsReadyGameState() {
  return (g_GameState == Get5State_PreVeto || g_GameState == Get5State_Warmup ||
          g_GameState == Get5State_PendingRestore) &&
         !IsDoingRestoreOrMapChange();
}

// Client ready status

static bool IsClientReady(int client) {
  return g_ClientReady[client] == true;
}

void SetClientReady(int client, bool ready) {
  g_ClientReady[client] = ready;
}

static void SetAllClientsReady(bool ready) {
  LOOP_CLIENTS(i) {
    SetClientReady(i, ready);
  }
}

// Team ready override

static bool IsTeamForcedReady(Get5Team team) {
  return g_TeamReadyOverride[team] == true;
}

static void SetTeamForcedReady(Get5Team team, bool ready) {
  g_TeamReadyOverride[team] = ready;
}

static void SetAllTeamsForcedReady(bool ready) {
  LOOP_TEAMS(team) {
    SetTeamForcedReady(team, ready);
  }
}

// Team ready status

bool IsTeamsReady() {
  return IsTeamReady(Get5Team_1) && IsTeamReady(Get5Team_2);
}

bool IsSpectatorsReady() {
  return IsTeamReady(Get5Team_Spec);
}

bool IsTeamReady(Get5Team team) {
  if (g_GameState == Get5State_Live) {
    return true;
  }

  if (team == Get5Team_None) {
    return true;
  }

  int minPlayers = GetPlayersPerTeam(team);
  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team, g_CoachesMustReady);
  int readyCount = GetTeamReadyCount(team, g_CoachesMustReady);

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

static int GetTeamReadyCount(Get5Team team, bool includeCoaches = false) {
  int readyCount = 0;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team && (includeCoaches || !IsClientCoaching(i)) && IsClientReady(i)) {
      readyCount++;
    }
  }
  return readyCount;
}

static int GetTeamPlayerCount(Get5Team team, bool includeCoaches = false) {
  int playerCount = 0;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientMatchTeam(i) == team && (includeCoaches || !IsClientCoaching(i))) {
      playerCount++;
    }
  }
  return playerCount;
}

static int GetTeamMinReady(Get5Team team) {
  if (team == Get5Team_1 || team == Get5Team_2) {
    return g_MinPlayersToReady;
  } else if (team == Get5Team_Spec) {
    return g_MinSpectatorsToReady;
  } else {
    return 0;
  }
}

static int GetPlayersPerTeam(Get5Team team) {
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

Action Command_AdminForceReady(int client, int args) {
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
void HandleReadyCommand(int client, bool autoReady) {
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

Action Command_Ready(int client, int args) {
  HandleReadyCommand(client, false);
  return Plugin_Handled;
}

Action Command_NotReady(int client, int args) {
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

Action Command_ForceReadyClient(int client, int args) {
  Get5Team team = GetClientMatchTeam(client);
  if (!IsReadyGameState() || team == Get5Team_None || IsTeamReady(team)) {
    return Plugin_Handled;
  }

  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team, g_CoachesMustReady);

  if (playerCount < minReady) {
    Get5_Message(client, "%t", "TeamFailToReadyMinPlayerCheck", minReady);
    return Plugin_Handled;
  }
  char formattedClientName[MAX_NAME_LENGTH];
  FormatPlayerName(formattedClientName, sizeof(formattedClientName), client, team);
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
  } else if (g_GameState == Get5State_PendingRestore) {
    Get5_MessageToAll("%t", "TeamReadyToRestoreBackupInfoMessage", g_FormattedTeamNames[team]);
  } else if (g_GameState == Get5State_Warmup) {
    bool knifeRound = view_as<SideChoice>(g_MapSides.Get(g_MapNumber)) == SideChoice_KnifeRound;
    Get5_MessageToAll("%t",
                      knifeRound ? "TeamReadyToKnifeInfoMessage" : "TeamReadyToBeginInfoMessage",
                      g_FormattedTeamNames[team]);
  }
}

void MissingPlayerInfoMessage() {
  MissingPlayerInfoMessageTeam(Get5Team_1);
  MissingPlayerInfoMessageTeam(Get5Team_2);
  MissingPlayerInfoMessageTeam(Get5Team_Spec);
}

static void MissingPlayerInfoMessageTeam(Get5Team team) {
  if (IsTeamForcedReady(team)) {
    return;
  }

  int minPlayers = GetPlayersPerTeam(team);
  int minReady = GetTeamMinReady(team);
  int playerCount = GetTeamPlayerCount(team, g_CoachesMustReady);
  int readyCount = GetTeamReadyCount(team, g_CoachesMustReady);

  if (playerCount == readyCount && playerCount < minPlayers && readyCount >= minReady &&
      minPlayers > 1) {
    char minPlayersFormatted[32];
    FormatEx(minPlayersFormatted, sizeof(minPlayersFormatted), "{GREEN}%d{NORMAL}", minPlayers);
    char forceReadyFormatted[64];
    FormatChatCommand(forceReadyFormatted, sizeof(forceReadyFormatted), "!forceready");
    Get5_MessageToTeam(team, "%t", "ForceReadyInfoMessage", forceReadyFormatted,
                       minPlayersFormatted);
  }
}

// Helpers

void UpdateClanTags() {
  if (!g_SetClientClanTagCvar.BoolValue) {
    LogDebug("Not setting client clan tags because get5_set_client_clan_tags is 0");
    return;
  }

  char readyTag[32], notReadyTag[32];
  bool readyGameState = IsReadyGameState();
  if (readyGameState) {
    // These are only used in ready state, no need to format them otherwise.
    FormatEx(readyTag, sizeof(readyTag), "%T", "ReadyTag", LANG_SERVER);
    FormatEx(notReadyTag, sizeof(notReadyTag), "%T", "NotReadyTag", LANG_SERVER);
  }

  int team;
  LOOP_CLIENTS(i) {
    if (!IsPlayer(i)) {
      continue;
    }
    team = GetClientTeam(i);
    if (team == CS_TEAM_NONE) {
      continue;
    }
    if (readyGameState) {
      if (team == CS_TEAM_SPECTATOR && IsClientCoaching(i)) { // No need to check for coach if not on team spec!
        CS_SetClientClanTag(i, g_CoachesMustReady ? (IsClientReady(i) ? readyTag : notReadyTag) : "");
      } else if (team == CS_TEAM_SPECTATOR) { // spectator but not coaching
        CS_SetClientClanTag(i, GetTeamMinReady(Get5Team_Spec) > 0 ? (IsClientReady(i) ? readyTag : notReadyTag) : "");
      } else {
        CS_SetClientClanTag(i, IsClientReady(i) ? readyTag : notReadyTag);
      }
    } else if (team == CS_TEAM_SPECTATOR) { // covers coaches and spectators.
      CS_SetClientClanTag(i, "");
    } else {
      CS_SetClientClanTag(i, g_TeamTags[GetClientMatchTeam(i)]);
    }
  }
}
