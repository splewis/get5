stock void ChangeMap(const char[] map, float delay = 3.0) {
  Get5_MessageToAll("%t", "ChangingMapInfoMessage", map);

  char map[PLATFORM_MAX_PATH];

  // pass the "true" name to a timer to changelevel
  DataPack pack = CreateDataPack();
  pack.WriteString(map);
  g_MapChangePending = true;


  CreateTimer(delay, Timer_DelayedChangeMap, pack);
}

public Action Timer_DelayedChangeMap(Handle timer, Handle data) {
  char map[PLATFORM_MAX_PATH];
  DataPack pack = view_as<DataPack>(data);
  pack.Reset();
  pack.ReadString(map, sizeof(map));
  delete pack;


  if (IsMapValid(map)) {
    ServerCommand("changelevel %s", map);
  } else if (StrContains(map, "workshop") == 0) {
    ServerCommand("host_workshop_map %d", GetMapIdFromString(map));
  }

  return Plugin_Handled;
}


public int GetMapIdFromString(const char[] map) {
  char buffers[4][PLATFORM_MAX_PATH];
  ExplodeString(map, "/", buffers, sizeof(buffers), PLATFORM_MAX_PATH);
  return StringToInt(buffers[1]);
}