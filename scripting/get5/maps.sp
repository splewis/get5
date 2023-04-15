void ChangeMap(const char[] map, float delay = 3.0) {
  char formattedMapName[64];
  FormatMapName(map, formattedMapName, sizeof(formattedMapName), g_FormatMapNamesCvar.BoolValue, true);
  Get5_MessageToAll("%t", "ChangingMapInfoMessage", formattedMapName);

  // pass the "true" name to a timer to changelevel
  Handle data = CreateDataPack();
  WritePackString(data, map);
  g_MapChangePending = true;

  CreateTimer(delay, Timer_DelayedChangeMap, data);
}

static Action Timer_DelayedChangeMap(Handle timer, Handle pack) {
  if (!g_MapChangePending) {
    delete pack;
    return Plugin_Handled;
  }
  char map[PLATFORM_MAX_PATH];
  ResetPack(pack);
  ReadPackString(pack, map, sizeof(map));
  CloseHandle(pack);
  char workshopMap[PLATFORM_MAX_PATH];
  if (IsMapWorkshop(map) && GetMapIdFromString(map, workshopMap, sizeof(workshopMap))) {
    ServerCommand("host_workshop_map %s", workshopMap);
  } else {
    ServerCommand("changelevel %s", map);
  }
  return Plugin_Handled;
}

bool GetMapIdFromString(const char[] map, char[] buffer, const int bufferSize) {
  char buffers[4][PLATFORM_MAX_PATH];
  ExplodeString(map, "/", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
  int value[2];
  StringToInt64(buffers[1], value);
  if (value[0] > 0) {
    strcopy(buffer, bufferSize, buffers[1]);
    return true;
  }
  return false;
}
