/**
 * A couple of additional timer functions.
 */

#if defined __stocksoup_timers_included
	#endinput
#endif

#define __stocksoup_timers_included

/**
 * Creates a timer that is set to fire at a random time.  If TIMER_REPEAT is set, the interval
 * between timer triggers is random within the bounds set.
 * 
 * Calling `CloseHandle()` on the timer will end it.
 * 
 * @param flMinTime		Minimum interval to execute the given function.
 * @param flMaxTime		Maximum interval to execute the given function.
 * @param func			Function to execute in between the given interval bounds.
 * @param data			Handle or value to pass through to the timer callback function.
 * @param flags			Flags to set.
 * @return				Handle to the timer object.  You do not need to call `CloseHandle()`.
 * 						If the timer could not be created, INVALID_HANDLE will be returned.
 */
stock Handle CreateRandomDurationTimer(float flMinTime, float flMaxTime, Timer func,
		any data = 0, int flags = 0) {
	if (flags & TIMER_REPEAT) {
		// Repeating timer; use some filthy hacks to make it repeat
		// Use a value greater than flMaxTime as we have to trigger the timer manually.
		Handle timer = CreateTimer(flMaxTime + 1.0, func, data, flags);
		
		if (timer) {
			CreateInternalRandomTimer(flMinTime, flMaxTime, timer);
			return timer;
		}
	} else {
		// Not a repeating timer, just set a random time
		return CreateTimer(GetRandomFloat(flMinTime, flMaxTime), func, data, flags);
	}
	return INVALID_HANDLE;
}

/**
 * Internal function that fires a given timer.
 */
static void CreateInternalRandomTimer(float flMinTime, float flMaxTime, Handle timer) {
	DataPack timerData;
	CreateDataTimer(GetRandomFloat(flMinTime, flMaxTime), RandomTimerTriggered, timerData);
	
	timerData.WriteCell(timer);
	timerData.WriteFloat(flMinTime);
	timerData.WriteFloat(flMaxTime);
}

/**
 * Internal callback that is fired after a random interval timer has elapsed.
 */
static stock Action RandomTimerTriggered(Handle internalTimer, DataPack timerData) {
	timerData.Reset();
	
	Handle randomTimer = timerData.ReadCell();
	
	/**
	 * We have no idea if the timer is still valid before being triggered (as it could've been
	 * killed at any time when triggered), so we *must* use `IsValidHandle()` to check if the
	 * timer is still available.
	 * 
	 * Hold my beer.
	 */
	if (IsValidHandle(randomTimer)) {
		TriggerTimer(randomTimer, true);
		
		// We'll assume the timer is still going and just check on the next interval.
		float flMinTime = timerData.ReadFloat();
		float flMaxTime = timerData.ReadFloat();
		
		CreateInternalRandomTimer(flMinTime, flMaxTime, randomTimer);
	}
	return Plugin_Stop;
}
