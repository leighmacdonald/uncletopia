echo "Adding configs from $1"
for fn in $1/host_vars/*; do
	ln -sf $fn host_vars
	echo "Added hosts config: $fn"
done

for fn in $1/group_vars/*; do
	ln -sf $fn group_vars
	echo "Added group config: $fn"
done
