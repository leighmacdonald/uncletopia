.PHONY: all pre system deploy
VAULT_PASS_PATH := ~/.vault_pass.txt
PROD_OPTS := -l production --vault-password-file $(VAULT_PASS_PATH)
BUILD_OPTS := -l build --vault-password-file $(VAULT_PASS_PATH)
LOCAL_OPTS := -l local --vault-password-file $(VAULT_PASS_PATH)
STAGING_OPTS := -l staging --vault-password-file $(VAULT_PASS_PATH)
TESTING_OPTS := -l testing --vault-password-file $(VAULT_PASS_PATH)
MGE_OPTS := -l mge --vault-password-file $(VAULT_PASS_PATH)
PLAYBOOK_PATH := ./playbooks

all: deploy

build_local:
	@ansible-playbook $(BUILD_OPTS) $(PLAYBOOK_PATH)/srcds.yml $(ARGS)

build_remote:
	@ansible-playbook $(BUILD_OPTS) $(PLAYBOOK_PATH)/srcds.yml $(ARGS)

deps:
	@ansible-galaxy collection install -r collections/requirements.yml

adduser:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/adduser.yml -u root $(ARGS)

pre:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/pre.yml $(ARGS)

srcds:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/srcds.yml $(ARGS) 

node_exporter:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/node_exporter.yml $(ARGS) 

metrics:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/metrics.yml $(ARGS) 

uncletopiaweb:
	@ansible-playbook $(PROD_OPTS) $(PLAYBOOK_PATH)/uncletopiaweb.yml $(ARGS) 

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

compile_sm: docker_build_sm
	docker run -it leighmacdonald/uncletopia-sourcemod:latest

docker_build_game:
	docker build -t leighmacdonald/uncletopia:latest --target game_build -f ./roles/srcds/files/Dockerfile ./roles/srcds/files/

docker_build_sm:
	docker build -t leighmacdonald/uncletopia:latest --no-cache --target sm_build -f ./roles/srcds/files/Dockerfile ./roles/srcds/files/

docker_build:
	docker build -t leighmacdonald/uncletopia:latest -f ./roles/srcds/files/Dockerfile ./roles/srcds/files/

rebuild_srcds:
	docker build -t leighmacdonald/uncletopia:latest --no-cache -f ./roles/srcds/files/Dockerfile ./roles/srcds/files/

shell_srcds: docker_build_srcds
	docker run -it leighmacdonald/uncletopia:latest

list_hosts:
	ansible all --list-hosts $(OPTS)

sourcemod:
	@./roles/srcds/files/build.py

ping:
	@ansible tf2 -m ping $(ARGS)

restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u tf2server -i hosts.yml -b
