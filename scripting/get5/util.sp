#include <sdktools>

#define MAX_INTEGER_STRING_LENGTH 16
#define MAX_FLOAT_STRING_LENGTH 32
#define AUTH_LENGTH 64

// Dummy value for when we need to write a keyvalue string, but we don't care about he value.
// Trying to write an empty string often results in the keyvalue not being written, so we use this.
#define KEYVALUE_STRING_PLACEHOLDER "__placeholder"

static char _colorNames[][] = {"{NORMAL}", "{DARK_RED}",    "{PINK}",      "{GREEN}",
                               "{YELLOW}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}",
                               "{ORANGE}", "{LIGHT_BLUE}",  "{DARK_BLUE}", "{PURPLE}"};
static char _colorCodes[][] = {"\x01", "\x02", "\x03", "\x04", "\x05", "\x06",
                               "\x07", "\x08", "\x09", "\x0B", "\x0C", "\x0E"};

// Convenience macros.
#define LOOP_TEAMS(%1) for (MatchTeam %1 = MatchTeam_Team1; %1 < MatchTeam_Count; %1 ++)
#define LOOP_CLIENTS(%1) for (int %1 = 0; %1 <= MaxClients; %1 ++)

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
    if (IsPlayer(i) && GetClientTeam(i) == team) {
      count++;
    }
  }
  return count;
}

stock int CountAlivePlayersOnTeam(int csTeam) {
  int count = 0;
  for (int i = 1; i <= MaxClients; i++) {
    if (IsPlayer(i) && IsPlayerAlive(i) && GetClientTeam(i) == csTeam) {
      count++;
    }
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
  if (GetClientTeam(client) == team) {
    return;
  }

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

stock void Colorize(char[] msg, int size, bool stripColor = false) {
  for (int i = 0; i < sizeof(_colorNames); i++) {
    if (stripColor) {
      ReplaceString(msg, size, _colorNames[i], "\x01");  // replace with white
    } else {
      ReplaceString(msg, size, _colorNames[i], _colorCodes[i]);
    }
  }
}

stock void ReplaceStringWithInt(char[] buffer, int len, const char[] replace, int value,
                                bool caseSensitive = false) {
  char intString[MAX_INTEGER_STRING_LENGTH];
  IntToString(value, intString, sizeof(intString));
  ReplaceString(buffer, len, replace, intString, caseSensitive);
}

stock bool IsTVEnabled() {
  ConVar tvEnabledCvar = FindConVar("tv_enable");
  if (tvEnabledCvar == null) {
    LogError("Failed to get tv_enable cvar");
    return false;
  }
  return tvEnabledCvar.BoolValue;
}

stock int GetTvDelay() {
  if (IsTVEnabled()) {
    return GetCvarIntSafe("tv_delay");
  }
  return 0;
}

stock bool Record(const char[] demoName) {
  char szDemoName[256];
  strcopy(szDemoName, sizeof(szDemoName), demoName);
  ReplaceString(szDemoName, sizeof(szDemoName), "\"", "\\\"");
  ServerCommand("tv_record \"%s\"", szDemoName);

  if (!IsTVEnabled()) {
    LogError(
        "Autorecording will not work with current cvar \"tv_enable\"=0. Set \"tv_enable 1\" in server.cfg (or another config file) to fix this.");
    return false;
  }

  return true;
}

stock void StopRecording() {
  ServerCommand("tv_stoprecord");
  LogDebug("Calling Get5_OnDemoFinished(file=%s)", g_DemoFileName);
  Call_StartForward(g_OnDemoFinished);
  Call_PushString(g_DemoFileName);
  Call_Finish();
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

  ServerCommand("mp_warmup_pausetimer 1");
  ServerCommand("mp_do_warmup_period 1");
  ServerCommand("mp_warmup_pausetimer 1");
}

stock void StartWarmup(bool indefiniteWarmup = true, int warmupTime = 60) {
  ServerCommand("mp_do_warmup_period 1");
  ServerCommand("mp_warmuptime %d", warmupTime);
  ServerCommand("mp_warmup_start");

  // For some reason it needs to get sent twice. Ask Valve.
  if (indefiniteWarmup) {
    ServerCommand("mp_warmup_pausetimer 1");
    ServerCommand("mp_warmup_pausetimer 1");
  }
}

stock void EndWarmup(int time = 0) {
  if (time == 0) {
    ServerCommand("mp_warmup_end");
  } else {
    ServerCommand("mp_warmup_pausetimer 0");
    ServerCommand("mp_warmuptime %d", time);
  }
}

stock bool IsPaused() {
  return GameRules_GetProp("m_bMatchWaitingForResume") != 0;
}

// Pauses and returns if the match will automatically unpause after the duration ends.
stock bool Pause(int pauseTime = 0, int csTeam = CS_TEAM_NONE) {
  if (pauseTime == 0 || csTeam == CS_TEAM_SPECTATOR || csTeam == CS_TEAM_NONE) {
    ServerCommand("mp_pause_match");
    return false;
  } else {
    ServerCommand("mp_pause_match");
    if (csTeam == CS_TEAM_T) {
      GameRules_SetProp("m_bTerroristTimeOutActive", true);
      GameRules_SetPropFloat("m_flTerroristTimeOutRemaining", float(pauseTime));
    } else if (csTeam == CS_TEAM_CT) {
      GameRules_SetProp("m_bCTTimeOutActive", true);
      GameRules_SetPropFloat("m_flCTTimeOutRemaining", float(pauseTime));
    }
    return true;
  }
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

stock void UpdateCoachTarget(int client, int csTeam) {
  SetEntProp(client, Prop_Send, "m_iCoachingTeam", csTeam);
}

stock void SetTeamInfo(int csTeam, const char[] name, const char[] flag = "",
                       const char[] logo = "", const char[] matchstat = "", int series_score = 0) {
  int team_int = (csTeam == CS_TEAM_CT) ? 1 : 2;

  char teamCvarName[MAX_CVAR_LENGTH];
  char flagCvarName[MAX_CVAR_LENGTH];
  char logoCvarName[MAX_CVAR_LENGTH];
  char textCvarName[MAX_CVAR_LENGTH];
  char scoreCvarName[MAX_CVAR_LENGTH];
  Format(teamCvarName, sizeof(teamCvarName), "mp_teamname_%d", team_int);
  Format(flagCvarName, sizeof(flagCvarName), "mp_teamflag_%d", team_int);
  Format(logoCvarName, sizeof(logoCvarName), "mp_teamlogo_%d", team_int);
  Format(textCvarName, sizeof(textCvarName), "mp_teammatchstat_%d", team_int);
  Format(scoreCvarName, sizeof(scoreCvarName), "mp_teamscore_%d", team_int);

  // Add Ready/Not ready tags to team name if in warmup.
  char taggedName[MAX_CVAR_LENGTH];
  if (g_ReadyTeamTagCvar.BoolValue) {
    if ((g_GameState == Get5State_Warmup || g_GameState == Get5State_PreVeto) &&
        !g_DoingBackupRestoreNow) {
      MatchTeam matchTeam = CSTeamToMatchTeam(csTeam);
      if (IsTeamReady(matchTeam)) {
        Format(taggedName, sizeof(taggedName), "%T %s", "ReadyTag", LANG_SERVER, name);
      } else {
        Format(taggedName, sizeof(taggedName), "%T %s", "NotReadyTag", LANG_SERVER, name);
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

  if (g_MapsToWin > 1) {
    SetConVarIntSafe(scoreCvarName, series_score);
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

stock void FormatMapName(const char[] mapName, char[] buffer, int len, bool cleanName = false) {
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
    } else if (StrEqual(buffer, "de_overpass")) {
      strcopy(buffer, len, "Overpass");
    } else if (StrEqual(buffer, "de_nuke")) {
      strcopy(buffer, len, "Nuke");
    } else if (StrEqual(buffer, "de_vertigo")) {
      strcopy(buffer, len, "Vertigo");
    } else if (StrEqual(buffer, "de_ancient")) {
      strcopy(buffer, len, "Ancient");
    }
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

stock int AddSubsectionKeysToList(KeyValues kv, const char[] section, ArrayList list,
                                  int maxKeyLength) {
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

stock int AddSubsectionAuthsToList(KeyValues kv, const char[] section, ArrayList list,
                                   int maxKeyLength) {
  int count = 0;
  if (kv.JumpToKey(section)) {
    count = AddAuthsToList(kv, list, maxKeyLength);
    kv.GoBack();
  }
  return count;
}

stock int AddAuthsToList(KeyValues kv, ArrayList list, int maxKeyLength) {
  int count = 0;
  char[] buffer = new char[maxKeyLength];
  char steam64[AUTH_LENGTH];
  char name[MAX_NAME_LENGTH];
  if (kv.GotoFirstSubKey(false)) {
    do {
      kv.GetSectionName(buffer, maxKeyLength);
      kv.GetString(NULL_STRING, name, sizeof(name));
      if (ConvertAuthToSteam64(buffer, steam64)) {
        list.PushString(steam64);
        Get5_SetPlayerName(steam64, name);
        count++;
      }
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

stock bool IsPlayerTeam(MatchTeam team) {
  return team == MatchTeam_Team1 || team == MatchTeam_Team2;
}

public MatchTeam VetoFirstFromString(const char[] str) {
  if (StrEqual(str, "team2", false)) {
    return MatchTeam_Team2;
  } else {
    return MatchTeam_Team1;
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
  for (int i = 1; i <= MaxClients; i++) {
    if (IsAuthedPlayer(i)) {
      char clientAuth[AUTH_LENGTH];
      if (GetAuth(i, clientAuth, sizeof(clientAuth)) && StrEqual(auth, clientAuth)) {
        return i;
      }
    }
  }
  return -1;
}

stock int MaxMapsToPlay(int mapsToWin) {
  if (g_BO2Match)
    return 2;
  else
    return 2 * mapsToWin - 1;
}

stock void CSTeamString(int csTeam, char[] buffer, int len) {
  if (csTeam == CS_TEAM_CT) {
    Format(buffer, len, "CT");
  } else if (csTeam == CS_TEAM_T) {
    Format(buffer, len, "T");
  } else {
    Format(buffer, len, "none");
  }
}

stock void GetTeamString(MatchTeam team, char[] buffer, int len) {
  if (team == MatchTeam_Team1) {
    Format(buffer, len, "team1");
  } else if (team == MatchTeam_Team2) {
    Format(buffer, len, "team2");
  } else if (team == MatchTeam_TeamSpec) {
    Format(buffer, len, "spec");
  } else {
    Format(buffer, len, "none");
  }
}

stock void GameStateString(Get5State state, char[] buffer, int length) {
  switch (state) {
    case Get5State_None:
      Format(buffer, length, "none");
    case Get5State_PreVeto:
      Format(buffer, length, "waiting for map veto");
    case Get5State_Veto:
      Format(buffer, length, "map veto");
    case Get5State_Warmup:
      Format(buffer, length, "warmup");
    case Get5State_KnifeRound:
      Format(buffer, length, "knife round");
    case Get5State_WaitingForKnifeRoundDecision:
      Format(buffer, length, "waiting for knife round decision");
    case Get5State_GoingLive:
      Format(buffer, length, "going live");
    case Get5State_Live:
      Format(buffer, length, "live");
    case Get5State_PostGame:
      Format(buffer, length, "postgame");
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

public void MatchSideTypeToString(MatchSideType type, char[] str, int len) {
  if (type == MatchSideType_Standard) {
    Format(str, len, "standard");
  } else if (type == MatchSideType_NeverKnife) {
    Format(str, len, "never_knife");
  } else {
    Format(str, len, "always_knife");
  }
}

stock void ExecCfg(ConVar cvar) {
  char cfg[PLATFORM_MAX_PATH];
  cvar.GetString(cfg, sizeof(cfg));
  ServerCommand("exec \"%s\"", cfg);
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

  Format(steam2Auth, size, "STEAM_0:%d:%d", a, b);
  return true;
}

stock bool ConvertAuthToSteam64(const char[] inputId, char outputId[AUTH_LENGTH],
                                bool reportErrors = true) {
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
  if (!IsValidClient(attacker) || !IsValidClient(victim)) {
    return false;
  }
  int attackerTeam = GetClientTeam(attacker);
  int victimTeam = GetClientTeam(victim);
  return attackerTeam != victimTeam && attacker != victim;
}

stock SideChoice SideTypeFromString(const char[] input) {
  if (StrEqual(input, "team1_ct", false)) {
    return SideChoice_Team1CT;
  } else if (StrEqual(input, "team1_t", false)) {
    return SideChoice_Team1T;
  } else if (StrEqual(input, "team2_ct", false)) {
    return SideChoice_Team1T;
  } else if (StrEqual(input, "team2_t", false)) {
    return SideChoice_Team1CT;
  } else if (StrEqual(input, "knife", false)) {
    return SideChoice_KnifeRound;
  } else {
    LogError("Invalid side choice \"%s\", falling back to knife round", input);
    return SideChoice_KnifeRound;
  }
}

typedef VoidFunction = function void();

stock void DelayFunction(float delay, VoidFunction f) {
  DataPack p = CreateDataPack();
  p.WriteFunction(f);
  CreateTimer(delay, _DelayFunctionCallback, p);
}

public Action _DelayFunctionCallback(Handle timer, DataPack data) {
  data.Reset();
  Function func = data.ReadFunction();
  Call_StartFunction(INVALID_HANDLE, func);
  Call_Finish();
  delete data;
}

// Deletes a file if it exists. Returns true if the
// file existed AND there was an error deleting it.
public bool DeleteFileIfExists(const char[] path) {
  if (FileExists(path)) {
    if (!DeleteFile(path)) {
      LogError("Failed to delete file %s", path);
      return false;
    }
  }

  return true;
}
