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
  if (g_GameState != Get5State_None && !restoreBackup) {
    return false;
  }

  ResetReadyStatus();
  LOOP_TEAMS(team) {
    g_TeamState[team].series_score = 0;
    g_TeamState[team].ready_for_unpause = false;
    g_TeamState[team].gave_stop_command = false;
    g_TeamState[team].pause_time_used = 0;
    g_TeamState[team].num_pauses_used = 0;
    g_TeamState[team].ready_time_used = 0;
    ClearArray(GetTeamAuths(team));
  }

  g_ForceWinnerSignal = false;
  g_ForcedWinner = MatchTeam_TeamNone;

  g_LastVetoTeam = MatchTeam_Team2;
  g_MapPoolList.Clear();
  g_MapsLeftInVetoPool.Clear();
  g_MapsToPlay.Clear();
  g_MapSides.Clear();
  g_MatchConfig.cvar_names.Clear();
  g_MatchConfig.cvar_values.Clear();
  g_TeamScoresPerMap.Clear();

  g_WaitingForRoundBackup = false;
  g_LastGet5BackupCvar.SetString("");

  CloseCvarStorage(g_KnifeChangedCvars);
  CloseCvarStorage(g_MatchConfigChangedCvars);

  if (!LoadMatchFile(config)) {
    return false;
  }

  if (!g_CheckAuthsCvar.BoolValue &&
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

  if (g_MatchConfig.skip_veto) {
    // Copy the first k maps from the maplist to the final match maps.
    for (int i = 0; i < MaxMapsToPlay(g_MapsToWin); i++) {
      g_MapPoolList.GetString(i, mapName, sizeof(mapName));
      g_MapsToPlay.PushString(mapName);

      // Push a map side if one hasn't been set yet.
      if (g_MapSides.Length < g_MapsToPlay.Length) {
        if (g_MatchConfig.side_type == MatchSideType_Standard) {
          g_MapSides.Push(SideChoice_KnifeRound);
        } else if (g_MatchConfig.side_type == MatchSideType_AlwaysKnife) {
          g_MapSides.Push(SideChoice_KnifeRound);
        } else if (g_MatchConfig.side_type == MatchSideType_NeverKnife) {
          g_MapSides.Push(SideChoice_Team1CT);
        }
      }
    }

    g_MapPoolList.GetString(GetMapNumber(), mapName, sizeof(mapName));
    ChangeState(Get5State_Warmup);

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    if (!StrEqual(mapName, currentMap) && !restoreBackup) {
      ChangeMap(mapName);
    }
  } else {
    ChangeState(Get5State_PreVeto);
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
    char configFile[PLATFORM_MAX_PATH];
    strcopy(configFile, sizeof(configFile), config);
    if (!FileExists(configFile)) {
      MatchConfigFail("Match json file doesn't exist: \"%s\"", configFile);
      return false;
    }

    JSON_Object json = json_load_file(configFile);
    if (json != null && LoadMatchFromJson(json)) {
      json.Cleanup();
      delete json;
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
  kv.SetNum("scrim", g_MatchConfig.scrim_mode);
  kv.SetNum("maps_to_win", g_MapsToWin);
  kv.SetNum("bo2_series", g_BO2Match);
  kv.SetNum("skip_veto", g_MatchConfig.skip_veto);
  kv.SetNum("players_per_team", g_MatchConfig.players_per_team);
  kv.SetNum("min_players_to_ready", g_MatchConfig.min_players_to_ready);
  kv.SetNum("min_spectators_to_ready", g_MatchConfig.min_spectators_to_ready);
  kv.SetString("match_title", g_MatchConfig.title);

  kv.SetNum("favored_percentage_team1", g_MatchConfig.favored_team_percentage);
  kv.SetString("favored_percentage_text", g_MatchConfig.favored_team_text);

  char sideType[64];
  MatchSideTypeToString(g_MatchConfig.side_type, sideType, sizeof(sideType));
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
  for (int i = 0; i < g_MatchConfig.cvar_names.Length; i++) {
    char cvarName[MAX_CVAR_LENGTH];
    char cvarValue[MAX_CVAR_LENGTH];
    g_MatchConfig.cvar_names.GetString(i, cvarName, sizeof(cvarName));
    g_MatchConfig.cvar_values.GetString(i, cvarValue, sizeof(cvarValue));
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

  kv.SetString("name", g_TeamConfig[team].name);
  if (team != MatchTeam_TeamSpec) {
    kv.SetString("tag", g_TeamConfig[team].tag);
    kv.SetString("flag", g_TeamConfig[team].flag);
    kv.SetString("logo", g_TeamConfig[team].logo);
    kv.SetString("matchtext", g_TeamConfig[team].match_text);
  }
}

static bool LoadMatchFromKv(KeyValues kv) {
  kv.GetString("matchid", g_MatchID, sizeof(g_MatchID), CONFIG_MATCHID_DEFAULT);
  g_MatchConfig.scrim_mode = kv.GetNum("scrim") != 0;
  kv.GetString("match_title", g_MatchConfig.title, sizeof(g_MatchConfig.title),
               CONFIG_MATCHTITLE_DEFAULT);
  g_MatchConfig.players_per_team = kv.GetNum("players_per_team", CONFIG_PLAYERSPERTEAM_DEFAULT);
  g_MatchConfig.min_players_to_ready =
      kv.GetNum("min_players_to_ready", CONFIG_MINPLAYERSTOREADY_DEFAULT);
  g_MatchConfig.min_spectators_to_ready =
      kv.GetNum("min_spectators_to_ready", CONFIG_MINSPECTATORSTOREADY_DEFAULT);
  g_MatchConfig.skip_veto = kv.GetNum("skip_veto", CONFIG_SKIPVETO_DEFAULT) != 0;

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
  g_MatchConfig.side_type = MatchSideTypeFromString(sideTypeBuffer);

  g_MatchConfig.favored_team_percentage = kv.GetNum("favored_percentage_team1", 0);
  kv.GetString("favored_percentage_text", g_MatchConfig.favored_team_text,
               sizeof(g_MatchConfig.favored_team_text));

  GetTeamAuths(MatchTeam_TeamSpec).Clear();
  if (kv.JumpToKey("spectators")) {
    AddSubsectionAuthsToList(kv, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
    kv.GetString("name", g_TeamConfig[MatchTeam_TeamSpec].name, MAX_CVAR_LENGTH,
                 CONFIG_SPECTATORSNAME_DEFAULT);
    kv.GoBack();

    Format(g_TeamConfig[MatchTeam_TeamSpec].formatted_name, MAX_CVAR_LENGTH, "%s%s{NORMAL}",
           g_DefaultTeamColors[MatchTeam_TeamSpec], g_TeamConfig[MatchTeam_TeamSpec].name);
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

  if (g_MatchConfig.skip_veto) {
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
        g_MatchConfig.cvar_names.PushString(name);
        g_MatchConfig.cvar_values.PushString(value);
      } while (kv.GotoNextKey(false));
      kv.GoBack();
    }
    kv.GoBack();
  }

  return true;
}

static bool LoadMatchFromJson(JSON_Object json) {
  json_object_get_string_safe(json, "matchid", g_MatchID, sizeof(g_MatchID),
                              CONFIG_MATCHID_DEFAULT);
  g_MatchConfig.scrim_mode = json_object_get_bool_safe(json, "scrim", false);
  json_object_get_string_safe(json, "match_title", g_MatchConfig.title, sizeof(g_MatchConfig.title),
                              CONFIG_MATCHTITLE_DEFAULT);

  g_MatchConfig.players_per_team =
      json_object_get_int_safe(json, "players_per_team", CONFIG_PLAYERSPERTEAM_DEFAULT);
  g_MatchConfig.min_players_to_ready =
      json_object_get_int_safe(json, "min_players_to_ready", CONFIG_MINPLAYERSTOREADY_DEFAULT);
  g_MatchConfig.min_spectators_to_ready = json_object_get_int_safe(
      json, "min_spectators_to_ready", CONFIG_MINSPECTATORSTOREADY_DEFAULT);
  g_MatchConfig.skip_veto = json_object_get_bool_safe(json, "skip_veto", CONFIG_SKIPVETO_DEFAULT);

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
  g_MatchConfig.side_type = MatchSideTypeFromString(sideTypeBuffer);

  json_object_get_string_safe(json, "favored_percentage_text", g_MatchConfig.favored_team_text,
                              sizeof(g_MatchConfig.favored_team_text));
  g_MatchConfig.favored_team_percentage =
      json_object_get_int_safe(json, "favored_percentage_team1", 0);

  JSON_Object spec = json.GetObject("spectators");
  if (spec != null) {
    json_object_get_string_safe(spec, "name", g_TeamConfig[MatchTeam_TeamSpec].name,
                                MAX_CVAR_LENGTH, CONFIG_SPECTATORSNAME_DEFAULT);
    AddJsonAuthsToList(spec, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);

    Format(g_TeamConfig[MatchTeam_TeamSpec].formatted_name, MAX_CVAR_LENGTH, "%s%s{NORMAL}",
           g_DefaultTeamColors[MatchTeam_TeamSpec], g_TeamConfig[MatchTeam_TeamSpec].name);
  }

  JSON_Object team1 = json.GetObject("team1");
  if (team1 != null) {
    LoadTeamDataJson(team1, MatchTeam_Team1);
  } else {
    MatchConfigFail("Missing \"team1\" section in match json");
    return false;
  }

  JSON_Object team2 = json.GetObject("team2");
  if (team2 != null) {
    LoadTeamDataJson(team2, MatchTeam_Team2);
  } else {
    MatchConfigFail("Missing \"team2\" section in match json");
    return false;
  }

  if (AddJsonSubsectionArrayToList(json, "maplist", g_MapPoolList, PLATFORM_MAX_PATH) <= 0) {
    LogMessage("Failed to find \"maplist\" array in match json, using fallback maplist.");
    LoadDefaultMapList(g_MapPoolList);
  }

  if (g_MatchConfig.skip_veto) {
    JSON_Object array = json.GetObject("map_sides");
    if (array != null) {
      if (!array.IsArray) {
        MatchConfigFail("Expected \"map_sides\" section to be an array");
        return false;
      }
      for (int i = 0; i < array.Length; i++) {
        char keyAsString[64];
        char buffer[64];
        array.GetIndexString(keyAsString, sizeof(keyAsString), i);
        array.GetString(keyAsString, buffer, sizeof(buffer));
        g_MapSides.Push(SideTypeFromString(buffer));
      }
      CloseHandle(array);
    }
  }

  JSON_Object cvars = json.GetObject("cvars");
  if (cvars != null) {
    char cvarName[MAX_CVAR_LENGTH];
    char cvarValue[MAX_CVAR_LENGTH];

    StringMapSnapshot snap = cvars.Snapshot();
    for (int i = 0; i < snap.Length; i++) {
      snap.GetKey(i, cvarName, sizeof(cvarName));
      cvars.GetString(cvarName, cvarValue, sizeof(cvarValue));
      g_MatchConfig.cvar_names.PushString(cvarName);
      g_MatchConfig.cvar_values.PushString(cvarValue);
    }
  }

  return true;
}

static void LoadTeamDataJson(JSON_Object json, MatchTeam matchTeam) {
  GetTeamAuths(matchTeam).Clear();

  char fromfile[PLATFORM_MAX_PATH];
  json_object_get_string_safe(json, "fromfile", fromfile, sizeof(fromfile));

  if (StrEqual(fromfile, "")) {
    // TODO: this needs to support both an array and a dictionary
    // For now, it only supports an array
    AddJsonAuthsToList(json, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    json_object_get_string_safe(json, "name", g_TeamConfig[matchTeam].name, MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "tag", g_TeamConfig[matchTeam].tag, MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "flag", g_TeamConfig[matchTeam].flag, MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "logo", g_TeamConfig[matchTeam].logo, MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "matchtext", g_TeamConfig[matchTeam].match_text,
                                MAX_CVAR_LENGTH);
  } else {
    JSON_Object fromfileJson = json_load_file(fromfile);
    if (fromfileJson == null) {
      LogError("Cannot load team config from file \"%s\", fromfile");
    } else {
      LoadTeamDataJson(fromfileJson, matchTeam);
      fromfileJson.Cleanup();
      delete fromfileJson;
    }
  }

  g_TeamState[matchTeam].series_score = json_object_get_int_safe(json, "series_score", 0);
  Format(g_TeamConfig[matchTeam].formatted_name, MAX_CVAR_LENGTH, "%s%s{NORMAL}",
         g_DefaultTeamColors[matchTeam], g_TeamConfig[matchTeam].name);
}

static void LoadTeamData(KeyValues kv, MatchTeam matchTeam) {
  GetTeamAuths(matchTeam).Clear();
  char fromfile[PLATFORM_MAX_PATH];
  kv.GetString("fromfile", fromfile, sizeof(fromfile));

  if (StrEqual(fromfile, "")) {
    AddSubsectionAuthsToList(kv, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    kv.GetString("name", g_TeamConfig[matchTeam].name, MAX_CVAR_LENGTH, "");
    kv.GetString("tag", g_TeamConfig[matchTeam].tag, MAX_CVAR_LENGTH, "");
    kv.GetString("flag", g_TeamConfig[matchTeam].flag, MAX_CVAR_LENGTH, "");
    kv.GetString("logo", g_TeamConfig[matchTeam].logo, MAX_CVAR_LENGTH, "");
    kv.GetString("matchtext", g_TeamConfig[matchTeam].match_text, MAX_CVAR_LENGTH, "");
  } else {
    KeyValues fromfilekv = new KeyValues("team");
    if (fromfilekv.ImportFromFile(fromfile)) {
      LoadTeamData(fromfilekv, matchTeam);
    } else {
      LogError("Cannot load team config from file \"%s\"", fromfile);
    }
    delete fromfilekv;
  }

  g_TeamState[matchTeam].series_score = kv.GetNum("series_score", 0);
  Format(g_TeamConfig[matchTeam].formatted_name, MAX_CVAR_LENGTH, "%s%s{NORMAL}",
         g_DefaultTeamColors[matchTeam], g_TeamConfig[matchTeam].name);
}

static void LoadDefaultMapList(ArrayList list) {
  list.PushString("de_cache");
  list.PushString("de_dust2");
  list.PushString("de_inferno");
  list.PushString("de_mirage");
  list.PushString("de_nuke");
  list.PushString("de_overpass");
  list.PushString("de_train");
}

public void SetMatchTeamCvars() {
  MatchTeam ctTeam = MatchTeam_Team1;
  MatchTeam tTeam = MatchTeam_Team2;
  if (g_TeamState[MatchTeam_Team1].starting_side == CS_TEAM_T) {
    ctTeam = MatchTeam_Team2;
    tTeam = MatchTeam_Team1;
  }

  int mapsPlayed = GetMapNumber();

  // Get the match configs set by the config file.
  // These might be modified so copies are made here.
  char ctMatchText[MAX_CVAR_LENGTH];
  char tMatchText[MAX_CVAR_LENGTH];
  strcopy(ctMatchText, sizeof(ctMatchText), g_TeamConfig[ctTeam].match_text);
  strcopy(tMatchText, sizeof(tMatchText), g_TeamConfig[tTeam].match_text);

  // Update mp_teammatchstat_txt with the match title.
  char mapstat[MAX_CVAR_LENGTH];
  strcopy(mapstat, sizeof(mapstat), g_MatchConfig.title);
  ReplaceStringWithInt(mapstat, sizeof(mapstat), "{MAPNUMBER}", mapsPlayed + 1);
  ReplaceStringWithInt(mapstat, sizeof(mapstat), "{MAXMAPS}", MaxMapsToPlay(g_MapsToWin));
  SetConVarStringSafe("mp_teammatchstat_txt", mapstat);

  if (g_MapsToWin >= 3) {
    char team1Text[MAX_CVAR_LENGTH];
    char team2Text[MAX_CVAR_LENGTH];
    IntToString(g_TeamState[MatchTeam_Team1].series_score, team1Text, sizeof(team1Text));
    IntToString(g_TeamState[MatchTeam_Team2].series_score, team2Text, sizeof(team2Text));

    MatchTeamStringsToCSTeam(team1Text, team2Text, ctMatchText, sizeof(ctMatchText), tMatchText,
                             sizeof(tMatchText));
  }

  SetTeamInfo(CS_TEAM_CT, g_TeamConfig[ctTeam].name, g_TeamConfig[ctTeam].flag,
              g_TeamConfig[ctTeam].logo, ctMatchText, g_TeamState[ctTeam].series_score);

  SetTeamInfo(CS_TEAM_T, g_TeamConfig[tTeam].name, g_TeamConfig[tTeam].flag,
              g_TeamConfig[tTeam].logo, tMatchText, g_TeamState[tTeam].series_score);

  // Set prediction cvars.
  SetConVarStringSafe("mp_teamprediction_txt", g_MatchConfig.favored_team_text);
  if (g_TeamState[MatchTeam_Team1].side == CS_TEAM_CT) {
    SetConVarIntSafe("mp_teamprediction_pct", g_MatchConfig.favored_team_percentage);
  } else {
    SetConVarIntSafe("mp_teamprediction_pct", 100 - g_MatchConfig.favored_team_percentage);
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
    g_MatchConfigChangedCvars = SaveCvars(g_MatchConfig.cvar_names);
  }

  char name[MAX_CVAR_LENGTH];
  char value[MAX_CVAR_LENGTH];
  for (int i = 0; i < g_MatchConfig.cvar_names.Length; i++) {
    g_MatchConfig.cvar_names.GetString(i, name, sizeof(name));
    g_MatchConfig.cvar_values.GetString(i, value, sizeof(value));
    ConVar cvar = FindConVar(name);
    if (cvar == null) {
      ServerCommand("%s %s", name, value);
    } else {
      cvar.SetString(value);
    }
  }
}

public Action Command_LoadTeam(int client, int args) {
  if (g_GameState == Get5State_None) {
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
  if (g_GameState == Get5State_None) {
    ReplyToCommand(client, "Cannot change player lists when there is no match to modify");
    return Plugin_Handled;
  }

  if (g_MatchConfig.scrim_mode) {
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
  if (g_GameState == Get5State_None) {
    ReplyToCommand(client, "Cannot change player lists when there is no match to modify");
    return Plugin_Handled;
  }

  if (g_MatchConfig.scrim_mode) {
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
  if (g_GameState != Get5State_None) {
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
  if (g_GameState != Get5State_None) {
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
  if (g_GameState == Get5State_None || !g_MatchConfig.scrim_mode) {
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
  AddTeamLogoToDownloadTable(g_TeamConfig[MatchTeam_Team1].logo);
  AddTeamLogoToDownloadTable(g_TeamConfig[MatchTeam_Team2].logo);
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
  if (StrEqual(g_TeamConfig[team].name, "") && team != MatchTeam_TeamSpec) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsAuthedPlayer(i)) {
        if (GetClientMatchTeam(i) == team) {
          char clientName[MAX_NAME_LENGTH];
          GetClientName(i, clientName, sizeof(clientName));
          Format(g_TeamConfig[team].name, MAX_CVAR_LENGTH, "team_%s", clientName);
          break;
        }
      }
    }

    char colorTag[32] = TEAM1_COLOR;
    if (team == MatchTeam_Team2)
      colorTag = TEAM2_COLOR;

    Format(g_TeamConfig[team].formatted_name, MAX_CVAR_LENGTH, "%s%s{NORMAL}", colorTag,
           g_TeamConfig[team].name);
  }
}
