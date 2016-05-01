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
    ArrayList paramNames = view_as<ArrayList>(GetNativeCell(2));
    ArrayList paramValues = view_as<ArrayList>(GetNativeCell(3));
    return LoadMatchFromUrl(url, paramNames, paramValues);
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
