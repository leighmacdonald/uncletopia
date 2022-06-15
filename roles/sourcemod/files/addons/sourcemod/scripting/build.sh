COUNTER=0

for PLUGIN in *.sp;
do
  echo "Compiling ${PLUGIN}"
    ./compile.sh || exit 2
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
  echo "Disabling ${PLUGIN}"
  mv ../plugins/${PLUGIN}.smx ../plugins/disabled/
done

# Enable pre-compiled plugins
for PLUGIN in compiled/*.smx;
do
  echo "Enabling ${PLUGIN}"
  mv compiled/"${PLUGIN}" ../plugins/
done

echo "Compiled ${COUNTER} plugins"