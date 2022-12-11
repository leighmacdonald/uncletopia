#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public
Action onCmdVersion(int clientId, int args) {
    ReplyToCommand(clientId, "[GB] Version %s", PLUGIN_VERSION);
    return Plugin_Handled;
}

/**
Ping the moderators through discord
*/
public
Action onCmdMod(int clientId, int argc) {
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
        gbLog("Failed to get user name?");
        return Plugin_Continue;
    }

    char serverName[PLATFORM_MAX_PATH];
    gHost.GetString(serverName, sizeof(serverName));
    JSON_Object obj = new JSON_Object();
    obj.SetString("server_name", serverName);
    obj.SetString("steam_id", auth_id);
    obj.SetString("name", name);
    obj.SetString("reason", reason);
    obj.SetInt("client", clientId);
    char encoded[1024];
    obj.Encode(encoded, sizeof(encoded));
    json_cleanup_and_delete(obj);
    System2HTTPRequest req = newReq(onPingModRespReceived, "/api/ping_mod");
    req.SetData(encoded);
    req.POST();
    delete req;

    ReplyToCommand(clientId, "Mods have been alerted, thanks!");

    return Plugin_Handled;
}

void onPingModRespReceived(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response,
                           HTTPRequestMethod method) {
    if (!success) {
        return;
    }
    if (response.StatusCode != HTTP_STATUS_OK) {
        gbLog("Bad status on mod resp request (%d): %s", response.StatusCode, error);
        return;
    }
}

public
Action onCmdHelp(int clientId, int argc) {
    onCmdVersion(clientId, argc);
    ReplyToCommand(clientId, "gb_ban #user duration [reason]");
    ReplyToCommand(clientId, "gb_ban_ip #user duration [reason]");
    ReplyToCommand(clientId, "gb_kick #user [reason]");
    ReplyToCommand(clientId, "gb_mute #user duration [reason]");
    ReplyToCommand(clientId, "gb_mod reason");
    ReplyToCommand(clientId, "gb_version -- Show the current version");
    return Plugin_Handled;
}

public
Action onAdminCmdReauth(int clientId, int argc) {
    refreshToken();
    return Plugin_Handled;
}

public
Action onAdminCmdBan(int clientId, int argc) {
    char command[64];
    char targetIdStr[50];
    char duration[50];
    char banTypeStr[50];
    char reasonStr[256];
    char usage[] = "Usage: %s <targetId> <banType> <duration> <reason>";

    GetCmdArg(0, command, sizeof(command));

    if (argc < 4) {
        ReplyToCommand(clientId, usage, command);
        return Plugin_Handled;
    }

    GetCmdArg(1, targetIdStr, sizeof(targetIdStr));
    GetCmdArg(2, banTypeStr, sizeof(banTypeStr));
    GetCmdArg(3, duration, sizeof(duration));
    GetCmdArg(4, reasonStr, sizeof(reasonStr));

    gbLog("Target: %s banType: %s duration: %s reason: %s", targetIdStr, banTypeStr, duration, reasonStr);

    int targetIdx = FindTarget(clientId, targetIdStr, true, false);
    if (targetIdx < 0) {
        ReplyToCommand(clientId, "Failed to locate user: %s", targetIdStr);
        return Plugin_Handled;
    }
    GB_BanReason reason = custom;
    if (!parseReason(reasonStr, reason)) {
        ReplyToCommand(clientId, "Failed to parse reason");
        return Plugin_Handled;
    }
    int banType = StringToInt(banTypeStr);
    if (banType != BSNoComm && banType != BSBanned) {
        ReplyToCommand(clientId, "Invalid ban type");
        return Plugin_Handled;
    }

    if (!ban(clientId, targetIdx, reason, duration, banType, "", 0)) {
        ReplyToCommand(clientId, "Error sending ban request");
    }

    return Plugin_Handled;
}
