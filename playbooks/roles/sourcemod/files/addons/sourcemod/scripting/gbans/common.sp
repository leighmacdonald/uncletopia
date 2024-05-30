#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

stock void gbLog(const char[] format, any...)
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
}

stock bool isValidClient(int client)
{
	if(!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client) || IsClientReplay(client))
	{
		return false;
	}
	return true;
}

stock void addAuthHeader(HTTPRequest request) {
	char serverKey[PLATFORM_MAX_PATH];
	GetConVarString(gb_core_server_key, serverKey, sizeof serverKey);

	request.SetHeader("Authorization", serverKey);
}

stock int GetRealClientCount()
{
	int iClients = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			iClients++;
		}
	}

	return iClients;
}

stock int GetAllClientCount()
{
	int iClients = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			iClients++;
		}
	}

	return iClients;
}

stock void reply(int clientId, const char[] message) {
	if (clientId > 0) {
		ReplyToCommand(clientId, message);
	} else {
		gbLog(message);
	}
}