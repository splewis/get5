#include <cstrike>
#include <sourcemod>
#include "include/get5.inc"
#include "get5/version.sp"

public Plugin myinfo = {
    name = "Get5 logger",
    author = "splewis",
    description = "",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/get5"
};

stock void Get5_Log(const char[] msg, any ...) {
    char buffer[255];
    VFormat(buffer, sizeof(buffer), msg, 2);
    LogMessage("Get5-Logger: %s", buffer);
}

public void Get5_OnMapResult(const char[] map, MatchTeam mapWinner,
    int team1Score, int team2Score) {
    int winnerScore = team1Score;
    int loserScore = team2Score;
    if (mapWinner == MatchTeam_Team2) {
        winnerScore = team2Score;
        loserScore = team1Score;
    }

    Get5_Log("Get5_OnMapResult: Team %d won %s %d:%d",
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

    Get5_Log("Get5_OnSeriesResult: Team %d won the series %d:%d",
        seriesWinner, winnerScore, loserScore);
}

public void Get5_OnLoadMatchConfigFailed(const char[] reason) {
    Get5_Log("Get5_OnLoadMatchConfigFailed: %s", reason);
}

public void Get5_OnMapVetoed(MatchTeam team, const char[] map) {
    Get5_Log("Get5_OnMapVetoed: %d vetoed %s", team, map);
}

public void Get5_OnMapPicked(MatchTeam team, const char[] map) {
    Get5_Log("Get5_OnMapPicked: %d picked %s", team, map);
}

public void Get5_OnDemoFinished(const char[] filename) {
    Get5_Log("Get5_OnDemoFinished: finished recording", filename);
}
