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

  int requiredVotes = GetRequiredSurrenderVotes();

  // Player has already voted for surrender.
  if (g_SurrenderedPlayers[client]) {
    LogDebug("Player client %d has already voted to surrender.", client);
    Get5_MessageToTeam(team, "%t", "SurrenderVoteStatus", g_SurrenderVotes[team], requiredVotes);
    return Plugin_Handled;
  }

  g_SurrenderVotes[team]++;
  g_SurrenderedPlayers[client] = true;

  // On first surrender vote, start a timer
  if (g_SurrenderVotes[team] == 1) {
    if (requiredVotes > 1) {
      int surrenderTimeLimit = g_SurrenderVoteTimeLimitCvar.IntValue;
      if (surrenderTimeLimit < 10) {
        surrenderTimeLimit = 10;
      }
      char playerNameFormatted[MAX_NAME_LENGTH];
      FormatPlayerName(playerNameFormatted, sizeof(playerNameFormatted), client, team);
      Get5_MessageToTeam(team, "%t", "SurrenderInitiated", playerNameFormatted, requiredVotes, surrenderTimeLimit);
      g_SurrenderTimers[team] = CreateTimer(float(surrenderTimeLimit), Timer_SurrenderFailed, team);
    }
  } else {
    Get5_MessageToTeam(team, "%t", "SurrenderVoteStatus", g_SurrenderVotes[team], requiredVotes);
  }

  if (g_SurrenderVotes[team] >= requiredVotes) {
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

Action Command_FFW(int client, int args) {
  if (g_GameState != Get5State_Live || client == 0 || !g_ForfeitEnabledCvar.BoolValue) {
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

void AnnounceRemainingForfeitTime(const int remainingSeconds, const Get5Team forfeitingTeam) {
  char formattedTimeRemaining[32];
  ConvertSecondsToMinutesAndSeconds(remainingSeconds, formattedTimeRemaining, sizeof(formattedTimeRemaining));
  FormatTimeString(formattedTimeRemaining, sizeof(formattedTimeRemaining), formattedTimeRemaining);

  if (forfeitingTeam != Get5Team_None) {
    char formattedCancelFFWCommand[64];
    GetChatAliasForCommand(Get5ChatCommand_CancelFFW, formattedCancelFFWCommand, sizeof(formattedCancelFFWCommand),
                           true);
    Get5_MessageToAll("%t", "WinByForfeitCountdownStarted", g_FormattedTeamNames[OtherMatchTeam(forfeitingTeam)],
                      formattedTimeRemaining, g_FormattedTeamNames[forfeitingTeam], formattedCancelFFWCommand);
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

void StartForfeitTimer(const Get5Team forfeitingTeam) {
  g_ForfeitSecondsPassed = 0;
  g_ForfeitingTeam = forfeitingTeam;
  g_ForfeitTimer = CreateTimer(1.0, Timer_ForfeitCountdownCheck, _, TIMER_REPEAT);
  LogDebug("Started timer to forfeit for team %d in %d seconds.", forfeitingTeam, GetForfeitGracePeriod());
}

Action Command_CancelFFW(int client, int args) {
  if (g_GameState != Get5State_Live || client == 0 || g_ForfeitingTeam == Get5Team_None ||
      g_ForfeitTimer == INVALID_HANDLE) {
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
  AnnounceForfeitCanceled();  // must be before ResetForfeitTimer() or the message will be wrong.
  ResetForfeitTimer();
  return Plugin_Handled;
}

void SurrenderMap(Get5Team team) {
  Get5Side side = view_as<Get5Side>(Get5TeamToCSTeam(team));
  CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue,
                    side == Get5Side_CT ? CSRoundEnd_CTSurrender : CSRoundEnd_TerroristsSurrender);
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

static Action Timer_ForfeitCountdownCheck(Handle timer) {
  if (g_GameState == Get5State_None) {
    LogDebug("Game state is none. Stopping forfeit timer.");
    g_ForfeitTimer = INVALID_HANDLE;
    ResetForfeitTimer();  // must go after g_ForfeitTimer = INVALID_HANDLE to avoid timer exception.
    return Plugin_Stop;
  }

  // We can't *just* check that both teams have players, as this opens up this path of abuse:
  // 1. Team 1 disconnects.
  // 2. Team 2 requests win by forfeit; team 1's forfeit timer starts.
  // 3. Team 2 all leave; no timer is started for them as one is running for team 1.
  // 4. Team 1 rejoins; team 2 now has no players and the timer is not stopped.
  // 5. Team 1 loses even though they were present.
  if (g_ForfeitingTeam != Get5Team_None) {
    if (GetTeamPlayerCount(g_ForfeitingTeam) > 0) {
      LogDebug("Stopping forfeit timer for team %d.", g_ForfeitingTeam);
      AnnounceForfeitCanceled();  // must go before ResetForfeitTimer()
      g_ForfeitTimer = INVALID_HANDLE;
      ResetForfeitTimer();
      return Plugin_Stop;
    }
  } else if (GetTeamPlayerCount(Get5Team_1) > 0 && GetTeamPlayerCount(Get5Team_2) > 0) {
    LogDebug("Stopping tie countdown timer as both teams now have players.");
    AnnounceForfeitCanceled();  // must go before ResetForfeitTimer()
    g_ForfeitTimer = INVALID_HANDLE;
    ResetForfeitTimer();
    return Plugin_Stop;
  }

  g_ForfeitSecondsPassed++;
  int gracePeriod = GetForfeitGracePeriod();
  if (g_ForfeitSecondsPassed < gracePeriod) {  // don't <= gracePeriod; zero seconds left should not trigger and return.
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
  // TODO: GOTV will freeze here if players forfeit due to the flush bug, but the server is not locked in post-game
  // screen, so it is risky to assume we can just wait the entire GOTV delay before we flush the demo file.
  // Lagging in this case might not be a real problem either as it's probably not an exiting match to watch the
  // surrender timeout.
  StopRecording(5.0);  // add 5 seconds to include announcement, so players know why they are potentially kicked.
  Get5Team winningTeam = Get5Team_None;
  if (g_ForfeitingTeam != Get5Team_None) {
    // We only announce if it's not a tie.
    Get5_MessageToAll("%t", "TeamForfeited", g_FormattedTeamNames[g_ForfeitingTeam]);
    winningTeam = OtherMatchTeam(g_ForfeitingTeam);
  }
  EndSeries(winningTeam, g_ForfeitingTeam == Get5Team_None, float(GetTvDelay()) + 5.0);
  return Plugin_Stop;
}

int GetForfeitGracePeriod() {
  int forfeitGracePeriod = g_ForfeitCountdownTimeCvar.IntValue;
  if (forfeitGracePeriod < 30) {
    forfeitGracePeriod = 30;
  }
  return forfeitGracePeriod;
}

static int GetRequiredSurrenderVotes() {
  int requiredVotes = g_VotesRequiredForSurrenderCvar.IntValue;
  if (g_PlayersPerTeam < requiredVotes) {
    // Don't exceed the number of players on a team.
    requiredVotes = g_PlayersPerTeam;
  }
  return requiredVotes > 0 ? requiredVotes : 1;
}
