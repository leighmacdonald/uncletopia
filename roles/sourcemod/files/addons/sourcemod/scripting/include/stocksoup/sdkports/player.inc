/**
 * Utility functions ported over from the Source SDK (baseplayer_shared.cpp).
 */

#if defined __stocksoup_sdkports_player_included
	#endinput
#endif

#define __stocksoup_sdkports_player_included

/**
 * Adds another punch angle to the player view.
 * 
 * Equivalent to CBasePlayer::ViewPunch(const QAngle &angleOffset)???
 */
stock void AddPlayerViewPunch(int client, const float vecAngleOffset[3]) {
	float vecAnglePlayer[3], vecAngleAdditive[3];
	
	GetEntPropVector(client, Prop_Data, "m_vecPunchAngleVel", vecAnglePlayer);
	
	// (copy angleOffset for modification)
	AddVectors(vecAngleOffset, NULL_VECTOR, vecAngleAdditive);
	
	// angleOffset *= 20 (???)
	ScaleVector(vecAngleAdditive, 20.0);
	
	// m_vecPunchAngleVel += angleOffset
	AddVectors(vecAnglePlayer, vecAngleAdditive, vecAnglePlayer);
	
	SetEntPropVector(client, Prop_Data, "m_vecPunchAngleVel", vecAnglePlayer);
}

/**
 * Sets the FOV of the client, doing interpolation between old and new if requested.
 * 
 * (Difference from SDK implementation:  The zoom owner isn't required, and there are no checks
 * to ensure that the requester can override the owner).
 */
stock bool SetPlayerFOV(int client, int fov, float zoomRate, int zoomStart = 0,
		int requester = -1) {
	if (requester > -1 && IsValidEntity(requester)) {
		SetEntProp(client, Prop_Data, "m_hZoomOwner", requester);
	}
	
	if (zoomStart > 0) {
		SetEntProp(client, Prop_Data, "m_iFOVStart", zoomStart);
	} else {
		SetEntProp(client, Prop_Data, "m_iFOVStart", GetPlayerFOV(client));
	}
	
	SetEntProp(client, Prop_Data, "m_iFOV", fov);
	SetEntPropFloat(client, Prop_Data, "m_flFOVRate", zoomRate);
	
	return true;
}

stock int GetPlayerFOV(int client) {
	return GetEntProp(client, Prop_Data, "m_iFOV");
}