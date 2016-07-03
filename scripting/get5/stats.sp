public void Stats_PluginStart() {
    HookEvent("player_death", Stats_PlayerDeathEvent);
    HookEvent("player_hurt", Stats_DamageDealtEvent, EventHookMode_Pre);
    HookEvent("bomb_planted", Stats_BombPlantedEvent);
    HookEvent("bomb_defused", Stats_BombDefusedEvent);
    HookEvent("flashbang_detonate", Stats_FlashbangDetonateEvent, EventHookMode_Pre);
    HookEvent("player_blind", Stats_PlayerBlindEvent);
}

public void Stats_Reset() {
    if (g_StatsKv != null) {
        delete g_StatsKv;
    }
    g_StatsKv = new KeyValues("Stats");
}

public void Stats_InitSeries() {
    Stats_Reset();
    char seriesType[32];
    Format(seriesType, sizeof(seriesType), "bo%d", MaxMapsToPlay(g_MapsToWin));
    g_StatsKv.SetString(STAT_SERIESTYPE, seriesType);
    g_StatsKv.SetString(STAT_SERIES_TEAM1NAME, g_TeamNames[MatchTeam_Team1]);
    g_StatsKv.SetString(STAT_SERIES_TEAM2NAME, g_TeamNames[MatchTeam_Team2]);
    DumpToFile();
}

public void Stats_ResetRoundValues() {
    g_SetTeamClutching[CS_TEAM_CT] = false;
    g_SetTeamClutching[CS_TEAM_T] = false;

    for (int i = 1; i <= MaxClients; i++) {
        Stats_ResetClientRoundValues(i);
    }
}

public void Stats_ResetClientRoundValues(int client) {
    g_RoundKills[client] = 0;
    g_RoundClutchingEnemyCount[client] = 0;
    g_RoundFlashedBy[client] = 0;
}

public void Stats_RoundStart() {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            MatchTeam team = GetClientMatchTeam(i);
            if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
                IncrementPlayerStat(i, STAT_ROUNDSPLAYED);

                GoToPlayer(i);
                char name[MAX_NAME_LENGTH];
                GetClientName(i, name, sizeof(name));
                g_StatsKv.SetString(STAT_NAME, name);
                GoBackFromPlayer();
            }
        }
    }

}

public void Stats_RoundEnd(int csTeamWinner) {
    // Update team scores.
    GoToMap();
    char mapName[PLATFORM_MAX_PATH];
    GetCleanMapName(mapName, sizeof(mapName));
    g_StatsKv.SetString(STAT_MAPNAME, mapName);
    GoBackFromMap();

    GoToTeam(MatchTeam_Team1);
    g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team1)));
    GoBackFromTeam();

    GoToTeam(MatchTeam_Team2);
    g_StatsKv.SetNum(STAT_TEAMSCORE, CS_GetTeamScore(MatchTeamToCSTeam(MatchTeam_Team2)));
    GoBackFromTeam();

    // Update player 1vx and x-kill values.
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            MatchTeam team = GetClientMatchTeam(i);
            if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
                switch(g_RoundKills[i]) {
                    case 1: IncrementPlayerStat(i, STAT_1K);
                    case 2: IncrementPlayerStat(i, STAT_2K);
                    case 3: IncrementPlayerStat(i, STAT_3K);
                    case 4: IncrementPlayerStat(i, STAT_4K);
                    case 5: IncrementPlayerStat(i, STAT_5K);
                }

                if (GetClientTeam(i) == csTeamWinner) {
                    switch (g_RoundClutchingEnemyCount[i]) {
                        case 1: IncrementPlayerStat(i, STAT_V1);
                        case 2: IncrementPlayerStat(i, STAT_V2);
                        case 3: IncrementPlayerStat(i, STAT_V3);
                        case 4: IncrementPlayerStat(i, STAT_V4);
                        case 5: IncrementPlayerStat(i, STAT_V5);
                    }
                }

                GoToPlayer(i);
                char name[MAX_NAME_LENGTH];
                GetClientName(i, name, sizeof(name));
                g_StatsKv.SetString(STAT_NAME, name);
                GoBackFromPlayer();
            }
        }
    }

}

public void Stats_UpdateMapScore(MatchTeam winner) {
    GoToMap();

    char winnerString[16];
    GetTeamString(winner, winnerString, sizeof(winnerString));

    g_StatsKv.SetString(STAT_MAPWINNER, winnerString);
    g_StatsKv.SetString(STAT_DEMOFILENAME, g_DemoFileName);

    GoBackFromMap();

    DumpToFile();
}

public void Stats_Forfeit(MatchTeam team) {
    g_StatsKv.SetNum(STAT_SERIES_FORFEIT, 1);

    if (team == MatchTeam_Team1)
        Stats_SeriesEnd(MatchTeam_Team2);
    else
        Stats_SeriesEnd(MatchTeam_Team1);
}

public void Stats_SeriesEnd(MatchTeam winner) {
    char winnerString[16];
    GetTeamString(winner, winnerString, sizeof(winnerString));
    g_StatsKv.SetString(STAT_SERIESWINNER, winnerString);
    DumpToFile();
}

public Action Stats_PlayerDeathEvent(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_Live) {
        return Plugin_Continue;
    }

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int assister = GetClientOfUserId(event.GetInt("assister"));
    bool headshot = event.GetBool("headshot");

    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validVictim) {
        IncrementPlayerStat(victim, STAT_DEATHS);
    }

    if (validAttacker) {
        if (HelpfulAttack(attacker, victim)) {
            g_RoundKills[attacker]++;
            IncrementPlayerStat(attacker, STAT_KILLS);
            if (headshot)
                IncrementPlayerStat(attacker, STAT_HEADSHOT_KILLS);
            if (IsValidClient(assister))
                IncrementPlayerStat(assister, STAT_ASSISTS);

            int flasher = g_RoundFlashedBy[victim];
            if (IsValidClient(flasher) && flasher != attacker)
                IncrementPlayerStat(flasher, STAT_FLASHBANG_ASSISTS);

        } else {
            if (attacker == victim)
                IncrementPlayerStat(attacker, STAT_SUICIDES);
            else
                IncrementPlayerStat(attacker, STAT_TEAMKILLS);
        }
    }

    // Update "clutch" (1vx) data structures to check if the clutcher wins the round
    int tCount = CountAlivePlayersOnTeam(CS_TEAM_T);
    int ctCount = CountAlivePlayersOnTeam(CS_TEAM_CT);

    if (tCount == 1 && !g_SetTeamClutching[CS_TEAM_T]) {
        g_SetTeamClutching[CS_TEAM_T] = true;
        int clutcher = GetClutchingClient(CS_TEAM_T);
        g_RoundClutchingEnemyCount[clutcher] = ctCount;
    }

    if (ctCount == 1 && !g_SetTeamClutching[CS_TEAM_CT]) {
        g_SetTeamClutching[CS_TEAM_CT] = true;
        int clutcher = GetClutchingClient(CS_TEAM_CT);
        g_RoundClutchingEnemyCount[clutcher] = tCount;
    }

    return Plugin_Continue;
}

public Action Stats_DamageDealtEvent(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_Live) {
        return Plugin_Continue;
    }

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    int victim = GetClientOfUserId(event.GetInt("userid"));
    bool validAttacker = IsValidClient(attacker);
    bool validVictim = IsValidClient(victim);

    if (validAttacker && validVictim) {
        int preDamageHealth = GetClientHealth(victim);
        int damage = event.GetInt("dmg_health");
        int postDamageHealth = event.GetInt("health");

        // this maxes the damage variables at 100,
        // so doing 50 damage when the player had 2 health
        // only counts as 2 damage.
        if (postDamageHealth == 0) {
            damage += preDamageHealth;
        }

        AddToPlayerStat(attacker, STAT_DAMAGE, damage);
    }

    return Plugin_Continue;
}

public Action Stats_BombPlantedEvent(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_Live) {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client)) {
        IncrementPlayerStat(client, STAT_BOMBPLANTS);
    }

    return Plugin_Continue;
}

public Action Stats_BombDefusedEvent(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_Live) {
        return Plugin_Continue;
    }

    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidClient(client)) {
        IncrementPlayerStat(client, STAT_BOMBDEFUSES);
    }

    return Plugin_Continue;
}

public Action Stats_FlashbangDetonateEvent(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_Live) {
        return Plugin_Continue;
    }

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);

    if (IsValidClient(client)) {
        g_LastFlashBangThrower = client;
    }

    return Plugin_Continue;
}

public Action Timer_ResetFlashStatus(Handle timer, int serial) {
    int client = GetClientFromSerial(serial);
    if (IsValidClient(client)) {
        g_RoundFlashedBy[client] = -1;
    }
}

public Action Stats_PlayerBlindEvent(Event event, const char[] name, bool dontBroadcast) {
    if (g_GameState != GameState_Live) {
        return Plugin_Continue;
    }

    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    RequestFrame(GetFlashInfo, GetClientSerial(client));

    return Plugin_Continue;
}

public void GetFlashInfo(int serial) {
    int client = GetClientFromSerial(serial);
    if (IsValidClient(client)) {
        float flashDuration = GetEntDataFloat(client, FindSendPropInfo("CCSPlayer", "m_flFlashDuration"));
        if (flashDuration >= 2.5) {
            g_RoundFlashedBy[client] = g_LastFlashBangThrower;
        }
        CreateTimer(flashDuration, Timer_ResetFlashStatus, serial);
    }
}

static int GetPlayerStat(int client, const char[] field) {
    GoToPlayer(client);
    int value = g_StatsKv.GetNum(field);
    GoBackFromPlayer();
    return value;
}

static int SetPlayerStat(int client, const char[] field, int newValue) {
    GoToPlayer(client);
    g_StatsKv.SetNum(field, newValue);
    GoBackFromPlayer();
    return newValue;
}

public int AddToPlayerStat(int client, const char[] field, int delta) {
    int value = GetPlayerStat(client, field);
    return SetPlayerStat(client, field, value + delta);
}

static int IncrementPlayerStat(int client, const char[] field) {
    LogDebug("Incrementing player stat %s for %L", field, client);
    return AddToPlayerStat(client, field, 1);
}

static void GoToMap() {
    char mapNumberString[32];
    Format(mapNumberString, sizeof(mapNumberString), "map%d", GetMapStatsNumber());
    g_StatsKv.JumpToKey(mapNumberString, true);
}

static void GoBackFromMap() {
    g_StatsKv.GoBack();
}

static void GoToTeam(MatchTeam team) {
    GoToMap();

    if (team == MatchTeam_Team1)
        g_StatsKv.JumpToKey("team1", true);
    else
        g_StatsKv.JumpToKey("team2", true);
}

static void GoBackFromTeam() {
    GoBackFromMap();
    g_StatsKv.GoBack();
}

static void GoToPlayer(int client) {
    MatchTeam team = GetClientMatchTeam(client);
    GoToTeam(team);

    char auth[AUTH_LENGTH];
    GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
    g_StatsKv.JumpToKey(auth, true);
}

static void GoBackFromPlayer() {
    GoBackFromTeam();
    g_StatsKv.GoBack();
}

public int GetMapStatsNumber() {
    int x = GetMapNumber();
    if (g_MapChangePending) {
        return x - 1;
    } else {
        return x;
    }
}

static int GetClutchingClient(int csTeam) {
    int client = -1;
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == csTeam) {
            client = i;
            count++;
        }
    }

    if (count == 1) {
        return client;
    } else {
        return -1;
    }
}

public void DumpToFile() {
    if (g_AutoDumpStatsCvar.IntValue != 0) {
        char path[PLATFORM_MAX_PATH];
        Format(path, sizeof(path), "get5_matchstats_%s", g_MatchID);
        g_StatsKv.ExportToFile(path);
    }
}
