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
#include <regex>
#include <sdkhooks>
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
#define MATCH_END_DELAY_AFTER_TV 15

#define TEAM1_STARTING_SIDE CS_TEAM_CT
#define TEAM2_STARTING_SIDE CS_TEAM_T
#define DEFAULT_TAG "[{YELLOW}Get5{NORMAL}]"

#if !defined LATEST_VERSION_URL
#define LATEST_VERSION_URL \
  "https://raw.githubusercontent.com/splewis/get5/master/scripting/get5/version.sp"
#endif

#if !defined GET5_GITHUB_PAGE
#define GET5_GITHUB_PAGE "splewis.github.io/get5"
#endif

#pragma semicolon 1
#pragma newdecls required

/** ConVar handles **/
ConVar g_AllowTechPauseCvar;
ConVar g_MaxTechPauseDurationCvar;
ConVar g_MaxTechPausesCvar;
ConVar g_AutoLoadConfigCvar;
ConVar g_AutoReadyActivePlayersCvar;
ConVar g_BackupSystemEnabledCvar;
ConVar g_CheckAuthsCvar;
ConVar g_DamagePrintCvar;
ConVar g_DamagePrintExcessCvar;
ConVar g_DamagePrintFormatCvar;
ConVar g_DemoNameFormatCvar;
ConVar g_DisplayGotvVetoCvar;
ConVar g_EndMatchOnEmptyServerCvar;
ConVar g_EventLogFormatCvar;
ConVar g_FixedPauseTimeCvar;
ConVar g_KickClientImmunityCvar;
ConVar g_KickClientsWithNoMatchCvar;
ConVar g_LiveCfgCvar;
ConVar g_WarmupCfgCvar;
ConVar g_KnifeCfgCvar;
ConVar g_LiveCountdownTimeCvar;
ConVar g_MaxBackupAgeCvar;
ConVar g_MaxTacticalPausesCvar;
ConVar g_MaxPauseTimeCvar;
ConVar g_MessagePrefixCvar;
ConVar g_PauseOnVetoCvar;
ConVar g_PausingEnabledCvar;
ConVar g_PrettyPrintJsonCvar;
ConVar g_ReadyTeamTagCvar;
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
ConVar g_PrintUpdateNoticeCvar;
ConVar g_RoundBackupPathCvar;
ConVar g_PhaseAnnouncementCountCvar;
ConVar g_Team1NameColorCvar;
ConVar g_Team2NameColorCvar;
ConVar g_SpecNameColorCvar;

// Autoset convars (not meant for users to set)
ConVar g_GameStateCvar;
ConVar g_LastGet5BackupCvar;
ConVar g_VersionCvar;

// Hooked cvars built into csgo
ConVar g_CoachingEnabledCvar;

/** Series config game-state **/
int g_MapsToWin = 1;  // Maps needed to win the series.
bool g_SeriesCanClinch = true;
int g_RoundNumber = -1;  // The round number, 0-indexed. -1 if the match is not live.
// The active map number, used by stats. Required as the calculated round number changes immediately
// as a map ends, but before the map changes to the next.
int g_MapNumber = 0; // the current map number, starting at 0.
int g_NumberOfMapsInSeries = 0; // the number of maps to play in the series.
char g_MatchID[MATCH_ID_LENGTH];
ArrayList g_MapPoolList = null;
ArrayList g_TeamAuths[MATCHTEAM_COUNT];
ArrayList g_TeamCoaches[MATCHTEAM_COUNT];
StringMap g_PlayerNames;
char g_TeamNames[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamTags[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_FormattedTeamNames[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamFlags[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamLogos[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamMatchTexts[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_MatchTitle[MAX_CVAR_LENGTH];
int g_FavoredTeamPercentage = 0;
char g_FavoredTeamText[MAX_CVAR_LENGTH];
int g_PlayersPerTeam = 5;
int g_CoachesPerTeam = 2;
int g_MinPlayersToReady = 1;
int g_MinSpectatorsToReady = 0;
float g_RoundStartedTime = 0.0;
float g_BombPlantedTime = 0.0;
Get5BombSite g_BombSiteLastPlanted = Get5BombSite_Unknown;

bool g_SkipVeto = false;
float g_VetoMenuTime = 0.0;
MatchSideType g_MatchSideType = MatchSideType_Standard;
ArrayList g_CvarNames = null;
ArrayList g_CvarValues = null;
bool g_InScrimMode = false;

/** Knife for sides **/
bool g_HasKnifeRoundStarted = false;
Get5Team g_KnifeWinnerTeam = Get5Team_None;
Handle g_KnifeChangedCvars = INVALID_HANDLE;
Handle g_KnifeDecisionTimer = INVALID_HANDLE;
Handle g_KnifeCountdownTimer = INVALID_HANDLE;

/** Pausing **/
bool g_IsChangingPauseState =
    false;  // Used to prevent mp_pause_match and mp_unpause_match from being called directly.
Get5Team g_PausingTeam = Get5Team_None;          // The team that last called for a pause.
Get5PauseType g_PauseType = Get5PauseType_None;  // The type of pause last initiated.
int g_LatestPauseDuration = 0;
bool g_TeamReadyForUnpause[MATCHTEAM_COUNT];
bool g_TeamGivenStopCommand[MATCHTEAM_COUNT];
int g_TacticalPauseTimeUsed[MATCHTEAM_COUNT];
int g_TacticalPausesUsed[MATCHTEAM_COUNT];
int g_TechnicalPausesUsed[MATCHTEAM_COUNT];

/** Other state **/
Get5State g_GameState = Get5State_None;
ArrayList g_MapsToPlay = null;
ArrayList g_MapSides = null;
ArrayList g_MapsLeftInVetoPool = null;
Get5Team g_LastVetoTeam;
Menu g_ActiveVetoMenu = null;

/** Backup data **/
bool g_WaitingForRoundBackup = false;
bool g_DoingBackupRestoreNow = false;

// Stats values
StringMap g_FlashbangContainer;  // Stores flashbang-entity-id -> Get5FlashbangDetonatedEvent.
StringMap g_HEGrenadeContainer;  // Stores he-entity-id -> Get5HEDetonatedEvent.
StringMap g_MolotovContainer;    // Stores molotov-entity-id -> Get5MolotovDetonatedEvent.
int g_LatestUserIdToDetonateMolotov =
    0;  // Molotov detonate and start-burning/extinguish are two separate events always fired right
        // after each other. We need this to bind them together as detonate does not have client id.
int g_LatestMolotovToExtinguishBySmoke = 0;  //  Attributes extinguish booleans to smoke grenades.
bool g_FirstKillDone = false;
bool g_FirstDeathDone = false;
bool g_SetTeamClutching[4];
int g_RoundKills[MAXPLAYERS + 1];  // kills per round each client has gotten
int g_RoundClutchingEnemyCount[MAXPLAYERS +
                               1];  // number of enemies left alive when last alive on your team
int g_PlayerKilledBy[MAXPLAYERS + 1];
float g_PlayerKilledByTime[MAXPLAYERS + 1];
int g_DamageDone[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_DamageDoneHits[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_DamageDoneKill[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_DamageDoneAssist[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_DamageDoneFlashAssist[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_PlayerRoundKillOrAssistOrTradedDeath[MAXPLAYERS + 1];
bool g_PlayerSurvived[MAXPLAYERS + 1];
KeyValues g_StatsKv;

ArrayList g_TeamScoresPerMap = null;
char g_LoadedConfigFile[PLATFORM_MAX_PATH];
char g_LoadedConfigUrl[PLATFORM_MAX_PATH];
int g_VetoCaptains[MATCHTEAM_COUNT];        // Clients doing the map vetos.
int g_TeamSeriesScores[MATCHTEAM_COUNT];    // Current number of maps won per-team.
bool g_TeamReadyOverride[MATCHTEAM_COUNT];  // Whether a team has been voluntarily force readied.
bool g_ClientReady[MAXPLAYERS + 1];         // Whether clients are marked ready.
int g_TeamSide[MATCHTEAM_COUNT];            // Current CS_TEAM_* side for the team.
int g_TeamStartingSide[MATCHTEAM_COUNT];
int g_ReadyTimeWaitingUsed = 0;

char g_LastKickedPlayerAuth[64];

/** Chat aliases loaded **/
#define ALIAS_LENGTH 64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

/** Map-game state not related to the actual gameplay. **/
char g_DemoFileName[PLATFORM_MAX_PATH];
bool g_MapChangePending = false;
bool g_PendingSideSwap = false;

// version check state
bool g_RunningPrereleaseVersion = false;
bool g_NewerVersionAvailable = false;

Handle g_MatchConfigChangedCvars = INVALID_HANDLE;

/** Forwards **/
Handle g_OnBackupRestore = INVALID_HANDLE;
Handle g_OnBombDefused = INVALID_HANDLE;
Handle g_OnBombExploded = INVALID_HANDLE;
Handle g_OnBombPlanted = INVALID_HANDLE;
Handle g_OnDemoFinished = INVALID_HANDLE;
Handle g_OnEvent = INVALID_HANDLE;
Handle g_OnFlashbangDetonated = INVALID_HANDLE;
Handle g_OnHEGrenadeDetonated = INVALID_HANDLE;
Handle g_OnSmokeGrenadeDetonated = INVALID_HANDLE;
Handle g_OnDecoyStarted = INVALID_HANDLE;
Handle g_OnMolotovDetonated = INVALID_HANDLE;
Handle g_OnGameStateChanged = INVALID_HANDLE;
Handle g_OnGoingLive = INVALID_HANDLE;
Handle g_OnGrenadeThrown = INVALID_HANDLE;
Handle g_OnLoadMatchConfigFailed = INVALID_HANDLE;
Handle g_OnMapPicked = INVALID_HANDLE;
Handle g_OnMapResult = INVALID_HANDLE;
Handle g_OnMapVetoed = INVALID_HANDLE;
Handle g_OnTeamReadyStatusChanged = INVALID_HANDLE;
Handle g_OnKnifeRoundStarted = INVALID_HANDLE;
Handle g_OnKnifeRoundWon = INVALID_HANDLE;
Handle g_OnMatchPaused = INVALID_HANDLE;
Handle g_OnMatchUnpaused = INVALID_HANDLE;
Handle g_OnPlayerConnected = INVALID_HANDLE;
Handle g_OnPlayerDisconnected = INVALID_HANDLE;
Handle g_OnPlayerDeath = INVALID_HANDLE;
Handle g_OnPlayerBecameMVP = INVALID_HANDLE;
Handle g_OnPlayerSay = INVALID_HANDLE;
Handle g_OnRoundEnd = INVALID_HANDLE;
Handle g_OnRoundStart = INVALID_HANDLE;
Handle g_OnPreLoadMatchConfig = INVALID_HANDLE;
Handle g_OnRoundStatsUpdated = INVALID_HANDLE;
Handle g_OnSeriesInit = INVALID_HANDLE;
Handle g_OnSeriesResult = INVALID_HANDLE;
Handle g_OnSidePicked = INVALID_HANDLE;

#include "get5/util.sp"
#include "get5/version.sp"

#include "get5/backups.sp"
#include "get5/chatcommands.sp"
#include "get5/debug.sp"
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
#include "get5/recording.sp"
#include "get5/stats.sp"
#include "get5/teamlogic.sp"
#include "get5/tests.sp"

// clang-format off
public Plugin myinfo = {
  name = "Get5",
  author = "splewis, nickdnk & PhlexPlexico",
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

  // Because we use SDKHooks for damage, we need to re-hook clients that are already on the server
  // in case the plugin is reloaded. This includes bots.
  LOOP_CLIENTS(i) {
    if (IsValidClient(i)) {
      Stats_HookDamageForClient(i);
    }
  }

  /** Translations **/
  LoadTranslations("get5.phrases");
  LoadTranslations("common.phrases");

  /** ConVars **/
  g_AllowTechPauseCvar = CreateConVar("get5_allow_technical_pause", "1",
                                      "Whether or not technical pauses are allowed");
  g_MaxTechPauseDurationCvar = CreateConVar(
      "get5_tech_pause_time", "0",
      "Number of seconds before anyone can call unpause on a technical timeout, 0=unlimited");
  g_MaxTechPausesCvar =
      CreateConVar("get5_max_tech_pauses", "0",
                   "Number of technical pauses a team is allowed to have, 0=unlimited");
  g_AutoLoadConfigCvar =
      CreateConVar("get5_autoload_config", "",
                   "Name of a match config file to automatically load when the server loads");
  g_AutoReadyActivePlayersCvar = CreateConVar(
      "get5_auto_ready_active_players", "0",
      "Whether to automatically mark players as ready if they kill anyone in the warmup or veto phase.");
  g_BackupSystemEnabledCvar =
      CreateConVar("get5_backup_system_enabled", "1", "Whether the get5 backup system is enabled");
  g_DamagePrintCvar =
      CreateConVar("get5_print_damage", "0", "Whether damage reports are printed on round end.");
  g_DamagePrintFormatCvar = CreateConVar(
      "get5_damageprint_format",
      "- [{KILL_TO}] ({DMG_TO} in {HITS_TO}) to [{KILL_FROM}] ({DMG_FROM} in {HITS_FROM}) from {NAME} ({HEALTH} HP)",
      "Format of the damage output string. Available tags are in the default, color tags such as {LIGHT_RED} and {GREEN} also work. {KILL_TO} and {KILL_FROM} indicate kills, assists and flash assists as booleans, all of which are mutually exclusive.");
  g_DamagePrintExcessCvar = CreateConVar(
      "get5_print_damage_excess", "0",
      "Prints full damage given in the damage report on round end. With this disabled (default), a player cannot take more than 100 damage.");
  g_CheckAuthsCvar =
      CreateConVar("get5_check_auths", "1",
                   "If set to 0, get5 will not force players to the correct team based on steamid");
  g_DemoNameFormatCvar = CreateConVar("get5_demo_name_format", "{TIME}_{MATCHID}_map{MAPNUMBER}_{MAPNAME}",
                                      "Format for demo file names, use \"\" to disable. Do not remove the {TIME} placeholder if you use the backup system.");
  g_DisplayGotvVetoCvar =
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
  g_KickClientImmunityCvar = CreateConVar(
      "get5_kick_immunity", "1",
      "Whether or not admins with the changemap flag will be immune to kicks from \"get5_kick_when_no_match_loaded\". Set to \"0\" to disable");
  g_KickClientsWithNoMatchCvar =
      CreateConVar("get5_kick_when_no_match_loaded", "0",
                   "Whether the plugin kicks new clients when no match is loaded");
  g_LiveCfgCvar = CreateConVar("get5_live_cfg", "get5/live.cfg",
                               "Config file to exec when the game goes live.");
  g_WarmupCfgCvar =
      CreateConVar("get5_warmup_cfg", "get5/warmup.cfg", "Config file to exec in warmup periods.");
  g_KnifeCfgCvar =
      CreateConVar("get5_knife_cfg", "get5/knife.cfg", "Config file to exec in knife periods.");
  g_LiveCountdownTimeCvar = CreateConVar(
      "get5_live_countdown_time", "10",
      "Number of seconds used to count down when a match is going live", 0, true, 5.0, true, 60.0);
  g_MaxBackupAgeCvar =
      CreateConVar("get5_max_backup_age", "160000",
                   "Number of seconds before a backup file is automatically deleted, 0 to disable");
  g_MaxTacticalPausesCvar =
      CreateConVar("get5_max_pauses", "0", "Maximum number of pauses a team can use, 0=unlimited");
  g_MaxPauseTimeCvar =
      CreateConVar("get5_max_pause_time", "300",
                   "Maximum number of time the game can spend paused by a team, 0=unlimited");
  g_MessagePrefixCvar =
      CreateConVar("get5_message_prefix", DEFAULT_TAG, "The tag applied before plugin messages.");
  g_ResetPausesEachHalfCvar =
      CreateConVar("get5_reset_pauses_each_half", "1",
                   "Whether pause limits will be reset each halftime period");
  g_PauseOnVetoCvar =
      CreateConVar("get5_pause_on_veto", "0", "Set 1 to Pause Match during Veto time");
  g_PausingEnabledCvar = CreateConVar("get5_pausing_enabled", "1", "Whether pausing is allowed.");
  g_PrettyPrintJsonCvar = CreateConVar("get5_pretty_print_json", "1",
                                       "Whether all JSON output is in pretty-print format.");
  g_ReadyTeamTagCvar =
      CreateConVar("get5_ready_team_tag", "1",
                   "Adds [READY] [NOT READY] Tags before Team Names. 0 to disable it.");
  g_ServerIdCvar = CreateConVar(
      "get5_server_id", "0",
      "Integer that identifies your server. This is used in temp files to prevent collisions.");
  g_SetClientClanTagCvar = CreateConVar("get5_set_client_clan_tags", "1",
                                        "Whether to set client clan tags to player ready status.");
  g_SetHostnameCvar = CreateConVar(
      "get5_hostname_format", "Get5: {TEAM1} vs {TEAM2}",
      "Template that the server hostname will follow when a match is live. Leave field blank to disable.");
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
      "get5_time_format", "%Y-%m-%d_%H-%M-%S",
      "Time format to use when creating file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
  g_VetoConfirmationTimeCvar = CreateConVar(
      "get5_veto_confirmation_time", "2.0",
      "Time (in seconds) from presenting a veto menu to a selection being made, during which a confirmation will be required, 0 to disable");
  g_VetoCountdownCvar =
      CreateConVar("get5_veto_countdown", "5",
                   "Seconds to countdown before veto process commences. Set to \"0\" to disable.");
  g_PrintUpdateNoticeCvar = CreateConVar(
      "get5_print_update_notice", "1",
      "Whether to print to chat when the game goes live if a new version of Get5 is available.");
  g_RoundBackupPathCvar = CreateConVar(
      "get5_backup_path", "",
      "The folder to save backup files in, relative to the csgo directory. If defined, it must not start with a slash and must end with a slash.");
  g_PhaseAnnouncementCountCvar = CreateConVar(
      "get5_phase_announcement_count", "5",
      "The number of times Get5 will print 'Knife' or 'Match is LIVE' when the game starts. Set to 0 to disable.");
  g_Team1NameColorCvar = CreateConVar("get5_team1_color", "{LIGHT_GREEN}",
                                      "The color used for the name of team 1 in chat messages.");
  g_Team2NameColorCvar = CreateConVar("get5_team2_color", "{PINK}",
                                      "The color used for the name of team 2 in chat messages.");
  g_SpecNameColorCvar = CreateConVar("get5_spec_color", "{NORMAL}",
                                     "The color used for the name of spectators in chat messages.");

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
  g_CoachingEnabledCvar.AddChangeHook(CoachingChangedHook); // used to move people off coaching if it gets disabled.

  /** Client commands **/
  g_ChatAliases = new ArrayList(ByteCountToCells(ALIAS_LENGTH));
  g_ChatAliasesCommands = new ArrayList(ByteCountToCells(COMMAND_LENGTH));
  AddAliasedCommand("r", Command_Ready, "Marks the client as ready");
  AddAliasedCommand("ready", Command_Ready, "Marks the client as ready");
  AddAliasedCommand("unready", Command_NotReady, "Marks the client as not ready");
  AddAliasedCommand("notready", Command_NotReady, "Marks the client as not ready");
  AddAliasedCommand("forceready", Command_ForceReadyClient, "Force marks clients team as ready");
  AddAliasedCommand("tech", Command_TechPause, "Calls for a tech pause");
  AddAliasedCommand("pause", Command_Pause, "Calls for a tactical pause");
  AddAliasedCommand("tac", Command_Pause, "Alias of pause");
  AddAliasedCommand("unpause", Command_Unpause, "Unpauses the game");
  AddAliasedCommand("coach", Command_SmCoach, "Marks a client as a coach for their team");
  AddAliasedCommand("stay", Command_Stay,
                    "Elects to stay on the current team after winning a knife round");
  AddAliasedCommand("swap", Command_Swap,
                    "Elects to swap the current teams after winning a knife round");
  AddAliasedCommand("switch", Command_Swap,
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
  RegAdminCmd("get5_addcoach", Command_AddCoach, ADMFLAG_CHANGEMAP,
              "Adds a steamid to a match teams coach slot");
  RegAdminCmd("get5_removeplayer", Command_RemovePlayer, ADMFLAG_CHANGEMAP,
              "Removes a steamid from a match team");
  RegAdminCmd("get5_addkickedplayer", Command_AddKickedPlayer, ADMFLAG_CHANGEMAP,
              "Adds the last kicked steamid to a match team");
  RegAdminCmd("get5_removekickedplayer", Command_RemoveKickedPlayer, ADMFLAG_CHANGEMAP,
              "Removes the last kicked steamid from a match team");
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
  HookEvent("cs_win_panel_match", Event_MatchOver);
  HookEvent("cs_win_panel_round", Event_RoundWinPanel, EventHookMode_Pre);
  HookEvent("player_connect_full", Event_PlayerConnectFull);
  HookEvent("player_disconnect", Event_PlayerDisconnect);
  HookEvent("player_spawn", Event_PlayerSpawn);
  HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
  HookEvent("round_freeze_end", Event_FreezeEnd);
  HookEvent("round_prestart", Event_RoundPreStart);
  HookEvent("round_start", Event_RoundStart);
  HookEvent("server_cvar", Event_CvarChanged, EventHookMode_Pre);

  Stats_PluginStart();
  Stats_InitSeries();

  AddCommandListener(Command_Coach, "coach");
  AddCommandListener(Command_JoinTeam, "jointeam");
  AddCommandListener(Command_JoinGame, "joingame");
  AddCommandListener(Command_PauseOrUnpauseMatch, "mp_pause_match");
  AddCommandListener(Command_PauseOrUnpauseMatch, "mp_unpause_match");

  /** Setup data structures **/
  g_MapPoolList = new ArrayList(PLATFORM_MAX_PATH);
  g_MapsLeftInVetoPool = new ArrayList(PLATFORM_MAX_PATH);
  g_MapsToPlay = new ArrayList(PLATFORM_MAX_PATH);
  g_MapSides = new ArrayList();
  g_CvarNames = new ArrayList(MAX_CVAR_LENGTH);
  g_CvarValues = new ArrayList(MAX_CVAR_LENGTH);
  g_TeamScoresPerMap = new ArrayList(MATCHTEAM_COUNT);

  for (int i = 0; i < sizeof(g_TeamAuths); i++) {
    g_TeamAuths[i] = new ArrayList(AUTH_LENGTH);
    // Same length.
    g_TeamCoaches[i] = new ArrayList(AUTH_LENGTH);
  }
  g_PlayerNames = new StringMap();
  g_FlashbangContainer = new StringMap();
  g_HEGrenadeContainer = new StringMap();
  g_MolotovContainer = new StringMap();

  /** Create forwards **/
  g_OnBackupRestore = CreateGlobalForward("Get5_OnBackupRestore", ET_Ignore, Param_Cell);
  g_OnDemoFinished = CreateGlobalForward("Get5_OnDemoFinished", ET_Ignore, Param_Cell);
  g_OnEvent = CreateGlobalForward("Get5_OnEvent", ET_Ignore, Param_Cell, Param_String);
  g_OnFlashbangDetonated = CreateGlobalForward("Get5_OnFlashbangDetonated", ET_Ignore, Param_Cell);
  g_OnHEGrenadeDetonated = CreateGlobalForward("Get5_OnHEGrenadeDetonated", ET_Ignore, Param_Cell);
  g_OnDecoyStarted = CreateGlobalForward("Get5_OnDecoyStarted", ET_Ignore, Param_Cell);
  g_OnSmokeGrenadeDetonated =
      CreateGlobalForward("Get5_OnSmokeGrenadeDetonated", ET_Ignore, Param_Cell);
  g_OnMolotovDetonated = CreateGlobalForward("Get5_OnMolotovDetonated", ET_Ignore, Param_Cell);
  g_OnGameStateChanged = CreateGlobalForward("Get5_OnGameStateChanged", ET_Ignore, Param_Cell);
  g_OnGoingLive = CreateGlobalForward("Get5_OnGoingLive", ET_Ignore, Param_Cell);
  g_OnGrenadeThrown = CreateGlobalForward("Get5_OnGrenadeThrown", ET_Ignore, Param_Cell);
  g_OnMapResult = CreateGlobalForward("Get5_OnMapResult", ET_Ignore, Param_Cell);
  g_OnPlayerConnected = CreateGlobalForward("Get5_OnPlayerConnected", ET_Ignore, Param_Cell);
  g_OnPlayerDisconnected = CreateGlobalForward("Get5_OnPlayerDisconnected", ET_Ignore, Param_Cell);
  g_OnPlayerDeath = CreateGlobalForward("Get5_OnPlayerDeath", ET_Ignore, Param_Cell);
  g_OnPlayerSay = CreateGlobalForward("Get5_OnPlayerSay", ET_Ignore, Param_Cell);
  g_OnPlayerBecameMVP = CreateGlobalForward("Get5_OnPlayerBecameMVP", ET_Ignore, Param_Cell);
  g_OnBombDefused = CreateGlobalForward("Get5_OnBombDefused", ET_Ignore, Param_Cell);
  g_OnBombPlanted = CreateGlobalForward("Get5_OnBombPlanted", ET_Ignore, Param_Cell);
  g_OnBombExploded = CreateGlobalForward("Get5_OnBombExploded", ET_Ignore, Param_Cell);
  g_OnRoundStart = CreateGlobalForward("Get5_OnRoundStart", ET_Ignore, Param_Cell);
  g_OnRoundEnd = CreateGlobalForward("Get5_OnRoundEnd", ET_Ignore, Param_Cell);
  g_OnLoadMatchConfigFailed =
      CreateGlobalForward("Get5_OnLoadMatchConfigFailed", ET_Ignore, Param_Cell);
  g_OnMapPicked = CreateGlobalForward("Get5_OnMapPicked", ET_Ignore, Param_Cell);
  g_OnMapVetoed = CreateGlobalForward("Get5_OnMapVetoed", ET_Ignore, Param_Cell);
  g_OnSidePicked = CreateGlobalForward("Get5_OnSidePicked", ET_Ignore, Param_Cell);
  g_OnTeamReadyStatusChanged =
      CreateGlobalForward("Get5_OnTeamReadyStatusChanged", ET_Ignore, Param_Cell);
  g_OnKnifeRoundStarted = CreateGlobalForward("Get5_OnKnifeRoundStarted", ET_Ignore, Param_Cell);
  g_OnKnifeRoundWon = CreateGlobalForward("Get5_OnKnifeRoundWon", ET_Ignore, Param_Cell);
  g_OnRoundStatsUpdated = CreateGlobalForward("Get5_OnRoundStatsUpdated", ET_Ignore, Param_Cell);
  g_OnPreLoadMatchConfig = CreateGlobalForward("Get5_OnPreLoadMatchConfig", ET_Ignore, Param_Cell);
  g_OnSeriesInit = CreateGlobalForward("Get5_OnSeriesInit", ET_Ignore, Param_Cell);
  g_OnSeriesResult = CreateGlobalForward("Get5_OnSeriesResult", ET_Ignore, Param_Cell);
  g_OnMatchPaused = CreateGlobalForward("Get5_OnMatchPaused", ET_Ignore, Param_Cell);
  g_OnMatchUnpaused = CreateGlobalForward("Get5_OnMatchUnpaused", ET_Ignore, Param_Cell);

  /** Start any repeating timers **/
  CreateTimer(CHECK_READY_TIMER_INTERVAL, Timer_CheckReady, _, TIMER_REPEAT);
  CreateTimer(INFO_MESSAGE_TIMER_INTERVAL, Timer_InfoMessages, _, TIMER_REPEAT);

  CheckForLatestVersion();
}

public Action Timer_InfoMessages(Handle timer) {
  if (g_GameState == Get5State_Live || g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  char readyCommandFormatted[64];
  FormatChatCommand(readyCommandFormatted, sizeof(readyCommandFormatted), "!ready");

  // Handle pre-veto messages
  if (g_GameState == Get5State_PreVeto) {
    if (IsTeamsReady() && !IsSpectatorsReady()) {
      Get5_MessageToAll("%t", "WaitingForCastersReadyInfoMessage",
                        g_FormattedTeamNames[Get5Team_Spec], readyCommandFormatted);
    } else {
      Get5_MessageToAll("%t", "ReadyToVetoInfoMessage", readyCommandFormatted);
    }
    MissingPlayerInfoMessage();
  } else if (g_GameState == Get5State_Warmup && !g_MapChangePending) {
    // Handle warmup state, provided we're not waiting for a map change
    // Backups take priority
    if (!IsTeamsReady() && g_WaitingForRoundBackup) {
      Get5_MessageToAll("%t", "ReadyToRestoreBackupInfoMessage", readyCommandFormatted);
      return Plugin_Continue;
    }

    // Find out what we're waiting for
    if (IsTeamsReady() && !IsSpectatorsReady()) {
      Get5_MessageToAll("%t", "WaitingForCastersReadyInfoMessage",
                        g_FormattedTeamNames[Get5Team_Spec], readyCommandFormatted);
    } else {
      if (g_MapSides.Get(Get5_GetMapNumber()) == SideChoice_KnifeRound) {
        Get5_MessageToAll("%t", "ReadyToKnifeInfoMessage", readyCommandFormatted);
      } else {
        Get5_MessageToAll("%t", "ReadyToStartInfoMessage", readyCommandFormatted);
      }
    }
    MissingPlayerInfoMessage();
  } else if (g_DisplayGotvVetoCvar.BoolValue && g_GameState == Get5State_Warmup &&
             g_MapChangePending && GetTvDelay() > 0) {
    Get5_MessageToAll("%t", "WaitingForGOTVVetoInfoMessage");
  } else if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    // Handle waiting for knife decision
    char formattedStayCommand[64];
    FormatChatCommand(formattedStayCommand, sizeof(formattedStayCommand), "!stay");
    char formattedSwapCommand[64];
    FormatChatCommand(formattedSwapCommand, sizeof(formattedSwapCommand), "!swap");
    Get5_MessageToAll("%t", "WaitingForEnemySwapInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam], formattedStayCommand,
                      formattedSwapCommand);
  } else if (g_GameState == Get5State_PostGame && GetTvDelay() > 0) {
    // Handle postgame
    Get5_MessageToAll("%t", "WaitingForGOTVBrodcastEndingInfoMessage");
  }

  return Plugin_Continue;
}

public void OnClientAuthorized(int client, const char[] auth) {
  SetClientReady(client, false);
  if (StrEqual(auth, "BOT", false)) {
    return;
  }

  if (g_GameState != Get5State_None && g_CheckAuthsCvar.BoolValue) {
    Get5Team team = GetClientMatchTeam(client);
    if (team == Get5Team_None) {
      RememberAndKickClient(client, "%t", "YouAreNotAPlayerInfoMessage");
    } else if (CountPlayersOnTeam(team, client) >= g_PlayersPerTeam
      && (!g_CoachingEnabledCvar.BoolValue || CountCoachesOnTeam(team, client) >= g_CoachesPerTeam)) {
      KickClient(client, "%t", "TeamIsFullInfoMessage");
    }
  }
}

public void RememberAndKickClient(int client, const char[] format, const char[] translationPhrase) {
  GetAuth(client, g_LastKickedPlayerAuth, sizeof(g_LastKickedPlayerAuth));
  KickClient(client, format, translationPhrase);
}

public void OnClientPutInServer(int client) {
  Stats_HookDamageForClient(client); // Also needed for bots!
  if (IsFakeClient(client)) {
    return;
  }

  // If a player joins during freezetime, ensure their round stats are 0, as there will be no round-start event to do it.
  // Maybe this could just be freezetime end?
  Stats_ResetClientRoundValues(client);

  // This checks for gamestate none and pending backup on its own.
  if (CheckAutoLoadConfig()) {
    return;
  }

  // Because OnConfigsExecuted may run before a client is on the server, we have to repeat the logic here when the
  // first client connects.
  if ((g_GameState <= Get5State_Warmup || g_WaitingForRoundBackup) && g_GameState != Get5State_None) {
    if (GetRealClientCount() <= 1) {
      ChangeState(Get5State_Warmup);
      ExecCfg(g_WarmupCfgCvar);
      StartWarmup();
    }
  }
}

public void OnClientPostAdminCheck(int client) {
  if (IsPlayer(client)) {
    if (g_GameState == Get5State_None && g_KickClientsWithNoMatchCvar.BoolValue) {
      if (!g_KickClientImmunityCvar.BoolValue ||
          !CheckCommandAccess(client, "get5_kickcheck", ADMFLAG_CHANGEMAP)) {
        KickClient(client, "%t", "NoMatchSetupInfoMessage");
      }
    }
  }
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (g_GameState != Get5State_None &&
      (StrEqual(command, "say") || StrEqual(command, "say_team"))) {
    if (IsValidClient(client)) {
      Get5PlayerSayEvent event =
          new Get5PlayerSayEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(),
                                 GetPlayerObject(client), command, sArgs);

      LogDebug("Calling Get5_OnPlayerSay()");

      Call_StartForward(g_OnPlayerSay);
      Call_PushCell(event);
      Call_Finish();

      EventLogger_LogAndDeleteEvent(event);
    }
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
  if (IsValidClient(client)) {
    char ipAddress[32];
    GetClientIP(client, ipAddress, sizeof(ipAddress));

    Get5PlayerConnectedEvent connectEvent =
        new Get5PlayerConnectedEvent(GetPlayerObject(client), ipAddress);

    LogDebug("Calling Get5_OnPlayerConnected()");

    Call_StartForward(g_OnPlayerConnected);
    Call_PushCell(connectEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(connectEvent);

    SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
  }
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));

  if (client > 0) {
    Get5PlayerDisconnectedEvent disconnectEvent =
        new Get5PlayerDisconnectedEvent(GetPlayerObject(client));

    LogDebug("Calling Get5_OnPlayerDisconnected()");

    Call_StartForward(g_OnPlayerDisconnected);
    Call_PushCell(disconnectEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(disconnectEvent);
  }

  // TODO: consider adding a forfeit if a full team disconnects.
  if (g_EndMatchOnEmptyServerCvar.BoolValue && g_GameState >= Get5State_Warmup &&
      g_GameState < Get5State_PostGame && GetRealClientCount() == 0 && !g_MapChangePending) {
    g_TeamSeriesScores[Get5Team_1] = 0;
    g_TeamSeriesScores[Get5Team_2] = 0;
    StopRecording();
    EndSeries(Get5Team_None, false, 0.0, false);
  }
}

// This runs every time a map starts *or* when the plugin is reloaded.
public void OnConfigsExecuted() {
  LogDebug("OnConfigsExecuted");
  g_MapChangePending = false;
  g_DoingBackupRestoreNow = false;
  g_ReadyTimeWaitingUsed = 0;
  g_HasKnifeRoundStarted = false;
  // Recording is always automatically stopped on map change, and
  // since there are no hooks to detect tv_stoprecord, we reset
  // our recording var if a map change is performed unexpectedly.
  g_DemoFileName = "";
  DeleteOldBackups();

  // Always reset ready status on map start
  ResetReadyStatus();

  if (CheckAutoLoadConfig()) {
    // If gamestate is none and a config was autoloaded, a match config will set all of the below state.
    return;
  }

  LOOP_TEAMS(team) {
    g_TeamGivenStopCommand[team] = false;
    g_TeamReadyForUnpause[team] = false;
    // We don't need to check for g_WaitingForRoundBackup here, as a backup will override the pauses consumed anyway; if
    // the map is changed, we always load the backup pauses. See the RestoreFromBackup function.
    g_TacticalPauseTimeUsed[team] = 0;
    g_TacticalPausesUsed[team] = 0;
    g_TechnicalPausesUsed[team] = 0;
  }

  // On map start, always put the game in warmup mode.
  // When executing a backup load, the live config is loaded and warmup ends after players ready-up again.
  if (g_GameState != Get5State_None) {
    LogDebug("Putting game into warmup in OnConfigsExecuted.");
    ChangeState(Get5State_Warmup);
    ExecCfg(g_WarmupCfgCvar);
    StartWarmup();
  }
  // This must not be called when waiting for a backup, as it will set the sides incorrectly if the team swapped in
  // knife or if the backup target is the second half.
  if (!g_WaitingForRoundBackup) {
    SetStartingTeams();
  }
}

public Action Timer_CheckReady(Handle timer) {
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  if (g_DoingBackupRestoreNow) {
    LogDebug("Timer_CheckReady: Waiting for restore");
    return Plugin_Continue;
  }

  CheckTeamNameStatus(Get5Team_1);
  CheckTeamNameStatus(Get5Team_2);
  UpdateClanTags();

  // Handle ready checks for pre-veto state
  if (g_GameState == Get5State_PreVeto) {
    if (IsTeamsReady()) {
      // We don't wait for spectators when initiating veto
      LogDebug("Timer_CheckReady: starting veto");
      ChangeState(Get5State_Veto);
      RestartGame();
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
      if (g_MapSides.Get(Get5_GetMapNumber()) == SideChoice_KnifeRound) {
        LogDebug("Timer_CheckReady: starting with a knife round");
        StartGame(true);
      } else {
        LogDebug("Timer_CheckReady: starting without a knife round");
        StartGame(false);
      }
      StartRecording();
    } else {
      CheckReadyWaitingTimes();
    }
  }

  return Plugin_Continue;
}

static void CheckReadyWaitingTimes() {
  if (g_TeamTimeToStartCvar.IntValue > 0) {
    g_ReadyTimeWaitingUsed++;

    bool team1Forfeited = CheckReadyWaitingTime(Get5Team_1);
    bool team2Forfeited = CheckReadyWaitingTime(Get5Team_2);

    if (team1Forfeited || team2Forfeited) {
      Stats_Forfeit();
      float minDelay = 5.0;
      StopRecording(minDelay);
      float endDelay = float(GetTvDelay());
      if (endDelay < minDelay) {
        endDelay = minDelay;
      }
      if (team1Forfeited && team2Forfeited) {
        EndSeries(Get5Team_None, false, endDelay);
      } else if (team1Forfeited) {
        EndSeries(Get5Team_2, false, endDelay);
      } else {
        EndSeries(Get5Team_1, false, endDelay);
      }
    }
  }
}

static bool CheckReadyWaitingTime(Get5Team team) {
  if (!IsTeamReady(team) && g_GameState != Get5State_None) {
    int timeLeft = g_TeamTimeToStartCvar.IntValue - g_ReadyTimeWaitingUsed;

    if (timeLeft <= 0) {
      Get5_MessageToAll("%t", "TeamForfeitInfoMessage", g_FormattedTeamNames[team]);
      return true;
    } else if (timeLeft >= 300 && timeLeft % 60 == 0) {
      Get5_MessageToAll("%t", "MinutesToForfeitMessage", g_FormattedTeamNames[team], timeLeft / 60);

    } else if (timeLeft < 300 && timeLeft % 30 == 0) {
      Get5_MessageToAll("%t", "SecondsToForfeitInfoMessage", g_FormattedTeamNames[team], timeLeft);

    } else if (timeLeft == 10) {
      Get5_MessageToAll("%t", "10SecondsToForfeitInfoMessage", g_FormattedTeamNames[team],
                        timeLeft);
    }
  }
  return false;
}

static bool CheckAutoLoadConfig() {
  if (g_GameState == Get5State_None && !g_WaitingForRoundBackup) {
    char autoloadConfig[PLATFORM_MAX_PATH];
    g_AutoLoadConfigCvar.GetString(autoloadConfig, sizeof(autoloadConfig));
    if (!StrEqual(autoloadConfig, "")) {
      bool loaded = LoadMatchConfig(autoloadConfig); // return false if match config load fails!
      if (loaded) {
        LogMessage("Match configuration was loaded via get5_autoload_config.");
      }
      return loaded;
    }
  }
  return false;
}

/**
 * Client and server commands.
 */

public Action Command_EndMatch(int client, int args) {
  if (g_GameState == Get5State_None) {
    ReplyToCommand(client, "No match is configured; nothing to end.");
    return Plugin_Handled;
  }

  Get5Team winningTeam = Get5Team_None;  // defaults to tie
  if (args >= 1) {
    char forcedWinningTeam[8];
    GetCmdArg(1, forcedWinningTeam, sizeof(forcedWinningTeam));
    if (StrEqual("team1", forcedWinningTeam, false)) {
      winningTeam = Get5Team_1;
    } else if (StrEqual("team2", forcedWinningTeam, false)) {
      winningTeam = Get5Team_2;
    } else {
      ReplyToCommand(client, "Usage: get5_endmatch <team1|team2> (omit team for tie)");
      return Plugin_Handled;
    }
  }

  if (IsPaused()) {
    UnpauseGame(Get5Team_None);
  }

  // Call game-ending forwards.
  g_MapChangePending = false;
  int team1score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1));
  int team2score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2));

  Get5MapResultEvent mapResultEvent = new Get5MapResultEvent(
      g_MatchID, g_MapNumber,
      new Get5Winner(winningTeam, view_as<Get5Side>(Get5TeamToCSTeam(winningTeam))), team1score,
      team2score);

  LogDebug("Calling Get5_OnMapResult()");
  Call_StartForward(g_OnMapResult);
  Call_PushCell(mapResultEvent);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(mapResultEvent);

  StopRecording(1.0); // must go before EndSeries as it depends on g_MatchID.

  // No delay required when not kicking players.
  EndSeries(winningTeam, false, 0.0, false);

  UpdateClanTags();

  if (winningTeam == Get5Team_None) {
    Get5_MessageToAll("%t", "AdminForceEndInfoMessage");
  } else {
    Get5_MessageToAll("%t", "AdminForceEndWithWinnerInfoMessage",
                      g_FormattedTeamNames[winningTeam]);
  }

  if (g_ActiveVetoMenu != null) {
    g_ActiveVetoMenu.Cancel();
  }

  if (g_KnifeCountdownTimer != INVALID_HANDLE) {
    LogDebug("Killing knife announce countdown timer.");
    delete g_KnifeCountdownTimer;
  }

  if (g_KnifeDecisionTimer != INVALID_HANDLE) {
    LogDebug("Killing knife decision timer.");
    delete g_KnifeDecisionTimer;
  }

  RestartGame();

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
      } else {
        ReplyToCommand(client, "Match config loading initialized.");
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

  if (DumpToFilePath(arg)) {
    g_StatsKv.Rewind();
    ReplyToCommand(client, "Saved match stats to %s", arg);
  } else {
    ReplyToCommand(client, "Failed to save match stats to %s", arg);
  }

  return Plugin_Handled;
}

public Action Command_Stop(int client, int args) {
  if (!g_StopCommandEnabledCvar.BoolValue) {
    Get5_MessageToAll("%t", "StopCommandNotEnabled");
    return Plugin_Handled;
  }

  if (g_GameState != Get5State_Live || g_PendingSideSwap == true) {
    return Plugin_Handled;
  }

  // Let the server/rcon always force restore.
  if (client == 0) {
    RestoreLastRound(client);
    return Plugin_Handled;
  }

  if (g_PauseType == Get5PauseType_Admin) {
    // Don't let teams restore backups while an admin has paused the game.
    return Plugin_Handled;
  }

  Get5Team team = GetClientMatchTeam(client);
  g_TeamGivenStopCommand[team] = true;

  char stopCommandFormatted[64];
  FormatChatCommand(stopCommandFormatted, sizeof(stopCommandFormatted), "!stop");
  if (g_TeamGivenStopCommand[Get5Team_1] && !g_TeamGivenStopCommand[Get5Team_2]) {
    Get5_MessageToAll("%t", "TeamWantsToReloadCurrentRound",
                      g_FormattedTeamNames[Get5Team_1], g_FormattedTeamNames[Get5Team_2],
                      stopCommandFormatted);
  } else if (!g_TeamGivenStopCommand[Get5Team_1] && g_TeamGivenStopCommand[Get5Team_2]) {
    Get5_MessageToAll("%t", "TeamWantsToReloadCurrentRound",
                      g_FormattedTeamNames[Get5Team_2], g_FormattedTeamNames[Get5Team_1],
                      stopCommandFormatted);
  } else if (g_TeamGivenStopCommand[Get5Team_1] && g_TeamGivenStopCommand[Get5Team_2]) {
    RestoreLastRound(client);
  }

  return Plugin_Handled;
}

public void RestoreLastRound(int client) {
  LOOP_TEAMS(x) {
    g_TeamGivenStopCommand[x] = false;
  }

  char lastBackup[PLATFORM_MAX_PATH];
  g_LastGet5BackupCvar.GetString(lastBackup, sizeof(lastBackup));
  if (!StrEqual(lastBackup, "")) {
    if (RestoreFromBackup(lastBackup, false)) {
      Get5_MessageToAll("%t", "BackupLoadedInfoMessage", lastBackup);
      // Fix the last backup cvar since it gets reset.
      g_LastGet5BackupCvar.SetString(lastBackup);
    } else {
      ReplyToCommand(client, "Failed to load backup %s - check error logs", lastBackup);
    }
  } else {
    ReplyToCommand(client, "Failed to load backup, as previous round backup does not exist.");
  }
}

/**
 * Game Events *not* related to the stats tracking system.
 */

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_None && g_GameState < Get5State_KnifeRound) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    CreateTimer(0.1, Timer_ReplenishMoney, client, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action Timer_ReplenishMoney(Handle timer, int client) {
  if (IsPlayer(client) && OnActiveTeam(client)) {
    SetEntProp(client, Prop_Send, "m_iAccount", GetCvarIntSafe("mp_maxmoney"));
  }
}

public Action Event_MatchOver(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_MatchOver");
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }

  // This ensures that the mp_match_restart_delay is not shorter
  // than what is required for the GOTV recording to finish.
  float restartDelay = GetCurrentMatchRestartDelay();
  float requiredDelay = float(GetTvDelay() + MATCH_END_DELAY_AFTER_TV);
  if (requiredDelay > restartDelay) {
    LogDebug("Extended mp_match_restart_delay from %f to %f to ensure GOTV broadcast can finish.",
             restartDelay, requiredDelay);
    SetCurrentMatchRestartDelay(requiredDelay);
    restartDelay = requiredDelay;  // reassigned because we reuse the variable below.
  }
  StopRecording(float(MATCH_END_DELAY_AFTER_TV));

  if (g_GameState == Get5State_Live) {
    // If someone called for a pause in the last round; cancel it.
    if (IsPaused()) {
      UnpauseGame(Get5Team_None);
    }
    // Figure out who won
    int t1score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1));
    int t2score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2));
    Get5Team winningTeam = Get5Team_None;
    if (t1score > t2score) {
      winningTeam = Get5Team_1;
    } else if (t2score > t1score) {
      winningTeam = Get5Team_2;
    }

    // If the round ends because the match is over, we clear the grenade container immediately as they will not fire
    // on their own if the game state is not live.
    Stats_ResetGrenadeContainers();

    // Update series scores
    Stats_UpdateMapScore(winningTeam);
    g_TeamSeriesScores[winningTeam]++;

    g_TeamScoresPerMap.Set(g_MapNumber, t1score, view_as<int>(Get5Team_1));
    g_TeamScoresPerMap.Set(g_MapNumber, t2score, view_as<int>(Get5Team_2));

    Get5MapResultEvent mapResultEvent = new Get5MapResultEvent(
        g_MatchID, g_MapNumber,
        new Get5Winner(winningTeam, view_as<Get5Side>(Get5TeamToCSTeam(winningTeam))), t1score,
        t2score);

    LogDebug("Calling Get5_OnMapResult()");

    Call_StartForward(g_OnMapResult);
    Call_PushCell(mapResultEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(mapResultEvent);

    int t1maps = g_TeamSeriesScores[Get5Team_1];
    int t2maps = g_TeamSeriesScores[Get5Team_2];
    int tiedMaps = g_TeamSeriesScores[Get5Team_None];
    int remainingMaps = g_MapsToPlay.Length - t1maps - t2maps - tiedMaps;

    if (t1maps == t2maps) {
      // As long as team scores are equal, we play until there are no maps left, regardless of
      // clinch config.
      if (remainingMaps <= 0) {
        EndSeries(Get5Team_None, true, restartDelay);
        return Plugin_Continue;
      }
    } else if (g_SeriesCanClinch) {
      // This adjusts for ties!
      int actualMapsToWin = MapsToWin(g_MapsToPlay.Length - tiedMaps);
      if (t1maps == actualMapsToWin) {
        // Team 1 won
        EndSeries(Get5Team_1, true, restartDelay);
        return Plugin_Continue;
      } else if (t2maps == actualMapsToWin) {
        // Team 2 won
        EndSeries(Get5Team_2, true, restartDelay);
        return Plugin_Continue;
      }
    } else if (remainingMaps <= 0) {
      EndSeries(t1maps > t2maps ? Get5Team_1 : Get5Team_2, true,
                restartDelay);  // Tie handled in first if-block
      return Plugin_Continue;
    }

    if (t1maps > t2maps) {
      Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage", g_FormattedTeamNames[Get5Team_1],
                        t1maps, t2maps);

    } else if (t2maps > t1maps) {
      Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage", g_FormattedTeamNames[Get5Team_2],
                        t2maps, t1maps);

    } else {
      Get5_MessageToAll("%t", "SeriesTiedInfoMessage", t1maps, t2maps);
    }

    char nextMap[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(Get5_GetMapNumber(), nextMap, sizeof(nextMap));

    char timeToMapChangeFormatted[8];
    convertSecondsToMinutesAndSeconds(RoundToFloor(restartDelay), timeToMapChangeFormatted,
                                      sizeof(timeToMapChangeFormatted));

    g_MapChangePending = true;
    FormatMapName(nextMap, nextMap, sizeof(nextMap), true, true);
    Get5_MessageToAll("%t", "NextSeriesMapInfoMessage", nextMap, timeToMapChangeFormatted);
    ChangeState(Get5State_PostGame);
    // Subtracting 4 seconds makes the map change 1 second before the timer expires, as there is a 3
    // second built-in delay in the ChangeMap function called by Timer_NextMatchMap.
    CreateTimer(restartDelay - 4, Timer_NextMatchMap);
  }

  return Plugin_Continue;
}

public Action Timer_NextMatchMap(Handle timer) {
  char map[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(Get5_GetMapNumber(), map, sizeof(map));
  // If you change these 3 seconds for whatever reason, you must adjust the counter-offset in
  // Event_MatchOver.
  ChangeMap(map, 3.0);
}

void EndSeries(Get5Team winningTeam, bool printWinnerMessage, float restoreDelay,
               bool kickPlayers = true) {
  Stats_SeriesEnd(winningTeam);

  if (printWinnerMessage) {
    if (winningTeam == Get5Team_None) {
      Get5_MessageToAll("%t", "TeamTiedMatchInfoMessage", g_FormattedTeamNames[Get5Team_1],
                        g_FormattedTeamNames[Get5Team_2]);
    } else {
      if (g_MapsToPlay.Length == 1) {
        Get5_MessageToAll("%t", "TeamWonMatchInfoMessage", g_FormattedTeamNames[winningTeam]);
      } else {
        Get5_MessageToAll("%t", "TeamWonSeriesInfoMessage", g_FormattedTeamNames[winningTeam],
                          g_TeamSeriesScores[winningTeam],
                          g_TeamSeriesScores[OtherMatchTeam(winningTeam)]);
      }
    }
  }

  Get5SeriesResultEvent event = new Get5SeriesResultEvent(
      g_MatchID, new Get5Winner(winningTeam, view_as<Get5Side>(Get5TeamToCSTeam(winningTeam))),
      g_TeamSeriesScores[Get5Team_1], g_TeamSeriesScores[Get5Team_2]);

  LogDebug("Calling Get5_OnSeriesResult()");

  Call_StartForward(g_OnSeriesResult);
  Call_PushCell(event);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(event);
  ChangeState(Get5State_None);
  g_MatchID = "";

  // We don't want to kick players until after the specified delay, as it will kick casters
  // potentially before GOTV ends.
  if (kickPlayers && g_KickClientsWithNoMatchCvar.BoolValue) {
    if (restoreDelay < 0.1) {
      KickPlayers();
    } else {
      CreateTimer(restoreDelay, Timer_KickOnEnd, _, TIMER_FLAG_NO_MAPCHANGE);
    }
  }

  if (restoreDelay < 0.1) {
    // When force-ending the match there is no delay.
    RestoreCvars(g_MatchConfigChangedCvars);
  } else {
    // If we restore cvars immediately, it might change the tv_ params or set the
    // mp_match_restart_delay to something lower, which is noticed by the game and may trigger a map
    // change before GOTV broadcast ends, so we don't do this until the current match restart delay
    // has passed.
    CreateTimer(restoreDelay, Timer_RestoreMatchCvars, _, TIMER_FLAG_NO_MAPCHANGE);
  }
}

public Action Timer_KickOnEnd(Handle timer) {
  if (g_GameState == Get5State_None) {
    // If a match was started before this event is triggered, don't do anything.
    KickPlayers();
  }
  return Plugin_Handled;
}

static void KickPlayers() {
  bool kickImmunity = g_KickClientImmunityCvar.BoolValue;
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) &&
        !(kickImmunity && CheckCommandAccess(i, "get5_kickcheck", ADMFLAG_CHANGEMAP))) {
      KickClient(i, "%t", "MatchFinishedInfoMessage");
    }
  }
}

public Action Timer_RestoreMatchCvars(Handle timer) {
  if (g_GameState == Get5State_None) {
    // Only reset if no game is running, otherwise a game started before the restart delay for
    // another ends will mess this up.
    RestoreCvars(g_MatchConfigChangedCvars);
  }
  return Plugin_Handled;
}

public Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundPreStart");

  if (g_GameState == Get5State_Live) {
    // End lingering grenade trackers from previous round.
    Stats_ResetGrenadeContainers();
  }

  if (g_PendingSideSwap) {
    SwapSides();
  }
  g_PendingSideSwap = false;

  Stats_ResetRoundValues();

  // We need this for events that fire after the map ends, such as grenades detonating (or someone
  // dying in fire), to be correct. It's sort of an edge-case, but due to how Get5_GetMapNumber
  // works, it will return +1 if called after a map has been decided, but before the game actually
  // stops, which could lead to events having the wrong map number, so we set both of these here and
  // not in round_end
  g_MapNumber = Get5_GetMapNumber();
  // Round number always -1 if not live.
  g_RoundNumber = g_GameState != Get5State_Live ? -1 : GetRoundsPlayed();

  return Plugin_Continue;
}

public Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_FreezeEnd");

  // If someone changes the map while in a pause, we have to make sure we reset this state, as the
  // UnpauseGame function will not be called to do it. FreezeTimeEnd is always called when the map
  // initially loads.
  g_LatestPauseDuration = 0;
  g_PauseType = Get5PauseType_None;
  g_PausingTeam = Get5Team_None;

  // We always want this to be correct, regardless of game state.
  g_RoundStartedTime = GetEngineTime();
  if (g_GameState == Get5State_Live && !g_DoingBackupRestoreNow && !g_WaitingForRoundBackup) {
    Stats_RoundStart();
  }
}

static bool CreateDirectoryWithPermissions(const char[] directory) {
  LogDebug("Creating directory: %s", directory);
  return CreateDirectory(directory,  // sets 777 permissions.
                         FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ |
                             FPERM_G_WRITE | FPERM_G_EXEC | FPERM_O_READ | FPERM_O_WRITE |
                             FPERM_O_EXEC);
}

static bool CreateBackupFolderStructure(const char[] path) {
  if (strlen(path) == 0 || DirExists(path)) {
    return true;
  }

  LogDebug("Creating backup directory %s because it does not exist.", path);
  char folders[16][PLATFORM_MAX_PATH];  // {folder1, folder2, etc}
  char fullFolderPath[PLATFORM_MAX_PATH] =
      "";  // initially empty, but we append every time a folder is created/verified
  char currentFolder[PLATFORM_MAX_PATH];  // shorthand for folders[i]

  ExplodeString(path, "/", folders, sizeof(folders), PLATFORM_MAX_PATH, true);
  for (int i = 0; i < sizeof(folders); i++) {
    currentFolder = folders[i];
    if (strlen(currentFolder) ==
        0) {  // as the loop is a fixed size, we stop when there are no more pieces.
      break;
    }
    // Append the current folder to the full path
    Format(fullFolderPath, sizeof(fullFolderPath), "%s%s/", fullFolderPath, currentFolder);
    if (!DirExists(fullFolderPath) && !CreateDirectoryWithPermissions(fullFolderPath)) {
      LogError("Failed to create or verify existence of directory: %s", fullFolderPath);
      return false;
    }
  }
  return true;
}

public void WriteBackup() {
  if (!g_BackupSystemEnabledCvar.BoolValue || g_DoingBackupRestoreNow || g_WaitingForRoundBackup) {
    return;
  }

  char folder[PLATFORM_MAX_PATH];
  g_RoundBackupPathCvar.GetString(folder, sizeof(folder));
  ReplaceString(folder, sizeof(folder), "{MATCHID}", g_MatchID);

  int backupFolderLength = strlen(folder);
  if (backupFolderLength > 0 &&
      (folder[0] == '/' || folder[0] == '.' || folder[backupFolderLength - 1] != '/' ||
       StrContains(folder, "//") != -1)) {
    LogError(
        "get5_backup_path must end with a slash and must not start with a slash or dot. It will be reset to an empty string! Current value: %s",
        folder);
    folder = "";
    g_RoundBackupPathCvar.SetString(folder, false, false);
  } else {
    CreateBackupFolderStructure(folder);
  }

  char path[PLATFORM_MAX_PATH];
  if (g_GameState == Get5State_Live) {
    Format(path, sizeof(path), "%sget5_backup_match%s_map%d_round%d.cfg", folder, g_MatchID,
           g_MapNumber, g_RoundNumber);
  } else {
    Format(path, sizeof(path), "%sget5_backup_match%s_map%d_prelive.cfg", folder, g_MatchID,
           g_MapNumber);
  }
  LogDebug("Writing backup to %s", path);
  WriteBackupStructure(path);
  g_LastGet5BackupCvar.SetString(path);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundStart");

  // Always reset these on round start, regardless of game state.
  // This ensures that the functions that rely on these don't get messed up.
  g_RoundStartedTime = 0.0;
  g_BombPlantedTime = 0.0;
  g_BombSiteLastPlanted = Get5BombSite_Unknown;

  if (g_WaitingForRoundBackup) {
    return;
  }

  // We cannot do this during warmup, as sending users into warmup post-knife triggers a round start event.
  // We add an extra restart to clear lingering state from the knife round, such as the round
  // indicator in the middle of the scoreboard not being reset. This also tightly couples the live-announcement to
  // the actual live start.
  if (!InWarmup()) {
    if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
      // Ensures that round end after knife sends players directly into warmup.
      // This immediately triggers another Event_RoundStart, so we can return here and avoid
      // writing backup twice.
      LogDebug("Changed to warmup post knife.");
      ExecCfg(g_WarmupCfgCvar);
      StartWarmup();
      return;
    }
    if (g_GameState == Get5State_GoingLive) {
      LogDebug("Changed to live.");
      ChangeState(Get5State_Live);
      RestartGame();
      CreateTimer(3.0, MatchLive, _, TIMER_FLAG_NO_MAPCHANGE);
      return; // Next round start will take care of below, such as writing backup.
    }
  }

  // Ensures that players who connect during halftime/team swap are placed in their correct slots as soon as the
  // following round starts. Otherwise they could be left on the "no team" screen and potentially
  // ghost, depending on where the camera drops them. Especially important for coaches.
  // We do this step *before* we write the backup, so we don't have any lingering players in case of a restore.
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientTeam(i) == CS_TEAM_NONE) {
      CheckClientTeam(i);
    }
  }

  if (g_GameState == Get5State_Warmup || g_GameState == Get5State_KnifeRound || g_GameState == Get5State_Live) {
    WriteBackup(); // Filters out backup states on its own
  }

  if (g_GameState != Get5State_Live) {
    return;
  }

  // We still want to fire the Get5_OnRoundStart event when doing a backup (g_DoingBackupRestoreNow), as this may be
  // required to insert the round into a database or event log, as the round is actually starting now and may have been
  // deleted when the backup load was requested.
  Get5RoundStartedEvent startEvent =
      new Get5RoundStartedEvent(g_MatchID, g_MapNumber, g_RoundNumber);

  LogDebug("Calling Get5_OnRoundStart()");

  Call_StartForward(g_OnRoundStart);
  Call_PushCell(startEvent);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(startEvent);
}

public Action Event_RoundWinPanel(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundWinPanel");
  if (g_GameState == Get5State_KnifeRound && g_HasKnifeRoundStarted) {
    g_HasKnifeRoundStarted = false;

    ChangeState(Get5State_WaitingForKnifeRoundDecision);
    if (g_KnifeChangedCvars != INVALID_HANDLE) {
      RestoreCvars(g_KnifeChangedCvars, true);
    }

    int ctAlive = CountAlivePlayersOnTeam(CS_TEAM_CT);
    int tAlive = CountAlivePlayersOnTeam(CS_TEAM_T);
    int winningCSTeam;
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
        winningCSTeam = GetRandomFloat(0.0, 1.0) < 0.5 ? CS_TEAM_CT : CS_TEAM_T;
        LogDebug("Randomized knife winner to side %d", winningCSTeam);
      }
    }

    g_KnifeWinnerTeam = CSTeamToGet5Team(winningCSTeam);
    char formattedStayCommand[64];
    FormatChatCommand(formattedStayCommand, sizeof(formattedStayCommand), "!stay");
    char formattedSwapCommand[64];
    FormatChatCommand(formattedSwapCommand, sizeof(formattedSwapCommand), "!swap");
    Get5_MessageToAll("%t", "WaitingForEnemySwapInfoMessage",
                      g_FormattedTeamNames[g_KnifeWinnerTeam], formattedStayCommand,
                      formattedSwapCommand);

    if (g_TeamTimeToKnifeDecisionCvar.FloatValue > 0) {
      g_KnifeDecisionTimer =
          CreateTimer(g_TeamTimeToKnifeDecisionCvar.FloatValue, Timer_ForceKnifeDecision);
    }

    // This ensures that the correct graphic is displayed in-game for the winning team, as CTs will
    // always win if the clock runs out. It also ensures that the fun fact displayed is correct;
    // overriding to number of players killed by knife and no "CT won by running down the clock".
    // MVP can still be on the losing team though. ran down".
    int maxFrags = 0;
    int topFragClient = 0;
    int frags;
    LOOP_CLIENTS(i) {
      if (IsValidClient(i)) {
        frags = GetClientFrags(i);
        if (frags >= maxFrags) {
          maxFrags = frags;
          topFragClient = i;
        }
      }
    }
    if (topFragClient > 0) {
      // Found here:
      // https://github.com/SteamDatabase/GameTracking-CSGO/blob/master/csgo/bin/server_client_strings.txt
      event.SetString("funfact_token", "#funfact_knife_kills");
      event.SetInt("funfact_player", topFragClient);
      event.SetInt("funfact_data1", maxFrags);
    }
    event.SetInt("final_event", ConvertCSTeamToDefaultWinReason(winningCSTeam));
  }
  return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundEnd");
  if (g_DoingBackupRestoreNow || g_WaitingForRoundBackup) {
    return Plugin_Continue;
  }

  if (g_GameState == Get5State_WaitingForKnifeRoundDecision && g_KnifeWinnerTeam != Get5Team_None) {
    int winningCSTeam = Get5TeamToCSTeam(g_KnifeWinnerTeam);
    // Event_RoundWinPanel is called before Event_RoundEnd, so that event handles knife winner.
    // We override this event only to have the correct audio callout in the game.
    event.SetInt("winner", winningCSTeam);
    event.SetInt("reason", ConvertCSTeamToDefaultWinReason(winningCSTeam));
    return Plugin_Continue;
  }

  if (g_GameState == Get5State_Live) {
    int csTeamWinner = event.GetInt("winner");

    Get5_MessageToAll("%s {GREEN}%d {NORMAL}- {GREEN}%d %s", g_FormattedTeamNames[Get5Team_1],
                      CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1)),
                      CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2)),
                      g_FormattedTeamNames[Get5Team_2]);

    Stats_RoundEnd(csTeamWinner);

    if (g_DamagePrintCvar.BoolValue) {
      LOOP_CLIENTS(i) {
        PrintDamageInfo(i);  // Checks valid client etc. on its own.
      }
    }

    Get5RoundStatsUpdatedEvent statsEvent =
        new Get5RoundStatsUpdatedEvent(g_MatchID, g_MapNumber, g_RoundNumber);

    LogDebug("Calling Get5_OnRoundStatsUpdated()");

    Call_StartForward(g_OnRoundStatsUpdated);
    Call_PushCell(statsEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(statsEvent);

    int roundsPlayed = GetRoundsPlayed();
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

    // CSRoundEndReason is incorrect in CSGO compared to the enumerations defined here:
    // https://github.com/alliedmodders/sourcemod/blob/master/plugins/include/cstrike.inc#L53-L77
    // - which is why we subtract one.
    Get5RoundEndedEvent roundEndEvent = new Get5RoundEndedEvent(
        g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(),
        view_as<CSRoundEndReason>(event.GetInt("reason") - 1),
        new Get5Winner(CSTeamToGet5Team(csTeamWinner), view_as<Get5Side>(csTeamWinner)),
        CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1)),
        CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2)));

    LogDebug("Calling Get5_OnRoundEnd()");

    Call_StartForward(g_OnRoundEnd);
    Call_PushCell(roundEndEvent);
    Call_Finish();

    EventLogger_LogAndDeleteEvent(roundEndEvent);

    // Reset this when a round ends, as voting has no reference to which round the teams wanted to restore to, so
    // votes to restore during one round should not carry over into the next round, as it would just restore that round
    // instead.
    LOOP_TEAMS(t) {
      if (g_TeamGivenStopCommand[t]) {
        Get5_MessageToAll("%t", "StopCommandVotingReset", g_FormattedTeamNames[t]);
      }
      g_TeamGivenStopCommand[t] = false;
    }
  }
  return Plugin_Continue;
}

public void SwapSides() {
  LogDebug("SwapSides");
  int tmp = g_TeamSide[Get5Team_1];
  g_TeamSide[Get5Team_1] = g_TeamSide[Get5Team_2];
  g_TeamSide[Get5Team_2] = tmp;

  if (g_ResetPausesEachHalfCvar.BoolValue) {
    LOOP_TEAMS(team) {
      g_TacticalPauseTimeUsed[team] = 0;
      g_TacticalPausesUsed[team] = 0;
    }
  }
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

  if (knifeRound) {
    ExecCfg(g_LiveCfgCvar); // live first, then apply and save knife cvars below
    LogDebug("StartGame: about to begin knife round");
    ChangeState(Get5State_KnifeRound);
    if (g_KnifeChangedCvars != INVALID_HANDLE) {
      CloseCvarStorage(g_KnifeChangedCvars);
    }
    char knifeConfig[PLATFORM_MAX_PATH];
    g_KnifeCfgCvar.GetString(knifeConfig, sizeof(knifeConfig));
    g_KnifeChangedCvars = ExecuteAndSaveCvars(knifeConfig);
    CreateTimer(1.0, StartKnifeRound);
  } else {
    // If there is no knife round, we go directly to live, which loads the live config etc. on its own.
    StartGoingLive();
  }
}

public void ChangeState(Get5State state) {
  if (g_GameState == state) {
    LogDebug("Ignoring request to change game state. Already in state %d.", state);
    return;
  }

  g_GameStateCvar.IntValue = view_as<int>(state);

  Get5GameStateChangedEvent event = new Get5GameStateChangedEvent(state, g_GameState);

  LogDebug("Calling Get5_OnGameStateChanged()");

  Call_StartForward(g_OnGameStateChanged);
  Call_PushCell(event);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(event);

  g_GameState = state;
}

public Action Command_Status(int client, int args) {
  Get5Status status = new Get5Status(PLUGIN_VERSION, g_GameState, IsPaused());

  if (g_GameState != Get5State_None) {
    status.SetMatchId(g_MatchID);
    status.SetConfigFile(g_LoadedConfigFile);
    status.MapNumber = g_MapNumber;
    status.RoundNumber = g_RoundNumber;
    status.RoundTime = GetRoundTime();

    status.Team1 = GetTeamInfo(Get5Team_1);
    status.Team2 = GetTeamInfo(Get5Team_2);
  }

  if (g_GameState > Get5State_Veto) {
    for (int i = 0; i < g_MapsToPlay.Length; i++) {
      char mapName[PLATFORM_MAX_PATH];
      g_MapsToPlay.GetString(i, mapName, sizeof(mapName));

      status.AddMap(mapName);
    }
  }

  int options = g_PrettyPrintJsonCvar.BoolValue ? JSON_ENCODE_PRETTY : 0;
  int bufferSize = status.EncodeSize(options);

  char[] buffer = new char[bufferSize];
  status.Encode(buffer, bufferSize, options);

  ReplyToCommand(client, buffer);

  json_cleanup_and_delete(status);
  return Plugin_Handled;
}

static Get5StatusTeam GetTeamInfo(Get5Team team) {
  int side = Get5TeamToCSTeam(team);
  return new Get5StatusTeam(g_TeamNames[team], g_TeamSeriesScores[team], CS_GetTeamScore(side),
                            IsTeamReady(team), view_as<Get5Side>(side), GetNumHumansOnTeam(side));
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
  strcopy(team1Str, sizeof(team1Str), g_TeamNames[Get5Team_1]);
  ReplaceString(team1Str, sizeof(team1Str), " ", "_");

  char team2Str[MAX_CVAR_LENGTH];
  strcopy(team2Str, sizeof(team2Str), g_TeamNames[Get5Team_2]);
  ReplaceString(team2Str, sizeof(team2Str), " ", "_");

  // MATCHTITLE must go first as it can contain other placeholders
  ReplaceString(buffer, len, "{MATCHTITLE}", g_MatchTitle, false);
  ReplaceStringWithInt(buffer, len, "{MAPNUMBER}", Get5_GetMapNumber() + 1, false);
  ReplaceStringWithInt(buffer, len, "{MAXMAPS}", g_NumberOfMapsInSeries, false);
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

public int GetRoundTime() {
  int time = GetMilliSecondsPassedSince(g_RoundStartedTime);
  if (time < 0) {
    return 0;
  }
  return time;
}

public void EventLogger_LogAndDeleteEvent(Get5Event event) {
  int options = g_PrettyPrintJsonCvar.BoolValue ? JSON_ENCODE_PRETTY : 0;
  int bufferSize = event.EncodeSize(options);

  char[] buffer = new char[bufferSize];
  event.Encode(buffer, bufferSize, options);

  char logPath[PLATFORM_MAX_PATH];
  if (FormatCvarString(g_EventLogFormatCvar, logPath, sizeof(logPath))) {
    File logFile = OpenFile(logPath, "a+");

    if (logFile) {
      LogToOpenFileEx(logFile, buffer);
      CloseHandle(logFile);
    } else {
      LogError("Could not open file \"%s\"", logPath);
    }
  }

  LogDebug("Calling Get5_OnEvent(data=%s)", buffer);

  Call_StartForward(g_OnEvent);
  Call_PushCell(event);
  Call_PushString(buffer);
  Call_Finish();

  json_cleanup_and_delete(event);
}

stock void CheckForLatestVersion() {
  // both x.y.z-dev and x.y.z-abcdef contain a single dash, so we can look for that.
  g_RunningPrereleaseVersion = StrContains(PLUGIN_VERSION, "-", true) > -1;
  if (g_RunningPrereleaseVersion) {
    LogMessage(
        "Non-official Get5 version detected. Skipping update check. You may see this if you compiled Get5 \
yourself or if you downloaded a pre-release for testing. If you are done testing, please download an official \
release version to remove this message.");
    return;
  }

  if (!LibraryExists("SteamWorks")) {
    LogMessage("SteamWorks not installed. Cannot perform Get5 version check.");
    return;
  }

  Handle req = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, LATEST_VERSION_URL);
  SteamWorks_SetHTTPCallbacks(req, VersionCheckRequestCallback);
  SteamWorks_SendHTTPRequest(req);
}

stock int VersionCheckRequestCallback(Handle request, bool failure, bool requestSuccessful,
                                      EHTTPStatusCode statusCode) {
  if (failure || !requestSuccessful) {
    LogError("Failed to check for Get5 update. HTTP error code: %d.", statusCode);
    delete request;
    return;
  }

  int responseSize;
  SteamWorks_GetHTTPResponseBodySize(request, responseSize);
  char[] response = new char[responseSize];
  SteamWorks_GetHTTPResponseBodyData(request, response, responseSize);
  delete request;

  // Since we're comparing against master, which always contains a -dev tag, we extract the version
  // substring *before* that -dev tag (or whatever it might be). This *should* have been removed by
  // the CI flow, so that official releases don't contain the -dev tag.
  Regex versionRegex = new Regex("#define PLUGIN_VERSION \"(.+)-.+\"");

  RegexError rError;
  versionRegex.MatchAll(response, rError);

  if (rError != REGEX_ERROR_NONE) {
    LogError("Get5 update regex error: %d", rError);
    delete versionRegex;
    return;
  }

  // Capture count is 2 because the first count is the entire match, the second is the substring.
  if (versionRegex.CaptureCount() != 2) {
    LogError("Get5 update check failed to match against version.sp file.");
    delete versionRegex;
    return;
  }

  char newestVersionFound[64];
  if (versionRegex.GetSubString(1, newestVersionFound, sizeof(newestVersionFound), 0)) {
    LogDebug("Newest Get5 version from GitHub is: %s", newestVersionFound);
    g_NewerVersionAvailable = !StrEqual(PLUGIN_VERSION, newestVersionFound);
    if (g_NewerVersionAvailable) {
      LogMessage(
          "A newer version of Get5 is available. You are running %s while the latest version is %s.",
          PLUGIN_VERSION, newestVersionFound);
    } else {
      LogMessage("Update check successful. Get5 is up-to-date (%s).", PLUGIN_VERSION);
    }
  }

  delete versionRegex;
}
