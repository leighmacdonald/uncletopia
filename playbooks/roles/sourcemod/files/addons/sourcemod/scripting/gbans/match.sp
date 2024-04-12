#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

// This gets incremented every time the teamplay_round_start event is fired. This event fires on the following conditions, so only the 
// 2nd fire is to be acted upon.
// - Pre setup time
// - The start of setup time <- valid
// - The start of setup time after swapping sides
int gMatchStartedCount = 0;

public Action onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	gMatchStartedCount++;

	if (gMatchStartedCount != 2) {
		return Plugin_Continue;
	}

	char url[1024];
	makeURL("/api/sm/match/start", url, sizeof url);

	HTTPRequest request = new HTTPRequest(url);
	addAuthHeader(request);
	
	char mapName[64];
	GetCurrentMap(mapName, sizeof mapName);

	char stvFileName[1024];
	SourceTV_GetDemoFileName(stvFileName, sizeof stvFileName);

	JSONObject obj = new JSONObject();
	obj.SetString("map_name", mapName);
	obj.SetString("demo_name", stvFileName);

    request.Post(obj, onRoundStartCB); 

	delete obj;

    return Plugin_Continue;
}

void onRoundStartCB(HTTPResponse response, any value)
{
	if (response.Status != HTTPStatus_Created) { 
		gbLog("Round start request did not complete successfully");
		return ;
	}

	gbLog("Round started");

	JSONObject matchOpts = view_as<JSONObject>(response.Data); 

	matchOpts.GetString("match_id", gMatchID, sizeof gMatchID);

	gbLog("Got new match_id: %s", gMatchID);

	PrintToChatAll("Match started: %s", gMatchID);
}

public Action onRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	PrintToChatAll("End Count: %d", gMatchStartedCount);
	char url[1024];
	makeURL("/api/sm/match/end", url, sizeof url);

	HTTPRequest request = new HTTPRequest(url);
	addAuthHeader(request);
    request.Get(onRoundEndCB);

    return Plugin_Continue;
}

void onRoundEndCB(HTTPResponse response, any value)
{
	if(response.Status != HTTPStatus_OK)
	{
		gbLog("Ban request did not complete successfully");
		return ;
	}

	gbLog("Round end completed");
	PrintToChatAll("Match ended: %s", gMatchID);

	if (StrEqual(gMatchID, "")) {
		return;
	}

	char path[1024];
	Format(path, sizeof path, "/match/%s", gMatchID);

	char matchURL[1024];
	makeURL(path, matchURL, sizeof matchURL);

	PrintToChatAll("Match stats: %s", matchURL);

	gMatchStartedCount = 0;
}