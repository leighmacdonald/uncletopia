/**
 * Implements a HTTP version of the standard sourcemod  admin-sql-prefetch plugin.
 */
#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "globals.sp"

// Are we already running admin update
bool gQueuedAdminUpdate = false;

// Maps a roles.v1.Permission value (serialized by the protobuf JSON mapping
// as its string name) to the sourcemod admin flag it corresponds to. Returns
// false for permissions with no sourcemod flag equivalent (the web-only
// permissions).
bool PermissionToFlag(const char[] perm, AdminFlag &flag) {
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_RESERVED")) {
        flag = Admin_Reservation;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_GENERIC")) {
        flag = Admin_Generic;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_KICK")) {
        flag = Admin_Kick;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_BAN")) {
        flag = Admin_Ban;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_UNBAN")) {
        flag = Admin_Unban;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_SLAY")) {
        flag = Admin_Slay;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CHANGEMAP")) {
        flag = Admin_Changemap;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CVAR")) {
        flag = Admin_Convars;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CFG")) {
        flag = Admin_Config;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CHAT")) {
        flag = Admin_Chat;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_VOTE")) {
        flag = Admin_Vote;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_PASSWORD")) {
        flag = Admin_Password;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_RCON")) {
        flag = Admin_RCON;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CHEATS")) {
        flag = Admin_Cheats;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_ROOT")) {
        flag = Admin_Root;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CUSTOM_1")) {
        flag = Admin_Custom1;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CUSTOM_2")) {
        flag = Admin_Custom2;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CUSTOM_3")) {
        flag = Admin_Custom3;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CUSTOM_4")) {
        flag = Admin_Custom4;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CUSTOM_5")) {
        flag = Admin_Custom5;
        return true;
    }
    if (StrEqual(perm, "PERMISSION_SOURCEMOD_CUSTOM_6")) {
        flag = Admin_Custom6;
        return true;
    }

    return false;
}

// Applies a group's permission set to a sourcemod group. The protobuf JSON
// mapping omits empty repeated fields, so the key is absent for groups with
// no permissions.
void ApplyGroupPermissions(GroupId grp, JSON_Object group) {
    if (!group.HasKey("permissions")) {
        return;
    }

    JSON_Array permissions = view_as<JSON_Array>(group.GetObject("permissions"));

    char      perm[40];
    AdminFlag flag;
    for (int i = 0; permissions != null && i < permissions.Length; i++) {
        if (!permissions.GetString(i, perm, sizeof perm)) {
            continue;
        }
        if (PermissionToFlag(perm, flag)) {
            grp.SetFlag(flag, true);
        }
    }
}

// Applies a user's permission set to a sourcemod admin. The protobuf JSON
// mapping omits empty repeated fields, so the key is absent for admins with
// no permissions.
void ApplyUserPermissions(AdminId adm, JSON_Object user) {
    if (!user.HasKey("permissions")) {
        return;
    }

    JSON_Array permissions = view_as<JSON_Array>(user.GetObject("permissions"));

    char      perm[40];
    AdminFlag flag;
    for (int i = 0; permissions != null && i < permissions.Length; i++) {
        if (!permissions.GetString(i, perm, sizeof perm)) {
            continue;
        }
        if (PermissionToFlag(perm, flag)) {
            adm.SetFlag(flag, true);
        }
    }
}

public
void OnRebuildAdminCache(AdminCachePart part) {
    if (gQueuedAdminUpdate) {
        return;
    }

    /* Without a token the rebuild requests would be rejected; authenticating
     * requests a rebuild once it succeeds, so don't hold the update lock
     * while waiting for it. */
    if (gToken[0] == '\0') {
        authenticateServer();
        return;
    }

    gQueuedAdminUpdate = true;
    RebuildGroups();
}

void RebuildGroups() {
    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMGroups", new JSON_Object(), onRebuildGroups);
}

void onRebuildGroups(Handle request, bool failure, bool successful, EHTTPStatusCode status, any value1, any value2) {
    if (status != k_EHTTPStatusCode200OK) {
        PrintRPCError(request, failure, status);
        LogError("Invalid response code reading user groups: %d", status);
        gQueuedAdminUpdate = false;
        delete request;

        return;
    }

    JSON_Object groupObj = GetResponseJSON(request);
    if (groupObj == null) {
        LogError("Failed to parse user groups response");
        gQueuedAdminUpdate = false;
        delete request;

        return;
    }

    /* The protobuf JSON mapping omits empty repeated fields, so the key may
     * be absent when there are no groups; the rebuild continues either way. */
    int numGroups = 0;

    if (groupObj.HasKey("groups")) {
        JSON_Array groups = view_as<JSON_Array>(groupObj.GetObject("groups"));

        numGroups = groups != null ? groups.Length : 0;

        char name[128];
        int  immunity;

        for (int i = 0; i < numGroups; i++) {
            JSON_Object group = groups.GetObject(i);
            if (group == null) {
                continue;
            }

            group.GetString("name", name, sizeof name);
            immunity = group.GetInt("immunityLevel");

            GroupId grp;
            if ((grp = FindAdmGroup(name)) == INVALID_GROUP_ID) {
                grp = CreateAdmGroup(name);
            }

            /* Add the permissions from the database to the group */
            ApplyGroupPermissions(grp, group);

            /* Set the immunity level this group has */
            grp.ImmunityLevel = immunity;
        }
    }

    if (groupObj.HasKey("immunities")) {
        JSON_Array immunities = view_as<JSON_Array>(groupObj.GetObject("immunities"));

        int numImmunities = immunities != null ? immunities.Length : 0;

        for (int i = 0; i < numImmunities; i++) {
            JSON_Object groupImmunity = immunities.GetObject(i);
            if (groupImmunity == null) {
                continue;
            }

            char    groupName[128];
            char    otherName[128];
            GroupId grp, other;

            groupImmunity.GetString("groupName", groupName, sizeof groupName);
            groupImmunity.GetString("otherName", otherName, sizeof otherName);

            if (((grp = FindAdmGroup(groupName)) == INVALID_GROUP_ID)
                || (other = FindAdmGroup(otherName)) == INVALID_GROUP_ID) {
                continue;
            }

            grp.AddGroupImmunity(other);
        }
    }

    json_cleanup_and_delete(groupObj);
    delete request;

    LogMessage("Loaded %d groups", numGroups);

    RebuildUsers();
}

void RebuildUsers() {
    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMUsers", new JSON_Object(), onRebuildUsers);
}

void onRebuildUsers(Handle request, bool failure, bool successful, EHTTPStatusCode status, any value1, any value2) {
    if (status != k_EHTTPStatusCode200OK) {
        PrintRPCError(request, failure, status);
        LogError("Invalid response code reading users: %d", status);
        gQueuedAdminUpdate = false;
        delete request;

        return;
    }

    JSON_Object usersObj = GetResponseJSON(request);
    if (usersObj == null) {
        LogError("Failed to parse users response");
        gQueuedAdminUpdate = false;
        delete request;

        return;
    }

    /* The protobuf JSON mapping omits empty repeated fields, so the keys may
     * be absent when there are no admins. */
    JSON_Array users      = view_as<JSON_Array>(usersObj.GetObject("users"));
    JSON_Array userGroups = view_as<JSON_Array>(usersObj.GetObject("userGroups"));

    char    authtype[16];
    char    identity[80];
    char    password[80];
    char    name[80];
    int     immunity;
    AdminId adm;
    GroupId grp;

    int numUsers      = users != null ? users.Length : 0;
    int numUserGroups = userGroups != null ? userGroups.Length : 0;

    /* Keep track of a mapping from admin DB IDs to internal AdminIds to
     * enable group lookups en masse.
     *
     * The id is the 64-bit SteamID serialized as a JSON string by the
     * protobuf JSON mapping, so it is read as a string. */
    StringMap htAdmins = new StringMap();
    char      key[24];

    for (int i = 0; i < numUsers; i++) {
        JSON_Object user = users.GetObject(i);
        if (user == null) {
            continue;
        }

        user.GetString("authType", authtype, sizeof authtype);
        user.GetString("identity", identity, sizeof identity);
        user.GetString("password", password, sizeof password);
        user.GetString("name", name, sizeof name);
        if (user.HasKey("immunity")) {
            immunity = user.GetInt("immunity");
        } else {
            immunity = 0;
        }

        /* Use a pre-existing admin if we can */
        if ((adm = FindAdminByIdentity(authtype, identity)) == INVALID_ADMIN_ID) {
            adm = CreateAdmin(name);
            if (!adm.BindIdentity(authtype, identity)) {
                LogError("Could not bind prefetched SQL admin (authtype \"%s\") (identity \"%s\")", authtype, identity);
                continue;
            }
        }

        user.GetString("id", key, sizeof key);

        htAdmins.SetValue(key, adm);

        /* See if this admin wants a password */
        if (password[0] != '\0') {
            adm.SetPassword(password);
        }

        /* Apply the permissions from the database to the admin */
        ApplyUserPermissions(adm, user);

        adm.ImmunityLevel = immunity;
    }

    char group[80];
    for (int i = 0; i < numUserGroups; i++) {
        JSON_Object userGroup = userGroups.GetObject(i);
        if (userGroup == null) {
            continue;
        }

        userGroup.GetString("adminId", key, sizeof key);
        userGroup.GetString("groupName", group, sizeof group);

        if (htAdmins.GetValue(key, adm)) {
            if ((grp = FindAdmGroup(group)) == INVALID_GROUP_ID) {
                /* Group wasn't found, don't bother with it.  */
                LogError("Failed to add group, it doesnt exist: %s", group);
                continue;
            }

            adm.InheritGroup(grp);
        }
    }

    delete htAdmins;
    json_cleanup_and_delete(usersObj);
    delete request;

    LogMessage("Loaded %d users into %d groups", numUsers, numUserGroups);

    RebuildOverrides();
}

void RebuildOverrides() {
    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMOverrides", new JSON_Object(), onRebuildOverrides);
}

void onRebuildOverrides(Handle request, bool failure, bool successful, EHTTPStatusCode status, any value1, any value2) {
    if (status != k_EHTTPStatusCode200OK) {
        PrintRPCError(request, failure, status);
        gQueuedAdminUpdate = false;
        delete request;

        return;
    }

    JSON_Object overridesObj = GetResponseJSON(request);
    if (overridesObj == null || !overridesObj.HasKey("overrides")) {
        gQueuedAdminUpdate = false;
        json_cleanup_and_delete(overridesObj);
        delete request;

        return;
    }

    JSON_Array overrides = view_as<JSON_Array>(overridesObj.GetObject("overrides"));

    int numOverrides = overrides != null ? overrides.Length : 0;

    char type[48];
    char name[64];
    int  flagBits;

    for (int i = 0; i < numOverrides; i++) {
        JSON_Object override = overrides.GetObject(i);
        if (override == null) {
            continue;
        }

        override.GetString("overrideType", type, sizeof type);
        override.GetString("name", name, sizeof name);

        /* Rebuild the ADMFLAG bits from the permission set. The AdminFlag
         * enum index matches the ADMFLAG_* bit position, and no bits (0)
         * means ADMFLAG_NONE - anyone may use the command. */
        flagBits = 0;
        if (override.HasKey("permissions")) {
            JSON_Array permissions = view_as<JSON_Array>(override.GetObject("permissions"));

            char      perm[40];
            AdminFlag flag;
            for (int j = 0; permissions != null && j < permissions.Length; j++) {
                if (!permissions.GetString(j, perm, sizeof perm)) {
                    continue;
                }
                if (PermissionToFlag(perm, flag)) {
                    flagBits |= 1 << view_as<int>(flag);
                }
            }
        }

        if (StrEqual(type, "OVERRIDE_TYPE_GROUP")) {
            AddCommandOverride(name, Override_CommandGroup, flagBits);
        } else {
            AddCommandOverride(name, Override_Command, flagBits);
        }
    }

    json_cleanup_and_delete(overridesObj);
    delete request;

    gQueuedAdminUpdate = false;
}
