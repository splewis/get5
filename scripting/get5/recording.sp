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
  char demoHeaderKey[1024];
  char demoHeaderValue[1024];

  g_DemoUploadURLCvar.GetString(demoUrl, sizeof(demoUrl));
  g_DemoUploadHeaderKeyCvar.GetString(demoHeaderKey, sizeof(demoHeaderKey));
  g_DemoUploadHeaderValueCvar.GetString(demoHeaderValue, sizeof(demoHeaderValue));

  if (StrEqual(demoUrl, "")) {
    LogDebug("Will not upload any demos as upload URL is not set.");
    return;
  }

  if (!LibraryExists("SteamWorks")) {
    LogDebug("Cannot upload demos to a web server without the SteamWorks extension running.");
    return;
  }

  LogDebug("UploadDemoToServer: demoUrl (SteamWorks) = %s", demoUrl);
  Handle demoRequest = CreateGet5HTTPRequest(k_EHTTPMethodPOST, demoUrl);

  if (demoRequest == INVALID_HANDLE) {
    return;
  }

  // Set the auth keys only if they are defined. If not, we can still technically POST
  // to an end point that has no authentication.
  if (!StrEqual(demoHeaderKey, "") && !StrEqual(demoHeaderValue, "")) {
    if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, demoHeaderKey, demoHeaderValue)) {
      LogError("Failed to add custom header '%s' with value '%s' to demo upload request.", demoHeaderKey, demoHeaderValue);
      delete demoRequest;
      return;
    }
  }

  if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, GET5_HEADER_DEMONAME, demoFileName)) {
    LogError("Failed to add filename header with value '%s' to demo upload request.", demoFileName);
    delete demoRequest;
    return;
  }

  if (strlen(matchId) > 0) {
   if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, GET5_HEADER_MATCHID, matchId)) {
      LogError("Failed to add match ID header with value '%s' to demo upload request.", matchId);
      delete demoRequest;
      return;
    }
  }

  char strMapNumber[5];
  IntToString(mapNumber, strMapNumber, sizeof(strMapNumber));
  if (!SteamWorks_SetHTTPRequestHeaderValue(demoRequest, GET5_HEADER_MAPNUMBER, strMapNumber)) {
    LogError("Failed to add map number header with value '%s' to demo upload request.", strMapNumber);
    delete demoRequest;
    return;
  }

  const timeout = 180;
  if (!SteamWorks_SetHTTPRequestNetworkActivityTimeout(demoRequest, timeout)) {
    LogError("Failed to change demo upload request timeout to %d seconds.", timeout);
    delete demoRequest;
    return;
  }

  if (!FileExists(demoFileName) || !SteamWorks_SetHTTPRequestRawPostBodyFromFile(
    demoRequest, "application/octet-stream", demoFileName)) {
    LogError("Failed to add file '%s' as POST body for demo upload request.", demoFileName);
    delete demoRequest;
    return;
  }

  DataPack pack = new DataPack();
  pack.WriteString(demoFileName);
  SteamWorks_SetHTTPRequestContextValue(demoRequest, pack);
  SteamWorks_SetHTTPCallbacks(demoRequest, DemoRequestCallback);
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
                               EHTTPStatusCode statusCode, DataPack pack) {
  char demoFileName[PLATFORM_MAX_PATH];
  pack.Reset();
  pack.ReadString(demoFileName, sizeof(demoFileName));
  delete pack;

  if (failure || !requestSuccessful) {
    LogError("Failed to upload demo %s.", demoFileName);
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
  if (g_DemoUploadDeleteAfterCvar.BoolValue) {
    LogDebug("get5_demo_delete_after_upload set to true; deleting the file from the game server.");
    if (FileExists(demoFileName)) {
      if (!DeleteFile(demoFileName)) {
        LogError("Unable to delete demo file %s.", demoFileName);
      }
    }
  }
  delete request;
}
