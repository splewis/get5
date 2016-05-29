#define TEMP_BACKUP_FILE "get5_temp_backup.txt"

public Action Command_LoadBackup(int client, int args) {
    if (g_BackupSystemEnabledCvar.IntValue == 0) {
        ReplyToCommand(client, "The backup system is disabled");
        return Plugin_Handled;
    }

    char path[PLATFORM_MAX_PATH];
    if (args >= 1 && GetCmdArg(1, path, sizeof(path))) {
        if (RestoreFromBackup(path)) {
            Get5_MessageToAll("Successfully loaded backup %s", path);
        } else {
            ReplyToCommand(client, "Failed to load backup %s - check error logs", path);
        }
    } else {
        ReplyToCommand(client, "Usage: get5_loadbackup <file>");
    }

    return Plugin_Handled;
}

public Action Command_ListBackups(int client, int args) {
    if (g_BackupSystemEnabledCvar.IntValue == 0) {
        ReplyToCommand(client, "The backup system is disabled");
        return Plugin_Handled;
    }
    char matchID[MATCH_ID_LENGTH];
    if (args >= 1) {
        GetCmdArg(1, matchID, sizeof(matchID));
    } else {
        strcopy(matchID, sizeof(matchID), g_MatchID);
    }

    char pattern[PLATFORM_MAX_PATH];
    Format(pattern, sizeof(pattern), "get5_backup_match%s", matchID);

    DirectoryListing files = OpenDirectory(".");
    if (files != null) {
        char path[PLATFORM_MAX_PATH];
        while (files.GetNext(path, sizeof(path))) {
            if (StrContains(path, pattern) == 0) {
                ReplyToCommand(client, path);
            }
        }
        delete files;
    }

    return Plugin_Handled;
}

public void WriteBackStructure(const char[] path) {
    KeyValues kv = new KeyValues("Backup");
    char timeString[PLATFORM_MAX_PATH];
    FormatTime(timeString, sizeof(timeString), "%Y-%m-%d %H:%M:%S", GetTime());
    kv.SetString("timestamp", timeString);
    kv.SetString("matchid", g_MatchID);
    kv.SetString("match_config", g_LoadedConfigFile);

    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));

    if (g_GameState == GameState_Veto) {
        kv.SetNum("gamestate", view_as<int>(GameState_PreVeto));
    } else if (g_GameState == GameState_Warmup ||
               g_GameState == GameState_WaitingForKnifeRoundDecision ||
               g_GameState == GameState_KnifeRound ||
               g_GameState == GameState_GoingLive ||
               g_GameState == GameState_PostGame) {
        kv.SetNum("gamestate", view_as<int>(GameState_Warmup));
    } else if (g_GameState == GameState_Live) {
        kv.SetNum("gamestate", view_as<int>(GameState_Live));
    }

    kv.SetNum("team1_side", g_TeamSide[MatchTeam_Team1]);
    kv.SetNum("team2_side", g_TeamSide[MatchTeam_Team2]);
    kv.SetNum("team1_start_side", g_TeamStartingSide[MatchTeam_Team1]);
    kv.SetNum("team2_start_side", g_TeamStartingSide[MatchTeam_Team2]);

    kv.SetNum("team1_series_score", g_TeamSeriesScores[MatchTeam_Team1]);
    kv.SetNum("team2_series_score", g_TeamSeriesScores[MatchTeam_Team2]);

    kv.JumpToKey("maps", true);
    for (int i = 0; i < g_MapsToPlay.Length; i++) {
        g_MapsToPlay.GetString(i, mapName, sizeof(mapName));
        kv.SetNum(mapName, view_as<int>(g_MapSides.Get(i)));
    }
    kv.GoBack();

    // Write valve's backup format into the file.
    char lastBackup[PLATFORM_MAX_PATH];
    ConVar lastBackupCvar = FindConVar("mp_backup_round_file_last");
    if (g_GameState == GameState_Live && lastBackupCvar != null) {
        lastBackupCvar.GetString(lastBackup, sizeof(lastBackup));
        KeyValues valveBackup = new KeyValues("valve_backup");
        if (valveBackup.ImportFromFile(lastBackup)) {
            kv.JumpToKey("valve_backup", true);
            KvCopySubkeys(valveBackup, kv);
            kv.GoBack();
        }
        delete valveBackup;
    }

    // Write the get5 stats into the file.
    kv.JumpToKey("stats", true);
    KvCopySubkeys(g_StatsKv, kv);
    kv.GoBack();

    kv.ExportToFile(path);
    delete kv;
}

public bool RestoreFromBackup(const char[] path) {
    KeyValues kv = new KeyValues("Backup");
    if (!kv.ImportFromFile(path)) {
        LogError("Failed to find read backup file \"%s\"", path);
        delete kv;
        return false;
    }

    char matchconfig[PLATFORM_MAX_PATH];
    kv.GetString("match_config", matchconfig, sizeof(matchconfig));
    if (!LoadMatchConfig(matchconfig, true)) {
        delete kv;
        LogError("Could not restore from match config \"%s\"", matchconfig);
        return false;
    }

    kv.GetString("matchid", g_MatchID, sizeof(g_MatchID));
    g_GameState = view_as<GameState>(kv.GetNum("gamestate"));

    g_TeamSide[MatchTeam_Team1] = kv.GetNum("team1_side");
    g_TeamSide[MatchTeam_Team2] = kv.GetNum("team2_side");

    g_TeamStartingSide[MatchTeam_Team1] = kv.GetNum("team1_start_side");
    g_TeamStartingSide[MatchTeam_Team2] = kv.GetNum("team2_start_side");

    g_TeamSeriesScores[MatchTeam_Team1] = kv.GetNum("team1_series_score");
    g_TeamSeriesScores[MatchTeam_Team2] = kv.GetNum("team2_series_score");

    char mapName[PLATFORM_MAX_PATH];
    if (g_GameState > GameState_Veto) {
        if (kv.JumpToKey("maps")) {
            g_MapsToPlay.Clear();
            g_MapSides.Clear();
            if (kv.GotoFirstSubKey(false)) {
                do {
                    kv.GetSectionName(mapName, sizeof(mapName));
                    SideChoice sides = view_as<SideChoice>(kv.GetNum(NULL_STRING));
                    g_MapsToPlay.PushString(mapName);
                    g_MapSides.Push(sides);
                } while (kv.GotoNextKey(false));
                kv.GoBack();
            }
            kv.GoBack();
        }
    }

    if (kv.JumpToKey("stats")) {
        Stats_Reset();
        KvCopySubkeys(kv, g_StatsKv);
        kv.GoBack();
    }

    if (kv.JumpToKey("valve_backup")) {
        g_SavedValveBackup = true;
        kv.ExportToFile(TEMP_BACKUP_FILE);
        kv.GoBack();
    } else {
        g_SavedValveBackup = false;
    }

    char currentMap[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));

    char currentSeriesMap[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(GetMapNumber(), currentSeriesMap, sizeof(currentSeriesMap));
    LogMessage("currentMap = %s, currentSeriesMap = %s", currentMap, currentSeriesMap);

    if (!StrEqual(currentMap, currentSeriesMap)) {
        ChangeMap(currentSeriesMap, 1.0);
        g_WaitingForRoundBackup = (g_GameState >= GameState_Live);

    } else {
        RestoreGet5Backup();
        Pause();
    }

    delete kv;

    Call_StartForward(g_OnBackupRestore);
    Call_Finish();

    return true;
}

public void RestoreGet5Backup() {
    ExecCfg(g_LiveCfgCvar);

    if (g_SavedValveBackup) {
        // ServerCommand("mp_teamname_1 \"\"");
        // ServerCommand("mp_teamname_2 \"\"");
        ServerCommand("mp_backup_restore_load_file \"%s\"", TEMP_BACKUP_FILE);
        Pause();

    } else {
        SetStartingTeams();
        SetMatchTeamCvars();
        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i))
                CheckClientTeam(i);
        }

        EndWarmup();
        EndWarmup();
        ServerCommand("mp_restartgame 5");

    }

    ChangeState(GameState_Live);
}

public void DeleteOldBackups() {
    int maxTimeDifference = g_MaxBackupAgeCvar.IntValue;
    if (maxTimeDifference <= 0) {
        return;
    }

    DirectoryListing files = OpenDirectory(".");
    if (files != null) {
        char path[PLATFORM_MAX_PATH];
        while (files.GetNext(path, sizeof(path))) {
            if (StrContains(path, "get5_backup_") == 0 &&
                GetTime() - GetFileTime(path, FileTime_LastChange) >= maxTimeDifference) {
                DeleteFile(path);
            }
        }
        delete files;
    }
}
