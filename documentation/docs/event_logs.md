# Event Logs

Get5 contains an event-logging system that logs many client actions and what is happening in the game. These supplement
the logs CS:GO does on its own, but adds additional information about the ongoing match.

An `event` is a json object that looks something like this:

```json
{
  "matchid": "1",
  "event": "series_start",
  "params": {
    "team1_name": "EnvyUs",
    "team2_name": "Fnatic"
  }
}
```

Events will have variable parameters depending on what type of event it is. In the example, we see the event name is "
series_start". All events include the "matchid" field and have a name under `event`.

## Interfacing With Events

From a plugin, you can use the `void Get5_OnEvent(const char[] eventJson)` forward to do anything you like with Get5
events.  
You can also use the builtin server `logaddress_add` command to add a server `ip:port` that is listening to the game
server log and reading events (it could also read plain CS:GO server log lines - this is
what [eBot](https://github.com/deStrO/eBot-CSGO) does).

Finally, event can be logged to a file by settting
the [`get5_event_log_format`](./get5_configuration.md#file-name-formatting) cvar. The file will look something like
this:

```log
L 11/26/2016 - 02:58:39: {
    "matchid": "example_match",
    "event": "series_start",
    "params": {
        "team1_name": "EnvyUs",
        "team2_name": "Fnatic"
    }
}
```

You'd have to do some processing to handle parsing the logging timestamp before each json event, but it isn't very
hard (a simple regex replacement would be fine).

## List of Events and Their Params

Some rules are followed in these settings:

1. `Winner` is a match team, i.e. `team1` or `team2`
2. `team` is a match team, i.e. `team1` or `team2`
3. `side` is a CS team, i.e. `CT` or `T`
4. `map_number` is 0-indexed
5. `client` fields (`client`, `attacker`, `victim`, etc.) will use `%L` SourceMod formatting
6. `site` is `"A"` or `"B"`

### Series Flow

*The events listed below are rather self-documenting in a sense as to when they will be called.*.

- `series_start`:
    - `team1_name`: The formatted team name for `team1`
    - `team2_name`: The formatted team name for `team2`
- `series_end`:
    - `team1_series_score`: The score of the series for `team1` (how many maps won).
    - `team2_series_score`: The score of the series for `team2` (how many maps won).
    - `winner`: Either `"team1"`, `"team2"`, or `"none"`.
- `series_cancel`: Called if a series is cancelled.
    - `team1_series_score`: The score of the series for `team1` (how many maps won).
    - `team2_series_score`: The score of the series for `team2` (how many maps won).
- `map_veto`:
    - `team`: Either `"team1"`, `"team2"` or `"none"` if it is a decider.
    - `map_name`: The name of the map being vetoed.
- `map_pick`:
    - `team`: Either `"team1"`, `"team2"` or `"none"` if it is a decider.
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The map number of which it will be played in the series.
- `side_picked`:
    - `team`: Either `"team1"`, `"team2"` or `"none"` if it is a decider.
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The map number of which it will be played in the series.
    - `side`: The enum for the side selected. Either `CS_TEAM_CT` or `CS_TEAM_T`.

### Map Flow

- `knife_start`
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
- `knife_won`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `winner`: Either `"team1"`, `"team2"`, or `"none"`.
    - `selected_side`: The enum for the side selected. Either `CS_TEAM_CT` or `CS_TEAM_T`.
- `going_live`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
- `round_end`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `winner_side`: String value of which team won. Either `"T"` or `"CT"`.
    - `winner`: Either `"team1"`, `"team2"`.
    - `team1_score`: The current score for `team1`.
    - `team2_score`: The current score for `team2`.
    - `reason`: The number that represents
      the [CSRoundEndReason](https://sm.alliedmods.net/new-api/cstrike/CSRoundEndReason)
- `side_swap`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `team1_side`: String value of which team is on which side. Either `"T"` or `"CT"`.
    - `team2_side`: String value of which team is on which side. Either `"T"` or `"CT"`.
    - `team1_score`: The current score for `team1`.
    - `team2_score`: The current score for `team2`.
- `map_end`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `winner`: Either `"team1"`, `"team2"`.
    - `team1_score`: The current score for `team1`.
    - `team2_score`: The current score for `team2`.
- `pause_command`: Called when a team calls any type of pause.
    - `request_team`: Either `"team1"`, `"team2"` or `"none"`.
    - `pause_reason`: Either `"technical"` or `"tactical"`.
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
- `unpause_command`: Called when a team calls unpause.
    - `request_team`: Either `"team1"`, `"team2"` or `"none"`.
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.

### Client Actions

- `player_death`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `attacker`: The name plus steam ID of the attacker.
    - `victim`: The name plus steam ID of the victim.
    - `headshot`: Boolean value if the death was from a headshot.
    - `weapon`: String value of the weapon used.
    - `assister`: The name plus steam ID of an optional assister.
    - `flash_assister`: The name plus steam ID of an optional flashbang assister.
- `bomb_planted`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `client`: The name plus steam ID of the client who planted the bomb.
    - `site`: Either `"A"` or `"B"`.
- `bomb_defused`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `client`: The name plus steam ID of the client who defused the bomb.
    - `site`: Either `"A"` or `"B"`.
- `bomb_exploded`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `client`: The name plus steam ID of the client who planted the bomb.
    - `site`: Either `"A"` or `"B"`.
- `client_say`: Whenever a client says something in text chat, either team or all chat.
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `client`: The name plus steam ID of the client who sent a message.
    - `message`: The message that the client had said.
- `player_connect`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `client`: The name plus steam ID of the client who connected.
    - `ip`: String value of the client's IP address.
- `player_disconnect`:
    - `map_name`: The name of the map being vetoed.
    - `map_number`: The current map number.
    - `client`: The name plus steam ID of the client who disconnected.

### Miscellaneous

- `match_config_load_fail`:
    - `reason`: Reason as to why the match configuration failed to load.
- `backup_loaded`:
  `file`: Location of the backup.
- `team_ready`
    - `team`: Either `"team1"`, `"team2"`, or `"spec"` if spectators are required to ready.
    - `stage`: one of `"veto"`, `"backup_restore"`, `"knife"`, or `"start"`
