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

#define CHECK_READY_TIMER_INTERVAL  1.0
#define INFO_MESSAGE_TIMER_INTERVAL 20.0

#define DEBUG_CVAR      "get5_debug"
#define MATCH_ID_LENGTH 64
#define MAX_CVAR_LENGTH 513  // 512 + 1 for buffers

#define TEAM1_STARTING_SIDE CS_TEAM_CT
#define TEAM2_STARTING_SIDE CS_TEAM_T
#define DEFAULT_TAG         "[{YELLOW}Get5{NORMAL}]"

#if !defined LATEST_VERSION_URL
#define LATEST_VERSION_URL "https://raw.githubusercontent.com/splewis/get5/master/scripting/get5/version.sp"
#endif

#if !defined GET5_GITHUB_PAGE
#define GET5_GITHUB_PAGE "splewis.github.io/get5"
#endif

#pragma semicolon 1
#pragma newdecls required
/**
 * Increases stack space to 32000 cells (or 128KB, a cell is 4 bytes)
 * This is to prevent "Not enough space on the heap" error when dumping match stats
 * Default heap size is 4KB
 */
#pragma dynamic 32000

/** ConVar handles **/
ConVar g_AllowPauseCancellationCvar;
ConVar g_AllowTechPauseCvar;
ConVar g_MaxTechPauseDurationCvar;
ConVar g_MaxTechPausesCvar;
ConVar g_AutoTechPauseMissingPlayersCvar;
ConVar g_AutoLoadConfigCvar;
ConVar g_AutoReadyActivePlayersCvar;
ConVar g_BackupSystemEnabledCvar;
ConVar g_RemoteBackupURLCvar;
ConVar g_RemoteBackupURLHeaderValueCvar;
ConVar g_RemoteBackupURLHeaderKeyCvar;
ConVar g_CheckAuthsCvar;
ConVar g_DateFormatCvar;
ConVar g_DamagePrintCvar;
ConVar g_DamagePrintExcessCvar;
ConVar g_DamagePrintFormatCvar;
ConVar g_DemoNameFormatCvar;
ConVar g_DisplayGotvVetoCvar;
ConVar g_EventLogFormatCvar;
ConVar g_EventLogRemoteURLCvar;
ConVar g_EventLogRemoteHeaderKeyCvar;
ConVar g_EventLogRemoteHeaderValueCvar;
ConVar g_FixedPauseTimeCvar;
ConVar g_KickClientImmunityCvar;
ConVar g_KickClientsWithNoMatchCvar;
ConVar g_LiveCfgCvar;
ConVar g_MuteAllChatDuringMapSelectionCvar;
ConVar g_WarmupCfgCvar;
ConVar g_KnifeCfgCvar;
ConVar g_LiveCountdownTimeCvar;
ConVar g_MaxBackupAgeCvar;
ConVar g_MaxTacticalPausesCvar;
ConVar g_MaxPauseTimeCvar;
ConVar g_MessagePrefixCvar;
ConVar g_PauseOnVetoCvar;
ConVar g_AllowUnpausingFixedPausesCvar;
ConVar g_PausingEnabledCvar;
ConVar g_PrettyPrintJsonCvar;
ConVar g_ReadyTeamTagCvar;
ConVar g_AllowForceReadyCvar;
ConVar g_ResetPausesEachHalfCvar;
ConVar g_ServerIdCvar;
ConVar g_ResetCvarsOnEndCvar;
ConVar g_SetClientClanTagCvar;
ConVar g_SetHostnameCvar;
ConVar g_StatsPathFormatCvar;
ConVar g_StopCommandEnabledCvar;
ConVar g_StopCommandNoDamageCvar;
ConVar g_StopCommandTimeLimitCvar;
ConVar g_TeamTimeToKnifeDecisionCvar;
ConVar g_TimeToStartCvar;
ConVar g_TimeToStartVetoCvar;
ConVar g_TimeFormatCvar;
ConVar g_VetoCountdownCvar;
ConVar g_PrintUpdateNoticeCvar;
ConVar g_RoundBackupPathCvar;
ConVar g_PhaseAnnouncementCountCvar;
ConVar g_Team1NameColorCvar;
ConVar g_Team2NameColorCvar;
ConVar g_SpecNameColorCvar;
ConVar g_SurrenderEnabledCvar;
ConVar g_MinimumRoundDeficitForSurrenderCvar;
ConVar g_VotesRequiredForSurrenderCvar;
ConVar g_SurrenderVoteTimeLimitCvar;
ConVar g_SurrenderCooldownCvar;
ConVar g_ForfeitEnabledCvar;
ConVar g_ForfeitCountdownTimeCvar;
ConVar g_DemoUploadURLCvar;
ConVar g_DemoUploadHeaderKeyCvar;
ConVar g_DemoUploadHeaderValueCvar;
ConVar g_DemoUploadDeleteAfterCvar;
ConVar g_DemoPathCvar;

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
int g_MapNumber = 0;             // the current map number, starting at 0.
int g_NumberOfMapsInSeries = 0;  // the number of maps to play in the series.
char g_MatchID[MATCH_ID_LENGTH];
ArrayList g_MapPoolList;
ArrayList g_TeamPlayers[MATCHTEAM_COUNT];
ArrayList g_TeamCoaches[MATCHTEAM_COUNT];
StringMap g_PlayerNames;
StringMap g_ChatCommands;
char g_TeamNames[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamTags[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_FormattedTeamNames[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamFlags[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamLogos[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_TeamMatchTexts[MATCHTEAM_COUNT][MAX_CVAR_LENGTH];
char g_MatchTitle[MAX_CVAR_LENGTH];
int g_FavoredTeamPercentage = 0;
char g_FavoredTeamText[MAX_CVAR_LENGTH];
char g_HostnamePreGet5[MAX_CVAR_LENGTH];
int g_PlayersPerTeam = 5;
int g_CoachesPerTeam = 2;
int g_MinPlayersToReady = 1;
bool g_CoachesMustReady = false;
int g_MinSpectatorsToReady = 0;
float g_RoundStartedTime = 0.0;
float g_BombPlantedTime = 0.0;
Get5BombSite g_BombSiteLastPlanted = Get5BombSite_Unknown;

bool g_SkipVeto = false;
MatchSideType g_MatchSideType = MatchSideType_Standard;
ArrayList g_CvarNames;
ArrayList g_CvarValues;
bool g_InScrimMode = false;

/** Knife for sides **/
bool g_HasKnifeRoundStarted = false;
Get5Team g_KnifeWinnerTeam = Get5Team_None;
Handle g_KnifeChangedCvars = INVALID_HANDLE;
Handle g_KnifeDecisionTimer = INVALID_HANDLE;
Handle g_KnifeCountdownTimer = INVALID_HANDLE;

/** Pausing **/
bool g_IsChangingPauseState = false;  // Used to prevent mp_pause_match and mp_unpause_match from being called directly.
Get5Team g_PausingTeam = Get5Team_None;          // The team that last called for a pause.
Get5PauseType g_PauseType = Get5PauseType_None;  // The type of pause last initiated.
Handle g_PauseTimer = INVALID_HANDLE;
int g_LatestPauseDuration = -1;
bool g_TeamReadyForUnpause[MATCHTEAM_COUNT];
bool g_TeamGivenStopCommand[MATCHTEAM_COUNT];
int g_TacticalPauseTimeUsed[MATCHTEAM_COUNT];
int g_TacticalPausesUsed[MATCHTEAM_COUNT];
int g_TechnicalPausesUsed[MATCHTEAM_COUNT];

/** Surrender/forfeit **/
int g_SurrenderVotes[MATCHTEAM_COUNT];
float g_SurrenderFailedAt[MATCHTEAM_COUNT];
bool g_SurrenderedPlayers[MAXPLAYERS + 1];
Handle g_SurrenderTimers[MATCHTEAM_COUNT];
Get5Team g_PendingSurrenderTeam = Get5Team_None;
Handle g_ForfeitTimer = INVALID_HANDLE;
int g_ForfeitSecondsPassed = 0;
Get5Team g_ForfeitingTeam = Get5Team_None;

/** Other state **/
Get5State g_GameState = Get5State_None;
ArrayList g_MapsToPlay;
ArrayList g_MapSides;
ArrayList g_MapsLeftInVetoPool;
ArrayList g_MapBanOrder;
Get5Team g_LastVetoTeam;
Handle g_InfoTimer = INVALID_HANDLE;
Handle g_MatchConfigExecTimer = INVALID_HANDLE;
Handle g_ResetCvarsTimer = INVALID_HANDLE;

/** Backup data **/
bool g_DoingBackupRestoreNow = false;

// Stats values
StringMap g_FlashbangContainer;  // Stores flashbang-entity-id -> Get5FlashbangDetonatedEvent.
StringMap g_HEGrenadeContainer;  // Stores he-entity-id -> Get5HEDetonatedEvent.
StringMap g_MolotovContainer;    // Stores molotov-entity-id -> Get5MolotovDetonatedEvent.

// Molotov detonate and start-burning/extinguish are two separate events always fired right
// after each other. We need this to bind them together as detonate does not have client id.
int g_LatestUserIdToDetonateMolotov = 0;
int g_LatestMolotovToExtinguishBySmoke = 0;  //  Attributes extinguish booleans to smoke grenades.
bool g_FirstKillDone = false;
bool g_FirstDeathDone = false;
bool g_SetTeamClutching[4];
int g_RoundKills[MAXPLAYERS + 1];                // kills per round each client has gotten
int g_RoundClutchingEnemyCount[MAXPLAYERS + 1];  // number of enemies left alive when last alive on your team
int g_PlayerKilledBy[MAXPLAYERS + 1];
float g_PlayerKilledByTime[MAXPLAYERS + 1];
int g_DamageDone[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_DamageDoneHits[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_DamageDoneKill[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_DamageDoneAssist[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_DamageDoneFlashAssist[MAXPLAYERS + 1][MAXPLAYERS + 1];
bool g_PlayerRoundKillOrAssistOrTradedDeath[MAXPLAYERS + 1];
bool g_PlayerSurvived[MAXPLAYERS + 1];
bool g_PlayerHasTakenDamage = false;
KeyValues g_StatsKv;

ArrayList g_TeamScoresPerMap = null;
char g_LoadedConfigFile[PLATFORM_MAX_PATH];
int g_VetoCaptains[MATCHTEAM_COUNT];        // Clients doing the map vetos.
int g_TeamSeriesScores[MATCHTEAM_COUNT];    // Current number of maps won per-team.
bool g_TeamReadyOverride[MATCHTEAM_COUNT];  // Whether a team has been voluntarily force readied.
bool g_ClientReady[MAXPLAYERS + 1];         // Whether clients are marked ready.
int g_TeamSide[MATCHTEAM_COUNT];            // Current CS_TEAM_* side for the team.
int g_TeamStartingSide[MATCHTEAM_COUNT];
int g_ReadyTimeWaitingUsed = 0;

char g_LastKickedPlayerAuth[64];

/** Chat aliases loaded **/
#define ALIAS_LENGTH   64
#define COMMAND_LENGTH 64
ArrayList g_ChatAliases;
ArrayList g_ChatAliasesCommands;

/** Map-game state not related to the actual gameplay. **/
char g_DemoFilePath[PLATFORM_MAX_PATH];  // full path to demo file being recorded to, including .dem extension
char g_DemoFileName[PLATFORM_MAX_PATH];  // the file name of the demo file, including .dem extension
bool g_MapChangePending = false;
bool g_PendingSideSwap = false;
Handle g_PendingMapChangeTimer = INVALID_HANDLE;
bool g_ClientPendingTeamCheck[MAXPLAYERS + 1];

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
Handle g_OnDemoUploadEnded = INVALID_HANDLE;
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
Handle g_OnPauseBegan = INVALID_HANDLE;
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
#include "get5/events.sp"
#include "get5/get5menu.sp"
#include "get5/goinglive.sp"
#include "get5/http.sp"
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
#include "get5/surrender.sp"
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

public void OnAllPluginsLoaded() {
  Handle h = FindPluginByFile("basebans.smx");
  if (h != INVALID_HANDLE) {
    LogMessage("Basebans plugin detected. You should remove this plugin as it conflicts with Get5. Unloading...");
    ServerCommand("sm plugins unload basebans");
    LogMessage("Unloaded basebans.smx.");
  }
}

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
  // clang-format off

  // Pauses
  g_AllowPauseCancellationCvar          = CreateConVar("get5_allow_pause_cancellation", "1", "Whether requests for pauses can be canceled by the pausing team using !unpause before freezetime begins.");
  g_AllowTechPauseCvar                  = CreateConVar("get5_allow_technical_pause", "1", "Whether technical pauses are allowed by players.");
  g_AllowUnpausingFixedPausesCvar       = CreateConVar("get5_allow_unpausing_fixed_pauses", "1", "Whether fixed-length tactical pauses can be stopped early if both teams !unpause.");
  g_AutoTechPauseMissingPlayersCvar     = CreateConVar("get5_auto_tech_pause_missing_players", "0", "The number of players that must leave a team to trigger an automatic technical pause. Set to 0 to disable.");
  g_FixedPauseTimeCvar                  = CreateConVar("get5_fixed_pause_time", "60", "The fixed duration of tactical pauses in seconds. Cannot be set lower than 15 if non-zero.");
  g_MaxTacticalPausesCvar               = CreateConVar("get5_max_pauses", "0", "Number of tactical pauses a team can use. 0 = unlimited.");
  g_MaxPauseTimeCvar                    = CreateConVar("get5_max_pause_time", "0", "Maximum number of seconds a game can spend under tactical pause for each team. 0 = unlimited.");
  g_MaxTechPausesCvar                   = CreateConVar("get5_max_tech_pauses", "0", "Number of technical pauses a team can use. 0 = unlimited.");
  g_PausingEnabledCvar                  = CreateConVar("get5_pausing_enabled", "1", "Whether tactical pauses are allowed by players.");
  g_ResetPausesEachHalfCvar             = CreateConVar("get5_reset_pauses_each_half", "1", "Whether tactical pause limits will be reset on halftime.");
  g_MaxTechPauseDurationCvar            = CreateConVar("get5_tech_pause_time", "0", "Number of seconds before anyone can call !unpause during a technical timeout. 0 = unlimited.");

  // Backups
  g_RoundBackupPathCvar                 = CreateConVar("get5_backup_path", "", "The folder to save backup files in, relative to the csgo directory. If defined, it must not start with a slash and must end with a slash. Set to empty string to use the csgo root.");
  g_BackupSystemEnabledCvar             = CreateConVar("get5_backup_system_enabled", "1", "Whether the Get5 backup system is enabled.");
  g_MaxBackupAgeCvar                    = CreateConVar("get5_max_backup_age", "172800", "Number of seconds before a backup file is automatically deleted. Set to 0 to disable. Default is 2 days.");
  g_StopCommandEnabledCvar              = CreateConVar("get5_stop_command_enabled", "1", "Whether clients can use the !stop command to restore to the beginning of the current round.");
  g_StopCommandNoDamageCvar             = CreateConVar("get5_stop_command_no_damage", "0", "Whether the stop command becomes unavailable if a player damages a player from the opposing team.");
  g_StopCommandTimeLimitCvar            = CreateConVar("get5_stop_command_time_limit", "0", "The number of seconds into a round after which a team can no longer request/confirm to stop and restart the round.");
  g_RemoteBackupURLCvar                 = CreateConVar("get5_remote_backup_url", "", "A URL to send backup files to over HTTP. Leave empty to disable.");
  g_RemoteBackupURLHeaderKeyCvar        = CreateConVar("get5_remote_backup_header_key", "Authorization", "If defined, a custom HTTP header with this name is added to the backup HTTP request.", FCVAR_DONTRECORD);
  g_RemoteBackupURLHeaderValueCvar      = CreateConVar("get5_remote_backup_header_value", "", "If defined, the value of the custom header added to the backup HTTP request.", FCVAR_DONTRECORD | FCVAR_PROTECTED);

  // Demos
  g_DemoUploadDeleteAfterCvar           = CreateConVar("get5_demo_delete_after_upload", "0", "Whether to delete the demo from the game server after a successful upload.");
  g_DemoNameFormatCvar                  = CreateConVar("get5_demo_name_format", "{TIME}_{MATCHID}_map{MAPNUMBER}_{MAPNAME}", "The format to use for demo files. Do not remove the {TIME} placeholder if you use the backup system. Set to empty string to disable automatic demo recording.");
  g_DemoPathCvar                        = CreateConVar("get5_demo_path", "", "The folder to save demo files in, relative to the csgo directory. If defined, it must not start with a slash and must end with a slash. Set to empty string to use the csgo root.");
  g_DemoUploadHeaderKeyCvar             = CreateConVar("get5_demo_upload_header_key", "Authorization", "If defined, a custom HTTP header with this name is added to the demo upload HTTP request.", FCVAR_DONTRECORD);
  g_DemoUploadHeaderValueCvar           = CreateConVar("get5_demo_upload_header_value", "", "If defined, the value of the custom header added to the demo upload HTTP request.", FCVAR_DONTRECORD | FCVAR_PROTECTED);
  g_DemoUploadURLCvar                   = CreateConVar("get5_demo_upload_url", "", "If defined, recorded demos will be uploaded to this URL over HTTP. If no protocol is provided, 'http://' is prepended to this value.", FCVAR_DONTRECORD);

  // Surrender/Forfeit
  g_ForfeitCountdownTimeCvar            = CreateConVar("get5_forfeit_countdown", "180", "The grace-period (in seconds) for rejoining the server to avoid a loss by forfeit.", 0, true, 30.0);
  g_ForfeitEnabledCvar                  = CreateConVar("get5_forfeit_enabled", "1", "Whether the forfeit feature is enabled.");
  g_SurrenderCooldownCvar               = CreateConVar("get5_surrender_cooldown", "60", "The number of seconds before a vote to surrender can be retried if it fails.");
  g_SurrenderEnabledCvar                = CreateConVar("get5_surrender_enabled", "0", "Whether the surrender command is enabled.");
  g_MinimumRoundDeficitForSurrenderCvar = CreateConVar("get5_surrender_minimum_round_deficit", "8", "The minimum number of rounds a team must be behind in order to surrender.", 0, true, 0.0);
  g_VotesRequiredForSurrenderCvar       = CreateConVar("get5_surrender_required_votes", "3", "The number of votes required for a team to surrender.", 0, true, 1.0);
  g_SurrenderVoteTimeLimitCvar          = CreateConVar("get5_surrender_time_limit", "15", "The number of seconds before a vote to surrender fails.", 0, true, 10.0);

  // Events
  g_EventLogFormatCvar                  = CreateConVar("get5_event_log_format", "", "Path to use when writing match event logs to disk. Use \"\" to disable.");
  g_EventLogRemoteHeaderKeyCvar         = CreateConVar("get5_remote_log_header_key", "Authorization", "If defined, a custom HTTP header with this name is added to the HTTP requests for events.", FCVAR_DONTRECORD);
  g_EventLogRemoteHeaderValueCvar       = CreateConVar("get5_remote_log_header_value", "", "If defined, the value of the custom header added to the events sent over HTTP.", FCVAR_DONTRECORD | FCVAR_PROTECTED);
  g_EventLogRemoteURLCvar               = CreateConVar("get5_remote_log_url", "", "If defined, all events are sent to this URL over HTTP. If no protocol is provided, 'http://' is prepended to this value.", FCVAR_DONTRECORD);

  // Damage info
  g_DamagePrintCvar                     = CreateConVar("get5_print_damage", "1", "Whether damage reports are printed to chat on round end.");
  g_DamagePrintExcessCvar               = CreateConVar("get5_print_damage_excess", "0", "Prints full damage given in the damage report on round end. With this disabled, a player cannot take more than 100 damage.");
  g_DamagePrintFormatCvar               = CreateConVar("get5_damageprint_format", "- [{KILL_TO}] ({DMG_TO} in {HITS_TO}) to [{KILL_FROM}] ({DMG_FROM} in {HITS_FROM}) from {NAME} ({HEALTH} HP)", "Format of the damage output string. Available tags are in the default, color tags such as {LIGHT_RED} and {GREEN} also work. {KILL_TO} and {KILL_FROM} indicate kills, assists and flash assists as booleans, all of which are mutually exclusive.");

  // Date/time formats
  g_DateFormatCvar                      = CreateConVar("get5_date_format", "%Y-%m-%d", "Date format to use when creating file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");
  g_TimeFormatCvar                      = CreateConVar("get5_time_format", "%Y-%m-%d_%H-%M-%S", "Time format to use when creating file names. Don't tweak this unless you know what you're doing! Avoid using spaces or colons.");

  // Ready system
  g_AllowForceReadyCvar                 = CreateConVar("get5_allow_force_ready", "1", "Allows players to use the !forceready command.");
  g_AutoReadyActivePlayersCvar          = CreateConVar("get5_auto_ready_active_players", "0", "Whether to automatically mark players as ready if they kill anyone in the warmup or veto phase.");
  g_ReadyTeamTagCvar                    = CreateConVar("get5_ready_team_tag", "1", "Adds [READY]/[NOT READY] tags to team names.");
  g_SetClientClanTagCvar                = CreateConVar("get5_set_client_clan_tags", "1", "Whether to set client clan tags to player ready status.");

  // Chat/color
  g_MessagePrefixCvar                   = CreateConVar("get5_message_prefix", DEFAULT_TAG, "The tag printed before each chat message.");
  g_PhaseAnnouncementCountCvar          = CreateConVar("get5_phase_announcement_count", "5", "The number of times 'Knife' or 'Match is LIVE' is printed to chat when the game starts.");
  g_SpecNameColorCvar                   = CreateConVar("get5_spec_color", "{NORMAL}", "The color used for the name of spectators in chat messages.");
  g_Team1NameColorCvar                  = CreateConVar("get5_team1_color", "{LIGHT_GREEN}", "The color used for the name of team 1 in chat messages.");
  g_Team2NameColorCvar                  = CreateConVar("get5_team2_color", "{PINK}", "The color used for the name of team 2 in chat messages.");

  // Countdown/timers
  g_LiveCountdownTimeCvar               = CreateConVar("get5_live_countdown_time", "10", "Number of seconds used to count down when a match is going live.", 0, true, 5.0, true, 60.0);
  g_TimeToStartCvar                     = CreateConVar("get5_time_to_start", "0", "Time (in seconds) teams have to ready up for live/knife before forfeiting the match. 0 = unlimited.");
  g_TimeToStartVetoCvar                 = CreateConVar("get5_time_to_start_veto", "0", "Time (in seconds) teams have to ready up for vetoing before forfeiting the match. 0 = unlimited.");
  g_TeamTimeToKnifeDecisionCvar         = CreateConVar("get5_time_to_make_knife_decision", "60", "Time (in seconds) a team has to make a !stay/!swap decision after winning knife round. 0 = unlimited.");
  g_VetoCountdownCvar                   = CreateConVar("get5_veto_countdown", "5", "Seconds to countdown before veto process commences. 0 to skip countdown.");

  // Veto
  g_MuteAllChatDuringMapSelectionCvar   = CreateConVar("get5_mute_allchat_during_map_selection", "1", "If enabled, only the team captains can type in all-chat during chat-based veto.");
  g_PauseOnVetoCvar                     = CreateConVar("get5_pause_on_veto", "0", "Whether the game pauses during the veto phase.");
  g_DisplayGotvVetoCvar                 = CreateConVar("get5_display_gotv_veto", "0", "Whether to wait for map vetos to be printed to GOTV before changing map.");

  // Server config
  g_AutoLoadConfigCvar                  = CreateConVar("get5_autoload_config", "", "The path/name of a match config file to automatically load when the server loads or when the first player joins.");
  g_CheckAuthsCvar                      = CreateConVar("get5_check_auths", "1", "Whether players are forced onto the correct teams based on their Steam IDs.");
  g_SetHostnameCvar                     = CreateConVar("get5_hostname_format", "Get5: {TEAM1} vs {TEAM2}", "The server hostname to use when a match is loaded. Set to \"\" to disable/use existing.");
  g_KickClientImmunityCvar              = CreateConVar("get5_kick_immunity", "1", "Whether admins with the 'changemap' flag will be immune to kicks from \"get5_kick_when_no_match_loaded\".");
  g_KickClientsWithNoMatchCvar          = CreateConVar("get5_kick_when_no_match_loaded", "0", "Whether the plugin kicks players when no match is loaded and when a match ends.");
  g_KnifeCfgCvar                        = CreateConVar("get5_knife_cfg", "get5/knife.cfg", "Config file to execute for the knife round.");
  g_LiveCfgCvar                         = CreateConVar("get5_live_cfg", "get5/live.cfg", "Config file to execute when the game goes live.");
  g_PrettyPrintJsonCvar                 = CreateConVar("get5_pretty_print_json", "1", "Whether all JSON output is in pretty-print format.");
  g_PrintUpdateNoticeCvar               = CreateConVar("get5_print_update_notice", "1", "Whether to print to chat when the game goes live if a new version of Get5 is available.");
  g_ServerIdCvar                        = CreateConVar("get5_server_id", "0", "A string that identifies your server. This is used in temporary files to prevent collisions and added as an HTTP header for network requests made by Get5.");
  g_StatsPathFormatCvar                 = CreateConVar("get5_stats_path_format", "get5_matchstats_{MATCHID}.cfg", "Where match stats are saved (updated each map end). Set to \"\" to disable.");
  g_WarmupCfgCvar                       = CreateConVar("get5_warmup_cfg", "get5/warmup.cfg", "Config file to execute during warmup periods.");
  g_ResetCvarsOnEndCvar                 = CreateConVar("get5_reset_cvars_on_end", "1", "Whether parameters from the \"cvars\" section of a match configuration and the Get5-determined hostname are restored to their original values when a series ends.");

  // clang-format on
  /** Create and exec plugin's configuration file **/
  AutoExecConfig(true, "get5");

  g_GameStateCvar = CreateConVar("get5_game_state", "0", "Current game state (see get5.inc)", FCVAR_DONTRECORD);
  g_LastGet5BackupCvar = CreateConVar("get5_last_backup_file", "", "Last get5 backup file written", FCVAR_DONTRECORD);
  g_VersionCvar = CreateConVar("get5_version", PLUGIN_VERSION, "Current get5 version",
                               FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
  g_VersionCvar.SetString(PLUGIN_VERSION);

  g_CoachingEnabledCvar = FindConVar("sv_coaching_enabled");
  g_CoachingEnabledCvar.AddChangeHook(CoachingChangedHook);  // used to move people off coaching if it gets disabled.

  /** Client commands **/
  g_ChatAliases = new ArrayList(ByteCountToCells(ALIAS_LENGTH));
  g_ChatAliasesCommands = new ArrayList(ByteCountToCells(COMMAND_LENGTH));
  g_ChatCommands = new StringMap();

  // Default chat mappings.
  MapChatCommand(Get5ChatCommand_Ready, "r");
  MapChatCommand(Get5ChatCommand_Ready, "ready");
  MapChatCommand(Get5ChatCommand_Unready, "notready");
  MapChatCommand(Get5ChatCommand_Unready, "unready");
  MapChatCommand(Get5ChatCommand_ForceReady, "forceready");
  MapChatCommand(Get5ChatCommand_Tech, "tech");
  MapChatCommand(Get5ChatCommand_Pause, "tac");
  MapChatCommand(Get5ChatCommand_Pause, "pause");
  MapChatCommand(Get5ChatCommand_Unpause, "unpause");
  MapChatCommand(Get5ChatCommand_Coach, "coach");
  MapChatCommand(Get5ChatCommand_Stay, "stay");
  MapChatCommand(Get5ChatCommand_Swap, "switch");
  MapChatCommand(Get5ChatCommand_Swap, "swap");
  MapChatCommand(Get5ChatCommand_T, "t");
  MapChatCommand(Get5ChatCommand_CT, "ct");
  MapChatCommand(Get5ChatCommand_Stop, "stop");
  MapChatCommand(Get5ChatCommand_Surrender, "gg");
  MapChatCommand(Get5ChatCommand_Surrender, "surrender");
  MapChatCommand(Get5ChatCommand_FFW, "ffw");
  MapChatCommand(Get5ChatCommand_CancelFFW, "cancelffw");
  MapChatCommand(Get5ChatCommand_Pick, "pick");
  MapChatCommand(Get5ChatCommand_Ban, "ban");

  LoadCustomChatAliases("addons/sourcemod/configs/get5/commands.cfg");

  /** Admin/server commands **/
  RegAdminCmd("get5_loadmatch", Command_LoadMatch, ADMFLAG_CHANGEMAP,
              "Loads a match config file (json or keyvalues) from a file relative to the csgo/ directory");
  RegAdminCmd("get5_loadmatch_url", Command_LoadMatchUrl, ADMFLAG_CHANGEMAP,
              "Loads a JSON config file by sending a GET request to download it. Requires the SteamWorks extension.");
  RegAdminCmd("get5_loadteam", Command_LoadTeam, ADMFLAG_CHANGEMAP, "Loads a team data from a file into a team");
  RegAdminCmd("get5_endmatch", Command_EndMatch, ADMFLAG_CHANGEMAP, "Force ends the current match");
  RegAdminCmd("get5_addplayer", Command_AddPlayer, ADMFLAG_CHANGEMAP, "Adds a steamid to a match team");
  RegAdminCmd("get5_addcoach", Command_AddCoach, ADMFLAG_CHANGEMAP, "Adds a steamid to a match teams coach slot");
  RegAdminCmd("get5_removeplayer", Command_RemovePlayer, ADMFLAG_CHANGEMAP, "Removes a steamid from a match team");
  RegAdminCmd("get5_addkickedplayer", Command_AddKickedPlayer, ADMFLAG_CHANGEMAP,
              "Adds the last kicked steamid to a match team");
  RegAdminCmd("get5_removekickedplayer", Command_RemoveKickedPlayer, ADMFLAG_CHANGEMAP,
              "Removes the last kicked steamid from a match team");
  RegAdminCmd("get5_creatematch", Command_CreateMatch, ADMFLAG_CHANGEMAP,
              "Creates and loads a match using the players currently on the server as a Bo1");
  RegAdminCmd(
    "get5_add_ready_time", Command_AddReadyTime, ADMFLAG_CHANGEMAP,
    "Adds additional ready-time by deducting the provided seconds from the time already used during a ready-phase.");

  RegAdminCmd("get5_scrim", Command_CreateScrim, ADMFLAG_CHANGEMAP,
              "Creates and loads a match using the scrim template");
  RegAdminCmd("sm_scrim", Command_CreateScrim, ADMFLAG_CHANGEMAP, "Creates and loads a match using the scrim template");

  RegAdminCmd("get5_ringer", Command_Ringer, ADMFLAG_CHANGEMAP, "Adds/removes a ringer to/from the home scrim team");
  RegAdminCmd("sm_ringer", Command_Ringer, ADMFLAG_CHANGEMAP, "Adds/removes a ringer to/from the home scrim team");

  RegAdminCmd("sm_get5", Command_Get5AdminMenu, ADMFLAG_CHANGEMAP, "Displays a helper menu");

  RegAdminCmd("get5_forceready", Command_AdminForceReady, ADMFLAG_CHANGEMAP, "Force readies all current teams");
  RegAdminCmd("get5_forcestart", Command_AdminForceReady, ADMFLAG_CHANGEMAP, "Force readies all current teams");

  RegAdminCmd("get5_dumpstats", Command_DumpStats, ADMFLAG_CHANGEMAP, "Dumps match stats to a file");
  RegAdminCmd("get5_listbackups", Command_ListBackups, ADMFLAG_CHANGEMAP,
              "Lists get5 match backups for the current matchid or a given one");
  RegAdminCmd("get5_loadbackup", Command_LoadBackup, ADMFLAG_CHANGEMAP,
              "Loads a Get5 match backup from a file relative to the csgo directory.");
  RegAdminCmd("get5_loadbackup_url", Command_LoadBackupUrl, ADMFLAG_CHANGEMAP,
              "Downloads and loads a Get5 match backup from a URL.");
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

  AddCommandListener(Command_BlockSuicide, "explode");
  AddCommandListener(Command_BlockSuicide, "kill");

  /** Setup data structures **/
  g_MapPoolList = new ArrayList(PLATFORM_MAX_PATH);
  g_MapsLeftInVetoPool = new ArrayList(PLATFORM_MAX_PATH);
  g_MapsToPlay = new ArrayList(PLATFORM_MAX_PATH);
  g_MapSides = new ArrayList();
  g_CvarNames = new ArrayList(MAX_CVAR_LENGTH);
  g_CvarValues = new ArrayList(MAX_CVAR_LENGTH);
  g_TeamScoresPerMap = new ArrayList(MATCHTEAM_COUNT);
  g_MapBanOrder = new ArrayList();

  for (int i = 0; i < sizeof(g_TeamPlayers); i++) {
    g_TeamPlayers[i] = new ArrayList(AUTH_LENGTH);
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
  g_OnDemoUploadEnded = CreateGlobalForward("Get5_OnDemoUploadEnded", ET_Ignore, Param_Cell);
  g_OnEvent = CreateGlobalForward("Get5_OnEvent", ET_Ignore, Param_Cell, Param_String);
  g_OnFlashbangDetonated = CreateGlobalForward("Get5_OnFlashbangDetonated", ET_Ignore, Param_Cell);
  g_OnHEGrenadeDetonated = CreateGlobalForward("Get5_OnHEGrenadeDetonated", ET_Ignore, Param_Cell);
  g_OnDecoyStarted = CreateGlobalForward("Get5_OnDecoyStarted", ET_Ignore, Param_Cell);
  g_OnSmokeGrenadeDetonated = CreateGlobalForward("Get5_OnSmokeGrenadeDetonated", ET_Ignore, Param_Cell);
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
  g_OnLoadMatchConfigFailed = CreateGlobalForward("Get5_OnLoadMatchConfigFailed", ET_Ignore, Param_Cell);
  g_OnMapPicked = CreateGlobalForward("Get5_OnMapPicked", ET_Ignore, Param_Cell);
  g_OnMapVetoed = CreateGlobalForward("Get5_OnMapVetoed", ET_Ignore, Param_Cell);
  g_OnSidePicked = CreateGlobalForward("Get5_OnSidePicked", ET_Ignore, Param_Cell);
  g_OnTeamReadyStatusChanged = CreateGlobalForward("Get5_OnTeamReadyStatusChanged", ET_Ignore, Param_Cell);
  g_OnKnifeRoundStarted = CreateGlobalForward("Get5_OnKnifeRoundStarted", ET_Ignore, Param_Cell);
  g_OnKnifeRoundWon = CreateGlobalForward("Get5_OnKnifeRoundWon", ET_Ignore, Param_Cell);
  g_OnRoundStatsUpdated = CreateGlobalForward("Get5_OnRoundStatsUpdated", ET_Ignore, Param_Cell);
  g_OnPreLoadMatchConfig = CreateGlobalForward("Get5_OnPreLoadMatchConfig", ET_Ignore, Param_Cell);
  g_OnSeriesInit = CreateGlobalForward("Get5_OnSeriesInit", ET_Ignore, Param_Cell);
  g_OnSeriesResult = CreateGlobalForward("Get5_OnSeriesResult", ET_Ignore, Param_Cell);
  g_OnMatchPaused = CreateGlobalForward("Get5_OnMatchPaused", ET_Ignore, Param_Cell);
  g_OnMatchUnpaused = CreateGlobalForward("Get5_OnMatchUnpaused", ET_Ignore, Param_Cell);
  g_OnPauseBegan = CreateGlobalForward("Get5_OnPauseBegan", ET_Ignore, Param_Cell);

  /** Start any repeating timers **/
  CreateTimer(CHECK_READY_TIMER_INTERVAL, Timer_CheckReady, _, TIMER_REPEAT);
  RestartInfoTimer();
  CheckForLatestVersion();
}

static Action Timer_InfoMessages(Handle timer) {
  if (g_GameState == Get5State_Live || g_GameState == Get5State_None) {
    return;
  }

  char readyCommandFormatted[64];
  GetChatAliasForCommand(Get5ChatCommand_Ready, readyCommandFormatted, sizeof(readyCommandFormatted), true);
  char unreadyCommandFormatted[64];
  GetChatAliasForCommand(Get5ChatCommand_Unready, unreadyCommandFormatted, sizeof(unreadyCommandFormatted), true);
  char coachCommandFormatted[64];
  GetChatAliasForCommand(Get5ChatCommand_Coach, coachCommandFormatted, sizeof(coachCommandFormatted), true);

  if (g_GameState == Get5State_PendingRestore) {
    if (!IsTeamsReady() && !IsDoingRestoreOrMapChange()) {
      Get5_MessageToAll("%t", "ReadyToRestoreBackupInfoMessage", readyCommandFormatted);
    }
  } else if (g_GameState == Get5State_Warmup || g_GameState == Get5State_PreVeto) {
    if (!g_MapChangePending) {
      // Find out what we're waiting for
      if (IsTeamsReady() && !IsSpectatorsReady()) {
        Get5_MessageToAll("%t", "WaitingForCastersReadyInfoMessage", g_FormattedTeamNames[Get5Team_Spec],
                          readyCommandFormatted);
      } else {
        // g_MapSides empty if we veto, so make sure to only check this during warmup.
        bool knifeRound = g_GameState == Get5State_Warmup && g_MapSides.Get(g_MapNumber) == SideChoice_KnifeRound;
        bool coachingEnabled = g_CoachingEnabledCvar.BoolValue && g_CoachesPerTeam > 0;
        LOOP_CLIENTS(i) {
          if (!IsPlayer(i)) {
            continue;
          }
          Get5Team team = GetClientMatchTeam(i);
          if (team == Get5Team_None) {
            continue;
          }
          bool coach = IsClientCoaching(i);
          if ((!coach || g_CoachesMustReady) && (team != Get5Team_Spec || g_MinSpectatorsToReady > 0)) {
            if (IsClientReady(i)) {
              Get5_Message(i, "%t", "TypeUnreadyIfNotReady", unreadyCommandFormatted);
            } else {
              Get5_Message(i, "%t",
                           g_GameState == Get5State_PreVeto
                             ? "ReadyForMapSelectionInfoMessage"
                             : (knifeRound ? "ReadyToKnifeInfoMessage" : "ReadyToStartInfoMessage"),
                           readyCommandFormatted);
            }
          }
          if (team == Get5Team_Spec) {
            // Spectators cannot coach.
            continue;
          }
          if (coach) {
            Get5_Message(i, "%t", "ExitCoachSlotHelp", coachCommandFormatted);
          } else if (coachingEnabled) {
            Get5_Message(i, "%t", "EnterCoachSlotHelp", coachCommandFormatted);
          }
        }
      }
      MissingPlayerInfoMessage();
    } else if (g_GameState == Get5State_Warmup && g_DisplayGotvVetoCvar.BoolValue && GetTvDelay() > 0) {
      Get5_MessageToAll("%t", "WaitingForGOTVMapSelection");
    }
  } else if (g_GameState == Get5State_Veto) {
    PrintVetoHelpMessage();
  } else if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    PromptForKnifeDecision();
  } else if (g_GameState == Get5State_PostGame && GetTvDelay() > 0) {
    // Handle postgame
    Get5_MessageToAll("%t", "WaitingForGOTVBroadcastEnding");
  }
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
    } else if (CountPlayersOnTeam(team, client) >= g_PlayersPerTeam &&
               (!g_CoachingEnabledCvar.BoolValue || CountCoachesOnTeam(team, client) >= g_CoachesPerTeam)) {
      KickClient(client, "%t", "TeamIsFullInfoMessage");
    }
  }
}

void RememberAndKickClient(int client, const char[] format, const char[] translationPhrase) {
  GetAuth(client, g_LastKickedPlayerAuth, sizeof(g_LastKickedPlayerAuth));
  KickClient(client, format, translationPhrase);
}

public void OnClientPutInServer(int client) {
  LogDebug("OnClientPutInServer");
  Stats_HookDamageForClient(client);  // Also needed for bots!
  if (IsFakeClient(client)) {
    return;
  }
  // If a player joins during freezetime, ensure their round stats are 0, as there will be no
  // round-start event to do it. Maybe this could just be freezetime end?
  Stats_ResetClientRoundValues(client);
  // Because OnConfigsExecuted may run before a client is on the server, we have to repeat the
  // start-logic here when the first client connects.
  SetServerStateOnStartup(false);
}

public void OnClientPostAdminCheck(int client) {
  if (IsPlayer(client)) {
    if (g_GameState == Get5State_None && g_KickClientsWithNoMatchCvar.BoolValue) {
      if (!g_KickClientImmunityCvar.BoolValue || !CheckCommandAccess(client, "get5_kickcheck", ADMFLAG_CHANGEMAP)) {
        KickClient(client, "%t", "NoMatchSetupInfoMessage");
      }
    }
  }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
  if (g_GameState == Get5State_Veto && g_MuteAllChatDuringMapSelectionCvar.BoolValue && StrEqual(command, "say")) {
    if (client != g_VetoCaptains[Get5Team_1] && client != g_VetoCaptains[Get5Team_2]) {
      Get5_Message(client, "%t", "MapSelectionTeamChatOnly");
      return Plugin_Stop;
    }
  }
  return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs) {
  if (g_GameState != Get5State_None && (StrEqual(command, "say") || StrEqual(command, "say_team"))) {
    if (IsValidClient(client)) {
      Get5PlayerSayEvent event = new Get5PlayerSayEvent(g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(),
                                                        GetPlayerObject(client), command, sArgs);

      LogDebug("Calling Get5_OnPlayerSay()");

      Call_StartForward(g_OnPlayerSay);
      Call_PushCell(event);
      Call_Finish();

      EventLogger_LogAndDeleteEvent(event);
    }
  }
  CheckForChatAlias(client, sArgs);
}

/**
 * Full connect event right when a player joins.
 * This sets the auto-pick time to a high value because mp_forcepicktime is broken and
 * if a player does not select a team but leaves their mouse over one, they are
 * put on that team and spawned, so we can't allow that.
 */
static Action Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }
  int client = GetClientOfUserId(event.GetInt("userid"));
  if (IsPlayer(client)) {
    char ipAddress[32];
    GetClientIP(client, ipAddress, sizeof(ipAddress));

    Get5PlayerConnectedEvent connectEvent = new Get5PlayerConnectedEvent(g_MatchID, GetPlayerObject(client), ipAddress);

    LogDebug("Calling Get5_OnPlayerConnected()");
    Call_StartForward(g_OnPlayerConnected);
    Call_PushCell(connectEvent);
    Call_Finish();
    EventLogger_LogAndDeleteEvent(connectEvent);

    SetEntPropFloat(client, Prop_Send, "m_fForceTeam", 3600.0);
  }
  return Plugin_Continue;
}

static Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
  int client = GetClientOfUserId(event.GetInt("userid"));
  g_ClientPendingTeamCheck[client] = false;
  if (g_GameState == Get5State_None || !IsPlayer(client)) {
    return Plugin_Continue;
  }
  Get5PlayerDisconnectedEvent disconnectEvent = new Get5PlayerDisconnectedEvent(g_MatchID, GetPlayerObject(client));

  LogDebug("Calling Get5_OnPlayerDisconnected()");
  Call_StartForward(g_OnPlayerDisconnected);
  Call_PushCell(disconnectEvent);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(disconnectEvent);

  // Because the disconnect event fires before the user leaves the server, we have to put this on a short callback
  // to get the right "number of players per team" in CheckForForfeitOnDisconnect().
  CreateTimer(0.1, Timer_DisconnectCheck, client, TIMER_FLAG_NO_MAPCHANGE);
  return Plugin_Continue;
}

// This runs every time a map starts *or* when the plugin is reloaded.
public void OnConfigsExecuted() {
  LogDebug("OnConfigsExecuted");
  // If the server has hibernation enabled, running this without a delay will cause it to frequently
  // fail with "Gamerules lookup failed" probably due to some odd internal race-condition where the
  // game is not yet running when we attempt to determine its "is paused" or "is in warmup" state.
  // Putting it on a 1 second callback seems to solve this problem.
  CreateTimer(1.0, Timer_ConfigsExecutedCallback);
}

static Action Timer_ConfigsExecutedCallback(Handle timer) {
  LogDebug("OnConfigsExecuted timer callback");

  // This is a defensive solution that ensures we don't have lingering forfeit-timers. If everyone leaves and a player
  // then joins the server again, the server may change the map, which triggers this. If this happens, we cannot
  // recover the game state and must force the series to end if the game has progressed past warmup. If we trigger the
  // timer during warmup, it might abruptly end the series when the first player connects to the server due to reloading
  // of the map because of "force client reconnect" from the server.
  if (g_ForfeitTimer != INVALID_HANDLE) {
    if (g_GameState > Get5State_Warmup && g_GameState < Get5State_PendingRestore && !g_MapChangePending) {
      LogDebug("Triggering forfeit timer immediately as map was changed post-warmup.");
      TriggerTimer(g_ForfeitTimer);
    } else {
      LogDebug("Stopped forfeit timer as the map was changed in non-live state.");
      ResetForfeitTimer();
    }
  }

  g_MapChangePending = false;
  g_DoingBackupRestoreNow = false;
  g_ReadyTimeWaitingUsed = 0;
  g_KnifeWinnerTeam = Get5Team_None;
  g_HasKnifeRoundStarted = false;
  // Recording is always automatically stopped on map change, and
  // since there are no hooks to detect tv_stoprecord, we reset
  // our recording var if a map change is performed unexpectedly.
  g_DemoFilePath = "";
  g_DemoFileName = "";
  DeleteOldBackups();

  EndSurrenderTimers();
  // Always reset ready status on map start
  ResetReadyStatus();

  if (CheckAutoLoadConfig()) {
    // If gamestate is none and a config was autoloaded, a match config will set all of the below
    // state.
    return;
  }

  LOOP_TEAMS(team) {
    g_TeamGivenStopCommand[team] = false;
    g_TeamReadyForUnpause[team] = false;
    if (g_GameState != Get5State_PendingRestore) {
      g_TacticalPauseTimeUsed[team] = 0;
      g_TacticalPausesUsed[team] = 0;
      g_TechnicalPausesUsed[team] = 0;
    }
  }

  // On map start, always put the game in warmup mode.
  // When executing a backup load, the live config is loaded and warmup ends after players ready-up
  // again.
  SetServerStateOnStartup(true);
  // This must not be called when waiting for a backup, as it will set the sides incorrectly if the
  // team swapped in knife or if the backup target is the second half.
  if (g_GameState != Get5State_PendingRestore) {
    SetStartingTeams();
  }

  // If the map is changed while a map timer is counting down, kill the timer. This could happen if
  // a too long mp_match_restart_delay was set and admins decide to manually intervene.
  if (g_PendingMapChangeTimer != INVALID_HANDLE) {
    delete g_PendingMapChangeTimer;
    LogDebug("Killed g_PendingMapChangeTimer as map was changed.");
  }
}

static Action Timer_CheckReady(Handle timer) {
  if (g_GameState == Get5State_None) {
    return;
  }
  if (IsDoingRestoreOrMapChange()) {
    LogDebug("Timer_CheckReady: Waiting for restore or map change");
    return;
  }
  CheckTeamNameStatus(Get5Team_1);
  CheckTeamNameStatus(Get5Team_2);
  UpdateClanTags();

  // Handle ready checks for pre-veto state
  if (g_GameState == Get5State_PreVeto) {
    if (CheckReadyWaitingTimes()) {
      // We don't wait for spectators when initiating veto
      LogDebug("Timer_CheckReady: starting veto");
      ChangeState(Get5State_Veto);
      RestartGame();
      CreateVeto();
      SetMatchTeamCvars();  // Removes ready status.
    }
  } else if (g_GameState == Get5State_PendingRestore) {
    // We don't wait for spectators when restoring backups
    if (IsTeamsReady()) {
      LogDebug("Timer_CheckReady: restoring from backup");
      RestoreGet5Backup(true);
    }
  } else if (g_GameState == Get5State_Warmup) {
    // Wait for both players and spectators before going live
    if (CheckReadyWaitingTimes() && IsSpectatorsReady()) {
      LogDebug("Timer_CheckReady: all teams ready to start");
      StartGame(g_MapSides.Get(g_MapNumber) == SideChoice_KnifeRound);
      StartRecording();
    }
  }
}

// Returns true if the teams are ready and then does not print anything.
static bool CheckReadyWaitingTimes() {
  g_ReadyTimeWaitingUsed++;
  bool team1Ready = IsTeamReady(Get5Team_1);
  bool team2Ready = IsTeamReady(Get5Team_2);

  if (team1Ready && team2Ready) {
    return true;
  }

  int readyTime = g_GameState == Get5State_PreVeto ? g_TimeToStartVetoCvar.IntValue : g_TimeToStartCvar.IntValue;
  if (readyTime <= 0) {
    return false;
  }

  int timeLeft = readyTime - g_ReadyTimeWaitingUsed;

  if (timeLeft > 0) {
    if ((timeLeft >= 300 && timeLeft % 60 == 0) || (timeLeft < 300 && timeLeft % 30 == 0) || (timeLeft == 10)) {
      char formattedTimeLeft[32];
      ConvertSecondsToMinutesAndSeconds(timeLeft, formattedTimeLeft, sizeof(formattedTimeLeft));
      FormatTimeString(formattedTimeLeft, sizeof(formattedTimeLeft), formattedTimeLeft);

      if (!team1Ready && !team2Ready) {
        Get5_MessageToAll("%t", "TeamsMustBeReadyOrTie", formattedTimeLeft);
      } else if (!team1Ready) {
        Get5_MessageToAll("%t", "TeamMustBeReadyOrForfeit", g_FormattedTeamNames[Get5Team_1], formattedTimeLeft);
      } else {
        Get5_MessageToAll("%t", "TeamMustBeReadyOrForfeit", g_FormattedTeamNames[Get5Team_2], formattedTimeLeft);
      }
    }
    // Still time left; don't end series.
    return false;
  }

  Get5Team winningTeam = Get5Team_None;
  if (team1Ready && !team2Ready) {
    winningTeam = Get5Team_1;
  } else if (team2Ready && !team1Ready) {
    winningTeam = Get5Team_2;
  }

  if (winningTeam != Get5Team_None) {
    Get5_MessageToAll("%t", "TeamForfeitInfoMessage", g_FormattedTeamNames[OtherMatchTeam(winningTeam)]);
  }

  Stats_Forfeit();
  EndSeries(winningTeam, winningTeam == Get5Team_None, 0.0);
  return false;
}

bool CheckAutoLoadConfig() {
  if (g_GameState == Get5State_None) {
    char autoloadConfig[PLATFORM_MAX_PATH];
    g_AutoLoadConfigCvar.GetString(autoloadConfig, sizeof(autoloadConfig));
    if (!StrEqual(autoloadConfig, "")) {
      char error[PLATFORM_MAX_PATH];
      bool loaded = LoadMatchConfig(autoloadConfig, error);  // return false if match config load fails!
      if (loaded) {
        LogMessage("Match configuration was loaded via get5_autoload_config.");
      } else {
        MatchConfigFail(error);
      }
      return loaded;
    }
  }
  return false;
}

/**
 * Client and server commands.
 */

static Action Command_EndMatch(int client, int args) {
  if (g_GameState == Get5State_None) {
    ReplyToCommand(client, "No match is configured; nothing to end.");
    return;
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
      return;
    }
  }

  if (IsPaused()) {
    UnpauseGame();
  }

  // Call game-ending forwards.
  int team1score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1));
  int team2score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2));

  Get5MapResultEvent mapResultEvent = new Get5MapResultEvent(
    g_MatchID, g_MapNumber, new Get5Winner(winningTeam, view_as<Get5Side>(Get5TeamToCSTeam(winningTeam))), team1score,
    team2score);

  LogDebug("Calling Get5_OnMapResult()");
  Call_StartForward(g_OnMapResult);
  Call_PushCell(mapResultEvent);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(mapResultEvent);

  StopRecording(1.0);  // must go before EndSeries as it depends on g_MatchID.

  // No delay required when not kicking players.
  EndSeries(winningTeam, false, 0.0, false);

  UpdateClanTags();

  if (winningTeam == Get5Team_None) {
    Get5_MessageToAll("%t", "AdminForceEndInfoMessage");
  } else {
    Get5_MessageToAll("%t", "AdminForceEndWithWinnerInfoMessage", g_FormattedTeamNames[winningTeam]);
  }

  RestartGame();
}

static Action Command_LoadMatch(int client, int args) {
  if (g_GameState != Get5State_None) {
    ReplyToCommand(client, "Cannot load a match config when another is already loaded.");
    return Plugin_Handled;
  }

  char arg[PLATFORM_MAX_PATH];
  if (args >= 1 && GetCmdArg(1, arg, sizeof(arg))) {
    char error[PLATFORM_MAX_PATH];
    if (!LoadMatchConfig(arg, error)) {
      MatchConfigFail(error);
      ReplyToCommand(client, error);
    }
  } else {
    ReplyToCommand(client, "Usage: get5_loadmatch <filename>");
  }
  return Plugin_Handled;
}

static Action Command_LoadMatchUrl(int client, int args) {
  char url[PLATFORM_MAX_PATH];
  if ((args != 1 && args != 3) || !GetCmdArg(1, url, sizeof(url))) {
    ReplyToCommand(client, "Usage: get5_loadmatch_url <url> [header name] [header value]");
    return Plugin_Handled;
  }
  if (g_GameState != Get5State_None) {
    ReplyToCommand(client, "Cannot load a match config when another is already loaded.");
    return Plugin_Handled;
  }

  ArrayList headerNames;
  ArrayList headerValues;
  if (args == 3) {
    headerNames = new ArrayList(PLATFORM_MAX_PATH);
    headerValues = new ArrayList(PLATFORM_MAX_PATH);
    char headerBuffer[PLATFORM_MAX_PATH];
    GetCmdArg(2, headerBuffer, sizeof(headerBuffer));
    headerNames.PushString(headerBuffer);
    GetCmdArg(3, headerBuffer, sizeof(headerBuffer));
    headerValues.PushString(headerBuffer);
  }
  char error[PLATFORM_MAX_PATH];
  if (!LoadMatchFromUrl(url, _, _, headerNames, headerValues, error)) {
    ReplyToCommand(client, "Failed to initiate request for remote match config: %s", error);
  } else {
    ReplyToCommand(client, "Loading match configuration...");
  }
  delete headerNames;
  delete headerValues;
  return Plugin_Handled;
}

static Action Command_DumpStats(int client, int args) {
  if (g_GameState == Get5State_None) {
    ReplyToCommand(client, "Cannot dump match stats when no match is loaded.");
    return;
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
}

Action Command_Ct(int client, int args) {
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  if (g_GameState == Get5State_Veto) {
    HandleSideChoice(Get5Side_CT, client);
  } else if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    int clientTeam = GetClientTeam(client);
    if (clientTeam == CS_TEAM_CT) {
      FakeClientCommand(client, "sm_stay");
    } else if (clientTeam == CS_TEAM_T) {
      FakeClientCommand(client, "sm_swap");
    }
  }
  return Plugin_Handled;
}

Action Command_T(int client, int args) {
  if (!IsPlayer(client)) {
    return Plugin_Handled;
  }
  if (g_GameState == Get5State_Veto) {
    HandleSideChoice(Get5Side_T, client);
  } else if (g_GameState == Get5State_WaitingForKnifeRoundDecision) {
    int clientTeam = GetClientTeam(client);
    if (clientTeam == CS_TEAM_CT) {
      FakeClientCommand(client, "sm_swap");
    } else if (clientTeam == CS_TEAM_T) {
      FakeClientCommand(client, "sm_stay");
    }
  }
  return Plugin_Handled;
}

Action Command_Stop(int client, int args) {
  if (!g_StopCommandEnabledCvar.BoolValue) {
    Get5_MessageToAll("%t", "StopCommandNotEnabled");
    return Plugin_Handled;
  }

  // Because a live restore to the same match does not change get5 state to warmup, we have to make sure
  // that successive calls to !stop (spammed by players) does not reload multiple backups.
  // Don't allow it after the round has ended either.
  if (g_GameState != Get5State_Live || InHalftimePhase() || g_DoingBackupRestoreNow ||
      GetRoundsPlayed() != g_RoundNumber) {
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
  if (!IsPlayerTeam(team)) {
    return Plugin_Handled;
  }

  if (g_PlayerHasTakenDamage && g_StopCommandNoDamageCvar.BoolValue) {
    Get5_MessageToAll("%t", "StopCommandRequiresNoDamage");
    return Plugin_Handled;
  }

  if (!InFreezeTime()) {
    int stopCommandGrace = g_StopCommandTimeLimitCvar.IntValue;
    if (stopCommandGrace > 0 && GetRoundTime() / 1000 > stopCommandGrace) {
      char formattedGracePeriod[32];
      ConvertSecondsToMinutesAndSeconds(stopCommandGrace, formattedGracePeriod, sizeof(formattedGracePeriod));
      FormatTimeString(formattedGracePeriod, sizeof(formattedGracePeriod), formattedGracePeriod);
      Get5_MessageToAll("%t", "StopCommandTimeLimitExceeded", formattedGracePeriod);
      return Plugin_Handled;
    }
  } else if (g_PauseType != Get5PauseType_Backup) {
    // If in freezetime and the game is not paused for restore, don't allow !stop until the round has started.
    // A tech pause should instead be used in this case. We allow additional calls to !stop if the game is paused post
    // restore, so a disconnecting player can be part of another restore process and have their inventory/cash restored
    // after reconnecting.
    Get5_MessageToAll("%t", "StopCommandOnlyAfterRoundStart");
    return Plugin_Handled;
  }

  g_TeamGivenStopCommand[team] = true;

  char stopCommandFormatted[64];
  GetChatAliasForCommand(Get5ChatCommand_Stop, stopCommandFormatted, sizeof(stopCommandFormatted), true);
  if (g_TeamGivenStopCommand[Get5Team_1] && !g_TeamGivenStopCommand[Get5Team_2]) {
    Get5_MessageToAll("%t", "TeamWantsToReloadCurrentRound", g_FormattedTeamNames[Get5Team_1],
                      g_FormattedTeamNames[Get5Team_2], stopCommandFormatted);
  } else if (!g_TeamGivenStopCommand[Get5Team_1] && g_TeamGivenStopCommand[Get5Team_2]) {
    Get5_MessageToAll("%t", "TeamWantsToReloadCurrentRound", g_FormattedTeamNames[Get5Team_2],
                      g_FormattedTeamNames[Get5Team_1], stopCommandFormatted);
  } else if (g_TeamGivenStopCommand[Get5Team_1] && g_TeamGivenStopCommand[Get5Team_2]) {
    RestoreLastRound(client);
  }

  return Plugin_Handled;
}

static Action Command_BlockSuicide(int client, const char[] command, int argc) {
  if (g_GameState == Get5State_None) {
    return Plugin_Continue;
  }
  ReplyToCommand(client, "You cannot kill yourself while Get5 is running.");
  return Plugin_Stop;
}

void RestoreLastRound(int client) {
  LOOP_TEAMS(x) {
    g_TeamGivenStopCommand[x] = false;
  }

  char lastBackup[PLATFORM_MAX_PATH];
  g_LastGet5BackupCvar.GetString(lastBackup, sizeof(lastBackup));
  if (!StrEqual(lastBackup, "")) {
    char error[PLATFORM_MAX_PATH];
    if (!RestoreFromBackup(lastBackup, error)) {
      ReplyToCommand(client, error);
    }
  } else {
    ReplyToCommand(client, "Failed to load backup as no backup file from this round exists.");
  }
}

/**
 * Game Events *not* related to the stats tracking system.
 */

Action Timer_DisconnectCheck(Handle timer, int disconnectingClient) {
  if (g_GameState == Get5State_Veto) {
    if (disconnectingClient == g_VetoCaptains[Get5Team_1]) {
      UnreadyTeam(Get5Team_1);
      AbortVeto();
    } else if (disconnectingClient == g_VetoCaptains[Get5Team_2]) {
      UnreadyTeam(Get5Team_2);
      AbortVeto();
    }
    return Plugin_Handled;
  }

  if (g_GameState <= Get5State_Warmup || g_GameState > Get5State_Live || IsDoingRestoreOrMapChange()) {
    // If we're in warmup or veto, the "time to ready" logic should be used instead of leave-surrender.
    // Postgame/restore also should not trigger any of this logic.
    return Plugin_Handled;
  }

  if (g_ForfeitTimer != INVALID_HANDLE) {
    LogDebug("Forfeit timer already started on player disconnect, ignoring.");
    return Plugin_Handled;
  }

  int team1Count = GetTeamPlayerCount(Get5Team_1);
  int team2Count = GetTeamPlayerCount(Get5Team_2);

  if (g_AutoTechPauseMissingPlayersCvar.BoolValue) {
    int playerCountTriggeringTechPause = g_PlayersPerTeam - g_AutoTechPauseMissingPlayersCvar.IntValue;
    if (playerCountTriggeringTechPause < 0) {
      playerCountTriggeringTechPause = 0;
    }
    if (team1Count > 0 && team2Count <= playerCountTriggeringTechPause) {
      TriggerAutomaticTechPause(Get5Team_2);
    } else if (team2Count > 0 && team1Count <= playerCountTriggeringTechPause) {
      TriggerAutomaticTechPause(Get5Team_1);
    }
  }

  if (team1Count > 0 && team2Count > 0) {
    // If both teams still have at least one player; no forfeit.
    return Plugin_Handled;
  }

  // The rest of the forfeit system can be disabled!
  if (!g_ForfeitEnabledCvar.BoolValue) {
    return Plugin_Handled;
  }

  Get5Team forfeitingTeam = Get5Team_None;
  if (team1Count == g_PlayersPerTeam) {
    // team2 has no players, team1 is full
    forfeitingTeam = Get5Team_2;
  } else if (team2Count == g_PlayersPerTeam) {
    // team1 has no players, team2 is full
    forfeitingTeam = Get5Team_1;
  }

  if (forfeitingTeam == Get5Team_None) {
    // End here if no players are left or one team is partially full.
    AnnounceRemainingForfeitTime(GetForfeitGracePeriod(), Get5Team_None);
    StartForfeitTimer(Get5Team_None);
    return Plugin_Handled;
  }

  if (g_GameState != Get5State_Live) {
    // !ffw can only be used in live, not in knife.
    return Plugin_Handled;
  }

  // One team is full, the other team left; announce that they can request to !ffw
  char winCommandFormatted[64];
  GetChatAliasForCommand(Get5ChatCommand_FFW, winCommandFormatted, sizeof(winCommandFormatted), true);
  Get5_MessageToAll("%t", "WinByForfeitAvailable", g_FormattedTeamNames[forfeitingTeam],
                    g_FormattedTeamNames[OtherMatchTeam(forfeitingTeam)], winCommandFormatted);
  return Plugin_Handled;
}

static Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_None && g_GameState < Get5State_KnifeRound) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    CreateTimer(0.1, Timer_ReplenishMoney, client, TIMER_FLAG_NO_MAPCHANGE);
  }
}

static Action Timer_ReplenishMoney(Handle timer, int client) {
  if (IsPlayer(client) && OnActiveTeam(client)) {
    SetEntProp(client, Prop_Send, "m_iAccount", GetCvarIntSafe("mp_maxmoney"));
  }
}

static Action Event_MatchOver(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_MatchOver");
  if (g_GameState == Get5State_None) {
    return;
  }

  // This ensures that the mp_match_restart_delay is not shorter
  // than what is required for the GOTV recording to finish.
  float restartDelay = GetCurrentMatchRestartDelay();
  float tvDelay = float(GetTvDelay());
  float requiredDelay = tvDelay + 15.0;  // Broadcast delay + 15 seconds to show scoreboard before get5 resets.
  float tvFlushDelay = requiredDelay;    // And initially, the recording flushes at the same time.
  if (tvDelay > 0.0) {
    // If there is a GOTV delay, add another 10 seconds to requiredDelay to leave room for flushing the demo to disk.
    // GOTV will freeze when flushing to disk with a substantial tv_delay, so we cannot stop the recording until all
    // of the GOTV has broadcast. Flushing to disk may take up to 10 seconds, and we want that to be complete before
    // the map changes. The freeze is a Valve bug and this is the only known way to reliably work around it.
    requiredDelay = requiredDelay + 10.0;
  }
  if (requiredDelay > restartDelay) {
    LogDebug("Extended mp_match_restart_delay from %f to %f to ensure GOTV broadcast can finish.", restartDelay,
             requiredDelay);
    SetCurrentMatchRestartDelay(requiredDelay);
    restartDelay = requiredDelay;  // reassigned because we reuse the variable below.
  }
  StopRecording(tvFlushDelay - 0.5);

  if (g_GameState == Get5State_Live) {
    // If someone called for a pause in the last round; cancel it.
    if (IsPaused()) {
      UnpauseGame();
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

    // If the round ends because the match is over, we clear the grenade container immediately as
    // they will not fire on their own if the game state is not live.
    Stats_ResetGrenadeContainers();

    // Update series scores
    Stats_UpdateMapScore(winningTeam);
    g_TeamSeriesScores[winningTeam]++;

    g_TeamScoresPerMap.Set(g_MapNumber, t1score, view_as<int>(Get5Team_1));
    g_TeamScoresPerMap.Set(g_MapNumber, t2score, view_as<int>(Get5Team_2));

    Get5MapResultEvent mapResultEvent = new Get5MapResultEvent(
      g_MatchID, g_MapNumber, new Get5Winner(winningTeam, view_as<Get5Side>(Get5TeamToCSTeam(winningTeam))), t1score,
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
        return;
      }
    } else if (g_SeriesCanClinch) {
      // This adjusts for ties!
      int actualMapsToWin = MapsToWin(g_MapsToPlay.Length - tiedMaps);
      if (t1maps == actualMapsToWin) {
        // Team 1 won
        EndSeries(Get5Team_1, true, restartDelay);
        return;
      } else if (t2maps == actualMapsToWin) {
        // Team 2 won
        EndSeries(Get5Team_2, true, restartDelay);
        return;
      }
    } else if (remainingMaps <= 0) {
      EndSeries(t1maps > t2maps ? Get5Team_1 : Get5Team_2, true,
                restartDelay);  // Tie handled in first if-block
      return;
    }

    if (t1maps > t2maps) {
      Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage", g_FormattedTeamNames[Get5Team_1], t1maps, t2maps);

    } else if (t2maps > t1maps) {
      Get5_MessageToAll("%t", "TeamWinningSeriesInfoMessage", g_FormattedTeamNames[Get5Team_2], t2maps, t1maps);

    } else {
      Get5_MessageToAll("%t", "SeriesTiedInfoMessage", t1maps, t2maps);
    }

    EndSurrenderTimers();
    ResetForfeitTimer();

    char nextMap[PLATFORM_MAX_PATH];
    g_MapsToPlay.GetString(Get5_GetMapNumber(), nextMap, sizeof(nextMap));
    if (StrContains(nextMap, "workshop", false) == 0) {
      LogDebug("Added 20 seconds to mp_match_restart_delay to ensure workshop map can download in time.");
      SetCurrentMatchRestartDelay(requiredDelay + 20);
    }

    char timeToMapChangeFormatted[8];
    ConvertSecondsToMinutesAndSeconds(RoundToFloor(restartDelay), timeToMapChangeFormatted,
                                      sizeof(timeToMapChangeFormatted));

    // g_MapChangePending is set in ChangeMap, but since we want to announce now and change the
    // state immediately while waiting for the restartDelay, we set it here also.
    g_MapChangePending = true;
    FormatMapName(nextMap, nextMap, sizeof(nextMap), true, true);
    Get5_MessageToAll("%t", "NextSeriesMapInfoMessage", nextMap, timeToMapChangeFormatted);
    ChangeState(Get5State_PostGame);
    // Subtracting 4 seconds makes the map change 1 second before the timer expires, as there is a 3
    // second built-in delay in the ChangeMap function called by Timer_NextMatchMap.
    g_PendingMapChangeTimer = CreateTimer(restartDelay - 4, Timer_NextMatchMap);
  }
}

Action Timer_NextMatchMap(Handle timer) {
  if (g_GameState == Get5State_None || timer != g_PendingMapChangeTimer) {
    return Plugin_Handled;
  }
  g_PendingMapChangeTimer = INVALID_HANDLE;
  char map[PLATFORM_MAX_PATH];
  g_MapsToPlay.GetString(Get5_GetMapNumber(), map, sizeof(map));
  // If you change these 3 seconds for whatever reason, you must adjust the counter-offset in
  // Event_MatchOver.
  ChangeMap(map, 3.0);
  return Plugin_Handled;
}

void EndSeries(Get5Team winningTeam, bool printWinnerMessage, float restoreDelay, bool kickPlayers = true) {
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
                          g_TeamSeriesScores[winningTeam], g_TeamSeriesScores[OtherMatchTeam(winningTeam)]);
      }
    }
  }

  Get5SeriesResultEvent event = new Get5SeriesResultEvent(
    g_MatchID, new Get5Winner(winningTeam, view_as<Get5Side>(Get5TeamToCSTeam(winningTeam))),
    g_TeamSeriesScores[Get5Team_1], g_TeamSeriesScores[Get5Team_2], RoundToFloor(restoreDelay));

  LogDebug("Calling Get5_OnSeriesResult()");

  Call_StartForward(g_OnSeriesResult);
  Call_PushCell(event);
  Call_Finish();

  EventLogger_LogAndDeleteEvent(event);
  ChangeState(Get5State_None);

  if (restoreDelay < 0.1) {
    // When force-ending the match there is no delay.
    ResetMatchCvarsAndHostnameAndKickPlayers(kickPlayers);
  } else {
    // If we restore cvars immediately, it might change the tv_ params or set the
    // mp_match_restart_delay to something lower, which is noticed by the game and may trigger a map
    // change before GOTV broadcast ends, so we don't do this until the current match restart delay
    // has passed. We also don't want to kick players until after the specified delay, as it will kick
    // casters potentially before GOTV ends.
    g_ResetCvarsTimer = CreateTimer(restoreDelay, Timer_RestoreMatchCvarsAndKickPlayers, kickPlayers);
  }

  // If the match is ended during pending map change;
  if (g_PendingMapChangeTimer != INVALID_HANDLE) {
    LogDebug("Killing g_PendingMapChangeTimer as match was ended.");
    delete g_PendingMapChangeTimer;
  }

  // If the match is ended during knife countdown;
  if (g_KnifeCountdownTimer != INVALID_HANDLE) {
    LogDebug("Killing g_KnifeCountdownTimer as match was ended.");
    delete g_KnifeCountdownTimer;
  }

  // If the match is ended during knife decision countdown;
  if (g_KnifeDecisionTimer != INVALID_HANDLE) {
    LogDebug("Killing g_KnifeDecisionTimer as match was ended.");
    delete g_KnifeDecisionTimer;
  }

  // If a config exec callback is in progress, stop it;
  if (g_MatchConfigExecTimer != INVALID_HANDLE) {
    LogDebug("Killing g_MatchConfigExecTimer as match was ended.");
    delete g_MatchConfigExecTimer;
  }

  // If a forfeit by disconnect is counting down and the match ends, ensure that no timer is running so a new game
  // won't be forfeited if it is started before the timer runs out.
  // Also end vote-to-surrender timers.
  ResetForfeitTimer();
  EndSurrenderTimers();
  if (IsPaused()) {
    UnpauseGame();
  }
  ResetMatchConfigVariables(false);
}

void ResetMatchConfigVariables(bool backup = false) {
  // Resets all match config variables and parameter used to track game state when Get5 is running.
  g_InScrimMode = false;
  g_MatchID = "";
  g_SkipVeto = false;
  g_MatchSideType = MatchSideType_Standard;
  g_MapsToWin = 1;
  g_SeriesCanClinch = true;
  g_LastVetoTeam = Get5Team_2;
  g_NumberOfMapsInSeries = 0;
  g_MapPoolList.Clear();
  g_PlayerNames.Clear();
  g_MapsToPlay.Clear();
  g_MapBanOrder.Clear();
  g_MapSides.Clear();
  g_MapsLeftInVetoPool.Clear();
  g_TeamScoresPerMap.Clear();
  for (int i = 0; i < MATCHTEAM_COUNT; i++) {
    g_TeamNames[i] = "";
    g_TeamTags[i] = "";
    g_FormattedTeamNames[i] = "";
    g_TeamFlags[i] = "";
    g_TeamLogos[i] = "";
    g_TeamMatchTexts[i] = "";
    g_TeamPlayers[i].Clear();
    g_TeamCoaches[i].Clear();
    g_TeamSeriesScores[i] = 0;
    g_TeamReadyForUnpause[i] = false;
    g_TeamGivenStopCommand[i] = false;
    if (!backup) {
      g_TacticalPauseTimeUsed[i] = 0;
      g_TacticalPausesUsed[i] = 0;
      g_TechnicalPausesUsed[i] = 0;
    }
  }
  g_FavoredTeamPercentage = 0;
  g_FavoredTeamText = "";
  g_PlayersPerTeam = 5;
  g_CoachesPerTeam = 2;
  g_MinPlayersToReady = 1;
  g_CoachesMustReady = false;
  g_MinSpectatorsToReady = 0;
  g_ReadyTimeWaitingUsed = 0;
  g_HasKnifeRoundStarted = false;
  g_KnifeWinnerTeam = Get5Team_None;
  g_RoundStartedTime = 0.0;
  g_BombPlantedTime = 0.0;
  g_BombSiteLastPlanted = Get5BombSite_Unknown;
  g_RoundNumber = -1;
  g_MapNumber = 0;
  g_PausingTeam = Get5Team_None;
  g_LatestPauseDuration = 0;
  g_PauseType = Get5PauseType_None;
  g_PlayerHasTakenDamage = false;
  if (!backup) {
    // All hell breaks loose if these are reset during a backup.
    g_DoingBackupRestoreNow = false;
    g_MapChangePending = false;
  }
}

static Action Timer_RestoreMatchCvarsAndKickPlayers(Handle timer, bool kickPlayers) {
  if (timer != g_ResetCvarsTimer) {
    LogDebug("g_ResetCvarsTimer callback has unexpected/invalid handle. Ignoring.");
    return Plugin_Handled;
  }
  ResetMatchCvarsAndHostnameAndKickPlayers(kickPlayers);
  g_ResetCvarsTimer = INVALID_HANDLE;
  return Plugin_Handled;
}

void ResetMatchCvarsAndHostnameAndKickPlayers(bool kickPlayers) {
  if (kickPlayers && g_KickClientsWithNoMatchCvar.BoolValue) {
    bool kickImmunity = g_KickClientImmunityCvar.BoolValue;
    LOOP_CLIENTS(i) {
      if (IsPlayer(i) && !(kickImmunity && CheckCommandAccess(i, "get5_kickcheck", ADMFLAG_CHANGEMAP))) {
        KickClient(i, "%t", "MatchFinishedInfoMessage");
      }
    }
  }
  if (g_ResetCvarsOnEndCvar.BoolValue) {
    RestoreCvars(g_MatchConfigChangedCvars);
    ResetHostname();
  } else {
    CloseCvarStorage(g_MatchConfigChangedCvars);
  }
}

static Action Event_RoundPreStart(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundPreStart");
  if (g_GameState == Get5State_None) {
    return;
  }

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
}

static Action Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_FreezeEnd");

  // If someone changes the map while in a pause, we have to make sure we reset this state, as the
  // UnpauseGame function will not be called to do it. FreezeTimeEnd is always called when the map
  // initially loads.
  g_LatestPauseDuration = -1;
  g_PauseType = Get5PauseType_None;
  g_PausingTeam = Get5Team_None;

  LOOP_TEAMS(t) {
    // Because teams can !stop again during freezetime after loading a backup, we want to make sure no lingering
    // requests persist after the freezetime ends.
    g_TeamGivenStopCommand[t] = false;
  }

  // We always want this to be correct, regardless of game state.
  g_RoundStartedTime = GetEngineTime();
  if (g_GameState == Get5State_Live && !IsDoingRestoreOrMapChange()) {
    Stats_RoundStart();
  }
}

void RestartInfoTimer() {
  // We restart this on each round start to make sure we don't double-print info messages
  // right on top of manually printed messages, such as "waiting for knife decision".
  if (g_InfoTimer != INVALID_HANDLE) {
    delete g_InfoTimer;
  }
  g_InfoTimer = CreateTimer(INFO_MESSAGE_TIMER_INTERVAL, Timer_InfoMessages, _, TIMER_REPEAT);
}

static Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundStart");

  // Always reset these on round start, regardless of game state.
  // This ensures that the functions that rely on these don't get messed up.
  g_RoundStartedTime = 0.0;
  g_BombPlantedTime = 0.0;
  g_BombSiteLastPlanted = Get5BombSite_Unknown;
  g_PlayerHasTakenDamage = false;
  RestartInfoTimer();
  if (g_PauseType != Get5PauseType_None && g_LatestPauseDuration == -1) {
    // Make sure the pause timer starts at 0.00 if the match is paused, as the timer can be offset by up to 1 second.
    // But don't do this if the pause has already ticked (i.e. pause from knife going to live).
    RestartPauseTimer();
  }

  if (g_GameState == Get5State_None || IsDoingRestoreOrMapChange()) {
    // Get5_OnRoundStart() is fired from within the backup event when loading the valve backup.
    return;
  }

  // Update server hostname as it may contain team score variables.
  UpdateHostname();

  // We cannot do this during warmup, as sending users into warmup post-knife triggers a round start
  // event.
  if (!InWarmup()) {
    if (g_GameState == Get5State_KnifeRound && g_HasKnifeRoundStarted) {
      // Knife-round decision cannot be made until the round has completely ended and a new round starts.
      // Letting players choose a side in after-round-time sometimes causes weird problems, such as going
      // directly to live and missing the countdown if done at the *exact* wrong time.
      g_HasKnifeRoundStarted = false;

      // Ensures that round end after knife sends players directly into warmup.
      // This immediately triggers another Event_RoundStart, so we can return here and avoid
      // writing backup twice.
      LogDebug("Changed to warmup post knife.");
      RestoreCvars(g_KnifeChangedCvars);
      ExecCfg(g_WarmupCfgCvar);
      StartWarmup();

      // Change state *after* starting the warmup just to reduce !swap/!stay race condition windows.
      ChangeState(Get5State_WaitingForKnifeRoundDecision);
      PromptForKnifeDecision();
      StartKnifeTimer();
      return;
    }
    if (g_GameState == Get5State_GoingLive) {
      LogDebug("Changed to live.");
      ChangeState(Get5State_Live);
      // We add an extra restart to clear lingering state from the knife round, such as the round
      // indicator in the middle of the scoreboard not being reset. This also tightly couples the
      // live-announcement to the actual live start.
      RestartGame();
      CreateTimer(3.0, Timer_MatchLive, _, TIMER_FLAG_NO_MAPCHANGE);
      return;  // Next round start will take care of below, such as writing backup.
    }
  }

  WriteBackup();

  // Ensures that players who connect during halftime/team swap are placed in their correct slots as
  // soon as the following round starts. Otherwise they could be left on the "no team" screen and
  // potentially ghost, depending on where the camera drops them. Especially important for coaches.
  // We do this step *after* we write the backup, as the Valve-backup has already been written for
  // this round at this point and we shouldn't change it (if someone is promoted coach) until next round.
  if (g_CheckAuthsCvar.BoolValue) {
    LOOP_CLIENTS(i) {
      if (IsPlayer(i) && g_ClientPendingTeamCheck[i] && GetClientTeam(i) == CS_TEAM_NONE) {
        LogDebug("Client %d is pending team assignment; placing them.", i);
        CheckClientTeam(i);
      }
    }
  }

  if (g_GameState != Get5State_Live) {
    return;
  }

  if (g_PendingSurrenderTeam != Get5Team_None) {
    SurrenderMap(g_PendingSurrenderTeam);
    g_PendingSurrenderTeam = Get5Team_None;
    return;
  }

  Get5RoundStartedEvent startEvent = new Get5RoundStartedEvent(g_MatchID, g_MapNumber, g_RoundNumber);
  LogDebug("Calling Get5_OnRoundStart()");
  Call_StartForward(g_OnRoundStart);
  Call_PushCell(startEvent);
  Call_Finish();
  EventLogger_LogAndDeleteEvent(startEvent);
}

static Action Event_RoundWinPanel(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundWinPanel");
  if (g_GameState == Get5State_KnifeRound && g_HasKnifeRoundStarted) {
    int ctAlive = CountAlivePlayersOnTeam(Get5Side_CT);
    int tAlive = CountAlivePlayersOnTeam(Get5Side_T);
    int winningCSTeam;
    if (ctAlive > tAlive) {
      winningCSTeam = CS_TEAM_CT;
    } else if (tAlive > ctAlive) {
      winningCSTeam = CS_TEAM_T;
    } else {
      int ctHealth = SumHealthOfTeam(Get5Side_CT);
      int tHealth = SumHealthOfTeam(Get5Side_T);
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

    // Adjust fun-fact to nothing and make sure the correct team is announced as winner.
    // This prevents things like "CTs won by running down the clock"
    event.SetString("funfact_token", "");
    event.SetInt("funfact_player", 0);
    event.SetInt("funfact_data1", 0);
    event.SetInt("funfact_data2", 0);
    event.SetInt("funfact_data3", 0);
    event.SetInt("final_event", ConvertCSTeamToDefaultWinReason(winningCSTeam));
  }
}

static Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
  LogDebug("Event_RoundEnd");
  if (g_GameState == Get5State_None || IsDoingRestoreOrMapChange()) {
    return;
  }

  if (g_GameState == Get5State_KnifeRound && g_KnifeWinnerTeam != Get5Team_None) {
    int winningCSTeam = Get5TeamToCSTeam(g_KnifeWinnerTeam);
    // Event_RoundWinPanel is called before Event_RoundEnd, so that event handles knife winner.
    // We override this event only to have the correct audio callout in the game.
    event.SetInt("winner", winningCSTeam);
    event.SetInt("reason", ConvertCSTeamToDefaultWinReason(winningCSTeam));
    return;
  }

  if (g_GameState == Get5State_Live) {
    int csTeamWinner = event.GetInt("winner");

    int team1Score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_1));
    int team2Score = CS_GetTeamScore(Get5TeamToCSTeam(Get5Team_2));

    if (team1Score == team2Score) {
      // If a vote is started and the game proceeds to a tie; stop the timers as surrender can now not be performed.
      EndSurrenderTimers();
    }

    Get5_MessageToAll("%s {GREEN}%d {NORMAL}- {GREEN}%d %s", g_FormattedTeamNames[Get5Team_1], team1Score, team2Score,
                      g_FormattedTeamNames[Get5Team_2]);

    Stats_RoundEnd(csTeamWinner);

    if (g_DamagePrintCvar.BoolValue) {
      LOOP_CLIENTS(i) {
        PrintDamageInfo(i);  // Checks valid client etc. on its own.
      }
    }

    Get5RoundStatsUpdatedEvent statsEvent = new Get5RoundStatsUpdatedEvent(g_MatchID, g_MapNumber, g_RoundNumber);

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
      g_MatchID, g_MapNumber, g_RoundNumber, GetRoundTime(), view_as<CSRoundEndReason>(event.GetInt("reason") - 1),
      new Get5Winner(CSTeamToGet5Team(csTeamWinner), view_as<Get5Side>(csTeamWinner)), team1Score, team2Score);

    LogDebug("Calling Get5_OnRoundEnd()");
    Call_StartForward(g_OnRoundEnd);
    Call_PushCell(roundEndEvent);
    Call_Finish();
    EventLogger_LogAndDeleteEvent(roundEndEvent);

    // Reset this when a round ends, as voting has no reference to which round the teams wanted to
    // restore to, so votes to restore during one round should not carry over into the next round,
    // as it would just restore that round instead.
    LOOP_TEAMS(t) {
      if (g_TeamGivenStopCommand[t]) {
        Get5_MessageToAll("%t", "StopCommandVotingReset", g_FormattedTeamNames[t]);
      }
      g_TeamGivenStopCommand[t] = false;
    }
  }
}

static void SwapSides() {
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
static Action Event_CvarChanged(Event event, const char[] name, bool dontBroadcast) {
  if (g_GameState != Get5State_None) {
    char cvarName[MAX_CVAR_LENGTH];
    event.GetString("cvarname", cvarName, sizeof(cvarName));
    if (!StrEqual(cvarName, "sv_cheats")) {
      event.BroadcastDisabled = true;
    }
  }
}

static void StartGame(bool knifeRound) {
  LogDebug("StartGame");

  if (knifeRound) {
    ExecCfg(g_LiveCfgCvar);  // live first, then apply and save knife cvars in callback
    LogDebug("StartGame: about to begin knife round");
    ChangeState(Get5State_KnifeRound);
    CreateTimer(0.5, StartKnifeRound);
  } else {
    // If there is no knife round, we go directly to live, which loads the live config etc. on its
    // own.
    StartGoingLive();
  }
}

static void SetServerStateOnStartup(bool force) {
  if (g_GameState == Get5State_None) {
    return;
  }
  if (!force && GetRealClientCount() != 1) {
    // Only run on first client connect or if forced (during OnConfigsExecuted).
    return;
  }
  // It shouldn't really be possible to end up here, as the server *should* reload the map anyway
  // when first player joins, but as a safeguard we don't want to move a live game into warmup on
  // player connect.
  if (!force && g_GameState == Get5State_Live) {
    return;
  }
  // If the server is in preveto or pending backup when someone joins or the configs exec, it should
  // remain in that state. This would happen if the a config with veto is loaded before someone
  // joins the server.
  if (g_GameState != Get5State_PreVeto && g_GameState != Get5State_PendingRestore) {
    ChangeState(Get5State_Warmup);
  }
  ExecCfg(g_WarmupCfgCvar);
  StartWarmup();
}

void ChangeState(Get5State state) {
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

static Action Command_Status(int client, int args) {
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
  return new Get5StatusTeam(g_TeamNames[team], g_TeamSeriesScores[team], CS_GetTeamScore(side), IsTeamReady(team),
                            view_as<Get5Side>(side), GetNumHumansOnTeam(side));
}

bool FormatCvarString(ConVar cvar, char[] buffer, int len, bool safeTeamNames = true) {
  cvar.GetString(buffer, len);
  if (StrEqual(buffer, "")) {
    return false;
  }

  char mapName[PLATFORM_MAX_PATH];
  GetCleanMapName(mapName, sizeof(mapName));

  // Get the time, this is {TIME} in the format string.
  char timeFormat[64];
  char dateFormat[64];
  g_TimeFormatCvar.GetString(timeFormat, sizeof(timeFormat));
  g_DateFormatCvar.GetString(dateFormat, sizeof(dateFormat));
  int timeStamp = GetTime();
  char formattedTime[64];
  char formattedDate[64];
  FormatTime(formattedTime, sizeof(formattedTime), timeFormat, timeStamp);
  FormatTime(formattedDate, sizeof(formattedDate), dateFormat, timeStamp);

  char team1Str[MAX_CVAR_LENGTH];
  strcopy(team1Str, sizeof(team1Str), g_TeamNames[Get5Team_1]);
  char team2Str[MAX_CVAR_LENGTH];
  strcopy(team2Str, sizeof(team2Str), g_TeamNames[Get5Team_2]);
  if (safeTeamNames) {
    // Get team names with spaces removed.
    ReplaceString(team1Str, sizeof(team1Str), " ", "_");
    ReplaceString(team2Str, sizeof(team2Str), " ", "_");
  }
  char serverId[65];
  g_ServerIdCvar.GetString(serverId, sizeof(serverId));

  // MATCHTITLE must go first as it can contain other placeholders
  ReplaceString(buffer, len, "{MATCHTITLE}", g_MatchTitle);
  ReplaceString(buffer, len, "{DATE}", formattedDate);
  ReplaceStringWithInt(buffer, len, "{MAPNUMBER}", Get5_GetMapNumber() + 1);
  ReplaceStringWithInt(buffer, len, "{MAXMAPS}", g_NumberOfMapsInSeries);
  ReplaceString(buffer, len, "{MATCHID}", g_MatchID);
  ReplaceString(buffer, len, "{MAPNAME}", mapName);
  ReplaceString(buffer, len, "{SERVERID}", serverId);
  ReplaceString(buffer, len, "{TIME}", formattedTime);
  ReplaceString(buffer, len, "{TEAM1}", team1Str);
  ReplaceString(buffer, len, "{TEAM2}", team2Str);

  int team1Score = 0;
  int team2Score = 0;
  if (g_GameState == Get5State_Live) {
    Get5Side team1Side = view_as<Get5Side>(Get5_Get5TeamToCSTeam(Get5Team_1));
    if (team1Side != Get5Side_None) {
      team1Score = CS_GetTeamScore(view_as<int>(team1Side));
      team2Score = CS_GetTeamScore(view_as<int>(team1Side == Get5Side_CT ? Get5Side_T : Get5Side_CT));
    }
  }
  ReplaceStringWithInt(buffer, len, "{TEAM1_SCORE}", team1Score);
  ReplaceStringWithInt(buffer, len, "{TEAM2_SCORE}", team2Score);

  return true;
}

// Formats a temp file path based ont he server id. The pattern parameter is expected to have a %s
// token in it.
void GetTempFilePath(char[] path, int len, const char[] pattern) {
  char serverId[65];
  g_ServerIdCvar.GetString(serverId, sizeof(serverId));
  FormatEx(path, len, pattern, serverId);
}

int GetRoundTime() {
  int time = GetMilliSecondsPassedSince(g_RoundStartedTime);
  if (time < 0) {
    return 0;
  }
  return time;
}

void EventLogger_LogAndDeleteEvent(Get5Event event) {
  int options = g_PrettyPrintJsonCvar.BoolValue ? JSON_ENCODE_PRETTY : 0;

  // We could use json_encode_size here from sm-json, but since we fire events *all the time*
  // and the function to calculate the buffer size is a lot of code, we just statically allocate
  // a 16k buffer here and reuse that.
  static char buffer[16384];
  event.Encode(buffer, 16384, options);

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

  SendEventJSONToURL(buffer);

  LogDebug("Calling Get5_OnEvent(data=%s)", buffer);

  Call_StartForward(g_OnEvent);
  Call_PushCell(event);
  Call_PushString(buffer);
  Call_Finish();

  json_cleanup_and_delete(event);
}

static void CheckForLatestVersion() {
  // both x.y.z-dev and x.y.z-abcdef contain a single dash, so we can look for that.
  g_RunningPrereleaseVersion = StrContains(PLUGIN_VERSION, "-", true) > -1;
  if (g_RunningPrereleaseVersion) {
    LogMessage("Non-official Get5 version detected. Skipping update check. You may see this if you compiled Get5 \
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

static int VersionCheckRequestCallback(Handle request, bool failure, bool requestSuccessful,
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
      LogMessage("A newer version of Get5 is available. You are running %s while the latest version is %s.",
                 PLUGIN_VERSION, newestVersionFound);
    } else {
      LogMessage("Update check successful. Get5 is up-to-date (%s).", PLUGIN_VERSION);
    }
  }

  delete versionRegex;
}
