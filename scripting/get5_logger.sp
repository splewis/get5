/**
 * =============================================================================
 * Get5 Logger
 * Copyright (C) 2016. Sean Lewis.  All rights reserved.
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <cstrike>
#include <sourcemod>

#include "get5/version.sp"
#include "include/get5.inc"

#include "get5/util.sp"

// clang-format off
public Plugin myinfo = {
  name = "Get5 logger",
  author = "splewis",
  description = "Provides logging for get5 forwards",
  version = PLUGIN_VERSION,
  url = "https://github.com/splewis/get5"
};
// clang-format on

public void Get5_OnSeriesInit() {
  LogMessage("Get5_OnSeriesInit");
}

public void Get5_OnGoingLive(int mapNumber) {
  LogMessage("Get5_OnGoingLive, mapNumber = %d", mapNumber);
}

public void Get5_OnGameStateChanged(GameState oldState, GameState newState) {
  LogMessage("Get5_OnGameStateChanged: %d -> %d", oldState, newState);
}

public void Get5_OnMapResult(const char[] map, MatchTeam mapWinner, int team1Score, int team2Score,
                      int mapNumber) {
  int winnerScore = team1Score;
  int loserScore = team2Score;
  if (mapWinner == MatchTeam_Team2) {
    winnerScore = team2Score;
    loserScore = team1Score;
  }

  char winnerString[32];
  GetTeamString(mapWinner, winnerString, sizeof(winnerString));

  LogMessage("Get5_OnMapResult: %s won %s (map%d) %d:%d", winnerString, map, mapNumber, winnerScore,
             loserScore);
}

public void Get5_OnSeriesResult(MatchTeam seriesWinner, int team1MapScore, int team2MapScore) {
  int winnerScore = team1MapScore;
  int loserScore = team2MapScore;
  if (seriesWinner == MatchTeam_Team2) {
    winnerScore = team2MapScore;
    loserScore = team1MapScore;
  }

  char winnerString[32];
  GetTeamString(seriesWinner, winnerString, sizeof(winnerString));

  LogMessage("Get5_OnSeriesResult: %s won the series %d:%d", winnerString, winnerScore, loserScore);
}

public void Get5_OnLoadMatchConfigFailed(const char[] reason) {
  LogMessage("Get5_OnLoadMatchConfigFailed: %s", reason);
}

public void Get5_OnMapVetoed(MatchTeam team, const char[] map) {
  LogMessage("Get5_OnMapVetoed: %d vetoed %s", team, map);
}

public void Get5_OnMapPicked(MatchTeam team, const char[] map) {
  LogMessage("Get5_OnMapPicked: %d picked %s", team, map);
}

public void Get5_OnDemoFinished(const char[] filename) {
  LogMessage("Get5_OnDemoFinished: finished recording", filename);
}
