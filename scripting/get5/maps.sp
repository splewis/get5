stock void ChangeMap(const char[] map, float delay=3.0) {
    Get5_MessageToAll("%t", "Changing map to {GREEN}%s...", map);

    // pass the "true" name to a timer to changelevel
    Handle data = CreateDataPack();
    WritePackString(data, map);
    g_MapChangePending = true;

    CreateTimer(delay, Timer_DelayedChangeMap, data);
}

public Action Timer_DelayedChangeMap(Handle timer, Handle pack) {
    char map[PLATFORM_MAX_PATH];
    ResetPack(pack);
    ReadPackString(pack, map, sizeof(map));
    CloseHandle(pack);
    ServerCommand("changelevel %s", map);

    return Plugin_Handled;
}

stock void FormatMapName(const char[] mapName, char[] buffer, int len, bool cleanName=false) {
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
        }
    }
}
