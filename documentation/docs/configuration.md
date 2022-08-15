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
blindly pasting another config in (e.g. ESL, CEVO). Configs that execute warmup commands (`mp_warmup_end`, for
example) **will** cause problems. These must only include commands you would run in the console (such
as `mp_friendly_fire 1`) and should determine the rules for those three stage of your match. You can
also [point to other files](#config-files) by editing
the main config file.

```yaml
cfg/get5/warmup.cfg # (1)
cfg/get5/knife.cfg # (2)
cfg/get5/live.cfg # (3)
```

1. Executed when the warmup/veto phase begins.
2. Executed when the knife-round starts.
3. Executed when the game goes live.

## Server Setup

**These options will generally not be directly presented to clients.**

####`get5_server_id`
:   Integer that identifies your server. This is used in temp files to prevent collisions. Defines the
[`{SERVERID}`](#tag-serverid) substitution and the return value of the `Get5_GetServerID` native. **`Default: 0`**

####`get5_kick_immunity`
:   Whether [admins](../installation/#administrators) will be immune to kicks from
[`get5_kick_when_no_match_loaded`](#get5_kick_when_no_match_loaded). **`Default: 1`**

####`get5_stop_command_enabled`
:   Whether the [`!stop`](../commands/#stop) command is enabled. **`Default: 1`**

####`get5_kick_when_no_match_loaded`
:   Whether to kick all clients if no match is loaded. Players will not be kicked if a match is forcefully ended
using [`get5_endmatch`](../commands/#get5_endmatch). **`Default: 0`**

####`get5_end_match_on_empty_server`
:   Whether the match is ended with no winner if all players leave (note: this will happen even if all players
disconnect even in warmup with the intention to reconnect!). **`Default: 0`**

####`get5_display_gotv_veto`
:   Whether to wait for map vetoes to be printed to GOTV before changing map. **`Default: 0`**

####`get5_check_auths`
:   Whether the Steam IDs from a `players` of a [match configuration](../match_schema/#schema) section are used to
force players onto teams, kicking everyone else. **`Default: 1`**

####`get5_print_update_notice`
:   Whether to print to chat when the game goes live if a new version of Get5 is available. This only works if
[SteamWorks](../installation/#steamworks) has been installed. **`Default: 1`**

####`get5_pretty_print_json`
:   Whether to pretty-print all JSON output. This also affects the output of JSON in the
[event system](../events_and_forwards). **`Default: 1`**

####`get5_hostname_format`
:   The hostname to apply to the server when a match configuration is loaded.
[State substitutes](#state-substitutes) can be used. Leave blank to disable changing the hostname.
**`Default: Get5: {TEAM1} vs {TEAM2}`**

## Match Setup

**These options will generally be represented by in-game changes to the client.**

####`get5_ready_team_tag`
:   Adds `[READY]` or `[NOT READY]` tags before team names, and removes clan tags from users. **`Default: 1`**

####`get5_live_countdown_time`
:   Number of seconds used to count down when a match is going live. **`Default: 10`**

####`get5_auto_ready_active_players`
:   Whether to automatically mark players as ready if they kill anyone in the warmup or veto phase. **`Default: 0`**

####`get5_set_client_clan_tags`
:   Whether to set client clan tags to player ready status. **`Default: 1`**

####`get5_time_to_start`
:   Time (in seconds) teams have to ready up before forfeiting the match, 0 = unlimited. **`Default: 0`**

####`get5_time_to_make_knife_decision`
:   Time (in seconds) a team has to make a [`!stay`](../commands/#stay) or [`!swap`](../commands/#swap)
decision after winning knife round, 0 = unlimited. **`Default: 60`**

####`get5_veto_countdown`
:   Time (in seconds) to countdown before veto process commences. **`Default: 5`**

####`get5_veto_confirmation_time`
:   Time (in seconds) from presenting a veto menu to a selection being made, during which a confirmation will be
required. 0 to disable. **`Default: 2.0`**

####`get5_print_damage`
:   Whether to print damage reports on round ends. **`Default: 0`**

####`get5_print_damage_excess`
:   Whether to include damage that exceeds the remaining health of a player in the chat
report. If enabled, you can inflict more than 100 damage to a player in the damage report. Ignored if
[`get5_print_damage`](#get5_print_damage) is disabled. **`Default: 0`**

####`get5_damageprint_format`
:   Formatting of damage reports in chat on round end. Ignored
if [`get5_print_damage`](#get5_print_damage) is disabled.
**`Default: - [{KILL_TO}] ({DMG_TO} in {HITS_TO}) to [{KILL_FROM}] ({DMG_FROM} in {HITS_FROM}) from {NAME} ({HEALTH} HP)`**

    The default example above prints the following to chat on round end and includes information about assists and flash
    assists.

    `{KILL_TO}` becomes a green `X` for a kill or a yellow `A` or `F` for assist or flash assist, respectively.
    `{KILL_FROM}` is similar to `{KILL_TO}`, but the `X` value is red (indicating a player killed you). No attribution
    becomes a white dash.

```
[Get5] Team A 1 - 0 Team B
- [X] (100 in 3) to [A] (44 in 1) from Player1 (0 HP) # - killed this player, they assisted in killing you
- [F] (0 in 0) to [X] (56 in 2) from Player2 (0 HP)   # - killed by this player, flash assisted in killing them
- [-] (0 in 0) to [-] (0 in 0) from Player3 (84 HP)   # - no interaction, this player survived
- [A] (73 in 2) to [-] (0 in 0) from Player4 (0 HP)   # - assisted in killing this player
- [-] (30 in 1) to [-] (0 in 0) from Player5 (0 HP)   # - dealt damage to this player, not enough for assist
```

####`get5_phase_announcement_count`
:   The number of times the "Knife" or "Match is LIVE" announcements will be printed in chat. Set to zero to disable.
**`Default: 5`**

####`get5_message_prefix`
:   The tag applied before plugin messages. Note that at least one character must come before
a [color modifier](#color-substitutes). **`Default: "[{YELLOW}Get5{NORMAL}]"`**

## Pausing

####`get5_pausing_enabled`
:   Whether [pauses](../pausing) are available to clients or not. **`Default: 1`**

####`get5_max_pauses`
:   Number of [tactical pauses](../pausing/#tactical) a team can use. 0 = unlimited. **`Default: 0`**

####`get5_max_pause_time`
:   Maximum number of seconds the game can spend under tactical pause for a team. 0 = unlimited. When pauses are
unlimited and when [get5_fixed_pause_time](#get5_fixed_pause_time) is zero, both teams
must call [`!unpause`](../commands/#unpause) to continue the match. This parameter is ignored
if [get5_fixed_pause_time](#get5_fixed_pause_time) is set to a non-zero
value. **`Default: 300 (5 minutes)`**

####`get5_fixed_pause_time`
:   If non-zero, the fixed length in seconds of all [`tactical`](../pausing/#tactical) pauses. This takes precedence
over the [get5_max_pause_time](#get5_max_pause_time) parameter, which will be ignored. **`Default: 0`**

####`get5_allow_technical_pause`
:   Whether [technical pauses](../pausing/#technical) are available to clients or not. **`Default: 1`**

####`get5_max_tech_pauses`
:   Number of [technical pauses](../pausing/#technical) a team is allowed to have, 0=unlimited. **`Default: 0`**

####`get5_tech_pause_time`
:   If non-zero, number of seconds before any team can call [`!unpause`](../commands/#unpause) to end
a [technical pause](../pausing/#technical) without confirmation from the pausing team. 0 = unlimited and both teams
must confirm. **`Default: 0`**

####`get5_pause_on_veto`
:   Whether to freeze players during the map-veto phase. **`Default: 0`**

####`get5_reset_pauses_each_half`
:   Whether [tactical pause](../pausing/#tactical) limits (time used and count) are reset each halftime period.
[Technical pauses](../pausing/#technical) are not reset. **`Default: 1`**

## Formats

**Note: for these, setting the cvar to an empty string ("") will disable the file writing entirely.**

####`get5_time_format`
:   Time format string. This determines the [`{TIME}`](#tag-time) tag. **Do not change this unless you know what you are
doing! Avoid using spaces or colons.** **`Default: %Y-%m-%d_%H`**

####`get5_demo_name_format`
:   Format to use for demo files when [recording matches](gotv.md). Do not include a file extension (`.dem` is added
automatically). Set to empty string to disable.<br>Note that the [`{MAPNUMBER}`](#tag-mapnumber) variable is not
zero-indexed!<br>**`Default: {MATCHID}_map{MAPNUMBER}_{MAPNAME}`**

####`get5_event_log_format`
:   Format to write event logs to. Set to empty string to disable. **`Default: ""`**

####`get5_stats_path_format`
:   Path where stats are output at each map end if it is set. Set to empty string to
disable. **`Default: get5_matchstats_{MATCHID}.cfg`**

## Backup System

####`get5_backup_system_enabled`
:   Whether the [backup system](backup.md) is enabled. This is required for the use of the [`!stop`](../commands/#stop)
command as well as the [`get5_loadbackup`](../commands/#get5_loadbackup) command. **`Default: 1`**

####`get5_max_backup_age`
:   Number of seconds before a Get5 backup file is automatically deleted. 0 to disable. If you define
[`get5_backup_path`](#get5_backup_path), only files in that path will be deleted. **`Default: 160000`**

####`get5_backup_path`
:   The folder of saved [backup files](../commands/#get5_loadbackup), relative to the `csgo` directory. You **can** use
the [`{MATCHID}`](#tag-matchid) variable, i.e. `backups/{MATCHID}/`. **`Default: ""`**

!!! warning "Slash, slash, hundred yard dash :material-slash-forward:"

    It is very important that your backup path does **not** start with a slash but instead **ends with a slash**. If
    not, the last part of the path will be considered a prefix of the filename and things will not work correctly. Also
    note that if you use the [`{MATCHID}`](#tag-matchid) variable, [automatic deletion of backups](#get5_max_backup_age)
    does not work.

    :white_check_mark: `backups/`

    :white_check_mark: `backups/{MATCHID}/`

    :no_entry: `/backups/`

    :no_entry: `/backups/{MATCHID}`

## Config Files

####`get5_live_cfg`
:   Config file executed when the game goes live. **`Default: get5/live.cfg`**

####`get5_autoload_config`
:   A config file to autoload on map starts if no match is loaded, relative to the `csgo` directory. Set to empty
string
to disable. **`Default: ""`**

####`get5_warmup_cfg`
:   Config file executed in warmup periods. **`Default: get5/warmup.cfg`**

## Substitution Variables

### Match/State Substitutes {: #state-substitutes }

Various configuration parameters, such as the file format parameters or the `get5_hostname_format` option, take
placeholder strings that will be replaced by meaningful values when printed.

####`{TIME}` {: #tag-time}
:   The current time, determined by [`get5_time_format`](#get5_time_format).

####`{MAPNAME}` {: #tag-mapname}
:   The pretty-printed name of the map, i.e. **Dust II** for `de_dust2`.

####`{MAPNUMBER}` {: #tag-mapnumber}
:   The map number being played. **Note: Not zero-indexed!**

####`{MAXMAPS}` {: #tag-maxmaps}
:   The maximum number of maps in the series, i.e. `3` for a Bo3. **Note: Not zero-indexed!**

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
