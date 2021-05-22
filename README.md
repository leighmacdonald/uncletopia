# Uncletopia

This repo contains [Ansible](https://docs.ansible.com) playbooks and tasks for
configuring and administering the uncletopia server cluster.

## Setup

Install Ansible & Clone playbooks

- `sudo apt-add-repository --yes --update ppa:ansible/ansible`
- `apt install ansible make git git-lfs sshpass -y` [or for macOS](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-macos)
- `git clone git@github.com:leighmacdonald/uncletopia && cd uncletopia`
- `ansible-galaxy collection install community.general`  

## Adding Servers

1. Add a new entry under `./hosts.yml`
2. Copy an existing host config from `./host_vars` and name it to the hostname you just
set in `./hosts.yml`
3. `make`

## Adding Maps

Just place the maps (.bsp) you want under `roles/tf2/files/tf/maps` and update
the `mapcycle.txt` config file below.

## Setting configs

All the static configs are copies from `roles/tf2/files/tf/cfg`

To change dynamic values (values that are unique to each host), you can edit the files
under host_vars. eg: `dane-us1.jttm.us.yml`.

## Commands

These command should be run from the Uncletopia folder on your local host system, NOT on the servers themselves.


## New Server Setup

### 1. Setup hostkey

Add your hostkey for the new server to your local ssh config. Ansible cannot do this properly.
Just run `ssh your_new_host.jttm.us` and enter `yes` for the confirmation.

    ➜  uncletopia git:(master) ✗ ssh dane-eu2.jttm.us
    The authenticity of host 'dane-eu2.jttm.us (185.107.96.74)' can't be established.
    RSA key fingerprint is SHA256:0idxMY3Fezv2FYGSAaG1HjLVk2BkOICgmM93+646RCM.
    Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
    Warning: Permanently added 'dane-eu2.jttm.us,185.107.96.74' (RSA) to the list of known hosts.


Add your ssh public key for root `ssh-copy-id root@dane-eu2.jttm.us`

    ➜  uncletopia git:(master) ✗ ssh-copy-id root@dane-eu2.jttm.us
    /usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
    /usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
    Enter passphrase for key '/home/leigh/.ssh/id_rsa':
    root@dane-eu2.jttm.us's password:

    Number of key(s) added: 1

    Now try logging into the machine, with:   "ssh 'root@dane-eu2.jttm.us'"
    and check to make sure that only the key(s) you wanted were added.

    ➜  uncletopia git:(master) ✗

### 2. User / SSH Setup

- Add tf2 group
- Add tf2server user
- Setup firewall
- Setup SSH

`make adduser` or `ansible-playbook -u your_ssh_username -i your_hosts.yml -K adduser.yml `

Note that this will only ever run ONCE per server as it disables the mechanism it uses to login
as the last step. Failures for the existing servers is expected behaviour.

### 3. `system.yml`

- Install prerequisite apt packages
- Update the server
- Adds prometheus support

`make system` or `ansible-playbook system.yml`

### 4. `pre.yml`

Next you can install the prerequisites for the tf2 server itself. This will do:

- Install [LinuxGSM](https://linuxgsm.com/lgsm/tf2server)
- Install TF2 base files under `~/serverfiles`

`make pre` or `ansible-playbook pre.yml`


### 5. `deploy.yml`

You are now ready to deploy the custom parts of the TF2 instance. This will:

- Copy the sourcemod folders (addons/sourcemod)
- Copy maps stores in `roles/tf2/files/tf/maps`
- Generate a custom tf2server.cfg from the template
- Install & Start the tf2server.service systemd service

`make` or `ansible-playbook deploy.yml`

## External config source

To be able to use this repo with your own private configs, there is an included helper script included: `add_configs.sh`

Your config dir should contain the host_vars and group_vars folders and all your configs you want inside those dirs.

For example:

	$ ls -la ../uncletopia-config
	drwxr-xr-x 5 leighm leighm 4096 Feb 28 21:01 .
	drwxr-xr-x 6 leighm leighm 4096 Feb 28 20:55 ..
	drwxr-xr-x 8 leighm leighm 4096 Feb 28 21:02 .git
	drwxr-xr-x 2 leighm leighm 4096 Feb 28 21:00 group_vars
	drwxr-xr-x 2 leighm leighm 4096 Feb 28 21:00 host_vars

	# ls -la ../uncletopia-config/host_vars
	drwxr-xr-x 2 leighm leighm 4096 Feb 28 21:00 .
	drwxr-xr-x 5 leighm leighm 4096 Feb 28 21:01 ..
	-rw-r--r-- 1 leighm leighm  186 Feb 22 21:02 as1.uncledane.com.yml
	-rw-r--r-- 1 leighm leighm  185 Feb 22 21:02 eu1.uncledane.com.yml
	...


Then link your configs with the following command, replacing the value with the path to your own config dir.

	$ ./add_configs.sh ../uncletopia-config
	Adding configs from ../uncletopia-config
	Added hosts config: ../uncletopia-config/host_vars/us4.uncledane.com.yml
	Added hosts config: ../uncletopia-config/host_vars/us5.uncledane.com.yml
	Added hosts config: ../uncletopia-config/host_vars/us6.uncledane.com.yml
	Added group config: ../uncletopia-config/group_vars/all.yml
	...

You should now see your linked configs in the tree.

	$ ls -la host_vars
	total 16
	drwxr-xr-x 2 leighm leighm 4096 Feb 28 21:18 .
	drwxr-xr-x 8 leighm leighm 4096 Feb 28 21:20 ..
	-rw-r--r-- 1 leighm leighm  281 Feb 22 22:17 192.168.0.210.yml
	lrwxrwxrwx 1 leighm leighm   52 Feb 28 21:18 as1.uncledane.com.yml -> ../uncletopia-config/host_vars/as1.uncledane.com.yml
	lrwxrwxrwx 1 leighm leighm   52 Feb 28 21:18 eu1.uncledane.com.yml -> ../uncletopia-config/host_vars/eu1.uncledane.com.yml
	lrwxrwxrwx 1 leighm leighm   52 Feb 28 21:18 eu2.uncledane.com.yml -> ../uncletopia-config/host_vars/eu2.uncledane.com.yml
	lrwxrwxrwx 1 leighm leighm   52 Feb 28 21:18 ha1.uncledane.com.yml -> ../uncletopia-config/host_vars/ha1.uncledane.com.yml			
	...

### Initial setup

This will setup a dual repo structure where your private configs are under one tree and are linked
to the correct locations within the main repo, without having to mix environments.

- git clone git@github.com:leighmacdonald/uncletopia.git
- git clone git@github.com:leighmacdonald/uncletopia-configs.git
- cd uncletopia
- ./add_configs.sh ../uncletopia-configs

From here you should me able to run `make` commands.

