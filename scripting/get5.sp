/**
 * =============================================================================
 * Get5
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

#include "include/get5.inc"
#include "include/logdebug.inc"
#include "include/restorecvars.inc"
#include <cstrike>
#include <sdktools>
#include <sourcemod>
#include <testing>

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>
#include <smjansson>
#include <system2>
#define REMOTE_CONFIG_FILENAME "remote.json"

#define CHECK_READY_TIMER_INTERVAL 1.0
#define INFO_MESSAGE_TIMER_INTERVAL 29.0

#define DEBUG_CVAR "get5_debug"
#define MATCH_ID_LENGTH 64
#define MAX_CVAR_LENGTH 128
#define MATCH_END_DELAY_AFTER_TV 10

#define TEAM1_COLOR "{LIGHT_GREEN}"
#define TEAM2_COLOR "{PINK}"
#define TEAM1_STARTING_SIDE CS_TEAM_CT
#define TEAM2_STARTING_SIDE CS_TEAM_T
#define KNIFE_CONFIG "get5/knife.cfg"

#pragma semicolon 1
#pragma newdecls required

/** ConVar handles **/
ConVar g_AutoLoadConfigCvar;
ConVar g_BackupSystemEnabledCvar;
ConVar g_CheckAuthsCvar;
ConVar g_DemoNameFormatCvar;
ConVar g_EventLogFormatCvar;
ConVar g_FixedPauseTimeCvar;
ConVar g_KickClientsWithNoMatchCvar;
ConVar g_LiveCfgCvar;
ConVar g_LiveCountdownTimeCvar;
ConVar g_MaxBackupAgeCvar;
ConVar g_MaxPausesCvar;
ConVar g_MaxPauseTimeCvar;
ConVar g_PausingEnabledCvar;
ConVar g_ResetPausesEachHalfCvar;
ConVar g_StatsPathFormatCvar;
ConVar g_StopCommandEnabledCvar;
ConVar g_TeamTimeToKnifeDecisionCvar;
ConVar g_TeamTimeToStartCvar;
ConVar g_TimeFormatCvar;
ConVar g_WarmupCfgCvar;

ConVar g_LastGet5BackupCvar;
ConVar g_VersionCvar;

// Hooked cvars built into csgo
ConVar g_CoachingEnabledCvar;

/** Series config game-state **/
int g_MapsToWin = 1;  // Maps needed to win the series
bool g_BO2Match = false;
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
int g_MinPlayersPerTeam = 4;
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

/** Backup data **/
bool g_WaitingForRoundBackup = false;
bool g_SavedValveBackup = false;
bool g_DoingBackupRestoreNow = false;

// Stats values
bool g_SetTeamClutching[4];
int g_RoundKills[MAXPLAYERS + 1];  // kills per round
int g_RoundClutchingEnemyCount[MAXPLAYERS +
                               1];  // number of enemies left alive when last alive on your team
int g_LastFlashBangThrower = -1;
int g_RoundFlashedBy[MAXPLAYERS + 1];
bool g_TeamFirstKillDone[MatchTeam_Count];
bool g_TeamFirstDeathDone[MatchTeam_Count];
KeyValues g_StatsKv;

ArrayList g_TeamScoresPerMap = null;
char g_LoadedConfigFile[PLATFORM_MAX_PATH];
int g_VetoCaptains[MatchTeam_Count];        // Clients doing the map vetos.
int g_TeamSeriesScores[MatchTeam_Count];    // Current number of maps won per-team.
bool g_TeamReadyOverride[MatchTeam_Count];  // Whether a team has been voluntarily force readied.
bool g_ClientReady[MAXPLAYERS + 1];         // Whether clients are marked ready.
int g_TeamSide[MatchTeam_Count];            // Current CS_TEAM_* side for the team.
int g_TeamStartingSide[MatchTeam_Count];
bool g_TeamReadyForUnpause[MatchTeam_Count];
bool g_TeamGivenStopCommand[MatchTeam_Count];
int g_TeamPauseTimeUsed[MatchTeam_Count];
int g_TeamPausesUsed[MatchTeam_Count];
int g_ReadyTimeWaitingUsed[MatchTeam_Count];
char g_DefaultTeamColors[][] = {
    TEAM1_COLOR, TEAM2_COLOR, "{NORMAL}", "{NORMAL}",
};

/** Map game-state **/
MatchTeam g_KnifeWinnerTeam = MatchTeam_TeamNone;

/** Map-game state not related to the actual gameplay. **/
char g_DemoFileName[PLATFORM_MAX_PATH];
bool g_MapChangePending = false;
bool g_MovingClientToCoach[MAXPLAYERS + 1];
bool g_PendingSideSwap = false;

Handle g_KnifeChangedCvars = INVALID_HANDLE;
Handle g_MatchConfigChangedCvars = INVALID_HANDLE;

/** Forwards **/
Handle g_OnBackupRestore = INVALID_HANDLE;
Handle g_OnDemoFinished = INVALID_HANDLE;
Handle g_OnGameStateChanged = INVALID_HANDLE;
Handle g_OnGoingLive = INVALID_HANDLE;
Handle g_OnLoadMatchConfigFailed = INVALID_HANDLE;
Handle g_OnMapPicked = INVALID_HANDLE;
Handle g_OnMapResult = INVALID_HANDLE;
Handle g_OnMapVetoed = INVALID_HANDLE;
Handle g_OnRoundStatsUpdated = INVALID_HANDLE;
Handle g_OnSeriesInit = INVALID_HANDLE;
Handle g_OnSeriesResult = INVALID_HANDLE;
Handle g_OnEvent = INVALID_HANDLE;

#include "get5/util.sp"

#include "get5/backups.sp"
#include "get5/eventlogger.sp"
#include "get5/goinglive.sp"
#include "get5/jsonhelpers.sp"
#include "get5/kniferounds.sp"
#include "get5/maps.sp"
#include "get5/mapveto.sp"
#include "get5/matchconfig.sp"
#include "get5/natives.sp"
#include "get5/pausing.sp"
#include "get5/readysystem.sp"
#include "get5/stats.sp"
#include "get5/teamlogic.sp"
#include "get5/tests.sp"
#include "get5/version.sp"

// clang-format off
public Plugin myinfo = {
  name = "Get5",
  author = "splewis",
  description = "",
  version = PLUGIN_VERSION,
  url = "https://github.com/splewis/get5"
};
// clang-format on

/**
 * Core SourceMod forwards,
 */

public void OnPluginStart() {
  InitDebugLog(DEBUG_CVAR, "get5");
  LogDebug("OnPluginStart version=%s", PLUGIN_VERSION);

  /** Translations **/
  LoadTranslations("get5.phrases");

  /** ConVars **/
  g_AutoLoadConfigCvar =
      CreateConVar("get5_autoload_config", "",
                   "Name of a match config file to automatically load when the server loads");
  g_BackupSystemEnabledCvar =
      CreateConVar("get5_backup_system_enabled", "1", "Whether the get5 backup system is enabled");
  g_CheckAuthsCvar =
      CreateConVar("get5_check_auths", "1",
                   "If set to 0, get5 will not force players to the correct team based on steamid");
  g_DemoNameFormatCvar = CreateConVar("get5_demo_name_format", "{MATCHID}_map{MAPNUMBER}_{MAPNAME}",
                                      "Format for demo file names, use \"\" to disable");
  g_EventLogFormatCvar =
      CreateConVar("get5_event_log_format", "logs/get5_match{MATCHID}_event_log.log",
                   "Path to use when writing match event logs, use \"\" to disable");
  g_FixedPauseTimeCvar =
      CreateConVar("get5_fixed_pause_time", "0",
                   "If set to non-zero, this will be the fixed length of any pause");
  g_KickClientsWithNoMatchCvar =
      CreateConVar("get5_kick_when_no_match_loaded", "1",
                   "Whether the plugin kicks new clients when no match is loaded");
  g_LiveCfgCvar =
      CreateConVar("get5_live_cfg", "get5/live.cfg", "Config file to exec when the game goes live");
  g_LiveCountdownTimeCvar = CreateConVar(
      "get5_live_countdown_time", "10",
      "Number of seconds used to count down when a match is going live", 0, true, 5.0, true, 60.0);
  g_MaxBackupAgeCvar =
      CreateConVar("get5_max_backup_age", "160000",
                   "Number of seconds before a backup file is automatically deleted, 0 to disable");
  g_MaxPausesCvar =
      CreateConVar("get5_max_pauses", "0", "Maximum number of pauses a team can use, 0=unlimited");
  g_MaxPauseTimeCvar =
      CreateConVar("get5_max_pause_time", "300",
                   "Maximum number of time the game can spend paused by a team, 0=unlimited");
  g_ResetPausesEachHalfCvar =
      CreateConVar("get5_reset_pauses_each_half", "1",
                   "Whether pause limits will be reset each halftime period");
  g_PausingEnabledCvar = CreateConVar("get5_pausing_enabled", "1", "Whether pausing is allowed.");
  g_StatsPathFormatCvar =
      CreateConVar("get5_stats_path_format", "get5_matchstats_{MATCHID}.cfg",
                   "Where match stats are saved (updated each map end), set to \"\" to disable");
  g_StopCommandEnabledCvar =
      CreateConVar("get5_stop_command_enabled", "1",
                   "Whether clients can use the !stop command to restore to the last round");
  g_TeamTimeToStartCvar = CreateConVar(
      "get5_time_to_start", "0",
      "Time (in seconds) teams have to ready up before forfeiting the match, 0=unlimited");
  g_TeamTimeToKnifeDecisionCvar = CreateConVar(
      "get5_time_to_make_knife_decision", "60",
      "Time (in seconds) a team has to make a !stay/!swap decision after winning knife round, 0=unlimited");
  g_TimeFormatCvar = CreateConVar(
      "get5_time_format", "%Y-%m-%d_%H",
      "Time format to use when creating file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
  g_WarmupCfgCvar =
      CreateConVar("get5_warmup_cfg", "get5/warmup.cfg", "Config file to exec in warmup periods");

  /** Create and exec plugin's configuration file **/
  AutoExecConfig(true, "get5");

  g_LastGet5BackupCvar =
      CreateConVar("get5_last_backup_file", "", "Last get5 backup file written", FCVAR_DONTRECORD);
  g_VersionCvar = CreateConVar("get5_version", PLUGIN_VERSION, "Current get5 version",
                               FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  g_VersionCvar.SetString(PLUGIN_VERSION);

  g_CoachingEnabledCvar = FindConVar("sv_coaching_enabled");

  /** Client commands **/
  RegConsoleCmd("sm_ready", Command_Ready, "Marks the client as ready");
  RegConsoleCmd("sm_unready", Command_NotReady, "Marks the client as not ready");
  RegConsoleCmd("sm_notready", Command_NotReady, "Marks the client as not ready");
  RegConsoleCmd("sm_forceready", Command_ForceReadyClient, "Force marks clients team as ready");
  RegConsoleCmd("sm_pause", Command_Pause, "Pauses the game");
  RegConsoleCmd("sm_unpause", Command_Unpause, "Unpauses the game");
  RegConsoleCmd("sm_coach", Command_SmCoach, "Marks a client as a coach for their team");
  RegConsoleCmd("sm_stay", Command_Stay,
                "Elects to stay on the current team after winning a knife round");
  RegConsoleCmd("sm_swap", Command_Swap,
                "Elects to swap the current teams after winning a knife round");
  RegConsoleCmd("sm_t", Command_T, "Elects to start on T side after winning a knife round");
  RegConsoleCmd("sm_ct", Command_Ct, "Elects to start on CT side after winning a knife round");
  RegConsoleCmd("sm_stop", Command_Stop, "Elects to stop the game to reload a backup file");

  /** Admin/server commands **/
  RegAdminCmd(
      "get5_loadmatch", Command_LoadMatch, ADMFLAG_CHANGEMAP,
      "Loads a match config file (json or keyvalues) from a file relative to the csgo/ directory");
  RegAdminCmd(
      "get5_loadmatch_url", Command_LoadMatchUrl, ADMFLAG_CHANGEMAP,
      "Loads a JSON config file by sending a GET request to download it. Requires either the SteamWorks or system2 extensions");
  RegAdminCmd("get5_loadteam", Command_LoadTeam, ADMFLAG_CHANGEMAP,
              "Loads a team data from a file into a team");
  RegAdminCmd("get5_endmatch", Command_EndMatch, ADMFLAG_CHANGEMAP, "Force ends the current match");
  RegAdminCmd("get5_addplayer", Command_AddPlayer, ADMFLAG_CHANGEMAP,
              "Adds a steamid to a match team");
  RegAdminCmd("get5_removeplayer", Command_RemovePlayer, ADMFLAG_CHANGEMAP,
              "Removes a steamid from a match team");
  RegAdminCmd("get5_creatematch", Command_CreateMatch, ADMFLAG_CHANGEMAP,
              "Creates and loads a match using the players currently on the server as a Bo1");
  RegAdminCmd("get5_scrim", Command_CreateScrim, ADMFLAG_CHANGEMAP,
              "Creates and loads a match using the players currently on the server as a Bo1");
  RegAdminCmd("get5_forceready", Command_AdminForceReady, ADMFLAG_CHANGEMAP,
              "Force readies all current teams");
  RegAdminCmd("get5_dumpstats", Command_DumpStats, ADMFLAG_CHANGEMAP,
              "Dumps match stats to a file");
  RegAdminCmd("get5_listbackups", Command_ListBackups, ADMFLAG_CHANGEMAP,
              "Lists get5 match backups for the current matchid or a given one");
  RegAdminCmd("get5_loadbackup", Command_LoadBackup, ADMFLAG_CHANGEMAP,
              "Loads a get5 match backup");

  /** Other commands **/
  RegConsoleCmd("get5_status", Command_Status, "Prints JSON formatted match state info");
  RegServerCmd(
      "get5_test", Command_Test,
      "Runs get5 tests - should not be used on a live match server since it will reload a match config to test");

  /** Hooks **/
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("cs_win_panel_match", Event_MatchOver);
  HookEvent("round_prestart", Event_RoundPreStart);
  HookEvent("round_freeze_end", Event_FreezeEnd);
  HookEvent("round_end", Event_RoundEnd);
  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);
  HookEvent("player_connect_full", Event_PlayerConnectFull);
  HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
  Stats_PluginStart();
  Stats_InitSeries();

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
  g_OnBackupRestore = CreateGlobalForward("Get5_OnBackupRestore", ET_Ignore);
  g_OnDemoFinished = CreateGlobalForward("Get5_OnDemoFinished", ET_Ignore, Param_String);
  g_OnGameStateChanged =
      CreateGlobalForward("Get5_OnGameStateChanged", ET_Ignore, Param_Cell, Param_Cell);
  g_OnGoingLive = CreateGlobalForward("Get5_OnGoingLive", ET_Ignore, Param_Cell);
  g_OnMapResult = CreateGlobalForward("Get5_OnMapResult", ET_Ignore, Param_String, Param_Cell,
                                      Param_Cell, Param_Cell, Param_Cell);
  g_OnLoadMatchConfigFailed =
      CreateGlobalForward("Get5_OnLoadMatchConfigFailed", ET_Ignore, Param_String);
  g_OnMapPicked = CreateGlobalForward("Get5_OnMapPicked", ET_Ignore, Param_Cell, Param_String);
  g_OnMapVetoed = CreateGlobalForward("Get5_OnMapVetoed", ET_Ignore, Param_Cell, Param_String);
  g_OnRoundStatsUpdated = CreateGlobalForward("Get5_OnRoundStatsUpdated", ET_Ignore);
  g_OnSeriesInit = CreateGlobalForward("Get5_OnSeriesInit", ET_Ignore);
  g_OnSeriesResult =
      CreateGlobalForward("Get5_OnSeriesResult", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
  g_OnEvent = CreateGlobalForward("Get5_OnEvent", ET_Ignore, Param_String);

  /** Start any repeating timers **/
  CreateTimer(CHECK_READY_TIMER_INTERVAL, Timer_CheckReady, _, TIMER_REPEAT);
  CreateTimer(INFO_MESSAGE_TIMER_INTERVAL, Timer_InfoMessages, _, TIMER_REPEAT);
}

public Action Timer_InfoMessages(Handle timer) {
  if (g_GameState == GameState_PreVeto) {
    Get5_MessageToAll("%t", "ReadyToVetoInfoMessage");
    MissingPlayerInfoMessage();

  } else if (g_GameState == GameState_Warmup && !g_MapChangePending) {
    if (AllTeamsReady(false) && !AllTeamsReady(true)) {
      Get5_MessageToAll("%t", "WaitingForCastersReadyInfoMessage");
      MissingPlayerInfoMessage();

    } else {
      SideChoice sides = view_as<SideChoice>(g_MapSides.Get(GetMapNumber()));
      if (g_WaitingForRoundBackup) {
        Get5_MessageToAll("%t", "ReadyToRestoreBackupInfoMessage");
      } else if (sides == SideChoice_KnifeRound) {
        Get5_MessageToAll("%t", "ReadyToKnifeInfoMessage");
        MissingPlayerInfoMessage();
      } else {
        Get5_MessageToAll("%t", "ReadyToStartInfoMessage");
        MissingPlayerInfoMessage();
      }
    }

  } else if (g_GameState == GameState_WaitingForKnifeRoundDecision) {
    Get5_MessageToAll("%t", "WaitingForEnemySwapInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);

  } else if (g_GameState == GameState_PostGame) {
    Get5_MessageToAll("%t", "WaitingForGOTVBrodcastEndingInfoMessage");
  }
}

public void OnClientAuthorized(int client, const char[] auth) {
  g_ClientReady[client] = false;
  g_MovingClientToCoach[client] = false;
  if (StrEqual(auth, "BOT", false)) {
    return;
  }

  if (g_GameState == GameState_None && g_KickClientsWithNoMatchCvar.IntValue != 0) {
    KickClient(client, "%t", "NoMatchSetupInfoMessage");
  }

  if (g_GameState != GameState_None && g_CheckAuthsCvar.IntValue != 0) {
    MatchTeam team = GetClientMatchTeam(client);
    if (team == MatchTeam_TeamNone) {
      KickClient(client, "%t", "YourAreNotAPlayerInfoMessage");
    } else {
      int teamCount = CountPlayersOnMatchTeam(team, client);
      if (teamCount >= g_PlayersPerTeam && g_CoachingEnabledCvar.IntValue == 0) {
        KickClient(client, "%t", "TeamIsFullInfoMessage");
      }
    }
  }
}

public void OnClientPutInServer(int client) {
  if (IsFakeClient(client)) {
    return;
  }

  CheckAutoLoadConfig();
  if (g_GameState <= GameState_Warmup && g_GameState != GameState_None) {
    if (GetRealClientCount() <= 1) {
      ExecCfg(g_WarmupCfgCvar);
      EnsurePausedWarmup();
    }
  }

  Stats_ResetClientRoundValues(client);
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (StrEqual(command, "say")) {
    EventLogger_ClientSay(client, sArgs);
  }
}

/**
 * Full connect event right when a player joins.
 * This sets the auto-pick time to a high value because mp_forcepicktime is broken and
 * if a player does not select a team but leaves their mouse over one, they are
 * put on that team and spawned, so we can't allow that.
 */
public Action Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (client > 0) {
    SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
  }
}

public void OnMapStart() {
  g_MapChangePending = false;
  DeleteOldBackups();

  ResetReadyStatus();
  LOOP_TEAMS(team) {
    g_TeamGivenStopCommand[team] = false;
    g_TeamReadyForUnpause[team] = false;
    g_TeamPauseTimeUsed[team] = 0;
    g_TeamPausesUsed[team] = 0;
    g_ReadyTimeWaitingUsed[team] = 0;
  }

  if (g_WaitingForRoundBackup) {
    ChangeState(GameState_Warmup);
    ExecCfg(g_LiveCfgCvar);
    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();
    EnsurePausedWarmup();

  } else {
    SetStartingTeams();
    CheckAutoLoadConfig();

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
}

public Action Timer_CheckReady(Handle timer) {
  CheckTeamNameStatus(MatchTeam_Team1);
  CheckTeamNameStatus(MatchTeam_Team2);

  if (g_GameState == GameState_PreVeto) {
    if (AllTeamsReady(false)) {
      ChangeState(GameState_Veto);
      CreateMapVeto();
    } else {
      CheckReadyWaitingTimes();
    }

  } else if (g_GameState == GameState_Warmup) {
    if (AllTeamsReady(true) && !g_MapChangePending) {
      int mapNumber = GetMapNumber();
      if (g_WaitingForRoundBackup) {
        g_WaitingForRoundBackup = false;
        RestoreGet5Backup();

      } else if (g_MapSides.Get(mapNumber) == SideChoice_KnifeRound) {
        ChangeState(GameState_KnifeRound);
        StartGame(true);

      } else {
        StartGame(false);
      }
    } else {
      CheckReadyWaitingTimes();
    }
  }

  UpdateClanTags();

  return Plugin_Continue;
}

static void CheckReadyWaitingTimes() {
  if (g_TeamTimeToStartCvar.IntValue > 0) {
    CheckReadyWaitingTime(MatchTeam_Team1);
    CheckReadyWaitingTime(MatchTeam_Team2);
  }
}

static void CheckReadyWaitingTime(MatchTeam team) {
  if (!IsTeamReady(team) && g_GameState != GameState_None) {
    g_ReadyTimeWaitingUsed[team]++;
    int timeLeft = g_TeamTimeToStartCvar.IntValue - g_ReadyTimeWaitingUsed[team];

    if (timeLeft <= 0) {
      Get5_MessageToAll("%t", "TeamForfeitInfoMessage", g_FormattedTeamNames[team]);
      ChangeState(GameState_None);
      Stats_Forfeit(team);
      EndSeries();

    } else if (timeLeft >= 300 && timeLeft % 60 == 0) {
      Get5_MessageToAll("%t", "MinutesToForfeitMessage", g_FormattedTeamNames[team], timeLeft / 60);

    } else if (timeLeft < 300 && timeLeft % 30 == 0) {
      Get5_MessageToAll("%t", "SecondsToForfeitInfoMessage", g_FormattedTeamNames[team], timeLeft);

    } else if (timeLeft == 10) {
      Get5_MessageToAll("%t", "10SecondsToForfeitInfoMessage", g_FormattedTeamNames[team],
                        timeLeft);
    }
  }
}

static void CheckAutoLoadConfig() {
  if (g_GameState == GameState_None) {
    char autoloadConfig[PLATFORM_MAX_PATH];
    g_AutoLoadConfigCvar.GetString(autoloadConfig, sizeof(autoloadConfig));
    if (!StrEqual(autoloadConfig, "")) {
      LoadMatchConfig(autoloadConfig);
    }
  }
}

/**
 * Client and server commands.
 */

public Action Command_EndMatch(int client, int args) {
  if (g_GameState == GameState_None) {
    return Plugin_Handled;
  }
  ChangeState(GameState_None);

  Get5_MessageToAll("%t", "AdminForceEndInfoMessage");
  RestoreCvars(g_MatchConfigChangedCvars);

  return Plugin_Handled;
}

public Action Command_LoadMatch(int client, int args) {
  if (g_GameState != GameState_None) {
    ReplyToCommand(client, "Cannot load a match when a match is already loaded");
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
    ReplyToCommand(client, "Cannot load a match config with another match already loaded");
    return Plugin_Handled;
  }

  bool steamWorksAvaliable = LibraryExists("SteamWorks");
  bool system2Avaliable = LibraryExists("system2");

  if (!steamWorksAvaliable && !system2Avaliable) {
    ReplyToCommand(
        client,
        "Cannot load matches from a url without the SteamWorks or system2 extension running");
  } else {
    char arg[PLATFORM_MAX_PATH];
    if (args >= 1 && GetCmdArgString(arg, sizeof(arg))) {
      if (!LoadMatchFromUrl(arg)) {
        ReplyToCommand(client, "Failed to load match config.");
      }
    } else {
      ReplyToCommand(client, "Usage: get5_loadmatch_url <url>");
    }
  }

  return Plugin_Handled;
}

public Action Command_DumpStats(int client, int args) {
  if (g_GameState == GameState_None) {
    ReplyToCommand(client, "Cannot dump match stats with no match existing");
    return Plugin_Handled;
  }

  char arg[PLATFORM_MAX_PATH];
  if (args < 1) {
    arg = "get5_matchstats.cfg";
  } else {
    GetCmdArg(1, arg, sizeof(arg));
  }

  if (g_StatsKv.ExportToFile(arg)) {
    g_StatsKv.Rewind();
    ReplyToCommand(client, "Saved match stats to %s", arg);
  } else {
    ReplyToCommand(client, "Failed to save match stats to %s", arg);
  }

  return Plugin_Handled;
}

public Action Command_Stop(int client, int args) {
  if (g_StopCommandEnabledCvar.IntValue == 0) {
    return Plugin_Handled;
  }

  if (g_GameState != GameState_Live || g_PendingSideSwap == true) {
    return Plugin_Handled;
  }

  // Let the server/rcon always force restore.
  if (client == 0) {
    RestoreLastRound();
  }

  MatchTeam team = GetClientMatchTeam(client);
  g_TeamGivenStopCommand[team] = true;

  if (g_TeamGivenStopCommand[MatchTeam_Team1] && !g_TeamGivenStopCommand[MatchTeam_Team2]) {
    Get5_MessageToAll("%t", "TeamWantsToReloadLastRoundInfoMessage",
                      g_FormattedTeamNames[MatchTeam_Team1], g_FormattedTeamNames[MatchTeam_Team2]);
  } else if (!g_TeamGivenStopCommand[MatchTeam_Team1] && g_TeamGivenStopCommand[MatchTeam_Team2]) {
    Get5_MessageToAll("%t", "TeamWantsToReloadLastRoundInfoMessage",
                      g_FormattedTeamNames[MatchTeam_Team2], g_FormattedTeamNames[MatchTeam_Team1]);
  } else if (g_TeamGivenStopCommand[MatchTeam_Team1] && g_TeamGivenStopCommand[MatchTeam_Team2]) {
    RestoreLastRound();
  }

  return Plugin_Handled;
}

static bool RestoreLastRound() {
  LOOP_TEAMS(x) {
    g_TeamGivenStopCommand[x] = false;
  }

  char lastBackup[PLATFORM_MAX_PATH];
  g_LastGet5BackupCvar.GetString(lastBackup, sizeof(lastBackup));
  if (!StrEqual(lastBackup, "")) {
    ServerCommand("get5_loadbackup \"%s\"", lastBackup);
    return true;
  }
  return false;
}

/**
 * Game Events *not* related to the stats tracking system.
 */

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
    Stats_UpdateMapScore(winningTeam);

    AddMapScore();
    g_TeamSeriesScores[winningTeam]++;

    g_MapChangePending = true;
    WriteBackup();

    EventLogger_MapEnd(winningTeam);

    char mapName[PLATFORM_MAX_PATH];
    GetCleanMapName(mapName, sizeof(mapName));

    Call_StartForward(g_OnMapResult);
    Call_PushString(mapName);
    Call_PushCell(winningTeam);
    Call_PushCell(CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
    Call_PushCell(CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
    Call_PushCell(GetMapNumber() - 1);
    Call_Finish();

    float minDelay = FindConVar("tv_delay").FloatValue + MATCH_END_DELAY_AFTER_TV;
    if (g_TeamSeriesScores[MatchTeam_Team1] == g_MapsToWin) {
      SeriesWonMessage(MatchTeam_Team1);
      DelayFunction(minDelay, EndSeries);

    } else if (g_TeamSeriesScores[MatchTeam_Team2] == g_MapsToWin) {
      SeriesWonMessage(MatchTeam_Team2);
      DelayFunction(minDelay, EndSeries);

    } else if (g_BO2Match && GetMapNumber() == 2) {
      SeriesWonMessage(MatchTeam_TeamNone);
      DelayFunction(minDelay, EndSeries);

    } else {
      if (g_TeamSeriesScores[MatchTeam_Team1] > g_TeamSeriesScores[MatchTeam_Team2]) {
        Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage",
                          g_FormattedTeamNames[MatchTeam_Team1],
                          g_TeamSeriesScores[MatchTeam_Team1], g_TeamSeriesScores[MatchTeam_Team2]);

      } else if (g_TeamSeriesScores[MatchTeam_Team2] > g_TeamSeriesScores[MatchTeam_Team1]) {
        Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage",
                          g_FormattedTeamNames[MatchTeam_Team2],
                          g_TeamSeriesScores[MatchTeam_Team2], g_TeamSeriesScores[MatchTeam_Team1]);

      } else {
        Get5_MessageToAll("%t", "SeriesTiedInfoMessage", g_TeamSeriesScores[MatchTeam_Team1],
                          g_TeamSeriesScores[MatchTeam_Team1]);
      }

      int index = g_TeamSeriesScores[MatchTeam_Team1] + g_TeamSeriesScores[MatchTeam_Team2];
      char nextMap[PLATFORM_MAX_PATH];
      g_MapsToPlay.GetString(index, nextMap, sizeof(nextMap));

      g_MapChangePending = true;
      Get5_MessageToAll("%t", "NextSeriesMapInfoMessage", nextMap);
      ChangeState(GameState_PostGame);
      CreateTimer(minDelay, Timer_NextMatchMap);
    }
  }

  return Plugin_Continue;
}

static void SeriesWonMessage(MatchTeam team) {
  if (g_MapsToWin == 1) {
    Get5_MessageToAll("%t", "TeamWonMatchInfoMessage", g_FormattedTeamNames[team]);
  } else {
    if (team == MatchTeam_TeamNone) {
      // BO2 split.
      Get5_MessageToAll("%t", "TeamsSplitSeriesBO2InfoMessage",
                        g_FormattedTeamNames[MatchTeam_Team1],
                        g_FormattedTeamNames[MatchTeam_Team2]);

    } else {
      Get5_MessageToAll("%t", "TeamWonSeriesInfoMessage", g_FormattedTeamNames[team],
                        g_TeamSeriesScores[team], g_TeamSeriesScores[OtherMatchTeam(team)]);
    }
  }
}

public Action Timer_NextMatchMap(Handle timer) {
  if (g_GameState >= GameState_Live)
    StopRecording();

  int index = GetMapNumber();
  char map[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(index, map, sizeof(map));
  ChangeMap(map);
}

public void KickClientsOnEnd() {
  if (g_KickClientsWithNoMatchCvar.IntValue != 0) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i)) {
        KickClient(i, "%t", "MatchFinishedInfoMessage");
      }
    }
  }
}

public void EndSeries() {
  DelayFunction(10.0, KickClientsOnEnd);
  StopRecording();

  MatchTeam winningTeam = MatchTeam_Team1;
  if (g_TeamSeriesScores[MatchTeam_Team2] > g_TeamSeriesScores[MatchTeam_Team1]) {
    winningTeam = MatchTeam_Team2;
  } else if (g_TeamSeriesScores[MatchTeam_Team1] == g_TeamSeriesScores[MatchTeam_Team2]) {
    winningTeam = MatchTeam_TeamNone;
  }

  Stats_SeriesEnd(winningTeam);
  EventLogger_SeriesEnd(winningTeam, g_TeamSeriesScores[MatchTeam_Team1],
                        g_TeamSeriesScores[MatchTeam_Team2]);

  Call_StartForward(g_OnSeriesResult);
  Call_PushCell(winningTeam);
  Call_PushCell(g_TeamSeriesScores[MatchTeam_Team1]);
  Call_PushCell(g_TeamSeriesScores[MatchTeam_Team2]);
  Call_Finish();

  RestoreCvars(g_MatchConfigChangedCvars);
  ChangeState(GameState_None);
}

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
  if (g_PendingSideSwap) {
    g_PendingSideSwap = false;
    SwapSides();
  }

  if (g_GameState == GameState_GoingLive) {
    ChangeState(GameState_Live);
  }

  Stats_ResetRoundValues();

  if (g_GameState >= GameState_Warmup && !g_DoingBackupRestoreNow) {
    WriteBackup();
  }
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState == GameState_Live) {
    Stats_RoundStart();
  }
}

public void WriteBackup() {
  if (g_BackupSystemEnabledCvar.IntValue == 0) {
    return;
  }

  char path[PLATFORM_MAX_PATH];
  if (g_GameState == GameState_Live) {
    Format(path, sizeof(path), "get5_backup_match%s_map%d_round%d.cfg", g_MatchID,
           GetMapStatsNumber(), GameRules_GetProp("m_totalRoundsPlayed"));
  } else {
    Format(path, sizeof(path), "get5_backup_match%s_map%d_prelive.cfg", g_MatchID,
           GetMapStatsNumber());
  }
  LogDebug("created path %s", path);

  if (!g_DoingBackupRestoreNow) {
    LogDebug("writing to %s", path);
    WriteBackStructure(path);
    g_LastGet5BackupCvar.SetString(path);
  }
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_DoingBackupRestoreNow)
    return;

  if (g_GameState == GameState_KnifeRound) {
    ChangeState(GameState_WaitingForKnifeRoundDecision);
    CreateTimer(1.0, Timer_PostKnife);

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
    Get5_MessageToAll("%t", "WaitingForEnemySwapInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam]);

    if (g_TeamTimeToKnifeDecisionCvar.FloatValue > 0)
      CreateTimer(g_TeamTimeToKnifeDecisionCvar.FloatValue, Timer_ForceKnifeDecision);
  }

  if (g_GameState == GameState_Live) {
    int csTeamWinner = event.GetInt("winner");

    Get5_MessageToAll("%t", "CurrentScoreInfoMessage", g_TeamNames[MatchTeam_Team1],
                      CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)),
                      CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)),
                      g_TeamNames[MatchTeam_Team2]);

    Stats_RoundEnd(csTeamWinner);
    Call_StartForward(g_OnRoundStatsUpdated);
    Call_Finish();

    EventLogger_RoundEnd(csTeamWinner);

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
    if (roundsPlayed >= 2 * roundsPerHalf) {
      int otround = roundsPlayed - 2 * roundsPerHalf;  // round 33 -> round 3, etc.
      // Do side swaps at OT halves (rounds 3, 9, ...)
      if ((otround + roundsPerOTHalf) % (2 * roundsPerOTHalf) == 0) {
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

  if (g_ResetPausesEachHalfCvar.IntValue != 0) {
    LOOP_TEAMS(team) {
      g_TeamPauseTimeUsed[team] = 0;
      g_TeamPausesUsed[team] = 0;
    }
  }
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
    char demoName[PLATFORM_MAX_PATH + 1];
    if (FormatCvarString(g_DemoNameFormatCvar, demoName, sizeof(demoName)) && Record(demoName)) {
      Format(g_DemoFileName, sizeof(g_DemoFileName), "%s.dem", demoName);
      LogMessage("Recording to %s", g_DemoFileName);
    } else {
      Format(g_DemoFileName, sizeof(g_DemoFileName), "");
    }
  }

  ExecCfg(g_LiveCfgCvar);

  if (knifeRound) {
    if (g_KnifeChangedCvars != INVALID_HANDLE)
      CloseCvarStorage(g_KnifeChangedCvars);
    g_KnifeChangedCvars = ExecuteAndSaveCvars(KNIFE_CONFIG);
    CreateTimer(1.0, StartKnifeRound);
  } else {
    ChangeState(GameState_GoingLive);
    CreateTimer(3.0, StartGoingLive, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action Timer_PostKnife(Handle timer) {
  if (g_KnifeChangedCvars != INVALID_HANDLE)
    RestoreCvars(g_KnifeChangedCvars, true);

  ExecCfg(g_WarmupCfgCvar);
  EnsurePausedWarmup();
}

public Action StopDemo(Handle timer) {
  StopRecording();
  return Plugin_Handled;
}

public void ChangeState(GameState state) {
  LogDebug("Change from state %d -> %d", g_GameState, state);
  Call_StartForward(g_OnGameStateChanged);
  Call_PushCell(g_GameState);
  Call_PushCell(state);
  Call_Finish();
  g_GameState = state;
}

public Action Command_Status(int client, int args) {
  if (!LibraryExists("jansson")) {
    ReplyToCommand(client, "get5_status requires the smjansson extension to be loaded");
    return Plugin_Handled;
  }

  Handle json = json_object();

  set_json_string(json, "matchid", g_MatchID);
  set_json_string(json, "plugin_version", PLUGIN_VERSION);

#if defined COMMIT_STRING
  set_json_string(json, "commit", COMMIT_STRING);
#endif

  set_json_int(json, "gamestate", view_as<int>(g_GameState));
  set_json_bool(json, "paused", IsPaused());

  char gamestate[64];
  GameStateString(g_GameState, gamestate, sizeof(gamestate));
  set_json_string(json, "gamestate_string", gamestate);

  if (g_GameState != GameState_None) {
    set_json_string(json, "loaded_config_file", g_LoadedConfigFile);
    set_json_int(json, "map_number", GetMapNumber());

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

    for (int i = 0; i < g_MapsToPlay.Length; i++) {
      char mapKey[64];
      Format(mapKey, sizeof(mapKey), "map%d", i);

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
  set_json_int(json, "ready", IsTeamReady(matchTeam));
  set_json_string(json, "side", side);
  set_json_int(json, "connected_clients", GetNumHumansOnTeam(team));
  set_json_int(json, "current_map_score", CS_GetTeamScore(team));
}

public bool FormatCvarString(ConVar cvar, char[] buffer, int len) {
  cvar.GetString(buffer, len);
  if (StrEqual(buffer, "")) {
    return false;
  }

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));

  // Get the time, this is {TIME} in the format string.
  char timeFormat[64];
  g_TimeFormatCvar.GetString(timeFormat, sizeof(timeFormat));
  int timeStamp = GetTime();
  char formattedTime[64];
  FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);

  // Get team names with spaces removed.
  char team1Str[MAX_CVAR_LENGTH];
  strcopy(team1Str, sizeof(team1Str), g_TeamNames[MatchTeam_Team1]);
  ReplaceString(team1Str, sizeof(team1Str), " ", "_");

  char team2Str[MAX_CVAR_LENGTH];
  strcopy(team2Str, sizeof(team2Str), g_TeamNames[MatchTeam_Team2]);
  ReplaceString(team2Str, sizeof(team2Str), " ", "_");

  int mapNumber = g_TeamSeriesScores[MatchTeam_Team1] + g_TeamSeriesScores[MatchTeam_Team2] + 1;
  ReplaceStringWithInt(buffer, len, "{MAPNUMBER}", mapNumber, false);
  ReplaceString(buffer, len, "{MATCHID}", g_MatchID, false);
  ReplaceString(buffer, len, "{MAPNAME}", mapName, false);
  ReplaceString(buffer, len, "{TIME}", formattedTime, false);
  ReplaceString(buffer, len, "{TEAM1}", team1Str, false);
  ReplaceString(buffer, len, "{TEAM2}", team2Str, false);

  return true;
}
