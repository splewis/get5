# Commands
Generally admin commands will have a `get5_` prefix and must be used in console. Commands intended for general player usage are created with `sm_` prefixes, which means sourcemod automtically registers a `!` chat version of the command. (For example: sm_ready in console is equivalent to !ready in chat)

Some client commands are available also for admin usage. For example, `sm_pause` and `sm_unpause` will force pauses if executed by the server (e.g., through `rcon`).

## Client Commands 
Please note that these can be typed by *all players* in chat.

- `!ready`: Marks a client's team as ready to begin.
- `!unready`: Marks a client's team as not-ready.
- `!pause`: Requests a freeze time pause. Pauses can be modified in the Get5 config.
- `!unpause`: Requests an unpause, requires the other team to confirm if pauses are not timed.
- `!tech`: Requests a technical pause. These can be modified in the Get5 config.
- `!coach`: Moves a client to coach for their team.
- `!stay`: Elects to stay after a knife round win.
- `!swap`: Elects to swap team side after a knife round win.
- `!switch`: Same as `!swap`.
- `!stop`: Asks to reload the last match backup file, requires other team to confirm.
- `!forceready`: Force readies your team, letting your team start regardless of player numbers/whether they are ready.
- `!get5`: Opens a menu that wraps some common commands. It's mostly intended for people using scrim settings, and has menu buttons for starting a scrim, force-starting, force-ending, adding a ringer, and loading the most recent backup file.

## Server/Admin Commands 
Please note that these are meant to be used by *admins* in console.

- `get5_loadmatch <filename>`: Loads a match config file (JSON or KeyValue) relative from the `csgo` directory.
- `get5_loadbackup <file>`: Loads a get5 backup file relative from the `csgo` directory.
- `get5_loadteam <team1|team2|spec> <filename>`: Loads a team section from a file into a team relative from the `csgo` directory.
- `get5_loadmatch_url <url>`: Loads a remote (JSON formatted) match config by sending a HTTP(S) GET to the given url, this requires the [Steamworks](https://forums.alliedmods.net/showthread.php?t=229556) extension. When specifying an URL with http:// or https:// in front, you have to put it in quotation (`""`) marks.
- `get5_endmatch`: Force ends the current match.
- `get5_creatematch`: Creates a BO1 match with the current players on the server on the current map.
- `get5_scrim`: Creates a BO1 match with the using settings from `addons/sourcemod/configs/get5/scrim_template.cfg`, relative from the `csgo` directory.
- `get5_addplayer <auth> <team1|team2|spec> [name]`: Adds a Steam ID to a team (can be any format for the Steam ID).
- `get5_removeplayer <auth>`: Removes a steamid from all teams (can be any format for the Steam ID).
- `get5_addkickedplayer <team1|team2|spec> [name]`: Adds the last kicked Steam ID to a team
- `get5_removekickedplayer`: Removes the last kicked steamid from all teams, cannot be used in scrim mode.
- `get5_forceready`: Marks all teams as ready.
- `get5_forcestart`: Same as `get5_forceready`.
- `get5_dumpstats`: Dumps current match stats to a file.
- `get5_status`: Replies with JSON formatted match state (available to all clients).
- `get5_listbackups <matchid>`: Lists backup files for the current matchid or a given matchid if not provided.
- `get5_ringer <player>`: Adds/removes a ringer to/from the home scrim team.
- `sm_ringer <player>`: Same as `get5_ringer`.
- `get5_debuginfo <file>`: Dumps debug info to a file (addons/sourcemod/logs/get5_debuginfo.txt by default, if no file provided).
- `get5_test`: Runs get5 tests. **This should not be used on a live match server since it will reload a match config to test**.
