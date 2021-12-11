import logging
import json
from os.path import dirname, abspath, join
import _thread
import websocket
import requests

# Url to a instance of https://github.com/xPaw/SteamWebPipes
ANNOUNCE_URL = "wss://update.uncletopia.com"
AWX_URL = "https://deploy.uncletopia.com/api/v2"

# Trigger update for specific app id's
# TF2 should be 232250 for the server component, not 440 which is the client
APP_ID = "232250"

USERNAME = ""
PASSWORD = "!"

SCRIPT_DIR = dirname(join(abspath(__file__), ".."))
ROOT_DIR = dirname(SCRIPT_DIR)

update_running = False
log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


def api_request(path, data):
    u = AWX_URL + path
    print(u)
    resp = requests.post(u, json=data, headers={"content-type": "application/json"})
    return resp


def trigger_playbook(args: object) -> None:
    global update_running
    log.info("Running TF2 playbook")
    update_running = True

    authResp = api_request("/authtoken/", {"username": USERNAME, "password": PASSWORD})

    try:
        sess = requests.Session()
        sess.get("")
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
                    _thread.start_new_thread(trigger_playbook, (data,))
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
    print("Connection closed: {} {}".format(close_status_code, close_msg))

def on_open(ws):
    print("Connection opened")

if __name__ == "__main__":
    print(api_request("/authtoken/", {"username": USERNAME, "password": PASSWORD}))
    ws = websocket.WebSocketApp(ANNOUNCE_URL, on_open=on_open, on_message=on_message, on_error=on_error, on_close=on_close)
    ws.run_forever()