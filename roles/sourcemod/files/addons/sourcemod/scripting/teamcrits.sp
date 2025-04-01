#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>

ConVar cvarBluEnabled;
ConVar cvarRedEnabled;

public Plugin myinfo = {
	name = "[TF2] Team based permanent crits",
	author = "Leigh MacDonald",
	description = "Enables permanent crits for either team",
	version = "1.0.0",
	url = "https://github.com/leighmacdonald/uncletopia"
};

public void OnPluginStart() {
	cvarRedEnabled = CreateConVar("sm_crits_red", "1", "Enable crits for red team", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	cvarBluEnabled = CreateConVar("sm_crits_blu", "0", "Enable crits for blu team", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result) {
	if ((GetConVarBool(cvarBluEnabled) && TF2_GetClientTeam(client) == TFTeam_Blue) || (GetConVarBool(cvarRedEnabled) && TF2_GetClientTeam(client) == TFTeam_Red)) {
		result = true;
		return Plugin_Changed;
	}

	return Plugin_Continue;
}