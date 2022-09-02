void ChangeMap(const char[] map, float delay = 3.0) {
  char formattedMapName[64];
  FormatMapName(map, formattedMapName, sizeof(formattedMapName), true, true);
  Get5_MessageToAll("%t", "ChangingMapInfoMessage", formattedMapName);

  // pass the "true" name to a timer to changelevel
  Handle data = CreateDataPack();
  WritePackString(data, map);
  g_MapChangePending = true;

  CreateTimer(delay, Timer_DelayedChangeMap, data);
}

static Action Timer_DelayedChangeMap(Handle timer, Handle pack) {
  char map[PLATFORM_MAX_PATH];
  ResetPack(pack);
  ReadPackString(pack, map, sizeof(map));
  CloseHandle(pack);
  ServerCommand("changelevel %s", map);

  return Plugin_Handled;
}
