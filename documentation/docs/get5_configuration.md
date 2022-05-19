# Get5 Configuration
This config is auto-generated on first plugin run, then auto-executed on each plugin start. The file is located at `cfg/sourcemod/get5.cfg`. You can either set these in the aforementioned file, or in the `cvars` section of a match config. As mentioned in the [match schema](../match_schema#optional-values), that section will override all other settings. This section will be broken up into various sub-sections which explains each configuration value.

## Pausing
- `get5_max_pauses`: Maximum number of pauses a team can use, 0=unlimited.
- `get5_max_pause_time`: Maximum number of time the game can spend paused by a team, 0=unlimited.
- `get5_reset_pauses_each_half`: Whether pause limits are reset each halftime period (default 1).
- `get5_fixed_pause_time`: If non-zero, the fixed length all pauses will be. Adjusting this to non-zero this will use the in-game timeout counter.
- `get5_pausing_enabled`: Whether the `!pause` command is enabled to clients or not.
- `get5_allow_technical_pause`: Whether technical pauses (`!tech` command) are enabled (default 1).
- `get5_max_tech_pauses`: Number of technical pauses a team is allowed to have, 0=unlimited.
- `get5_tech_pause_time`: If non-zero, number of seconds before any team can call unpause without confirmation. 0=unlimited and both teams must confirm.
- `get5_pause_on_veto`: Pauses/Freezes players during the veto phase.

## File Name Formatting
*Note: for these, setting the cvar to an empty string ("") will disable the file writing entirely.*

- `get5_time_format`: Time format string (default `%Y-%m-%d_%H`), only affects if a {TIME} tag is used in other file-name formatting cvars.
- `get5_demo_name_format`: Format to name demo files in (default `{MATCHID}_map{MAPNUMBER}_{MAPNAME}`).
- `get5_event_log_format`: Format to write get5 event logs to (default `logs/get5_match{MATCHID}.log`).
- `get5_stats_path_format`: Path where stats are output at each map end if it is set. Default `get5_matchstats_{MATCHID}.cfg`

### Substitution Variables
Valid substitutions into the above file name formatting cvars (when surrounded by {}):

- `TIME`
- `MAPNAME`
- `MAPNUMBER`
- `MATCHID`
- `TEAM1`
- `TEAM2`
- `MATCHTITLE`

## Match Management Timers
- `get5_time_to_start`: Time (in seconds) teams have to ready up before forfeiting the match, 0=unlimited.
- `get5_time_to_make_knife_decision`: Time (in seconds) a team has to make a !stay/!swap decision after winning knife round, 0=unlimited.
- `get5_veto_countdown`: Time (in seconds) to countdown before veto process commences, default 5 seconds.
- `get5_end_match_on_empty_server`: Whether the match is ended with no winner if all players leave (note: this will happen even if all players disconnect even in warmup with the intention to reconnect!).
- `get5_veto_confirmation_time`: Time (in seconds) from presenting a veto menu to a selection being made, during which a confirmation will be required, 0 to disable, default 2.0 seconds.

## Backup System
- `get5_backup_system_enabled`: Whether the get5 backup system is enabled, default is 1.
- `get5_last_backup_file`: Last match backup file get5 wrote in the current series, this is automatically updated by get5 each time a backup file is written.
- `get5_max_backup_age`: Number of seconds before a get5 backup file is automatically deleted, 0 to disable, default is 160000 seconds.

## Miscellaneous
### Configs
- `get5_live_cfg`: Config file executed when the game goes live, default is `get5/live.cfg`.
- `get5_autoload_config`: A config file to autoload on map starts if no match is loaded, directory is relative to the `csgo/` directory.
- `get5_warmup_cfg`: Config file executed in warmup periods, default is `get5/warmup.cfg`.

### Server Setup
*These options will generally not be directly presented to clients, but will modify how Get5 interacts on the game server.*

- `get5_server_id`: Integer that identifies your server. This is used in temp files to prevent collisions. Default is 0.
- `get5_kick_immunity`: Whether or not admins with the changemap flag will be immune to kicks from `get5_kick_when_no_match_loaded`. Set to 0 to disable, default is 1.
- `get5_stop_command_enabled`: Whether the `!stop` command is enabled, default is 1.
- `get5_kick_when_no_match_loaded`: Whether to kick all clients if no match is loaded. Default 0.
- `get5_display_gotv_veto`: Whether to wait for map vetos to be printed to GOTV before changing map, default is 0.
- `get5_check_auths`: Whether the steamids from a "players" section are used to force players onto teams, and will kick users if they are not in the auth list (default 1).

### Match Setup
*These options will generally be represented by changes to the clients.*

- `get5_ready_team_tag`: Adds `[READY] [NOT READY]` Tags before Team Names, and removes clan tags from users. 0 to disable it, default is 1.
- `get5_live_countdown_time`: Number of seconds used to count down when a match is going live, default 10 seconds.
- `get5_auto_ready_active_players`: Whether to automatically mark players as ready if they kill anyone in the warmup or veto phase. Default is 0.
- `get5_set_client_clan_tags`: Whether to set client clan tags to player ready status. Default is 1.
- `get5_print_damage`: Whether to print damage reports on round ends, default is 0.
- `get5_damageprint_format`: Formatting of damage reports in the text chat. defaults to `- [{KILL_TO}] ({DMG_TO} in {HITS_TO}) to [{KILL_FROM}] ({DMG_FROM} in {HITS_FROM}) from {NAME} ({HEALTH} HP)`.
- `get5_message_prefix`: The tag applied before plugin messages, default is `Get5`.
