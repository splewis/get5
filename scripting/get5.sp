#include <cstrike>
#include <sdktools>
#include <sourcemod>
#include <testing>
#include "include/restorecvars.inc"
#include "include/logdebug.inc"
#include "include/get5.inc"

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include <system2>
#include <smjansson>
#include "get5/jsonhelpers.sp"
#define REMOTE_CONFIG_FILENAME "remote.json"

#define LIVE_TIMER_INTERVAL 1.0
#define INFO_MESSAGE_TIMER_INTERVAL 29.0

#define DEBUG_CVAR "get5_debug"
#define AUTH_LENGTH 64
#define AUTH_METHOD AuthId_Steam2
#define MATCH_ID_LENGTH 64
#define MATCH_NAME_LENGTH 64
#define MAX_CVAR_LENGTH 128
#define MATCH_END_DELAY_AFTER_TV 10

#define TEAM1_COLOR "{LIGHT_GREEN}"
#define TEAM2_COLOR "{PINK}"
#define TEAM1_STARTING_SIDE CS_TEAM_CT
#define TEAM2_STARTING_SIDE CS_TEAM_T
#define KNIFE_CONFIG "get5/knife.cfg"

#pragma semicolon 1
#pragma newdecls required



/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** ConVar handles **/
ConVar g_AutoLoadConfigCvar;
ConVar g_DemoNameFormatCvar;
ConVar g_DemoTimeFormatCvar;
ConVar g_KickClientsWithNoMatchCvar;
ConVar g_LiveCfgCvar;
ConVar g_PausingEnabledCvar;
ConVar g_QuickRestartCvar;
ConVar g_VersionCvar;
ConVar g_WaitForSpecReadyCvar;
ConVar g_WarmupCfgCvar;

// Hooked cvars built into csgo
ConVar g_CoachingEnabledCvar;

/** Series config game-state **/
int g_MapsToWin = 1;
char g_MatchID[MATCH_ID_LENGTH];
ArrayList g_MapPoolList = null;
ArrayList g_TeamAuths[MatchTeam_Count];
char g_TeamNames[MatchTeam_Count][MAX_CVAR_LENGTH];
char g_FormattedTeamNames[MatchTeam_Count][MAX_CVAR_LENGTH];
char g_TeamFlags[MatchTeam_Count][MAX_CVAR_LENGTH];
char g_TeamLogos[MatchTeam_Count][MAX_CVAR_LENGTH];
char g_TeamMatchTexts[MatchTeam_Count][MAX_CVAR_LENGTH];
char g_MatchTitle[MAX_CVAR_LENGTH];
int g_FavoredTeamPercentage = 0;
char g_FavoredTeamText[MAX_CVAR_LENGTH];
int g_PlayersPerTeam = 5;
bool g_SkipVeto = false;
MatchSideType g_MatchSideType = MatchSideType_Standard;
ArrayList g_CvarNames = null;
ArrayList g_CvarValues = null;

/** Other state **/
GameState g_GameState = GameState_None;
ArrayList g_MapsToPlay = null;
ArrayList g_MapSides = null;
ArrayList g_MapsLeftInVetoPool = null;
MatchTeam g_LastVetoTeam;

ArrayList g_TeamScoresPerMap = null;
char g_LoadedConfigFile[PLATFORM_MAX_PATH];
int g_VetoCaptains[MatchTeam_Count]; // Clients doing the map vetos.
int g_TeamSeriesScores[MatchTeam_Count]; // Current number of maps won per-team.
bool g_TeamReady[MatchTeam_Count]; // Whether a team is marked as ready.
int g_TeamSide[MatchTeam_Count]; // Current CS_TEAM_* side for the team.
bool g_TeamReadyForUnpause[MatchTeam_Count];

/** Map game-state **/
MatchTeam g_KnifeWinnerTeam = MatchTeam_TeamNone;

/** Map-game state not related to the actual gameplay. **/
char g_DemoFileName[PLATFORM_MAX_PATH];
bool g_MapChangePending = false;
bool g_MovingClientToCoach[MAXPLAYERS+1];
bool g_PendingSideSwap = false;

Handle g_KnifeChangedCvars = INVALID_HANDLE;

/** Forwards **/
Handle g_hOnMapResult = INVALID_HANDLE;
Handle g_hOnSeriesResult = INVALID_HANDLE;

#include "get5/util.sp"
#include "get5/kniferounds.sp"
#include "get5/liveon3.sp"
#include "get5/maps.sp"
#include "get5/mapveto.sp"
#include "get5/matchconfig.sp"
#include "get5/natives.sp"
#include "get5/teamlogic.sp"
#include "get5/tests.sp"
#include "get5/version.sp"



/***********************
 *                     *
 * Sourcemod forwards  *
 *                     *
 ***********************/

public Plugin myinfo = {
    name = "Get5",
    author = "splewis",
    description = "",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/get5"
};

public void OnPluginStart() {
    InitDebugLog(DEBUG_CVAR, "get5");

    /** ConVars **/
    g_AutoLoadConfigCvar = CreateConVar("get5_autoload_config", "",
        "Name of a match config file to automatically load when the server loads");
    g_DemoNameFormatCvar = CreateConVar("get5_demo_name_format",
        "{MATCHID}_map{MAPNUMBER}_{MAPNAME}", "Format for demo file names");
    g_DemoTimeFormatCvar = CreateConVar("get5_time_format", "%Y-%m-%d_%H",
        "Time format to use when creating demo file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
    g_KickClientsWithNoMatchCvar = CreateConVar("get5_kick_when_no_match_loaded", "0",
        "Whether the plugin kicks new clients when no match is loaded");
    g_LiveCfgCvar = CreateConVar("get5_live_cfg", "get5/live.cfg",
        "Config file to exec when the game goes live");
    g_PausingEnabledCvar = CreateConVar("get5_pausing_enabled", "1",
        "Whether pausing is allowed.");
    g_QuickRestartCvar = CreateConVar("get5_quick_restarts", "0",
        "Whether to use a quick restart or a full live-on-3 restart");
    g_WaitForSpecReadyCvar = CreateConVar("get5_wait_for_spec_ready", "0",
        "Whether to wait for spectators to ready up if there are any");
    g_WarmupCfgCvar = CreateConVar("get5_warmup_cfg", "get5/warmup.cfg",
        "Config file to exec in warmup periods");

    /** Create and exec plugin's configuration file **/
    AutoExecConfig(true, "get5");

    g_VersionCvar = CreateConVar("get5_version", PLUGIN_VERSION, "Current get5 version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
    g_VersionCvar.SetString(PLUGIN_VERSION);

    g_CoachingEnabledCvar = FindConVar("sv_coaching_enabled");

    /** Client commands **/
    RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
    RegConsoleCmd("sm_unready", Command_NotReady, "Marks the client as not ready");
    RegConsoleCmd("sm_notready", Command_NotReady, "Marks the client as not ready");
    RegConsoleCmd("sm_pause", Command_Pause, "Pauses the game");
    RegConsoleCmd("sm_unpause", Command_Unpause, "Unpauses the game");
    RegConsoleCmd("sm_coach", Command_SmCoach, "Marks a client as a coach for their team");
    RegConsoleCmd("sm_stay", Command_Stay, "Elects to stay on the current team after winning a knife round");
    RegConsoleCmd("sm_swap", Command_Swap, "Elects to swap the current teams after winning a knife round");
    RegConsoleCmd("sm_t", Command_T, "Elects to start on T side after winning a knife round");
    RegConsoleCmd("sm_ct", Command_Ct, "Elects to start on CT side after winning a knife round");

    /** Admin/server commands **/
    RegAdminCmd("get5_loadmatch", Command_LoadMatch, ADMFLAG_CHANGEMAP,
        "Loads a match config file (json or keyvalues) from a file relative to the csgo/ directory");
    RegAdminCmd("get5_loadmatch_url", Command_LoadMatchUrl, ADMFLAG_CHANGEMAP,
        "Loads a JSON config file by sending a GET request to download it. Requires either the SteamWorks or system2 extensions");
    RegAdminCmd("get5_endmatch", Command_EndMatch, ADMFLAG_CHANGEMAP,
        "Force ends the current match");
    RegAdminCmd("get5_addplayer", Command_AddPlayer, ADMFLAG_CHANGEMAP,
        "Adds a steamid to a match team");
    RegAdminCmd("get5_removeplayer", Command_RemovePlayer, ADMFLAG_CHANGEMAP,
        "Adds a steamid to a match team");
    RegAdminCmd("get5_creatematch", Command_CreateMatch, ADMFLAG_CHANGEMAP,
        "Creates and loads a match using the players currently on the server as a Bo1 with the current map");

    /** Other commands **/
    RegConsoleCmd("get5_status", Command_Status, "Prints JSON formatted match state info");
    RegServerCmd("get5_test", Command_Test,
        "Runs get5 tests - should not be used on a live match server since it will reload a match config to test");

    /** Hooks **/
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("cs_win_panel_match", Event_MatchOver);
    HookEvent("round_prestart", Event_RoundPreStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
    HookEvent("player_connect_full", Event_PlayerConnectFull);
    HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
    AddCommandListener(Command_Coach, "coach");
    AddCommandListener(Command_JoinTeam, "jointeam");
    AddCommandListener(Command_JoinGame, "joingame");

    /** Setup data structures **/
    g_MapPoolList = new ArrayList(PLATFORM_MAX_PATH);
    g_MapsLeftInVetoPool = new ArrayList(PLATFORM_MAX_PATH);
    g_MapsToPlay = new ArrayList(PLATFORM_MAX_PATH);
    g_MapSides = new ArrayList();
    g_CvarNames = new ArrayList(MAX_CVAR_LENGTH);
    g_CvarValues = new ArrayList(MAX_CVAR_LENGTH);
    g_TeamScoresPerMap = new ArrayList(view_as<int>(MatchTeam_Count));

    for (int i = 0; i < sizeof(g_TeamAuths); i++) {
        g_TeamAuths[i] = new ArrayList(AUTH_LENGTH);
    }

    /** Create forwards **/
    g_hOnMapResult = CreateGlobalForward("Get5_OnMapResult", ET_Ignore, Param_String,
        Param_Cell, Param_Cell, Param_Cell);
    g_hOnSeriesResult = CreateGlobalForward("Get5_OnSeriesResult", ET_Ignore, Param_Cell,
        Param_Cell, Param_Cell);

    /** Start any repeating timers **/
    CreateTimer(LIVE_TIMER_INTERVAL, Timer_CheckReady, _, TIMER_REPEAT);
    CreateTimer(INFO_MESSAGE_TIMER_INTERVAL, Timer_InfoMessages, _, TIMER_REPEAT);
}

public Action Timer_InfoMessages(Handle timer) {
    if (g_GameState == GameState_PreVeto) {
        Get5_MessageToAll("Type {GREEN}!ready {NORMAL}when your team is ready to veto.");
    } else if (g_GameState == GameState_Warmup && !g_MapChangePending) {
        if (AllTeamsReady(false) && !AllTeamsReady(true)) {
            Get5_MessageToAll("Waiting for the casters to type {GREEN}!ready {NORMAL}to begin.");
        } else {
            SideChoice sides = view_as<SideChoice>(g_MapSides.Get(GetMapNumber()));
            if (sides == SideChoice_KnifeRound) {
                Get5_MessageToAll("Type {GREEN}!ready {NORMAL}when your team is ready to knife.");
            } else {
                Get5_MessageToAll("Type {GREEN}!ready {NORMAL}when your team is ready to begin.");
            }
        }
    } else if (g_GameState == GameState_PostGame) {
        Get5_MessageToAll("The map will change once the GOTV broadcast has ended.");
    }
}

public void OnClientAuthorized(int client, const char[] auth) {
    g_MovingClientToCoach[client] = false;
    if (StrEqual(auth, "BOT", false)) {
        return;
    }

    if (g_GameState == GameState_None && g_KickClientsWithNoMatchCvar.IntValue != 0) {
        KickClient(client, "There is no match setup");
    }

    if (g_GameState != GameState_None) {
        MatchTeam team = GetClientMatchTeam(client);
        if (team == MatchTeam_TeamNone) {
            KickClient(client, "You are not a player in this match");
        } else {
            int teamCount = CountPlayersOnMatchTeam(team, client);
            if (teamCount >= g_PlayersPerTeam && g_CoachingEnabledCvar.IntValue == 0) {
                KickClient(client, "Your team is full");
            }
        }
    }
}

public void OnClientPutInServer(int client) {
    if (IsFakeClient(client)) {
        return;
    }

    if (g_GameState <= GameState_Warmup) {
        if (GetRealClientCount() <= 1) {
            ExecCfg(g_WarmupCfgCvar);
            EnsurePausedWarmup();
        }
    }
}

/**
 * Full connect event right when a player joins.
 * This sets the auto-pick time to a high value because mp_forcepicktime is broken and
 * if a player does not select a team but leaves their mouse over one, they are
 * put on that team and spawned, so we can't allow that.
 */
public Action Event_PlayerConnectFull(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
}

public void OnMapStart() {
    g_MapChangePending = false;

    LOOP_TEAMS(team) {
        g_TeamReady[team] = false;
    }

    SetStartingTeams();

    if (g_GameState == GameState_None) {
        char autoloadConfig[PLATFORM_MAX_PATH];
        g_AutoLoadConfigCvar.GetString(autoloadConfig, sizeof(autoloadConfig));
        if (!StrEqual(autoloadConfig, "")) {
            LoadMatchConfig(autoloadConfig);
        }
    }

    if (g_GameState == GameState_PostGame) {
        ChangeState(GameState_Warmup);
    }

    if (g_GameState == GameState_Warmup || g_GameState == GameState_Veto) {
        ExecCfg(g_WarmupCfgCvar);
        SetMatchTeamCvars();
        ExecuteMatchConfigCvars();
        EnsurePausedWarmup();
    }

}

public Action Timer_CheckReady(Handle timer) {
    if (g_GameState == GameState_PreVeto) {
        if (AllTeamsReady(false)) {
            ChangeState(GameState_Veto);
            CreateMapVeto();
        }

    } else  if (g_GameState == GameState_Warmup) {
        if (AllTeamsReady(true) && !g_MapChangePending) {
            int mapNumber = GetMapNumber();
            if (g_MapSides.Get(mapNumber) == SideChoice_KnifeRound) {
                ChangeState(GameState_KnifeRound);
                StartGame(true);
            } else {
                StartGame(false);
            }
        }
    }

    return Plugin_Continue;
}


/***********************
 *                     *
 *     Commands        *
 *                     *
 ***********************/

static bool Pauseable() {
    return g_GameState >= GameState_KnifeRound && g_PausingEnabledCvar.IntValue != 0;
}

public Action Command_Pause(int client, int args) {
    if (!Pauseable() || IsPaused())
        return Plugin_Handled;

    g_TeamReadyForUnpause[MatchTeam_Team1] = false;
    g_TeamReadyForUnpause[MatchTeam_Team2] = false;
    Pause();
    if (IsPlayer(client)) {
        Get5_MessageToAll("%N paused the match.", client);
    }

    return Plugin_Handled;
}

public Action Command_Unpause(int client, int args) {
    if (!IsPaused())
        return Plugin_Handled;

    // Let console force unpause
    if (client == 0) {
        Unpause();
    } else {
        MatchTeam team = GetClientMatchTeam(client);
        g_TeamReadyForUnpause[team] = true;

        if (g_TeamReadyForUnpause[MatchTeam_Team1] && g_TeamReadyForUnpause[MatchTeam_Team2])  {
            Unpause();
            if (IsPlayer(client)) {
                Get5_MessageToAll("%N unpaused the match.", client);
            }
        } else if (g_TeamReadyForUnpause[MatchTeam_Team1] && !g_TeamReadyForUnpause[MatchTeam_Team2]) {
            Get5_MessageToAll("%s wants to unpause, waiting for %s to type !unpause.",
                g_FormattedTeamNames[MatchTeam_Team1], g_FormattedTeamNames[MatchTeam_Team2]);
        } else if (!g_TeamReadyForUnpause[MatchTeam_Team1] && g_TeamReadyForUnpause[MatchTeam_Team2]) {
            Get5_MessageToAll("%s team wants to unpause, waiting for the %s to type !unpause.",
                g_FormattedTeamNames[MatchTeam_Team2], g_FormattedTeamNames[MatchTeam_Team1]);
        }
    }

    return Plugin_Handled;
}

public Action Command_Ready(int client, int args) {
    if (g_GameState == GameState_None) {
        return Plugin_Handled;
    }

    MatchTeam t = GetCaptainTeam(client);
    if (t == MatchTeam_Team1 && !g_TeamReady[MatchTeam_Team1]) {
        g_TeamReady[MatchTeam_Team1] = true;
        if (g_GameState == GameState_PreVeto) {
            Get5_MessageToAll("%s is ready to veto.", g_FormattedTeamNames[MatchTeam_Team1]);
        } else {
            Get5_MessageToAll("%s is ready to begin the match.", g_FormattedTeamNames[MatchTeam_Team1]);
        }
    } else if (t == MatchTeam_Team2 && !g_TeamReady[MatchTeam_Team2]) {
        g_TeamReady[MatchTeam_Team2] = true;
        if (g_GameState == GameState_PreVeto) {
            Get5_MessageToAll("%s is ready to veto.", g_FormattedTeamNames[MatchTeam_Team2]);
        } else {
            Get5_MessageToAll("%s is ready to begin the match.", g_FormattedTeamNames[MatchTeam_Team2]);
        }
    }
    return Plugin_Handled;
}

public Action Command_NotReady(int client, int args) {
    if (g_GameState == GameState_None) {
        return Plugin_Handled;
    }

    MatchTeam t = GetCaptainTeam(client);
    if (t == MatchTeam_Team1 && g_TeamReady[MatchTeam_Team1]) {
        Get5_MessageToAll("%s is no longer ready.", g_FormattedTeamNames[MatchTeam_Team1]);
        g_TeamReady[MatchTeam_Team1] = false;
    } else if (t == MatchTeam_Team2 && g_TeamReady[MatchTeam_Team2]) {
        Get5_MessageToAll("%s is no longer ready.", g_FormattedTeamNames[MatchTeam_Team2]);
        g_TeamReady[MatchTeam_Team2] = false;
    }
    return Plugin_Handled;
}

public Action Command_EndMatch(int client, int args) {
    if (g_GameState == GameState_None) {
        return Plugin_Handled;
    }
    ChangeState(GameState_None);

    Get5_MessageToAll("An admin force ended the match.");
    return Plugin_Handled;
}

public Action Command_LoadMatch(int client, int args) {
    if (g_GameState != GameState_None) {
        LogError("Cannot load a match when a match is already loaded");
        return Plugin_Handled;
    }

    char arg[PLATFORM_MAX_PATH];
    if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
        if (!LoadMatchConfig(arg)) {
            ReplyToCommand(client, "Failed to load match config.");
        }
    } else {
        ReplyToCommand(client, "Usage: get5_loadmatch <filename>");
    }

    return Plugin_Handled;
}

public Action Command_LoadMatchUrl(int client, int args) {
    if (g_GameState != GameState_None) {
        LogError("Cannot load a match config with another match already loaded");
        return Plugin_Handled;
    }

    bool steamWorksAvaliable = GetFeatureStatus(FeatureType_Native,
        "SteamWorks_CreateHTTPRequest") == FeatureStatus_Available;
    bool system2Avaliable = GetFeatureStatus(FeatureType_Native,
        "System2_DownloadFile") == FeatureStatus_Available;

    if (!steamWorksAvaliable && !system2Avaliable) {
        ReplyToCommand(client, "Cannot load matches from a url without the SteamWorks or system2 extension running");
    } else {
        char arg[PLATFORM_MAX_PATH];
        if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
            if (!LoadMatchFromUrl(arg)) {
                ReplyToCommand(client, "Failed to load match config.");
            }
        } else {
            ReplyToCommand(client, "Usage: get5_loadmatch_url <url>");
        }
    }

    return Plugin_Handled;
}


/***********************
 *                     *
 *       Events        *
 *                     *
 ***********************/

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_None && g_GameState < GameState_KnifeRound) {
        int client = GetClientOfUserId(event.GetInt("userid"));
        if (IsPlayer(client) && OnActiveTeam(client)) {
            SetEntProp(client, Prop_Send, "m_iAccount", GetCvarIntSafe("mp_maxmoney"));
        }
    }
}

public Action Event_MatchOver(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState == GameState_Live) {
        int t1score = CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1));
        int t2score = CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2));
        MatchTeam winningTeam = (t1score > t2score) ? MatchTeam_Team1 : MatchTeam_Team2;

        AddMapScore();
        if (winningTeam == MatchTeam_Team1) {
            g_TeamSeriesScores[MatchTeam_Team1]++;
        } else {
            g_TeamSeriesScores[MatchTeam_Team2]++;
        }

        char mapName[PLATFORM_MAX_PATH];
        GetCleanMapName(mapName, sizeof(mapName));

        Call_StartForward(g_hOnMapResult);
        Call_PushString(mapName);
        Call_PushCell(winningTeam);
        Call_PushCell(CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
        Call_PushCell(CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
        Call_Finish();

        float minDelay = FindConVar("tv_delay").FloatValue + MATCH_END_DELAY_AFTER_TV;
        if (g_TeamSeriesScores[MatchTeam_Team1] == g_MapsToWin) {
            SeriesWonMessage(MatchTeam_Team1);
            CreateTimer(minDelay, Timer_EndSeries);

        } else if (g_TeamSeriesScores[MatchTeam_Team2] == g_MapsToWin) {
            SeriesWonMessage(MatchTeam_Team2);
            CreateTimer(minDelay, Timer_EndSeries);

        } else {
            if (g_TeamSeriesScores[MatchTeam_Team1] > g_TeamSeriesScores[MatchTeam_Team2]) {
                Get5_MessageToAll("%s{NORMAL} is winning the series %d-%d",
                    g_FormattedTeamNames[MatchTeam_Team1],
                    g_TeamSeriesScores[MatchTeam_Team1],
                    g_TeamSeriesScores[MatchTeam_Team2]);

            } else if (g_TeamSeriesScores[MatchTeam_Team2] > g_TeamSeriesScores[MatchTeam_Team1]) {
                Get5_MessageToAll("%s {NORMAL}is winning the series %d-%d",
                    g_FormattedTeamNames[MatchTeam_Team2],
                    g_TeamSeriesScores[MatchTeam_Team2],
                    g_TeamSeriesScores[MatchTeam_Team1]);

            } else {
                Get5_MessageToAll("The series is tied at %d-%d",
                    g_TeamSeriesScores[MatchTeam_Team1],
                    g_TeamSeriesScores[MatchTeam_Team1]);
            }

            int index = g_TeamSeriesScores[MatchTeam_Team1] + g_TeamSeriesScores[MatchTeam_Team2];
            char nextMap[PLATFORM_MAX_PATH];
            g_MapsToPlay.GetString(index, nextMap, sizeof(nextMap));

            g_MapChangePending = true;
            Get5_MessageToAll("The next map in the series is {GREEN}%s", nextMap);
            ChangeState(GameState_PostGame);
            CreateTimer(minDelay, Timer_NextMatchMap);
        }
    }

    return Plugin_Continue;
}

static void SeriesWonMessage(MatchTeam team) {
    if (g_MapsToWin == 1) {
        Get5_MessageToAll("%s has won the match.", g_FormattedTeamNames[team]);
    } else {
        Get5_MessageToAll("%s has won the series %d-%d.",
            g_FormattedTeamNames[team],
            g_TeamSeriesScores[team],
            g_TeamSeriesScores[OtherMatchTeam(team)]);
    }
}

public Action Timer_NextMatchMap(Handle timer) {
    StopRecording();

    int index = GetMapNumber();
    char map[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(index, map, sizeof(map));
    ChangeMap(map);
}

public Action Timer_EndSeries(Handle timer) {
    ChangeState(GameState_None);
    if (g_KickClientsWithNoMatchCvar.IntValue != 0) {
        for (int i = 1; i <= MaxClients; i++) {
            if (IsPlayer(i)) {
                KickClient(i, "The match has been finished");
            }
        }
    }

    StopRecording();

    MatchTeam winningTeam  = MatchTeam_Team1;
    if (g_TeamSeriesScores[MatchTeam_Team2] > g_TeamSeriesScores[MatchTeam_Team1]) {
        winningTeam = MatchTeam_Team2;
    }

    Call_StartForward(g_hOnSeriesResult);
    Call_PushCell(winningTeam);
    Call_PushCell(g_TeamSeriesScores[MatchTeam_Team1]);
    Call_PushCell(g_TeamSeriesScores[MatchTeam_Team2]);
    Call_Finish();
}

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
    if (g_PendingSideSwap) {
        g_PendingSideSwap = false;
        SwapSides();
    }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState == GameState_KnifeRound) {
        ChangeState(GameState_WaitingForKnifeRoundDecision);

        int ctAlive = CountAlivePlayersOnTeam(CS_TEAM_CT);
        int tAlive = CountAlivePlayersOnTeam(CS_TEAM_T);
        int winningCSTeam = CS_TEAM_NONE;
        if (ctAlive > tAlive) {
            winningCSTeam = CS_TEAM_CT;
        } else if (tAlive > ctAlive) {
            winningCSTeam = CS_TEAM_T;
        } else {
            int ctHealth = SumHealthOfTeam(CS_TEAM_CT);
            int tHealth = SumHealthOfTeam(CS_TEAM_T);
            if (ctHealth > tHealth) {
                winningCSTeam = CS_TEAM_CT;
            } else if (tHealth > ctHealth) {
                winningCSTeam = CS_TEAM_T;
            } else {
                if (GetRandomFloat(0.0, 1.0) < 0.5) {
                    winningCSTeam = CS_TEAM_CT;
                } else {
                    winningCSTeam = CS_TEAM_T;
                }
            }
        }

        g_KnifeWinnerTeam = CSTeamToMatchTeam(winningCSTeam);
        Get5_MessageToAll("%s won the knife round. Waiting for them to type !stay or !swap.",
            g_FormattedTeamNames[g_KnifeWinnerTeam]);
    }

    if (g_GameState == GameState_Live) {
        int roundsPlayed = GameRules_GetProp("m_totalRoundsPlayed");
        LogDebug("m_totalRoundsPlayed = %d", roundsPlayed);

        int roundsPerHalf = GetCvarIntSafe("mp_maxrounds") / 2;
        int roundsPerOTHalf = GetCvarIntSafe("mp_overtime_maxrounds") / 2;

        // Regulation halftime. (after round 15)
        if (roundsPlayed == roundsPerHalf) {
            LogDebug("Pending regulation side swap");
            g_PendingSideSwap = true;
        }

        // Now in OT.
        if (roundsPlayed >= 2*roundsPerHalf) {
            int otround = roundsPlayed - 2*roundsPerHalf; // round 33 -> round 3, etc.
            // Do side swaps at OT halves (rounds 3, 9, ...)
            if (otround + roundsPerOTHalf % (2*roundsPerOTHalf) == 0) {
                LogDebug("Pending OT side swap");
                g_PendingSideSwap = true;
            }
        }
    }
}

public void SwapSides() {
    LogDebug("SwapSides");
    int tmp = g_TeamSide[MatchTeam_Team1];
    g_TeamSide[MatchTeam_Team1] = g_TeamSide[MatchTeam_Team2];
    g_TeamSide[MatchTeam_Team2] = tmp;
}

/**
 * Silences cvar changes when executing live/knife/warmup configs, *unless* it's sv_cheats.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_None) {
        char cvarName[MAX_CVAR_LENGTH];
        event.GetString("cvarname", cvarName, sizeof(cvarName));
        if (!StrEqual(cvarName, "sv_cheats")) {
            event.BroadcastDisabled = true;
        }
    }

    return Plugin_Continue;
}

public void StartGame(bool knifeRound) {
    if (!IsTVEnabled()) {
        LogError("GOTV demo could not be recorded since tv_enable is not set to 1");
    } else {
        // get the map, with any workshop stuff before removed
        // this is {MAP} in the format string
        char mapName[PLATFORM_MAX_PATH];
        GetCleanMapName(mapName, sizeof(mapName));

        // get the time, this is {TIME} in the format string
        char timeFormat[64];
        g_DemoTimeFormatCvar.GetString(timeFormat, sizeof(timeFormat));
        int timeStamp = GetTime();
        char formattedTime[64];
        FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

        // get the player count, this is {TEAMSIZE} in the format string
        char playerCount[MAX_INTEGER_STRING_LENGTH];
        IntToString(g_PlayersPerTeam, playerCount, sizeof(playerCount));

        // create the actual demo name to use
        char demoName[PLATFORM_MAX_PATH];
        g_DemoNameFormatCvar.GetString(demoName, sizeof(demoName));

        int mapNumber = g_TeamSeriesScores[MatchTeam_Team1] + g_TeamSeriesScores[MatchTeam_Team2] + 1;
        ReplaceStringWithInt(demoName, sizeof(demoName), "{MAPNUMBER}", mapNumber, false);
        ReplaceString(demoName, sizeof(demoName), "{MATCHID}", g_MatchID, false);
        ReplaceString(demoName, sizeof(demoName), "{MAPNAME}", mapName, false);
        ReplaceString(demoName, sizeof(demoName), "{TIME}", formattedTime, false);
        ReplaceString(demoName, sizeof(demoName), "{TEAM1}", g_TeamNames[MatchTeam_Team1], false);
        ReplaceString(demoName, sizeof(demoName), "{TEAM2}", g_TeamNames[MatchTeam_Team2], false);

        if (Record(demoName)) {
            LogMessage("Recording to %s", demoName);
            Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
        }
    }

    ExecCfg(g_LiveCfgCvar);

    if (knifeRound) {
        if (g_KnifeChangedCvars != INVALID_HANDLE)
            CloseCvarStorage(g_KnifeChangedCvars);
        g_KnifeChangedCvars = ExecuteAndSaveCvars(KNIFE_CONFIG);
        EndWarmup();
        CreateTimer(3.0, StartKnifeRound);
    } else {
        ChangeState(GameState_GoingLive);
        CreateTimer(3.0, BeginLO3, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action StopDemo(Handle timer) {
    StopRecording();
    return Plugin_Handled;
}

public void ChangeState(GameState state) {
    LogDebug("Change from state %d -> %d", g_GameState, state);
    g_GameState = state;
}

public Action Command_Status(int client, int args) {
    if (!LibraryExists("smjansson")) {
        ReplyToCommand(client, "get5_status requires the smjansson extension to be loaded");
        return Plugin_Handled;
    }

    Handle json = json_object();

    set_json_string(json, "matchid", g_MatchID);
    set_json_string(json, "plugin_version", PLUGIN_VERSION);

    #if defined COMMIT_STRING
    set_json_string(json, "commit", COMMIT_STRING);
    #endif

    char gamestate[64];
    GameStateString(g_GameState, gamestate, sizeof(gamestate));
    set_json_string(json, "gamestate", gamestate);

    if (g_GameState != GameState_None) {
        set_json_string(json, "loaded_config_file", g_LoadedConfigFile);
        set_json_int(json, "map_number", GetMapNumber() + 1);

        Handle team1 = json_object();
        AddTeamInfo(team1, MatchTeam_Team1);
        json_object_set(json, "team1", team1);
        CloseHandle(team1);

        Handle team2 = json_object();
        AddTeamInfo(team2, MatchTeam_Team2);
        json_object_set(json, "team2", team2);
        CloseHandle(team2);
    }

    if (g_GameState > GameState_Veto) {
        Handle maps = json_object();

        // Done backwards since the json keys are reported in a way such that
        // the last added is the first stored.
        for (int i = g_MapsToPlay.Length - 1; i >= 0; i--) {
            char mapKey[64];
            Format(mapKey, sizeof(mapKey), "map%d", i + 1);

            char mapName[PLATFORM_MAX_PATH];
            g_MapsToPlay.GetString(i, mapName, sizeof(mapName));

            set_json_string(maps, mapKey, mapName);
        }
        json_object_set(json, "maps", maps);
        CloseHandle(maps);
    }

    char buffer[4096];
    json_dump(json, buffer, sizeof(buffer));
    ReplyToCommand(client, buffer);
    CloseHandle(json);
    return Plugin_Handled;
}

static void AddTeamInfo(Handle json, MatchTeam matchTeam) {
    int team = MatchTeamToCSTeam(matchTeam);
    char side[4];
    CSTeamString(team, side, sizeof(side));
    set_json_string(json, "name", g_TeamNames[matchTeam]);
    set_json_int(json, "series_score", g_TeamSeriesScores[matchTeam]);
    set_json_int(json, "ready", g_TeamReady[matchTeam]);
    set_json_string(json, "side", side);
    set_json_int(json, "connected_clients", GetNumHumansOnTeam(team));
    set_json_int(json, "current_map_score", CS_GetTeamScore(team));
}

stock bool AllTeamsReady(bool includeSpec=true) {
    bool playersReady = g_TeamReady[MatchTeam_Team1] && g_TeamReady[MatchTeam_Team2];
    if (g_WaitForSpecReadyCvar.IntValue == 0 ||
        GetTeamAuths(MatchTeam_TeamSpec).Length == 0 ||
        !includeSpec) {
        return playersReady;
    } else {
        return playersReady && g_TeamReady[MatchTeam_TeamSpec];
    }
}
