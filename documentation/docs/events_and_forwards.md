# :material-function: Events & Forwards

Get5 contains an event-logging system that logs many client actions and what is happening in the game. These supplement
the logs CS:GO makes on its own, but add a lot of additional information about the ongoing match.

## HTTP {: #http }

To receive Get5 [events](#events) on a web server, define
a [URL for event logging](../configuration#get5_remote_log_url). Get5 will send all events to the URL as JSON over
HTTP. You may add a [custom HTTP header](../configuration#get5_remote_log_header_key) to authenticate your request.
Get5 will also add a header called `Get5-ServerId` with the value of [`get5_server_id`](../configuration#get5_server_id)
**if** it is set to a positive integer.

!!! warning "Simple HTTP"

    There is no deduplication or retry-logic for failed requests. It is assumed that a stable connection can be made
    between your game server and the URL at all times.
    HTTP [Keep-Alive](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Keep-Alive) is **not** supported. HTTPS
    **is** supported and encouraged if connection is made over a public network. Logging over HTTP requires
    the [SteamWorks](../installation#steamworks) extension on your server.

## SourceMod Forwards {: #sourcemod-forwards }

If you are writing your own SourceMod plugin, you can hook onto
the Get5 [forwards](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc). This is
what `get5_apistats` and [`get5_mysqlstats`](../stats_system#mysql) both do. The paths of the `POST` endpoints in the
table below indicate the name of the forward in SourceMod.

## Events

<swagger-ui src="event_schema.yml"/>
