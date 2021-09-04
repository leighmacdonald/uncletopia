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


stage_adduser:
#	@ansible-playbook -i staginghosts.yml adduser.yml -u root $(ARGS)
	@ansible-playbook -i staginghosts.yml adduser.yml -u ubuntu $(ARGS)
#	@ansible-playbook -i staginghosts.yml adduser.yml -u danethebrain $(ARGS)

stage_pre:
	@ansible-playbook -i staginghosts.yml pre.yml $(ARGS)

stage_system:
	@ansible-playbook -i staginghosts.yml system.yml $(ARGS)

stage_deploy:
	@ansible-playbook -i staginghosts.yml deploy.yml $(ARGS)

stage_ping:
	@ansible tf2 -m ping -i staginghosts.yml $(ARGS)

stage_restart:
	@ansible all -m reboot -a reboot_timeout=3600 -u tf2server -i staginghosts.yml -b

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
	@ansible tf2 -a "/sbin/reboot now" -f 10 -u tf2server --become $(ARGS)

rm:
	ansible -m file -a "state=absent path=$(ARGS)"
