# :material-backup-restore: Backup System

Get5 ships with a backup system built on top of
CS:GO's [built-in round restore system](https://totalcsgo.com/command/mpbackuprestoreloadfile), which can be used to
either replay a round using the [`!stop`](../commands#stop) command, or to simply restore an entire match's state on
any server using the [`get5_loadbackup`](../commands#get5_loadbackup) command.

As Get5's backup system sits on top of CS:GO's, it contains everything a normal CS:GO round backup would, but also
the entire [match configuration](../match_schema) and the match series score for already-played maps.

The backup system can be enabled or disabled
with [`get5_backup_system_enabled`](../configuration#get5_backup_system_enabled).

### How does it work? {: #how-to }

Every time a round starts, CS:GO automatically writes a round backup file into the root of the `csgo` directory based on
the value of [`mp_backup_round_file`](https://totalcsgo.com/command/mpbackuproundfile), which Get5 will [automatically
adjust to prevent file collisions](../configuration#get5_server_id). Get5 reads this file, copies it into its
own file called `get5_backup%d_match%s_map%d_round%d.cfg`, where the arguments
are [`get5_server_id`](..configuration/#get5_server_id), `matchid`, `mapnumber` and `roundnumber`, respectively, and
then deletes the original backup file. A special backup
called `get5_backup%d_match%s_map%d_prelive.cfg` is created and should be used if you want to restore to the beginning
of the map, before the knife round.

### Example

When in a match, you can call [`get5_listbackups`](../commands#get5_listbackups) to view all backups for the current
match. Note that all rounds and map numbers start at 0.

They print in the format `filepath timestamp team1 team2 map team1_score team2_score`.

```
> get5_listbackups
get5_backup4_match1844_map0_prelive.cfg 2022-07-26 18:51:25 "Team A" "Team B"
get5_backup4_match1844_map0_round30.cfg 2022-07-26 19:13:41 "Team A" "Team B" de_dust2 2 28
get5_backup4_match1844_map0_round4.cfg 2022-07-26 18:55:01 "Team A" "Team B" de_dust2 2 2
get5_backup4_match1844_map0_round10.cfg 2022-07-26 18:59:25 "Team A" "Team B" de_dust2 2 8
get5_backup4_match1844_map0_round23.cfg 2022-07-26 19:08:13 "Team A" "Team B" de_dust2 2 21
get5_backup4_match1844_map0_round12.cfg 2022-07-26 19:00:26 "Team A" "Team B" de_dust2 2 10
get5_backup4_match1844_map0_round17.cfg 2022-07-26 19:03:39 "Team A" "Team B" de_dust2 2 15
...
```

!!! example "Loading a backup"

    To load at the beginning of round 13 of the first map of match ID 1844 from a backup created on a
    [server with ID 4](../configuration#get5_server_id), run [`get5_loadbackup`](../commands#get5_loadbackup):

    `get5_loadbackup get5_backup4_match1844_map0_round12.cfg`

After loading a backup, the game state is restored and the game is [paused](../pausing#backup). Both teams
must [`!unpause`](../commands#unpause) to continue.

### Automatic Upload {: #upload }

You can configure Get5 to automatically send all your backups to
a [remote location](../configuration#get5_remote_backup_url) (such as a central server at a LAN). The file will be sent
as the raw HTTP body. Requires the [SteamWorks](../installation#steamworks) extension.

!!! warning "Pre-live backups are sent multiple times"

    As Get5 writes the `prelive` backup file multiple times, it will also upload it multiple times. If you don't care
    about this backup, just discard the file if the `Get5-RoundNumber` header is `-1`. You should still reply with
    `200 OK` though.

#### Headers

Get5 will add these headers to the request in order for your server to handle it:

1. `Get5-FileName` is the name of the backup file (see examples above).
2. `Get5-MapNumber` is the zero-indexed map number in the series.
3. `Get5-RoundNumber` is the zero-indexed round number of the map. If the match is not yet live (warmup, knife), this
   value is `-1`.
4. `Get5-MatchId` **if** the [match ID](../match_schema#schema) is not an empty string.
5. `Get5-ServerId` **if** [`get5_server_id`](../configuration#get5_server_id) is set to a positive integer.
6. `Get5-Version` is the version of Get5, i.e. `0.12.0`.

#### Authorization

You can add a [custom header](../configuration#get5_remote_backup_header_key) to the request for authorization, if
required.

#### Example

For an example of how to read the file on your web server, please see the example for [demo uploads](../gotv#example).
The same principles apply to backups.

### Loading from Remote {: #remote }

You can use the [`get5_loadbackup_url`](../commands#get5_loadbackup_url) command to load a backup from a remote host.
This assumes the file is a valid KeyValues file and requires the [SteamWorks](../installation#steamworks) extension.

### Consumed pauses in backups {: #pauses }

When restoring from a backup, the [consumed pauses](../pausing) are reset to the state they were in at the beginning
of the round you restore to, but only if the game state is not currently live. This means that using
the [`!stop`](../commands#stop) command or the [`get5_loadbackup`](../commands#get5_loadbackup) command **for the same
match and map while the game is live** will retain the currently used pauses. If restarting the server or loading the
backup from scratch, the consumed pauses defined in the backup file will be set.
