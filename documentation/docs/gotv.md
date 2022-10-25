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
written to disk, the [`Get5_OnDemoFinished`](events_and_forwards.md) forward is called shortly after. The filename can
also be found in the map-section of the [KeyValue stats system](../stats_system/#keyvalue).

!!! danger "GOTV lockup on flush to disk"

    Some servers experience lockups of the GOTV broadcast while the demo file is being flushed to disk, which may take
    up to 10 seconds in some cases. If your server suffers from this problem and you cannot fix it, you can enable
    [`get5_demo_postpone_stop`](../configuration/#get5_demo_postpone_stop).

## Automatic Upload {: #upload }

In addition to recording demos, Get5 can also upload them to a URL when the recording stops. To enable this feature, you
must have the [SteamWorks](../installation/#steamworks) extension installed and define the URL with
[`get5_demo_upload_url`](../configuration/#get5_demo_upload_url). The HTTP body will be the raw demo file, and you can
read the [headers](#headers) for file metadata.

### Headers {: #headers }

Get5 will add these HTTP headers to its demo upload request:

1. `Get5-DemoName` is the name of the file as defined
   by [`get5_demo_name_format`](../configuration/#get5_demo_name_format),
   i.e. `2022-09-11_20-49-49_1564_map1_de_vertigo.dem`.
2. `Get5-MapNumber` is the zero-indexed map number in the series.
3. `Get5-MatchId` **if** the [match ID](../match_schema/#schema) is not an empty string.
4. `Get5-ServerId` **if** [`get5_server_id`](configuration.md#get5_server_id) is set to a positive integer.

#### Authorization {: #authorization }

If you wish to authenticate your upload request, you can define both
[`get5_demo_upload_header_key`](../configuration/#get5_demo_upload_header_key) and
[`get5_demo_upload_header_value`](../configuration/#get5_demo_upload_header_value) as a header key-value pair which
Get5 will add to the request.

### Cleanup {: #cleanup }

If you set [`get5_demo_delete_after_upload`](../configuration/#get5_demo_delete_after_upload),
the [demo file](../configuration/#get5_demo_name_format) will be removed from the game server after successful upload.

### Example

This is an example of how a [Node.js](https://nodejs.org/en/) web server using [Express](https://expressjs.com/) might
read the demo upload request sent by Get5.

!!! warning "Proof of concept only"
 
    This is a simple proof-of-concept and should not be blindly copied to a production system. It has no HTTPS support
    and is only meant to demonstrate the key aspects of reading a potentially large POST request.

```js title="Node.js example"
const express = require('express');
const fs = require('fs');
const path = require("path");
const app = express();

// Accept POST requests at http://domain.tld/upload-file
app.post('/upload-file', function (req, res) {

   // Check that the authorization header configured in Get5 matches.
   // Note that header names are not case-sensitive.
   const authorization = req.header('Authorization');
   
   if (authorization !== 'super_secret_key') {
       res.status(403);
       res.end('Invalid authorization header.');
       return;
   }

   // Read the Get5 headers to know what to do with the file and potentially identify the server.
   const filename = req.header('Get5-DemoName');
   const matchId = req.header('Get5-MatchId');
   const mapNumber = req.header('Get5-MapNumber');
   const serverId = req.header('Get5-ServerId');

   // Put all demos for the same match in a folder.
   const folder = path.join(__dirname, 'demos', matchId);
   if (!fs.existsSync(folder)) {
      fs.mkdirSync(folder, {recursive: true});
   }
   // Create a stream and point it to a file, using the filename from the header.
   let writeStream = fs.createWriteStream(path.join(folder, filename));

   // Pipe the request body into the stream.
   req.pipe(writeStream);

   // Wait for the request to end and reply with 200.
   req.on('end', () => {
      writeStream.end();
      res.status(200);
      res.end('Success');
   });

   // If there is a problem writing the file, reply with 500.
   writeStream.on('error', function (err) {
      res.status(500);
      res.end('Error writing demo file: ' + err.message);
   });

})
app.listen(8080);
```
