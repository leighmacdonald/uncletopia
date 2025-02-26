#if defined __stocksoup_log_server_included
	#endinput
#endif

#define __stocksoup_log_server_included

// Change the maximum length of the message if desired.
#if !defined LOG_SERVER_MESSAGE_MAXLEN
	#define LOG_SERVER_MESSAGE_MAXLEN 1024
#endif

#if !defined LOG_SERVER_DEFINED
	#define LOG_SERVER_DEFINED
#endif

/**
 * Prints a plugin message to the server console.  The log message will be prefixed by the
 * plugin's logtag (filename).
 * 
 * If LOG_SERVER_DISABLE is defined before this file is included, treat this function as a
 * no-op.
 * 
 * @param format		String format.
 * @param any			Format arguments.
 */
stock void LogServer(const char[] format, any ...) {
	#if !defined LOG_SERVER_DISABLE
	char message[LOG_SERVER_MESSAGE_MAXLEN], pluginName[PLATFORM_MAX_PATH], dateTime[64];
	
	VFormat(message, sizeof(message), format, 2);
	GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));
	FormatTime(dateTime, sizeof(dateTime), NULL_STRING);
	
	PrintToServer("- %s: [%s] %s", dateTime, pluginName, message);
	#endif
}
