# :material-text: Welcome to Get5

Get5 is a standalone SourceMod plugin for CS:GO servers for running matches. It was originally based
on [pugsetup](https://github.com/splewis/csgo-pug-setup) and inspired by [eBot](https://github.com/deStrO/eBot-CSGO).

The core idea behind Get5 is to encapsulate all match details in a [single configuration file](./match_schema.md).
Its main target use-case
is tournaments and leagues (online or LAN). All that is required of server-admins is to load match config file to the
server and the match should run without any additional interference. This plugin is not invasive - most of its
functionality is built to work within how the CS:GO server normally operates, not replacing its functionality.

Highlights of Get5 include:

- Locking players to their correct team and side by their Steam ID
- Automatically setting team names/logos/match text values for spectator/GOTV clients
- In-game map-veto support from the match's list of maps
- Support for multi-map series (Bo1, Bo2, Bo3, Bo5, etc.)
- Warmup and [`!ready`](commands/#ready)-system for each team
- Automatic GOTV demo recording
- Advanced backup system built on top of Valve's backup system
- Knifing for sides
- Pausing support
- Coaching support
- Lightweight usage for scrims
- Event logging and SourceMod forwards you can interface with, allowing for collection of stats etc.
- [Commands](commands/#serveradmin-commands) allow remote management of the plugin

If you are installing this on your game server, head over to the [Installation](./installation.md) instructions.
