get5
===========================

[![Build status](http://ci.splewis.net/job/get5/badge/icon)](http://ci.splewis.net/job/get5/)

Get5 is a standalone [SourceMod](http://www.sourcemod.net/) plugin for CS:GO servers for running matches. It is originally based on [pugsetup](https://github.com/splewis/csgo-pug-setup) and is inspired by [eBot](https://github.com/deStrO/eBot-CSGO).

The core idea behind its use is all match details being fully defined in a single config file. Check out [this example config](configs/get5/example_match.cfg). Its main target use-case is tournaments and leagues (online or LAN). All that is required of the server-admins is to load match config file to the server and the match should run without any more manual actions from the admins. This plugin is not invasive - most of its functionality is built to work within how the CS:GO server normally operates, not replacing its functionality. No, it is not recommended for your new matchmaking service.

It is meant to be relatively easy to use for tournament admins.

Features of this include:
- Locking players to the correct team by their Steam ID
- In-game map veto support from the match's maplist
- Support for multi-map series (Bo1, Bo2, Bo3, Bo5, etc.)
- Warmup and !ready system each team
- Automatic GOTV demo recording
- Advanced backup system built on top of valve's backup system ([see the wiki](https://github.com/splewis/get5/wiki/Match-backups))
- Knifing for sides
- Pausing support
- Coaching support
- Automatically executing match config files
- Automatically setting team names/logos/match text values for spectator/GOTV clients
- Stats collection and optional MySQL result/stats upload ([see the wiki](https://github.com/splewis/get5/wiki/Stats))

#### TODO:

This is still very-much a work in progress. It may have bugs. See the [issues](https://github.com/splewis/get5/issues) section for bugs or things that are yet-to-be-done. Pull requests are welcome.

## Download and Installation

#### Requirements
You must have sourcemod installed on the game server. You can download it at http://www.sourcemod.net/downloads.php. Note that sourcemod also requires MetaMod:Source to be on the server. You can download it at http://www.sourcemm.net/downloads.

#### Download
Download a release package from the [releases section](https://github.com/splewis/get5/releases) or a [the latest development build](http://ci.splewis.net/job/get5/lastSuccessfulBuild/).

Release and development builds are currently compiled against sourcemod 1.7 and should work on sourcemod 1.7 or later.

#### Installation
Extract the download archive into the csgo/ directory on the server. The only required file is actually just the ``get5.smx`` plugin binary in the ``addons/sourcemod/plugins`` directory.

If you need more help, see the [step-by-step guide in the wiki](https://github.com/splewis/get5/wiki/Step-by-step-installation-guide).


## Commands
#### Client Commands
- ``!ready``: marks a client's team as ready to begin
- ``!unready``: marks a client's team as not-ready
- ``!pause``: requests a freezetime pause
- ``!unpause``: requests an unpause, requires the other team to confirm
- ``!coach``: moves a client to coach for their team
- ``!stay``: elects to stay after a knife round win
- ``!swap``: elects to swap after a knife round win
- ``!stop``: asks to reload the last match backup file, requires other team to confirm

#### Server/Admin Commands
- ``get5_loadmatch``: loads a match config file (JSON or keyvalues) relative from the ``csgo`` directory
- ``get5_loadbackup``: loads a get5 backup file
- ``get5_loadteam``: loads a team section from a file into a team
- ``get5_loadmatch_url``: loads a remote (JSON formatted) match config by sending a HTTP GET to the given url, this requires either the [system2](https://forums.alliedmods.net/showthread.php?t=146019) or [Steamworks](https://forums.alliedmods.net/showthread.php?t=229556) Extensions
- ``get5_endmatch``: force ends the current match
- ``get5_creatematch``: creates a Bo1 match with the current players on the server on the current map
- ``get5_scrim``: creates a Bo1 match with the current players on the server on the current map, with all 30-rounds played out and no knife round
- ``get5_addplayer``: adds a steamid to a team (any format for steamid)
- ``get5_removeplayer``: removes a steamid from all teams (any format for steamid)
- ``get5_forceready``: marks all teams as ready
- ``get5_dumpstats``: dumps current match stats to a file
- ``get5_status``: replies with JSON formatted match state (available to all clients, requires [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604))
- ``get5_list_backups``: lists backup files for the current matchid or a given matchid


## Match Schema

See the example config in [Valve KeyValues format](configs/get5/example_match.cfg) or [JSON format](configs/get5/example_match.json) to learn how to format the configs. Both files contain equivalent match data.

**Note:** to use a JSON match file, you must install the [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604) sourcemod extension on the server.

Of the below fields, only the ``team1`` and ``team2`` fields are actually required. Reasonable defaults are used for entires (bo3 series, 5v5, empty strings for team names, etc.)

- ``matchid``: a string matchid used to identify the match
- ``match_title``: wrapper on the ``mp_teammatchstat_txt`` cvar, but can use {MAPNUMBER} and {MAXMAPS} as variables that get replaced with their integer values
- ``maps_to_win``: number of maps needed to win the series (1 in a Bo1, 2 in a Bo3, 3 in a Bo5)
- ``bo2_series``: whether the series is a bo2 series (will ignore ``maps_to_win`` if it is)
- ``maplist``: list of the maps in use (an array of strings in JSON, mapnames as keys for KeyValues), you should always use an odd-sized maplist
- ``skip_veto``: whether the veto will be skipped and the maps will come from the maplist (in the order given)
- ``side_type``: either "standard", "never_knife", or "always_knife"; standard means the team that doesn't pick a map gets the side choice, never_knife means team is always on CT first, and always knife means there is always a knife round
- ``players_per_team``: maximum players per team (doesn't include a coach spot)
- ``favored_percentage_team1``: wrapper for ``mp_teamprediction_pct``
- ``favored_percentage_text`` wrapper for ``mp_teamprediction_txt``
- ``cvars``: cvars to be set during the match warmup/knife round/live state
- ``spectators``: see the team schema below (only the ``players`` section is used for spectators)
- ``team1``: see the team schema below
- ``team2``: see the team schema below

#### Team Schema
- ``name``: team name (wraps ``mp_teamname_1`` and is displayed often in chat messages)
- ``flag``: team flag (2 letter country code, wraps ``mp_teamflag_1``)
- ``logo`` team logo (wraps ``mp_teamlogo_1``)
- ``matchtext``: warps ``mp_teammatchstat_1``
- ``players``: list of Steam id's for users on the team (not used if ``get5_check_auths`` is set to 0)
- ``series_score``: current score in the series, this can be used to give a team a map advantage or used as a manual backup method, defaults to 0

There is advice on handling these match configs in [the wiki](https://github.com/splewis/get5/wiki/Managing-match-configs).

Instead of the above fields, you can also use "fromfile" and a filename, where that file contains the other above fields. This is available for both json and keyvalue format.s

## ConVars
Note: these are auto-executed on plugin start by the auto-generated (the 1st time the plugin starts) file ``cfg/sourcemod/get5.cfg``.

You should either set these in the above file, or in the match config's ``cvars`` section.

- ``get5_auto_dump_stats``: whether match stats keyvalues files are saved to a get5_matchstats_matchid.cfg file (updated each map end)
- ``get5_autoload_config``: a config file to autoload on map starts if no match is loaded
- ``get5_check_auths``: whether the steamids from a "players" section are used to force players onto teams (default 1)
- ``get5_demo_name_format``: format to name demo files in (default ``{MATCHID}_map{MAPNUMBER}_{MAPNAME}``)
- ``get5_kick_when_no_match_loaded``: whether to kick all clients if no match is loaded
- ``get5_last_backup_file``: last match backup file get5 wrote in the current series
- ``get5_live_cfg``: config file executed when the game goes live
- ``get5_max_backup_age``: number of seconds before a get5 backup file is automatically deleted, 0 to disable
- ``get5_pausing_enabled``: whether pausing (!pause command) is enabled
- ``get5_stop_command_enabled``: whether the !stop command is enabled
- ``get5_time_format``: time format string (default ``"%Y-%m-%d_%H``), only affects if a {TIME} tag is used in ``get5_demo_name_format``
- ``get5_wait_for_spec_ready``: whether to wait for spectators (if there are any) to ready up to begin
- ``get5_warmup_cfg``: config file executed in warmup periods
