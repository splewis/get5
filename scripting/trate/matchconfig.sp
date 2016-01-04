public bool LoadMatchConfig(const char[] config) {
    g_TeamReady[MatchTeam_Team1] = false;
    g_TeamReady[MatchTeam_Team2] = false;
    g_TeamSide[MatchTeam_Team1] = TEAM1_STARTING_SIDE;
    g_TeamSide[MatchTeam_Team2] = TEAM2_STARTING_SIDE;
    g_TeamMapScores[MatchTeam_Team1] = 0;
    g_TeamMapScores[MatchTeam_Team2] = 0;
    g_LastVetoTeam = MatchTeam_Team2;


    KeyValues kv = new KeyValues("Match");
    if (kv.ImportFromFile(config) && LoadMatchFromKv(kv)) {
        delete kv;
        Trate_MessageToAll("Loaded match config.");
    } else {
        delete kv;
        LogError("Failed to load match config from %s", config);
        return false;
    }

    if (g_SkipVeto) {
        // Copy the first k maps from the maplist to the final match maps.
        for (int i = 0; i < MaxMapsToPlay(g_MapsToWin); i++) {
            char mapName[PLATFORM_MAX_PATH];
            g_MapList.GetString(i, mapName, sizeof(mapName));
            g_MapsToPlay.PushString(mapName);
        }

        char mapName[PLATFORM_MAX_PATH];
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

    ClearArray(GetTeamAuths(MatchTeam_TeamSpec));
    if (kv.JumpToKey("spectators")) {
        AddSubsectionKeysToList(kv, GetTeamAuths(MatchTeam_TeamSpec), AUTH_LENGTH, "players");
        kv.GoBack();
    }

    ClearArray(GetTeamAuths(MatchTeam_Team1));
    if (kv.JumpToKey("team1")) {
        LoadTeamData(kv, MatchTeam_Team1, "Team1", "{LIGHT_GREEN}");
        kv.GoBack();
    } else {
        LogError("Missing \"team1\" section in match kv");
        return false;
    }

    ClearArray(GetTeamAuths(MatchTeam_Team2));
    if (kv.JumpToKey("team2")) {
        LoadTeamData(kv, MatchTeam_Team2, "Team2", "{PINK}");
        kv.GoBack();
    } else {
        LogError("Missing \"team2\" section in match kv");
        return false;
    }

    g_MapList.Clear();
    g_MapsToPlay.Clear();
    if (AddSubsectionKeysToList(kv, g_MapList, PLATFORM_MAX_PATH, "maplist") <= 0) {
        LogError("Failed to find \"maplist\" section in config, using fallback maplist.");
        LoadDefaultMapList(g_MapList);
    }

    // Copy all the maps into the veto pool.
    g_MapsLeftInVetoPool.Clear();
    char mapName[PLATFORM_MAX_PATH];
    for (int i = 0; i < g_MapList.Length; i++) {
        g_MapList.GetString(i, mapName, sizeof(mapName));
        g_MapsLeftInVetoPool.PushString(mapName);
    }

    g_CvarNames.Clear();
    g_CvarValues.Clear();
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

static void LoadTeamData(KeyValues kv, MatchTeam matchTeam, const char[] defaultName, const char[] colorTag) {
    AddSubsectionKeysToList(kv, GetTeamAuths(matchTeam), AUTH_LENGTH, "players");
    kv.GetString("name", g_TeamNames[matchTeam], TEAM_NAME_LENGTH, defaultName);
    kv.GetString("flag", g_TeamFlags[matchTeam], TEAM_FLAG_LENGTH, "");
    kv.GetString("logo", g_TeamLogos[matchTeam], TEAM_LOGO_LENGTH, "");
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
