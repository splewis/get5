# :material-pause: Pausing

Get5 supports three different types of pauses. Together, these mimic all the methods of pausing available in the game.
The availability of and maximum number of pauses and their lengths are determined by
the [pause configuration](../configuration/#pausing) parameters.

## Tactical

Tactical pauses can be requested by any member of a team using the [`!pause` or `!tac`](../commands/#pause) command and
requires no voting. This initiates a pause at the beginning of the following round (or immediately if still in
freeze-time). If [get5_fixed_pause_time](../configuration/#get5_fixed_pause_time) is set, the pauses will always be of
that length and cannot be unpaused by players, otherwise both teams must call [`!unpause`](../commands/#unpause). If
[get5_max_pause_time](../configuration/#get5_max_pause_time) is set, the game is automatically unpaused if the pausing
team runs out of pause time *or* if both teams unpause.
Pauses [`initiated by administrators`](../pausing/#administrative) (see below) cannot be unpaused by players.

## Technical

If [technical pauses are allowed](../configuration/#get5_allow_technical_pause), any team member can type
[`!tech`](../commands/#tech) to initiate a technical pause. Technical pauses have their own set of configuration
parameters to allow for different lengths or maximum number of uses. Both teams must [`!unpause`](../commands/#unpause)
unless the pausing team [runs out of tech pause time](../configuration/#get5_tech_pause_time), in which case only the
opposing team must [`!unpause`](../commands/#unpause).

## Administrative

As a [server admin](../installation/#administrators), you can pause the match at any time and with no time
restrictions, but you should **not** use `mp_pause_match` at any stage. Due to the way Get5 handles pausing, you
should **always** use `sm_pause` in the console, since this will track all details and configurations related to pausing
in the system. Similarly, `sm_unpause` should be used to unpause. Pauses initiated by administrators via console (
using `sm_pause`) **cannot** be [`!unpause`'ed](../commands/#unpause) by players. Also note that
an [`admin` pause event](../events_and_forwards) is fired when the game is paused during veto (
if [`get5_pause_on_veto`](../configuration/#get5_pause_on_veto) is enabled).

!!! help "But the [event system](../events_and_forwards) also hints at the existence of a `backup` pause type?"

    Internally, Get5 uses the `backup` pause type when pausing due to loading backup configurations. To not confuse
    any program reaction to pauses, we added a special pause type in these cases, and you should probably just ignore
    these events. They still fire because *technically* the game is pausing.
