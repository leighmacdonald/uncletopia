#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <basecomm>
#include <json> // sm-json
#include <sdktools>
#include <sourcemod>
#include <system2> // system2 extension
#include <gbans>

#define DEBUG

#define PLUGIN_AUTHOR "Leigh MacDonald"
#define PLUGIN_VERSION "0.00"
#define PLUGIN_NAME "gbans"

// Ban states returned from server
#define BSUnknown -1 // Fail-open unknown status
#define BSOK 0       // OK
#define BSNoComm 1   // Muted
#define BSBanned 2   // Banned

// Authentication token len
#define TOKEN_LEN 40

#define HTTP_STATUS_OK 200

// clang-format off
enum struct PlayerInfo {
    bool authed;
    char ip[16];
    int ban_type;
}
// clang-format on

// Globals must all start with g_
char g_token[TOKEN_LEN + 1]; // tokens are 40 chars + term

PlayerInfo g_players[MAXPLAYERS + 1];

int g_port;
char g_host[128];
char g_server_name[128];
char g_server_key[41];

public
Plugin myinfo = {name = PLUGIN_NAME, author = PLUGIN_AUTHOR, description = "gbans game client",
                 version = PLUGIN_VERSION, url = "https://github.com/leighmacdonald/gbans"};

public
void OnPluginStart() {
    LoadTranslations("common.phrases.txt");

    RegConsoleCmd("gb_version", CmdVersion, "Get gbans version");
    RegConsoleCmd("gb_mod", CmdMod, "Ping a moderator");
    RegConsoleCmd("mod", CmdMod, "Ping a moderator");
    RegAdminCmd("gb_ban", AdminCmdBan, ADMFLAG_BAN);
    RegAdminCmd("gb_banip", AdminCmdBanIP, ADMFLAG_BAN);
    RegAdminCmd("gb_mute", AdminCmdMute, ADMFLAG_KICK);
    RegAdminCmd("gb_kick", AdminCmdKick, ADMFLAG_KICK);
    RegAdminCmd("gb_reauth", AdminCmdReauth, ADMFLAG_KICK);
    RegConsoleCmd("gb_help", CmdHelp, "Get a list of gbans commands");

    ReadConfig();
    AuthenticateServer();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GB_BanClient", Native_GB_BanClient);
	return APLRes_Success;
}

void ReadConfig() {
    char localPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, localPath, sizeof(localPath), "configs/%s", "gbans.cfg");
#if defined DEBUG
    PrintToServer("[GB] Using config file: %s", localPath);
#endif
    KeyValues kv = new KeyValues("gbans");
    if (!kv.ImportFromFile(localPath)) {
        PrintToServer("[GB] No config file could be found");
    } else {
        kv.GetString("host", g_host, sizeof(g_host), "http://localhost");
        g_port = kv.GetNum("port", 6006);
        kv.GetString("server_name", g_server_name, sizeof(g_server_name), "default");
        kv.GetString("server_key", g_server_key, sizeof(g_server_key), "");
    }
    delete kv;
}

System2HTTPRequest newReq(System2HTTPResponseCallback cb, const char[] path) {
    char fullAddr[1024];
    Format(fullAddr, sizeof(fullAddr), "%s%s", g_host, path);
    System2HTTPRequest httpRequest = new System2HTTPRequest(cb, fullAddr);
    httpRequest.SetPort(g_port);
    httpRequest.SetHeader("Content-Type", "application/json");
    if (strlen(g_token) == TOKEN_LEN) {
        httpRequest.SetHeader("Authorization", g_token);
    }
    return httpRequest;
}

void CheckPlayer(int clientId, const char[] auth, const char[] ip, const char[] name) {
    if (!IsClientConnected(clientId) || IsFakeClient(clientId)) {
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
        float totalTime = response.TotalTime;
#if defined DEBUG
        PrintToServer("[GB] Request to %s finished with status code %d in %.2f seconds", lastURL, statusCode,
                      totalTime);
#endif
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
        char msg[256];
        data.GetString("msg", msg, sizeof(msg));
        PrintToServer("[GB] Ban state: %d", ban_type);
        switch (ban_type) {
            case BSBanned: {
                KickClient(client_id, msg);
                return;
            }
        }
        if(IsClientInGame(client_id) && !IsFakeClient(client_id)) {
            char ip[16];
            GetClientIP(client_id, ip, sizeof(ip));
            g_players[client_id].authed = true;
            g_players[client_id].ip = ip;
            g_players[client_id].ban_type = ban_type;
            PrintToServer("[GB] Successfully authenticated with gbans server");
            if (g_players[client_id].ban_type == BSNoComm) {
                if (IsClientInGame(client_id)) {
                    OnClientPostAdminCheck(client_id);
                }
            }
        }
        json_cleanup_and_delete(resp);
    } else {
        PrintToServer("[GB] Error on authentication request: %s", error);
    }
}

public
void OnClientPostAdminCheck(int clientId) {
    PrintToServer("[GB] OnClientPostAdminCheck");
    if (g_players[clientId].ban_type == BSNoComm) {
        if (!BaseComm_IsClientMuted(clientId)) {
            BaseComm_SetClientMute(clientId, true);
        }
        if (!BaseComm_IsClientGagged(clientId)) {
            BaseComm_SetClientGag(clientId, true);
        }
        LogAction(0, clientId, "Muted \"%L\" for an unfinished mute punishment.", clientId);
    }
}

/**
Authenicates the server with the backend API system.

Send unauthenticated request for token to -> API /api/server_auth
Recv Token <- API
Send authenticated commands with header "Authorization $token" set for subsequent calls -> API /api/<path>

*/
void AuthenticateServer() {
    JSON_Object obj = new JSON_Object();
    obj.SetString("server_name", g_server_name);
    obj.SetString("key", g_server_key);
    char encoded[1024];
    obj.Encode(encoded, sizeof(encoded));
    json_cleanup_and_delete(obj);

    System2HTTPRequest req = newReq(OnAuthReqReceived, "/api/server_auth");
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
        float totalTime = response.TotalTime;
#if defined DEBUG
        PrintToServer("[GB] Request to %s finished with status code %d in %.2f seconds", lastURL, statusCode,
                      totalTime);
#endif
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
        char token[41];
        data.GetString("token", token, sizeof(token));
        if (strlen(token) != 40) {
            PrintToServer("[GB] Invalid response status, invalid token");
            return;
        }
        g_token = token;
        PrintToServer("[GB] Successfully authenticated with gbans server");
        json_cleanup_and_delete(resp);
    } else {
        PrintToServer("[GB] Error on authentication request: %s", error);
    }
}

public
Action AdminCmdBanIP(int client, int argc) {
    PrintToServer("banip");
    return Plugin_Handled;
}

public
Action AdminCmdMute(int clientId, int argc) {
    if (IsClientInGame(clientId) && !IsFakeClient(clientId)) {
        if (!BaseComm_IsClientMuted(clientId)) {
            BaseComm_SetClientMute(clientId, true);
        }
        if (!BaseComm_IsClientGagged(clientId)) {
            BaseComm_SetClientGag(clientId, true);
        }
    }
    return Plugin_Handled;
}

public
Action AdminCmdReauth(int clientId, int argc) {
    AuthenticateServer();
    return Plugin_Handled;
}

public
Action AdminCmdKick(int clientId, int argc) {
    if (IsClientInGame(clientId) && !IsFakeClient(clientId)) {
        KickClient(clientId);
    }
    return Plugin_Handled;
}

public
Action CmdVersion(int clientId, int args) {
    ReplyToCommand(clientId, "[GB] Version %s", PLUGIN_VERSION);
    return Plugin_Handled;
}

/**
Ping the moderators through discord
*/
public
Action CmdMod(int clientId, int argc) {
    if (argc < 1) {
        ReplyToCommand(clientId, "Must supply a reason message for pinging");
        return Plugin_Handled;
    }
    char reason[256];
    for (int i = 1; i <= argc; i++) {
        if (i > 1) {
            StrCat(reason, sizeof(reason), " ");
        }
        char buff[128];
        GetCmdArg(i, buff, sizeof(buff));
        StrCat(reason, sizeof(reason), buff);
    }
    char auth_id[50];
    if (!GetClientAuthId(clientId, AuthId_Steam3, auth_id, sizeof(auth_id), true)) {
        ReplyToCommand(clientId, "Failed to get auth_id of user: %d", clientId);
        return Plugin_Continue;
    }
    char name[64];
    if (!GetClientName(clientId, name, sizeof(name))) {
        PrintToServer("Failed to get user name?");
        return Plugin_Continue;
    }
    JSON_Object obj = new JSON_Object();
    obj.SetString("server_name", g_server_name);
    obj.SetString("steam_id", auth_id);
    obj.SetString("name", name);
    obj.SetString("reason", reason);
    obj.SetInt("client", clientId);
    char encoded[1024];
    obj.Encode(encoded, sizeof(encoded));
    json_cleanup_and_delete(obj);
    System2HTTPRequest req = newReq(OnPingModRespReceived, "/api/ping_mod");
    req.SetData(encoded);
    req.POST();
    delete req;

    ReplyToCommand(clientId, "Mods have been alerted, thanks!");

    return Plugin_Handled;
}

void OnPingModRespReceived(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response,
                           HTTPRequestMethod method) {
    if (!success) {
        return;
    }
    if (response.StatusCode != HTTP_STATUS_OK) {
        PrintToServer("[GB] Bad status on authentication request: %s", error);
        return;
    }
    char[] content = new char[response.ContentLength + 1];
    char message[250];
    int client;
    response.GetContent(content, response.ContentLength + 1);
    JSON_Object resp = json_decode(content);
    resp.GetString("message", message, sizeof(message));
    resp.GetInt("client");
    ReplyToCommand(client, message);
    json_cleanup_and_delete(resp);
}

public
Action CmdHelp(int clientId, int argc) {
    CmdVersion(clientId, argc);
    ReplyToCommand(clientId, "gb_ban #user duration [reason]");
    ReplyToCommand(clientId, "gb_ban_ip #user duration [reason]");
    ReplyToCommand(clientId, "gb_kick #user [reason]");
    ReplyToCommand(clientId, "gb_mute #user duration [reason]");
    ReplyToCommand(clientId, "gb_mod reason");
    ReplyToCommand(clientId, "gb_version -- Show the current version");
    return Plugin_Handled;
}

public
bool OnClientConnect(int clientId, char[] rejectMsg, int maxLen) {
    g_players[clientId].authed = false;
    g_players[clientId].ban_type = BSUnknown;
    return true;
}

public
void OnClientAuthorized(int clientId, const char[] auth) {
    char ip[16];
    GetClientIP(clientId, ip, sizeof(ip));

    char name[32];
    GetClientName(clientId, name, sizeof(name));

    /* Do not check bots nor check player with lan steamid. */
    if (auth[0] == 'B' /*|| auth[9] == 'L'*/) {
        g_players[clientId].authed = true;
        g_players[clientId].ip = ip;
        g_players[clientId].ban_type = BSUnknown;
        return;
    }
#if defined DEBUG
    PrintToServer("[GB] Checking ban state for: %s", auth);
#endif
    CheckPlayer(clientId, auth, ip, name);
}

any Native_GB_BanClient(Handle plugin, int numParams) {
    int adminId = GetNativeCell(1);
    if (adminId <= 0) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid adminId index (%d)", adminId);
    }
    int targetId = GetNativeCell(2);
    if (targetId <= 0) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid targetId index (%d)", targetId);
    }
    int reason = GetNativeCell(3);
    if (reason <= 0) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid reason index (%d)", reason);
    }
    int duration = GetNativeCell(4);
    if (duration < 0) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid duration, but must be positive integer or 0 for permanent");
    }
    banReason reasonValue = view_as<banReason>(reason);
    if (!ban(adminId, targetId, reasonValue, duration)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Ban error ");
    }
    return true;
}

public
bool ban(int adminId, int targetId, banReason reason, int duration) {
    return true;
}

public
bool parseReason(const char[] reasonStr, banReason &reason) {
    int reasonInt = StringToInt(reasonStr, 10);
    if (reasonInt <= 0 || reasonInt < view_as<int>(custom) || reasonInt > view_as<int>(itemDescriptions)) {
        return false;
    }
    reason = view_as<banReason>(reasonInt);
    return true;
}

public
Action AdminCmdBan(int clientId, int argc) {
    int time = 0;
    char command[64];
    char target[50];
    char timeStr[50];
    char reasonStr[256];
    char auth_id[50];
    char usage[] = "Usage: %s <targetId> <reason> <duration>";

    GetCmdArg(0, command, sizeof(command));

    if (argc < 3) {
        ReplyToCommand(clientId, usage, command);
        return Plugin_Handled;
    }
    
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, reasonStr, sizeof(reasonStr));
    GetCmdArg(3, timeStr, sizeof(timeStr));

    time = StringToInt(timeStr, 10);
    PrintToServer("Target: %s", target);
    int targetId = FindTarget(clientId, target, true, true);
    if (targetId < 0) {
        ReplyToCommand(clientId, "Failed to locate user: %s", target);
        return Plugin_Handled;
    }
    if (!GetClientAuthId(targetId, AuthId_Steam3, auth_id, sizeof(auth_id), true)) {
        ReplyToCommand(clientId, "Failed to get auth_id of user: %s", target);
        return Plugin_Handled;
    }
    if (time > 0) {
        PrintToServer("Non permanent");
    }
    banReason reason = custom;
    if (!parseReason(reasonStr, reason)) {
        return Plugin_Handled;
    }
    if (!ban(clientId, targetId, reason, time)) {
        PrintToServer("ban error");
    }

    return Plugin_Handled;
}
