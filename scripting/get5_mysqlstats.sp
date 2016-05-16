#include <cstrike>
#include <sourcemod>
#include "include/get5.inc"
#include "get5/util.sp"
#include "get5/version.sp"


Database db = null;
char queryBuffer[1024];

int g_MatchID = -1;
int g_MapNumber = 0;

ConVar g_ForceMatchIDCvar;
bool g_DisableStats = false;


public Plugin myinfo = {
    name = "Get5 MySQL stats",
    author = "splewis",
    description = "Records match stats collected by get5 to MySQL",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/get5"
};

public void OnPluginStart() {
    g_ForceMatchIDCvar = CreateConVar("get5_mysql_force_matchid", "0", "If set to a positive integer, this will force get5 to use the matchid in this convar");

    char error[255];
    db = SQL_Connect("get5", true, error, sizeof(error));
    if (db == null) {
        SetFailState("Could not connect to get5 database: %s", error);
    } else {
        g_DisableStats = false;
        db.SetCharset("utf8");
    }
}

public void Get5_OnSeriesInit() {
    g_MatchID = -1;
    g_MapNumber = 0;

    char seriesType[64];
    char team1Name[64];
    char team2Name[64];

    char seriesTypeSz[sizeof(seriesType)*2 + 1];
    char team1NameSz[sizeof(team1Name)*2 + 1];
    char team2NameSz[sizeof(team2Name)*2 + 1];

    KeyValues tmpStats = new KeyValues("Stats");

    Get5_GetMatchStats(tmpStats);
    tmpStats.GetString(STAT_SERIESTYPE, seriesType, sizeof(seriesType));
    db.Escape(seriesType, seriesTypeSz, sizeof(seriesTypeSz));

    tmpStats.JumpToKey("team1", true);
    tmpStats.GetString("name", team1Name, sizeof(team1Name));
    db.Escape(team1Name, team1NameSz, sizeof(team1NameSz));
    tmpStats.GoBack();

    tmpStats.JumpToKey("team2", true);
    tmpStats.GetString("name", team2Name, sizeof(team2Name));
    db.Escape(team2Name, team2NameSz, sizeof(team2NameSz));
    tmpStats.GoBack();

    delete tmpStats;

    g_DisableStats = false;
    if (g_ForceMatchIDCvar.IntValue > 0) {
        SetMatchID(g_ForceMatchIDCvar.IntValue);
        g_ForceMatchIDCvar.IntValue = 0;
        Format(queryBuffer, sizeof(queryBuffer),
            "INSERT INTO `get5_stats_matches` \
            (matchid, series_type, team1_name, team2_name) VALUES \
            (%d, '%s', '%s', '%s')",
            g_MatchID, seriesTypeSz, team1NameSz, team2NameSz);
        db.Query(SQLErrorCheckCallback, queryBuffer);

        LogMessage("Starting match id %d", g_MatchID);

    } else {
        Transaction t = SQL_CreateTransaction();

        Format(queryBuffer, sizeof(queryBuffer),
            "INSERT INTO `get5_stats_matches` \
            (series_type, team1_name, team2_name) VALUES \
            ('%s', '%s', '%s')",
            seriesTypeSz, team1NameSz, team2NameSz);
        t.AddQuery(queryBuffer);

        Format(queryBuffer, sizeof(queryBuffer),
            "SELECT LAST_INSERT_ID()");
        t.AddQuery(queryBuffer);

        db.Execute(t, MatchInitSuccess, MatchInitFailure);
    }
}

public void MatchInitSuccess(Database database, any data, int numQueries, Handle[] results, any[] queryData) {
    Handle matchidResult = results[1];
    if (SQL_FetchRow(matchidResult)) {
        SetMatchID(SQL_FetchInt(matchidResult, 0));
        LogMessage("Starting match id %d", g_MatchID);
    } else {
        LogError("Failed to get matchid from match init query");
        g_DisableStats = true;
    }
}

public void MatchInitFailure(Database database, any data, int numQueries, const char[] error, int failIndex, any[] queryData) {
    LogError("Failed match creation query, error = %s", error);
    g_DisableStats = true;
}

static void SetMatchID(int matchid) {
    g_MatchID = matchid;
    char idStr[32];
    IntToString(g_MatchID, idStr, sizeof(idStr));
    Get5_SetMatchID(idStr);
}

public void Get5_OnGoingLive(int mapNumber) {
    if (g_DisableStats)
        return;

    g_MapNumber = mapNumber;

    char mapName[255];
    GetCurrentMap(mapName, sizeof(mapName));

    char mapNameSz[sizeof(mapName)*2 + 1];
    db.Escape(mapName, mapNameSz, sizeof(mapNameSz));

    Format(queryBuffer, sizeof(queryBuffer),
        "INSERT INTO `get5_stats_maps` \
        (matchid, mapnumber, mapname) VALUES \
        (%d, %d, '%s')",
        g_MatchID, mapNumber, mapNameSz);

    db.Query(SQLErrorCheckCallback, queryBuffer);
}

public void Get5_OnMapResult(const char[] map, MatchTeam mapWinner,
    int team1Score, int team2Score, int mapNumber) {
    if (g_DisableStats)
        return;

    char winnerString[64];
    GetTeamString(mapWinner, winnerString, sizeof(winnerString));

    Format(queryBuffer, sizeof(queryBuffer),
        "UPDATE `get5_stats_maps` \
        SET winner = '%s', team1_score = %d, team2_score = %d WHERE matchid = %d and mapnumber = %d",
        winnerString, team1Score, team2Score, g_MatchID, mapNumber);
    db.Query(SQLErrorCheckCallback, queryBuffer);

    KeyValues kv = new KeyValues("Stats");
    Get5_GetMatchStats(kv);
    char mapKey[32];
    Format(mapKey, sizeof(mapKey), "map%d", mapNumber);
    if (kv.JumpToKey(mapKey)) {
        if (kv.JumpToKey("team1")) {
            AddPlayerStats(kv, MatchTeam_Team1);
            kv.GoBack();
        }
        if (kv.JumpToKey("team2")) {
            AddPlayerStats(kv, MatchTeam_Team2);
            kv.GoBack();
        }
        kv.GoBack();
    }
    delete kv;
}

public void AddPlayerStats(KeyValues kv, MatchTeam team) {
    char name[MAX_NAME_LENGTH];
    char auth[AUTH_LENGTH];
    char nameSz[MAX_NAME_LENGTH*2 + 1];
    char authSz[AUTH_LENGTH*2 + 1];

    if (kv.GotoFirstSubKey()) {
        do {
            kv.GetSectionName(auth, sizeof(auth));
            kv.GetString("name", name, sizeof(name));
            db.Escape(auth, authSz, sizeof(authSz));
            db.Escape(name, nameSz, sizeof(nameSz));

            int kills = kv.GetNum(STAT_KILLS);
            int deaths = kv.GetNum(STAT_DEATHS);
            int assists = kv.GetNum(STAT_ASSISTS);
            int teamkills = kv.GetNum(STAT_TEAMKILLS);
            int damage = kv.GetNum(STAT_DAMAGE);
            int headshot_kills = kv.GetNum(STAT_HEADSHOT_KILLS);
            int roundsplayed = kv.GetNum(STAT_ROUNDSPLAYED);
            int plants = kv.GetNum(STAT_BOMBPLANTS);
            int defuses = kv.GetNum(STAT_BOMBDEFUSES);
            int v1 = kv.GetNum(STAT_V1);
            int v2 = kv.GetNum(STAT_V2);
            int v3 = kv.GetNum(STAT_V3);
            int v4 = kv.GetNum(STAT_V4);
            int v5 = kv.GetNum(STAT_V5);

            char teamString[16];
            GetTeamString(team, teamString, sizeof(teamString));

            Format(queryBuffer, sizeof(queryBuffer),
                "INSERT IGNORE INTO `get5_stats_players` \
                (matchid, mapnumber, steamid64, team, \
                rounds_played, name, kills, deaths, \
                assists, teamkills, headshot_kills, damage, \
                bomb_plants, bomb_defuses, \
                v1, v2, v3, v4, v5 \
                ) VALUES \
                (%d, %d, '%s', '%s', \
                %d, '%s', %d, %d, \
                %d, %d, %d, %d, \
                %d, %d, \
                %d, %d, %d, %d, %d)",
                g_MatchID, g_MapNumber, authSz, teamString,
                roundsplayed, nameSz, kills, deaths,
                assists, teamkills, headshot_kills, damage,
                plants, defuses,
                v1, v2, v3, v4, v5);

            db.Query(SQLErrorCheckCallback, queryBuffer);

        } while (kv.GotoNextKey());
        kv.GoBack();
    }
}

public void Get5_OnSeriesResult(MatchTeam seriesWinner,
    int team1MapScore, int team2MapScore) {
    if (g_DisableStats)
        return;

    char winnerString[64];
    GetTeamString(seriesWinner, winnerString, sizeof(winnerString));

    Format(queryBuffer, sizeof(queryBuffer),
        "UPDATE `get5_stats_matches` \
        SET winner = '%s', team1_score = %d, team2_score = %d WHERE matchid = %d",
        winnerString, team1MapScore, team2MapScore, g_MatchID);
    db.Query(SQLErrorCheckCallback, queryBuffer);
}

public int SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, int data) {
    if (!StrEqual("", error)) {
        LogError("Last Connect SQL Error: %s", error);
    }
}
