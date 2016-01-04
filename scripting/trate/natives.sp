// See include/pugsetup.inc for documentation.
#define MESSAGE_PREFIX "[\x05Trate\x01]"

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("Trate_GetGameState", Native_GetGameState);
    CreateNative("Trate_Message", Native_TrateMessage);
    CreateNative("Trate_MessageToAll", Native_TrateMessageToAll);
    RegPluginLibrary("trate");
    return APLRes_Success;
}

public int Native_GetGameState(Handle plugin, int numParams) {
    return view_as<int>(g_GameState);
}

public int Native_TrateMessage(Handle plugin, int numParams) {
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

public int Native_TrateMessageToAll(Handle plugin, int numParams) {
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
