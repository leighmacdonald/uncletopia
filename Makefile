.PHONY: all pre system deploy

all: deploy

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser: deps
	@ansible-playbook adduser.yml -u root $(ARGS)

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

restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u tf2server -i hosts.yml -b

test_adduser:
	@ansible-playbook -i testhost.yml adduser.yml -u root $(ARGS)

test_pre:
	@ansible-playbook -i testhost.yml pre.yml $(ARGS)

test_system:
	@ansible-playbook -i testhost.yml system.yml $(ARGS)

test_deploy:
	@ansible-playbook -i testhost.yml deploy.yml $(ARGS)

test_ping:
	@ansible tf2 -m ping -i testhost.yml $(ARGS)

rm:
	ansible -m file -a "state=absent path=$(ARGS)"
