#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "2.2.0"

bool g_bThirdPersonEnabled[MAXPLAYERS+1] = { false, ... };

public Plugin myinfo =
{
	name = "[TF2] Thirdperson",
	author = "DarthNinja, Leigh MacDonald",
	description = "Allows players to use thirdperson without having to enable client sv_cheats",
	version = PLUGIN_VERSION,
	url = "https://github.com/leighmacdonald/uncletopia"
};

public void OnPluginStart()
{
	CreateConVar("thirdperson_version", PLUGIN_VERSION, "Plugin Version",  FCVAR_PLUGIN|FCVAR_NOTIFY);
	RegAdminCmd("sm_thirdperson", EnableThirdperson, 0, "Usage: sm_thirdperson");
	RegAdminCmd("tp", EnableThirdperson, 0, "Usage: sm_thirdperson");
	RegAdminCmd("sm_firstperson", DisableThirdperson, 0, "Usage: sm_firstperson");
	RegAdminCmd("fp", DisableThirdperson, 0, "Usage: sm_firstperson");
	HookEvent("player_spawn", OnPlayerSpawned);
	HookEvent("player_class", OnPlayerSpawned);
}

public Action OnPlayerSpawned(Handle event, char[] name, bool dontBroadcast) {
	int userid = GetEventInt(event, "userid");
	if (g_bThirdPersonEnabled[GetClientOfUserId(userid)]) {
		CreateTimer(0.2, SetViewOnSpawn, userid);
	}

	return Plugin_Continue;
}

public Action SetViewOnSpawn(Handle timer, int userid) {
	int client = GetClientOfUserId(userid);
	if (client != 0) {
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
	}

	return Plugin_Continue;
}

public Action EnableThirdperson(int client, int args) {
	if (!IsPlayerAlive(client)) {
		PrintToChat(client, "[SM] Thirdperson view will be enabled when you spawn.");
	}
	SetVariantInt(1);
	AcceptEntityInput(client, "SetForcedTauntCam");
	g_bThirdPersonEnabled[client] = true;

	return Plugin_Handled;
}

public Action DisableThirdperson(int client, int args) {
	if (!IsPlayerAlive(client)) {
		PrintToChat(client, "[SM] Thirdperson view disabled!");
	}
	SetVariantInt(0);
	AcceptEntityInput(client, "SetForcedTauntCam");
	g_bThirdPersonEnabled[client] = false;
	return Plugin_Handled;
}

public void OnClientDisconnect(int client) {
	g_bThirdPersonEnabled[client] = false;
}
