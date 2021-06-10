.PHONY: all pre system deploy

all: deploy

deps:
	@ansible-galaxy install -f -r requirements.yml

adduser: deps
	@ansible-playbook adduser.yml -u root $(ARGS)

pre: deps
	@ansible-playbook pre.yml $(ARGS)

system: deps
	@ansible-playbook system.yml $(ARGS)

deploy: deps
	@ansible-playbook deploy.yml $(ARGS)

ping:
	@ansible tf2 -m ping $(ARGS)

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

restart:
	@ansible-playbook restart.yml $(ARGS)

rm:
	ansible -m file -a "state=absent path=$(ARGS)"
