#define TEMP_MATCHCONFIG_BACKUP_PATTERN "get5_match_config_backup%d.txt"
#define TEMP_VALVE_BACKUP_PATTERN "get5_temp_backup%d.txt"
#define TEMP_VALVE_NAMES_FILE_PATTERN "get5_names%d.txt"

public Action Command_LoadBackup(int client, int args) {
  if (!g_BackupSystemEnabledCvar.BoolValue) {
    ReplyToCommand(client, "The backup system is disabled.");
    return Plugin_Handled;
  }

  if (g_PendingSideSwap || InHalftimePhase()) {
    ReplyToCommand(client, "You cannot load a backup during halftime.");
    return Plugin_Handled;
  }

  char path[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, path, sizeof(path))) {
    if (RestoreFromBackup(path)) {
      Get5_MessageToAll("%t", "BackupLoadedInfoMessage", path);
      g_LastGet5BackupCvar.SetString(path);
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

bool GetBackupInfo(const char[] path, char[] info, int maxlength) {
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

void WriteBackupStructure(const char[] path) {
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

  kv.SetNum("team1_tac_pauses_used", g_TacticalPausesUsed[Get5Team_1]);
  kv.SetNum("team2_tac_pauses_used", g_TacticalPausesUsed[Get5Team_2]);
  kv.SetNum("team1_tech_pauses_used", g_TechnicalPausesUsed[Get5Team_1]);
  kv.SetNum("team2_tech_pauses_used", g_TechnicalPausesUsed[Get5Team_2]);
  kv.SetNum("team1_pause_time_used", g_TacticalPauseTimeUsed[Get5Team_1]);
  kv.SetNum("team2_pause_time_used", g_TacticalPauseTimeUsed[Get5Team_2]);

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

  if (g_GameState == Get5State_Live) {
    // Write valve's backup format into the file. This only applies to live rounds, as any pre-live backups should
    // just restart the game to the knife round.
    char lastBackup[PLATFORM_MAX_PATH];
    ConVar lastBackupCvar = FindConVar("mp_backup_round_file_last");
    if (lastBackupCvar != null) {
      lastBackupCvar.GetString(lastBackup, sizeof(lastBackup));
      KeyValues valveBackup = new KeyValues("valve_backup");
      if (valveBackup.ImportFromFile(lastBackup)) {
        kv.JumpToKey("valve_backup", true);
        KvCopySubkeys(valveBackup, kv);
        kv.GoBack();
      }
      delete valveBackup;
    }
  }

  // Write the get5 stats into the file.
  kv.JumpToKey("stats", true);
  KvCopySubkeys(g_StatsKv, kv);
  kv.GoBack();

  kv.ExportToFile(path);
  delete kv;
}

bool RestoreFromBackup(const char[] path, bool restartRecording = true) {
  KeyValues kv = new KeyValues("Backup");
  if (!kv.ImportFromFile(path)) {
    LogError("Failed to read backup file \"%s\"", path);
    delete kv;
    return false;
  }

  if (restartRecording) {
    // We must stop recording when loading a backup, and we must do it before we load the match config, or the g_MatchID
    // variable will be incorrect. This is suppressed when using the !stop command.
    StopRecording();
  }

  if (kv.JumpToKey("Match")) {
    char tempBackupFile[PLATFORM_MAX_PATH];
    GetTempFilePath(tempBackupFile, sizeof(tempBackupFile), TEMP_MATCHCONFIG_BACKUP_PATTERN);
    kv.ExportToFile(tempBackupFile);
    if (!LoadMatchConfig(tempBackupFile, true)) {
      delete kv;
      LogError("Could not restore from match config \"%s\"", tempBackupFile);
      // If the backup load fails, all the game configs will have been reset by LoadMatchConfig,
      // but the game state won't. This ensures we don't end up a in a "live" state with no get5
      // variables set, which would prevent a call to load a new match.
      ChangeState(Get5State_None);
      return false;
    }
    kv.GoBack();
  }

  if (g_GameState != Get5State_Live) {
    // This isn't perfect, but it's better than resetting all pauses used to zero in cases of restore on a new server.
    // If restoring while live, we just retain the current pauses used, as they should be the "most correct".
    g_TacticalPausesUsed[Get5Team_1] = kv.GetNum("team1_tac_pauses_used", 0);
    g_TacticalPausesUsed[Get5Team_2] = kv.GetNum("team2_tac_pauses_used", 0);
    g_TechnicalPausesUsed[Get5Team_1] = kv.GetNum("team1_tech_pauses_used", 0);
    g_TechnicalPausesUsed[Get5Team_2] = kv.GetNum("team2_tech_pauses_used", 0);
    g_TacticalPauseTimeUsed[Get5Team_1] = kv.GetNum("team1_pause_time_used", 0);
    g_TacticalPauseTimeUsed[Get5Team_2] = kv.GetNum("team2_pause_time_used", 0);
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

  // When loading pre-live, there is no Valve backup, so we assume -1.
  g_WaitingForRoundBackup = false;
  int roundNumberRestoredTo = -1;
  if (kv.JumpToKey("valve_backup")) {
    g_WaitingForRoundBackup = true;
    char tempValveBackup[PLATFORM_MAX_PATH];
    GetTempFilePath(tempValveBackup, sizeof(tempValveBackup), TEMP_VALVE_BACKUP_PATTERN);
    kv.ExportToFile(tempValveBackup);
    roundNumberRestoredTo = kv.GetNum("round", 0);
    kv.GoBack();
  }

  char currentMap[PLATFORM_MAX_PATH];
  GetCurrentMap(currentMap, sizeof(currentMap));

  char currentSeriesMap[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(g_MapNumber, currentSeriesMap, sizeof(currentSeriesMap));

  if (!StrEqual(currentMap, currentSeriesMap)) {
    // We don't need to assign players if changing map; this will be done when the players rejoin.
    ChangeMap(currentSeriesMap, 3.0);
  } else {
    // We must assign players to their teams. This is normally done inside LoadMatchConfig, but since we need
    // the team sides to be applied from the backup, we skip it then and do it here.
    LOOP_CLIENTS(i) {
      if (IsPlayer(i)) {
        CheckClientTeam(i);
      }
    }
    if (g_WaitingForRoundBackup) {
      // Same map, but round restore with a Valve backup; do normal restore immediately with no ready-up.
      RestoreGet5Backup(restartRecording);
    } else {
      // We are restarting to the same map for prelive; just go back into warmup and let players ready-up again.
      ResetReadyStatus();
      UnpauseGame(Get5Team_None);
      ChangeState(Get5State_Warmup);
      ExecCfg(g_WarmupCfgCvar);
      StartWarmup();
    }
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

void RestoreGet5Backup(bool restartRecording = true) {
  // If you load a backup during a live round, the game might get stuck if there are only bots remaining and no
  // players are alive. Other stuff will probably also go wrong, so we just reset the game before loading the
  // backup to avoid any weird edge-cases.
  if (!InWarmup()) {
   RestartGame();
  }
  ExecCfg(g_LiveCfgCvar);
  PauseGame(Get5Team_None, Get5PauseType_Backup);
  g_DoingBackupRestoreNow = true; // reset after the backup has completed, suppresses various events and hooks until then.
  g_WaitingForRoundBackup = false;
  CreateTimer(1.5, Time_StartRestore);
  if (restartRecording) {
    // Since a backup command forces the recording to stop, we restart it here once the backup has completed.
    // We have to do this on a delay, as when loading from a live game, the backup will already be recording and must
    // flush before a new record command can be issued. This is suppressed when using the !stop command!
    CreateTimer(3.0, Timer_StartRecordingAfterBackup, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action Timer_StartRecordingAfterBackup(Handle timer) {
  if (g_GameState != Get5State_Live) {
    return;
  }
  StartRecording();
}

public Action Time_StartRestore(Handle timer) {
  ChangeState(Get5State_Live);
  char tempValveBackup[PLATFORM_MAX_PATH];
  GetTempFilePath(tempValveBackup, sizeof(tempValveBackup), TEMP_VALVE_BACKUP_PATTERN);
  ServerCommand("mp_backup_restore_load_file \"%s\"", tempValveBackup);
  CreateTimer(0.5, Timer_FinishBackup);
}

public Action Timer_FinishBackup(Handle timer) {
  // This ensures that coaches are moved to their slots.
  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      CheckClientTeam(i);
    }
  }
  g_DoingBackupRestoreNow = false;
  // Delete the temporary backup file we just wrote and restored from.
  char tempValveBackup[PLATFORM_MAX_PATH];
  GetTempFilePath(tempValveBackup, sizeof(tempValveBackup), TEMP_VALVE_BACKUP_PATTERN);
  if (DeleteFile(tempValveBackup)) {
    LogDebug("Deleted temp valve backup file: %s", tempValveBackup);
  } else {
    LogDebug("Failed to delete temp valve backup file: %s", tempValveBackup);
  }
}

void DeleteOldBackups() {
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
