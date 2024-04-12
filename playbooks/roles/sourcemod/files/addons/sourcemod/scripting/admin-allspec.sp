#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "1.0.2"

Handle hIsValidTarget;
Handle mp_forcecamera;
bool g_bCheckNullPtr = false;

public Plugin myinfo = 
{
	name = "Admin all spec",
	author = "Dr!fter",
	description = "Allows admin to spec all players",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("DHookIsNullParam");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	mp_forcecamera = FindConVar("mp_forcecamera");
	
	if(!mp_forcecamera)
	{
		SetFailState("Failed to locate mp_forcecamera");
	}
	
	Handle temp = LoadGameConfigFile("allow-spec.games");
	
	if(!temp)
	{
		SetFailState("Failed to load allow-spec.games.txt");
	}
	
	int offset = GameConfGetOffset(temp, "IsValidObserverTarget");
	
	hIsValidTarget = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, IsValidTarget);
	
	DHookAddParam(hIsValidTarget, HookParamType_CBaseEntity);
	
	CloseHandle(temp);
	
	g_bCheckNullPtr = (GetFeatureStatus(FeatureType_Native, "DHookIsNullParam") == FeatureStatus_Available);
	
	CreateConVar("admin_allspec_version", PLUGIN_VERSION, "Plugin version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client)) {
		return;
	}
	if(CheckCommandAccess(client, "admin_allspec_flag", ADMFLAG_CHEATS)) {
		SendConVarValue(client, mp_forcecamera, "0");
		DHookEntity(hIsValidTarget, true, client);
	}
}

public MRESReturn IsValidTarget(int pThis, Handle hReturn, Handle hParams)
{
	// As of DHooks 1.0.12 we must check for a null param.
	if (g_bCheckNullPtr && DHookIsNullParam(hParams, 1))
		return MRES_Ignored;
	
	int target = DHookGetParam(hParams, 1);
	if(target <= 0 || target > MaxClients || !IsClientInGame(pThis) || !IsClientInGame(target) || !IsPlayerAlive(target) || IsPlayerAlive(pThis) || GetClientTeam(pThis) <= 1 || GetClientTeam(target) <= 1)
	{
		return MRES_Ignored;
	}
	else
	{
		DHookSetReturn(hReturn, true);
		return MRES_Override;
	}
}