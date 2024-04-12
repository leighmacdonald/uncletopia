#if defined __stocksoup_sdkports_util_included
	#endinput
#endif

#define __stocksoup_sdkports_util_included

/* Utility functions ported over from the Source SDK (util.cpp). */

/* Accurate screenfade implementation from Valve below. */
#define SCREENFADE_FRACBITS 9
#define FFADE_IN       0x0001 // Just here so we don't pass 0 into the function
#define FFADE_OUT      0x0002 // Fade out (not in)
#define FFADE_MODULATE 0x0004 // Modulate (don't blend)
#define FFADE_STAYOUT  0x0008 // ignores the duration, stays faded out until new ScreenFade message received
#define FFADE_PURGE    0x0010 // Purges all other fades, replacing them with this one

stock void UTIL_ScreenFade(int target, const int color[4], float flDuration, float flHoldTime,
		int flags = FFADE_IN) {
	UserMsg s_fadeUserMsgId = GetUserMessageId("Fade");
	int targets[1];
	targets[0] = target;

	int duration = FixedUnsigned16(flDuration, 1 << SCREENFADE_FRACBITS);
	int holdtime = FixedUnsigned16(flHoldTime, 1 << SCREENFADE_FRACBITS);

	Handle message = StartMessageEx(s_fadeUserMsgId, targets, 1);
	if (GetUserMessageType() == UM_Protobuf) {
		PbSetInt(message, "duration", duration);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", flags);
		PbSetColor(message, "clr", color);
	} else {
		BfWriteShort(message, duration);
		BfWriteShort(message, holdtime);
		BfWriteShort(message, flags);        
		BfWriteByte(message, color[0]);
		BfWriteByte(message, color[1]);
		BfWriteByte(message, color[2]);
		BfWriteByte(message, color[3]);
	}

	EndMessage();
}

stock int FixedUnsigned16(float value, int scale) {
	int output = RoundFloat(value * scale);
	if (output < 0) {
		output = 0;
	}
	if (output > 0xFFFF) {
		output = 0xFFFF;
	}
	return output;
}
