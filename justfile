playbook_path := "./"
user := "tf2server"
forks := "20"
inventory := "prod.hosts"

all: site

lint:
    @ansible-lint --exclude sm_plugins --exclude watcher --exclude roles/*/files

deps:
    @ansible-galaxy collection install -r requirements.yml

adduser:
    @ansible-playbook -u root -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/adduser.yml

srcds:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/srcds.yml

web:
    ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/web.yml --limit metrics

# vpn:
#     @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/vpn.yml
# Note: vpn.yml does not exist. Remove or implement the vpn playbook.

system:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/system.yml

site:
    ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} site.yml

update:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/update.yml

game_engine:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} --tags game_engine {{ playbook_path }}/srcds.yml

game_config:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} --tags game_config {{ playbook_path }}/srcds.yml

demostats:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/demostats.yml

tf2bdd:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/tf2bdd.yml

firewall:
    @ansible-playbook -u {{ user }} -i {{ inventory }} --forks {{ forks }} {{ playbook_path }}/firewall.yml
