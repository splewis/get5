# :material-play: Getting Started

!!! tip "Show me the money!"

    While you can just jump right in, we recommend you read the [configuration](../configuration) and
    [match schema](../match_schema) sections of the documentation to understand what Get5 can do.

## Match Configuration {: #match-configuration }

The default operation mode for Get5 is the configuration and loading of a [match configuration file](../match_schema).
Once you've created your file, you can load it using
the [`get5_loadmatch`](../commands#get5_loadmatch) command or configure your server to automatically load the file as
soon as a player joins by setting [`get5_autoload_config`](../configuration#get5_autoload_config).

## The Menu {: #get5-menu }

If you wish to use Get5 more like you would use PugSetup, the [`!get5`](../commands#get5) menu can be used
by [server admins](../installation#administrators) to configure and start a match from within the game.
Out-of-the-box, you can only start a match with current players, meaning that all players (and coaches) must be present
and on the right team before you can continue. In order to preselect teams, you must add available teams to
your [teams file](../configuration#teams-file). You can also configure a custom map pool using
the [maps file](../configuration#maps-file). Behind the scenes, the menu simply creates and loads
a [match configuration](../match_schema) file based on the selected options.

### Menu Options {: #menu-options }

The options below are available in the `!get5` menu. Each option changes one or
more [match schema](../match_schema#schema) parameters in the resulting match configuration generated by the menu.

#### Game Mode {: #game-mode }

* Sets `wingman`.

The game mode allows you to switch between Competitive (regular 5v5) and [Wingman](../wingman) mode.

#### Series Length {: #series-length }

* Sets `num_maps`.

Sets the maximum number of maps to play in the series.

#### Team Size {: #team-size }

* Sets `players_per_team`.

Defines the number of players each team can have, excluding coaches. Make sure this matches the selected Game Mode.

#### Team Selection Mode {: #team-selection-mode }

* Sets `scrim`, `team1` and `team2`.

Determines how teams are selected or configured.

1. **Current**<br>
   Uses teams as-is (requires full teams on both sides). If you want coaches on your team in this mode,
   they must use the `coach ct` or `coach t` console command before the match is started. This mode also allows you to
   set the team captains manually or let Get5 randomly select them.

2. **Fixed**<br>
   Uses the teams selected from the menu by the admin. This requires at least two teams in
   the [teams file](../configuration#teams-file). The team captains will be the first players in `players` for each
   team.

3. **Scrim**<br>
   Uses the team selected from the menu as the "home team". This requires at least one team in
   the [teams file](../configuration##teams-file). The home team captain will be the first player in `players`, and the
   away-team captain will be a random player.

#### Map Selection {: #map-selection }

* Sets `skip_veto` and `maplist`.

Determines the strategy used to select the map(s) to play:

1. **Manual**<br>
   The map(s) must be selected from the menu by the admin.

2. **Current Map**<br>
   Play the current map (*Series Length == 1 only*).

3. **Pick/Ban**<br>
   The [map selection](../veto) system is used.

#### Map Pool {: #map-pool}

* Sets `maplist`.

Determines which pool of maps to select from when using **Manual** or **Pick/Ban** [map selection](#map-selection) mode.
You can define additional map pools by editing your [maps file](../configuration#maps-file).

#### Side Type {: #side-type }

* Sets `side_type`.

Determines the strategy for side selection.

1. **Standard**<br>
   The team that doesn't pick a map gets to pick a side on it (*Map Selection == Pick/Ban only*).

2. **Always Knife**<br>
   A knife round is always used.

3. **Team 1 CT**<br>
   Team 1 always starts CT.

4.  **Random**<br>
   Sides are randomly decided.

#### Friendly Fire {: #friendly-fire }

* Sets [`mp_friendlyfire`](https://totalcsgo.com/command/mpfriendlyfire) in `cvars`.

Determines if friendly fire is enabled or not.

#### Overtime {: #overtime }

* Sets [`mp_overtime_enable`](https://totalcsgo.com/command/mpovertimeenable) in `cvars`.

Determines if overtime is enabled or not.

#### Play All Rounds {: #play-all-rounds }

* Sets [`mp_match_can_clinch`](https://totalcsgo.com/command/mpmatchcanclinch) in `cvars`.

Determines if all rounds of the match will be played or not, even if a team has logically won.

## Scrims {: #scrims }

We call "_having a home team defined and anyone else on the opposing team_" a **scrim**, and loading this configuration
is referred to as **scrim mode**. This feature is designed for practices where you know the Steam IDs of your own team
and want to enforce team-locking, but don't know the Steam IDs of your opponents.

### How-to

There are four distinct ways you can start a scrim:

1. Using the [`!get5`](#get5-menu) menu and setting [Team Selection Mode](#team-selection-mode) to **Scrim**.
2. Setting `scrim: true` in any [match configuration](../match_schema#schema).
3. Passing `--scrim` and your home team to `--team1` with [`get5_creatematch`](../commands#get5_creatematch).
4. Using the  [`get5_scrim`](../commands#get5_scrim) command and the fixed `scrim_template.cfg` file - see below.

### Using the Scrim template (:warning: Legacy) {: #scrim-template }

!!! warning "`scrim_template.cfg` is legacy and inflexible"

    While the following approach still works fine for backwards-compatibilty reasons, it is not the recommended one. If
    you are new to Get5, we recommend that you use the [`!get5`](#get5-menu) menu, the
    [`get5_creatematch`](../commands#get5_creatematch) command or load a normal match configuration in Scrim mode
    instead.

#### Adding your team's Steam IDs {: #home-team }

You **must** edit the [scrim template](https://github.com/splewis/get5/blob/master/configs/get5/scrim_template.cfg)
located at `addons/sourcemod/configs/get5/scrim_template.cfg` and add in *your* team's players to the `team1` section by
their Steam IDs (any format works). After doing this, any user who does not belong in `team1` will implicitly be set
to `team2`.

!!! warning "Coaches in scrims"

    You **cannot** set the [`coaches`](../match_schema#schema) section in a scrim template. Instead, add everyone to
    the [`players`](../match_schema#schema) section and use the [`!coach`](../commands#coach) command to become a
    [coach](../coaching) after joining the game. If the team is full (defined by
    [`players_per_team`](../match_schema#schema)), additional players will automatically be moved to coach if there are
    available slots.

You can list however many players you want. Add all your coaches, analysts, ringers, etc. If someone on your list
ends up being on the other team in a scrim, you can use the [`!ringer`](../commands#ringer) command to temporarily swap
them (similarly, you can use it to put someone not in the list on your team temporarily).

#### Starting the Match

Use the [`get5_scrim`](../commands#get5_scrim) command when the server is on the correct map. You can do this via
RCON or as a regular console command if you are [a server administrator](../installation#administrators).
You could also type [`!scrim`](../commands#scrim) in chat.

#### Changing Scrim Settings

You can edit the [scrim template](https://github.com/splewis/get5/blob/master/configs/get5/scrim_template.cfg) located
at `addons/sourcemod/configs/get5/scrim_template.cfg` to change parameters of your scrims. In this you can set any
scrim-specific properties in the `cvars` section. The template defaults to `mp_match_can_clinch 0` (designed for
practice). You can apply any option from the [match configuration schema](../match_schema#schema), but `scrim` will
always be enabled.

!!! danger "Practice Mode"

    If you have [practicemode](https://github.com/splewis/csgo-practice-mode) on your server as well, you may wish to
    add `sm_practicemode_can_be_started 0` in the `cvars` section of your scrim
    [match configuration](../match_schema#schema). This will remove the ability to start practice mode until the match
    is completed or cancelled.
