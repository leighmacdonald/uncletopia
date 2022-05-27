#!/usr/bin/env python3
import argparse
import json


def get_empty_vars():
    return json.dumps({})

def get_list(addresses, pretty):
    return {
        "_meta": {
            "hostvars": {}
        },
        "all": {
            "children": [
                "local",
                "build",
                "metrics",
                "web",
                "tf2",
            ]
        },
        "local": {
            "hosts": [
                "localhost"
            ]
        },
        "build": {
            "hosts": [
                "mtl-1.ca.uncletopia.com"
            ]
        },
        "metrics": {
            "hosts": [
                "mtl-1.ca.uncletopia.com"
            ]
        },
        "web": {
            "hosts": [
                "mtl-1.ca.uncletopia.com"
            ]
        },
        "tf2": {
            "children": [
                "production",
                "staging"
            ]
        },
        "production": {
            "children": [
                "nac"
            ]
        },
        "nac": {
            "hosts": [
                "mtl-1.ca.uncletopia.com"
            ]
        },
        "staging": {
            "hosts": [
                "test-1.ca.uncletopia.com"
            ]
        }
    }

if __name__ == "__main__":
    arg_parser = argparse.ArgumentParser(description=__doc__, prog=__file__)
    arg_parser.add_argument('--pretty', action='store_true', default=False, help="Pretty print JSON")
    mandatory_options = arg_parser.add_mutually_exclusive_group()
    mandatory_options.add_argument('--list', action='store', nargs="*", default="dummy", help="Show JSON of all managed inventory.py")
    mandatory_options.add_argument('--host', action='store', help="Display vars related to the host")

    try:
        addresses = []

        args = arg_parser.parse_args()
        if args.host:
            print(json.dumps(get_empty_vars()))
        elif len(args.list) >= 0:
            print(json.dumps(get_list(addresses, args.pretty)))
        else:
            raise ValueError("Expecting either --host $HOSTNAME or --list")

    except ValueError:
        raise
