#if defined _tfdb_ffa_included
 #endinput
#endif
#define _tfdb_ffa_included

/**
 * Returns whether FFA mode is currently active.
 *
 * Used by Guardian / PvB / DeathMatch to refuse to coexist with FFA — FFA flips
 * rocket teams to neutral which breaks the team-vs-team semantics those modes
 * assume.
 *
 * @return True if FFA is currently enabled, false otherwise.
 */
native bool TFDB_IsFFAActive();

public SharedPlugin __pl_tfdb_ffa =
{
	name = "tfdb_ffa",
	file = "tfdb_ffa.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tfdb_ffa_SetNTVOptional()
{
	MarkNativeAsOptional("TFDB_IsFFAActive");
}
#endif
