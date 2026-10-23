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

    JSONObject req = new JSONObject();
    req.SetString("password", passwd);

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMAuthenticate", req, onAuthenticate);
}

bool g_has_authed = false;

void onAuthenticate(HTTPResponse response, any value) {
    switch (response.Status) {
    case HTTPStatus_OK: {
        JSONObject data = view_as<JSONObject>(response.Data);
        if (!data.GetString("token", gToken, sizeof gToken)) {
            LogError("No token found");
            return;
        }
        LogMessage("Authenticated server successfully");
        if (!g_has_authed) {
            onAuthSuccess();
        }
    }
    default: {
        PrintRPCError(response);
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

    JSONObject obj = new JSONObject();
    obj.SetString("steamId", clientAuth);
    obj.SetInt("clientId", clientId);
    obj.SetString("ip", ip);
    obj.SetString("name", name);

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMCheck", obj, onCheckResp);
}

void onCheckResp(HTTPResponse response, any value) {
    if (response.Status != HTTPStatus_OK) {
        PrintRPCError(response);
        return;
    }

    JSONObject data = view_as<JSONObject>(response.Data);
    if (!data.HasKey("clientId")) {
        LogError("No client id in check resp");
        return;
    }
    int clientId = data.GetInt("clientId");

    char banType[48];
    if (!data.GetString("banType", banType, sizeof banType)) {
        LogError("Could not parse banType");
        return;
    }

    char msg[256];
    if (!data.GetString("msg", msg, sizeof msg)) {
        LogError("Could not parse message");
        return;
    }
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
