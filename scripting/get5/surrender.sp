Action Command_Surrender(int client, int args) {
  if (g_GameState != Get5State_Live || client == 0) {
    return Plugin_Handled;
  }

  Get5Side side = view_as<Get5Side>(GetClientTeam(client));
  if (side != Get5Side_CT && side != Get5Side_T) {
    return Plugin_Handled;
  }

  Get5Team team = GetClientMatchTeam(client);
  if (team != Get5Team_1 && team != Get5Team_2) {
    return Plugin_Handled;
  }

  if (g_PendingSurrenderTeam != Get5Team_None) {
    LogDebug("There's a pending surrendered team for round start; ignore surrender command from client %d.", client);
    return Plugin_Handled;
  }

  if (!g_SurrenderEnabledCvar.BoolValue) {
    Get5_MessageToAll("%t", "SurrenderCommandNotEnabled");
    return Plugin_Handled;
  }

  int teamScore = CS_GetTeamScore(view_as<int>(side));
  int otherTeamScore = CS_GetTeamScore(view_as<int>(side == Get5Side_CT ? Get5Side_T : Get5Side_CT));

  int minimumRoundDeficit = g_MinimumRoundDeficitForSurrenderCvar.IntValue;
  if (minimumRoundDeficit < 1) {
    minimumRoundDeficit = 1;
  }

  if (otherTeamScore - teamScore < minimumRoundDeficit) {
    Get5_MessageToTeam(team, "%t", "SurrenderMinimumRoundDeficit", minimumRoundDeficit);
    return Plugin_Handled;
  }

  if (g_SurrenderCooldownCvar.IntValue > 0 && g_SurrenderFailedAt[team] > 0) {

    int timeSinceFailedSurrender = GetMilliSecondsPassedSince(g_SurrenderFailedAt[team]) / 1000;
    int surrenderCooldownLength = g_SurrenderCooldownCvar.IntValue;

    if (timeSinceFailedSurrender < surrenderCooldownLength) {
      int timeRemainingUntilUnlock = surrenderCooldownLength - timeSinceFailedSurrender;
      char timeLeftFormatted[32];
      ConvertSecondsToMinutesAndSeconds(timeRemainingUntilUnlock, timeLeftFormatted, sizeof(timeLeftFormatted));
      FormatTimeString(timeLeftFormatted, sizeof(timeLeftFormatted), timeLeftFormatted);
      Get5_MessageToTeam(team, "%t", "SurrenderOnCooldown", timeLeftFormatted);
      return Plugin_Handled;
    }
  }

  // Player has already voted for surrender.
  if (g_SurrenderedPlayers[client]) {
    LogDebug("Player client %d has already voted to surrender.", client);
    Get5_MessageToTeam(team, "%t", "SurrenderVoteStatus", g_SurrenderVotes[team], g_VotesRequiredForSurrenderCvar.IntValue);
    return Plugin_Handled;
  }

  g_SurrenderVotes[team]++;
  g_SurrenderedPlayers[client] = true;

  // On first surrender vote, start a timer
  if (g_SurrenderVotes[team] == 1) {
    if (g_VotesRequiredForSurrenderCvar.IntValue > 1) {
      int surrenderTimeLimit = g_SurrenderVoteTimeLimitCvar.IntValue;
      if (surrenderTimeLimit < 10) {
        surrenderTimeLimit = 10;
      }
      char playerNameFormatted[MAX_NAME_LENGTH];
      FormatPlayerName(playerNameFormatted, sizeof(playerNameFormatted), client, team);
      Get5_MessageToTeam(team, "%t", "SurrenderInitiated", playerNameFormatted, g_VotesRequiredForSurrenderCvar.IntValue, surrenderTimeLimit);
      g_SurrenderTimers[team] = CreateTimer(float(surrenderTimeLimit), Timer_SurrenderFailed, team, TIMER_FLAG_NO_MAPCHANGE);
    }
  } else {
    Get5_MessageToTeam(team, "%t", "SurrenderVoteStatus", g_SurrenderVotes[team], g_VotesRequiredForSurrenderCvar.IntValue);
  }

  if (g_SurrenderVotes[team] >= g_VotesRequiredForSurrenderCvar.IntValue) {
    EndSurrenderTimers();
    Get5_MessageToAll("%t", "SurrenderSuccessful", g_FormattedTeamNames[team]);
    if (GetRoundsPlayed() != g_RoundNumber) {
      g_PendingSurrenderTeam = team;
    } else {
      SurrenderMap(team);
    }
  }
  return Plugin_Handled;
}

Action Command_Win(int client, int args) {
  if (g_GameState != Get5State_Live || client == 0) {
    return Plugin_Handled;
  }
  Get5Team team = GetClientMatchTeam(client);
  if (!IsPlayerTeam(team)) {
    return Plugin_Handled;
  }
  if (g_ForfeitTimer != INVALID_HANDLE) {
    Get5_MessageToAll("%t", "WinByForfeitAlreadyRequested");
    return Plugin_Handled;
  }
  Get5Team otherTeam = OtherMatchTeam(team);
  if (GetTeamPlayerCount(otherTeam) > 0) {
    return Plugin_Handled;
  }
  if (GetTeamPlayerCount(team) < g_PlayersPerTeam) {
    Get5_MessageToAll("%t", "WinByForfeitRequiresFullTeam");
    return Plugin_Handled;
  }
  AnnounceRemainingForfeitTime(GetForfeitGracePeriod(), otherTeam);
  StartForfeitTimer(otherTeam);
  return Plugin_Handled;
}

static void AnnounceRemainingForfeitTime(const int remainingSeconds, const Get5Team forfeitingTeam) {
  char formattedTimeRemaining[32];
  ConvertSecondsToMinutesAndSeconds(remainingSeconds, formattedTimeRemaining, sizeof(formattedTimeRemaining));
  FormatTimeString(formattedTimeRemaining, sizeof(formattedTimeRemaining), formattedTimeRemaining);

  if (forfeitingTeam != Get5Team_None) {
    char formattedCancelWinCommand[64];
    FormatChatCommand(formattedCancelWinCommand, sizeof(formattedCancelWinCommand), "!cancelwin");

    Get5_MessageToAll("%t", "WinByForfeitCountdownStarted",
      g_FormattedTeamNames[OtherMatchTeam(forfeitingTeam)],
      formattedTimeRemaining,
      g_FormattedTeamNames[forfeitingTeam],
      formattedCancelWinCommand
    );
  } else {
    Get5_MessageToAll("%t", "AllPlayersLeftTieCountdown", formattedTimeRemaining);
  }
}

static void AnnounceForfeitCanceled() {
  if (g_ForfeitingTeam != Get5Team_None) {
    Get5_MessageToAll("%t", "WinByForfeitCountdownCanceled", g_FormattedTeamNames[OtherMatchTeam(g_ForfeitingTeam)]);
  } else {
    Get5_MessageToAll("%t", "TieCountdownCanceled");
  }
}

void ResetForfeitTimer() {
  if (g_ForfeitTimer != INVALID_HANDLE) {
    LogDebug("Killed g_ForfeitTimer.");
    delete g_ForfeitTimer;
  }
  g_ForfeitSecondsPassed = 0;
  g_ForfeitingTeam = Get5Team_None;
}

static void StartForfeitTimer(const Get5Team forfeitingTeam) {
  g_ForfeitSecondsPassed = 0;
  g_ForfeitingTeam = forfeitingTeam;
  g_ForfeitTimer = CreateTimer(1.0, Timer_ForfeitCountdownCheck, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
  LogDebug("Started timer to forfeit for team %d in %d seconds.", forfeitingTeam, GetForfeitGracePeriod());
}

Action Command_CancelWin(int client, int args) {
  if (g_GameState != Get5State_Live || client == 0 || g_ForfeitingTeam == Get5Team_None || g_ForfeitTimer == INVALID_HANDLE) {
    return Plugin_Handled;
  }
  Get5Team team = GetClientMatchTeam(client);
  if (!IsPlayerTeam(team)) {
   return Plugin_Handled;
  }
  if (GetTeamPlayerCount(team) < g_PlayersPerTeam) {
    Get5_MessageToAll("%t", "WinByForfeitRequiresFullTeam");
    return Plugin_Handled;
  }
  ResetForfeitTimer();
  AnnounceForfeitCanceled();
  return Plugin_Handled;
}

void SurrenderMap(Get5Team team) {
  Get5Side side = view_as<Get5Side>(Get5TeamToCSTeam(team));
  CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, side == Get5Side_CT ? CSRoundEnd_CTSurrender : CSRoundEnd_TerroristsSurrender);
}

void EndSurrenderTimers() {
  g_PendingSurrenderTeam = Get5Team_None;
  LOOP_CLIENTS(i) {
    g_SurrenderedPlayers[i] = false;
  }
  LOOP_TEAMS(team) {
    g_SurrenderVotes[team] = 0;
    g_SurrenderFailedAt[team] = 0.0;
    if (g_SurrenderTimers[team] != INVALID_HANDLE) {
      delete g_SurrenderTimers[team];
    }
  }
}

static Action Timer_SurrenderFailed(Handle timer, Get5Team team) {
  g_SurrenderTimers[team] = INVALID_HANDLE;
  g_SurrenderVotes[team] = 0;
  g_SurrenderFailedAt[team] = GetEngineTime();
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && view_as<Get5Team>(GetClientMatchTeam(i)) == team) {
      g_SurrenderedPlayers[i] = false;
    }
  }
  Get5_MessageToTeam(team, "%t", "SurrenderVoteFailed");
  return Plugin_Handled;
}

void CheckForfeitStateOnConnect() {
  if (g_ForfeitTimer == INVALID_HANDLE) {
    return;
  }
  if (g_GameState <= Get5State_Warmup) {
    // Timer is always reset if someone joins the server in warmup/veto.
    // We don't call AnnounceForfeitCanceled here as the timer may be triggered
    // by client force-reconnect logic when players first join the server.
    ResetForfeitTimer();
    return;
  }

  int team1Count = GetTeamPlayerCount(Get5Team_1);
  int team2Count = GetTeamPlayerCount(Get5Team_2);

  if (g_ForfeitingTeam == Get5Team_1) {
    if (team1Count == 0) {
      // Team 1 left the server and they have no players yet; continue counting down.
      return;
    }
  } else if (g_ForfeitingTeam == Get5Team_2) {
    if (team2Count == 0) {
      // Team 2 left the server and they have no players yet; continue counting down.
      return;
    }
  } else if (team1Count == 0 || team2Count == 0) {
    // Else we're waiting for both teams and they must both rejoin to stop the timer; continue countdown down.
    return;
  }
  AnnounceForfeitCanceled();
  ResetForfeitTimer();
}

void CheckForForfeitOnDisconnect() {
  if (g_GameState == Get5State_None || g_GameState == Get5State_PostGame
    || g_GameState == Get5State_PendingRestore || g_MapChangePending) {
    return;
  }

  if (g_ForfeitTimer != INVALID_HANDLE) {
    LogDebug("Forfeit timer already started on player disconnect, ignoring.");
    return;
  }

  int team1Count = GetTeamPlayerCount(Get5Team_1);
  int team2Count = GetTeamPlayerCount(Get5Team_2);

  Get5Team forfeitingTeam = Get5Team_None;

  if (g_GameState <= Get5State_Warmup && g_TeamTimeToStartCvar.IntValue > 0) {
    // If we're in warmup or veto and a "time to ready" value is defined; let that handle it.
    return;
  } else if (team1Count > 0 && team2Count > 0) {
    // If both teams still have at least one player; do nothing.
    return;
  } else if (team1Count == g_PlayersPerTeam) {
    // team2 has no players, team1 is full
    forfeitingTeam = Get5Team_2;
  } else if (team2Count == g_PlayersPerTeam) {
    // team1 has no players, team2 is full
    forfeitingTeam = Get5Team_1;
  } else if (team1Count > 0 || team2Count > 0) {
    // The server still has some players on either team, but none are full or empty.
    return;
  }

  if (forfeitingTeam == Get5Team_None) {
    // End here if no players are left and we're not in warmup/veto with time to ready.
    AnnounceRemainingForfeitTime(GetForfeitGracePeriod(), Get5Team_None);
    StartForfeitTimer(Get5Team_None);
    return;
  }

  if (g_GameState != Get5State_Live) {
    return;
  }
  // One team is full, the other team left; announce that they can request to !win
  char winCommandFormatted[32];
  FormatChatCommand(winCommandFormatted, sizeof(winCommandFormatted), "!win");
  Get5_MessageToAll("%t", "WinByForfeitAvailable", g_FormattedTeamNames[forfeitingTeam],
   g_FormattedTeamNames[OtherMatchTeam(forfeitingTeam)],
    winCommandFormatted
  );
}

static Action Timer_ForfeitCountdownCheck(Handle timer) {
  if (g_GameState == Get5State_None) {
    LogDebug("Game state is none. Stopping forfeit timer.");
    g_ForfeitTimer = INVALID_HANDLE;
    return Plugin_Stop;
  }

  if (g_ForfeitingTeam != Get5Team_None && GetTeamPlayerCount(g_ForfeitingTeam) > 0) {
    LogDebug("Forfeiting team now has players. Stopping forfeit timer.");
    g_ForfeitTimer = INVALID_HANDLE;
    return Plugin_Stop;
  }

  if (GetTeamPlayerCount(Get5Team_1) > 0 && GetTeamPlayerCount(Get5Team_2) > 0) {
    LogDebug("Both teams have players. Stopping tie-forfeit timer.");
    g_ForfeitTimer = INVALID_HANDLE;
    return Plugin_Stop;
  }

  g_ForfeitSecondsPassed++;
  int gracePeriod = GetForfeitGracePeriod();
  if (g_ForfeitSecondsPassed < gracePeriod) { // don't <= gracePeriod; zero seconds left should not trigger.
    int remainingSeconds = gracePeriod - g_ForfeitSecondsPassed;
    if (remainingSeconds % 30 == 0 || remainingSeconds == 10) {
      AnnounceRemainingForfeitTime(remainingSeconds, g_ForfeitingTeam);
    }
    return Plugin_Continue;
  }

  // This must go before EndSeries() or it will raise an exception from trying to cancel the timer
  // inside the timer's callback.
  g_ForfeitTimer = INVALID_HANDLE;

  LogDebug("Forfeit timer expired. Ending series with %d as forfeiting team.", g_ForfeitingTeam);
  StopRecording(5.0); // add 5 seconds to include announcement, so players know why they are potentially kicked.
  Get5Team winningTeam = Get5Team_None;
  if (g_ForfeitingTeam != Get5Team_None) {
    // We only announce if it's not a tie.
    Get5_MessageToAll("%t", "TeamForfeited", g_FormattedTeamNames[g_ForfeitingTeam]);
    winningTeam = OtherMatchTeam(g_ForfeitingTeam);
  }
  EndSeries(winningTeam, g_ForfeitingTeam == Get5Team_None, float(GetTvDelay()) + 5.0);
  return Plugin_Stop;
}

static int GetForfeitGracePeriod() {
  int forfeitGracePeriod = g_ForfeitCountdownTimeCvar.IntValue;
  if (forfeitGracePeriod < 30) {
    forfeitGracePeriod = 30;
  }
  return forfeitGracePeriod;
}
