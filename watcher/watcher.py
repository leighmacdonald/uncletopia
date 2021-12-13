"""
Basic script to watch for
"""
import logging
import json
from os import environ
import websocket
import requests

# Url to an instance of https://github.com/xPaw/SteamWebPipes
ANNOUNCE_URL = "wss://update.uncletopia.com"

# Tower/AWX api url https://github.com/ansible/awx
AWX_URL = "https://deploy.uncletopia.com/api/v2"

# Name of AWX job template to execute
TEMPLATE_CONFIG = "Deploy TF2 Config"

# Trigger update for specific app id's
# TF2 should be 232250 for the server component, not 440 which is the client
APP_ID = "232250"


update_running = False

log = logging.getLogger(__name__)


class WatcherException(Exception):
    pass


def api_request(method, path, data=None):
    u = AWX_URL + path
    resp = getattr(requests, method.lower())(u, json=data, headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer {}".format(PAT)})
    if not resp.ok:
        raise WatcherException("Invalid http response: {}".format(resp.status_code))
    return resp.json()


def find_template(name: str):
    for res in api_request("get", "/job_templates/")["results"]:
        if res["name"].lower() == name.lower():
            return res
    raise WatcherException("Failed to find matching template")


def run_template(template_name: str):
    try:
        tpl = find_template(template_name)
        api_request("post", "/job_templates/{}/launch/".format(tpl["id"]))
    except WatcherException:
        log.exception("Application error", exc_info=True)
    except Exception:
        log.exception("Unhandled exception", exc_info=True)


def on_message(_, message):
    try:
        data = json.loads(message)
        if data["Type"] == "Changelist":
            if APP_ID in data["Apps"]:
                log.info("Appid update triggered: {} {}".format(data["ChangeNumber"], ",".join(data["Apps"].keys())))
                run_template(TEMPLATE_CONFIG)
            else:
                log.debug("Appid update skipped: {} {}".format(data["ChangeNumber"], ",".join(data["Apps"].keys())))
        elif data["Type"] == "UsersOnline":
            log.debug("Users online: {}".format(data["Users"]))
        elif data["Type"] == "LogOn":
            log.info("Steam logon")
        elif data["Type"] == "LogOff":
            log.info("Steam logoff")
        else:
            raise WatcherException("Unsupported key: {}".format(data["Type"]))
    except KeyError as err:
        log.exception("Unhandled exception", exc_info=True)


def on_error(_, error):
    log.exception("Connection error: {}", exc_info=True)


def on_close(_, close_status_code, close_msg):
    log.info("Connection closed: {} {}".format(close_status_code, close_msg))


def on_open(_):
    log.info("Connection opened")


if __name__ == "__main__":
    logging.basicConfig()
    log.setLevel(logging.INFO)
    PAT = environ.get("PAT")
    if PAT == "":
        log.fatal("Must set PAT env var to personal access token")
    conn = websocket.WebSocketApp(ANNOUNCE_URL, on_open=on_open, on_message=on_message, on_error=on_error,
                                  on_close=on_close)
    conn.run_forever()
