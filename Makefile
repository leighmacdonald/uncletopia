.PHONY: all pre system deploy

PLAYBOOK_PATH := ./playbooks
HOSTS := hosts.yml
USER := tf2server

all: site

format:
	@find ./roles/sourcemod/files/addons/sourcemod/scripting -regex '.*\.\(sp\)' -exec clang-format -style=file -i {} \;

lint:
	@ansible-lint

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser:
	@ansible-playbook -u root -i $(HOSTS) $(PLAYBOOK_PATH)/adduser.yml

pre:
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/pre.yml

sourcemod:
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/sourcemod.yml

deploy:
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/deploy.yml

srcds:
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/srcds.yml

srcds_clean:
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/srcds.yml

web:
	ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/web.yml --limit metrics

vpn:
	# This *does not work* when using --limit
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/vpn.yml

system:
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/system.yml

wg:
	@ansible-playbook -u $(USER) -i $(HOSTS) $(PLAYBOOK_PATH)/wg.yml

site:
	ansible-playbook -u $(USER) -i $(HOSTS) site.yml

ping:
	@ansible tf2 -m ping $(ARGS)

restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u $(USER) -i $(HOSTS) -b

game_config:
	ansible-playbook $(PLAYBOOK_PATH)/srcds.yml -u $(USER) -i $(HOSTS) --tags game_config
