public bool LoadMatchConfig(const char[] config) {
    if (g_GameState != GameState_None) {
        return false;
    }

    LOOP_TEAMS(team) {
        g_TeamReady[team] = false;
        g_TeamSeriesScores[team] = 0;
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

    if (StrContains(config, "json") >= 0) {
        if (!LibraryExists("jansson")) {
            MatchConfigFail("Cannot load a json config without the smjansson extension loaded");
            return false;
        }

        char configFile[PLATFORM_MAX_PATH];
        strcopy(configFile, sizeof(configFile), config);

        Handle json = json_load_file(configFile);
        if (json != INVALID_HANDLE && LoadMatchFromJson(json)) {
            CloseHandle(json);
            Get5_MessageToAll("Loaded match config.");
        } else {
            MatchConfigFail("invalid match json");
            return false;
        }

    } else {
        // Assume its a keyvalues file.
        KeyValues kv = new KeyValues("Match");
        if (kv.ImportFromFile(config) && LoadMatchFromKv(kv)) {
            delete kv;
            Get5_MessageToAll("Loaded match config.");
        } else {
            delete kv;
            MatchConfigFail("invalid match kv");
            return false;
        }
    }

    // Copy all the maps into the veto pool.
    char mapName[PLATFORM_MAX_PATH];
    for (int i = 0; i < g_MapPoolList.Length; i++) {
        g_MapPoolList.GetString(i, mapName, sizeof(mapName));
        g_MapsLeftInVetoPool.PushString(mapName);
    }

    if (g_SkipVeto) {
        // Copy the first k maps from the maplist to the final match maps.
        for (int i = 0; i < MaxMapsToPlay(g_MapsToWin); i++) {
            g_MapPoolList.GetString(i, mapName, sizeof(mapName));
            g_MapsToPlay.PushString(mapName);

            if (g_MatchSideType == MatchSideType_Standard) {
                g_MapSides.Push(SideChoice_KnifeRound);
            } else if (g_MatchSideType == MatchSideType_AlwaysKnife) {
                g_MapSides.Push(SideChoice_KnifeRound);
            } else if (g_MatchSideType == MatchSideType_NeverKnife) {
                g_MapSides.Push(SideChoice_Team1CT);
            }
        }

        g_MapPoolList.GetString(GetMapNumber(), mapName, sizeof(mapName));
        ChangeState(GameState_Warmup);

        char currentMap[PLATFORM_MAX_PATH];
        GetCleanMapName(currentMap, sizeof(currentMap));
        if (!StrEqual(mapName, currentMap))
            ChangeMap(mapName);
    } else {
        ChangeState(GameState_PreVeto);
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (IsAuthedPlayer(i) && GetClientMatchTeam(i) == MatchTeam_TeamNone) {
            KickClient(i, "You are not a player in this match");
        }
    }

    SetStartingTeams();
    ExecCfg(g_WarmupCfgCvar);
    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();
    EnsurePausedWarmup();
    AddTeamLogosToDownloadTable();
    strcopy(g_LoadedConfigFile, sizeof(g_LoadedConfigFile), config);

    return true;
}

static void MatchConfigFail(const char[] reason, any ...) {
    char buffer[512];
    VFormat(buffer, sizeof(buffer), reason, 2);

    Call_StartForward(g_OnLoadMatchConfigFailed);
    LogError("Failed to load match config: %s", buffer);
    Call_PushString(buffer);
    Call_Finish();
}

stock bool LoadMatchFromUrl(const char[] url, ArrayList paramNames=null, ArrayList paramValues=null) {
    bool steamWorksAvaliable = GetFeatureStatus(FeatureType_Native,
        "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available;
    bool system2Avaliable = GetFeatureStatus(FeatureType_Native,
        "System2_DownloadFile") == FeatureStatus_Available;

    if (system2Avaliable) {
        System2_DownloadFile(System2_OnMatchConfigReceived, url, REMOTE_CONFIG_FILENAME);
        return true;

    } else if (steamWorksAvaliable) {
        Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
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
        MatchConfigFail("Neither steamworks nor system2 extensions avaliable");
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

    SteamWorks_WriteHTTPResponseBodyToFile(request, REMOTE_CONFIG_FILENAME);
    LoadMatchConfig(REMOTE_CONFIG_FILENAME);
}


public int System2_OnMatchConfigReceived(bool finished, const char[] error, float dltotal,
    float dlnow, float ultotal, float ulnow, int serial) {
    if (!StrEqual(error, "")) {
        MatchConfigFail("Error receiving remote config: %s", error);
    }
    if (finished) {
        LoadMatchConfig(REMOTE_CONFIG_FILENAME);
    }
}

static bool LoadMatchFromKv(KeyValues kv) {
    kv.GetString("matchid", g_MatchID, sizeof(g_MatchID), "matchid");
    kv.GetString("match_title", g_MatchTitle, sizeof(g_MatchTitle), "Map {MAPNUMBER} of {MAXMAPS}");
    g_PlayersPerTeam = kv.GetNum("players_per_team", 5);
    g_MapsToWin = kv.GetNum("maps_to_win", 2);
    g_SkipVeto = kv.GetNum("skip_veto", 0) != 0;

    char buf[64];
    kv.GetString("side_type", buf, sizeof(buf), "standard");
    g_MatchSideType = MatchSideTypeFromString(buf);

    g_FavoredTeamPercentage = kv.GetNum("favored_percentage_team1", 0);
    kv.GetString("favored_percentage_text", g_FavoredTeamText, sizeof(g_FavoredTeamText));

    if (kv.JumpToKey("spectators")) {
        AddSubsectionAuthsToList(kv, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
        kv.GoBack();
    }

    if (kv.JumpToKey("team1")) {
        LoadTeamData(kv, MatchTeam_Team1, "Team1", TEAM1_COLOR);
        kv.GoBack();
    } else {
        MatchConfigFail("Missing \"team1\" section in match kv");
        return false;
    }

    if (kv.JumpToKey("team2")) {
        LoadTeamData(kv, MatchTeam_Team2, "Team2", TEAM2_COLOR);
        kv.GoBack();
    } else {
        MatchConfigFail("Missing \"team2\" section in match kv");
        return false;
    }

    if (AddSubsectionKeysToList(kv, "maplist", g_MapPoolList, PLATFORM_MAX_PATH) <= 0) {
        LogError("Failed to find \"maplist\" section in config, using fallback maplist.");
        LoadDefaultMapList(g_MapPoolList);
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
    json_object_get_string_safe(json, "matchid", g_MatchID, sizeof(g_MatchID), "matchid");
    json_object_get_string_safe(json, "match_title", g_MatchTitle, sizeof(g_MatchTitle), "Map {MAPNUMBER} of {MAXMAPS}");
    g_PlayersPerTeam = json_object_get_int_safe(json, "players_per_team", 5);
    g_MapsToWin = json_object_get_int_safe(json, "maps_to_win", 2);
    g_SkipVeto = json_object_get_bool_safe(json, "skip_veto", false);

    char buf[64];
    json_object_get_string_safe(json, "side_type", buf, sizeof(buf), "standard");
    g_MatchSideType = MatchSideTypeFromString(buf);

    json_object_get_string_safe(json, "favored_percentage_text",
        g_FavoredTeamText, sizeof(g_FavoredTeamText), "matchID");
    g_FavoredTeamPercentage = json_object_get_int_safe(json, "favored_percentage_team1", 0);

    Handle spec = json_object_get(json, "spectators");
    if (spec != INVALID_HANDLE) {
        AddJsonAuthsToList(json, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
        CloseHandle(spec);
    }

    Handle team1 = json_object_get(json, "team1");
    if (team1 != INVALID_HANDLE) {
        LoadTeamDataJson(team1, MatchTeam_Team1, "Team1", TEAM1_COLOR);
        CloseHandle(team1);
    } else {
        MatchConfigFail("Missing \"team1\" section in match json");
        return false;
    }

    Handle team2 = json_object_get(json, "team2");
    if (team2 != INVALID_HANDLE) {
        LoadTeamDataJson(team2, MatchTeam_Team2, "Team2", TEAM2_COLOR);
        CloseHandle(team2);
    } else {
        MatchConfigFail("Missing \"team2\" section in match json");
        return false;
    }

    if (AddJsonSubsectionArrayToList(json, "maplist", g_MapPoolList, PLATFORM_MAX_PATH) <= 0) {
        LogError("Failed to find \"maplist\" array in match json, using fallback maplist.");
        LoadDefaultMapList(g_MapPoolList);
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

static void LoadTeamDataJson(Handle json, MatchTeam matchTeam, const char[] defaultName, const char[] colorTag) {
    AddJsonAuthsToList(json, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    json_object_get_string_safe(json, "name", g_TeamNames[matchTeam], MAX_CVAR_LENGTH);
    if (StrEqual(g_TeamNames[matchTeam], ""))
        strcopy(g_TeamNames[matchTeam], MAX_CVAR_LENGTH, defaultName);

    json_object_get_string_safe(json, "flag", g_TeamFlags[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "logo", g_TeamLogos[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string_safe(json, "matchtext", g_TeamMatchTexts[matchTeam], MAX_CVAR_LENGTH);
    g_TeamSeriesScores[matchTeam] = json_object_get_int_safe(json, "series_score", 0);
    Format(g_FormattedTeamNames[matchTeam], MAX_CVAR_LENGTH, "%s%s{NORMAL}", colorTag, g_TeamNames[matchTeam]);
}

static void LoadTeamData(KeyValues kv, MatchTeam matchTeam, const char[] defaultName, const char[] colorTag) {
    AddSubsectionAuthsToList(kv, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    kv.GetString("name", g_TeamNames[matchTeam], MAX_CVAR_LENGTH, defaultName);
    kv.GetString("flag", g_TeamFlags[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("logo", g_TeamLogos[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("matchtext", g_TeamMatchTexts[matchTeam], MAX_CVAR_LENGTH, "");
    g_TeamSeriesScores[matchTeam] = kv.GetNum("series_score", 0);
    Format(g_FormattedTeamNames[matchTeam], MAX_CVAR_LENGTH, "%s%s{NORMAL}", colorTag, g_TeamNames[matchTeam]);
}

static void LoadDefaultMapList(ArrayList list) {
    list.PushString("de_cache");
    list.PushString("de_cbble");
    list.PushString("de_dust2");
    list.PushString("de_inferno");
    list.PushString("de_mirage");
    list.PushString("de_overpass");
    list.PushString("de_train");
}

public void SetMatchTeamCvars() {
    MatchTeam ctTeam = CSTeamToMatchTeam(CS_TEAM_CT);
    MatchTeam tTeam = CSTeamToMatchTeam(CS_TEAM_T);
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

        MatchTeamStringsToCSTeam(team1Text, team2Text,
            ctMatchText, sizeof(ctMatchText),
            tMatchText, sizeof(tMatchText));
    }

    // Set the match stat text values to display the previous map
    // results for a Bo3 series.
    if (g_MapsToWin == 2 && mapsPlayed >= 1) {
        MatchTeam map1Winner = GetMapWinner(0);
        char map1[PLATFORM_MAX_PATH];
        char map2[PLATFORM_MAX_PATH];
        char map1Display[PLATFORM_MAX_PATH];
        char map2Display[PLATFORM_MAX_PATH];
        g_MapsToPlay.GetString(0, map1, sizeof(map1));
        g_MapsToPlay.GetString(1, map2, sizeof(map2));
        FormatMapName(map1, map1Display, sizeof(map1Display), true);
        FormatMapName(map2, map2Display, sizeof(map2Display), true);

        char team1Text[MAX_CVAR_LENGTH];
        char team2Text[MAX_CVAR_LENGTH];
        if (mapsPlayed == 0) {
            Format(team1Text, sizeof(team1Text), "0");
            Format(team2Text, sizeof(team2Text), "0");

        } else if (mapsPlayed == 1) {
            if (map1Winner == MatchTeam_Team1) {
                Format(team1Text, sizeof(team1Text), "Won %s %d:%d",
                    map1Display,
                    GetMapScore(0, MatchTeam_Team1),
                    GetMapScore(0, MatchTeam_Team2));
                Format(team2Text, sizeof(team2Text), "Lost %s", map1Display);
            } else {
                Format(team1Text, sizeof(team2Text), "Lost %s", map1Display);
                Format(team2Text, sizeof(team1Text), "Won %s %d:%d",
                    map1Display,
                    GetMapScore(0, MatchTeam_Team2),
                    GetMapScore(0, MatchTeam_Team1));
            }

        } else if (mapsPlayed == 2) {
            MatchTeam map2Winner = GetMapWinner(1);
            // Note: you can assume map1winner = map2loser and map2winner = map1loser
            if (map1Winner == MatchTeam_Team1) {
                Format(team1Text, sizeof(team1Text), "Won %s %d:%d",
                    map1Display,
                    GetMapScore(0, map1Winner),
                    GetMapScore(0, map2Winner));
                Format(team2Text, sizeof(team2Text), "Won %s %d:%d",
                    map2Display,
                    GetMapScore(1, map2Winner),
                    GetMapScore(1, map1Winner));
            } else {
                Format(team1Text, sizeof(team1Text), "Won %s %d:%d",
                    map2Display,
                    GetMapScore(1, map2Winner),
                    GetMapScore(1, map1Winner));
                Format(team2Text, sizeof(team2Text), "Won %s %d:%d",
                    map1Display,
                    GetMapScore(0, map1Winner),
                    GetMapScore(0, map2Winner));
            }
        }

        MatchTeamStringsToCSTeam(team1Text, team2Text,
            ctMatchText, sizeof(ctMatchText),
            tMatchText, sizeof(tMatchText));
    }

    SetTeamInfo(CS_TEAM_CT, g_TeamNames[ctTeam],
        g_TeamFlags[ctTeam], g_TeamLogos[ctTeam], ctMatchText);

    SetTeamInfo(CS_TEAM_T, g_TeamNames[tTeam],
        g_TeamFlags[tTeam], g_TeamLogos[tTeam], tMatchText);


    // Set prediction cvars.
    SetConVarStringSafe("mp_teamprediction_txt", g_FavoredTeamText);
    if (g_TeamSide[MatchTeam_Team1] == CS_TEAM_CT)
        SetConVarIntSafe("mp_teamprediction_pct", g_FavoredTeamPercentage);
    else
        SetConVarIntSafe("mp_teamprediction_pct", 100 - g_FavoredTeamPercentage);
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
    char name[MAX_CVAR_LENGTH];
    char value[MAX_CVAR_LENGTH];
    for (int i = 0; i < g_CvarNames.Length; i++) {
        g_CvarNames.GetString(i, name, sizeof(name));
        g_CvarValues.GetString(i, value, sizeof(value));
        ServerCommand("%s %s", name, value);
    }
}

public Action Command_AddPlayer(int client, int args) {
    if (g_GameState == GameState_None) {
        LogError("Cannot change player lists when there is no match to modify");
        return Plugin_Handled;
    }

    char auth[AUTH_LENGTH];
    char teamString[32];
    if (args >= 2 && GetCmdArg(1, auth, sizeof(auth)) && GetCmdArg(2, teamString, sizeof(teamString))) {
        MatchTeam team = MatchTeam_TeamNone;
        if (StrEqual(teamString, "team1"))  {
            team = MatchTeam_Team1;
        } else if (StrEqual(teamString, "team2")) {
            team = MatchTeam_Team2;
        } else if (StrEqual(teamString, "spec")) {
            team = MatchTeam_TeamSpec;
        } else {
            ReplyToCommand(client, "Unknown team: must be one of team1, team2, spec");
            return Plugin_Handled;
        }

        if (AddPlayerToTeam(auth, team)) {
            ReplyToCommand(client, "Successfully added player %s to team %s", auth, teamString);
        } else {
            ReplyToCommand(client, "Failed to add %s to a match team", auth);
        }

    } else {
        ReplyToCommand(client, "Usage: get5_addplayer <auth> <team1|team2|spec>");
    }
    return Plugin_Handled;
}

public Action Command_RemovePlayer(int client, int args) {
    if (g_GameState == GameState_None) {
        LogError("Cannot change player lists when there is no match to modify");
        return Plugin_Handled;
    }

    char auth[AUTH_LENGTH];
    if (args >= 1 && GetCmdArg(1, auth, sizeof(auth))) {
        if (RemovePlayerFromTeams(auth)) {
            ReplyToCommand(client, "Successfully removed player %s", auth);
        } else {
            ReplyToCommand(client, "Failed to remove %s from team auth lists", auth);
        }
    } else {
        ReplyToCommand(client, "Usage: get5_removeplayer <auth>");
    }
    return Plugin_Handled;
}

public Action Command_CreateMatch(int client, int args) {
    if (g_GameState != GameState_None) {
        LogError("Cannot create a match when a match is already loaded");
        return Plugin_Handled;
    }

    char matchid[MATCH_ID_LENGTH] = "manual";
    char matchMap[PLATFORM_MAX_PATH];
    GetCleanMapName(matchMap, sizeof(matchMap));

    if (args >= 1) {
        GetCmdArg(1, matchid, sizeof(matchid));
    } if (args >= 2) {
        GetCmdArg(2, matchMap, sizeof(matchMap));
        if (!IsMapValid(matchMap)) {
            LogError("Invalid map: %s", matchMap);
            return Plugin_Handled;
        }
    }

    char path[PLATFORM_MAX_PATH];
    if (FileExists(path)) {
        DeleteFile(path);
    }

    Format(path, sizeof(path), "get5_%s.cfg", matchid);

    KeyValues kv = new KeyValues("Match");
    kv.SetString("matchid", matchid);
    kv.SetNum("maps_to_win", 1);
    kv.SetNum("skip_veto", 1);
    kv.SetNum("players_per_team", 5);

    kv.JumpToKey("maplist", true);
    kv.SetString(matchMap, "x");
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

    kv.ExportToFile(path);
    delete kv;
    LoadMatchConfig(path);
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
                if (!gotClientName){
                    gotClientName = true;
                    char clientName[MAX_NAME_LENGTH];
                    GetClientName(i, clientName, sizeof(clientName));
                    Format(teamName, sizeof(teamName), "team_%s", clientName);
                }

                count++;
                GetClientAuthId(i, AuthId_SteamID64, auth, sizeof(auth));
                kv.SetString(auth, "x");
            }
        }
    }
    kv.GoBack();
    return count;
}

static void MatchTeamStringsToCSTeam(const char[] team1Str, const char[] team2Str,
    char[] ctStr, int ctLen,
    char[] tStr, int tLen) {
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
    Format(logoPath, sizeof(logoPath),
        "resource/flash/econ/tournaments/teams/%s.png",
        logoName);

    if (FileExists(logoPath)) {
        AddFileToDownloadsTable(logoPath);
    }
}
