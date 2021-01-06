.PHONY: all pre system deploy

all: deploy

adduser:
	@ansible-playbook adduser.yml -u root

pre:
	@ansible-playbook pre.yml

system:
	@ansible-playbook system.yml

deploy:
	@ansible-playbook deploy.yml

debug:
	@ansible-playbook deploy.yml -v

ping:
	@ansible tf2 -m ping

test_adduser:
	@ansible-playbook -i testhost.yml adduser.yml -u root

test_pre:
	@ansible-playbook -i testhost.yml pre.yml

test_system:
	@ansible-playbook -i testhost.yml system.yml

test_deploy:
	@ansible-playbook -i testhost.yml deploy.yml

test_debug:
	@ansible-playbook -i testhost.yml deploy.yml -v

test_ping:
	@ansible tf2 -m ping -i testhost.yml

restart:
	@ansible-playbook restart.yml

test_restart:
	@ansible-playbook -i testhost.yml restart.yml