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
      char timeLeftFormatted[8];
      convertSecondsToMinutesAndSeconds(timeRemainingUntilUnlock, timeLeftFormatted, sizeof(timeLeftFormatted));
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

void SurrenderMap(Get5Team team) {
  Get5Side side = view_as<Get5Side>(Get5TeamToCSTeam(team));
  CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, side == Get5Side_CT ? CSRoundEnd_CTSurrender : CSRoundEnd_TerroristsSurrender);
}

void EndSurrenderTimers() {
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

void CheckSurrenderStateOnConnect() {
  if (g_GameState == Get5State_None) {
    return;
  }

  // No timer is running; nothing to do.
  if (g_EndMatchOnEmptyServerTimer == INVALID_HANDLE) {
    return;
  }

  int team1Count = GetTeamPlayerCount(Get5Team_1);
  int team2Count = GetTeamPlayerCount(Get5Team_2);

  if (team1Count == 0 || team2Count == 0) {
    // Both teams must have at least one player to end the timer.
    return;
  }

  LogDebug("Stopped end-match/surrender timeout as both teams have players.");
  delete g_EndMatchOnEmptyServerTimer;
  if (team1Count == g_PlayersPerTeam || team2Count == g_PlayersPerTeam) {
    // If a full team is sitting in the server, waiting for the other team to rejoin, inform players that the
    // surrender countdown was canceled when the first player rejoins the game. We check both teams simply
    // because we don't know which team triggered the surrender timer at this stage. If we didn't, this would be
    // announced in the event that both teams left the server and rejoined, in which case there is no actual surrender
    // to dismiss.
    Get5_MessageToAll("%t", "SurrenderRejoinCountdownCanceled");
  }
}

void CheckForSurrenderOnDisconnect() {
  if (g_GameState == Get5State_None || g_GameState == Get5State_PostGame || g_MapChangePending) {
    return;
  }

  if (g_EndMatchOnEmptyServerTimer != INVALID_HANDLE) {
    // Timer is already running: don't start another. We would end here if one full team disconnects and then
    // the opposing team leaves after that. We don't want to override the fact that a team already left; they should
    // lose the game, it shouldn't be a tie.
    return;
  }

  int team1Count = GetTeamPlayerCount(Get5Team_1);
  int team2Count = GetTeamPlayerCount(Get5Team_2);

  // If a team starts leaving, we want to inform the other team to stay on the server to get their win.
  // In 5v5, this would trigger when only 2 players remain on a team.
  int halfTeam = (g_PlayersPerTeam / 2);
  if (team1Count == g_PlayersPerTeam && team2Count == halfTeam) {
    Get5_MessageToAll("%t", "SurrenderTeamAppearsToLeaveWarning", g_FormattedTeamNames[Get5Team_2], g_FormattedTeamNames[Get5Team_1]);
  } else if (team2Count == g_PlayersPerTeam && team1Count == halfTeam) {
    Get5_MessageToAll("%t", "SurrenderTeamAppearsToLeaveWarning", g_FormattedTeamNames[Get5Team_1], g_FormattedTeamNames[Get5Team_2]);
  }

  // If both teams still have at least one player; do nothing.
  if (team1Count > 0 && team2Count > 0) {
    LogDebug("Both teams had players; no disconnect trigger.");
    return;
  }

  Get5Team surrenderingTeam = Get5Team_None;
  if (team1Count == g_PlayersPerTeam && team2Count == 0) {
    surrenderingTeam = Get5Team_2;
  } else if (team2Count == g_PlayersPerTeam && team1Count == 0) {
    surrenderingTeam = Get5Team_1;
  }

  int surrenderRejoinTime = g_SurrenderTimeToRejoinCvar.IntValue;
  if (surrenderRejoinTime < 30) {
    surrenderRejoinTime = 30;
  }
  char surrenderSecondsFormatted[32];
  FormatEx(surrenderSecondsFormatted, sizeof(surrenderSecondsFormatted), "{GREEN}%d{NORMAL}", surrenderRejoinTime);
  if (surrenderingTeam == Get5Team_None) {
    // We end here if people start leaving at the same time; if none of the teams are full and no full team disconnected.
    Get5_MessageToAll("%t", "AllPlayersLeftTieCountdown", surrenderSecondsFormatted);
  } else {
    Get5Team winningTeam = surrenderingTeam == Get5Team_1 ? Get5Team_2 : Get5Team_1;
    Get5_MessageToAll("%t", "SurrenderTeamMustRejoin", g_FormattedTeamNames[surrenderingTeam],
      surrenderSecondsFormatted,
      g_FormattedTeamNames[winningTeam]);
  }
  LogDebug("Starting timer to end the match in %d seconds. Surrendering team will be %d.", surrenderRejoinTime, surrenderingTeam);
  g_EndMatchOnEmptyServerTimer = CreateTimer(float(surrenderRejoinTime), Timer_EndEmptyServer, surrenderingTeam);
}

static Action Timer_EndEmptyServer(Handle timer, Get5Team surrenderingTeam) {
  g_EndMatchOnEmptyServerTimer = INVALID_HANDLE;
  if (g_GameState == Get5State_None) {
    return;
  }
  if (GetTeamPlayerCount(Get5Team_1) > 0 && GetTeamPlayerCount(Get5Team_2) > 0) {
    LogDebug("Surrender timer expired but both teams had players. No action taken.");
    return;
  }

  LogDebug("Surrender timer expired. Ending series with %d as surrendering team.", surrenderingTeam);
  if (surrenderingTeam != Get5Team_None) {
    // We only announce if it's not a tie.
    Get5_MessageToAll("%t", "SurrenderSuccessful", g_FormattedTeamNames[surrenderingTeam]);
  }

  if (surrenderingTeam != Get5Team_None && !InHalftimePhase() && !InWarmup() && GetRealClientCount() > 0) {
    // We probably cannot call a surrender if there are no players in the game, so we only do this if at least one
    // player remains on what at this stage can only be the winning team. It probably also would be buggy if called
    // during halftime or warmup, so we skip that as well.
    Get5Side side = view_as<Get5Side>(Get5TeamToCSTeam(surrenderingTeam));
    CS_TerminateRound(FindConVar("mp_round_restart_delay").FloatValue, side == Get5Side_CT ? CSRoundEnd_CTSurrender : CSRoundEnd_TerroristsSurrender);
  } else {
    // One of:
    // 1. Both teams left the server and it's a tie
    // 2. One team left, then the other team left and there are now no players on the server
    // 3. It's half-time.
    // 4. It's warmup
    // We just end the match.
    StopRecording(5.0); // add 5 seconds to include announcement, so players know why they are potentially kicked.
    Get5Team winningTeam = Get5Team_None;
    if (surrenderingTeam == Get5Team_1) {
      winningTeam = Get5Team_2;
    } else if (surrenderingTeam == Get5Team_2) {
      winningTeam = Get5Team_1;
    }
    EndSeries(winningTeam, false, float(GetTvDelay()) + 5.0);
  }
}
