#if defined _tfdb_guardian_included
 #endinput
#endif
#define _tfdb_guardian_included

/**
 * Returns whether a Guardian round is currently active.
 *
 * @return True if a Guardian round is active, false otherwise.
 */
native bool TFDB_IsGuardianActive();

/**
 * Gets the client index of the current Guardian.
 *
 * @return Client index of the Guardian, or 0 if no Guardian is active.
 */
native int TFDB_GetGuardian();

/**
 * Returns whether the next round is scheduled to be a Guardian round.
 *
 * @return True if the next round will be a Guardian round, false otherwise.
 */
native bool TFDB_IsNextRoundGuardian();

public SharedPlugin __pl_tfdb_guardian = 
{
	name = "tfdb_guardian",
	file = "tfdb_guardian.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tfdb_guardian_SetNTVOptional()
{
	MarkNativeAsOptional("TFDB_IsGuardianActive");
	MarkNativeAsOptional("TFDB_GetGuardian");
	MarkNativeAsOptional("TFDB_IsNextRoundGuardian");
}
#endif
