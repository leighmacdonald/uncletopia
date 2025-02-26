#if defined __stocksoup_sdkports_vector_included
	#endinput
#endif

#define __stocksoup_sdkports_vector_included

/**
 * Checks if a point is in the field of view of an object.  Supports up to 180 degree FOV.
 * I forgot how the dot product stuff works.
 * 
 * Direct port of the function of the same name from the Source SDK:
 * https://github.com/ValveSoftware/source-sdk-2013/blob/beaae8ac45a2f322a792404092d4482065bef7ef/sp/src/public/mathlib/vector.h#L461-L477
 * 
 * @param vecSrcPosition	Source position of the view.
 * @param vecTargetPosition	Point to check if within view angle.
 * @param vecLookDirection	The direction to look towards.  Note that this must be a forward
 * 							angle vector.
 * @param flCosHalfFOV		The width of the forward view cone as a dot product result. For
 * 							subclasses of CBaseCombatCharacter, you can use the
 * 							`m_flFieldOfView` data property.  To manually calculate for a
 * 							desired FOV, use `cos(0.5 * FOV)`.
 * @return					True if the point is within view from the source position at the
 * 							specified FOV.
 */
stock bool PointWithinViewAngle(const float vecSrcPosition[3], const float vecTargetPosition[3],
		const float vecLookDirection[3], float flCosHalfFOV) {
	float vecDelta[3];
	
	SubtractVectors(vecTargetPosition, vecSrcPosition, vecDelta);
	
	float cosDiff = GetVectorDotProduct(vecLookDirection, vecDelta);
	
	if (cosDiff < 0.0) {
		return false;
	}
	
	float flLen2 = GetVectorLength(vecDelta, true);
	
	// a/sqrt(b) > c  == a^2 > b * c ^2
	return ( cosDiff * cosDiff >= flLen2 * flCosHalfFOV * flCosHalfFOV );
}
