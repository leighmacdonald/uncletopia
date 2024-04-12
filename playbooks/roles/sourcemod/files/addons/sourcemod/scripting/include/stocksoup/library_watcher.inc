/**
 * A collection of functions to make tracking library availability slightly easier.
 * 
 * If AUTO_LIBRARY_MANAGEMENT is defined, this include will add its own `OnLibraryAdded` and
 * `OnLibraryRemoved` callbacks.  If it is not, you'll have to call `TrackLibraryAdd` and
 * `TrackLibraryRemove` yourself.
 * 
 * The compiler will warn you that the symbols are never used, if you happen to forget.
 * 
 * If TRACK_LIBRARY_STATES is defined, the `GetLibraryState` function and associated storage
 * will be provided for library state retrieval.  Otherwise, this include file only helps manage
 * forwards for library availability.
 */

#if defined __stocksoup_library_watcher_included
	#endinput
#endif

#define __stocksoup_library_watcher_included

enum LibraryState {
	Library_Untracked = 0,
	Library_Available,
	Library_Unavailable
};

typedef LibraryStateCallback = function void(const char[] name, LibraryState state);

/**
 * Begins tracking a library.  Can be called during `OnPluginStart`.
 */
stock void HookLibraryUpdate(const char[] name, LibraryStateCallback callback) {
	Handle localForward;
	if (!GetLibraryWatchList().GetValue(name, localForward)) {
		localForward = CreateForward(ET_Ignore, Param_String, Param_Cell);
		
		GetLibraryWatchList().SetValue(name, localForward);
	}
	
	AddToForward(localForward, INVALID_HANDLE, callback);
}

/**
 * Stops tracking a library.
 */
stock void UnhookLibraryUpdate(const char[] name, LibraryStateCallback callback) {
	Handle localForward;
	if (GetLibraryWatchList().GetValue(name, localForward)) {
		RemoveFromForward(localForward, INVALID_HANDLE, callback);
		
		if (GetForwardFunctionCount(localForward) == 0) {
			delete localForward;
			GetLibraryWatchList().Remove(name);
		}
	}
#if defined TRACK_LIBRARY_STATES
	GetLibraryStates().DeleteKey(name);
#endif
}

static void UpdateLibraryState(const char[] name, LibraryState state) {
	Handle localForward;
	if (GetLibraryWatchList().GetValue(name, localForward)) {
#if defined TRACK_LIBRARY_STATES
		LibraryState previousState = GetLibraryState(name);
		GetLibraryStates().SetNum(name, view_as<int>(state));
#else
		LibraryState previousState = Library_Untracked;
#endif
		if (previousState == Library_Untracked || previousState != state) {
			Call_StartForward(localForward);
			Call_PushString(name);
			Call_PushCell(state);
			Call_Finish();
		}
	}
}

static stock StringMap GetLibraryWatchList() {
	static StringMap s_LibraryInfo;
	
	if (!s_LibraryInfo) {
		s_LibraryInfo = new StringMap();
	}
	return s_LibraryInfo;
}

#if defined TRACK_LIBRARY_STATES
/**
 * Returns the current library availability.
 */
stock LibraryState GetLibraryState(const char[] name) {
	return view_as<LibraryState>(GetLibraryStates().GetNum(name));
}

static stock KeyValues GetLibraryStates() {
	static KeyValues s_LibraryState;
	
	if (!s_LibraryState) {
		s_LibraryState = new KeyValues("library-state");
	}
	return s_LibraryState;
}
#endif

/**
 * Functions that must be called when a library is added.
 * If AUTO_LIBRARY_MANAGEMENT isn't defined, you'll have to call these functions yourself.
 */

void TrackLibraryAdd(const char[] name) {
	UpdateLibraryState(name, Library_Available);
}

void TrackLibraryRemove(const char[] name) {
	UpdateLibraryState(name, Library_Unavailable);
}

/**
 * Automatic library tracking.
 */

#if defined AUTO_LIBRARY_MANAGEMENT
public void OnLibraryAdded(const char[] name) {
	TrackLibraryAdd(name);
}

public void OnLibraryRemoved(const char[] name) {
	TrackLibraryRemove(name);
}
#endif
