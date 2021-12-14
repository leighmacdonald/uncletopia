import subprocess
from os import makedirs, unlink
from os.path import join, exists

COMPILER = "spcomp"
OUTPUT_PATH = "../plugins"
INCLUDE_PATHS = [
    "/build/sourcemod/addons/sourcemod/scripting/include",
    "./include",
]
PLUGINS = [
    "SendToSpec", 
    "admin-allspec", 
    "cronjobs", 
    "nativevotes-basecommands", 
    "nativevotes-basevotes", 
    "nativevotes",
    "stac", 
    "system2_http",
    "tf2-comp-fixes", 
    "tf2attributes",
    "tf2centerprojectiles", 
    "umc-adminmenu",
    "umc-core",
    "umc-echonextmap", 
    "umc-endvote-warnings",
    "umc-endvote",
    "umc-mapcommands",
    "umc-maprate-reweight", 
    "umc-nativevotes",
    "umc-nominate",
    "umc-playercountmonitor", 
    "umc-playerlimits", 
    "umc-postexclude",
    "umc-prefixexclude",
    "umc-randomcycle", 
    "umc-rockthevote", 
    "umc-timelimits", 
    "umc-votecommand",
    "umc-weight", 
    "unusedvoicelines",
    "votescramble",
    "waitingdoors"
]


def compile_sp(input_name, out_path):
    print("Compiling {}.sp".format(input_name))
    out_file = join(out_path, input_name)
    if exists(out_file):
        unlink(out_file)
    cmd = [COMPILER, input_name + ".sp", "-v0",  "-o{}.smx".format(out_file)]
    includes = ["-i{}".format(i) for i in INCLUDE_PATHS]
    print("sp: {}".format(" ".join(cmd + includes)))
    res = subprocess.call(cmd + includes, shell=False)
    if res == 0:
        print("Successfully built {}".format(input_name))
    else:
        raise Exception("Bad return value: {}".format(res))


def main():
    if not exists(OUTPUT_PATH):
        makedirs(OUTPUT_PATH)
    ok = 0
    for plugin_name in PLUGINS:
        try:
            compile_sp(plugin_name, OUTPUT_PATH)
            ok += 1
        except Exception as err:
            print("Error compiling plugin: {}".format(err))
            return 1
    print("\nCompilation status: {}/{} Plugins successfully built".format(ok, len(PLUGINS)))
    return 0


if __name__ == "__main__":
    exit(main())