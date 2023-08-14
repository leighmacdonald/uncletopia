public void onPluginStart()
{
	CreateTimer(30.0, updateState, _, TIMER_REPEAT);
}


stock GetRealClientCount()
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


stock GetAllClientCount()
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

public Action updateState(Handle timer)
{

	char curMap[PLATFORM_MAX_PATH];
	if(!GetCurrentMap(curMap, sizeof curMap))
	{
		return Plugin_Handled;
	}

	char curHostname[PLATFORM_MAX_PATH];
	if(!GetConVarString(gHostname, curHostname, sizeof curHostname))
	{
		return Plugin_Handled;
	}

	char serverName[PLATFORM_MAX_PATH];
	gServerName.GetString(serverName, sizeof serverName);

	JSON_Object obj = new JSON_Object();
	obj.SetString("current_map", curMap);
	obj.SetString("hostname", curHostname);
	obj.SetString("short_name", serverName);
	obj.SetInt("players_real", GetRealClientCount());
    obj.SetInt("players_total", GetAllClientCount());
    obj.SetInt("players_visible", gSvVisibleMaxPlayers.IntValue);
	
	char encoded[PLATFORM_MAX_PATH * 6];
	obj.Encode(encoded, sizeof encoded);
	
	json_cleanup_and_delete(obj);

	System2HTTPRequest req = newReq(onStateUpdateResp, "/api/state_update");
	req.SetData(encoded);
	req.POST();
	delete req;
    
    return Plugin_Continue;
}

void onStateUpdateResp(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!success)
	{
		gbLog("State update error: %s", error);
	}
}
