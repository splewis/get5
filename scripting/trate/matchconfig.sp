#include "../include/jsonhelpers.inc"

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

    LogDebug("%d", StrContains(config, "json"));
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
            Trate_MessageToAll("Loaded match config.");
        } else {
            LogError("Failed to load match config from %s", config);
            return false;
        }
    } else {
        // Assume its a keyvalues file.
        KeyValues kv = new KeyValues("Match");
        if (kv.ImportFromFile(config) && LoadMatchFromKv(kv)) {
            delete kv;
            Trate_MessageToAll("Loaded match config.");
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
        ChangeMap(mapName);
    } else {
        ChangeState(GameState_PreVeto);
    }

    ExecuteMatchConfigCvars();
    SetMatchTeamCvars();
    EnsurePausedWarmup();
    strcopy(g_LoadedConfigFile, sizeof(g_LoadedConfigFile), config);

    return true;
}

static bool LoadMatchFromKv(KeyValues kv) {
    kv.GetString("matchid", g_MatchID, sizeof(g_MatchID), "matchID");
    g_PlayersPerTeam = kv.GetNum("players_per_team", 5);
    g_MapsToWin = kv.GetNum("maps_to_win", 2);
    g_SkipVeto = kv.GetNum("skip_veto", 0) != 0;

    if (kv.JumpToKey("spectators")) {
        AddSubsectionKeysToList(kv, GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH, "players");
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

    if (AddSubsectionKeysToList(kv, g_MapList, PLATFORM_MAX_PATH, "maplist") <= 0) {
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

static bool LoadMatchFromJson(Handle json) {
    json_object_get_string_safe(json, "matchid", g_MatchID, sizeof(g_MatchID), "matchID");
    g_PlayersPerTeam = json_object_get_int_safe(json, "players_per_team", 5);
    g_MapsToWin = json_object_get_int_safe(json, "maps_to_win", 2);
    g_SkipVeto = json_object_get_int_safe(json, "skip_veto", 0) != 0;

    Handle spec = json_object_get(json, "spectators");
    if (spec != INVALID_HANDLE) {
        JsonSubsectionArrayToList(json, "players", GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH);
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

    if (JsonSubsectionArrayToList(json, "maplist", g_MapList, PLATFORM_MAX_PATH) <= 0) {
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

static void LoadTeamData(KeyValues kv, MatchTeam matchTeam, const char[] defaultName, const char[] colorTag) {
    AddSubsectionKeysToList(kv, GetTeamAuths(matchTeam), AUTH_LENGTH, "players");
    kv.GetString("name", g_TeamNames[matchTeam], TEAM_NAME_LENGTH, defaultName);
    kv.GetString("flag", g_TeamFlags[matchTeam], TEAM_FLAG_LENGTH, "");
    kv.GetString("logo", g_TeamLogos[matchTeam], TEAM_LOGO_LENGTH, "");
    Format(g_FormattedTeamNames[matchTeam], TEAM_NAME_LENGTH, "%s%s{NORMAL}", colorTag, g_TeamNames[matchTeam]);
}

static void LoadTeamDataJson(Handle json, MatchTeam matchTeam, const char[] colorTag) {
    JsonSubsectionArrayToList(json, "players", GetTeamAuths(matchTeam), AUTH_LENGTH);
    json_object_get_string(json, "name", g_TeamNames[matchTeam], TEAM_NAME_LENGTH);
    json_object_get_string(json, "flag", g_TeamFlags[matchTeam], TEAM_FLAG_LENGTH);
    json_object_get_string(json, "logo", g_TeamLogos[matchTeam], TEAM_LOGO_LENGTH);
    Format(g_FormattedTeamNames[matchTeam], TEAM_NAME_LENGTH, "%s%s{NORMAL}", colorTag, g_TeamNames[matchTeam]);
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

    int mapsPlayed = g_TeamMapScores[MatchTeam_Team1] + g_TeamMapScores[MatchTeam_Team2];
    SetTeamInfo(CS_TEAM_CT, g_TeamNames[ctTeam], g_TeamFlags[ctTeam], g_TeamLogos[ctTeam]);
    SetTeamInfo(CS_TEAM_T, g_TeamNames[tTeam], g_TeamFlags[tTeam], g_TeamLogos[tTeam]);

    char mapstat[128];
    Format(mapstat, sizeof(mapstat), "Map %d of %d",
           mapsPlayed + 1, MaxMapsToPlay(g_MapsToWin));
    SetConVarStringSafe("mp_teammatchstat_txt", mapstat);
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
