#define TEMP_MATCHCONFIG_BACKUP_PATTERN "get5_match_config_backup%d.txt"
#define TEMP_REMOTE_BACKUP_PATTERN      "get5_backup_remote%d.txt"
#define TEMP_VALVE_BACKUP_PATTERN       "get5_temp_backup%d.txt"
#define TEMP_VALVE_NAMES_FILE_PATTERN   "get5_names%d.txt"

Action Command_LoadBackupUrl(int client, int args) {
  if (!g_BackupSystemEnabledCvar.BoolValue) {
    ReplyToCommand(client, "The backup system is disabled.");
    return Plugin_Handled;
  }

  if (g_PendingSideSwap || InHalftimePhase()) {
    ReplyToCommand(client, "You cannot load a backup during halftime.");
    return Plugin_Handled;
  }

  if (IsDoingRestoreOrMapChange()) {
    ReplyToCommand(client, "A map change or backup restore is in progress. You cannot load a backup right now.");
    return Plugin_Handled;
  }

  char url[PLATFORM_MAX_PATH];
  if ((args != 1 && args != 3) || !GetCmdArg(1, url, sizeof(url))) {
    ReplyToCommand(client, "Usage: get5_loadbackup_url <url> [header name] [header value]");
    return Plugin_Handled;
  }

  ArrayList headerNames;
  ArrayList headerValues;
  if (args == 3) {
    headerNames = new ArrayList(PLATFORM_MAX_PATH);
    headerValues = new ArrayList(PLATFORM_MAX_PATH);
    char headerBuffer[PLATFORM_MAX_PATH];
    GetCmdArg(2, headerBuffer, sizeof(headerBuffer));
    headerNames.PushString(headerBuffer);
    GetCmdArg(3, headerBuffer, sizeof(headerBuffer));
    headerValues.PushString(headerBuffer);
  }
  char error[PLATFORM_MAX_PATH];
  if (!LoadBackupFromUrl(url, _, _, headerNames, headerValues, error)) {
    ReplyToCommand(client, "Failed to initiate request for remote backup load: %s", error);
  } else {
    ReplyToCommand(client, "Loading backup from remote...");
  }
  delete headerNames;
  delete headerValues;
  return Plugin_Handled;
}

Action Command_LoadBackup(int client, int args) {
  if (!g_BackupSystemEnabledCvar.BoolValue) {
    ReplyToCommand(client, "The backup system is disabled.");
    return Plugin_Handled;
  }

  char path[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, path, sizeof(path))) {
    char error[PLATFORM_MAX_PATH];
    if (!RestoreFromBackup(path, error)) {
      ReplyToCommand(client, error);
    }
  } else {
    ReplyToCommand(client, "Usage: get5_loadbackup <file>");
  }
  return Plugin_Handled;
}

Action Command_ListBackups(int client, int args) {
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
  bool foundBackups = false;
  if (files != null) {
    char backupInfo[256];
    char pattern[PLATFORM_MAX_PATH];
    FormatEx(pattern, sizeof(pattern), "get5_backup%d_match%s", Get5_GetServerID(), matchID);

    char filename[PLATFORM_MAX_PATH];
    while (files.GetNext(filename, sizeof(filename))) {
      if (StrContains(filename, pattern) == 0) {
        foundBackups = true;
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

  if (!foundBackups) {
    ReplyToCommand(client, "Found no backup files matching the provided parameters.");
  }

  return Plugin_Handled;
}

static bool GetBackupInfo(const char[] path, char[] info, int maxlength) {
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
    FormatEx(info, maxlength, "%s %s \"%s\" \"%s\"", path, timestamp, team1Name, team2Name);
    delete kv;
    return true;
  }

  char map[128];
  kv.GetString("map", map, sizeof(map));

  // Try entering FirstHalfScore section.
  if (!kv.JumpToKey("FirstHalfScore")) {
    FormatEx(info, maxlength, "%s %s \"%s\" \"%s\" %s %d %d", path, timestamp, team1Name, team2Name, map, 0, 0);
    delete kv;
    return true;
  }

  int team1Score = kv.GetNum("team1");
  int team2Score = kv.GetNum("team2");

  // Exit FirstHalfScore section.
  kv.GoBack();

  // Try entering SecondHalfScore section.
  if (!kv.JumpToKey("SecondHalfScore")) {
    FormatEx(info, maxlength, "%s %s \"%s\" \"%s\" %s %d %d", path, timestamp, team1Name, team2Name, map, team1Score,
             team2Score);
    delete kv;
    return true;
  }

  team1Score += kv.GetNum("team1");
  team2Score += kv.GetNum("team2");

  // Exit SecondHalfScore section.
  kv.GoBack();
  delete kv;

  FormatEx(info, maxlength, "%s %s \"%s\" \"%s\" %s %d %d", path, timestamp, team1Name, team2Name, map, team1Score,
           team2Score);
  return true;
}

void WriteBackup() {
  if (!g_BackupSystemEnabledCvar.BoolValue || IsDoingRestoreOrMapChange()) {
    return;
  }

  if (g_PendingSurrenderTeam != Get5Team_None) {
    LogDebug("Not writing backup as there is a pending surrender for team %d.", g_PendingSurrenderTeam);
    return;
  }

  if (g_GameState != Get5State_Warmup && g_GameState != Get5State_KnifeRound && g_GameState != Get5State_Live) {
    LogDebug("Not writing backup for game state %d.", g_GameState);
    return;  // Only backup post-veto warmup, knife and live.
  }

  char folder[PLATFORM_MAX_PATH];
  char variableSubstitutes[][] = {"{MATCHID}"};
  CheckAndCreateFolderPath(g_RoundBackupPathCvar, variableSubstitutes, 1, folder, sizeof(folder));

  char filename[PLATFORM_MAX_PATH];
  if (g_GameState == Get5State_Live) {
    FormatEx(filename, sizeof(filename), "get5_backup%d_match%s_map%d_round%d.cfg", Get5_GetServerID(), g_MatchID,
             g_MapNumber, g_RoundNumber);
  } else {
    FormatEx(filename, sizeof(filename), "get5_backup%d_match%s_map%d_prelive.cfg", Get5_GetServerID(), g_MatchID,
             g_MapNumber);
  }

  char path[PLATFORM_MAX_PATH];
  if (strlen(folder) > 0) {
    FormatEx(path, sizeof(path), "%s%s", folder, filename);
  } else {
    strcopy(path, sizeof(path), filename);
  }

  LogDebug("Writing backup to %s", path);
  if (WriteBackupStructure(path)) {
    g_LastGet5BackupCvar.SetString(path);
    UploadBackupFile(path, filename, g_MatchID, g_MapNumber, g_RoundNumber);
  }
}

static bool WriteBackupStructure(const char[] path) {
  KeyValues kv = new KeyValues("Backup");
  char timeString[PLATFORM_MAX_PATH];
  FormatTime(timeString, sizeof(timeString), "%Y-%m-%d %H:%M:%S", GetTime());
  kv.SetString("timestamp", timeString);
  kv.SetString("matchid", g_MatchID);

  char mapName[PLATFORM_MAX_PATH];
  GetCurrentMap(mapName, sizeof(mapName));

  // Assume warmup; changed to live below if a valve backup exists.
  kv.SetNum("gamestate", view_as<int>(Get5State_Warmup));

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

  kv.SetNum("mapnumber", g_MapNumber);

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
    char lastBackup[PLATFORM_MAX_PATH];
    ConVar lastBackupCvar = FindConVar("mp_backup_round_file_last");
    lastBackupCvar.GetString(lastBackup, sizeof(lastBackup));
    if (strlen(lastBackup) == 0) {
      LogError("Found no Valve backup when attempting to write a backup during the live state. This is a bug!");
      delete kv;
      return false;
    }
    // Write valve's backup format into the file. This only applies to live rounds, as any pre-live
    // backups should just restart the game to warmup (post-veto).
    KeyValues valveBackup = new KeyValues("valve_backup");
    bool success = valveBackup.ImportFromFile(lastBackup);
    if (success) {
      kv.SetNum("gamestate", view_as<int>(Get5State_Live));
      kv.JumpToKey("valve_backup", true);
      KvCopySubkeys(valveBackup, kv);
      kv.GoBack();
    }
    delete valveBackup;
    if (!success) {
      LogError("Failed to import Valve backup into Get5 backup.");
      delete kv;
      return false;
    }
    if (DeleteFile(lastBackup)) {
      lastBackupCvar.SetString("");
    }
  }

  // Write the get5 stats into the file.
  kv.JumpToKey("stats", true);
  KvCopySubkeys(g_StatsKv, kv);
  kv.GoBack();

  bool success = kv.ExportToFile(path);
  if (!success) {
    LogError("Failed to write Get5 backup to file \"%s\".", path);
  }
  delete kv;
  return success;
}

static void UploadBackupFile(const char[] file, const char[] filename, const char[] matchId, const int mapNumber,
                             const int roundNumber) {
  char backupUrl[1024];
  g_RemoteBackupURLCvar.GetString(backupUrl, sizeof(backupUrl));
  if (strlen(backupUrl) == 0) {
    LogDebug("Not uploading backup file as no URL was set.");
    return;
  }

  char error[PLATFORM_MAX_PATH];
  Handle request = CreateGet5HTTPRequest(k_EHTTPMethodPOST, backupUrl, error);
  if (request == INVALID_HANDLE || !AddFileAsHttpBody(request, file, error) ||
      !SetFileNameHeader(request, filename, error) || !SetMatchIdHeader(request, matchId, error) ||
      !SetMapNumberHeader(request, mapNumber, error) || !SetRoundNumberHeader(request, roundNumber, error)) {
    LogError(error);
    delete request;
    return;
  }

  char backupUrlHeaderKey[1024];
  char backupUrlHeaderValue[1024];

  g_RemoteBackupURLHeaderKeyCvar.GetString(backupUrlHeaderKey, sizeof(backupUrlHeaderKey));
  g_RemoteBackupURLHeaderValueCvar.GetString(backupUrlHeaderValue, sizeof(backupUrlHeaderValue));

  if (strlen(backupUrlHeaderKey) > 0 && strlen(backupUrlHeaderValue) > 0 &&
      !SetHeaderKeyValuePair(request, backupUrlHeaderKey, backupUrlHeaderValue, error)) {
    LogError(error);
    delete request;
    return;
  }

  DataPack pack = new DataPack();
  pack.WriteString(backupUrl);
  pack.WriteString(filename);

  SteamWorks_SetHTTPRequestContextValue(request, pack);
  SteamWorks_SetHTTPCallbacks(request, BackupUpload_Callback);
  SteamWorks_SendHTTPRequest(request);
}

static void BackupUpload_Callback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode,
                                  DataPack pack) {
  char url[1024];
  char filename[PLATFORM_MAX_PATH];
  pack.Reset();
  pack.ReadString(url, sizeof(url));
  pack.ReadString(filename, sizeof(filename));
  delete pack;

  if (failure || !requestSuccessful) {
    LogError("Failed to upload backup file '%s' to '%s'. Make sure your URL is enclosed in quotes.", filename, url);
  } else if (!CheckForSuccessfulResponse(request, statusCode)) {
    LogError("Failed to upload backup file '%s' to '%s'. HTTP status code: %d.", filename, url, statusCode);
  }
  delete request;
}

bool RestoreFromBackup(const char[] path, char[] error) {
  if (g_PendingSideSwap || InHalftimePhase()) {
    FormatEx(error, PLATFORM_MAX_PATH, "You cannot load a backup during halftime.");
    return false;
  }

  if (IsDoingRestoreOrMapChange()) {
    FormatEx(error, PLATFORM_MAX_PATH,
             "A map change or backup restore is in progress. You cannot load a backup right now.");
    return false;
  }

  if (!FileExists(path)) {
    FormatEx(error, PLATFORM_MAX_PATH, "Backup file \"%s\" does not exists or cannot be read.", path);
    return false;
  }

  if (!CheckKeyValuesFile(path, error, PLATFORM_MAX_PATH)) {
    Format(error, PLATFORM_MAX_PATH, "Failed to read backup file \"%s\" as valid KeyValues. Error: %s", path, error);
    return false;
  }

  KeyValues kv = new KeyValues("Backup");
  if (!kv.ImportFromFile(path)) {
    FormatEx(error, PLATFORM_MAX_PATH, "Failed to read backup from file: \"%s\".", path);
    delete kv;
    return false;
  }

  int loadedMapNumber = kv.GetNum("mapnumber", -1);
  if (loadedMapNumber == -1) {
    FormatEx(error, PLATFORM_MAX_PATH, "The backup was created with an earlier version of Get5 and is not compatible.");
    delete kv;
    return false;
  }

  char currentMap[PLATFORM_MAX_PATH];
  GetCurrentMap(currentMap, sizeof(currentMap));

  char loadedMatchId[MATCH_ID_LENGTH];
  kv.GetString("matchid", loadedMatchId, sizeof(loadedMatchId));
  char loadedMapName[PLATFORM_MAX_PATH];

  // These gymnastics are required to determine if the backup we are trying to load is for a different
  // map than the one the server is currently on, in which case the StopRecording() call should always
  // be made. We have to loop "maps" twice because:
  // 1. You cannot access KeyValue keys on index, so we can't just grab index "loadedMapNumber"
  // 2. We need to determine if we should stop recording **before** we change the global variables,
  // which the second loop below does.
  if (kv.JumpToKey("maps")) {
    if (kv.GotoFirstSubKey(false)) {
      int index = 0;
      do {
        if (index == loadedMapNumber) {
          kv.GetSectionName(loadedMapName, sizeof(loadedMapName));
          break;
        }
        index++;
      } while (kv.GotoNextKey(false));
      kv.GoBack();
    }
    kv.GoBack();
  }

  bool backupIsForDifferentMap = !StrEqual(currentMap, loadedMapName, false);
  bool backupIsForDifferentMatch = g_GameState != Get5State_Live || g_MapNumber != loadedMapNumber ||
                                backupIsForDifferentMap || !StrEqual(loadedMatchId, g_MatchID);

  if (backupIsForDifferentMatch) {
    // We must stop recording to fire the Get5_OnDemoFinished event when loading a backup to another match or map, and
    // we must do it before we load the match config, or the g_MatchID, g_MapNumber and g_DemoFilePath variables will be
    // incorrect. This is suppressed if we load to the same match and map ID during a live match, either via
    // get5_loadbackup or the !stop-command, as we want only 1 demo file in those cases.
    StopRecording();
  }

  if (kv.JumpToKey("Match")) {
    char tempBackupFile[PLATFORM_MAX_PATH];
    GetTempFilePath(tempBackupFile, sizeof(tempBackupFile), TEMP_MATCHCONFIG_BACKUP_PATTERN);
    kv.ExportToFile(tempBackupFile);
    if (!LoadMatchConfig(tempBackupFile, error, true)) {
      delete kv;
      // If the backup load fails, all the game configs will have been reset by LoadMatchConfig,
      // but the game state won't. This ensures we don't end up a in a "live" state with no get5
      // variables set, which would prevent a call to load a new match.
      ChangeState(Get5State_None);
      return false;
    }
    kv.GoBack();
  }

  if (backupIsForDifferentMatch) {
    // This isn't perfect, but it's better than resetting all pauses used to zero in cases of
    // restore on a new server or a different map. If restoring while live, we just retain the
    // current pauses used, as they should be the "most correct".
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

  g_MapNumber = loadedMapNumber;

  char mapName[PLATFORM_MAX_PATH];
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

  if (kv.JumpToKey("stats")) {
    Stats_Reset();
    KvCopySubkeys(kv, g_StatsKv);
    kv.GoBack();
  }

  // When loading pre-live, there is no Valve backup, so we assume -1.
  bool valveBackup = false;
  int roundNumberRestoredTo = -1;
  if (kv.JumpToKey("valve_backup")) {
    valveBackup = true;
    char tempValveBackup[PLATFORM_MAX_PATH];
    GetTempFilePath(tempValveBackup, sizeof(tempValveBackup), TEMP_VALVE_BACKUP_PATTERN);
    kv.ExportToFile(tempValveBackup);
    roundNumberRestoredTo = kv.GetNum("round", 0);
    kv.GoBack();
  }
  delete kv;

  if (backupIsForDifferentMap) {
    // We don't need to assign players if changing map; this will be done when the players rejoin.
    // If a map is to be changed, we want to suppress all stats events immediately, as the
    // Get5_OnBackupRestore is called now and we don't want events firing after this until the game
    // is live again.
    ChangeState(valveBackup ? Get5State_PendingRestore : Get5State_Warmup);
    ChangeMap(loadedMapName, 3.0);
  } else {
    if (valveBackup && !backupIsForDifferentMatch) {
      // Same map/match, but round restore with a Valve backup; do normal restore immediately with no
      // ready-up and no game-state change. Players' teams are checked after the backup file is loaded.
      RestoreGet5Backup(false);
    } else {
      // We are restarting to the same map for prelive or loading from a none-live state; just go back into
      // warmup and let players ready-up again, either for a restore or for knife/live.
      // Ready status is reset when loading a match config.
      UnpauseGame(Get5Team_None);
      // If we load a valve backup in non-live, we have to go to ready-up, otherwise it's a prelive and we go to warmup.
      ChangeState(valveBackup ? Get5State_PendingRestore : Get5State_Warmup);
      ExecCfg(g_WarmupCfgCvar);
      StartWarmup();
      // We must assign players to their teams. This is normally done inside LoadMatchConfig, but
      // since we need the team sides to be applied from the backup, we skip it then and do it here.
      // We do this *after* putting the game into warmup, as it may otherwise kill people if they are
      // moved the other team, which will trigger various events and cause the game to misbehave.
      if (g_CheckAuthsCvar.BoolValue) {
        LOOP_CLIENTS(i) {
          if (IsPlayer(i)) {
            CheckClientTeam(i);
          }
        }
      }
    }
  }

  LogDebug("Calling Get5_OnBackupRestore()");

  Get5BackupRestoredEvent backupEvent =
    new Get5BackupRestoredEvent(g_MatchID, g_MapNumber, roundNumberRestoredTo, path);

  Call_StartForward(g_OnBackupRestore);
  Call_PushCell(backupEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(backupEvent);

  char fileFormatted[PLATFORM_MAX_PATH];
  FormatCvarName(fileFormatted, sizeof(fileFormatted), path);
  Get5_MessageToAll("%t", "BackupLoadedInfoMessage", fileFormatted);
  g_LastGet5BackupCvar.SetString(path);  // Loading a match config resets this Cvar.
  return true;
}

void RestoreGet5Backup(bool restartRecording) {
  g_DoingBackupRestoreNow = true;  // reset after the backup has completed, suppresses various
                                   // events and hooks until then.
  // If you load a backup during a live round, the game might get stuck if there are only bots
  // remaining and no players are alive. Other stuff will probably also go wrong, so we put the game
  // into warmup. We **cannot** restart the game as that causes problems for tournaments using the
  // logging system.
  if (!InWarmup()) {
    StartWarmup();
  }
  ExecCfg(g_LiveCfgCvar);
  PauseGame(Get5Team_None, Get5PauseType_Backup);
  // We add a 2 second delay here to give the server time to
  // flush the current GOTV recording *if* one is running.
  CreateTimer(2.0, Timer_StartRestore, restartRecording, TIMER_FLAG_NO_MAPCHANGE);
}

static Action Timer_StartRestore(Handle timer, bool restartRecording) {
  if (!g_DoingBackupRestoreNow) {
    return Plugin_Handled;
  }
  ChangeState(Get5State_Live);
  char tempValveBackup[PLATFORM_MAX_PATH];
  GetTempFilePath(tempValveBackup, sizeof(tempValveBackup), TEMP_VALVE_BACKUP_PATTERN);
  ServerCommand("mp_backup_restore_load_file \"%s\"", tempValveBackup);

  // Small delay here as mp_backup_restore_load_file is async.
  CreateTimer(0.5, Timer_FinishBackup, restartRecording, TIMER_FLAG_NO_MAPCHANGE);

  // We need to fire the OnRoundStarted event manually, as it will be suppressed during backups and
  // won't fire while g_DoingBackupRestoreNow is true.
  KeyValues kv = new KeyValues("Backup");
  if (kv.ImportFromFile(tempValveBackup)) {
    Get5RoundStartedEvent startEvent = new Get5RoundStartedEvent(g_MatchID, g_MapNumber, kv.GetNum("round", 0));
    LogDebug("Calling Get5_OnRoundStart() via backup.");
    Call_StartForward(g_OnRoundStart);
    Call_PushCell(startEvent);
    Call_Finish();
    EventLogger_LogAndDeleteEvent(startEvent);
  }
  delete kv;
  return Plugin_Handled;
}

static Action Timer_FinishBackup(Handle timer, bool restartRecording) {
  if (!g_DoingBackupRestoreNow) {
    return Plugin_Handled;
  }
  // This ensures that coaches are moved to their slots.
  if (g_CheckAuthsCvar.BoolValue) {
    LOOP_CLIENTS(i) {
      if (IsPlayer(i)) {
        CheckClientTeam(i);
      }
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
  if (restartRecording) {
    StartRecording();
  }
  return Plugin_Handled;
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
    LogError("Automatic backup deletion cannot be performed when get5_backup_path contains the {MATCHID} variable.");
    return;
  }

  DirectoryListing files = OpenDirectory(strlen(path) > 0 ? path : ".");
  if (files != null) {
    LogDebug("Searching '%s' for expired backups...", path);
    char filename[PLATFORM_MAX_PATH];
    while (files.GetNext(filename, sizeof(filename))) {
      if (StrContains(filename, "get5_backup") == 0) {
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

bool LoadBackupFromUrl(const char[] url, const ArrayList paramNames = null, const ArrayList paramValues = null,
                       const ArrayList headerNames = null, const ArrayList headerValues = null, char[] error) {
  if (!LibraryExists("SteamWorks")) {
    FormatEx(error, PLATFORM_MAX_PATH, "The SteamWorks extension is required in order to load backups over HTTP.");
    return false;
  }

  Handle request = CreateGet5HTTPRequest(k_EHTTPMethodGET, url, error);
  if (request == INVALID_HANDLE || !SetMultipleQueryParameters(request, paramNames, paramValues, error) ||
      !SetMultipleHeaders(request, headerNames, headerValues, error)) {
    delete request;
    return false;
  }

  DataPack pack = new DataPack();
  pack.WriteString(url);

  SteamWorks_SetHTTPRequestContextValue(request, pack);
  SteamWorks_SetHTTPCallbacks(request, LoadBackup_Callback);
  SteamWorks_SendHTTPRequest(request);
  return true;
}

static void LoadBackup_Callback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode,
                                DataPack pack) {

  char loadedUrl[PLATFORM_MAX_PATH];
  pack.Reset();
  pack.ReadString(loadedUrl, sizeof(loadedUrl));
  delete pack;

  if (failure || !requestSuccessful) {
    LogError("Failed to load backup file from '%s'. Make sure your URL is enclosed in quotes.", loadedUrl);
  } else if (!CheckForSuccessfulResponse(request, statusCode)) {
    LogError("Failed to load backup file from '%s'. HTTP status code: %d.", loadedUrl, statusCode);
  } else {
    char remoteBackup[PLATFORM_MAX_PATH];
    char error[PLATFORM_MAX_PATH];
    GetTempFilePath(remoteBackup, sizeof(remoteBackup), TEMP_REMOTE_BACKUP_PATTERN);
    if (SteamWorks_WriteHTTPResponseBodyToFile(request, remoteBackup)) {
      if (!RestoreFromBackup(remoteBackup, error)) {
        LogError(error);
      } else if (FileExists(remoteBackup) && !DeleteFile(remoteBackup)) {
        // We only delete the file if it loads successfully, as it may be used for debugging otherwise.
        LogError("Unable to delete temporary backup file '%s'.", remoteBackup);
      }
    } else {
      LogError("Failed to write temporary backup to file '%s'.", remoteBackup);
    }
  }
  delete request;
}
