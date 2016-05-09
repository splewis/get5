#include <cstrike>
#include <sourcemod>
#include "include/get5.inc"
#include "get5/version.sp"

public Plugin myinfo = {
    name = "Get5 logger",
    author = "splewis",
    description = "Provides logging for get5 forwards",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/get5"
};

public void Get5_OnGameStateChanged(GameState oldState, GameState newState) {
    LogMessage("Get5_OnGameStateChanged: %d -> %d", oldState, newState);
}

public void Get5_OnMapResult(const char[] map, MatchTeam mapWinner,
    int team1Score, int team2Score) {
    int winnerScore = team1Score;
    int loserScore = team2Score;
    if (mapWinner == MatchTeam_Team2) {
        winnerScore = team2Score;
        loserScore = team1Score;
    }

    LogMessage("Get5_OnMapResult: Team %d won %s %d:%d",
        mapWinner, map, winnerScore, loserScore);
}

public void Get5_OnSeriesResult(MatchTeam seriesWinner,
    int team1MapScore, int team2MapScore) {
    int winnerScore = team1MapScore;
    int loserScore = team2MapScore;
    if (seriesWinner == MatchTeam_Team2) {
        winnerScore = team2MapScore;
        loserScore = team1MapScore;
    }

    LogMessage("Get5_OnSeriesResult: Team %d won the series %d:%d",
        seriesWinner, winnerScore, loserScore);
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
