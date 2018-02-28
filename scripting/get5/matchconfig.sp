#define REMOTE_CONFIG_PATTERN "remote_config%d.json"
#define CONFIG_MATCHID_DEFAULT "matchid"
#define CONFIG_MATCHTITLE_DEFAULT "Map {MAPNUMBER} of {MAXMAPS}"
#define CONFIG_PLAYERSPERTEAM_DEFAULT 5
#define CONFIG_MINPLAYERSTOREADY_DEFAULT 0
#define CONFIG_MINSPECTATORSTOREADY_DEFAULT 0
#define CONFIG_SPECTATORSNAME_DEFAULT "casters"
#define CONFIG_NUM_MAPSDEFAULT 3
#define CONFIG_SKIPVETO_DEFAULT false
#define CONFIG_VETOFIRST_DEFAULT "team1"
#define CONFIG_SIDETYPE_DEFAULT "standard"

stock bool LoadMatchConfig(const char[] config, bool restoreBackup = false) {
  if (g_GameState != GameState_None && !restoreBackup) {
    return false;
  }

  ResetReadyStatus();
  LOOP_TEAMS(team) {
    g_TeamSeriesScores[team] = 0;
    g_TeamReadyForUnpause[team] = false;
    g_TeamGivenStopCommand[team] = false;
    g_TeamPauseTimeUsed[team] = 0;
    g_TeamPausesUsed[team] = 0;
    g_ReadyTimeWaitingUsed[team] = 0;
    ClearArray(GetTeamAuths(team));
  }

  g_LastVetoTeam = MatchTeam_Team2;
  g_MapPoolList.Clear();
  g_MapsLeftInVetoPool.Clear();
  g_MapsToPlay.Clear();
  g_MapSides.Clear();
  g_CvarNames.Clear();
  g_CvarValues.Clear();
  g_TeamScoresPerMap.Clear();

  g_WaitingForRoundBackup = false;
  g_LastGet5BackupCvar.SetString("");

  CloseCvarStorage(g_KnifeChangedCvars);
  CloseCvarStorage(g_MatchConfigChangedCvars);

  if (!LoadMatchFile(config)) {
    return false;
  }

  if (g_CheckAuthsCvar.IntValue == 0 &&
      (GetTeamAuths(MatchTeam_Team1).Length != 0 || GetTeamAuths(MatchTeam_Team2).Length != 0)) {
    LogError(
        "Setting player auths in the \"players\" section has no impact with get5_check_auths 0");
  }

  // Copy all the maps into the veto pool.
  char mapName[PLATFORM_MAX_PATH];
  for (int i = 0; i < g_MapPoolList.Length; i++) {
    g_MapPoolList.GetString(i, mapName, sizeof(mapName));
    g_MapsLeftInVetoPool.PushString(mapName);
    g_TeamScoresPerMap.Push(0);
    g_TeamScoresPerMap.Set(g_TeamScoresPerMap.Length - 1, 0, 0);
    g_TeamScoresPerMap.Set(g_TeamScoresPerMap.Length - 1, 0, 1);
  }

  if (g_BO2Match) {
    g_MapsToWin = 2;
  }

  if (MaxMapsToPlay(g_MapsToWin) > g_MapPoolList.Length) {
    MatchConfigFail("Cannot play a series of %d maps with a maplist of %d maps",
                    MaxMapsToPlay(g_MapsToWin), g_MapPoolList.Length);
    return false;
  }

  if (g_SkipVeto) {
    // Copy the first k maps from the maplist to the final match maps.
    for (int i = 0; i < MaxMapsToPlay(g_MapsToWin); i++) {
      g_MapPoolList.GetString(i, mapName, sizeof(mapName));
      g_MapsToPlay.PushString(mapName);

      // Push a map side if one hasn't been set yet.
      if (g_MapSides.Length < g_MapsToPlay.Length) {
        if (g_MatchSideType == MatchSideType_Standard) {
          g_MapSides.Push(SideChoice_KnifeRound);
        } else if (g_MatchSideType == MatchSideType_AlwaysKnife) {
          g_MapSides.Push(SideChoice_KnifeRound);
        } else if (g_MatchSideType == MatchSideType_NeverKnife) {
          g_MapSides.Push(SideChoice_Team1CT);
        }
      }
    }

    g_MapPoolList.GetString(GetMapNumber(), mapName, sizeof(mapName));
    ChangeState(GameState_Warmup);

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    if (!StrEqual(mapName, currentMap) && !restoreBackup) {
      ChangeMap(mapName);
    }
  } else {
    ChangeState(GameState_PreVeto);
  }

  if (!restoreBackup) {
    SetStartingTeams();
    ExecCfg(g_WarmupCfgCvar);
    ExecuteMatchConfigCvars();
    LoadPlayerNames();
    EnsurePausedWarmup();

    EventLogger_SeriesStart();
    Stats_InitSeries();
    Call_StartForward(g_OnSeriesInit);
    Call_Finish();
  }

  for (int i = 1; i <= MaxClients; i++) {
    if (IsAuthedPlayer(i)) {
      if (GetClientMatchTeam(i) == MatchTeam_TeamNone) {
        KickClient(i, "%t", "YourAreNotAPlayerInfoMessage");
      } else {
        CheckClientTeam(i);
      }
    }
  }

  AddTeamLogosToDownloadTable();
  SetMatchTeamCvars();
  ExecuteMatchConfigCvars();
  LoadPlayerNames();
  strcopy(g_LoadedConfigFile, sizeof(g_LoadedConfigFile), config);

  return true;
}

public bool LoadMatchFile(const char[] config) {
  Call_StartForward(g_OnPreLoadMatchConfig);
  Call_PushString(config);
  Call_Finish();

  if (StrContains(config, "json") >= 0) {
    if (!LibraryExists("jansson")) {
      MatchConfigFail("Cannot load a json config without the smjansson extension loaded");
      return false;
    }

    char configFile[PLATFORM_MAX_PATH];
    strcopy(configFile, sizeof(configFile), config);
    if (!FileExists(configFile)) {
      MatchConfigFail("Match json file doesn't exist: \"%s\"", configFile);
      return false;
    }

    Handle json = json_load_file(configFile);
    if (json != INVALID_HANDLE && LoadMatchFromJson(json)) {
      CloseHandle(json);
      Get5_MessageToAll("%t", "MatchConfigLoadedInfoMessage");
    } else {
      MatchConfigFail("invalid match json");
      return false;
    }

  } else {
    // Assume its a keyvalues file.
    KeyValues kv = new KeyValues("Match");
    if (!FileExists(config)) {
      delete kv;
      MatchConfigFail("Match kv file doesn't exist: \"%s\"", config);
      return false;
    } else if (kv.ImportFromFile(config) && LoadMatchFromKv(kv)) {
      delete kv;
      Get5_MessageToAll("%t", "MatchConfigLoadedInfoMessage");
    } else {
      delete kv;
      MatchConfigFail("invalid match kv");
      return false;
    }
  }

  return true;
}

static void MatchConfigFail(const char[] reason, any...) {
  char buffer[512];
  VFormat(buffer, sizeof(buffer), reason, 2);
  LogError("Failed to load match config: %s", buffer);

  EventLogger_MatchConfigFail(buffer);

  Call_StartForward(g_OnLoadMatchConfigFailed);
  Call_PushString(buffer);
  Call_Finish();
}

stock bool LoadMatchFromUrl(const char[] url, ArrayList paramNames = null,
                            ArrayList paramValues = null) {
  bool steamWorksAvaliable = LibraryExists("SteamWorks");

  char cleanedUrl[1024];
  strcopy(cleanedUrl, sizeof(cleanedUrl), url);
  ReplaceString(cleanedUrl, sizeof(cleanedUrl), "\"", "");

  if (steamWorksAvaliable) {
    // Add the protocl strings. Only allow http since SteamWorks doesn't support http it seems?
    ReplaceString(cleanedUrl, sizeof(cleanedUrl), "https://", "http://");
    if (StrContains(cleanedUrl, "http://") == -1) {
      Format(cleanedUrl, sizeof(cleanedUrl), "http://%s", cleanedUrl);
    }
    LogDebug("cleanedUrl (SteamWorks) = %s", cleanedUrl);
    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, cleanedUrl);
    if (request == INVALID_HANDLE) {
      MatchConfigFail("Failed to create HTTP GET request");
      return false;
    }

    if (paramNames != null && paramValues != null) {
      if (paramNames.Length != paramValues.Length) {
        MatchConfigFail("request paramNames and paramValues size mismatch");
        return false;
      }

      char param[128];
      char value[128];
      for (int i = 0; i < paramNames.Length; i++) {
        paramNames.GetString(i, param, sizeof(param));
        paramValues.GetString(i, value, sizeof(value));
        SteamWorks_SetHTTPRequestGetOrPostParameter(request, param, value);
      }
    }

    SteamWorks_SetHTTPCallbacks(request, SteamWorks_OnMatchConfigReceived);
    SteamWorks_SendHTTPRequest(request);
    return true;

  } else {
    MatchConfigFail("SteamWorks extension is not available");
    return false;
  }
}

// SteamWorks HTTP callback for fetching a workshop collection
public int SteamWorks_OnMatchConfigReceived(Handle request, bool failure, bool requestSuccessful,
                                     EHTTPStatusCode statusCode, Handle data) {
  if (failure || !requestSuccessful) {
    MatchConfigFail("Steamworks GET request failed, HTTP status code = %d", statusCode);
    return;
  }

  char remoteConfig[PLATFORM_MAX_PATH];
  GetTempFilePath(remoteConfig, sizeof(remoteConfig), REMOTE_CONFIG_PATTERN);
  SteamWorks_WriteHTTPResponseBodyToFile(request, remoteConfig);
  LoadMatchConfig(remoteConfig);
}

public void WriteMatchToKv(KeyValues kv) {
  kv.SetString("matchid", g_MatchID);
  kv.SetNum("scrim", g_InScrimMode);
  kv.SetNum("maps_to_win", g_MapsToWin);
  kv.SetNum("bo2_series", g_BO2Match);
  kv.SetNum("skip_veto", g_SkipVeto);
  kv.SetNum("players_per_team", g_PlayersPerTeam);
  kv.SetNum("min_players_to_ready", g_MinPlayersToReady);
  kv.SetNum("min_spectators_to_ready", g_MinSpectatorsToReady);
  kv.SetString("match_title", g_MatchTitle);

  kv.SetNum("favored_percentage_team1", g_FavoredTeamPercentage);
  kv.SetString("favored_percentage_text", g_FavoredTeamText);

  char sideType[64];
  MatchSideTypeToString(g_MatchSideType, sideType, sizeof(sideType));
  kv.SetString("side_type", sideType);

  kv.JumpToKey("maplist", true);
  for (int i = 0; i < g_MapPoolList.Length; i++) {
    char map[PLATFORM_MAX_PATH];
    g_MapPoolList.GetString(i, map, sizeof(map));
    kv.SetString(map, KEYVALUE_STRING_PLACEHOLDER);
  }
  kv.GoBack();

  kv.JumpToKey("team1", true);
  AddTeamBackupData(kv, MatchTeam_Team1);
  kv.GoBack();

  kv.JumpToKey("team2", true);
  AddTeamBackupData(kv, MatchTeam_Team2);
  kv.GoBack();

  kv.JumpToKey("spectators", true);
  AddTeamBackupData(kv, MatchTeam_TeamSpec);
  kv.GoBack();

  kv.JumpToKey("cvars", true);
  for (int i = 0; i < g_CvarNames.Length; i++) {
    char cvarName[MAX_CVAR_LENGTH];
    char cvarValue[MAX_CVAR_LENGTH];
    g_CvarNames.GetString(i, cvarName, sizeof(cvarName));
    g_CvarValues.GetString(i, cvarValue, sizeof(cvarValue));
    kv.SetString(cvarName, cvarValue);
  }
  kv.GoBack();
}

static void AddTeamBackupData(KeyValues kv, MatchTeam team) {
  kv.JumpToKey("players", true);
  char auth[AUTH_LENGTH];
  char name[MAX_NAME_LENGTH];
  for (int i = 0; i < GetTeamAuths(team).Length; i++) {
    GetTeamAuths(team).GetString(i, auth, sizeof(auth));
    if (!g_PlayerNames.GetString(auth, name, sizeof(name))) {
      strcopy(name, sizeof(name), KEYVALUE_STRING_PLACEHOLDER);
    }
    kv.SetString(auth, name);
  }
  kv.GoBack();

  kv.SetString("name", g_TeamNames[team]);
  if (team != MatchTeam_TeamSpec) {
    kv.SetString("tag", g_TeamTags[team]);
    kv.SetString("flag", g_TeamFlags[team]);
    kv.SetString("logo", g_TeamLogos[team]);
    kv.SetString("matchtext", g_TeamMatchTexts[team]);
  }
}

static bool LoadMatchFromKv(KeyValues kv) {
  kv.GetString("matchid", g_MatchID, sizeof(g_MatchID), CONFIG_MATCHID_DEFAULT);
  g_InScrimMode = kv.GetNum("scrim") != 0;
  kv.GetString("match_title", g_MatchTitle, sizeof(g_MatchTitle), CONFIG_MATCHTITLE_DEFAULT);
  g_PlayersPerTeam = kv.GetNum("players_per_team", CONFIG_PLAYERSPERTEAM_DEFAULT);
  g_MinPlayersToReady = kv.GetNum("min_players_to_ready", CONFIG_MINPLAYERSTOREADY_DEFAULT);
  g_MinSpectatorsToReady =
      kv.GetNum("min_spectators_to_ready", CONFIG_MINSPECTATORSTOREADY_DEFAULT);
  g_SkipVeto = kv.GetNum("skip_veto", CONFIG_SKIPVETO_DEFAULT) != 0;

  // bo2_series and maps_to_win are deprecated. They are used if provided, but otherwise
  // num_maps' default is the fallback.
  bool bo2 = (kv.GetNum("bo2_series", false) != 0);
  int mapsToWin = kv.GetNum("maps_to_win", 0);
  int numMaps = kv.GetNum("num_maps", CONFIG_NUM_MAPSDEFAULT);
  if (bo2 || numMaps == 2) {
    g_BO2Match = true;
    g_MapsToWin = 2;
  } else {
    if (mapsToWin >= 1) {
      g_MapsToWin = mapsToWin;
    } else {
      // Normal path. No even numbers allowed since we already handled bo2.
      if (numMaps % 2 == 0) {
        MatchConfigFail("Cannot create a series of %d maps. Use a odd number or 2.", numMaps);
        return false;
      }
      g_MapsToWin = (numMaps + 1) / 2;
    }
  }

  char vetoFirstBuffer[64];
  kv.GetString("veto_first", vetoFirstBuffer, sizeof(vetoFirstBuffer), CONFIG_VETOFIRST_DEFAULT);
  g_LastVetoTeam = OtherMatchTeam(VetoFirstFromString(vetoFirstBuffer));

  char sideTypeBuffer[64];
  kv.GetString("side_type", sideTypeBuffer, sizeof(sideTypeBuffer), CONFIG_SIDETYPE_DEFAULT);
  g_MatchSideType = MatchSideTypeFromString(sideTypeBuffer);

  g_FavoredTeamPercentage = kv.GetNum("favored_percentage_team1", 0);
  kv.GetString("favored_percentage_text", g_FavoredTeamText, sizeof(g_FavoredTeamText));

  GetTeamAuths(MatchTeam_TeamSpec).Clear();
  if (kv.JumpToKey("spectators")) {
    AddSubsectionAuthsToList(kv, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
    kv.GetString("name", g_TeamNames[MatchTeam_TeamSpec], MAX_CVAR_LENGTH,
                 CONFIG_SPECTATORSNAME_DEFAULT);
    kv.GoBack();

    Format(g_FormattedTeamNames[MatchTeam_TeamSpec], MAX_CVAR_LENGTH, "%s%s{NORMAL}",
           g_DefaultTeamColors[MatchTeam_TeamSpec], g_TeamNames[MatchTeam_TeamSpec]);
  }

  if (kv.JumpToKey("team1")) {
    LoadTeamData(kv, MatchTeam_Team1);
    kv.GoBack();
  } else {
    MatchConfigFail("Missing \"team1\" section in match kv");
    return false;
  }

  if (kv.JumpToKey("team2")) {
    LoadTeamData(kv, MatchTeam_Team2);
    kv.GoBack();
  } else {
    MatchConfigFail("Missing \"team2\" section in match kv");
    return false;
  }

  if (AddSubsectionKeysToList(kv, "maplist", g_MapPoolList, PLATFORM_MAX_PATH) <= 0) {
    LogMessage("Failed to find \"maplist\" section in config, using fallback maplist.");
    LoadDefaultMapList(g_MapPoolList);
  }

  if (g_SkipVeto) {
    if (kv.JumpToKey("map_sides")) {
      if (kv.GotoFirstSubKey(false)) {
        do {
          char buffer[64];
          kv.GetSectionName(buffer, sizeof(buffer));
          g_MapSides.Push(SideTypeFromString(buffer));
        } while (kv.GotoNextKey(false));
        kv.GoBack();
      }
      kv.GoBack();
    }
  }

  if (kv.JumpToKey("cvars")) {
    if (kv.GotoFirstSubKey(false)) {
      char name[MAX_CVAR_LENGTH];
      char value[MAX_CVAR_LENGTH];
      do {
        kv.GetSectionName(name, sizeof(name));
        kv.GetString(NULL_STRING, value, sizeof(value));
        g_CvarNames.PushString(name);
        g_CvarValues.PushString(value);
      } while (kv.GotoNextKey(false));
      kv.GoBack();
    }
    kv.GoBack();
  }

  return true;
}

static bool LoadMatchFromJson(Handle json) {
  json_object_get_string_safe(json, "matchid", g_MatchID, sizeof(g_MatchID),
                              CONFIG_MATCHID_DEFAULT);
  g_InScrimMode = json_object_get_bool_safe(json, "scrim", false);
  json_object_get_string_safe(json, "match_title", g_MatchTitle, sizeof(g_MatchTitle),
                              CONFIG_MATCHTITLE_DEFAULT);

  g_PlayersPerTeam =
      json_object_get_int_safe(json, "players_per_team", CONFIG_PLAYERSPERTEAM_DEFAULT);
  g_MinPlayersToReady =
      json_object_get_int_safe(json, "min_players_to_ready", CONFIG_MINPLAYERSTOREADY_DEFAULT);
  g_MinSpectatorsToReady = json_object_get_int_safe(json, "min_spectators_to_ready",
                                                    CONFIG_MINSPECTATORSTOREADY_DEFAULT);
  g_SkipVeto = json_object_get_bool_safe(json, "skip_veto", CONFIG_SKIPVETO_DEFAULT);

  // bo2_series and maps_to_win are deprecated. They are used if provided, but otherwise
  // num_maps' default is the fallback.
  bool bo2 = json_object_get_bool_safe(json, "bo2_series", false);
  int mapsToWin = json_object_get_int_safe(json, "maps_to_win", 0);
  int numMaps = json_object_get_int_safe(json, "num_maps", CONFIG_NUM_MAPSDEFAULT);

  if (bo2 || numMaps == 2) {
    g_BO2Match = true;
    g_MapsToWin = 2;
  } else {
    if (mapsToWin >= 1) {
      g_MapsToWin = mapsToWin;
    } else {
      // Normal path. No even numbers allowed since we already handled bo2.
      if (numMaps % 2 == 0) {
        MatchConfigFail("Cannot create a series of %d maps. Use a odd number or 2.", numMaps);
        return false;
      }
      g_MapsToWin = (numMaps + 1) / 2;
    }
  }

  char vetoFirstBuffer[64];
  json_object_get_string_safe(json, "veto_first", vetoFirstBuffer, sizeof(vetoFirstBuffer),
                              CONFIG_VETOFIRST_DEFAULT);
  g_LastVetoTeam = OtherMatchTeam(VetoFirstFromString(vetoFirstBuffer));

  char sideTypeBuffer[64];
  json_object_get_string_safe(json, "side_type", sideTypeBuffer, sizeof(sideTypeBuffer),
                              CONFIG_SIDETYPE_DEFAULT);
  g_MatchSideType = MatchSideTypeFromString(sideTypeBuffer);

  json_object_get_string_safe(json, "favored_percentage_text", g_FavoredTeamText,
                              sizeof(g_FavoredTeamText));
  g_FavoredTeamPercentage = json_object_get_int_safe(json, "favored_percentage_team1", 0);

  Handle spec = json_object_get(json, "spectators");
  if (spec != INVALID_HANDLE) {
    json_object_get_string_safe(spec, "name", g_TeamNames[MatchTeam_TeamSpec], MAX_CVAR_LENGTH,
                                CONFIG_SPECTATORSNAME_DEFAULT);
    AddJsonAuthsToList(spec, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
    CloseHandle(spec);

    Format(g_FormattedTeamNames[MatchTeam_TeamSpec], MAX_CVAR_LENGTH, "%s%s{NORMAL}",
           g_DefaultTeamColors[MatchTeam_TeamSpec], g_TeamNames[MatchTeam_TeamSpec]);
  }

  Handle team1 = json_object_get(json, "team1");
  if (team1 != INVALID_HANDLE) {
    LoadTeamDataJson(team1, MatchTeam_Team1);
    CloseHandle(team1);
  } else {
    MatchConfigFail("Missing \"team1\" section in match json");
    return false;
  }

  Handle team2 = json_object_get(json, "team2");
  if (team2 != INVALID_HANDLE) {
    LoadTeamDataJson(team2, MatchTeam_Team2);
    CloseHandle(team2);
  } else {
    MatchConfigFail("Missing \"team2\" section in match json");
    return false;
  }

  if (AddJsonSubsectionArrayToList(json, "maplist", g_MapPoolList, PLATFORM_MAX_PATH) <= 0) {
    LogMessage("Failed to find \"maplist\" array in match json, using fallback maplist.");
    LoadDefaultMapList(g_MapPoolList);
  }

  if (g_SkipVeto) {
    Handle array = json_object_get(json, "map_sides");
    if (array != INVALID_HANDLE) {
      for (int i = 0; i < json_array_size(array); i++) {
        char buffer[64];
        json_array_get_string(array, i, buffer, sizeof(buffer));
        g_MapSides.Push(SideTypeFromString(buffer));
      }
      CloseHandle(array);
    }
  }

  Handle cvars = json_object_get(json, "cvars");
  if (cvars != INVALID_HANDLE) {
    char cvarName[MAX_CVAR_LENGTH];
    char cvarValue[MAX_CVAR_LENGTH];

    Handle iterator = json_object_iter(cvars);
    while (iterator != INVALID_HANDLE) {
      json_object_iter_key(iterator, cvarName, sizeof(cvarName));
      Handle value = json_object_iter_value(iterator);
      json_string_value(value, cvarValue, sizeof(cvarValue));
      g_CvarNames.PushString(cvarName);
      g_CvarValues.PushString(cvarValue);
      CloseHandle(value);
      iterator = json_object_iter_next(cvars, iterator);
    }
    CloseHandle(cvars);
  }

  return true;
}

static void LoadTeamDataJson(Handle json, MatchTeam matchTeam) {
  GetTeamAuths(matchTeam).Clear();

  char fromfile[PLATFORM_MAX_PATH];
  json_object_get_string_safe(json, "fromfile", fromfile, sizeof(fromfile));

  if (StrEqual(fromfile, "")) {
    AddJsonAuthsToList(json, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    json_object_get_string_safe(json, "name", g_TeamNames[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "tag", g_TeamTags[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "flag", g_TeamFlags[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "logo", g_TeamLogos[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "matchtext", g_TeamMatchTexts[matchTeam], MAX_CVAR_LENGTH);
  } else {
    Handle fromfileJson = json_load_file(fromfile);
    if (fromfileJson == INVALID_HANDLE) {
      LogError("Cannot load team config from file \"%s\", fromfile");
    } else {
      LoadTeamDataJson(fromfileJson, matchTeam);
      CloseHandle(fromfileJson);
    }
  }

  g_TeamSeriesScores[matchTeam] = json_object_get_int_safe(json, "series_score", 0);
  Format(g_FormattedTeamNames[matchTeam], MAX_CVAR_LENGTH, "%s%s{NORMAL}",
         g_DefaultTeamColors[matchTeam], g_TeamNames[matchTeam]);
}

static void LoadTeamData(KeyValues kv, MatchTeam matchTeam) {
  GetTeamAuths(matchTeam).Clear();
  char fromfile[PLATFORM_MAX_PATH];
  kv.GetString("fromfile", fromfile, sizeof(fromfile));

  if (StrEqual(fromfile, "")) {
    AddSubsectionAuthsToList(kv, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    kv.GetString("name", g_TeamNames[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("tag", g_TeamTags[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("flag", g_TeamFlags[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("logo", g_TeamLogos[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("matchtext", g_TeamMatchTexts[matchTeam], MAX_CVAR_LENGTH, "");
  } else {
    KeyValues fromfilekv = new KeyValues("team");
    if (fromfilekv.ImportFromFile(fromfile)) {
      LoadTeamData(fromfilekv, matchTeam);
    } else {
      LogError("Cannot load team config from file \"%s\"", fromfile);
    }
    delete fromfilekv;
  }

  g_TeamSeriesScores[matchTeam] = kv.GetNum("series_score", 0);
  Format(g_FormattedTeamNames[matchTeam], MAX_CVAR_LENGTH, "%s%s{NORMAL}",
         g_DefaultTeamColors[matchTeam], g_TeamNames[matchTeam]);
}

static void LoadDefaultMapList(ArrayList list) {
  list.PushString("de_cache");
  list.PushString("de_cbble");
  list.PushString("de_dust2");
  list.PushString("de_mirage");
  list.PushString("de_nuke");
  list.PushString("de_overpass");
  list.PushString("de_train");
}

public void SetMatchTeamCvars() {
  MatchTeam ctTeam = MatchTeam_Team1;
  MatchTeam tTeam = MatchTeam_Team2;
  if (g_TeamStartingSide[MatchTeam_Team1] == CS_TEAM_T) {
    ctTeam = MatchTeam_Team2;
    tTeam = MatchTeam_Team1;
  }

  int mapsPlayed = GetMapNumber();

  // Get the match configs set by the config file.
  // These might be modified so copies are made here.
  char ctMatchText[MAX_CVAR_LENGTH];
  char tMatchText[MAX_CVAR_LENGTH];
  strcopy(ctMatchText, sizeof(ctMatchText), g_TeamMatchTexts[ctTeam]);
  strcopy(tMatchText, sizeof(tMatchText), g_TeamMatchTexts[tTeam]);

  // Update mp_teammatchstat_txt with the match title.
  char mapstat[MAX_CVAR_LENGTH];
  strcopy(mapstat, sizeof(mapstat), g_MatchTitle);
  ReplaceStringWithInt(mapstat, sizeof(mapstat), "{MAPNUMBER}", mapsPlayed + 1);
  ReplaceStringWithInt(mapstat, sizeof(mapstat), "{MAXMAPS}", MaxMapsToPlay(g_MapsToWin));
  SetConVarStringSafe("mp_teammatchstat_txt", mapstat);

  if (g_MapsToWin >= 3) {
    char team1Text[MAX_CVAR_LENGTH];
    char team2Text[MAX_CVAR_LENGTH];
    IntToString(g_TeamSeriesScores[MatchTeam_Team1], team1Text, sizeof(team1Text));
    IntToString(g_TeamSeriesScores[MatchTeam_Team2], team2Text, sizeof(team2Text));

    MatchTeamStringsToCSTeam(team1Text, team2Text, ctMatchText, sizeof(ctMatchText), tMatchText,
                             sizeof(tMatchText));
  }

  SetTeamInfo(CS_TEAM_CT, g_TeamNames[ctTeam], g_TeamFlags[ctTeam], g_TeamLogos[ctTeam],
              ctMatchText, g_TeamSeriesScores[ctTeam]);

  SetTeamInfo(CS_TEAM_T, g_TeamNames[tTeam], g_TeamFlags[tTeam], g_TeamLogos[tTeam], tMatchText,
              g_TeamSeriesScores[tTeam]);

  // Set prediction cvars.
  SetConVarStringSafe("mp_teamprediction_txt", g_FavoredTeamText);
  if (g_TeamSide[MatchTeam_Team1] == CS_TEAM_CT) {
    SetConVarIntSafe("mp_teamprediction_pct", g_FavoredTeamPercentage);
  } else {
    SetConVarIntSafe("mp_teamprediction_pct", 100 - g_FavoredTeamPercentage);
  }

  if (g_MapsToWin > 1) {
    SetConVarIntSafe("mp_teamscore_max", g_MapsToWin);
  }

  char formattedHostname[128];

  if (FormatCvarString(g_SetHostnameCvar, formattedHostname, sizeof(formattedHostname))) {
    SetConVarStringSafe("hostname", formattedHostname);
  }
}

public MatchTeam GetMapWinner(int mapNumber) {
  int team1score = GetMapScore(mapNumber, MatchTeam_Team1);
  int team2score = GetMapScore(mapNumber, MatchTeam_Team2);
  if (team1score > team2score) {
    return MatchTeam_Team1;
  } else {
    return MatchTeam_Team2;
  }
}

public void ExecuteMatchConfigCvars() {
  // Save the original match cvar values if we haven't already.
  if (g_MatchConfigChangedCvars == INVALID_HANDLE) {
    g_MatchConfigChangedCvars = SaveCvars(g_CvarNames);
  }

  char name[MAX_CVAR_LENGTH];
  char value[MAX_CVAR_LENGTH];
  for (int i = 0; i < g_CvarNames.Length; i++) {
    g_CvarNames.GetString(i, name, sizeof(name));
    g_CvarValues.GetString(i, value, sizeof(value));
    ConVar cvar = FindConVar(name);
    if (cvar == null) {
      ServerCommand("%s %s", name, value);
    } else {
      cvar.SetString(value);
    }
  }
}

public Action Command_LoadTeam(int client, int args) {
  if (g_GameState == GameState_None) {
    ReplyToCommand(client, "Cannot change player lists when there is no match to modify");
    return Plugin_Handled;
  }

  char arg1[PLATFORM_MAX_PATH];
  char arg2[PLATFORM_MAX_PATH];
  if (args >= 2 && GetCmdArg(1, arg1, sizeof(arg1)) && GetCmdArg(2, arg2, sizeof(arg2))) {
    MatchTeam team = MatchTeam_TeamNone;
    if (StrEqual(arg1, "team1")) {
      team = MatchTeam_Team1;
    } else if (StrEqual(arg1, "team2")) {
      team = MatchTeam_Team2;
    } else if (StrEqual(arg1, "spec")) {
      team = MatchTeam_TeamSpec;
    } else {
      ReplyToCommand(client, "Unknown team: must be one of team1, team2, spec");
      return Plugin_Handled;
    }

    KeyValues kv = new KeyValues("team");
    if (kv.ImportFromFile(arg2)) {
      LoadTeamData(kv, team);
      ReplyToCommand(client, "Loaded team data for %s", arg1);
      SetMatchTeamCvars();
    } else {
      ReplyToCommand(client, "Failed to read keyvalues from file \"%s\"", arg2);
    }
    delete kv;

  } else {
    ReplyToCommand(client, "Usage: get_loadteam <team1|team2|spec> <filename>");
  }

  return Plugin_Handled;
}

public Action Command_AddPlayer(int client, int args) {
  if (g_GameState == GameState_None) {
    ReplyToCommand(client, "Cannot change player lists when there is no match to modify");
    return Plugin_Handled;
  }

  if (g_InScrimMode) {
    ReplyToCommand(
        client, "Cannot use get5_addplayer in scrim mode. Use get5_ringer to swap a players team.");
    return Plugin_Handled;
  }

  char auth[AUTH_LENGTH];
  char teamString[32];
  char name[MAX_NAME_LENGTH];
  if (args >= 2 && GetCmdArg(1, auth, sizeof(auth)) &&
      GetCmdArg(2, teamString, sizeof(teamString))) {
    if (args >= 3) {
      GetCmdArg(3, name, sizeof(name));
    }

    MatchTeam team = MatchTeam_TeamNone;
    if (StrEqual(teamString, "team1")) {
      team = MatchTeam_Team1;
    } else if (StrEqual(teamString, "team2")) {
      team = MatchTeam_Team2;
    } else if (StrEqual(teamString, "spec")) {
      team = MatchTeam_TeamSpec;
    } else {
      ReplyToCommand(client, "Unknown team: must be one of team1, team2, spec");
      return Plugin_Handled;
    }

    if (AddPlayerToTeam(auth, team, name)) {
      ReplyToCommand(client, "Successfully added player %s to team %s", auth, teamString);
    } else {
      ReplyToCommand(client, "Player %s is already on a match team.", auth);
    }

  } else {
    ReplyToCommand(client, "Usage: get5_addplayer <auth> <team1|team2|spec> [name]");
  }
  return Plugin_Handled;
}

public Action Command_RemovePlayer(int client, int args) {
  if (g_GameState == GameState_None) {
    ReplyToCommand(client, "Cannot change player lists when there is no match to modify");
    return Plugin_Handled;
  }

  if (g_InScrimMode) {
    ReplyToCommand(
        client,
        "Cannot use get5_removeplayer in scrim mode. Use get5_ringer to swap a players team.");
    return Plugin_Handled;
  }

  char auth[AUTH_LENGTH];
  if (args >= 1 && GetCmdArg(1, auth, sizeof(auth))) {
    if (RemovePlayerFromTeams(auth)) {
      ReplyToCommand(client, "Successfully removed player %s", auth);
    } else {
      ReplyToCommand(client, "Player %s not found in auth lists.", auth);
    }
  } else {
    ReplyToCommand(client, "Usage: get5_removeplayer <auth>");
  }
  return Plugin_Handled;
}

public Action Command_CreateMatch(int client, int args) {
  if (g_GameState != GameState_None) {
    ReplyToCommand(client, "Cannot create a match when a match is already loaded");
    return Plugin_Handled;
  }

  char matchid[MATCH_ID_LENGTH] = "manual";
  char matchMap[PLATFORM_MAX_PATH];
  GetCleanMapName(matchMap, sizeof(matchMap));

  if (args >= 1) {
    GetCmdArg(1, matchid, sizeof(matchid));
  }
  if (args >= 2) {
    GetCmdArg(2, matchMap, sizeof(matchMap));
    if (!IsMapValid(matchMap)) {
      ReplyToCommand(client, "Invalid map: %s", matchMap);
      return Plugin_Handled;
    }
  }

  char path[PLATFORM_MAX_PATH];
  Format(path, sizeof(path), "get5_%s.cfg", matchid);
  DeleteFileIfExists(path);

  KeyValues kv = new KeyValues("Match");
  kv.SetString("matchid", matchid);
  kv.SetNum("maps_to_win", 1);
  kv.SetNum("skip_veto", 1);
  kv.SetNum("players_per_team", 5);

  kv.JumpToKey("maplist", true);
  kv.SetString(matchMap, KEYVALUE_STRING_PLACEHOLDER);
  kv.GoBack();

  char teamName[MAX_CVAR_LENGTH];

  kv.JumpToKey("team1", true);
  int count = AddPlayersToAuthKv(kv, MatchTeam_Team1, teamName);
  if (count > 0)
    kv.SetString("name", teamName);
  kv.GoBack();

  kv.JumpToKey("team2", true);
  count = AddPlayersToAuthKv(kv, MatchTeam_Team2, teamName);
  if (count > 0)
    kv.SetString("name", teamName);
  kv.GoBack();

  kv.JumpToKey("spectators", true);
  AddPlayersToAuthKv(kv, MatchTeam_TeamSpec, teamName);
  kv.GoBack();

  if (!kv.ExportToFile(path)) {
    delete kv;
    MatchConfigFail("Failed to read write match config to %s", path);
    return Plugin_Handled;
  }

  delete kv;
  LoadMatchConfig(path);
  return Plugin_Handled;
}

public Action Command_CreateScrim(int client, int args) {
  if (g_GameState != GameState_None) {
    ReplyToCommand(client, "Cannot create a match when a match is already loaded");
    return Plugin_Handled;
  }

  char matchid[MATCH_ID_LENGTH] = "scrim";
  char matchMap[PLATFORM_MAX_PATH];
  GetCleanMapName(matchMap, sizeof(matchMap));
  char otherTeamName[MAX_CVAR_LENGTH] = "Away";

  if (args >= 1) {
    GetCmdArg(1, otherTeamName, sizeof(otherTeamName));
  }
  if (args >= 2) {
    GetCmdArg(2, matchMap, sizeof(matchMap));
    if (!IsMapValid(matchMap)) {
      ReplyToCommand(client, "Invalid map: %s", matchMap);
      return Plugin_Handled;
    }
  }
  if (args >= 3) {
    GetCmdArg(3, matchid, sizeof(matchid));
  }

  char path[PLATFORM_MAX_PATH];
  Format(path, sizeof(path), "get5_%s.cfg", matchid);
  DeleteFileIfExists(path);

  KeyValues kv = new KeyValues("Match");
  kv.SetString("matchid", matchid);
  kv.SetNum("scrim", 1);
  kv.JumpToKey("maplist", true);
  kv.SetString(matchMap, KEYVALUE_STRING_PLACEHOLDER);
  kv.GoBack();

  char templateFile[PLATFORM_MAX_PATH + 1];
  BuildPath(Path_SM, templateFile, sizeof(templateFile), "configs/get5/scrim_template.cfg");
  if (!kv.ImportFromFile(templateFile)) {
    delete kv;
    MatchConfigFail("Failed to read scrim template in %s", templateFile);
    return Plugin_Handled;
  }

  if (kv.JumpToKey("team1") && kv.JumpToKey("players") && kv.GotoFirstSubKey(false)) {
    // Empty string values are found when reading KeyValues, but don't get written out.
    // So this adds a value for each auth so scrim templates don't have to insert fake values.
    do {
      char auth[AUTH_LENGTH];
      char name[MAX_NAME_LENGTH];
      kv.GetString(NULL_STRING, name, sizeof(name), KEYVALUE_STRING_PLACEHOLDER);
      kv.GetSectionName(auth, sizeof(auth));

      // This shouldn't be necessary, but when the name field was empty, the
      // use of KEYVALUE_STRING_PLACEHOLDER as a default doesn't seem to work.
      // TODO: figure out what's going on with needing this here.
      if (StrEqual(name, "")) {
        name = KEYVALUE_STRING_PLACEHOLDER;
      }

      kv.SetString(NULL_STRING, name);
    } while (kv.GotoNextKey(false));
    kv.Rewind();
  } else {
    delete kv;
    MatchConfigFail("You must add players to team1 on your scrim template!");
    return Plugin_Handled;
  }

  kv.JumpToKey("team2", true);
  kv.SetString("name", otherTeamName);
  kv.GoBack();

  if (!kv.ExportToFile(path)) {
    delete kv;
    MatchConfigFail("Failed to read write scrim config to %s", path);
    return Plugin_Handled;
  }

  delete kv;
  LoadMatchConfig(path);
  return Plugin_Handled;
}

public Action Command_Ringer(int client, int args) {
  if (g_GameState == GameState_None || !g_InScrimMode) {
    ReplyToCommand(client, "This command can only be used in scrim mode");
    return Plugin_Handled;
  }

  char arg1[32];
  if (args >= 1 && GetCmdArg(1, arg1, sizeof(arg1))) {
    int target = FindTarget(client, arg1, true, false);
    if (IsAuthedPlayer(target)) {
      SwapScrimTeamStatus(target);
    } else {
      ReplyToCommand(client, "Player not found");
    }
  } else {
    ReplyToCommand(client, "Usage: sm_ringer <player>");
  }

  return Plugin_Handled;
}

static int AddPlayersToAuthKv(KeyValues kv, MatchTeam team, char teamName[MAX_CVAR_LENGTH]) {
  int count = 0;
  kv.JumpToKey("players", true);
  bool gotClientName = false;
  char auth[AUTH_LENGTH];
  for (int i = 1; i <= MaxClients; i++) {
    if (IsAuthedPlayer(i)) {
      int csTeam = GetClientTeam(i);
      MatchTeam t = MatchTeam_TeamNone;
      if (csTeam == TEAM1_STARTING_SIDE) {
        t = MatchTeam_Team1;
      } else if (csTeam == TEAM2_STARTING_SIDE) {
        t = MatchTeam_Team2;
      } else if (csTeam == CS_TEAM_SPECTATOR) {
        t = MatchTeam_TeamSpec;
      }

      if (t == team) {
        if (!gotClientName) {
          gotClientName = true;
          char clientName[MAX_NAME_LENGTH];
          GetClientName(i, clientName, sizeof(clientName));
          Format(teamName, sizeof(teamName), "team_%s", clientName);
        }

        count++;
        if (GetAuth(i, auth, sizeof(auth))) {
          kv.SetString(auth, KEYVALUE_STRING_PLACEHOLDER);
        }
      }
    }
  }
  kv.GoBack();
  return count;
}

static void MatchTeamStringsToCSTeam(const char[] team1Str, const char[] team2Str, char[] ctStr,
                                     int ctLen, char[] tStr, int tLen) {
  if (MatchTeamToCSTeam(MatchTeam_Team1) == CS_TEAM_CT) {
    strcopy(ctStr, ctLen, team1Str);
    strcopy(tStr, tLen, team2Str);
  } else {
    strcopy(tStr, tLen, team1Str);
    strcopy(ctStr, ctLen, team2Str);
  }
}

// Adds the team logos to the download table.
static void AddTeamLogosToDownloadTable() {
  AddTeamLogoToDownloadTable(g_TeamLogos[MatchTeam_Team1]);
  AddTeamLogoToDownloadTable(g_TeamLogos[MatchTeam_Team2]);
}

static void AddTeamLogoToDownloadTable(const char[] logoName) {
  if (StrEqual(logoName, ""))
    return;

  char logoPath[PLATFORM_MAX_PATH + 1];
  Format(logoPath, sizeof(logoPath), "resource/flash/econ/tournaments/teams/%s.png", logoName);

  LogDebug("Adding file %s to download table", logoName);
  AddFileToDownloadsTable(logoPath);
}

public void CheckTeamNameStatus(MatchTeam team) {
  if (StrEqual(g_TeamNames[team], "") && team != MatchTeam_TeamSpec) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsAuthedPlayer(i)) {
        if (GetClientMatchTeam(i) == team) {
          char clientName[MAX_NAME_LENGTH];
          GetClientName(i, clientName, sizeof(clientName));
          Format(g_TeamNames[team], MAX_CVAR_LENGTH, "team_%s", clientName);
          break;
        }
      }
    }

    char colorTag[32] = TEAM1_COLOR;
    if (team == MatchTeam_Team2)
      colorTag = TEAM2_COLOR;

    Format(g_FormattedTeamNames[team], MAX_CVAR_LENGTH, "%s%s{NORMAL}", colorTag,
           g_TeamNames[team]);
  }
}
