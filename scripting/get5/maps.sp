stock void ChangeMap(const char[] map, float delay=3.0) {
    Get5_MessageToAll("Changing map to {GREEN}%s...", map);

    // pass the "true" name to a timer to changelevel
    Handle data = CreateDataPack();
    WritePackString(data, map);
    g_MapChangePending = true;

    CreateDataTimer(delay, Timer_DelayedChangeMap, data);
}

public Action Timer_DelayedChangeMap(Handle timer, Handle pack) {
    char map[PLATFORM_MAX_PATH];
    ResetPack(pack);
    ReadPackString(pack, map, sizeof(map));
    ServerCommand("changelevel %s", map);

    return Plugin_Handled;
}

public void FormatMapName(const char[] mapName, char[] buffer, int len) {
    // explode map by '/' so we can remove any directory prefixes (e.g. workshop stuff)
    char buffers[4][PLATFORM_MAX_PATH];
    int numSplits = ExplodeString(mapName, "/", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
    int mapStringIndex = (numSplits > 0) ? (numSplits - 1) : (0);
    strcopy(buffer, len, buffers[mapStringIndex]);

    // do it with backslashes too
    numSplits = ExplodeString(buffer, "\\", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
    mapStringIndex = (numSplits > 0) ? (numSplits - 1) : (0);
    strcopy(buffer, len, buffers[mapStringIndex]);
}
