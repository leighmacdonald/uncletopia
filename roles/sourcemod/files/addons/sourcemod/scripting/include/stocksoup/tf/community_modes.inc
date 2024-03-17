/**
 * Provides some detection for certain odd game modes.
 * 
 * For general detection, I'd recommend Powerlord's `tf2_morestocks` collection:
 * https://github.com/powerlord/sourcemod-snippets/blob/master/scripting/include/tf2_morestocks.inc
 */
#if defined __stocksoup_tf_community_modes_included
	#endinput
#endif

#define __stocksoup_tf_community_modes_included

#include <stocksoup/entity_tools>

/**
 * Checks if the map uses a known variant of 2-Team Payload, a.k.a. Tug-of-War Payload.
 * 
 * This is a symmetrical game mode where both teams attempt to push a neutral Payload cart from
 * the center of the map to the enemy's base.
 */
stock bool TF2_IsGameMode2TPL() {
	char target[64];
	
	// Not even Payload
	if (FindEntityByClassname(-1, "func_tracktrain") < 0) {
		return false;
	}
	
	// Detection for Fubar's prefab (used in Effigy)
	{
		int gameRules = -1;
		while ( (gameRules = FindEntityByClassname(gameRules, "tf_gamerules")) != -1 ) {
			GetEntityTargetName(gameRules, target, sizeof(target));
			if (StrEqual(target, "tug_gamerules")) {
				return true;
			}
		}
	}
	
	// Detection for Icarus's prefab (used in Waste)
	// Also publicly available: http://tf2.gamebanana.com/prefabs/3527
	{
		bool bRedTriggerFound, bBlueTriggerFound;
		
		int trigger = -1;
		while ( (trigger = FindEntityByClassname(trigger, "trigger_capture_area")) != -1) {
			GetEntityTargetName(trigger, target, sizeof(target));
			bBlueTriggerFound |= StrEqual(target, "Trigger_BLUCart");
			bRedTriggerFound |= StrEqual(target, "Trigger_REDCart");
		}
		
		if (bBlueTriggerFound && bRedTriggerFound) {
			return true;
		}
	}
	
	// Detection based on the `2tpl_` map prefix
	{
		char mapPrefix[8], currentMap[PLATFORM_MAX_PATH];
		GetCurrentMap(currentMap, sizeof(currentMap));
		GetMapDisplayName(currentMap, mapPrefix, sizeof(mapPrefix));
		
		if (StrContains(mapPrefix, "2tpl_", false) == 0) {
			return true;
		}
	}
	
	return false;
}
