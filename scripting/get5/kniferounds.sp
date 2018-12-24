public Action StartKnifeRound(Handle timer) {
  g_HasKnifeRoundStarted = false;
  g_PendingSideSwap = false;

  Get5_MessageToAll("%t", "KnifeIn5SecInfoMessage");
  if (InWarmup()) {
    EndWarmup(5);
  } else {
    RestartGame(5);
  }

  CreateTimer(10.0, Timer_AnnounceKnife);
  return Plugin_Handled;
}

public Action Timer_AnnounceKnife(Handle timer) {
  for (int i = 0; i < 5; i++) {
    Get5_MessageToAll("%t", "KnifeInfoMessage");
  }

  g_HasKnifeRoundStarted = true;
  EventLogger_KnifeStart();
  return Plugin_Handled;
}

static void PerformSideSwap(bool swap) {
  if (swap) {
    int tmp = g_TeamState[MatchTeam_Team2].side;
    g_TeamState[MatchTeam_Team2].side = g_TeamState[MatchTeam_Team1].side;
    g_TeamState[MatchTeam_Team1].side = tmp;

    for (int i = 1; i <= MaxClients; i++) {
      if (IsValidClient(i)) {
        int team = GetClientTeam(i);
        if (team == CS_TEAM_T) {
          SwitchPlayerTeam(i, CS_TEAM_CT);
        } else if (team == CS_TEAM_CT) {
          SwitchPlayerTeam(i, CS_TEAM_T);
        } else if (IsClientCoaching(i)) {
          int correctTeam = MatchTeamToCSTeam(GetClientMatchTeam(i));
          UpdateCoachTarget(i, correctTeam);
        }
      }
    }
  } else {
    g_TeamState[MatchTeam_Team1].side = TEAM1_STARTING_SIDE;
    g_TeamState[MatchTeam_Team2].side = TEAM2_STARTING_SIDE;
  }

  g_TeamState[MatchTeam_Team1].starting_side = g_TeamState[MatchTeam_Team1].side;
  g_TeamState[MatchTeam_Team2].starting_side = g_TeamState[MatchTeam_Team2].side;
  SetMatchTeamCvars();
}

public void EndKnifeRound(bool swap) {
  PerformSideSwap(swap);
  EventLogger_KnifeWon(g_KnifeWinnerTeam, swap);
  ChangeState(Get5State_GoingLive);
  CreateTimer(3.0, StartGoingLive, _, TIMER_FLAG_NO_MAPCHANGE);
}

static bool AwaitingKnifeDecision(int client) {
  bool waiting = g_GameState == Get5State_WaitingForKnifeRoundDecision;
  bool onWinningTeam = IsPlayer(client) && GetClientMatchTeam(client) == g_KnifeWinnerTeam;
  bool admin = (client == 0);
  return waiting && (onWinningTeam || admin);
}

public Action Command_Stay(int client, int args) {
  if (AwaitingKnifeDecision(client)) {
    EndKnifeRound(false);
    Get5_MessageToAll("%t", "TeamDecidedToStayInfoMessage",
                      g_TeamConfig[g_KnifeWinnerTeam].formatted_name);
  }
  return Plugin_Handled;
}

public Action Command_Swap(int client, int args) {
  if (AwaitingKnifeDecision(client)) {
    EndKnifeRound(true);
    Get5_MessageToAll("%t", "TeamDecidedToSwapInfoMessage",
                      g_TeamConfig[g_KnifeWinnerTeam].formatted_name);
  } else if (g_GameState == Get5State_Warmup && g_MatchConfig.scrim_mode &&
             GetClientMatchTeam(client) == MatchTeam_Team1) {
    PerformSideSwap(true);
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
  LogDebug("m_iPendingTeamNum = %d", GetEntProp(client, Prop_Send, "m_iPendingTeamNum"));

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

public Action Timer_ForceKnifeDecision(Handle timer) {
  if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    EndKnifeRound(false);
    Get5_MessageToAll("%t", "TeamLostTimeToDecideInfoMessage",
                      g_TeamConfig[g_KnifeWinnerTeam].formatted_name);
  }
}
