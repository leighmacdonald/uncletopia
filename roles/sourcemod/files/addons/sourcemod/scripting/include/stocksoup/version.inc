/** 
 * Stock functions for game version identification.
 */

#if defined __stocksoup_version_included
	#endinput
#endif

#define __stocksoup_version_included

/** 
 * Returns a StringMap containing key-value entries from steam.inf.
 */
static stock StringMap GetSteamINFData() {
	static StringMap s_VersionInfo;
	
	if (!s_VersionInfo) {
		s_VersionInfo = new StringMap();
		
		File hSteam = OpenFile("steam.inf", "r");
		
		char buffer[32];
		while (hSteam.ReadLine(buffer, sizeof(buffer))) {
			int assign = FindCharInString(buffer, '=');
			if (assign != -1) {
				// copy everything up to equals sign
				char[] key = new char[assign + 1];
				strcopy(key, assign + 1, buffer);
				
				s_VersionInfo.SetString(key, buffer[assign + 1]);
			}
		}
		
		delete hSteam;
	}
	
	return s_VersionInfo;
}

stock int GetNetworkPatchVersion() {
	char buffer[16];
	if (GetSteamINFData().GetString("PatchVersion", buffer, sizeof(buffer))) {
		return StringToInt(buffer);
	}
	return 0;
}

stock int GetApplicationClientVersion() {
	char buffer[16];
	if (GetSteamINFData().GetString("ClientVersion", buffer, sizeof(buffer))) {
		return StringToInt(buffer);
	}
	return 0;
}

stock int GetApplicationServerVersion() {
	char buffer[16];
	if (GetSteamINFData().GetString("ServerVersion", buffer, sizeof(buffer))) {
		return StringToInt(buffer);
	}
	return 0;
}
