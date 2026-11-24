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

public
SharedPlugin __pl_gbans = {name = "gbans", file = "gbans.smx",
#if defined REQUIRE_PLUGIN
                           required = 1
#else
                           required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_gbans_SetNTVOptional()
{
	MarkNativeAsOptional("GB_BanClient");
	MarkNativeAsOptional("GB_BanClientAC");
	MarkNativeAsOptional("GB_ScrambleTeams");
}
#endif

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

/**
 * Ban a client flagged by anticheat (e.g. StAC)
 *
 * The ban is permanent and recorded with a custom reason so the detection
 * text is preserved.
 *
 * @param targetId Client idx of ban target
 * @param reason Free form reason for the ban, must be at least 10 characters
 * @return success status
 */
native bool GB_BanClientAC(int targetId, const char[] reason);

/**
 * Callback for GB_ScrambleTeams. The arrays contain the client indexes that
 * were moved to each team, plus the error text when success is false.
 */
typedef GB_ScrambleResultCallback = function void (
    bool success, const int[] redClients, int redCount, const int[] bluClients, int bluCount,
    const int[] waitingClients, int waitingCount, const char[] error);

/**
 * Ask the backend to balance the supplied players by their internal skill
 * rating and have gbans perform the team changes itself.
 *
 * Bots, SourceTV and replay clients are ignored, as are clients without a
 * valid SteamID64. Spectators and unassigned clients are included. The backend
 * selects the stats bucket and balancer automatically. The callback fires
 * exactly once, after team changes have been applied.
 *
 * @param clientIds Client indexes to include in the scramble
 * @param numClients Number of entries in clientIds
 * @param callback Called with the result when the scramble completes
 * @param maxExact Maximum pool size for the exact solver, 0 for the default
 */
native void GB_ScrambleTeams(const int[] clientIds, int numClients, GB_ScrambleResultCallback callback,
                             int maxExact = 32);
