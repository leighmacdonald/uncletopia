# Uncletopia

This repo contains [Ansible](https://docs.ansible.com) playbooks and tasks for 
configuring and administering the uncletopia server cluster.

## Setup

Install Ansible & Clone playbooks

- `sudo apt-add-repository --yes --update ppa:ansible/ansible`
- `apt install ansible make git git-lfs sshpass -y` [or for macOS](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-macos)
- `git clone git@github.com:leighmacdonald/uncletopia && cd uncletopia`  

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


## Git Workflow

This repo is meant as a template / master. Your private customizations should be in your local repository only. Below 
is a demonstration of the workflow for contributing changes back:

### Initial setup

This will set your origin server to your private repo, and the upstream to the master uncletopia repo.

- git clone git@github.com:leighmacdonald/uncletopia.git uncletopia-private
- cd uncletopia-private 
- git remote add upstream git@github.com:leighmacdonald/uncletopia.git
- git remote set-url origin git@github.com:leighmacdonald/uncletopia-private.git
- cp host_vars/your.host.com.yml.example host_vars/custom.host.com.yml
- vim host_vars/custom.host.com.yml
- vim README.md
- git commit README.md -m "Updated readme with git instructions"
- git push upstream readme_update