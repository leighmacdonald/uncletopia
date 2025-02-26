#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#if defined _gbans_included
#endinput
#endif
#define _gbans_included

// Ban states returned from server
#define BSUnknown -1 // Fail-open unknown status
#define BSOK 0       // OK
#define BSNoComm 1   // Muted
#define BSBanned 2   // Banned
#define BSNetwork 3   // Network blocked

#define PERMISSION_RESERVED 15
#define PERMISSION_EDITOR 25
#define PERMISSION_MOD 50
#define PERMISSION_ADMIN 100

#define HTTP_STATUS_OK 200
#define HTTP_STATUS_CREATED 201
#define HTTP_STATUS_CONFLICT 409

public
SharedPlugin __pl_gbans = {name = "gbans", file = "gbans.smx",
#if defined REQUIRE_PLUGIN
                           required = 1
#else
                           required = 0
#endif
};

enum GB_BanReason {
    unknown = 0,
    custom = 1,
    external = 2,
    cheating = 3,
    racism = 4,
    harassment = 5,
    exploiting = 6,
    warningsExceeded = 7,
    spam = 8,
    languageUsed = 9,
    profile = 10,
    itemDescriptions = 11,
    botHost = 12,
    Evading = 13,
    Username = 14
}

/**
 * Ban or Mute+Gag a client
 *
 * @param adminId Client idx of admin who banned, 0 for system.
 * @param targetId Client idx of ban target
 * @param reason Reason for the ban
 * @param duration Duration in seconds, 0 = permanent
 * @param banType One of BSBanned (banned) or BSNoComm (Muted/Gagged)
 * @param note Optional note for mods
 * @return success status
 */
native bool
GB_BanClient(int adminId, int targetId, GB_BanReason reason, int duration, int banType = BSBanned,
             const char[] note = "");
