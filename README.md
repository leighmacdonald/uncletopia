# Uncletopia

This repo contains [Ansible](https://docs.ansible.com) playbooks and tasks for
configuring and administering the uncletopia server cluster.

## Setup

Install Ansible & Clone playbooks

- `sudo apt-add-repository --yes --update ppa:ansible/ansible`
- `apt install ansible make git git-lfs sshpass -y` [or for macOS](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html#installing-ansible-on-macos)
- `git clone git@github.com:leighmacdonald/uncletopia`

## Game Update Workflow

1. Watch for game update triggers via `watcher/watcher.py` using `wss://update.uncletopia.com`
2. Trigger srcds build & upload image to docker hub.
3. Trigger TF2 deploy.