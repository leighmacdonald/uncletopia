/**
 * Some math-related functions.
 */
#if defined __stocksoup_math_included
	#endinput
#endif

#define __stocksoup_math_included

/**
 * Linearly interpolates float across (a, b).
 */
stock float LerpFloat(float flPercent, float a, float b) {
	return a + ((b - a) * flPercent);
}

/**
 * Scales the difference between `initial` to `current` by a factor of `scale`.
 * Completely missed the fact that LerpFloat does the same thing; this is now just present for
 * backwards compatibility.
 */
#pragma deprecated This is literally just LerpFloat with a different name and argument order
stock float ScaleDifference(float current, float initial, float scale) {
	return LerpFloat(scale, initial, current);
}

/**
 * Clamps the given value to between min / max.
 */
stock float ClampFloat(float value, float min, float max) {
	if (value > max) {
		return max;
	} else if (value < min) {
		return min;
	}
	return value;
}

/**
 * Returns a normalized angle between [-180.0, 180).
 */
stock float NormalizeAngle(float value) {
	// https://stackoverflow.com/a/43780476
	return value - 360.0 * RoundToFloor((value + 180.0) / 360.0);
}

/**
 * Converts a signed 8-bit value into a signed 32-bit value.
 * Any higher bits set will be ignored and replaced accordingly.
 */
stock int SignExtendInt8(int byte) {
	return (byte >> 7 & 1)? 0xFFFFFF00 | byte : 0x000000FF & byte;
}

/**
 * Converts a signed 16-bit value into a signed 32-bit value.
 * Any higher bits set will be ignored and replaced accordingly.
 */
stock int SignExtendInt16(int word) {
	return (word >> 15 & 1)? 0xFFFF0000 | word : 0x0000FFFF & word;
}

/** 
 * The double values below can be represented by the following enum struct:
 * 
 *     enum struct Double {
 *         int low;
 *         int high;
 *     }
 */

/**
 * Performs a double conversion to a float value.
 * Lower 32 bits of the double should be in index zero.
 */
stock float DoubleToFloat(const int dblVal[2], bool clamp = false) {
	int sign = (dblVal[1] >> 31) & 1;
	
	// extract truncated mantissa from both cells
	int mantissa = ((dblVal[1] << 3) & 0x007FFFFF) | (dblVal[0] >> 29);
	int expdbl_2 = (dblVal[1] >> 20) & 0x7FF;
	
	int expflt_2 = (expdbl_2 - 1023) + 127;
	if (expdbl_2 == 0x7FF) {
		// special case: infinity or subnormal
		expflt_2 = 0xFF;
		mantissa = (mantissa || dblVal[0]);
	} else if (expdbl_2 == 0) {
		// special case: no exponent
		expflt_2 = 0;
	} else if (expflt_2 > 0xFE) {
		// case: exponent is larger than can be represented
		// TODO test case for smaller exponent values
		if (!clamp) {
			ThrowError("Double value %08x%08x is outside of float value range", dblVal[1], dblVal[0]);
		}
		expflt_2 = 0xFE;
		mantissa = 0x007FFFFFF;
	}
	
	return view_as<float>((sign << 31) | (expflt_2 << 23) | (mantissa & 0x007FFFFF));
}

/**
 * Performs a float conversion to a double value.
 * Lower bits of the double in index zero.
 */
stock void FloatToDouble(float flValue, int dblVal[2]) {
	int bytesFloat = view_as<int>(flValue);
	
	int sign = (bytesFloat >> 31) & 1;
	int exp_2 = (bytesFloat >> 23) & 0xFF;
	int mantissa = bytesFloat & 0x007FFFFF;
	
	int expdbl_2 = (1023 + (exp_2 - 127)) & 0x7FF;
	if (exp_2 == 0xFF) {
		// special case: infinity or subnormal
		expdbl_2 = 0x7FF;
	} else if (exp_2 == 0) {
		// special case: no exponent
		expdbl_2 = 0;
	}
	
	// no bits in lower three bytes of double
	dblVal[0] = (mantissa << 29);
	dblVal[1] = (sign << 31) | (expdbl_2 << 20) | (mantissa >> 3);
}

/**
 * Returns a vector containing the midpoint between two points.
 */
stock void GetCenterFromPoints(const float pt1[3], const float pt2[3], float center[3]) {
	center[0] = pt1[0] + pt2[0] / 2.0;
	center[1] = pt1[1] + pt2[1] / 2.0;
	center[2] = pt1[2] + pt2[2] / 2.0;
}

/**
 * Calculates the width of the forward view cone as a dot product result from the given angle.
 * This manually calculates the value of CBaseCombatCharacter's `m_flFieldOfView` data property.
 *
 * For reference: https://github.com/ValveSoftware/source-sdk-2013/blob/master/sp/src/game/server/hl2/npc_bullseye.cpp#L151
 *
 * @param angle     The FOV value in degree
 * @return          Width of the forward view cone as a dot product result
 */
stock float GetFOVDotProduct(float angle) {
	return Cosine(DegToRad(angle) / 2.0);
}