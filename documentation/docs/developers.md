# :material-code-braces: Developers

## Interfacing with Get5 {: #api }

1. You can write another SourceMod plugin that uses
   the [Get5 natives and forwards](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc). This is
   exactly what the [get5_apistats](https://github.com/splewis/get5/blob/master/scripting/get5_apistats.sp)
   and [get5_mysqlstats](https://github.com/splewis/get5/blob/master/scripting/get5_mysqlstats.sp) plugins do. Please
   use these as a general guide/starting point. Don't fork this repository to make changes to these plugins alone, but
   use these as a template and create a new repository for your plugin. All the events and forwards
   are [thoroughly documented](./events_and_forwards.md).

2. You can read [event logs](./events_and_forwards.md) from a file on disk (set
   by [`get5_event_log_format`](./configuration.md#get5_event_log_format)), through a RCON connection to the server
   console since they are output there, or through another SourceMod plugin (see #1).

3. You can read the [stats](./stats_system.md) Get5 collects from a file on disk (set
   by [`get5_stats_path_format`](./configuration.md#get5_stats_path_format)), or through another SourceMod plugin (
   see #1).

4. You can execute the [`get5_loadmatch`](../commands/#get5_loadmatch) command
   or [`get5_loadmatch_url`](../commands/#get5_loadmatch_url) commands via another plugin or via a RCON
   to begin matches. Of course, you could execute any get5 command you want as well.

## Building Get5 from source {: #build }

If you are unfamiliar with how building SourceMod plugins works, you can use [Docker](https://www.docker.com/) to build
Get5 [from source](https://github.com/splewis/get5). A precompiled image is available:

```shell
docker pull nickdnk/get5-build:latest
```

If run from the repository root, this would put the compiled plugin into a `builds` folder. You could of course replace
`$PWD/builds` with any other path to move the output there.

```shell
docker run --rm -v $PWD:/get5src -v $PWD/builds:/get5/builds nickdnk/get5-build:latest
```

!!! warning "Custom builds are unsupported"

    Note that while building Get5 yourself may seem easy, we do not provide support for custom builds. If you want to
    report a bug, please use the latest [official version](https://github.com/splewis/get5/releases/latest).
