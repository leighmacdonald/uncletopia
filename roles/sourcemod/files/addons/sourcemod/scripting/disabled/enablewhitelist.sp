/*
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.0.1"

ConVar convar_mpTournament;

Handle dhook_CEconItemSystem_ReloadWhitelist;
Handle dhook_CTFPlayer_GetLoadoutItem;

public Plugin myinfo = 
{
	name = "Enable Item Whitelist outside of Tournament Mode", 
	author = "Sappykun", 
	description = "Force-enables tournament mode only when loading and applying the item whitelist.", 
	version = PLUGIN_VERSION, 
	url = "https://forums.alliedmods.net/showthread.php?p=2819339"
};

public void OnPluginStart()
{
	CreateConVar("sm_enablewhitelist_version", PLUGIN_VERSION, "Enable Item Whitelist version. Don't touch.", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);

	convar_mpTournament = FindConVar("mp_tournament");
	convar_mpTournament.Flags &= ~FCVAR_NOTIFY;

	Handle conf = LoadGameConfigFile("tf2.enablewhitelist");
	if (conf == null) SetFailState("Failed to load tf2.enablewhitelist!");

	dhook_CEconItemSystem_ReloadWhitelist = DHookCreateFromConf(conf, "ReloadWhitelist");
	dhook_CTFPlayer_GetLoadoutItem = DHookCreateFromConf(conf, "GetLoadoutItem");

	if (dhook_CEconItemSystem_ReloadWhitelist == null) SetFailState("Failed to create dhook_CEconItemSystem_ReloadWhitelist");
	if (dhook_CTFPlayer_GetLoadoutItem == null) SetFailState("Failed to create dhook_CTFPlayer_GetLoadoutItem");
	
	delete conf;

	DHookEnableDetour(dhook_CEconItemSystem_ReloadWhitelist, false, DHookCallback_TournamentModeEnable);
	DHookEnableDetour(dhook_CEconItemSystem_ReloadWhitelist, true, DHookCallback_TournamentModeDisable);
	DHookEnableDetour(dhook_CTFPlayer_GetLoadoutItem, false, DHookCallback_TournamentModeEnable);
	DHookEnableDetour(dhook_CTFPlayer_GetLoadoutItem, true, DHookCallback_TournamentModeDisable);
}

MRESReturn DHookCallback_TournamentModeEnable(int entity, DHookReturn hReturn) {
	convar_mpTournament.SetBool(true, true, false);
	return MRES_Ignored;
}

MRESReturn DHookCallback_TournamentModeDisable(int entity, DHookReturn hReturn) {
	convar_mpTournament.SetBool(false, true, false);
	return MRES_Ignored;
}
