#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sdktools>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo = {
	name = "No Contracker", 
	author = "Malifox, Sreaper", 
	description = "Blocks Contracker", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart() {
	CreateConVar("sm_nocontracker_version", PLUGIN_VERSION, "No Contracker plugin version.", FCVAR_REPLICATED | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	AddCommandListener(Commands_CommandListener, "cyoa_pda_open");
}

public Action Commands_CommandListener(int client, const char[] command, int argc) {
    if (!IsClientValid(client)) {
        return Plugin_Continue;
    }
    char cmd[16];
    GetCmdArg(1, cmd, sizeof(cmd)); 
    if (StringToInt(cmd) != 0) {
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public void OnEntityCreated(int iEnt, char[] classname) {
    if(IsValidEntity(iEnt) && StrEqual(classname, "tf_wearable_campaign_item"))
    {
        AcceptEntityInput(iEnt, "Kill");
    }
}

bool IsClientValid(int i) {
    return 0 < i <= MaxClients && IsClientInGame(i);
} 