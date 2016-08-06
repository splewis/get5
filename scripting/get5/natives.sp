// See include/pugsetup.inc for documentation.
#define MESSAGE_PREFIX "[\x05Get5\x01]"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("Get5_GetGameState", Native_GetGameState);
    CreateNative("Get5_Message", Native_Message);
    CreateNative("Get5_MessageToAll", Native_MessageToAll);
    CreateNative("Get5_LoadMatchConfig", Native_LoadMatchConfig);
    CreateNative("Get5_LoadMatchConfigFromURL", Native_LoadMatchConfigFromURL);
    CreateNative("Get5_AddPlayerToTeam", Native_AddPlayerToTeam);
    CreateNative("Get5_RemovePlayerFromTeam", Native_RemovePlayerFromTeam);
    CreateNative("Get5_GetPlayerTeam", Native_GetPlayerTeam);
    CreateNative("Get5_CSTeamToMatchTeam", Native_CSTeamToMatchTeam);
    CreateNative("Get5_MatchTeamToCSTeam", Native_MatchTeamToCSTeam);
    CreateNative("Get5_GetTeamScores", Native_GetTeamScores);
    CreateNative("Get5_GetMatchID", Native_GetMatchID);
    CreateNative("Get5_SetMatchID", Native_SetMatchID);
    CreateNative("Get5_AddLiveCvar", Native_AddLiveCvar);
    CreateNative("Get5_IncreasePlayerStat", Native_IncreasePlayerStat);
    CreateNative("Get5_GetMatchStats", Native_GetMatchStats);
    RegPluginLibrary("get5");
    return APLRes_Success;
}

public int Native_GetGameState(Handle plugin, int numParams) {
    return view_as<int>(g_GameState);
}

public int Native_Message(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    if (client != 0 && (!IsClientConnected(client) || !IsClientInGame(client)))
        return;

    char buffer[1024];
    int bytesWritten = 0;
    SetGlobalTransTarget(client);
    FormatNativeString(0, 2, 3, sizeof(buffer), bytesWritten, buffer);

    char prefix[64] = MESSAGE_PREFIX;
    // g_MessagePrefixCvar.GetString(prefix, sizeof(prefix));

    char finalMsg[1024];
    if (StrEqual(prefix, ""))
        Format(finalMsg, sizeof(finalMsg), " %s", buffer);
    else
        Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

    if (client == 0) {
        Colorize(finalMsg, sizeof(finalMsg), false);
        PrintToConsole(client, finalMsg);
    } else if (IsClientInGame(client)) {
        Colorize(finalMsg, sizeof(finalMsg));
        PrintToChat(client, finalMsg);
    }

}

public int Native_MessageToAll(Handle plugin, int numParams) {
    char prefix[64] = MESSAGE_PREFIX;
    // g_MessagePrefixCvar.GetString(prefix, sizeof(prefix));
    char buffer[1024];
    int bytesWritten = 0;

    for (int i = 0; i <= MaxClients; i++) {
        if (i != 0 && (!IsClientConnected(i) || !IsClientInGame(i)))
            continue;

        SetGlobalTransTarget(i);
        FormatNativeString(0, 1, 2, sizeof(buffer), bytesWritten, buffer);

        char finalMsg[1024];
        if (StrEqual(prefix, ""))
            Format(finalMsg, sizeof(finalMsg), " %s", buffer);
        else
            Format(finalMsg, sizeof(finalMsg), "%s %s", prefix, buffer);

        if (i != 0) {
            Colorize(finalMsg, sizeof(finalMsg));
            PrintToChat(i, finalMsg);
        } else {
            Colorize(finalMsg, sizeof(finalMsg), false);
            PrintToConsole(i, finalMsg);
        }
    }
}

public int Native_LoadMatchConfig(Handle plugin, int numParams) {
    char filename[PLATFORM_MAX_PATH];
    GetNativeString(1, filename, sizeof(filename));
    return LoadMatchConfig(filename);
}

public int Native_LoadMatchConfigFromURL(Handle plugin, int numParams) {
    char url[PLATFORM_MAX_PATH];
    GetNativeString(1, url, sizeof(url));
    bool preferSystem2 = GetNativeCell(2);
    ArrayList paramNames = view_as<ArrayList>(GetNativeCell(3));
    ArrayList paramValues = view_as<ArrayList>(GetNativeCell(4));
    return LoadMatchFromUrl(url, preferSystem2, paramNames, paramValues);
}

public int Native_AddPlayerToTeam(Handle plugin, int numParams) {
    char auth[AUTH_LENGTH];
    GetNativeString(1, auth, sizeof(auth));
    MatchTeam team = view_as<MatchTeam>(GetNativeCell(2));
    return AddPlayerToTeam(auth, team);
}

public int Native_RemovePlayerFromTeam(Handle plugin, int numParams) {
    char auth[AUTH_LENGTH];
    GetNativeString(1, auth, sizeof(auth));
    return RemovePlayerFromTeams(auth);
}

public int Native_GetPlayerTeam(Handle plugin, int numParams) {
    char auth[AUTH_LENGTH];
    GetNativeString(1, auth, sizeof(auth));

    char steam64Auth[AUTH_LENGTH];
    if (ConvertAuthToSteam64(auth, steam64Auth, false)) {
        return view_as<int>(GetAuthMatchTeam(steam64Auth));
    } else {
        return view_as<int>(MatchTeam_TeamNone);
    }
}

public int Native_CSTeamToMatchTeam(Handle plugin, int numParams) {
    return view_as<int>(CSTeamToMatchTeam(GetNativeCell(1)));
}

public int Native_MatchTeamToCSTeam(Handle plugin, int numParams) {
    return MatchTeamToCSTeam(GetNativeCell(1));
}

public int Native_GetTeamScores(Handle plugin, int numParams) {
    MatchTeam team = GetNativeCell(1);
    if (team == MatchTeam_Team1 || team == MatchTeam_Team2) {
        SetNativeCellRef(2, g_TeamSeriesScores[team]);
        SetNativeCellRef(3, CS_GetTeamScore(MatchTeamToCSTeam(team)));
    }
}

public int Native_GetMatchID(Handle plugin, int numParams) {
    SetNativeString(1, g_MatchID, GetNativeCell(2));
    return 0;
}

public int Native_SetMatchID(Handle plugin, int numParams) {
    GetNativeString(1, g_MatchID, sizeof(g_MatchID));
    return 0;
}

public int Native_AddLiveCvar(Handle plugin, int numParams) {
    char cvarName[MAX_CVAR_LENGTH];
    char cvarValue[MAX_CVAR_LENGTH];
    GetNativeString(1, cvarName, sizeof(cvarName));
    GetNativeString(2, cvarValue, sizeof(cvarValue));
    int index = g_CvarNames.FindString(cvarName);

    bool override = false;
    if (numParams >= 3) {
        override = (GetNativeCell(3) != 0);
    }

    if (index == -1) {
        g_CvarNames.PushString(cvarName);
        g_CvarValues.PushString(cvarValue);
    } else if (override) {
        g_CvarValues.SetString(index, cvarValue);
    }

    return 0;
}

public int Native_IncreasePlayerStat(Handle plugin, int numParams) {
    int client = GetNativeCell(1);
    char field[64];
    GetNativeString(2, field, sizeof(field));
    int amount = GetNativeCell(3);
    return AddToPlayerStat(client, field, amount);
}

public int Native_GetMatchStats(Handle plugin, int numParams) {
    Handle output = GetNativeCell(1);
    if (output == INVALID_HANDLE) {
        return view_as<int>(false);
    } else {
        KvCopySubkeys(g_StatsKv, output);
        g_StatsKv.Rewind();
        return view_as<int>(true);
    }
}
