#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "globals.sp"

/**
Authenticates the server with the backend API system.

Send unauthenticated request for token to -> API /api/server_auth
Recv Token <- API
Send authenticated commands with header "Authorization $token" set for subsequent calls -> API /api/<path>

*/
void refreshToken()
{
	char serverName[PLATFORM_MAX_PATH];
	gServerName.GetString(serverName, sizeof serverName);

	char serverKey[PLATFORM_MAX_PATH];
	gServerKey.GetString(serverKey, sizeof serverKey);

	JSON_Object obj = new JSON_Object();
	obj.SetString("server_name", serverName);
	obj.SetString("key", serverKey);
	char encoded[1024];
	obj.Encode(encoded, sizeof encoded);
	json_cleanup_and_delete(obj);

	System2HTTPRequest req = newReq(onAuthReqReceived, "/api/server/auth");
	req.SetData(encoded);
	req.POST();
	delete req;
}


void onAuthReqReceived(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!success) {
		gbLog("Error on authentication request: %s", error);
		return;
	}

	char lastURL[128];
	response.GetLastURL(lastURL, sizeof lastURL);
	int statusCode = response.StatusCode;
	if(statusCode != HTTP_STATUS_OK)
	{
		gbLog("Bad status on authentication request: %d", statusCode);
		return ;
	}

	char[] content = new char[response.ContentLength + 1];
	int contentSize = response.GetContent(content, response.ContentLength + 1);
	PrintToServer("Content of the response: %s", content); 
	if (contentSize <= 0) {
		gbLog("Empty content");
		return;
	}

	JSON_Object data = json_decode(content);
	if (data == null) {
		gbLog("Invalid auth response json");
		return;
	}


	char token[512];

	bool status = data.GetBool("status");
	if (!status) {
		gbLog("Invalid server auth status returned");
		return;
	}

	data.GetString("token", token, sizeof token);

	if(strlen(token) == 0)
	{
		gbLog("Invalid response status, invalid token");
		return;
	}

	gAccessToken = token;
	gbLog("Successfully authenticated with gbans server");
	json_cleanup_and_delete(data);
	delete response;
}


public Action onAdminCmdReload(int clientId, int argc)
{
	reloadAdmins();
	return Plugin_Handled;
}


void reloadAdmins()
{
	gbLog("Fetching admin users");
	System2HTTPRequest req = newReq(onAdminsReqReceived, "/export/sourcemod/admins_simple.ini");
	req.GET();
	delete req;
}


void onAdminsReqReceived(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if (!success) {
		gbLog("Error on reload admins request: %s", error);
		return;
	}

	char lastURL[128];
	response.GetLastURL(lastURL, sizeof lastURL);
	int statusCode = response.StatusCode;
	if(statusCode != HTTP_STATUS_OK)
	{
		gbLog("Bad status on reload admins request: %d", statusCode);
		return ;
	}
	char[] content = new char[response.ContentLength + 1];
	response.GetContent(content, response.ContentLength + 1);
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/admins_simple.ini");

	gbLog(path);
	Handle f = OpenFile(path, "w", false, "");
	if(!WriteFileString(f, content, false))
	{
		gbLog("Failed to write admin file");
		return ;
	}
	CloseHandle(f);
	ServerCommand("sm_reloadadmins");
	gbLog("Reloaded admins");
	delete response;
}


public void writeCachedFile(const char[] name, const char[] data)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "data/gbans/%s.cache", name);
	File fp = OpenFile(path, "w");
	WriteFileString(fp, data, false);
	CloseHandle(fp);
}


public void readCachedFile(const char[] name)
{
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "data/gbans/%s.cache", name);
	// File fp = OpenFile(path, "r");
	// ReadFileString(fp, )
}


public void OnClientPutInServer(int clientId)
{
	OnClientPutInServerMutes(clientId);
	OnClientPutInServerSTV(clientId);
}


public void OnClientPutInServerMutes(int clientId)
{
	switch(gPlayers[clientId].banType)
	{
		case BSNoComm:
		{
			if(!BaseComm_IsClientMuted(clientId))
			{
				BaseComm_SetClientMute(clientId, true);
			}
			if(!BaseComm_IsClientGagged(clientId))
			{
				BaseComm_SetClientGag(clientId, true);
			}
			ReplyToCommand(clientId, "You are currently muted/gag, it will expire automatically");
			gbLog("Muted \"%L\" for an unfinished mute punishment.", clientId);
		}
	}
}


public void onClientPostAdminCheck(int clientId)
{
	switch(gPlayers[clientId].banType)
	{
		// BSNoComm handled in OnClientPutInServer		
		case BSBanned:
		{
			KickClient(clientId, gPlayers[clientId].message);
			LogAction(0, clientId, "Kicked \"%L\" for an unfinished ban.", clientId);
		}
	}
}


void checkPlayer(int clientId, const char[] auth, const char[] ip, const char[] name)
{
	if(!IsClientConnected(clientId) || IsFakeClient(clientId))
	{
		gbLog("Skipping check on invalid player");
		return ;
	}
	char encoded[1024];
	JSON_Object obj = new JSON_Object();
	obj.SetString("steam_id", auth);
	obj.SetInt("client_id", clientId);
	obj.SetString("ip", ip);
	obj.SetString("name", name);
	obj.Encode(encoded, sizeof encoded);
	json_cleanup_and_delete(obj);

	System2HTTPRequest req = newReq(onCheckResp, "/api/check");
	req.SetData(encoded);
	req.POST();
	delete req;
}


void onCheckResp(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(success)
	{
		char lastURL[128];
		response.GetLastURL(lastURL, sizeof lastURL);
		int statusCode = response.StatusCode;
		char[] content = new char[response.ContentLength + 1];
		response.GetContent(content, response.ContentLength + 1);
		if(statusCode != HTTP_STATUS_OK)
		{
			// Fail open if the server is broken
			gbLog("Invalid response code on check call: %d", statusCode);
			return ;
		}

		JSON_Object data = json_decode(content);
		int clientId = data.GetInt("client_id");
		int banType = data.GetInt("ban_type");
		int permissionLevel = data.GetInt("permission_level");
		char msg[256];	// welcome or ban message
		data.GetString("msg", msg, sizeof msg);
		if(IsFakeClient(clientId))
		{
			return ;
		}
		char ip[16];
		GetClientIP(clientId, ip, sizeof ip);
		gPlayers[clientId].authed = true;
		gPlayers[clientId].ip = ip;
		gPlayers[clientId].banType = banType;
		gPlayers[clientId].message = msg;
		gPlayers[clientId].permissionLevel = permissionLevel;

		gbLog("Client authenticated (banType: %d level: %d)", banType, permissionLevel);
		json_cleanup_and_delete(data);
		// Called manually since we are using the connect extension
		onClientPostAdminCheck(clientId);
	}
	else
	{
		gbLog("Error on authentication request: %s", error);
	}
}
