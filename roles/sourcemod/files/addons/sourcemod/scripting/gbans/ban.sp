#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "sourcetvmanager"

any Native_GB_BanClient(Handle plugin, int numParams) {
    int adminId = GetNativeCell(1);
    if (adminId < 0) {
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

    GB_BanReason reasonValue = view_as<GB_BanReason>(reason);

    int duration = GetNativeCell(4);
    if (duration < 0) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid duration, but must be positive integer or 0 for permanent");
    }

    int banType = GetNativeCell(5);
    if (banType != BSBanned && banType != BSNoComm) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid banType, but must be 1: mute/gag  or 2: ban");
    }

    char note[256];
    if (GetNativeString(6, note, sizeof note) != SP_ERROR_NONE) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid note");
    }

    if (!ban(adminId, targetId, reasonValue, duration, banType, note)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Ban error ");
    }

    return true;
}
/**
 * ban performs the actual work of sending the ban request to the gbans server
 *
 * NOTE: There is currently no way to set a custom ban reason string
 */
public
bool ban(int sourceId, int targetId, GB_BanReason reason, int duration, int banType, const char[] note) {
    if (strlen(note) < 10) {
        ReplyToCommand(sourceId, "Ban note must be at least 10 characters");
        return false;
    }

    if (duration < 0) {
        ReplyToCommand(sourceId, "Invalid duration, must be a positive integer or 0 for permanent");
        return false;
    }

    char banTypeStr[32];
    if (!BanTypeToApiString(banType, banTypeStr, sizeof banTypeStr)) {
        ReplyToCommand(sourceId, "Invalid banType, must be 1 (mute/gag) or 2 (ban)");
        return false;
    }

    char reasonStr[64];
    if (!BanReasonToApiString(reason, reasonStr, sizeof reasonStr)) {
        ReplyToCommand(sourceId, "Invalid ban reason");
        return false;
    }

    char targetSid[32];
    if (!GetClientAuthId(targetId, AuthId_SteamID64, targetSid, sizeof targetSid)) {
        ReplyToCommand(sourceId, "Failed to get targetId of user: %d", targetId);
        return false;
    }

    char sourceSid[32];
    bool hasSource = false;
    if (sourceId > 0) {
        if (!GetClientAuthId(sourceId, AuthId_SteamID64, sourceSid, sizeof sourceSid)) {
            ReplyToCommand(sourceId, "Failed to get sourceId of user: %d", sourceId);
            return false;
        }
        hasSource = true;
    }

    char validUntil[32];
    FormatValidUntil(duration, validUntil, sizeof validUntil);

    JSONObject obj = new JSONObject();
    if (hasSource) {
        obj.SetString("sourceId", sourceSid);
    }
    obj.SetString("targetId", targetSid);
    obj.SetString("note", note);
    obj.SetString("banType", banTypeStr);
    obj.SetString("reason", reasonStr);
    obj.SetString("origin", "ORIGIN_IN_GAME");
    obj.SetString("validUntil", validUntil);

    if (reason == custom) {
        obj.SetString("reasonText", note);
    }

    if (SourceTV_IsRecording()) {
        int tick = SourceTV_GetRecordingTick();
        if (tick >= 0) {
            obj.SetInt("demoTick", tick);
        }
    }

    postHTTPRequest("/connect/ban.v1.BanService/Create", obj, onBanRespReceived, sourceId);

    return true;
}

void onBanRespReceived(HTTPResponse response, any clientId) {
    if (response.Status != HTTPStatus_OK) {
        if (response.Status == HTTPStatus_Conflict) {
            ReplyToCommand(clientId, "Duplicate ban");
            return;
        }
        PrintRPCError(response);
        ReplyToCommand(clientId, "Unhandled error response");
        return;
    }

    JSONObject data   = view_as<JSONObject>(response.Data);
    JSONObject banObj = view_as<JSONObject>(data.Get("ban"));
    int        banId  = banObj.GetInt("banId");
    ReplyToCommand(clientId, "User banned (#%d)", banId);
}
