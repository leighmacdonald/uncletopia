# Uncletopia

This repo contains [Ansible](https://docs.ansible.com) playbooks and roles for
configuring and administering the uncletopia server cluster.

## Roles

### bd-api (optional)

Installs the [bd-api](https://github.com/leighmacdonald/bd-api) service.

### caddy

The [caddy](https://caddyserver.com/) role configures the frontend http proxy that exposes all the internal services such as the 
gbans website and grafana.

### demostats

The [demostats](https://github.com/leighmacdonald/tf2_demostats) role handles configuring the demostats docker container
web service for processing incoming demos.

### gbans

The gbans roles downloads and configures the [gbans](https://github.com/leighmacdonald/gbans) (and postgres) docker instances. gbans is a tools that provides 
centralized bans, appeals and other simple community components.

### metrics (optional)

The metrics role is responsible for configuring the grafana monitoring stack. Installs the grafana web service 
and associated backend agents loki, prometheus and promtail.

### sourcemod (+metamod)

The sourcemod role is responsible for configuring the [metamod](https://www.sourcemm.net/) and [sourcemod](https://www.sourcemod.net/) installation used in the srcds role. It will 
automatically download the latest metamod and source versions and fully rebuild the entire plugin tree to ensure 
compatibility.

Note that all plugins which to not comply with sourcemods newer syntax `newdecls` have had their source updated with `#pragma newdecls required` and all subsequent 
required changes.

There is no pre-existing compiled plugins, you will need to compile anything you need yourself if you use any of these. We compile all plugins during
the deployment stage.

### srcds

Installs the baseline SRCDS instance using steamcmd (dd will work too, but it was disabled temporarily due to an auth problem and needs to be re-enabled).

These do *not* currently run under docker containers due to some painful ergonomics at the time and dealing with some other external problems.
But they may again in the future as things have improved.

- Downloads and installs metamod and sourcemod.
- Builds *all* sourcemod plugins from source. This is done to help reduce bitrot and ensure correctness.
- Configures the services specific plugins and extensions.

## Playbooks

These are largely in the order they should be executed in except for, adduser.yml, which must be run first. 

### adduser.yml (once)

Creates the user used for running the services. This only should be run once. A new user will be created and will be used for future playbooks instead as root logins over ssh will be disabled. 

### vpn.yml

Setups a P2P wireguard based vpn network. These playbooks and services are designed to listen and otherwise use internal vpn network traffic
everywhere possible. This is not strictly required, but not using a vpn is 100% untested/unsupported and will require fixing things yourself.

Note: This required the `python3-netaddr` package to be installed on the *ansible controller host*.

### system.yml

Installs base OS runtime requirements and services.

- Set timezone
- Enable i386 arch for steam_cmd/srcds
- Installs apt repos and install .net, docker, rsyslog 
- Install [DepotDownloader](https://github.com/SteamRE/DepotDownloader)
- Enable firewall in deny mode

### update.yml

A helper playbook that will update all systems and reboot them if required.

### tune.yml

An *optional* playbook that contains tasks that will tune the underlying OS. You *must* not run this without understanding
the repercussions of the changes. You should also adjust them accordingly to your hardware specs & needs.

## Requirements

To install the required additional collections and roles you can use the provided requirements.yml file.

    ansible-galaxy install -r requirements.yml

## Troubleshooting

### spcomp fails to execute

If you are on a 64bit machine you will want 32bit libs for spcomp.

    sudo apt get install libc6:i386 lib32stdc++6


## Manual Setup Steps

There is a few steps that are not entirely automated yet. These are generally going to be one time setup type of steps.

These will eventually get automated, but are quite low priority.

- (One time) Create sentry admin user
  - ssh {{ caddy.hosts.sentry.dns }} -C "cd ~/sentry && docker compose run --rm web createuser"