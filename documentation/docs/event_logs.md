# Event Logs

Get5 contains an event-logging system that logs many client actions and what is happening in the game. These supplement
the logs CS:GO does on its own, but adds additional information about the ongoing match.

You should hook onto these forwards if creating extensions to Get5, such as a plugin to collect stats. You can also
implement something similar to the `get5_apistats` plugin, which sends the data
somewhere via HTTP or logs the events to a file.

The HTTP method displayed here is required for the OpenAPI swagger documentation tool and has no particular meaning.
All forwards, except for `Get5_OnEvent`, take a single argument; the event object.

<swagger-ui src="event_schema.yml"/>
