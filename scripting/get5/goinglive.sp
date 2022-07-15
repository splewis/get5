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

  EventLogger_GoingLive();

  LogDebug("Calling Get5_OnGoingLive(mapnum=%d)", GetMapNumber());
  Call_StartForward(g_OnGoingLive);
  Call_PushCell(GetMapNumber());
  Call_Finish();

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

  // If there is a set amount of timeouts available update the built-in convar and game rule
  // properties to show the correct amount of timeouts remaining in gsi and in-game
  if (g_MaxPausesCvar.IntValue > 0) {
    ServerCommand("mp_team_timeout_max %d", g_MaxPausesCvar.IntValue);
    GameRules_SetProp("m_nTerroristTimeOuts", g_MaxPausesCvar.IntValue);
    GameRules_SetProp("m_nCTTimeOuts", g_MaxPausesCvar.IntValue);
  }

  // We force the match end-delay to extend for the duration of the GOTV broadcast here.
  g_PendingSideSwap = false;
  SetMatchRestartDelay();

  for (int i = 0; i < 5; i++) {
    Get5_MessageToAll("%t", "MatchIsLiveInfoMessage");
  }

  //Exec message.cfg - Console text message before match start
  ServerCommand("exec message.cfg");

  return Plugin_Handled;
}

public void SetMatchRestartDelay() {
  ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
  int delay = GetTvDelay() + MATCH_END_DELAY_AFTER_TV + 5;
  SetConVarInt(mp_match_restart_delay, delay);
}