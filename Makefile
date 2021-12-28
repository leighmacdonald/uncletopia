.PHONY: all pre system deploy
VAULT_PASS_PATH := ~/.vault_pass.txt
PROD_OPTS := -l production --vault-password-file $(VAULT_PASS_PATH)
STAGING_OPTS := -l staging --vault-password-file $(VAULT_PASS_PATH)
TESTING_OPTS := -l testing --vault-password-file $(VAULT_PASS_PATH)
MGE_OPTS := -l mge --vault-password-file $(VAULT_PASS_PATH)
PLAYBOOK_PATH := ./playbooks

all: deploy

build_remote:
	@ansible-playbook $(STAGING_OPTS) $(PLAYBOOK_PATH)/srcds.yml $(ARGS)

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/adduser.yml -u root $(ARGS)

pre:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/pre.yml $(ARGS)

srcds:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/srcds.yml $(ARGS) 

metrics:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/metrics.yml $(ARGS) 

gbans:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/gbans.yml $(ARGS) 

system:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/system.yml $(ARGS)

wg:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/wg.yml $(ARGS)

deploy:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/deploy.yml $(ARGS)

# Only deploy new game config files, skipping container redeploy/restart steps
config:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/deploy.yml --tags "game_config" $(ARGS)

mge_deploy:
	@ansible-playbook $(MGE_OPTS) $(PLAYBOOK_PATH)/deploy.yml $(ARGS)

stage_deploy:
	@ansible-playbook $(STAGING_OPTS) $(PLAYBOOK_PATH)/deploy.yml $(ARGS)

test_adduser:
	@ansible-playbook $(TESTING_OPTS) $(PLAYBOOK_PATH)/adduser.yml -u root $(ARGS)

test_pre:
	@ansible-playbook $(TESTING_OPTS) $(PLAYBOOK_PATH)/pre.yml $(ARGS)

test_system:
	@ansible-playbook $(TESTING_OPTS) $(PLAYBOOK_PATH)/system.yml $(ARGS)

test_srcds:
	@ansible-playbook $(TESTING_OPTS) $(PLAYBOOK_PATH)/srcds.yml $(ARGS)

test_deploy:
	@ansible-playbook $(TESTING_OPTS) $(PLAYBOOK_PATH)/deploy.yml $(ARGS)

test_ping:
	@ansible tf2 -m ping -i testhost.yml $(ARGS)

compile_sm: build_sm
	docker run -it leighmacdonald/uncletopia-sourcemod:latest

build_sm:
	docker build -t leighmacdonald/uncletopia-sourcemod:latest -f docker/sourcemod.Dockerfile .

build_srcds: build_sm
	docker build -t leighmacdonald/uncletopia:latest -f docker/srcds.Dockerfile .

shell_srcds: build_srcds
	docker run -it leighmacdonald/uncletopia:latest

list_hosts:
	ansible all --list-hosts $(OPTS)

sourcemod:
	@./roles/srcds/files/build.py

ping:
	@ansible tf2 -m ping $(ARGS)

restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u tf2server -i hosts.yml -b
	