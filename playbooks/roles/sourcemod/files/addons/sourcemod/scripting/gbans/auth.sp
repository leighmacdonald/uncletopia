#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public Action onAdminCmdReload(int clientId, int argc)
{
	reloadAdmins(true);

	return Plugin_Handled;
}

public void reloadAdmins(bool force)
{
	ServerCommand("sm_reloadadmins");
}

public void OnClientPostAdminCheck(int clientId) {
	gbLog("--- OnClientPostAdminCheck");
	if (!(clientId > 0 && IsClientInGame(clientId) && !IsFakeClient(clientId))) {
		return;
	}

	checkPlayer(clientId);
}

void checkPlayer(int clientId)
{
	
	if (!(clientId > 0 && IsClientInGame(clientId) && !IsFakeClient(clientId))) {
		gbLog("Skipping check on invalid player");
		return ;
	}
	
	gbLog("--- checkPlayer");

	char ip[16];
	GetClientIP(clientId, ip, sizeof ip);

	char name[32];
	GetClientName(clientId, name, sizeof name);

	char clientAuth[64];
	GetClientAuthId(clientId, AuthId_SteamID64, clientAuth, sizeof(clientAuth));


	JSONObject obj = new JSONObject(); 
	obj.SetString("steam_id", clientAuth);
	obj.SetInt("client_id", clientId);
	obj.SetString("ip", ip);
	obj.SetString("name", name);

	char url[1024];
	makeURL("/api/sm/check", url, sizeof url);

	HTTPRequest request = new HTTPRequest(url);
	addAuthHeader(request);

    request.Post(obj, onCheckResp); 

	delete obj;
}


void onCheckResp(HTTPResponse response, any value)
{
	gbLog("--- onCheckResp");
	if (response.Status != HTTPStatus_OK) {
		LogError("Invalid check response code: %d", response.Status);

        return;
    } 

	JSONObject data = view_as<JSONObject>(response.Data); 
	
	char msg[256];
	data.GetString("msg", msg, sizeof msg);
	int clientId = data.GetInt("client_id");
	int banType = data.GetInt("ban_type");

	switch(banType)
	{
		case BSNoComm: {
			if(!BaseComm_IsClientMuted(clientId)) {
				BaseComm_SetClientMute(clientId, true);
			}
			if(!BaseComm_IsClientGagged(clientId)){
				BaseComm_SetClientGag(clientId, true);
			}
			ReplyToCommand(clientId, "You are currently muted/gag, it will expire automatically");
			gbLog("Muted \"%L\" for an unfinished mute punishment.", clientId);
		}
		case BSNetwork:
		{
		    KickClient(clientId, msg);
		    LogAction(0, clientId, "Kicked \"%L\" for a network block.", clientId);
		}
		case BSBanned:
		{
			KickClient(clientId, msg);
			LogAction(0, clientId, "Kicked \"%L\" for an unfinished ban.", clientId);
		}
	}

}
