#if defined _tfdb_included
 #endinput
#endif
#define _tfdb_included

// ---- General settings -----------------------------------------------------------
//
//   Timer rate vs OnGameFrame:
//   SourceMod's TimerSys.cpp defines TIMER_MIN_ACCURACY = 0.1 (seconds).
//   The timer processing loop (RunFrame) only fires every ~0.1s regardless of
//   the interval passed to CreateTimer — so the logic timer runs at ~10Hz.
//   The actual fire interval is NOT exactly 0.1s: it depends on tickrate since
//   0.1s must be rounded up to the next tick boundary (e.g. 7 ticks on 66-tick
//   = 0.1061s, 13 ticks on 128-tick = 0.1016s).
//
//   OnGameFrame fires every server tick (~66Hz on 66-tick, ~128Hz on 128-tick).
//   We use it for smooth per-frame homing. Turn rate and elevation values in the
//   config are calibrated as "amount per 0.1s" for backwards compatibility.
//   Per-frame scaling uses GetTickInterval() directly — no derived magic numbers.
//
#define FPS_LOGIC_RATE          10.0
#define FPS_LOGIC_INTERVAL      1.0 / FPS_LOGIC_RATE

/**
 * The base time interval (seconds) that config turn rate / elevation values
 * are calibrated against. Turn rate 0.05 means "lerp 0.05 per 0.1s."
 * Per-frame code divides by this and multiplies by GetTickInterval().
 */
#define TICK_BASE_INTERVAL      0.1

/** Conversion factor: Hammer units/s to MPH. (1 HU ≈ 0.01905m) */
#define HAMMER_TO_MPH           0.042614

// ---- Maximum structure sizes ----------------------------------------------------
#define MAX_ROCKETS             100
#define MAX_ROCKET_CLASSES      50
#define MAX_SPAWNER_CLASSES     50
#define MAX_SPAWN_POINTS        100
#define MAX_PRESETS             16

// ---- Flags and types constants --------------------------------------------------

/**
 * Rocket behaviour types that determine how rockets track targets.
 */
enum BehaviourTypes
{
	Behaviour_Unknown,       /**< Unknown/undefined behaviour */
	Behaviour_Homing,        /**< Modern homing - smooth tracking with turn rate */
	Behaviour_LegacyHoming   /**< Legacy homing - instant direction changes */
};

/**
 * Rocket behaviour flags (bitfield). Combine using bitwise OR (|).
 * Use TestFlags() macro to check if a flag is set.
 */
enum RocketFlags
{
	RocketFlag_None             = 0,        /**< No flags set */
	RocketFlag_PlaySpawnSound   = 1 << 0,   /**< Play sound when rocket spawns */
	RocketFlag_PlayBeepSound    = 1 << 1,   /**< Play periodic beep sound */
	RocketFlag_PlayAlertSound   = 1 << 2,   /**< Play alert sound when target changes */
	RocketFlag_ElevateOnDeflect = 1 << 3,   /**< Rocket elevates after deflection */
	RocketFlag_IsNeutral        = 1 << 4,   /**< Rocket has no team (grey skin) */
	RocketFlag_Exploded         = 1 << 5,   /**< Rocket has exploded (internal) */
	RocketFlag_OnSpawnCmd       = 1 << 6,   /**< Execute commands on spawn */
	RocketFlag_OnDeflectCmd     = 1 << 7,   /**< Execute commands on deflect */
	RocketFlag_OnKillCmd        = 1 << 8,   /**< Execute commands on kill */
	RocketFlag_OnExplodeCmd     = 1 << 9,   /**< Execute commands on explode */
	RocketFlag_CustomModel      = 1 << 10,  /**< Uses custom model */
	RocketFlag_CustomSpawnSound = 1 << 11,  /**< Uses custom spawn sound */
	RocketFlag_CustomBeepSound  = 1 << 12,  /**< Uses custom beep sound */
	RocketFlag_CustomAlertSound = 1 << 13,  /**< Uses custom alert sound */
	RocketFlag_Elevating        = 1 << 14,  /**< Currently elevating (internal) */
	RocketFlag_IsAnimated       = 1 << 15,  /**< Model has animations */
	RocketFlag_IsTRLimited      = 1 << 16,  /**< Turn rate has a limit */
	RocketFlag_IsSpeedLimited   = 1 << 17,  /**< Speed has a limit */
	RocketFlag_KeepDirection    = 1 << 18,  /**< Maintain direction after deflect */
	RocketFlag_TeamlessHits     = 1 << 19,  /**< Can hit players of any team */
	RocketFlag_ResetBounces     = 1 << 20,  /**< Reset bounce count on deflect */
	RocketFlag_NoBounceDrags    = 1 << 21,  /**< Can't drag while bouncing */
	RocketFlag_OnNoTargetCmd    = 1 << 22,  /**< Execute commands when no target */
	RocketFlag_CanBeStolen      = 1 << 23,  /**< Rocket can be stolen by other players */
	RocketFlag_StealTeamCheck   = 1 << 24   /**< Only teammates can steal */
};

/**
 * Sound types for rocket audio.
 */
enum RocketSound
{
	RocketSound_Spawn,   /**< Sound played when rocket spawns */
	RocketSound_Beep,    /**< Periodic tracking beep sound */
	RocketSound_Alert    /**< Sound played when target changes */
};

/**
 * Rocket state flags (bitfield). Indicates current rocket status.
 */
enum RocketState
{
	RocketState_None     = 0,       /**< Default state */
	RocketState_Dragging = 1 << 0,  /**< Player is dragging the rocket */
	RocketState_Bouncing = 1 << 1,  /**< Rocket is bouncing off surfaces */
	RocketState_Stolen   = 1 << 2,  /**< Rocket was stolen from another player */
	RocketState_Delayed  = 1 << 3,  /**< Rocket is in delay prevention mode */
	RocketState_CanDrag  = 1 << 4   /**< Rocket can be dragged by owner */
};

/**
 * Steal information for a client.
 */
enum struct eRocketSteal
{
	bool stoleRocket;    /**< Whether client stole a rocket this round */
	int rocketsStolen;   /**< Number of rockets stolen this round */
}

/** Macro to test if flags are set: TestFlags(flags, RocketFlag_PlaySpawnSound) */
#define TestFlags(%1,%2)    (!!((%1) & (%2)))

// ---- Other resources ------------------------------------------------------------
#define SOUND_DEFAULT_SPAWN     "weapons/sentry_rocket.wav"
#define SOUND_DEFAULT_BEEP      "weapons/sentry_scan.wav"
#define SOUND_DEFAULT_ALERT     "weapons/sentry_spot.wav"
#define SOUND_DEFAULT_SPEEDUP   "misc/doomsday_lift_warning.wav"
#define SNDCHAN_MUSIC           32
#define PARTICLE_NUKE_1         "fireSmokeExplosion"
#define PARTICLE_NUKE_2         "fireSmokeExplosion1"
#define PARTICLE_NUKE_3         "fireSmokeExplosion2"
#define PARTICLE_NUKE_4         "fireSmokeExplosion3"
#define PARTICLE_NUKE_5         "fireSmokeExplosion4"
#define PARTICLE_NUKE_COLLUMN   "fireSmoke_collumnP"
#define PARTICLE_NUKE_1_ANGLES  view_as<float>({270.0, 0.0, 0.0})
#define PARTICLE_NUKE_2_ANGLES  PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_3_ANGLES  PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_4_ANGLES  PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_5_ANGLES  PARTICLE_NUKE_1_ANGLES
#define PARTICLE_NUKE_COLLUMN_ANGLES  PARTICLE_NUKE_1_ANGLES

// ---- Forwards --------------------------------------------------

/**
 * Called when a rocket has been created and spawned.
 *
 * @param iIndex    The rocket's internal index (0 to MAX_ROCKETS-1).
 * @param iEntity   The rocket's entity index.
 */
forward void TFDB_OnRocketCreated(int iIndex, int iEntity);

/**
 * Called before a rocket is created. Return Plugin_Handled to prevent creation.
 *
 * @param iIndex    The rocket's internal index (0 to MAX_ROCKETS-1).
 * @param iClass    The rocket class index. Can be modified.
 * @param iFlags    The rocket flags. Can be modified.
 * @return          Plugin_Continue to allow, Plugin_Handled to block.
 */
forward Action TFDB_OnRocketCreatedPre(int iIndex, int &iClass, RocketFlags &iFlags);

/**
 * Called when a rocket has been deflected by a player.
 *
 * @param iIndex    The rocket's internal index.
 * @param iEntity   The rocket's entity index.
 * @param iOwner    The client index of the new owner (deflector).
 */
forward void TFDB_OnRocketDeflect(int iIndex, int iEntity, int iOwner);

/**
 * Called before a rocket deflection. Return Plugin_Handled to prevent deflection.
 *
 * @param iIndex    The rocket's internal index.
 * @param iEntity   The rocket's entity index.
 * @param iOwner    The client index of the new owner (deflector).
 * @param iTarget   The new target client. Can be modified.
 * @return          Plugin_Continue to allow, Plugin_Handled to block.
 */
forward Action TFDB_OnRocketDeflectPre(int iIndex, int iEntity, int iOwner, int &iTarget);

/**
 * Called when a player steals another player's rocket.
 *
 * @param iIndex        The rocket's internal index.
 * @param iOwner        The client who stole the rocket.
 * @param iTarget       The original target who lost the rocket.
 * @param iStealCount   The number of times this player has stolen rockets this round.
 */
forward void TFDB_OnRocketSteal(int iIndex, int iOwner, int iTarget, int iStealCount);

/**
 * Called when a rocket has no valid target available.
 *
 * @param iIndex    The rocket's internal index.
 * @param iTarget   The previous target (may be invalid).
 * @param iOwner    The rocket's current owner.
 */
forward void TFDB_OnRocketNoTarget(int iIndex, int iTarget, int iOwner);

/**
 * Called when a rocket enters delay prevention mode (player is delaying).
 *
 * @param iIndex    The rocket's internal index.
 * @param iTarget   The target player who is delaying.
 */
forward void TFDB_OnRocketDelay(int iIndex, int iTarget);

/**
 * Called when a rocket bounces off a surface.
 *
 * @param iIndex    The rocket's internal index.
 * @param iEntity   The rocket's entity index.
 */
forward void TFDB_OnRocketBounce(int iIndex, int iEntity);

/**
 * Called before a rocket bounces. Return Plugin_Handled to prevent bounce.
 *
 * @param iIndex        The rocket's internal index.
 * @param iEntity       The rocket's entity index.
 * @param fAngles       The bounce angles. Can be modified.
 * @param fVelocity     The bounce velocity. Can be modified.
 * @return              Plugin_Continue to allow, Plugin_Handled to block.
 */
forward Action TFDB_OnRocketBouncePre(int iIndex, int iEntity, float fAngles[3], float fVelocity[3]);

/**
 * Called after a rockets configuration file has been loaded and parsed.
 *
 * @param strConfigFile The name of the configuration file that was loaded.
 */
forward void TFDB_OnRocketsConfigExecuted(const char[] strConfigFile);

/**
 * Called when a rocket's state changes.
 *
 * @param iIndex        The rocket's internal index.
 * @param iState        The previous state.
 * @param iNewState     The new state.
 */
forward void TFDB_OnRocketStateChanged(int iIndex, RocketState iState, RocketState iNewState);

// ---- Natives --------------------------------------------------

// ============ Rocket Instance Functions ============

/**
 * Checks if a rocket index is valid and the rocket exists.
 *
 * @param iIndex    The rocket's internal index (0 to MAX_ROCKETS-1).
 * @return          True if the rocket exists, false otherwise.
 */
native bool TFDB_IsValidRocket(int iIndex);

/**
 * Finds a rocket's internal index by its entity index.
 *
 * @param iEntity   The rocket's entity index.
 * @return          The rocket's internal index, or -1 if not found.
 */
native int TFDB_FindRocketByEntity(int iEntity);

/**
 * Checks if the dodgeball gamemode is currently enabled.
 *
 * @return          True if dodgeball is enabled, false otherwise.
 */
native bool TFDB_IsDodgeballEnabled();

/**
 * Gets the entity index of a rocket.
 *
 * @param iIndex    The rocket's internal index.
 * @return          The rocket's entity index.
 */
native int TFDB_GetRocketEntity(int iIndex);

/**
 * Gets the behaviour flags of a rocket instance.
 *
 * @param iIndex    The rocket's internal index.
 * @return          The rocket's RocketFlags bitfield.
 */
native RocketFlags TFDB_GetRocketFlags(int iIndex);

/**
 * Sets the behaviour flags of a rocket instance.
 *
 * @param iIndex    The rocket's internal index.
 * @param iFlags    The new RocketFlags bitfield.
 */
native void TFDB_SetRocketFlags(int iIndex, RocketFlags iFlags);

/**
 * Gets the current target of a rocket.
 *
 * @param iIndex    The rocket's internal index.
 * @return          The target client index, or -1 if no target.
 */
native int TFDB_GetRocketTarget(int iIndex);

/**
 * Sets the target of a rocket.
 *
 * @param iIndex    The rocket's internal index.
 * @param iTarget   The new target client index (as entity reference).
 */
native void TFDB_SetRocketTarget(int iIndex, int iTarget);

/**
 * Gets the deflection count for the current event (resets each round).
 *
 * @param iIndex    The rocket's internal index.
 * @return          The number of deflections this event.
 */
native int TFDB_GetRocketEventDeflections(int iIndex);

/**
 * Sets the event deflection count.
 *
 * @param iIndex        The rocket's internal index.
 * @param iDeflections  The new deflection count.
 */
native void TFDB_SetRocketEventDeflections(int iIndex, int iDeflections);

/**
 * Gets the total deflection count for this rocket's lifetime.
 *
 * @param iIndex    The rocket's internal index.
 * @return          The total number of deflections.
 */
native int TFDB_GetRocketDeflections(int iIndex);

/**
 * Sets the total deflection count.
 *
 * @param iIndex        The rocket's internal index.
 * @param iDeflections  The new total deflection count.
 */
native void TFDB_SetRocketDeflections(int iIndex, int iDeflections);

/**
 * Gets the class index of a rocket.
 *
 * @param iIndex    The rocket's internal index.
 * @return          The rocket class index.
 */
native int TFDB_GetRocketClass(int iIndex);

/**
 * Sets the class of a rocket.
 *
 * @param iIndex    The rocket's internal index.
 * @param iClass    The new rocket class index.
 */
native void TFDB_SetRocketClass(int iIndex, int iClass);

// ============ Rocket Class Configuration ============

/**
 * Gets the total number of rocket classes defined.
 *
 * @return          The number of rocket classes.
 */
native int TFDB_GetRocketClassCount();

/**
 * Gets the behaviour type of a rocket class.
 *
 * @param iClass    The rocket class index.
 * @return          The BehaviourTypes value (Homing, LegacyHoming, etc).
 */
native BehaviourTypes TFDB_GetRocketClassBehaviour(int iClass);

/**
 * Sets the behaviour type of a rocket class.
 *
 * @param iClass        The rocket class index.
 * @param iBehaviour    The new BehaviourTypes value.
 */
native void TFDB_SetRocketClassBehaviour(int iClass, BehaviourTypes iBehaviour);

/** Gets the default flags of a rocket class. */
native RocketFlags TFDB_GetRocketClassFlags(int iClass);

/** Sets the default flags of a rocket class. */
native void TFDB_SetRocketClassFlags(int iClass, RocketFlags iFlags);

/** Gets the base damage of a rocket class. */
native float TFDB_GetRocketClassDamage(int iClass);

/** Sets the base damage of a rocket class. */
native void TFDB_SetRocketClassDamage(int iClass, float fDamage);

/** Gets the damage increment per deflection. */
native float TFDB_GetRocketClassDamageIncrement(int iClass);

/** Sets the damage increment per deflection. */
native void TFDB_SetRocketClassDamageIncrement(int iClass, float fDamage);

/** Gets the base speed (in Hammer units/second). */
native float TFDB_GetRocketClassSpeed(int iClass);

/** Sets the base speed (in Hammer units/second). */
native void TFDB_SetRocketClassSpeed(int iClass, float fSpeed);

/** Gets the speed increment per deflection. */
native float TFDB_GetRocketClassSpeedIncrement(int iClass);

/** Sets the speed increment per deflection. */
native void TFDB_SetRocketClassSpeedIncrement(int iClass, float fSpeed);

/** Gets the maximum speed limit (0 = no limit). */
native float TFDB_GetRocketClassSpeedLimit(int iClass);

/** Sets the maximum speed limit (0 = no limit). */
native void TFDB_SetRocketClassSpeedLimit(int iClass, float fSpeed);

/** Gets the base turn rate (degrees/second). */
native float TFDB_GetRocketClassTurnRate(int iClass);

/** Sets the base turn rate (degrees/second). */
native void TFDB_SetRocketClassTurnRate(int iClass, float fTurnRate);

/** Gets the turn rate increment per deflection. */
native float TFDB_GetRocketClassTurnRateIncrement(int iClass);

/** Sets the turn rate increment per deflection. */
native void TFDB_SetRocketClassTurnRateIncrement(int iClass, float fTurnRate);

/** Gets the maximum turn rate limit (0 = no limit). */
native float TFDB_GetRocketClassTurnRateLimit(int iClass);

/** Sets the maximum turn rate limit (0 = no limit). */
native void TFDB_SetRocketClassTurnRateLimit(int iClass, float fTurnRate);

/** Gets the elevation rate (vertical tracking speed). */
native float TFDB_GetRocketClassElevationRate(int iClass);

/** Sets the elevation rate (vertical tracking speed). */
native void TFDB_SetRocketClassElevationRate(int iClass, float fElevation);

/** Gets the maximum elevation limit. */
native float TFDB_GetRocketClassElevationLimit(int iClass);

/** Sets the maximum elevation limit. */
native void TFDB_SetRocketClassElevationLimit(int iClass, float fElevation);

/** Gets the rockets modifier (affects speed based on active rockets). */
native float TFDB_GetRocketClassRocketsModifier(int iClass);

/** Sets the rockets modifier (affects speed based on active rockets). */
native void TFDB_SetRocketClassRocketsModifier(int iClass, float fModifier);

/** Gets the player modifier (affects speed based on player count). */
native float TFDB_GetRocketClassPlayerModifier(int iClass);

/** Sets the player modifier (affects speed based on player count). */
native void TFDB_SetRocketClassPlayerModifier(int iClass, float fModifier);

/** Gets the control delay (time before player can redirect after deflect). */
native float TFDB_GetRocketClassControlDelay(int iClass);

/** Sets the control delay. */
native void TFDB_SetRocketClassControlDelay(int iClass, float fDelay);


/** Sets the total number of rocket classes. */
native void TFDB_SetRocketClassCount(int iCount);

/** Sets the entity index of a rocket. */
native void TFDB_SetRocketEntity(int iIndex, int iEntity);

/** Gets the maximum number of bounces allowed. */
native int TFDB_GetRocketClassMaxBounces(int iClass);

/** Sets the maximum number of bounces allowed. */
native void TFDB_SetRocketClassMaxBounces(int iClass, int iBounces);

// ============ Spawner Configuration ============

/** Gets the name of a spawner class. */
native void TFDB_GetSpawnersName(int iSpawnerClass, char[] strBuffer, int iMaxLen);

/** Sets the name of a spawner class. */
native void TFDB_SetSpawnersName(int iSpawnerClass, const char[] strName);

/** Gets the maximum rockets a spawner can fire at once. */
native int TFDB_GetSpawnersMaxRockets(int iSpawnerClass);

/** Sets the maximum rockets a spawner can fire at once. */
native void TFDB_SetSpawnersMaxRockets(int iSpawnerClass, int iMaxRockets);

/** Gets the spawn interval (seconds between rockets). */
native float TFDB_GetSpawnersInterval(int iSpawnerClass);

/** Sets the spawn interval (seconds between rockets). */
native void TFDB_SetSpawnersInterval(int iSpawnerClass, float fInterval);

/**
 * Gets the rocket class spawn chances table.
 * @note You MUST call delete on the returned ArrayList Handle when finished, or your plugin will leak memory.
 */
native ArrayList TFDB_GetSpawnersChancesTable(int iSpawnerClass);

/** Sets the rocket class spawn chances table. */
native void TFDB_SetSpawnersChancesTable(int iSpawnerClass, ArrayList hTable);

/** Gets the total number of spawner classes. */
native int TFDB_GetSpawnersCount();

/** Sets the total number of spawner classes. */
native void TFDB_SetSpawnersCount(int iCount);

// ============ Spawn Points ============

/** Gets the current RED team spawn point index. */
native int TFDB_GetCurrentRedSpawn();

/** Sets the current RED team spawn point index. */
native void TFDB_SetCurrentRedSpawn(int iRedSpawn);

/** Gets the number of RED team spawn points. */
native int TFDB_GetSpawnPointsRedCount();

/** Sets the number of RED team spawn points. */
native void TFDB_SetSpawnPointsRedCount(int iCount);

/** Gets the spawner class assigned to a RED spawn point. */
native int TFDB_GetSpawnPointsRedClass(int iSpawner);

/** Sets the spawner class assigned to a RED spawn point. */
native void TFDB_SetSpawnPointsRedClass(int iSpawner, int iSpawnerClass);

/** Gets the entity index of a RED spawn point. */
native int TFDB_GetSpawnPointsRedEntity(int iSpawner);

/** Sets the entity index of a RED spawn point. */
native void TFDB_SetSpawnPointsRedEntity(int iSpawner, int iEntity);

/** Gets the current BLU team spawn point index. */
native int TFDB_GetCurrentBluSpawn();

/** Sets the current BLU team spawn point index. */
native void TFDB_SetCurrentBluSpawn(int iBluSpawn);

/** Gets the number of BLU team spawn points. */
native int TFDB_GetSpawnPointsBluCount();

/** Sets the number of BLU team spawn points. */
native void TFDB_SetSpawnPointsBluCount(int iCount);

/** Gets the spawner class assigned to a BLU spawn point. */
native int TFDB_GetSpawnPointsBluClass(int iSpawner);

/** Sets the spawner class assigned to a BLU spawn point. */
native void TFDB_SetSpawnPointsBluClass(int iSpawner, int iSpawnerClass);

/** Gets the entity index of a BLU spawn point. */
native int TFDB_GetSpawnPointsBluEntity(int iSpawner);

/** Sets the entity index of a BLU spawn point. */
native void TFDB_SetSpawnPointsBluEntity(int iSpawner, int iEntity);

// ============ Game State ============

/** Returns true if the round has started. */
native bool TFDB_GetRoundStarted();

/** Gets the current round count. */
native int TFDB_GetRoundCount();

/** Gets the total number of rockets fired this round. */
native int TFDB_GetRocketsFired();

/** Gets the next scheduled rocket spawn time. */
native float TFDB_GetNextSpawnTime();

/** Sets the next scheduled rocket spawn time. */
native void TFDB_SetNextSpawnTime(float fSpawnTime);

/** Gets the team of the last player to die. */
native int TFDB_GetLastDeadTeam();

/** Gets the client index of the last player to die. */
native int TFDB_GetLastDeadClient();

/** Gets the client index of the last player to steal a rocket. */
native int TFDB_GetLastStealer();

// ============ Rocket Runtime State ============

/** Gets the current speed of a rocket (Hammer units/second). */
native float TFDB_GetRocketSpeed(int iIndex);

/** Sets the current speed of a rocket (Hammer units/second). */
native void TFDB_SetRocketSpeed(int iIndex, float fSpeed);

/** Gets the current speed of a rocket in MPH. */
native float TFDB_GetRocketMphSpeed(int iIndex);

/** Sets the current speed of a rocket in MPH. */
native void TFDB_SetRocketMphSpeed(int iIndex, float fSpeed);

/** Gets the current direction vector of a rocket. */
native void TFDB_GetRocketDirection(int iIndex, float fBuffer[3]);

/** Sets the direction vector of a rocket. */
native void TFDB_SetRocketDirection(int iIndex, float fDirection[3]);

/** Gets the timestamp of the last deflection. */
native float TFDB_GetRocketLastDeflectionTime(int iIndex);

/** Sets the timestamp of the last deflection. */
native void TFDB_SetRocketLastDeflectionTime(int iIndex, float fTime);

/** Gets the timestamp of the last beep sound. */
native float TFDB_GetRocketLastBeepTime(int iIndex);

/** Sets the timestamp of the last beep sound. */
native void TFDB_SetRocketLastBeepTime(int iIndex, float fTime);

/** Gets the total number of active rockets. */
native int TFDB_GetRocketCount();

/** Gets the spawn timestamp of a rocket. */
native float TFDB_GetLastSpawnTime(int iIndex);

/** Gets the number of bounces for a rocket. */
native int TFDB_GetRocketBounces(int iIndex);

/** Sets the number of bounces for a rocket. */
native void TFDB_SetRocketBounces(int iIndex, int iBounces);

// ============ Rocket Class Strings & Sounds ============

/** Gets the short name of a rocket class. */
native void TFDB_GetRocketClassName(int iClass, char[] strBuffer, int iMaxLen);

/** Sets the short name of a rocket class. */
native void TFDB_SetRocketClassName(int iClass, const char[] strName);

/** Gets the display name of a rocket class. */
native void TFDB_GetRocketClassLongName(int iClass, char[] strBuffer, int iMaxLen);

/** Sets the display name of a rocket class. */
native void TFDB_SetRocketClassLongName(int iClass, const char[] strName);

/** Gets the model path of a rocket class. */
native void TFDB_GetRocketClassModel(int iClass, char[] strBuffer, int iMaxLen);

/** Sets the model path of a rocket class. */
native void TFDB_SetRocketClassModel(int iClass, const char[] strPath);

/** Gets the beep sound interval (seconds). */
native float TFDB_GetRocketClassBeepInterval(int iClass);

/** Sets the beep sound interval (seconds). */
native void TFDB_SetRocketClassBeepInterval(int iClass, float fInterval);

/** Gets the spawn sound path. */
native void TFDB_GetRocketClassSpawnSound(int iClass, char[] strBuffer, int iMaxLen);

/** Sets the spawn sound path. */
native void TFDB_SetRocketClassSpawnSound(int iClass, const char[] strPath);

/** Gets the beep sound path. */
native void TFDB_GetRocketClassBeepSound(int iClass, char[] strBuffer, int iMaxLen);

/** Sets the beep sound path. */
native void TFDB_SetRocketClassBeepSound(int iClass, const char[] strPath);

/** Gets the alert sound path. */
native void TFDB_GetRocketClassAlertSound(int iClass, char[] strBuffer, int iMaxLen);

/** Sets the alert sound path. */
native void TFDB_SetRocketClassAlertSound(int iClass, const char[] strPath);

/** Gets the critical hit chance (0.0 to 1.0). */
native float TFDB_GetRocketClassCritChance(int iClass);

/** Sets the critical hit chance (0.0 to 1.0). */
native void TFDB_SetRocketClassCritChance(int iClass, float fChance);

/** Gets the target weight for target selection. */
native float TFDB_GetRocketClassTargetWeight(int iClass);

/** Sets the target weight for target selection. */
native void TFDB_SetRocketClassTargetWeight(int iClass, float fWeight);

// ============ Command Handlers ============

/**
 * Gets the commands to execute on rocket spawn.
 * @note You MUST call delete on the returned DataPack Handle when finished, or your plugin will leak memory.
 */
native DataPack TFDB_GetRocketClassCmdsOnSpawn(int iClass);

/** Sets the commands to execute on rocket spawn. */
native void TFDB_SetRocketClassCmdsOnSpawn(int iClass, DataPack hCmds);

/**
 * Gets the commands to execute on deflection.
 * @note You MUST call delete on the returned DataPack Handle when finished, or your plugin will leak memory.
 */
native DataPack TFDB_GetRocketClassCmdsOnDeflect(int iClass);

/** Sets the commands to execute on deflection. */
native void TFDB_SetRocketClassCmdsOnDeflect(int iClass, DataPack hCmds);

/**
 * Gets the commands to execute when rocket kills a player.
 * @note You MUST call delete on the returned DataPack Handle when finished, or your plugin will leak memory.
 */
native DataPack TFDB_GetRocketClassCmdsOnKill(int iClass);

/** Sets the commands to execute when rocket kills a player. */
native void TFDB_SetRocketClassCmdsOnKill(int iClass, DataPack hCmds);

/**
 * Gets the commands to execute when rocket explodes.
 * @note You MUST call delete on the returned DataPack Handle when finished, or your plugin will leak memory.
 */
native DataPack TFDB_GetRocketClassCmdsOnExplode(int iClass);

/** Sets the commands to execute when rocket explodes. */
native void TFDB_SetRocketClassCmdsOnExplode(int iClass, DataPack hCmds);

/**
 * Gets the commands to execute when rocket has no target.
 * @note You MUST call delete on the returned DataPack Handle when finished, or your plugin will leak memory.
 */
native DataPack TFDB_GetRocketClassCmdsOnNoTarget(int iClass);

/** Sets the commands to execute when rocket has no target. */
native void TFDB_SetRocketClassCmdsOnNoTarget(int iClass, DataPack hCmds);

/** Gets the bounce velocity scale factor. */
native float TFDB_GetRocketClassBounceScale(int iClass);

/** Sets the bounce velocity scale factor. */
native void TFDB_SetRocketClassBounceScale(int iClass, float fScale);

// ============ Actions ============

/**
 * Creates and spawns a new rocket.
 *
 * @param iSpawnerEntity    The spawner entity to spawn from.
 * @param iSpawnerClass     The spawner class index.
 * @param iTeam             The team the rocket belongs to.
 * @param iClass            Optional rocket class (-1 for random from spawner chances).
 */
native void TFDB_CreateRocket(int iSpawnerEntity, int iSpawnerClass, int iTeam, int iClass = -1);

/** Destroys a single rocket by index. */
native void TFDB_DestroyRocket(int iIndex);

/** Destroys all active rockets. */
native void TFDB_DestroyRockets();

/** Clears all rocket class definitions. */
native void TFDB_DestroyRocketClasses();

/** Clears all spawner class definitions. */
native void TFDB_DestroySpawners();

/**
 * Parses a configuration file and loads rocket/spawner classes.
 *
 * @param strConfigFile     Config file name in configs/dodgeball/ (default: "general.cfg")
 */
native void TFDB_ParseConfigurations(const char[] strConfigFile = "general.cfg");

/** Populates spawn points from the current map. */
native void TFDB_PopulateSpawnPoints();

/** Runs the homing rocket think logic for a rocket. */
native void TFDB_HomingRocketThink(int iIndex);

/** Runs the legacy homing rocket think logic for a rocket. */
native void TFDB_RocketLegacyThink(int iIndex);

/** Gets the state flags of a rocket. */
native RocketState TFDB_GetRocketState(int iIndex);

/** Sets the state flags of a rocket. */
native void TFDB_SetRocketState(int iIndex, RocketState iState);

/**
 * Gets steal info for a client.
 *
 * @param iClient   Client index.
 * @param stole     Output: whether client stole a rocket this round.
 * @param count     Output: number of rockets stolen this round.
 */
native void TFDB_GetStealInfo(int iClient, bool &stole, int &count);

/**
 * Sets steal info for a client.
 *
 * @param iClient   Client index.
 * @param stole     Whether client stole a rocket.
 * @param count     Number of rockets stolen.
 */
native void TFDB_SetStealInfo(int iClient, bool stole, int count);

// ============ Preset Functions ============

/**
 * Gets the number of loaded presets.
 *
 * @return          Number of presets (0 if none loaded or presets.cfg missing).
 */
native int TFDB_GetPresetCount();

/**
 * Gets the display name of a preset.
 *
 * @param iPreset   Preset index (0 to TFDB_GetPresetCount()-1).
 * @param buffer    Buffer to store the name.
 * @param maxlen    Maximum buffer length.
 */
native void TFDB_GetPresetName(int iPreset, char[] buffer, int maxlen);

/**
 * Applies a preset: destroys active rockets, sets spawner max rockets,
 * spawn interval, and chances table to 100% the preset's rocket class.
 *
 * @param iPreset   Preset index (0 to TFDB_GetPresetCount()-1).
 * @return          True if applied successfully, false if invalid preset or class not found.
 */
native bool TFDB_ApplyPreset(int iPreset);

public SharedPlugin __pl_TFDB =
{
	name = "tfdb",
	file = "TF2Dodgeball.smx",
	
	#if defined REQUIRE_PLUGIN
		required=1,
	#else
		required=0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_TFDB_SetNTVOptional()
{
	MarkNativeAsOptional("TFDB_IsValidRocket");
	MarkNativeAsOptional("TFDB_FindRocketByEntity");
	MarkNativeAsOptional("TFDB_IsDodgeballEnabled");
	MarkNativeAsOptional("TFDB_GetRocketEntity");
	MarkNativeAsOptional("TFDB_GetRocketFlags");
	MarkNativeAsOptional("TFDB_SetRocketFlags");
	MarkNativeAsOptional("TFDB_GetRocketTarget");
	MarkNativeAsOptional("TFDB_SetRocketTarget");
	MarkNativeAsOptional("TFDB_GetRocketEventDeflections");
	MarkNativeAsOptional("TFDB_SetRocketEventDeflections");
	MarkNativeAsOptional("TFDB_GetRocketDeflections");
	MarkNativeAsOptional("TFDB_SetRocketDeflections");
	MarkNativeAsOptional("TFDB_GetRocketClass");
	MarkNativeAsOptional("TFDB_SetRocketClass");
	MarkNativeAsOptional("TFDB_GetRocketClassCount");
	MarkNativeAsOptional("TFDB_GetRocketClassBehaviour");
	MarkNativeAsOptional("TFDB_SetRocketClassBehaviour");
	MarkNativeAsOptional("TFDB_GetRocketClassFlags");
	MarkNativeAsOptional("TFDB_SetRocketClassFlags");
	MarkNativeAsOptional("TFDB_GetRocketClassDamage");
	MarkNativeAsOptional("TFDB_SetRocketClassDamage");
	MarkNativeAsOptional("TFDB_GetRocketClassDamageIncrement");
	MarkNativeAsOptional("TFDB_SetRocketClassDamageIncrement");
	MarkNativeAsOptional("TFDB_GetRocketClassSpeed");
	MarkNativeAsOptional("TFDB_SetRocketClassSpeed");
	MarkNativeAsOptional("TFDB_GetRocketClassSpeedIncrement");
	MarkNativeAsOptional("TFDB_SetRocketClassSpeedIncrement");
	MarkNativeAsOptional("TFDB_GetRocketClassSpeedLimit");
	MarkNativeAsOptional("TFDB_SetRocketClassSpeedLimit");
	MarkNativeAsOptional("TFDB_GetRocketClassTurnRate");
	MarkNativeAsOptional("TFDB_SetRocketClassTurnRate");
	MarkNativeAsOptional("TFDB_GetRocketClassTurnRateIncrement");
	MarkNativeAsOptional("TFDB_SetRocketClassTurnRateIncrement");
	MarkNativeAsOptional("TFDB_GetRocketClassTurnRateLimit");
	MarkNativeAsOptional("TFDB_SetRocketClassTurnRateLimit");
	MarkNativeAsOptional("TFDB_GetRocketClassElevationRate");
	MarkNativeAsOptional("TFDB_SetRocketClassElevationRate");
	MarkNativeAsOptional("TFDB_GetRocketClassElevationLimit");
	MarkNativeAsOptional("TFDB_SetRocketClassElevationLimit");
	MarkNativeAsOptional("TFDB_GetRocketClassRocketsModifier");
	MarkNativeAsOptional("TFDB_SetRocketClassRocketsModifier");
	MarkNativeAsOptional("TFDB_GetRocketClassPlayerModifier");
	MarkNativeAsOptional("TFDB_SetRocketClassPlayerModifier");
	MarkNativeAsOptional("TFDB_GetRocketClassControlDelay");
	MarkNativeAsOptional("TFDB_SetRocketClassControlDelay");
	MarkNativeAsOptional("TFDB_SetRocketClassCount");
	MarkNativeAsOptional("TFDB_SetRocketEntity");
	MarkNativeAsOptional("TFDB_GetRocketClassMaxBounces");
	MarkNativeAsOptional("TFDB_SetRocketClassMaxBounces");
	MarkNativeAsOptional("TFDB_GetSpawnersName");
	MarkNativeAsOptional("TFDB_SetSpawnersName");
	MarkNativeAsOptional("TFDB_GetSpawnersMaxRockets");
	MarkNativeAsOptional("TFDB_SetSpawnersMaxRockets");
	MarkNativeAsOptional("TFDB_GetSpawnersInterval");
	MarkNativeAsOptional("TFDB_SetSpawnersInterval");
	MarkNativeAsOptional("TFDB_GetSpawnersChancesTable");
	MarkNativeAsOptional("TFDB_SetSpawnersChancesTable");
	MarkNativeAsOptional("TFDB_GetSpawnersCount");
	MarkNativeAsOptional("TFDB_SetSpawnersCount");
	MarkNativeAsOptional("TFDB_GetCurrentRedSpawn");
	MarkNativeAsOptional("TFDB_SetCurrentRedSpawn");
	MarkNativeAsOptional("TFDB_GetSpawnPointsRedCount");
	MarkNativeAsOptional("TFDB_SetSpawnPointsRedCount");
	MarkNativeAsOptional("TFDB_GetSpawnPointsRedClass");
	MarkNativeAsOptional("TFDB_SetSpawnPointsRedClass");
	MarkNativeAsOptional("TFDB_GetSpawnPointsRedEntity");
	MarkNativeAsOptional("TFDB_SetSpawnPointsRedEntity");
	MarkNativeAsOptional("TFDB_GetCurrentBluSpawn");
	MarkNativeAsOptional("TFDB_SetCurrentBluSpawn");
	MarkNativeAsOptional("TFDB_GetSpawnPointsBluCount");
	MarkNativeAsOptional("TFDB_SetSpawnPointsBluCount");
	MarkNativeAsOptional("TFDB_GetSpawnPointsBluClass");
	MarkNativeAsOptional("TFDB_SetSpawnPointsBluClass");
	MarkNativeAsOptional("TFDB_GetSpawnPointsBluEntity");
	MarkNativeAsOptional("TFDB_SetSpawnPointsBluEntity");
	MarkNativeAsOptional("TFDB_GetRoundStarted");
	MarkNativeAsOptional("TFDB_GetRoundCount");
	MarkNativeAsOptional("TFDB_GetRocketsFired");
	MarkNativeAsOptional("TFDB_GetNextSpawnTime");
	MarkNativeAsOptional("TFDB_SetNextSpawnTime");
	MarkNativeAsOptional("TFDB_GetLastDeadTeam");
	MarkNativeAsOptional("TFDB_GetLastDeadClient");
	MarkNativeAsOptional("TFDB_GetLastStealer");
	MarkNativeAsOptional("TFDB_GetRocketSpeed");
	MarkNativeAsOptional("TFDB_SetRocketSpeed");
	MarkNativeAsOptional("TFDB_GetRocketMphSpeed");
	MarkNativeAsOptional("TFDB_SetRocketMphSpeed");
	MarkNativeAsOptional("TFDB_GetRocketDirection");
	MarkNativeAsOptional("TFDB_SetRocketDirection");
	MarkNativeAsOptional("TFDB_GetRocketLastDeflectionTime");
	MarkNativeAsOptional("TFDB_SetRocketLastDeflectionTime");
	MarkNativeAsOptional("TFDB_GetRocketLastBeepTime");
	MarkNativeAsOptional("TFDB_SetRocketLastBeepTime");
	MarkNativeAsOptional("TFDB_GetRocketCount");
	MarkNativeAsOptional("TFDB_GetLastSpawnTime");
	MarkNativeAsOptional("TFDB_GetRocketBounces");
	MarkNativeAsOptional("TFDB_SetRocketBounces");
	MarkNativeAsOptional("TFDB_GetRocketClassName");
	MarkNativeAsOptional("TFDB_SetRocketClassName");
	MarkNativeAsOptional("TFDB_GetRocketClassLongName");
	MarkNativeAsOptional("TFDB_SetRocketClassLongName");
	MarkNativeAsOptional("TFDB_GetRocketClassModel");
	MarkNativeAsOptional("TFDB_SetRocketClassModel");
	MarkNativeAsOptional("TFDB_GetRocketClassBeepInterval");
	MarkNativeAsOptional("TFDB_SetRocketClassBeepInterval");
	MarkNativeAsOptional("TFDB_GetRocketClassSpawnSound");
	MarkNativeAsOptional("TFDB_SetRocketClassSpawnSound");
	MarkNativeAsOptional("TFDB_GetRocketClassBeepSound");
	MarkNativeAsOptional("TFDB_SetRocketClassBeepSound");
	MarkNativeAsOptional("TFDB_GetRocketClassAlertSound");
	MarkNativeAsOptional("TFDB_SetRocketClassAlertSound");
	MarkNativeAsOptional("TFDB_GetRocketClassCritChance");
	MarkNativeAsOptional("TFDB_SetRocketClassCritChance");
	MarkNativeAsOptional("TFDB_GetRocketClassTargetWeight");
	MarkNativeAsOptional("TFDB_SetRocketClassTargetWeight");
	MarkNativeAsOptional("TFDB_GetRocketClassCmdsOnSpawn");
	MarkNativeAsOptional("TFDB_SetRocketClassCmdsOnSpawn");
	MarkNativeAsOptional("TFDB_GetRocketClassCmdsOnDeflect");
	MarkNativeAsOptional("TFDB_SetRocketClassCmdsOnDeflect");
	MarkNativeAsOptional("TFDB_GetRocketClassCmdsOnKill");
	MarkNativeAsOptional("TFDB_SetRocketClassCmdsOnKill");
	MarkNativeAsOptional("TFDB_GetRocketClassCmdsOnExplode");
	MarkNativeAsOptional("TFDB_SetRocketClassCmdsOnExplode");
	MarkNativeAsOptional("TFDB_GetRocketClassCmdsOnNoTarget");
	MarkNativeAsOptional("TFDB_SetRocketClassCmdsOnNoTarget");
	MarkNativeAsOptional("TFDB_GetRocketClassBounceScale");
	MarkNativeAsOptional("TFDB_SetRocketClassBounceScale");
	MarkNativeAsOptional("TFDB_CreateRocket");
	MarkNativeAsOptional("TFDB_DestroyRocket");
	MarkNativeAsOptional("TFDB_DestroyRockets");
	MarkNativeAsOptional("TFDB_DestroyRocketClasses");
	MarkNativeAsOptional("TFDB_DestroySpawners");
	MarkNativeAsOptional("TFDB_ParseConfigurations");
	MarkNativeAsOptional("TFDB_PopulateSpawnPoints");
	MarkNativeAsOptional("TFDB_HomingRocketThink");
	MarkNativeAsOptional("TFDB_RocketLegacyThink");
	MarkNativeAsOptional("TFDB_GetRocketState");
	MarkNativeAsOptional("TFDB_SetRocketState");
	MarkNativeAsOptional("TFDB_GetStealInfo");
	MarkNativeAsOptional("TFDB_SetStealInfo");
	MarkNativeAsOptional("TFDB_GetPresetCount");
	MarkNativeAsOptional("TFDB_GetPresetName");
	MarkNativeAsOptional("TFDB_ApplyPreset");
}
#endif