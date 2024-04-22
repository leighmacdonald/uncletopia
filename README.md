# Uncletopia

This repo contains [Ansible](https://docs.ansible.com) playbooks and roles for
configuring and administering the uncletopia server cluster.

## Role Descriptions

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
