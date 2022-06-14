COUNTER=0
for PLUGIN in *.sp;
do
  echo "Compiling ${PLUGIN}"
  spcomp "${PLUGIN}" -v2 -o../plugins/"$(basename -- "$PLUGIN" .sp)".smx \
    -i/home/leigh/projects/sourcemod/addons/sourcemod/scripting/include \
    -i/build/sourcemod/addons/sourcemod/scripting/include \
    -i/home/leigh/projects/uncletopia/roles/srcds/files/addons/sourcemod/scripting/include
    ((COUNTER=COUNTER+1))
done

# Disable plugins that are incompatible with our
for PLUGIN in admin-sql-prefetch \
    admin-allspec \
    admin-sql-threaded \
    csgo_votestart_test \
    nativevotes_votemanager_test \
    rockthevote.smx \
    votediagnostics \
    admin-sql-prefetch  \
    basevotes \
    mapchooser \
    nominations \
    sql-admin-manager;
do
  mv ../plugins/${PLUGIN}.smx ../plugins/disabled/
done

echo "Compiled ${COUNTER} plugins"