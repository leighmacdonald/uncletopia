#if defined _tfdb_deathmatch_included
 #endinput
#endif
#define _tfdb_deathmatch_included

/**
 * Returns whether DeathMatch mode is currently active.
 * DeathMatch = Never-Ending Rounds + Solo queue.
 *
 * @return True if DeathMatch is active (NER running or soloers queued).
 */
native bool TFDB_IsDeathMatchActive();

/**
 * Returns whether Never-Ending Rounds is currently enabled.
 *
 * @return True if NER is enabled.
 */
native bool TFDB_IsNEREnabled();

public SharedPlugin __pl_tfdb_deathmatch =
{
    name = "tfdb_deathmatch",
    file = "tfdb_deathmatch.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tfdb_deathmatch_SetNTVOptional()
{
    MarkNativeAsOptional("TFDB_IsDeathMatchActive");
    MarkNativeAsOptional("TFDB_IsNEREnabled");
}
#endif
