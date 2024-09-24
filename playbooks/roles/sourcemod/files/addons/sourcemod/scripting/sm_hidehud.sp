#include <sdktools>

#define HIDEHUD_ALL 4

public Plugin myinfo = 
{
	name = "[TF2] Hide Hud", 
	author = "Moonly Days", 
	description = "Displays a taunt menu.", 
	version = "1.0.0", 
	url = "https://github.com/MoonlyDays"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_hidehud", cHideHud);
}

bool CanPlayerToggleHud(int client) {

    if(GetClientTeam(client) <= 1) {
        return true;
    }

    return IsPlayerAlive(client);
}

public Action cHideHud(int client, int args)
{
    if(! CanPlayerToggleHud(client)) {
        ReplyToCommand(client, "[SM] You must be alive to use this.");
        return Plugin_Handled;
    }

    if(ToggleHud(client)) {
        ReplyToCommand(client, "[SM] Your HUD is now hidden! Use this command again to revert.");
    } else {
        ReplyToCommand(client, "[SM] Your HUD is now visible again!");
    }
    
    return Plugin_Handled;
}

public bool ToggleHud(int client)
{
    int hideFlags = GetEntProp(client, Prop_Send, "m_iHideHUD");
    bool hidden = (hideFlags & HIDEHUD_ALL) > 0;
    if(hidden) {
        SetEntProp(client, Prop_Send, "m_iHideHUD", 0);
    } else {
        SetEntProp(client, Prop_Send, "m_iHideHUD", HIDEHUD_ALL);
    }

    return !hidden;
}