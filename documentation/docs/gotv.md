# :material-filmstrip: GOTV & Demos {: #gotv }

## GOTV Broadcast {: #broadcast }

Get5 makes no changes to the broadcasting part of the GOTV, but will automatically adjust the
[`mp_match_restart_delay`](https://totalcsgo.com/command/mpmatchrestartdelay) when a map ends if GOTV is enabled to
ensure that it won't be shorter than what is required for the GOTV broadcast to finish. Players will also not
be [kicked from the server](../configuration/#get5_kick_when_no_match_loaded) before this delay has passed.

!!! warning "Don't mess too much with the TV! :tv:"

    Changing `tv_delay` or `tv_enable` in `warmup.cfg`, `live.cfg` etc. is going to cause problems with your demos.
    We recommend you set `tv_delay` either on your server in general or only once in the `cvars` section of your
    [match configuration](../match_schema). You should also not set `tv_delaymapchange` as Get5 handles this
    automatically.
    
    We recommend that you **do not** set `tv_enable` in your match configuration, as it **requires** a map change for
    the GOTV bot to join the server. You should enable GOTV in your general server config and refrain from turning it on
    and off with Get5. Note that setting `tv_enable 1` won't allow people to join your server's GOTV. You must also set
    `tv_advertise_watchable 1`, so you don't have to worry about ghosting if this is disabled.

## Recording Demos {: #demos }

Get5 can be configured to automatically record matches. This is enabled by default based on the state
of [`get5_demo_name_format`](../configuration/#get5_demo_name_format) and can be disabled by setting that parameter to
an empty string.

Demo recording starts once all teams have readied up and ends shortly following a map result. When a demo file is
written to disk, the [`Get5_OnDemoFinished`](events_and_forwards.md) forward is called. The filename can also be found
in the map-section of the [KeyValue stats system](../stats_system/#keyvalue).

## Automatic Upload {: #upload }

In addition to recording demos, Get5 can also upload them to a URL when the series ends. To enable this feature, you
must have the [SteamWorks](../installation/#steamworks) extension installed and define the URL with
[`get5_demo_upload_url`](../configuration/#get5_demo_upload_url). The HTTP body will be the raw demo file, and you can
read the [headers](#headers) for file metadata.

### Headers {: #headers }

Get5 will always add these three HTTP headers to its demo upload request:

1. `Get5-Demoname` is the name of the file as defined
   by [`get5_demo_name_format`](../configuration/#get5_demo_name_format),
   i.e. `2022-09-11_20-49-49_1564_map1_de_vertigo.dem`.
2. `Get5-MatchId` is the [match ID](../match_schema/#schema) of the series.
3. `Get5-MapNumber` is the zero-indexed map number in the series.

#### Authorization {: #authorization }

If you wish to authenticate your upload request, you can define both
[`get5_demo_upload_header_key`](../configuration/#get5_demo_upload_header_key) and
[`get5_demo_upload_header_value`](../configuration/#get5_demo_upload_header_value) as a header key-value pair which
Get5 will add to the request.

### Cleanup {: #cleanup }

If you set [`get5_demo_delete_after_upload`](../configuration/#get5_demo_delete_after_upload),
the [demo file](../configuration/#get5_demo_name_format) will be removed from the game server after successful upload.
