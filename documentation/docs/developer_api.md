# Developer API

Get5 can be interacted with in several ways. At a glance:

1. You can write another SourceMod plugin that uses
   the [Get5 natives and forwards](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc). This is
   exactly what the [get5_apistats](https://github.com/splewis/get5/blob/master/scripting/get5_apistats.sp)
   and [get5_mysqlstats](https://github.com/splewis/get5/blob/master/scripting/get5_mysqlstats.sp) plugins do. Please
   use these as a general guide/starting point. Don't fork this repository to make changes to these plugins alone, but
   use these as a template and create a new repository for your plugin! All the events and forwards
   are [thoroughly documented](./events_and_forwards.md).

3. You can read [event logs](./events_and_forwards.md) from a file on disk (set
   by [`get5_event_log_format`](./configuration.md#get5_event_log_format)), through a RCON connection to the server
   console since they are output there, or through another SourceMod plugin (see #1).

4. You can read the [stats](./stats_system.md) Get5 collects from a file on disk (set
   by [`get5_stats_path_format`](./configuration.md#get5_stats_path_format)), or through another SourceMod plugin (
   see #1).

5. You can execute the [`get5_loadmatch`](../commands/#get5_loadmatch) command
   or [`get5_loadmatch_url`](../commands/#get5_loadmatch_url) commands via another plugin or via a RCON
   to begin matches. Of course, you could execute any get5 command you want as well.
