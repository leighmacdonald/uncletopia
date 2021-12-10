import logging
import json
from os.path import dirname, abspath, join
import _thread
from collections import namedtuple
import websocket
from ansible.playbook.play import Play
from ansible.parsing.dataloader import DataLoader
from ansible.vars.manager import VariableManager
from ansible.inventory.manager import InventoryManager
from ansible.playbook.play import Play
from ansible.executor.playbook_executor import PlaybookExecutor

# Url to a instance of https://github.com/xPaw/SteamWebPipes
ANNOUNCE_URL = "wss://update.uncletopia.com"

# Trigger update for specific app id's
# TF2 should be 232250 for the server component, not 440 which is the client
APP_ID = "232250"

SCRIPT_DIR = dirname(join(abspath(__file__), ".."))
ROOT_DIR = dirname(SCRIPT_DIR)

update_running = False
log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)

def run_playbook_tf2(args: object) -> None:
    global update_running
    log.info("Running TF2 playbook")
    update_running = True
    try:
        playbook_path = "roles/tf2/tasks/main.yml"
        inventory_path = "hosts"

        Options = namedtuple('Options', ['connection', 'module_path', 'forks', 'become', 'become_method', 'become_user', 
            'check', 'diff', 'listhosts', 'listtasks', 'listtags', 'syntax'])
        loader = DataLoader()
        options = Options(
            connection='local', 
            module_path='%s/' % (ROOT_DIR), 
            forks=100, 
            become=None, 
            become_method=None, 
            become_user=None, 
            check=False,
            diff=False, 
            listhosts=False, 
            listtasks=True, 
            listtags=False, 
            syntax=False)
        passwords = dict(vault_pass='')
        inventory = InventoryManager(loader=loader, sources=[inventory_path])
        variable_manager = VariableManager(loader=loader, inventory=inventory)
        executor = PlaybookExecutor(  
                    playbooks=[playbook_path], inventory=inventory, variable_manager=variable_manager, loader=loader,  
                    options=options, passwords=passwords)  
        results = executor.run()  
        print(results)
    finally:
        update_running = False

def on_message(ws, message):
    global update_running
    try:
        data = json.loads(message)
        if data["Type"] == "Changelist":
            if APP_ID in data["Apps"]:
                print("Appid update triggered: {} {}".format(data["ChangeNumber"], data["Apps"].keys()))
                if update_running:
                    log.error("Failed to start update, exiting update still in progress")
                else:
                    _thread.start_new_thread(run_playbook_tf2, (data,))
            else:
                print("Appid update skipped: {} {}".format(data["ChangeNumber"], ",".join(data["Apps"].keys())))
        elif data["Type"] == "UsersOnline":
            print("Users online: {}".format(data["Users"]))
        elif data["Type"] == "LogOn":
            print("Steam logon")
        elif data["Type"] == "LogOff":
            print("Steam logoff")
        else:
            print("Unsupported key: {}".format(data["Type"]))
    except KeyError as err:
        print(err)

def on_error(ws, error):
    print("Connection error: {}", error)

def on_close(ws, close_status_code, close_msg):
    print("Connection closed: {} {}", close_status_code, close_msg)

def on_open(ws):
    print("Connection opened")

if __name__ == "__main__":
    ws = websocket.WebSocketApp(ANNOUNCE_URL, on_open=on_open, on_message=on_message, on_error=on_error, on_close=on_close)
    ws.run_forever()