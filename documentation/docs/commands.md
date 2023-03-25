# :material-apple-keyboard-command: Commands

Admin commands will have a `get5_` prefix and must be used in console. Commands intended for general player
usage are created with `sm_` prefixes, which means SourceMod automatically registers a `!` and `.` chat version of the
command. (For example: `sm_ready` in console is equivalent to `!ready` or `.ready` in chat).

## Client Commands

Please note that these can be typed by *all players* in chat.

####`!ready` or `!r` {: #ready }

:   Marks the player as ready.

####`!unready` or `!notready` {: #unready }

:   Marks the player as not ready.

####`!pause` or `!tac` {: #pause }

:   Requests a [tactical pause](../pausing#tactical).

####`!unpause`

:   Requests to unpause the game.

####`!tech`

:   Requests a [technical pause](../pausing#technical).

####`!coach`

:   Requests to become a [coach](../coaching) for your team. If already coaching, this will move you back as a player
if possible. Can only be used during warmup.

####`!stay`

:   Elects to stay after a knife round win. This can be substituted by `!ct` or `!t` to select a side.

####`!swap` or `!switch` {: #swap }

:   Elects to swap team side after a knife round win. This can be substituted by `!ct` or `!t` to select a side.

####`!ct` {: #ct }

:   Used by the team captain to select CT as the starting side during [map selection](../veto) or by any team member to
choose the CT side after winning the knife round.

####`!t` {: #t }

:   Used by the team captain to select T as the starting side during [map selection](../veto) or by any team member to
choose the T side after winning the knife round.

####`!stop`

:   Asks to reload the last match backup file, i.e. restart the current round. The opposing team must confirm before the
round ends. Only works if the [backup system is enabled](../configuration#get5_backup_system_enabled)
and [`get5_stop_command_enabled`](../configuration#get5_stop_command_enabled) is set to `1`. You can also set
a [time](../configuration#get5_stop_command_time_limit) or
[damage](../configuration#get5_stop_command_no_damage) restriction on the use of this command.

####`!forceready`

:   Force-readies your team, marking all players on your team as ready. This requires that your team has at
least [`min_players_to_ready`](../match_schema#schema) number of players. Access to this command can be disabled
with [`get5_allow_force_ready`](../configuration#get5_allow_force_ready).

####`!ringer <target>` {: #ringer }

:   Alias for [`get5_ringer`](#get5_ringer).

####`!scrim`

:   Alias for [`get5_scrim`](#get5_scrim).

####`!pick <map>` {: #pick }

:   Picks a map during [map selection](../veto). Can only be used by the team's captain when it's their turn to pick.

####`!ban <map>` {: #ban }

:   Bans a map during [map selection](../veto). Can only be used by the team's captain when it's their turn to ban.

####`!surrender` or `!gg` {: #surrender }

:   Initiates a vote to [surrender the current map](../surrender-forfeit#surrender).

####`!ffw`
:   Initiates a countdown to [win the series by forfeit](../surrender-forfeit#forfeit) (forfeit-win) if the entire
opposing team has left the server during the live phase of a map. The countdown is canceled if a player from the leaving
team rejoins the server within [the grace period](../configuration#get5_forfeit_countdown).

####`!cancelffw`
:   If a [timer to win by forfeit](../configuration#get5_forfeit_countdown) was started after a team left the
server, this stops that timer.

!!! info "All aboard!"

    The [`!ffw`](#ffw) and [`!cancelffw`](#cancelffw) commands can only be issued by a full team, which is evaluated via
    [`players_per_team`](../match_schema#schema). This prevents a player from reversing a team's decision to request or
    cancel a forfeit win if the rest of the team left.

####`!get5`

:   Opens a [menu](../getting_started#get5-menu) that allows access to common commands. You can use the menu to start
a new match (or scrim), [end a match](#get5_endmatch), [force teams ready](#get5_forceready) or load
a [backup](../backup).

## Customizing Chat Commands {: #custom-chat-commands }

Get5 allows you to customize the chat commands used by players. By default, all of the above commands can be used,
but you can define your own set of commands by adding aliases to
the [chat commands file](../configuration#chat-commands-file). This file is empty by default. When you add a new alias
for a command, that alias will be the one Get5 uses when it references the command in chat.

If you provide an invalid command (on the *right-hand side* in the config file), an error will be thrown. Avoid mapping
already used commands to other functionality, as it will likely be confusing to players. You may add multiple aliases
for a single command, but note that the **last** alias to be assigned to the command will be the one Get5 uses in chat.

The chat alias file is only loaded once per plugin boot. If you want to reload it, you must reload Get5.

!!! note "Valid Chat Commands"

    The follwing strings are valid commands, and are all explained in the list of commands above:

    [`ready`](#ready), [`unready`](#unready), [`forceready`](#forceready), [`tech`](#tech), [`pause`](#pause),
    [`unpause`](#unpause), [`coach`](#coach), [`stay`](#stay), [`swap`](#swap), [`t`](#stay), [`ct`](#stay),
    [`stop`](#stop), [`surrender`](#surrender), [`ffw`](#ffw), [`cancelffw`](#cancelffw), [`ban`](#ban), [`pick`](#pick)

!!! example "Example: `addons/sourcemod/configs/get5/commands.cfg`"

    This maps the French word *abandon* to the surrender command. Get5 will also print `!abandon` when it references the
    surrender command in chat messages. The original commands ([`!surrender`](#surrender) and [`!gg`](#surrender)) will
    still work. **Do not** prefix your alias with `!` or `.` - this is done automatically.

    ```
    "Commands"
    {
        "abandon" "surrender"
    }
    ```

## Server/Admin Commands

Please note that these are meant to be used by *admins* in console. The definition is:

**`command <required parameter> [optional parameter]`**

####`get5_loadmatch <filename>` {: #get5_loadmatch }

:   Loads a [match configuration](../match_schema) file (JSON or KeyValue) relative to the `csgo` directory.

####`get5_loadbackup <filename>` {: #get5_loadbackup }
:   Loads a match backup, relative to the `csgo` directory. Requires that
the [backup system is enabled](../configuration#get5_backup_system_enabled). If you
define [`get5_backup_path`](../configuration#get5_backup_path), you must include the path in the filename.

####`get5_loadbackup_url <url> [header name] [header value]` {: #get5_loadbackup_url }
:   Loads a match backup [from a remote host](../backup#remote) by sending an HTTP(S) `GET` to the given URL. Requires
that the [backup system is enabled](../configuration#get5_backup_system_enabled). You may optionally provide an HTTP
header and value pair using the `header name` and `header value` arguments. You should put all arguments inside
quotation marks (`""`).

####`get5_last_backup_file`
:   Prints the name of the last match backup file Get5 wrote in the current series, this is automatically updated each
time a backup file is written. Empty string if no backup was written.

####`get5_loadteam <team1|team2|spec> <filename>` {: #get5_loadteam }
:   Loads a [team section of a match configuration](../match_schema) from a file into a team relative to the `csgo`
directory. The file must contain a `Get5MatchTeam` object.

####`get5_loadmatch_url <url> [header name] [header value]` {: #get5_loadmatch_url }
:   Loads a remote (JSON-formatted) [match configuration](../match_schema) by sending an HTTP(S) `GET` to the given URL.
You may optionally provide an HTTP header and value pair using the `header name` and `header value` arguments. You
should put all arguments inside quotation marks (`""`).

!!! example

    With `Authorization`:<br>
    `get5_loadmatch_url "https://example.com/match_config.json" "Authorization" "Bearer <token>"`

    Without custom headers:<br>
    `get5_loadmatch_url "https://example.com/match_config.json"`

!!! warning "SteamWorks required"

    Loading remote matches requires the [SteamWorks](../installation#steamworks) extension.

!!! danger "File URL is public!"

    As the [`get_status`](#get5_status) command is available to all clients, be aware that everyone can see the URL of
    the loaded match configuration when loading from a remote. Make sure that your match configuration file does not
    contain any sensitive information *or* that it is protected by authorization or is inaccessible to clients.

####`get5_endmatch [team1|team2]` {: #get5_endmatch }
:   Force-ends the current match. The team argument will force the winner of the series and the current map to be set
to that team. Omitting the team argument sets no winner (tie). This command can be configured to
also [kick players](../configuration#get5_kick_on_force_end).

####`get5_creatematch [--parameter] [value]` {: #get5_creatematch }
:   Creates a new match using a CLI-approach. You can use this command to create almost any kind of match by combining
any of the following parameters as arguments. Running this command with no arguments creates a single match (5v5) with
the first map pool from your [maps file](../configuration#maps-file) and map selection enabled, as explained by the
defaults below.

!!! tip "Single dash is a shorthand & booleans don't take arguments"

    The parameters all have a double-dash (`--num_maps`) and a single-dash name (`-nm`). This is simply to allow you to
    shorten the command if you use the CLI often or with automated systems. Boolean switches can be disabled by simply
    *not* passing the parameter as they all default to `false`.

- `--num_maps` or `-nm`
    - The number of maps to play in the series.
    - Type: Integer
    - Default: `1`

- `--players_per_team` or `-ppt`
    - Determines the number of players per team.
    - Type: Integer
    - Default: `5` or `2` (depending on `--wingman`)

- `--coaches_per_team` or `-cpt`
    - Determines the maximum number of coaches per team.
    - Type: Integer
    - Default: `2`

- `--matchid` or `-id`
    - The ID of the match.
    - Type: String
    - Default: `""`

- `--skip_veto` or `-sv`
    - Disables the [map selection system](../veto).
    - Type: Boolean (no arguments)
    - Default: `false`

- `--side_type` or `-st`
    - Determines the behavior for side selection, unless overridden by `--map_sides`.
    - Type: `String`; one of `standard`, `always_knife`, `never_knife`, `random`
    - Default: `standard`

- `--coaches_must_ready` or `-cmr`
    - Determines if coaches must also [`!ready`](../commands#ready) up.
    - Type: `Boolean` (no arguments)
    - Default: `false`

- `--min_players_to_ready` or `-mptr`
    - Determines the minimum number of players that must be present before the [`!forceready`](../commands#forceready)
      command may be used.
    - Type: `Integer`
    - Default: `0`

- `--min_spectators_to_ready` or `-mstr`
    - Determines the minimum number of spectators that must [`!ready`](../commands#ready) up.
    - Type: `Integer`
    - Default: `0`

- `--scrim` or `-s`
    - Configures the match for [scrim mode](../getting_started#scrims). Cannot be combined with `--team2`. Optionally
      takes the name of the opposing team as an argument. `--team1` defines the home team. This parameter acts a boolean
      switch if no team name argument is supplied, in which case the opposing team will be unnamed.
    - Type: `String`
    - Default: `"" / false`

- `--wingman` or `-w`
    - Configures the match for [wingman mode](../wingman). This sets the default of `--players_per_team` to `2` if not
      provided.
    - Type: `Boolean` (no arguments)
    - Default: `false`

- `--veto_first` or `-vf`
    - Determines the logic for selecting which team gets to pick or ban a map first. Ignored if `--skip_veto` is passed.
    - Type: `String`; one of `team1`, `team2`, `random`
    - Default: `team1`

- `--current_map` or `-cm`
    - Creates a match on the *current* map. Cannot be combined with `--num_maps > 1` or `--maplist`.
    - Type: `Boolean` (no arguments)
    - Default: `false`

- `--no_series_clinch` or `-nsc`
    - Configures the series to play all maps, even if a team has practically won. I.e. plays all 3 maps of a Bo3.
      Irrelevant if `--num_maps` is 1.
    - Type: `Boolean` (no arguments)
    - Default: `false`

- `--team1` or `-t1`
    - Sets `team1`. Must be the key of a team in
      the [teams file](../configuration#teams-file). If you omit this *and* `--team2`, the match will be created with
      the current teams, and each team must have `--players_per_team` players present. Must not be equal to `--team2`.
    - Type: `String`
    - Default: `""`

- `--team2` or `-t2`
    - Sets `team2`. Must be the key of a team in the [teams file](../configuration#teams-file). Cannot be used
      with `--scrim`. Must not be equal to `--team1`.
    - Type: `String`
    - Default: `""`

- `--maplist` or `-ml`
    - Uses a custom map list instead of the maps from the [maps file](../configuration#maps-file). Must be a
      comma-separated list of map names, i.e. `de_mirage,de_nuke,de_vertigo` Cannot be used with `--current_map`
      or `--map_pool` and cannot contain fewer maps than provided to `--num_maps`.
    - Type: `String[]`
    - Default: `[]`

- `--map_sides` or `-ms`
    - Presets the sides for each map. Must be a comma-separated list of side options. It does *not* need to contain as
      many parameters as `--num_maps`, i.e. `team1_ct,team2_ct` could be used for a Bo3, and the side on the last map
      would be determined by the value of `--side_type`.
    - Type: `String[]`, any of: `team1_ct`, `team2_ct`, `knife`
    - Default: `[]`

- `--map_pool` or `-mp`
    - Determines which key to read maps from in the [maps file](../configuration#maps-file). The selected map pool
      cannot contain fewer maps than `--num_maps`. Cannot be used with `--maplist` or `--current_map`.
    - Type: String
    - Default: `default`

- `--cvars` or `-cv`
    - Determines which key to read `cvars` from in the [cvars file](../configuration#cvars-file).
    - Type: String
    - Default: `default`

- `--match_title` or `-mt`
    - Sets the title of the match.
    - Type: String
    - Default: `""`

!!! example "`get5_creatematch` examples"

    Bo3 with current teams and map selection, using the default maps from the [maps file](../configuration#maps-file):
    ```sh
    get5_creatematch --num_maps 3
    ```

    Bo3 with current teams using a specific set of maps:
    ```sh
    get5_creatematch --num_maps 3 --maplist "de_nuke,de_mirage,de_inferno,de_vertigo,de_cache"
    ```

    Single match with specific teams from the [teams file](../configuration#teams-file) and the default maps from the [maps file](../configuration#maps-file):
    ```sh
    get5_creatematch --team1 "astralis" --team2 "navi"
    ```

    A Bo3 scrim against a team named "Heroic" with home team preset to Astralis (from the [teams file](../configuration#teams-file)) and using the
    default map pool from the [maps file](../configuration#maps-file):
    ```sh
    get5_creatematch --num_maps 3 --team1 "astralis" --scrim "Heroic"
    ```

    A single scrim match against an unnamed team with a custom set of `cvars` (from the [cvars file](../configuration#cvars-file)):
    ```sh
    get5_creatematch --team1 "astralis" --scrim --cvars "no_ff_casual"
    ```

    A Bo5 from an extended map pool in the [maps file](../configuration#maps-file) and fixed teams from the [teams file](../configuration#teams-file):
    ```sh
    get5_creatematch --num_maps 5 --team1 "astralis" --team2 "navi" --map_pool "extended"
    ```

    A 1v1 wingman match with current players on the current map:
    ```sh
    get5_creatematch --current_map --wingman --players_per_team 1
    ```

    A Bo3 with current teams, sides *and* maps already set and a custom title. `--skip_veto` is not required when
    `--num_maps` is the same as the number of maps provided to `--maplist`.
    ```sh
    get5_creatematch --num_maps 3 --maplist "de_nuke,de_mirage,de_inferno"
    --map_sides "team1_ct,team2_ct,knife" --match_title "Blast Fall Final 2022"
    ```

####`get5_scrim [opposing team name] [map name] [matchid]` {: #get5_scrim }
:   Creates a [scrim](../getting_started#scrims) on the current map using the `scrim_template.cfg` approach. The
opposing team name defaults to `Away` and the map defaults to the current map. `matchid` defaults to `scrim`. You should
**not** provide a match ID if you use the [MySQL extension](../stats_system#mysql).

!!! note "Legacy"

    You should consider using the teams file + `get5_creatematch` CLI-approach instead of this command.
    The same could be accomplished by adding your home team to your teams file and running this command:<br>
    `get5_creatematch --scrim [opposing team name] --maplist [map name] --matchid [match id] --team1 [home team id]`

####`get5_addplayer <auth> <team1|team2|spec> [name]` {: #get5_addplayer }
:   Adds a Steam ID to a team (can be any format for the Steam ID). The name parameter optionally locks the player's
name.

####`get5_addcoach <auth> <team1|team2> [name]` {: #get5_addcoach }
:   Adds a Steam ID to a team as a coach. The name parameter optionally locks the player's
name. This requires that [`sv_coaching_enabled`](https://totalcsgo.com/command/svcoachingenabled) is enabled and cannot
be used in [scrim mode](../getting_started#scrims).

####`get5_removeplayer <auth>` {: #get5_removeplayer}
:   Removes a steam ID from all teams (can be any format for the Steam ID). This also removes the player as
a [coach](../coaching). If [`get5_check_auths`](../configuration#get5_check_auths) is set, the player will be removed
from the server immediately.

####`get5_addkickedplayer <team1|team2|spec> [name]` {: #get5_addkickedplayer }
:   Adds the last kicked Steam ID to a team. The name parameter optionally locks the player's name.

####`get5_removekickedplayer` {: #get5_removekickedplayer }
:   Removes the last kicked Steam ID from all teams. Cannot be used in scrim mode.

####`get5_add_ready_time <seconds>` {: #get5_add_ready_time }
:   Adds additional time-to-ready, limited by [`get5_time_to_start`](../configuration#get5_time_to_start)
or [`get5_time_to_start_veto`](../configuration#get5_time_to_start_veto), depending on the game state. Can only be used
during ready-up phases.

####`get5_forceready`
:   Marks all teams as ready. `get5_forcestart` does the same thing.

####`get5_status`
:   Replies with JSON formatted match state (available to all clients).

!!! abstract "Definition"

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
            | "going_live" | "live" | "pending_restore" | "post_game", // (2)
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
    2. The current state of the game. The definition lists them in the order they would typically occur.
       <br><br>**`none`**<br>No Get5 configuration was loaded and Get5 will only interfere if
       [`get5_autoload_config`](../configuration#get5_autoload_config) is defined.
       <br><br>**`pre_veto`**<br>The game is in warmup, waiting for players to [`!ready`](../commands#ready) for
       [map selection](../veto).
       <br><br>**`veto`**<br>The game is in warmup with the [map selecton](../veto) phase currently ongoing.
       <br><br>**`warmup`**<br>The game is in warmup, waiting for players to [`!ready`](../commands#ready) for either
       the knife-round or live.
       <br><br>**`knife`**<br>The knife-round is ongoing.
       <br><br>**`waiting_for_knife_decision`**<br>The knife-round has ended and a decision to
       [`!stay`](../commands#stay) or [`!swap`](../commands#swap) is pending.
       <br><br>**`going_live`**<br>The countdown to live has begun.
       <br><br>**`live`**<br>The game is live.
       <br><br>**`pending_restore`**<br>A [backup](../backup) for a different map was loaded and the game is either
       pending a map change or waiting for users to [`!ready`](../commands#ready) to restore to a live round.
       <br><br>**`post_game`**<br>The map has ended and the countdown to the next map or
       [server config restoration](../configuration#get5_reset_cvars_on_end) is ongoing. If the server is broadcasting 
       [GOTV](../gotv/#broadcast), it will remain in `post_game` at least until the broadcast has ended.
    3. Whether the game is currently [paused](../pausing).
    4. The match configuration file currently loaded. `Example: "addons/sourcemod/configs/get5/match_config.json"`. Note
       that this points to the URL of the match configuration when a match was loaded
       using [`get5_loadmatch_url`](#get5_loadmatch_url).
    5. The current match ID. Empty string if not defined or `scrim` or `manual` if using
       [`get5_scrim`](../commands#get5_scrim) or [`get5_creatematch`](../commands#get5_creatematch).
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
    15. Whether the team is [`!ready`](../commands#ready).
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
:   Lists backup files for the current match or a given match ID if provided. If you define
[`get5_backup_path`](../configuration#get5_backup_path), it will only list backups found under that prefix.

####`get5_ringer <target>` {: #get5_ringer }
:   Adds/removes a ringer to/from the home scrim team. `target` is the name of the player, their user ID or their Steam
ID. Similar to [`!ringer`](../commands#ringer) in chat. To target a user or Steam ID, prefix it with a `#`, i.e.
`get5_ringer #43` to target user ID 43.
See [this article](https://wiki.alliedmods.net/Admin_Commands_(SourceMod)#How_to_Target) for details.

!!! example "User ID vs client index"

    To view user IDs, type `users` in console. In this example, `43` is the user ID and `1` is the client index:
    ```
    > users
    1:43:"Quinn"
    ```

####`get5_dumpstats [file]` {: #get5_dumpstats }
:   Dumps [player stats](../stats_system#keyvalue) to a file, relative to the `csgo` directory, defaulting
to `get5_matchstats.cfg` if no file parameter is provided. If you provide a `.json` filename, the stats data will be
output in JSON format.

####`get5_debuginfo [file]` {: #get5_debuginfo }
:   Dumps debug info to a file, relative to the `csgo` directory, defaulting
to `addons/sourcemod/logs/get5_debuginfo.txt` if no file parameter is provided.

####`get5_test`
:   Runs get5 tests. **This should not be used on a live match server since it will reload a match config to test**.

####`get5_web_available`
:   Indicates if the Get5 web panel has been installed.
