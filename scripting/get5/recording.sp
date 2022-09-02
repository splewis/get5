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

  Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
  LogMessage("Recording to %s", g_DemoFileName);

  // Escape unsafe characters and start recording. .dem is appended to the filename automatically.
  char szDemoName[PLATFORM_MAX_PATH + 1];
  strcopy(szDemoName, sizeof(szDemoName), demoName);
  ReplaceString(szDemoName, sizeof(szDemoName), "\"", "\\\"");
  ServerCommand("tv_record \"%s\"", szDemoName);
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
  return Plugin_Handled;
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
