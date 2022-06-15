export PATH=".:$PATH"
COUNTER=0
for PLUGIN in *.sp;
do
  echo "Compiling ${PLUGIN}"
  spcomp "${PLUGIN}" -v2 -o../plugins/"$(basename -- "$PLUGIN" .sp)".smx \
    -i/build_srcds/sourcemod/addons/sourcemod/scripting/include || exit 2
    ((COUNTER=COUNTER+1))
done

# Disable plugins that are incompatible with our
for PLUGIN in admin-sql-prefetch \
    admin-allspec \
    admin-sql-threaded \
    csgo_votestart_test \
    nativevotes_votemanager_test \
    rockthevote \
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