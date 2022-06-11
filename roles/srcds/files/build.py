#!/usr/bin/env python3
import subprocess
from os import makedirs, unlink, chdir
from os.path import join, exists, realpath, dirname


BASE_DIR = dirname(realpath(__file__))
OUTPUT_PATH = join(BASE_DIR, "..", "plugins")
COMPILER = "/build/addons/sourcemod/scripting/spcomp64"
INCLUDE_PATHS = [
    # Docker container build path
    # "/build/sourcemod/addons/sourcemod/scripting/include",
    join(BASE_DIR, "addons", "sourcemod", "scripting", "include")
]
PLUGINS = [
    "autorecorder",
    "admin-allspec",
    #"classrestrict",
    "cronjobs",
    "disableautokick",
    "extendedmapconfig",
    "gbans",
    "medicstats",
    "nativevotes-basecommands",
    "nativevotes-basevotes",
    "nativevotes",
    "NetworkTools",
    "SendToSpec",
    "stac",
    "supstats2",
    "system2_http",
    # "tf_kick_immunity",
    "tf2-comp-fixes",
    "tf2attributes",
    "tf2centerprojectiles",
    "tidychat",
    "uncletopia-nags",
    "unusedvoicelines",
    "votescramble",
    "waitingdoors"
]

def compile_sp(input_name, out_path):
    out_file = join(out_path, input_name)
    if exists(out_file):
        unlink(out_file)
    cmd = [COMPILER, input_name + ".sp", "-v1",  "-o{}.smx".format(out_file)]
    includes = ["-i{}".format(i) for i in INCLUDE_PATHS]
    print("{}".format(" ".join(cmd + includes)))
    res = subprocess.call(cmd + includes, shell=False)
    if res == 0:
        print("Successfully built {}".format(input_name))
    else:
        raise Exception("Bad return value: {}".format(res))


def main():
    if not exists(OUTPUT_PATH):
        makedirs(OUTPUT_PATH)
    chdir(BASE_DIR)
    ok = 0
    for plugin_name in PLUGINS:
        try:
            compile_sp(plugin_name, OUTPUT_PATH)
            ok += 1
        except Exception as err:
            print("Error compiling plugin: {}".format(err))
            return 1
    print("\nCompilation status: {}/{} Plugins successfully built [{}]".format(ok, len(PLUGINS), OUTPUT_PATH))
    return 0


if __name__ == "__main__":
    exit(main())
