# :material-chart-bar: Player Stats System

!!! warning

    None of the methods for collecting stats are going to be reliable if
    [`get5_check_auths`](../configuration/#get5_check_auths) is set to `0`.

## SourceMod Forwards {: #forwards }

If you're writing your own plugin, you can collect stats from the game using the
[forwards](./events_and_forwards.md) provided by Get5.

## KeyValue System {: #keyvalue }

Get5 will automatically record basic stats for each player for each map in the match. These are stored in an internal
KeyValues structure, and are available at any time during the match (including the postgame waiting period) via the
`Get5_GetMatchStats` native and the [`get5_dumpstats`](../commands/#get5_dumpstats) command.

The root level contains data for the full series; the series winner (if one exists yet) and the series type (
bo1, bo3, etc).

Under the root level is a level for each map (`map0`, `map1` etc.), which contains the map winner (if one exists yet),
the map name and the demo file recording.

Under the map level is a section for each team (`team1` and `team2`), which contains the current team score (on
that map) and the team name.

Each player has a section under the team level under the section name of their SteamID 64. It contains all the personal
level stats: name, kills, deaths, assists, etc.

Partial Example:

```
"Stats"
{
	"series_type"       "bo1"
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
				"deaths"    "1"
				"assists"	"5"
				"damage"	"352"
			}
		}
	}
}
```

!!! question "What stats are collected?"

    See the [get5.inc include file](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc#L1769) for
    what stats will be recorded and what their keys are in the KeyValue structure.

## MySQL Statistics {: #mysql }

Get5 ships with a (disabled by default) plugin called `get5_mysqlstats` that will save many of the stats to a MySQL
database. You can use the included plugin as a source of inspiration and build your own to collect even more stats, or
even wrap a website around it for managing matches. The included plugin is meant as a proof-of-concept of this
functionality, but can also be used as-is.

!!! danger "Fixed Match IDs"

    If you use the MySQL extension, you should **not** set the `matchid` in your
    [match configuration](../match_schema/#schema) (just leave it empty) or when creating scrims or matches using the
    [`get5_scrim`](../commands/#get5_scrim) or [`get5_creatematch`](../commands/#get5_creatematch) commands. The match
    ID will be set to the
    [auto-incrementing integer](https://dev.mysql.com/doc/refman/8.0/en/example-auto-increment.html) (cast to a string)
    returned by inserting into the `get5_stats_matches` table.

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
    network location, and you can replace this with `@'localhost'` if your database is running on the same host as the
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
