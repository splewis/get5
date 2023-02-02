# :material-flag: Surrender & Forfeit {: #surrender-forfeit }

Two different types of "giving up" exist in Get5; surrender and forfeit. While they may sound the same, they are in fact
not.

## Surrender

The surrender feature allows a player to use the [`!surrender`](../commands#surrender) command to initiate a vote to
surrender the current map (and not the entire series). After the first vote is cast,
a [minimum number of votes](../configuration#get5_surrender_required_votes) must be cast by other team members
within [the defined time limit](../configuration#get5_surrender_time_limit). A team can only vote to surrender if they
are [sufficiently behind on points](../configuration#get5_surrender_minimum_round_deficit).

You can only surrender during the live phase; not during warmup, [map selection](../veto) or the knife round.

The surrender feature is [disabled by default](../configuration#get5_surrender_enabled).

## Forfeit

#### If one team leaves {: #one-team }

If a full team disconnects during the live phase of a match, and nobody on the other team has disconnected,
the [`!ffw`](../commands#ffw) command becomes available to the remaining team. Once the command is issued, at least one
player from the leaving team must connect within the defined [time window](../configuration#get5_forfeit_countdown), or
the remaining team wins the series.

The request to win by forfeit can be canceled with [`!cancelffw`](../commands#cancelffw) by the issuing team, as long as
the team is full. Whether a team is considered full is determined by the value
of [`players_per_team`](../match_schema#schema).

#### If both teams leave {: #both-teams }

If both teams disconnect (during the live **or** knife phase), at least one player from **both** teams must rejoin
the server before [the time runs out](../configuration#get5_forfeit_countdown), or the series is ended in a tie. Unlike
the case where one team leaves, this timer is started automatically under the assumption that nobody is left on the
server to do it.

!!! info "Not full team = empty team"

    If one team has left and the other team has partially left, Get5 will consider it to be equal to both teams
    leaving, under the assumption that players are leaving at the same time.

The forfeit system is disabled during the warmup and [map selection](../veto) phases. You can instead set a restriction
on the [time a team has to become ready](../configuration#get5_time_to_start).

The forfeit feature is [enabled by default](../configuration#get5_forfeit_enabled).

!!! danger "Empty server ends the series"

    If there are no players at all (no spectators, coaches or players) and someone rejoins the server during the live
    phase, a pending forfeit timer may immediately trigger a series end, as the game may restart, which causes a loss
    of game state. If this happens, you must [restore the game state from a backup](../commands#get5_loadbackup) to
    continue.

!!! warning "Coaches don't count"

    [Coaches](../coaching) are not considered players in a forfeit context.

## Automatic Technical Pause {: #auto-tech-pause }

If you want to trigger a technical pause if a team leaves the server,
see [`get5_auto_tech_pause_missing_players`](../configuration#get5_auto_tech_pause_missing_players).
