#if defined _tfdb_pvb_included
 #endinput
#endif
#define _tfdb_pvb_included

/**
 * Returns whether PvB is currently active in normal mode
 * (a bot is spawned, fighting human players).
 *
 * @return True if PvB normal mode is active, false otherwise.
 */
native bool TFDB_IsPvBActive();

/**
 * Returns whether PvB training mode is currently active
 * (bots on both teams, humans in spectator).
 *
 * @return True if PvB training mode is active, false otherwise.
 */
native bool TFDB_IsPvBTraining();

public SharedPlugin __pl_tfdb_pvb =
{
    name = "tfdb_pvb",
    file = "tfdb_pvb.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_tfdb_pvb_SetNTVOptional()
{
    MarkNativeAsOptional("TFDB_IsPvBActive");
    MarkNativeAsOptional("TFDB_IsPvBTraining");
}
#endif
