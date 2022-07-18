# Player Stats System

When a get5 match is live, the plugin will automatically record match stats for each player, across each map in the
match. These are recorded in an internal KeyValues structure, and are available at any time during the match (including
the postgame waiting period) via the `Get5_GetMatchStats` native and
the [`get5_dumpstats`](./commands.md#serveradmin-commands) command.

Note: the stats collection is not going to be reliable if
using [`get5_check_auths 0`](./configuration.md#server-setup).

## SourceMod Forwards

If you're writing your own plugin, you can collect stats from the game using the
[forwards](./event_logs.md) provided by Get5.

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

## What Stats Are Collected

See the [get5 include](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc#L171) for what stats will
be recorded and what their key in the keyvalues structure is.

## MySQL Statistics

Get5 ships with a (disabled by default) plugin called `get5_mysqlstats` that will save many of the stats to a MySQL
database. To use this:

- Create the tables using this [schema](https://github.com/splewis/get5/blob/master/misc/import_stats.sql), raw text
  link can be found [here](https://raw.githubusercontent.com/splewis/get5/master/misc/import_stats.sql).
- Configure a `"get5"` database section in `addons/sourcemod/configs/databases.cfg`.
- Make sure the `get5_mysqlstats` plugin is enabled (moved up a directory from `addons/sourcemod/plugins/disabled`
  directory).

**Note**: If you use this module, you can force the match ID used by setting it in your match config
(the [Match Schema](./match_schema/#optional-values) section). If you don't do this, the match ID will be set to the
auto-incrementing integer (cast to a string) returned by inserting into the `get5_stats_matches` table.

If you are using an external web panel, **this plugin is not needed** as most external applications record to their own
match tables.
