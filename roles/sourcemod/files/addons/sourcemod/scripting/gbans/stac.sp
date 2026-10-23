#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "gbans"
#include "sourcetvmanager"

/**
 * Native implementation of GB_BanClientAC.
 *
 * Bans a client flagged by in-game anticheat (e.g. StAC). The ban is
 * permanent and recorded with a custom reason so the detection text is
 * preserved on the gbans server.
 */
any Native_GB_BanClientAC(Handle plugin, int numParams) {
    int targetId = GetNativeCell(1);
    if (!isValidClient(targetId)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid targetId (%d)", targetId);
    }

    char reason[256];
    if (GetNativeString(2, reason, sizeof reason) != SP_ERROR_NONE) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Invalid reason");
    }

    TrimString(reason);
    if (strlen(reason) < 10) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Reason must be at least 10 characters");
    }

    if (!banAC(targetId, reason)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Failed to ban client (%d)", targetId);
    }

    return true;
}

/**
 * banAC sends a permanent custom-reason ban for a client flagged by
 * anticheat to the gbans server. The reason text is stored as both the
 * ban note and the custom reason text.
 */
stock bool banAC(int targetId, const char[] reason) {
    char targetSid[32];
    if (!GetClientAuthId(targetId, AuthId_SteamID64, targetSid, sizeof targetSid)) {
        LogMessage("Failed to get SteamID64 for client %d", targetId);
        return false;
    }

    char banTypeStr[32];
    char reasonStr[64];
    if (!BanTypeToApiString(BSBanned, banTypeStr, sizeof banTypeStr)
        || !BanReasonToApiString(custom, reasonStr, sizeof reasonStr)) {
        LogMessage("Failed to build anticheat ban request for client %d", targetId);
        return false;
    }

    char validUntil[32];
    FormatValidUntil(0, validUntil, sizeof validUntil);

    JSONObject obj = new JSONObject();
    obj.SetString("targetId", targetSid);
    obj.SetString("note", reason);
    obj.SetString("reason", reasonStr);
    obj.SetString("reasonText", reason);
    obj.SetString("banType", banTypeStr);
    obj.SetString("origin", "ORIGIN_IN_GAME");
    obj.SetString("validUntil", validUntil);

    if (SourceTV_IsRecording()) {
        int tick = SourceTV_GetRecordingTick();
        if (tick >= 0) {
            obj.SetInt("demoTick", tick);
        }
    }

    postHTTPRequest("/connect/ban.v1.BanService/Create", obj, onBanRespReceived, 0);

    return true;
}
