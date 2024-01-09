#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <ripext>

/**
Authenticates the server with the backend API system.

Send unauthenticated request for token to -> API /api/server_auth
Recv Token <- API
Send authenticated commands with header "Authorization $token" set for subsequent calls -> API /api/<path>

*/
public void refreshToken()
{
	gbLog("Refreshing token %s", PLUGIN_VERSION);

	char serverName[PLATFORM_MAX_PATH];
	GetConVarString(gb_core_server_name, serverName, sizeof serverName);

	char serverKey[PLATFORM_MAX_PATH];
	GetConVarString(gb_core_server_key, serverKey, sizeof serverKey);

	JSONObject obj = new JSONObject();
	obj.SetString("server_name", serverName);
	obj.SetString("key", serverKey);

	char url[1024];
	makeURL("/api/server/auth", url, sizeof url);
	
	gbLog("Calling: %s", url);
	
	HTTPRequest request = new HTTPRequest(url);
    request.Post(obj, onAuthReqReceived);

	delete obj;
}

public void onAuthReqReceived(HTTPResponse response, any value)
{
	gbLog("Refreshing token reponded");

	if (response.Status != HTTPStatus_OK) {
        gbLog("Invalid refreshToken response code: %d", response.Status);
        return;
    } 

	JSONObject resp = view_as<JSONObject>(response.Data); 

	char token[512];

	bool status = resp.GetBool("status");
	if (!status) {
		gbLog("Invalid server auth status returned");
		return;
	}

	resp.GetString("token", token, sizeof token);

	if(strlen(token) == 0)
	{
		gbLog("Invalid response status, invalid token");
		return;
	}

	gAccessToken = token;
	gbLog("Successfully authenticated with gbans server");

	reloadAdmins(false);
}

public Action onAdminCmdReload(int clientId, int argc)
{
	reloadAdmins(true);

	return Plugin_Handled;
}

public void reloadAdmins(bool force)
{
	gbLog("Reloading admin users");
	char path[PLATFORM_MAX_PATH];
	getAdminCachePath(path);

	bool doRequest = false;

	if (force || !FileExists(path)) {
		doRequest = true;
	} else {
		int time = GetFileTime(path, FileTime_LastChange);
		doRequest = time == -1 || (GetTime() - time) > 3600;
	}

	if (!doRequest) {
		gbLog("Using cached admins");

		return;
	}

	char url[1024];
	makeURL("/export/sourcemod/admins_simple.ini", url, sizeof url);

	char savePath[PLATFORM_MAX_PATH];
	getAdminCachePath(savePath);

	HTTPRequest request = new HTTPRequest(url);

	request.SetHeader("Authorization", gAccessToken);

	request.DownloadFile(savePath, onAdminsReqReceived); 
}

void getAdminCachePath(char[] out) {
	BuildPath(Path_SM, out, PLATFORM_MAX_PATH, "configs/admins_simple.ini");
}

void onAdminsReqReceived(HTTPStatus status, any value)
{
	if (status != HTTPStatus_OK) {
        gbLog("Invalid reloadAdmins response code: %d", status);
        return;
    } 

	ServerCommand("sm_reloadadmins");

	gbLog("Reloaded admins");
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
	//OnClientPutInServerSTV(clientId);
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
    // BSNoComm handled in OnClientPutInServer
	switch(gPlayers[clientId].banType)
	{

		case BSNetwork:
		{
		    KickClient(clientId, gPlayers[clientId].message);
		    LogAction(0, clientId, "Kicked \"%L\" for a network block.", clientId);
		}
		case BSBanned:
		{
			KickClient(clientId, gPlayers[clientId].message);
			LogAction(0, clientId, "Kicked \"%L\" for an unfinished ban.", clientId);
		}
	}
}


void checkPlayer(int clientId, const char[] auth, const char[] ip, const char[] name)
{
	if(!IsClientConnected(clientId) || IsFakeClient(clientId)) {
		gbLog("Skipping check on invalid player");
		return ;
	}

	JSONObject obj = new JSONObject(); 
	obj.SetString("steam_id", auth);
	obj.SetInt("client_id", clientId);
	obj.SetString("ip", ip);
	obj.SetString("name", name);

	char url[1024];
	makeURL("/api/check", url, sizeof url);

	HTTPRequest request = new HTTPRequest(url);
    request.Post(obj, onCheckResp); 

	delete obj;
}


void onCheckResp(HTTPResponse response, any value)
{
	if (response.Status != HTTPStatus_OK) {
		LogError("Invalid check response code: %d", response.Status);

        return;
    } 

	JSONObject data = view_as<JSONObject>(response.Data); 

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

	// Called manually since we are using the connect extension
	onClientPostAdminCheck(clientId);
}
