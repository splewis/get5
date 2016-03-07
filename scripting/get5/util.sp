#define MAX_INTEGER_STRING_LENGTH 16
#define MAX_FLOAT_STRING_LENGTH 32

static char _colorNames[][] = {"{NORMAL}", "{DARK_RED}", "{PINK}", "{GREEN}", "{YELLOW}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}", "{ORANGE}", "{LIGHT_BLUE}", "{DARK_BLUE}", "{PURPLE}"};
static char _colorCodes[][] = {"\x01",     "\x02",      "\x03",   "\x04",         "\x05",     "\x06",          "\x07",        "\x08",   "\x09",     "\x0B",         "\x0C",        "\x0E"};

// Convenience macro for looping over match teams.
#define LOOP_TEAMS(%1) for (MatchTeam %1=MatchTeam_Team1; %1 < MatchTeam_Count; %1++)

// These match CS:GO's m_gamePhase values.
enum GamePhase {
    GamePhase_FirstHalf = 2,
    GamePhase_SecondHalf = 3,
    GamePhase_HalfTime = 4,
    GamePhase_PostGame = 5,
};

/**
 * Returns the number of human clients on a team.
 */
stock int GetNumHumansOnTeam(int team) {
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && GetClientTeam(i) == team)
            count++;
    }
    return count;
}

stock int CountAlivePlayersOnTeam(int team) {
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)
            count++;
    }
    return count;
}

stock int SumHealthOfTeam(int team) {
    int sum = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) {
            sum += GetClientHealth(i);
        }
    }
    return sum;
}

/**
 * Switches and respawns a player onto a new team.
 */
stock void SwitchPlayerTeam(int client, int team) {
    if (GetClientTeam(client) == team)
        return;

    LogDebug("SwitchPlayerTeam %L to %d", client, team);
    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
        CS_RespawnPlayer(client);
    } else {
        ChangeClientTeam(client, team);
    }
}

/**
 * Returns if a client is valid.
 */
stock bool IsValidClient(int client) {
    return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client);
}

stock bool IsPlayer(int client) {
    return IsValidClient(client) && !IsFakeClient(client);
}

stock bool IsAuthedPlayer(int client) {
    return IsPlayer(client) && IsClientAuthorized(client);
}

/**
 * Returns the number of clients that are actual players in the game.
 */
stock int GetRealClientCount() {
    int clients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            clients++;
        }
    }
    return clients;
}

stock void Colorize(char[] msg, int size, bool stripColor=false) {
    for (int i = 0; i < sizeof(_colorNames); i ++) {
        if (stripColor)
            ReplaceString(msg, size, _colorNames[i], "\x01"); // replace with white
        else
            ReplaceString(msg, size, _colorNames[i], _colorCodes[i]);
    }
}

stock void ReplaceStringWithInt(char[] buffer, int len, const char[] replace,
                                int value, bool caseSensitive=false) {
    char intString[MAX_INTEGER_STRING_LENGTH];
    IntToString(value, intString, sizeof(intString));
    ReplaceString(buffer, len, replace, intString, caseSensitive);
}

stock bool IsTVEnabled() {
    Handle tvEnabledCvar = FindConVar("tv_enable");
    if (tvEnabledCvar == INVALID_HANDLE) {
        LogError("Failed to get tv_enable cvar");
        return false;
    }
    return GetConVarInt(tvEnabledCvar) != 0;
}

stock bool Record(const char[] demoName) {
    char szDemoName[256];
    strcopy(szDemoName, sizeof(szDemoName), demoName);
    ReplaceString(szDemoName, sizeof(szDemoName), "\"", "\\\"");
    ServerCommand("tv_record \"%s\"", szDemoName);

    if (!IsTVEnabled()) {
        LogError("Autorecording will not work with current cvar \"tv_enable\"=0. Set \"tv_enable 1\" in server.cfg (or another config file) to fix this.");
        return false;
    }

    return true;
}

stock void StopRecording() {
    ServerCommand("tv_stoprecord");
}

stock bool InWarmup() {
    return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

stock bool InOvertime() {
    return GameRules_GetProp("m_nOvertimePlaying") != 0;
}

stock bool InFreezeTime() {
    return GameRules_GetProp("m_bFreezePeriod") != 0;
}

stock void EnsurePausedWarmup() {
    if (!InWarmup()) {
        StartWarmup();
    }
    FindConVar("mp_warmup_pausetimer").IntValue = 1;
}

stock void StartWarmup(bool indefiniteWarmup=true, int warmupTime=60) {
    if (indefiniteWarmup) {
        FindConVar("mp_warmup_pausetimer").IntValue = 1;
    }

    ServerCommand("mp_warmuptime %d", warmupTime);
    ServerCommand("mp_warmup_start");

    // for some reason this needs to get set multiple times to work correctly on occasion? (valve pls)
    if (indefiniteWarmup) {
        FindConVar("mp_warmup_pausetimer").IntValue = 1;
    }
}

stock void EndWarmup() {
    ServerCommand("mp_warmup_end");
}

stock bool IsPaused() {
    return GameRules_GetProp("m_bMatchWaitingForResume") != 0;
}

stock void Pause() {
    ServerCommand("mp_pause_match");
}

stock void Unpause() {
    ServerCommand("mp_unpause_match");
}

stock void RestartGame(int delay) {
    ServerCommand("mp_restartgame %d", delay);
}

stock bool IsClientCoaching(int client) {
    return GetClientTeam(client) == CS_TEAM_SPECTATOR &&
        GetEntProp(client, Prop_Send, "m_iCoachingTeam") != 0;
}

stock void UpdateCoachTarget(int client, int team) {
    SetEntProp(client, Prop_Send, "m_iCoachingTeam", team);
}

stock void SetTeamInfo(int team, const char[] name, const char[] flag="", const char[] logo="", const char[] matchstat="") {
    int team_int = (team == CS_TEAM_CT) ? 1 : 2;

    char teamCvarName[32];
    char flagCvarName[32];
    char logoCvarName[32];
    char textCvarName[32];
    Format(teamCvarName, sizeof(teamCvarName), "mp_teamname_%d", team_int);
    Format(flagCvarName, sizeof(flagCvarName), "mp_teamflag_%d", team_int);
    Format(logoCvarName, sizeof(logoCvarName), "mp_teamlogo_%d", team_int);
    Format(textCvarName, sizeof(textCvarName), "mp_teammatchstat_%d", team_int);

    SetConVarStringSafe(teamCvarName, name);
    SetConVarStringSafe(flagCvarName, flag);
    SetConVarStringSafe(logoCvarName, logo);
    SetConVarStringSafe(textCvarName, matchstat);
}

stock void SetConVarIntSafe(const char[] name, int value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("Failed to find cvar: \"%s\"", name);
    } else {
        SetConVarInt(cvar, value);
    }
}

stock void SetConVarStringSafe(const char[] name, const char[] value) {
    Handle cvar = FindConVar(name);
    if (cvar == INVALID_HANDLE) {
        LogError("Failed to find cvar: \"%s\"", name);
    } else {
        SetConVarString(cvar, value);
    }
}

stock bool OnActiveTeam(int client) {
    if (!IsPlayer(client))
        return false;

    int team = GetClientTeam(client);
    return team == CS_TEAM_CT || team == CS_TEAM_T;
}

stock int GetCvarIntSafe(const char[] cvarName) {
    Handle cvar = FindConVar(cvarName);
    if (cvar == INVALID_HANDLE) {
        LogError("Failed to find cvar \"%s\"", cvar);
        return 0;
    } else {
        return GetConVarInt(cvar);
    }
}

stock void GetCleanMapName(char[] buffer, int size) {
    char mapName[PLATFORM_MAX_PATH];
    GetCurrentMap(mapName, sizeof(mapName));
    FormatMapName(mapName, buffer, size);
}

stock GamePhase GetGamePhase() {
    return view_as<GamePhase>(GameRules_GetProp("m_gamePhase"));
}

stock bool InHalftimePhase() {
    return GetGamePhase() == GamePhase_HalfTime;
}

stock int AddSubsectionKeysToList(KeyValues kv, const char[] section, ArrayList list, int maxKeyLength) {
    int count = 0;
    if (kv.JumpToKey(section)) {
        count = AddKeysToList(kv, list, maxKeyLength);
        kv.GoBack();
    }
    return count;
}

stock int AddKeysToList(KeyValues kv, ArrayList list, int maxKeyLength) {
    int count = 0;
    char[] buffer = new char[maxKeyLength];
    if (kv.GotoFirstSubKey(false)) {
        do {
            count++;
            kv.GetSectionName(buffer, maxKeyLength);
            list.PushString(buffer);
        } while (kv.GotoNextKey(false));
        kv.GoBack();
    }
    return count;
}

stock bool RemoveStringFromArray(ArrayList list, const char[] str) {
    int index = list.FindString(str);
    if (index != -1) {
        list.Erase(index);
        return true;
    }
    return false;
}

stock int FindAuthInArray(ArrayList list, const char[] auth) {
    char tmp[AUTH_LENGTH];
    for (int i = 0; i < list.Length; i++) {
        list.GetString(i, tmp, sizeof(tmp));
        if (SteamIdsEqual(auth, tmp))
            return i;
    }
    return -1;
}

stock bool RemoveAuthFromArray(ArrayList list, const char[] auth) {
    int index = FindAuthInArray(list, auth);
    if (index != -1) {
        list.Erase(index);
        return true;
    }
    return false;
}

stock int OtherCSTeam(int team) {
    if (team == CS_TEAM_CT) {
        return CS_TEAM_T;
    } else if (team == CS_TEAM_T) {
        return CS_TEAM_CT;
    } else {
        return team;
    }
}

stock MatchTeam OtherMatchTeam(MatchTeam team) {
    if (team == MatchTeam_Team1) {
        return MatchTeam_Team2;
    } else if (team == MatchTeam_Team2) {
        return MatchTeam_Team1;
    } else {
        return team;
    }
}

stock bool SteamIdsEqual(const char[] id1, const char[] id2) {
    if (StrEqual(id1, id2, false)) {
        return true;
    }

    if (strlen(id1) < 10 || strlen(id2) < 10) {
        return false;
    }
    return StrEqual(id1[10], id2[10]);
}

// TODO: might want a auth->client adt-trie to speed this up, maintained during
// client auth and disconnect forwards.
stock int AuthToClient(const char[] auth) {
    for (int i = 1; i <= MaxClients; i++) {
        if (IsAuthedPlayer(i)) {
            char clientAuth[AUTH_LENGTH];
            GetClientAuthId(i, AUTH_METHOD, clientAuth, sizeof(clientAuth));
            if (SteamIdsEqual(auth, clientAuth)) {
                return i;
            }
        }
    }
    return -1;
}

stock int MaxMapsToPlay(int mapsToWin) {
    return 2 * mapsToWin - 1;
}

stock void CSTeamString(int csTeam, char[] buffer, int len) {
    if (csTeam == CS_TEAM_CT) {
        Format(buffer, len, "CT");
    } else {
        Format(buffer, len, "T");
    }
}

stock void GameStateString(GameState state, char[] buffer, int length) {
    switch(state) {
        case GameState_None: Format(buffer, length, "none");
        case GameState_PreVeto: Format(buffer, length, "waiting for map veto");
        case GameState_Veto: Format(buffer, length, "map veto");
        case GameState_Warmup: Format(buffer, length, "warmup");
        case GameState_KnifeRound: Format(buffer, length, "knife round");
        case GameState_WaitingForKnifeRoundDecision: Format(buffer, length, "waiting for knife round decision");
        case GameState_GoingLive: Format(buffer, length, "going live");
        case GameState_Live: Format(buffer, length, "live");
        case GameState_PostGame: Format(buffer, length, "postgame");
    }
}

public MatchSideType MatchSideTypeFromString(const char[] str) {
    if (StrEqual(str, "normal", false) || StrEqual(str, "standard", false)) {
        return MatchSideType_Standard;
    } else if (StrEqual(str, "never_knife", false)) {
        return MatchSideType_NeverKnife;
    } else {
        return MatchSideType_AlwaysKnife;
    }
}

stock void ExecCfg(ConVar cvar) {
    char cfg[PLATFORM_MAX_PATH];
    cvar.GetString(cfg, sizeof(cfg));
    ServerCommand("exec \"%s\"", cfg);
}
