#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "globals.sp"

/**
Authenicates the server with the backend API system.

Send unauthenticated request for token to -> API /api/server_auth
Recv Token <- API
Send authenticated commands with header "Authorization $token" set for subsequent calls -> API /api/<path>

*/
void refreshToken() {
    char server_name[PLATFORM_MAX_PATH];
    g_server_name.GetString(server_name, sizeof(server_name));

    char server_key[PLATFORM_MAX_PATH];
    g_server_key.GetString(server_key, sizeof(server_key));

    JSON_Object obj = new JSON_Object();
    obj.SetString("server_name", server_name);
    obj.SetString("key", server_key);
    char encoded[1024];
    obj.Encode(encoded, sizeof(encoded));
    json_cleanup_and_delete(obj);

    System2HTTPRequest req = newReq(OnAuthReqReceived, "/api/server/auth");
    req.SetData(encoded);
    req.POST();
    delete req;
}

void OnAuthReqReceived(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response,
                       HTTPRequestMethod method) {
    if (success) {
        char lastURL[128];
        response.GetLastURL(lastURL, sizeof(lastURL));
        int statusCode = response.StatusCode;
        if (statusCode != HTTP_STATUS_OK) {
            PrintToServer("[GB] Bad status on authentication request: %d", statusCode);
            return;
        }
        char[] content = new char[response.ContentLength + 1];
        response.GetContent(content, response.ContentLength + 1);
        JSON_Object resp = json_decode(content);
        bool ok = resp.GetBool("status");
        if (!ok) {
            PrintToServer("[GB] Invalid response status, cannot authenticate");
            return;
        }
        JSON_Object data = resp.GetObject("result");
        char token[512];
        data.GetString("token", token, sizeof(token));
        if (strlen(token) == 0) {
            PrintToServer("[GB] Invalid response status, invalid token");
            return;
        }
        g_access_token = token;
        PrintToServer("[GB] Successfully authenticated with gbans server");
        json_cleanup_and_delete(resp);
        reloadAdmins();
    } else {
        PrintToServer("[GB] Error on authentication request: %s", error);
    }
}

public
Action AdminCmdReload(int clientId, int argc) {
    reloadAdmins();
    return Plugin_Handled;
}

void reloadAdmins() {
    PrintToServer("[GB] Refreshing admin users");
    System2HTTPRequest req = newReq(OnAdminsReqReceived, "/api/server/admins");
    req.GET();
    delete req;
}

void OnAdminsReqReceived(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response,
                       HTTPRequestMethod method) {
    if (success) {
        char lastURL[128];
        response.GetLastURL(lastURL, sizeof(lastURL));
        int statusCode = response.StatusCode;
        if (statusCode != HTTP_STATUS_OK) {
            PrintToServer("[GB] Bad status on reload admins request: %d", statusCode);
            return;
        }
        char[] content = new char[response.ContentLength + 1];
        response.GetContent(content, response.ContentLength + 1);
        JSON_Object resp = json_decode(content);
        bool ok = resp.GetBool("status");
        if (!ok) {
            PrintToServer("[GB] Invalid response status, cannot reload admins");
            return;
        }
        JSON_Array adminArray = view_as<JSON_Array>(resp.GetObject("result"));

        int length = adminArray.Length;
        AdminId adm;
        int immunity;
        for (int i = 0; i < length; i += 1) {
            char flags[32];
            char steamId[32];
            JSON_Object perm = adminArray.GetObject(i);
            perm.GetString("flags", flags, sizeof(flags));
            perm.GetString("steam_id", steamId, sizeof(steamId));

            if ((adm = FindAdminByIdentity(AUTHMETHOD_STEAM, steamId)) == INVALID_ADMIN_ID)
            {
                // "" = anon admin
                adm = CreateAdmin("");
                if (!adm.BindIdentity(AUTHMETHOD_STEAM, steamId))
                {
                    LogError("Could not bind prefetched SQL admin (identity \"%s\")", steamId);
                    continue;
                }
            }

            /* Apply each flag */
            int len = strlen(flags);
            AdminFlag flag;
            for (int j=0; j<len; j++)
            {
                if (!FindFlagByChar(flags[j], flag))
                {
                    continue;
                }
                adm.SetFlag(flag, true);
            }
            adm.ImmunityLevel = immunity;
        }       

        PrintToServer("[GB] Successfully reloaded %d admins", length);
        json_cleanup_and_delete(resp);
    } else {
        PrintToServer("[GB] Error on reload admins request: %s", error);
    }
}

public
void OnClientPostAdminCheck(int clientId) {
    switch (g_players[clientId].ban_type) {
        case BSNoComm: {
            if (!BaseComm_IsClientMuted(clientId)) {
                BaseComm_SetClientMute(clientId, true);
            }
            if (!BaseComm_IsClientGagged(clientId)) {
                BaseComm_SetClientGag(clientId, true);
            }
            ReplyToCommand(clientId, "You are currently muted/gag, it will expire automatically");
            LogAction(0, clientId, "Muted \"%L\" for an unfinished mute punishment.", clientId);
        }
        case BSBanned: {
            KickClient(clientId, g_players[clientId].message);
            LogAction(0, clientId, "Kicked \"%L\" for an unfinished ban.", clientId);
        }
    }
}


void CheckPlayer(int clientId, const char[] auth, const char[] ip, const char[] name) {
    if (/**!IsClientConnected(clientId) ||*/ IsFakeClient(clientId)) {
        PrintToServer("[GB] Skipping check on invalid player");
        return;
    }
    char encoded[1024];
    JSON_Object obj = new JSON_Object();
    obj.SetString("steam_id", auth);
    obj.SetInt("client_id", clientId);
    obj.SetString("ip", ip);
    obj.SetString("name", name);
    obj.Encode(encoded, sizeof(encoded));
    json_cleanup_and_delete(obj);

    System2HTTPRequest req = newReq(OnCheckResp, "/api/check");
    req.SetData(encoded);
    req.POST();
    delete req;
}

void OnCheckResp(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response,
                 HTTPRequestMethod method) {
    if (success) {
        char lastURL[128];
        response.GetLastURL(lastURL, sizeof(lastURL));
        int statusCode = response.StatusCode;
        char[] content = new char[response.ContentLength + 1];
        response.GetContent(content, response.ContentLength + 1);
        if (statusCode != HTTP_STATUS_OK) {
            // Fail open if the server is broken
            return;
        }
        
        JSON_Object resp = json_decode(content);
        JSON_Object data = resp.GetObject("result");
        int client_id = data.GetInt("client_id");
        int ban_type = data.GetInt("ban_type");
        int permission_level = data.GetInt("permission_level");
        char msg[256]; // welcome or ban message
        data.GetString("msg", msg, sizeof(msg));
        if(IsFakeClient(client_id)) {
            return;
        }
        char ip[16];
        GetClientIP(client_id, ip, sizeof(ip));
        g_players[client_id].authed = true;
        g_players[client_id].ip = ip;
        g_players[client_id].ban_type = ban_type;
        g_players[client_id].message = msg;
        g_players[client_id].permission_level = permission_level;

        PrintToServer("[GB] Client authenticated (banType: %d level: %d)", ban_type, permission_level);      
        json_cleanup_and_delete(resp);  
    } else {
        PrintToServer("[GB] Error on authentication request: %s", error);
    }
}
