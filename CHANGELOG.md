# Get5 Changelog

### Updating

Whenever you update your Get5 plugin, remember to **always** update the `translations` folder. If you only replace the
`.smx` files, Get5 will likely error as translations are often changed between versions.

Please see the [installation instructions](https://splewis.github.io/get5/latest/installation/#installation) for
details.

# 0.14.0

⚠️ PRERELEASE

#### 2022-03-09

### Breaking Changes 🛠

1. The `Get5_OnPlayerSay` event now includes messages sent from Console (or potentially GOTV). You should filter out
   these messages on your end if you don't want to react to them. Note that console is always `user_id` 0 and GOTV's
   name is always `GOTV`. Alternatively, you can ignore all messages with an empty `steamid`.
2. The [stats system](https://splewis.github.io/get5/latest/stats_system/#keyvalue) has been updated. This means that
   the structure has been modified to allow for more information, specifically the starting side and score for each side
   for each team.

   **If you use any of the stats extensions, you must also update those plugins (`get5_mysqlstats.smx`
   and `get5_apistats.smx`)!**

   Keys changed for each team (i.e. `map0 -> team1`):
    1. Players' SteamIDs and stats have moved from the root of the team object into a key called `players`.
    2. Added `score_ct`
    3. Added `score_t`
    4. Added `starting_side` (`2` for T, `3` for CT as this is an integer enum)
3. The structure of the `Get5_OnRoundEnd` JSON event has changed (not to be confused with the KeyValues file in #2
   above):

   `teamX_score` (int) has been replaced by an object called `teamX`, which looks like this.

   Old:
   ```json
   {
     "event": "round_end",
     "matchid": "29844",
     "map_number": 0,
     "map_name": "de_dust2",
     "round_number": 21,
     "round_time": 34944,
     "reason": 8,
     "winner": {
       "team": "team1",
       "side": "ct"
     },
     "team1_score": 10,
     "team2_score": 12
   }
   ```
   New:
   ```json
   {
     "event": "round_end",
     "matchid": "29844",
     "map_number": 0,
     "map_name": "de_dust2",
     "round_number": 21,
     "round_time": 34944,
     "reason": 8,
     "winner": {
       "team": "team1",
       "side": "ct"
     },
     "team1": {
       "name": "TeamName",
       "score": 10,
       "score_ct": 4,
       "score_t": 6,
       "side": "t",
       "starting_side": "ct",
       "players": [
         {
           "name": "Nyxi",
           "steamid": "76561197996426755",
           "stats": {
             // Full player stats.
           }
         }
       ]
     },
     // same for "team2"
   }
   ```

   This affects the `Get5_OnRoundEnd` forward as well, so if you have a plugin that reads this data, you must update it.
   For full details and the SourceMod properties, see
   the [event documentation](https://splewis.github.io/get5/dev/events_and_forwards/#events).

### New Features / Changes 🎉

1. Get5 is now built with SourceMod 1.11.
2. The JSON "pretty print" spacing string has changed from 4 spaces to 1 tab. This is strictly because there is a 16KB
   max buffer size in SourceMod, which we come dangerously close to when posting the full player stats via JSON. If you
   play 6v6 or 7v7, you may need to
   set [`get5_pretty_print_json 0`](https://splewis.github.io/get5/latest/configuration/#get5_pretty_print_json) to
   avoid hitting the limit. You **will** see an error in console if this happens.
3. The `get5_mysqlstats` extension now uses a transaction to update stat rows for each player. This improves performance
   via reduced I/O between the game server and the database server.
4. The [documentation of events](https://splewis.github.io/get5/dev/events_and_forwards/#events) is now rendered
   on `https://redocly.github.io` instead of being embedded in the Get5 documentation website. This allows for more
   space and makes it easier to browse/read.

# 0.13.0

#### 2022-02-18

### Breaking Changes 🛠

1. The [map selection](https://splewis.github.io/get5/latest/veto/) ("veto") system has been entirely reworked and can
   now be customized. Please see the development [documentation](https://splewis.github.io/get5/latest/veto/) for
   details. It is now also chat-based instead of using in-game menus. As the map selection system uses the `!ban`
   command, Get5 will now unload the default `basebans.smx` SourceMod plugin to prevent conflicts, as this also uses
   the `!ban` command. You are encouraged to instead simply remove this plugin from your server (delete it or move it to
   the `disabled` folder).
2. `Get5_OnMatchUnpaused`'s `team` property now always reflects the team that started the pause. Previously, this would
   be the team that triggered the unpause.
3. Technical pauses can now be enabled without enabling tactical pauses. Previously, you would have to enable tactical
   pauses via [`get5_pausing_enabled`](https://splewis.github.io/get5/latest/configuration/#get5_pausing_enabled) to
   have access to technical pauses
   via [`get5_allow_technical_pause`](https://splewis.github.io/get5/latest/configuration/#get5_allow_technical_pause).
   These have now been decoupled.
4. [`get5_server_id`](https://splewis.github.io/get5/latest/configuration/#get5_server_id) is now a string instead of an
   integer, which changes a few things:

   4.a. If you use the default MySQL extension for stats, you must run this command to make your `server_id` column
   accept a string. If you don't run this, **and** you set a non-integer value as your `get5_server_id`, your server
   will error. If you continue to use a regular integer for the cvar, it will still work without modifying your database
   schema. `get5_server_id` also still defaults to `"0"` for backwards compatibility.

   ```mysql
   ALTER TABLE `get5_stats_matches`
       MODIFY COLUMN `server_id` VARCHAR(64) NOT NULL DEFAULT '0'
   ```

   4.b. The native has changed from:

   ```c
   native int Get5_GetServerID();
   ```

   to this, accepting a buffer instead of returning an integer:

   ```c
   native void Get5_GetServerID(char[] id, int length);
   ```

5. [`get5_surrender_required_votes`](https://splewis.github.io/get5/latest/configuration/#get5_surrender_required_votes)
   is now limited by the value provided to `players_per_team`, so you will not have a situation where you don't have
   enough players to successfully vote to surrender.
6. Pauses are not consumed until they actually start, which means they can be canceled if you `!unpause` before the
   round ends. This behavior can be controlled
   via [`get5_allow_pause_cancellation`](https://splewis.github.io/get5/latest/configuration/#get5_allow_pause_cancellation).

### New Features / Changes 🎉

1. Admins can now use the
   command [`get5_add_ready_time`](https://splewis.github.io/get5/latest/commands/#get5_add_ready_time) to add more time
   during ready-up phases if a team needs more time.
2. Tactical pauses now default to 60 seconds fixed-duration
   via [`get5_fixed_pause_time`](https://splewis.github.io/get5/latest/configuration/#get5_fixed_pause_time) instead of
   a total pause time of 300
   via [`get5_max_pause_time`](https://splewis.github.io/get5/latest/configuration/#get5_max_pause_time). This changes
   nothing for existing servers and only affects new installations of Get5.
3. The in-game pause counters are now used for tactical timeouts, which makes them work properly with various GOTV
   overlays.
4. To bring pauses more in line with the built-in ones, the ability to unpause fixed-duration tactical pauses if both
   teams `!unpause` can now be disabled
   via [`get5_allow_unpausing_fixed_pauses`](https://splewis.github.io/get5/latest/configuration/#get5_allow_unpausing_fixed_pauses).
5. There is a new [forward/event](https://splewis.github.io/get5/latest/events_and_forwards/)
   called `Get5_OnPauseBegan`, which fires when a pause begins, unlike `Get5_OnMatchPaused`, which fires when pause is
   called by a player, even if it does not begin until the next round.
6. If the map the server is on also happens to be the first map to be played after map selection, the server will not
   reload and ask everyone to ready, but instead simply start the match.
7. Get5 now speaks Greek, Turkish and Swedish. (Thanks @GekasD, AliOnIce and OmegaSkid, respectively).
8. You can now add Workshop maps to the [`maplist`](https://splewis.github.io/get5/latest/match_schema/#schema). Please
   note that this *requires* a [Steam Web API key](https://steamcommunity.com/dev), or your match configuration will
   fail to load.
9. Get5 now officially supports [Wingman](https://splewis.github.io/get5/latest/wingman). If you are upgrading a Get5
   installation, remember to copy in the new wingman config file from `cfg/get5/live_wingman.cfg` if you want to run
   Wingman matches.
10. [`get5_pause_on_veto`](https://splewis.github.io/get5/latest/configuration/#get5_pause_on_veto) now defaults to
    enabled for new installations.
11. You can now
    set [`get5_kick_on_force_end 1`](https://splewis.github.io/get5/latest/configuration/#get5_kick_on_force_end)
    if you want [`get5_endmatch`](https://splewis.github.io/get5/latest/commands/#get5_endmatch) to adhere to the value
    of [`get5_kick_when_no_match_loaded`](https://splewis.github.io/get5/latest/configuration/#get5_kick_when_no_match_loaded).

# 0.12.1

#### 2022-01-16

## What's Changed

This is a bugfix release. There are no breaking changes or translation changes, so you only need to replace
the `get5.smx` for this one.

_If_ you use the `Get5_OnEvent` forward in another plugin, please make sure it still works. It had wrong syntax, so it's
unlikely you would have been using it in its previous format anyway.

### Bug Fixes 🐞

* Fix syntax error for SM 1.11+ in the `Get5_OnEvent` forward. @hammy2899 in https://github.com/splewis/get5/pull/964
* Fix a problem
  where [`get5_demo_delete_after_upload`](https://splewis.github.io/get5/latest/configuration/#get5_demo_delete_after_upload)
  was not working if [`get5_demo_path`](https://splewis.github.io/get5/latest/configuration/#get5_demo_path) was set.
  @nickdnk in https://github.com/splewis/get5/pull/965

## New Contributors

* @hammy2899 made their first contribution in https://github.com/splewis/get5/pull/964

**Full Changelog**: https://github.com/splewis/get5/compare/v0.12.0...v0.12.1

# 0.12.0

#### 2022-12-25

## What's Changed

0.12 is now available. A bunch of stuff has been improved, bugs have been fixed and new features have been introduced.
Please test it out and report any problems. As always, remember to update your `translations` folder and read the
breaking changes (since 0.11).

Translations are still a bit hit-and-miss for some languages, so if you want to help complete them, head over
to [the documentation](https://splewis.github.io/get5/latest/translations/) for instructions on how to help.

### Breaking Changes 🛠

1. `Get5-DemoName` header when uploading demos has been renamed to `Get5-FileName`, as this now also applies to
   uploading backups.
2. Player connect/disconnect events/forwards now only fire when a match config is loaded (but now include `matchid`).
3. You must now
   provide [`get5_time_to_start_veto`](https://splewis.github.io/get5/latest/configuration/#get5_time_to_start_veto)
   separately from [`get5_time_to_start`](https://splewis.github.io/get5/latest/configuration/#get5_time_to_start). If
   you don't set this variable, players will have infinite time to ready for veto.
4. `maplist` is now required in match configurations. There is now no "default map list" in Get5.
6. The `filename` property of the `demo_finished` and `demo_upload_ended` events now includes the folder, i.e. the full
   path to the file, if [`get5_demo_path`](https://splewis.github.io/get5/latest/configuration/#get5_demo_path) is set.
7. `Get5_OnPreLoadMatchConfig()` no longer fires when loading a backup file.
8. If you use `fromfile`, make sure to always have JSON files end with `.json`, or Get5 will assume they are KeyValues,
   regardless of the format of the match config.

### New Features 🎉

1. You can now opt to disable the [`!stop`](https://splewis.github.io/get5/latest/commands#stop) command
   using [`get5_stop_command_no_damage`](https://splewis.github.io/get5/latest/configuration/#get5_stop_command_no_damage)
   and [`get5_stop_command_time_limit`](https://splewis.github.io/get5/latest/configuration/#get5_stop_command_time_limit).
2. Bots are now considered players in deciding the knife round winner and will also trigger 1vX player stats.
3. You can now use [`fromfile`](https://splewis.github.io/get5/latest/match_schema/#schema) when loading
   both `maplist`, `spectators` and `team1/team2` in the match configurations, and both JSON and KeyValues is supported.
4. You can use [`{TEAM1_SCORE}`](https://splewis.github.io/get5/latest/configuration/#tag-team1-score)
   and [`{TEAM2_SCORE}`](https://splewis.github.io/get5/latest/configuration/#tag-team2-score)
   in [`get5_hostname_format`](https://splewis.github.io/get5/latest/configuration/#get5_hostname_format).
5. ConVars can now be up to 512 characters, previously limited to 128. Note that the source of setting Cvars might
   impose a shorter length (direct console input seems to only allow up to around 128, but `get5.cfg` allows you to set
   up to 512). Your mileage may vary.
6. You can prevent Get5 from restoring parameters provided in the `cvars` section of a match configuration to their
   pre-Get5-value
   using [`get5_reset_cvars_on_end`](https://splewis.github.io/get5/latest/configuration/#get5_reset_cvars_on_end) -
   this is useful if you only use Get5 and want to provide parameters in your configs that don't like to be reset when
   the series ends.
7. You can now [automatically upload backups](https://splewis.github.io/get5/latest/backup/#upload) and also load
   backups from a remote URL
   using [`get5_loadbackup_url`](https://splewis.github.io/get5/latest/commands/#get5_loadbackup_url).
8. All HTTP requests sent by Get5 (loading match config, loading backup, uploading demo, uploading backup, sending
   events) now include a `Get5-Version` HTTP header with the SemVer of Get5 (i.e. `0.12.0` or `0.12.0-353cee5` for a
   nightly), so you can gracefully handle breaking changes on the server-side - *or* outright refuse to communicate with
   an outdated server.
9. You can now add [custom aliases](https://splewis.github.io/get5/latest/commands/#custom-chat-commands) to all chat
   commands.

### Bug Fixes 🐞

1. Fixed a problem where players at index 0 in JSON match configurations were not elected as captains for veto.
2. Increased max heap size from 4kb to 128kb to prevent various out-of-memory errors (Thanks @thelitlej).
3. Fixed a problem with the backup system that would cause problems if restoring from the first round of the second half
   to any round in the first half.
4. Lots of improvements to error handling/feedback related to match loading, team loading and backups.
5. The hostname set
   via [`get5_hostname_format`](https://splewis.github.io/get5/latest/configuration/#get5_hostname_format) now properly
   resets when a series ends.
6. Fixed a problem where loading a backup on a non-live server that happens to be on the correct map would not trigger a
   ready-up for backup restore, but instead immediately load the backup.
7. Players are no longer marked as ready if they suicide in warmup
   when [`get5_auto_ready_active_players`](https://splewis.github.io/get5/latest/configuration/#get5_auto_ready_active_players)
   is enabled (killed via `!coach` for instance).

## New Contributors

* @thelitlej made their first contribution in https://github.com/splewis/get5/pull/944

**Full Changelog**: https://github.com/splewis/get5/compare/v0.11.0...v0.12.0

# 0.11.0

#### 2022-11-03

## What's Changed

* Improved communication to players about the use/availability of `!coach`, `!ready` and `!unready` commands during
  warmup, depending on match and individual player state.
* Doubled duration of
  the [auto ready](https://splewis.github.io/get5/latest/configuration/#get5_auto_ready_active_players) hint so players
  are less likely to miss it.
* Consumed pauses are now included in backups, so they can be properly restored if the game state is lost or if a new
  server is needed.
* The [`Get5_OnSeriesResult`](https://splewis.github.io/get5/latest/events_and_forwards/) event/forward now has
  a `time_to_restore` property, letting you know how long until Get5 no longer manages the server and GOTV broadcast has
  ended.
* Demos are no longer split into two files if you
  use [`get5_loadbackup`](https://splewis.github.io/get5/latest/commands/#get5_loadbackup) for the **same match and map
  ** during the live phase.
* Prevent suicide via console using `kill` or `explode`.
* Updated German translation. (Thanks @Apfelwurm)
* Updated French translation. (Thanks @Iwhite67 @Gryfenfer97 @Maruchun0)
* Updated Russian translation. (Thanks @Saph1s)
* Updated Hungarian translation. (Thanks @enerbewow)
* Updated Portuguese transaltion. (Thanks @SidiBecker and Nathy)
* Updated Danish translation. (@nickdnk)
* Improved Polish and Spanish translation. (Thanks axsusxd)
* Lots of improvements to [the documentation](https://splewis.github.io/get5/latest).
* Lots of improvements to CI (Thanks @PhlexPlexico @Apfelwurm).

### Breaking Changes 🛠

* The format of Get5 [backup files](https://splewis.github.io/get5/latest/backup/#how-to) has changed to now
  include `get5_server_id` to prevent backup file collisions.
* The `mp_backup_round_file` convar is now managed by Get5 automatically and also uses `get5_server_id` to prevent file
  collisions.
* Backup files made with previous versions of Get5 cannot be used.
* The built-in backup files created by the game (`backup_round00.txt` etc.) are now removed automatically by Get5 when
  merged into the Get5 backup system.
* A new [game state](https://splewis.github.io/get5/latest/commands/#get5_status) has been
  introduced: `pending_restore`, which is used when changing to a different map during a restore from backup.
  Previously, this would be either `live` or `warmup`.
* Removed `get5_end_match_on_empty_server` as it was unreliable and buggy. You should instead use the
  new [forfeiting system](https://splewis.github.io/get5/latest/surrender-forfeit/#forfeit) for similar behavior.

### New Features 🎉

* Access to the [`!forceready`](https://splewis.github.io/get5/latest/commands/#forceready) command can now be disabled
  with [`get5_allow_force_ready`](https://splewis.github.io/get5/latest/configuration/#get5_allow_force_ready). (
  @nickdnk)
* You can
  now [automatically start a tech pause](https://splewis.github.io/get5/latest/configuration/#get5_auto_tech_pause_missing_players)
  if enough players leave a team. (@nickdnk)
* All Get5 events can now be sent as [JSON over HTTP](https://splewis.github.io/get5/latest/events_and_forwards/#http)
  to any remote host. (@nickdnk)
* A new system for [surrendering and forfeiting](https://splewis.github.io/get5/latest/surrender-forfeit/) has been
  introduced. Note that the [forfeit](https://splewis.github.io/get5/latest/surrender-forfeit/#forfeit) system is *
  *enabled** by default, so you must turn it off if you don't want it. (@nickdnk)
* You can now automatically [upload demos over HTTP](https://splewis.github.io/get5/latest/gotv/#upload) when recording
  ends. (@PhlexPlexico and @nickdnk)
* [Demos](https://splewis.github.io/get5/latest/configuration/#get5_demo_path)
  and [backups](https://splewis.github.io/get5/latest/configuration/#get5_backup_path) can now be stored in
  subfolders. (@PhlexPlexico and @nickdnk)
* [`get5_loadmatch_url`](https://splewis.github.io/get5/latest/commands/#get5_loadmatch_url) now takes optional header
  key/value arguments to allow for authorization. (@Apfelwurm)
* You can now choose to include coaches in the `!ready`-system using the `coaches_must_ready` property in
  your [match configuration](https://splewis.github.io/get5/latest/match_schema/#schema). (@nickdnk)

### Bug Fixes 🐞

* Fixed a problem where players would sometimes spawn in odd places when auto-placed onto teams when joining the server.
* Fixed a problem where you could not join a team even if no Get5 match configuration was loaded.
* Fixed a problem where a "CTs win!" callout would be heard as warmup ended, messing up the start of the knife round.
* Added missing `Player` property to the `Get5PlayerSayEvent`.
* Fixed a problem where the use of numbers in the cvars section of JSON match configurations would result in undefined
  behavior.
* Fixed a bunch of issues with runaway timers causing problems if ending and restarting matches at various times, such
  as when waiting for a map change or a knife round decision.
* We now prevent users from loading backups when it is not safe, and from issuing various commands that are not safe
  while waiting for a backup. This could cause all kinds of problems.
* We now prevent multiple backups from being loaded on top of each other if multiple `!stop` or `get5_loadbackup`
  commands are issued in succession.
* We no longer stop recording demos right after a match ends if there is a non-zero `tv_delay`, as it would cause the
  GOTV broadcast to freeze when the file is flushed to disk. This is a Valve bug we can only work around.

...and many, many more minor adjustments and tweaks. As always, big thanks to everyone who helped test and provide
feedback on all the changes since 0.10, especially to OmegaSkid from SCL and @LukasW1337 from HLTV for daring to run
nightly builds in production.

If I forgot to tag someone for something you helped with, @nickdnk.

**Full Changelog**: https://github.com/splewis/get5/compare/v0.10.5...v0.11.0

# 0.10.5

#### 2022-10-04

## What's Changed

Small hotfix. Should have been in 0.10.4, but hindsight 20/20.

### Bug Fixes 🐞

* Remove team `[READY]` tags if there is no knife round. https://github.com/splewis/get5/pull/890.

**Full Changelog**: https://github.com/splewis/get5/compare/v0.10.4...v0.10.5

# 0.10.4

#### 2022-10-03

## What's Changed

This is a bug-fix release.

### Bug Fixes 🐞

* Fixed a case where multiple calls to [`!stop`](https://splewis.github.io/get5/latest/commands/#stop) (such as all
  players spamming it) would cause Get5 to load multiple backups on top of each
  other. https://github.com/splewis/get5/pull/887.
* Fixed some lingering issues with timing of [`!stay`](https://splewis.github.io/get5/latest/commands/#stay)
  or [`!swap`](https://splewis.github.io/get5/latest/commands/#swap) which were thought to have been fixed
  in [0.10.3](https://github.com/splewis/get5/releases/tag/v0.10.3). To truly mitigate this problem, you now cannot
  elect to stay or swap until the knife round has completely ended and the game has returned to warmup mode. The
  default `mp_round_restart_delay` in the knife round has been reduced to 3 seconds, but you can set this even lower in
  the [knife.cfg](https://splewis.github.io/get5/latest/configuration/#phase-configuration-files) if you
  wish. https://github.com/splewis/get5/pull/888
* `g_KnifeWinnerTeam` now gets properly reset so that an unfortunately-timed restart of a match will not mess up the
  knife round. https://github.com/splewis/get5/pull/888

**Full Changelog**: https://github.com/splewis/get5/compare/v0.10.3...v0.10.4

# 0.10.3

#### 2022-09-16

This is strictly a bug-fix release. A problem has been identified and corrected that would cause a `!swap` or `!stay`
command issued in a 1-second gap right as the knife-round ends to send the game directly into live mode, skipping the
countdown, with an incorrect round number for the `Get5_OnRoundStart` event/forward.

## What's Changed

### Bug Fixes 🐞

* Fix problems with game going directly to live, skipping countdown.

**Full Changelog**: https://github.com/splewis/get5/compare/v0.10.2...v0.10.3

# 0.10.2

#### 2022-09-15

## What's Changed

* You can now define `spectators` in [scrim](https://splewis.github.io/get5/latest/getting_started/#scrims) templates.
* Some code was optimized and renamed.

### Bug Fixes 🐞

* Sorted some problems related to team assignment priority when players are defined in multiple places in the match
  configuration.

  Players are now consistently assigned a slot in this order:
    1. Spectator
    2. Coach for `team1`
    3. Coach for `team2`
    4. Player on `team1`
    5. Player on `team2`

  If not found in any of these places, or if their assignment has no free slots, players are removed from the server.

* The number of spectators cannot exceed `mp_spectators_max` and additional spectators will be kicked similarly to how
  players are kicked if a team is full.

**Full Changelog**: https://github.com/splewis/get5/compare/v0.10.1...v0.10.2

# 0.10.1

#### 2022-09-11

## What's Changed

A minor release here fixing some discovered problems with 0.10.0. There are no breaking changes.

### Bug Fixes 🐞

* The game no longer restarts (`mp_restartgame 1`) when loading a backup, as that would break some tournament logging
  systems. It now sends the game into warmup instead and then loads the backup.

* The secondary GOTV (`tv_enable1`) is no longer kicked when performing a
  team [`!swap`](https://splewis.github.io/get5/latest/commands/#swap). It also no longer announces
  2x `PlayerX is now coaching Team X` if you have coaches in the game.

* As version 0.10.0 did not really work
  with [`get5_check_auths`](https://splewis.github.io/get5/latest/configuration/#get5_check_auths) disabled, this has
  been remedied as well as it can. Note that running Get5 with team-locking disabled is discouraged and many things are
  not guaranteed to behave as you would expect. We recommend you leave it on (the default) and
  use [`get5_creatematch`](https://splewis.github.io/get5/latest/commands/#get5_creatematch) when players have joined
  the teams they want to be on, instead of loading match configurations with no SteamIDs in the teams. The coaching bug
  still exists if you use `!coach` without locking Steam IDs, as Get5 forwards to the internal `coach t` and `coach ct`
  commands in this case, which suffer from this problem, so beware of this! There is no coaching bug if locking the
  teams.

* Team names are now `team1` and `team2` internally if no team name was provided. The team name gets auto-corrected when
  a player joins a team (`team_PlayerName`), but in between this, the team names would be empty, causing some messages
  to misbehave.

**Full Changelog**: https://github.com/splewis/get5/compare/v0.10.0...v0.10.1

# 0.10.0

#### 2022-09-03

## What's Changed

Version 0.10.0 is now completed. **A lot** has changed in this release and many bugs have been fixed. This is probably
what version 0.9.0 *should* have been, so we strongly encourage everyone on 0.9.0 to upgrade to this version as soon as
possible.

### Breaking Changes 🛠

* If you are updating from a version prior to 0.9, please read the breaking changes for that release as
  well: https://github.com/splewis/get5/releases/tag/v0.9.0
* Removed deprecated `bo2_series` and `maps_to_win` match config parameters. Use `num_maps` and `clinch_series` to
  achieve similar behavior. See https://splewis.github.io/get5/latest/match_schema/#schema
* [`get5_creatematch`](https://splewis.github.io/get5/latest/commands/#get5_creatematch) had its argument order changed
  to match `get5_scrim`: https://github.com/splewis/get5/pull/806
* If you update to this version from a previous Get5 version, ensure you make the following changes to
  your [`cfg/sourcemod/get5.cfg`](https://splewis.github.io/get5/latest/configuration/#main-config) file:

  [`get5_time_format`](https://splewis.github.io/get5/latest/configuration/#get5_time_format) must
  be `"%Y-%m-%d_%H-%M-%S"` (or any equivalent with hours, minutes and seconds in it)
  [`get5_demo_name_format`](https://splewis.github.io/get5/latest/configuration/#get5_demo_name_format) must
  include `{TIME}`, i.e: `"{TIME}_{MATCHID}_map{MAPNUMBER}_{MAPNAME}"`

  If you don't make this change, your demos will be overwritten if you use the backup system!
* Backup files created with previous versions of Get5 will not work correctly.
* Backups are now never written for pre-veto or veto stages, as that would be equivalent to simply reloading the match
  configuration.
* The coaching and player team assignment system has been completely rewritten. The default `coach` console command is
  disabled, and you must use `!coach` in chat (or `sm_coach` in console) instead. You must also **never**
  set `players_per_team` to a value higher than the actual number of players you want on teams. If you don't use fixed
  coaches (that is, if you just put everyone in `players` and tell them to call `!coach`) and you want to be able to
  swap players for coaches, set `coaches_per_team` to 2 (or any higher value) to make room for a player to coach so that
  a coach can then become a player. Please consult
  the [coach documentation](https://splewis.github.io/get5/latest/coaching/) for details.
* Not exactly a breaking change, but we would strongly recommend you go over the `Prohibited options` section
  of https://splewis.github.io/get5/latest/configuration/#phase-configuration-files and remove any of those from
  your `live.cfg`, `warmup.cfg` and `knife.cfg` files, if they are present. These should also *not* go in your `cvars`
  section of a match configuration (except for `tv_delay`)!
* First kills and first deaths are now **per round**, not **per team per round
  **: https://github.com/splewis/get5/issues/660
* A new `coaching` key in the stats now indicates if a player was a coach, and coaches no longer have
  their `roundsplayed` stat increased/set.

### New Features 🎉

* A lot of updates to various parts of the documentation, which now also has versioning for latest and development.
* Added a new documentation section on GOTV: https://splewis.github.io/get5/latest/gotv/
* Added a new documentation section on coaching: https://splewis.github.io/get5/latest/coaching/
* Allow for setting the knife config file location: https://splewis.github.io/get5/latest/configuration/#get5_knife_cfg
* Allow for customizing team name colors: https://splewis.github.io/get5/latest/configuration/#get5_team1_color
* Added Hungarian translation.
* Added `!tac` pause alias: https://splewis.github.io/get5/latest/commands/#pause
* Added support for subfolders for
  backups: https://splewis.github.io/get5/latest/configuration/#get5_backup_path (https://github.com/splewis/get5/issues/344)
* Added option to disable clinching of a series, allowing for a full playout of the entire maplist, regardless if a
  series can no longer be won: See `clinch_series` in the match
  schema: https://splewis.github.io/get5/latest/match_schema/#schema (https://github.com/splewis/get5/issues/728)
* Added `{GOLD}` color option: https://splewis.github.io/get5/latest/configuration/#color-substitutes
* Added option to control the number of phase-change announcements, i.e. "Knife!" or "Match is LIVE" in
  chat: https://splewis.github.io/get5/latest/configuration/#get5_phase_announcement_count
* `get5_endmatch` now takes an optional `team1` or `team2` parameter, forcing that team to win the series when it
  ends: https://splewis.github.io/get5/latest/commands/#get5_endmatch (https://github.com/splewis/get5/issues/190)
* Player names in chat messages are now always formatted with colors corresponding to their team side.

### Known Issues

* https://github.com/splewis/get5/issues/549: If `get5_end_match_on_empty_server` is enabled, the entire match series
  will sometimes end on map changes or when first joining the server. This will be addressed in 0.11 which will also
  contain logic for surrendering. We recommend you disable `get5_end_match_on_empty_server` or live with this
  consequence.

### Bug Fixes 🐞

* Player stats are now initialized to zero: https://github.com/splewis/get5/pull/814
* Don't allow the use of `!ready` when a map change is pending: https://github.com/splewis/get5/pull/832
* Pause timer hints are now visible to GOTV clients: https://github.com/splewis/get5/pull/834
* Team ready-tags are now removed when the knife-round starts: https://github.com/splewis/get5/pull/846
* The knife-round now has correct call-out of the winning team, even if "CTs run down the
  clock": https://github.com/splewis/get5/pull/838
* A team's request to `!stop` is now reset when the round ends: https://github.com/splewis/get5/pull/854
* Added server collision protection to the `get5_names.txt` player name file.
* Pauses used/consumed are now stored in backup files.
* Fixed an invalid handle error when using `fromfile` when loading a team file in JSON.
* The `Get5_OnSeriesResult` foward/event is now called immediately as the series ends, not after GOTV has finished
  broadcasting: https://github.com/splewis/get5/pull/821
* Fixed a bunch of problems with backups, such as map draws breaking it completely, players being put on the wrong side
  if restoring to a round after halftime or restoring to the last round of a match simply ending the match immediately.
* Fixed invalid handle error when ending a match during veto, then restarting the veto.
* GOTV broadcast delay now auto-adjusts `mp_match_restart_delay` so it is never too short.
* `cvars` of a match configuration are now always correctly applied **after** values in `knife.cfg`, `live.cfg`
  and `warmup.cfg`.
* Players joining a game during halftime are now automatically put on their team as soon as the next round starts.
* The `Get5_OnBackupRestore` forward now correctly contains the match, map and round number being restored **to**. This
  can be used by other plugins to remove any data recorded after the beginning of that round, as the rounds will be
  replayed.
* Fixed invalid client index errors in the veto system if a team is empty.
* All backups for live rounds now contain a "Valve backup" file, making the restore logic for round 0 (first round)
  similar to that of any other live round.
* Fixed a problem with server hibernation causing the use of `get5_autoload_config` to produce `Gamerules lookup failed`
  errors and not firing the `Get5_OnSeriesInit` forward/event.
* The game now restarts **once** when the game goes live, clearing lingering UI indicators of a round-win from the knife
  round.
* Fixed a problem where the game would change to live get5 state too early, causing the countdown and "going live"
  announcements to misbehave.
* If a match is canceled during veto countdown, it now correctly stops counting down and resets its countdown for the
  next attempt.
* Team ready tags have been moved **behind** the team names to prevent the UI from displaying `[` as a start-letter for
  both teams when viewed from the default GOTV overlay.
* Color variables are now stripped from console messages, preventing garbled icon output in the log files.
* Fixed a problem where setting values to empty strings (such as `"get5_demo_format" ""`) in the `cvars` section of a
  match configuration would be ignored.
* `g_MatchID` is now correctly reset when a match ends, so `get5_listbackups` will not be stuck listing the last ended
  match's backups only: https://github.com/splewis/get5/pull/849
* ... and many, many more minor bugs and adjustments. See the full commit list below if you want to inspect the
  changes (it's **a lot**)

**Full Changelog**: https://github.com/splewis/get5/compare/v0.9.0...v0.10.0

## New Contributors

* @enerbewow made their first contribution in https://github.com/splewis/get5/pull/805

# 0.9.0

#### 2022-07-01

### Breaking Changes 🛠

* The entire event and forward system has been rewritten from the ground up. This means if you had *any* plugin using
  the SourceMod forwards or the JSON events, you will have to go through
  the [event system](https://splewis.github.io/get5/events_and_forwards/) documentation to update your implementation.
* The misspelled `get5_web_available` command has been removed. The Get5 Web proof-of-concept system has been updated to
  accommodate this.
* The [MySQL extension](https://splewis.github.io/get5/stats_system/#mysql) has had its schema changed. Please verify
  that you have **all the columns** as defined in the template schema
  found [here](https://github.com/splewis/get5/blob/master/misc/import_stats.sql).
* SourceMod 1.10 is now required. It also works fine on 1.11 though!
* A lot of translations have been adjusted, so you **must** merge in the `translations` folder to your SourceMod
  translations folder (`addons/sourcemod/translations`) if you update from an earlier version of Get5!

### New Features 🎉

* **A lot** of new information has been added to the events and forward system, including grenades thrown and their
  victims, every player death and bomb plants/defuses. (@nickdnk)
* The pausing-system has been totally reworked, using hints instead of the in-game counters. (@nickdnk + @PhlexPlexico
  with help from @rpkaul)
* A slick, new [documentation](https://splewis.github.io/get5/) site has been built, replacing the outdated GitHub
  Wiki. (@nickdnk and @PhlexPlexico)
* A complete CI-flow has been implemented (@PhlexPlexico). We plan to do a lot more frequent releases going forward and
  hopefully reach a 1.0 version in the not-too-distant future.
* Improved damage report to include kills, assists and flash assists. by @nickdnk
  in https://github.com/splewis/get5/pull/725
* Implement "random" value for "veto_first" by @tapir in https://github.com/splewis/get5/pull/765
* ... and a lot more minor stuff!

### What happened to 0.8?

Breaking changes were merged into master after 0.7, and these ran under the 0.8.0 version internally in Get5, but no
release was ever made, so we jumped straight to 0.9 instead of retconning 0.8.

### Bug Fixes 🐞

This list is simply too long to go over. But it's a lot. We've closed around 50 issues since 0.7.2, and some of the
changes can be found in these commits and pull requests:

* In-game timeout counter by @VilkkuV in https://github.com/splewis/get5/pull/547
* Stats in JSON format by @jenrik in https://github.com/splewis/get5/pull/686
* Increased JSON buffer from 8kb to 64kb by @TimiSillman in https://github.com/splewis/get5/pull/723
* Pause/Unpause events and forwards by @PhlexPlexico in https://github.com/splewis/get5/pull/626
* Include Pause Forwards in get5.inc by @PhlexPlexico in https://github.com/splewis/get5/pull/727
* Fix g_BO2Match never being set to false on match load. by @PhlexPlexico in https://github.com/splewis/get5/pull/726
* Pause Game While Veto is going on. by @TandelK in https://github.com/splewis/get5/pull/696
* Match restore issues by @arildboifot in https://github.com/splewis/get5/pull/652
* Update clan tag prevention message to be debug. by @PhlexPlexico in https://github.com/splewis/get5/pull/764
* Update Dockerfile to debian 11 by @Apfelwurm in https://github.com/splewis/get5/pull/760
* Change gMapSides when knife round swaps. by @PhlexPlexico in https://github.com/splewis/get5/pull/753
* Create Github Pages Documentation by @PhlexPlexico in https://github.com/splewis/get5/pull/752
* Include timeouts for tech pauses. by @PhlexPlexico in https://github.com/splewis/get5/pull/749
* Add -E flag to spcomp to treat warnings as errors for workflow builds by @nickdnk
  in https://github.com/splewis/get5/pull/766
* Bring in check to not allow users the ability to unpause admin pauses. by @PhlexPlexico
  in https://github.com/splewis/get5/pull/767
* Swap pause type for restore to tracitcal by @PhlexPlexico in https://github.com/splewis/get5/pull/769
* Maintain Pause Count On Match Restore by @PhlexPlexico in https://github.com/splewis/get5/pull/770
* Fix pausing during match restore when users use a fixed pause timer. by @PhlexPlexico
  in https://github.com/splewis/get5/pull/771
* More fixed pause timer fixes. by @PhlexPlexico in https://github.com/splewis/get5/pull/772
* Match Restore Coach Fix by @PhlexPlexico in https://github.com/splewis/get5/pull/754
* 0.9 Release by @nickdnk in https://github.com/splewis/get5/pull/803

## New Contributors

* @VilkkuV made their first contribution in https://github.com/splewis/get5/pull/547
* @TimiSillman made their first contribution in https://github.com/splewis/get5/pull/723
* @tapir made their first contribution in https://github.com/splewis/get5/pull/765

**Full Changelog**: https://github.com/splewis/get5/compare/0.7.2...v0.9.0
