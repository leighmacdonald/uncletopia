#if !defined __tf_entity_prefabs_included
	#define __tf_entity_prefabs_included
#else
	#endinput
#endif

#pragma newdecls optional
#include <tf2>
#include <stocksoup/entity_tools>
#pragma newdecls required

#define EF_BONEMERGE	(1 << 0)
#define EF_NOSHADOW		16
#define EF_NOINTERP		8

/**
 * Attaches the outline effect to an entity so it can be seen through walls.
 * 
 * Stock referenced from the Glowing MvM money plugin:
 * https://forums.alliedmods.net/showthread.php?t=280942
 * 
 * @param entity	The entity that will receive an outline effect.
 * @param team		The team associated with the outline effect entity.
 * 					(Doesn't actually work.)
 * 
 * @return			Index for the created outline effect entity.
 */
stock int TF2_AttachBasicGlow(int entity, TFTeam team = TFTeam_Unassigned) {
	char model[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", model, PLATFORM_MAX_PATH);
	
	if (strlen(model) != 0) {
		int prop = CreateEntityByName("tf_taunt_prop");
		
		if (IsValidEntity(prop)) {
			if (team != TFTeam_Unassigned) {
				SetEntProp(prop, Prop_Data, "m_iInitialTeamNum", view_as<int>(team));
				SetEntProp(prop, Prop_Send, "m_iTeamNum", view_as<int>(team));
			}
			DispatchSpawn(prop);

			SetEntityModel(prop, model);

			SetEntPropEnt(prop, Prop_Data, "m_hEffectEntity", entity);
			SetEntProp(prop, Prop_Send, "m_bGlowEnabled", 1);
			
			int iFlags = GetEntProp(prop, Prop_Send, "m_fEffects");
			
			SetEntProp(prop, Prop_Send, "m_fEffects",
					iFlags | EF_BONEMERGE | EF_NOSHADOW | EF_NOINTERP);

			SetVariantString("!activator");
			AcceptEntityInput(prop, "SetParent", entity);
			
			SetEntityRenderMode(prop, RENDER_TRANSCOLOR);
			SetEntityRenderColor(prop, 255, 255, 255, 0);
		}
		return prop;
	}
	return -1;
}

/**
 * Attaches a colored glow to an entity.  Did some tests; SetTransmit doesn't work with glows
 * via `tf_glow`.
 */
stock int TF2_AttachColoredGlow(int entity, int rgba[4]) {
	int glow = CreateEntityByName("tf_glow");
	
	if (IsValidEntity(glow)) {
		char glowTarget[PLATFORM_MAX_PATH];
		
		GetEntityTargetName(entity, glowTarget, sizeof(glowTarget), true);
		DispatchKeyValue(glow, "target", glowTarget);
		
		DispatchSpawn(glow);
		
		SetVariantColor(rgba);
		AcceptEntityInput(glow, "SetGlowColor");
	}
	return glow;
}
