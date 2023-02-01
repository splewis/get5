#include <sdktools>

#define MAX_INTEGER_STRING_LENGTH 16
#define MAX_FLOAT_STRING_LENGTH   32
#define AUTH_LENGTH               64

// Dummy value for when we need to write a KeyValue string, but we don't care about the value *or*
// when the value is an empty string. Trying to write an empty string results in the KeyValue not
// being written, so we use this.
#define KEYVALUE_STRING_PLACEHOLDER "__placeholder"

static char _colorNames[][] = {"{NORMAL}",      "{DARK_RED}",  "{PINK}", "{GREEN}",  "{YELLOW}",
                               "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}", "{ORANGE}", "{LIGHT_BLUE}",
                               "{DARK_BLUE}",   "{PURPLE}",    "{GOLD}"};
static char _colorCodes[][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07",
                               "\x08", "\x09", "\x0B", "\x0C", "\x0E", "\x10"};

// Convenience macros.
#define LOOP_TEAMS(%1)   for (Get5Team %1 = Get5Team_1; %1 < Get5Team_Count; %1 ++)
#define LOOP_CLIENTS(%1) for (int %1 = 1; %1 <= MaxClients; %1 ++)

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
  LOOP_CLIENTS(i) {
    if (IsPlayer(i) && GetClientTeam(i) == team) {
      count++;
    }
  }
  return count;
}

stock int CountAlivePlayersOnTeam(const Get5Side side) {
  int count = 0;
  LOOP_CLIENTS(i) {
    if (IsValidClient(i) && IsPlayerAlive(i) && view_as<Get5Side>(GetClientTeam(i)) == side) {
      count++;
    }
  }
  return count;
}

stock int SumHealthOfTeam(Get5Side side) {
  int sum = 0;
  LOOP_CLIENTS(i) {
    if (IsValidClient(i) && IsPlayerAlive(i) && view_as<Get5Side>(GetClientTeam(i)) == side) {
      sum += GetClientHealth(i);
    }
  }
  return sum;
}

stock int ConvertCSTeamToDefaultWinReason(int side) {
  // This maps to
  // https://github.com/VSES/SourceEngine2007/blob/master/se2007/game/shared/cstrike/cs_gamerules.h,
  // which is the regular CSRoundEndReason + 1.
  return view_as<int>(side == CS_TEAM_CT ? CSRoundEnd_CTWin : CSRoundEnd_TerroristWin) + 1;
}

stock void SwitchPlayerTeam(int client, Get5Side side, bool useDefaultTeamSelection = true) {
  // Check avoids killing player if they're already on the right team.
  int team = view_as<int>(side);
  if (GetClientTeam(client) == team) {
    return;
  }
  if (useDefaultTeamSelection || team == CS_TEAM_SPECTATOR) {
    ChangeClientTeam(client, team);
  } else {
    // When doing side-swap in knife-rounds, we do this to prevent the score from going -1 for
    // everyone.
    CS_SwitchTeam(client, team);
    CS_UpdateClientModel(client);
    CS_RespawnPlayer(client);
  }
}

/**
 * Returns if a client is valid.
 */
stock bool IsValidClient(int client) {
  return client > 0 && client <= MaxClients && IsClientInGame(client);
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
  LOOP_CLIENTS(i) {
    if (IsPlayer(i)) {
      clients++;
    }
  }
  return clients;
}

stock void Colorize(char[] msg, int size, bool stripColor = false) {
  for (int i = 0; i < sizeof(_colorNames); i++) {
    if (stripColor) {
      ReplaceString(msg, size, _colorNames[i], "");  // replace with no color tag
    } else {
      ReplaceString(msg, size, _colorNames[i], _colorCodes[i]);
    }
  }
}

stock void FormatChatCommand(char[] buffer, const int bufferLength, const char[] command) {
  Format(buffer, bufferLength, "{GREEN}%s{NORMAL}", command);
}

stock void FormatTimeString(char[] buffer, const int bufferLength, const char[] formattedTime) {
  Format(buffer, bufferLength, "{GREEN}%s{NORMAL}", formattedTime);
}

stock void FormatCvarName(char[] buffer, const int bufferLength, const char[] cVar) {
  Format(buffer, bufferLength, "{GRAY}%s{NORMAL}", cVar);
}

stock void FormatPlayerName(char[] buffer, const int bufferLength, const int client, const Get5Team team) {
  // Used when injecting the team for coaching players, who are always on team spectator.
  Get5Side side = view_as<Get5Side>(Get5_Get5TeamToCSTeam(team));
  if (side == Get5Side_CT) {
    FormatEx(buffer, bufferLength, "{LIGHT_BLUE}%N{NORMAL}", client);
  } else if (side == Get5Side_T) {
    FormatEx(buffer, bufferLength, "{GOLD}%N{NORMAL}", client);
  } else {
    FormatEx(buffer, bufferLength, "{PURPLE}%N{NORMAL}", client);
  }
}

stock void ReplaceStringWithInt(char[] buffer, int len, const char[] replace, int value, bool caseSensitive = true) {
  char intString[MAX_INTEGER_STRING_LENGTH];
  IntToString(value, intString, sizeof(intString));
  ReplaceString(buffer, len, replace, intString, caseSensitive);
}

stock void AnnouncePhaseChange(const char[] format, const char[] message) {
  int count = g_PhaseAnnouncementCountCvar.IntValue;
  if (count > 10) {
    count = 10;
  }
  for (int i = 0; i < count; i++) {
    Get5_MessageToAll(format, message);
  }
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

stock bool CheckKeyValuesFile(const char[] file, char[] error, const int errSize) {
  // Because KeyValues.ImportFromFile does not actually return false if the syntax is invalid, we use the SMC parser to
  // parse the file before trying to import it, as this correctly detects syntax errors which we can return to the
  // user, instead of trying to load data from an invalid KV structure.
  SMCParser parser = new SMCParser();
  SMCError result = parser.ParseFile(file);
  if (result != SMCError_Okay) {
    parser.GetErrorString(result, error, errSize);
  }
  delete parser;
  return result == SMCError_Okay;
}

stock void StartWarmup(int warmupTime = 0) {
  ServerCommand("mp_do_warmup_period 1");
  ServerCommand("mp_warmuptime_all_players_connected 0");
  ServerCommand("mp_warmup_start");
  if (warmupTime < 1) {
    LogDebug("Setting indefinite warmup.");
    // Setting mp_warmuptime to anything less than 7 triggers the countdown to restart regardless of
    // mp_warmup_pausetimer 1, and this might be tick-related, so we set it to 10 just for good
    // measure.
    ServerCommand("mp_warmuptime 10");
    ServerCommand("mp_warmup_pausetimer 1");
  } else {
    ServerCommand("mp_warmuptime %d", warmupTime);
    ServerCommand("mp_warmup_pausetimer 0");
  }
}

stock bool IsPaused() {
  return GameRules_GetProp("m_bMatchWaitingForResume") != 0;
}

stock void RestartGame(int delay = 1) {
  ServerCommand("mp_restartgame %d", delay);
}

stock void SetTeamInfo(const Get5Side side, const char[] name, const char[] flag, const char[] logo,
                       const char[] matchstat, int series_score) {
  int team_int = (side == Get5Side_CT) ? 1 : 2;

  char teamCvarName[MAX_CVAR_LENGTH];
  char flagCvarName[MAX_CVAR_LENGTH];
  char logoCvarName[MAX_CVAR_LENGTH];
  char textCvarName[MAX_CVAR_LENGTH];
  char scoreCvarName[MAX_CVAR_LENGTH];
  FormatEx(teamCvarName, sizeof(teamCvarName), "mp_teamname_%d", team_int);
  FormatEx(flagCvarName, sizeof(flagCvarName), "mp_teamflag_%d", team_int);
  FormatEx(logoCvarName, sizeof(logoCvarName), "mp_teamlogo_%d", team_int);
  FormatEx(textCvarName, sizeof(textCvarName), "mp_teammatchstat_%d", team_int);
  FormatEx(scoreCvarName, sizeof(scoreCvarName), "mp_teamscore_%d", team_int);

  // Add Ready/Not ready tags to team name if in warmup.
  char taggedName[MAX_CVAR_LENGTH];
  if (g_ReadyTeamTagCvar.BoolValue) {
    if (IsReadyGameState()) {
      Get5Team matchTeam = CSTeamToGet5Team(view_as<int>(side));
      if (IsTeamReady(matchTeam)) {
        FormatEx(taggedName, sizeof(taggedName), "%s %T", name, "ReadyTag", LANG_SERVER);
      } else {
        FormatEx(taggedName, sizeof(taggedName), "%s %T", name, "NotReadyTag", LANG_SERVER);
      }
    } else {
      strcopy(taggedName, sizeof(taggedName), name);
    }
  } else {
    strcopy(taggedName, sizeof(taggedName), name);
  }

  SetConVarStringSafe(teamCvarName, taggedName);
  SetConVarStringSafe(flagCvarName, flag);
  SetConVarStringSafe(logoCvarName, logo);
  SetConVarStringSafe(textCvarName, matchstat);

  // We do this because IntValue = 0 does not consistently set an empty string, relevant for testing.
  if (g_MapsToWin > 1 && series_score > 0) {
    SetConVarIntSafe(scoreCvarName, series_score);
  } else {
    SetConVarStringSafe(scoreCvarName, "");
  }
}

stock void SetConVarIntSafe(const char[] name, int value) {
  ConVar cvar = FindConVar(name);
  if (cvar == null) {
    LogError("Failed to find cvar: \"%s\"", name);
  } else {
    cvar.IntValue = value;
  }
}

stock bool SetConVarStringSafe(const char[] name, const char[] value) {
  ConVar cvar = FindConVar(name);
  if (cvar == null) {
    LogError("Failed to find cvar: \"%s\"", name);
    return false;
  } else {
    cvar.SetString(value);
    return true;
  }
}

stock bool GetConVarStringSafe(const char[] name, char[] value, int len) {
  ConVar cvar = FindConVar(name);
  if (cvar == null) {
    LogError("Failed to find cvar: \"%s\"", name);
    return false;
  } else {
    cvar.GetString(value, len);
    return true;
  }
}

stock bool OnActiveTeam(int client) {
  if (!IsPlayer(client))
    return false;

  int team = GetClientTeam(client);
  return team == CS_TEAM_CT || team == CS_TEAM_T;
}

stock int GetCvarIntSafe(const char[] cvarName) {
  ConVar cvar = FindConVar(cvarName);
  if (cvar == null) {
    LogError("Failed to find cvar \"%s\"", cvar);
    return 0;
  } else {
    return cvar.IntValue;
  }
}

stock void FormatMapName(const char[] mapName, char[] buffer, int len, bool cleanName = false, bool color = false) {
  // explode map by '/' so we can remove any directory prefixes (e.g. workshop stuff)
  char buffers[4][PLATFORM_MAX_PATH];
  int numSplits = ExplodeString(mapName, "/", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
  int mapStringIndex = (numSplits > 0) ? (numSplits - 1) : (0);
  strcopy(buffer, len, buffers[mapStringIndex]);

  // do it with backslashes too
  numSplits = ExplodeString(buffer, "\\", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
  mapStringIndex = (numSplits > 0) ? (numSplits - 1) : (0);
  strcopy(buffer, len, buffers[mapStringIndex]);

  if (cleanName) {
    if (StrEqual(buffer, "de_cache")) {
      strcopy(buffer, len, "Cache");
    } else if (StrEqual(buffer, "de_inferno")) {
      strcopy(buffer, len, "Inferno");
    } else if (StrEqual(buffer, "de_dust2")) {
      strcopy(buffer, len, "Dust II");
    } else if (StrEqual(buffer, "de_mirage")) {
      strcopy(buffer, len, "Mirage");
    } else if (StrEqual(buffer, "de_train")) {
      strcopy(buffer, len, "Train");
    } else if (StrEqual(buffer, "de_cbble")) {
      strcopy(buffer, len, "Cobblestone");
    } else if (StrEqual(buffer, "de_anubis")) {
      strcopy(buffer, len, "Anubis");
    } else if (StrEqual(buffer, "de_overpass")) {
      strcopy(buffer, len, "Overpass");
    } else if (StrEqual(buffer, "de_nuke")) {
      strcopy(buffer, len, "Nuke");
    } else if (StrEqual(buffer, "de_vertigo")) {
      strcopy(buffer, len, "Vertigo");
    } else if (StrEqual(buffer, "de_ancient")) {
      strcopy(buffer, len, "Ancient");
    } else if (StrEqual(buffer, "de_tuscan")) {
      strcopy(buffer, len, "Tuscan");
    } else if (StrEqual(buffer, "de_prime")) {
      strcopy(buffer, len, "Prime");
    } else if (StrEqual(buffer, "de_grind")) {
      strcopy(buffer, len, "Grind");
    } else if (StrEqual(buffer, "de_mocha")) {
      strcopy(buffer, len, "Mocha");
    } else if (StrEqual(buffer, "cs_militia")) {
      strcopy(buffer, len, "Militia");
    } else if (StrEqual(buffer, "cs_agency")) {
      strcopy(buffer, len, "Agency");
    } else if (StrEqual(buffer, "cs_office")) {
      strcopy(buffer, len, "Office");
    } else if (StrEqual(buffer, "cs_italy")) {
      strcopy(buffer, len, "Italy");
    } else if (StrEqual(buffer, "cs_assault")) {
      strcopy(buffer, len, "Assault");
    }
  }
  if (color) {
    Format(buffer, len, "{GREEN}%s{NORMAL}", buffer);
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

stock int AddSubsectionKeysToList(const KeyValues kv, const char[] section, const ArrayList list, int maxKeyLength) {
  int count = 0;
  if (kv.JumpToKey(section)) {
    count = AddKeysToList(kv, list, maxKeyLength);
    kv.GoBack();
  }
  return count;
}

stock int AddKeysToList(const KeyValues kv, const ArrayList list, int maxKeyLength) {
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

stock int AddSubsectionAuthsToList(const KeyValues kv, const char[] section, const ArrayList list) {
  int count = 0;
  if (kv.JumpToKey(section)) {
    count = AddAuthsToList(kv, list);
    kv.GoBack();
  }
  return count;
}

stock int AddAuthsToList(const KeyValues kv, const ArrayList list) {
  int count = 0;
  char buffer[AUTH_LENGTH];
  char steam64[AUTH_LENGTH];
  char name[MAX_NAME_LENGTH];
  if (kv.GotoFirstSubKey(false)) {
    do {
      kv.GetSectionName(buffer, AUTH_LENGTH);
      ReadEmptyStringInsteadOfPlaceholder(kv, name, sizeof(name));
      if (ConvertAuthToSteam64(buffer, steam64)) {
        list.PushString(steam64);
        Get5_SetPlayerName(steam64, name, true);
        count++;
      }
    } while (kv.GotoNextKey(false));
    kv.GoBack();
  }
  return count;
}

// If the string is found, it is inserted into the buffer.
stock bool RemoveStringFromArray(const ArrayList list, const char[] str, char[] buffer, const int bufferSize, bool caseSensitive = true) {
  for(int i = 0; i < list.Length; i++) {
    list.GetString(i, buffer, bufferSize);
    if (StrEqual(str, buffer, caseSensitive)) {
      list.Erase(i);
      return true;
    }
  }
  return false;
}

// Because KeyValue cannot write empty strings, we use this to consistently read empty strings and
// replace our empty-string-placeholder with actual empty string.
stock bool ReadEmptyStringInsteadOfPlaceholder(const KeyValues kv, char[] buffer, const int bufferSize) {
  kv.GetString(NULL_STRING, buffer, bufferSize);
  if (StrEqual(KEYVALUE_STRING_PLACEHOLDER, buffer)) {
    FormatEx(buffer, bufferSize, "");
    return true;
  }
  return false;
}

stock bool WritePlaceholderInsteadOfEmptyString(const KeyValues kv, char[] buffer, const int bufferSize) {
  kv.GetString(NULL_STRING, buffer, bufferSize);
  if (strlen(buffer) == 0) {
    kv.SetString(NULL_STRING, KEYVALUE_STRING_PLACEHOLDER);
    return true;
  }
  return false;
}

stock Get5Team OtherMatchTeam(Get5Team team) {
  if (team == Get5Team_1) {
    return Get5Team_2;
  } else if (team == Get5Team_2) {
    return Get5Team_1;
  } else {
    return team;
  }
}

stock bool IsPlayerTeam(Get5Team team) {
  return team == Get5Team_1 || team == Get5Team_2;
}

stock Get5Team VetoFirstFromString(const char[] str) {
  if (StrEqual(str, "random", false)) {
    return view_as<Get5Team>(GetRandomInt(0, 1));
  } else if (StrEqual(str, "team2", false)) {
    return Get5Team_2;
  } else {
    return Get5Team_1;
  }
}

stock bool GetAuth(int client, char[] auth, int size) {
  if (client == 0)
    return false;

  bool ret = GetClientAuthId(client, AuthId_SteamID64, auth, size);
  if (!ret) {
    LogError("Failed to get steamid for client %L", client);
  }
  return ret;
}

// TODO: might want a auth->client adt-trie to speed this up, maintained during
// client auth and disconnect forwards.
stock int AuthToClient(const char[] auth) {
  LOOP_CLIENTS(i) {
    if (IsAuthedPlayer(i)) {
      char clientAuth[AUTH_LENGTH];
      if (GetAuth(i, clientAuth, sizeof(clientAuth)) && StrEqual(auth, clientAuth)) {
        return i;
      }
    }
  }
  return -1;
}

stock int MapsToWin(int numberOfMaps) {
  // This works because integers are rounded down; so 3 / 2 = 1.5, which becomes 1 as integer.
  return (numberOfMaps / 2) + 1;
}

stock void CSTeamString(int csTeam, char[] buffer, int len) {
  if (csTeam == CS_TEAM_CT) {
    FormatEx(buffer, len, "CT");
  } else if (csTeam == CS_TEAM_T) {
    FormatEx(buffer, len, "T");
  } else {
    FormatEx(buffer, len, "none");
  }
}

stock void GetTeamString(Get5Team team, char[] buffer, int len) {
  if (team == Get5Team_1) {
    FormatEx(buffer, len, "team1");
  } else if (team == Get5Team_2) {
    FormatEx(buffer, len, "team2");
  } else if (team == Get5Team_Spec) {
    FormatEx(buffer, len, "spec");
  } else {
    FormatEx(buffer, len, "none");
  }
}

stock MatchSideType MatchSideTypeFromString(const char[] str) {
  if (StrEqual(str, "normal", false) || StrEqual(str, "standard", false)) {
    return MatchSideType_Standard;
  } else if (StrEqual(str, "never_knife", false)) {
    return MatchSideType_NeverKnife;
  } else {
    return MatchSideType_AlwaysKnife;
  }
}

stock void MatchSideTypeToString(MatchSideType type, char[] str, int len) {
  if (type == MatchSideType_Standard) {
    FormatEx(str, len, "standard");
  } else if (type == MatchSideType_NeverKnife) {
    FormatEx(str, len, "never_knife");
  } else {
    FormatEx(str, len, "always_knife");
  }
}

// Taken from Zephyrus (https://forums.alliedmods.net/showpost.php?p=2231850&postcount=2)
stock bool ConvertSteam2ToSteam64(const char[] steam2Auth, char[] steam64Auth, int size) {
  if (strlen(steam2Auth) < 11 || steam2Auth[0] != 'S' || steam2Auth[6] == 'I') {
    steam64Auth[0] = 0;
    return false;
  }
  int iUpper = 765611979;
  int isteam64Auth = StringToInt(steam2Auth[10]) * 2 + 60265728 + steam2Auth[8] - 48;
  int iDiv = isteam64Auth / 100000000;
  int iIdx = 9 - (iDiv ? iDiv / 10 + 1 : 0);
  iUpper += iDiv;
  IntToString(isteam64Auth, steam64Auth[iIdx], size - iIdx);
  iIdx = steam64Auth[9];
  IntToString(iUpper, steam64Auth, size);
  steam64Auth[9] = iIdx;
  return true;
}

stock bool ConvertSteam3ToSteam2(const char[] steam3Auth, char[] steam2Auth, int size) {
  if (StrContains(steam3Auth, "[U:1:") != 0 || strlen(steam3Auth) >= AUTH_LENGTH) {
    return false;
  }

  // Steam2 -> Steam3 is:
  // Old: STEAM_0:A:B
  // New: [U:1:B*2+A]
  // Example: STEAM_0:1:1234 ---> [U:1:2469]
  //
  // So the inverse Steam3 -> Steam2 is:
  // [U:1:x], x = B * 2 + A
  // where A = 1 if x odd, A = 0 if x even
  // -> B = (x - A) / 2

  // Get the x value as a string, then convert it to an int.
  char xBuf[AUTH_LENGTH];
  const int startIndex = 5;
  int i = startIndex;
  for (; i < strlen(steam3Auth) - 1; i++) {
    xBuf[i - startIndex] = steam3Auth[i];
  }
  xBuf[i - startIndex] = '\0';

  int x = StringToInt(xBuf);
  if (x == 0) {
    return false;
  }

  int a = (x % 2);
  int b = (x - a) / 2;

  FormatEx(steam2Auth, size, "STEAM_0:%d:%d", a, b);
  return true;
}

stock bool ConvertAuthToSteam64(const char[] inputId, char outputId[AUTH_LENGTH], bool reportErrors = true) {
  if (StrContains(inputId, "STEAM_") == 0 && strlen(inputId) >= 11) {  // steam2
    return ConvertSteam2ToSteam64(inputId, outputId, sizeof(outputId));

  } else if (StrContains(inputId, "7656119") == 0) {  // steam64
    strcopy(outputId, sizeof(outputId), inputId);
    return true;

  } else if (StrContains(inputId, "[U:1:") == 0) {  // steam3
    // Convert to steam2 then to steam64.
    char steam2[AUTH_LENGTH];
    if (ConvertSteam3ToSteam2(inputId, steam2, sizeof(steam2))) {
      return ConvertSteam2ToSteam64(steam2, outputId, sizeof(outputId));
    }
  }

  if (reportErrors) {
    LogError("Failed to read input auth id \"%s\", inputId", inputId);
  }

  return false;
}

stock bool HelpfulAttack(int attacker, int victim) {
  // Assumes both attacker and victim are valid clients; check this before calling this function.
  return attacker != victim && GetClientTeam(attacker) != GetClientTeam(victim);
}

stock SideChoice SideTypeFromString(const char[] input, char[] error) {
  if (StrEqual(input, "team1_ct", false) || StrEqual(input, "team2_t", false)) {
    return SideChoice_Team1CT;
  } else if (StrEqual(input, "team1_t", false) || StrEqual(input, "team2_ct", false)) {
    return SideChoice_Team1T;
  } else if (StrEqual(input, "knife", false)) {
    return SideChoice_KnifeRound;
  } else {
    FormatEx(error, PLATFORM_MAX_PATH,
             "Invalid side choice '%s'. Must be one of 'team1_ct', 'team1_t', 'team2_ct', 'team2_t', 'knife'.", input);
    return SideChoice_Invalid;
  }
}

// Deletes a file if it exists. Returns false if the
// file exists AND there was an error deleting it.
stock bool DeleteFileIfExists(const char[] path) {
  if (FileExists(path) && !DeleteFile(path)) {
    LogError("Failed to delete file %s", path);
    return false;
  }
  return true;
}

stock bool IsJSONPath(const char[] path) {
  int length = strlen(path);
  if (length >= 5) {
    return strcmp(path[length - 5], ".json", false) == 0;
  } else {
    return false;
  }
}

stock bool CreateDirectoryWithPermissions(const char[] directory) {
  LogDebug("Creating directory: %s", directory);
  return CreateDirectory(directory,  // sets 777 permissions.
                         FPERM_U_READ | FPERM_U_WRITE | FPERM_U_EXEC | FPERM_G_READ | FPERM_G_WRITE | FPERM_G_EXEC |
                           FPERM_O_READ | FPERM_O_WRITE | FPERM_O_EXEC);
}

stock bool CreateFolderStructure(const char[] path) {
  if (strlen(path) == 0 || DirExists(path)) {
    return true;
  }

  LogDebug("Creating directory %s because it does not exist.", path);
  char folders[16][PLATFORM_MAX_PATH];  // {folder1, folder2, etc}
  // initially empty, but we append every time a folder is created/verified
  char fullFolderPath[PLATFORM_MAX_PATH] = "";
  // shorthand for folders[i]
  char currentFolder[PLATFORM_MAX_PATH];

  ExplodeString(path, "/", folders, sizeof(folders), PLATFORM_MAX_PATH, true);
  for (int i = 0; i < sizeof(folders); i++) {
    currentFolder = folders[i];
    if (strlen(currentFolder) == 0) {  // as the loop is a fixed size, we stop when there are no more pieces.
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

stock void CheckAndCreateFolderPath(const ConVar cvar, const char[][] varsToReplace, const int varListSize,
                                    char outputFolder[PLATFORM_MAX_PATH], const int outputFolderSize) {
  char path[PLATFORM_MAX_PATH];
  char cvarName[MAX_CVAR_LENGTH];

  cvar.GetName(cvarName, sizeof(cvarName));
  cvar.GetString(path, sizeof(path));

  for (int i = 0; i < varListSize; i++) {
    if (StrEqual("{MATCHID}", varsToReplace[i])) {
      ReplaceString(path, sizeof(path), varsToReplace[i], g_MatchID);
    } else if (StrEqual("{DATE}", varsToReplace[i])) {
      char dateFormat[64];
      char formattedDate[64];
      int timeStamp = GetTime();
      g_DateFormatCvar.GetString(dateFormat, sizeof(dateFormat));

      FormatTime(formattedDate, sizeof(formattedDate), dateFormat, timeStamp);
      ReplaceString(path, sizeof(path), varsToReplace[i], formattedDate);
    }
  }

  int folderLength = strlen(path);

  if (folderLength > 0 &&
      (path[0] == '/' || path[0] == '.' || path[folderLength - 1] != '/' || StrContains(path, "//") != -1)) {
    LogError(
      "%s must end with a slash and must not start with a slash or dot. It will be reset to an empty string! Current value: %s",
      cvarName, path);
    path = "";
    cvar.SetString(path, false, false);
  } else {
    CreateFolderStructure(path);
  }
  Format(outputFolder, outputFolderSize, "%s", path);
}

stock int GetMilliSecondsPassedSince(float timestamp) {
  return RoundToFloor((GetEngineTime() - timestamp) * 1000);
}

stock int GetRoundsPlayed() {
  return GameRules_GetProp("m_totalRoundsPlayed");
}

// Not entirely sure how this works, but it does work.
// Also tested on Nuke with bombsites right on top of each other.
stock Get5BombSite GetNearestBombsite(int client) {
  int playerResource = GetPlayerResourceEntity();
  if (playerResource == INVALID_ENT_REFERENCE) {
    return Get5BombSite_Unknown;
  }

  float pos[3];
  GetClientAbsOrigin(client, pos);

  float aCenter[3], bCenter[3];
  GetEntPropVector(playerResource, Prop_Send, "m_bombsiteCenterA", aCenter);
  GetEntPropVector(playerResource, Prop_Send, "m_bombsiteCenterB", bCenter);

  float aDist = GetVectorDistance(aCenter, pos, true);
  float bDist = GetVectorDistance(bCenter, pos, true);

  LogDebug("Bomb planted. Distance to A: %f. Distance to B: %f.", aDist, bDist);

  return (aDist < bDist) ? Get5BombSite_A : Get5BombSite_B;
}

stock void ConvertSecondsToMinutesAndSeconds(int timeAsSeconds, char[] buffer, const int bufferSize) {
  int minutes = 0;
  int seconds = timeAsSeconds;
  if (timeAsSeconds >= 60) {
    minutes = timeAsSeconds / 60;
    seconds = timeAsSeconds % 60;
  }
  FormatEx(buffer, bufferSize, seconds < 10 ? "%d:0%d" : "%d:%d", minutes, seconds);
}

stock bool IsDoingRestoreOrMapChange() {
  return g_DoingBackupRestoreNow || g_MapChangePending;
}

stock void ChatCommandToString(const Get5ChatCommand command, char[] buffer, const int bufferSize) {
  switch (command) {
    case Get5ChatCommand_Ready: {
      FormatEx(buffer, bufferSize, "ready");
    }
    case Get5ChatCommand_Unready: {
      FormatEx(buffer, bufferSize, "unready");
    }
    case Get5ChatCommand_ForceReady: {
      FormatEx(buffer, bufferSize, "forceready");
    }
    case Get5ChatCommand_Tech: {
      FormatEx(buffer, bufferSize, "tech");
    }
    case Get5ChatCommand_Pause: {
      FormatEx(buffer, bufferSize, "pause");
    }
    case Get5ChatCommand_Unpause: {
      FormatEx(buffer, bufferSize, "unpause");
    }
    case Get5ChatCommand_Coach: {
      FormatEx(buffer, bufferSize, "coach");
    }
    case Get5ChatCommand_Stay: {
      FormatEx(buffer, bufferSize, "stay");
    }
    case Get5ChatCommand_Swap: {
      FormatEx(buffer, bufferSize, "swap");
    }
    case Get5ChatCommand_T: {
      FormatEx(buffer, bufferSize, "t");
    }
    case Get5ChatCommand_CT: {
      FormatEx(buffer, bufferSize, "ct");
    }
    case Get5ChatCommand_Stop: {
      FormatEx(buffer, bufferSize, "stop");
    }
    case Get5ChatCommand_Surrender: {
      FormatEx(buffer, bufferSize, "surrender");
    }
    case Get5ChatCommand_FFW: {
      FormatEx(buffer, bufferSize, "ffw");
    }
    case Get5ChatCommand_CancelFFW: {
      FormatEx(buffer, bufferSize, "cancelffw");
    }
    case Get5ChatCommand_Pick: {
      FormatEx(buffer, bufferSize, "pick");
    }
    case Get5ChatCommand_Ban: {
      FormatEx(buffer, bufferSize, "ban");
    }
    default: {
      LogError("Failed to map Get5ChatCommand with value %d to a string. It is missing from ChatCommandToString.",
               command);
    }
  }
}

stock Get5ChatCommand StringToChatCommand(const char[] string) {
  if (strcmp(string, "ready") == 0) {
    return Get5ChatCommand_Ready;
  } else if (strcmp(string, "unready") == 0) {
    return Get5ChatCommand_Unready;
  } else if (strcmp(string, "forceready") == 0) {
    return Get5ChatCommand_ForceReady;
  } else if (strcmp(string, "tech") == 0) {
    return Get5ChatCommand_Tech;
  } else if (strcmp(string, "pause") == 0) {
    return Get5ChatCommand_Pause;
  } else if (strcmp(string, "unpause") == 0) {
    return Get5ChatCommand_Unpause;
  } else if (strcmp(string, "coach") == 0) {
    return Get5ChatCommand_Coach;
  } else if (strcmp(string, "stay") == 0) {
    return Get5ChatCommand_Stay;
  } else if (strcmp(string, "swap") == 0) {
    return Get5ChatCommand_Swap;
  } else if (strcmp(string, "t") == 0) {
    return Get5ChatCommand_T;
  } else if (strcmp(string, "ct") == 0) {
    return Get5ChatCommand_CT;
  } else if (strcmp(string, "stop") == 0) {
    return Get5ChatCommand_Stop;
  } else if (strcmp(string, "surrender") == 0) {
    return Get5ChatCommand_Surrender;
  } else if (strcmp(string, "ffw") == 0) {
    return Get5ChatCommand_FFW;
  } else if (strcmp(string, "cancelffw") == 0) {
    return Get5ChatCommand_CancelFFW;
  } else if (strcmp(string, "pick") == 0) {
    return Get5ChatCommand_Pick;
  } else if (strcmp(string, "ban") == 0) {
    return Get5ChatCommand_Ban;
  } else {
    return Get5ChatCommand_Unknown;
  }
}
