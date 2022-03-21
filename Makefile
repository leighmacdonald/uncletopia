.PHONY: all pre system deploy

all: deploy

deps:
	@ansible-galaxy install -f -r collections/requirements.yml

adduser: deps
	@ansible-playbook adduser.yml -u ubuntu $(ARGS)

pre: deps
	@ansible-playbook pre.yml $(ARGS)

system: deps
	@ansible-playbook system.yml $(ARGS)

wg: deps
	@ansible-playbook wg.yml $(ARGS)

deploy: deps
	@ansible-playbook deploy.yml $(ARGS)

# Only deploy new game config files, skipping container redeploy/restart steps
config: deps
	@ansible-playbook deploy.yml --tags "game_config" $(ARGS)

ping:
	@ansible tf2 -m ping $(ARGS)

mge_deploy:
	@ansible-playbook -i mgehosts.yml deploy.yml $(ARGS)

test_adduser:
	@ansible-playbook --limit test adduser.yml -u root $(ARGS)

test_pre:
	@ansible-playbook --limit test pre.yml $(ARGS)

test_system:
	@ansible-playbook --limit test system.yml $(ARGS)

test_deploy:
	@ansible-playbook --limit test deploy.yml $(ARGS)

test_ping:
	@ansible tf2 -m ping --limit test $(ARGS)

restart:
	@ansible tf2 -a "/sbin/reboot now" -f 10 -u tf2server --become $(ARGS)
