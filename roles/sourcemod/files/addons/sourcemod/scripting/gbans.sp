#pragma semicolon 1
#pragma tabsize 4

#include <basecomm>
#include <json> // sm-json
#include <sdktools>
#include <sourcemod>
#include <system2> // system2 extension

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
    ReadConfig();
    AuthenticateServer();
    RegConsoleCmd("gb_version", CmdVersion, "Get gbans version");
    RegConsoleCmd("gb_mod", CmdMod, "Ping a moderator");
    RegConsoleCmd("mod", CmdMod, "Ping a moderator");
    RegAdminCmd("gb_ban", AdminCmdBan, ADMFLAG_BAN);
    RegAdminCmd("gb_banip", AdminCmdBanIP, ADMFLAG_BAN);
    RegAdminCmd("gb_mute", AdminCmdMute, ADMFLAG_KICK);
    RegAdminCmd("gb_kick", AdminCmdKick, ADMFLAG_KICK);
    RegAdminCmd("gb_reauth", AdminCmdReauth, ADMFLAG_KICK);
    RegConsoleCmd("gb_help", CmdHelp, "Get a list of gbans commands");
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

void CheckPlayer(int client, const char[] auth, const char[] ip) {
    char encoded[1024];
    JSON_Object obj = new JSON_Object();
    obj.SetString("steam_id", auth);
    obj.SetInt("client_id", client);
    obj.SetString("ip", ip);
    obj.Encode(encoded, sizeof(encoded));
    obj.Cleanup();
    System2HTTPRequest req = newReq(OnCheckResp, "/api/check");
    req.SetData(encoded);
    req.POST();
    delete obj;
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
        JSON_Object data = resp.GetObject("data");
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
        resp.Cleanup();
        delete resp;
    } else {
        PrintToServer("[GB] Error on authentication request: %s", error);
    }
}

public
void OnClientPostAdminCheck(int client_id) {
    PrintToServer("[GB] OnClientPostAdminCheck");
    if (g_players[client_id].ban_type == BSNoComm) {
        if (!BaseComm_IsClientMuted(client_id)) {
            BaseComm_SetClientMute(client_id, true);
        }
        if (!BaseComm_IsClientGagged(client_id)) {
            BaseComm_SetClientGag(client_id, true);
        }
        LogAction(0, client_id, "Muted \"%L\" for an unfinished mute punishment.", client_id);
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
    obj.Cleanup();
    delete obj;
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
        JSON_Object data = resp.GetObject("data");
        char token[41];
        data.GetString("token", token, sizeof(token));
        if (strlen(token) != 40) {
            PrintToServer("[GB] Invalid response status, invalid token");
            return;
        }
        g_token = token;
        PrintToServer("[GB] Successfully authenticated with gbans server");

        resp.Cleanup();
        delete resp;
    } else {
        PrintToServer("[GB] Error on authentication request: %s", error);
    }
}

public
Action AdminCmdBan(int client, int argc) {
    int time = 0;
    char command[64];
    char target[50];
    char timeStr[50];
    char reason[256];
    char auth_id[50];
    char usage[] = "Usage: %s <steamid> <time> [reason]";
    GetCmdArg(0, command, sizeof(command));
    if (argc < 3) {
        ReplyToCommand(client, usage, command);
        return Plugin_Handled;
    }
    GetCmdArg(1, target, sizeof(target));
    GetCmdArg(2, timeStr, sizeof(timeStr));
    for (int i = 3; i <= argc; i++) {
        if (i > 3) {
            StrCat(reason, sizeof(reason), " ");
        }
        char buff[128];
        GetCmdArg(i, buff, sizeof(buff));
        StrCat(reason, sizeof(reason), buff);
    }
    time = StringToInt(timeStr, 10);
    PrintToServer("Target: %s", target);
    int user_id = FindTarget(client, target, true, true);
    if (user_id < 0) {
        ReplyToCommand(client, "Failed to locate user: %s", target);
        return Plugin_Handled;
    }
    if (!GetClientAuthId(user_id, AuthId_Steam3, auth_id, sizeof(auth_id), true)) {
        ReplyToCommand(client, "Failed to get auth_id of user: %s", target);
        return Plugin_Handled;
    }
    PrintToServer(auth_id);
    if (time > 0) {
        PrintToServer("Non permanent");
    }
    return Plugin_Handled;
}

public
Action AdminCmdBanIP(int client, int argc) {
    PrintToServer("banip");
    return Plugin_Handled;
}

public
Action AdminCmdMute(int client_id, int argc) {
    if (IsClientInGame(client_id)) {
        if (!BaseComm_IsClientMuted(client_id)) {
            BaseComm_SetClientMute(client_id, true);
        }
        if (!BaseComm_IsClientGagged(client_id)) {
            BaseComm_SetClientGag(client_id, true);
        }
    }
    return Plugin_Handled;
}

public
Action AdminCmdReauth(int client, int argc) {
    AuthenticateServer();
    return Plugin_Handled;
}

public
Action AdminCmdKick(int client, int argc) {
    if (IsClientInGame(client)) {
        KickClient(client);
    }
    return Plugin_Handled;
}

public
Action CmdVersion(int client, int args) {
    ReplyToCommand(client, "[GB] Version %s", PLUGIN_VERSION);
    return Plugin_Handled;
}

/**
Ping the moderators through discord
*/
public
Action CmdMod(int client, int argc) {
    if (argc < 1) {
        ReplyToCommand(client, "Must supply a reason message for pinging");
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
    if (!GetClientAuthId(client, AuthId_Steam3, auth_id, sizeof(auth_id), true)) {
        ReplyToCommand(client, "Failed to get auth_id of user: %d", client);
        return Plugin_Continue;
    }
    char name[64];
    if (!GetClientName(client, name, sizeof(name))) {
        PrintToServer("Failed to get user name?");
        return Plugin_Continue;
    }
    JSON_Object obj = new JSON_Object();
    obj.SetString("server_name", g_server_name);
    obj.SetString("steam_id", auth_id);
    obj.SetString("name", name);
    obj.SetString("reason", reason);
    obj.SetInt("client", client);
    char encoded[1024];
    obj.Encode(encoded, sizeof(encoded));
    obj.Cleanup();
    delete obj;
    System2HTTPRequest req = newReq(OnPingModRespRecieved, "/api/ping_mod");
    req.SetData(encoded);
    req.POST();
    delete req;

    ReplyToCommand(client, "Mods have been alerted, thanks!");

    return Plugin_Handled;
}

void OnPingModRespRecieved(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response,
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
    resp.Cleanup();
    delete resp;
}

public
Action CmdHelp(int client, int argc) {
    CmdVersion(client, argc);
    ReplyToCommand(client, "gb_ban #user duration [reason]");
    ReplyToCommand(client, "gb_ban_ip #user duration [reason]");
    ReplyToCommand(client, "gb_kick #user [reason]");
    ReplyToCommand(client, "gb_mute #user duration [reason]");
    ReplyToCommand(client, "gb_mod reason");
    ReplyToCommand(client, "gb_version -- Show the current version");
    return Plugin_Handled;
}

public
bool OnClientConnect(int client, char[] rejectmsg, int maxlen) {
    g_players[client].authed = false;
    g_players[client].ban_type = BSUnknown;
    return true;
}

public
void OnClientAuthorized(int client, const char[] auth) {
    char ip[16];
    GetClientIP(client, ip, sizeof(ip));
    /* Do not check bots nor check player with lan steamid. */
    if (auth[0] == 'B' /*|| auth[9] == 'L'*/) {
        g_players[client].authed = true;
        g_players[client].ip = ip;
        g_players[client].ban_type = BSUnknown;
        return;
    }
#if defined DEBUG
    PrintToServer("[GB] Checking ban state for: %s", auth);
#endif
    CheckPlayer(client, auth, ip);
}
