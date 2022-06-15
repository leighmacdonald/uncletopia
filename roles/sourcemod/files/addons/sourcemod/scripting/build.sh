echo "Compiling sourcemod plugins..."

./compile.sh || exit 2

# Enable pre-compiled plugins
for PLUGIN in pre-compiled/*.smx;
do
  echo "Enabling ${PLUGIN}"
  mv pre-compiled/"${PLUGIN}" compiled/
done

# Disable plugins that are incompatible with our plugin setup
for PLUGIN in admin-sql-prefetch \
    admin-allspec \
    admin-sql-threaded \
    rockthevote \
    votediagnostics \
    basevotes \
    mapchooser \
    nominations \
    sql-admin-manager;
do
  echo "Disabling ${PLUGIN}"
  mv compiled/${PLUGIN}.smx ../plugins/disabled/
done

mv -v compiled/* ../plugins/*

echo "Compiled ${COUNTER} plugins"