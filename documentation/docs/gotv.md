# :material-filmstrip: GOTV & Demos {: #gotv }

Get5 can be configured to automatically record matches. This is enabled by default based on the state
of [`get5_demo_name_format`](../configuration/#get5_demo_name_format) and can be disabled by setting that parameter to
an empty string.

!!! warning "Don't mess too much with the delay!"

    Changing the `tv_delay` or `tv_enable` in `warmup.cfg`, `live.cfg` etc. is going to cause problems with your demos.
    We recommend you set this variable either on your server in general or only once in the `cvar` section of your
    [match configuration](../match_schema). You should also not set `tv_delaymapchange` as Get5 handles this
    automatically.

Demo recording starts once all teams have readied up and ends shortly following a map result. When a demo file is
written to disk, the [`Get5_OnDemoFinished`](events_and_forwards.md) forward is called, which you can use to move the
file or upload it somewhere. The filename can also be found in the map-section of the
[KeyValue stats system](../stats_system/#keyvalue).

Get5 will automatically adjust the [`mp_match_restart_delay`](https://totalcsgo.com/command/mpmatchrestartdelay) when a
map ends if GOTV is enabled to ensure that it won't be shorter than what is required for the GOTV broadcast to finish.
Players will also not be [kicked from the server](../configuration/#get5_kick_when_no_match_loaded) before this delay
has passed.
