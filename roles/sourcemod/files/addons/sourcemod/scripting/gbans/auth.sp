#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "common.sp"

// Set once the current token has been used to trigger the post-auth setup.
bool g_has_authed = false;

// Admin data only changes on the website, not on map boundaries, so the map
// start refresh is throttled to avoid three HTTP requests and a full cache
// rebuild on every single map load.
const adminReloadInterval = 900;
int gLastAdminReloadAt    = 0;

public
Action onAdminCmdReload(int clientId, int argc) {
    // Drop the cached token so a rotated gb_core_server_key takes effect, and
    // force the admin cache rebuild that runs after a successful auth.
    gToken[0]    = '\0';
    g_has_authed = false;

    if (!authenticateServer()) {
        reply(clientId, "[GB] Failed to send the authentication request to gbans");

        return Plugin_Handled;
    }

    reply(clientId, "[GB] Re-authenticating with gbans");

    return Plugin_Handled;
}

public
void reloadAdmins(bool force) {
    int now = GetTime();
    if (!force && gLastAdminReloadAt > 0 && now - gLastAdminReloadAt < adminReloadInterval) {
        return;
    }

    gLastAdminReloadAt = now;
    ServerCommand("sm_reloadadmins");
}

public
void OnClientPostAdminCheck(int clientId) {
    if (!(clientId > 0 && IsClientInGame(clientId) && !IsFakeClient(clientId))) {
        return;
    }

    checkPlayer(clientId);
}

public
bool authenticateServer() {
    char passwd[40];
    gb_core_server_key.GetString(passwd, sizeof passwd);

    JSON_Object req = new JSON_Object();
    req.SetString("password", passwd);

    return postHTTPRequest("/connect/sourcemod.v1.PluginService/SMAuthenticate", req, onAuthenticate);
}

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

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMCheck", obj, onCheckResp, GetClientUserId(clientId));
}

void onCheckResp(Handle request, bool failure, bool successful, EHTTPStatusCode status, any userId, any value2) {
    if (status != k_EHTTPStatusCode200OK) {
        PrintRPCError(request, failure, status);
        delete request;

        return;
    }

    // The response echoes the client index that was sent with the request, but
    // that slot may have been reused by another player while the request was
    // in flight. Resolving the user id is the only reliable way back to the
    // client that was checked.
    int clientId = GetClientOfUserId(view_as<int>(userId));
    if (!isValidClient(clientId)) {
        delete request;

        return;
    }

    JSON_Object data = GetResponseJSON(request);
    if (data == null) {
        LogError("Failed to parse check response");
        delete request;

        return;
    }

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
        KickClient(clientId, "%s", msg);
        LogAction(0, clientId, "Kicked \"%L\" for an unfinished ban.", clientId);

        return;
    } else if (StrEqual(banType, "BAN_TYPE_NETWORK")) {
        KickClient(clientId, "%s", msg);
        LogAction(0, clientId, "Kicked \"%L\" for a network block.", clientId);

        return;
    }
}
