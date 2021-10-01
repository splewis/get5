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

int g_MatchID = -1;

ConVar g_ForceMatchIDCvar;
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

  g_ForceMatchIDCvar = CreateConVar(
      "get5_mysql_force_matchid", "0",
      "If set to a positive integer, this will force get5 to use the matchid in this convar");

  char error[255];
  db = SQL_Connect("get5", true, error, sizeof(error));
  if (db == null) {
    SetFailState("Could not connect to get5 database: %s", error);
  } else {
    g_DisableStats = false;
    db.SetCharset("utf8mb4");
  }
}

public void Get5_OnBackupRestore() {
  char matchid[64];
  Get5_GetMatchID(matchid, sizeof(matchid));
  g_MatchID = StringToInt(matchid);
}

public void Get5_OnSeriesInit() {
  g_MatchID = -1;

  char seriesType[64];
  char team1Name[64];
  char team2Name[64];

  int serverId = Get5_GetServerID();

  char seriesTypeSz[sizeof(seriesType) * 2 + 1];
  char team1NameSz[sizeof(team1Name) * 2 + 1];
  char team2NameSz[sizeof(team2Name) * 2 + 1];

  KeyValues tmpStats = new KeyValues("Stats");

  Get5_GetMatchStats(tmpStats);
  tmpStats.GetString(STAT_SERIESTYPE, seriesType, sizeof(seriesType));
  db.Escape(seriesType, seriesTypeSz, sizeof(seriesTypeSz));

  tmpStats.GetString(STAT_SERIES_TEAM1NAME, team1Name, sizeof(team1Name));
  db.Escape(team1Name, team1NameSz, sizeof(team1NameSz));

  tmpStats.GetString(STAT_SERIES_TEAM2NAME, team2Name, sizeof(team2Name));
  db.Escape(team2Name, team2NameSz, sizeof(team2NameSz));

  delete tmpStats;

  g_DisableStats = false;
  LogDebug("Setting up series stats, get5_mysql_force_matchid = %d", g_ForceMatchIDCvar.IntValue);

  if (g_ForceMatchIDCvar.IntValue > 0) {
    SetMatchID(g_ForceMatchIDCvar.IntValue);
    g_ForceMatchIDCvar.IntValue = 0;
    Format(queryBuffer, sizeof(queryBuffer), "INSERT INTO `get5_stats_matches` \
            (matchid, series_type, team1_name, team2_name, start_time, server_id) VALUES \
            (%d, '%s', '%s', '%s', NOW(), %d)",
           g_MatchID, seriesTypeSz, team1NameSz, team2NameSz, serverId);
    LogDebug(queryBuffer);
    db.Query(SQLErrorCheckCallback, queryBuffer);

    LogMessage("Starting match id %d", g_MatchID);

  } else {
    Format(queryBuffer, sizeof(queryBuffer), "INSERT INTO `get5_stats_matches` \
            (series_type, team1_name, team2_name, start_time, server_id) VALUES \
            ('%s', '%s', '%s', NOW(), %d)",
           seriesTypeSz, team1NameSz, team2NameSz, serverId);
    LogDebug(queryBuffer);
    db.Query(MatchInitCallback, queryBuffer);
  }
}

public void MatchInitCallback(Database dbObj, DBResultSet results, const char[] error, any data) {
  if (results == null) {
    LogError("Failed to get matchid from match init query");
    g_DisableStats = true;
  } else {
    if (results.InsertId > 0) {
      SetMatchID(results.InsertId);
    }
    LogMessage("Starting match id %d", g_MatchID);
  }
}

static void SetMatchID(int matchid) {
  g_MatchID = matchid;
  char idStr[32];
  IntToString(g_MatchID, idStr, sizeof(idStr));
  Get5_SetMatchID(idStr);
}

public void Get5_OnGoingLive(int mapNumber) {
  if (g_DisableStats)
    return;

  char mapName[255];
  GetCurrentMap(mapName, sizeof(mapName));

  char mapNameSz[sizeof(mapName) * 2 + 1];
  db.Escape(mapName, mapNameSz, sizeof(mapNameSz));

  Format(queryBuffer, sizeof(queryBuffer), "INSERT IGNORE INTO `get5_stats_maps` \
        (matchid, mapnumber, mapname, start_time) VALUES \
        (%d, %d, '%s', NOW())",
         g_MatchID, mapNumber, mapNameSz);
  LogDebug(queryBuffer);

  db.Query(SQLErrorCheckCallback, queryBuffer);
}

public void UpdateRoundStats(int mapNumber) {
  // Update team scores
  int t1score = CS_GetTeamScore(Get5_MatchTeamToCSTeam(MatchTeam_Team1));
  int t2score = CS_GetTeamScore(Get5_MatchTeamToCSTeam(MatchTeam_Team2));

  Format(queryBuffer, sizeof(queryBuffer), "UPDATE `get5_stats_maps` \
        SET team1_score = %d, team2_score = %d WHERE matchid = %d and mapnumber = %d",
         t1score, t2score, g_MatchID, mapNumber);
  LogDebug(queryBuffer);
  db.Query(SQLErrorCheckCallback, queryBuffer);

  // Update player stats
  KeyValues kv = new KeyValues("Stats");
  Get5_GetMatchStats(kv);
  char mapKey[32];
  Format(mapKey, sizeof(mapKey), "map%d", mapNumber);
  if (kv.JumpToKey(mapKey)) {
    if (kv.JumpToKey("team1")) {
      AddPlayerStats(kv, MatchTeam_Team1);
      kv.GoBack();
    }
    if (kv.JumpToKey("team2")) {
      AddPlayerStats(kv, MatchTeam_Team2);
      kv.GoBack();
    }
    kv.GoBack();
  }
  delete kv;
}

public void Get5_OnMapResult(const char[] map, MatchTeam mapWinner, int team1Score, int team2Score,
                      int mapNumber) {
  if (g_DisableStats)
    return;

  // Update the map winner
  char winnerString[64];
  GetTeamString(mapWinner, winnerString, sizeof(winnerString));
  Format(queryBuffer, sizeof(queryBuffer),
         "UPDATE `get5_stats_maps` SET winner = '%s', end_time = NOW() \
        WHERE matchid = %d and mapnumber = %d",
         winnerString, g_MatchID, mapNumber);
  LogDebug(queryBuffer);
  db.Query(SQLErrorCheckCallback, queryBuffer);

  // Update the series scores
  int t1_seriesscore, t2_seriesscore, tmp;
  Get5_GetTeamScores(MatchTeam_Team1, t1_seriesscore, tmp);
  Get5_GetTeamScores(MatchTeam_Team2, t2_seriesscore, tmp);

  Format(queryBuffer, sizeof(queryBuffer), "UPDATE `get5_stats_matches` \
        SET team1_score = %d, team2_score = %d WHERE matchid = %d",
         t1_seriesscore, t2_seriesscore, g_MatchID);
  LogDebug(queryBuffer);
  db.Query(SQLErrorCheckCallback, queryBuffer);
}

public void AddPlayerStats(KeyValues kv, MatchTeam team) {
  char name[MAX_NAME_LENGTH];
  char auth[AUTH_LENGTH];
  char nameSz[MAX_NAME_LENGTH * 2 + 1];
  char authSz[AUTH_LENGTH * 2 + 1];
  int mapNumber = MapNumber();

  if (kv.GotoFirstSubKey()) {
    do {
      kv.GetSectionName(auth, sizeof(auth));
      kv.GetString("name", name, sizeof(name));
      db.Escape(auth, authSz, sizeof(authSz));
      db.Escape(name, nameSz, sizeof(nameSz));

      int kills = kv.GetNum(STAT_KILLS);
      int deaths = kv.GetNum(STAT_DEATHS);
      int flashbang_assists = kv.GetNum(STAT_FLASHBANG_ASSISTS);
      int assists = kv.GetNum(STAT_ASSISTS);
      int teamkills = kv.GetNum(STAT_TEAMKILLS);
      int damage = kv.GetNum(STAT_DAMAGE);
      int utility_damage = kv.GetNum(STAT_UTILITY_DAMAGE);
      int enemies_flashed = kv.GetNum(STAT_ENEMIES_FLASHED);
      int friendlies_flashed = kv.GetNum(STAT_FRIENDLIES_FLASHED);
      int headshot_kills = kv.GetNum(STAT_HEADSHOT_KILLS);
      int knife_kills = kv.GetNum(STAT_KNIFE_KILLS);
      int roundsplayed = kv.GetNum(STAT_ROUNDSPLAYED);
      int plants = kv.GetNum(STAT_BOMBPLANTS);
      int defuses = kv.GetNum(STAT_BOMBDEFUSES);
      int v1 = kv.GetNum(STAT_V1);
      int v2 = kv.GetNum(STAT_V2);
      int v3 = kv.GetNum(STAT_V3);
      int v4 = kv.GetNum(STAT_V4);
      int v5 = kv.GetNum(STAT_V5);
      int k2 = kv.GetNum(STAT_2K);
      int k3 = kv.GetNum(STAT_3K);
      int k4 = kv.GetNum(STAT_4K);
      int k5 = kv.GetNum(STAT_5K);
      int firstkill_t = kv.GetNum(STAT_FIRSTKILL_T);
      int firstkill_ct = kv.GetNum(STAT_FIRSTKILL_CT);
      int firstdeath_t = kv.GetNum(STAT_FIRSTDEATH_T);
      int firstdeath_ct = kv.GetNum(STAT_FIRSTDEATH_CT);
      int tradekill = kv.GetNum(STAT_TRADEKILL);
      int kast = kv.GetNum(STAT_KAST);
      int contribution_score = kv.GetNum(STAT_CONTRIBUTION_SCORE);
      int mvp = kv.GetNum(STAT_MVP);

      char teamString[16];
      GetTeamString(team, teamString, sizeof(teamString));

      // Note that Format() has a 127 argument limit. See SP_MAX_CALL_ARGUMENTS in sourcepawn.
      // At this time we're at around 33, so this should not be a problem in the foreseeable future.
      // clang-format off
      Format(queryBuffer, sizeof(queryBuffer),
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
                (%d, %d, '%s', '%s', \
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
             g_MatchID, mapNumber, authSz, teamString, 
             roundsplayed, nameSz, kills, deaths, flashbang_assists, 
             assists, teamkills, knife_kills, headshot_kills, damage, utility_damage,
             enemies_flashed, friendlies_flashed,
             plants, defuses, 
             v1, v2, v3, v4, v5, 
             k2, k3, k4, k5, 
             firstkill_t, firstkill_ct, firstdeath_t, firstdeath_ct,
             tradekill, kast, contribution_score, mvp);
      // clang-format on

      LogDebug(queryBuffer);
      db.Query(SQLErrorCheckCallback, queryBuffer);

    } while (kv.GotoNextKey());
    kv.GoBack();
  }
}

public void Get5_OnSeriesResult(MatchTeam seriesWinner, int team1MapScore, int team2MapScore) {
  if (g_DisableStats)
    return;

  char winnerString[64];
  GetTeamString(seriesWinner, winnerString, sizeof(winnerString));

  Format(queryBuffer, sizeof(queryBuffer), "UPDATE `get5_stats_matches` \
        SET winner = '%s', team1_score = %d, team2_score = %d, end_time = NOW() \
        WHERE matchid = %d",
         winnerString, team1MapScore, team2MapScore, g_MatchID);
  LogDebug(queryBuffer);
  db.Query(SQLErrorCheckCallback, queryBuffer);
}

public int SQLErrorCheckCallback(Handle owner, Handle hndl, const char[] error, int data) {
  if (!StrEqual("", error)) {
    LogError("Last Connect SQL Error: %s", error);
  }
}

public void Get5_OnRoundStatsUpdated() {
  if (Get5_GetGameState() == Get5State_Live && !g_DisableStats) {
    UpdateRoundStats(MapNumber());
  }
}

static int MapNumber() {
  int t1, t2;
  int buf;
  Get5_GetTeamScores(MatchTeam_Team1, t1, buf);
  Get5_GetTeamScores(MatchTeam_Team2, t2, buf);
  return t1 + t2;
}
