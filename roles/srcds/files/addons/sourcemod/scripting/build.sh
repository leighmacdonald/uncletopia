for PLUGIN in \
  "autorecorder" \
  "admin-allspec" \
  "cronjobs" \
  "disableautokick" \
  "extendedmapconfig" \
  "gbans" \
  "medicstats" \
  "nativevotes-basecommands" \
  "nativevotes-basevotes" \
  "nativevotes" \
  "NetworkTools" \
  "SendToSpec" \
  "stac" \
  "supstats2" \
  "system2_http" \
  "tf2-comp-fixes" \
  "tf2attributes" \
  "tf2centerprojectiles" \
  "tidychat" \
  "uncletopia-nags" \
  "unusedvoicelines" \
  "votescramble" \
  "waitingdoors"
do
  spcomp ${PLUGIN} -v2 -o../plugins/${PLUGIN}.smx \
    -i/home/leigh/projects/sourcemod/addons/sourcemod/scripting/include \
    -i/build/sourcemod/addons/sourcemod/scripting/include \
    -i/home/leigh/projects/uncletopia/roles/srcds/files/addons/sourcemod/scripting/include
done