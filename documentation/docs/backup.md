# :material-backup-restore: Backup System

Get5 ships with a backup system built on top of
CS:GO's [built-in round restore system](https://totalcsgo.com/command/mpbackuprestoreloadfile), which can be used to
either replay a round using the [`!stop`](../commands/#stop) command, or to simply restore an entire match's state on
any server using the [`get5_loadbackup`](../commands/#get5_loadbackup) command.

As Get5's backup system sits on top of CS:GO's, it contains everything a normal CS:GO round backup would, but also
the entire [match configuration](../match_schema) and the match series score for already-played maps.

The backup system must be [enabled](../configuration/#get5_backup_system_enabled) for this to work.

## How does it work?

Every time a round starts, CS:GO automatically writes a round backup file into the root of the `csgo` directory based on
the value of `mp_backup_round_file`. The default value for this is `backup`. Get5 reads this file and copies it into its
own file called `get5_backup_match%s_map%d_round%d.cfg`, where the arguments are `matchid`, `mapnumber` and `roundnumber`,
respectively. A special backup called `get5_backup_match%s_map%d_prelive.cfg` is created for the knife round.

## Example

When in a match, you can call [`get5_listbackups`](../commands/#get5_listbackups) to view all backups for the current
match. Note that all rounds and map numbers start at 0.

They print in the format `filepath date time team1 team2 map team1_score team2_score`.

```
> get5_listbackups
get5_backup_match1844_map0_prelive.cfg 2022-07-26 18:51:25 "Team A" "Team B"
get5_backup_match1844_map0_round30.cfg 2022-07-26 19:13:41 "Team A" "Team B" de_dust2 2 28
get5_backup_match1844_map0_round4.cfg 2022-07-26 18:55:01 "Team A" "Team B" de_dust2 2 2
get5_backup_match1844_map0_round10.cfg 2022-07-26 18:59:25 "Team A" "Team B" de_dust2 2 8
get5_backup_match1844_map0_round23.cfg 2022-07-26 19:08:13 "Team A" "Team B" de_dust2 2 21
get5_backup_match1844_map0_round12.cfg 2022-07-26 19:00:26 "Team A" "Team B" de_dust2 2 10
get5_backup_match1844_map0_round17.cfg 2022-07-26 19:03:39 "Team A" "Team B" de_dust2 2 15
...
```

To load at the beginning of round 13 of the first map of match ID 1844, all players should be connected to the server,
and you use the [`get5_loadbackup`](../commands/#get5_loadbackup) command:

`get5_loadbackup get5_backup_match1844_map0_round12.cfg`. 

The game should restore in a paused state and both teams must [`!unpause`](../commands/#unpause) to continue.
