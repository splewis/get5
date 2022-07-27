get5
===========================

[![Build Status](https://github.com/splewis/get5/actions/workflows/build.yml/badge.svg)](https://github.com/splewis/get5/actions/workflows/build.yml)
[![Downloads](https://img.shields.io/github/downloads/splewis/get5/total.svg?&label=Downloads)](https://github.com/splewis/get5/releases/latest)
[![Discord Chat](https://img.shields.io/discord/926309849673895966.svg)](https://discord.gg/zmqEa4keCk)  

**Status: Supported, actively developed.**

Get5 is a standalone [SourceMod](http://www.sourcemod.net/) plugin for CS:GO servers for running matches. It is originally based on [pugsetup](https://github.com/splewis/csgo-pug-setup) and is inspired by [eBot](https://github.com/deStrO/eBot-CSGO).

The core idea behind its use is all match details being fully defined in a single config file. Check out [this example config](configs/get5/example_match.cfg). Its main target use-case is tournaments and leagues (online or LAN). All that is required of the server-admins is to load match config file to the server and the match should run without any more manual actions from the admins. This plugin is not invasive - most of its functionality is built to work within how the CS:GO server normally operates, not replacing its functionality. **No, it is not recommended for your new matchmaking service. It is intended for competitive play, not pickup games.**

It is meant to be relatively easy to use for tournament admins.

Features of this include:
- Locking players to the correct team by their [Steam ID](https://github.com/splewis/get5/wiki/Authentication-and-Steam-IDs)
- In-game [map veto](https://github.com/splewis/get5/wiki/Map-Vetoes) support from the match's maplist
- Support for multi-map series (Bo1, Bo2, Bo3, Bo5, etc.)
- Warmup and !ready system for each team
- Automatic GOTV demo recording
- [Advanced backup system](https://github.com/splewis/get5/wiki/Match-backups) built on top of valve's backup system
- Knifing for sides
- [Pausing support](https://github.com/splewis/get5/wiki/Pausing)
- Coaching support
- Automatically executing match config files
- Automatically setting team names/logos/match text values for spectator/GOTV clients
- [Stats collection](https://github.com/splewis/get5/wiki/Stats-system) and optional MySQL result/stats upload
- Allows lightweight usage for [scrims](https://github.com/splewis/get5/wiki/Using-get5-for-scrims)
- Has its own [event logging](https://github.com/splewis/get5/wiki/Event-logs) system you can interface with

Get5 also aims to make it easy to build automation for it. Commands are added so that a remote server can manage get5, collect stats, etc. The [get5 web panel](https://github.com/splewis/get5-web) is an (functional) proof-of-concept for this.

## Download and Installation
To see how to download and use Get5 on your game server, please visit the [documentation website](https://splewis.github.io/get5).

## Other things

### Discord Chat

A [Discord](https://discord.gg/zmqEa4keCk) channel is available for general discussion.

### Reporting bugs

Please make a [github issue](https://github.com/splewis/get5/issues) and fill out as much information as possible. Reproducible steps and a clear version number will help tremendously!

### Contributions

Pull requests are welcome. Please follow the general coding formatting style as much as possible. If you're concerned about a pull request not being merged, please feel free to make an  [issue](https://github.com/splewis/get5/issues) and inquire if the feature is worth adding.

### Building

You can use Docker to Build get5. First you need to build the container image locally: Go to the repository folder and run:

	docker build . -t get5build:latest

Afterwards you can build get5 with the following command: (specify /path/to/your/build/output and /path/to/your/get5src)

	docker run --rm -v /path/to/your/get5src:/get5src -v /path/to/your/build/output:/get5/builds get5build:latest
	
