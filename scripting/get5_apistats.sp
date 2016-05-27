#include <cstrike>
#include <sourcemod>
#include "include/get5.inc"
#include "get5/util.sp"
#include "get5/version.sp"

#include <SteamWorks>
#include <smjansson>

#include "get5/jsonhelpers.sp"


int g_MatchID = -1;

ConVar g_APIKeyCvar;
char g_APIKey[128];

ConVar g_APIURLCvar;
char g_APIURL[128];


public Plugin myinfo = {
    name = "Get5 Web Integration",
    author = "splewis",
    description = "Records match stats to a get5 web api",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/get5"
};

public void OnPluginStart() {
    g_APIKeyCvar = CreateConVar("get5_web_api_key", "", "Match API key, this is automatically set through rcon");
    HookConVarChange(g_APIKeyCvar, ApiInfoChanged);

    g_APIURLCvar = CreateConVar("get5_web_api_url", "http://get5.splewis.net", "URL the get5 api is hosted at")
    HookConVarChange(g_APIURLCvar, ApiInfoChanged)

    RegConsoleCmd("get5_web_avaliable", Command_Avaliable);
}

public Action Command_Avaliable(int client, int args) {
    Handle json = json_object();

    set_json_int(json, "gamestate", view_as<int>(Get5_GetGameState()));
    set_json_int(json, "avaliable", 1);

    char buffer[128];
    json_dump(json, buffer, sizeof(buffer));
    ReplyToCommand(client, buffer);

    CloseHandle(json);

    return Plugin_Handled;
}

public void ApiInfoChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    g_APIKeyCvar.GetString(g_APIKey, sizeof(g_APIKey));
    g_APIURLCvar.GetString(g_APIURL, sizeof(g_APIURL));
}

static Handle CreateRequest(EHTTPMethod httpMethod, const char[] apiMethod, any:...) {
    char url[1024];
    Format(url, sizeof(url), "%s/%s", g_APIURL, apiMethod);

    char formattedUrl[1024];
    VFormat(formattedUrl, sizeof(formattedUrl), url, 3);

    Handle req = SteamWorks_CreateHTTPRequest(httpMethod, formattedUrl);
    if (req == INVALID_HANDLE || StrEqual(g_APIKey, "")) {
        LogError("Failed to create request to %s", formattedUrl);
        return INVALID_HANDLE;
    } else {
        SteamWorks_SetHTTPCallbacks(req, RequestCallback);
        AddStringParam(req, "key", g_APIKey);
        return req;
    }
}

public int RequestCallback(Handle request, bool failure, bool requestSuccessful,
                           EHTTPStatusCode statusCode) {
    if (failure || !requestSuccessful) {
        LogError("API request failed, HTTP status code = %d", statusCode);
        char response[1024];
        SteamWorks_GetHTTPResponseBodyData(request, response, sizeof(response));
        LogError(response);
        return;
    }

}

public void Get5_OnBackupRestore() {
    char matchid[64];
    Get5_GetMatchID(matchid, sizeof(matchid));
    g_MatchID = StringToInt(matchid);
}

public void Get5_OnSeriesInit() {
    char matchid[64];
    Get5_GetMatchID(matchid, sizeof(matchid));
    g_MatchID = StringToInt(matchid);
}

public void Get5_OnGoingLive(int mapNumber) {
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    Handle req = CreateRequest(k_EHTTPMethodPOST, "match/%d/map/%d/start", g_MatchID, mapNumber);
    if (req != INVALID_HANDLE) {
        AddStringParam(req, "mapname", mapName);
        SteamWorks_SendHTTPRequest(req);
    }
}

public void UpdateRoundStats(int mapNumber) {
    int t1score = CS_GetTeamScore(Get5_MatchTeamToCSTeam(MatchTeam_Team1));
    int t2score = CS_GetTeamScore(Get5_MatchTeamToCSTeam(MatchTeam_Team2));

    Handle req = CreateRequest(k_EHTTPMethodPOST, "match/%d/map/%d/update", g_MatchID, mapNumber);
    if (req != INVALID_HANDLE) {
        AddIntParam(req, "team1score", t1score);
        AddIntParam(req, "team2score", t2score);
        SteamWorks_SendHTTPRequest(req);
    }

    // Update player stats
    KeyValues kv = new KeyValues("Stats");
    Get5_GetMatchStats(kv);
    char mapKey[32];
    Format(mapKey, sizeof(mapKey), "map%d", mapNumber);
    if (kv.JumpToKey(mapKey)) {
        if (kv.JumpToKey("team1")) {
            UpdatePlayerStats(kv, MatchTeam_Team1);
            kv.GoBack();
        }
        if (kv.JumpToKey("team2")) {
            UpdatePlayerStats(kv, MatchTeam_Team2);
            kv.GoBack();
        }
        kv.GoBack();
    }
    delete kv;
}

public void Get5_OnMapResult(const char[] map, MatchTeam mapWinner,
    int team1Score, int team2Score, int mapNumber) {
    char winnerString[64];
    GetTeamString(mapWinner, winnerString, sizeof(winnerString));

    Handle req = CreateRequest(k_EHTTPMethodPOST, "match/%d/map/%d/finish", g_MatchID, mapNumber);
    if (req != INVALID_HANDLE) {
        AddIntParam(req, "team1score", team1Score);
        AddIntParam(req, "team2score", team2Score);
        AddStringParam(req, "winner", winnerString);
        SteamWorks_SendHTTPRequest(req);
    }
}

static void AddIntStat(Handle req, KeyValues kv, const char[] field) {
    AddIntParam(req, field, kv.GetNum(field));
}

public void UpdatePlayerStats(KeyValues kv, MatchTeam team) {
    char name[MAX_NAME_LENGTH];
    char auth[AUTH_LENGTH];
    int mapNumber = MapNumber();

    if (kv.GotoFirstSubKey()) {
        do {
            kv.GetSectionName(auth, sizeof(auth));
            kv.GetString("name", name, sizeof(name));
            char teamString[16];
            GetTeamString(team, teamString, sizeof(teamString));

            Handle req = CreateRequest(k_EHTTPMethodPOST, "match/%d/map/%d/player/%s/update",
                g_MatchID, mapNumber, auth);
            if (req != INVALID_HANDLE) {
                AddStringParam(req, "team", teamString);
                AddStringParam(req, "name", name);
                AddIntStat(req, kv, STAT_KILLS);
                AddIntStat(req, kv, STAT_DEATHS);
                AddIntStat(req, kv, STAT_ASSISTS);
                AddIntStat(req, kv, STAT_FLASHBANG_ASSISTS);
                AddIntStat(req, kv, STAT_TEAMKILLS);
                AddIntStat(req, kv, STAT_SUICIDES);
                AddIntStat(req, kv, STAT_DAMAGE);
                AddIntStat(req, kv, STAT_HEADSHOT_KILLS);
                AddIntStat(req, kv, STAT_ROUNDSPLAYED);
                AddIntStat(req, kv, STAT_BOMBPLANTS);
                AddIntStat(req, kv, STAT_BOMBDEFUSES);
                AddIntStat(req, kv, STAT_1K);
                AddIntStat(req, kv, STAT_2K);
                AddIntStat(req, kv, STAT_3K);
                AddIntStat(req, kv, STAT_4K);
                AddIntStat(req, kv, STAT_5K);
                AddIntStat(req, kv, STAT_V1);
                AddIntStat(req, kv, STAT_V2);
                AddIntStat(req, kv, STAT_V3);
                AddIntStat(req, kv, STAT_V4);
                AddIntStat(req, kv, STAT_V5);
                SteamWorks_SendHTTPRequest(req);
            }

        } while (kv.GotoNextKey());
        kv.GoBack();
    }
}

static void AddStringParam(Handle request, const char[] key, const char[] value) {
    SteamWorks_SetHTTPRequestGetOrPostParameter(request, key, value);
}

static void AddIntParam(Handle request, const char[] key, int value) {
    char buffer[32];
    IntToString(value, buffer, sizeof(buffer));
    SteamWorks_SetHTTPRequestGetOrPostParameter(request, key, buffer);
}

public void Get5_OnSeriesResult(MatchTeam seriesWinner,
    int team1MapScore, int team2MapScore) {
    char winnerString[64];
    GetTeamString(seriesWinner, winnerString, sizeof(winnerString));
    Handle req = CreateRequest(k_EHTTPMethodPOST, "match/%d/finish", g_MatchID);
    if (req != INVALID_HANDLE) {
        AddStringParam(req, "winner", winnerString);
        SteamWorks_SendHTTPRequest(req);
    }

    g_APIKeyCvar.SetString("");
}

public void Get5_OnRoundStatsUpdated() {
    if (Get5_GetGameState() == GameState_Live) {
        UpdateRoundStats(MapNumber());
    }
}

static int MapNumber() {
    int t1, t2;
    int buf;
    Get5_GetTeamScores(MatchTeam_Team1, t1, buf);
    Get5_GetTeamScores(MatchTeam_Team2, t2, buf);
    return t1 + t2;
}
