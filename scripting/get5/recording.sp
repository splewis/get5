bool StartRecording() {
  char demoFormat[PLATFORM_MAX_PATH];
  g_DemoNameFormatCvar.GetString(demoFormat, sizeof(demoFormat));
  if (StrEqual("", demoFormat)) {
    LogMessage("Demo recording is disabled via get5_demo_name_format.");
    return false;
  }

  if (!IsTVEnabled()) {
    LogError("Demo recording will not work with \"tv_enable 0\". Set \"tv_enable 1\" and restart the map to fix this.");
    g_DemoFilePath = "";
    g_DemoFileName = "";
    return false;
  }

  char demoName[PLATFORM_MAX_PATH + 1];
  if (!FormatCvarString(g_DemoNameFormatCvar, demoName, sizeof(demoName))) {
    LogError("Failed to format demo filename. Please check your demo file format ConVar.");
    g_DemoFilePath = "";
    g_DemoFileName = "";
    return false;
  }

  char demoFolder[PLATFORM_MAX_PATH];
  char variableSubstitutes[][] = {"{MATCHID}", "{DATE}"};
  CheckAndCreateFolderPath(g_DemoPathCvar, variableSubstitutes, 2, demoFolder, sizeof(demoFolder));

  // If there is no path (folder empty string), this just becomes = demoName
  char demoPath[PLATFORM_MAX_PATH];
  FormatEx(demoPath, sizeof(demoPath), "%s%s", demoFolder, demoName);
  // Escape unsafe characters and start recording. .dem is appended to the filename automatically.
  ReplaceString(demoPath, sizeof(demoPath), "\"", "\\\"");
  ServerCommand("tv_record \"%s\"", demoPath);

  // Global reference needs the .dem file extension for the uploader to be able to find the file.
  FormatEx(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
  FormatEx(g_DemoFilePath, sizeof(g_DemoFilePath), "%s%s", demoFolder, g_DemoFileName);
  LogMessage("Recording to %s", g_DemoFilePath);
  Stats_SetDemoName(g_DemoFilePath);
  return true;
}

void StopRecording(float delay = 0.0) {
  if (StrEqual("", g_DemoFilePath)) {
    LogDebug("Demo was not recorded by Get5; not firing Get5_OnDemoFinished().");
    ServerCommand("tv_stoprecord");
    return;
  }
  char uploadUrl[1024];
  g_DemoUploadURLCvar.GetString(uploadUrl, sizeof(uploadUrl));
  char uploadUrlHeaderKey[1024];
  g_DemoUploadHeaderKeyCvar.GetString(uploadUrlHeaderKey, sizeof(uploadUrlHeaderKey));
  char uploadUrlHeaderValue[1024];
  g_DemoUploadHeaderValueCvar.GetString(uploadUrlHeaderValue, sizeof(uploadUrlHeaderValue));
  DataPack pack = GetDemoInfoDataPack(g_MatchID, g_MapNumber, g_DemoFilePath, g_DemoFileName, uploadUrl,
                                      uploadUrlHeaderKey, uploadUrlHeaderValue, g_DemoUploadDeleteAfterCvar.BoolValue);
  if (delay < 0.1) {
    LogDebug("Stopping GOTV recording immediately.");
    StopRecordingCallback(pack);
  } else {
    LogDebug("Starting timer that will end GOTV recording in %f seconds.", delay);
    CreateTimer(delay, Timer_StopGoTVRecording, pack);
  }
  g_DemoFilePath = "";
  g_DemoFileName = "";
}

static Action Timer_StopGoTVRecording(Handle timer, DataPack pack) {
  StopRecordingCallback(pack);
  return Plugin_Handled;
}

static void StopRecordingCallback(DataPack pack) {
  ServerCommand("tv_stoprecord");
  // We delay this by 15 seconds to allow the server to flush to the file before firing the event.
  // For some servers, this take a pretty long time (up to 8-9 seconds, so 15 for grace).
  CreateTimer(15.0, Timer_FireStopRecordingEvent, pack);
}

static Action Timer_FireStopRecordingEvent(Handle timer, DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFilePath[PLATFORM_MAX_PATH];
  char demoFileName[PLATFORM_MAX_PATH];
  int mapNumber;
  char uploadUrl[1024];
  char uploadUrlHeaderKey[1024];
  char uploadUrlHeaderValue[1024];
  bool deleteAfterUpload;
  ReadDemoDataPack(pack, matchId, sizeof(matchId), mapNumber, uploadUrl, sizeof(uploadUrl), uploadUrlHeaderKey,
                   sizeof(uploadUrlHeaderKey), uploadUrlHeaderValue, sizeof(uploadUrlHeaderValue), demoFilePath,
                   sizeof(demoFilePath), demoFileName, sizeof(demoFileName), deleteAfterUpload);
  delete pack;

  Get5DemoFinishedEvent event = new Get5DemoFinishedEvent(matchId, mapNumber, demoFilePath);
  LogDebug("Calling Get5_OnDemoFinished()");
  Call_StartForward(g_OnDemoFinished);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);

  UploadDemoToServer(demoFilePath, demoFileName, matchId, mapNumber, uploadUrl, uploadUrlHeaderKey,
                     uploadUrlHeaderValue, deleteAfterUpload);
  return Plugin_Handled;
}

static DataPack GetDemoInfoDataPack(const char[] matchId, const int mapNumber, const char[] demoFilePath,
                                    const char[] demoFileName, const char[] uploadUrl, const char[] uploadHeaderKey,
                                    const char[] uploadHeaderValue, const bool deleteAfterUpload) {
  DataPack pack = CreateDataPack();
  pack.WriteString(matchId);
  pack.WriteCell(mapNumber);
  pack.WriteString(demoFilePath);  // Full path, including file name and extension
  pack.WriteString(demoFileName);  // File name and extension only
  pack.WriteString(uploadUrl);
  pack.WriteString(uploadHeaderKey);
  pack.WriteString(uploadHeaderValue);
  pack.WriteCell(deleteAfterUpload);
  return pack;
}

static void ReadDemoDataPack(DataPack pack, char[] matchId, const int matchIdLength, int &mapNumber, char[] uploadUrl,
                             const int uploadUrlLength, char[] uploadHeaderKey, const int uploadHeaderKeyLength,
                             char[] uploadeHeaderValue, const int uploadHeaderValueLength, char[] demoFilePath,
                             const int demoFilePathLength, char[] demoFileName, const int demoFileNameLength,
                             bool &deleteAfterUpload) {
  pack.Reset();
  pack.ReadString(matchId, matchIdLength);
  mapNumber = pack.ReadCell();
  pack.ReadString(demoFilePath, demoFilePathLength);
  pack.ReadString(demoFileName, demoFileNameLength);
  pack.ReadString(uploadUrl, uploadUrlLength);
  pack.ReadString(uploadHeaderKey, uploadHeaderKeyLength);
  pack.ReadString(uploadeHeaderValue, uploadHeaderValueLength);
  deleteAfterUpload = pack.ReadCell();
}

static void UploadDemoToServer(const char[] demoFilePath, const char[] demoFileName, const char[] matchId,
                               int mapNumber, const char[] demoUrl, const char[] demoHeaderKey,
                               const char[] demoHeaderValue, const bool deleteAfterUpload) {

  if (StrEqual(demoUrl, "")) {
    LogDebug("Skipping demo upload as upload URL is not set.");
    return;
  }

  if (!LibraryExists("SteamWorks")) {
    LogError(
      "Get5 cannot upload demos to a web server without the SteamWorks extension. Set get5_demo_upload_url to an empty string to remove this message.");
    return;
  }

  char error[PLATFORM_MAX_PATH];
  EHTTPMethod method = g_DemoUploadUsePUTCvar.BoolValue ? k_EHTTPMethodPUT : k_EHTTPMethodPOST;
  Handle demoRequest = CreateGet5HTTPRequest(method, demoUrl, error);
  if (demoRequest == INVALID_HANDLE || !AddFileAsHttpBody(demoRequest, demoFilePath, error) ||
      !SetFileNameHeader(demoRequest, demoFileName, error) || !SetMatchIdHeader(demoRequest, matchId, error) ||
      !SetMapNumberHeader(demoRequest, mapNumber, error)) {
    LogError(error);
    delete demoRequest;
    CallUploadEvent(matchId, mapNumber, demoFilePath, false);
    return;
  }

  // Set the auth keys only if they are defined. If not, we can still technically POST
  // to an end point that has no authentication.
  if (strlen(demoHeaderKey) > 0 && strlen(demoHeaderValue) > 0 &&
      !SetHeaderKeyValuePair(demoRequest, demoHeaderKey, demoHeaderValue, error)) {
    LogError(error);
    delete demoRequest;
    CallUploadEvent(matchId, mapNumber, demoFilePath, false);
    return;
  }

  DataPack pack = GetDemoInfoDataPack(matchId, mapNumber, demoFilePath, demoFileName, demoUrl, demoHeaderKey,
                                      demoHeaderValue, deleteAfterUpload);

  int timeout = g_DemoUploadTimeoutCvar.IntValue;
  if (timeout < 0) {
    timeout = 0;
  }
  SteamWorks_SetHTTPRequestNetworkActivityTimeout(demoRequest, timeout);
  SteamWorks_SetHTTPRequestContextValue(demoRequest, pack);
  SteamWorks_SetHTTPCallbacks(demoRequest, DemoRequest_Callback);
  SteamWorks_SendHTTPRequest(demoRequest);
}

static bool IsTVEnabled() {
  ConVar tvEnabledCvar = FindConVar("tv_enable");
  if (tvEnabledCvar == null) {
    LogError("Failed to get tv_enable cvar");
    return false;
  }
  if (tvEnabledCvar.BoolValue) {
    // GOTV can be enabled without the bot actually running; map restart is
    // required, so it might be disabled in edge-cases.
    LOOP_CLIENTS(i) {
      if (IsClientConnected(i) && IsClientSourceTV(i)) {
        return true;
      }
    }
  }
  return false;
}

int GetTvDelay() {
  if (IsTVEnabled()) {
    bool tvEnable1 = GetCvarIntSafe("tv_enable1") > 0;
    int tvDelay = GetCvarIntSafe("tv_delay");
    if (!tvEnable1) {
      return tvDelay;
    }
    int tvDelay1 = GetCvarIntSafe("tv_delay1");
    if (tvDelay < tvDelay1) {
      LogDebug("tv_delay1 is longer than the default tv_delay; using that.");
      return tvDelay1;
    }
    return tvDelay;
  }
  return 0;
}

float GetCurrentMatchRestartDelay() {
  ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
  if (mp_match_restart_delay == INVALID_HANDLE) {
    return 1.0;  // Shouldn't really be possible, but as a safeguard.
  }
  return mp_match_restart_delay.FloatValue;
}

void SetCurrentMatchRestartDelay(float delay) {
  ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
  if (mp_match_restart_delay != INVALID_HANDLE) {
    mp_match_restart_delay.FloatValue = delay;
  }
}

static void DemoRequest_Callback(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode,
                                 DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFilePath[PLATFORM_MAX_PATH];
  char demoFileName[PLATFORM_MAX_PATH];
  int mapNumber;
  char uploadUrl[1024];
  char uploadUrlHeaderKey[1024];
  char uploadUrlHeaderValue[1024];
  bool deleteAfterUpload;
  ReadDemoDataPack(pack, matchId, sizeof(matchId), mapNumber, uploadUrl, sizeof(uploadUrl), uploadUrlHeaderKey,
                   sizeof(uploadUrlHeaderKey), uploadUrlHeaderValue, sizeof(uploadUrlHeaderValue), demoFilePath,
                   sizeof(demoFilePath), demoFileName, sizeof(demoFileName), deleteAfterUpload);
  delete pack;
  bool success = false;
  if (failure || !requestSuccessful) {
    LogError("Failed to upload demo '%s' to '%s'. Make sure your URL is enclosed in quotes.", demoFilePath, uploadUrl);
  } else if (!CheckForSuccessfulResponse(request, statusCode)) {
    LogError("Failed to upload demo '%s' to '%s'. HTTP status code: %d.", demoFilePath, uploadUrl, statusCode);
  } else {
    success = true;
    LogDebug("Demo request succeeded. HTTP status code: %d.", statusCode);
    if (deleteAfterUpload) {
      LogDebug(
        "get5_demo_delete_after_upload set to true when demo request started; deleting the file from the game server.");
      if (FileExists(demoFilePath) && !DeleteFile(demoFilePath)) {
        LogError("Unable to delete demo file %s.", demoFilePath);
      }
    }
  }
  CallUploadEvent(matchId, mapNumber, demoFilePath, success);
  delete request;
}

static void CallUploadEvent(const char[] matchId, const int mapNumber, const char[] demoFileName, const bool success) {
  Get5DemoUploadEndedEvent event = new Get5DemoUploadEndedEvent(matchId, mapNumber, demoFileName, success);
  LogDebug("Calling Get5_OnDemoUploadEnded()");
  Call_StartForward(g_OnDemoUploadEnded);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);
}
