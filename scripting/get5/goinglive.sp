/** Begins the LO3 process. **/
public Action StartGoingLive(Handle timer) {
    ExecCfg(g_LiveCfgCvar);
    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();

    // Force kill the warmup if we (still) need to.
    Get5_MessageToAll("The match will begin in 10 seconds.");
    if (InWarmup()) {
        EndWarmup(10);
    } else {
        RestartGame(10);
    }

    CreateTimer(15.0, MatchLive);

    return Plugin_Handled;
}


public Action MatchLive(Handle timer) {
    if (g_GameState == GameState_None)
        return Plugin_Handled;

    // We force the match end-delay to extend for the duration of the GOTV broadcast here.
    g_PendingSideSwap = false;
    ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
    ConVar tv_delay = FindConVar("tv_delay");
    SetConVarInt(mp_match_restart_delay, tv_delay.IntValue + MATCH_END_DELAY_AFTER_TV + 5);

    ChangeState(GameState_Live);

    for (int i = 0; i < 5; i++) {
        Get5_MessageToAll("Match is {GREEN}LIVE");
    }

    return Plugin_Handled;
}
