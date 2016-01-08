public Action StartKnifeRound(Handle timer) {
    g_PendingSideSwap = false;
    EndWarmup();
    RestartGame(1);
    CreateTimer(2.0, Timer_AnnounceKnife);
    return Plugin_Handled;
}

public Action Timer_AnnounceKnife(Handle timer) {
    EndWarmup();
    for (int i = 0; i < 5; i++)
        Get5_MessageToAll("Knife!");

    return Plugin_Handled;
}

public void EndKnifeRound(bool swap) {
    if (swap) {
        SwapSides();
        for (int i = 1; i <= MaxClients; i++) {
            if (IsValidClient(i)) {
                int team = GetClientTeam(i);
                if (team == CS_TEAM_T) {
                    SwitchPlayerTeam(i, CS_TEAM_CT);
                } else if (team == CS_TEAM_CT) {
                    SwitchPlayerTeam(i, CS_TEAM_T);
                } else if (IsClientCoaching(i))  {
                    int correctTeam = MatchTeamToCSTeam(GetClientMatchTeam(i));
                    UpdateCoachTarget(i, correctTeam);
                }
            }
        }
    } else {
        g_TeamSide[MatchTeam_Team1] = CS_TEAM_CT;
        g_TeamSide[MatchTeam_Team2] = CS_TEAM_T;
    }

    RestoreCvars(g_KnifeChangedCvars, true);
    ServerCommand("exec %s", LIVE_CONFIG);

    ChangeState(GameState_GoingLive);
    CreateTimer(3.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
}

static bool AwaitingKnifeDecision(int client) {
    return (g_GameState == GameState_WaitingForKnifeRoundDecision) &&
        IsPlayer(client) && GetClientMatchTeam(client) == g_KnifeWinnerTeam;
}


public Action Command_Stay(int client, int args) {
    if (AwaitingKnifeDecision(client)) {
        EndKnifeRound(false);
        Get5_MessageToAll("%s have decided to stay.", g_FormattedTeamNames[g_KnifeWinnerTeam]);
    }
    return Plugin_Handled;
}

public Action Command_Swap(int client, int args) {
    if (AwaitingKnifeDecision(client)) {
        EndKnifeRound(true);
        Get5_MessageToAll("%s have decided to swap.", g_FormattedTeamNames[g_KnifeWinnerTeam]);
    }
    return Plugin_Handled;
}

public Action Command_Ct(int client, int args) {
    if (IsPlayer(client)) {
        if (GetClientTeam(client) == CS_TEAM_CT)
            FakeClientCommand(client, "sm_stay");
        else if (GetClientTeam(client) == CS_TEAM_T)
            FakeClientCommand(client, "sm_swap");
    }

    LogDebug("cs team = %d", GetClientTeam(client));
    LogDebug("m_iCoachingTeam = %d", GetEntProp(client, Prop_Send, "m_iCoachingTeam"));
    LogDebug("m_iPendingTeamNum = %d",  GetEntProp(client, Prop_Send, "m_iPendingTeamNum"));


    return Plugin_Handled;
}

public Action Command_T(int client, int args) {
    if (IsPlayer(client)) {
        if (GetClientTeam(client) == CS_TEAM_T)
            FakeClientCommand(client, "sm_stay");
        else if (GetClientTeam(client) == CS_TEAM_CT)
            FakeClientCommand(client, "sm_swap");
    }
    return Plugin_Handled;
}
