#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "gbans"
#include "globals.sp"

const TOKEN_LEN = 1024;

/**
Print out a formatted ConnectRPC error messages to the error log.

https://connectrpc.com/docs/web/errors/
*/
void PrintRPCError(HTTPResponse response) {
    LogError("Invalid response code: %d", response.Status);

    if (response.Status == HTTPStatus_Invalid) {
        return;
    }

    char contentType[128] = "unknown";
    response.GetHeader("Content-Type", contentType, sizeof contentType);
    if (StrContains(contentType, "json", false) == -1) {
        LogError("Invalid response content type: %s", contentType);

        return;
    }

    if (response.Data == null) {
        return;
    }

    char code[64];
    char message[1024];

    JSONObject err_obj = view_as<JSONObject>(response.Data);
    if (!err_obj.GetString("code", code, sizeof code)) {
        return;
    }
    if (!err_obj.GetString("message", message, sizeof message)) {
        return;
    }

    LogError("ConnectRPC Error code=%s message=%s", code, message);
}

/**
 * Extracts the message from a ConnectRPC JSON error response.
 *
 * Returns false when the response is not a JSON encoded ConnectRPC error.
 */
stock bool GetRPCErrorMessage(HTTPResponse response, char[] message, int maxLen) {
    if (response.Status == HTTPStatus_Invalid) {
        return false;
    }

    char contentType[128] = "unknown";
    response.GetHeader("Content-Type", contentType, sizeof contentType);
    if (StrContains(contentType, "json", false) == -1 || response.Data == null) {
        return false;
    }

    JSONObject err_obj = view_as<JSONObject>(response.Data);

    return err_obj.GetString("message", message, maxLen);
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

void postHTTPRequest(const char[] path, JSON data, HTTPRequestCallback callback, any value = 0) {
    char url[1024];
    makeURL(path, url, sizeof url);

    HTTPRequest request = new HTTPRequest(url);
    request.SetHeader("Content-Type", "application/json");
    if (gToken[0] != '\0') {
        char authHeader[1024] = "Bearer ";
        StrCat(authHeader, sizeof authHeader, gToken);
        request.SetHeader("Authorization", authHeader);
    }

    request.Post(data, callback, value);

    CloseHandle(data);
}

stock void makeURL(const char[] path, char[] outURL, int maxLen) {
    char serverHost[PLATFORM_MAX_PATH];
    GetConVarString(gb_core_host, serverHost, sizeof serverHost);
    int port = GetConVarInt(gb_core_port);

    Format(outURL, maxLen, "%s:%d%s", serverHost, port, path);
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
