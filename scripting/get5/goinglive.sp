/** Begins the LO3 or one 10sec process. **/
public Action StartGoingLive(Handle timer) {
    ExecCfg(g_LiveCfgCvar);
    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();

	// Checking if user want one 10s restart or oldschool LO3
	if (g_QuickRestartCvar.IntValue != 0){
		Get5_MessageToAll("The match will begin in 10 seconds.");
		// Force kill the warmup if we (still) need to.
		if (InWarmup()){
			EndWarmup(10);
		} else {
        RestartGame(10);
		}

		// Always disable sv_cheats!
		ServerCommand("sv_cheats 0");

		CreateTimer(15.0, MatchLive);
		Call_StartForward(g_OnGoingLive);
		Call_PushCell(GetMapNumber());
		Call_Finish();

	} else {
		Get5_MessageToAll("Restart 1/3");
		if (InWarmup()){
			EndWarmup();
		} else {
			RestartGame(1);
		}
        CreateTimer(3.0, Restart2);	
	}
	
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
		
		// Always disable sv_cheats!
		ServerCommand("sv_cheats 0");
		
		CreateTimer(5.1, MatchLive);
		Call_StartForward(g_OnGoingLive);
		Call_PushCell(GetMapNumber());
		Call_Finish();
 
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
        Get5_MessageToAll("Match is {GREEN}LIVE");
    }

    return Plugin_Handled;
}
