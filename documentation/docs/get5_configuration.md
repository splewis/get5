# Get5 Configuration

The config file is auto-generated on **first plugin run**, then auto-executed on each plugin start. The file is located
here:

```
cfg/sourcemod/get5.cfg
```

You can either set these in that file, or in the `cvars` section of a match config. As mentioned in
the [match schema](../match_schema#optional-values), that section will override all other
settings. This section will be broken up into various sub-sections which explains each configuration value.

## Server Setup

**These options will generally not be directly presented to clients, but will modify how Get5 interacts on the game
server.**

####`get5_server_id`
:   Integer that identifies your server. This is used in temp files to prevent collisions. **`Default: 0`**

####`get5_kick_immunity`
:   Whether admins with the changemap flag will be immune to kicks from
[get5_kick_when_no_match_loaded](../get5_configuration#get5_kick_when_no_match_loaded). **`Default: 1`**

####`get5_stop_command_enabled`
:   Whether the [`!stop`](../commands/#stop) command is enabled. **`Default: 1`**

####`get5_kick_when_no_match_loaded`
:   Whether to kick all clients if no match is loaded. **`Default: 0`**

####`get5_display_gotv_veto`
:   Whether to wait for map vetoes to be printed to GOTV before changing map. **`Default: 0`**

####`get5_check_auths`
:   Whether the Steam IDs from a "players" section are used to force players onto teams, and will kick
users if they are not in the auth list. **`Default: 1`**

## Match Setup

**These options will generally be represented by changes to the clients.**

####`get5_ready_team_tag`
:   Adds `[READY]` or `[NOT READY]` tags before team names, and removes clan tags from users. **`Default: 1`**

####`get5_live_countdown_time`
:   Number of seconds used to count down when a match is going live. **`Default: 10`**

####`get5_auto_ready_active_players`
:   Whether to automatically mark players as ready if they kill anyone in the warmup or veto phase. **`Default: 0`**

####`get5_set_client_clan_tags`
:   Whether to set client clan tags to player ready status. **`Default: 1`**

####`get5_print_damage`
:   Whether to print damage reports on round ends. **`Default: 0`**

####`get5_print_damage_excess`
:   Whether to discard damage that exceeds the remaining health of a player in the chat
report. If enabled, you can inflict more than 100 damage to a player in the damage report. Ignored if
[get5_print_damage](../get5_configuration#get5_print_damage) is disabled. **`Default: 0`**

####`get5_damageprint_format`
:   Formatting of damage reports in chat on round end. Ignored
if [get5_print_damage](../get5_configuration#get5_print_damage) is disabled.
**`Default: - [{KILL_TO}] ({DMG_TO} in {HITS_TO}) to [{KILL_FROM}] ({DMG_FROM} in {HITS_FROM}) from {NAME} ({HEALTH} HP)`**

    The default example above prints the following to chat on round end and includes information about assists and flash
    assists.

    `{KILL_TO}` becomes a green `X` for a kill or a yellow `A` or `F` for assist or flash assist, respectively.
    `{KILL_FROM}` is similar to `{KILL_TO}`, but the `X` value is red (indicating a player killed you).

```
[Get5] Team A 1 - 0 Team B
- [X] (100 in 3) to [A] (44 in 1) from Player1 (0 HP)  - killed this player, they assisted in killing you
- [F] (0 in 0) to [X] (56 in 2) from Player2 (0 HP)  - killed by this player, flash assisted in killing them
- [-] (0 in 0) to [-] (0 in 0) from Player3 (84 HP)  - no interaction, this player survived
- [A] (73 in 2) to [-] (0 in 0) from Player4 (0 HP)  - assisted in killing this player
- [-] (30 in 1) to [-] (0 in 0) from Player5 (0 HP)  - dealt damage to this player, not enough for assist
```

####`get5_message_prefix`
:   The tag applied before plugin messages. If you change this variable, `Powered by Get5` will be printed when the game
goes live. **`Default: Get5`**

## Pausing

####`get5_max_pauses`
:   Maximum number of tactical pauses a team can use, 0 = unlimited. **`Default: 0`**

####`get5_max_pause_time`
:   Maximum number of seconds the game can spend paused by a team, 0 = unlimited. When pauses are unlimited, both teams
must call [`!unpause`](../commands/#unpause) to continue the match. If this is set to a non-zero value, the
[`!unpause`](../commands/#unpause) does not work for tactical pauses. **`Default: 300 (5 minutes)`**

####`get5_reset_pauses_each_half`
:   Whether pause limits are reset each halftime period. **`Default: 1`**

####`get5_fixed_pause_time`
:   If non-zero, the fixed length in seconds all pauses will be. Adjusting this to non-zero will use
the in-game timeout counter, and the [`!unpause`](../commands/#unpause) command cannot be used. **`Default: 0`**

####`get5_pausing_enabled`
:   Whether the [`!pause`](../commands/#pause) command is available to clients or not. **`Default: 1`**

####`get5_allow_technical_pause`
:   Whether the [`!tech`](../commands/#tech) command is available to clients or not. **`Default: 1`**

####`get5_max_tech_pauses`
:   Number of [`technical pauses`](../commands/#tech) a team is allowed to have, 0=unlimited. **`Default: 0`**

####`get5_tech_pause_time`
:   If non-zero, number of seconds before any team can call [`!unpause`](../commands/#unpause) without confirmation.
0 = unlimited and both teams must confirm. **`Default: 0`**

####`get5_pause_on_veto`
:   Whether to freeze players during the map-veto phase. **`Default: 0`**

## File Name Formatting

**Note: for these, setting the cvar to an empty string ("") will disable the file writing entirely.**

####`get5_time_format`
:   Time format string. This determines the `{TIME}` tag. **`Default: %Y-%m-%d_%H`**

####`get5_demo_name_format`
:   Format to name demo files. Set to empty string to disable. **`Default: {MATCHID}_map{MAPNUMBER}_{MAPNAME}`**

####`get5_event_log_format`
:   Format to write event logs to. Set to empty string to disable. **`Default: ""`**

####`get5_stats_path_format`
:   Path where stats are output at each map end if it is set. Set to empty string to
disable. **`Default: get5_matchstats_{MATCHID}.cfg`**

## Match Management Timers

####`get5_time_to_start`
:   Time (in seconds) teams have to ready up before forfeiting the match, 0 = unlimited. **`Default: 0`**

####`get5_time_to_make_knife_decision`
:   Time (in seconds) a team has to make a !stay/!swap decision after winning knife round, 0 =
unlimited. **`Default: 60`**

####`get5_veto_countdown`
:   Time (in seconds) to countdown before veto process commences. **`Default: 5`**

####`get5_end_match_on_empty_server`
:   Whether the match is ended with no winner if all players leave (note: this will happen even if all players
disconnect
even in warmup with the intention to reconnect!). **`Default: 0`**

####`get5_veto_confirmation_time`
:   Time (in seconds) from presenting a veto menu to a selection being made, during which a confirmation will be
required. 0 to disable. **`Default: 2.0`**

## Backup System

####`get5_backup_system_enabled`
:   Whether the Get5 backup system is enabled. This is required for the use of the [`!stop`](../commands/#stop) command
as well as the [`get5_loadbackup`](../commands/#get5_loadbackup-filename) command. **`Default: 1`**

####`get5_last_backup_file`
:   Last match backup file Get5 wrote in the current series, this is automatically updated by Get5 each time a backup
file is written. **`Default: ""`**

####`get5_max_backup_age`
:   Number of seconds before a Get5 backup file is automatically deleted. 0 to disable. **`Default: 160000`**

## Config Files

####`get5_live_cfg`
:   Config file executed when the game goes live. **`Default: get5/live.cfg`**

####`get5_autoload_config`
:   A config file to autoload on map starts if no match is loaded, relative to the `csgo/` directory. Set to empty
string
to disable. **`Default: ""`**

####`get5_warmup_cfg`
:   Config file executed in warmup periods. **`Default: get5/warmup.cfg`**

## Substitution Variables

### Match/State Substitutes

Valid substitutions into the above file name formatting cvars:

- `{TIME}`
- `{MAPNAME}`
- `{MAPNUMBER}`
- `{MATCHID}`
- `{TEAM1}`
- `{TEAM2}`
- `{MATCHTITLE}`

### Chat Colour Substitutes

This project also includes substitution variables for colour in chat text.

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
