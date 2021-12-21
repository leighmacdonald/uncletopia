# Uncletopia

This repo contains [Ansible](https://docs.ansible.com) playbooks and tasks for
configuring and administering the uncletopia server cluster.

## Setup

Install Ansible & Clone playbooks

- `sudo apt-add-repository --yes --update ppa:ansible/ansible`
- `apt install ansible make git git-lfs sshpass -y` [or for macOS](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-macos)
- `git clone git@github.com:leighmacdonald/uncletopia`



For contributors, you should also enable the git hooks for the repo:

	git config core.hooksPath .hooks


## Adding Maps

Just place the maps (.bsp) you want under `roles/tf2/files/tf/maps` and update
the `mapcycle.txt` config file below.

## Setting configs

To change dynamic values (values that are unique to each host), you can edit the files
under host_vars. eg: `dane-us1.jttm.us.yml`.

## Commands

These command should be run from the Uncletopia folder on your local host system, NOT on the servers themselves.

## New Server Setup

Most of these steps are not strictly required, but you should be aware of the assumptions that we will have
in the rest of the system              

### 1. User / SSH Setup

- Add tf2 group
- Add tf2server user
- Setup firewall
- Setup SSH

`make adduser` or `ansible-playbook -u your_ssh_username -i your_hosts.yml -K adduser.yml `

Note that this will only ever run ONCE per server as it disables the mechanism it uses to login
as the last step. Failures for the existing servers is expected behaviour.

### 2. `system.yml`

- Install prerequisite apt packages
- Update the server
- Adds prometheus support

`make system` or `ansible-playbook system.yml`

### 3. `deploy.yml`

You are now ready to deploy the custom parts of the TF2 instance. This will:

- Generate a custom tf2server.cfg from the template
- Download and configure N+1 docker containers for each instance using `leighmacdonald/uncletopia-srcds:latest`
- Allow the ports for each instance in the firewall

`make` or `ansible-playbook deploy.yml`

