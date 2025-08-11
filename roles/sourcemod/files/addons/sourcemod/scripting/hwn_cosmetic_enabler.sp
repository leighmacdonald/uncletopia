/**
 * Copyright (C) 2022  Mikusch
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>

#define PLUGIN_VERSION "1.3.1"

enum
{
	VISION_MODE_NONE = 0,
	VISION_MODE_PYRO,
	VISION_MODE_HALLOWEEN,
	VISION_MODE_ROME,
	
	MAX_VISION_MODES
};

ConVar tf_enable_halloween_cosmetics;
ConVar tf_forced_holiday;
DynamicDetour g_hDetourIsHolidayActive;
DynamicDetour g_hDetourInputFire;

bool g_bIsEnabled;
bool g_bIsMapRunning;
bool g_bNoForcedHoliday;

public Plugin myinfo =
{
	name = "[TF2] Halloween Cosmetic Enabler",
	author = "Mikusch",
	description = "Enables Halloween cosmetics and spells regardless of current holiday",
	version = PLUGIN_VERSION,
	url = "https://github.com/Mikusch/HalloweenCosmeticEnabler"
}

public void OnPluginStart()
{
	tf_enable_halloween_cosmetics = CreateConVar("tf_enable_halloween_cosmetics", "1", "Whether to enable cosmetics and effects with a Halloween / Full Moon restriction.");
	tf_enable_halloween_cosmetics.AddChangeHook(ConVarChanged_EnableHalloweenCosmetics);
	
	tf_forced_holiday = FindConVar("tf_forced_holiday");
	
	GameData hGameConf = new GameData("hwn_cosmetic_enabler");
	if (!hGameConf)
		SetFailState("Failed to find hwn_cosmetic_enabler gamedata");
	
	g_hDetourIsHolidayActive = DynamicDetour.FromConf(hGameConf, "TF_IsHolidayActive");
	if (!g_hDetourIsHolidayActive)
		SetFailState("Failed to setup detour for TF_IsHolidayActive");
	
	g_hDetourInputFire = DynamicDetour.FromConf(hGameConf, "CLogicOnHoliday::InputFire");
	if (!g_hDetourInputFire)
		SetFailState("Failed to setup detour for CLogicOnHoliday::InputFire");
	
	delete hGameConf;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientInGame(iClient))
			OnClientPutInServer(iClient);
	}
}

public void OnMapStart()
{
	g_bIsMapRunning = true;
}

public void OnMapEnd()
{
	g_bIsMapRunning = false;
}

public void OnConfigsExecuted()
{
	if (g_bIsEnabled != tf_enable_halloween_cosmetics.BoolValue)
		TogglePlugin(tf_enable_halloween_cosmetics.BoolValue);
}

public void OnClientPutInServer(int iClient)
{
	if (!g_bIsEnabled)
		return;
	
	if (!IsFakeClient(iClient))
		ReplicateHolidayToClient(iClient, TFHoliday_HalloweenOrFullMoon);
}

public void OnEntityCreated(int iEntity, const char[] szClassname)
{
	if (!g_bIsEnabled)
		return;
	
	if (!g_bIsMapRunning)
		return;
	
	if (!strncmp(szClassname, "item_healthkit_", 15))
		SDKHook(iEntity, SDKHook_SpawnPost, SDKHookCB_HealthKit_SpawnPost);
}

public void ConVarChanged_ForcedHoliday(ConVar hConVar, const char[] szOldValue, const char[] szNewValue)
{
	// If tf_forced_holiday was changed, replicate the desired value back to each client
	TFHoliday holiday = view_as<TFHoliday>(hConVar.IntValue);
	if (holiday != TFHoliday_HalloweenOrFullMoon)
	{
		// Allow clients to react to the initial change first
		RequestFrame(RequestFrameCallback_ReplicateForcedHoliday, TFHoliday_HalloweenOrFullMoon);
	}
}

public void ConVarChanged_EnableHalloweenCosmetics(ConVar hConVar, const char[] szOldValue, const char[] szNewValue)
{
	if (g_bIsEnabled != hConVar.BoolValue)
		TogglePlugin(hConVar.BoolValue);
}

public MRESReturn DHookCallback_IsHolidayActive_Post(DHookReturn hReturn, DHookParam hParam)
{
	TFHoliday eHoliday = hParam.Get(1);
	
	if (!g_bIsEnabled)
		return MRES_Ignored;
	
	// Force-enable Halloween at all times unless we specifically request not to
	if (eHoliday == TFHoliday_HalloweenOrFullMoon && !g_bNoForcedHoliday)
	{
		hReturn.Value = true;
		return MRES_Supercede;
	}
	
	// Otherwise, let the game determine which holiday is active
	return MRES_Ignored;
}

public MRESReturn DHookCallback_InputFire_Pre(int iEntity, DHookParam hParam)
{
	// Prevent tf_logic_on_holiday from assuming it's always Halloween
	g_bNoForcedHoliday = true;
	
	return MRES_Ignored;
}

public MRESReturn DHookCallback_InputFire_Post(int iEntity, DHookParam hParam)
{
	g_bNoForcedHoliday = false;
	
	return MRES_Ignored;
}

public void SDKHookCB_HealthKit_SpawnPost(int iEntity)
{
	g_bNoForcedHoliday = true;
	
	if (!TF2_IsHolidayActive(TFHoliday_HalloweenOrFullMoon))
	{
		// Force normal non-holiday health kit model
		SetEntProp(iEntity, Prop_Send, "m_nModelIndexOverrides", 0, _, VISION_MODE_HALLOWEEN);
	}
	
	g_bNoForcedHoliday = false;
}

public void RequestFrameCallback_ReplicateForcedHoliday(TFHoliday eHoliday)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;
		
		if (IsFakeClient(iClient))
			continue;
		
		ReplicateHolidayToClient(iClient, eHoliday);
	}
}

void TogglePlugin(bool bEnable)
{
	g_bIsEnabled = bEnable;
	
	if (bEnable)
	{
		tf_forced_holiday.AddChangeHook(ConVarChanged_ForcedHoliday);
		
		if (g_hDetourIsHolidayActive)
		{
			g_hDetourIsHolidayActive.Enable(Hook_Post, DHookCallback_IsHolidayActive_Post);
		}
		
		if (g_hDetourInputFire)
		{
			g_hDetourInputFire.Enable(Hook_Pre, DHookCallback_InputFire_Pre);
			g_hDetourInputFire.Enable(Hook_Post, DHookCallback_InputFire_Post);
		}
	}
	else
	{
		tf_forced_holiday.RemoveChangeHook(ConVarChanged_ForcedHoliday);
		
		if (g_hDetourIsHolidayActive)
		{
			g_hDetourIsHolidayActive.Disable(Hook_Post, DHookCallback_IsHolidayActive_Post);
		}
		
		if (g_hDetourInputFire)
		{
			g_hDetourInputFire.Disable(Hook_Pre, DHookCallback_InputFire_Pre);
			g_hDetourInputFire.Disable(Hook_Post, DHookCallback_InputFire_Post);
		}
	}
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient))
			continue;
		
		if (IsFakeClient(iClient))
			continue;
		
		if (bEnable)
		{
			ReplicateHolidayToClient(iClient, TFHoliday_HalloweenOrFullMoon);
		}
		else
		{
			TFHoliday eHoliday = view_as<TFHoliday>(tf_forced_holiday.IntValue);
			ReplicateHolidayToClient(iClient, eHoliday);
		}
	}
}

void ReplicateHolidayToClient(int iClient, TFHoliday eHoliday)
{
	char szHoliday[11];
	if (IntToString(view_as<int>(eHoliday), szHoliday, sizeof(szHoliday)))
	{
		// Make client code think that it is a different holiday
		tf_forced_holiday.ReplicateToClient(iClient, szHoliday);
	}
}
