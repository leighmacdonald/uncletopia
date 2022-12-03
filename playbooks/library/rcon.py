#!/usr/bin/python
# -*- coding: utf-8 -*-

DOCUMENTATION = r'''
---
module: rcon
short_description: Remotely control game servers
options:
    address:
        description: RCON-enabled game server remote address
        required: true
        type: str
    port:
        description: Game server port
        required: true
        type: int
    password:
        description: The rcon password
        required: true
        type: str
    command:
        description: What command to send
        required: true
        type: list
author:
    - viora (@crescentrose)
'''

EXAMPLES = r'''
- name: Say "hello world" to a local TF2 server
  rcon:
    address: localhost
    port: 27015
    password: password
    command: ['say', 'Hello, world!']
'''

RETURN = r'''
response:
    description: Response from the server, if any
    type: str
    returned: always
    sample: "Console: hello, world!\nL 12/03/2022 - 16:37:03: \"Console<0><Console><Console>\" say \"hello, world!\"\n"
'''

from ansible.module_utils.basic import *
from rcon.source import Client
from rcon.exceptions import WrongPassword, EmptyResponse

def rcon(addr: str, port: int, password: str, cmd: str):
  with Client(addr, port, passwd=password) as client:
    response = client.run(cmd)
  return response

def main():
  fields = {
    "address": {"required": True, "type": "str"},
    "port": {"required": True, "type": "int"},
    "password": {"required": True, "type": "str", "no_log": True},
    "command": {"required": True, "type": "str"}
  }

  module = AnsibleModule(argument_spec=fields)

  try:
    response = rcon(
      module.params['address'],
      module.params['port'],
      module.params['password'],
      module.params['command']
    )
  except ConnectionError:
    return module.fail_json("cannot connect to rcon host " + module.params['address'])
  except WrongPassword:
    return module.fail_json("wrong password provided for rcon host " + module.params['address'])
  except EmptyResponse:
    return module.fail_json("no response from rcon host " + module.params['address'])

  module.exit_json(changed=True, meta={"response": response})

if __name__ == '__main__':
  main()
