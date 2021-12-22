.PHONY: all pre system deploy
VAULT_PASS_PATH := ~/.vault_pass.txt
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

adduser:
	@ansible-playbook playbooks/adduser.yml -u root $(ARGS)

pre:
	@ansible-playbook playbooks/pre.yml $(ARGS)

list_hosts:
	ansible all --list-hosts --vault-password-file $(VAULT_PASS_PATH)

srcds:
	@ansible-playbook --limit "flk-1.de.uncletopia.com" --vault-password-file $(VAULT_PASS_PATH) playbooks/srcds.yml $(ARGS) 

metrics:
	@ansible-playbook --vault-password-file $(VAULT_PASS_PATH) playbooks/metrics.yml $(ARGS) 

gbans:
	@ansible-playbook --vault-password-file $(VAULT_PASS_PATH) playbooks/gbans.yml $(ARGS) 

system:
	@ansible-playbook playbooks/system.yml $(ARGS)

sourcemod:
	@./roles/srcds/files/build.py

wg:
	@ansible-playbook playbooks/wg.yml $(ARGS)

deploy:
	@ansible-playbook playbooks/deploy.yml $(ARGS)

# Only deploy new game config files, skipping container redeploy/restart steps
config:
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
