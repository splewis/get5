Action StartKnifeRound(Handle timer) {
  g_HasKnifeRoundStarted = false;

  // Removes ready tags
  SetMatchTeamCvars();

  Get5_MessageToAll("%t", "KnifeIn5SecInfoMessage");
  if (InWarmup()) {
    EndWarmup(5);
  } else {
    RestartGame(5);
  }

  g_KnifeCountdownTimer = CreateTimer(10.0, Timer_AnnounceKnife);
  return Plugin_Handled;
}

static Action Timer_AnnounceKnife(Handle timer) {
  g_KnifeCountdownTimer = INVALID_HANDLE;
  if (g_GameState == Get5State_None) {
    return;
  }
  AnnouncePhaseChange("{GREEN}%t", "KnifeInfoMessage");

  Get5KnifeRoundStartedEvent knifeEvent = new Get5KnifeRoundStartedEvent(g_MatchID, g_MapNumber);

  LogDebug("Calling Get5_OnKnifeRoundStarted()");

  Call_StartForward(g_OnKnifeRoundStarted);
  Call_PushCell(knifeEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(knifeEvent);

  g_HasKnifeRoundStarted = true;
}

static void PerformSideSwap(bool swap) {
  if (swap) {
    int tmp = g_TeamSide[Get5Team_2];
    g_TeamSide[Get5Team_2] = g_TeamSide[Get5Team_1];
    g_TeamSide[Get5Team_1] = tmp;

    Get5Side currentSide;
    Get5Side coachingSide;
    LOOP_CLIENTS(i) {
      if (!IsPlayer(i)) {
        continue;
      }
      currentSide = view_as<Get5Side>(GetClientTeam(i));
      if (currentSide == Get5Side_T) {
        SwitchPlayerTeam(i, Get5Side_CT, false);
      } else if (currentSide == Get5Side_CT) {
        SwitchPlayerTeam(i, Get5Side_T, false);
      } else {
        coachingSide = GetClientCoachingSide(i);
        if (coachingSide != Get5Side_None) {
          SetClientCoaching(i, coachingSide == Get5Side_CT ? Get5Side_T : Get5Side_CT, false);
        }
      }
    }
    // Make sure g_MapSides has the correct values as well,
    // that way set starting teams won't swap on round 0,
    // since a temp valve backup does not exist.
    if (g_TeamSide[Get5Team_1] == CS_TEAM_CT)
      g_MapSides.Set(g_MapNumber, SideChoice_Team1CT);
    else
      g_MapSides.Set(g_MapNumber, SideChoice_Team1T);
  } else {
    g_TeamSide[Get5Team_1] = TEAM1_STARTING_SIDE;
    g_TeamSide[Get5Team_2] = TEAM2_STARTING_SIDE;
  }

  g_TeamStartingSide[Get5Team_1] = g_TeamSide[Get5Team_1];
  g_TeamStartingSide[Get5Team_2] = g_TeamSide[Get5Team_2];
  SetMatchTeamCvars();
}

static void EndKnifeRound(bool swap) {
  PerformSideSwap(swap);

  Get5KnifeRoundWonEvent knifeEvent =
      new Get5KnifeRoundWonEvent(g_MatchID, g_MapNumber, g_KnifeWinnerTeam,
                                 view_as<Get5Side>(g_TeamStartingSide[g_KnifeWinnerTeam]), swap);

  LogDebug("Calling Get5_OnKnifeRoundWon()");

  Call_StartForward(g_OnKnifeRoundWon);
  Call_PushCell(knifeEvent);
  Call_Finish();

  if (g_KnifeDecisionTimer != INVALID_HANDLE) {
    LogDebug("Stopped knife decision timer as a choice was made before it expired.");
    delete g_KnifeDecisionTimer;
  }

  EventLogger_LogAndDeleteEvent(knifeEvent);
  g_KnifeWinnerTeam = Get5Team_None;
  StartGoingLive();
}

static bool AwaitingKnifeDecision(int client) {
  bool waiting = g_GameState == Get5State_WaitingForKnifeRoundDecision;
  bool onWinningTeam = IsPlayer(client) && GetClientMatchTeam(client) == g_KnifeWinnerTeam;
  bool admin = (client == 0);
  return waiting && (onWinningTeam || admin);
}

Action Command_Stay(int client, int args) {
  if (AwaitingKnifeDecision(client)) {
    Get5_MessageToAll("%t", "TeamDecidedToStayInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);
    EndKnifeRound(false);
  }
  return Plugin_Handled;
}

Action Command_Swap(int client, int args) {
  if (AwaitingKnifeDecision(client)) {
    Get5_MessageToAll("%t", "TeamDecidedToSwapInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);
    EndKnifeRound(true);
  } else if (g_GameState == Get5State_Warmup && g_InScrimMode &&
             GetClientMatchTeam(client) == Get5Team_1) {
    PerformSideSwap(true);
  }
  return Plugin_Handled;
}

Action Command_Ct(int client, int args) {
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

Action Command_T(int client, int args) {
  if (IsPlayer(client)) {
    if (GetClientTeam(client) == CS_TEAM_T)
      FakeClientCommand(client, "sm_stay");
    else if (GetClientTeam(client) == CS_TEAM_CT)
      FakeClientCommand(client, "sm_swap");
  }
  return Plugin_Handled;
}

Action Timer_ForceKnifeDecision(Handle timer) {
  g_KnifeDecisionTimer = INVALID_HANDLE;
  if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    Get5_MessageToAll("%t", "TeamLostTimeToDecideInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);
    EndKnifeRound(false);
  }
}
