# Commands

Generally admin commands will have a `get5_` prefix and must be used in console. Commands intended for general player
usage are created with `sm_` prefixes, which means SourceMod automatically registers a `!` and `.` chat version of the
command. (For example: `sm_ready` in console is equivalent to `!ready` or `.ready` in chat).

## Client Commands

Please note that these can be typed by *all players* in chat.

####`!ready`

:   Marks the player as ready.

####`!unready`

:   Marks the player as not ready.

####`!pause`

:   Requests a freeze time pause. Pauses can be modified in the [Get5 config](../get5_configuration#pausing).

####`!unpause`

:   Requests an unpause. The other team must also call `!unpause`
if [get5_max_pause_time](../get5_configuration/#get5_max_pause_time)
is set to `0`. If [get5_fixed_pause_time](../get5_configuration/#get5_fixed_pause_time) is set to a non-zero value, this
command cannot be used. Pauses [`initiated by administrators`](../commands/#pause-commands) cannot be unpaused by
players.

####`!tech`

:   Requests a technical pause. These can be modified in the [Get5 config](../get5_configuration#pausing).

####`!coach`

:   Moves a client to coach for their team. Requires that
the [`sv_coaching_enabled`](https://totalcsgo.com/command/svcoachingenabled) variable is set to `1`.

####`!stay`

:   Elects to stay after a knife round win. This can be substituted by `!ct` or `!t` to select a side.

####`!swap` or `!switch`

:   Elects to swap team side after a knife round win. This can be substituted by `!ct` or `!t` to select a side.

####`!stop`

:   Asks to reload the last match backup file. The opposing team must confirm. Only works if
the [backup system is enabled](../get5_configuration/#get5_backup_system_enabled).

####`!forceready`

:   Force-readies your team, marking all players on your team as ready.

####`!get5`

:   Opens a menu that wraps some common commands. It's mostly intended for people using scrim settings, and has
menu buttons for starting a scrim, force-starting, force-ending, adding a ringer, and loading the most recent backup
file.

## Server/Admin Commands

Please note that these are meant to be used by *admins* in console.

####`get5_loadmatch <filename>`

:   Loads a match config file (JSON or KeyValue) relative from the `csgo` directory.

####`get5_loadbackup <filename>`
:   Loads a match config file (JSON or KeyValue) relative from the `csgo` directory.

####`get5_loadteam <team1|team2|spec> <filename>`
:   Loads a team section from a file into a team relative from the `csgo`
directory.

####`get5_loadmatch_url <url>`
:   Loads a remote (JSON-formatted) match config by sending an HTTP(S) GET to the given URL. This requires the
[Steamworks](https://forums.alliedmods.net/showthread.php?t=229556) extension. When specifying a URL with http:// or
https:// in front, you have to put it in quotation (`""`) marks.

####`get5_endmatch`
:   Force ends the current match. No winner is set (draw).

####`get5_creatematch`
:   Creates a BO1 match with the current players on the server on the current map.

####`get5_scrim`
:   Creates a BO1 match with the using settings from `addons/sourcemod/configs/get5/scrim_template.cfg`. You should
edit this file to contain your team's names in team 1.

####`get5_addplayer <auth> <team1|team2|spec> [name]`
:   Adds a Steam ID to a team (can be any format for the Steam ID). The name parameter optionally locks the player's
name.

####`get5_removeplayer <auth>`
:   Removes a steam ID from all teams (can be any format for the Steam ID).

####`get5_addkickedplayer <team1|team2|spec> [name]`
:   Adds the last kicked Steam ID to a team. The name parameter optionally locks the player's name.

####`get5_removekickedplayer <team1|team2|spec>`
:   Removes the last kicked Steam ID from all teams. Cannot be used in scrim mode.

####`get5_forceready`
:   Marks all teams as ready. `get5_forcestart` and [`!forceready`](../commands/#forceready) do the same thing.

####`get5_dumpstats`
:   Dumps current match stats to a file.

####`get5_status`
:   Replies with JSON formatted match state (available to all clients). The response structure is documented
under [Event Logs](./event_logs.md).

####`get5_listbackups [matchid]`
:   Lists backup files for the current match or a given match ID if provided.

####`get5_ringer <player>`
:   Adds/removes a ringer to/from the home scrim team. `player` is the name of the player.

####`get5_debuginfo [file]`
:   Dumps debug info to a file (addons/sourcemod/logs/get5_debuginfo.txt if no file parameter provided).

####`get5_test`
:   Runs get5 tests. **This should not be used on a live match server since it will reload a match config to test**.

## Pause Commands

As a server admin, you should not be calling pauses using `mp_pause_match` at any stage. Due to the way Get5 handles
pausing in game, you should either use [`!pause`](../commands/#pause) in chat as a player, or `sm_pause` in the console,
since this will
track all details and configurations related to pausing in the system. Similarly, `sm_unpause` should be used to
unpause. Pauses initiated by administrators via console **cannot** be [`!unpause`'ed](../commands/#unpause) by players
and have no
time-limits.
