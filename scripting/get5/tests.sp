public Action Command_Test(int args) {
    Get5_Test();
    return Plugin_Handled;
}

public void Get5_Test() {
    if (g_GameState != GameState_None) {
        g_GameState = GameState_None;
    }
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/get5/example_match.cfg");
    LoadMatchConfig(path);

    Utils_Test();
    KV_Test();

    g_GameState = GameState_None;
}

static void Utils_Test() {
    SetTestContext("Utils_Test");

    // MaxMapsToPlay
    AssertEq("MaxMapsToPlay1", MaxMapsToPlay(1), 1);
    AssertEq("MaxMapsToPlay2", MaxMapsToPlay(2), 3);
    AssertEq("MaxMapsToPlay3", MaxMapsToPlay(3), 5);
    AssertEq("MaxMapsToPlay4", MaxMapsToPlay(4), 7);

    // SteamIdsEqual
    AssertTrue("SteamIdsEqual1", SteamIdsEqual("STEAM_1:1:12345", "STEAM_1:1:12345"));
    AssertTrue("SteamIdsEqual2", SteamIdsEqual("STEAM_1:1:12345", "STEAM_0:1:12345"));
    AssertTrue("SteamIdsEqual3", SteamIdsEqual("STEAM_1:1:12345", "STEAM_0:0:12345"));
    AssertFalse("SteamIdsEqual4", SteamIdsEqual("STEAM_1:1:12345", "STEAM_1:1:11345"));
    AssertFalse("SteamIdsEqual5", SteamIdsEqual("STEAM_1:1:12345", "STEAM_1:1:12346"));
    AssertFalse("SteamIdsEqual6", SteamIdsEqual("STEAM_1:1:12345", "STEAM_1:1:125346"));

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
    AssertEq("skip_veto", g_SkipVeto, false);
    AssertEq("players_per_team", g_PlayersPerTeam, 1);
    AssertEq("favored_percentage_team1", g_FavoredTeamPercentage, 65);

    AssertTrue("team1.name", StrEqual(g_TeamNames[MatchTeam_Team1], "EnvyUs", false));
    AssertTrue("team1.flag", StrEqual(g_TeamFlags[MatchTeam_Team1], "FR", false));
    AssertTrue("team1.logo", StrEqual(g_TeamLogos[MatchTeam_Team1], "nv", false));

    AssertTrue("team2.name", StrEqual(g_TeamNames[MatchTeam_Team2], "fnatic", false));
    AssertTrue("team2.flag", StrEqual(g_TeamFlags[MatchTeam_Team2], "SE", false));
    AssertTrue("team2.logo", StrEqual(g_TeamLogos[MatchTeam_Team2], "fntc", false));
}
