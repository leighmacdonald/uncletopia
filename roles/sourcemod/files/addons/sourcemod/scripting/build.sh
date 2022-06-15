export PATH=".:$PATH"
COUNTER=0
chmod +x ./spcomp
for PLUGIN in *.sp;
do
  echo "Compiling ${PLUGIN}"
  ./spcomp64 "${PLUGIN}" -v2 -o../plugins/"$(basename -- "$PLUGIN" .sp)".smx \
    -i/build_srcds/sourcemod/addons/sourcemod/scripting/include || exit 2
    ((COUNTER=COUNTER+1))
done

# Disable plugins that are incompatible with our plugin setup
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

# Enable pre-compiled plugins
for PLUGIN in compiled/*.smx;
do
  echo "Enabling ${PLUGIN}"
  mv compiled/"${PLUGIN}" ../plugins/
done

echo "Compiled ${COUNTER} plugins"