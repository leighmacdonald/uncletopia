/*
Copyright 2020, rtldg

Copying and distribution of this file, with or without modification, are permitted in any medium without royalty, provided the copyright notice and this notice are preserved. This file is offered as-is, without any warranty.
*/

#include <sourcemod>
#include <clientprefs>
#include <tf2_stocks>
#include <dhooks> // https://github.com/peace-maker/DHooks2

#include <tf2attributes> // https://github.com/FlaminSarge/tf2attributes

public Plugin myinfo = {
	name = "[TF2] Center Projectiles",
	author = "rtldg & pufftwitt",
	version = "7.1",
	url = "https://github.com/rtldg/tf2centerprojectiles",
	description = "Provides the command sm_centerprojectiles [0|1] to shoot rockets from the center (like The Original) for any rocket launcher, shoot pipebombs and sticky bombs from the center, and more!"
};

bool g_bLate;
bool g_bCentered[MAXPLAYERS+1];
Handle g_hCenterProjectiles;
Handle g_hWeapon_ShootPosition = null;
Handle g_hIsViewModelFlipped = null;

float g_fOffset_FirePipeBomb = 8.0;

stock bool IsValidClient(int client, bool bAlive = false)
{
	return (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client) && (!bAlive || IsPlayerAlive(client)));
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bLate = late;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_centerprojectiles", sm_centerprojectiles, "sm_centerprojectiles to toggle or sm_centerprojectiles [1|0] to set");
	g_hCenterProjectiles = RegClientCookie("tf2centerprojectiles", "TF2 Center Projectiles thing", CookieAccess_Protected);

	// Called every player spawn...
	HookEvent("player_spawn", Event_EverythingEver, EventHookMode_Post);
	// Sent when a player gets a whole new set of items, aka touches a resupply locker / respawn cabinet or spawns in.
	HookEvent("post_inventory_application", Event_EverythingEver, EventHookMode_Post);

	Handle hGameData = LoadGameConfigFile("tf2centerprojectiles.games");

	if (hGameData == null)
	{
		SetFailState("Failed to load tf2centerprojectiles gamedata");
	}

	int offset;

	if ((offset = GameConfGetOffset(hGameData, "Weapon_ShootPosition")) == -1)
	{
		SetFailState("Couldn't get the offset for Weapon_ShootPosition");
	}

	g_hWeapon_ShootPosition = DHookCreate(offset, HookType_Entity, ReturnType_Vector, ThisPointer_CBaseEntity, Hook_Weapon_ShootPosition);

	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hGameData, SDKConf_Virtual, "IsViewModelFlipped");
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	g_hIsViewModelFlipped = EndPrepSDKCall();

	if (g_bLate)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
}

public void OnClientPutInServer(int client)
{
	if (g_hWeapon_ShootPosition != null)
	{
		DHookEntity(g_hWeapon_ShootPosition, true, client);
	}
}

public void OnClientCookiesCached(int client)
{
	char cookie[2];
	GetClientCookie(client, g_hCenterProjectiles, cookie, sizeof(cookie));
	g_bCentered[client] = (cookie[0] == '1');
}

// Hook to work with FirePipeBomb... aka grenade launcher & pipebomb launcher
public MRESReturn Hook_Weapon_ShootPosition(int client, DHookReturn hReturn)
{
	if (!g_bCentered[client])
	{
		return MRES_Ignored;
	}

	int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");

	if (weapon == 0 || weapon == -1) // probably good enough check...
	{
		return MRES_Ignored;
	}

	char classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));

	if (!StrEqual(classname, "tf_weapon_grenadelauncher") && !StrEqual(classname, "tf_weapon_pipebomblauncher"))
	{
		return MRES_Ignored;
	}

	float pos[3];
	GetClientEyePosition(client, pos);

	float ang[3], fwd[3], right[3], up[3];
	GetClientEyeAngles(client, ang);
	GetAngleVectors(ang, fwd, right, up);

	// We need to return a ShootPosition that'll return the center once the game has added the offset.
	// i.e. subtract g_fOffset_FirePipeBomb and then the game adds g_fOffset_FirePipeBomb
	bool isFlipped = SDKCall(g_hIsViewModelFlipped, weapon);
	ScaleVector(right, isFlipped ? -g_fOffset_FirePipeBomb : g_fOffset_FirePipeBomb);
	SubtractVectors(pos, right, pos);

	hReturn.SetVector(pos);
	return MRES_Override;
}

Action sm_centerprojectiles(int client, int args)
{
	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	bool center;

	if (args == 0)
	{
		center = !g_bCentered[client];
	}
	else
	{
		char arg[128];
		GetCmdArg(1, arg, sizeof(arg));
		center = !(0 == StringToInt(arg, 10));
	}

	SetCentered(client, center);
	CenterPlayer(client);
	PrintToChat(client, "[TF2 Center Projectiles] %s", center ? "Enabled" : "Disabled");
	return Plugin_Handled;
}

Action Event_EverythingEver(Event event, const char[] name, bool dontBroadcast)
{
	CenterPlayer(GetClientOfUserId(event.GetInt("userid")));
	return Plugin_Continue;
}

void SetCentered(int client, bool center)
{
	char cookie[2];
	cookie[0] = center ? '1' : '0';
	SetClientCookie(client, g_hCenterProjectiles, cookie);
	g_bCentered[client] = center;
}

void CenterPlayer(int client)
{
	if (IsFakeClient(client))
		return;

	SetCenterAttribute(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Primary));
	SetCenterAttribute(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary));
	SetCenterAttribute(client, GetPlayerWeaponSlot(client, TFWeaponSlot_Melee));
}

void SetCenterAttribute(int client, int weapon)
{
	if (weapon == -1) // How could this happen? :thinking:
		return;

	bool isTheOriginal = (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 513);
	bool center = g_bCentered[client] || isTheOriginal;

	// List of attributes at https://wiki.teamfortress.com/wiki/List_of_item_attributes
	// 289 == centerfire_projectile
	TF2Attrib_SetByDefIndex(weapon, 289, center ? 1.0 : 0.0);
}
