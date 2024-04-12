echo "Compiling & enabling sourcemod plugins..."

./compile.sh || exit 2

# Enable pre-compiled plugins
for PLUGIN in pre-compiled/*.smx;
do
  echo "Enabling ${PLUGIN}"
  mv "${PLUGIN}" compiled/
done

# Disable plugins that are incompatible/unneeded with our plugin setup
for PLUGIN in admin-sql-prefetch \
    admin-allspec \
    admin-sql-threaded \
    rockthevote \
    votediagnostics \
    basevotes \
    mapchooser \
    nominations \
    sql-admin-manager \
    reservedslots ;
do
  echo "Disabling ${PLUGIN}"
  mv compiled/${PLUGIN}.smx ../plugins/disabled/
done

mv compiled/* ../plugins/

mv ../plugins/basevotes.smx ../plugins/disabled/

echo "Compiled ${COUNTER} plugins"