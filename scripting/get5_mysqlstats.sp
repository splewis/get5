/**
 * =============================================================================
 * Get5 MySQL stats
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

#include <cstrike>
#include <sourcemod>

#include "get5/version.sp"
#include "include/get5.inc"
#include "include/logdebug.inc"

#include "get5/util.sp"

#pragma semicolon 1
#pragma newdecls required

Database db = null;
char queryBuffer[2048];

bool g_DisableStats = false;

// clang-format off
public Plugin myinfo = {
  name = "Get5 MySQL stats",
  author = "splewis",
  description = "Records match stats collected by get5 to MySQL",
  version = PLUGIN_VERSION,
  url = "https://github.com/splewis/get5"
};
// clang-format on

public void OnPluginStart() {
  InitDebugLog("get5_debug", "get5_mysql");

  char error[255];
  db = SQL_Connect("get5", true, error, sizeof(error));
  if (db == null) {
    SetFailState("Could not connect to get5 database: %s", error);
    g_DisableStats = true;
  } else {
    db.SetCharset("utf8mb4");
  }
}

public void Get5_OnSeriesInit(const Get5SeriesStartedEvent event) {
  if (g_DisableStats) {
    return;
  }

  char matchId[64];
  event.GetMatchId(matchId, sizeof(matchId));

  char seriesType[64];
  char team1Name[64];
  char team2Name[64];
  char serverId[65];

  char team1NameSz[sizeof(team1Name) * 2 + 1];
  char team2NameSz[sizeof(team2Name) * 2 + 1];
  char serverIdSz[sizeof(serverId) * 2 + 1];

  FormatEx(seriesType, sizeof(seriesType), "bo%d", event.SeriesLength);

  event.Team1.GetName(team1Name, sizeof(team1Name));
  event.Team2.GetName(team2Name, sizeof(team2Name));

  db.Escape(team1Name, team1NameSz, sizeof(team1NameSz));
  db.Escape(team2Name, team2NameSz, sizeof(team2NameSz));

  Get5_GetServerID(serverId, sizeof(serverId));
  db.Escape(serverId, serverIdSz, sizeof(serverIdSz));

  // Match ID defaults to an empty string, so if it's empty we use auto-increment from MySQL.
  // We also consider "scrim" and "manual" candidates for auto-increment, as those are the fixed
  // strings used for get5_scrim and get5_creatematch, so without that condition, those would break
  // the default mysql as only integers are accepted.
  if (strlen(matchId) > 0 && !StrEqual(matchId, "scrim") && !StrEqual(matchId, "manual")) {
    char matchIdSz[128];
    db.Escape(matchId, matchIdSz, sizeof(matchIdSz));

    FormatEx(queryBuffer, sizeof(queryBuffer), "INSERT INTO `get5_stats_matches` \
            (matchid, series_type, team1_name, team2_name, start_time, server_id) VALUES \
            ('%s', '%s', '%s', '%s', NOW(), '%s')",
             matchIdSz, seriesType, team1NameSz, team2NameSz, serverIdSz);
    LogDebug(queryBuffer);
    db.Query(SQLErrorCheckCallback, queryBuffer);
    LogMessage("Starting match with preset ID: %s", matchId);
  } else {
    FormatEx(queryBuffer, sizeof(queryBuffer), "INSERT INTO `get5_stats_matches` \
            (series_type, team1_name, team2_name, start_time, server_id) VALUES \
            ('%s', '%s', '%s', NOW(), '%s')",
             seriesType, team1NameSz, team2NameSz, serverIdSz);
    LogDebug(queryBuffer);
    db.Query(MatchInitCallback, queryBuffer);
  }
}

static void MatchInitCallback(Database dbObj, DBResultSet results, const char[] error, any data) {
  if (results == null) {
    LogError("Failed to get Match ID from match init query: %s.", error);
    g_DisableStats = true;
  } else if (results.InsertId < 1) {
    LogError(
      "Match ID init query succeeded but did not return a match ID integer. Perhaps the column does not have AUTO_INCREMENT?");
    g_DisableStats = true;
  } else {
    char matchId[64];
    IntToString(results.InsertId, matchId, sizeof(matchId));
    Get5_SetMatchID(matchId);
    LogMessage("Starting match ID: %d", results.InsertId);
  }
}

public void Get5_OnGoingLive(const Get5GoingLiveEvent event) {
  if (g_DisableStats) {
    return;
  }

  char matchId[64];
  event.GetMatchId(matchId, sizeof(matchId));

  char mapName[255];
  GetCurrentMap(mapName, sizeof(mapName));

  char mapNameSz[sizeof(mapName) * 2 + 1];
  db.Escape(mapName, mapNameSz, sizeof(mapNameSz));

  char matchIdSz[128];
  db.Escape(matchId, matchIdSz, sizeof(matchIdSz));

  FormatEx(queryBuffer, sizeof(queryBuffer), "INSERT IGNORE INTO `get5_stats_maps` \
        (matchid, mapnumber, mapname, start_time) VALUES \
        ('%s', %d, '%s', NOW())",
           matchIdSz, event.MapNumber, mapNameSz);
  LogDebug(queryBuffer);

  db.Query(SQLErrorCheckCallback, queryBuffer);
}

public void Get5_OnMapResult(const Get5MapResultEvent event) {
  if (g_DisableStats) {
    return;
  }

  char matchId[64];
  event.GetMatchId(matchId, sizeof(matchId));

  char matchIdSz[128];
  db.Escape(matchId, matchIdSz, sizeof(matchIdSz));

  // Update the map winner
  char winnerString[64];
  GetTeamString(event.Winner.Team, winnerString, sizeof(winnerString));

  Transaction t = new Transaction();

  FormatEx(queryBuffer, sizeof(queryBuffer), "UPDATE `get5_stats_maps` SET winner = '%s', end_time = NOW() \
        WHERE matchid = '%s' and mapnumber = %d",
           winnerString, matchIdSz, event.MapNumber);
  LogDebug(queryBuffer);
  t.AddQuery(queryBuffer);

  // Update the series scores
  FormatEx(queryBuffer, sizeof(queryBuffer), "UPDATE `get5_stats_matches` \
        SET team1_score = %d, team2_score = %d WHERE matchid = '%s'",
           event.Team1.SeriesScore, event.Team2.SeriesScore, matchIdSz);
  LogDebug(queryBuffer);
  t.AddQuery(queryBuffer);

  db.Execute(t, SQL_TransactionSuccessCallback, SQL_TransactionErrorCallback);
}

static void SQL_TransactionSuccessCallback(Database d, any data, int numQueries, DBResultSet[] results,
                                           any[] queryData) {
  return;
}

static void SQL_TransactionErrorCallback(Database d, any data, int numQueries, const char[] error, int failIndex,
                                         any[] queryData) {
  if (!StrEqual("", error)) {
    LogError("SQL transaction error: %s", error);
  }
}

public void Get5_OnSeriesResult(const Get5SeriesResultEvent event) {
  if (g_DisableStats) {
    return;
  }

  char matchId[64];
  event.GetMatchId(matchId, sizeof(matchId));

  char winnerString[64];
  GetTeamString(event.Winner.Team, winnerString, sizeof(winnerString));

  char matchIdSz[128];
  db.Escape(matchId, matchIdSz, sizeof(matchIdSz));

  FormatEx(queryBuffer, sizeof(queryBuffer), "UPDATE `get5_stats_matches` \
        SET winner = '%s', team1_score = %d, team2_score = %d, end_time = NOW() \
        WHERE matchid = '%s'",
           winnerString, event.Team1SeriesScore, event.Team2SeriesScore, matchIdSz);
  LogDebug(queryBuffer);
  db.Query(SQLErrorCheckCallback, queryBuffer);
}

static void SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, int data) {
  if (!StrEqual("", error)) {
    LogError("Last Connect SQL Error: %s", error);
  }
}

static void AddPlayerStatToTransaction(const char[] escapedMatchId, const Transaction t, const Get5StatsPlayer player,
                                       const Get5Team team, const int mapNumber) {
  char name[MAX_NAME_LENGTH];
  char auth[AUTH_LENGTH];
  char nameSz[MAX_NAME_LENGTH * 2 + 1];
  char authSz[AUTH_LENGTH * 2 + 1];

  player.GetSteamId(auth, sizeof(auth));
  player.GetName(name, sizeof(name));

  db.Escape(auth, authSz, sizeof(authSz));
  db.Escape(name, nameSz, sizeof(nameSz));

  char teamString[16];
  GetTeamString(team, teamString, sizeof(teamString));

  Get5PlayerStats s = player.Stats;

  // Note that FormatEx() has a 127 argument limit. See SP_MAX_CALL_ARGUMENTS in sourcepawn.
  // At this time we're at around 33, so this should not be a problem in the foreseeable future.
  // clang-format off
  FormatEx(queryBuffer, sizeof(queryBuffer),
            "INSERT INTO `get5_stats_players` \
            (`matchid`, `mapnumber`, `steamid64`, `team`, \
            `rounds_played`, `name`, `kills`, `deaths`, `flashbang_assists`, \
            `assists`, `teamkills`, `knife_kills`, `headshot_kills`, \
            `damage`, `utility_damage`, `enemies_flashed`, `friendlies_flashed`, \
            `bomb_plants`, `bomb_defuses`, \
            `v1`, `v2`, `v3`, `v4`, `v5`, \
            `2k`, `3k`, `4k`, `5k`, \
            `firstkill_t`, `firstkill_ct`, `firstdeath_t`, `firstdeath_ct`, \
            `tradekill`, `kast`, `contribution_score`, `mvp` \
            ) VALUES \
            ('%s', %d, '%s', '%s', \
            %d, '%s', %d, %d, %d, \
            %d, %d, %d, %d, \
            %d, %d, %d, %d, %d, %d, \
            %d, %d, %d, %d, %d, \
            %d, %d, %d, %d, \
            %d, %d, %d, %d, \
            %d, %d, %d, %d) \
            ON DUPLICATE KEY UPDATE \
            `rounds_played` = VALUES(`rounds_played`), \
            `kills` = VALUES(`kills`), \
            `deaths` = VALUES(`deaths`), \
            `flashbang_assists` = VALUES(`flashbang_assists`), \
            `assists` = VALUES(`assists`), \
            `teamkills` = VALUES(`teamkills`), \
            `knife_kills` = VALUES(`knife_kills`), \
            `headshot_kills` = VALUES(`headshot_kills`), \
            `damage` = VALUES(`damage`), \
            `utility_damage` = VALUES(`utility_damage`), \
            `enemies_flashed` = VALUES(`enemies_flashed`), \
            `friendlies_flashed` = VALUES(`friendlies_flashed`), \
            `bomb_plants` = VALUES(`bomb_plants`), \
            `bomb_defuses` = VALUES(`bomb_defuses`), \
            `v1` = VALUES(`v1`), \
            `v2` = VALUES(`v2`), \
            `v3` = VALUES(`v3`), \
            `v4` = VALUES(`v4`), \
            `v5` = VALUES(`v5`), \
            `2k` = VALUES(`2k`), \
            `3k` = VALUES(`3k`), \
            `4k` = VALUES(`4k`), \
            `5k` = VALUES(`5k`), \
            `firstkill_t` = VALUES(`firstkill_t`), \
            `firstkill_ct` = VALUES(`firstkill_ct`), \
            `firstdeath_t` = VALUES(`firstdeath_t`), \
            `firstdeath_ct` = VALUES(`firstdeath_ct`), \
            `tradekill` = VALUES(`tradekill`), \
            `kast` = VALUES(`kast`), \
            `contribution_score` = VALUES(`contribution_score`), \
            `mvp` = VALUES(`mvp`)",
         escapedMatchId, mapNumber, authSz, teamString,
         s.RoundsPlayed, nameSz, s.Kills, s.Deaths, s.FlashAssists,
         s.Assists, s.TeamKills, s.KnifeKills, s.HeadshotKills, s.Damage, s.UtilityDamage,
         s.EnemiesFlashed, s.FriendliesFlashed,
         s.BombPlants, s.BombDefuses,
         s.OneV1s, s.OneV2s, s.OneV3s, s.OneV4s, s.OneV5s,
         s.Kills2, s.Kills3, s.Kills4, s.Kills5,
         s.FirstKillsT, s.FirstKillsCT, s.FirstDeathsT, s.FirstDeathsCT,
         s.TradeKills, s.KAST, s.Score, s.MVPs);
  // clang-format on

  LogDebug(queryBuffer);
  t.AddQuery(queryBuffer);
}

public void Get5_OnRoundEnd(const Get5RoundEndedEvent event) {
  if (Get5_GetGameState() != Get5State_Live || g_DisableStats) {
    return;
  }

  char matchId[64];
  event.GetMatchId(matchId, sizeof(matchId));
  char matchIdSz[128];
  db.Escape(matchId, matchIdSz, sizeof(matchIdSz));

  Transaction t = new Transaction();

  FormatEx(queryBuffer, sizeof(queryBuffer), "UPDATE `get5_stats_maps` \
        SET team1_score = %d, team2_score = %d WHERE matchid = '%s' and mapnumber = %d",
           event.Team1.Score, event.Team2.Score, matchIdSz, event.MapNumber);
  LogDebug(queryBuffer);
  t.AddQuery(queryBuffer);

  JSON_Array team1Players = event.Team1.Players;
  JSON_Array team2Players = event.Team2.Players;

  int i;
  int size = team1Players.Length;
  for (i = 0; i < size; i++) {
    AddPlayerStatToTransaction(matchIdSz, t, view_as<Get5StatsPlayer>(team1Players.GetObject(i)), Get5Team_1,
                               event.MapNumber);
  }
  size = team2Players.Length;
  for (i = 0; i < size; i++) {
    AddPlayerStatToTransaction(matchIdSz, t, view_as<Get5StatsPlayer>(team2Players.GetObject(i)), Get5Team_2,
                               event.MapNumber);
  }

  db.Execute(t, SQL_TransactionSuccessCallback, SQL_TransactionErrorCallback);
}
