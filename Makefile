.PHONY: all pre system deploy

VAULT_PASS_PATH := ~/.vault_pass.txt
PROD_OPTS := -l production
DEVELOPMENT_OPTS := -l development
STAGING_OPTS := --limit test-1.ca.uncletopia.com,test-2.ca.uncletopia.com
PLAYBOOK_PATH := ./playbooks

all: site

format:
	@find ./roles/sourcemod/files/addons/sourcemod/scripting -regex '.*\.\(sp\)' -exec clang-format -style=file -i {} \;

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

test: srcds
	docker stop srcds-localhost-1 || true # dont bail if a container doesnt already exist
	docker rm srcds-localhost-1 || true
	ansible-playbook playbooks/deploy.yml --limit localhost -K
	make logs

logs:
	docker logs -f srcds-localhost-1

deploy:
	@ansible-playbook -l tf2 $(PLAYBOOK_PATH)/deploy.yml

srcds:
	@ansible-playbook -l tf2 --skip-tags clean $(PLAYBOOK_PATH)/srcds.yml

srcds_clean:
	@ansible-playbook -l tf2 $(PLAYBOOK_PATH)/srcds.yml

shell:
	@docker exec -it srcds-test-1 bash

web:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/web.yml --limit metrics

srcdsup:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/srcdsup.yml

vpn:
	# This *does not work* when using --limit
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/vpn.yml

game_config:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/deploy.yml --tags game_config

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

local:
	ansible-playbook playbooks/srcds.yml --limit localhost
	ansible-playbook playbooks/deploy.yml --limit localhost
