#if defined _get5_included_
#endinput
#endif
#define _get5_included_

#include <json>  // github.com/clugg/sm-json
#include <cstrike>

// Series stats (root section)
#define STAT_SERIESWINNER "winner"
#define STAT_SERIESTYPE "series_type"
#define STAT_SERIES_TEAM_ID "id"
#define STAT_SERIES_TEAM_NAME "name"
#define STAT_SERIES_FORFEIT "forfeit"

// Map stats (under "map0", "map1", etc.)
#define STAT_MAPNAME "mapname"
#define STAT_MAPWINNER "winner"
#define STAT_DEMOFILENAME "demo_filename"

// Team stats (under map section, then "team1" or "team2")
#define STAT_TEAMSCORE "score"
#define STAT_TEAMSCORE_CT "score_ct"
#define STAT_TEAMSCORE_T "score_t"
#define STAT_STARTING_SIDE "starting_side"

// Player stats (under map section, then team section, then player's steam64)
// If adding stuff here, also add to the InitPlayerStats function!
#define STAT_INIT "init" // used to zero-fill stats only. Not a real stat.
#define STAT_COACHING "coaching" // indicates if the player is a coach.
#define STAT_NAME "name"
#define STAT_KILLS "kills"
#define STAT_DEATHS "deaths"
#define STAT_ASSISTS "assists"
#define STAT_FLASHBANG_ASSISTS "flashbang_assists"
#define STAT_TEAMKILLS "teamkills"
#define STAT_SUICIDES "suicides"
#define STAT_DAMAGE "damage"
#define STAT_UTILITY_DAMAGE "util_damage"
#define STAT_ENEMIES_FLASHED "enemies_flashed"
#define STAT_FRIENDLIES_FLASHED "friendlies_flashed"
#define STAT_KNIFE_KILLS "knife_kills"
#define STAT_HEADSHOT_KILLS "headshot_kills"
#define STAT_ROUNDSPLAYED "roundsplayed"
#define STAT_BOMBDEFUSES "bomb_defuses"
#define STAT_BOMBPLANTS "bomb_plants"
#define STAT_1K "1kill_rounds"
#define STAT_2K "2kill_rounds"
#define STAT_3K "3kill_rounds"
#define STAT_4K "4kill_rounds"
#define STAT_5K "5kill_rounds"
#define STAT_V1 "v1"
#define STAT_V2 "v2"
#define STAT_V3 "v3"
#define STAT_V4 "v4"
#define STAT_V5 "v5"
#define STAT_FIRSTKILL_T "firstkill_t"
#define STAT_FIRSTKILL_CT "firstkill_ct"
#define STAT_FIRSTDEATH_T "firstdeath_t"
#define STAT_FIRSTDEATH_CT "firstdeath_ct"
#define STAT_TRADEKILL "tradekill"
#define STAT_KAST "kast"
#define STAT_CONTRIBUTION_SCORE "contribution_score"
#define STAT_MVP "mvp"

enum Get5Side {
  Get5Side_None = CS_TEAM_NONE,
  Get5Side_Spec = CS_TEAM_SPECTATOR,
  Get5Side_T = CS_TEAM_T,
  Get5Side_CT = CS_TEAM_CT
};

enum Get5BombSite {
  Get5BombSite_Unknown = 0,
  Get5BombSite_A = 1,
  Get5BombSite_B = 2
};

enum Get5MapSelectionOption {
  Get5MapSelectionOption_Invalid,
  Get5MapSelectionOption_Team1Pick,
  Get5MapSelectionOption_Team2Pick,
  Get5MapSelectionOption_Team1Ban,
  Get5MapSelectionOption_Team2Ban
}

#define MATCHTEAM_COUNT 4

enum Get5Team {
  Get5Team_1,
  Get5Team_2,
  Get5Team_Spec,
  Get5Team_None,
  Get5Team_Count
};

enum Get5State {
  Get5State_None,                          // no setup has taken place
  Get5State_PreVeto,                       // warmup, waiting for the veto
  Get5State_Veto,                          // warmup, doing the veto
  Get5State_Warmup,                        // setup done, waiting for players to ready up
  Get5State_KnifeRound,                    // in the knife round
  Get5State_WaitingForKnifeRoundDecision,  // waiting for a .stay/.swap command after the knife
  Get5State_GoingLive,                     // counting down to live
  Get5State_Live,                          // the match is live
  Get5State_PendingRestore,                // pending restore to a live match
  Get5State_PostGame,                      // postgame screen + waiting for GOTV to finish broadcast
};

enum Get5PauseType {
  Get5PauseType_None,      // Not paused
  Get5PauseType_Tech,      // Technical pause
  Get5PauseType_Tactical,  // Tactical Pause
  Get5PauseType_Admin,     // Admin/RCON Pause
  Get5PauseType_Backup     // Special type for match pausing during backups.
};

enum Get5ChatCommand {
  Get5ChatCommand_Unknown,
  Get5ChatCommand_Ready,
  Get5ChatCommand_Unready,
  Get5ChatCommand_ForceReady,
  Get5ChatCommand_Tech,
  Get5ChatCommand_Pause,
  Get5ChatCommand_Unpause,
  Get5ChatCommand_Coach,
  Get5ChatCommand_Stay,
  Get5ChatCommand_Swap,
  Get5ChatCommand_T,
  Get5ChatCommand_CT,
  Get5ChatCommand_Stop,
  Get5ChatCommand_Surrender,
  Get5ChatCommand_FFW,
  Get5ChatCommand_CancelFFW,
  Get5ChatCommand_Pick,
  Get5ChatCommand_Ban
};

enum MatchSideType {
  MatchSideType_Standard,     // Team that doesn't pick map gets side choice, leftovers go to knife rounds
  MatchSideType_AlwaysKnife,  // All maps use a knife round to pick sides
  MatchSideType_NeverKnife,   // Team 1 always starts CT
};

enum SideChoice {
  SideChoice_Team1CT,     // Team 1 will start on CT
  SideChoice_Team1T,      // Team 1 will start on T
  SideChoice_KnifeRound,  // There will be a knife round to choose sides
  SideChoice_Invalid
};

// Returns the current pug gamestate.
native Get5State Get5_GetGameState();

// Prints a plugin-formatted message to a client.
native void Get5_Message(int client, const char[] format, any:...);

// Prints a plugin-formatted message to a team.
native void Get5_MessageToTeam(Get5Team team, const char[] format, any:...);

// Prints a plugin-formatted message to all clients.
native void Get5_MessageToAll(const char[] format, any:...);

// Loads a match config (keyvalues or JSON) from a local file.
// Returns true if the config was successfully loaded.
native bool Get5_LoadMatchConfig(const char[] filename);

// Loads a match config by downloading a remote config via a HTTP GET request.
// Request parameters should be left out of the url and put into the optional ArrayLists parameters.
native bool Get5_LoadMatchConfigFromURL(const char[] url, ArrayList paramNames = null,
                                        ArrayList paramValues = null, ArrayList headerNames = null,
                                        ArrayList headerValues = null);

// Adds a player to a match team. You can optionally force set a player name here as well.
// Returns if they were successfully added.
native bool Get5_AddPlayerToTeam(const char[] steamId, Get5Team team,
                                 const char[] playerName = "");

// Force sets a steam64 to map to a specified playername. If calling this multiple times, you may want to
// suppress loading the player names until the last call.
native bool Get5_SetPlayerName(const char[] steamId, const char[] playerName, bool suppressNameLoading = false);

// Removes a player from all match teams.
// Returns if they were successfully removed (false if not round).
native bool Get5_RemovePlayerFromTeam(const char[] steamId);

// Returns the current match team a auth is mapped to.
native Get5Team Get5_GetPlayerTeam(const char[] steamId);

// Translates a CS team (CS_TEAM_T, etc.) to a Get5Team.
native Get5Team Get5_CSTeamToGet5Team(int csTeam);

// Translates a Get5Team to a CS team.
native int Get5_Get5TeamToCSTeam(Get5Team team);

// Gets the scores for a match team.
native void Get5_GetTeamScores(Get5Team team, int& seriesScore, int& currentMapScore);

// Gets the current matchid.
native void Get5_GetMatchID(char[] id, int length);

// Sets the current matchid.
native void Get5_SetMatchID(const char[] id);

// Gets the server ID as defined by get5_server_id.
native void Get5_GetServerID(char[] id, int length);

// Returns the current map number, 0 being the first in the series.
native int Get5_GetMapNumber();

// Adds a cvar to be set when going live. If the cvar is already in the cvars for the match, the new
// value will replace the old value if the override parameter is true.
// Note: this should only be used when a match config loaded.
native void Get5_AddLiveCvar(const char[] name, const char[] value, bool override = true);

// Copies the current series stats into the passed KeyValues structure.
// Below are the keys used for stats in the kv copied.
// The caller is responsible for creating and deleting a KeyValues
// object if using this method.
native bool Get5_GetMatchStats(KeyValues kv);

// Increases an (integer-typed) player statistic in the plugin's stats keyvalue structure.
native int Get5_IncreasePlayerStat(int client, const char[] statName, int amount = 1);


methodmap Get5PlayerStats < JSON_Object {

  property int Kills {
    public set(int val) {
      this.SetInt("kills", val);
    }
    public get() {
      return this.GetInt("kills");
    }
  }

  property int Deaths {
    public set(int val) {
      this.SetInt("deaths", val);
    }
    public get() {
      return this.GetInt("deaths");
    }
  }

  property int Assists {
    public set(int val) {
      this.SetInt("assists", val);
    }
    public get() {
      return this.GetInt("assists");
    }
  }

  property int FlashAssists {
    public set(int val) {
      this.SetInt("flash_assists", val);
    }
    public get() {
      return this.GetInt("flash_assists");
    }
  }

  property int TeamKills {
    public set(int val) {
      this.SetInt("team_kills", val);
    }
    public get() {
      return this.GetInt("team_kills");
    }
  }

  property int Suicides {
    public set(int val) {
      this.SetInt("suicides", val);
    }
    public get() {
      return this.GetInt("suicides");
    }
  }

  property int Damage {
    public set(int val) {
      this.SetInt("damage", val);
    }
    public get() {
      return this.GetInt("damage");
    }
  }

  property int UtilityDamage {
    public set(int val) {
      this.SetInt("utility_damage", val);
    }
    public get() {
      return this.GetInt("utility_damage");
    }
  }

  property int EnemiesFlashed {
    public set(int val) {
      this.SetInt("enemies_flashed", val);
    }
    public get() {
      return this.GetInt("enemies_flashed");
    }
  }

  property int FriendliesFlashed {
    public set(int val) {
      this.SetInt("friendlies_flashed", val);
    }
    public get() {
      return this.GetInt("friendlies_flashed");
    }
  }

  property int KnifeKills {
    public set(int val) {
      this.SetInt("knife_kills", val);
    }
    public get() {
      return this.GetInt("knife_kills");
    }
  }

  property int HeadshotKills {
    public set(int val) {
      this.SetInt("headshot_kills", val);
    }
    public get() {
      return this.GetInt("headshot_kills");
    }
  }

  property int RoundsPlayed {
    public set(int val) {
      this.SetInt("rounds_played", val);
    }
    public get() {
      return this.GetInt("rounds_played");
    }
  }

  property int BombDefuses {
    public set(int val) {
      this.SetInt("bomb_defuses", val);
    }
    public get() {
      return this.GetInt("bomb_defuses");
    }
  }

  property int BombPlants {
    public set(int val) {
      this.SetInt("bomb_plants", val);
    }
    public get() {
      return this.GetInt("bomb_plants");
    }
  }

  property int Kills1 {
    public set(int val) {
      this.SetInt("1k", val);
    }
    public get() {
      return this.GetInt("1k");
    }
  }

  property int Kills2 {
    public set(int val) {
      this.SetInt("2k", val);
    }
    public get() {
      return this.GetInt("2k");
    }
  }

  property int Kills3 {
    public set(int val) {
      this.SetInt("3k", val);
    }
    public get() {
      return this.GetInt("3k");
    }
  }

  property int Kills4 {
    public set(int val) {
      this.SetInt("4k", val);
    }
    public get() {
      return this.GetInt("4k");
    }
  }

  property int Kills5 {
    public set(int val) {
      this.SetInt("5k", val);
    }
    public get() {
      return this.GetInt("5k");
    }
  }

  property int OneV1s {
    public set(int val) {
      this.SetInt("1v1", val);
    }
    public get() {
      return this.GetInt("1v1");
    }
  }

  property int OneV2s {
    public set(int val) {
      this.SetInt("1v2", val);
    }
    public get() {
      return this.GetInt("1v2");
    }
  }

  property int OneV3s {
    public set(int val) {
      this.SetInt("1v3", val);
    }
    public get() {
      return this.GetInt("1v3");
    }
  }

  property int OneV4s {
    public set(int val) {
      this.SetInt("1v4", val);
    }
    public get() {
      return this.GetInt("1v4");
    }
  }

  property int OneV5s {
    public set(int val) {
      this.SetInt("1v5", val);
    }
    public get() {
      return this.GetInt("1v5");
    }
  }

  property int FirstKillsT {
    public set(int val) {
      this.SetInt("first_kills_t", val);
    }
    public get() {
      return this.GetInt("first_kills_t");
    }
  }

  property int FirstKillsCT {
    public set(int val) {
      this.SetInt("first_kills_ct", val);
    }
    public get() {
      return this.GetInt("first_kills_ct");
    }
  }

  property int FirstDeathsT {
    public set(int val) {
      this.SetInt("first_deaths_t", val);
    }
    public get() {
      return this.GetInt("first_deaths_t");
    }
  }

  property int FirstDeathsCT {
    public set(int val) {
      this.SetInt("first_deaths_ct", val);
    }
    public get() {
      return this.GetInt("first_deaths_ct");
    }
  }

  property int TradeKills {
    public set(int val) {
      this.SetInt("trade_kills", val);
    }
    public get() {
      return this.GetInt("trade_kills");
    }
  }

  property int KAST {
    public set(int val) {
      this.SetInt("kast", val);
    }
    public get() {
      return this.GetInt("kast");
    }
  }

  property int Score {
    public set(int val) {
      this.SetInt("score", val);
    }
    public get() {
      return this.GetInt("score");
    }
  }

  property int MVPs {
    public set(int val) {
      this.SetInt("mvp", val);
    }
    public get() {
      return this.GetInt("mvp");
    }
  }

  public Get5PlayerStats(const int kills, const int deaths, const int assists, const int flashAssists,
        const int teamKills, const int suicides, const int damage, const int utilityDamage, const int enemiesFlashed,
        const int friendliesFlashed, const int knifeKills, const int headshotKills, const int roundsPlayed,
        const int bombDefuses, const int bombPlants, const int kills1, const int kills2, const int kills3,
        const int kills4, const int kills5, const int oneV1s, const int oneV2s, const int oneV3s,
        const int oneV4s, const int oneV5s, const int firstKillsT, const int firstKillsCT, const int firstDeathsT,
        const int firstDeathsCT, const int tradeKills, const int kast, const int score, const int mvp) {
    Get5PlayerStats self = view_as<Get5PlayerStats>(new JSON_Object());
    self.Kills = kills;
    self.Deaths = deaths;
    self.Assists = assists;
    self.FlashAssists = flashAssists;
    self.TeamKills = teamKills;
    self.Suicides = suicides;
    self.Damage = damage;
    self.UtilityDamage = utilityDamage;
    self.EnemiesFlashed = enemiesFlashed;
    self.FriendliesFlashed = friendliesFlashed;
    self.KnifeKills = knifeKills;
    self.HeadshotKills = headshotKills;
    self.RoundsPlayed = roundsPlayed;
    self.BombDefuses = bombDefuses;
    self.BombPlants = bombPlants;
    self.OneV1s = oneV1s;
    self.OneV2s = oneV2s;
    self.OneV3s = oneV3s;
    self.OneV4s = oneV4s;
    self.OneV5s = oneV5s;
    self.Kills1 = kills1;
    self.Kills2 = kills2;
    self.Kills3 = kills3;
    self.Kills4 = kills4;
    self.Kills5 = kills5;
    self.FirstKillsT = firstKillsT;
    self.FirstKillsCT = firstKillsCT;
    self.FirstDeathsT = firstDeathsT;
    self.FirstDeathsCT = firstDeathsCT;
    self.TradeKills = tradeKills;
    self.KAST = kast;
    self.Score = score
    self.MVPs = mvp;
    return self;
  }
}

methodmap Get5PlayerBase < JSON_Object {
  public bool SetSteamId(const char[] value) {
    return this.SetString("steamid", value);
  }
  public bool GetSteamId(char[] buffer, const int maxSize) {
    return this.GetString("steamid", buffer, maxSize);
  }

  public bool SetName(const char[] value) {
    return this.SetString("name", value);
  }
  public bool GetName(char[] buffer, const int maxSize) {
    return this.GetString("name", buffer, maxSize);
  }
}

methodmap Get5StatsPlayer < Get5PlayerBase {

  property Get5PlayerStats Stats {
    public get() {
      return view_as<Get5PlayerStats>(this.GetObject("stats"));
    }
    public set(Get5PlayerStats val) {
      this.SetObject("stats", val);
    }
  }

  public Get5StatsPlayer(const char[] steamId, const char[] name, const Get5PlayerStats stats) {
    Get5StatsPlayer self = view_as<Get5StatsPlayer>(new JSON_Object());
    self.SetSteamId(steamId);
    self.SetName(name);
    self.Stats = stats;
    return self;
  }
}

methodmap Get5TeamWrapper < JSON_Object {

  // This allows the property to be null in JSON but empty string in SourceMod.
  public bool GetId(char[] buffer, const int maxSize) {
    if (this.GetType("id") != JSON_Type_String) {
      strcopy(buffer, maxSize, "");
      return true;
    } else {
      return this.GetString("id", buffer, maxSize);
    }
  }

  public bool SetId(const char[] value) {
    if (strlen(value) > 0) {
      return this.SetString("id", value);
    }
    return this.SetObject("id", null);
  }

  public bool GetName(char[] buffer, const int maxSize) {
    return this.GetString("name", buffer, maxSize);
  }

  public bool SetName(const char[] value) {
    return this.SetString("name", value);
  }

  public Get5TeamWrapper(const char[] id, const char[] teamName) {
    Get5TeamWrapper self = view_as<Get5TeamWrapper>(new JSON_Object());
    self.SetId(id);
    self.SetName(teamName);
    return self;
  }
}

methodmap Get5StatsTeam < Get5TeamWrapper {

  property int SeriesScore {
    public get() {
      return this.GetInt("series_score");
    }
    public set(int val) {
      this.SetInt("series_score", val);
    }
  }

  property int Score {
    public get() {
      return this.GetInt("score");
    }
    public set(int val) {
      this.SetInt("score", val);
    }
  }

  property int ScoreCT {
    public get() {
      return this.GetInt("score_ct");
    }
    public set(int val) {
      this.SetInt("score_ct", val);
    }
  }

  property int ScoreT {
    public get() {
      return this.GetInt("score_t");
    }
    public set(int val) {
      this.SetInt("score_t", val);
    }
  }

  // Array of type Get5StatsPlayer
  property JSON_Array Players {
    public get() {
      return view_as<JSON_Array>(this.GetObject("players"));
    }
    public set(JSON_Array players) {
      this.SetObject("players", players);
    }
  }

  property Get5Side Side {
    public get() {
      return view_as<Get5Side>(this.GetInt("side_int"));
    }
    public set(Get5Side side) {
      this.SetInt("side_int", view_as<int>(side));
      this.SetHidden("side_int", true);
      ConvertGet5SideToStringInJson(this, "side", side);
    }
  }

  property Get5Side StartingSide {
    public get() {
      return view_as<Get5Side>(this.GetInt("starting_side_int"));
    }
    public set(Get5Side side) {
      this.SetInt("starting_side_int", view_as<int>(side));
      this.SetHidden("starting_side_int", true);
      ConvertGet5SideToStringInJson(this, "starting_side", side);
    }
  }

  public Get5StatsTeam(const char[] id, const char[] teamName, const int score, const int seriesScore, const Get5Side side) {
    Get5StatsTeam self = view_as<Get5StatsTeam>(new JSON_Object());
    self.SetId(id);
    self.SetName(teamName);
    self.Score = score;
    self.SeriesScore = seriesScore;
    self.Side = side;
    self.Players = new JSON_Array();
    self.ScoreCT = 0;
    self.ScoreT = 0;
    self.StartingSide = Get5Side_None;
    return self;
  }
}

methodmap Get5StatusTeam < JSON_Object {

  public bool SetTeamName(const char[] event) {
    return this.SetString("name", event);
  }

  property int SeriesScore {
    public set(int score) {
      this.SetInt("series_score", score);
    }
  }

  property int MapScore {
    public set(int score) {
      this.SetInt("current_map_score", score);
    }
  }

  property int ConnectedClients {
    public set(int clients) {
      this.SetInt("connected_clients", clients);
    }
  }

  property bool Ready {
    public set(bool ready) {
      this.SetBool("ready", ready);
    }
  }

  property Get5Side Side {
    public set(Get5Side side) {
      this.SetInt("side_int", view_as<int>(side));
      this.SetHidden("side_int", true);
      ConvertGet5SideToStringInJson(this, "side", side);
    }
  }

  public Get5StatusTeam(const char[] teamName,
    const int seriesScore, const int mapScore, const bool ready, const Get5Side side, const int connectedClients) {
    Get5StatusTeam self = view_as<Get5StatusTeam>(new JSON_Object());
    self.SetTeamName(teamName);
    self.SeriesScore = seriesScore;
    self.MapScore = mapScore;
    self.Ready = ready;
    self.Side = side;
    self.ConnectedClients = connectedClients;
    return self;
  }
}

methodmap Get5Status < JSON_Object {

  public bool SetPluginVersion(const char[] event) {
    return this.SetString("plugin_version", event);
  }

  property Get5State GameState {
    public set(Get5State state) {
      ConvertGameStateToStringInJson(this, "gamestate", state);
    }
  }

  property bool IsPaused {
    public set(bool paused) {
      this.SetBool("paused", paused);
    }
  }

  public bool SetConfigFile(const char[] file) {
    return this.SetString("loaded_config_file", file);
  }

  public bool SetMatchId(const char[] matchId) {
    return this.SetString("matchid", matchId);
  }

  property int MapNumber {
    public set(int mapNumber) {
      this.SetInt("map_number", mapNumber);
    }
  }

  property int RoundNumber {
    public set(int roundNumber) {
      this.SetInt("round_number", roundNumber);
    }
  }

  property int RoundTime {
    public set(int roundTime) {
      this.SetInt("round_time", roundTime);
    }
  }

  property Get5StatusTeam Team1 {
    public set(Get5StatusTeam team) {
      this.SetObject("team1", team);
    }
  }

  property Get5StatusTeam Team2 {
    public set(Get5StatusTeam team) {
      this.SetObject("team2", team);
    }
  }

  public bool AddMap(const char[] map) {
    if (!this.HasKey("maps")) {
      this.SetObject("maps", new JSON_Array());
    }
    JSON_Array maps = view_as<JSON_Array>(this.GetObject("maps"));
    maps.PushString(map);
  }

  public Get5Status(const char[] pluginVersion, const Get5State gamestate, const bool isPaused) {
    Get5Status self = view_as<Get5Status>(new JSON_Object());
    self.SetPluginVersion(pluginVersion);
    self.GameState = gamestate;
    self.IsPaused = isPaused;
    return self;
  }
}

methodmap Get5Weapon < JSON_Object {

  public bool SetWeaponName(const char[] value) {
    return this.SetString("name", value);
  }

  public bool GetWeaponName(char[] buffer, const int maxSize) {
    return this.GetString("name", buffer, maxSize);
  }

  property CSWeaponID Id {
    public get() {
      return view_as<CSWeaponID>(this.GetInt("id"));
    }
    public set(CSWeaponID id) {
      this.SetInt("id", view_as<int>(id));
    }
  }

  public Get5Weapon(const char[] weapon, CSWeaponID weaponId) {
    Get5Weapon self = view_as<Get5Weapon>(new JSON_Object());
    self.SetWeaponName(weapon);
    self.Id = weaponId;
    return self;
  }
}

methodmap Get5Winner < JSON_Object {

  property Get5Side Side {
    public get() {
      return view_as<Get5Side>(this.GetInt("side_int"));
    }
    public set(Get5Side side) {
      this.SetInt("side_int", view_as<int>(side));
      this.SetHidden("side_int", true);
      ConvertGet5SideToStringInJson(this, "side", side);
    }
  }

  property Get5Team Team {
    public get() {
      return view_as<Get5Team>(this.GetInt("team_int"));
    }
    public set(Get5Team team) {
      this.SetInt("team_int", view_as<int>(team));
      this.SetHidden("team_int", true);
      ConvertGet5TeamToStringInJson(this, "team", team);
    }
  }

  public Get5Winner(Get5Team team, Get5Side side) {
      Get5Winner self = view_as<Get5Winner>(new JSON_Object());
      self.Team = team;
      self.Side = side;
      return self;
  }
}

methodmap Get5Player < Get5PlayerBase {

  property Get5Side Side {
    public get() {
      return view_as<Get5Side>(this.GetInt("side_int"));
    }
    public set(Get5Side side) {
      this.SetInt("side_int", view_as<int>(side));
      this.SetHidden("side_int", true);
      ConvertGet5SideToStringInJson(this, "side", side);
    }
  }

  property bool IsBot {
    public get() {
      return this.GetBool("is_bot");
    }
    public set(bool bot) {
      this.SetBool("is_bot", bot);
    }
  }

  property int UserId {
    public get() {
      return this.GetInt("user_id");
    }
    public set(int id) {
      this.SetInt("user_id", id);
    }
  }

  public Get5Player(const int userId, const char[] steamId, const Get5Side side, const char[] name, const bool isBot) {
    Get5Player self = view_as<Get5Player>(new JSON_Object());
    self.UserId = userId;
    self.SetSteamId(steamId);
    self.Side = side;
    self.SetName(name);
    self.IsBot = isBot;
    return self;
  }
}

methodmap Get5Event < JSON_Object {

  public bool SetEvent(const char[] event) {
    return this.SetString("event", event);
  }
  public bool GetEvent(char[] buffer, const int maxSize) {
    return this.GetString("event", buffer, maxSize);
  }
}

methodmap Get5MatchEvent < Get5Event {

  public bool SetMatchId(const char[] matchId) {
    return this.SetString("matchid", matchId);
  }
  public bool GetMatchId(char[] buffer, const int maxSize) {
    return this.GetString("matchid", buffer, maxSize);
  }
}

methodmap Get5MatchTeamEvent < Get5MatchEvent {

  property Get5Team Team {
    public get() {
      return view_as<Get5Team>(this.GetInt("team_int"));
    }
    public set(Get5Team team) {
      this.SetInt("team_int", view_as<int>(team));
      this.SetHidden("team_int", true);
      ConvertGet5TeamToStringInJson(this, "team", team);
    }
  }
}

methodmap Get5MapEvent < Get5MatchEvent {

  property int MapNumber {
    public get() {
      return this.GetInt("map_number");
    }
    public set(int mapNumber) {
      this.SetInt("map_number", mapNumber);
    }
  }
}

methodmap Get5MapTeamEvent < Get5MapEvent {

  property Get5Team Team {
    public get() {
      return view_as<Get5Team>(this.GetInt("team_int"));
    }
    public set(Get5Team team) {
      this.SetInt("team_int", view_as<int>(team));
      this.SetHidden("team_int", true);
      ConvertGet5TeamToStringInJson(this, "team", team);
    }
  }
}

methodmap Get5RoundEvent < Get5MapEvent {

  property int RoundNumber {
    public get() {
      return this.GetInt("round_number");
    }
    public set(int roundNumber) {
      this.SetInt("round_number", roundNumber);
    }
  }
}

methodmap Get5TimedRoundEvent < Get5RoundEvent {

  property int RoundTime {
    public get() {
      return this.GetInt("round_time");
    }
    public set(int roundTime) {
      this.SetInt("round_time", roundTime);
    }
  }
}

methodmap Get5PlayerRoundEvent < Get5RoundEvent {

  property Get5Player Player {
    public get() {
      return view_as<Get5Player>(this.GetObject("player"));
    }
    public set(Get5Player player) {
      this.SetObject("player", player);
    }
  }
}

methodmap Get5PlayerTimedRoundEvent < Get5TimedRoundEvent {

  property Get5Player Player {
    public get() {
      return view_as<Get5Player>(this.GetObject("player"));
    }
    public set(Get5Player player) {
      this.SetObject("player", player);
    }
  }
}

// MATCH CONFIG
methodmap Get5PlayerDisconnectedEvent < Get5MatchEvent {

  property Get5Player Player {
    public get() {
      return view_as<Get5Player>(this.GetObject("player"));
    }
    public set(Get5Player player) {
      this.SetObject("player", player);
    }
  }

  public Get5PlayerDisconnectedEvent(const char[] matchId, const Get5Player player) {
    Get5PlayerDisconnectedEvent self = view_as<Get5PlayerDisconnectedEvent>(new JSON_Object());
    self.SetMatchId(matchId);
    self.SetEvent("player_disconnect");
    self.Player = player;
    return self;
  }
}

methodmap Get5PlayerConnectedEvent < Get5PlayerDisconnectedEvent {

  public bool SetIPAddress(const char[] address) {
    return this.SetString("ip_address", address);
  }

  public bool GetIPAddress(char[] buffer, const int maxSize) {
    return this.GetString("ip_address", buffer, maxSize);
  }

  public Get5PlayerConnectedEvent(const char[] matchId, const Get5Player player, const char[] ipAddress) {
    Get5PlayerConnectedEvent self = view_as<Get5PlayerConnectedEvent>(new JSON_Object());
    self.SetMatchId(matchId);
    self.SetEvent("player_connect");
    self.Player = player;
    self.SetIPAddress(ipAddress);
    return self;
  }
}

methodmap Get5SeriesResultEvent < Get5MatchEvent {

  property int TimeUntilRestore {
    public get() {
      return this.GetInt("time_until_restore");
    }
    public set(int time) {
      this.SetInt("time_until_restore", time);
    }
  }

  property Get5Winner Winner {
    public get() {
      return view_as<Get5Winner>(this.GetObject("winner"));
    }
    public set(Get5Winner winner) {
      this.SetObject("winner", winner);
    }
  }

  property int Team1SeriesScore {
    public get() {
      return this.GetInt("team1_series_score");
    }
    public set(int score) {
      this.SetInt("team1_series_score", score);
    }
  }

  property int Team2SeriesScore {
    public get() {
      return this.GetInt("team2_series_score");
    }
    public set(int score) {
      this.SetInt("team2_series_score", score);
    }
  }

  public Get5SeriesResultEvent(const char[] matchId, const Get5Winner winner, const int team1Score, const int team2Score, const int timeUntilRestore) {
    Get5SeriesResultEvent self = view_as<Get5SeriesResultEvent>(new JSON_Object());
    self.SetEvent("series_end");
    self.SetMatchId(matchId);
    self.Winner = winner;
    self.Team1SeriesScore = team1Score;
    self.Team2SeriesScore = team2Score;
    self.TimeUntilRestore = timeUntilRestore;
    return self;
  }
}

methodmap Get5PreloadMatchConfigEvent < Get5Event {

  public bool SetFileName(const char[] filePath) {
    return this.SetString("filename", filePath);
  }
  public bool GetFileName(char[] buffer, const int maxSize) {
    return this.GetString("filename", buffer, maxSize);
  }

  public Get5PreloadMatchConfigEvent(const char[] filePath) {
    Get5PreloadMatchConfigEvent self = view_as<Get5PreloadMatchConfigEvent>(new JSON_Object());
    self.SetEvent("preload_match_config");
    self.SetFileName(filePath);
    return self;
  }
}

methodmap Get5LoadMatchConfigFailedEvent < Get5Event {

  public bool SetReason(const char[] reason) {
    return this.SetString("reason", reason);
  }
  public bool GetReason(char[] buffer, const int maxSize) {
    return this.GetString("reason", buffer, maxSize);
  }

  public Get5LoadMatchConfigFailedEvent(const char[] reason) {
    Get5LoadMatchConfigFailedEvent self = view_as<Get5LoadMatchConfigFailedEvent>(new JSON_Object());
    self.SetEvent("match_config_load_fail");
    self.SetReason(reason);
    return self;
  }
}

methodmap Get5TeamReadyStatusChangedEvent < Get5MatchTeamEvent {

  property bool Ready {
    public get() {
      return this.GetBool("ready");
    }
    public set(bool ready) {
      this.SetBool("ready", ready);
    }
  }

  property Get5State GameState {
    public get() {
      return view_as<Get5State>(this.GetInt("game_state_int"));
    }
    public set(Get5State state) {
      this.SetInt("game_state_int", view_as<int>(state));
      this.SetHidden("game_state_int", true);
      ConvertGameStateToStringInJson(this, "game_state", state);
    }
  }

  public Get5TeamReadyStatusChangedEvent(const char[] matchId, const Get5Team team, const bool ready, const Get5State gamestate) {
    Get5TeamReadyStatusChangedEvent self = view_as<Get5TeamReadyStatusChangedEvent>(new JSON_Object());
    self.SetEvent("team_ready_status_changed");
    self.SetMatchId(matchId);
    self.Team = team;
    self.Ready = ready;
    self.GameState = gamestate;
    return self;
  }
}

methodmap Get5MapSelectionEvent < Get5MatchTeamEvent {

  public bool SetMapName(const char[] map) {
    return this.SetString("map_name", map);
  }
  public bool GetMapName(char[] buffer, const int maxSize) {
    return this.GetString("map_name", buffer, maxSize);
  }
}

methodmap Get5MapPickedEvent < Get5MapSelectionEvent {

  property int MapNumber {
    public get() {
      return this.GetInt("map_number");
    }
    public set(int mapNumber) {
      this.SetInt("map_number", mapNumber);
    }
  }

  public Get5MapPickedEvent(const char[] matchId, const Get5Team team, const char[] map, const int mapNumber) {
    Get5MapPickedEvent self = view_as<Get5MapPickedEvent>(new JSON_Object());
    self.SetEvent("map_picked");
    self.SetMatchId(matchId);
    self.Team = team;
    self.SetMapName(map);
    self.MapNumber = mapNumber;
    return self;
  }
}

methodmap Get5MapVetoedEvent < Get5MapSelectionEvent {

  public Get5MapVetoedEvent(const char[] matchId, const Get5Team team, const char[] map) {
    Get5MapVetoedEvent self = view_as<Get5MapVetoedEvent>(new JSON_Object());
    self.SetEvent("map_vetoed");
    self.SetMatchId(matchId);
    self.Team = team;
    self.SetMapName(map);
    return self;
  }
}

methodmap Get5SidePickedEvent < Get5MapSelectionEvent {

  property int MapNumber {
    public get() {
      return this.GetInt("map_number");
    }
    public set(int mapNumber) {
     this.SetInt("map_number", mapNumber);
    }
  }

  property Get5Side Side {
    public get() {
      return view_as<Get5Side>(this.GetInt("side_int"));
    }
    public set(Get5Side side) {
      this.SetInt("side_int", view_as<int>(side));
      this.SetHidden("side_int", true);
      ConvertGet5SideToStringInJson(this, "side", side);
    }
  }

  public Get5SidePickedEvent(const char[] matchId, const int mapNumber, const char[] mapName, const Get5Team team, const Get5Side side) {
    Get5SidePickedEvent self = view_as<Get5SidePickedEvent>(new JSON_Object());
    self.SetEvent("side_picked");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.SetMapName(mapName);
    self.Team = team;
    self.Side = side;
    return self;
  }
}

// MATCH STATE
methodmap Get5MapResultEvent < Get5MapEvent {

  property Get5Winner Winner {
    public get() {
      return view_as<Get5Winner>(this.GetObject("winner"));
    }
    public set(Get5Winner winner) {
      this.SetObject("winner", winner);
    }
  }

  property Get5StatsTeam Team1 {
    public get() {
      return view_as<Get5StatsTeam>(this.GetObject("team1"));
    }
    public set(Get5StatsTeam team) {
      this.SetObject("team1", team);
    }
  }

  property Get5StatsTeam Team2 {
    public get() {
      return view_as<Get5StatsTeam>(this.GetObject("team2"));
    }
    public set(Get5StatsTeam team) {
      this.SetObject("team2", team);
    }
  }

  public Get5MapResultEvent(const char[] matchId, const int mapNumber, const Get5Winner winner,
      const Get5StatsTeam team1, const Get5StatsTeam team2) {
    Get5MapResultEvent self = view_as<Get5MapResultEvent>(new JSON_Object());
    self.SetEvent("map_result");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.Winner = winner;
    self.Team1 = team1;
    self.Team2 = team2;
    return self;
  }
}

methodmap Get5GameStateChangedEvent < Get5Event {

  property Get5State NewState {
    public get() {
      return view_as<Get5State>(this.GetInt("new_state_int"));
    }
    public set(Get5State state) {
      this.SetInt("new_state_int", view_as<int>(state));
      this.SetHidden("new_state_int", true);
      ConvertGameStateToStringInJson(this, "new_state", state);
    }
  }

  property Get5State OldState {
    public get() {
      return view_as<Get5State>(this.GetInt("old_state_int"));
    }
    public set(Get5State state) {
      this.SetInt("old_state_int", view_as<int>(state));
      this.SetHidden("old_state_int", true);
      ConvertGameStateToStringInJson(this, "old_state", state);
    }
  }

  public Get5GameStateChangedEvent(const Get5State newState, const Get5State oldState) {
    Get5GameStateChangedEvent self = view_as<Get5GameStateChangedEvent>(new JSON_Object());
    self.SetEvent("game_state_changed");
    self.NewState = newState;
    self.OldState = oldState;
    return self;
  }
}

methodmap Get5RoundStatsUpdatedEvent < Get5RoundEvent {

  public Get5RoundStatsUpdatedEvent(const char[] matchId, const int mapNumber, const int roundNumber) {
    Get5RoundStatsUpdatedEvent self = view_as<Get5RoundStatsUpdatedEvent>(new JSON_Object());
    self.SetEvent("stats_updated");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    return self;
  }
}

methodmap Get5DemoFileEvent < Get5MapEvent {

  public bool SetFileName(const char[] filename) {
    return this.SetString("filename", filename);
  }
  public bool GetFileName(char[] buffer, const int maxSize) {
    return this.GetString("filename", buffer, maxSize);
  }
}

methodmap Get5DemoFinishedEvent < Get5DemoFileEvent {

  public Get5DemoFinishedEvent(const char[] matchId, const int mapNumber, const char[] filename) {
    Get5DemoFinishedEvent self = view_as<Get5DemoFinishedEvent>(new JSON_Object());
    self.SetEvent("demo_finished");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.SetFileName(filename);
    return self;
  }
}

methodmap Get5DemoUploadEndedEvent < Get5DemoFileEvent {

  property bool Success {
    public get() {
      return this.GetBool("success");
    }
    public set(bool success) {
      this.SetBool("success", success);
    }
  }

  public Get5DemoUploadEndedEvent(const char[] matchId, const int mapNumber, const char[] filename, const bool success) {
    Get5DemoUploadEndedEvent self = view_as<Get5DemoUploadEndedEvent>(new JSON_Object());
    self.SetEvent("demo_upload_ended");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.SetFileName(filename);
    self.Success = success;
    return self;
  }
}

methodmap Get5KnifeRoundStartedEvent < Get5MapEvent {

  public Get5KnifeRoundStartedEvent(const char[] matchId, int mapNumber) {
    Get5KnifeRoundStartedEvent self = view_as<Get5KnifeRoundStartedEvent>(new JSON_Object());
    self.SetEvent("knife_start");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    return self;
  }
}

methodmap Get5KnifeRoundWonEvent < Get5MapTeamEvent {

  // We don't use Get5Winner here as the side represents the picked side.
  // Team already represents the winning team. Winning side is irrelevant in knife.
  property Get5Side Side {
    public get() {
      return view_as<Get5Side>(this.GetInt("side_int"));
    }
    public set(Get5Side side) {
      this.SetInt("side_int", view_as<int>(side));
      this.SetHidden("side_int", true);
      ConvertGet5SideToStringInJson(this, "side", side);
    }
  }

  property bool Swapped {
    public get() {
      return this.GetBool("swapped");
    }
    public set(bool swapped) {
      this.SetBool("swapped", swapped);
    }
  }

  public Get5KnifeRoundWonEvent(const char[] matchId, int mapNumber, const Get5Team winner, const Get5Side side, const bool swapped) {
    Get5KnifeRoundWonEvent self = view_as<Get5KnifeRoundWonEvent>(new JSON_Object());
    self.SetEvent("knife_won");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.Team = winner;
    self.Side = side;
    self.Swapped = swapped;
    return self;
  }
}

methodmap Get5MatchPauseEvent < Get5MapTeamEvent {

  property Get5PauseType PauseType {
    public get() {
      return view_as<Get5PauseType>(this.GetInt("pause_type_int"));
    }
    public set(Get5PauseType type) {
      this.SetInt("pause_type_int", view_as<int>(type));
      this.SetHidden("pause_type_int", true);
      ConvertGet5PauseTypeToStringInJson(this, "pause_type", type);
    }
  }
}

methodmap Get5MatchPauseBeganEvent < Get5MatchPauseEvent {

  public Get5MatchPauseBeganEvent(const char[] matchId, const int mapNumber, const Get5Team team, const Get5PauseType pauseType) {
    Get5MatchPauseBeganEvent self = view_as<Get5MatchPauseBeganEvent>(new JSON_Object());
    self.SetEvent("pause_began");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.Team = team;
    self.PauseType = pauseType;
    return self;
  }
}

methodmap Get5MatchPausedEvent < Get5MatchPauseEvent {

  public Get5MatchPausedEvent(const char[] matchId, const int mapNumber, const Get5Team team, const Get5PauseType pauseType) {
    Get5MatchPausedEvent self = view_as<Get5MatchPausedEvent>(new JSON_Object());
    self.SetEvent("game_paused");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.Team = team;
    self.PauseType = pauseType;
    return self;
  }
}

methodmap Get5MatchUnpausedEvent < Get5MatchPauseEvent {

  public Get5MatchUnpausedEvent(const char[] matchId, const int mapNumber, const Get5Team team, const Get5PauseType pauseType) {
    Get5MatchUnpausedEvent self = view_as<Get5MatchUnpausedEvent>(new JSON_Object());
    self.SetEvent("game_unpaused");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.Team = team;
    self.PauseType = pauseType;
    return self;
  }
}

methodmap Get5SeriesStartedEvent < Get5MatchEvent {

  property int SeriesLength {
    public get() {
      return this.GetInt("series_length");
    }
    public set(int val) {
      this.SetInt("series_length", val);
    }
  }

  property Get5TeamWrapper Team1 {
    public get() {
      return view_as<Get5TeamWrapper>(this.GetObject("team1"));
    }
    public set(Get5TeamWrapper team) {
      this.SetObject("team1", team);
    }
  }

  property Get5TeamWrapper Team2 {
    public get() {
      return view_as<Get5TeamWrapper>(this.GetObject("team2"));
    }
    public set(Get5TeamWrapper team) {
      this.SetObject("team2", team);
    }
  }

  public Get5SeriesStartedEvent(const char[] matchId, const int length, const Get5TeamWrapper team1, const Get5TeamWrapper team2) {
    Get5SeriesStartedEvent self = view_as<Get5SeriesStartedEvent>(new JSON_Object());
    self.SetEvent("series_start");
    self.SetMatchId(matchId);
    self.SeriesLength = length;
    self.Team1 = team1;
    self.Team2 = team2;
    return self;
  }
}

methodmap Get5BackupRestoredEvent < Get5RoundEvent {

  public bool SetFileName(const char[] file) {
    return this.SetString("filename", file);
  }
  public bool GetFileName(char[] buffer, const int maxSize) {
    return this.GetString("filename", buffer, maxSize);
  }

  public Get5BackupRestoredEvent(const char[] matchId, const int mapNumber, const int roundNumber, const char[] file) {
    Get5BackupRestoredEvent self = view_as<Get5BackupRestoredEvent>(new JSON_Object());
    self.SetEvent("backup_loaded");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.SetFileName(file);
    return self;
  }
}

methodmap Get5RoundStartedEvent < Get5RoundEvent {

  public Get5RoundStartedEvent(const char[] matchId, const int mapNumber, const int roundNumber) {
    Get5RoundStartedEvent self = view_as<Get5RoundStartedEvent>(new JSON_Object());
    self.SetEvent("round_start");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    return self;
  }
}

methodmap Get5GoingLiveEvent < Get5MapEvent {

  public Get5GoingLiveEvent(const char[] matchId, const int mapNumber) {
    Get5GoingLiveEvent self = view_as<Get5GoingLiveEvent>(new JSON_Object());
    self.SetEvent("going_live");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    return self;
  }
}

methodmap Get5RoundEndedEvent < Get5TimedRoundEvent {

  // Note that reason is decremented by 1 to match the values defined at https://github.com/alliedmodders/sourcemod/blob/master/plugins/include/cstrike.inc
  // CSGO increments these by 1 for some reason.
  property CSRoundEndReason Reason {
    public get() {
      return view_as<CSRoundEndReason>(this.GetInt("reason"));
    }
    public set(CSRoundEndReason reason) {
      this.SetInt("reason", view_as<int>(reason));
    }
  }

  property Get5Winner Winner {
    public get() {
      return view_as<Get5Winner>(this.GetObject("winner"));
    }
    public set(Get5Winner winner) {
      this.SetObject("winner", winner);
    }
  }

  property Get5StatsTeam Team1 {
    public get() {
      return view_as<Get5StatsTeam>(this.GetObject("team1"));
    }
    public set(Get5StatsTeam team) {
      this.SetObject("team1", team);
    }
  }

  property Get5StatsTeam Team2 {
    public get() {
      return view_as<Get5StatsTeam>(this.GetObject("team2"));
    }
    public set(Get5StatsTeam team) {
      this.SetObject("team2", team);
    }
  }

  public Get5RoundEndedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime,
      const CSRoundEndReason reason, const Get5Winner winner, const Get5StatsTeam team1, const Get5StatsTeam team2) {
    Get5RoundEndedEvent self = view_as<Get5RoundEndedEvent>(new JSON_Object());
    self.SetEvent("round_end");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Reason = reason;
    self.Winner = winner;
    self.Team1 = team1;
    self.Team2 = team2;
    return self;
  }
}

// All other events

methodmap Get5PlayerSayEvent < Get5PlayerTimedRoundEvent {

  public bool SetCommand(const char[] command) {
    return this.SetString("command", command);
  }
  public bool GetCommand(char[] buffer, const int maxSize) {
    return this.GetString("command", buffer, maxSize);
  }

  public bool SetMessage(const char[] message) {
    return this.SetString("message", message);
  }
  public bool GetMessage(char[] buffer, const int maxSize) {
    return this.GetString("message", buffer, maxSize);
  }

  public Get5PlayerSayEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, const char[] command, const char[] message) {
    Get5PlayerSayEvent self = view_as<Get5PlayerSayEvent>(new JSON_Object());
    self.SetEvent("player_say");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.SetCommand(command);
    self.SetMessage(message);
    return self;
  }
}

methodmap Get5RoundMVPEvent < Get5PlayerRoundEvent {

  // There doesn't seem to be an enum for MVP reason, so we go with the plain integer.
  property int Reason {
    public get() {
      return this.GetInt("reason");
    }
    public set(int reason) {
      this.SetInt("reason", reason);
    }
  }

  public Get5RoundMVPEvent(const char[] matchId, const int mapNumber, const int roundNumber, const Get5Player player, const int reason) {
    Get5RoundMVPEvent self = view_as<Get5RoundMVPEvent>(new JSON_Object());
    self.SetEvent("round_mvp");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.Player = player;
    self.Reason = reason;
    return self;
  }
}

methodmap Get5AssisterObject < JSON_Object {

  property Get5Player Player {
    public get() {
      return view_as<Get5Player>(this.GetObject("player"));
    }
    public set(Get5Player player) {
      this.SetObject("player", player);
    }
  }

  property bool FriendlyFire {
    public get() {
      return this.GetBool("friendly_fire");
    }
    public set(bool friendlyFire) {
      this.SetBool("friendly_fire", friendlyFire);
    }
  }

  property bool FlashAssist {
    public get() {
      return this.GetBool("flash_assist");
    }
    public set(bool flashAssist) {
      this.SetBool("flash_assist", flashAssist);
    }
  }

  public Get5AssisterObject(const Get5Player player, bool flashAssist, bool friendlyFire) {
    Get5AssisterObject self = view_as<Get5AssisterObject>(new JSON_Object());
    self.Player = player;
    self.FlashAssist = flashAssist;
    self.FriendlyFire = friendlyFire;
    return self;
  }
}

methodmap Get5PlayerWeaponEvent < Get5PlayerTimedRoundEvent {

  property Get5Weapon Weapon {
    public get() {
      return view_as<Get5Weapon>(this.GetObject("weapon"));
    }
    public set(Get5Weapon weapon) {
      this.SetObject("weapon", weapon);
    }
  }
}

methodmap Get5PlayerDeathEvent < Get5PlayerWeaponEvent {

  property bool Bomb {
    public get() {
      return this.GetBool("bomb");
    }
    public set(bool bomb) {
      this.SetBool("bomb", bomb);
    }
  }

  property bool Headshot {
    public get() {
      return this.GetBool("headshot");
    }
    public set(bool headshot) {
      this.SetBool("headshot", headshot);
    }
  }

  property bool ThruSmoke {
    public get() {
      return this.GetBool("thru_smoke");
    }
    public set(bool thruSmoke) {
      this.SetBool("thru_smoke", thruSmoke);
    }
  }

  property int Penetrated {
    public get() {
      return this.GetInt("penetrated");
    }
    public set(int penetrated) {
      this.SetInt("penetrated", penetrated);
    }
  }

  property bool AttackerBlind {
    public get() {
      return this.GetBool("attacker_blind");
    }
    public set(bool blind) {
      this.SetBool("attacker_blind", blind);
    }
  }

  property bool NoScope {
    public get() {
      return this.GetBool("no_scope");
    }
    public set(bool noScope) {
      this.SetBool("no_scope", noScope);
    }
  }

  property bool Suicide {
    public get() {
      return this.GetBool("suicide");
    }
    public set(bool suicide) {
      this.SetBool("suicide", suicide);
    }
  }

  property bool FriendlyFire {
    public get() {
      return this.GetBool("friendly_fire");
    }
    public set(bool friendlyFire) {
      this.SetBool("friendly_fire", friendlyFire);
    }
  }

  property Get5Player Attacker {
    public get() {
      return view_as<Get5Player>(this.GetObject("attacker"));
    }
    public set(Get5Player attacker) {
      this.SetObject("attacker", attacker);
    }
  }

  property Get5AssisterObject Assist {
    public get() {
      return view_as<Get5AssisterObject>(this.GetObject("assist"));
    }
    public set(Get5AssisterObject assister) {
      this.SetObject("assist", assister);
    }
  }

  // Use before accessing "Assist", as its getter will raise an exception if null.
  public bool HasAssist() {
    return this.GetObject("assist") != null;
  }

  // Use before accessing "Attacker", as its getter will raise an exception if null.
  public bool HasAttacker() {
    return this.GetObject("attacker") != null;
  }

  public Get5PlayerDeathEvent(
    const char[] matchId,
    const int mapNumber,
    const int roundNumber,
    const int roundTime,
    const Get5Player victim,
    const Get5Weapon weapon,
    const bool headshot,
    const bool friendlyFire,
    const bool thruSmoke,
    const bool noScope,
    const bool attackerBlind,
    const bool suicide,
    const int penetrated,
    const bool bomb) {
      Get5PlayerDeathEvent self = view_as<Get5PlayerDeathEvent>(new JSON_Object());
      self.SetEvent("player_death");
      self.SetMatchId(matchId);
      self.MapNumber = mapNumber;
      self.RoundNumber = roundNumber;
      self.RoundTime = roundTime;
      self.Player = victim;
      self.Weapon = weapon;
      self.Headshot = headshot;
      self.FriendlyFire = friendlyFire;
      self.ThruSmoke = thruSmoke;
      self.NoScope = noScope;
      self.AttackerBlind = attackerBlind;
      self.Suicide = suicide;
      self.Penetrated = penetrated;
      self.Bomb = bomb;

      // set nullables to null initially
      self.SetObject("assist", null);
      self.SetObject("attacker", null);
      return self;
  }
}

// GRENADES
methodmap Get5GrenadeThrownEvent < Get5PlayerWeaponEvent {

  public Get5GrenadeThrownEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, const Get5Weapon weapon) {
    Get5GrenadeThrownEvent self = view_as<Get5GrenadeThrownEvent>(new JSON_Object());
    self.SetEvent("grenade_thrown");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Weapon = weapon;
    return self;
  }
}

methodmap Get5VictimGrenadeEvent < Get5PlayerWeaponEvent {

  // Array of either Get5DamageGrenadeVictim or Get5BlindedGrenadeVictim
  property JSON_Array Victims {
    public get() {
      return view_as<JSON_Array>(this.GetObject("victims"));
    }
    public set(JSON_Array victims) {
      this.SetObject("victims", victims);
    }
  }
}

methodmap Get5VictimWithDamageGrenadeEvent < Get5VictimGrenadeEvent {

  property int DamageEnemies {
    public get() {
      return this.GetInt("damage_enemies");
    }
    public set(int damage) {
      this.SetInt("damage_enemies", damage);
    }
  }

  property int DamageFriendlies {
    public get() {
      return this.GetInt("damage_friendlies");
    }
    public set(int damage) {
      this.SetInt("damage_friendlies", damage);
    }
  }
}

methodmap Get5SmokeDetonatedEvent < Get5PlayerWeaponEvent {

  property bool ExtinguishedMolotov {
    public get() {
      return this.GetBool("extinguished_molotov");
    }
    public set(bool extinguishedMolotov) {
      this.SetBool("extinguished_molotov", extinguishedMolotov);
    }
  }

  public Get5SmokeDetonatedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, bool extinguishedMolotov) {
    Get5SmokeDetonatedEvent self = view_as<Get5SmokeDetonatedEvent>(new JSON_Object());
    self.SetEvent("smokegrenade_detonated");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Weapon = new Get5Weapon("smokegrenade", CSWeapon_SMOKEGRENADE);
    self.ExtinguishedMolotov = extinguishedMolotov;
    return self;
  }
}

methodmap Get5HEDetonatedEvent < Get5VictimWithDamageGrenadeEvent {

  public Get5HEDetonatedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
    Get5HEDetonatedEvent self = view_as<Get5HEDetonatedEvent>(new JSON_Object());
    self.SetEvent("hegrenade_detonated");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Weapon = new Get5Weapon("hegrenade", CSWeapon_HEGRENADE);
    self.Victims = new JSON_Array();
    self.DamageEnemies = 0;
    self.DamageFriendlies = 0;
    return self;
  }
}

methodmap Get5FlashbangDetonatedEvent < Get5VictimGrenadeEvent {

  public Get5FlashbangDetonatedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
    Get5FlashbangDetonatedEvent self = view_as<Get5FlashbangDetonatedEvent>(new JSON_Object());
    self.SetEvent("flashbang_detonated");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Weapon = new Get5Weapon("flashbang", CSWeapon_FLASHBANG);
    self.Victims = new JSON_Array();
    return self;
  }
}

methodmap Get5DecoyStartedEvent < Get5PlayerWeaponEvent {

  public Get5DecoyStartedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
    Get5DecoyStartedEvent self = view_as<Get5DecoyStartedEvent>(new JSON_Object());
    self.SetEvent("decoygrenade_started");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Weapon = new Get5Weapon("decoy", CSWeapon_DECOY);
    return self;
  }
}

// This event fires when the molotov ends, but its RoundTime parameter is when it started burning.
// Note that this event does *not* fire if the molotov was thrown directly at a smoke and did not start burning.
methodmap Get5MolotovDetonatedEvent < Get5VictimWithDamageGrenadeEvent {

  // RoundTime is when the molotov detonated.
  property int EndTime {
    public get() {
      return this.GetInt("round_time_ended");
    }
    public set(int endTime) {
      this.SetInt("round_time_ended", endTime);
      this.SetInt("duration", endTime - this.RoundTime);
    }
  }

  public Get5MolotovDetonatedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player) {
    Get5MolotovDetonatedEvent self = view_as<Get5MolotovDetonatedEvent>(new JSON_Object());
    self.SetEvent("molotov_detonated");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Weapon = new Get5Weapon("molotov", CSWeapon_MOLOTOV); // SourceMod does not give us the info required to distinguish between molly and firebomb
    self.Victims = new JSON_Array();
    self.EndTime = 0; // Set after the molotov stops burning (either by expiration, extinguish or new round start).
    self.DamageEnemies = 0;
    self.DamageFriendlies = 0;
    return self;
  }
}

methodmap Get5GrenadeVictim < JSON_Object {

  property Get5Player Player {
    public get() {
      return view_as<Get5Player>(this.GetObject("player"));
    }
    public set(Get5Player player) {
      this.SetObject("player", player);
    }
  }

  property bool FriendlyFire {
    public get() {
      return this.GetBool("friendly_fire");
    }
    public set(bool friendlyFire) {
      this.SetBool("friendly_fire", friendlyFire);
    }
  }
}

methodmap Get5DamageGrenadeVictim < Get5GrenadeVictim {

  property int Damage {
    public get() {
      return this.GetInt("damage");
    }
    public set(int damage) {
      this.SetInt("damage", damage);
    }
  }

  property bool Killed {
    public get() {
      return this.GetBool("killed");
    }
    public set(bool killed) {
      this.SetBool("killed", killed);
    }
  }

  public Get5DamageGrenadeVictim(const Get5Player player, const bool friendlyFire, bool killed, const int damage) {
    Get5DamageGrenadeVictim self = view_as<Get5DamageGrenadeVictim>(new JSON_Object());
    self.Player = player
    self.FriendlyFire = friendlyFire;
    self.Killed = killed;
    self.Damage = damage;
    return self;
  }
}

methodmap Get5BlindedGrenadeVictim < Get5GrenadeVictim {

  property float BlindDuration {
    public get() {
      return this.GetFloat("blind_duration");
    }
    public set(float blindDuration) {
      this.SetFloat("blind_duration", blindDuration);
    }
  }

  public Get5BlindedGrenadeVictim(const Get5Player player, const bool friendlyFire, const float blindDuration) {
    Get5BlindedGrenadeVictim self = view_as<Get5BlindedGrenadeVictim>(new JSON_Object());
    self.Player = player
    self.FriendlyFire = friendlyFire;
    self.BlindDuration = blindDuration;
    return self;
  }
}

// BOMB

methodmap Get5BombEvent < Get5TimedRoundEvent {

  property Get5BombSite Site {
    public get() {
      return view_as<Get5BombSite>(this.GetInt("site_int"));
    }
    public set(Get5BombSite site) {
      this.SetInt("site_int", view_as<int>(site));
      this.SetHidden("site_int", true);
      ConvertBombSiteToStringInJson(this, "site", site);
    }
  }
}

methodmap Get5PlayerBombEvent < Get5PlayerTimedRoundEvent {

  property Get5BombSite Site {
    public get() {
      return view_as<Get5BombSite>(this.GetInt("site_int"));
    }
    public set(Get5BombSite site) {
      this.SetInt("site_int", view_as<int>(site));
      this.SetHidden("site_int", true);
      ConvertBombSiteToStringInJson(this, "site", site);
    }
  }
}

methodmap Get5BombPlantedEvent < Get5PlayerBombEvent {

  public Get5BombPlantedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5Player player, const Get5BombSite site) {
    Get5BombPlantedEvent self = view_as<Get5BombPlantedEvent>(new JSON_Object());
    self.SetEvent("bomb_planted");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Site = site;
    return self;
  }
}

methodmap Get5BombExplodedEvent < Get5BombEvent {

  public Get5BombExplodedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime, const Get5BombSite site) {
    Get5BombExplodedEvent self = view_as<Get5BombExplodedEvent>(new JSON_Object());
    self.SetEvent("bomb_exploded");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Site = site;
    return self;
  }
}

methodmap Get5BombDefusedEvent < Get5PlayerBombEvent {

  property int TimeRemaining {
    public get() {
      return this.GetInt("bomb_time_remaining");
    }
    public set(int time) {
      this.SetInt("bomb_time_remaining", time);
    }
  }

  public Get5BombDefusedEvent(const char[] matchId, const int mapNumber, const int roundNumber, const int roundTime,
    const Get5Player player, const Get5BombSite site, const int timeRemaining) {
    Get5BombDefusedEvent self = view_as<Get5BombDefusedEvent>(new JSON_Object());
    self.SetEvent("bomb_defused");
    self.SetMatchId(matchId);
    self.MapNumber = mapNumber;
    self.RoundNumber = roundNumber;
    self.RoundTime = roundTime;
    self.Player = player;
    self.Site = site;
    self.TimeRemaining = timeRemaining;
    return self;
  }
}

stock void GameStateString(const Get5State state, char[] buffer, const int length) {
  switch (state) {
    case Get5State_None:
      FormatEx(buffer, length, "none");
    case Get5State_PreVeto:
      FormatEx(buffer, length, "pre_veto");
    case Get5State_Veto:
      FormatEx(buffer, length, "veto");
    case Get5State_Warmup:
      FormatEx(buffer, length, "warmup");
    case Get5State_KnifeRound:
      FormatEx(buffer, length, "knife");
    case Get5State_WaitingForKnifeRoundDecision:
      FormatEx(buffer, length, "waiting_for_knife_decision");
    case Get5State_GoingLive:
      FormatEx(buffer, length, "going_live");
    case Get5State_Live:
      FormatEx(buffer, length, "live");
    case Get5State_PendingRestore:
      FormatEx(buffer, length, "pending_restore");
    case Get5State_PostGame:
      FormatEx(buffer, length, "post_game");
  }
}

stock void ConvertGameStateToStringInJson(const JSON_Object obj, const char[] key,
                                          const Get5State state) {
  char gameStateString[64];
  GameStateString(state, gameStateString, sizeof(gameStateString));
  obj.SetString(key, gameStateString);
}

stock void ConvertGet5SideToStringInJson(const JSON_Object obj, const char[] key, Get5Side side) {
  if (side == Get5Side_T) {
    obj.SetString(key, "t");
  } else if (side == Get5Side_CT) {
    obj.SetString(key, "ct");
  } else if (side == Get5Side_Spec) {
    obj.SetString(key, "spec");
  } else {
    obj.SetObject(key, null);
  }
}

stock void ConvertGet5TeamToStringInJson(const JSON_Object obj, const char[] key, Get5Team team) {
  if (team == Get5Team_1) {
    obj.SetString(key, "team1");
  } else if (team == Get5Team_2) {
    obj.SetString(key, "team2");
  } else if (team == Get5Team_Spec) {
    obj.SetString(key, "spec");
  } else {
    obj.SetObject(key, null);
  }
}

stock void ConvertGet5PauseTypeToStringInJson(const JSON_Object obj, const char[] key,
                                              Get5PauseType pauseType) {
  if (pauseType == Get5PauseType_Admin) {
    obj.SetString(key, "admin");
  } else if (pauseType == Get5PauseType_Tech) {
    obj.SetString(key, "technical");
  } else if (pauseType == Get5PauseType_Tactical) {
    obj.SetString(key, "tactical");
  } else if (pauseType == Get5PauseType_Backup) {
    obj.SetString(key, "backup");
  } else {
    obj.SetObject(key, null);
  }
}

stock void ConvertBombSiteToStringInJson(const JSON_Object obj, const char[] key,
                                         const Get5BombSite site) {
  if (site == Get5BombSite_A) {
    obj.SetString(key, "a");
  } else if (site == Get5BombSite_B) {
    obj.SetString(key, "b");
  } else {
    obj.SetObject(key, null);
  }
}

// Called each get5-event with JSON formatted event text.
forward void Get5_OnEvent(const Get5Event event, const char[] eventJson);

// Called when a series is first setup.
// Note: Do not rely on the state of any cvars at this point.
// Also: matchId is an empty string at this stage if not defined in the match config.
forward void Get5_OnSeriesInit(const Get5SeriesStartedEvent event);

// Called each time in a match when a map is going live.
// The mapNumber parameter starts at 0.
forward void Get5_OnGoingLive(const Get5GoingLiveEvent event);

// Called whenever the gamestate phase is changed.
forward void Get5_OnGameStateChanged(const Get5GameStateChangedEvent event);

// Called when a grenade is thrown.
forward void Get5_OnGrenadeThrown(const Get5GrenadeThrownEvent event);

// Called when the stats for the last round have been updated.
forward void Get5_OnRoundStatsUpdated(const Get5RoundStatsUpdatedEvent event);

// Called at the end of a map in a series.
forward void Get5_OnMapResult(const Get5MapResultEvent event);

// Called at the end of a full match.
// Note: both Get5_OnMapResult and Get5_OnSeriesResult are called on the last map of a series.
forward void Get5_OnSeriesResult(const Get5SeriesResultEvent event);

forward void Get5_OnPreLoadMatchConfig(const Get5PreloadMatchConfigEvent event);

// Called when a match config fails to load.
forward void Get5_OnLoadMatchConfigFailed(const Get5LoadMatchConfigFailedEvent event);

// Called when a team vetoes a map.
forward void Get5_OnMapVetoed(const Get5MapVetoedEvent event);

// Called when the knife round starts.
forward void Get5_OnKnifeRoundStarted(const Get5KnifeRoundStartedEvent event);

// Called when a team has won the knife round and picked a starting side.
forward void Get5_OnKnifeRoundWon(const Get5KnifeRoundWonEvent event);

// Called when a team selects a map.
// The team parameter will be Get5Team_None if the map was selected as the last remaining map
// and not by one of the teams specifically.
forward void Get5_OnMapPicked(const Get5MapPickedEvent event);

// Called when a player connects to the server.
forward void Get5_OnPlayerConnected(const Get5PlayerConnectedEvent event);

// Called when a player disconnects from the server.
forward void Get5_OnPlayerDisconnected(const Get5PlayerDisconnectedEvent event);

// Called when a player is elected the MVP of the round.
forward void Get5_OnPlayerBecameMVP(const Get5RoundMVPEvent event);

// Called when a player dies in a match, including from suicide and team kills.
forward void Get5_OnPlayerDeath(const Get5PlayerDeathEvent event);

// Called when a player types something in the chat, including commands.
forward void Get5_OnPlayerSay(const Get5PlayerSayEvent event);

// Called when a round starts (not when freezetime ends!)
forward void Get5_OnRoundStart(const Get5RoundStartedEvent event);

// Called when a flashbang detonates (after collecting victim info)
forward void Get5_OnFlashbangDetonated(const Get5FlashbangDetonatedEvent event);

// Called when a decoy grenade starts making noise.
forward void Get5_OnDecoyStarted(const Get5DecoyStartedEvent event);

// Called when an HE grenade goes off (after collecting victim info).
forward void Get5_OnHEGrenadeDetonated(const Get5HEDetonatedEvent event);

// Called when a smoke grenade detonates.
forward void Get5_OnSmokeGrenadeDetonated(const Get5SmokeDetonatedEvent event);

// Called when a molotov grenade expires - or if the round ends (after collecting victim info).
forward void Get5_OnMolotovDetonated(const Get5MolotovDetonatedEvent event);

// Called when the round ends.
forward void Get5_OnRoundEnd(const Get5RoundEndedEvent event);

// Called when the bomb is defused.
forward void Get5_OnBombDefused(const Get5BombDefusedEvent event);

// Called when the bomb is planted.
forward void Get5_OnBombPlanted(const Get5BombPlantedEvent event);

// Called when the bomb explodes.
forward void Get5_OnBombExploded(const Get5BombExplodedEvent event);

// Called when a team selects a side.
forward void Get5_OnSidePicked(const Get5SidePickedEvent event);

// Called when a demo finishes recording.
forward void Get5_OnDemoFinished(const Get5DemoFinishedEvent event);

// Called when a demo upload attempt ends.
forward void Get5_OnDemoUploadEnded(const Get5DemoUploadEndedEvent event);

// Called when a match is paused.
forward void Get5_OnMatchPaused(const Get5MatchPausedEvent event);

// Called when a match is unpaused.
forward void Get5_OnMatchUnpaused(const Get5MatchUnpausedEvent event);

// Called when a pause begins.
forward void Get5_OnPauseBegan(const Get5MatchPauseBeganEvent event);

// Called when a match backup is restored.
// Note that the match ID, map number and round number is the one being restored *to*, not the current game state at the
// time the backup is loaded.
forward void Get5_OnBackupRestore(const Get5BackupRestoredEvent event);

public SharedPlugin __pl_get5 = {
    name = "get5",
    file = "get5.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_get5_SetNTVOptional() {
  MarkNativeAsOptional("Get5_GetGameState");
  MarkNativeAsOptional("Get5_Message");
  MarkNativeAsOptional("Get5_MessageToTeam");
  MarkNativeAsOptional("Get5_MessageToAll");
  MarkNativeAsOptional("Get5_LoadMatchConfig");
  MarkNativeAsOptional("Get5_LoadMatchConfigFromURL");
  MarkNativeAsOptional("Get5_AddPlayerToTeam");
  MarkNativeAsOptional("Get5_SetPlayerName");
  MarkNativeAsOptional("Get5_RemovePlayerFromTeam");
  MarkNativeAsOptional("Get5_GetPlayerTeam");
  MarkNativeAsOptional("Get5_CSTeamToGet5Team");
  MarkNativeAsOptional("Get5_Get5TeamToCSTeam");
  MarkNativeAsOptional("Get5_GetTeamScores");
  MarkNativeAsOptional("Get5_GetMatchID");
  MarkNativeAsOptional("Get5_SetMatchID");
  MarkNativeAsOptional("Get5_GetServerID");
  MarkNativeAsOptional("Get5_AddLiveCvar");
  MarkNativeAsOptional("Get5_IncreasePlayerStat");
  MarkNativeAsOptional("Get5_GetMatchStats");
  MarkNativeAsOptional("Get5_GetMapNumber");
}
#endif
