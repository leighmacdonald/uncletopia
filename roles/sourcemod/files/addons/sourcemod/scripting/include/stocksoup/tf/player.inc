/**
 * Provides stocks that deal with player entities.
 */

#if defined __stocksoup_tf_player_included
	#endinput
#endif

#define __stocksoup_tf_player_included

/**
 * Attempts to heal player by the specified amount.  Also provides functionality to visually
 * indicate to players that they have been healed.
 * 
 * @return true if the player was successfully (over) healed, false if no heals were applied
 */
stock bool TF2_HealPlayer(int client, int nHealAmount, bool overheal = false,
		bool notify = false) {
	if (IsPlayerAlive(client)) {
		int nHealth = GetClientHealth(client);
		int nMaxHealth = TF2_GetPlayerMaxHealth(client);
		
		// cap heals to max health
		if (!overheal && nHealAmount > nMaxHealth - nHealth) {
			nHealAmount = nMaxHealth - nHealth;
		}
		
		if (nHealAmount > 0) {
			SetEntityHealth(client, nHealth + nHealAmount);
			
			// player health HUD notification
			if (notify) {
				Event event = CreateEvent("player_healonhit");
				if (event) {
					event.SetInt("amount", nHealAmount);
					event.SetInt("entindex", client);
					
					event.FireToClient(client);
					delete event;
				}
			}
			
			return true;
		}
	}
	return false;
}

/**
 * Returns the current maximum amount of health that a player can have.
 */
stock int TF2_GetPlayerMaxHealth(int client) {
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}
