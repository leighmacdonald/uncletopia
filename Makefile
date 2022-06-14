.PHONY: all pre system deploy

VAULT_PASS_PATH := ~/.vault_pass.txt
PROD_OPTS := -l production --vault-password-file $(VAULT_PASS_PATH)
DEVELOPMENT_OPTS := -l development --vault-password-file $(VAULT_PASS_PATH)
STAGING_OPTS := -l staging --vault-password-file $(VAULT_PASS_PATH)
PLAYBOOK_PATH := ./playbooks

all: site

lint:
	@ansible-lint

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/adduser.yml -u root

pre:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/pre.yml

sourcemod:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/sourcemod.yml

srcds:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/srcds.yml

node_exporter:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/node_exporter.yml

web:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/web.yml --limit metrics

stvup:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/stvup.yml

system:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/system.yml

wg:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/wg.yml

site:
	ansible-playbook $(PROD_OPTS) site.yml

ping:
	@ansible tf2 -m ping $(ARGS)

restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u tf2server -i hosts.yml -b
