.PHONY: all pre system deploy

PLAYBOOK_PATH := ./playbooks
HOSTS := hosts.yml
USER := tf2server
FORKS := 20

all: site

#format:
#	@find ./roles/sourcemod/files/addons/sourcemod/scripting -regex '.*\.\(sp\)' -exec clang-format -style=file -i {} \;

lint:
	@ansible-lint --exclude sm_plugins watcher

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser:
	@ansible-playbook -u root -i $(HOSTS) --forks $(FORKS) $(PLAYBOOK_PATH)/adduser.yml

srcds:
	@ansible-playbook -u $(USER) -i $(HOSTS) --forks $(FORKS) $(PLAYBOOK_PATH)/srcds.yml

web:
	ansible-playbook -u $(USER) -i $(HOSTS) --forks $(FORKS) $(PLAYBOOK_PATH)/web.yml --limit metrics

vpn:
	@ansible-playbook -u $(USER) -i $(HOSTS) --forks $(FORKS) $(PLAYBOOK_PATH)/vpn.yml

system:
	@ansible-playbook -u $(USER) -i $(HOSTS) --forks $(FORKS) $(PLAYBOOK_PATH)/system.yml

site:
	ansible-playbook -u $(USER) -i $(HOSTS) --forks $(FORKS) site.yml

ping:
	@ansible tf2 -m ping $(ARGS)

update:
	@ansible-playbook -u $(USER) -i $(HOSTS) --forks $(FORKS) $(PLAYBOOK_PATH)/update.yml --limit sao-1.br.uncletopia.com

game_engine:
	@ansible-playbook -u $(USER) -i $(HOSTS) --forks $(FORKS) --tags game_engine $(PLAYBOOK_PATH)/srcds.yml

game_config:
	@ansible-playbook $(PLAYBOOK_PATH)/srcds.yml -u $(USER) -i $(HOSTS) --tags game_config --forks $(FORKS)

srcds-test:
	@ansible-playbook -u $(USER) -i dev.hosts --forks $(FORKS) $(PLAYBOOK_PATH)/srcds.yml