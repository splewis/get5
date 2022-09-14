bool StartRecording() {
  char demoFormat[PLATFORM_MAX_PATH];
  g_DemoNameFormatCvar.GetString(demoFormat, sizeof(demoFormat));
  if (StrEqual("", demoFormat)) {
    LogMessage("Demo recording is disabled via get5_demo_name_format.");
    return false;
  }

  if (!IsTVEnabled()) {
    LogError(
        "Demo recording will not work with \"tv_enable 0\". Set \"tv_enable 1\" and restart the map to fix this.");
    g_DemoFileName = "";
    return false;
  }

  char demoName[PLATFORM_MAX_PATH + 1];

  if (!FormatCvarString(g_DemoNameFormatCvar, demoName, sizeof(demoName))) {
    LogError("Failed to format demo filename. Please check your demo file format convar.");
    g_DemoFileName = "";
    return false;
  }

  char demoFolder[PLATFORM_MAX_PATH];
  char variableSubstitutes[][] = {"{MATCHID}", "{DATE}"};
  CheckAndCreateFolderPath(g_DemoPathCvar, variableSubstitutes, 2, demoFolder,
                           sizeof(demoFolder));

  char demoPath[PLATFORM_MAX_PATH];
  FormatEx(demoPath, sizeof(demoPath), "%s%s", demoFolder, demoName);
  FormatEx(g_DemoFileName, sizeof(g_DemoFileName), "%s%s.dem", demoFolder, demoName);
  LogMessage("Recording to %s", g_DemoFileName);

  // Escape unsafe characters and start recording. .dem is appended to the filename automatically.
  ReplaceString(demoPath, sizeof(demoPath), "\"", "\\\"");
  ServerCommand("tv_record \"%s\"", demoPath);
  Stats_SetDemoName(g_DemoFileName);
  return true;
}

void StopRecording(float delay = 0.0) {
  if (delay < 0.1) {
    LogDebug("Stopping GOTV recording immediately.");
    StopRecordingCallback(g_MatchID, g_MapNumber, g_DemoFileName);
  } else {
    LogDebug("Starting timer that will end GOTV recording in %f seconds.", delay);
    CreateTimer(delay, Timer_StopGoTVRecording,
                GetDemoInfoDataPack(g_MatchID, g_MapNumber, g_DemoFileName));
  }
  g_DemoFileName = "";
}

static void StopRecordingCallback(const char[] matchId, const int mapNumber,
                                  const char[] demoFileName) {
  ServerCommand("tv_stoprecord");
  if (StrEqual("", demoFileName)) {
    LogDebug("Demo was not recorded by Get5; not firing Get5_OnDemoFinished()");
    return;
  }
  // We delay this by 3 seconds to allow the server to flush to the file before firing the event.
  CreateTimer(3.0, Timer_FireStopRecordingEvent,
              GetDemoInfoDataPack(matchId, mapNumber, demoFileName));
}

static DataPack GetDemoInfoDataPack(const char[] matchId, const int mapNumber,
                                    const char[] demoFileName) {
  DataPack pack = CreateDataPack();
  pack.WriteString(matchId);
  pack.WriteCell(mapNumber);
  pack.WriteString(demoFileName);
  return pack;
}

static void ReadDemoDataPack(DataPack pack, char[] matchId, const int matchIdLength, int &mapNumber,
                             char[] demoFileName, const int demoFileNameLength) {
  pack.Reset();
  pack.ReadString(matchId, matchIdLength);
  mapNumber = pack.ReadCell();
  pack.ReadString(demoFileName, demoFileNameLength);
  delete pack;
}

static Action Timer_StopGoTVRecording(Handle timer, DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFileName[PLATFORM_MAX_PATH];
  int mapNumber;
  ReadDemoDataPack(pack, matchId, sizeof(matchId), mapNumber, demoFileName, sizeof(demoFileName));
  StopRecordingCallback(matchId, mapNumber, demoFileName);
  return Plugin_Handled;
}

static Action Timer_FireStopRecordingEvent(Handle timer, DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFileName[PLATFORM_MAX_PATH];
  int mapNumber;
  ReadDemoDataPack(pack, matchId, sizeof(matchId), mapNumber, demoFileName, sizeof(demoFileName));

  Get5DemoFinishedEvent event = new Get5DemoFinishedEvent(matchId, mapNumber, demoFileName);
  LogDebug("Calling Get5_OnDemoFinished()");
  Call_StartForward(g_OnDemoFinished);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);

  UploadDemoToServer(demoFileName, matchId, mapNumber);
  return Plugin_Handled;
}

static void UploadDemoToServer(const char[] demoFileName, const char[] matchId, int mapNumber) {
  char demoUrl[1024];
  char demoAuthKey[1024];
  char demoAuthValue[1024];

  g_DemoUploadUrlCvar.GetString(demoUrl, sizeof(demoUrl));
  g_DemoUploadAuthKeyCvar.GetString(demoAuthKey, sizeof(demoAuthKey));
  g_DemoUploadAuthValueCvar.GetString(demoAuthValue, sizeof(demoAuthValue));

  if (StrEqual(demoUrl, "")) {
    LogDebug("Will not upload any demos as upload URL is not set.");
    return;
  }

  if (!LibraryExists("SteamWorks")) {
    LogDebug("Cannot upload demos to a web server without the SteamWorks extension running.");
    return;
  }

  char userAgent[1024];
  char strMapNumber[5];
  ReplaceString(demoUrl, sizeof(demoUrl), "\"", "");
  FormatEx(userAgent, sizeof(userAgent), "SourceMod Get5 %s+https://%s", PLUGIN_VERSION,
         GET5_GITHUB_PAGE);
  FormatEx(strMapNumber, sizeof(strMapNumber), "%d", mapNumber);
  // Add the protocol strings if missing (only http).
  if (StrContains(demoUrl, "http", false) != 0) {
    Format(demoUrl, sizeof(demoUrl), "http://%s", demoUrl);
  }

  LogDebug("UploadDemoToServer: demoUrl (SteamWorks) = %s", demoUrl);
  Handle demoRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, demoUrl);

  if (demoRequest == INVALID_HANDLE) {
    LogDebug("Failed to create request %s", demoUrl);
    return;
  }

  // Set the auth keys only if they are defined. If not, we can still technically POST
  // to an end point that has no authentication.
  if (!StrEqual(demoAuthKey, "") && !StrEqual(demoAuthValue, "")) {
    if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, demoAuthKey, demoAuthValue)) {
      LogError("Failed to add auth key and token to call. Will end request here.");
      delete demoRequest;
      return;
    }
  }

  if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, "Get5-DemoName", demoFileName)) {
    LogError("Failed to add filename content header to call. Will end request here.");
    delete demoRequest;
    return;
  }

  if (!SteamWorks_SetHTTPRequestUserAgentInfo(demoRequest, userAgent)) {
    LogError("Failed to add user-agent header to call. Will end request here.");
    delete demoRequest;
    return;
  }
  
  if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, "Get5-MatchId", matchId)) {
    LogError("Failed to add match id content header to call. Will end request here.");
    delete demoRequest;
    return;
  }
  
  if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, "Get5-MapNumber", strMapNumber)) {
    LogError("Failed to add map number content header to call. Will end request here.");
    delete demoRequest;
    return;
  }

  if (!SteamWorks_SetHTTPRequestNetworkActivityTimeout(demoRequest, 180)) {
    LogError("Failed to change request timeout to 180 seconds. Will end request here.");
    delete demoRequest;
    return;
  }

  if (!SteamWorks_SetHTTPRequestRawPostBodyFromFile(demoRequest, "application/octet-stream",
                                                    demoFileName)) {
    LogError("Failed to append raw POST body, perhaps the file %s is missing?", demoFileName);
    delete demoRequest;
    return;
  }
  SteamWorks_SetHTTPCallbacks(demoRequest, DemoRequestCallback);
  SteamWorks_SendHTTPRequest(demoRequest);
  // Store the filename of the demo for the callback.
  FormatEx(g_DemoFileNameLastStartedUpload, sizeof(g_DemoFileNameLastStartedUpload), demoFileName);
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
    return GetCvarIntSafe("tv_delay");
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

static int DemoRequestCallback(Handle request, bool failure, bool requestSuccessful,
                               EHTTPStatusCode statusCode) {
  if (failure || !requestSuccessful) {
    LogError("Failed to upload demo %s.", g_DemoFileNameLastStartedUpload);
    delete request;
    return;
  }
  int status = view_as<int>(statusCode);
  if (status >= 300 || status < 200) {
    LogError("Demo request failed with HTTP status code: %d.", statusCode);
    int responseSize;
    SteamWorks_GetHTTPResponseBodySize(request, responseSize);
    char[] response = new char[responseSize];
    if (SteamWorks_GetHTTPResponseBodyData(request, response, responseSize)) {
      LogError("Response body: %s", response);
    } else {
      LogError("Failed to read response body.");
    }
    delete request;
    return;
  }
  LogDebug("Demo request succeeded. HTTP status code: %d.", statusCode);
  if (g_DemoUploadDeleteAfterCvar.BoolValue && !StrEqual(g_DemoFileNameLastStartedUpload, "")) {
    LogDebug("get5_demo_delete_after_upload set to true; deleting the file from the game server.");
    if (FileExists(g_DemoFileNameLastStartedUpload)) {
      if (!DeleteFile(g_DemoFileNameLastStartedUpload)) {
        LogError("Unable to delete demo file %s.", g_DemoFileNameLastStartedUpload);
      }
    }
  }
  delete request;
}
