#include <sourcemod>
#include <dhooks>

#define PLUGIN_VERSION "1.0.2"

new Handle:hIsValidTarget;
new Handle:mp_forcecamera;
new bool:g_bCheckNullPtr = false;

public Plugin:myinfo = 
{
	name = "Admin all spec",
	author = "Dr!fter",
	description = "Allows admin to spec all players",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("DHookIsNullParam");
	
	return APLRes_Success;
}

public OnPluginStart()
{
	mp_forcecamera = FindConVar("mp_forcecamera");
	
	if(!mp_forcecamera)
	{
		SetFailState("Failed to locate mp_forcecamera");
	}
	
	new Handle:temp = LoadGameConfigFile("allow-spec.games");
	
	if(!temp)
	{
		SetFailState("Failed to load allow-spec.games.txt");
	}
	
	new offset = GameConfGetOffset(temp, "IsValidObserverTarget");
	
	hIsValidTarget = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, IsValidTarget);
	
	DHookAddParam(hIsValidTarget, HookParamType_CBaseEntity);
	
	CloseHandle(temp);
	
	g_bCheckNullPtr = (GetFeatureStatus(FeatureType_Native, "DHookIsNullParam") == FeatureStatus_Available);
	
	CreateConVar("admin_allspec_version", PLUGIN_VERSION, "Plugin version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
}
public OnClientPostAdminCheck(client)
{
	if(IsFakeClient(client))
		return;
	
	if(CheckCommandAccess(client, "admin_allspec_flag", ADMFLAG_CHEATS))
	{
		SendConVarValue(client, mp_forcecamera, "0");
		DHookEntity(hIsValidTarget, true, client);
	}
}
public MRESReturn:IsValidTarget(this, Handle:hReturn, Handle:hParams)
{
	// As of DHooks 1.0.12 we must check for a null param.
	if (g_bCheckNullPtr && DHookIsNullParam(hParams, 1))
		return MRES_Ignored;
	
	new target = DHookGetParam(hParams, 1);
	if(target <= 0 || target > MaxClients || !IsClientInGame(this) || !IsClientInGame(target) || !IsPlayerAlive(target) || IsPlayerAlive(this) || GetClientTeam(this) <= 1 || GetClientTeam(target) <= 1)
	{
		return MRES_Ignored;
	}
	else
	{
		DHookSetReturn(hReturn, true);
		return MRES_Override;
	}
}