# :material-pause: Pausing

Get5 supports three different types of pauses. Together, these mimic all the methods of pausing available in the game.
The availability of and maximum number of pauses and their lengths are determined by
the [pause configuration](../configuration#pausing) parameters.

!!! warning "Not a democracy"

    No pauses require voting. If a player calls [`!pause`](../commands#pause) or [`!tech`](../commands#tech), the
    pause will be triggered and a pause count will be consumed (if defined). You cannot cancel a request for pause. Do
    **not** enable [`sv_allow_votes`](https://totalcsgo.com/command/svallowvotes) as it will mess up the pausing system.

## :material-message-question-outline: Tactical {: #tactical }

If [pauses are allowed](../configuration#get5_pausing_enabled), tactical pauses can be requested by any
member of a team using the [`!pause` or `!tac`](../commands#pause) command.
This initiates a pause at the beginning of the following round (or immediately if still in
freeze-time). If [fixed pause time](../configuration#get5_fixed_pause_time) is set, the pauses will always be of
that length, unless both teams call [`!unpause`](../commands#unpause). If instead
[a maximum pause time](../configuration#get5_max_pause_time) is set, the game is automatically unpaused if the pausing
team runs out of pause time *or* if both teams unpause. Note that maximum pause time is across **all tactical pauses**
and does not reset for each pause. If neither fixed pause time nor maximum pause are set, both teams must call unpause
and tactical pauses will have no time restrictions. You can
set [the maximum number of tactical pauses](../configuration#get5_max_pauses) and also decide if you want the tactical
pause restrictions to [reset on halftime](../configuration#get5_reset_pauses_each_half).

## :material-wrench-outline: Technical {: #technical }

If [technical pauses are allowed](../configuration#get5_allow_technical_pause), any team member can type
[`!tech`](../commands#tech) to initiate a technical pause. Technical pauses have their own set of configuration
parameters to allow for different lengths or maximum number of uses. Both teams must [`!unpause`](../commands#unpause)
unless the pausing team [runs out of tech pause time](../configuration#get5_tech_pause_time), in which case only one
team (*either* the pausing or the opposing) must unpause. Technical pauses never end without intervention.
Administrators
cannot call technical pauses, as an administrative pause will be triggered instead. You can set [the maximum number of
technical pauses](../configuration#get5_max_tech_pauses). Technical pauses are never reset on halftime.

## :material-backup-restore: Backup {: #backup }

If the game is [restored from a backup](../backup), it will be so in a paused state. Both teams must
[`!unpause`](../commands#unpause) before the match can continue. Administrators can also unpause backup pauses, or even
override them to an [administrative pause](#administrative).

## :material-account-hard-hat-outline: Administrative {: #administrative }

As a server admin, you can pause the match at any time and with no time
restrictions, but you **cannot** use [`mp_pause_match`](https://totalcsgo.com/command/mppausematch) (or its unpause
equivalent) at any stage. Due to the way Get5 handles pausing, you must use `sm_pause` in the console, since this will
track all details and configurations related to pausing in the system. Similarly, `sm_unpause` must be used to unpause.
Pauses initiated by administrators via console **cannot** be [`!unpause`'ed](../commands#unpause) by players. Also note
that an [`admin` pause event](../events_and_forwards) is fired when the game
is [paused during veto](../configuration#get5_pause_on_veto).

!!! question "I'm an admin on my server, but I cannot call admin pause?"

    Only console/RCON is considered an administrator in pause-context. Having an admin flag as a user/player does not
    allow you to call administrative pauses.
