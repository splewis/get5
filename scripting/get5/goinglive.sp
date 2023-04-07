void StartGoingLive() {
  LogDebug("StartGoingLive");
  ExecCfg(g_Wingman ? g_LiveWingmanCfgCvar : g_LiveCfgCvar);
  // This ensures that we can send send the game to warmup and count down *even if* someone had put
  // "mp_warmup_end", or something else that would mess up warmup, in their live config, which they
  // shouldn't. But we can't be sure.
  CreateTimer(1.0, Timer_GoToLive, _, TIMER_FLAG_NO_MAPCHANGE);
}

static Action Timer_GoToLive(Handle timer) {
  if (g_GameState != Get5State_Warmup && g_GameState != Get5State_WaitingForKnifeRoundDecision) {
    // super defensive race-condition check. These are the only two allowed states
    // for this callback, so if the game had been canceled during this time, do nothing.
    return Plugin_Handled;
  }
  // Always disable sv_cheats!
  ServerCommand("sv_cheats 0");
  // Ensure we're in warmup and counting down to live. Round_PreStart handles the rest.
  int countdown = g_LiveCountdownTimeCvar.IntValue;
  if (countdown < 5) {
    // ensures that a cvar countdown value of 0 does not leave the game forever in warmup.
    countdown = 5;
  }
  Get5_MessageToAll("%t", "MatchBeginInSecondsInfoMessage", countdown);
  StartWarmup(countdown);
  LogDebug("Started warmup countdown to live in %d seconds.", countdown);

  // Change state as we're now counting down to live from warmup.
  ChangeState(Get5State_GoingLive);

  // Remove team ready tags if there was no knife-round to do it.
  // The ExecCfg for the live config finished before the game state changes
  // to Get5State_GoingLive above, so it won't be set then.
  SetMatchTeamCvars();

  // Going live event
  Get5GoingLiveEvent liveEvent = new Get5GoingLiveEvent(g_MatchID, g_MapNumber);
  LogDebug("Calling Get5_OnGoingLive()");
  Call_StartForward(g_OnGoingLive);
  Call_PushCell(liveEvent);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(liveEvent);
  return Plugin_Handled;
}

Action Timer_MatchLive(Handle timer) {
  if (g_GameState != Get5State_Live) {
    return Plugin_Handled;
  }

  AnnouncePhaseChange("%t", "MatchIsLiveInfoMessage");

  if (g_PrintUpdateNoticeCvar.BoolValue) {
    if (g_RunningPrereleaseVersion) {
      char conVarName[64];
      g_PrintUpdateNoticeCvar.GetName(conVarName, sizeof(conVarName));
      FormatCvarName(conVarName, sizeof(conVarName), conVarName);
      Get5_MessageToAll("%t", "PrereleaseVersionWarning", PLUGIN_VERSION, conVarName);
    } else if (g_NewerVersionAvailable) {
      Get5_MessageToAll("%t", "NewVersionAvailable", GET5_GITHUB_PAGE);
    }
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
