#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <basecomm>
#include <json> // sm-json
#include <sdktools>
#include <sourcemod>
#include <system2> // system2 extension
#include <connect> // connect extension
#include <gbans>

#include "gbans/globals.sp"
#include "gbans/common.sp"
#include "gbans/ban.sp"
#include "gbans/commands.sp"
#include "gbans/connect.sp"
#include "gbans/auth.sp"

#define DEBUG

public
Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, description = "gbans game client",
                 version = PLUGIN_VERSION, url = "https://github.com/leighmacdonald/gbans"};

public Extension __ext_Connect = 
{
	name = "Connect",
	file = "connect.ext",
	autoload = 1,
	required = 1,
}

public
void OnPluginStart() {
    LoadTranslations("common.phrases.txt");

    RegConsoleCmd("gb_version", CmdVersion, "Get gbans version");
    RegConsoleCmd("gb_mod", CmdMod, "Ping a moderator");
    RegConsoleCmd("mod", CmdMod, "Ping a moderator");
    RegAdminCmd("gb_ban", AdminCmdBan, ADMFLAG_BAN);
    RegAdminCmd("gb_reauth", AdminCmdReauth, ADMFLAG_ROOT);
    RegAdminCmd("gb_reload", AdminCmdReload, ADMFLAG_ROOT);
    RegConsoleCmd("gb_help", CmdHelp, "Get a list of gbans commands");

    readConfig();
    refreshToken();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GB_BanClient", Native_GB_BanClient);
	return APLRes_Success;
}
