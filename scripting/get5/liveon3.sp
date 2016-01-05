/** Begins the LO3 process. **/
public Action BeginLO3(Handle timer) {
    if (g_GameState == GameState_None)
        return Plugin_Handled;

    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();
    ChangeState(GameState_GoingLive);

    // Force kill the warmup if we (still) need to.
    if (InWarmup()) {
        EndWarmup();
    }

    Get5_MessageToAll("Restart 1/3");
    RestartGame(1);
    CreateTimer(3.0, Restart2);

    return Plugin_Handled;
}

public Action Restart2(Handle timer) {
    if (g_GameState == GameState_None)
        return Plugin_Handled;

    Get5_MessageToAll("Restart 2/3");
    RestartGame(1);
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
    ConVar mp_match_restart_delay = FindConVar("mp_match_restart_delay");
    ConVar tv_delay = FindConVar("tv_delay");
    SetConVarInt(mp_match_restart_delay, tv_delay.IntValue + MATCH_END_DELAY_AFTER_TV);

    ChangeState(GameState_Live);

    for (int i = 0; i < 5; i++) {
        Get5_MessageToAll("Match is {GREEN}LIVE");
    }

    return Plugin_Handled;
}
