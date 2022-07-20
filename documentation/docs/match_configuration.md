# Match Configuration

## Quick Start

If you want to create a match quickly without modifying anything, you will just need to change two
cvars, `get5_check_auths 0` and `get5_kick_when_no_match_loaded 0`, so users will be able to join the server. Once these
are set, and all players are connected to the server and correct teams, just call `get5_creatematch`. There is also a
simple menu that you can call this command by using `!get5` in the game chat.

## Scrim Configuration

If you are using get5 for scrims, please follow these steps.

While get5 is intended for matches (league matches, LAN-matches, cups, etc.), it can be used for everyday
scrims/gathers/whatever as well. If that is your use case, you should do a few things differently.

### Cvars

By default, get5 kicks all players from the server if no match is loaded. You should disable this for a practice server.
To do so, edit `cfg/sourcemod/get5.cfg` and change the following cvar:

`get5_kick_when_no_match_loaded 0` - this will enable players to join before starting

### Adding Your Team's Steam IDs

You **must** edit the [scrim template](https://github.com/splewis/get5/blob/master/configs/get5/scrim_template.cfg)
located at `addons/sourcemod/configs/get5/scrim_template.cfg` and add in *your* team's players to the `team1` section by
their Steam IDs (any format works). After doing this, any user who does not belong in `team1` will implicitly be set
to `team2`.

You can list however many players you want. Add all your coaches, analysts, ringers, and such. If someone on your list
ends up being on the other team in a scrim, you can use the !ringer command to temporarily swap them (similarly, you can
use !ringer to put someone not in the list, on your team temporarily).

### Starting the Match

Rather than creating a [match config](https://github.com/splewis/get5#match-schema), you should use the `get5_scrim`
when the server is on the correct map. You can use this via rcon (`rcon get5_scrim`, be sure your `rcon_password` is
set!) or as a regular console command if you have the SourceMod changemap admin flag. You could also type `!scrim` in
chat.

This command takes optional arguments: `get5_scrim [other team name] [map name] [matchid]`. For example, if you're
playing *fnatic* on *dust2* you might run `get5_scrim fnatic de_dust2`. The other team name defaults to "away" and the
map name defaults to the current map. `matchid` defaults to "scrim".

Once you've done this, all that has to happen is teams to ready up to start the match.

#### Extra Commands

- You can use `get5_ringer` in console with a Steam ID to add a player to the "home" team, or `!ringer` in chat.
- You can do `!swap` in chat to swap sides during the warmup phase if you want to start on a different side.
- If you forget commands, use `!get5` in chat, and you will get a user-friendly menu to do all the above.
- If you have [practicemode](https://github.com/splewis/csgo-practice-mode) on your server as well, you may wish to
  add `sm_practicemode_can_be_started 0` in
  your [live config](https://github.com/splewis/get5/blob/master/cfg/get5/live.cfg) at `cfg/get5/live.cfg`.

### Changing Scrim Settings

You can (and should) edit
the [scrim template](https://github.com/splewis/get5/blob/master/configs/get5/scrim_template.cfg)
at `addons/sourcemod/configs/get5/scrim_template.cfg`. In this you can set any scrim-specific cvars in the cvars
section.  
The default settings will playout all 30 rounds and shorten up the halftime break. You also may want to
lower `tv_delay` (and maybe `tv_enable` so you can record your scrims) and other settings in
your [live config](https://github.com/splewis/get5/blob/master/cfg/get5/live.cfg) at `cfg/get5/live.cfg`.

## Match Configuration

**Note**: If you are using get5 just for scrims, do not proceed here, just follow the instructions above!

You can either load a match config from a Key Value file (a
good [example](https://github.com/splewis/get5/blob/master/configs/get5/example_match.cfg) and starting point is located
at `addons/sourcemod/configs/get5/example_match.cfg`). There are many *optional* fields there, and they can be explained
in the [Match Schema](./match_schema.md) section of the docs. The only **required** portions of the config are `team1`
and `team2`.  
Once you have your file created, you can place it anywhere in your server directory. For example, if you create the file
under `csgo/match.cfg`, you would call `get5_loadmatch match.cfg`.  
If you place it anywhere else, for example `csgo/addons/sourcemod/configs/get5/match.cfg`, you would
call `get5_loadmatch addons/sourcemod/configs/get5/match.cfg` and Get5 will load your match according to the values in
that file.
