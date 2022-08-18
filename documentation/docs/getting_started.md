# :material-play: Getting Started

!!! tip "Show me the money!"

    While you can just jump right in, we recommend you read the [configuration](../configuration) and
    [match schema](../match_schema) sections of the documentation to understand what Get5 can do.

## Quick Start {: #quick-start }

If you want to create a match quickly without modifying anything, you must set two properties:

1. [`get5_check_auths 0`](../configuration/#get5_check_auths)
2. [`get5_kick_when_no_match_loaded 0`](../configuration/#get5_kick_when_no_match_loaded)

Once these are disabled, anyone can join the server and they will not be kicked for not being a part of a match.
Once all players are connected to the server and on correct teams, just
call [`get5_creatematch`](../commands/#get5_creatematch). There is also a simple menu that you can call this command
from by typing [`!get5`](../commands/#get5) in the game chat. Note that you must
be [a server administrator](../installation/#administrators) to do this.

## Match Configuration {: #match-configuration }

The default operation mode for Get5 is the configuration and loading of
a [match configuration file](../match_schema). This file should contain all the players and coaches, their team
name and optionally flag and logo as well as any spectators/casters. Once you've created your file you can load it
using the [`get5_loadmatch`](../commands/#get5_loadmatch) command or configure your server to automatically load the
file as soon as a player joins by setting [`get5_autoload_config`](../configuration/#get5_autoload_config).

!!! tip "Lock it down"

    When loading match configurations, ensure that [`get5_check_auths`](../configuration/#get5_check_auths) is enabled.
    This ensures that people are locked to the correct teams and that nobody else can join the server.

## Scrims {: #scrims }

While Get5 is intended for matches (league matches, LAN-matches, cups, etc.), it can be used for everyday
scrims/gathers/whatever as well. If that is your use case, you should do a few things differently. We call "_having a
home team defined and anyone else on the opposing team_" a **scrim**, and loading this configuration is referred to as
**scrim mode**.

### Adding your team's Steam IDs {: #home-team }

You **must** edit the [scrim template](https://github.com/splewis/get5/blob/master/configs/get5/scrim_template.cfg)
located at `addons/sourcemod/configs/get5/scrim_template.cfg` and add in *your* team's players to the `team1` section by
their Steam IDs (any format works). After doing this, any user who does not belong in `team1` will implicitly be set
to `team2`.

!!! warning "Coaches in scrims"

    You **cannot** set the [`coaches`](../match_schema/#schema) section in a scrim template. Instead, add everyone to
    the [`players`](../match_schema/#schema) section and use the [`!coach`](../commands/#coach) command to become a
    [coach](coaching.md) after joining the game. If the team is full (defined by
    [`players_per_team`](../match_schema/#schema)), additional players will automatically be moved to coach if there are
    available slots.

You can list however many players you want. Add all your coaches, analysts, ringers, and such. If someone on your list
ends up being on the other team in a scrim, you can use the [`!ringer`](../commands/#ringer) command to temporarily swap
them (similarly, you can use it to put someone not in the list on your team temporarily).

### Letting the opposing team in {: #opposing-team }

Get5 can be configured to kick all players from the server if no match is loaded. You should disable this for a scrim
server. To do so, edit [`cfg/sourcemod/get5.cfg`](../configuration/#main-config) and make sure that
[`get5_kick_when_no_match_loaded`](../configuration/#get5_kick_when_no_match_loaded) is set to `0`.

### Starting the Match

Rather than creating a [match configuration](match_schema.md), you should
use the [`get5_scrim`](../commands/#get5_scrim) command when the server is on the correct map. You can do this via
RCON or as a regular console command if you are [a server administrator](../installation/#administrators).
You could also type [`!scrim`](../commands/#scrim) in chat.

Once you've done this, all that is required is for both teams to [ready up](../commands/#ready) and the match will
begin.

!!! danger "Practice Mode"

    If you have [practicemode](https://github.com/splewis/csgo-practice-mode) on your server as well, you may wish to
    add `sm_practicemode_can_be_started 0` in the `cvars` section of your [match configuration](../match_schema/#schema).
    This will remove the ability to start practice mode until the match is completed or cancelled.

### Changing Scrim Settings

You can (and should) edit
the [scrim template](https://github.com/splewis/get5/blob/master/configs/get5/scrim_template.cfg)
at `addons/sourcemod/configs/get5/scrim_template.cfg`. In this you can set any scrim-specific properties in the `cvars`
section. The template defaults to `mp_match_can_clinch 0` (designed for practice) which you should disable if playing a
real match. You may also want to lower `tv_delay` (and maybe set `tv_enable 1` so you can [record your scrims](gotv.md))
.
