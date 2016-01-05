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
- Automatically executing match config files
- Automatically setting team names/logos/match text values for spectator/GOTV clients

## Download and Installation

#### Requirements
You must have sourcemod installed on the game server. You can download it at http://www.sourcemod.net/downloads.php. Note that sourcemod also requires MetaMod:Source to be on the server. You can download it at http://www.sourcemm.net/downloads.

#### Download
Download a release package from the [releases section](https://github.com/splewis/get5/releases) or a [the latest development build](http://ci.splewis.net/job/get5/lastSuccessfulBuild/).

#### Installation
Extract the download archive into the csgo/ directory on the server. The only required file is actually just the ``get5.smx`` plugin binary in the ``addons/sourcemod/plugins`` directory. The example configs and plugin source code do not have to be uploaded.


## Commands
#### Client Commands
- ``!ready``
- ``!unready``
- ``!pause``
- ``!unpause``
- ``!coach``
- ``!stay``
- ``!swap``

#### Server Commands
- ``get5_endmatch``
- ``get5_loadmatch``
- ``get5_status``


## Match Schema

See the example config in [keyvalues format](configs/get5/example_match.cfg) or [json format](configs/get5/example_match.json) to learn how to format the configs. Both files contain equivalent match data.

**Note:** to use a JSON match file, you must install the [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604) sourcemod extension on the server.

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
- ``get5_autoload_config``
- ``get5_demo_name_format``
- ``get5_time_format``
- ``get5_pausing_enabled``
