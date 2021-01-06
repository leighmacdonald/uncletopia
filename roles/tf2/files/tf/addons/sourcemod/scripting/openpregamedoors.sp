#include <sourcemod>
#include <gamemode>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1

#define PLUGIN_VERSION "1.5"

public Plugin myinfo =
{
	name = "[TF2] Open Pre-Game Doors",
	author = "Qball",
	description = "Opens the waiting for players doors for BLU team on Payload and A/D gamemodes.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/qballking4/"
};

public void OnPluginStart()
{
    HookEventEx("teamplay_round_active", teamplay_round_active);
}
public void teamplay_round_active(Event event, const char[] name, bool dontBroadcast)
{
    int ent = -1;
    bool IsWaitingForPlayers = false;
    char m_iName[64];

    // Check do we have entity team_round_timer "zz_teamplay_waiting_timer" ? (Waiting for players)
    while((ent = FindEntityByClassname(ent, "team_round_timer")) != -1)
    {
        if(!HasEntProp(ent, Prop_Data, "m_iName")) continue;
        

        GetEntPropString(ent, Prop_Data, "m_iName", m_iName, sizeof(m_iName));
        
        if(!StrEqual(m_iName, "zz_teamplay_waiting_timer", true)) continue;
        
        // we do
        IsWaitingForPlayers = true;

    }

    ent = -1;

    if(!IsWaitingForPlayers) return;

    while((ent = FindEntityByClassname(ent, "func_door")) != -1)
    {
        AcceptEntityInput(ent, "Open");
    }

} 