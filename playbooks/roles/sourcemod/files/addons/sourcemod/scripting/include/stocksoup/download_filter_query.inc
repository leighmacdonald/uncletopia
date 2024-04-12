#if defined __stocksoup_download_filter_query_included
	#endinput
#endif

#define __stocksoup_download_filter_query_included

#define DOWNLOADFILTER_NONE		(0 << 0)				// No downloads allowed.
#define DOWNLOADFILTER_MAPS		(1 << 0)				// Maps.
#define DOWNLOADFILTER_SOUNDS	(1 << 1)				// Sounds.
#define DOWNLOADFILTER_ALL		~DOWNLOADFILTER_NONE	// All downloads allowed.

typedef DownloadFlagsReceived = function void(int client, int downloadflags);

/**
 * Starts querying the client to see what downloads they have enabled.
 * 
 * @param client		Which client to query
 * @param callback		Callback function.
 */
stock void QueryClientDownloadFilters(int client, DownloadFlagsReceived callback) {
	DataPack callpack = new DataPack();
	callpack.WriteFunction(callback);
	
	if (!IsClientInGame(client) ||
			QueryClientConVar(client, "cl_allowdownload", OnAllowDownloadQueried, callpack) == QUERYCOOKIE_FAILED) {
		CallFiltersReceivedCallback(callback, client, DOWNLOADFILTER_NONE);
		delete callpack;
	}
}

/**
 * Internal handler for when `cl_allowdownload` is done being queried.
 * If downloads are enabled and client is still valid, it queries `cl_downloadfilter`.
 * If not, assume no downloads are allowed.
 */
public void OnAllowDownloadQueried(QueryCookie cookie, int client, ConVarQueryResult result,
		const char[] convarName, const char[] convarValue, DataPack callpack) {
	bool bAllowDownload = StringToInt(convarValue) != 0;
	if (!bAllowDownload || !IsClientInGame(client)
			|| QueryClientConVar(client, "cl_downloadfilter", OnDownloadFiltersQueried, callpack) == QUERYCOOKIE_FAILED) {
		callpack.Reset();
		DownloadFlagsReceived callback = view_as<DownloadFlagsReceived>(callpack.ReadFunction());
		
		CallFiltersReceivedCallback(callback, client, DOWNLOADFILTER_NONE);
		
		delete callpack;
	}
}

/**
 * Internal handler for when `cl_downloadfilter` is done being queried.
 * Calls the callback function with flags indicating which downloads are allowed.
 */
public void OnDownloadFiltersQueried(QueryCookie cookie, int client, ConVarQueryResult result,
		const char[] convarName, const char[] convarValue, DataPack callpack) {
	callpack.Reset();
	DownloadFlagsReceived callback = view_as<DownloadFlagsReceived>(callpack.ReadFunction());
	
	delete callpack;
	
	CallFiltersReceivedCallback(callback, client, GetDownloadFilterFlags(convarValue));
}

/**
 * Converts a `cl_downloadfilter` value to a set of flags.
 */
stock int GetDownloadFilterFlags(const char[] filter) {
	if (StrEqual(filter, "none")) {
		return DOWNLOADFILTER_NONE;
	} else if (StrEqual(filter, "mapsonly")) {
		return DOWNLOADFILTER_MAPS;
	} else if (StrEqual(filter, "nosounds")) {
		return DOWNLOADFILTER_ALL & ~DOWNLOADFILTER_SOUNDS;
	} else if (StrEqual(filter, "all")) {
		return DOWNLOADFILTER_ALL;
	}
	return DOWNLOADFILTER_NONE;
}

/**
 * Calls the necessary callback.
 */
static stock void CallFiltersReceivedCallback(DownloadFlagsReceived callback, int client,
		int downloadflags) {
	Call_StartFunction(INVALID_HANDLE, callback);
	Call_PushCell(client);
	Call_PushCell(downloadflags);
	Call_Finish();
}
