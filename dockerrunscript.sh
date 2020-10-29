#!/bin/bash
cd /get5src && git submodule update --init
cp -rf /get5src/* /get5/
cd /get5
cp -r ./dependencies/sm-json/addons/sourcemod/scripting/include/* ./addons/sourcemod/scripting/include
smbuilder --flags='-E'
