.PHONY: all pre system deploy
HOSTS := ./hosts.yml
USER := tf2server
PLAYBOOK_PATH := ./playbooks
PASSWORD_FILE := ./.vault_pw

COMMON_ARGS := -i $(HOSTS) -u $(USER) $(PLAYBOOK_PATH)

all: site

format:
	@find ./roles/sourcemod/files/addons/sourcemod/scripting -regex '.*\.\(sp\)' -exec clang-format -style=file -i {} \;

lint:
	@ansible-lint

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser:
	@ansible-playbook $(COMMON_ARGS)/adduser.yml -u root

pre:
	@ansible-playbook $(COMMON_ARGS)/pre.yml

sourcemod:
	@ansible-playbook $(COMMON_ARGS)/sourcemod.yml

test: srcds
	docker stop srcds-localhost-1 || true # dont bail if a container doesnt already exist
	docker rm srcds-localhost-1 || true
	ansible-playbook playbooks/deploy.yml --limit localhost -K
	make logs

logs:
	docker logs -f srcds-localhost-1

srcds:
	@ansible-playbook -l tf2 $(PLAYBOOK_PATH)/srcds.yml

shell:
	@docker exec -it srcds-test-1 bash

web:
	@ansible-playbook $(COMMON_ARGS)/web.yml --limit metrics

srcdsup:
	@ansible-playbook$(COMMON_ARGS)/srcdsup.yml

vpn:
	# This *does not work* when using --limit
	@ansible-playbook /vpn.yml

game_config:
	@ansible-playbook $(COMMON_ARGS)/deploy.yml --tags game_config

system:
	@ansible-playbook $(COMMON_ARGS)/system.yml

wg:
	@ansible-playbook $(COMMON_ARGS)/wg.yml

site:
	ansible-playbook $(COMMON_ARGS)/site.yml

ping:
	@ansible tf2 -m ping $(ARGS)

restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u $(USER) -i hosts.yml -b
