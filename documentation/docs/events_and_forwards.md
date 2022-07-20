# :material-function: Events & Forwards

Get5 contains an event-logging system that logs many client actions and what is happening in the game. These supplement
the logs CS:GO makes on its own, but add a lot of additional information about the ongoing match.

You should hook onto these forwards if creating extensions to Get5, such as a plugin to collect stats. You can also
implement something similar to the `get5_apistats` plugin, which sends the data
somewhere via HTTP or logs the events to a file.

!!! help "Why are there HTTP methods?"

    The HTTP methods displayed here must be defined for the OpenAPI swagger documentation tool and have **no meaning**.
    We use swagger because it allows us to document the structure of the
    [event objects](https://github.com/splewis/get5/blob/master/scripting/include/get5.inc) and their inheritance 1:1 to
    the JSON output you would see from each forward/event.

<swagger-ui src="event_schema.yml"/>


