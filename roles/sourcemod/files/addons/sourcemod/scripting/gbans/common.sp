#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

void gbLog(const char[] format, any...)
{
	char buffer[254];
	VFormat(buffer, sizeof buffer, format, 2);
	PrintToServer("[GB] %s", buffer);
}

public bool parseReason(const char[] reasonStr, GB_BanReason &reason)
{
	int reasonInt = StringToInt(reasonStr, 10);
	if(reasonInt <= 0 || reasonInt < view_as<int>(custom) || reasonInt > view_as<int>(itemDescriptions))
	{
		return false;
	}
	reason = view_as<GB_BanReason>(reasonInt);
	return true;
}

stock void makeURL(const char[] path, char[] outURL, int maxLen) {
	char serverHost[PLATFORM_MAX_PATH];
	GetConVarString(gb_core_host, serverHost, sizeof serverHost);
	int port = GetConVarInt(gb_core_port);

	Format(outURL, maxLen, "%s:%d%s", serverHost, port, path);

	gbLog("Made url: %s", outURL);
}

public void OnMapEnd()
{
	onMapEndSTV();
}


stock bool isValidClient(int client)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}
	return true;
}
