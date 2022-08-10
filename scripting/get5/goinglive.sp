/** Begins the LO3 process. **/
public Action StartGoingLive(Handle timer) {
  LogDebug("StartGoingLive");
  ExecCfg(g_LiveCfgCvar);
  SetMatchTeamCvars();
  ExecuteMatchConfigCvars();

  // Force kill the warmup if we (still) need to.
  Get5_MessageToAll("%t", "MatchBeginInSecondsInfoMessage", g_LiveCountdownTimeCvar.IntValue);
  if (InWarmup()) {
    EndWarmup(g_LiveCountdownTimeCvar.IntValue);
  } else {
    RestartGame(g_LiveCountdownTimeCvar.IntValue);
  }

  // Always disable sv_cheats!
  ServerCommand("sv_cheats 0");

  // Delayed an extra 5 seconds for the final 3-second countdown
  // the game uses after the origina countdown.
  float delay = float(5 + g_LiveCountdownTimeCvar.IntValue);
  CreateTimer(delay, MatchLive);

  Get5GoingLiveEvent liveEvent = new Get5GoingLiveEvent(g_MatchID, Get5_GetMapNumber());

  LogDebug("Calling Get5_OnGoingLive()");

  Call_StartForward(g_OnGoingLive);
  Call_PushCell(liveEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(liveEvent);

  return Plugin_Handled;
}

public Action MatchLive(Handle timer) {
  if (g_GameState == Get5State_None) {
    return Plugin_Handled;
  }

  // Reset match config cvars. The problem is that when they are first
  // set in StartGoingLive is that setting them right after executing the
  // live config causes the live config values to get used for some reason
  // (asynchronous command execution/cvar setting?), so they're set again
  // to be sure.
  SetMatchTeamCvars();
  ExecuteMatchConfigCvars();

  // We force the match end-delay to extend for the duration of the GOTV broadcast here.
  g_PendingSideSwap = false;
  SetMatchRestartDelay();

  for (int i = 0; i < 5; i++) {
    Get5_MessageToAll("%t", "MatchIsLiveInfoMessage");
  }

  char tag[64];
  g_MessagePrefixCvar.GetString(tag, sizeof(tag));
  if (!StrEqual(tag, DEFAULT_TAG)) {
    Get5_MessageToAll("%t", "MatchPoweredBy");
  }

  if (!g_PrintUpdateNoticeCvar.BoolValue) {
    return Plugin_Handled;
  }

  if (g_RunningPrereleaseVersion) {
    char conVarName[64];
    g_PrintUpdateNoticeCvar.GetName(conVarName, sizeof(conVarName));
    Get5_MessageToAll("%t", "PrereleaseVersionWarning", PLUGIN_VERSION, conVarName);
  } else if (g_NewerVersionAvailable) {
    Get5_MessageToAll("%t", "NewVersionAvailable", GET5_GITHUB_PAGE);
  }

  return Plugin_Handled;
}

public void SetMatchRestartDelay() {
  // This ensures that the mp_match_restart_delay is not shorter than what
  // is required for the GOTV recording to finish.
  ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
  int requiredDelay = GetTvDelay() + MATCH_END_DELAY_AFTER_TV + 5;
  if (requiredDelay > mp_match_restart_delay.IntValue) {
    LogDebug("Extended mp_match_restart_delay from %d to %d to ensure GOTV can finish recording.", mp_match_restart_delay.IntValue, requiredDelay);
    mp_match_restart_delay.IntValue = requiredDelay;
  }
}
