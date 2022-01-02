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
      File hLogFile = OpenFile(logPath, "a+");

      if (hLogFile) {
        LogToOpenFileEx(hLogFile, buffer);
        CloseHandle(hLogFile);
      } else {
        LogError("Could not open file \"%s\"", logPath);
      }
    }

    LogDebug("Calling Get5_OnEvent(event name = %s)", eventName);
    Call_StartForward(g_OnEvent);
    Call_PushString(buffer);
    Call_Finish();
  }

  json_cleanup_and_delete(json);
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

static void AddPause(JSON_Object params, const char[] key, PauseType pause) {
  char value[16];
  GetPauseType(pause, value, sizeof(value));
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

public void EventLogger_GrenadeThrown(int roundNumber, int roundTime, int attacker, const char[] weapon) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "attacker", attacker);
  params.SetInt("round_number", roundNumber);
  params.SetInt("round_time", roundTime);
  params.SetString("weapon", weapon);
  EventLogger_EndEvent("grenade_thrown");
}

public void EventLogger_PlayerDeath(int roundNumber, int roundTime, int attacker, int victim, bool suicide,
                             bool headshot, int assister, bool flashAssist, const char[] weapon, bool friendlyFire,
                             bool assistFriendlyFire, int penetrated, bool thruSmoke,
                             bool noScope, bool attackerBlind) {
  EventLogger_StartEvent();
  AddMapData(params);

  if (attacker > 0) {
    AddPlayer(params, "attacker", attacker);
  } else {
    params.SetObject("attacker", null); // In case of non-player attacker, such as fall damage.
  }

  AddPlayer(params, "victim", victim);
  params.SetInt("round_number", roundNumber);
  params.SetInt("round_time", roundTime);
  params.SetInt("headshot", headshot);
  params.SetInt("penetrated", penetrated);
  params.SetBool("suicide", suicide);
  params.SetBool("thru_smoke", thruSmoke);
  params.SetBool("no_scope", noScope);
  params.SetBool("attacker_blind", attackerBlind);
  params.SetString("weapon", weapon);
  params.SetBool("friendly_fire", friendlyFire);

  if (assister > 0) {

    JSON_Object assist = new JSON_Object();
    AddPlayer(assist, "assister", assister);
    assist.SetBool("flash_assist", flashAssist);
    assist.SetBool("friendly_fire", assistFriendlyFire);

    params.SetObject("assist", assist);

  } else {
    params.SetObject("assist", null); // Set to null instead of omitting for JSON consistency.
  }

  EventLogger_EndEvent("player_death");
}

public void EventLogger_RoundStart(int roundNumber) {
  EventLogger_StartEvent();
  AddMapData(params);
  params.SetInt("round_number", roundNumber);
  EventLogger_EndEvent("round_start");
}

public void EventLogger_RoundEnd(int roundNumber, int csTeamWinner, int csReason, int roundTime) {
  EventLogger_StartEvent();
  AddMapData(params);
  params.SetInt("round_number", roundNumber);
  params.SetInt("round_time", roundTime);
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

public void EventLogger_SeriesCancel(int t1score, int t2score) {
  EventLogger_StartEvent();
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

public void EventLogger_BombPlanted(int client, int roundNumber, int roundTime, int site) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetInt("site", site);
  params.SetInt("round_number", roundNumber);
  params.SetInt("round_time", roundTime);
  EventLogger_EndEvent("bomb_planted");
}

public void EventLogger_BombDefused(int client, int roundNumber, int roundTime, int site, int bombTimeRemaining) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetInt("site", site);
  params.SetInt("bomb_time_remaining", bombTimeRemaining);
  params.SetInt("round_number", roundNumber);
  params.SetInt("round_time", roundTime);
  EventLogger_EndEvent("bomb_defused");
}

public void EventLogger_MVP(int client, int roundNumber, int reason) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetInt("reason", reason);
  params.SetInt("round_number", roundNumber);
  EventLogger_EndEvent("round_mvp");
}

public void EventLogger_BombExploded(int client, int roundNumber, int roundTime, int site) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddPlayer(params, "client", client);
  params.SetInt("site", site);
  params.SetInt("round_number", roundNumber);
  params.SetInt("round_time", roundTime);
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

public void EventLogger_PauseCommand(MatchTeam team, PauseType pauseReason) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddTeam(params, "request_team", team);
  AddPause(params, "pause_reason", pauseReason);
  EventLogger_EndEvent("pause_command");
}

public void EventLogger_UnpauseCommand(MatchTeam team) {
  EventLogger_StartEvent();
  AddMapData(params);
  AddTeam(params, "request_team", team);
  EventLogger_EndEvent("unpause_command");
}
