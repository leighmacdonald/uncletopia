echo "Compiling & enabling sourcemod plugins..."

./compile.sh || exit 2

# Enable pre-compiled plugins
for PLUGIN in pre-compiled/*.smx; do
	echo "Enabling ${PLUGIN}"
	mv "${PLUGIN}" compiled/
done

# Install every plugin on the host by default. Which ones actually load is
# decided per instance by the pristine-layout task in roles/srcds, not here.
mv compiled/* ../plugins/

# Promote anything shipped in optional/ or left in disabled/ by a previous
# build so the host tree really is pristine.
mv ../plugins/optional/*.smx ../plugins/ 2>/dev/null || true
mv ../plugins/disabled/*.smx ../plugins/ 2>/dev/null || true

echo "Compiled ${COUNTER} plugins"
