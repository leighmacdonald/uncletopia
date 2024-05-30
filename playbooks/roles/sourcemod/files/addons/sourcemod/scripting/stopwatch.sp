/**
 * Copyright (C) 2023  Mikusch
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

#include <sdktools>
#include <dhooks>

#define PLUGIN_VERSION "1.0.0"

bool g_bEnabled;
ArrayList g_dynamicHookIds;
ConVar mp_tournament;
ConVar mp_tournament_stopwatch;
ConVar tf_attack_defend_map;

DynamicDetour g_detour_CTFGameRules_ManageStopwatchTimer;
DynamicHook g_hook_CTeamRoundTimer_SetTimeRemaining;
DynamicHook g_hook_CTeamRoundTimer_AddTimerSeconds;
DynamicHook g_hook_CTeamplayRoundBasedRules_StopWatchModeThink;

public Plugin myinfo = 
{
	name = "[TF2] Casual Stopwatch Mode",
	author = "Mikusch",
	description = "Allows using Stopwatch mode without enabling Tournament mode.",
	version = "1.0.0",
	url = "https://github.com/Mikusch/stopwatch"
}

public void OnPluginStart()
{
	g_dynamicHookIds = new ArrayList();
	
	mp_tournament = FindConVar("mp_tournament");
	mp_tournament.AddChangeHook(OnTournamentModeChanged);
	mp_tournament_stopwatch = FindConVar("mp_tournament_stopwatch");
	tf_attack_defend_map = FindConVar("tf_attack_defend_map");
	
	GameData gameconf = new GameData("stopwatch");
	if (!gameconf)
		SetFailState("Failed to find stopwatch gamedata");
	
	g_detour_CTFGameRules_ManageStopwatchTimer = CreateDynamicDetour(gameconf, "CTFGameRules::ManageStopwatchTimer");
	g_hook_CTeamRoundTimer_SetTimeRemaining = CreateDynamicHook(gameconf, "CTeamRoundTimer::SetTimeRemaining");
	g_hook_CTeamRoundTimer_AddTimerSeconds = CreateDynamicHook(gameconf, "CTeamRoundTimer::AddTimerSeconds");
	g_hook_CTeamplayRoundBasedRules_StopWatchModeThink = CreateDynamicHook(gameconf, "CTeamplayRoundBasedRules::StopWatchModeThink");
}

public void OnPluginEnd()
{
	if (!g_bEnabled)
		return;
	
	TogglePlugin(false);
}

public void OnConfigsExecuted()
{
	if (g_bEnabled == mp_tournament.BoolValue)
	{
		TogglePlugin(!mp_tournament.BoolValue);
	}
}

public void OnMapStart()
{
	if (!g_bEnabled)
		return;
	
	g_dynamicHookIds.Push(g_hook_CTeamplayRoundBasedRules_StopWatchModeThink.HookGamerules(Hook_Pre, CTeamplayRoundBasedRules_StopWatchModeThink_Pre, DHookRemovalCB_OnHookRemoved));
	g_dynamicHookIds.Push(g_hook_CTeamplayRoundBasedRules_StopWatchModeThink.HookGamerules(Hook_Post, CTeamplayRoundBasedRules_StopWatchModeThink_Post, DHookRemovalCB_OnHookRemoved));
	
	// Calculates the value of tf_attack_defend_map
	SetVariantString("IsAttackDefenseMode()");
	AcceptEntityInput(0, "RunScriptCode");
	
	bool bUseStopWatch = tf_attack_defend_map.BoolValue;
	
	GameRules_SetProp("m_bStopWatch", bUseStopWatch);
	mp_tournament_stopwatch.BoolValue = bUseStopWatch;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_bEnabled)
		return;
	
	if (StrEqual(classname, "team_round_timer"))
	{
		g_dynamicHookIds.Push(g_hook_CTeamRoundTimer_SetTimeRemaining.HookEntity(Hook_Pre, entity, CTeamRoundTimer_SetTimeRemaining_Pre, DHookRemovalCB_OnHookRemoved));
		g_dynamicHookIds.Push(g_hook_CTeamRoundTimer_SetTimeRemaining.HookEntity(Hook_Post, entity, CTeamRoundTimer_SetTimeRemaining_Post, DHookRemovalCB_OnHookRemoved));
		
		g_dynamicHookIds.Push(g_hook_CTeamRoundTimer_AddTimerSeconds.HookEntity(Hook_Pre, entity, CTeamRoundTimer_AddTimerSeconds_Pre, DHookRemovalCB_OnHookRemoved));
		g_dynamicHookIds.Push(g_hook_CTeamRoundTimer_AddTimerSeconds.HookEntity(Hook_Post, entity, CTeamRoundTimer_AddTimerSeconds_Post, DHookRemovalCB_OnHookRemoved));
	}
}

public void OnClientPutInServer(int client)
{
	if (!g_bEnabled)
		return;
	
	if (!IsFakeClient(client))
		mp_tournament.ReplicateToClient(client, GameRules_GetProp("m_bInWaitingForPlayers") ? "0" : "1");
}

public void TF2_OnWaitingForPlayersStart()
{
	if (!g_bEnabled)
		return;
	
	ReplicateTournamentMode(false);
}

public void TF2_OnWaitingForPlayersEnd()
{
	if (!g_bEnabled)
		return;
	
	ReplicateTournamentMode(true);
}

void TogglePlugin(bool bEnable)
{
	g_bEnabled = bEnable;
	
	if (bEnable)
	{
		mp_tournament.Flags &= ~(FCVAR_REPLICATED | FCVAR_NOTIFY);
		
		g_detour_CTFGameRules_ManageStopwatchTimer.Enable(Hook_Pre, CTFGameRules_ManageStopwatchTimer_Pre);
		g_detour_CTFGameRules_ManageStopwatchTimer.Enable(Hook_Post, CTFGameRules_ManageStopwatchTimer_Post);
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			OnClientPutInServer(client);
		}
		
		int entity = -1;
		while ((entity = FindEntityByClassname(entity, "*")) != -1)
		{
			if (entity <= MaxClients)
				continue;
			
			char classname[256];
			if (!GetEntityClassname(entity, classname, sizeof(classname)))
				continue;
			
			OnEntityCreated(entity, classname);
		}
		
		OnMapStart();
	}
	else
	{
		mp_tournament.Flags |= (FCVAR_REPLICATED | FCVAR_NOTIFY);
		ReplicateTournamentMode(mp_tournament.BoolValue);
		
		g_detour_CTFGameRules_ManageStopwatchTimer.Disable(Hook_Pre, CTFGameRules_ManageStopwatchTimer_Pre);
		g_detour_CTFGameRules_ManageStopwatchTimer.Disable(Hook_Post, CTFGameRules_ManageStopwatchTimer_Post);
		
		for (int i = g_dynamicHookIds.Length - 1; i >= 0; i--)
		{
			int hookid = g_dynamicHookIds.Get(i);
			DynamicHook.RemoveHook(hookid);
		}
	}
}

DynamicDetour CreateDynamicDetour(GameData gameconf, const char[] name)
{
	DynamicDetour detour = DynamicDetour.FromConf(gameconf, name);
	if (!detour)
		ThrowError("Failed to create detour for %s", name);
	
	return detour;
}

DynamicHook CreateDynamicHook(GameData gameconf, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gameconf, name);
	if (!hook)
		ThrowError("Failed to create virtual hook for %s", name);
	
	return hook;
}

void ReplicateTournamentMode(bool bInTournamentMode)
{
	char value[11];
	if (!IntToString(bInTournamentMode, value, sizeof(value)))
		return;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		if (IsFakeClient(client))
			continue;
		
		mp_tournament.ReplicateToClient(client, value);
	}
}

void SetTournamentMode(bool bInTournamentMode)
{
	mp_tournament.RemoveChangeHook(OnTournamentModeChanged);
	mp_tournament.BoolValue = bInTournamentMode;
	mp_tournament.AddChangeHook(OnTournamentModeChanged);
}

static void OnTournamentModeChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_bEnabled == convar.BoolValue)
	{
		TogglePlugin(!convar.BoolValue);
	}
}

static MRESReturn CTFGameRules_ManageStopwatchTimer_Pre(DHookParam param)
{
	SetTournamentMode(true);
	return MRES_Ignored;
}

static MRESReturn CTFGameRules_ManageStopwatchTimer_Post(DHookParam param)
{
	SetTournamentMode(false);
	return MRES_Ignored;
}

static MRESReturn CTeamRoundTimer_SetTimeRemaining_Pre(int timer, DHookParam param)
{
	SetTournamentMode(true);
	return MRES_Ignored;
}

static MRESReturn CTeamRoundTimer_SetTimeRemaining_Post(int timer, DHookParam param)
{
	SetTournamentMode(false);
	return MRES_Ignored;
}

static MRESReturn CTeamRoundTimer_AddTimerSeconds_Pre(int timer, DHookParam param)
{
	SetTournamentMode(true);
	return MRES_Ignored;
}

static MRESReturn CTeamRoundTimer_AddTimerSeconds_Post(int timer, DHookParam param)
{
	SetTournamentMode(false);
	return MRES_Ignored;
}

static MRESReturn CTeamplayRoundBasedRules_StopWatchModeThink_Pre()
{
	SetTournamentMode(true);
	return MRES_Ignored;
}

static MRESReturn CTeamplayRoundBasedRules_StopWatchModeThink_Post()
{
	SetTournamentMode(false);
	return MRES_Ignored;
}

static void DHookRemovalCB_OnHookRemoved(int hookid)
{
	int index = g_dynamicHookIds.FindValue(hookid);
	if (index != -1)
		g_dynamicHookIds.Erase(index);
}
