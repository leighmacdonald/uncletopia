#if defined __stocksoup_tf_econ_included
	#endinput
#endif

#define __stocksoup_tf_econ_included

// defindex used for wearables not in the schema (medic's backpack, etc.)
#define DEFINDEX_UNDEFINED 65535

/**
 * Returns an item's definition index.
 */
stock int TF2_GetItemDefinitionIndex(int entity) {
	return GetEntProp(entity, Prop_Send, "m_iItemDefinitionIndex");
}

/**
 * Returns an item's definition index.
 * 
 * On invalid entities and entities that are not items, this returns DEFINDEX_UNDEFINED instead
 * of generating a runtime exception.
 */
stock int TF2_GetItemDefinitionIndexSafe(int entity) {
	if (!IsValidEntity(entity) || !HasEntProp(entity, Prop_Send, "m_iItemDefinitionIndex")) {
		return DEFINDEX_UNDEFINED;
	}
	return TF2_GetItemDefinitionIndex(entity);
}

/** 
 * Creates a wearable entity.
 * 
 * Wearables spawned via this method and equipped on human players are not visible to other
 * human players due to economy rules.  You're on your own there.
 * 
 * If defindex is set to DEFINDEX_UNDEFINED, the item is not initialized, and no quality or
 * level is applied.
 * 
 * @param defindex		Wearable definition index.
 * @param quality		Wearable quality.
 * @param level			Wearable level.
 */
stock int TF2_SpawnWearable(int defindex = DEFINDEX_UNDEFINED, int quality = 6, int level = 1) {
	int wearable = CreateEntityByName("tf_wearable");
	
	if (IsValidEntity(wearable)) {
		SetEntProp(wearable, Prop_Send, "m_iItemDefinitionIndex", defindex);
		
		if (defindex != DEFINDEX_UNDEFINED) {
			// using defindex of a valid item
			SetEntProp(wearable, Prop_Send, "m_bInitialized", 1);
			
			SetEntProp(wearable, Prop_Send, "m_iEntityLevel", level);
			
			// Something about m_iEntityQuality doesn't play nice with SetEntProp.
			SetEntData(wearable, FindSendPropInfo("CTFWearable", "m_iEntityQuality"), quality);
		}
		
		// Spawn.
		DispatchSpawn(wearable);
	}
	return wearable;
}
