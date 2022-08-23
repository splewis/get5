public Action Command_Test(int args) {
  Get5_Test();
  return Plugin_Handled;
}

public void Get5_Test() {
  if (g_GameState != Get5State_None) {
    g_GameState = Get5State_None;
  }
  char path[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, path, sizeof(path), "configs/get5/example_match.cfg");
  LoadMatchConfig(path);

  Utils_Test();
  KV_Test();

  g_GameState = Get5State_None;
  LogMessage("Tests complete!");
}

static void Utils_Test() {
  SetTestContext("Utils_Test");

  // MaxMapsToPlay
  AssertEq("MaxMapsToPlay1", MaxMapsToPlay(1), 1);
  AssertEq("MaxMapsToPlay2", MaxMapsToPlay(2), 3);
  AssertEq("MaxMapsToPlay3", MaxMapsToPlay(3), 5);
  AssertEq("MaxMapsToPlay4", MaxMapsToPlay(4), 7);

  // ConvertAuthToSteam64
  char input[64] = "STEAM_0:1:52245092";
  char expected[64] = "76561198064755913";
  char output[64] = "";
  AssertTrue("ConvertAuthToSteam64_1_return", ConvertAuthToSteam64(input, output));
  AssertTrue("ConvertAuthToSteam64_1_value", StrEqual(output, expected));

  input = "76561198064755913";
  expected = "76561198064755913";
  AssertTrue("ConvertAuthToSteam64_2_return", ConvertAuthToSteam64(input, output));
  AssertTrue("ConvertAuthToSteam64_2_value", StrEqual(output, expected));

  input = "_0:1:52245092";
  expected = "76561198064755913";
  AssertFalse("ConvertAuthToSteam64_3_return", ConvertAuthToSteam64(input, output, false));
  AssertTrue("ConvertAuthToSteam64_3_value", StrEqual(output, expected));

  input = "[U:1:104490185]";
  expected = "76561198064755913";
  AssertTrue("ConvertAuthToSteam64_4_return", ConvertAuthToSteam64(input, output));
  AssertTrue("ConvertAuthToSteam64_4_value", StrEqual(output, expected));

  // AddSubsectionKeysToList
  KeyValues kv = new KeyValues("test");
  char kvstr[] = "\"test\"{ \"a\" { \"x\" \"y\" \"c\" \"d\" } }";
  kv.ImportFromString(kvstr);
  ArrayList list = new ArrayList(64);
  AssertEq("AddSubsectionKeysToList1", AddSubsectionKeysToList(kv, "a", list, 64), 2);
  delete kv;

  AssertEq("AddSubsectionKeysToList2", list.Length, 2);

  char key[64];
  list.GetString(0, key, sizeof(key));
  AssertTrue("AddSubsectionKeysToList3", StrEqual(key, "x", false));

  list.GetString(1, key, sizeof(key));
  AssertTrue("AddSubsectionKeysToList4", StrEqual(key, "c", false));
}

static void KV_Test() {
  SetTestContext("KV_Test");

  AssertEq("maps_to_win", g_MapsToWin, 2);
  AssertEq("bo2_series", g_BO2Match, false);
  AssertEq("skip_veto", g_SkipVeto, false);
  AssertEq("players_per_team", g_PlayersPerTeam, 5);
  AssertEq("favored_percentage_team1", g_FavoredTeamPercentage, 65);

  AssertTrue("team1.name", StrEqual(g_TeamNames[Get5Team_1], "EnvyUs", false));
  AssertTrue("team1.flag", StrEqual(g_TeamFlags[Get5Team_1], "FR", false));
  AssertTrue("team1.logo", StrEqual(g_TeamLogos[Get5Team_1], "nv", false));

  AssertTrue("team2.name", StrEqual(g_TeamNames[Get5Team_2], "fnatic", false));
  AssertTrue("team2.flag", StrEqual(g_TeamFlags[Get5Team_2], "SE", false));
  AssertTrue("team2.logo", StrEqual(g_TeamLogos[Get5Team_2], "fntc", false));
}
