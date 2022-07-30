get5
===========================

[![Build Status](https://github.com/splewis/get5/actions/workflows/build.yml/badge.svg)](https://github.com/splewis/get5/actions/workflows/build.yml)
[![Downloads](https://img.shields.io/github/downloads/splewis/get5/total.svg?&label=Downloads)](https://github.com/splewis/get5/releases/latest)
[![Discord Chat](https://img.shields.io/discord/926309849673895966.svg)](https://discord.gg/zmqEa4keCk)  

**Status: Supported, actively developed.**

Get5 is a standalone SourceMod plugin for CS:GO servers for running matches.

Please visit https://splewis.github.io/get5 for documentation.

### Discord Chat

A [Discord](https://discord.gg/zmqEa4keCk) channel is available for general discussion.

### Reporting bugs

Please make a [github issue](https://github.com/splewis/get5/issues) and fill out as much information as possible. Reproducible steps and a clear version number will help tremendously!

### Contributions

Pull requests are welcome. Please follow the general coding formatting style as much as possible.

### Building

You can use Docker to Build get5. First you need to build the container image locally: Go to the repository folder and run:

	docker build . -t get5build:latest

Afterwards you can build get5 with the following command: (specify /path/to/your/build/output and /path/to/your/get5src)

	docker run --rm -v /path/to/your/get5src:/get5src -v /path/to/your/build/output:/get5/builds get5build:latest
	
