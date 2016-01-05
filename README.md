get5
===========================

[![Build status](http://ci.splewis.net/job/get5/badge/icon)](http://ci.splewis.net/job/get5/)

Get5 is a [SourceMod](http://www.sourcemod.net/) plugin for CS:GO servers for running matches. It is originally based on [pugsetup](https://github.com/splewis/csgo-pug-setup) and is inspired by [eBot](https://github.com/deStrO/eBot-CSGO).

The core idea behind its use is all match details being fully defined in a single config file. Check out [this example config](configs/get5/example_match.cfg). Its main target use-case is tournaments (online or LAN). All that is required of the server-admins is to load match config file to the server and the match should run without any more manual actions from the admins

Features of this include:
- Locking players to the correct team by their Steam ID
- In-game map veto support from the match's maplist
- Support for multi-map series (Bo1, Bo3, Bo5, etc.)
- Warmup and !ready system each team
- Automatic GOTV demo recording
- Knifing for sides
- Pausing support
- Coaching support

## Commands
#### Client Commands
- !ready
- !unready
- !pause
- !unpause
- !coach
- !stay
- !swap

#### Server Commands
- get5_endmatch
- get5_loadmatch
- get5_status


## Match Schema

See the example config in [keyvalues format](configs/get5/example_match.cfg) or [json format](configs/get5/example_match.json) to learn how to format the configs. Both files contain equivalent match data.

- ``matchid``
- ``maps_to_win``
- ``skip_veto``
- ``players_per_team``
- ``favored_percentage_team1``
- ``favored_percentage_text``
- ``spectators``
- ``team1``
- ``team2``
- ``cvars``

#### Team Schema
- ``name``
- ``flag``
- ``logo``
- ``matchtext``
- ``players``


## ConVars
- get5_autoload_config
- get5_demo_name_format
- get5_time_format
- get5_pausing_enabled
