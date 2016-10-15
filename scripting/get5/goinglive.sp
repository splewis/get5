/** Begins the LO3 process. **/
public Action StartGoingLive(Handle timer) {
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

    if (g_QuickRestartCvar.IntValue != 0) {
        CreateTimer(delay, MatchLive);
    } else {
        CreateTimer(delay, Restart2);
    }

    EventLogger_GoingLive();

    Call_StartForward(g_OnGoingLive);
    Call_PushCell(GetMapNumber());
    Call_Finish();

    return Plugin_Handled;
}

public Action Restart2(Handle timer) {
    if (g_GameState == GameState_None)
        return Plugin_Handled;

    Get5_MessageToAll("Restart 2/3");
    RestartGame(5);
    CreateTimer(4.0, Restart3);

    return Plugin_Handled;
}

public Action Restart3(Handle timer) {
    if (g_GameState == GameState_None)
        return Plugin_Handled;

    Get5_MessageToAll("Restart 3/3");
    RestartGame(5);
    CreateTimer(5.1, MatchLive);

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

    for (int i = 0; i < 5; i++) {
        Get5_MessageToAll("%t", "MatchIsLiveInfoMessage");
    }

    return Plugin_Handled;
}
