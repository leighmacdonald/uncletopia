#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

bool gMatchStarted = false;

public Action onRoundStart(Handle event, const char[] name, bool dontBroadcast) {
	if (gMatchStarted) {
		return Plugin_Continue;
	}
	
	gMatchStarted = true;

	gbLog("Round start");
	char url[1024];
	makeURL("/api/sm/match/start", url, sizeof url);

	HTTPRequest request = new HTTPRequest(url);
	addAuthHeader(request);

	char stvFileName[1024];
	SourceTV_GetDemoFileName(stvFileName, sizeof stvFileName);

	JSONObject obj = new JSONObject();
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
}

public Action onRoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	gbLog("Round end");
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
}