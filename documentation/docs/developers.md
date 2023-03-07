# :material-code-braces: Developers

## Interfacing with Get5 {: #api }

1. You can write another SourceMod plugin that uses
   the [Get5 natives and forwards](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc). This is
   exactly what the [get5_apistats](https://github.com/splewis/get5/blob/master/scripting/get5_apistats.sp)
   and [get5_mysqlstats](https://github.com/splewis/get5/blob/master/scripting/get5_mysqlstats.sp) plugins do.

2. You can read [event logs](../events_and_forwards) from a file on disk (set
   by [`get5_event_log_format`](../configuration#get5_event_log_format)), through a RCON connection to the server
   console since they are output there, or through another SourceMod plugin.

3. You can [send all events to a web server over HTTP](../events_and_forwards#http).

4. You can read the [stats](../stats_system) Get5 collects from a file on disk (set
   by [`get5_stats_path_format`](../configuration#get5_stats_path_format)).

5. You can execute any [command](../commands), such as [`get5_loadmatch`](../commands#get5_loadmatch)
   or [`get5_loadmatch_url`](../commands#get5_loadmatch_url) via another plugin or
   via [RCON](https://developer.valvesoftware.com/wiki/Source_RCON_Protocol).

## Building Get5 from source {: #build }

If you are unfamiliar with how building SourceMod plugins works, you can use [Docker](https://www.docker.com/) to build
Get5 [from source](https://github.com/splewis/get5). A precompiled image is available:

```shell
docker pull nickdnk/get5-build:1.10.0-6545-sp-fix
```

If run from the repository root, this would put the compiled plugin into a `builds` folder. You could of course replace
`$PWD/builds` with any other path to move the output there.

```shell
docker run --rm -v $PWD:/get5src -v $PWD/builds:/get5/builds nickdnk/get5-build:1.10.0-6545-sp-fix
```

!!! warning "Custom builds are unsupported"

    Note that while building Get5 yourself may seem easy, we do not provide support for custom builds. If you want to
    report a bug, please use the latest [official version](https://github.com/splewis/get5/releases/latest).
