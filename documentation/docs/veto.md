# :material-map: Map Selection

If your match is configured to include a veto-phase (setting [`skip_veto`](../match_schema#schema) to `false`), each
team's captain will ban or pick maps to play using in-game menus.

## Team Captains {: #captains }

Get5 will give map pick/ban and side choice menus to a player on each team. The player it gives it to will be the first
player listed in the [`players`](../match_schema#schema) section of a match configuration, or a random player on the
away-team when in [scrim mode](../getting_started#scrims).

## Options {: #options }

`team1` vetoes first by default, but you can change this in the match configuration via
the [`veto_first`](../match_schema#schema) parameter, which also supports `random`.

When a team picks a map, the other team gets to choose the side to start on for that map. If a map is selected
by default by being the last map standing, a knife round is used. This behavior is determined by
the [`side_type`](../match_schema#schema) parameter of your match configuration. Sides may also be predetermined using
the [`map_sides`](../match_schema#schema) parameter.

## Default Flow {: #default }

If you don't provide a custom [`veto_mode`](../match_schema#schema), Get5 will create a suitable map selection flow
depending on your series length ([`num_maps`](../match_schema#schema)) and map
list ([`maplist`](../match_schema#schema)). In all cases, the map list must be **at least one larger than the number of
maps to play**. If not, the veto system is automatically disabled, and the maps are played in the order they appear in
the map list.

!!! info "Legend"

    To make the table easier to read, we'll use icons instead of strings to illustrate.

    :one: :white_check_mark: :octicons-dash-16: `team1_pick`
   
    :two: :white_check_mark: :octicons-dash-16: `team2_pick`
   
    :one: :no_entry: :octicons-dash-16: `team1_ban`
   
    :two: :no_entry: :octicons-dash-16: `team2_ban`
   
    :regional_indicator_x: :white_check_mark: :octicons-dash-16: played by default

Note that these examples assume that [`veto_first`](../match_schema#schema) is set to `team1`.

=== "Single Map"

    Teams alternate banning maps until only one map remains.

    5 is used as at the map pool size example here, but the flow is identical for any pool size.

    | Map Pool Size | Flow                                                                                                                                                                                     |
    |---------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
    | 5             | :one: :no_entry: :octicons-dash-16: :two: :no_entry: :octicons-dash-16::one: :no_entry: :octicons-dash-16: :two: :no_entry: :octicons-dash-16: :regional_indicator_x: :white_check_mark: |

=== "Double Map"

    When less than 5 maps are in the pool, each team simply picks one map. At 5 or more maps, each team bans one map
    and then picks one map, regardless of map pool size.
    
    | Map Pool Size | Flow                                                                                                                                         |
    |---------------|----------------------------------------------------------------------------------------------------------------------------------------------|
    | 3-4           | :one: :white_check_mark: :octicons-dash-16: :two: :white_check_mark:                                                                         |
    | 5+            | :one: :no_entry: :octicons-dash-16: :two: :no_entry: :octicons-dash-16: :one: :white_check_mark: :octicons-dash-16: :two: :white_check_mark: |

=== "Best-of-X (odd-sized series)"

    Alternating bans until there are `num_maps` (i.e. 3) maps left, at which point teams alternate picking `num_maps-1` (i.e. 2) maps. The remaining map is played last by default.
    
    | Map Pool Size | Flow                                                                                                                                                                                                      |
    |---------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
    | 4+ (even)     | :one: :no_entry: :octicons-dash-16: :two: :white_check_mark: :octicons-dash-16: :one: :white_check_mark: :octicons-dash-16: :regional_indicator_x: :white_check_mark:                                     |
    | 5+ (odd)      | :one: :no_entry: :octicons-dash-16: :two: :no_entry: :octicons-dash-16: :one: :white_check_mark: :octicons-dash-16: :two: :white_check_mark: :octicons-dash-16: :regional_indicator_x: :white_check_mark: |

=== "Best-of-X (even-sized series)"

    Alternating bans until there are `num_maps` (i.e. 4) maps left, at which point teams alternate picking `num_maps-1` (i.e. 3) maps. The remaining map is played last by default.
    
    | Map Pool Size | Flow                                                                                                                                                                                                                                                  |
    |---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
    | 5+ (odd)      | :one: :no_entry: :octicons-dash-16: :two: :white_check_mark: :octicons-dash-16: :one: :white_check_mark: :octicons-dash-16: :two: :white_check_mark: :octicons-dash-16: :regional_indicator_x: :white_check_mark:                                     |
    | 6+ (even)     | :one: :no_entry: :octicons-dash-16: :two: :no_entry: :octicons-dash-16: :one: :white_check_mark: :octicons-dash-16: :two: :white_check_mark: :octicons-dash-16: :one: :white_check_mark: :octicons-dash-16: :regional_indicator_x: :white_check_mark: |

    !!! warning "Life ain't fair"

        When the series length is even-sized, the last team to ban will have one map pick less than the other team.

## Custom Flow {: #custom }

You may provide a custom ban/pick order using the [`veto_mode`](../match_schema#schema) property of a match
configuration. If you do this, any logically possible combination of picks/bans, number of maps to
play ([`num_maps`](../match_schema#schema)) and map pool size ([`maplist`](../match_schema#schema)) is allowed.

The [`veto_mode`](../match_schema#schema) parameter accepts an array of strings:

`team1_pick`, `team1_ban`, `team2_pick` and `team2_ban`.

### Rules {: #rules }

Your array of picks and bans **must** comply with these rules, or your match configuration will fail to load:

1. If your series consists of more than one map, the number of picks must be _no less_ than the number of maps to play
   minus one. This ensures there is no ambiguity in the order of maps, even if the number of maps remaining after bans
   is correct. I.e. in a Bo3, you must have at least 2 picks.
2. If you provide more options (picks or bans) than required, extra options are ignored. I.e. with a map pool of 7, only
   the first 6 options would be evaluated and used.
3. If you provide more picks than required, extra options are ignored. I.e. with a map pool of 7 and 6 picks in a Bo3,
   only the first 3 picks would be evaluated and used.
4. Which team you assign to pick or ban does not matter. If you wanted, you could have one team pick all the maps.
5. Either:
    1. If the number of picks is less than the series length, you must provide at least
       "map pool size minus 1" number of options, i.e. no less than 6 options for a pool of 7 maps.
    2. If the number of picks is _equal to_ (or per rule 3, _exceed_) the series length, the picks can be positioned
       before the map pool has been exhausted, and the total number of options can be less than the "map pool size minus
       1".

