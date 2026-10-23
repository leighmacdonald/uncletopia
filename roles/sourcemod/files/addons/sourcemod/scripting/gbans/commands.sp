#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "common.sp"
#include "globals.sp"
#include "ripext/http"
#include "ripext/json"

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
            StrCat(reason, sizeof reason, " ");
        }
        char buff[128];
        GetCmdArg(i, buff, sizeof buff);
        StrCat(reason, sizeof reason, buff);
    }
    char authId[32];
    if (!GetClientAuthId(clientId, AuthId_SteamID64, authId, sizeof authId)) {
        ReplyToCommand(clientId, "Failed to get auth_id of user: %d", clientId);
        return Plugin_Continue;
    }
    char name[64];
    if (!GetClientName(clientId, name, sizeof name)) {
        LogError("Failed to get user name?");
        return Plugin_Continue;
    }

    char serverName[PLATFORM_MAX_PATH];
    GetConVarString(gb_core_host, serverName, sizeof serverName);

    JSONObject obj = new JSONObject();
    obj.SetString("steamId", authId);
    obj.SetString("name", name);
    obj.SetString("reason", reason);
    obj.SetInt("clientId", clientId);

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMPingMod", obj, onPingModRespReceived, clientId);

    return Plugin_Handled;
}

void onPingModRespReceived(HTTPResponse response, any clientId) {
    if (response.Status != HTTPStatus_OK) {
        PrintRPCError(response);
        ReplyToCommand(clientId, "Failed to alert the moderators, please try again later");

        return;
    }
    ReplyToCommand(clientId, "Mods have been alerted, thanks!");
}

public
Action onCmdSeed(int clientId, int argc) {
    char authId[32];
    if (!GetClientAuthId(clientId, AuthId_SteamID64, authId, sizeof authId)) {
        ReplyToCommand(clientId, "Failed to get auth_id of user: %d", clientId);
        return Plugin_Continue;
    }

    // Acknowledge the request up front so the player knows it was received; the
    // final status is delivered from onCmdSeedReceived once the server responds.
    ReplyToCommand(clientId, "Seed request submitted, waiting for confirmation...");

    JSONObject obj = new JSONObject();
    obj.SetString("steamId", authId);

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMSeed", obj, onCmdSeedReceived, clientId);

    return Plugin_Handled;
}

void onCmdSeedReceived(HTTPResponse response, any clientId) {
    // Deliver the final status via chat. ReplyToCommand is only reliable from
    // within a command handler, but this callback fires asynchronously once the
    // server responds. PrintToChat is a safe no-op if the player disconnected
    // while the request was in flight.
    switch (response.Status) {
    case HTTPStatus_TooManyRequests: {
        PrintToChat(clientId, "Please wait before making new seed requests (5min cooldown)");
        return;
    }
    case HTTPStatus_OK: {
        PrintToChat(clientId, "Mods have been alerted, thanks!");
        return;
    }
    case HTTPStatus_Unauthorized: {
        PrintRPCError(response);
        authenticateServer();
        PrintToChat(clientId, "Server authentication expired, re-authenticating. Please try again shortly.");
        return;
    }
    default: {
        PrintRPCError(response);

        char reason[256];
        if (GetRPCErrorMessage(response, reason, sizeof reason)) {
            PrintToChat(clientId, "Seed request failed: %s", reason);
        } else {
            PrintToChat(clientId, "Seed request failed (HTTP %d), check the server logs for details", response.Status);
        }

        return;
    }
    }
}

/**
 * Every 10 minutes, advertise the /seed command to real players when the
 * server is below gb_seed_promo_minplayers non-bot players.
 */
public
Action Timer_CheckSeedPromo(Handle timer) {
    if (GetRealClientCount() >= GetConVarInt(gb_seed_promo_minplayers)) {
        return Plugin_Handled;
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (isValidClient(i)) {
            PrintToChat(i, "The server is a little quiet. Use /seed in chat to find more players on our Discord!");
        }
    }

    return Plugin_Handled;
}

public
Action onCmdHelp(int clientId, int argc) {
    onCmdVersion(clientId, argc);
    ReplyToCommand(clientId, "gb_admins -- List admins and groups");
    ReplyToCommand(clientId, "gb_ban <target> <reason> <duration> <bantype> [note]");
    ReplyToCommand(clientId, "gb_mod <reason> -- Ping a moderator");
    ReplyToCommand(clientId, "seed -- Send a seed request to discord");
    ReplyToCommand(clientId, "report -- Report a player");
    ReplyToCommand(clientId, "gb_reload -- Reload admins");
    ReplyToCommand(clientId, "gb_stv_record -- Start a SourceTV demo");
    ReplyToCommand(clientId, "gb_stv_stoprecord -- Stop the current SourceTV demo");
    ReplyToCommand(clientId, "gb_version -- Show the current version");
    return Plugin_Handled;
}

public
Action onAdminCmdBan(int clientId, int argc) {
    char         command[64];
    char         targetIdStr[50];
    char         memo[256];
    GB_BanReason reason;
    int          duration;
    int          bantype;

    char usage[] = "Usage: %s <target> <reason> <duration> <bantype> [note]";

    GetCmdArg(0, command, sizeof command);

    if (argc < 4) {
        char usageReply[256];
        Format(usageReply, sizeof usageReply, usage, command);
        reply(clientId, usageReply);
        return Plugin_Handled;
    }

    GetCmdArg(1, targetIdStr, sizeof targetIdStr);

    int reasonInt = 0;
    if (!GetCmdArgIntEx(2, reasonInt)) {
        reply(clientId, "Failed to parse reason");
        return Plugin_Handled;
    }

    if (reasonInt < view_as<int>(custom) || reasonInt > view_as<int>(Username)) {
        reply(clientId, "Invalid reason value. Out of range.");
        return Plugin_Handled;
    }

    reason = view_as<GB_BanReason>(reasonInt);

    if (!GetCmdArgIntEx(3, duration)) {
        reply(clientId, "Failed to parse duration");
        return Plugin_Handled;
    }

    if (duration < 0) {
        reply(clientId, "Invalid duration, must be a positive integer or 0 for permanent");
        return Plugin_Handled;
    }

    if (!GetCmdArgIntEx(4, bantype)) {
        reply(clientId, "Failed to parse bantype");
        return Plugin_Handled;
    }

    if (bantype != BSNoComm && bantype != BSBanned) {
        reply(clientId, "Invalid bantype, must be 1 (mute/gag) or 2 (ban)");
        return Plugin_Handled;
    }

    LogMessage("args: %d", argc);
    if (argc > 4) {
        memo[0] = '\0';
        char part[128];
        for (int i = 5; i <= argc; i++) {
            GetCmdArg(i, part, sizeof part);
            if (i > 5) {
                StrCat(memo, sizeof memo, " ");
            }
            StrCat(memo, sizeof memo, part);
        }
    } else {
        Format(memo, sizeof memo, "in-game ban");
    }

    if (strlen(memo) < 10) {
        reply(clientId, "Note must be at least 10 characters");
        return Plugin_Handled;
    }

    LogMessage("Target: %s reason: %d duration: %d bantype: %d memo: %s", targetIdStr, reason, duration, bantype, memo);

    int targetIdx = FindTarget(clientId, targetIdStr, true, false);
    if (targetIdx < 0) {
        reply(clientId, "Failed to locate user");
        return Plugin_Handled;
    }

    if (!ban(clientId, targetIdx, reason, duration, bantype, memo)) {
        reply(clientId, "Error sending ban request");
    }

    return Plugin_Handled;
}

/**
 * List the gbans sourcemod groups and admins, fetched from the gbans backend.
 */
public
Action onCmdAdmins(int clientId, int argc) {
    if (gToken[0] == '\0') {
        reply(clientId, "[GB] Not authenticated with gbans yet, try again later");
        authenticateServer();
        return Plugin_Handled;
    }

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMGroups", new JSONObject(), onCmdAdminsGroupsResp, clientId);

    return Plugin_Handled;
}

void onCmdAdminsGroupsResp(HTTPResponse response, any value) {
    int clientId = view_as<int>(value);
    if (!isValidClient(clientId)) {
        clientId = 0;
    }

    if (response.Status != HTTPStatus_OK) {
        PrintRPCError(response);
        reply(clientId, "[GB] Failed to fetch groups from gbans");
        return;
    }

    JSONObject obj = view_as<JSONObject>(response.Data);

    JSONArray groups;
    if (obj.HasKey("groups")) {
        groups = view_as<JSONArray>(obj.Get("groups"));
    } else {
        groups = new JSONArray();
    }

    JSONObject group;
    char       name[80];
    char       flags[24];
    char       line[96];

    Format(line, sizeof line, "[GB] Groups (%d):", groups.Length);
    reply(clientId, line);

    Format(line, sizeof line, "[GB]   %-24s %-21s %3s", "NAME", "FLAGS", "IMM");
    reply(clientId, line);

    for (int i = 0; i < groups.Length; i++) {
        group = view_as<JSONObject>(groups.Get(i));

        group.GetString("name", name, sizeof name);
        if (strlen(name) > 24) {
            name[24] = '\0';
        }

        permissionSetToFlags(group, "permissions", flags, sizeof flags);
        if (flags[0] == '\0') {
            Format(flags, sizeof flags, "-");
        }

        int immunity = 0;
        if (group.HasKey("immunityLevel")) {
            immunity = group.GetInt("immunityLevel");
        }

        Format(line, sizeof line, "[GB]   %-24s %-21s %3d", name, flags, immunity);
        reply(clientId, line);

        delete group;
    }

    delete groups;

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMUsers", new JSONObject(), onCmdAdminsUsersResp, clientId);
}

void onCmdAdminsUsersResp(HTTPResponse response, any value) {
    int clientId = view_as<int>(value);
    if (!isValidClient(clientId)) {
        clientId = 0;
    }

    if (response.Status != HTTPStatus_OK) {
        PrintRPCError(response);
        reply(clientId, "[GB] Failed to fetch admins from gbans");
        return;
    }

    JSONObject obj = view_as<JSONObject>(response.Data);

    JSONArray users;
    if (obj.HasKey("users")) {
        users = view_as<JSONArray>(obj.Get("users"));
    } else {
        users = new JSONArray();
    }

    JSONArray userGroups;
    if (obj.HasKey("userGroups")) {
        userGroups = view_as<JSONArray>(obj.Get("userGroups"));
    } else {
        userGroups = new JSONArray();
    }

    JSONObject user;
    char       name[80];
    char       identity[80];
    char       id[24];
    char       flags[24];
    char       groups[64];
    char       line[256];

    Format(line, sizeof line, "[GB] Admins (%d):", users.Length);
    reply(clientId, line);

    Format(line, sizeof line, "[GB]   %-20s %-17s %-21s %3s %s", "NAME", "IDENTITY", "FLAGS", "IMM", "GROUPS");
    reply(clientId, line);

    for (int i = 0; i < users.Length; i++) {
        user = view_as<JSONObject>(users.Get(i));

        user.GetString("name", name, sizeof name);
        if (strlen(name) > 20) {
            name[20] = '\0';
        }

        user.GetString("identity", identity, sizeof identity);
        if (strlen(identity) > 17) {
            identity[17] = '\0';
        }

        user.GetString("id", id, sizeof id);

        permissionSetToFlags(user, "permissions", flags, sizeof flags);
        if (flags[0] == '\0') {
            Format(flags, sizeof flags, "-");
        }

        int immunity = 0;
        if (user.HasKey("immunity")) {
            immunity = user.GetInt("immunity");
        }

        userGroupNames(id, userGroups, groups, sizeof groups);

        Format(line, sizeof line, "[GB]   %-20s %-17s %-21s %3d %s", name, identity, flags, immunity, groups);
        reply(clientId, line);

        delete user;
    }

    delete users;
    delete userGroups;
}

// Builds the sourcemod flag string for the gbans permissions JSON array held
// on obj under field (e.g. "permissions").
stock void permissionSetToFlags(JSONObject obj, const char[] field, char[] flags, int flagsLen) {
    int bits = 0;

    if (obj.HasKey(field)) {
        JSONArray perms = view_as<JSONArray>(obj.Get(field));

        char      perm[40];
        AdminFlag flag;
        for (int i = 0; i < perms.Length; i++) {
            if (!perms.GetString(i, perm, sizeof perm)) {
                continue;
            }

            if (PermissionToFlag(perm, flag)) {
                bits |= 1 << view_as<int>(flag);
            }
        }

        delete perms;
    }

    FlagBitsToString(bits, flags, flagsLen);
}

// Comma-separated names of the groups the admin (matched by gbans id string)
// belongs to.
stock void userGroupNames(const char[] adminId, JSONArray userGroups, char[] names, int namesLen) {
    names[0] = '\0';

    char id[24];
    char groupName[80];
    for (int i = 0; i < userGroups.Length; i++) {
        JSONObject ug = view_as<JSONObject>(userGroups.Get(i));

        ug.GetString("adminId", id, sizeof id);
        if (StrEqual(id, adminId)) {
            ug.GetString("groupName", groupName, sizeof groupName);

            if (names[0] != '\0') {
                StrCat(names, namesLen, ", ");
            }
            StrCat(names, namesLen, groupName);
        }

        delete ug;
    }
}
