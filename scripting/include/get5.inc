#if defined _get5_included_
  #endinput
#endif
#define _get5_included_

enum GameState {
    GameState_None,                          // no setup has taken place
    GameState_PreVeto,                       // warmup, waiting for the veto
    GameState_Veto,                          // warmup, doing the veto
    GameState_Warmup,                        // setup done, waiting for players to ready up
    GameState_KnifeRound,                    // in the knife round
    GameState_WaitingForKnifeRoundDecision,  // waiting for a .stay/.swap command after the knife round
    GameState_GoingLive,                     // in the lo3 process
    GameState_Live,                          // the match is live
    GameState_PostGame,                      // postgame screen + waiting for GOTV to finish broadcast
};

enum MatchTeam {
    MatchTeam_Team1,
    MatchTeam_Team2,
    MatchTeam_TeamSpec,
    MatchTeam_TeamNone,
    MatchTeam_Count,
};

enum MatchSideType {
    MatchSideType_Standard,     // Team that doesn't pick map gets side choice, leftovers go to knife rounds
    MatchSideType_AlwaysKnife,  // All maps use a knife round to pick sides
    MatchSideType_NeverKnife,   // Team 1 always starts CT
};

enum SideChoice {
    SideChoice_Team1CT,     // Team 1 will start on CT
    SideChoice_Team1T,      // Team 2 will start on T
    SideChoice_KnifeRound,  // There will be a knife round to choose sides
};

// Called at the end of a map in a series.
forward void Get5_OnMapResult(const char[] map, MatchTeam mapWinner,
    int team1Score, int team2Score);

// Called at the end of a full match.
// Note: both Get5_OnMapResult and Get5_OnSeriesResult are called
// on the last map of a series.
forward void Get5_OnSeriesResult(MatchTeam seriesWinner,
    int team1MapScore, int team2MapScore);

// Called when a match config fails to load.
forward void Get5_OnLoadMatchConfigFailed(const char[] reason);

// Returns the current pug gamestate.
native GameState Get5_GetGameState();

// Prints a plugin-formatted message to a client.
native void Get5_Message(int client, const char[] format, any:...);

// Prints a plugin-formatted message to all clients.
native void Get5_MessageToAll(const char[] format, any:...);

// Loads a match config (keyvalues or JSON) from a local file.
// Returns true if the config was successfully loaded.
native bool Get5_LoadMatchConfig(const char[] filename);

// Loads a match config by downloading a remote config via a HTTP GET request.
// If using the SteamWorks extension, request parameters should be left out of the url
// and put into the optional ArrayLists parameters.
native bool Get5_LoadMatchConfigFromURL(const char[] url,
    ArrayList paramNames=null, ArrayList paramValues=null);

// Adds a player to a match team.
// Returns if they were successfully added.
native bool Get5_AddPlayerToTeam(const char[] steamId, MatchTeam team);

// Removes a player from all match teams.
// Returns if they were successfully removed (false if not round).
native bool Get5_RemovePlayerFromTeam(const char[] steamId);

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
    MarkNativeAsOptional("Get5_MessageToAll");
    MarkNativeAsOptional("Get5_LoadMatchConfig");
    MarkNativeAsOptional("Get5_LoadMatchConfigFromURL");
    MarkNativeAsOptional("Get5_AddPlayerToTeam");
    MarkNativeAsOptional("Get5_RemovePlayerFromTeam");
}
#endif
