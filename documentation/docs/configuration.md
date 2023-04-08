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

!!! warning "512 and no more"

    Note that the maximum length of any config parameter is *less than* 512 characters. Depending on where these
    parameters are set, being close to this limit may cause problems. This applies to things like URLs or HTTP headers,
    so beware of long strings in these cases.

### Configuration Files

#### Game Phases

You should also have four config files. These can be edited, but we recommend not
blindly pasting another config in (e.g. ESL, CEVO). These must only include commands you would run in the console (such
as `mp_friendlyfire 1`) and should determine the rules for those three stage of your match. You can
also [point to other files](#config-files) by editing the main config file.

```yaml
cfg/get5/warmup.cfg # (1)
cfg/get5/knife.cfg # (2)
cfg/get5/live.cfg # (3)
cfg/get5/live_wingman.cfg # (4)
```

1. Executed when the warmup or map selection phase begins.
2. Executed when the knife-round starts.
3. Executed when the game goes live during competitive matches.
4. Executed when the game goes live during wingman matches.

!!! danger "Prohibited options"

    You should avoid these commands in your live, knife and warmup configuration files, as most of these are handled by
    Get5 automatically or not suitable for changes based on game phases. Introducing restarts, warmup changes or
    [GOTV](../gotv) delay modifications can cause problems. If you want to set your `tv_delay` or `tv_delay1`, do it in
    the `cvars` section of your [match configuration](../match_schema). You should also not manually configure any
    parameters related to pausing or teams (names, flags etc.), as all of these are set by Get5 based on the contents of
    you match configuration.

    ```
    // You should *never* change any of these yourself:
    mp_do_warmup_period
    mp_restartgame
    mp_warmup_end
    mp_warmup_pausetimer
    mp_warmup_start
    mp_warmuptime
    mp_warmuptime_all_players_connected
    mp_endwarmup_player_count
    mp_team_timeout_max
    mp_team_timeout_time
    mp_teamscore_max
    mp_teammatchstat_txt
    mp_teamprediction_txt
    mp_teamprediction_pct
    mp_teamname_1/2
    mp_teamflag_1/2
    mp_teamlogo_1/2
    mp_teammatchstat_1/2
    mp_teamscore_1/2
    tv_delaymapchange

    // You can change these (or any other GOTV parameters),
    // but don't use live/knife/warmup.cfg to do it:
    tv_delay
    tv_delay1
    tv_enable
    tv_enable1
    tv_snapshotrate
    tv_snapshotrate1
    ```

#### Chat Commands File {: #chat-commands-file }

```yaml
addons/sourcemod/configs/get5/commands.cfg
```

Contains custom Get5 [chat commands](../commands#custom-chat-commands) in KeyValues format. The location of this file
cannot be configured.

#### Teams File {: #teams-file }

```yaml
cfg/get5/teams.json
```

The teams file is used to set teams from the [`!get5`](../commands#get5) menu or as arguments to `--team1` or `--team2`
when using [`get5_creatematch`](../commands#get5_creatematch). Any property defined in
the [Get5MatchTeam](../match_schema#schema) schema (except `fromfile`) can be used in this file, but only `players` is
required. If you don't set a team `name`, the team's key is used in the menu. The default, empty teams file is generated
if the file does not exist. This prevents accidental overwrites when updating the plugin.

You can set the location of the teams file with [`get5_teams_file`](#get5_teams_file).

!!! example "Teams file example"

    This file would allow you to run:

    ```sh
    get5_creatematch --team1 "navi" --team2 "astralis"
    ```

    or

    ```sh
    get5_creatematch --team1 "navi" --scrim "OtherTeamName"
    ```

    ```json
    {
       "navi": {
          "name": "Natus Vincere",
          "tag": "NaVi",
          "flag": "UA",
          "logo": "navi",
          "players": {
             "76561198034202275": "s1mple",
             "76561198044045107": "electronic",
             "76561198246607476": "b1t",
             "76561198121220486": "Perfecto",
             "76561198040577200": "sdy"
          },
          "coaches": {
             "76561198013523865": "B1ad3"
          }
       },
       "astralis": {
          "name": "Astralis",
          "tag": "Astralis",
          "flag": "DK",
          "logo": "astr",
          "players": {
             "76561197990682262": "Xyp9x",
             "76561198010511021": "gla1ve",
             "76561197979669175": "K0nfig",
             "76561198028458803": "BlameF",
             "76561198024248129": "farlig"
          },
          "coaches": {
             "76561197987144812": "Trace"
          }
       }
    }
    ```

#### Maps File {: #maps-file }

```yaml
cfg/get5/maps.json
```

You can configure sets of map pools to use. The default file covers the competitive map pool, an extended pool and some
[Wingman](../wingman) maps. You can add as many sets of map pools as you want. Each key of your pool can be selected
in the [`!get5`](../commands#get5) menu or passed to `--map_pool` when using
the [`get5_creatematch`](../commands#get5_creatematch) command. You can add workshop maps to this file as well, i.e.
`"workshop/1193875520/de_aztec"`.

You can set the location of the maps file with [`get5_maps_file`](#get5_maps_file). The default map file (example below)
is generated if the file does not exist. This prevents accidental overwrites when updating the plugin.

!!! example "Maps file example"

    This file would allow you to run:

    ```sh
    get5_creatematch --map_pool "extended"
    ```

    ```json
    {
       "default": [
          "de_ancient",
          "de_anubis",
          "de_inferno",
          "de_mirage",
          "de_nuke",
          "de_overpass",
          "de_vertigo"
       ],
       "extended": [
          "de_ancient",
          "de_anubis",
          "de_cache",
          "de_dust2",
          "de_inferno",
          "de_mirage",
          "de_nuke",
          "de_overpass",
          "de_train",
          "de_vertigo"
       ],
       "wingman": [
          "de_shortdust",
          "de_boyard",
          "de_chalice",
          "de_cbble",
          "de_inferno",
          "de_lake",
          "de_overpass",
          "de_shortnuke",
          "de_train",
          "de_vertigo"
       ]
    }
    ```

#### Cvars File {: #cvars-file }

```yaml
cfg/get5/cvars.json
```

You can configure sets of configuration parameters (`cvars`) to use. The default file contains only `default`, which is
automatically used in the [`!get5`](../commands#get5) menu and as the default `--cvars` parameter when
using [`get5_creatematch`](../commands#get5_creatematch). Anything you put in the `default` key is automatically loaded
unless you provide a different `--cvars` parameter.

You can set the location of the cvars file with [`get5_cvars_file`](#get5_cvars_file). The default cvars file is
generated if the file does not exist. This prevents accidental overwrites when updating the plugin.

!!! example "Cvars file example"

    This file would allow you to run:

    ```sh
    get5_creatematch --cvars "no_ff_casual"
    ```

    ```json
    {
       "default": {},
       "no_ff_casual": {
          "mp_friendlyfire": 0,
          "sv_damage_print_enable": 1
       }
    }
    ```

!!! warning "`default` is required!"

    Do not remove the `default` key. If you don't want to apply any extra `cvars` when loading matches from the `!get5`
    menu or when using `get5_creatematch`, you should simply leave this object empty (`{}`).

## Server Setup

####`get5_server_id`
:   A string that identifies your server. This is used in temporary and backup files to prevent collisions and added as
a header to [demo](../gotv#upload) and [backup](../backup#upload) uploads
and [event requests](../events_and_forwards#http). You should set this if you run multiple servers off the same storage,
such as if using [Docker](https://www.docker.com/), or if simply want to be able to tell servers apart. This also
defines the [`{SERVERID}`](#tag-serverid) substitution and the return value of the `Get5_GetServerID` native.
**Maximum length is 64 characters**.<br>**`Default: "0"`**

!!! bug "Alphanumeric only and no spaces"

    If you set a custom server ID, **do not** use spaces, slashes or any other odd symbols. The value is used in various
    commands and filenames, so it **will** cause problems if it contains unexpected symbols.

!!! tip "Server ID could be port number"

    A good candidate for `get5_server_id` would be the port number the server is bound to, since it uniquely identifies
    a server instance on a host and ensures that no two instances run with the same server ID at the same time. You
    should also **not** put this parameter in your [match configuration](../match_schema#schema) `cvars`, as those
    parameters will be written to [backup](../backup) files, which would mean that loading a backup created on another
    server would change the server ID.

####`get5_kick_immunity`
:   Whether [admins](../installation#administrators) will be immune to kicks from
[`get5_kick_when_no_match_loaded`](#get5_kick_when_no_match_loaded).<br>**`Default: 1`**

####`get5_kick_when_no_match_loaded`
:   Whether to kick all clients and prevent anyone from joining the server if no match is loaded. This can
be [suppressed for administrators](#get5_kick_immunity).<br>**`Default: 0`**

####`get5_kick_on_force_end`
:   Whether players are kicked from the server when a match is [forcefully ended](../commands#get5_endmatch). This only
applies if players are [kicked when no match is loaded](#get5_kick_when_no_match_loaded).<br>**`Default: 0`**

####`get5_check_auths`
:   Whether the Steam IDs from the `players`, `coaches` and `spectators` sections of
a [match configuration](../match_schema#schema) are used to force players onto teams. Anyone not defined will be
removed from the game, or if in [scrim mode](../getting_started#scrims), put on `team2`.<br>**`Default: 1`**

####`get5_print_update_notice`
:   Whether to print to chat when the game goes live if a new version of Get5 is available. This only works if
[SteamWorks](../installation#steamworks) has been installed.<br>**`Default: 1`**

####`get5_pretty_print_json`
:   Whether to pretty-print all JSON output. This also affects the output of JSON in the
[event system](../events_and_forwards).<br>**`Default: 1`**

####`get5_autoload_config`
:  A [match configuration](../match_schema#schema) file, relative to the `csgo` directory, to autoload when the server
starts, when Get5 is reloaded or if no match is loaded when a player joins the server. Set to empty string to
disable.<br>**`Default: ""`**

####`get5_reset_cvars_on_end`
:  Whether the `cvars` of a [match configuration](../match_schema#schema) as well as
the [Get5-determined hostname](#get5_hostname_format) are reset to their original values when a series ends. This also
causes team-specific configuration options (name, flag, logo etc.) to be set to empty on match end. You may want to
disable this if you only run Get5 on your servers and use `cvars` to configure [demos](../gotv), [backups](../backup)
or [remote URL logging](../events_and_forwards#http) on a per-match basis, as reverting some of those parameters can be
problematic.<br>**`Default: 1`**

####`get5_debug`
:   Enable or disable verbose debug output from Get5. Intended for development and debugging purposes
only.<br>**`Default: 0`**

## Match Setup

####`get5_ready_team_tag`
:   Adds `[READY]` or `[NOT READY]` tags to team names.<br>**`Default: 1`**

####`get5_live_countdown_time`
:   Number of seconds used to count down when a match is going live.<br>**`Default: 10`**

####`get5_auto_ready_active_players`
:   Whether to automatically mark players as ready if they kill anyone in the warmup or [map selection](../veto)
phase.<br>**`Default: 0`**

####`get5_allow_force_ready`
:   Whether the [`!forceready`](../commands#forceready) command is accessible to players. This does not
affect the availability of [`get5_forceready`](../commands#get5_forceready) to admins.<br>**`Default: 1`**

####`get5_set_client_clan_tags`
:   Whether to set client clan tags to player ready status.<br>**`Default: 1`**

####`get5_time_to_start`
:   Time (in seconds) teams have to ready up for knife/live before forfeiting the match. Set to zero for no limit. If
neither team becomes ready in time, the series is ended in a tie.
Note that the [time to ready for map selection](../configuration#get5_time_to_start_veto) is set separately to allow for
shorter ready-up-periods in multi-map series.<br>**`Default: 0`**

####`get5_time_to_make_knife_decision`
:   Time (in seconds) a team has to make a [`!stay`](../commands#stay) or [`!swap`](../commands#swap)
decision after winning knife round. Cannot be set lower than 10 if non-zero. Set to zero to remove
limit.<br>**`Default: 60`**

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

## Map Selection {: #map-selection }

####`get5_display_gotv_veto`
:   Whether to wait for [map selection](../veto) to be broadcast to [GOTV](../gotv) before changing
map.<br>**`Default: 0`**

####`get5_mute_allchat_during_map_selection`
:   Suppresses all chat messages not sent in the team-channel for everyone but the team captains
during [map selection](../veto).<br>**`Default: 1`**

####`get5_pause_on_veto`
:   Whether to freeze players during the [map selection](../veto) phase.<br>**`Default: 1`**

####`get5_time_to_start_veto`
:   Time (in seconds) teams have to ready up for [map selection](../veto) before forfeiting the match. Set to zero for
no limit. If neither team becomes ready in time, the series is ended in a tie.<br>**`Default: 0`**

####`get5_veto_countdown`
:   Time (in seconds) to countdown before the [map selection](../veto) process commences. Set to zero to move to veto
without a countdown.<br>**`Default: 5`**

## Pausing

####`get5_pausing_enabled`
:   Whether [tactical pauses](../pausing) are available to clients or not.<br>**`Default: 1`**

####`get5_max_pauses`
:   Number of [tactical pauses](../pausing#tactical) a team can use. Set to zero to remove limit.<br>**`Default: 0`**

####`get5_max_pause_time`
:   Maximum number of seconds the game can spend under tactical pause for a team. When pauses are
unlimited and when [`get5_fixed_pause_time`](#get5_fixed_pause_time) is zero, both teams
must call [`!unpause`](../commands#unpause) to continue the match. This parameter is ignored
if [`get5_fixed_pause_time`](#get5_fixed_pause_time) is set to a non-zero
value. Set to zero to remove limit.<br>**`Default: 0`**

####`get5_fixed_pause_time`
:   If non-zero, the fixed length in seconds of all [tactical pauses](../pausing#tactical). This takes precedence over
the [`get5_max_pause_time`](#get5_max_pause_time) parameter, which will be ignored. Cannot be set lower than 15
seconds if non-zero.<br>**`Default: 60`**

####`get5_allow_unpausing_fixed_pauses`
:   Whether fixed-duration [tactical pauses](../pausing#tactical) can be stopped early if both teams choose
to [`!unpause`](../commands#unpause).<br>**`Default: 1`**

####`get5_allow_technical_pause`
:   Whether [technical pauses](../pausing#technical) are available to clients or not.<br>**`Default: 1`**

####`get5_allow_pause_cancellation`
:   Whether a pending pause can be canceled by the pausing team using [`!unpause`](../commands#unpause) before
freezetime begins.<br>**`Default: 1`**

####`get5_max_tech_pauses`
:   Number of [technical pauses](../pausing#technical) a team is allowed to have. Set to zero to remove
limit.<br>**`Default: 0`**

####`get5_tech_pause_time`
:   If non-zero, number of seconds before any team can call [`!unpause`](../commands#unpause) to end
a [technical pause](../pausing#technical) without confirmation from the pausing team. Set to zero to remove
limit.<br>**`Default: 0`**

####`get5_auto_tech_pause_missing_players`
:   The number of players that must disconnect from a team during the live phase of a game in order to trigger an
automatic [technical pause](../pausing#technical). [`players_per_team`](../match_schema#schema) is used to determine
what is considered a full team, so if these parameters are equal (typically 5), a pause is triggered if an entire team
leaves. Set to zero to disable.<br>**`Default: 0`**

!!! question "If I just want to pause if a team is empty?"

    If you always want the pause to trigger if an entire team disconnects, regardless of team size, you can
    set [`get5_auto_tech_pause_missing_players`](#get5_auto_tech_pause_missing_players) to a large value, as setting it
    to a value larger than [`players_per_team`](../match_schema#schema) behaves as if it was set to that value.

!!! warning "Auto-pausing is always enabled"

    If you set [`get5_auto_tech_pause_missing_players`](#get5_auto_tech_pause_missing_players) to a non-zero value, a
    technical pause will be started regardless of the configuration of [`get5_pausing_enabled`](#get5_pausing_enabled)
    or [`get5_allow_technical_pause`](#get5_allow_technical_pause). This allows you to automatically enable technical
    pauses without letting players initiate them on their own.

    Automatic tech pauses are still limited by [`get5_max_tech_pauses`](#get5_max_tech_pauses), so you can set that to a
    non-zero value to prevent abuse.

####`get5_reset_pauses_each_half`
:   Whether [tactical pause](../pausing#tactical) limits (time used and count) are reset each halftime period.
[Technical pauses](../pausing#technical) are not reset.<br>**`Default: 1`**

## Surrender & Forfeit

####`get5_surrender_enabled`
:   Whether the [`!surrender`](../commands#surrender) command is available.<br>**`Default: 0`**

####`get5_surrender_minimum_round_deficit`
:   The minimum number of rounds a team must be behind in order to initiate a vote
to [surrender](../surrender-forfeit#surrender). This cannot be set lower than `1`.<br>**`Default: 8`**

####`get5_surrender_required_votes`
:   The number of votes required to [surrender](../surrender-forfeit#surrender) as a team. If set to `1` or below, any
attempt to surrender will immediately succeed. This value is practically limited to the value
of [`players_per_team`](../match_schema#schema).<br>**`Default: 3`**

####`get5_surrender_time_limit`
:   The number of seconds a team has to vote to [surrender](../surrender-forfeit#surrender) after the first vote is
cast. This cannot be set lower than `10`.<br>**`Default: 15`**

####`get5_surrender_cooldown`
:   The minimum number of seconds a team must wait before they can initiate
a [surrender](../surrender-forfeit#surrender) vote following a failed vote. Set to zero to disable.<br>**`Default: 60`**

####`get5_forfeit_enabled`
:   Whether the [`!ffw`](../commands#ffw) command is available if one team leaves and whether
an [automatic forfeit](../surrender-forfeit#forfeit) is triggered if both teams leave.<br>**`Default: 1`**

####`get5_forfeit_countdown`
:   Sets the number of seconds players have to rejoin the server once a [forfeit](../surrender-forfeit#forfeit) timer
has started. This value cannot be set lower than 30.<br>**`Default: 180`**

## Backup System

####`get5_backup_system_enabled`
:   Whether the [backup system](../backup) is enabled. This is required for the use of the [`!stop`](../commands#stop)
command as well as the [`get5_loadbackup`](../commands#get5_loadbackup) command.<br>**`Default: 1`**

####`get5_stop_command_enabled`
:   Whether the [`!stop`](../commands#stop) command is enabled.<br>**`Default: 1`**

####`get5_stop_command_no_damage`
:   Whether the [`!stop`](../commands#stop) command becomes unavailable after a player takes damage during a round. Only
damage from one team to another counts (no friendly fire, no fall damage etc.). The command may still be used by admins
via console at any time (`sm_stop`).<br>**`Default: 0`**

####`get5_stop_command_time_limit`
:   The number of seconds into a round after which the [`!stop`](../commands#stop) command can no longer be used. The
command may still be used by admins via console at any time (`sm_stop`). Set to zero to remove the
limit.<br>**`Default: 0`**

####`get5_max_backup_age`
:   Number of seconds before a Get5 backup file is automatically deleted. If you define
[`get5_backup_path`](#get5_backup_path), only files in that path will be deleted. Set to zero to
disable.<br>**`Default: 160000`**

####`get5_backup_path`
:   The folder of saved [backup files](../commands#get5_loadbackup), relative to the `csgo` directory. You **can** use
the [`{MATCHID}`](#tag-matchid) variable, i.e. `backups/{MATCHID}/`. Required folders will be created if they do not
exist.<br>**`Default: ""`**

!!! warning "Slash, slash, hundred-yard dash :material-slash-forward:"

    It is very important that your backup path does **not** start with a slash but instead **ends with a slash**. If
    not, the last part of the path will be considered a prefix of the filename and things will not work correctly. Also
    note that if you use the [`{MATCHID}`](#tag-matchid) variable, [automatic deletion of backups](#get5_max_backup_age)
    does not work.

    :white_check_mark: `backups/`

    :white_check_mark: `backups/{MATCHID}/`

    :no_entry: `/backups/`

    :no_entry: `/backups/{MATCHID}`

####`get5_remote_backup_url`
:   If defined, Get5 will [automatically send backups](../backup#upload) to this URL in an HTTP `POST` request. If no
protocol is provided, `http://` will be prepended to this value. Requires the
[SteamWorks](../installation#steamworks) extension.<br>**`Default: ""`**

####`get5_remote_backup_header_key`
:   If this **and** [`get5_remote_backup_header_value`](#get5_remote_backup_header_value) are defined, this header name
and value will be used for your [backup upload HTTP request](#get5_remote_backup_url).<br>**`Default: "Authorization"`**

####`get5_remote_backup_header_value`
:   If this **and** [`get5_remote_backup_header_key`](#get5_remote_backup_header_key) are defined, this header name and
value will be used for your [backup upload HTTP request](#get5_remote_backup_url).<br>**`Default: ""`**

## Formats & Paths

####`get5_format_map_names`
:   Whether to format known map names in chat and menus, i.e. `de_mirage` becomes `Mirage`.<br>**`Default: 1`**

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
:   The hostname to apply to the server. [State substitutes](#state-substitutes) can be used.
If [`get5_reset_cvars_on_end`](#get5_reset_cvars_on_end) is enabled, the hostname will be reverted to its original value
when the series ends. The hostname is updated on every round start to allow for the use of team score substitutes. Set
to an empty string to disable changing the hostname.<br>**`Default: "Get5: {TEAM1} vs {TEAM2}"`**

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

## Config File Locations {: #config-files }

####`get5_live_cfg`
:   Config file executed when the game goes live, relative to `csgo/cfg`.<br>**`Default: "get5/live.cfg"`**

####`get5_live_wingman_cfg`
:   Config file executed when the game goes live, relative to `csgo/cfg`, but for [wingman](../wingman)
mode.<br>**`Default: "get5/live_wingman.cfg"`**

####`get5_warmup_cfg`
:   Config file executed in warmup periods, relative to `csgo/cfg`.<br>**`Default: "get5/warmup.cfg"`**

####`get5_knife_cfg`
:   Config file executed for the knife round, relative to `csgo/cfg`.<br>**`Default: "get5/knife.cfg"`**

####`get5_teams_file`
:   Location of the JSON [teams file](#teams-file). Relative
to `csgo/cfg`.<br>**`Default: "get5/teams.json"`**

####`get5_maps_file`
:   Location of the JSON [maps file](#maps-file). Relative
to `csgo/cfg`.<br>**`Default: "get5/maps.json"`**

####`get5_cvars_file`
:   Location of the JSON [cvars file](#Cvars-file). Relative
to `csgo/cfg`.<br>**`Default: "get5/cvars.json"`**

## Demos

####`get5_demo_upload_url`
:   If defined, Get5 will [automatically send a recorded demo](../gotv#upload) to this URL in an HTTP `POST` request
once a recording stops. If no protocol is provided, `http://` will be prepended to this value. Requires the
[SteamWorks](../installation#steamworks) extension.<br>**`Default: ""`**

####`get5_demo_upload_header_key`
:   If this **and** [`get5_demo_upload_header_value`](#get5_demo_upload_header_value) are defined, this header name and
value will be used for your [demo upload HTTP request](#get5_demo_upload_url).<br>**`Default: "Authorization"`**

####`get5_demo_upload_header_value`
:   If this **and** [`get5_demo_upload_header_key`](#get5_demo_upload_header_key) are defined, this header name and
value will be used for your [demo upload HTTP request](#get5_demo_upload_url).<br>**`Default: ""`**

####`get5_demo_delete_after_upload`
:   Whether to delete the demo file from the game server after
successfully [uploading it to a web server](../gotv#upload).<br>**`Default: 0`**

####`get5_demo_path`
:   The folder of saved [demo files](../gotv#demos), relative to the `csgo` directory. You **can** use
the [`{MATCHID}`](#tag-matchid) and [`{DATE}`](#tag-date) variables, i.e. `demos/{DATE}/{MATCHID}/`.
Much like [`get5_backup_path`](#get5_backup_path), the path must **not** start with a slash, and
must **end with a slash**. Required folders will be created if they do not exist.<br>**`Default: ""`**

####`get5_demo_name_format`
:   Format to use for demo files when [recording matches](../gotv#demos). Do not include a file extension (`.dem` is
added automatically). If you do not include the [`{TIME}`](#tag-time) tag, you will have problems with duplicate files
if restoring a game from a backup. Note that the [`{MAPNUMBER}`](#tag-mapnumber) variable is not zero-indexed. Set to
empty string to disable recording demos.<br>**`Default: "{TIME}_{MATCHID}_map{MAPNUMBER}_{MAPNAME}"`**

!!! info "Team score is always zero"

    While it may be tempting to use the [`{TEAM1_SCORE}`](#tag-team1-score) and [`{TEAM2_SCORE}`](#tag-team2-score)
    variables in the demo name; note that this file is created as the match begins, so the score will always be zero at
    that stage.

## Events

####`get5_remote_log_url`
:   The URL to send all [events](../events_and_forwards#http) to. Requires the [SteamWorks](../installation#steamworks)
extension. Set to empty string to disable.<br>**`Default: ""`**

####`get5_remote_log_header_key`
:   If this **and** [`get5_remote_log_header_value`](#get5_remote_log_header_value) are defined, this
header name and value will be used for your [event HTTP requests](../events_and_forwards#http).<br>*
*`Default: "Authorization"`**

####`get5_remote_log_header_value`
:   If this **and** [`get5_remote_log_header_key`](#get5_remote_log_header_key) are defined, this header
name and value will be used for your [event HTTP requests](../events_and_forwards#http).<br>**`Default: ""`**

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

####`{TEAM1_SCORE}` {: #tag-team1-score }
:   The score of `team1` on the current map.

####`{TEAM2_SCORE}` {: #tag-team2-score }
:   The score of `team2` on the current map.

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
