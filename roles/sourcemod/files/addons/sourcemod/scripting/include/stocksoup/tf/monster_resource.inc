/**
 * Methodmap to manage the `monster_resource` entity used for TF2 Halloween bosses.
 */

#if defined __stocksoup_tf_monster_resource_included
	#endinput
#endif

#define __stocksoup_tf_monster_resource_included

#include <sdktools>

enum TFBossHealthState {
	HealthState_Default = 0,
	HealthState_Healing // displays a green health bar
};

methodmap TFMonsterResource {
	/**
	 * Returns the first monster_resource entity, with an option to create it if it doesn't
	 * exist.
	 */
	public static TFMonsterResource GetEntity(bool create = false) {
		int hMonsterResource = FindEntityByClassname(-1, "monster_resource");
		
		if (hMonsterResource == -1 && create) {
			hMonsterResource = CreateEntityByName("monster_resource");
			
			if (IsValidEntity(hMonsterResource)) {
				DispatchSpawn(hMonsterResource);
			}
		}
		
		return view_as<TFMonsterResource>(IsValidEntity(hMonsterResource)?
				EntIndexToEntRef(hMonsterResource) : INVALID_ENT_REFERENCE);
	}
	
	/**
	 * Entity index.
	 */
	property int Index {
		public get() {
			return EntRefToEntIndex(view_as<int>(this));
		}
	}
	
	property int BossHealthPercentageByte {
		public get() {
			return GetEntProp(this.Index, Prop_Send, "m_iBossHealthPercentageByte");
		}
		public set(int value) {
			value = value > 0xFF? 0xFF : value;
			value = value < 0? 0 : value;
			SetEntProp(this.Index, Prop_Send, "m_iBossHealthPercentageByte", value);
		}
	}
	
	property TFBossHealthState BossHealthState {
		public get() {
			int index = this.Index;
			return view_as<TFBossHealthState>(GetEntProp(index, Prop_Send, "m_iBossState"));
		}
		public set(TFBossHealthState value) {
			SetEntProp(this.Index, Prop_Send, "m_iBossState", value);
		}
	}
	
	/**
	 * Updates the monster resource health display to display the current health of the
	 * specified entity.
	 * 
	 * Must be called every time the entity health changes; this does not automatically track
	 * health.
	 */
	public void LinkHealth(int entity) {
		int hEntity = EntRefToEntIndex(entity);
		
		if (IsValidEntity(hEntity)) {
			int iMaxHealth = GetEntProp(hEntity, Prop_Data, "m_iMaxHealth");
			
			// account for max unbuffed health on clients, stored in player resource entity
			if (entity > 0 && entity <= MaxClients) {
				int resource = GetPlayerResourceEntity();
				if (IsValidEntity(resource)) {
					iMaxHealth = GetEntProp(resource, Prop_Send, "m_iMaxHealth", _, entity);
				}
			}
			
			int iHealth = GetEntProp(hEntity, Prop_Data, "m_iHealth");
			
			this.BossHealthPercentageByte = RoundToCeil(float(iHealth) / iMaxHealth * 255);
		}
	}
	
	/** 
	 * Hides the display.
	 * Do *not* use the "Kill" input on this entity.
	 */
	public void Hide() {
		this.BossHealthPercentageByte = 0;
	}
}
