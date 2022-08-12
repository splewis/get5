// See include/pugsetup.inc for documentation.

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
  CreateNative("Get5_GetGameState", Native_GetGameState);
  CreateNative("Get5_Message", Native_Message);
  CreateNative("Get5_MessageToTeam", Native_MessageToTeam);
  CreateNative("Get5_MessageToAll", Native_MessageToAll);
  CreateNative("Get5_LoadMatchConfig", Native_LoadMatchConfig);
  CreateNative("Get5_LoadMatchConfigFromURL", Native_LoadMatchConfigFromURL);
  CreateNative("Get5_AddPlayerToTeam", Native_AddPlayerToTeam);
  CreateNative("Get5_SetPlayerName", Native_SetPlayerName);
  CreateNative("Get5_RemovePlayerFromTeam", Native_RemovePlayerFromTeam);
  CreateNative("Get5_GetPlayerTeam", Native_GetPlayerTeam);
  CreateNative("Get5_CSTeamToGet5Team", Native_CSTeamToGet5Team);
  CreateNative("Get5_Get5TeamToCSTeam", Native_Get5TeamToCSTeam);
  CreateNative("Get5_GetTeamScores", Native_GetTeamScores);
  CreateNative("Get5_GetMatchID", Native_GetMatchID);
  CreateNative("Get5_SetMatchID", Native_SetMatchID);
  CreateNative("Get5_GetServerID", Native_GetServerID);
  CreateNative("Get5_GetMapNumber", Native_GetMapNumber);
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
  char buffer[1024];
  FormatNativeString(0, 2, 3, sizeof(buffer), _, buffer);
  PrintMessage(buffer, Get5Team_None, client);
}

public int Native_MessageToTeam(Handle plugin, int numParams) {
  Get5Team team = view_as<Get5Team>(GetNativeCell(1));
  char buffer[1024];
  FormatNativeString(0, 2, 3, sizeof(buffer), _, buffer);
  PrintMessage(buffer, team, 0);
}

public int Native_MessageToAll(Handle plugin, int numParams) {
  char buffer[1024];
  FormatNativeString(0, 1, 2, sizeof(buffer), _, buffer);
  PrintMessage(buffer, Get5Team_None, 0);
}

static void PrintMessage(const char[] message, const Get5Team onlyForTeam, const int onlyForClient) {
  char prefix[64];
  g_MessagePrefixCvar.GetString(prefix, sizeof(prefix));
  char prefixedMsg[1024];
  if (StrEqual(prefix, "")) {
    Format(prefixedMsg, sizeof(prefixedMsg), " %s", message);
  } else {
    Format(prefixedMsg, sizeof(prefixedMsg), "%s %s", prefix, message);
  }

  if (onlyForClient == 0) {
    // Copy the string and strip color tags for console output, if the message is not only for one client.
    char consoleMessage[1024];
    strcopy(consoleMessage, sizeof(consoleMessage), prefixedMsg);
    Colorize(consoleMessage, sizeof(consoleMessage), true);
    PrintToConsole(0, consoleMessage);
  }

  // Replace color tags with colors for client output
  Colorize(prefixedMsg, sizeof(prefixedMsg), false);

  if (onlyForClient > 0) {
    if (IsClientConnected(onlyForClient) && IsClientInGame(onlyForClient)) {
      SetGlobalTransTarget(onlyForClient);
      PrintToChat(onlyForClient, prefixedMsg);
    }
    return;
  }

  LOOP_CLIENTS(i) {
    if (!IsClientConnected(i) || !IsClientInGame(i)) {
      continue;
    }
    if (onlyForTeam == Get5Team_None || GetClientMatchTeam(i) == onlyForTeam) {
      SetGlobalTransTarget(i);
      PrintToChat(i, prefixedMsg);
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
  Get5Team team = view_as<Get5Team>(GetNativeCell(2));
  char name[MAX_NAME_LENGTH];
  if (numParams >= 3) {
    GetNativeString(3, name, sizeof(name));
  }
  return AddPlayerToTeam(auth, team, name);
}

public int Native_SetPlayerName(Handle plugin, int numParams) {
  char auth[AUTH_LENGTH];
  char name[MAX_NAME_LENGTH];
  GetNativeString(1, auth, sizeof(auth));
  GetNativeString(2, name, sizeof(name));
  char steam64[AUTH_LENGTH];
  ConvertAuthToSteam64(auth, steam64);
  if (strlen(name) > 0 && !StrEqual(name, KEYVALUE_STRING_PLACEHOLDER)) {
    g_PlayerNames.SetString(steam64, name);
    LoadPlayerNames();
  }
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
    return view_as<int>(Get5Team_None);
  }
}

public int Native_CSTeamToGet5Team(Handle plugin, int numParams) {
  return view_as<int>(CSTeamToGet5Team(GetNativeCell(1)));
}

public int Native_Get5TeamToCSTeam(Handle plugin, int numParams) {
  return Get5TeamToCSTeam(GetNativeCell(1));
}

public int Native_GetTeamScores(Handle plugin, int numParams) {
  Get5Team team = GetNativeCell(1);
  if (team == Get5Team_1 || team == Get5Team_2) {
    SetNativeCellRef(2, g_TeamSeriesScores[team]);
    SetNativeCellRef(3, CS_GetTeamScore(Get5TeamToCSTeam(team)));
  }
}

public int Native_GetMatchID(Handle plugin, int numParams) {
  SetNativeString(1, g_MatchID, GetNativeCell(2));
  return 0;
}

public int Native_SetMatchID(Handle plugin, int numParams) {
  GetNativeString(1, g_MatchID, sizeof(g_MatchID));
  WriteBackup();
  return 0;
}

public int Native_GetServerID(Handle plugin, int numParams) {
  return g_ServerIdCvar.IntValue;
}

public int Native_GetMapNumber(Handle plugin, int numParams) {
  return g_TeamSeriesScores[Get5Team_1] + g_TeamSeriesScores[Get5Team_2] +
         g_TeamSeriesScores[Get5Team_None];
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
