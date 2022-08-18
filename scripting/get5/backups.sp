#define TEMP_MATCHCONFIG_BACKUP_PATTERN "get5_match_config_backup%d.txt"
#define TEMP_VALVE_BACKUP_PATTERN "get5_temp_backup%d.txt"

public Action Command_LoadBackup(int client, int args) {
  if (!g_BackupSystemEnabledCvar.BoolValue) {
    ReplyToCommand(client, "The backup system is disabled");
    return Plugin_Handled;
  }

  char path[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, path, sizeof(path))) {
    if (RestoreFromBackup(path)) {
      Get5_MessageToAll("%t", "BackupLoadedInfoMessage", path);
    } else {
      ReplyToCommand(client, "Failed to load backup %s - check error logs", path);
    }
  } else {
    ReplyToCommand(client, "Usage: get5_loadbackup <file>");
  }

  return Plugin_Handled;
}

public Action Command_ListBackups(int client, int args) {
  if (!g_BackupSystemEnabledCvar.BoolValue) {
    ReplyToCommand(client, "The backup system is disabled");
    return Plugin_Handled;
  }

  char matchID[MATCH_ID_LENGTH];
  if (args >= 1) {
    GetCmdArg(1, matchID, sizeof(matchID));
  } else {
    strcopy(matchID, sizeof(matchID), g_MatchID);
  }

  char path[PLATFORM_MAX_PATH];
  g_RoundBackupPathCvar.GetString(path, sizeof(path));
  ReplaceString(path, sizeof(path), "{MATCHID}", matchID);

  DirectoryListing files = OpenDirectory(strlen(path) > 0 ? path : ".");
  if (files != null) {
    char backupInfo[256];
    char pattern[PLATFORM_MAX_PATH];
    Format(pattern, sizeof(pattern), "get5_backup_match%s", matchID);

    char filename[PLATFORM_MAX_PATH];
    while (files.GetNext(filename, sizeof(filename))) {
      if (StrContains(filename, pattern) == 0) {
        Format(filename, sizeof(filename), "%s%s", path, filename);
        if (GetBackupInfo(filename, backupInfo, sizeof(backupInfo))) {
          ReplyToCommand(client, backupInfo);
        } else {
          ReplyToCommand(client, filename);
        }
      }
    }
    delete files;
  }

  return Plugin_Handled;
}

public bool GetBackupInfo(const char[] path, char[] info, int maxlength) {
  KeyValues kv = new KeyValues("Backup");
  if (!kv.ImportFromFile(path)) {
    LogError("Failed to find or read backup file \"%s\"", path);
    delete kv;
    return false;
  }

  char timestamp[64];
  kv.GetString("timestamp", timestamp, sizeof(timestamp));

  char team1Name[MAX_NAME_LENGTH], team2Name[MAX_NAME_LENGTH];

  // Enter Match section.
  kv.JumpToKey("Match");

  kv.JumpToKey("team1");
  kv.GetString("name", team1Name, sizeof(team1Name), "");
  kv.GoBack();

  kv.JumpToKey("team2");
  kv.GetString("name", team2Name, sizeof(team2Name), "");
  kv.GoBack();

  // Exit Match section.
  kv.GoBack();

  if (StrEqual(team1Name, "") || StrEqual(team2Name, "")) {
    LogError("A team name is empty in \"%s\"", path);
    delete kv;
    return false;
  }

  // Try entering Valve's backup section (it doesn't always exist).
  if (!kv.JumpToKey("valve_backup")) {
    Format(info, maxlength, "%s %s \"%s\" \"%s\"", path, timestamp, team1Name, team2Name);
    delete kv;
    return true;
  }

  char map[128];
  kv.GetString("map", map, sizeof(map));

  // Try entering FirstHalfScore section.
  if (!kv.JumpToKey("FirstHalfScore")) {
    Format(info, maxlength, "%s %s \"%s\" \"%s\" %s %d %d", path, timestamp, team1Name, team2Name,
           map, 0, 0);
    delete kv;
    return true;
  }

  int team1Score = kv.GetNum("team1");
  int team2Score = kv.GetNum("team2");

  // Exit FirstHalfScore section.
  kv.GoBack();

  // Try entering SecondHalfScore section.
  if (!kv.JumpToKey("SecondHalfScore")) {
    Format(info, maxlength, "%s %s \"%s\" \"%s\" %s %d %d", path, timestamp, team1Name, team2Name,
           map, team1Score, team2Score);
    delete kv;
    return true;
  }

  team1Score += kv.GetNum("team1");
  team2Score += kv.GetNum("team2");

  // Exit SecondHalfScore section.
  kv.GoBack();
  delete kv;

  Format(info, maxlength, "%s %s \"%s\" \"%s\" %s %d %d", path, timestamp, team1Name, team2Name,
         map, team1Score, team2Score);
  return true;
}

public void WriteBackStructure(const char[] path) {
  KeyValues kv = new KeyValues("Backup");
  char timeString[PLATFORM_MAX_PATH];
  FormatTime(timeString, sizeof(timeString), "%Y-%m-%d %H:%M:%S", GetTime());
  kv.SetString("timestamp", timeString);
  kv.SetString("matchid", g_MatchID);

  char mapName[PLATFORM_MAX_PATH];
  GetCurrentMap(mapName, sizeof(mapName));

  if (g_GameState == Get5State_Veto) {
    kv.SetNum("gamestate", view_as<int>(Get5State_PreVeto));
  } else if (g_GameState == Get5State_Warmup ||
             g_GameState == Get5State_WaitingForKnifeRoundDecision ||
             g_GameState == Get5State_KnifeRound || g_GameState == Get5State_GoingLive ||
             g_GameState == Get5State_PostGame) {
    kv.SetNum("gamestate", view_as<int>(Get5State_Warmup));
  } else if (g_GameState == Get5State_Live) {
    kv.SetNum("gamestate", view_as<int>(Get5State_Live));
  }

  kv.SetNum("team1_side", g_TeamSide[Get5Team_1]);
  kv.SetNum("team2_side", g_TeamSide[Get5Team_2]);

  kv.SetNum("team1_start_side", g_TeamStartingSide[Get5Team_1]);
  kv.SetNum("team2_start_side", g_TeamStartingSide[Get5Team_2]);

  kv.SetNum("team1_series_score", g_TeamSeriesScores[Get5Team_1]);
  kv.SetNum("team2_series_score", g_TeamSeriesScores[Get5Team_2]);

  kv.SetNum("series_draw", g_TeamSeriesScores[Get5Team_None]);

  // Write original maplist.
  kv.JumpToKey("maps", true);
  for (int i = 0; i < g_MapsToPlay.Length; i++) {
    g_MapsToPlay.GetString(i, mapName, sizeof(mapName));
    kv.SetNum(mapName, view_as<int>(g_MapSides.Get(i)));
  }
  kv.GoBack();

  // Write map score history.
  kv.JumpToKey("map_scores", true);
  for (int i = 0; i < g_MapsToPlay.Length; i++) {
    char key[32];
    IntToString(i, key, sizeof(key));

    kv.JumpToKey(key, true);

    kv.SetNum("team1", GetMapScore(i, Get5Team_1));
    kv.SetNum("team2", GetMapScore(i, Get5Team_2));
    kv.GoBack();
  }
  kv.GoBack();

  // Write the original match config data.
  kv.JumpToKey("Match", true);
  WriteMatchToKv(kv);
  kv.GoBack();

  // Write valve's backup format into the file.
  char lastBackup[PLATFORM_MAX_PATH];
  ConVar lastBackupCvar = FindConVar("mp_backup_round_file_last");
  if (g_GameState == Get5State_Live && lastBackupCvar != null) {
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
    LogError("Failed to read backup file \"%s\"", path);
    delete kv;
    return false;
  }

  if (kv.JumpToKey("Match")) {
    char tempBackupFile[PLATFORM_MAX_PATH];
    GetTempFilePath(tempBackupFile, sizeof(tempBackupFile), TEMP_MATCHCONFIG_BACKUP_PATTERN);
    kv.ExportToFile(tempBackupFile);
    if (!LoadMatchConfig(tempBackupFile, true)) {
      delete kv;
      LogError("Could not restore from match config \"%s\"", tempBackupFile);
      if (g_GameState != Get5State_None) {
        // If the backup load fails, all the game configs will have been reset by LoadMatchConfig,
        // but the game state won't. This ensure we don't end up a in a "live" state with no get5
        // variables set, which would prevent a call to load a new match.
        ChangeState(Get5State_None);
      }
      return false;
    }
    kv.GoBack();
  }

  kv.GetString("matchid", g_MatchID, sizeof(g_MatchID));
  g_GameState = view_as<Get5State>(kv.GetNum("gamestate"));

  g_TeamSide[Get5Team_1] = kv.GetNum("team1_side");
  g_TeamSide[Get5Team_2] = kv.GetNum("team2_side");

  g_TeamStartingSide[Get5Team_1] = kv.GetNum("team1_start_side");
  g_TeamStartingSide[Get5Team_2] = kv.GetNum("team2_start_side");

  g_TeamSeriesScores[Get5Team_1] = kv.GetNum("team1_series_score");
  g_TeamSeriesScores[Get5Team_2] = kv.GetNum("team2_series_score");

  // This ensures that the MapNumber logic correctly calculates the map number when there have been
  // draws.
  g_TeamSeriesScores[Get5Team_None] = kv.GetNum("series_draw", 0);

  // Immediately set map number global var to ensure anything below doesn't break.
  g_MapNumber = Get5_GetMapNumber();

  char mapName[PLATFORM_MAX_PATH];
  if (g_GameState > Get5State_Veto) {
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

    if (kv.JumpToKey("map_scores")) {
      if (kv.GotoFirstSubKey()) {
        do {
          char buf[32];
          kv.GetSectionName(buf, sizeof(buf));
          int map = StringToInt(buf);

          int t1 = kv.GetNum("team1");
          int t2 = kv.GetNum("team2");
          g_TeamScoresPerMap.Set(map, t1, view_as<int>(Get5Team_1));
          g_TeamScoresPerMap.Set(map, t2, view_as<int>(Get5Team_2));
        } while (kv.GotoNextKey());
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

  // When loading round 0, there is no valve backup, so we assume round 0 if the game is live,
  // otherwise -1
  int roundNumberRestoredTo = g_GameState == Get5State_Live ? 0 : -1;
  char tempValveBackup[PLATFORM_MAX_PATH];
  GetTempFilePath(tempValveBackup, sizeof(tempValveBackup), TEMP_VALVE_BACKUP_PATTERN);
  if (kv.JumpToKey("valve_backup")) {
    g_SavedValveBackup = true;
    kv.ExportToFile(tempValveBackup);
    roundNumberRestoredTo = kv.GetNum("round", 0);
    kv.GoBack();
  } else {
    g_SavedValveBackup = false;
  }

  char currentMap[PLATFORM_MAX_PATH];
  GetCurrentMap(currentMap, sizeof(currentMap));

  char currentSeriesMap[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(g_MapNumber, currentSeriesMap, sizeof(currentSeriesMap));

  if (!StrEqual(currentMap, currentSeriesMap)) {
    ChangeMap(currentSeriesMap, 1.0);
    g_WaitingForRoundBackup = (g_GameState >= Get5State_Live);

  } else {
    RestoreGet5Backup();
  }

  delete kv;

  LogDebug("Calling Get5_OnBackupRestore()");

  Get5BackupRestoredEvent backupEvent =
      new Get5BackupRestoredEvent(g_MatchID, g_MapNumber, roundNumberRestoredTo, path);

  Call_StartForward(g_OnBackupRestore);
  Call_PushCell(backupEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(backupEvent);

  return true;
}

public void RestoreGet5Backup() {
  // This variable is reset on a timer since the implementation of the
  // mp_backup_restore_load_file doesn't do everything in one frame.
  g_DoingBackupRestoreNow = true;
  ExecCfg(g_LiveCfgCvar); // async
  CreateTimer(0.5, Timer_ExecMatchConfig, _, TIMER_FLAG_NO_MAPCHANGE);

  if (g_SavedValveBackup) {
    ChangeState(Get5State_Live);
    // There are some timing issues leading to incorrect score when restoring matches in second
    // half. Doing the restore on a timer
    CreateTimer(1.0, Time_StartRestore);
  } else {
    SetStartingTeams();
    if (g_GameState == Get5State_Live) {
      EndWarmup();
      EndWarmup();
      ServerCommand("mp_restartgame 5");
      PauseGame(Get5Team_None, Get5PauseType_Backup);
    } else {
      EnsureIndefiniteWarmup();
    }

    g_DoingBackupRestoreNow = false;
  }
}

public Action Timer_ExecMatchConfig(Handle timer) {
  // This needs to go on a callback because ServerCommand("exec") is async, so the config will load
  // *after* the match cvars if we put them in RestoreGet5Backup, which we don't want, as that's not the order in which
  // they were loaded when the match was initially set up.
  SetMatchTeamCvars();
  ExecuteMatchConfigCvars();
  return Plugin_Handled;
}

public Action Time_StartRestore(Handle timer) {
  PauseGame(Get5Team_None, Get5PauseType_Backup);

  char tempValveBackup[PLATFORM_MAX_PATH];
  GetTempFilePath(tempValveBackup, sizeof(tempValveBackup), TEMP_VALVE_BACKUP_PATTERN);
  ServerCommand("mp_backup_restore_load_file \"%s\"", tempValveBackup);
  CreateTimer(0.5, Timer_FinishBackup);
}

public Action Timer_FinishBackup(Handle timer) {
  if (g_CoachingEnabledCvar.BoolValue) {
    // If we are coaching we want to ensure our
    // coaches get moved back onto the team.
    // We cannot trust Valve's system as a disconnected
    // player will count as a "player" and not be placed
    // in the coach slot.
    LOOP_CLIENTS(i) {
      if (IsValidClient(i)) {
        CheckClientTeam(i);
      }
    }
  }
  g_DoingBackupRestoreNow = false;
}

public void DeleteOldBackups() {
  int maxTimeDifference = g_MaxBackupAgeCvar.IntValue;
  if (maxTimeDifference <= 0) {
    LogDebug("Backups are not being deleted as get5_max_backup_age is 0.");
    return;
  }

  char path[PLATFORM_MAX_PATH];
  g_RoundBackupPathCvar.GetString(path, sizeof(path));

  if (StrContains(path, "{MATCHID}") != -1) {
    LogError(
        "Automatic backup deletion cannot be performed when get5_backup_path contains the {MATCHID} variable.");
    return;
  }

  DirectoryListing files = OpenDirectory(strlen(path) > 0 ? path : ".");
  if (files != null) {
    LogDebug("Searching '%s' for expired backups...", path);
    char filename[PLATFORM_MAX_PATH];
    while (files.GetNext(filename, sizeof(filename))) {
      if (StrContains(filename, "get5_backup_") == 0) {
        Format(filename, sizeof(filename), "%s%s", path, filename);
        if (GetTime() - GetFileTime(filename, FileTime_LastChange) >= maxTimeDifference) {
          if (DeleteFileIfExists(filename)) {
            LogDebug("Deleted '%s' as it was older than %d seconds.", filename, maxTimeDifference);
          }
        }
      }
    }
    delete files;
  } else {
    LogError("Failed to list contents of directory '%s' for backup deletion.", path);
  }
}
