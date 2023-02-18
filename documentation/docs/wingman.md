# :fontawesome-solid-jet-fighter-up: Wingman {: #wingman }

Get5 can be configured to run in Wingman mode. For this, you only need to set `wingman` to `true`, `players_per_team`
to `2` and use [maps that support Wingman mode](https://counterstrike.fandom.com/wiki/Wingman#Supported_Maps) for
the `maplist` property in your [match configuration](../match_schema#schema).

When a match is configured for Wingman, Get5 will check if
the [`game_mode` and `game_type`](https://developer.valvesoftware.com/wiki/CS:GO_Game_Modes) parameters on your server
are set correctly, and if not, set them and reload the map. This allows you to switch between Wingman and normal 5v5
without having to worry about these parameters.

When in Wingman mode, a separate [live config](../configuration#get5_live_wingman_cfg) file is executed with the Wingman
ruleset. Get5 ships with the default parameters, but similarly to the 5v5 live config, you can change these however you
want.
