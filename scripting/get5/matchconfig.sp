public bool LoadMatchConfig(const char[] config) {
    g_TeamReady[MatchTeam_Team1] = false;
    g_TeamReady[MatchTeam_Team2] = false;
    g_TeamSide[MatchTeam_Team1] = TEAM1_STARTING_SIDE;
    g_TeamSide[MatchTeam_Team2] = TEAM2_STARTING_SIDE;
    g_TeamMapScores[MatchTeam_Team1] = 0;
    g_TeamMapScores[MatchTeam_Team2] = 0;
    g_LastVetoTeam = MatchTeam_Team2;
    g_MapList.Clear();
    g_MapsLeftInVetoPool.Clear();
    g_MapsToPlay.Clear();
    g_CvarNames.Clear();
    g_CvarValues.Clear();

    ClearArray(GetTeamAuths(MatchTeam_TeamSpec));
    ClearArray(GetTeamAuths(MatchTeam_Team1));
    ClearArray(GetTeamAuths(MatchTeam_Team2));

    if (StrContains(config, "json") >= 0) {
        if (!LibraryExists("jansson")) {
            LogError("Cannot load a json config without the smjansson extension loaded");
            return false;
        }

        char configFile[PLATFORM_MAX_PATH];
        strcopy(configFile, sizeof(configFile), config);

        Handle json = json_load_file(configFile);
        if (json != INVALID_HANDLE && LoadMatchFromJson(json)) {
            CloseHandle(json);
            Get5_MessageToAll("Loaded match config.");
        } else {
            LogError("Failed to load match config from %s", config);
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
            LogError("Failed to load match config from %s", config);
            return false;
        }
    }

    // Copy all the maps into the veto pool.
    char mapName[PLATFORM_MAX_PATH];
    for (int i = 0; i < g_MapList.Length; i++) {
        g_MapList.GetString(i, mapName, sizeof(mapName));
        g_MapsLeftInVetoPool.PushString(mapName);
    }

    if (g_SkipVeto) {
        // Copy the first k maps from the maplist to the final match maps.
        for (int i = 0; i < MaxMapsToPlay(g_MapsToWin); i++) {
            g_MapList.GetString(i, mapName, sizeof(mapName));
            g_MapsToPlay.PushString(mapName);
        }

        g_MapList.GetString(0, mapName, sizeof(mapName));
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
            KickClient(i, "You are not a player in ths match");
        }
    }

    ServerCommand("exec %s", WARMUP_CONFIG);
    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();
    EnsurePausedWarmup();
    strcopy(g_LoadedConfigFile, sizeof(g_LoadedConfigFile), config);

    return true;
}

static bool LoadMatchFromKv(KeyValues kv) {
    kv.GetString("matchid", g_MatchID, sizeof(g_MatchID), "matchid");
    g_PlayersPerTeam = kv.GetNum("players_per_team", 5);
    g_MapsToWin = kv.GetNum("maps_to_win", 2);
    g_SkipVeto = kv.GetNum("skip_veto", 0) != 0;

    g_FavoredTeamPercentage = kv.GetNum("favored_percentage_team1", 0);
    kv.GetString("favored_percentage_text", g_FavoredTeamText, sizeof(g_FavoredTeamText));

    if (kv.JumpToKey("spectators")) {
        AddSubsectionKeysToList(kv, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
        kv.GoBack();
    }

    if (kv.JumpToKey("team1")) {
        LoadTeamData(kv, MatchTeam_Team1, "Team1", TEAM1_COLOR);
        kv.GoBack();
    } else {
        LogError("Missing \"team1\" section in match kv");
        return false;
    }

    if (kv.JumpToKey("team2")) {
        LoadTeamData(kv, MatchTeam_Team2, "Team2", TEAM2_COLOR);
        kv.GoBack();
    } else {
        LogError("Missing \"team2\" section in match kv");
        return false;
    }

    if (AddSubsectionKeysToList(kv, "maplist", g_MapList, PLATFORM_MAX_PATH) <= 0) {
        LogError("Failed to find \"maplist\" section in config, using fallback maplist.");
        LoadDefaultMapList(g_MapList);
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

#if defined _jansson_included_
static bool LoadMatchFromJson(Handle json) {
    json_object_get_string_safe(json, "matchid", g_MatchID, sizeof(g_MatchID), "matchid");
    g_PlayersPerTeam = json_object_get_int_safe(json, "players_per_team", 5);
    g_MapsToWin = json_object_get_int_safe(json, "maps_to_win", 2);
    g_SkipVeto = json_object_get_bool_safe(json, "skip_veto", false);

    json_object_get_string_safe(json, "favored_percentage_text", g_FavoredTeamText, sizeof(g_FavoredTeamText), "matchID");
    g_FavoredTeamPercentage = json_object_get_int_safe(json, "favored_percentage_team1", 0);

    Handle spec = json_object_get(json, "spectators");
    if (spec != INVALID_HANDLE) {
        AddJsonSubsectionArrayToList(json, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
        CloseHandle(spec);
    }

    Handle team1 = json_object_get(json, "team1");
    if (team1 != INVALID_HANDLE) {
        LoadTeamDataJson(team1, MatchTeam_Team1, TEAM1_COLOR);
        CloseHandle(team1);
    } else {
        LogError("Missing \"team1\" section in match json");
        return false;
    }

    Handle team2 = json_object_get(json, "team2");
    if (team2 != INVALID_HANDLE) {
        LoadTeamDataJson(team2, MatchTeam_Team2, TEAM2_COLOR);
        CloseHandle(team2);
    } else {
        LogError("Missing \"team2\" section in match json");
        return false;
    }

    if (AddJsonSubsectionArrayToList(json, "maplist", g_MapList, PLATFORM_MAX_PATH) <= 0) {
        LogError("Failed to find \"maplist\" array in match json, using fallback maplist.");
        LoadDefaultMapList(g_MapList);
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

static void LoadTeamDataJson(Handle json, MatchTeam matchTeam, const char[] colorTag) {
    AddJsonSubsectionArrayToList(json, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    json_object_get_string(json, "name", g_TeamNames[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string(json, "flag", g_TeamFlags[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string(json, "logo", g_TeamLogos[matchTeam], MAX_CVAR_LENGTH);
    json_object_get_string(json, "matchtext", g_TeamMatchTexts[matchTeam], MAX_CVAR_LENGTH);
    Format(g_FormattedTeamNames[matchTeam], MAX_CVAR_LENGTH, "%s%s{NORMAL}", colorTag, g_TeamNames[matchTeam]);
}
#endif

static void LoadTeamData(KeyValues kv, MatchTeam matchTeam, const char[] defaultName, const char[] colorTag) {
    AddSubsectionKeysToList(kv, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    kv.GetString("name", g_TeamNames[matchTeam], MAX_CVAR_LENGTH, defaultName);
    kv.GetString("flag", g_TeamFlags[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("logo", g_TeamLogos[matchTeam], MAX_CVAR_LENGTH, "");
    kv.GetString("matchtext", g_TeamMatchTexts[matchTeam], MAX_CVAR_LENGTH, "");
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
    MatchTeam ctTeam = MatchTeam_Team2;
    MatchTeam tTeam = MatchTeam_Team1;
    if (g_TeamSide[MatchTeam_Team1] == CS_TEAM_CT) {
        ctTeam = MatchTeam_Team1;
        tTeam = MatchTeam_Team2;
    }

    // TODO: in a series (longer than 1-map),
    // the current map score (and possibly map history) should be displayed
    // in the match texts instead of the g_TeamMatchTexts values.

    SetTeamInfo(CS_TEAM_CT, g_TeamNames[ctTeam], g_TeamFlags[ctTeam],
        g_TeamLogos[ctTeam], g_TeamMatchTexts[ctTeam]);

    SetTeamInfo(CS_TEAM_T, g_TeamNames[tTeam],
        g_TeamFlags[tTeam], g_TeamLogos[tTeam], g_TeamMatchTexts[tTeam]);

    if (g_MapsToWin >= 2) {
        int mapsPlayed = g_TeamMapScores[MatchTeam_Team1] + g_TeamMapScores[MatchTeam_Team2];
        char mapstat[128];
        Format(mapstat, sizeof(mapstat), "Map %d of %d",
               mapsPlayed + 1, MaxMapsToPlay(g_MapsToWin));
        SetConVarStringSafe("mp_teammatchstat_txt", mapstat);
    }

    // Set prediction cvars.
    SetConVarStringSafe("mp_teamprediction_txt", g_FavoredTeamText);
    if (g_TeamSide[MatchTeam_Team1] == CS_TEAM_CT)
        SetConVarIntSafe("mp_teamprediction_pct", g_FavoredTeamPercentage);
    else
        SetConVarIntSafe("mp_teamprediction_pct", 100 - g_FavoredTeamPercentage);
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
        GetTeamAuths(team).PushString(auth);
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
        for (int i = 0; i < view_as<int>(MatchTeam_Count); i++) {
            MatchTeam team = view_as<MatchTeam>(i);
            if (RemoveAuthFromArray(GetTeamAuths(team), auth)) {
                ReplyToCommand(client, "Successfully removed player %s", auth);
                int target = AuthToClient(auth);
                if (IsAuthedPlayer(target)) {
                    KickClient(target, "You are not a player in this match");
                }
            }
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
                GetClientAuthId(i, AUTH_METHOD, auth, sizeof(auth));
                kv.SetString(auth, "x");
            }
        }
    }
    kv.GoBack();
    return count;
}
