/**
 * Map vetoing functions
 */

#define CONFIRM_NEGATIVE_VALUE "_"
#define TEAM1_PICK             "team1_pick"
#define TEAM2_PICK             "team2_pick"
#define TEAM1_BAN              "team1_ban"
#define TEAM2_BAN              "team2_ban"

Get5VetoType VetoStringToVetoType(const char[] veto, char[] error) {
  if (strcmp(veto, TEAM1_PICK) == 0) {
    return Get5VetoTypeTeam1Pick;
  } else if (strcmp(veto, TEAM2_PICK) == 0) {
    return Get5VetoTypeTeam2Pick;
  } else if (strcmp(veto, TEAM1_BAN) == 0) {
    return Get5VetoTypeTeam1Ban;
  } else if (strcmp(veto, TEAM2_BAN) == 0) {
    return Get5VetoTypeTeam2Ban;
  }
  FormatEx(error, PLATFORM_MAX_PATH, "Veto order type '%s' is invalid. Must be one of: '%s', '%s', '%s', '%s'.", veto,
           TEAM1_PICK, TEAM2_PICK, TEAM1_BAN, TEAM2_BAN);
  return Get5VetoTypeInvalid;
}

void CreateVeto() {
  g_VetoCaptains[Get5Team_1] = GetTeamCaptain(Get5Team_1);
  g_VetoCaptains[Get5Team_2] = GetTeamCaptain(Get5Team_2);
  ResetReadyStatus();
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
    VetoController();
    return Plugin_Stop;
  }
  warningsPrinted++;
  int secondsRemaining = g_VetoCountdownCvar.IntValue - warningsPrinted + 1;
  char secondsFormatted[32];
  FormatEx(secondsFormatted, sizeof(secondsFormatted), "{GREEN}%d{NORMAL}", secondsRemaining);
  Get5_MessageToAll("%t", "VetoCountdown", secondsFormatted);
  return Plugin_Continue;
}

static void AbortVeto() {
  Get5_MessageToAll("%t", "CaptainLeftOnVetoInfoMessage");
  char readyCommandFormatted[64];
  GetChatAliasForCommand(Get5ChatCommand_Ready, readyCommandFormatted, sizeof(readyCommandFormatted), true);
  Get5_MessageToAll("%t", "ReadyToResumeVetoInfoMessage", readyCommandFormatted);
  ChangeState(Get5State_PreVeto);
  if (g_ActiveVetoMenu != null) {
    g_ActiveVetoMenu.Cancel();
  }
  if (IsPaused()) {
    UnpauseGame(Get5Team_None);
  }
}

static void VetoFinished() {
  ChangeState(Get5State_Warmup);
  Get5_MessageToAll("%t", "MapDecidedInfoMessage");
  g_MapsLeftInVetoPool.Clear();

  if (IsPaused()) {
    UnpauseGame(Get5Team_None);
  }

  // If a team has a map advantage, don't print that map.
  int mapNumber = Get5_GetMapNumber();
  for (int i = mapNumber; i < g_MapsToPlay.Length; i++) {
    char map[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(i, map, sizeof(map));
    FormatMapName(map, map, sizeof(map), true, true);
    Get5_MessageToAll("%t", "MapIsInfoMessage", i + 1 - mapNumber, map);
  }

  float delay = 10.0;
  g_MapChangePending = true;
  if (!g_SkipVeto && g_DisplayGotvVetoCvar.BoolValue) {
    // Players must wait for GOTV to end before we can change map, but we don't need to record that.
    g_PendingMapChangeTimer = CreateTimer(float(GetTvDelay()) + delay, Timer_NextMatchMap);
  } else {
    g_PendingMapChangeTimer = CreateTimer(delay, Timer_NextMatchMap);
  }
  // Always end recording here; ensures that we can successfully start one after veto.
  StopRecording(delay);
  WriteBackup();  // Write first pre-live backup after veto.
}

// Main Veto Controller

static void VetoController() {
  // As long as sides are not set for a map, either give side pick or auto-decide sides and recursively call this.
  if (g_MapSides.Length < g_MapsToPlay.Length) {
    if (g_MatchSideType == MatchSideType_Standard) {
      GiveSidePickMenu(g_VetoCaptains[OtherMatchTeam(g_LastVetoTeam)]);
    } else if (g_MatchSideType == MatchSideType_AlwaysKnife) {
      g_MapSides.Push(SideChoice_KnifeRound);
      VetoController();
    } else {
      g_MapSides.Push(SideChoice_Team1CT);
      VetoController();
    }
  } else if (g_NumberOfMapsInSeries < g_MapsToPlay.Length) {
    if (g_MapsLeftInVetoPool.Length == 1) {
      // Only 1 map left in the pool, add it be deduction and determine knife logic.
      char mapName[PLATFORM_MAX_PATH];
      g_MapsLeftInVetoPool.GetString(0, mapName, sizeof(mapName));
      PickMap(mapName, Get5Team_None);
      if (g_MatchSideType == MatchSideType_Standard || g_MatchSideType == MatchSideType_AlwaysKnife) {
        g_MapSides.Push(SideChoice_KnifeRound);
      } else {
        g_MapSides.Push(SideChoice_Team1CT);
      }
      VetoFinished();
    } else {
      // Number of banned maps must be: original pool - (current pool + picked);
      // 7 - (4 + 2) = 1; if 4 are left and 2 were picked, 1 must have been banned.
      int mapsBanned = g_MapPoolList.Length - (g_MapsLeftInVetoPool.Length + g_MapsToPlay.Length);
      // More than 1 map in the pool and not all maps are picked; present choices as determine by config.
      switch (g_MapBanOrder.Get(g_MapsToPlay.Length + mapsBanned)) {
        case Get5VetoTypeTeam1Ban:
          GiveMapVetoMenu(g_VetoCaptains[Get5Team_1]);
        case Get5VetoTypeTeam2Ban:
          GiveMapVetoMenu(g_VetoCaptains[Get5Team_2]);
        case Get5VetoTypeTeam1Pick:
          GiveMapPickMenu(g_VetoCaptains[Get5Team_1]);
        case Get5VetoTypeTeam2Pick:
          GiveMapPickMenu(g_VetoCaptains[Get5Team_2]);
      }
    }
  } else {
    VetoFinished();
  }
}

static void PickMap(const char[] mapName, const Get5Team team) {
  if (team != Get5Team_None) {
    char mapNameFormatted[PLATFORM_MAX_PATH];
    FormatMapName(mapName, mapNameFormatted, sizeof(mapNameFormatted), true, true);
    Get5_MessageToAll("%t", "TeamPickedMapInfoMessage", g_FormattedTeamNames[team], mapNameFormatted,
                      g_MapsToPlay.Length);
  }
  RemoveStringFromArray(g_MapsLeftInVetoPool, mapName);
  g_MapsToPlay.PushString(mapName);

  Get5MapPickedEvent event = new Get5MapPickedEvent(g_MatchID, team, mapName, g_MapsToPlay.Length - 1);
  LogDebug("Calling Get5_OnMapPicked()");
  Call_StartForward(g_OnMapPicked);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);
}

static void VetoMap(const char[] mapName, const Get5Team team) {
  RemoveStringFromArray(g_MapsLeftInVetoPool, mapName);
  char mapNameFormatted[PLATFORM_MAX_PATH];
  FormatMapName(mapName, mapNameFormatted, sizeof(mapNameFormatted), true, false);
  // Add color here as FormatMapName would make the color green.
  Format(mapNameFormatted, sizeof(mapNameFormatted), "{LIGHT_RED}%s{NORMAL}", mapNameFormatted);
  Get5_MessageToAll("%t", "TeamVetoedMapInfoMessage", g_FormattedTeamNames[team], mapNameFormatted);

  Get5MapVetoedEvent event = new Get5MapVetoedEvent(g_MatchID, team, mapName);
  LogDebug("Calling Get5_OnMapVetoed()");
  Call_StartForward(g_OnMapVetoed);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);
}

// Confirmations

static void GiveConfirmationMenu(int client, MenuHandler handler, const char[] title, const char[] confirmChoice) {
  // Figure out text for positive and negative values
  char positiveBuffer[1024], negativeBuffer[1024];
  FormatEx(positiveBuffer, sizeof(positiveBuffer), "%T", "ConfirmPositiveOptionText", client);
  FormatEx(negativeBuffer, sizeof(negativeBuffer), "%T", "ConfirmNegativeOptionText", client);

  // Create menu
  Menu menu = new Menu(handler);
  menu.SetTitle("%T", title, client, confirmChoice);
  menu.ExitButton = false;
  menu.Pagination = MENU_NO_PAGINATION;

  // Add rows of padding to move selection out of "danger zone"
  for (int i = 0; i < 7; i++) {
    menu.AddItem(CONFIRM_NEGATIVE_VALUE, "", ITEMDRAW_NOTEXT);
  }

  // Add actual choices
  menu.AddItem(confirmChoice, positiveBuffer);
  menu.AddItem(CONFIRM_NEGATIVE_VALUE, negativeBuffer);

  // Show menu and disable confirmations
  g_ActiveVetoMenu = menu;
  menu.Display(client, MENU_TIME_FOREVER);
  SetConfirmationTime(false);
}

static void SetConfirmationTime(bool enabled) {
  if (enabled) {
    g_VetoMenuTime = GetTickedTime();
  } else {
    // Set below 0 to signal that we don't want confirmation
    g_VetoMenuTime = -1.0;
  }
}

static bool ConfirmationNeeded() {
  // Don't give confirmations if it's been disabled
  if (g_VetoConfirmationTimeCvar.FloatValue <= 0.0) {
    return false;
  }
  // Don't give confirmation if the veto time is less than 0
  // (in case we're presenting a menu that doesn't need confirmation)
  if (g_VetoMenuTime < 0.0) {
    return false;
  }

  float diff = GetTickedTime() - g_VetoMenuTime;
  return diff <= g_VetoConfirmationTimeCvar.FloatValue;
}

static bool ConfirmationNegative(const char[] choice) {
  return StrEqual(choice, CONFIRM_NEGATIVE_VALUE);
}

// Map Vetos

static void GiveMapVetoMenu(int client) {
  if (!IsPlayer(client) || !IsPlayerTeam(GetClientMatchTeam(client))) {
    AbortVeto();
    return;
  }

  Menu menu = new Menu(MapVetoMenuHandler);
  menu.SetTitle("%T", "MapVetoBanMenuText", client);
  menu.ExitButton = false;
  // Don't paginate the menu if we have 7 maps or less, as they will fit
  // on one page when we don't add the pagination options
  if (g_MapsLeftInVetoPool.Length <= 7) {
    menu.Pagination = MENU_NO_PAGINATION;
  }

  char mapName[PLATFORM_MAX_PATH];
  for (int i = 0; i < g_MapsLeftInVetoPool.Length; i++) {
    g_MapsLeftInVetoPool.GetString(i, mapName, sizeof(mapName));
    menu.AddItem(mapName, mapName);
  }
  g_ActiveVetoMenu = menu;
  menu.Display(client, MENU_TIME_FOREVER);
  SetConfirmationTime(true);
}

static int MapVetoMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    if (g_GameState != Get5State_Veto) {
      return;
    }
    int client = param1;
    Get5Team team = GetClientMatchTeam(client);
    char mapName[PLATFORM_MAX_PATH];
    menu.GetItem(param2, mapName, sizeof(mapName));

    // Go back if we were called from a confirmation menu and client selected no
    if (ConfirmationNegative(mapName)) {
      GiveMapVetoMenu(client);
      return;
    }
    // Show a confirmation menu if needed
    if (ConfirmationNeeded()) {
      GiveConfirmationMenu(client, MapVetoMenuHandler, "MapVetoBanConfirmMenuText", mapName);
      return;
    }

    VetoMap(mapName, team);
    g_LastVetoTeam = team;
    VetoController();
  } else if (action == MenuAction_Cancel) {
    if (g_GameState == Get5State_Veto) {
      AbortVeto();
    }
  } else if (action == MenuAction_End) {
    if (menu == g_ActiveVetoMenu) {
      g_ActiveVetoMenu = null;
    }
    delete menu;
  }
}

// Map Picks

static void GiveMapPickMenu(int client) {
  if (!IsPlayer(client) || !IsPlayerTeam(GetClientMatchTeam(client))) {
    AbortVeto();
    return;
  }
  Menu menu = new Menu(MapPickMenuHandler);
  menu.SetTitle("%T", "MapVetoPickMenuText", client);
  menu.ExitButton = false;
  // Don't paginate the menu if we have 7 maps or less, as they will fit
  // on one page when we don't add the pagination options
  if (g_MapsLeftInVetoPool.Length <= 7) {
    menu.Pagination = MENU_NO_PAGINATION;
  }

  char mapName[PLATFORM_MAX_PATH];
  for (int i = 0; i < g_MapsLeftInVetoPool.Length; i++) {
    g_MapsLeftInVetoPool.GetString(i, mapName, sizeof(mapName));
    menu.AddItem(mapName, mapName);
  }
  g_ActiveVetoMenu = menu;
  menu.Display(client, MENU_TIME_FOREVER);
  SetConfirmationTime(true);
}

static int MapPickMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    if (g_GameState != Get5State_Veto) {
      return;
    }
    int client = param1;
    Get5Team team = GetClientMatchTeam(client);
    char mapName[PLATFORM_MAX_PATH];
    menu.GetItem(param2, mapName, sizeof(mapName));

    // Go back if we were called from a confirmation menu and client selected no
    if (ConfirmationNegative(mapName)) {
      GiveMapPickMenu(client);
      return;
    }
    // Show a confirmation menu if needed
    if (ConfirmationNeeded()) {
      GiveConfirmationMenu(client, MapPickMenuHandler, "MapVetoPickConfirmMenuText", mapName);
      return;
    }

    PickMap(mapName, team);
    g_LastVetoTeam = team;
    VetoController();
  } else if (action == MenuAction_Cancel) {
    if (g_GameState == Get5State_Veto) {
      AbortVeto();
    }
  } else if (action == MenuAction_End) {
    if (menu == g_ActiveVetoMenu) {
      g_ActiveVetoMenu = null;
    }
    delete menu;
  }
}

// Side Picks

static void GiveSidePickMenu(int client) {
  if (!IsPlayer(client) || !IsPlayerTeam(GetClientMatchTeam(client))) {
    AbortVeto();
    return;
  }
  Menu menu = new Menu(SidePickMenuHandler);
  menu.ExitButton = false;
  char mapName[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(g_MapsToPlay.Length - 1, mapName, sizeof(mapName));
  menu.SetTitle("%T", "MapVetoSidePickMenuText", client, mapName);
  menu.AddItem("CT", "CT");
  menu.AddItem("T", "T");
  g_ActiveVetoMenu = menu;
  menu.Display(client, MENU_TIME_FOREVER);
  SetConfirmationTime(true);
}

static int SidePickMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    if (g_GameState != Get5State_Veto) {
      return;
    }
    int client = param1;
    Get5Team team = GetClientMatchTeam(client);
    char choice[PLATFORM_MAX_PATH];
    menu.GetItem(param2, choice, sizeof(choice));

    // Go back if we were called from a confirmation menu and client selected no
    if (ConfirmationNegative(choice)) {
      GiveSidePickMenu(client);
      return;
    }
    // Show a confirmation menu if needed
    if (ConfirmationNeeded()) {
      GiveConfirmationMenu(client, SidePickMenuHandler, "MapVetoSidePickConfirmMenuText", choice);
      return;
    }

    Get5Side selectedSide;
    if (StrEqual(choice, "CT")) {
      selectedSide = Get5Side_CT;
      g_MapSides.Push(team == Get5Team_1 ? SideChoice_Team1CT : SideChoice_Team1T);
    } else {
      selectedSide = Get5Side_T;
      g_MapSides.Push(team == Get5Team_1 ? SideChoice_Team1T : SideChoice_Team1CT);
    }

    int mapNumber = g_MapsToPlay.Length - 1;

    char mapName[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(mapNumber, mapName, sizeof(mapName));

    Format(choice, sizeof(choice), "{GREEN}%s{NORMAL}", choice);
    Get5_MessageToAll("%t", "TeamSelectSideInfoMessage", g_FormattedTeamNames[team], choice, mapName);

    Get5SidePickedEvent event = new Get5SidePickedEvent(g_MatchID, mapNumber, mapName, team, selectedSide);

    LogDebug("Calling Get5_OnSidePicked()");
    Call_StartForward(g_OnSidePicked);
    Call_PushCell(event);
    Call_Finish();
    EventLogger_LogAndDeleteEvent(event);

    VetoController();

  } else if (action == MenuAction_Cancel) {
    if (g_GameState == Get5State_Veto) {
      AbortVeto();
    }
  } else if (action == MenuAction_End) {
    if (menu == g_ActiveVetoMenu) {
      g_ActiveVetoMenu = null;
    }
    delete menu;
  }
}
