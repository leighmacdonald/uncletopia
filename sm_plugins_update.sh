#!/bin/env bash
ROOT=$(pwd)/playbooks
SM_ROOT=$ROOT/roles/sourcemod/files/addons/sourcemod
SRC_ROOT="sm_plugins"

STAC_ROOT="$SRC_ROOT/stac"
STAC_BRANCH="gbans-native"

PVE_ROOT="$SRC_ROOT/TF2_EngineerPVE"
PVE_BRANCH="master"

ACCEL_ROOT="$SRC_ROOT/accelerator"
ACCEL_BRANCH="master"

GBANS_ROOT="$SRC_ROOT/gbans"
GBANS_BRANCH="v0.7.20"
#GBANS_BRANCH="match-tracking"

DISCORD_ROOT="$SRC_ROOT/discord"
DISCORD_BRANCH="master"

COMPFIXES_ROOT="$SRC_ROOT/tf2-comp-fixes"
COMPFIXES_BRANCH="v1.16.17"

EDICT_LIMITER_ROOT="$SRC_ROOT/edict-limiter"
EDICT_LIMITER_BRANCH="v3.1.0-fix"

ECON_DATA_ROOT="$SRC_ROOT/tf2_econ_data"
ECON_DATA_BRANCH="0.19.1.2"

ATTRIBUTES_ROOT="$SRC_ROOT/tf2attributes"
ATTRIBUTES_BRANCH="v1.7.3.3"

CENTERPROJECTILES_ROOT="$SRC_ROOT/tf2centerprojectiles"
CENTERPROJECTILES_BRANCH="v8.0"

NATIVEVOTES_ROOT="$SRC_ROOT/nativevotes"
NATIVEVOTES_BRANCH="master"

SKIPMOTD_ROOT="$SRC_ROOT/skipmotd"
SKIPMOTD_BRANCH="master"

# git submodule update --init --recursive

pushd $STAC_ROOT || exit
git fetch --all
git checkout $STAC_BRANCH
git pull
for d in 'scripting' 'extensions' 'gamedata' 'translations'; do
  cp -rv $d "$SM_ROOT"
done
popd || exit

pushd $ACCEL_ROOT || exit
git fetch --all
git checkout $ACCEL_BRANCH
git pull

cp -v accelerator.games.txt "$SM_ROOT/gamedata/"
popd || exit

pushd $GBANS_ROOT || exit
git fetch --all
git checkout $GBANS_BRANCH
git pull
cp -rv sourcemod/scripting/* "$SM_ROOT/scripting"
popd || exit

pushd $DISCORD_ROOT || exit
git fetch --all
git checkout $DISCORD_BRANCH
git pull
cp -rv scripting/* "$SM_ROOT/scripting"
rm "$SM_ROOT/scripting/discord_calladmin.sp" \
  "$SM_ROOT/scripting/discord_sourcebans.sp" \
  "$SM_ROOT/scripting/discord_sourcecomms.sp"
popd || exit

pushd $COMPFIXES_ROOT || exit
git fetch --all
git checkout $COMPFIXES_BRANCH
cp -rv scripting gamedata "$SM_ROOT"
popd || exit

pushd $EDICT_LIMITER_ROOT || exit
git fetch --all
git checkout $EDICT_LIMITER_BRANCH
cp -rv scripting gamedata extensions "$SM_ROOT"
popd || exit

pushd $ECON_DATA_ROOT || exit
git fetch --all
git checkout $ECON_DATA_BRANCH
cp -rv scripting gamedata "$SM_ROOT"
popd || exit

pushd $ATTRIBUTES_ROOT || exit
git fetch --all
git checkout $ATTRIBUTES_BRANCH
cp -rv scripting gamedata "$SM_ROOT"
rm "$SM_ROOT/scripting/tf2attributes_example.sp"
popd || exit

pushd $CENTERPROJECTILES_ROOT || exit
git fetch --all
git checkout $CENTERPROJECTILES_BRANCH
cp -rv addons/sourcemod/* "$SM_ROOT/"
popd || exit

pushd $NATIVEVOTES_ROOT || exit
git fetch --all
git checkout $NATIVEVOTES_BRANCH
git pull
cp -rv addons/sourcemod/* "$SM_ROOT/"
rm "$SM_ROOT/scripting/nativevotes_votemanager_test.sp" \
  "$SM_ROOT/scripting/nativevotes_votetest.sp" \
  "$SM_ROOT/scripting/csgo_votestart_test.sp"
popd || exit

pushd $SKIPMOTD_ROOT || exit
git fetch --all
git checkout $SKIPMOTD_BRANCH
cp -rv *.sp "$SM_ROOT/scripting/"
popd || exit

pushd $PVE_ROOT || exit
git fetch --all
git checkout $PVE_BRANCH
cp -rv scripting gamedata "$SM_ROOT"
popd || exit