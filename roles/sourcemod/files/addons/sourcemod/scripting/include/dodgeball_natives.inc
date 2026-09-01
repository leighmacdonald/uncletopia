#if defined _dodgeball_natives_included
  #endinput
#endif
#define _dodgeball_natives_included

/**
 * Implements the native functions exposed by the TF2 Dodgeball plugin.
 * These natives allow other plugins to interact with and control the gamemode.
 *
 * Most get/set natives follow the same pattern: fetch the array index from
 * native cell 1, read or write the corresponding slot. The macros below
 * generate the boilerplate. Use them for simple primitive (int/float/any)
 * arrays indexed by a single int key.
 *
 * For non-primitive types (ent-refs, vectors, strings, DataPacks, handles)
 * or for natives with custom logic, write the handler out explicitly.
 */

// Generate a getter that returns Field[GetNativeCell(1)].
// Uses view_as<any> so float arrays work without a separate macro.
// Bounds-check the rocket index — third-party subplugins that forget to call
// IsValidRocket() first would otherwise read/write adjacent memory and crash
// core. ThrowNativeError raises a script exception in the calling subplugin
// instead of corrupting our state. (Audit finding 2026-04-28.)
//
// All TFDB rocket-instance arrays are sized [MAX_ROCKETS] (see dodgeball.sp).
// Class arrays use a separate set of natives that have their own bounds path.
//
// Example: TFDB_NATIVE_GET(Native_GetRocketSpeed, RocketSpeed)
#define TFDB_NATIVE_GET(%1,%2) \
	public any %1(Handle plugin, int numParams) { \
		int idx = GetNativeCell(1); \
		if (idx < 0 || idx >= MAX_ROCKETS) return ThrowNativeError(SP_ERROR_PARAM, "Rocket index %d out of range [0..%d)", idx, MAX_ROCKETS); \
		return view_as<any>(%2[idx]); \
	}

// Generate a setter that writes GetNativeCell(2) into Field[GetNativeCell(1)].
// Example: TFDB_NATIVE_SET(Native_SetRocketSpeed, RocketSpeed)
#define TFDB_NATIVE_SET(%1,%2) \
	public any %1(Handle plugin, int numParams) { \
		int idx = GetNativeCell(1); \
		if (idx < 0 || idx >= MAX_ROCKETS) return ThrowNativeError(SP_ERROR_PARAM, "Rocket index %d out of range [0..%d)", idx, MAX_ROCKETS); \
		%2[idx] = GetNativeCell(2); \
		return 0; \
	}

// Setter with an enum cast (for typed-enum arrays like RocketInstanceFlags).
// Example: TFDB_NATIVE_SET_CAST(Native_SetRocketFlags, RocketInstanceFlags, RocketFlags)
#define TFDB_NATIVE_SET_CAST(%1,%2,%3) \
	public any %1(Handle plugin, int numParams) { \
		int idx = GetNativeCell(1); \
		if (idx < 0 || idx >= MAX_ROCKETS) return ThrowNativeError(SP_ERROR_PARAM, "Rocket index %d out of range [0..%d)", idx, MAX_ROCKETS); \
		%2[idx] = view_as<%3>(GetNativeCell(2)); \
		return 0; \
	}

// *********************************************************************************
// NATIVES - GENERAL & STATE
// *********************************************************************************

public any Native_IsValidRocket(Handle plugin, int numParams) {
	return IsValidRocket(GetNativeCell(1));
}

public any Native_FindRocketByEntity(Handle plugin, int numParams) {
	return FindRocketByEntity(GetNativeCell(1));
}

public any Native_IsDodgeballEnabled(Handle plugin, int numParams) {
	return Enabled;
}

// *********************************************************************************
// NATIVES - ROCKET GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRocketEntity(Handle plugin, int numParams) {
	return EntRefToEntIndex(RocketEntity[GetNativeCell(1)]);
}

public any Native_SetRocketEntity(Handle plugin, int numParams) {
	RocketEntity[GetNativeCell(1)] = EntIndexToEntRef(GetNativeCell(2));
	return 0;
}

TFDB_NATIVE_GET(     Native_GetRocketFlags,              RocketInstanceFlags)
TFDB_NATIVE_SET_CAST(Native_SetRocketFlags,              RocketInstanceFlags, RocketFlags)

// Ent-ref round-trip — kept explicit because of the EntIndexToEntRef wrapping.
public any Native_GetRocketTarget(Handle plugin, int numParams) {
	return EntRefToEntIndex(RocketTarget[GetNativeCell(1)]);
}
public any Native_SetRocketTarget(Handle plugin, int numParams) {
	RocketTarget[GetNativeCell(1)] = EntIndexToEntRef(GetNativeCell(2));
	return 0;
}

// Derived — owner is read from an entity prop, not a rocket-class array.
public any Native_GetRocketOwner(Handle plugin, int numParams) {
	int index = GetNativeCell(1);
	if (!RocketIsValid[index]) return -1;
	int entity = EntRefToEntIndex(RocketEntity[index]);
	if (entity == -1) return -1;
	return GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
}

TFDB_NATIVE_GET(Native_GetRocketEventDeflections,    RocketEventDeflections)
TFDB_NATIVE_SET(Native_SetRocketEventDeflections,    RocketEventDeflections)
TFDB_NATIVE_GET(Native_GetRocketDeflections,         RocketDeflections)
TFDB_NATIVE_SET(Native_SetRocketDeflections,         RocketDeflections)
TFDB_NATIVE_GET(Native_GetRocketClass,               RocketClass)
TFDB_NATIVE_SET(Native_SetRocketClass,               RocketClass)
TFDB_NATIVE_GET(Native_GetRocketSpeed,               RocketSpeed)
TFDB_NATIVE_SET(Native_SetRocketSpeed,               RocketSpeed)
TFDB_NATIVE_GET(Native_GetRocketMphSpeed,            RocketMphSpeed)
TFDB_NATIVE_SET(Native_SetRocketMphSpeed,            RocketMphSpeed)

// Vector get/set — needs SetNativeArray / GetNativeArray. Kept explicit.
public any Native_GetRocketDirection(Handle plugin, int numParams) {
	SetNativeArray(2, RocketDirection[GetNativeCell(1)], 3);
	return 0;
}
public any Native_SetRocketDirection(Handle plugin, int numParams) {
	float direction[3];
	GetNativeArray(2, direction, sizeof(direction));
	CopyVectors(direction, RocketDirection[GetNativeCell(1)]);
	return 0;
}

TFDB_NATIVE_GET(Native_GetRocketLastDeflectionTime,  RocketLastDeflectionTime)
TFDB_NATIVE_SET(Native_SetRocketLastDeflectionTime,  RocketLastDeflectionTime)
TFDB_NATIVE_GET(Native_GetRocketLastBeepTime,        RocketLastBeepTime)
TFDB_NATIVE_SET(Native_SetRocketLastBeepTime,        RocketLastBeepTime)

// Global counter — not array-indexed, so the macros don't apply.
public any Native_GetRocketCount(Handle plugin, int numParams) {
	return RocketCount;
}

TFDB_NATIVE_GET(Native_GetLastSpawnTime,             LastSpawnTime)

public any Native_GetRocketBounces(Handle plugin, int numParams) {
	return RocketBounces[GetNativeCell(1)];
}

public any Native_SetRocketBounces(Handle plugin, int numParams) {
	RocketBounces[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketState(Handle plugin, int numParams) {
	return RocketInstanceState[GetNativeCell(1)];
}

public any Native_SetRocketState(Handle plugin, int numParams) {
	Internal_SetRocketState(GetNativeCell(1), view_as<RocketState>(GetNativeCell(2)));
	return 0;
}

// *********************************************************************************
// NATIVES - ROCKET CLASS GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRocketClassCount(Handle plugin, int numParams) {
	return RocketClassCount;
}

public any Native_SetRocketClassCount(Handle plugin, int numParams) {
	RocketClassCount = GetNativeCell(1);
	return 0;
}

TFDB_NATIVE_GET(     Native_GetRocketClassBehaviour,        RocketClassBehaviour)
TFDB_NATIVE_SET_CAST(Native_SetRocketClassBehaviour,        RocketClassBehaviour, BehaviourTypes)
TFDB_NATIVE_GET(     Native_GetRocketClassFlags,            RocketClassFlags)
TFDB_NATIVE_SET_CAST(Native_SetRocketClassFlags,            RocketClassFlags, RocketFlags)

TFDB_NATIVE_GET(Native_GetRocketClassDamage,                RocketClassDamage)
TFDB_NATIVE_SET(Native_SetRocketClassDamage,                RocketClassDamage)
TFDB_NATIVE_GET(Native_GetRocketClassDamageIncrement,       RocketClassDamageIncrement)
TFDB_NATIVE_SET(Native_SetRocketClassDamageIncrement,       RocketClassDamageIncrement)
TFDB_NATIVE_GET(Native_GetRocketClassSpeed,                 RocketClassSpeed)
TFDB_NATIVE_SET(Native_SetRocketClassSpeed,                 RocketClassSpeed)
TFDB_NATIVE_GET(Native_GetRocketClassSpeedIncrement,        RocketClassSpeedIncrement)
TFDB_NATIVE_SET(Native_SetRocketClassSpeedIncrement,        RocketClassSpeedIncrement)
TFDB_NATIVE_GET(Native_GetRocketClassSpeedLimit,            RocketClassSpeedLimit)
TFDB_NATIVE_SET(Native_SetRocketClassSpeedLimit,            RocketClassSpeedLimit)
TFDB_NATIVE_GET(Native_GetRocketClassTurnRate,              RocketClassTurnRate)
TFDB_NATIVE_SET(Native_SetRocketClassTurnRate,              RocketClassTurnRate)
TFDB_NATIVE_GET(Native_GetRocketClassTurnRateIncrement,     RocketClassTurnRateIncrement)
TFDB_NATIVE_SET(Native_SetRocketClassTurnRateIncrement,     RocketClassTurnRateIncrement)
TFDB_NATIVE_GET(Native_GetRocketClassTurnRateLimit,         RocketClassTurnRateLimit)
TFDB_NATIVE_SET(Native_SetRocketClassTurnRateLimit,         RocketClassTurnRateLimit)
TFDB_NATIVE_GET(Native_GetRocketClassElevationRate,         RocketClassElevationRate)
TFDB_NATIVE_SET(Native_SetRocketClassElevationRate,         RocketClassElevationRate)
TFDB_NATIVE_GET(Native_GetRocketClassElevationLimit,        RocketClassElevationLimit)
TFDB_NATIVE_SET(Native_SetRocketClassElevationLimit,        RocketClassElevationLimit)
TFDB_NATIVE_GET(Native_GetRocketClassRocketsModifier,       RocketClassRocketsModifier)
TFDB_NATIVE_SET(Native_SetRocketClassRocketsModifier,       RocketClassRocketsModifier)
TFDB_NATIVE_GET(Native_GetRocketClassPlayerModifier,        RocketClassPlayerModifier)
TFDB_NATIVE_SET(Native_SetRocketClassPlayerModifier,        RocketClassPlayerModifier)
TFDB_NATIVE_GET(Native_GetRocketClassControlDelay,          RocketClassControlDelay)
TFDB_NATIVE_SET(Native_SetRocketClassControlDelay,          RocketClassControlDelay)
TFDB_NATIVE_GET(Native_GetRocketClassMaxBounces,            RocketClassMaxBounces)
TFDB_NATIVE_SET(Native_SetRocketClassMaxBounces,            RocketClassMaxBounces)

public any Native_GetRocketClassName(Handle plugin, int numParams) {
	SetNativeString(2, RocketClassName[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassName(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int maxLen;
	GetNativeStringLength(2, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(2, buffer, maxLen + 1);
	strcopy(RocketClassName[rocketClass], sizeof(RocketClassName[]), buffer);
	return 0;
}

public any Native_GetRocketClassLongName(Handle plugin, int numParams) {
	SetNativeString(2, RocketClassLongName[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassLongName(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int maxLen;
	GetNativeStringLength(2, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(2, buffer, maxLen + 1);
	strcopy(RocketClassLongName[rocketClass], sizeof(RocketClassLongName[]), buffer);
	return 0;
}

public any Native_GetRocketClassModel(Handle plugin, int numParams) {
	SetNativeString(2, RocketClassModel[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassModel(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int maxLen;
	GetNativeStringLength(2, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(2, buffer, maxLen + 1);
	strcopy(RocketClassModel[rocketClass], sizeof(RocketClassModel[]), buffer);
	return 0;
}

TFDB_NATIVE_GET(Native_GetRocketClassBeepInterval,          RocketClassBeepInterval)
TFDB_NATIVE_SET(Native_SetRocketClassBeepInterval,          RocketClassBeepInterval)

public any Native_GetRocketClassSpawnSound(Handle plugin, int numParams) {
	SetNativeString(2, RocketClassSpawnSound[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassSpawnSound(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int maxLen;
	GetNativeStringLength(2, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(2, buffer, maxLen + 1);
	strcopy(RocketClassSpawnSound[rocketClass], sizeof(RocketClassSpawnSound[]), buffer);
	return 0;
}

public any Native_GetRocketClassBeepSound(Handle plugin, int numParams) {
	SetNativeString(2, RocketClassBeepSound[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassBeepSound(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int maxLen;
	GetNativeStringLength(2, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(2, buffer, maxLen + 1);
	strcopy(RocketClassBeepSound[rocketClass], sizeof(RocketClassBeepSound[]), buffer);
	return 0;
}

public any Native_GetRocketClassAlertSound(Handle plugin, int numParams) {
	SetNativeString(2, RocketClassAlertSound[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassAlertSound(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int maxLen;
	GetNativeStringLength(2, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(2, buffer, maxLen + 1);
	strcopy(RocketClassAlertSound[rocketClass], sizeof(RocketClassAlertSound[]), buffer);
	return 0;
}

TFDB_NATIVE_GET(Native_GetRocketClassCritChance,            RocketClassCritChance)
TFDB_NATIVE_SET(Native_SetRocketClassCritChance,            RocketClassCritChance)
TFDB_NATIVE_GET(Native_GetRocketClassTargetWeight,          RocketClassTargetWeight)
TFDB_NATIVE_SET(Native_SetRocketClassTargetWeight,          RocketClassTargetWeight)
TFDB_NATIVE_GET(Native_GetRocketClassOrbitTightness,        RocketClassOrbitTightness)
TFDB_NATIVE_SET(Native_SetRocketClassOrbitTightness,        RocketClassOrbitTightness)
TFDB_NATIVE_GET(Native_GetRocketClassMaxSpeed,              RocketClassMaxSpeed)
TFDB_NATIVE_SET(Native_SetRocketClassMaxSpeed,              RocketClassMaxSpeed)
TFDB_NATIVE_GET(Native_GetRocketClassMaxDeflections,        RocketClassMaxDeflections)
TFDB_NATIVE_SET(Native_SetRocketClassMaxDeflections,        RocketClassMaxDeflections)
TFDB_NATIVE_GET(Native_GetRocketClassBounceCeiling,         RocketClassBounceCeiling)
TFDB_NATIVE_SET(Native_SetRocketClassBounceCeiling,         RocketClassBounceCeiling)
TFDB_NATIVE_GET(Native_GetRocketClassCritGlowStack,         RocketClassCritGlowStack)
TFDB_NATIVE_SET(Native_SetRocketClassCritGlowStack,         RocketClassCritGlowStack)

/**
 * TFDB_GetRocketClassCritGlowParticle(int iClass, int iTeam, char[] strBuffer, int iMaxLen)
 *
 * Reads the per-class crit glow particle name for a given team. Returns the
 * stored override (set in cfg or via the setter); empty string means "use
 * the engine default" — the caller can fall back to "critical_rocket_red" /
 * "critical_rocket_blue" / "eyeboss_projectile" as appropriate.
 *
 * iTeam values: 2 = TFTeam_Red, 3 = TFTeam_Blue, 0 = neutral (any other value
 * also routed to neutral).
 */
public any Native_GetRocketClassCritGlowParticle(Handle plugin, int numParams) {
	int iClass = GetNativeCell(1);
	int iTeam  = GetNativeCell(2);
	int maxLen = GetNativeCell(4);
	if (iClass < 0 || iClass >= MAX_ROCKET_CLASSES) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid rocket class index %d", iClass);

	if      (iTeam == view_as<int>(TFTeam_Red))   SetNativeString(3, RocketClassCritGlowParticleRed[iClass],     maxLen);
	else if (iTeam == view_as<int>(TFTeam_Blue))  SetNativeString(3, RocketClassCritGlowParticleBlue[iClass],    maxLen);
	else                                          SetNativeString(3, RocketClassCritGlowParticleNeutral[iClass], maxLen);
	return 0;
}

/**
 * TFDB_SetRocketClassCritGlowParticle(int iClass, int iTeam, const char[] strBuffer)
 *
 * Sets the per-class crit glow particle name for a given team. Empty string
 * restores the engine default. Takes effect on the NEXT rocket spawn (existing
 * rockets keep the particle they were spawned with).
 */
public any Native_SetRocketClassCritGlowParticle(Handle plugin, int numParams) {
	int iClass = GetNativeCell(1);
	int iTeam  = GetNativeCell(2);
	if (iClass < 0 || iClass >= MAX_ROCKET_CLASSES) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid rocket class index %d", iClass);

	char buffer[32];
	GetNativeString(3, buffer, sizeof(buffer));

	if      (iTeam == view_as<int>(TFTeam_Red))   strcopy(RocketClassCritGlowParticleRed[iClass],     32, buffer);
	else if (iTeam == view_as<int>(TFTeam_Blue))  strcopy(RocketClassCritGlowParticleBlue[iClass],    32, buffer);
	else                                          strcopy(RocketClassCritGlowParticleNeutral[iClass], 32, buffer);
	return 0;
}

public any Native_GetRocketClassSteeringControl(Handle plugin, int numParams) {
	return RocketClassSteeringControl[GetNativeCell(1)];
}

public any Native_SetRocketClassSteeringControl(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int ticks = GetNativeCell(2);
	if (ticks < 0) ticks = 0;
	RocketClassSteeringControl[rocketClass] = ticks;
	return 0;
}

public any Native_GetRocketClassBounceControl(Handle plugin, int numParams) {
	return RocketClassBounceControl[GetNativeCell(1)];
}

public any Native_SetRocketClassBounceControl(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	int ticks = GetNativeCell(2);
	if (ticks < 0) ticks = 0;
	RocketClassBounceControl[rocketClass] = ticks;
	return 0;
}

public any Native_GetRocketClassThinkInterval(Handle plugin, int numParams) {
	return view_as<any>(RocketClassThinkInterval[GetNativeCell(1)]);
}

public any Native_SetRocketClassThinkInterval(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	float seconds = view_as<float>(GetNativeCell(2));
	if (seconds < 0.0) seconds = 0.0;
	RocketClassThinkInterval[rocketClass] = seconds;
	return 0;
}

// *********************************************************************************
// NATIVES - SPAWNER GETTERS/SETTERS
// *********************************************************************************

public any Native_GetSpawnersName(Handle plugin, int numParams) {
	SetNativeString(2, SpawnersName[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetSpawnersName(Handle plugin, int numParams) {
	int spawnerClass = GetNativeCell(1);
	int maxLen;
	GetNativeStringLength(2, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(2, buffer, maxLen + 1);
	strcopy(SpawnersName[spawnerClass], sizeof(SpawnersName[]), buffer);
	return 0;
}

TFDB_NATIVE_GET(Native_GetSpawnersMaxRockets, SpawnersMaxRockets)
TFDB_NATIVE_SET(Native_SetSpawnersMaxRockets, SpawnersMaxRockets)
TFDB_NATIVE_GET(Native_GetSpawnersInterval,   SpawnersInterval)
TFDB_NATIVE_SET(Native_SetSpawnersInterval,   SpawnersInterval)

public any Native_GetSpawnersChancesTable(Handle plugin, int numParams) {
	return CloneHandle(SpawnersChancesTable[GetNativeCell(1)], plugin);
}

public any Native_SetSpawnersChancesTable(Handle plugin, int numParams) {
	int spawnerClass = GetNativeCell(1);
	ArrayList table = view_as<ArrayList>(GetNativeCell(2));
	ArrayList clonedTable = view_as<ArrayList>(CloneHandle(table, GetMyHandle()));
	delete SpawnersChancesTable[spawnerClass];
	SpawnersChancesTable[spawnerClass] = clonedTable;
	return 0;
}

public any Native_GetSpawnersCount(Handle plugin, int numParams) {
	return SpawnersCount;
}

public any Native_SetSpawnersCount(Handle plugin, int numParams) {
	SpawnersCount = GetNativeCell(1);
	return 0;
}

// *********************************************************************************
// NATIVES - SPAWN POINT GETTERS/SETTERS
// *********************************************************************************

public any Native_GetCurrentRedSpawn(Handle plugin, int numParams) {
	return CurrentRedSpawn;
}

public any Native_SetCurrentRedSpawn(Handle plugin, int numParams) {
	CurrentRedSpawn = GetNativeCell(1);
	return 0;
}

public any Native_GetSpawnPointsRedCount(Handle plugin, int numParams) {
	return SpawnPointsRedCount;
}

public any Native_SetSpawnPointsRedCount(Handle plugin, int numParams) {
	SpawnPointsRedCount = GetNativeCell(1);
	return 0;
}

TFDB_NATIVE_GET(Native_GetSpawnPointsRedClass,  SpawnPointsRedClass)
TFDB_NATIVE_SET(Native_SetSpawnPointsRedClass,  SpawnPointsRedClass)
TFDB_NATIVE_GET(Native_GetSpawnPointsRedEntity, SpawnPointsRedEntity)
TFDB_NATIVE_SET(Native_SetSpawnPointsRedEntity, SpawnPointsRedEntity)

public any Native_GetCurrentBluSpawn(Handle plugin, int numParams) {
	return CurrentBluSpawn;
}

public any Native_SetCurrentBluSpawn(Handle plugin, int numParams) {
	CurrentBluSpawn = GetNativeCell(1);
	return 0;
}

public any Native_GetSpawnPointsBluCount(Handle plugin, int numParams) {
	return SpawnPointsBluCount;
}

public any Native_SetSpawnPointsBluCount(Handle plugin, int numParams) {
	SpawnPointsBluCount = GetNativeCell(1);
	return 0;
}

TFDB_NATIVE_GET(Native_GetSpawnPointsBluClass,  SpawnPointsBluClass)
TFDB_NATIVE_SET(Native_SetSpawnPointsBluClass,  SpawnPointsBluClass)
TFDB_NATIVE_GET(Native_GetSpawnPointsBluEntity, SpawnPointsBluEntity)
TFDB_NATIVE_SET(Native_SetSpawnPointsBluEntity, SpawnPointsBluEntity)

// *********************************************************************************
// NATIVES - GAMEPLAY GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRoundStarted(Handle plugin, int numParams) {
	return RoundStarted;
}

public any Native_GetRoundCount(Handle plugin, int numParams) {
	return RoundCount;
}

public any Native_GetRocketsFired(Handle plugin, int numParams) {
	return RocketsFired;
}

public any Native_GetNextSpawnTime(Handle plugin, int numParams) {
	return view_as<any>(NextSpawnTime);
}

public any Native_SetNextSpawnTime(Handle plugin, int numParams) {
	NextSpawnTime = GetNativeCell(1);
	return 0;
}

public any Native_GetLastDeadTeam(Handle plugin, int numParams) {
	return LastDeadTeam;
}

public any Native_GetLastDeadClient(Handle plugin, int numParams) {
	return LastDeadClient;
}

public any Native_GetLastStealer(Handle plugin, int numParams) {
	return LastStealer;
}

public any Native_GetStealInfo(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	SetNativeCellRef(2, StealInfo[client].stoleRocket);
	SetNativeCellRef(3, StealInfo[client].rocketsStolen);
	return 0;
}

public any Native_SetStealInfo(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	if (client < 1 || client > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
	}
	StealInfo[client].stoleRocket = view_as<bool>(GetNativeCell(2));
	StealInfo[client].rocketsStolen = GetNativeCell(3);
	return 0;
}

// *********************************************************************************
// NATIVES - DATAPACK-BASED GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRocketClassCmdsOnSpawn(Handle plugin, int numParams) {
	return CloneHandle(RocketClassCmdsOnSpawn[GetNativeCell(1)], plugin);
}

public any Native_SetRocketClassCmdsOnSpawn(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	DataPack cmds = view_as<DataPack>(GetNativeCell(2));
	DataPack clonedPack = view_as<DataPack>(CloneHandle(cmds, GetMyHandle()));
	delete RocketClassCmdsOnSpawn[rocketClass];
	RocketClassCmdsOnSpawn[rocketClass] = clonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnDeflect(Handle plugin, int numParams) {
	return CloneHandle(RocketClassCmdsOnDeflect[GetNativeCell(1)], plugin);
}

public any Native_SetRocketClassCmdsOnDeflect(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	DataPack cmds = view_as<DataPack>(GetNativeCell(2));
	DataPack clonedPack = view_as<DataPack>(CloneHandle(cmds, GetMyHandle()));
	delete RocketClassCmdsOnDeflect[rocketClass];
	RocketClassCmdsOnDeflect[rocketClass] = clonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnKill(Handle plugin, int numParams) {
	return CloneHandle(RocketClassCmdsOnKill[GetNativeCell(1)], plugin);
}

public any Native_SetRocketClassCmdsOnKill(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	DataPack cmds = view_as<DataPack>(GetNativeCell(2));
	DataPack clonedPack = view_as<DataPack>(CloneHandle(cmds, GetMyHandle()));
	delete RocketClassCmdsOnKill[rocketClass];
	RocketClassCmdsOnKill[rocketClass] = clonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnSpawnKill(Handle plugin, int numParams) {
	return CloneHandle(RocketClassCmdsOnSpawnKill[GetNativeCell(1)], plugin);
}

public any Native_SetRocketClassCmdsOnSpawnKill(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	DataPack cmds = view_as<DataPack>(GetNativeCell(2));
	DataPack clonedPack = view_as<DataPack>(CloneHandle(cmds, GetMyHandle()));
	delete RocketClassCmdsOnSpawnKill[rocketClass];
	RocketClassCmdsOnSpawnKill[rocketClass] = clonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnExplode(Handle plugin, int numParams) {
	return CloneHandle(RocketClassCmdsOnExplode[GetNativeCell(1)], plugin);
}

public any Native_SetRocketClassCmdsOnExplode(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	DataPack cmds = view_as<DataPack>(GetNativeCell(2));
	DataPack clonedPack = view_as<DataPack>(CloneHandle(cmds, GetMyHandle()));
	delete RocketClassCmdsOnExplode[rocketClass];
	RocketClassCmdsOnExplode[rocketClass] = clonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnNoTarget(Handle plugin, int numParams) {
	return CloneHandle(RocketClassCmdsOnNoTarget[GetNativeCell(1)], plugin);
}

public any Native_SetRocketClassCmdsOnNoTarget(Handle plugin, int numParams) {
	int rocketClass = GetNativeCell(1);
	DataPack cmds = view_as<DataPack>(GetNativeCell(2));
	DataPack clonedPack = view_as<DataPack>(CloneHandle(cmds, GetMyHandle()));
	delete RocketClassCmdsOnNoTarget[rocketClass];
	RocketClassCmdsOnNoTarget[rocketClass] = clonedPack;
	return 0;
}

// *********************************************************************************
// NATIVES - ACTION FUNCTIONS
// *********************************************************************************

public any Native_CreateRocket(Handle plugin, int numParams) {
	CreateRocket(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4));
	return 0;
}

public any Native_DestroyRocket(Handle plugin, int numParams) {
	DestroyRocket(GetNativeCell(1));
	return 0;
}

public any Native_DestroyRockets(Handle plugin, int numParams) {
	DestroyRockets();
	return 0;
}

public any Native_DestroyRocketClasses(Handle plugin, int numParams) {
	DestroyRocketClasses();
	return 0;
}

public any Native_DestroySpawners(Handle plugin, int numParams) {
	DestroySpawners();
	return 0;
}

public any Native_ParseConfigurations(Handle plugin, int numParams) {
	int maxLen;
	GetNativeStringLength(1, maxLen);
	char[] buffer = new char[maxLen + 1];
	GetNativeString(1, buffer, maxLen + 1);
	ParseConfigurations(buffer);
	return 0;
}

public any Native_PopulateSpawnPoints(Handle plugin, int numParams) {
	PopulateSpawnPoints();
	return 0;
}

public any Native_HomingRocketThink(Handle plugin, int numParams) {
	HomingRocketThink(GetNativeCell(1));
	return 0;
}

public any Native_RocketLegacyThink(Handle plugin, int numParams) {
	RocketLegacyThink(GetNativeCell(1));
	return 0;
}

// *********************************************************************************
// NATIVES - PRESETS
// *********************************************************************************

public any Native_GetPresetCount(Handle plugin, int numParams) {
	return PresetCount;
}

public any Native_GetPresetName(Handle plugin, int numParams) {
	int preset = GetNativeCell(1);
	int maxLen = GetNativeCell(3);
	SetNativeString(2, PresetName[preset], maxLen);
	return 0;
}

public any Native_ApplyPreset(Handle plugin, int numParams) {
	int preset = GetNativeCell(1);
	if (preset < 0 || preset >= PresetCount) return false;

	// Find the rocket class index by short name
	int targetClass = -1;
	for (int i = 0; i < RocketClassCount; i++)
	{
		if (StrEqual(RocketClassName[i], PresetRocketClass[preset], false))
		{
			targetClass = i;
			break;
		}
	}
	if (targetClass == -1) return false;

	// Destroy active rockets before changing settings
	DestroyRockets();

	// Apply to all spawners
	for (int i = 0; i < SpawnersCount; i++)
	{
		SpawnersMaxRockets[i] = PresetMaxRockets[preset];

		if (PresetSpawnInterval[preset] > 0.0)
		{
			SpawnersInterval[i] = PresetSpawnInterval[preset];
		}

		// Set all chances to 0, then set the target class to 100
		ArrayList table = SpawnersChancesTable[i];
		for (int j = 0; j < table.Length; j++)
		{
			table.Set(j, 0);
		}
		if (targetClass < table.Length)
		{
			table.Set(targetClass, 100);
		}
	}

	return true;
}
