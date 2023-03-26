// TODO: Add translations for this.
// TODO: Add admin top menu integration.
#define SETUP_MENU_CREATE_MATCH            "SETUP_MENU_CREATE_MATCH"
#define SETUP_MENU_FORCE_READY             "SETUP_MENU_FORCE_READY"
#define SETUP_MENU_END_MATCH               "SETUP_MENU_END_MATCH"
#define SETUP_MENU_CONFIRM_END_MATCH_DRAW  "SETUP_MENU_CONFIRM_END_MATCH_DRAW"
#define SETUP_MENU_CONFIRM_END_MATCH_TEAM1 "SETUP_MENU_CONFIRM_END_MATCH_TEAM1"
#define SETUP_MENU_CONFIRM_END_MATCH_TEAM2 "SETUP_MENU_CONFIRM_END_MATCH_TEAM2"
#define SETUP_MENU_LIST_BACKUPS            "SETUP_MENU_LIST_BACKUPS"
#define SETUP_MENU_RINGER                  "SETUP_MENU_RINGER"

#define SETUP_MENU_SELECTION_MATCH_TYPE       "SETUP_MENU_SELECTION_MATCH_TYPE"
#define SETUP_MENU_SELECTION_PLAYERS_PER_TEAM "SETUP_MENU_SELECTION_PLAYERS_PER_TEAM"
#define SETUP_MENU_FRIENDLY_FIRE              "SETUP_MENU_FRIENDLY_FIRE"
#define SETUP_MENU_OVERTIME                   "SETUP_MENU_OVERTIME"
#define SETUP_MENU_CLINCH                     "SETUP_MENU_CLINCH"
#define SETUP_MENU_SERIES_LENGTH              "SETUP_MENU_SERIES_LENGTH"
#define SETUP_MENU_MAP_SELECTION              "SETUP_MENU_MAP_SELECTION"
#define SETUP_MENU_MAP_POOL_SELECTION         "SETUP_MENU_MAP_POOL_SELECTION"
#define SETUP_MENU_SELECTED_MAPS              "SETUP_MENU_SELECTED_MAPS"
#define SETUP_MENU_SIDE_TYPE                  "SETUP_MENU_SIDE_TYPE"
#define SETUP_MENU_TEAM_SELECTION             "SETUP_MENU_TEAM_SELECTION"
#define SETUP_MENU_SELECT_TEAMS               "SETUP_MENU_SELECT_TEAMS"
#define SETUP_MENU_SWAP_TEAMS                 "SETUP_MENU_SWAP_TEAMS"
#define SETUP_MENU_CAPTAINS                   "SETUP_MENU_CAPTAINS"
#define SETUP_MENU_START_MATCH                "SETUP_MENU_START_MATCH"

#define SETUP_MENU_MAP_SELECTION_RESET "SETUP_MENU_MAP_SELECTION_RESET"

#define SETUP_MENU_CAPTAINS_TEAM1 "SETUP_MENU_CAPTAINS_TEAM1"
#define SETUP_MENU_CAPTAINS_TEAM2 "SETUP_MENU_CAPTAINS_TEAM2"
#define SETUP_MENU_CAPTAINS_AUTO  "SETUP_MENU_CAPTAINS_AUTO"

#define SETUP_MENU_TEAMS_TEAM1 "SETUP_MENU_TEAMS_TEAM1"
#define SETUP_MENU_TEAMS_TEAM2 "SETUP_MENU_TEAMS_TEAM2"
#define SETUP_MENU_TEAMS_RESET "SETUP_MENU_TEAMS_RESET"
#define SETUP_MENU_TEAMS_SWAP  "SETUP_MENU_TEAMS_SWAP"

static void FillMenuPageWithBlanks(const Menu menu) {
  while (menu.ItemCount % 6 != 0) {
    menu.AddItem("", "", ITEMDRAW_SPACER);
  }
}

static int GetIndexForPage(const int page) {
  return page * 6;
}

static int GetPageIndexForItem(const int selectedItem) {
  int page = selectedItem / 6;  // Items start at 0 and we floor to int; so 5/6 is 0, 6/6 is 1, 7/6 is still 1 etc.
  return 6 * page;              // Get the first item of the page.
}

static void ShowSetupMenu(int client, int displayAt = 0) {
  if (g_SetupMenuSelectedMaps == INVALID_HANDLE) {
    g_SetupMenuSelectedMaps = new ArrayList(PLATFORM_MAX_PATH);
  }
  if (g_SetupMenuMapPool == null) {
    ResetMapPool(client);
    HandleMapPoolAndSeriesLength();
  }

  Menu menu = new Menu(SetupMenuHandler);
  menu.SetTitle("Match Options");
  menu.ExitButton = false;
  menu.ExitBackButton = true;

  char buffer[64];
  FormatEx(buffer, sizeof(buffer), "Game Mode: %s", g_SetupMenuWingman ? "Wingman" : "Competitive");
  menu.AddItem(SETUP_MENU_SELECTION_MATCH_TYPE, buffer);
  FormatEx(buffer, sizeof(buffer), "Series Length: %d map(s)", g_SetupMenuSeriesLength);
  menu.AddItem(SETUP_MENU_SERIES_LENGTH, buffer);
  char mapSelectionMode[32];
  switch (g_SetupMenuMapSelection) {
    case Get5SetupMenu_MapSelectionMode_PickBan:
      FormatEx(mapSelectionMode, sizeof(mapSelectionMode), "Pick/Ban");
    case Get5SetupMenu_MapSelectionMode_Current:
      FormatEx(mapSelectionMode, sizeof(mapSelectionMode), "Current");
    case Get5SetupMenu_MapSelectionMode_Manual:
      FormatEx(mapSelectionMode, sizeof(mapSelectionMode), "Manual");
  }
  FormatEx(buffer, sizeof(buffer), "Map Selection: %s", mapSelectionMode);
  menu.AddItem(SETUP_MENU_MAP_SELECTION, buffer);

  if (g_SetupMenuMapSelection != Get5SetupMenu_MapSelectionMode_Current) {
    FormatEx(buffer, sizeof(buffer), "Map Pool: %s", g_SetupMenuSelectedMapPool);
    menu.AddItem(SETUP_MENU_MAP_POOL_SELECTION, buffer);
  }

  if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_Manual) {
    char mapsString[PLATFORM_MAX_PATH];
    if (g_SetupMenuSelectedMaps.Length > 0) {
      ImplodeMapArrayToString(g_SetupMenuSelectedMaps, mapsString, sizeof(mapsString));
      Format(mapsString, sizeof(mapsString), "Maps: %s", mapsString);
    } else {
      mapsString = "Select Maps";
    }
    menu.AddItem(SETUP_MENU_SELECTED_MAPS, mapsString);
  }

  FillMenuPageWithBlanks(menu);

  FormatEx(buffer, sizeof(buffer), "Team Size: %d", g_SetupMenuPlayersPerTeam);
  menu.AddItem(SETUP_MENU_SELECTION_PLAYERS_PER_TEAM, buffer);

  char teamSelectionMode[32];
  switch (g_SetupMenuTeamSelection) {
    case Get5SetupMenu_TeamSelectionMode_Current:
      FormatEx(teamSelectionMode, sizeof(teamSelectionMode), "Current");
    case Get5SetupMenu_TeamSelectionMode_Fixed:
      FormatEx(teamSelectionMode, sizeof(teamSelectionMode), "Fixed");
    case Get5SetupMenu_TeamSelectionMode_Scrim:
      FormatEx(teamSelectionMode, sizeof(teamSelectionMode), "Scrim");
  }
  FormatEx(buffer, sizeof(buffer), "Team Selection: %s", teamSelectionMode);
  menu.AddItem(SETUP_MENU_TEAM_SELECTION, buffer);

  switch (g_SetupMenuTeamSelection) {
    case Get5SetupMenu_TeamSelectionMode_Current:
      menu.AddItem(SETUP_MENU_CAPTAINS, "Set Captains");
    case Get5SetupMenu_TeamSelectionMode_Fixed: {
      char title[64];
      if (strlen(g_SetupMenuTeamForTeam1) == 0 && strlen(g_SetupMenuTeamForTeam2) == 0) {
        title = "Select Teams";
      } else {
        char teamName1[64] = "??";
        char teamName2[64] = "??";
        if (strlen(g_SetupMenuTeamForTeam1) > 0) {
          GetTeamNameFromJson(g_SetupMenuTeamForTeam1, teamName1, sizeof(teamName1), true);
        }
        if (strlen(g_SetupMenuTeamForTeam2) > 0) {
          GetTeamNameFromJson(g_SetupMenuTeamForTeam2, teamName2, sizeof(teamName2), true);
        }
        FormatEx(title, sizeof(title), "Teams: %s vs. %s", teamName1, teamName2);
      }
      menu.AddItem(SETUP_MENU_SELECT_TEAMS, title);
    }
    case Get5SetupMenu_TeamSelectionMode_Scrim: {
      char title[64];
      char teamName[64] = "??";
      if (strlen(g_SetupMenuTeamForTeam1) > 0) {
        GetTeamNameFromJson(g_SetupMenuTeamForTeam1, teamName, sizeof(teamName), true);
      }
      FormatEx(title, sizeof(title), "Home Team: %s", teamName);
      menu.AddItem(SETUP_MENU_SELECT_TEAMS, title);
    }
  }

  char sideTypeBuffer[32];
  switch (g_SetupMenuSideType) {
    case MatchSideType_Standard:
      FormatEx(sideTypeBuffer, sizeof(sideTypeBuffer), "Standard");
    case MatchSideType_AlwaysKnife:
      FormatEx(sideTypeBuffer, sizeof(sideTypeBuffer), "Always Knife");
    case MatchSideType_NeverKnife:
      FormatEx(sideTypeBuffer, sizeof(sideTypeBuffer), "Team 1 CT");
    case MatchSideType_Random:
      FormatEx(sideTypeBuffer, sizeof(sideTypeBuffer), "Random");
  }
  FormatEx(buffer, sizeof(buffer), "Side Type: %s", sideTypeBuffer);
  menu.AddItem(SETUP_MENU_SIDE_TYPE, buffer);

  if (g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Current &&
      g_SetupMenuSideType == MatchSideType_NeverKnife) {
    menu.AddItem(SETUP_MENU_SWAP_TEAMS, "Swap Sides");
  }

  FillMenuPageWithBlanks(menu);

  FormatEx(buffer, sizeof(buffer), "Friendly Fire: %s", g_SetupMenuFriendlyFire ? "On" : "Off");
  menu.AddItem(SETUP_MENU_FRIENDLY_FIRE, buffer);

  FormatEx(buffer, sizeof(buffer), "Overtime: %s", g_SetupMenuOvertime ? "On" : "Off");
  menu.AddItem(SETUP_MENU_OVERTIME, buffer);

  FormatEx(buffer, sizeof(buffer), "Play All Rounds: %s", g_SetupMenuClinch ? "No" : "Yes");
  menu.AddItem(SETUP_MENU_CLINCH, buffer);

  if (menu.ItemCount % 6 != 0) {
    menu.AddItem("", "", ITEMDRAW_SPACER);
  }

  menu.AddItem(SETUP_MENU_START_MATCH, "Start Match");

  menu.DisplayAt(client, displayAt, MENU_TIME_FOREVER);
  g_ActiveSetupMenu = menu;
}

static int SetupMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char infoString[64];
    menu.GetItem(param2, infoString, sizeof(infoString));
    if (StrEqual(infoString, SETUP_MENU_SELECTION_MATCH_TYPE, true)) {
      g_SetupMenuWingman = !g_SetupMenuWingman;
      // Retain default player counts when switching game mode.
      if (g_SetupMenuPlayersPerTeam == 5 && g_SetupMenuWingman) {
        g_SetupMenuPlayersPerTeam = 2;
      } else if (g_SetupMenuPlayersPerTeam == 2 && !g_SetupMenuWingman) {
        g_SetupMenuPlayersPerTeam = 5;
      }
    } else if (StrEqual(infoString, SETUP_MENU_SELECTION_PLAYERS_PER_TEAM, true)) {
      g_SetupMenuPlayersPerTeam = g_SetupMenuPlayersPerTeam + 1;
      if (g_SetupMenuPlayersPerTeam > 7) {  // 7v7 max.
        g_SetupMenuPlayersPerTeam = 1;
      }
    } else if (StrEqual(infoString, SETUP_MENU_FRIENDLY_FIRE, true)) {
      g_SetupMenuFriendlyFire = !g_SetupMenuFriendlyFire;
    } else if (StrEqual(infoString, SETUP_MENU_CLINCH, true)) {
      g_SetupMenuClinch = !g_SetupMenuClinch;
    } else if (StrEqual(infoString, SETUP_MENU_OVERTIME, true)) {
      g_SetupMenuOvertime = !g_SetupMenuOvertime;
    } else if (StrEqual(infoString, SETUP_MENU_TEAM_SELECTION, true)) {
      switch (g_SetupMenuTeamSelection) {
        case Get5SetupMenu_TeamSelectionMode_Current:
          g_SetupMenuTeamSelection = Get5SetupMenu_TeamSelectionMode_Fixed;
        case Get5SetupMenu_TeamSelectionMode_Fixed:
          g_SetupMenuTeamSelection = Get5SetupMenu_TeamSelectionMode_Scrim;
        case Get5SetupMenu_TeamSelectionMode_Scrim:
          g_SetupMenuTeamSelection = Get5SetupMenu_TeamSelectionMode_Current;
      }
    } else if (StrEqual(infoString, SETUP_MENU_SELECT_TEAMS, true)) {
      ShowSelectTeamsMenu(client);
      return 0;
    } else if (StrEqual(infoString, SETUP_MENU_SWAP_TEAMS, true)) {
      ServerCommand("mp_swapteams");
    } else if (StrEqual(infoString, SETUP_MENU_SIDE_TYPE, true)) {
      switch (g_SetupMenuSideType) {
        case MatchSideType_Standard:
          g_SetupMenuSideType = MatchSideType_AlwaysKnife;
        case MatchSideType_AlwaysKnife:
          g_SetupMenuSideType = MatchSideType_NeverKnife;
        case MatchSideType_NeverKnife:
          g_SetupMenuSideType = MatchSideType_Random;
        case MatchSideType_Random:
          // Cannot use "standard" if not banning/picking maps.
          g_SetupMenuSideType = g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_PickBan
                                  ? MatchSideType_Standard
                                  : MatchSideType_AlwaysKnife;
      }
    } else if (StrEqual(infoString, SETUP_MENU_SERIES_LENGTH, true)) {

      g_SetupMenuSelectedMaps.Clear();
      ResetMapPool(client);

      g_SetupMenuSeriesLength = g_SetupMenuSeriesLength + 1;
      if (g_SetupMenuSeriesLength > 5) {
        g_SetupMenuSeriesLength = 1;
      }

      HandleMapPoolAndSeriesLength();

    } else if (StrEqual(infoString, SETUP_MENU_MAP_POOL_SELECTION, true)) {
      ShowSelectMapPoolMenu(client);
      return 0;
    } else if (StrEqual(infoString, SETUP_MENU_MAP_SELECTION, true)) {

      // Reset the map pool when changing map selection; makes validation easier.
      g_SetupMenuSelectedMaps.Clear();
      ResetMapPool(client);

      // Cycle mode first.
      switch (g_SetupMenuMapSelection) {
        case Get5SetupMenu_MapSelectionMode_PickBan:
          g_SetupMenuMapSelection = Get5SetupMenu_MapSelectionMode_Current;
        case Get5SetupMenu_MapSelectionMode_Current:
          g_SetupMenuMapSelection = Get5SetupMenu_MapSelectionMode_Manual;
        case Get5SetupMenu_MapSelectionMode_Manual:
          g_SetupMenuMapSelection = Get5SetupMenu_MapSelectionMode_PickBan;
      }

      // In "current", we only allow series length 1.
      if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_Current) {
        g_SetupMenuSeriesLength = 1;
      }

      // In "manual", make sure series length is not longer than the map pool.
      JSON_Array maps = GetMapsFromSelectedPool();
      if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_Manual) {
        if (g_SetupMenuSeriesLength > maps.Length) {
          g_SetupMenuSeriesLength = maps.Length;
        }
      }

      // If we switch to pick/ban, make sure series length is one less than the map pool.
      // We can't do this if there are not enough maps.
      if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_PickBan) {
        if (g_SetupMenuSeriesLength >= maps.Length) {
          g_SetupMenuSeriesLength = maps.Length - 1;
          if (g_SetupMenuSeriesLength < 1) {
            g_SetupMenuSeriesLength = 1;
            g_SetupMenuMapSelection = Get5SetupMenu_MapSelectionMode_Manual;
          }
        }
      }

      // Side type "standard" only applies when picking/banning maps, otherwise this is the same as always knife.
      if (g_SetupMenuMapSelection != Get5SetupMenu_MapSelectionMode_PickBan &&
          g_SetupMenuSideType == MatchSideType_Standard) {
        g_SetupMenuSideType = MatchSideType_AlwaysKnife;
      }
    } else if (StrEqual(infoString, SETUP_MENU_SELECTED_MAPS, true)) {
      ShowSelectMapMenu(client);
      return 0;
    } else if (StrEqual(infoString, SETUP_MENU_CAPTAINS, true)) {
      ShowCaptainsMenu(client);
      return 0;
    } else if (StrEqual(infoString, SETUP_MENU_START_MATCH, true)) {
      if (g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Current &&
          (GetTeamPlayerCount(Get5Team_1) != g_SetupMenuPlayersPerTeam ||
           GetTeamPlayerCount(Get5Team_2) != g_SetupMenuPlayersPerTeam)) {
        Get5_Message(client, "Both teams must have %d player(s) when using current teams.", g_SetupMenuPlayersPerTeam);
      } else if (g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Fixed &&
                 (strlen(g_SetupMenuTeamForTeam1) == 0 || strlen(g_SetupMenuTeamForTeam2) == 0)) {
        Get5_Message(client, "You must select both teams when using fixed teams.");
      } else if (g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Scrim &&
                 strlen(g_SetupMenuTeamForTeam1) == 0) {
        Get5_Message(client, "You must select a home team in scrim mode.");
      } else if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_Manual &&
                 g_SetupMenuSelectedMaps.Length < g_SetupMenuSeriesLength) {
        Get5_Message(client,
                     "You must select all maps to play in manual map selection mode. You selected %d map(s) out of %d.",
                     g_SetupMenuSelectedMaps.Length, g_SetupMenuSeriesLength);
      } else {
        CreateMatch(client);
        return 0;
      }
    }
    ShowSetupMenu(client, GetPageIndexForItem(param2));
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    Command_Get5AdminMenu(client, 0);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    if (g_ActiveSetupMenu == menu) {
      g_ActiveSetupMenu = null;
    }
    LogDebug("Ended SetupMenuHandler");
    delete menu;
  }
  return 0;
}

static void ShowSelectTeamsMenu(int client, bool showTeamReloadMessage = false) {
  Menu menu = new Menu(SelectTeamsMenuHandler);
  menu.SetTitle("Select Teams");
  char error[PLATFORM_MAX_PATH];
  if (g_SetupMenuAvailableTeams == null) {
    if (!ResetTeams(error)) {
      Get5_Message(client, "Error loading team data: %s", error);
    } else if (showTeamReloadMessage) {
      Get5_Message(client, "Reloaded team data. Found %d team(s).", g_SetupMenuAvailableTeams.Length);
    }
  }
  PrintSelectedTeamName(Get5Team_1, menu);
  if (g_SetupMenuTeamSelection != Get5SetupMenu_TeamSelectionMode_Scrim) {
    PrintSelectedTeamName(Get5Team_2, menu);
  }

  menu.AddItem("", "", ITEMDRAW_SPACER);
  if (g_SetupMenuTeamSelection != Get5SetupMenu_TeamSelectionMode_Scrim) {
    menu.AddItem(SETUP_MENU_TEAMS_SWAP, "Swap",
                 EnabledIf(strlen(g_SetupMenuTeamForTeam1) > 0 || strlen(g_SetupMenuTeamForTeam2) > 0));
  }
  menu.AddItem(SETUP_MENU_TEAMS_RESET, "Reload Teams");
  menu.ExitButton = false;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
  g_ActiveSetupMenu = menu;
}

static void PrintSelectedTeamName(const Get5Team team, const Menu menu) {
  char key[64];
  strcopy(key, sizeof(key), team == Get5Team_1 ? g_SetupMenuTeamForTeam1 : g_SetupMenuTeamForTeam2);
  char teamNameString[64];
  int teamNumber = view_as<int>(team) + 1;
  char prefix[32];
  if (g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Fixed) {
    FormatEx(prefix, sizeof(prefix), "Team %d", teamNumber);
  } else {
    prefix = "Home Team";
  }
  if (strlen(key) == 0 || !g_SetupMenuAvailableTeams.HasKey(key)) {
    FormatEx(teamNameString, sizeof(teamNameString), "%s: n/a", prefix);
  } else {
    GetTeamNameFromJson(key, teamNameString, sizeof(teamNameString));
    Format(teamNameString, sizeof(teamNameString), "%s: %s", prefix, teamNameString);
  }
  menu.AddItem(team == Get5Team_1 ? SETUP_MENU_TEAMS_TEAM1 : SETUP_MENU_TEAMS_TEAM2, teamNameString);
}

static int SelectTeamsMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char selectedOption[PLATFORM_MAX_PATH];
    menu.GetItem(param2, selectedOption, sizeof(selectedOption));
    if (StrEqual(selectedOption, SETUP_MENU_TEAMS_TEAM1, true)) {
      ShowTeamSelectionMenu(Get5Team_1, client);
    } else if (StrEqual(selectedOption, SETUP_MENU_TEAMS_TEAM2, true)) {
      ShowTeamSelectionMenu(Get5Team_2, client);
    } else if (StrEqual(selectedOption, SETUP_MENU_TEAMS_SWAP, true)) {
      char team1[64];
      strcopy(team1, sizeof(team1), g_SetupMenuTeamForTeam1);
      strcopy(g_SetupMenuTeamForTeam1, sizeof(g_SetupMenuTeamForTeam1), g_SetupMenuTeamForTeam2);
      strcopy(g_SetupMenuTeamForTeam2, sizeof(g_SetupMenuTeamForTeam2), team1);
      ShowSelectTeamsMenu(client);
    } else if (StrEqual(selectedOption, SETUP_MENU_TEAMS_RESET, true)) {
      json_cleanup_and_delete(g_SetupMenuAvailableTeams);
      ShowSelectTeamsMenu(client, true);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    ShowSetupMenu(client, GetIndexForPage(1));
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    if (g_ActiveSetupMenu == menu) {
      g_ActiveSetupMenu = null;
    }
    LogDebug("Ended ShowSelectTeamsMenu");
    delete menu;
  }
  return 0;
}

static void ShowTeamSelectionMenu(const Get5Team team, int client) {
  Menu menu = new Menu(team == Get5Team_1 ? Team1SelectionMenuHandler : Team2SelectionMenuHandler);
  menu.SetTitle("Select Team %d", view_as<int>(team) + 1);

  if (g_SetupMenuAvailableTeams != null && g_SetupMenuAvailableTeams.Length > 0) {
    char teamNameString[64];
    int length = g_SetupMenuAvailableTeams.Length;
    int keyLength = 0;
    for (int i = 0; i < length; i++) {
      keyLength = g_SetupMenuAvailableTeams.GetKeySize(i);
      char[] key = new char[keyLength];
      g_SetupMenuAvailableTeams.GetKey(i, key, keyLength);
      GetTeamNameFromJson(key, teamNameString, sizeof(teamNameString));
      menu.AddItem(key, teamNameString,
                   EnabledIf(strcmp(team == Get5Team_1 ? g_SetupMenuTeamForTeam2 : g_SetupMenuTeamForTeam1, key) != 0));
    }
  } else {
    menu.AddItem("", "No teams found.", EnabledIf(false));
  }
  menu.ExitButton = false;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
  g_ActiveSetupMenu = menu;
}

static void GetTeamNameFromJson(const char[] teamKey, char[] name, const int nameLength, bool useTag = false) {
  // First If no name, use the index as team name.
  JSON_Object team = g_SetupMenuAvailableTeams.GetObject(teamKey);
  if (useTag && team.GetString("tag", name, nameLength) && strlen(name) > 0) {
    return;
  } else if (team.GetString("name", name, nameLength) && strlen(name) > 0) {
    return;
  }
  // Use key if no name was provided.
  strcopy(name, nameLength, teamKey);
}

static int Team1SelectionMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  return TeamSelectionMenuHandler(menu, Get5Team_1, action, client, param2);
}

static int Team2SelectionMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  return TeamSelectionMenuHandler(menu, Get5Team_2, action, client, param2);
}

static int TeamSelectionMenuHandler(Menu menu, Get5Team team, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char selectedTeam[PLATFORM_MAX_PATH];
    menu.GetItem(param2, selectedTeam, sizeof(selectedTeam));
    if (team == Get5Team_1) {
      strcopy(g_SetupMenuTeamForTeam1, sizeof(g_SetupMenuTeamForTeam1), selectedTeam);
    } else {
      strcopy(g_SetupMenuTeamForTeam2, sizeof(g_SetupMenuTeamForTeam2), selectedTeam);
    }
    ShowSelectTeamsMenu(client);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    ShowSelectTeamsMenu(client);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    if (g_ActiveSetupMenu == menu) {
      g_ActiveSetupMenu = null;
    }
    LogDebug("Ended ShowTeamSelectionMenu");
    delete menu;
  }
  return 0;
}

static void ShowSelectMapPoolMenu(int client) {
  Menu menu = new Menu(SelectMapPoolMenuHandler);
  menu.SetTitle("Select Map Pool");

  int length = g_SetupMenuMapPool.Length;
  int keyLength = 0;
  for (int i = 0; i < length; i++) {
    keyLength = g_SetupMenuMapPool.GetKeySize(i);
    char[] key = new char[keyLength];
    g_SetupMenuMapPool.GetKey(i, key, keyLength);
    menu.AddItem(key, key);
  }

  if (menu.ItemCount % 6 != 0) {
    menu.AddItem("", "", ITEMDRAW_SPACER);
  }

  menu.AddItem(SETUP_MENU_MAP_SELECTION_RESET, "Reset");
  menu.ExitButton = false;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
  g_ActiveSetupMenu = menu;
}

static int SelectMapPoolMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char selectedPool[64];
    menu.GetItem(param2, selectedPool, sizeof(selectedPool));
    g_SetupMenuSelectedMaps.Clear();
    if (!StrEqual(selectedPool, SETUP_MENU_MAP_SELECTION_RESET, true)) {
      strcopy(g_SetupMenuSelectedMapPool, sizeof(g_SetupMenuSelectedMapPool), selectedPool);
      ResetMapPool(client);
      HandleMapPoolAndSeriesLength();
      ShowSetupMenu(client, 0);
    } else {
      ResetMapPool(client);
      HandleMapPoolAndSeriesLength();
      ShowSelectMapPoolMenu(client);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    ShowSetupMenu(client, 0);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    if (g_ActiveSetupMenu == menu) {
      g_ActiveSetupMenu = null;
    }
    LogDebug("Ended ShowSelectMapPoolMenu");
    delete menu;
  }
  return 0;
}

static void ShowSelectMapMenu(int client) {
  if (g_SetupMenuSeriesLength == g_SetupMenuSelectedMaps.Length) {
    ResetMapPool(client);
    g_SetupMenuSelectedMaps.Clear();
  }
  Menu menu = new Menu(SelectMapMenuHandler);
  menu.SetTitle("Select Map %d", g_SetupMenuSelectedMaps.Length + 1);

  ArrayList sortedMaps = new ArrayList(PLATFORM_MAX_PATH);
  char mapName[PLATFORM_MAX_PATH];
  JSON_Array pool = GetMapsFromSelectedPool();  // Not copied: don't delete this!
  int l = pool.Length;
  for (int i = 0; i < l; i++) {
    pool.GetString(i, mapName, sizeof(mapName));
    sortedMaps.PushString(mapName);
  }

  // Sorts maps based on their formatted name.
  sortedMaps.SortCustom(SortMapsBasedOnFormattedName);

  char formattedMapName[PLATFORM_MAX_PATH];
  l = sortedMaps.Length;
  for (int i = 0; i < l; i++) {
    sortedMaps.GetString(i, mapName, sizeof(mapName));
    FormatMapName(mapName, formattedMapName, sizeof(formattedMapName), true);
    menu.AddItem(mapName, formattedMapName);
  }
  delete sortedMaps;

  if (menu.ItemCount % 6 != 0) {
    menu.AddItem("", "", ITEMDRAW_SPACER);
  }

  menu.AddItem(SETUP_MENU_MAP_SELECTION_RESET, "Reset");
  menu.ExitButton = false;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
  g_ActiveSetupMenu = menu;
}

static int SortMapsBasedOnFormattedName(int index1, int index2, ArrayList list, Handle opt) {
  // Because we need the maps sorted by their formatted name, but without changing their source name (which is used in
  // the menu as a key), we need to do a significant amount of "double work".
  char b1[PLATFORM_MAX_PATH], b2[PLATFORM_MAX_PATH], b1f[PLATFORM_MAX_PATH], b2f[PLATFORM_MAX_PATH];
  list.GetString(index1, b1, PLATFORM_MAX_PATH);
  list.GetString(index2, b2, PLATFORM_MAX_PATH);
  FormatMapName(b1, b1f, PLATFORM_MAX_PATH, true);
  FormatMapName(b2, b2f, PLATFORM_MAX_PATH, true);
  return strcmp(b1f, b2f);
}

static int SelectMapMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char selectedMap[PLATFORM_MAX_PATH];
    menu.GetItem(param2, selectedMap, sizeof(selectedMap));
    if (!StrEqual(selectedMap, SETUP_MENU_MAP_SELECTION_RESET, true)) {
      JSON_Array maps = GetMapsFromSelectedPool();
      int index = maps.IndexOfString(selectedMap);
      if (index >= 0) {
        maps.GetString(index, selectedMap, sizeof(selectedMap));
        LogDebug("Selected map: %s", selectedMap);
        g_SetupMenuSelectedMaps.PushString(selectedMap);
        maps.Remove(index);
      }
      if (g_SetupMenuSelectedMaps.Length < g_SetupMenuSeriesLength) {
        ShowSelectMapMenu(client);
      } else {
        ShowSetupMenu(client, 0);
      }
    } else {
      g_SetupMenuSelectedMaps.Clear();
      ResetMapPool(client);
      ShowSelectMapMenu(client);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    ShowSetupMenu(client, 0);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    if (g_ActiveSetupMenu == menu) {
      g_ActiveSetupMenu = null;
    }
    LogDebug("Ended ShowSelectMapMenu");
    delete menu;
  }
  return 0;
}

static void ShowCaptainsMenu(int client) {
  Menu menu = new Menu(CaptainsMenuHandler);
  menu.SetTitle("Team Captains");

  // Check that captains are still valid:
  if (g_SetupMenuTeam1Captain > 0) {
    if (!IsPlayer(g_SetupMenuTeam1Captain) ||
        view_as<Get5Side>(GetClientTeam(g_SetupMenuTeam1Captain)) != Get5Side_CT) {
      g_SetupMenuTeam1Captain = -1;
    }
  }
  if (g_SetupMenuTeam2Captain > 0) {
    if (!IsPlayer(g_SetupMenuTeam2Captain) || view_as<Get5Side>(GetClientTeam(g_SetupMenuTeam2Captain)) != Get5Side_T) {
      g_SetupMenuTeam2Captain = -1;
    }
  }

  char playerName[64];
  if (g_SetupMenuTeam1Captain > 0) {
    FormatEx(playerName, sizeof(playerName), "Team 1: %N", g_SetupMenuTeam1Captain);
    menu.AddItem(SETUP_MENU_CAPTAINS_TEAM1, playerName);
  } else {
    menu.AddItem(SETUP_MENU_CAPTAINS_TEAM1, "Team 1: Auto");
  }
  if (g_SetupMenuTeam2Captain > 0) {
    FormatEx(playerName, sizeof(playerName), "Team 2: %N", g_SetupMenuTeam2Captain);
    menu.AddItem(SETUP_MENU_CAPTAINS_TEAM2, playerName);
  } else {
    menu.AddItem(SETUP_MENU_CAPTAINS_TEAM2, "Team 2: Auto");
  }

  menu.ExitButton = false;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
  g_ActiveSetupMenu = menu;
}

static int CaptainsMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char selectedTeam[PLATFORM_MAX_PATH];
    menu.GetItem(param2, selectedTeam, sizeof(selectedTeam));
    if (StrEqual(selectedTeam, SETUP_MENU_CAPTAINS_TEAM1, true)) {
      ShowCaptainSelectionForTeamMenu(client, Get5Team_1);
    } else if (StrEqual(selectedTeam, SETUP_MENU_CAPTAINS_TEAM2, true)) {
      ShowCaptainSelectionForTeamMenu(client, Get5Team_2);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    ShowSetupMenu(client, GetIndexForPage(1));
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    if (g_ActiveSetupMenu == menu) {
      g_ActiveSetupMenu = null;
    }
    LogDebug("Ended ShowCaptainsMenu");
    delete menu;
  }
  return 0;
}

static void ShowCaptainSelectionForTeamMenu(int client, Get5Team team) {
  Menu menu = new Menu(team == Get5Team_1 ? CaptainSelectionForTeam1MenuHandler : CaptainSelectionForTeam2MenuHandler);
  menu.SetTitle("Team %d Captain", view_as<int>(team) + 1);

  char clientIndex[16];
  char playerName[64];
  Get5Side side;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      side = view_as<Get5Side>(GetClientTeam(i));
      if ((team == Get5Team_1 && side == Get5Side_CT) || (team == Get5Team_2 && side == Get5Side_T)) {
        IntToString(i, clientIndex, sizeof(clientIndex));
        FormatEx(playerName, sizeof(playerName), "%N", i);
        menu.AddItem(clientIndex, playerName);
      }
    }
  }

  if (menu.ItemCount % 6 != 0) {
    menu.AddItem("", "", ITEMDRAW_SPACER);
  }
  menu.AddItem(SETUP_MENU_CAPTAINS_AUTO, "Auto");

  menu.ExitButton = false;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
  g_ActiveSetupMenu = menu;
}

static int CaptainSelectionForTeamMenuHandler(Menu menu, MenuAction action, int client, int param2, Get5Team team) {
  if (action == MenuAction_Select) {
    char selection[PLATFORM_MAX_PATH];
    menu.GetItem(param2, selection, sizeof(selection));
    if (StrEqual(selection, SETUP_MENU_CAPTAINS_AUTO, false)) {
      if (team == Get5Team_1) {
        g_SetupMenuTeam1Captain = -1;
      } else {
        g_SetupMenuTeam2Captain = -1;
      }
      ShowCaptainsMenu(client);
      return 0;
    } else {
      int selectedPlayerClient = StringToInt(selection);
      if (IsPlayer(selectedPlayerClient)) {
        Get5Side side = view_as<Get5Side>(GetClientTeam(selectedPlayerClient));
        if (side == Get5Side_CT && team == Get5Team_1) {
          g_SetupMenuTeam1Captain = selectedPlayerClient;
          ShowCaptainsMenu(client);
          return 0;
        } else if (side == Get5Side_T && team == Get5Team_2) {
          g_SetupMenuTeam2Captain = selectedPlayerClient;
          ShowCaptainsMenu(client);
          return 0;
        }
      }
    }
    // If invalid or set to auto; show the captain menu again.
    ShowCaptainSelectionForTeamMenu(client, team);
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    ShowCaptainsMenu(client);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    if (g_ActiveSetupMenu == menu) {
      g_ActiveSetupMenu = null;
    }
    LogDebug("Ended ShowCaptainSelectionForTeamMenu");
    delete menu;
  }
  return 0;
}

static int CaptainSelectionForTeam1MenuHandler(Menu menu, MenuAction action, int client, int param2) {
  return CaptainSelectionForTeamMenuHandler(menu, action, client, param2, Get5Team_1);
}

static int CaptainSelectionForTeam2MenuHandler(Menu menu, MenuAction action, int client, int param2) {
  return CaptainSelectionForTeamMenuHandler(menu, action, client, param2, Get5Team_2);
}

static void HandleMapPoolAndSeriesLength() {
  // If we increase series length, switch "current" map selection to "pick/ban"
  if (g_SetupMenuSeriesLength > 1 && g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_Current) {
    g_SetupMenuMapSelection = Get5SetupMenu_MapSelectionMode_PickBan;
  }

  JSON_Array maps = GetMapsFromSelectedPool();
  // Make sure the map pool is large enough to support the series length
  if (maps.Length <= g_SetupMenuSeriesLength) {
    if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_PickBan) {
      // In pick/ban, the pool must be 1 larger than the series length.
      g_SetupMenuSeriesLength = maps.Length - 1;
      if (g_SetupMenuSeriesLength < 1) {
        g_SetupMenuSeriesLength = 1;
      }
      if (maps.Length < 2) {
        g_SetupMenuMapSelection = Get5SetupMenu_MapSelectionMode_Manual;
      }
    } else if (g_SetupMenuSeriesLength > maps.Length) {
      // In manual mode, the map pool must at least the series length. Set to 1 to allow cycling.
      g_SetupMenuSeriesLength = 1;
    }
  }
}

static void ResetMapPool(int client) {
  json_cleanup_and_delete(g_SetupMenuMapPool);
  char error[PLATFORM_MAX_PATH];
  g_SetupMenuMapPool = LoadMapsFile(error);
  if (g_SetupMenuMapPool == null) {
    CreateDefaultMapPool();
    if (IsValidClient(client)) {
      Get5_Message(client, "Failed to read maps file. Generating default map pool. Error: %s", error);
    }
  } else if (strlen(g_SetupMenuSelectedMapPool) == 0 || !g_SetupMenuMapPool.HasKey(g_SetupMenuSelectedMapPool)) {
    g_SetupMenuMapPool.GetKey(0, g_SetupMenuSelectedMapPool, sizeof(g_SetupMenuSelectedMapPool));
  }
}

static void CreateDefaultMapPool() {
  g_SetupMenuMapPool = new JSON_Object();
  g_SetupMenuSelectedMapPool = "default";
  JSON_Array defaultArray = new JSON_Array();
  defaultArray.PushString("de_ancient");
  defaultArray.PushString("de_anubis");
  defaultArray.PushString("de_inferno");
  defaultArray.PushString("de_mirage");
  defaultArray.PushString("de_nuke");
  defaultArray.PushString("de_overpass");
  defaultArray.PushString("de_vertigo");
  g_SetupMenuMapPool.SetObject(g_SetupMenuSelectedMapPool, defaultArray);
}

static JSON_Array GetMapsFromSelectedPool() {
  return view_as<JSON_Array>(g_SetupMenuMapPool.GetObject(g_SetupMenuSelectedMapPool));
}

static bool ResetTeams(char[] error) {
  g_SetupMenuTeamForTeam1 = "";
  g_SetupMenuTeamForTeam2 = "";
  json_cleanup_and_delete(g_SetupMenuAvailableTeams);
  g_SetupMenuAvailableTeams = LoadTeamsFile(error);
  return g_SetupMenuAvailableTeams != null;
}

static int EnabledIf(bool cond) {
  return cond ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
}

static void CreateMatch(int client) {
  if (g_GameState != Get5State_None) {
    Get5_Message(client, "A match is already loaded.");
    return;
  }

  char serverId[SERVER_ID_LENGTH];
  g_ServerIdCvar.GetString(serverId, sizeof(serverId));
  char path[PLATFORM_MAX_PATH];
  FormatEx(path, sizeof(path), TEMP_MATCHCONFIG_JSON, serverId);
  DeleteFileIfExists(path);

  JSON_Object match = new JSON_Object();
  match.SetString("matchid", "manual");
  match.SetInt("num_maps", g_SetupMenuSeriesLength);
  match.SetBool("skip_veto", g_SetupMenuMapSelection != Get5SetupMenu_MapSelectionMode_PickBan);
  match.SetInt("players_per_team", g_SetupMenuPlayersPerTeam);
  match.SetBool("clinch_series", true);
  match.SetBool("wingman", g_SetupMenuWingman);
  match.SetBool("scrim", g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Scrim);

  char sideType[32];
  MatchSideTypeToString(g_SetupMenuSideType, sideType, sizeof(sideType));
  match.SetString("side_type", sideType);

  JSON_Array mapList;
  char mapName[PLATFORM_MAX_PATH];
  if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_PickBan) {
    mapList = GetMapsFromSelectedPool().DeepCopy();
  } else {
    mapList = new JSON_Array();
    if (g_SetupMenuMapSelection == Get5SetupMenu_MapSelectionMode_Current) {
      GetCurrentMap(mapName, sizeof(mapName));
      mapList.PushString(mapName);
    } else {  // else manual
      int l = g_SetupMenuSelectedMaps.Length;
      for (int i = 0; i < l; i++) {
        g_SetupMenuSelectedMaps.GetString(i, mapName, sizeof(mapName));
        mapList.PushString(mapName);
      }
    }
  }
  match.SetObject("maplist", mapList);

  if (g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Current) {

    match.SetObject("team1", GetTeamObjectFromCurrentPlayers(Get5Team_1, g_SetupMenuTeam1Captain));
    match.SetObject("team2", GetTeamObjectFromCurrentPlayers(Get5Team_2, g_SetupMenuTeam2Captain));

  } else if (g_SetupMenuTeamSelection == Get5SetupMenu_TeamSelectionMode_Fixed) {

    // Important to copy the teams here as to not mess up the menu handles.
    match.SetObject("team1", g_SetupMenuAvailableTeams.GetObject(g_SetupMenuTeamForTeam1).DeepCopy());
    match.SetObject("team2", g_SetupMenuAvailableTeams.GetObject(g_SetupMenuTeamForTeam2).DeepCopy());

  } else {

    // Scrim by deduction
    match.SetObject("team1", g_SetupMenuAvailableTeams.GetObject(g_SetupMenuTeamForTeam1).DeepCopy());
  }

  JSON_Object spectators = GetTeamObjectFromCurrentPlayers(Get5Team_Spec);
  if (view_as<JSON_Array>(spectators.GetObject("players")).Length > 0) {
    match.SetObject("spectators", spectators);
  } else {
    // Don't need this if empty.
    json_cleanup_and_delete(spectators);
  }

  char error[PLATFORM_MAX_PATH];
  JSON_Object cvars = LoadCvarsFile(error, "default");
  if (cvars == null) {
    Get5_Message(client, "Error loading cvars: %s", error);
    json_cleanup_and_delete(match);
    return;
  }

  cvars.SetString("mp_friendlyfire", g_SetupMenuFriendlyFire ? "1" : "0");
  cvars.SetString("mp_match_can_clinch", g_SetupMenuClinch ? "1" : "0");
  cvars.SetString("mp_overtime_enable", g_SetupMenuOvertime ? "1" : "0");
  match.SetObject("cvars", cvars);

  if (!match.WriteToFile(path)) {
    Get5_Message(client, "Failed to write match config file to: \"%s\".", path);
  } else {
    if (!LoadMatchConfig(path, error)) {
      Get5_Message(client, "Failed to start match. Error: %s", error);
    } else {
      DeleteFileIfExists(path);
    }
  }
  json_cleanup_and_delete(match);
}

Action Command_Get5AdminMenu(int client, int args) {
  GiveAdminMenu(client);
  return Plugin_Handled;
}

static void GiveAdminMenu(int client) {
  Menu menu = new Menu(AdminMenuHandler);
  menu.SetTitle("Get5 Menu");

  menu.AddItem(SETUP_MENU_CREATE_MATCH, "Create Match", EnabledIf(g_GameState == Get5State_None));
  menu.AddItem(SETUP_MENU_FORCE_READY, "Force-ready all players",
               EnabledIf(g_GameState == Get5State_Warmup || g_GameState == Get5State_PreVeto ||
                         g_GameState == Get5State_PendingRestore));
  menu.AddItem(SETUP_MENU_END_MATCH, "End Match", EnabledIf(g_GameState != Get5State_None));
  menu.AddItem(SETUP_MENU_RINGER, "Add scrim ringer", EnabledIf(g_InScrimMode && g_GameState != Get5State_None));
  menu.AddItem(SETUP_MENU_LIST_BACKUPS, "Load Backup", EnabledIf(g_BackupSystemEnabledCvar.BoolValue));

  menu.Pagination = MENU_NO_PAGINATION;
  menu.ExitButton = true;

  menu.Display(client, MENU_TIME_FOREVER);
}

static int AdminMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char infoString[64];
    menu.GetItem(param2, infoString, sizeof(infoString));
    if (StrEqual(infoString, SETUP_MENU_CREATE_MATCH)) {
      if (g_ActiveSetupMenu != null) {
        Get5_Message(client, "Another player is currently setting up a match.");
      } else if (g_GameState != Get5State_None) {
        Get5_Message(client, "The match setup menu cannot be used while a match is loaded.");
      } else {
        if (!InWarmup()) {
          StartWarmup();  // So players can "coach ct/t" after joining their team.
        }
        ShowSetupMenu(client);
      }
    } else if (StrEqual(infoString, SETUP_MENU_FORCE_READY)) {
      FakeClientCommand(client, "get5_forceready");
    } else if (StrEqual(infoString, SETUP_MENU_END_MATCH)) {
      GiveConfirmEndMatchMenu(client);
    } else if (StrEqual(infoString, SETUP_MENU_LIST_BACKUPS)) {
      GiveBackupMenu(client);
    } else if (StrEqual(infoString, SETUP_MENU_RINGER)) {
      GiveRingerMenu(client);
    }
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    LogDebug("Ended GiveAdminMenu");
    delete menu;
  }
  return 0;
}

static void GiveConfirmEndMatchMenu(int client) {
  Menu menu = new Menu(ConfirmEndMatchMenuHandler);
  menu.SetTitle("Select Outcome");
  char teamName[64];
  strcopy(teamName, sizeof(teamName), g_TeamNames[Get5Team_1]);
  if (strlen(teamName) > 0) {
    Format(teamName, sizeof(teamName), "Team 1 (%s) wins", teamName);
  } else {
    FormatEx(teamName, sizeof(teamName), "Team 1 wins");
  }
  menu.AddItem(SETUP_MENU_CONFIRM_END_MATCH_TEAM1, teamName);

  strcopy(teamName, sizeof(teamName), g_TeamNames[Get5Team_2]);
  if (strlen(teamName) > 0) {
    Format(teamName, sizeof(teamName), "Team 2 (%s) wins", teamName);
  } else {
    FormatEx(teamName, sizeof(teamName), "Team 2 wins");
  }
  menu.AddItem(SETUP_MENU_CONFIRM_END_MATCH_TEAM2, teamName);

  menu.AddItem(SETUP_MENU_CONFIRM_END_MATCH_DRAW, "Draw");
  menu.ExitButton = false;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

static int ConfirmEndMatchMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char infoString[64];
    menu.GetItem(param2, infoString, sizeof(infoString));
    if (StrEqual(infoString, SETUP_MENU_CONFIRM_END_MATCH_DRAW)) {
      FakeClientCommand(client, "get5_endmatch");
    } else if (StrEqual(infoString, SETUP_MENU_CONFIRM_END_MATCH_TEAM1)) {
      FakeClientCommand(client, "get5_endmatch team1");
    } else if (StrEqual(infoString, SETUP_MENU_CONFIRM_END_MATCH_TEAM2)) {
      FakeClientCommand(client, "get5_endmatch team2");
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveAdminMenu(client);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    LogDebug("Ended GiveConfirmEndMatchMenu");
    delete menu;
  }
  return 0;
}

static void GiveBackupMenu(int client) {
  Menu menu = new Menu(ListBackupsMenuHandler);
  menu.SetTitle("Select Backup");

  char lastBackup[PLATFORM_MAX_PATH];
  g_LastGet5BackupCvar.GetString(lastBackup, sizeof(lastBackup));
  menu.AddItem(lastBackup, "Latest", EnabledIf(!StrEqual(lastBackup, "")));

  ArrayList backups = GetBackups(g_MatchID);
  if (backups == null || backups.Length == 0) {
    menu.AddItem("", "No backups found.", EnabledIf(false));
  } else {
    char backupInfo[64];
    char filename[PLATFORM_MAX_PATH];
    int length = backups.Length;
    for (int i = 0; i < length; i++) {
      backups.GetString(i, filename, sizeof(filename));
      if (GetRoundInfoFromBackupFile(filename, backupInfo, sizeof(backupInfo), g_GameState == Get5State_None)) {
        menu.AddItem(filename, backupInfo);
      }
    }
  }
  delete backups;
  menu.ExitBackButton = true;
  menu.Display(client, MENU_TIME_FOREVER);
}

static int ListBackupsMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char backupFileString[PLATFORM_MAX_PATH];
    char error[PLATFORM_MAX_PATH];
    menu.GetItem(param2, backupFileString, sizeof(backupFileString));
    if (!RestoreFromBackup(backupFileString, error)) {
      Get5_Message(client, "Failed to load backup: %s", error);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveAdminMenu(client);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    LogDebug("Ended GiveBackupMenu");
    delete menu;
  }
  return 0;
}

static void GiveRingerMenu(int client) {
  Menu menu = new Menu(RingerMenuHandler);
  menu.SetTitle("Select Player");
  menu.ExitButton = true;
  menu.ExitBackButton = true;

  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      char infoString[64];
      IntToString(GetClientUserId(i), infoString, sizeof(infoString));
      char displayString[64];
      FormatEx(displayString, sizeof(displayString), "%N", i);
      menu.AddItem(infoString, displayString);
    }
  }
  menu.Display(client, MENU_TIME_FOREVER);
}

static int RingerMenuHandler(Menu menu, MenuAction action, int client, int param2) {
  if (action == MenuAction_Select) {
    char infoString[64];
    menu.GetItem(param2, infoString, sizeof(infoString));
    int userId = StringToInt(infoString);
    int choiceClient = GetClientOfUserId(userId);
    if (IsPlayer(choiceClient)) {
      if (SwapScrimTeamStatus(choiceClient)) {
        Get5_Message(client, "Swapped %N.", choiceClient);
        GiveAdminMenu(client);
      } else {
        Get5_Message(client, "Failed to swap %N.", choiceClient);
        GiveRingerMenu(client);
      }
    } else {
      Get5_Message(client, "Invalid selection. Please try again.");
      GiveRingerMenu(client);
    }
  } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
    GiveAdminMenu(client);
  } else if (action == MenuAction_Cancel && (param2 == MenuCancel_Disconnected || param2 == MenuCancel_Interrupted)) {
    menu.Cancel();
  } else if (action == MenuAction_End) {
    LogDebug("Ended GiveRingerMenu");
    delete menu;
  }
  return 0;
}
