# :material-headset: Coaching

Get5 ships with mechanics to manage coaches, but the behavior differs _slightly_ from the built-in coaching
system found in the game, which avoids a
few ["minor" bugs](https://en.wikipedia.org/wiki/Counter-Strike_coaching_bug_scandal).

### Server requirements {: #requirements }

1. [`sv_coaching_enabled`](https://totalcsgo.com/command/svcoachingenabled) must be set.
2. [`coaches_per_team`](../match_schema/#schema) in your match configuration
   or [scrim template](../getting_started/#scrims) must be larger than 0.
3. The [`-maxplayers_override`](https://developer.valvesoftware.com/wiki/Maxplayers)
   launch parameter must be defined on your server to allow for the number of connected clients you expect, including
   all players, spectators and coaches.

### Becoming a coach {: #howto }

Due to internal conflicts with how [backups](backup.md) and auto-assignment to teams works in Get5, the default
[`coach`](https://counterstrike.fandom.com/wiki/Coaching) console command is disabled. You can become a coach in one of
three ways:

1. Use the [`!coach`](../commands/#coach) chat command during freezetime or warmup.
2. Be defined as a coach in the [match configuration](../match_schema/#schema) or
   via [`get5_addcoach`](../commands/#get5_addcoach).
3. Join a game where the team is already full (determined by [`players_per_team`](../match_schema/#schema)) and where a
   coach slot is available.

!!! warning "Coaching is permanent"

    Once you are assigned as a coach in a non-scrim game, you cannot leave the coach slot unless you are removed from
    coaching using [`get5_removeplayer`](../commands/#get5_removeplayer).

If the current number of coaches exceeds or equals [`coaches_per_team`](../match_schema/#schema), including if it is
zero, additional players will be kicked from the match. However, if a connecting player is defined
in [`players`](../match_schema/#schema), the team is full and a coach slot is open, they will be permanently moved to
coaching for the series.

This behavior allows you to define as many coaches and players in the match configuration as you want: As long as the
number of players and coaches on the server don't exceed [`players_per_team`](../match_schema/#schema)
and [`coaches_per_team`](../match_schema/#schema), respectively, Get5 will fill the
game slots with the appropriate number of players and coaches and kick the rest. Being in
the [`coaches`](../match_schema/#schema) section takes precedence over [`players`](../match_schema/#schema).

!!! note "Decreasing the number of players"

    If a match configuration with [`players_per_team`](../match_schema/#schema) or
    [`coaches_per_team`](../match_schema/#schema) set to a number *lower* than the number of players **already connected
    to the server**, the entire team will be kicked and must reconnect.

### Coaching in Scrims {: #scrims }

When in [scrim-mode](../getting_started/#scrims), you cannot set the [`coaches`](../match_schema/#schema) key, and
players are never locked to the coaching slot. This means that to become a coach in a scrim, you must always
call [`!coach`](../commands/#coach) or join a team that already has [`players_per_team`](../match_schema/#schema)
players (i.e. is full). Contrary
to games with a complete [match configuration](../match_schema/#schema), you can also exit the coaching slot if the team
is not full by simply selecting any team using the team-join menu, which will respawn you as a player in the next
round (or immediately if still in freezetime), similarly to if you were to reconnect to the server.

!!! danger "`players_per_team` matters in scrims!"

    Do not set [`players_per_team`](../match_schema/#schema) to a value larger than the number of players you expect.
    If you do this, a player could go back and forth between coaching and playing during freezetime, potentially
    dropping items for their team. If you play 5v5, don't set it to 6 to allow "anyone to join to coach".
