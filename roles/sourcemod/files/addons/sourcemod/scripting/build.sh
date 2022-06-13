COUNTER=0
for PLUGIN in *.sp;
do
  echo "Compiling ${PLUGIN}"
  ./spcomp "${PLUGIN}" -v2 -o../plugins/"$(basename -- "$PLUGIN" .sp)".smx \
    -i/home/leigh/projects/sourcemod/addons/sourcemod/scripting/include \
    -i/build/sourcemod/addons/sourcemod/scripting/include \
    -i/home/leigh/projects/uncletopia/roles/srcds/files/addons/sourcemod/scripting/include
    ((COUNTER=COUNTER+1))
done
mv ../plugins/basevotes.smx ../plugins/disabled/
echo "Compiled ${COUNTER} plugins"