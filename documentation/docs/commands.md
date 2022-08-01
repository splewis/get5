# :material-apple-keyboard-command: Commands

Generally admin commands will have a `get5_` prefix and must be used in console. Commands intended for general player
usage are created with `sm_` prefixes, which means SourceMod automatically registers a `!` and `.` chat version of the
command. (For example: `sm_ready` in console is equivalent to `!ready` or `.ready` in chat).

## Client Commands

Please note that these can be typed by *all players* in chat.

####`!ready`

:   Marks the player as ready.

####`!unready`

:   Marks the player as not ready.

####`!pause` or `!tac` {: #pause }

:   Requests a [tactical pause](../pausing/#tactical).

####`!unpause`

:   Requests to unpause the game.

####`!tech`

:   Requests a [technical pause](../pausing/#technical).

####`!coach`

:   Moves a client to coach for their team. Requires that
the [`sv_coaching_enabled`](https://totalcsgo.com/command/svcoachingenabled) variable is set to `1`.

####`!stay`

:   Elects to stay after a knife round win. This can be substituted by `!ct` or `!t` to select a side.

####`!swap` or `!switch` {: #swap }

:   Elects to swap team side after a knife round win. This can be substituted by `!ct` or `!t` to select a side.

####`!stop`

:   Asks to reload the last match backup file. The opposing team must confirm. Only works if
the [backup system is enabled](../configuration/#get5_backup_system_enabled) and
the [get5_stop_command_enabled](../configuration/#get5_stop_command_enabled) is set to `1`.

####`!forceready`

:   Force-readies your team, marking all players on your team as ready.

####`!ringer`

:   Adds/removes a ringer to/from the home scrim team.

####`!scrim`

:   Shortcut for [`get5_scrim`](#get5_scrim).

####`!get5`

:   Opens a menu that wraps some common commands. It's mostly intended for people using scrim settings, and has
menu buttons for starting a scrim, force-starting, force-ending, adding a ringer, and loading the most recent backup
file.

## Server/Admin Commands

Please note that these are meant to be used by *admins* in console.

####`get5_loadmatch <filename>` {: #get5_loadmatch }

:   Loads a [match configuration](../match_schema) file (JSON or KeyValue) relative from the `csgo` directory.

####`get5_loadbackup <filename>` {: #get5_loadbackup }
:   Loads a match backup file (JSON or KeyValue) relative from the `csgo`
directory. Only works if the [backup system is enabled](../configuration/#get5_backup_system_enabled).

####`get5_last_backup_file`
:   Prints the name of the last match backup file Get5 wrote in the current series, this is automatically updated each
time a backup file is written. Empty string if no backup was written.

####`get5_loadteam <team1|team2|spec> <filename>` {: #get5_loadteam }
:   Loads a [team section of a match configuration](../match_schema) from a file into a team relative from the `csgo`
directory. The file must contain a `Get5MatchTeam` object.

####`get5_loadmatch_url <url>` {: #get5_loadmatch_url }
:   Loads a remote (JSON-formatted) [match configuration](../match_schema) by sending an HTTP(S) `GET` to the given URL.
You should put the `url` argument inside quotation marks (`""`).

!!! warning "SteamWorks required"

    Loading remote matches requires the [SteamWorks](../installation/#steamworks) extension.

####`get5_endmatch`
:   Force ends the current match. No winner is set (draw).

####`get5_creatematch`
:   Creates a BO1 match with the current players on the server on the current map.

####`get5_scrim [opposing team name] [map name] [matchid]` {: #get5_scrim }
:   Creates a [scrim](../getting_started/#scrims) on the current map. For example, if you're
    playing *fnatic* on `de_dust2` you might run `get5_scrim fnatic de_dust2`. The other team name defaults to "away"
    and the map defaults to the current map. `matchid` defaults to an empty string.

####`get5_addplayer <auth> <team1|team2|spec> [name]` {: #get5_addplayer }
:   Adds a Steam ID to a team (can be any format for the Steam ID). The name parameter optionally locks the player's
name.

####`get5_addcoach <auth> <team1|team2> [name]` {: #get5_addcoach }
:   Adds a Steam ID to a team as a coach. The name parameter optionally locks the player's
name.

####`get5_removeplayer <auth>`
:   Removes a steam ID from all teams (can be any format for the Steam ID).

####`get5_addkickedplayer <team1|team2|spec> [name]` {: #get5_addkickedplayer }
:   Adds the last kicked Steam ID to a team. The name parameter optionally locks the player's name.

####`get5_removekickedplayer <team1|team2|spec>` {: #get5_removekickedplayer }
:   Removes the last kicked Steam ID from all teams. Cannot be used in scrim mode.

####`get5_forceready`
:   Marks all teams as ready. `get5_forcestart` does the same thing.

####`get5_dumpstats`
:   Dumps current match stats to a file. This does not work if you set
[`get5_stats_enabled`](../configuration/#get5_stats_enabled) to `0`.

####`get5_status`
:   Replies with JSON formatted match state (available to all clients).

??? abstract "Definition"

    :warning: Properties marked as `undefined` are only present if a match configuration has been loaded.

    ```typescript
    interface StatusTeam {
        "name": string, // (11)
        "series_score": number, // (12)
        "current_map_score": number, // (13)
        "connected_clients": number, // (14)
        "ready": boolean, // (15)
        "side": "t" | "ct" // (16)
    }
    
    interface Status {
        "plugin_version": string, // (1)
        "gamestate": "none" | "pre_veto" | "veto" | "warmup"
            | "knife" | "waiting_for_knife_decision"
            | "going_live" | "live" | "post_game", // (2)
        "paused": boolean, // (3)
        "loaded_config_file": string | undefined, // (4)
        "matchid": string | undefined, // (5)
        "map_number": number | undefined, // (6)
        "round_number": number | undefined, // (7)
        "round_time": number | undefined, // (8)
        "team1": StatusTeam | undefined, // (9),
        "team2": StatusTeam | undefined, // (10)
        "maps": [string] | undefined // (17)
    }
    ```

    1. The version of Get5 you are currently running, along with that version's commit. `Example: "0.8.1-8ef7ffa3"`
    2. The current state of the game. The definition lists them in the order they occur.
    3. Whether the game is currently paused.
    4. The match configuration file currently loaded. `Example: "addons/sourcemod/configs/get5/match_config.json"`.
    5. The current match ID. Empty string if not defined or `scrim` or `manual` if using
       [`get5_scrim`](../commands/#get5_scrim) or [`get5_creatematch`](../commands/#get5_creatematch).
    6. The current map number, starting at `0`. You can use this to determine the current map by looking at the `maps`
       array.
    7. The current round number, starting at `0`. `-1` if `gamestate` is not `live`.
    8. The number of milliseconds elapsed in the current round.
    9. Describes `team1`.
    10. Describes `team2`.
    11. The name of the team.
    12. The current series score; the number of maps won.
    13. The number of rounds won on the current map.
    14. The number of currently connected players.
    15. Whether the team is [`!ready`](../commands/#ready).
    16. The side the team is currently on.
    17. The maps to be played in the series, i.e. `["de_dust2", "de_mirage", "de_nuke"]`. Maps are played in the order they
        appear in this array. `map_number` is the array index of the current map. **Note:** `maps` is only present if the
        maps have been decided (i.e. after `veto`).

??? example

    ```js
    {
        "plugin_version": "0.9.4-8ef7ffa3",
        "gamestate": "live",
        "paused": false,
        "loaded_config_file": "addons/sourcemod/configs/get5/match_config.json",
        "matchid": "1743",
        "map_number": 1,
        "round_number": 14,
        "round_time": 14234,
        "team1": {
            "name": "NaVi",
            "series_score": 1,
            "current_map_score": 4,
            "connected_clients": 5,
            "ready": true,
            "side": "t"
        },
        "team2": {
            "name": "Astralis",
            "series_score": 0,
            "current_map_score": 10,
            "connected_clients": 5,
            "ready": true,
            "side": "ct"
        },
        "maps": [
            "de_dust2",
            "de_nuke",
            "de_inferno"
        ]
    }
    ```

####`get5_listbackups [matchid]` {: #get5_listbackups }
:   Lists backup files for the current match or a given match ID if provided.

####`get5_ringer <player>`
:   Adds/removes a ringer to/from the home scrim team. `player` is the name of the player. Similar
to [`!ringer`](../commands/#ringer)

####`get5_debuginfo [file]` {: #get5_debuginfo }
:   Dumps debug info to a file (`addons/sourcemod/logs/get5_debuginfo.txt` if no file parameter is provided).

####`get5_test`
:   Runs get5 tests. **This should not be used on a live match server since it will reload a match config to test**.

####`get5_web_available`
:   Indicates if the Get5 web panel has been installed.
