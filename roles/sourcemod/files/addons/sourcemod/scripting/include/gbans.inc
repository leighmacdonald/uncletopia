
enum banReason {
	custom            = 1,
	external          = 2,
	cheating          = 3,
	racism            = 4,
	harassment        = 5,
	exploiting        = 6,
	warningsExceeded  = 7,
	spam              = 8,
	language          = 9,
	profile           = 10,
	itemDescriptions  = 11
}

native bool GB_BanClient(int adminId, int targetId, banReason reason, int duration = -1);