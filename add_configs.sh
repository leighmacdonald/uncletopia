echo "Adding configs from $1"
for fn in $1/host_vars/*; do
	ln -f $fn host_vars
	echo "Added hosts config: $fn"
done

for fn in $1/group_vars/*; do
	ln -f $fn group_vars
	echo "Added group config: $fn"
done
ln -f $1/hosts.yml hosts.yml
