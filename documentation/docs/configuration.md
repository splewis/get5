# :material-cog: Configuration

This is a list of all the configuration parameters you can set that change how Get5 behaves.

### The Main Config File {: #main-config }

The config file is auto-generated on **first plugin run**, then auto-executed on each plugin start. The file is located
here:

```yaml
cfg/sourcemod/get5.cfg
```

You can either set the below parameters in that file, or in the `cvars` section of a match config. As mentioned in
the explanation of the [match schema](../match_schema), that section will override all other settings.

### Phase Configuration Files

You should also have three config files. These can be edited, but we recommend not
blindly pasting another config in (e.g. ESL, CEVO). These must only include commands you would run in the console (such
as `mp_friendly_fire 1`) and should determine the rules for those three stage of your match. You can
also [point to other files](#config-files) by editing the main config file.

```yaml
cfg/get5/warmup.cfg # (1)
cfg/get5/knife.cfg # (2)
cfg/get5/live.cfg # (3)
```

1. Executed when the warmup/veto phase begins.
2. Executed when the knife-round starts.
3. Executed when the game goes live.

!!! danger "Prohibited options"

    You should avoid these commands in your live, knife and warmup configuration files, as all of these are handled by
    Get5 automatically. Introducing restarts, warmup changes or [GOTV](gotv.md) delay modifications can cause problems.
    If you want to set your `tv_delay` or `tv_delay1`, do it in the `cvars` section of your
    [match configuration](match_schema.md).

    ```
    mp_do_warmup_period
    mp_restartgame
    mp_warmup_end
    mp_warmup_pausetimer   
    mp_warmup_start
    mp_warmuptime
    mp_warmuptime_all_players_connected
    tv_delay
    tv_delay1
    tv_delaymapchange
    tv_enable
    tv_enable1
    tv_record
    tv_stoprecord
    ```

## Server Setup

####`get5_server_id`
:   Integer that identifies your server. This is used in temporary and backup files to prevent collisions and added as a
header to [demo uploads](gotv.md#upload) and [event requests](events_and_forwards.md#http). You should set this if you
run multiple servers off the same storage, such as if using [Docker](https://www.docker.com/). This also defines
the [`{SERVERID}`](#tag-serverid) substitution and the return value of the `Get5_GetServerID`
native.<br>**`Default: 0`**

!!! tip "Server ID could be port number"

    A good candidate for `get5_server_id` would be the port number the server is bound to, since it uniquely identifies
    a server instance on a host and ensures that no two instances run with the same server ID at the same time.

####`get5_kick_immunity`
:   Whether [admins](../installation/#administrators) will be immune to kicks from
[`get5_kick_when_no_match_loaded`](#get5_kick_when_no_match_loaded).<br>**`Default: 1`**

####`get5_kick_when_no_match_loaded`
:   Whether to kick all clients if no match is loaded. Players will not be kicked if a match is forcefully ended
using [`get5_endmatch`](../commands/#get5_endmatch).<br>**`Default: 0`**

####`get5_display_gotv_veto`
:   Whether to wait for [map vetoes](veto.md) to be broadcast to [GOTV](gotv.md) before changing
map.<br>**`Default: 0`**

####`get5_check_auths`
:   Whether the Steam IDs from the `players`, `coaches` and `spectators` sections of
a [match configuration](../match_schema/#schema) are used to force players onto teams. Anyone not defined will be
removed from the game, or if in [scrim mode](../getting_started/#scrims), put on `team2`.<br>**`Default: 1`**

####`get5_print_update_notice`
:   Whether to print to chat when the game goes live if a new version of Get5 is available. This only works if
[SteamWorks](../installation/#steamworks) has been installed.<br>**`Default: 1`**

####`get5_pretty_print_json`
:   Whether to pretty-print all JSON output. This also affects the output of JSON in the
[event system](../events_and_forwards).<br>**`Default: 1`**

####`get5_autoload_config`
:  A [match configuration](../match_schema/#schema) file, relative to the `csgo` directory, to autoload when the server
starts, when Get5 is reloaded or if no match is loaded when a player joins the server. Set to empty string to
disable.<br>**`Default: ""`**

####`get5_debug`
:   Enable or disable verbose debug output from Get5. Intended for development and debugging purposes
only.<br>**`Default: 0`**

## Match Setup

####`get5_ready_team_tag`
:   Adds `[READY]` or `[NOT READY]` tags to team names.<br>**`Default: 1`**

####`get5_live_countdown_time`
:   Number of seconds used to count down when a match is going live.<br>**`Default: 10`**

####`get5_auto_ready_active_players`
:   Whether to automatically mark players as ready if they kill anyone in the warmup or [veto](veto.md)
phase.<br>**`Default: 0`**

####`get5_allow_force_ready`
:   Whether the [`!forceready`](../commands/#forceready) command is accessible to players. This does not
affect the availability of [`get5_forceready`](../commands/#get5_forceready) to admins.<br>**`Default: 1`**

####`get5_set_client_clan_tags`
:   Whether to set client clan tags to player ready status.<br>**`Default: 1`**

####`get5_time_to_start`
:   Time (in seconds) teams have to ready up before forfeiting the match. Set to zero to remove
limit. If set to a non-zero value, [`get5_forfeit_countdown`](#get5_forfeit_countdown) behaves differently
during warmup or veto. If neither team becomes ready in time, the series is ended in a tie.<br>**`Default: 0`**

####`get5_time_to_make_knife_decision`
:   Time (in seconds) a team has to make a [`!stay`](../commands/#stay) or [`!swap`](../commands/#swap)
decision after winning knife round. Cannot be set lower than 10 if non-zero. Set to zero to remove
limit.<br>**`Default: 60`**

####`get5_veto_countdown`
:   Time (in seconds) to countdown before the [veto](veto.md) process commences. Set to zero to move to veto without a
countdown.<br>**`Default: 5`**

####`get5_veto_confirmation_time`
:   Time (in seconds) from presenting a [veto](veto.md) menu to a selection being made, during which a confirmation will
be required. 0 to disable.<br>**`Default: 2.0`**

####`get5_print_damage`
:   Whether to print damage reports when a round ends. The format is determined
by [`get5_damageprint_format`](#get5_damageprint_format).<br>**`Default: 0`**

####`get5_print_damage_excess`
:   Whether to include damage that exceeds the remaining health of a player in the chat
report. If enabled, you can inflict more than 100 damage to a player in the damage report. Ignored if
[`get5_print_damage`](#get5_print_damage) is disabled.<br>**`Default: 0`**

####`get5_phase_announcement_count`
:   The number of times the "Knife" or "Match is LIVE" announcements will be printed in chat. Set to zero to
disable.<br>**`Default: 5`**

####`get5_team1_color`
:   The [color](#color-substitutes) to use when printing the name of `team1` in chat
messages.<br>**`Default: "{LIGHT_GREEN}"`**

####`get5_team2_color`
:   The [color](#color-substitutes) to use when printing the name of `team2` in chat
messages.<br>**`Default: "{PINK}"`**

####`get5_spec_color`
:   The [color](#color-substitutes) to use when printing the name of `spectators` in chat
messages.<br>**`Default: "{NORMAL}"`**

## Pausing

####`get5_pausing_enabled`
:   Whether [pauses](../pausing) are available to clients or not.<br>**`Default: 1`**

####`get5_max_pauses`
:   Number of [tactical pauses](../pausing/#tactical) a team can use. Set to zero to remove limit.<br>**`Default: 0`**

####`get5_max_pause_time`
:   Maximum number of seconds the game can spend under tactical pause for a team. When pauses are
unlimited and when [get5_fixed_pause_time](#get5_fixed_pause_time) is zero, both teams
must call [`!unpause`](../commands/#unpause) to continue the match. This parameter is ignored
if [get5_fixed_pause_time](#get5_fixed_pause_time) is set to a non-zero
value. Set to zero to remove limit.<br>**`Default: 300`**

####`get5_fixed_pause_time`
:   If non-zero, the fixed length in seconds of all [`tactical`](../pausing/#tactical) pauses. This takes precedence
over the [get5_max_pause_time](#get5_max_pause_time) parameter, which will be ignored.<br>**`Default: 0`**

####`get5_allow_technical_pause`
:   Whether [technical pauses](../pausing/#technical) are available to clients or not. Note that this depends
on [`get5_pausing_enabled`](#get5_pausing_enabled) being enabled as well.<br>**`Default: 1`**

####`get5_max_tech_pauses`
:   Number of [technical pauses](../pausing/#technical) a team is allowed to have. Set to zero to remove
limit.<br>**`Default: 0`**

####`get5_tech_pause_time`
:   If non-zero, number of seconds before any team can call [`!unpause`](../commands/#unpause) to end
a [technical pause](../pausing/#technical) without confirmation from the pausing team. Set to zero to remove
limit.<br>**`Default: 0`**

####`get5_pause_on_veto`
:   Whether to freeze players during the [veto](veto.md) phase.<br>**`Default: 0`**

####`get5_reset_pauses_each_half`
:   Whether [tactical pause](../pausing/#tactical) limits (time used and count) are reset each halftime period.
[Technical pauses](../pausing/#technical) are not reset.<br>**`Default: 1`**

## Surrender

####`get5_surrender_enabled`
:   Whether the [`!surrender`](../commands/#surrender) command is available.<br>**`Default: 0`**

####`get5_surrender_minimum_round_deficit`
:   The minimum number of rounds a team must be behind in order to initiate a vote to surrender. This cannot be set
lower than `1`.<br>**`Default: 8`**

####`get5_surrender_required_votes`
:   The number of votes required to surrender as a team. If set to `1` or below, any attempt to surrender will
immediately succeed.<br>**`Default: 3`**

####`get5_surrender_time_limit`
:   The number of seconds a team has to vote to surrender after the first vote is cast. This cannot be set lower
than `10`.<br>**`Default: 15`**

####`get5_surrender_cooldown`
:   The minimum number of seconds a team must wait before they can initiate a surrender vote following a failed
vote. Set to zero to disable.<br>**`Default: 60`**

####`get5_forfeit_countdown`
:   If a full team disconnects during the live phase, the [`!win`](../commands/#win) command becomes available to the
opposing team, and this then determines the number of seconds a player from the disconnecting team has to rejoin the
server before the opposing team wins. If both teams disconnect (at any stage), this determines how long at least one
player from both teams have to rejoin the server before the series is ended in a tie. This value cannot be set lower
than 30.<br>**`Default: 60`**

!!! info "Ready-up logic takes precedence"

    If [`get5_time_to_start`](#get5_time_to_start) is larger than 0 and the game is in the warmup or veto phase, the
    ready-up surrender logic takes precedence and there will be no forfeit-countdown when players leave the server.

!!! warning "Empty server ends the series"

    If there are no players at all (no spectators, coaches or players) and someone rejoins the server during the live
    phase, a pending forfeit timer will immediately trigger a series end, as the game will restart which causes a loss
    of game state. If this happens, you must [restore the game state from a backup](../commands/#get5_loadbackup) to
    continue.

## Backup System

####`get5_backup_system_enabled`
:   Whether the [backup system](backup.md) is enabled. This is required for the use of the [`!stop`](../commands/#stop)
command as well as the [`get5_loadbackup`](../commands/#get5_loadbackup) command.<br>**`Default: 1`**

####`get5_stop_command_enabled`
:   Whether the [`!stop`](../commands/#stop) command is enabled.<br>**`Default: 1`**

####`get5_max_backup_age`
:   Number of seconds before a Get5 backup file is automatically deleted. If you define
[`get5_backup_path`](#get5_backup_path), only files in that path will be deleted. Set to zero to
disable.<br>**`Default: 160000`**

####`get5_backup_path`
:   The folder of saved [backup files](../commands/#get5_loadbackup), relative to the `csgo` directory. You **can** use
the [`{MATCHID}`](#tag-matchid) variable, i.e. `backups/{MATCHID}/`.<br>**`Default: ""`**

!!! warning "Slash, slash, hundred-yard dash :material-slash-forward:"

    It is very important that your backup path does **not** start with a slash but instead **ends with a slash**. If
    not, the last part of the path will be considered a prefix of the filename and things will not work correctly. Also
    note that if you use the [`{MATCHID}`](#tag-matchid) variable, [automatic deletion of backups](#get5_max_backup_age)
    does not work.

    :white_check_mark: `backups/`

    :white_check_mark: `backups/{MATCHID}/`

    :no_entry: `/backups/`

    :no_entry: `/backups/{MATCHID}`

## Formats & Paths

####`get5_time_format`
:   Date and time format string. This determines the [`{TIME}`](#tag-time) tag.<br>**`Default: "%Y-%m-%d_%H-%M-%S"`**

####`get5_date_format`
:   Date format string. This determines the [`{DATE}`](#tag-date) tag.<br>**`Default: "%Y-%m-%d"`**

!!! danger "Advanced users only"

    Do not change the time format unless you know what you are doing. Please always include a component of hours,
    minutes and seconds in your `get5_time_format` so that [demo files](#get5_demo_name_format) will not be overwritten.
    You can find the reference for formatting a time string [here](https://cplusplus.com/reference/ctime/strftime/). The
    default example above prints time in this format: `2022-06-12_13-15-45`.

####`get5_event_log_format`
:   Format to write event logs to. Set to empty string to disable writing event logs.<br>**`Default: ""`**

####`get5_stats_path_format`
:   Path where stats are output on each map end. Set to empty string to
disable.<br>**`Default: "get5_matchstats_{MATCHID}.cfg"`**

####`get5_hostname_format`
:   The hostname to apply to the server when a match configuration is loaded.
[State substitutes](#state-substitutes) can be used. Leave blank to disable changing the hostname.<br>
**`Default: "Get5: {TEAM1} vs {TEAM2}"`**

####`get5_message_prefix`
:   The tag applied before plugin messages. Note that at least one character must come before
a [color modifier](#color-substitutes).<br>**`Default: "[{YELLOW}Get5{NORMAL}]"`**

####`get5_damageprint_format`
:   Formatting of damage reports in chat on round end. Ignored
if [`get5_print_damage`](#get5_print_damage) is disabled.<br>
**`Default: "- [{KILL_TO}] ({DMG_TO} in {HITS_TO}) to [{KILL_FROM}] ({DMG_FROM} in {HITS_FROM}) from {NAME} ({HEALTH} HP)"`**

!!! example "Damage report example"

    The default example above prints the following to chat on round end and includes information about kills, deaths,
    assists and flash assists.

    `{KILL_TO}` becomes a green `X` for a kill or a yellow `A` or `F` for assist or flash assist, respectively.

    `{KILL_FROM}` is similar to `{KILL_TO}`, but the `X` value is red (indicating a player killed you).

    No attribution replaces `{KILL_TO}` and/or `{KILL_FROM}` with a white dash: `-`.
    ```
    [Get5] Team A 1 - 0 Team B
    - [X] (100 in 3) to [A] (44 in 1) from Player1 (0 HP) # - Killed this player, they assisted in killing you.
    - [F] (0 in 0) to [X] (56 in 2) from Player2 (0 HP)   # - Killed by this player, flash assisted in killing them.
    - [-] (0 in 0) to [-] (0 in 0) from Player3 (84 HP)   # - No interaction, this player survived.
    - [A] (73 in 2) to [-] (0 in 0) from Player4 (0 HP)   # - Assisted in killing this player.
    - [-] (30 in 1) to [-] (0 in 0) from Player5 (0 HP)   # - Dealt damage to this player, not enough for assist.
    ```

## Config Files

####`get5_live_cfg`
:   Config file executed when the game goes live, relative to `csgo/cfg`.<br>**`Default: "get5/live.cfg"`**

####`get5_warmup_cfg`
:   Config file executed in warmup periods, relative to `csgo/cfg`.<br>**`Default: "get5/warmup.cfg"`**

####`get5_knife_cfg`
:   Config file executed for the knife round, relative to `csgo/cfg`.<br>**`Default: "get5/knife.cfg"`**

## Demos

####`get5_demo_upload_url`
:   If defined, Get5 will [automatically send a recorded demo](gotv.md#upload) to this URL in an HTTP `POST` request
once a recording stops. If no protocol is provided, `http://` will be prepended to this value. Requires the
[SteamWorks](../installation/#steamworks) extension.<br>**`Default: ""`**

####`get5_demo_upload_header_key`
:   If this **and** [`get5_demo_upload_header_value`](#get5_demo_upload_header_value) are defined, this header name and
value will be used for your [demo upload HTTP request](#get5_demo_upload_url).<br>**`Default: "Authorization"`**

####`get5_demo_upload_header_value`
:   If this **and** [`get5_demo_upload_header_key`](#get5_demo_upload_header_key) are defined, this header name and
value will be used for your [demo upload HTTP request](#get5_demo_upload_url).<br>**`Default: ""`**

####`get5_demo_delete_after_upload`
:   Whether to delete the demo file from the game server after
successfully [uploading it to a web server](gotv.md#upload).<br>**`Default: 0`**

####`get5_demo_path`
:   The folder of saved [demo files](../gotv#demos), relative to the `csgo` directory. You **can** use
the [`{MATCHID}`](#tag-matchid) and [`{DATE}`](#tag-date) variables, i.e. `demos/{DATE}/{MATCHID}/`.
Much like [`get5_backup_path`](#get5_backup_path), the path must **not** start with a slash, and
must **end with a slash**.<br>**`Default: ""`**

####`get5_demo_name_format`
:   Format to use for demo files when [recording matches](gotv.md#demos). Do not include a file extension (`.dem` is
added automatically). If you do not include the [`{TIME}`](#tag-time) tag, you will have problems with duplicate files
if restoring a game from a backup. Note that the [`{MAPNUMBER}`](#tag-mapnumber)variable is not zero-indexed. Set to
empty string to disable recording demos.<br>**`Default: "{TIME}_{MATCHID}_map{MAPNUMBER}_{MAPNAME}"`**

## Events

####`get5_remote_log_url`
:   The URL to send all [events](events_and_forwards.md#http) to. Requires the [SteamWorks](../installation/#steamworks)
extension. Set to empty string to disable.<br>**`Default: ""`**

####`get5_remote_log_header_key`
:   If this **and** [`get5_remote_log_header_value`](#get5_remote_log_header_value) are defined, this
header name and value will be used for your [event HTTP requests](events_and_forwards.md#http).<br>**`Default: "Authorization"`**

####`get5_remote_log_header_value`
:   If this **and** [`get5_remote_log_header_key`](#get5_remote_log_header_key) are defined, this header
name and value will be used for your [event HTTP requests](events_and_forwards.md#http).<br>**`Default: ""`**

## Substitution Variables

### Match/State Substitutes {: #state-substitutes }

Various configuration parameters, such as the file format parameters or the `get5_hostname_format` option, take
placeholder strings that will be replaced by meaningful values when printed. Note that these are **case-sensitive**, so
`{Mapname}` would not work.

####`{TIME}` {: #tag-time}
:   The current time, determined by [`get5_time_format`](#get5_time_format).

####`{DATE}` {: #tag-date}
:   The current date, determined by [`get5_date_format`](#get5_date_format).

####`{MAPNAME}` {: #tag-mapname}
:   The pretty-printed name of the map, i.e. **Dust II** for `de_dust2`.

####`{MAPNUMBER}` {: #tag-mapnumber}
:   The map number being played. **Note: Not zero-indexed!**

####`{MAXMAPS}` {: #tag-maxmaps}
:   The maximum number of maps in the series, i.e. `3` for a Bo3.

####`{MATCHID}` {: #tag-matchid}
:   The match ID.

####`{TEAM1}` {: #tag-team1}
:   The name of `team1`.

####`{TEAM2}` {: #tag-team2}
:   The name of `team2`.

####`{MATCHTITLE}` {: #tag-matchtitle}
:   The title of the current match.

####`{SERVERID}` {: #tag-serverid}
:   The value provided to the [`get5_server_id`](#get5_server_id) parameter.

### Colour Substitutes {: #color-substitutes }

These variables can be used to color text in the chat. You must return to `{NORMAL}` (white)
after using a color variable.

Example: `This text becomes {DARK_RED}red{NORMAL}, while {YELLOW}all of this will be yellow`.

- `{NORMAL}`
- `{DARK_RED}`
- `{PINK}`
- `{GREEN}`
- `{YELLOW}`
- `{LIGHT_GREEN}`
- `{LIGHT_RED}`
- `{GRAY}`
- `{ORANGE}`
- `{LIGHT_BLUE}`
- `{DARK_BLUE}`
- `{PURPLE}`
- `{GOLD}`
