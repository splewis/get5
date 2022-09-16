# :fontawesome-solid-ban: Map Veto

If your match is configured to include a veto-phase (setting [`skip_veto`](../match_schema/#schema) to `false`), each
team's captain will ban or pick maps to play using in-game menus. The veto system behaves slightly differently depending
on the number of maps to play (Bo3, Bo5 etc.).

!!! warning "Lucky number seven"

    The veto-system assumes the [`maplist`](../match_schema/#schema) has 7 maps, similarly to the competitive map pool,
    and it may not function properly if this is not the case. We also assume that [`side_type`](../match_schema/#schema)
    is set to `standard` when describing side choices.

## Team Captains {: #captains }

Get5 will give veto menus to a player on each team. The player it gives it to will be the first player listed
in the [`players`](../match_schema/#schema) section of a match configuration, or a random player on the away-team
when in [scrim mode](../getting_started/#scrims).

`team1` vetoes first by default, but you can change this in the match configuration via
the [`veto_first`](../match_schema/#schema) parameter, which also supports `random`.

## Veto Types {: #types }

### Single map (Bo1) {: #bo1 }

Each team alternates vetoing, vetoing 3 maps each. The last map standing will be played. A knife round will be used to
decide starting sides.

`ban/ban/ban/ban/ban/ban/last map played`

### Double (Bo2) {: #bo2 }

Each team alternates vetoing, vetoing 2 maps each. After those vetoes, each team picks a map, letting the other team
choose a starting side on it. The last map standing will **not** be played.

`ban/ban/ban/ban/pick/pick/last map unused`

### Best-of-three (Bo3) {: #bo3 }

Each team vetoes 1 map, then each team picks 1 map. The team that did not pick a map gets the side choice on it. After
this, each team will veto another map until only 1 map is left. The last map standing will be the 3rd map in the series,
and a knife round will be used to decide starting sides.

`ban/ban/pick/pick/ban/ban/last map is 3rd map in series`

### Best-of-five (Bo5) {: #bo5 }

Each team vetoes 1 map, then alternate picking the maps. When a team picks a map, the other team will get the side
choice. The last map standing will be the 5th map in the series and a knife round will be used to decide starting sides.

`ban/ban/pick/pick/pick/pick/last map is 5th map in series`
