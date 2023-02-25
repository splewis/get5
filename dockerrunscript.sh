#!/bin/bash
set -e

WORKING_ROOT=/get5
SM_INCLUDE_PATH=$WORKING_ROOT/addons/sourcemod/scripting/include

SRC_ROOT=/get5_src
SM_JSON_ROOT=$SRC_ROOT/dependencies/sm-json

BUILD_ROOT=/get5_build
GET5_OUTPUT_ROOT=$BUILD_ROOT/get5
PLUGINS_OUTPUT_ROOT=$BUILD_ROOT/plugins
SM_OUTPUT_ROOT=$GET5_OUTPUT_ROOT/addons/sourcemod
SM_OUTPUT_PLUGINS=$SM_OUTPUT_ROOT/plugins

if [ ! -d "$SM_JSON_ROOT" ]; then
  echo "Error: sm-json dependency not found; please run 'git submodule update --init' from the repository root."
  exit 1;
fi

echo "Copying source files from host..."
# Copy the mounted source files into the /get5 working directory, overwriting any files
cp -rf $SRC_ROOT/scripting $WORKING_ROOT/scripting
# Move the sm-json includes into the SM include directory
echo "Copying sm-json includes..."
cp -rf $SM_JSON_ROOT/addons/sourcemod/scripting/include/* $SM_INCLUDE_PATH
mkdir -p $SM_OUTPUT_PLUGINS
for file in "$@"
do
    echo "Compiling '$file'.sp...";
    spcomp -v0 -i $SM_INCLUDE_PATH -E -o $SM_OUTPUT_PLUGINS/$file.smx $WORKING_ROOT/scripting/$file.sp
done
echo "Copying source files and translations..."
# Copy translations, configs and cfg to their correct destination
cp -rf $SRC_ROOT/translations $SM_OUTPUT_ROOT
cp -rf $SRC_ROOT/configs $SM_OUTPUT_ROOT
cp -rf $SRC_ROOT/cfg $SRC_ROOT/LICENSE $SRC_ROOT/README.md $GET5_OUTPUT_ROOT
# Copy the compiled .smx files to /plugins of the build output as well:
mkdir -p $PLUGINS_OUTPUT_ROOT
cp -f $SM_OUTPUT_PLUGINS/*.smx $PLUGINS_OUTPUT_ROOT
echo "Build completed."
