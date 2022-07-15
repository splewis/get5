# API for developers

Get5 can be interacted with in several ways. At a glance:

1) You can write another SourceMod plugin that uses
   the [Get5 natives and forwards](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc). This is
   exactly what the [get5_apistats](https://github.com/splewis/get5/blob/master/scripting/get5_apistats.sp)
   and [get5_mysqlstats](https://github.com/splewis/get5/blob/master/get5_mysqlstats.sp) plugins do. Please use these as
   a general guide/starting point, don't fork this repository to make changes to these plugins alone, but use these as a
   template and create a new repository for your plugin!

2) You can read [event logs](./event_logs.md) from a file on disk (set
   by [`get5_event_log_format`](./get5_configuration.md#file-name-formatting)), through a RCON connection to the server
   console since they are output there, or through another SourceMod plugin (see #1).

3) You can read the [stats](./stats_system.md) get5 collects from a file on disk (set
   by [`get5_stats_path_format`](./get5_configuration.md#file-name-formatting)), or through another SourceMod plugin (
   see #1).

4) You can execute the `get5_loadmatch` command or `get5_loadmatch_url` commands via another plugin or via a RCON
   connection to begin matches. Of course, you could execute any get5 command you want as well.

## Status Schema

The following is the `get_status` response's schema.

### Static

- `plugin_version`: Get5's version number.
- `commit`: Only here if `COMMIT_STRING` is defined (probably not your case).
- `gamestate`: A number representing the game's state.
    - **0**: No setup has taken place.
    - **1**: Warmup, waiting for the veto.
    - **2**: Warmup, doing the veto.
    - **3**: Setup done, waiting for players to ready up.
    - **4**: In the knife round.
    - **5**: Waiting for a !stay or !swap command after the knife.
    - **6**: In the lo3 process.
    - **7**: The match is live.
    - **8**: Postgame screen + waiting for GOTV to finish broadcast.
- `paused`: Is the match paused?
- `gamestate_string`:  human-readable gamestate which is a translation of `gamestate`.
    - `"none"`
    - `"waiting for map veto"`
    - `"map veto"`
    - `"warmup"`
    - `"knife round"`
    - `"waiting for knife round decision"`
    - `"going live"`
    - `"live"`
    - `"postgame"`

#### Additional Parts

*If the current game state is not "none"*:

- `matchid`: The current match's id. You can set it in match configs, with the property which has the same name.
- `loaded_config_file`: The name of the loaded config file. If you used `get5_loadmatch <file>`, it's this file's name.
  If you used `get5_loadmatch_url`, the pattern of the file is `remote_config%d.json`, where `%d` is the server's id,
  which you can set with `get5_server_id`.
- `map_number`: The current map number in the series.
- `team1` and `team2`: Two JSON objects which share the same properties.
    - `name`: Name of the team.
    - `series_score`: The score in the series.
    - `ready`: Boolean indicating if the team is ready.
    - `side`: The side on which the team is. Can be `"CT"`, `"T"`, or `"none"`.
    - `connected_clients`: The number of human clients connected on the team.
    - `current_map_score`: The team's score on the current map.

*If the current game state is past the veto stage*

- `maps`: A JSON Object which contains one property per map.
    - Key: `"map%d"` where `%d` is the map index in the array.
    - Value: The name of the map (taken from the [match config](./match_configuration.md)).
