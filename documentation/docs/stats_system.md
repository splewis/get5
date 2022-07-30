# Player Stats System

When a get5 match is live, the plugin will automatically record match stats for each player, across each map in the
match. These are recorded in an internal KeyValues structure, and are available at any time during the match (including
the postgame waiting period) via the `Get5_GetMatchStats` native and
the [`get5_dumpstats`](../commands/#get5_dumpstats) command.

Note: the stats collection is not going to be reliable if [`get5_check_auths`](../configuration/#get5_check_auths) is 
set to `0`.

## SourceMod Forwards

If you're writing your own plugin, you can collect stats from the game using the
[forwards](./events_and_forwards.md) provided by Get5.

## Stats KeyValues structure

The root level of the KV contains data for the full series: the series winner (if one exists yet) and the series type (
bo1, bo2..., etc).

Under that root level, there is a level for each map ("map1", "map2"), which contains the map winner (if one exists yet)
, the mapname, and the demo file recording.

Under the map level, there is a section for each team ("team1" and "team2) which contains the current team score (on
that map) and the team name.

Each player has a section under the team level under the section name of their steam64id. It contains all the personal
level stats: name, kills, deaths, assists, etc.

Partial Example:

```
"Stats"
{
	"series_type"        "bo1"
	"team1_name"        "EnvyUs"
	"team2_name"        "Fnatic"
	"map0"
	{
		"mapname"		"de_mirage"
		"winner"		"team1"
		"team1"
		{
			"score"		"5"
			"73613643164646"
			{
				"name"		"xyz"
				"kills"		"0"
				"deaths"		"1"
				"assists"		"5"
				"damage"		"352"
			}
		}
	}
}
```

## What Stats Are Collected?

See the [get5 include](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc#L1769) for what stats will
be recorded and what their key in the KeyValue structure is.

## MySQL Statistics {: #mysql }

Get5 ships with a (disabled by default) plugin called `get5_mysqlstats` that will save many of the stats to a MySQL
database. 

!!! tip "Advanced users only"

    You should have a basic understanding of MySQL if you wish to use this plugin. It is assumed you know what the
    commands below do.

1. Make sure the `get5_mysqlstats.smx` plugin is enabled (moved up a directory from `addons/sourcemod/plugins/disabled`
   directory).
2. Have a MySQL server reachable from the game server's network. These commands are for MySQL 8 but should also work on
MySQL 5.7.

3. Create a schema/database for your tables:
```mysql
CREATE SCHEMA `get5` DEFAULT CHARACTER SET `utf8mb4` COLLATE `utf8mb4_0900_ai_ci`;
USE `get5`;
```
    :warning: The `utf8mb4` part ensures that your database can handle all kinds of emojis and unicode characters. This is
    the default in MySQL 8 but must be explicitly defined for MySQL 5.7.
4. Configure a database user and grant it access to the database:
```mysql
CREATE USER 'get5_db_user'@'%' IDENTIFIED WITH mysql_native_password BY 'super_secret_password';
GRANT ALL ON `get5`.* TO 'get5_db_user'@'%';
```
    :warning: You **can** use the `root` database user instead if you wish. `@'%'` means that the user can log in from any
    network location, and you can replace with this `@'localhost'` if your database is running on the same host as the
    game server.

5. Create the required tables using [these commands](https://github.com/splewis/get5/blob/master/misc/import_stats.sql).
Raw text link can be found [here](https://raw.githubusercontent.com/splewis/get5/master/misc/import_stats.sql).

6. Configure a `"get5"` database section in SourceMod and provide the parameters you used to configure your database:
!!! example ":material-file-cog: `addons/sourcemod/configs/databases.cfg`"

    ```
    "get5"
    {
        "driver"			"mysql"
        "host"				"127.0.0.1"
        "database"			"get5"
        "user"				"get5_db_user"
        "pass"				"super_secret_password"
        "port"			    "3306"
    }
    ```



**Note**: If you use this module, you can force the match ID used by setting it in your match config
(the [Match Schema](../match_schema/#optional-values) section). If you don't do this, the match ID will be set to the
auto-incrementing integer (cast to a string) returned by inserting into the `get5_stats_matches` table. It is strongly
recommended that you always leave the `matchid` blank, as MySQL will then manage the IDs for you.

If you are using an external web panel, **this plugin is not needed** as most external applications record to their own
match tables.
