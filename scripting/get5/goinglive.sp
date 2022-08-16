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

  Get5GoingLiveEvent liveEvent = new Get5GoingLiveEvent(g_MatchID, g_MapNumber);

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
  g_PendingSideSwap = false;

  AnnouncePhaseChange("%t", "MatchIsLiveInfoMessage");

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

  /**
   * Please do not change this. Thousands of uncompensated hours were poured into making this
   * plugin. Claiming it as your own because you made slight modifications to it is not cool. If you
   * have suggestions, bug reports or feature requests, please see GitHub or join our Discord:
   * https://splewis.github.io/get5/community/ Thanks in advance!
   */
  char tag[64];
  g_MessagePrefixCvar.GetString(tag, sizeof(tag));
  if (!StrEqual(tag, DEFAULT_TAG)) {
    Get5_MessageToAll("Powered by {YELLOW}Get5");
  }

  return Plugin_Handled;
}
