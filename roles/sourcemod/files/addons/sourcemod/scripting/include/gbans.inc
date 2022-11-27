
#if defined _gbans_included
#endinput
#endif
#define _gbans_included

// Ban states returned from server
#define BSUnknown -1 // Fail-open unknown status
#define BSOK 0       // OK
#define BSNoComm 1   // Muted
#define BSBanned 2   // Banned

#define PERMISSION_RESERVED 15
#define PERMISSION_EDITOR 25
#define PERMISSION_MOD 50
#define PERMISSION_ADMIN 100

#define HTTP_STATUS_OK 200
#define HTTP_STATUS_CONFLICT 409

public SharedPlugin __pl_gbans =
{
	name = "gbans",
	file = "gbans.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

enum banReason {
	custom            = 1,
	external          = 2,
	cheating          = 3,
	racism            = 4,
	harassment        = 5,
	exploiting        = 6,
	warningsExceeded  = 7,
	spam              = 8,
	languageUsed      = 9, // "language" shadows var
	profile           = 10,
	itemDescriptions  = 11
}

/**
 * Ban or Mute+Gag a client
 * 
 * 
 */
native bool GB_BanClient(int adminId, int targetId, banReason reason, const char[] duration = "2d", int banType = BSBanned);
