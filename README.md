# Uncletopia

This repo contains [Ansible](https://docs.ansible.com) playbooks and roles for
configuring and administering the uncletopia server cluster.

## Roles

### caddy

The [caddy](https://caddyserver.com/) role configured the frontend http server that exposes all the internal services such as the 
gbans website and grafana.

### gbans

The gbans roles downloads and configures the [gbans](https://github.com/leighmacdonald/gbans) (and postgres) docker instances. gbans is a tools that provides 
centralized bans, appeals and other simple community components.

### metrics

The metrics role is responsible for configuring the grafana & prometheus stacks. 

### sourcemod (+metamod)

The sourcemod role is responsible for configuring the [metamod](https://www.sourcemm.net/) and [sourcemod](https://www.sourcemod.net/) installation used in the srcds role. It will 
automatically download the latest metamod and source versions and fully rebuild the entire plugin tree to ensure 
compatibility.

### srcds

srcds is responsible for downloading and configuring each games docker instance. We 
do *not* use steamcmd nor its auto update mechanics. Containers should not auto update themselves, so instead we use 
[depot downloader](https://github.com/SteamRE/DepotDownloader) to download the latest build, then rebuild the images. 
To save on download/rebuild times, the base tf2 image is cached untouched so subsequent updates only pull deltas. 

## Playbooks

These are largely in the order they should be executed in with the exception of  adduser.yml, which must be run first. 

### adduser.yml (once)

Creates the user used for running the services. This only should be ran once. A new user will be created and will be used for future playbooks instead as root logins over ssh will be disabled. 

### vpn.yml

Setups a P2P wireguard based vpn network. These playbooks and services are designed to listen and otherwise use internal vpn network traffic
everywhere possible. This is not strictly required, but not using a vpn is 100% untested/unsupported and will required fixing things yourself.

### system.yml

Installs base OS runtime requirements and services.

- Set timezone
- Enable i386 arch for steam_cmd/srcds
- Installs apt repos and install .net, docker, rsyslog 
- Install depotdownloader
- Enable firewall in deny mode

### srcds.yml

Installs the baseline SRCDS instance using steamcmd (dd will work too, but it was disabled temporarily due to a auth problem and needs to be re-enabled).

These do *not* currently run under docker containers due to some painful ergonomics at the time and dealing with some other external problems. 
But they may again in the future as things have improved.

- Downloads and installs metamod and sourcemod.
- Builds *all* sourcemod plugins from source. This is done to help reduce bitrot and ensure correctness.
- Configures the services specific plugins and extensions.

### web.yml

Installs all web functionality, includes all backend monitoring tooling as well. All services run under docker
containers

- Install and configure caddy web server
- Setup backend metrics services
  - node_exporter
  - srcds_watch
  - promtail
  - loki
  - mimir (w/minio storage) 
  - prometheus
  - grafana w/dashboards
- Install and configure gbans and required services
  - bd-api
  - postgres

### tune.yml

A *optional* playbook that contains tasks that will tune the underlying OS. You *must* not run this without understanding
the reprocussions of the changes. You should also adjust them accordingly to your hardware specs & needs.

## Setup

Install Ansible & Clone playbooks

- `sudo apt-add-repository --yes --update ppa:ansible/ansible`
- `apt install ansible make git git-lfs sshpass -y` [or for macOS](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-macos)
- `git clone git@github.com:leighmacdonald/uncletopia`
- `pip install rcon`

## Game Update Workflow

1. Watch for game update triggers via `watcher/watcher.py` using `wss://update.uncletopia.com`
2. Trigger srcds build & upload image to docker hub.
3. Trigger TF2 deploy.


### Development

If you are on a 64bit machine you will want 32bit libs for spcomp to execute.

    sudo apt get install libc6:i386 lib32stdc++6

## Git pre-commit

There is a pre-commit hook that you should enable to ensure you don't commit any unencrypted secret.

    ln .hooks/pre-commit .git/hooks/pre-commit
