bool StartRecording() {
  if (!IsTVEnabled()) {
    LogError("Demo recording will not work with \"tv_enable 0\". Set \"tv_enable 1\" and restart the map to fix this.");
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

  // Escape unsafe characters and start recording.
  char szDemoName[PLATFORM_MAX_PATH + 1];
  strcopy(szDemoName, sizeof(szDemoName), demoName);
  ReplaceString(szDemoName, sizeof(szDemoName), "\"", "\\\"");
  ServerCommand("tv_record \"%s\"", szDemoName);
  return true;
}

void StopRecording(bool forceStop = false) {
  if (!IsTVEnabled()) {
    LogDebug("Cannot stop recording as GOTV is not enabled.");
    return;
  }
  if (forceStop) {
    LogDebug("Ending GOTV recording immediately by force.");
    StopRecordingCallback(g_MatchID, g_MapNumber, g_DemoFileName);
    return;
  }
  int tvDelay = GetTvDelay();
  if (tvDelay > 0) {
    LogDebug("Starting timer that will end GOTV recording in %d seconds.", tvDelay);
    DataPack pack = CreateDataPack();
    pack.WriteString(g_MatchID);
    pack.WriteCell(g_MapNumber);
    pack.WriteString(g_DemoFileName);
    CreateTimer(float(tvDelay), Timer_StopGoTVRecording, pack, TIMER_FLAG_NO_MAPCHANGE); // changemap ends recording, so the timer cannot carry over.
  } else {
    LogDebug("Ending GOTV recording immediately as tv_delay is 0.");
    StopRecordingCallback(g_MatchID, g_MapNumber, g_DemoFileName);
  }
}

static void StopRecordingCallback(char[] matchId, int mapNumber, char[] demoFileName) {
  ServerCommand("tv_stoprecord");
  if (StrEqual("", demoFileName)) {
    LogDebug("Demo was not recorded by Get5; not firing Get5_OnDemoFinished()");
    return;
  }

  // We delay this by 3 seconds to allow the server to flush to the file before firing the event.
  // This requires a pack with the data, as the map might change and stuff might happen after the
  // tv_delay has expired. This would also allow us to extend this delay later without breaking anything.
  DataPack pack = CreateDataPack();
  pack.WriteString(matchId);
  pack.WriteCell(mapNumber);
  pack.WriteString(demoFileName);

  CreateTimer(3.0, Timer_FireStopRecordingEvent, pack);
}

public Action Timer_StopGoTVRecording(Handle timer, DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFileName[PLATFORM_MAX_PATH];
  pack.Reset();
  pack.ReadString(matchId, sizeof(matchId));
  int mapNumber = pack.ReadCell();
  pack.ReadString(demoFileName, sizeof(demoFileName));
  delete pack;

  StopRecordingCallback(matchId, mapNumber, demoFileName);
  return Plugin_Handled;
}

public Action Timer_FireStopRecordingEvent(Handle timer, DataPack pack) {
  char matchId[MATCH_ID_LENGTH];
  char demoFileName[PLATFORM_MAX_PATH];
  pack.Reset();
  pack.ReadString(matchId, sizeof(matchId));
  int mapNumber = pack.ReadCell();
  pack.ReadString(demoFileName, sizeof(demoFileName));
  delete pack;

  Get5DemoFinishedEvent event = new Get5DemoFinishedEvent(matchId, mapNumber, demoFileName);
  LogDebug("Calling Get5_OnDemoFinished()");
  Call_StartForward(g_OnDemoFinished);
  Call_PushCell(event);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(event);
  return Plugin_Handled;
}

bool IsTVEnabled() {
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
