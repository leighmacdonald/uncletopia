#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "gbans"
#include "globals.sp"

const TOKEN_LEN = 1024;

/**
 * Reads and decodes the JSON body of a completed SteamWorks HTTP request.
 *
 * Returns null when the response has no body or the body is not valid JSON.
 * The caller owns the returned object and must free it with
 * json_cleanup_and_delete().
 */
stock JSON_Object GetResponseJSON(Handle request) {
    int size = 0;
    if (!SteamWorks_GetHTTPResponseBodySize(request, size) || size <= 0) {
        return null;
    }

    char[] body = new char[size + 1];
    if (!SteamWorks_GetHTTPResponseBodyData(request, body, size)) {
        return null;
    }
    body[size] = '\0';

    return json_decode(body);
}

stock bool ResponseHasJSONContent(Handle request) {
    char contentType[128];
    if (!SteamWorks_GetHTTPResponseHeaderValue(request, "Content-Type", contentType, sizeof contentType)) {
        return false;
    }

    return StrContains(contentType, "json", false) != -1;
}

/**
Print out a formatted ConnectRPC error messages to the error log.

https://connectrpc.com/docs/web/errors/
*/
void PrintRPCError(Handle request, bool failure, EHTTPStatusCode status) {
    if (failure) {
        LogError("HTTP request failed, no response received");

        return;
    }

    LogError("Invalid response code: %d", status);

    if (status == k_EHTTPStatusCodeInvalid) {
        return;
    }

    char contentType[128] = "unknown";
    if (!SteamWorks_GetHTTPResponseHeaderValue(request, "Content-Type", contentType, sizeof contentType)
        || StrContains(contentType, "json", false) == -1) {
        LogError("Invalid response content type: %s", contentType);

        return;
    }

    JSON_Object err_obj = GetResponseJSON(request);
    if (err_obj == null) {
        return;
    }

    char code[64];
    char message[1024];
    if (err_obj.GetString("code", code, sizeof code) && err_obj.GetString("message", message, sizeof message)) {
        LogError("ConnectRPC Error code=%s message=%s", code, message);
    }

    json_cleanup_and_delete(err_obj);
}

/**
 * Extracts the message from a ConnectRPC JSON error response.
 *
 * Returns false when the response is not a JSON encoded ConnectRPC error.
 */
stock bool GetRPCErrorMessage(Handle request, EHTTPStatusCode status, char[] message, int maxLen) {
    if (status == k_EHTTPStatusCodeInvalid || !ResponseHasJSONContent(request)) {
        return false;
    }

    JSON_Object err_obj = GetResponseJSON(request);
    if (err_obj == null) {
        return false;
    }

    bool found = err_obj.GetString("message", message, maxLen);
    json_cleanup_and_delete(err_obj);

    return found;
}

public
bool parseReason(const char[] reasonStr, GB_BanReason &reason) {
    int reasonInt = StringToInt(reasonStr, 10);
    if (reasonInt <= 0 || reasonInt < view_as<int>(custom) || reasonInt > view_as<int>(Username)) {
        return false;
    }
    reason = view_as<GB_BanReason>(reasonInt);
    return true;
}

/**
 * Maps a GB_BanReason to its ban.v1.BanReason protobuf enum name used by the
 * ConnectRPC JSON mapping. Returns false for unknown values.
 */
stock bool BanReasonToApiString(GB_BanReason reason, char[] buffer, int maxlen) {
    switch (reason) {
    case custom: {
        strcopy(buffer, maxlen, "BAN_REASON_CUSTOM");
    }
    case external: {
        strcopy(buffer, maxlen, "BAN_REASON_EXTERNAL");
    }
    case cheating: {
        strcopy(buffer, maxlen, "BAN_REASON_CHEATING");
    }
    case racism: {
        strcopy(buffer, maxlen, "BAN_REASON_RACISM");
    }
    case harassment: {
        strcopy(buffer, maxlen, "BAN_REASON_HARASSMENT");
    }
    case exploiting: {
        strcopy(buffer, maxlen, "BAN_REASON_EXPLOITING");
    }
    case warningsExceeded: {
        strcopy(buffer, maxlen, "BAN_REASON_WARNINGS_EXCEEDED");
    }
    case spam: {
        strcopy(buffer, maxlen, "BAN_REASON_SPAM");
    }
    case languageUsed: {
        strcopy(buffer, maxlen, "BAN_REASON_LANGUAGE");
    }
    case profile: {
        strcopy(buffer, maxlen, "BAN_REASON_PROFILE");
    }
    case itemDescriptions: {
        strcopy(buffer, maxlen, "BAN_REASON_ITEM_DESCRIPTIONS");
    }
    case botHost: {
        strcopy(buffer, maxlen, "BAN_REASON_BOT_HOST");
    }
    case Evading: {
        strcopy(buffer, maxlen, "BAN_REASON_EVADING");
    }
    case Username: {
        strcopy(buffer, maxlen, "BAN_REASON_USERNAME");
    }
    default: {
        return false;
    }
    }
    return true;
}

/**
 * Human readable name for a GB_BanReason, used for synthesized messages.
 */
stock bool BanReasonDisplayName(GB_BanReason reason, char[] buffer, int maxlen) {
    switch (reason) {
    case custom: {
        strcopy(buffer, maxlen, "Custom");
    }
    case external: {
        strcopy(buffer, maxlen, "External");
    }
    case cheating: {
        strcopy(buffer, maxlen, "Cheating");
    }
    case racism: {
        strcopy(buffer, maxlen, "Racism");
    }
    case harassment: {
        strcopy(buffer, maxlen, "Harassment");
    }
    case exploiting: {
        strcopy(buffer, maxlen, "Exploiting");
    }
    case warningsExceeded: {
        strcopy(buffer, maxlen, "Warnings Exceeded");
    }
    case spam: {
        strcopy(buffer, maxlen, "Spam");
    }
    case languageUsed: {
        strcopy(buffer, maxlen, "Language");
    }
    case profile: {
        strcopy(buffer, maxlen, "Profile");
    }
    case itemDescriptions: {
        strcopy(buffer, maxlen, "Items/Descriptions");
    }
    case botHost: {
        strcopy(buffer, maxlen, "Bot Host");
    }
    case Evading: {
        strcopy(buffer, maxlen, "Evading");
    }
    case Username: {
        strcopy(buffer, maxlen, "Username");
    }
    default: {
        return false;
    }
    }
    return true;
}

/**
 * Maps a ban type (BSNoComm / BSBanned) to its ban.v1.BanType protobuf enum
 * name used by the ConnectRPC JSON mapping. Returns false for unknown values.
 */
stock bool BanTypeToApiString(int banType, char[] buffer, int maxlen) {
    if (banType == BSNoComm) {
        strcopy(buffer, maxlen, "BAN_TYPE_NO_COMM");
        return true;
    }
    if (banType == BSBanned) {
        strcopy(buffer, maxlen, "BAN_TYPE_BANNED");
        return true;
    }
    return false;
}

/**
 * Formats a ban duration (seconds, 0 = permanent) as the RFC3339 timestamp
 * string expected for the valid_until field of ban.v1.CreateRequest.
 * Permanent bans expire 10 years out so they read as permanent in the web UI.
 */
stock void FormatValidUntil(int durationSeconds, char[] buffer, int maxlen) {
    int now = GetTime();
    int expiry;
    if (durationSeconds <= 0) {
        expiry = now + 315360000;
    } else {
        expiry = now + durationSeconds;
    }
    FormatTime(buffer, maxlen, "%Y-%m-%dT%H:%M:%SZ", expiry);
}

/**
 * Sends a JSON POST request to the gbans backend using the SteamWorks HTTP
 * client. The callback runs from the SteamWorks completion handler and must
 * free the request handle once the response has been read.
 *
 * The request JSON object is owned by this function and freed before it
 * returns.
 */
void postHTTPRequest(const char[] path, JSON_Object data, SteamWorksHTTPRequestCompleted callback, any value = 0) {
    char url[1024];
    makeURL(path, url, sizeof url);

    Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
    if (request == INVALID_HANDLE) {
        LogError("Failed to create HTTP request to %s", url);
        json_cleanup_and_delete(data);

        return;
    }

    if (gToken[0] != '\0') {
        char authHeader[1024] = "Bearer ";
        StrCat(authHeader, sizeof authHeader, gToken);
        SteamWorks_SetHTTPRequestHeaderValue(request, "Authorization", authHeader);
    }

    int bodyLen = data.EncodeSize();
    char[] body = new char[bodyLen];
    data.Encode(body, bodyLen);

    SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", body, strlen(body));
    SteamWorks_SetHTTPRequestContextValue(request, value, 0);
    SteamWorks_SetHTTPCallbacks(request, callback);
    SteamWorks_SetHTTPRequestNetworkActivityTimeout(request, 30);

    if (!SteamWorks_SendHTTPRequest(request)) {
        LogError("Failed to send HTTP request to %s", url);
        delete request;
    }

    json_cleanup_and_delete(data);
}

stock void makeURL(const char[] path, char[] outURL, int maxLen) {
    char serverHost[PLATFORM_MAX_PATH];
    GetConVarString(gb_core_host, serverHost, sizeof serverHost);
    int port = GetConVarInt(gb_core_port);

    if (StrContains(serverHost, "://", false) == -1) {
        Format(outURL, maxLen, "http://%s:%d%s", serverHost, port, path);
    } else {
        Format(outURL, maxLen, "%s:%d%s", serverHost, port, path);
    }
}

stock bool isValidClient(int client) {
    if (!(1 <= client <= MaxClients) || !IsClientInGame(client) || IsFakeClient(client) || IsClientSourceTV(client)
        || IsClientReplay(client)) {
        return false;
    }
    return true;
}

stock int GetRealClientCount() {
    int iClients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !IsFakeClient(i)) {
            iClients++;
        }
    }

    return iClients;
}

stock int GetAllClientCount() {
    int iClients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            iClients++;
        }
    }

    return iClients;
}

stock void reply(int clientId, const char[] message) {
    if (clientId > 0) {
        ReplyToCommand(clientId, message);
    } else {
        LogMessage(message);
    }
}
