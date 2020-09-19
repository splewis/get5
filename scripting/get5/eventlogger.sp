#define EventLogger_StartEvent() JSON_Object params = new JSON_Object()

#define EventLogger_EndEvent(%1) EventLogger_LogEvent(%1, params)

static void EventLogger_LogEvent(const char[] eventName, JSON_Object params) {
  // Handle json = json_object();
  JSON_Object json = new JSON_Object();
  json.SetString("event", eventName);
  json.SetString("matchid", g_MatchID);
  json.SetObject("params", params);

  const int kMaxCharacters = 1000;
  char buffer[2048];

  json.Encode(buffer, sizeof(buffer), g_PrettyPrintJsonCvar.BoolValue);
  if (strlen(buffer) > kMaxCharacters) {
    LogError("Event JSON too long (%d characters, %d max): %s", eventName, strlen(buffer),
             kMaxCharacters);
  } else {
    LogDebug("get5_event: %s", buffer);
    LogToGame("get5_event: %s", buffer);

    char logPath[PLATFORM_MAX_PATH];
    if (FormatCvarString(g_EventLogFormatCvar, logPath, sizeof(logPath))) {
      LogToFileEx(logPath, buffer);
    }

    LogDebug("Calling Get5_OnEvent(event name = %s)", eventName);
    Call_StartForward(g_OnEvent);
    Call_PushString(buffer);
    Call_Finish();
  }
}

static void AddMapData(JSON_Object params) {
  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  params.SetString("map_name", mapName);
  params.SetInt("map_number", GetMapNumber());
}

static void AddTeam(JSON_Object params, const char[] key, MatchTeam team) {
  char value[16];
  GetTeamString(team, value, sizeof(value));
  params.SetString(key, value);
}

static void AddCSTeam(JSON_Object params, const char[] key, int team) {
  char value[16];
  CSTeamString(team, value, sizeof(value));
  params.SetString(key, value);
}

static void AddPlayer(JSON_Object params, const char[] key, int client) {
  char value[64];
  if (IsValidClient(client)) {
    Format(value, sizeof(value), "%L", client);
  } else {
    Format(value, sizeof(value), "none");
  }
  params.SetString(key, value);
}

static void AddIpAddress(JSON_Object params, int client) {
    char value[32];
    if (IsValidClient(client)) {
        GetClientIP(client, value, sizeof(value));
    }
    params.SetString("ip", value);
}

public void EventLogger_SeriesStart() {
  EventLogger_StartEvent();
  params.SetString("team1_name", g_TeamNames[MatchTeam_Team1]);
  params.SetString("team2_name", g_TeamNames[MatchTeam_Team2]);
  EventLogger_EndEvent("series_start");
}

public void EventLogger_MapVetoed(MatchTeam team, const char[] map) {
  EventLogger_StartEvent();

  AddTeam(params, "team", team);
  params.SetString("map_name", map);

  EventLogger_EndEvent("map_veto");
}

public void EventLogger_MapPicked(MatchTeam team, const char[] map, int mapNumber) {
  EventLogger_StartEvent();

  AddTeam(params, "team", team);
  params.SetString("map_name", map);
  params.SetInt("map_number", mapNumber);

  EventLogger_EndEvent("map_pick");
}

public void EventLogger_SidePicked(MatchTeam team, const char[] map, int mapNumber, int side) {
  EventLogger_StartEvent();

  AddTeam(params, "team", team);
  params.SetString("map_name", map);
  params.SetInt("map_number", mapNumber);
  AddCSTeam(params, "side", side);

  EventLogger_EndEvent("side_picked");
}

public void EventLogger_KnifeStart() {
  EventLogger_StartEvent();
  AddMapData(params);
  EventLogger_EndEvent("knife_start");
}

public void EventLogger_KnifeWon(MatchTeam winner, bool swap) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddTeam(params, "winner", winner);
  AddCSTeam(params, "selected_side", g_TeamStartingSide[winner]);
  EventLogger_EndEvent("knife_won");
}

public void EventLogger_GoingLive() {
  EventLogger_StartEvent();
  AddMapData(params);
  EventLogger_EndEvent("going_live");
}

public void EventLogger_PlayerDeath(int killer, int victim, bool headshot, int assister,
                             int flash_assister, const char[] weapon) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "attacker", killer);
  AddPlayer(params, "victim", victim);
  params.SetInt("headshot", headshot);
  params.SetString("weapon", weapon);

  if (assister > 0)
    AddPlayer(params, "assister", assister);
  if (flash_assister > 0)
    AddPlayer(params, "flash_assister", flash_assister);

  EventLogger_EndEvent("player_death");
}

public void EventLogger_RoundEnd(int csTeamWinner, int csReason) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddCSTeam(params, "winner_side", csTeamWinner);
  AddTeam(params, "winner", CSTeamToMatchTeam(csTeamWinner));
  params.SetInt("reason", csReason);
  params.SetInt("team1_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  params.SetInt("team2_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  EventLogger_EndEvent("round_end");
}

public void EventLogger_SideSwap(int team1Side, int team2Side) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddCSTeam(params, "team1_side", team1Side);
  AddCSTeam(params, "team2_side", team2Side);
  params.SetInt("team1_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  params.SetInt("team2_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  EventLogger_EndEvent("side_swap");
}

public void EventLogger_MapEnd(MatchTeam winner) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddTeam(params, "winner", winner);
  params.SetInt("team1_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  params.SetInt("team2_score", CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  EventLogger_EndEvent("map_end");
}

public void EventLogger_SeriesEnd(MatchTeam winner, int t1score, int t2score) {
  EventLogger_StartEvent();
  AddTeam(params, "team", winner);
  params.SetInt("team1_series_score", t1score);
  params.SetInt("team2_series_score", t2score);
  EventLogger_EndEvent("series_end");
}

public void EventLogger_SeriesCancel(MatchTeam winner, int t1score, int t2score) {
  EventLogger_StartEvent();
  AddTeam(params, "team", winner);
  params.SetInt("team1_series_score", t1score);
  params.SetInt("team2_series_score", t2score);
  EventLogger_EndEvent("series_cancel");
}

public void EventLogger_BackupLoaded(const char[] path) {
  EventLogger_StartEvent();
  params.SetString("file", path);
  EventLogger_EndEvent("backup_loaded");
}

public void EventLogger_MatchConfigFail(const char[] reason) {
  EventLogger_StartEvent();
  params.SetString("reason", reason);
  EventLogger_EndEvent("match_config_load_fail");
}

public void EventLogger_ClientSay(int client, const char[] message) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetString("message", message);
  EventLogger_EndEvent("client_say");
}

public void EventLogger_BombPlanted(int client, int site) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetInt("site", site);
  EventLogger_EndEvent("bomb_planted");
}

public void EventLogger_BombDefused(int client, int site) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetInt("site", site);
  EventLogger_EndEvent("bomb_defused");
}

public void EventLogger_BombExploded(int client, int site) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetInt("site", site);
  EventLogger_EndEvent("bomb_exploded");
}

public void EventLogger_PlayerConnect(int client) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  AddIpAddress(params, client);
  EventLogger_EndEvent("player_connect");
}

public void EventLogger_PlayerDisconnect(int client) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  EventLogger_EndEvent("player_disconnect");
}

public void EventLogger_TeamReady(MatchTeam team, const char[] stage) {
  EventLogger_StartEvent();

  AddTeam(params, "team", team);
  params.SetString("stage", stage);

  EventLogger_EndEvent("team_ready");
}

public void EventLogger_TeamUnready(MatchTeam team) {
  EventLogger_StartEvent();

  AddTeam(params, "team", team);

  EventLogger_EndEvent("team_unready");
}