#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "common.sp"

public
Action onAdminCmdReload(int clientId, int argc) {
    reloadAdmins(true);

    return Plugin_Handled;
}

public
void reloadAdmins(bool force) { ServerCommand("sm_reloadadmins"); }

public
void OnClientPostAdminCheck(int clientId) {
    if (!(clientId > 0 && IsClientInGame(clientId) && !IsFakeClient(clientId))) {
        return;
    }

    checkPlayer(clientId);
}

public
void authenticateServer() {
    char passwd[40];
    gb_core_server_key.GetString(passwd, sizeof passwd);

    JSON_Object req = new JSON_Object();
    req.SetString("password", passwd);

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMAuthenticate", req, onAuthenticate);
}

bool g_has_authed = false;

void onAuthenticate(Handle request, bool failure, bool successful, EHTTPStatusCode status, any value1, any value2) {
    switch (status) {
    case k_EHTTPStatusCode200OK: {
        JSON_Object data = GetResponseJSON(request);
        if (data == null || !data.GetString("token", gToken, sizeof gToken)) {
            LogError("No token found");
            json_cleanup_and_delete(data);
            delete request;

            return;
        }

        json_cleanup_and_delete(data);
        delete request;

        LogMessage("Authenticated server successfully");
        if (!g_has_authed) {
            onAuthSuccess();
        }
    }
    default: {
        PrintRPCError(request, failure, status);
        delete request;
    }
    }
}

void onAuthSuccess() {
    g_has_authed = true;
    reloadAdmins(true);
    checkCrashStatus();
}

void checkPlayer(int clientId) {
    if (!(clientId > 0 && IsClientInGame(clientId) && !IsFakeClient(clientId))) {
        return;
    }

    char ip[16];
    GetClientIP(clientId, ip, sizeof ip);

    char name[32];
    GetClientName(clientId, name, sizeof name);

    char clientAuth[64];
    GetClientAuthId(clientId, AuthId_SteamID64, clientAuth, sizeof clientAuth);

    JSON_Object obj = new JSON_Object();
    obj.SetString("steamId", clientAuth);
    obj.SetInt("clientId", clientId);
    obj.SetString("ip", ip);
    obj.SetString("name", name);

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMCheck", obj, onCheckResp);
}

void onCheckResp(Handle request, bool failure, bool successful, EHTTPStatusCode status, any value1, any value2) {
    if (status != k_EHTTPStatusCode200OK) {
        PrintRPCError(request, failure, status);
        delete request;

        return;
    }

    JSON_Object data = GetResponseJSON(request);
    if (data == null || !data.HasKey("clientId")) {
        LogError("No client id in check resp");
        json_cleanup_and_delete(data);
        delete request;

        return;
    }

    int clientId = data.GetInt("clientId");

    char banType[48];
    if (!data.GetString("banType", banType, sizeof banType)) {
        LogError("Could not parse banType");
        json_cleanup_and_delete(data);
        delete request;

        return;
    }

    char msg[256];
    if (!data.GetString("msg", msg, sizeof msg)) {
        LogError("Could not parse message");
        json_cleanup_and_delete(data);
        delete request;

        return;
    }

    json_cleanup_and_delete(data);
    delete request;

    if (StrEqual(banType, "BAN_TYPE_NO_COMM")) {
        if (!BaseComm_IsClientMuted(clientId)) {
            BaseComm_SetClientMute(clientId, true);
        }
        if (!BaseComm_IsClientGagged(clientId)) {
            BaseComm_SetClientGag(clientId, true);
        }
        ReplyToCommand(clientId, "You are currently muted/gag, it will expire automatically");
        LogMessage("Muted \"%L\" for an unfinished mute punishment.", clientId);

        return;
    } else if (StrEqual(banType, "BAN_TYPE_BANNED")) {
        KickClient(clientId, msg);
        LogAction(0, clientId, "Kicked \"%L\" for an unfinished ban.", clientId);

        return;
    } else if (StrEqual(banType, "BAN_TYPE_NETWORK")) {
        KickClient(clientId, msg);
        LogAction(0, clientId, "Kicked \"%L\" for a network block.", clientId);

        return;
    }
}
