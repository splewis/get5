/**
 * Map vetoing functions
 */

#define TEAM1_PICK "team1_pick"
#define TEAM2_PICK "team2_pick"
#define TEAM1_BAN  "team1_ban"
#define TEAM2_BAN  "team2_ban"

Get5MapSelectionOption MapSelectionStringToMapSelection(const char[] option, char[] error) {
  if (strcmp(option, TEAM1_PICK) == 0) {
    return Get5MapSelectionOption_Team1Pick;
  } else if (strcmp(option, TEAM2_PICK) == 0) {
    return Get5MapSelectionOption_Team2Pick;
  } else if (strcmp(option, TEAM1_BAN) == 0) {
    return Get5MapSelectionOption_Team1Ban;
  } else if (strcmp(option, TEAM2_BAN) == 0) {
    return Get5MapSelectionOption_Team2Ban;
  }
  FormatEx(error, PLATFORM_MAX_PATH, "Map selection option '%s' is invalid. Must be one of: '%s', '%s', '%s', '%s'.",
           option, TEAM1_PICK, TEAM2_PICK, TEAM1_BAN, TEAM2_BAN);
  return Get5MapSelectionOption_Invalid;
}

void CreateVeto() {
  g_VetoCaptains[Get5Team_1] = GetTeamCaptain(Get5Team_1);
  g_VetoCaptains[Get5Team_2] = GetTeamCaptain(Get5Team_2);
  if (g_PauseOnVetoCvar.BoolValue) {
    PauseGame(Get5Team_None, Get5PauseType_Admin);
  }
  CreateTimer(1.0, Timer_VetoCountdown, _, TIMER_REPEAT);
}

static Action Timer_VetoCountdown(Handle timer) {
  static int warningsPrinted = 0;
  if (g_GameState != Get5State_Veto) {
    warningsPrinted = 0;
    return Plugin_Stop;
  }
  if (warningsPrinted >= g_VetoCountdownCvar.IntValue) {
    warningsPrinted = 0;
    if (!IsPlayer(g_VetoCaptains[Get5Team_1]) || !IsPlayer(g_VetoCaptains[Get5Team_2])) {
      AbortVeto();
      return Plugin_Stop;
    }
    Get5_MessageToAll("%t", "MapSelectionAnnounceCaptains", g_FormattedTeamNames[Get5Team_1],
                      g_VetoCaptains[Get5Team_1]);
    Get5_MessageToAll("%t", "MapSelectionAnnounceCaptains", g_FormattedTeamNames[Get5Team_2],
                      g_VetoCaptains[Get5Team_2]);
    HandleVetoStep();
    return Plugin_Stop;
  }
  warningsPrinted++;
  int secondsRemaining = g_VetoCountdownCvar.IntValue - warningsPrinted + 1;
  char secondsFormatted[32];
  FormatEx(secondsFormatted, sizeof(secondsFormatted), "{GREEN}%d{NORMAL}", secondsRemaining);
  Get5_MessageToAll("%t", "MapSelectionCountdown", secondsFormatted);
  return Plugin_Continue;
}

void AbortVeto() {
  Get5_MessageToAll("%t", "CaptainLeftDuringMapSelection");
  char readyCommandFormatted[64];
  GetChatAliasForCommand(Get5ChatCommand_Ready, readyCommandFormatted, sizeof(readyCommandFormatted), true);
  Get5_MessageToAll("%t", "ReadyToResumeMapSelection", readyCommandFormatted);
  ChangeState(Get5State_PreVeto);
  if (IsPaused()) {
    UnpauseGame();
  }
  g_VetoCaptains[Get5Team_1] = -1;
  g_VetoCaptains[Get5Team_2] = -1;
  SetMatchTeamCvars();  // Resets ready status.
}

static void FinishVeto() {
  Get5_MessageToAll("%t", "MapDecidedInfoMessage");
  g_MapsLeftInVetoPool.Clear();

  if (IsPaused()) {
    UnpauseGame();
  }

  // If a team has a map advantage, don't print that map.
  int mapNumber = Get5_GetMapNumber();
  bool formatMapNames = g_FormatMapNamesCvar.BoolValue;
  for (int i = mapNumber; i < g_MapsToPlay.Length; i++) {
    char map[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(i, map, sizeof(map));
    FormatMapName(map, map, sizeof(map), formatMapNames, true);
    Get5_MessageToAll("%t", "MapIsInfoMessage", i + 1 - mapNumber, map);
  }

  char currentMapName[PLATFORM_MAX_PATH];
  GetCurrentMap(currentMapName, sizeof(currentMapName));

  char mapToPlay[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(0, mapToPlay, sizeof(mapToPlay));

  // In case the sides don't match after selection, we check it here before writing the backup.
  // Also required if the map doesn't need to change.
  SetStartingTeams();
  SetMatchTeamCvars();

  if (IsMapReloadRequiredForGameMode(g_Wingman) || g_MapReloadRequired || !StrEqual(currentMapName, mapToPlay)) {
    ResetReadyStatus();
    SetCorrectGameMode();
    float delay = 7.0;
    g_MapChangePending = true;
    if (g_DisplayGotvVetoCvar.BoolValue) {
      delay = float(GetTvDelay()) + delay;
    }
    g_PendingMapChangeTimer = CreateTimer(delay, Timer_NextMatchMap);
  } else {
    LOOP_CLIENTS(i) {
      if (IsPlayer(i)) {
        CheckClientTeam(i);
      }
    }
  }
  ChangeState(Get5State_Warmup);
  WriteBackup();  // Write first pre-live backup after veto.
}

// Main Veto Controller

Action Command_Pick(int client, int args) {
  if (g_GameState != Get5State_Veto || !IsPlayer(client) || SidePickPending()) {
    return Plugin_Handled;
  }
  Get5Team playerTeam = GetClientMatchTeam(client);
  Get5Team currentTeamToPick;
  switch (GetCurrentMapSelectionOption()) {
    case Get5MapSelectionOption_Team1Pick:
      currentTeamToPick = Get5Team_1;
    case Get5MapSelectionOption_Team2Pick:
      currentTeamToPick = Get5Team_2;
    case Get5MapSelectionOption_Invalid, Get5MapSelectionOption_Team1Ban, Get5MapSelectionOption_Team2Ban:
      return Plugin_Handled;
  }

  if (client != g_VetoCaptains[currentTeamToPick]) {
    return Plugin_Handled;
  }

  char mapArg[PLATFORM_MAX_PATH];
  if (args < 1 || !GetCmdArg(1, mapArg, sizeof(mapArg))) {
    return Plugin_Handled;
  }

  if (!PickMap(mapArg, playerTeam)) {
    Get5_Message(client, "%t", "MapSelectionInvalidMap", mapArg);
  } else {
    HandleVetoStep();
  }
  return Plugin_Handled;
}

Action Command_Ban(int client, int args) {
  if (g_GameState != Get5State_Veto || !IsPlayer(client) || SidePickPending()) {
    return Plugin_Handled;
  }

  Get5Team currentTeamToBan;
  switch (GetCurrentMapSelectionOption()) {
    case Get5MapSelectionOption_Team1Ban:
      currentTeamToBan = Get5Team_1;
    case Get5MapSelectionOption_Team2Ban:
      currentTeamToBan = Get5Team_2;
    case Get5MapSelectionOption_Invalid, Get5MapSelectionOption_Team1Pick, Get5MapSelectionOption_Team2Pick:
      return Plugin_Handled;
  }

  if (client != g_VetoCaptains[currentTeamToBan]) {
    return Plugin_Handled;
  }

  char mapArg[PLATFORM_MAX_PATH];
  if (args < 1 || !GetCmdArg(1, mapArg, sizeof(mapArg))) {
    return Plugin_Handled;
  }

  if (!BanMap(mapArg, currentTeamToBan)) {
    Get5_Message(client, "%t", "MapSelectionInvalidMap", mapArg);
  } else {
    HandleVetoStep();
  }
  return Plugin_Handled;
}

void HandleSideChoice(const Get5Side side, int client) {
  if (!SidePickPending()) {
    // No side selection is done by players in this case.
    return;
  }
  Get5Team pickingTeam = OtherMatchTeam(g_LastVetoTeam);
  if (client != g_VetoCaptains[pickingTeam]) {
    // Only captain can select a side.
    return;
  }
  PickSide(side, pickingTeam);
  HandleVetoStep();
}

static void HandleAutomaticSideSelection() {
  if (g_MatchSideType == MatchSideType_Random) {
    g_MapSides.Push(GetRandomInt(0, 1) == 0 ? SideChoice_Team1CT : SideChoice_Team1T);
  } else {
    g_MapSides.Push(g_MatchSideType == MatchSideType_NeverKnife ? SideChoice_Team1CT : SideChoice_KnifeRound);
  }
}

static void HandleVetoStep() {
  // As long as sides are not set for a map, either give side pick or auto-decide sides and recursively call this.
  if (g_MapSides.Length < g_MapsToPlay.Length) {
    if (g_MatchSideType == MatchSideType_Standard) {
      PromptForSideSelectionInChat(OtherMatchTeam(g_LastVetoTeam));
    } else {
      HandleAutomaticSideSelection();
      HandleVetoStep();
    }
  } else if (g_NumberOfMapsInSeries > g_MapsToPlay.Length) {
    if (g_MapsLeftInVetoPool.Length == 1) {
      // Only 1 map left in the pool, add it by deduction and determine knife logic.
      char mapName[PLATFORM_MAX_PATH];
      g_MapsLeftInVetoPool.GetString(0, mapName, sizeof(mapName));
      PickMap(mapName, Get5Team_None);
      HandleAutomaticSideSelection();
      FinishVeto();
    } else {
      // More than 1 map in the pool and not all maps are picked; present choices as determine by config.
      PromptForMapSelectionInChat(GetCurrentMapSelectionOption());
    }
  } else {
    FinishVeto();
  }
  RestartInfoTimer();  // Prevents stacking chat messages if timed poorly.
}

void PrintVetoHelpMessage() {
  if (SidePickPending()) {
    PromptForSideSelectionInChat(OtherMatchTeam(g_LastVetoTeam));
  } else if (g_NumberOfMapsInSeries > g_MapsToPlay.Length) {
    PromptForMapSelectionInChat(GetCurrentMapSelectionOption());
  }
}
static Get5MapSelectionOption GetCurrentMapSelectionOption() {
  // Number of banned maps must be: original pool - (current pool + picked);
  // 7 - (4 + 2) = 1; if 4 are left and 2 were picked, 1 must have been banned.
  int mapsBanned = g_MapPoolList.Length - (g_MapsLeftInVetoPool.Length + g_MapsToPlay.Length);
  int index = g_MapsToPlay.Length + mapsBanned;
  if (index > g_MapBanOrder.Length - 1) {
    return Get5MapSelectionOption_Invalid;
  }
  return g_MapBanOrder.Get(index);
}

static bool SidePickPending() {
  return g_MapSides.Length < g_MapsToPlay.Length && g_MatchSideType == MatchSideType_Standard;
}

static void PromptForMapSelectionInChat(const Get5MapSelectionOption option) {
  char action[64];
  switch (option) {
    case Get5MapSelectionOption_Team1Ban, Get5MapSelectionOption_Team2Ban:
      FormatEx(action, sizeof(action), "{DARK_RED}%t{NORMAL}", "MapSelectionBan");
    case Get5MapSelectionOption_Team1Pick, Get5MapSelectionOption_Team2Pick:
      FormatEx(action, sizeof(action), "{GREEN}%t{NORMAL}", "MapSelectionPick");
  }
  switch (option) {
    case Get5MapSelectionOption_Team1Ban:
      Get5_MessageToAll("%t", "MapSelectionTurnToBan", g_FormattedTeamNames[Get5Team_1], action);
    case Get5MapSelectionOption_Team2Ban:
      Get5_MessageToAll("%t", "MapSelectionTurnToBan", g_FormattedTeamNames[Get5Team_2], action);
    case Get5MapSelectionOption_Team1Pick:
      Get5_MessageToAll("%t", "MapSelectionTurnToPick", g_FormattedTeamNames[Get5Team_1], action,
                        g_MapsToPlay.Length + 1);
    case Get5MapSelectionOption_Team2Pick:
      Get5_MessageToAll("%t", "MapSelectionTurnToPick", g_FormattedTeamNames[Get5Team_2], action,
                        g_MapsToPlay.Length + 1);
  }
  char mapListAsString[PLATFORM_MAX_PATH];
  ImplodeMapArrayToString(g_MapsLeftInVetoPool, mapListAsString, sizeof(mapListAsString), true);
  Get5_MessageToAll("%t %s.", "MapSelectionRemainingMaps", mapListAsString);

  int client;
  switch (option) {
    case Get5MapSelectionOption_Team1Ban, Get5MapSelectionOption_Team1Pick:
      client = g_VetoCaptains[Get5Team_1];
    case Get5MapSelectionOption_Team2Ban, Get5MapSelectionOption_Team2Pick:
      client = g_VetoCaptains[Get5Team_2];
  }
  if (!IsPlayer(client)) {
    return;
  }

  char formattedCommand[64];
  switch (option) {
    case Get5MapSelectionOption_Team1Ban, Get5MapSelectionOption_Team2Ban: {
      GetChatAliasForCommand(Get5ChatCommand_Ban, formattedCommand, sizeof(formattedCommand), true);
      Get5_Message(client, "%t", "MapSelectionBanMapHelp", formattedCommand);
    }
    case Get5MapSelectionOption_Team1Pick, Get5MapSelectionOption_Team2Pick: {
      GetChatAliasForCommand(Get5ChatCommand_Pick, formattedCommand, sizeof(formattedCommand), true);
      Get5_Message(client, "%t", "MapSelectionPickMapHelp", formattedCommand);
    }
  }
}

static void PromptForSideSelectionInChat(const Get5Team team) {
  char mapName[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(g_MapsToPlay.Length - 1, mapName, sizeof(mapName));
  char formattedMapName[PLATFORM_MAX_PATH];
  FormatMapName(mapName, formattedMapName, sizeof(formattedMapName), g_FormatMapNamesCvar.BoolValue, true);
  Get5_MessageToAll("%t", "MapSelectionPickSide", g_FormattedTeamNames[team], formattedMapName);

  int client = g_VetoCaptains[team];
  if (!IsPlayer(client)) {
    return;
  }
  char formattedCommandCT[64];
  char formattedCommandT[64];
  GetChatAliasForCommand(Get5ChatCommand_CT, formattedCommandCT, sizeof(formattedCommandCT), true);
  GetChatAliasForCommand(Get5ChatCommand_T, formattedCommandT, sizeof(formattedCommandT), true);
  Get5_Message(client, "%t", "MapSelectionPickSideHelp", formattedCommandCT, formattedCommandT);
}

void ImplodeMapArrayToString(const ArrayList mapPool, char[] buffer, const int bufferSize, bool sort) {
  char[][] mapsArray = new char[mapPool.Length][PLATFORM_MAX_PATH];
  bool formatMapNames = g_FormatMapNamesCvar.BoolValue;
  for (int i = 0; i < mapPool.Length; i++) {
    mapPool.GetString(i, mapsArray[i], PLATFORM_MAX_PATH);
    FormatMapName(mapsArray[i], mapsArray[i], PLATFORM_MAX_PATH, formatMapNames, false);
  }
  // Sort alphabetically.
  if (sort) {
    SortStrings(mapsArray, mapPool.Length, Sort_Ascending);
  }
  ImplodeStrings(mapsArray, mapPool.Length, ", ", buffer, bufferSize);
}

// Map Vetos

static bool BanMap(const char[] mapName, const Get5Team team) {
  char mapNameFromArray[PLATFORM_MAX_PATH];  // RemoveMapFromMapPool returns correct map name into this, mapName is user
                                             // input.
  if (!RemoveMapFromMapPool(g_MapsLeftInVetoPool, mapName, mapNameFromArray, sizeof(mapNameFromArray))) {
    return false;
  }
  char mapNameFormatted[PLATFORM_MAX_PATH];
  FormatMapName(mapNameFromArray, mapNameFormatted, sizeof(mapNameFormatted), g_FormatMapNamesCvar.BoolValue, false);
  // Add color here as FormatMapName would make the color green.
  Format(mapNameFormatted, sizeof(mapNameFormatted), "{LIGHT_RED}%s{NORMAL}", mapNameFormatted);
  Get5_MessageToAll("%t", "TeamBannedMap", g_FormattedTeamNames[team], mapNameFormatted);

  Get5MapVetoedEvent event = new Get5MapVetoedEvent(g_MatchID, team, mapNameFromArray);
  LogDebug("Calling Get5_OnMapVetoed()");
  Call_StartForward(g_OnMapVetoed);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);

  g_LastVetoTeam = team;

  return true;
}

// Map Picks

static bool PickMap(const char[] mapName, const Get5Team team) {
  char mapNameFromArray[PLATFORM_MAX_PATH];  // RemoveMapFromMapPool returns correct map name into this, mapName is user
                                             // input.
  if (!RemoveMapFromMapPool(g_MapsLeftInVetoPool, mapName, mapNameFromArray, sizeof(mapNameFromArray))) {
    return false;
  }
  if (team != Get5Team_None) {
    char mapNameFormatted[PLATFORM_MAX_PATH];
    FormatMapName(mapNameFromArray, mapNameFormatted, sizeof(mapNameFormatted), g_FormatMapNamesCvar.BoolValue, true);
    Get5_MessageToAll("%t", "TeamPickedMap", g_FormattedTeamNames[team], mapNameFormatted, g_MapsToPlay.Length + 1);
  }

  g_MapsToPlay.PushString(mapNameFromArray);

  Get5MapPickedEvent event = new Get5MapPickedEvent(g_MatchID, team, mapNameFromArray, g_MapsToPlay.Length - 1);
  LogDebug("Calling Get5_OnMapPicked()");
  Call_StartForward(g_OnMapPicked);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);

  g_LastVetoTeam = team;

  return true;
}

// Side Picks

static void PickSide(const Get5Side side, const Get5Team team) {
  if (side == Get5Side_CT) {
    g_MapSides.Push(team == Get5Team_1 ? SideChoice_Team1CT : SideChoice_Team1T);
  } else {
    g_MapSides.Push(team == Get5Team_1 ? SideChoice_Team1T : SideChoice_Team1CT);
  }

  int mapNumber = g_MapsToPlay.Length - 1;

  char mapName[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(mapNumber, mapName, sizeof(mapName));
  char mapNameFormatted[PLATFORM_MAX_PATH];
  FormatMapName(mapName, mapNameFormatted, sizeof(mapNameFormatted), g_FormatMapNamesCvar.BoolValue, true);

  char sideFormatted[32];
  FormatEx(sideFormatted, sizeof(sideFormatted), "{GREEN}%s{NORMAL}", side == Get5Side_CT ? "CT" : "T");

  Get5_MessageToAll("%t", "TeamSelectedSide", g_FormattedTeamNames[team], sideFormatted, mapNameFormatted);

  Get5SidePickedEvent event = new Get5SidePickedEvent(g_MatchID, mapNumber, mapName, team, side);
  LogDebug("Calling Get5_OnSidePicked()");
  Call_StartForward(g_OnSidePicked);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);
}

bool RemoveMapFromMapPool(const ArrayList mapPool, const char[] str, char[] buffer, const int bufferSize) {
  int eraseIndex = -1;
  // First check if we have a single match with a substring.
  if (strlen(str) >= 3) {
    for (int i = 0; i < mapPool.Length; i++) {
      mapPool.GetString(i, buffer, bufferSize);
      if (StrContains(buffer, str, false) > -1) {
        if (eraseIndex >= 0) {
          eraseIndex = -1;  // If more than one match, reset and break.
          break;
        }
        eraseIndex = i;
      }
    }
  }
  // If no match or more than one match on substring, restart, this time only matching the full string.
  if (eraseIndex == -1) {
    for (int i = 0; i < mapPool.Length; i++) {
      mapPool.GetString(i, buffer, bufferSize);
      if (StrEqual(buffer, str, false)) {
        eraseIndex = i;
        break;
      }
    }
  }
  if (eraseIndex >= 0) {
    // Copy the correct map into the buffer!
    mapPool.GetString(eraseIndex, buffer, bufferSize);
    mapPool.Erase(eraseIndex);
    return true;
  }
  if (StrContains(str, "cobble", false) > -1) {
    // Because Cobblestone is the only map that's actually misspelled, we re-run the code if the input contained
    // "cobble" but there was no match, this time using "cbble" instead, which will match de_cbble.
    return RemoveMapFromMapPool(mapPool, "cbble", buffer, bufferSize);
  }
  return false;
}
