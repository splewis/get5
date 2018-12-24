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
#include <json>  // github.com/clugg/sm-json
#include <sdktools>
#include <sourcemod>
#include <testing>

#undef REQUIRE_EXTENSIONS
#include <SteamWorks>

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
#define DEFAULT_TAG "[{YELLOW}Get5{NORMAL}]"

#pragma semicolon 1
#pragma newdecls required

/** ConVar handles **/
ConVar g_AllowTechPauseCvar;
ConVar g_AutoLoadConfigCvar;
ConVar g_BackupSystemEnabledCvar;
ConVar g_CheckAuthsCvar;
ConVar g_DamagePrintCvar;
ConVar g_DamagePrintFormat;
ConVar g_DemoNameFormatCvar;
ConVar g_DisplayGotvVeto;
ConVar g_EndMatchOnEmptyServerCvar;
ConVar g_EventLogFormatCvar;
ConVar g_FixedPauseTimeCvar;
ConVar g_KickClientImmunity;
ConVar g_KickClientsWithNoMatchCvar;
ConVar g_LiveCfgCvar;
ConVar g_LiveCountdownTimeCvar;
ConVar g_MaxBackupAgeCvar;
ConVar g_MaxPausesCvar;
ConVar g_MaxPauseTimeCvar;
ConVar g_MessagePrefixCvar;
ConVar g_PausingEnabledCvar;
ConVar g_ResetPausesEachHalfCvar;
ConVar g_ServerIdCvar;
ConVar g_SetClientClanTagCvar;
ConVar g_SetHostnameCvar;
ConVar g_StatsPathFormatCvar;
ConVar g_StopCommandEnabledCvar;
ConVar g_TeamTimeToKnifeDecisionCvar;
ConVar g_TeamTimeToStartCvar;
ConVar g_TimeFormatCvar;
ConVar g_VetoConfirmationTimeCvar;
ConVar g_VetoCountdownCvar;
ConVar g_WarmupCfgCvar;

// Autoset convars (not meant for users to set)
ConVar g_GameStateCvar;
ConVar g_LastGet5BackupCvar;
ConVar g_VersionCvar;

// Hooked cvars built into csgo
ConVar g_CoachingEnabledCvar;

// clang-format off
/** Series config game-state **/
int g_MapsToWin = 1;  // Maps needed to win the series.
bool g_BO2Match = false;
char g_MatchID[MATCH_ID_LENGTH];
ArrayList g_MapPoolList = null;
ArrayList g_TeamAuths[MatchTeam_Count];
StringMap g_PlayerNames;

enum struct TeamConfig {
  char name[MAX_CVAR_LENGTH]; 
  char formatted_name[MAX_CVAR_LENGTH]; 
  char tag[MAX_CVAR_LENGTH];
  char flag[MAX_CVAR_LENGTH];
  char logo[MAX_CVAR_LENGTH];
  char match_text[MAX_CVAR_LENGTH];
}
TeamConfig g_TeamConfig[MatchTeam_Count];

enum struct MatchConfig {
  char title[MAX_CVAR_LENGTH];
  int favored_team_percentage;
  char favored_team_text[MAX_CVAR_LENGTH];
  int players_per_team;
  int min_spectators_to_ready;
  int min_players_to_ready;
  bool skip_veto;
  // float veto_menu_time;
  MatchSideType side_type;
  ArrayList cvar_values;
  ArrayList cvar_names;
  bool scrim_mode;
};
MatchConfig g_MatchConfig;

float g_VetoMenuTime = 0.0;
bool g_HasKnifeRoundStarted = false;

/** Other state **/
Get5State g_GameState = Get5State_None;
ArrayList g_MapsToPlay = null;
ArrayList g_MapSides = null;
ArrayList g_MapsLeftInVetoPool = null;
MatchTeam g_LastVetoTeam;
Menu g_ActiveVetoMenu = null;

/** Backup data **/
bool g_WaitingForRoundBackup = false;
bool g_SavedValveBackup = false;
bool g_DoingBackupRestoreNow = false;

// Stats values
bool g_SetTeamClutching[4];
int g_RoundKills[MAXPLAYERS + 1];  // kills per round each client has gotten
int g_RoundClutchingEnemyCount[MAXPLAYERS +
                               1];  // number of enemies left alive when last alive on your team
int g_LastFlashBangThrower = -1;    // last client to have a flashbang detonate
int g_RoundFlashedBy[MAXPLAYERS + 1];
bool g_TeamFirstKillDone[MatchTeam_Count];
bool g_TeamFirstDeathDone[MatchTeam_Count];
int g_PlayerKilledBy[MAXPLAYERS + 1];
float g_PlayerKilledByTime[MAXPLAYERS + 1];
int g_DamageDone[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_DamageDoneHits[MAXPLAYERS + 1][MAXPLAYERS + 1];
KeyValues g_StatsKv;

enum struct TeamState {
  int veto_captain; // Client doing the map vetos.
  int series_score; // Current number of maps won.
  bool ready_override; // Whether a team has been force readied.
  int side; // Current CS_TEAM_* side.
  int starting_side;

  // Pause info.
  bool ready_for_unpause;
  bool gave_stop_command;
  int pause_time_used;
  int num_pauses_used;
  int ready_time_used;
}
TeamState g_TeamState[MatchTeam_Count];

ArrayList g_TeamScoresPerMap = null;
char g_LoadedConfigFile[PLATFORM_MAX_PATH];
bool g_ClientReady[MAXPLAYERS + 1];  // Whether clients are marked ready.
bool g_InExtendedPause;
char g_DefaultTeamColors[][] = {
    TEAM1_COLOR, TEAM2_COLOR, "{NORMAL}", "{NORMAL}",
};

bool g_ForceWinnerSignal = false;
MatchTeam g_ForcedWinner = MatchTeam_TeamNone;

/** Chat aliases loaded **/
#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

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
Handle g_OnEvent = INVALID_HANDLE;
Handle g_OnGameStateChanged = INVALID_HANDLE;
Handle g_OnGoingLive = INVALID_HANDLE;
Handle g_OnLoadMatchConfigFailed = INVALID_HANDLE;
Handle g_OnMapPicked = INVALID_HANDLE;
Handle g_OnMapResult = INVALID_HANDLE;
Handle g_OnMapVetoed = INVALID_HANDLE;
Handle g_OnSidePicked = INVALID_HANDLE;
Handle g_OnPreLoadMatchConfig = INVALID_HANDLE;
Handle g_OnRoundStatsUpdated = INVALID_HANDLE;
Handle g_OnSeriesInit = INVALID_HANDLE;
Handle g_OnSeriesResult = INVALID_HANDLE;

#include "get5/util.sp"
#include "get5/version.sp"

#include "get5/backups.sp"
#include "get5/chatcommands.sp"
#include "get5/debug.sp"
#include "get5/eventlogger.sp"
#include "get5/get5menu.sp"
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
  LoadTranslations("common.phrases");

  /** ConVars **/
  g_AllowTechPauseCvar = CreateConVar("get5_allow_technical_pause", "1",
                                      "Whether or not technical pauses are allowed");
  g_AutoLoadConfigCvar =
      CreateConVar("get5_autoload_config", "",
                   "Name of a match config file to automatically load when the server loads");
  g_BackupSystemEnabledCvar =
      CreateConVar("get5_backup_system_enabled", "1", "Whether the get5 backup system is enabled");
  g_DamagePrintCvar =
      CreateConVar("get5_print_damage", "0", "Whether damage reports are printed on round end.");
  g_DamagePrintFormat = CreateConVar(
      "get5_damageprint_format",
      "--> ({DMG_TO} dmg / {HITS_TO} hits) to ({DMG_FROM} dmg / {HITS_FROM} hits) from {NAME} ({HEALTH} HP)",
      "Format of the damage output string. Avaliable tags are in the default, color tags such as {LIGHT_RED} and {GREEN} also work.");
  g_CheckAuthsCvar =
      CreateConVar("get5_check_auths", "1",
                   "If set to 0, get5 will not force players to the correct team based on steamid");
  g_DemoNameFormatCvar = CreateConVar("get5_demo_name_format", "{MATCHID}_map{MAPNUMBER}_{MAPNAME}",
                                      "Format for demo file names, use \"\" to disable");
  g_DisplayGotvVeto =
      CreateConVar("get5_display_gotv_veto", "0",
                   "Whether to wait for map vetos to be printed to GOTV before changing map");
  g_EndMatchOnEmptyServerCvar = CreateConVar(
      "get5_end_match_on_empty_server", "0",
      "Whether to end the match if all players disconnect before ending. No winner is set if this happens.");
  g_EventLogFormatCvar =
      CreateConVar("get5_event_log_format", "",
                   "Path to use when writing match event logs, use \"\" to disable");
  g_FixedPauseTimeCvar =
      CreateConVar("get5_fixed_pause_time", "0",
                   "If set to non-zero, this will be the fixed length of any pause");
  g_KickClientImmunity = CreateConVar(
      "get5_kick_immunity", "1",
      "Whether or not admins with the changemap flag will be immune to kicks from \"get5_kick_when_no_match_loaded\". Set to \"0\" to disable");
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
  g_MessagePrefixCvar =
      CreateConVar("get5_message_prefix", DEFAULT_TAG, "The tag applied before plugin messages.");
  g_ResetPausesEachHalfCvar =
      CreateConVar("get5_reset_pauses_each_half", "1",
                   "Whether pause limits will be reset each halftime period");
  g_PausingEnabledCvar = CreateConVar("get5_pausing_enabled", "1", "Whether pausing is allowed.");
  g_ServerIdCvar = CreateConVar(
      "get5_server_id", "0",
      "Integer that identifies your server. This is used in temp files to prevent collisions.");
  g_SetClientClanTagCvar = CreateConVar("get5_set_client_clan_tags", "1",
                                        "Whether to set client clan tags to player ready status.");
  g_SetHostnameCvar = CreateConVar(
      "get5_hostname_format", "Get5: {TEAM1} vs {TEAM2}",
      "Template that the server hostname will follow when a match is live. Leave field blank to disable. Valid parameters are: {MAPNUMBER}, {MATCHID}, {SERVERID}, {MAPNAME}, {TIME}, {TEAM1}, {TEAM2}");
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
  g_VetoConfirmationTimeCvar = CreateConVar(
      "get5_veto_confirmation_time", "2.0",
      "Time (in seconds) from presenting a veto menu to a selection being made, during which a confirmation will be required, 0 to disable");
  g_VetoCountdownCvar =
      CreateConVar("get5_veto_countdown", "5",
                   "Seconds to countdown before veto process commences. Set to \"0\" to disable.");
  g_WarmupCfgCvar =
      CreateConVar("get5_warmup_cfg", "get5/warmup.cfg", "Config file to exec in warmup periods");

  /** Create and exec plugin's configuration file **/
  AutoExecConfig(true, "get5");

  g_GameStateCvar =
      CreateConVar("get5_game_state", "0", "Current game state (see get5.inc)", FCVAR_DONTRECORD);
  g_LastGet5BackupCvar =
      CreateConVar("get5_last_backup_file", "", "Last get5 backup file written", FCVAR_DONTRECORD);
  g_VersionCvar = CreateConVar("get5_version", PLUGIN_VERSION, "Current get5 version",
                               FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  g_VersionCvar.SetString(PLUGIN_VERSION);

  g_CoachingEnabledCvar = FindConVar("sv_coaching_enabled");

  /** Client commands **/
  g_ChatAliases = new ArrayList(ByteCountToCells(ALIAS_LENGTH));
  g_ChatAliasesCommands = new ArrayList(ByteCountToCells(COMMAND_LENGTH));
  AddAliasedCommand("ready", Command_Ready, "Marks the client as ready");
  AddAliasedCommand("unready", Command_NotReady, "Marks the client as not ready");
  AddAliasedCommand("notready", Command_NotReady, "Marks the client as not ready");
  AddAliasedCommand("forceready", Command_ForceReadyClient, "Force marks clients team as ready");
  AddAliasedCommand("tech", Command_TechPause, "Calls for a tech pause");
  AddAliasedCommand("pause", Command_Pause, "Pauses the game");
  AddAliasedCommand("unpause", Command_Unpause, "Unpauses the game");
  AddAliasedCommand("coach", Command_SmCoach, "Marks a client as a coach for their team");
  AddAliasedCommand("stay", Command_Stay,
                    "Elects to stay on the current team after winning a knife round");
  AddAliasedCommand("swap", Command_Swap,
                    "Elects to swap the current teams after winning a knife round");
  AddAliasedCommand("t", Command_T, "Elects to start on T side after winning a knife round");
  AddAliasedCommand("ct", Command_Ct, "Elects to start on CT side after winning a knife round");
  AddAliasedCommand("stop", Command_Stop, "Elects to stop the game to reload a backup file");

  /** Admin/server commands **/
  RegAdminCmd(
      "get5_loadmatch", Command_LoadMatch, ADMFLAG_CHANGEMAP,
      "Loads a match config file (json or keyvalues) from a file relative to the csgo/ directory");
  RegAdminCmd(
      "get5_loadmatch_url", Command_LoadMatchUrl, ADMFLAG_CHANGEMAP,
      "Loads a JSON config file by sending a GET request to download it. Requires either the SteamWorks extension.");
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
              "Creates and loads a match using the scrim template");
  RegAdminCmd("sm_scrim", Command_CreateScrim, ADMFLAG_CHANGEMAP,
              "Creates and loads a match using the scrim template");

  RegAdminCmd("get5_ringer", Command_Ringer, ADMFLAG_CHANGEMAP,
              "Adds/removes a ringer to/from the home scrim team");
  RegAdminCmd("sm_ringer", Command_Ringer, ADMFLAG_CHANGEMAP,
              "Adds/removes a ringer to/from the home scrim team");

  RegAdminCmd("sm_get5", Command_Get5AdminMenu, ADMFLAG_CHANGEMAP, "Displays a helper menu");

  RegAdminCmd("get5_forceready", Command_AdminForceReady, ADMFLAG_CHANGEMAP,
              "Force readies all current teams");
  RegAdminCmd("get5_forcestart", Command_AdminForceReady, ADMFLAG_CHANGEMAP,
              "Force readies all current teams");

  RegAdminCmd("get5_dumpstats", Command_DumpStats, ADMFLAG_CHANGEMAP,
              "Dumps match stats to a file");
  RegAdminCmd("get5_listbackups", Command_ListBackups, ADMFLAG_CHANGEMAP,
              "Lists get5 match backups for the current matchid or a given one");
  RegAdminCmd("get5_loadbackup", Command_LoadBackup, ADMFLAG_CHANGEMAP,
              "Loads a get5 match backup");
  RegAdminCmd("get5_debuginfo", Command_DebugInfo, ADMFLAG_CHANGEMAP,
              "Dumps debug info to a file (addons/sourcemod/logs/get5_debuginfo.txt by default)");

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
  HookEvent("player_disconnect", Event_PlayerDisconnect);
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
  g_MatchConfig.cvar_names = new ArrayList(MAX_CVAR_LENGTH);
  g_MatchConfig.cvar_values = new ArrayList(MAX_CVAR_LENGTH);
  g_TeamScoresPerMap = new ArrayList(view_as<int>(MatchTeam_Count));

  for (int i = 0; i < sizeof(g_TeamAuths); i++) {
    g_TeamAuths[i] = new ArrayList(AUTH_LENGTH);
  }
  g_PlayerNames = new StringMap();

  /** Create forwards **/
  g_OnBackupRestore = CreateGlobalForward("Get5_OnBackupRestore", ET_Ignore);
  g_OnDemoFinished = CreateGlobalForward("Get5_OnDemoFinished", ET_Ignore, Param_String);
  g_OnEvent = CreateGlobalForward("Get5_OnEvent", ET_Ignore, Param_String);
  g_OnGameStateChanged =
      CreateGlobalForward("Get5_OnGameStateChanged", ET_Ignore, Param_Cell, Param_Cell);
  g_OnGoingLive = CreateGlobalForward("Get5_OnGoingLive", ET_Ignore, Param_Cell);
  g_OnMapResult = CreateGlobalForward("Get5_OnMapResult", ET_Ignore, Param_String, Param_Cell,
                                      Param_Cell, Param_Cell, Param_Cell);
  g_OnLoadMatchConfigFailed =
      CreateGlobalForward("Get5_OnLoadMatchConfigFailed", ET_Ignore, Param_String);
  g_OnMapPicked = CreateGlobalForward("Get5_OnMapPicked", ET_Ignore, Param_Cell, Param_String);
  g_OnMapVetoed = CreateGlobalForward("Get5_OnMapVetoed", ET_Ignore, Param_Cell, Param_String);
  g_OnSidePicked =
      CreateGlobalForward("Get5_OnSidePicked", ET_Ignore, Param_Cell, Param_String, Param_Cell);
  g_OnRoundStatsUpdated = CreateGlobalForward("Get5_OnRoundStatsUpdated", ET_Ignore);
  g_OnPreLoadMatchConfig =
      CreateGlobalForward("Get5_OnPreLoadMatchConfig", ET_Ignore, Param_String);
  g_OnSeriesInit = CreateGlobalForward("Get5_OnSeriesInit", ET_Ignore);
  g_OnSeriesResult =
      CreateGlobalForward("Get5_OnSeriesResult", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);

  /** Start any repeating timers **/
  CreateTimer(CHECK_READY_TIMER_INTERVAL, Timer_CheckReady, _, TIMER_REPEAT);
  CreateTimer(INFO_MESSAGE_TIMER_INTERVAL, Timer_InfoMessages, _, TIMER_REPEAT);
}

public Action Timer_InfoMessages(Handle timer) {
  // Handle pre-veto messages
  if (g_GameState == Get5State_PreVeto) {
    if (IsTeamsReady() && !IsSpectatorsReady()) {
      Get5_MessageToAll("%t", "WaitingForCastersReadyInfoMessage",
                        g_TeamConfig[MatchTeam_TeamSpec].formatted_name);
    } else {
      Get5_MessageToAll("%t", "ReadyToVetoInfoMessage");
    }
    MissingPlayerInfoMessage();
  }

  // Handle warmup state, provided we're not waiting for a map change
  if (g_GameState == Get5State_Warmup && !g_MapChangePending) {
    // Backups take priority
    if (!IsTeamsReady() && g_WaitingForRoundBackup) {
      Get5_MessageToAll("%t", "ReadyToRestoreBackupInfoMessage");
      return Plugin_Continue;
    }

    // Find out what we're waiting for
    if (IsTeamsReady() && !IsSpectatorsReady()) {
      Get5_MessageToAll("%t", "WaitingForCastersReadyInfoMessage",
                        g_TeamConfig[MatchTeam_TeamSpec].formatted_name);
    } else {
      if (g_MapSides.Get(GetMapNumber()) == SideChoice_KnifeRound) {
        Get5_MessageToAll("%t", "ReadyToKnifeInfoMessage");
      } else {
        Get5_MessageToAll("%t", "ReadyToStartInfoMessage");
      }
    }
    MissingPlayerInfoMessage();
  } else if (g_DisplayGotvVeto.BoolValue && g_GameState == Get5State_Warmup && g_MapChangePending) {
    Get5_MessageToAll("%t", "WaitingForGOTVVetoInfoMessage");
  }

  // Handle waiting for knife decision
  if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    Get5_MessageToAll("%t", "WaitingForEnemySwapInfoMessage",
                      g_TeamConfig[g_KnifeWinnerTeam].formatted_name);
  }

  // Handle postgame
  if (g_GameState == Get5State_PostGame) {
    Get5_MessageToAll("%t", "WaitingForGOTVBrodcastEndingInfoMessage");
  }

  return Plugin_Continue;
}

public void OnClientAuthorized(int client, const char[] auth) {
  SetClientReady(client, false);
  g_MovingClientToCoach[client] = false;
  if (StrEqual(auth, "BOT", false)) {
    return;
  }

  if (g_GameState == Get5State_None && g_KickClientsWithNoMatchCvar.BoolValue) {
    if (!g_KickClientImmunity.BoolValue ||
        !CheckCommandAccess(client, "get5_kickcheck", ADMFLAG_CHANGEMAP)) {
      KickClient(client, "%t", "NoMatchSetupInfoMessage");
    }
  }

  if (g_GameState != Get5State_None && g_CheckAuthsCvar.BoolValue) {
    MatchTeam team = GetClientMatchTeam(client);
    if (team == MatchTeam_TeamNone) {
      KickClient(client, "%t", "YourAreNotAPlayerInfoMessage");
    } else {
      int teamCount = CountPlayersOnMatchTeam(team, client);
      if (teamCount >= g_MatchConfig.players_per_team && !g_CoachingEnabledCvar.BoolValue) {
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
  if (g_GameState <= Get5State_Warmup && g_GameState != Get5State_None) {
    if (GetRealClientCount() <= 1) {
      ExecCfg(g_WarmupCfgCvar);
      EnsurePausedWarmup();
    }
  }

  Stats_ResetClientRoundValues(client);
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (StrEqual(command, "say") && g_GameState != Get5State_None) {
    EventLogger_ClientSay(client, sArgs);
  }
  CheckForChatAlias(client, command, sArgs);
}

/**
 * Full connect event right when a player joins.
 * This sets the auto-pick time to a high value because mp_forcepicktime is broken and
 * if a player does not select a team but leaves their mouse over one, they are
 * put on that team and spawned, so we can't allow that.
 */
public Action Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  EventLogger_PlayerConnect(client);
  if (client > 0) {
    SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
  }
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  EventLogger_PlayerDisconnect(client);

  // TODO: consider adding a forfeit if a full team disconnects.
  if (g_EndMatchOnEmptyServerCvar.BoolValue && g_GameState >= Get5State_Warmup &&
      g_GameState < Get5State_PostGame && GetRealClientCount() == 0 && !g_MapChangePending) {
    g_TeamState[MatchTeam_Team1].series_score = 0;
    g_TeamState[MatchTeam_Team2].series_score = 0;
    EndSeries();
  }
}

public void OnMapStart() {
  g_MapChangePending = false;
  DeleteOldBackups();

  ResetReadyStatus();
  LOOP_TEAMS(team) {
    g_TeamState[team].gave_stop_command = false;
    g_TeamState[team].ready_for_unpause = false;
    g_TeamState[team].pause_time_used = 0;
    g_TeamState[team].num_pauses_used = 0;
    g_TeamState[team].ready_time_used = 0;
  }

  if (g_WaitingForRoundBackup) {
    ChangeState(Get5State_Warmup);
    ExecCfg(g_LiveCfgCvar);
    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();
    EnsurePausedWarmup();
  }
}

public void OnConfigsExecuted() {
  SetStartingTeams();
  CheckAutoLoadConfig();

  if (g_GameState == Get5State_PostGame) {
    ChangeState(Get5State_Warmup);
  }

  if (g_GameState == Get5State_Warmup || g_GameState == Get5State_Veto) {
    ExecCfg(g_WarmupCfgCvar);
    SetMatchTeamCvars();
    ExecuteMatchConfigCvars();
    EnsurePausedWarmup();
  }
}

public Action Timer_CheckReady(Handle timer) {
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  CheckTeamNameStatus(MatchTeam_Team1);
  CheckTeamNameStatus(MatchTeam_Team2);
  UpdateClanTags();

  // Handle ready checks for pre-veto state
  if (g_GameState == Get5State_PreVeto) {
    if (IsTeamsReady()) {
      // We don't wait for spectators when initiating veto
      LogDebug("Timer_CheckReady: starting veto");
      ChangeState(Get5State_Veto);
      CreateVeto();
    } else {
      CheckReadyWaitingTimes();
    }
  }

  // Handle ready checks for warmup, provided we are not waiting for a map change
  if (g_GameState == Get5State_Warmup && !g_MapChangePending) {
    // We don't wait for spectators when restoring backups
    if (IsTeamsReady() && g_WaitingForRoundBackup) {
      LogDebug("Timer_CheckReady: restoring from backup");
      g_WaitingForRoundBackup = false;
      RestoreGet5Backup();
      return Plugin_Continue;
    }

    // Wait for both players and spectators before going live
    if (IsTeamsReady() && IsSpectatorsReady()) {
      LogDebug("Timer_CheckReady: all teams ready to start");
      if (g_MapSides.Get(GetMapNumber()) == SideChoice_KnifeRound) {
        LogDebug("Timer_CheckReady: starting with a knife round");
        StartGame(true);
      } else {
        LogDebug("Timer_CheckReady: starting without a knife round");
        StartGame(false);
      }
    } else {
      CheckReadyWaitingTimes();
    }
  }

  return Plugin_Continue;
}

static void CheckReadyWaitingTimes() {
  if (g_TeamTimeToStartCvar.IntValue > 0) {
    CheckReadyWaitingTime(MatchTeam_Team1);
    CheckReadyWaitingTime(MatchTeam_Team2);
  }
}

static void CheckReadyWaitingTime(MatchTeam team) {
  if (!IsTeamReady(team) && g_GameState != Get5State_None) {
    g_TeamState[team].ready_time_used++;
    int timeLeft = g_TeamTimeToStartCvar.IntValue - g_TeamState[team].ready_time_used;

    if (timeLeft <= 0) {
      g_ForceWinnerSignal = true;
      g_ForcedWinner = (team == MatchTeam_Team1) ? MatchTeam_Team2 : MatchTeam_Team1;
      Get5_MessageToAll("%t", "TeamForfeitInfoMessage", g_TeamConfig[team].formatted_name);
      ChangeState(Get5State_None);
      Stats_Forfeit(team);
      EndSeries();

    } else if (timeLeft >= 300 && timeLeft % 60 == 0) {
      Get5_MessageToAll("%t", "MinutesToForfeitMessage", g_TeamConfig[team].formatted_name,
                        timeLeft / 60);

    } else if (timeLeft < 300 && timeLeft % 30 == 0) {
      Get5_MessageToAll("%t", "SecondsToForfeitInfoMessage", g_TeamConfig[team].formatted_name,
                        timeLeft);

    } else if (timeLeft == 10) {
      Get5_MessageToAll("%t", "10SecondsToForfeitInfoMessage", g_TeamConfig[team].formatted_name,
                        timeLeft);
    }
  }
}

static void CheckAutoLoadConfig() {
  if (g_GameState == Get5State_None) {
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
  if (g_GameState == Get5State_None) {
    return Plugin_Handled;
  }

  // Call game-ending forwards.
  g_MapChangePending = false;
  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));
  Call_StartForward(g_OnMapResult);
  Call_PushString(mapName);
  Call_PushCell(MatchTeam_TeamNone);
  Call_PushCell(CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
  Call_PushCell(CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
  Call_PushCell(GetMapNumber() - 1);
  Call_Finish();

  Call_StartForward(g_OnSeriesResult);
  Call_PushCell(MatchTeam_TeamNone);
  Call_PushCell(g_TeamState[MatchTeam_Team1].series_score);
  Call_PushCell(g_TeamState[MatchTeam_Team2].series_score);
  Call_Finish();

  UpdateClanTags();
  ChangeState(Get5State_None);

  Get5_MessageToAll("%t", "AdminForceEndInfoMessage");
  RestoreCvars(g_MatchConfigChangedCvars);
  StopRecording();

  if (g_ActiveVetoMenu != null) {
    g_ActiveVetoMenu.Cancel();
  }

  return Plugin_Handled;
}

public Action Command_LoadMatch(int client, int args) {
  if (g_GameState != Get5State_None) {
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
  if (g_GameState != Get5State_None) {
    ReplyToCommand(client, "Cannot load a match config with another match already loaded");
    return Plugin_Handled;
  }

  bool steamWorksAvaliable = LibraryExists("SteamWorks");
  if (!steamWorksAvaliable) {
    ReplyToCommand(client,
                   "Cannot load matches from a url without the SteamWorks extension running");
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
  if (g_GameState == Get5State_None) {
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
  if (!g_StopCommandEnabledCvar.BoolValue) {
    return Plugin_Handled;
  }

  if (g_GameState != Get5State_Live || g_PendingSideSwap == true) {
    return Plugin_Handled;
  }

  // Let the server/rcon always force restore.
  if (client == 0) {
    RestoreLastRound();
  }

  MatchTeam team = GetClientMatchTeam(client);
  g_TeamState[team].gave_stop_command = true;

  if (g_TeamState[MatchTeam_Team1].gave_stop_command &&
      !g_TeamState[MatchTeam_Team2].gave_stop_command) {
    Get5_MessageToAll("%t", "TeamWantsToReloadLastRoundInfoMessage",
                      g_TeamConfig[MatchTeam_Team1].formatted_name,
                      g_TeamConfig[MatchTeam_Team2].formatted_name);
  } else if (!g_TeamState[MatchTeam_Team1].gave_stop_command &&
             g_TeamState[MatchTeam_Team2].gave_stop_command) {
    Get5_MessageToAll("%t", "TeamWantsToReloadLastRoundInfoMessage",
                      g_TeamConfig[MatchTeam_Team2].formatted_name,
                      g_TeamConfig[MatchTeam_Team1].formatted_name);
  } else if (g_TeamState[MatchTeam_Team1].gave_stop_command &&
             g_TeamState[MatchTeam_Team2].gave_stop_command) {
    RestoreLastRound();
  }

  return Plugin_Handled;
}

public bool RestoreLastRound() {
  LOOP_TEAMS(x) {
    g_TeamState[x].gave_stop_command = false;
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
  if (g_GameState != Get5State_None && g_GameState < Get5State_KnifeRound) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsPlayer(client) && OnActiveTeam(client)) {
      SetEntProp(client, Prop_Send, "m_iAccount", GetCvarIntSafe("mp_maxmoney"));
    }
  }
}

public Action Event_MatchOver(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_MatchOver");
  if (g_GameState == Get5State_Live) {
    // Figure out who won
    int t1score = CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1));
    int t2score = CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2));
    MatchTeam winningTeam = MatchTeam_TeamNone;
    if (t1score > t2score) {
      winningTeam = MatchTeam_Team1;
    } else if (t2score > t1score) {
      winningTeam = MatchTeam_Team2;
    }

    // Write backup before series score increments
    WriteBackup();

    // Update series scores
    Stats_UpdateMapScore(winningTeam);
    AddMapScore();
    g_TeamState[winningTeam].series_score++;

    // Handle map end

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

    int t1maps = g_TeamState[MatchTeam_Team1].series_score;
    int t2maps = g_TeamState[MatchTeam_Team2].series_score;
    int tiedMaps = g_TeamState[MatchTeam_TeamNone].series_score;

    float minDelay = float(GetTvDelay()) + MATCH_END_DELAY_AFTER_TV;

    if (t1maps == g_MapsToWin) {
      // Team 1 won
      SeriesEndMessage(MatchTeam_Team1);
      DelayFunction(minDelay, EndSeries);

    } else if (t2maps == g_MapsToWin) {
      // Team 2 won
      SeriesEndMessage(MatchTeam_Team2);
      DelayFunction(minDelay, EndSeries);

    } else if (t1maps == t2maps && t1maps + tiedMaps == g_MapsToWin) {
      // The whole series was a tie
      SeriesEndMessage(MatchTeam_TeamNone);
      DelayFunction(minDelay, EndSeries);

    } else if (g_BO2Match && GetMapNumber() == 2) {
      // It was a bo2, and none of the teams got to 2
      SeriesEndMessage(MatchTeam_TeamNone);
      DelayFunction(minDelay, EndSeries);

    } else {
      if (t1maps > t2maps) {
        Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage",
                          g_TeamConfig[MatchTeam_Team1].formatted_name, t1maps, t2maps);

      } else if (t2maps > t1maps) {
        Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage",
                          g_TeamConfig[MatchTeam_Team2].formatted_name, t2maps, t1maps);

      } else {
        Get5_MessageToAll("%t", "SeriesTiedInfoMessage", t1maps, t2maps);
      }

      int index = GetMapNumber();
      char nextMap[PLATFORM_MAX_PATH];
      g_MapsToPlay.GetString(index, nextMap, sizeof(nextMap));

      g_MapChangePending = true;
      Get5_MessageToAll("%t", "NextSeriesMapInfoMessage", nextMap);
      ChangeState(Get5State_PostGame);
      CreateTimer(minDelay, Timer_NextMatchMap);
    }
  }

  return Plugin_Continue;
}

static void SeriesEndMessage(MatchTeam team) {
  if (g_MapsToWin == 1) {
    if (team == MatchTeam_TeamNone) {
      Get5_MessageToAll("%t", "TeamTiedMatchInfoMessage",
                        g_TeamConfig[MatchTeam_Team1].formatted_name,
                        g_TeamConfig[MatchTeam_Team2].formatted_name);
    } else {
      Get5_MessageToAll("%t", "TeamWonMatchInfoMessage", g_TeamConfig[team].formatted_name);
    }
  } else {
    if (team == MatchTeam_TeamNone) {
      // BO2 split.
      Get5_MessageToAll("%t", "TeamsSplitSeriesBO2InfoMessage",
                        g_TeamConfig[MatchTeam_Team1].formatted_name,
                        g_TeamConfig[MatchTeam_Team2].formatted_name);

    } else {
      Get5_MessageToAll("%t", "TeamWonSeriesInfoMessage", g_TeamConfig[team].formatted_name,
                        g_TeamState[team].series_score,
                        g_TeamState[OtherMatchTeam(team)].series_score);
    }
  }
}

public Action Timer_NextMatchMap(Handle timer) {
  if (g_GameState >= Get5State_Live)
    StopRecording();

  int index = GetMapNumber();
  char map[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(index, map, sizeof(map));

  if (!g_MatchConfig.skip_veto && g_DisplayGotvVeto.BoolValue && index == 0) {
    float minDelay = float(GetTvDelay()) + MATCH_END_DELAY_AFTER_TV;
    ChangeMap(map, minDelay);
  } else {
    ChangeMap(map);
  }
}

public void KickClientsOnEnd() {
  if (g_KickClientsWithNoMatchCvar.BoolValue) {
    for (int i = 1; i <= MaxClients; i++) {
      if (IsPlayer(i) &&
          !(g_KickClientImmunity.BoolValue &&
            CheckCommandAccess(i, "get5_kickcheck", ADMFLAG_CHANGEMAP))) {
        KickClient(i, "%t", "MatchFinishedInfoMessage");
      }
    }
  }
}

public void EndSeries() {
  DelayFunction(10.0, KickClientsOnEnd);
  StopRecording();

  // Figure out who won
  int t1maps = g_TeamState[MatchTeam_Team1].series_score;
  int t2maps = g_TeamState[MatchTeam_Team2].series_score;

  MatchTeam winningTeam = MatchTeam_TeamNone;
  if (t1maps > t2maps) {
    winningTeam = MatchTeam_Team1;
  } else if (t2maps > t1maps) {
    winningTeam = MatchTeam_Team2;
  }

  if (g_ForceWinnerSignal) {
    winningTeam = g_ForcedWinner;
  }

  Stats_SeriesEnd(winningTeam);
  EventLogger_SeriesEnd(winningTeam, t1maps, t2maps);

  Call_StartForward(g_OnSeriesResult);
  Call_PushCell(winningTeam);
  Call_PushCell(t1maps);
  Call_PushCell(t2maps);
  Call_Finish();

  RestoreCvars(g_MatchConfigChangedCvars);
  ChangeState(Get5State_None);
}

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundPreStart");
  if (g_PendingSideSwap) {
    g_PendingSideSwap = false;
    SwapSides();
  }

  if (g_GameState == Get5State_GoingLive) {
    ChangeState(Get5State_Live);
  }

  Stats_ResetRoundValues();

  if (g_GameState >= Get5State_Warmup && !g_DoingBackupRestoreNow) {
    WriteBackup();
  }
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState == Get5State_Live) {
    Stats_RoundStart();
  }
}

public void WriteBackup() {
  if (!g_BackupSystemEnabledCvar.BoolValue) {
    return;
  }

  char path[PLATFORM_MAX_PATH];
  if (g_GameState == Get5State_Live) {
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
  LogDebug("Event_RoundEnd");
  if (g_DoingBackupRestoreNow) {
    return;
  }

  if (g_GameState == Get5State_KnifeRound && g_HasKnifeRoundStarted) {
    ChangeState(Get5State_WaitingForKnifeRoundDecision);
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
                      g_TeamConfig[g_KnifeWinnerTeam].formatted_name);

    if (g_TeamTimeToKnifeDecisionCvar.FloatValue > 0)
      CreateTimer(g_TeamTimeToKnifeDecisionCvar.FloatValue, Timer_ForceKnifeDecision);
  }

  if (g_GameState == Get5State_Live) {
    int csTeamWinner = event.GetInt("winner");
    int csReason = event.GetInt("reason");

    Get5_MessageToAll("%t", "CurrentScoreInfoMessage", g_TeamConfig[MatchTeam_Team1].name,
                      CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)),
                      CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)),
                      g_TeamConfig[MatchTeam_Team2].name);

    Stats_RoundEnd(csTeamWinner);
    Call_StartForward(g_OnRoundStatsUpdated);
    Call_Finish();

    EventLogger_RoundEnd(csTeamWinner, csReason);

    int roundsPlayed = GameRules_GetProp("m_totalRoundsPlayed");
    LogDebug("m_totalRoundsPlayed = %d", roundsPlayed);

    int roundsPerHalf = GetCvarIntSafe("mp_maxrounds") / 2;
    int roundsPerOTHalf = GetCvarIntSafe("mp_overtime_maxrounds") / 2;

    bool halftimeEnabled = (GetCvarIntSafe("mp_halftime") != 0);
    if (halftimeEnabled) {
      // TODO: There should be a better way of detecting when halftime is occuring.
      // What about the halftime_start event, or one of the intermission events?

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
}

public void SwapSides() {
  LogDebug("SwapSides");
  int tmp = g_TeamState[MatchTeam_Team1].side;
  g_TeamState[MatchTeam_Team1].side = g_TeamState[MatchTeam_Team2].side;
  g_TeamState[MatchTeam_Team2].side = tmp;

  if (g_ResetPausesEachHalfCvar.BoolValue) {
    LOOP_TEAMS(team) {
      g_TeamState[team].pause_time_used = 0;
      g_TeamState[team].num_pauses_used = 0;
    }
  }

  EventLogger_SideSwap(g_TeamState[MatchTeam_Team1].side, g_TeamState[MatchTeam_Team2].side);
}

/**
 * Silences cvar changes when executing live/knife/warmup configs, *unless* it's sv_cheats.
 */
public Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_None) {
    char cvarName[MAX_CVAR_LENGTH];
    event.GetString("cvarname", cvarName, sizeof(cvarName));
    if (!StrEqual(cvarName, "sv_cheats")) {
      event.BroadcastDisabled = true;
    }
  }

  return Plugin_Continue;
}

public void StartGame(bool knifeRound) {
  LogDebug("StartGame");
  if (!IsTVEnabled()) {
    LogMessage("GOTV demo could not be recorded since tv_enable is not set to 1");
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
    LogDebug("StartGame: about to begin knife round");
    ChangeState(Get5State_KnifeRound);
    if (g_KnifeChangedCvars != INVALID_HANDLE) {
      CloseCvarStorage(g_KnifeChangedCvars);
    }
    g_KnifeChangedCvars = ExecuteAndSaveCvars(KNIFE_CONFIG);
    CreateTimer(1.0, StartKnifeRound);
  } else {
    LogDebug("StartGame: about to go live");
    ChangeState(Get5State_GoingLive);
    CreateTimer(3.0, StartGoingLive, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action Timer_PostKnife(Handle timer) {
  if (g_KnifeChangedCvars != INVALID_HANDLE) {
    RestoreCvars(g_KnifeChangedCvars, true);
  }

  ExecCfg(g_WarmupCfgCvar);
  EnsurePausedWarmup();
}

public Action StopDemo(Handle timer) {
  StopRecording();
  return Plugin_Handled;
}

public void ChangeState(Get5State state) {
  LogDebug("Change from state %d -> %d", g_GameState, state);
  g_GameStateCvar.IntValue = view_as<int>(state);
  Call_StartForward(g_OnGameStateChanged);
  Call_PushCell(g_GameState);
  Call_PushCell(state);
  Call_Finish();
  g_GameState = state;
}

public Action Command_Status(int client, int args) {
  JSON_Object json = new JSON_Object();

  json.SetString("plugin_version", PLUGIN_VERSION);

#if defined COMMIT_STRING
  json.SetString("commit", COMMIT_STRING);
#endif

  json.SetInt("gamestate", view_as<int>(g_GameState));
  json.SetBool("paused", IsPaused());

  char gamestate[64];
  GameStateString(g_GameState, gamestate, sizeof(gamestate));
  json.SetString("gamestate_string", gamestate);

  if (g_GameState != Get5State_None) {
    json.SetString("matchid", g_MatchID);
    json.SetString("loaded_config_file", g_LoadedConfigFile);
    json.SetInt("map_number", GetMapNumber());

    JSON_Object team1 = new JSON_Object();
    AddTeamInfo(team1, MatchTeam_Team1);
    json.SetObject("team1", team1);

    JSON_Object team2 = new JSON_Object();
    AddTeamInfo(team2, MatchTeam_Team2);
    json.SetObject("team2", team2);
  }

  if (g_GameState > Get5State_Veto) {
    JSON_Object maps = new JSON_Object();

    for (int i = 0; i < g_MapsToPlay.Length; i++) {
      char mapKey[64];
      Format(mapKey, sizeof(mapKey), "map%d", i);

      char mapName[PLATFORM_MAX_PATH];
      g_MapsToPlay.GetString(i, mapName, sizeof(mapName));

      maps.SetString(mapKey, mapName);
    }
    json.SetObject("maps", maps);
  }

  char buffer[4096];
  json.Encode(buffer, sizeof(buffer));
  ReplyToCommand(client, buffer);

  json.Cleanup();
  delete json;
  return Plugin_Handled;
}

static void AddTeamInfo(JSON_Object json, MatchTeam matchTeam) {
  int team = MatchTeamToCSTeam(matchTeam);
  char side[4];
  CSTeamString(team, side, sizeof(side));
  json.SetString("name", g_TeamConfig[matchTeam].name);
  json.SetInt("series_score", g_TeamState[matchTeam].series_score);
  json.SetBool("ready", IsTeamReady(matchTeam));
  json.SetString("side", side);
  json.SetInt("connected_clients", GetNumHumansOnTeam(team));
  json.SetInt("current_map_score", CS_GetTeamScore(team));
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
  strcopy(team1Str, sizeof(team1Str), g_TeamConfig[MatchTeam_Team1].name);
  ReplaceString(team1Str, sizeof(team1Str), " ", "_");

  char team2Str[MAX_CVAR_LENGTH];
  strcopy(team2Str, sizeof(team2Str), g_TeamConfig[MatchTeam_Team2].name);
  ReplaceString(team2Str, sizeof(team2Str), " ", "_");

  int mapNumber =
      g_TeamState[MatchTeam_Team1].series_score + g_TeamState[MatchTeam_Team2].series_score + 1;
  ReplaceStringWithInt(buffer, len, "{MAPNUMBER}", mapNumber, false);
  ReplaceString(buffer, len, "{MATCHID}", g_MatchID, false);
  ReplaceString(buffer, len, "{MAPNAME}", mapName, false);
  ReplaceStringWithInt(buffer, len, "{SERVERID}", g_ServerIdCvar.IntValue, false);
  ReplaceString(buffer, len, "{TIME}", formattedTime, false);
  ReplaceString(buffer, len, "{TEAM1}", team1Str, false);
  ReplaceString(buffer, len, "{TEAM2}", team2Str, false);

  return true;
}

// Formats a temp file path based ont he server id. The pattern parameter is expected to have a %d
// token in it.
public void GetTempFilePath(char[] path, int len, const char[] pattern) {
  Format(path, len, pattern, g_ServerIdCvar.IntValue);
}
