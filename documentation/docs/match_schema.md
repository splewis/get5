# Match Schema

Inside this repo are two files that give a general idea of what can be included in a match config. A Valve KeyValue
format can be found [here](https://github.com/splewis/get5/blob/master/configs/get5/example_match.cfg), and a JSON
format can be found [here](https://github.com/splewis/get5/blob/master/configs/get5/example_match.json). In this
documentation, we'll go through what each value means, but do note that **only the values** `team1` and `team2` are
required to start a match, which can be seen in the next section. Reasonable defaults are used for entries (bo3 series,
5v5, empty strings for team names, etc.). We recommend using the JSON format whenever possible.

## Required Values (The Team Schema)

There are quite a few values that are also optional within the team schema, but we will outline what they are all
intended for. Realisitcally, if you want to setup a quick match, only the `name` and `players` are required to set up a
match.

- `name`: The team name (wraps `mp_teamname_1` and is displayed often in chat messages).
- `tag`: The team tag (or short name), this replaces client "clan tags".
- `flag`: The team flag (2 letter country code, wraps `mp_teamflag_1`), list of country codes for CS:GO can be
  found [here](https://steamcommunity.com/sharedfiles/filedetails/?id=719079703).
- `logo`: The team logo (wraps `mp_teamlogo_1`), which requires to be on a FastDL in order for clients to see, or users
  may download another [SourceMod plugin](https://forums.alliedmods.net/showthread.php?t=258206).
- `players`: A list of Steam ID's for users on the team (not used if `get5_check_auths` is set to `0`). You can also
  force player names in here; in JSON you may use either an array of steamids or a dictionary of Steam IDs to names.
  Both ways are shown in the above example.
- `series_score`: The current score in the series, this can be used to give a team a map advantage or used as a manual
  backup method, defaults to `0`.
- `matchtext`: Wraps `mp_teammatchstat_1`, you probably don't want to set this, in BoX series `mp_teamscore` cvars are
  automatically set and take the place of the `mp_teammatchstat` cvars.
- `coaches`: Identical to the `players` tag, it's an optional list of Steam ID's for users who wish to coach a team.
  You may also force player names here. This field is optional.

## Optional Values

- `matchid`: A string matchid used to identify the match.
- `num_maps`: Number of maps in the series. This must be an odd number or 2.
- `maplist`: List of the maps in use (an array of strings in JSON, mapnames as keys for KeyValues), you should always
  use an odd-sized maplist
- `skip_veto`: Whether the veto will be skipped and the maps will come from the maplist (in the order given).
- `veto_first`: Either "random", "team1", or "team2". If not set, or set to any other value, "team1" will veto first.
- `side_type`: Either "standard", "never_knife", or "always_knife"; "standard" means the team that doesn't pick a map
  gets the side choice, "never_knife" means "team1" is always on CT first, and "always_knife" means there is always a
  knife round.
- `players_per_team`: Maximum players per team (doesn't include a coach spot, default: 5).
- `coaches_per_team`: Maximum coaches per team (default: 2).
- `min_players_to_ready`: Minimum players a team needs to be able to ready up (default: 1).
- `favored_percentage_team1`: Wrapper for the servers `mp_teamprediction_pct`.
- `favored_percentage_text` Wrapper for the servers `mp_teamprediction_txt`.
- `cvars`: Cvars to be set during the match warmup/knife round/live state. **These will override all other settings** (
  standard CS:GO cvars are also supported).
- `match_title`: Wrapper on the servers `mp_teammatchstat_txt` cvar, but can use {MAPNUMBER} and {MAXMAPS} as variables
  that get replaced with their integer values. In a BoX series, you probably don't want to set this since Get5
  automatically sets `mp_teamscore` cvars for the current series score, and take the place of the `mp_teammatchstat`
  cvars.

## Managing Match Configs

### Going *laissez faire*

The cvar `get5_check_auths` (which you should set in `cfg/sourcemod/get5.cfg`, or the match config cvars section) can be
set to `0`, which will stop the plugin from forcing players onto the correct team. This means the players section will
not be used, and can be omitted if you don't want to set everyone's Steam ID.

This is **generally not recommended**, as there are great advantages to letting the plugin handle forcing players onto
the correct teams and kicking people that shouldn't be in the server.

### Managing Team Data From Separate Files

One strategy for storing all the team data is to create a config for each team, then you can use the `fromfile` field
when creating match configs.

By using this strategy, you would:

- Create a team config file for every team in your tournament/league/etc.
- When a match is played, update the server's match config `team1:fromfile` and `team2:fromfile` fields.

Here is an example `match.cfg` that includes `fromfile`:

```cfg
"Match"
{

	"maps_to_win"		"1"
	"skip_veto"		"0"
	"side_type"		"standard"

	"maplist"
	{
		"de_cache"		""
		"de_cbble"		""
		"de_dust2"		""
		"de_mirage"		""
		"de_nuke"		""
		"de_overpass"		""
		"de_train"		""
	}

	"players_per_team"		"5"

	"team1"
	{
		"fromfile"		"addons/sourcemod/configs/get5/team_nip.cfg"
	}

	"team2"
	{
		"fromfile"		"addons/sourcemod/configs/get5/team_nv.cfg"
	}

	"cvars"
	{
		"hostname"		"Match server #1"
	}
}
```

Inside the `team_nip.cfg` would be the following:

```cfg
"team"
{
	"name"		"NiP" 
	"flag"		"SE"
	"logo"		"nip"
	"matchtext"		""
	"players"
	{
		"STEAM_1:1:52245092"		""
	}
}
```

And inside `team_nv.cfg` would be the following:

```cfg
"team"
{
	"name"		"EnvyUs" 
	"flag"		"FR"
	"logo"		"nv"
	"matchtext"		""
	"players"
	{
		"STEAM_1:0:78189799"		""
	}
}
```

Please note that this works for both KeyValue and JSON formatted configs.
