.PHONY: all pre system deploy

all: deploy

compile_sm: build_sm
	docker run -it leighmacdonald/uncletopia-sourcemod:latest

build_sm:
	docker build -t leighmacdonald/uncletopia-sourcemod:latest -f docker/sourcemod.Dockerfile .

build_srcds: build_sm
	docker build -t leighmacdonald/uncletopia:latest -f docker/srcds.Dockerfile .

shell_srcds: build_srcds
	docker run -it leighmacdonald/uncletopia:latest

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser: deps
	@ansible-playbook playbooks/adduser.yml -u root $(ARGS)

pre: deps
	@ansible-playbook playbooks/pre.yml $(ARGS)

srcds: deps
	@ansible-playbook playbooks/srcds.yml $(ARGS) 

system: deps
	@ansible-playbook playbooks/system.yml $(ARGS)

wg: deps
	@ansible-playbook playbooks/wg.yml $(ARGS)

deploy: deps
	@ansible-playbook playbooks/deploy.yml $(ARGS)

# Only deploy new game config files, skipping container redeploy/restart steps
config: deps
	@ansible-playbook deploy.yml --tags "game_config" $(ARGS)

ping:
	@ansible tf2 -m ping $(ARGS)

mge_deploy:
	@ansible-playbook -i mgehosts.yml playbooks/deploy.yml $(ARGS)

restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u tf2server -i hosts.yml -b

test_adduser:
	@ansible-playbook -i testhost.yml playbooks/adduser.yml -u root $(ARGS)

test_pre:
	@ansible-playbook -i testhost.yml playbooks/pre.yml $(ARGS)

test_system:
	@ansible-playbook -i testhost.yml playbooks/system.yml $(ARGS)

test_srcds:
	@ansible-playbook -i testhost.yml playbooks/srcds.yml $(ARGS)

test_deploy:
	@ansible-playbook -i testhost.yml playbooks/deploy.yml $(ARGS)

test_ping:
	@ansible tf2 -m ping -i testhost.yml $(ARGS)

rm:
	ansible -m file -a "state=absent path=$(ARGS)"
