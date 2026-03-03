#if defined _dodgeball_natives_included
  #endinput
#endif
#define _dodgeball_natives_included

/**
 * Implements the native functions exposed by the TF2 Dodgeball plugin.
 * These natives allow other plugins to interact with and control the gamemode.
 */

// *********************************************************************************
// NATIVES - GENERAL & STATE
// *********************************************************************************

public any Native_IsValidRocket(Handle hPlugin, int iNumParams) {
	return IsValidRocket(GetNativeCell(1));
}

public any Native_FindRocketByEntity(Handle hPlugin, int iNumParams) {
	return FindRocketByEntity(GetNativeCell(1));
}

public any Native_IsDodgeballEnabled(Handle hPlugin, int iNumParams) {
	return Enabled;
}

// *********************************************************************************
// NATIVES - ROCKET GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRocketEntity(Handle hPlugin, int iNumParams) {
	return EntRefToEntIndex(RocketEntity[GetNativeCell(1)]);
}

public any Native_SetRocketEntity(Handle hPlugin, int iNumParams) {
	RocketEntity[GetNativeCell(1)] = EntIndexToEntRef(GetNativeCell(2));
	return 0;
}

public any Native_GetRocketFlags(Handle hPlugin, int iNumParams) {
	return RocketInstanceFlags[GetNativeCell(1)];
}

public any Native_SetRocketFlags(Handle hPlugin, int iNumParams) {
	RocketInstanceFlags[GetNativeCell(1)] = view_as<RocketFlags>(GetNativeCell(2));
	return 0;
}

public any Native_GetRocketTarget(Handle hPlugin, int iNumParams) {
	return EntRefToEntIndex(RocketTarget[GetNativeCell(1)]);
}

public any Native_SetRocketTarget(Handle hPlugin, int iNumParams) {
	RocketTarget[GetNativeCell(1)] = EntIndexToEntRef(GetNativeCell(2));
	return 0;
}

public any Native_GetRocketEventDeflections(Handle hPlugin, int iNumParams) {
	return RocketEventDeflections[GetNativeCell(1)];
}

public any Native_SetRocketEventDeflections(Handle hPlugin, int iNumParams) {
	RocketEventDeflections[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketDeflections(Handle hPlugin, int iNumParams) {
	return RocketDeflections[GetNativeCell(1)];
}

public any Native_SetRocketDeflections(Handle hPlugin, int iNumParams) {
	RocketDeflections[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClass(Handle hPlugin, int iNumParams) {
	return RocketClass[GetNativeCell(1)];
}

public any Native_SetRocketClass(Handle hPlugin, int iNumParams) {
	RocketClass[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketSpeed(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketSpeed[GetNativeCell(1)]);
}

public any Native_SetRocketSpeed(Handle hPlugin, int iNumParams) {
	RocketSpeed[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketMphSpeed(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketMphSpeed[GetNativeCell(1)]);
}

public any Native_SetRocketMphSpeed(Handle hPlugin, int iNumParams) {
	RocketMphSpeed[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketDirection(Handle hPlugin, int iNumParams) {
	SetNativeArray(2, RocketDirection[GetNativeCell(1)], 3);
	return 0;
}

public any Native_SetRocketDirection(Handle hPlugin, int iNumParams) {
	float fDirection[3];
	GetNativeArray(2, fDirection, sizeof(fDirection));
	CopyVectors(fDirection, RocketDirection[GetNativeCell(1)]);
	return 0;
}

public any Native_GetRocketLastDeflectionTime(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketLastDeflectionTime[GetNativeCell(1)]);
}

public any Native_SetRocketLastDeflectionTime(Handle hPlugin, int iNumParams) {
	RocketLastDeflectionTime[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketLastBeepTime(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketLastBeepTime[GetNativeCell(1)]);
}

public any Native_SetRocketLastBeepTime(Handle hPlugin, int iNumParams) {
	RocketLastBeepTime[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketCount(Handle hPlugin, int iNumParams) {
	return RocketCount;
}

public any Native_GetLastSpawnTime(Handle hPlugin, int iNumParams) {
	return view_as<any>(LastSpawnTime[GetNativeCell(1)]);
}

public any Native_GetRocketBounces(Handle hPlugin, int iNumParams) {
	return RocketBounces[GetNativeCell(1)];
}

public any Native_SetRocketBounces(Handle hPlugin, int iNumParams) {
	RocketBounces[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketState(Handle hPlugin, int iNumParams) {
	return RocketInstanceState[GetNativeCell(1)];
}

public any Native_SetRocketState(Handle hPlugin, int iNumParams) {
	Internal_SetRocketState(GetNativeCell(1), view_as<RocketState>(GetNativeCell(2)));
	return 0;
}

// *********************************************************************************
// NATIVES - ROCKET CLASS GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRocketClassCount(Handle hPlugin, int iNumParams) {
	return RocketClassCount;
}

public any Native_SetRocketClassCount(Handle hPlugin, int iNumParams) {
	RocketClassCount = GetNativeCell(1);
	return 0;
}

public any Native_GetRocketClassBehaviour(Handle hPlugin, int iNumParams) {
	return RocketClassBehaviour[GetNativeCell(1)];
}

public any Native_SetRocketClassBehaviour(Handle hPlugin, int iNumParams) {
	RocketClassBehaviour[GetNativeCell(1)] = view_as<BehaviourTypes>(GetNativeCell(2));
	return 0;
}

public any Native_GetRocketClassFlags(Handle hPlugin, int iNumParams) {
	return RocketClassFlags[GetNativeCell(1)];
}

public any Native_SetRocketClassFlags(Handle hPlugin, int iNumParams) {
	RocketClassFlags[GetNativeCell(1)] = view_as<RocketFlags>(GetNativeCell(2));
	return 0;
}

public any Native_GetRocketClassDamage(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassDamage[GetNativeCell(1)]);
}

public any Native_SetRocketClassDamage(Handle hPlugin, int iNumParams) {
	RocketClassDamage[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassDamageIncrement(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassDamageIncrement[GetNativeCell(1)]);
}

public any Native_SetRocketClassDamageIncrement(Handle hPlugin, int iNumParams) {
	RocketClassDamageIncrement[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassSpeed(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassSpeed[GetNativeCell(1)]);
}

public any Native_SetRocketClassSpeed(Handle hPlugin, int iNumParams) {
	RocketClassSpeed[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassSpeedIncrement(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassSpeedIncrement[GetNativeCell(1)]);
}

public any Native_SetRocketClassSpeedIncrement(Handle hPlugin, int iNumParams) {
	RocketClassSpeedIncrement[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassSpeedLimit(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassSpeedLimit[GetNativeCell(1)]);
}

public any Native_SetRocketClassSpeedLimit(Handle hPlugin, int iNumParams) {
	RocketClassSpeedLimit[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassTurnRate(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassTurnRate[GetNativeCell(1)]);
}

public any Native_SetRocketClassTurnRate(Handle hPlugin, int iNumParams) {
	RocketClassTurnRate[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassTurnRateIncrement(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassTurnRateIncrement[GetNativeCell(1)]);
}

public any Native_SetRocketClassTurnRateIncrement(Handle hPlugin, int iNumParams) {
	RocketClassTurnRateIncrement[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassTurnRateLimit(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassTurnRateLimit[GetNativeCell(1)]);
}

public any Native_SetRocketClassTurnRateLimit(Handle hPlugin, int iNumParams) {
	RocketClassTurnRateLimit[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassElevationRate(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassElevationRate[GetNativeCell(1)]);
}

public any Native_SetRocketClassElevationRate(Handle hPlugin, int iNumParams) {
	RocketClassElevationRate[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassElevationLimit(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassElevationLimit[GetNativeCell(1)]);
}

public any Native_SetRocketClassElevationLimit(Handle hPlugin, int iNumParams) {
	RocketClassElevationLimit[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassRocketsModifier(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassRocketsModifier[GetNativeCell(1)]);
}

public any Native_SetRocketClassRocketsModifier(Handle hPlugin, int iNumParams) {
	RocketClassRocketsModifier[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassPlayerModifier(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassPlayerModifier[GetNativeCell(1)]);
}

public any Native_SetRocketClassPlayerModifier(Handle hPlugin, int iNumParams) {
	RocketClassPlayerModifier[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassControlDelay(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassControlDelay[GetNativeCell(1)]);
}

public any Native_SetRocketClassControlDelay(Handle hPlugin, int iNumParams) {
	RocketClassControlDelay[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}


public any Native_GetRocketClassMaxBounces(Handle hPlugin, int iNumParams) {
	return RocketClassMaxBounces[GetNativeCell(1)];
}

public any Native_SetRocketClassMaxBounces(Handle hPlugin, int iNumParams) {
	RocketClassMaxBounces[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassName(Handle hPlugin, int iNumParams) {
	SetNativeString(2, RocketClassName[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassName(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	int iMaxLen;
	GetNativeStringLength(2, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(2, strBuffer, iMaxLen + 1);
	strcopy(RocketClassName[iClass], sizeof(RocketClassName[]), strBuffer);
	return 0;
}

public any Native_GetRocketClassLongName(Handle hPlugin, int iNumParams) {
	SetNativeString(2, RocketClassLongName[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassLongName(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	int iMaxLen;
	GetNativeStringLength(2, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(2, strBuffer, iMaxLen + 1);
	strcopy(RocketClassLongName[iClass], sizeof(RocketClassLongName[]), strBuffer);
	return 0;
}

public any Native_GetRocketClassModel(Handle hPlugin, int iNumParams) {
	SetNativeString(2, RocketClassModel[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassModel(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	int iMaxLen;
	GetNativeStringLength(2, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(2, strBuffer, iMaxLen + 1);
	strcopy(RocketClassModel[iClass], sizeof(RocketClassModel[]), strBuffer);
	return 0;
}

public any Native_GetRocketClassBeepInterval(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassBeepInterval[GetNativeCell(1)]);
}

public any Native_SetRocketClassBeepInterval(Handle hPlugin, int iNumParams) {
	RocketClassBeepInterval[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassSpawnSound(Handle hPlugin, int iNumParams) {
	SetNativeString(2, RocketClassSpawnSound[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassSpawnSound(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	int iMaxLen;
	GetNativeStringLength(2, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(2, strBuffer, iMaxLen + 1);
	strcopy(RocketClassSpawnSound[iClass], sizeof(RocketClassSpawnSound[]), strBuffer);
	return 0;
}

public any Native_GetRocketClassBeepSound(Handle hPlugin, int iNumParams) {
	SetNativeString(2, RocketClassBeepSound[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassBeepSound(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	int iMaxLen;
	GetNativeStringLength(2, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(2, strBuffer, iMaxLen + 1);
	strcopy(RocketClassBeepSound[iClass], sizeof(RocketClassBeepSound[]), strBuffer);
	return 0;
}

public any Native_GetRocketClassAlertSound(Handle hPlugin, int iNumParams) {
	SetNativeString(2, RocketClassAlertSound[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetRocketClassAlertSound(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	int iMaxLen;
	GetNativeStringLength(2, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(2, strBuffer, iMaxLen + 1);
	strcopy(RocketClassAlertSound[iClass], sizeof(RocketClassAlertSound[]), strBuffer);
	return 0;
}

public any Native_GetRocketClassCritChance(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassCritChance[GetNativeCell(1)]);
}

public any Native_SetRocketClassCritChance(Handle hPlugin, int iNumParams) {
	RocketClassCritChance[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassTargetWeight(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassTargetWeight[GetNativeCell(1)]);
}

public any Native_SetRocketClassTargetWeight(Handle hPlugin, int iNumParams) {
	RocketClassTargetWeight[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetRocketClassBounceScale(Handle hPlugin, int iNumParams) {
	return view_as<any>(RocketClassBounceScale[GetNativeCell(1)]);
}

public any Native_SetRocketClassBounceScale(Handle hPlugin, int iNumParams) {
	RocketClassBounceScale[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

// *********************************************************************************
// NATIVES - SPAWNER GETTERS/SETTERS
// *********************************************************************************

public any Native_GetSpawnersName(Handle hPlugin, int iNumParams) {
	SetNativeString(2, SpawnersName[GetNativeCell(1)], GetNativeCell(3));
	return 0;
}

public any Native_SetSpawnersName(Handle hPlugin, int iNumParams) {
	int iSpawnerClass = GetNativeCell(1);
	int iMaxLen;
	GetNativeStringLength(2, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(2, strBuffer, iMaxLen + 1);
	strcopy(SpawnersName[iSpawnerClass], sizeof(SpawnersName[]), strBuffer);
	return 0;
}

public any Native_GetSpawnersMaxRockets(Handle hPlugin, int iNumParams) {
	return SpawnersMaxRockets[GetNativeCell(1)];
}

public any Native_SetSpawnersMaxRockets(Handle hPlugin, int iNumParams) {
	SpawnersMaxRockets[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetSpawnersInterval(Handle hPlugin, int iNumParams) {
	return view_as<any>(SpawnersInterval[GetNativeCell(1)]);
}

public any Native_SetSpawnersInterval(Handle hPlugin, int iNumParams) {
	SpawnersInterval[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetSpawnersChancesTable(Handle hPlugin, int iNumParams) {
	return CloneHandle(SpawnersChancesTable[GetNativeCell(1)], hPlugin);
}

public any Native_SetSpawnersChancesTable(Handle hPlugin, int iNumParams) {
	int iSpawnerClass = GetNativeCell(1);
	ArrayList hTable = view_as<ArrayList>(GetNativeCell(2));
	ArrayList hClonedTable = view_as<ArrayList>(CloneHandle(hTable, GetMyHandle()));
	delete SpawnersChancesTable[iSpawnerClass];
	SpawnersChancesTable[iSpawnerClass] = hClonedTable;
	return 0;
}

public any Native_GetSpawnersCount(Handle hPlugin, int iNumParams) {
	return SpawnersCount;
}

public any Native_SetSpawnersCount(Handle hPlugin, int iNumParams) {
	SpawnersCount = GetNativeCell(1);
	return 0;
}

// *********************************************************************************
// NATIVES - SPAWN POINT GETTERS/SETTERS
// *********************************************************************************

public any Native_GetCurrentRedSpawn(Handle hPlugin, int iNumParams) {
	return CurrentRedSpawn;
}

public any Native_SetCurrentRedSpawn(Handle hPlugin, int iNumParams) {
	CurrentRedSpawn = GetNativeCell(1);
	return 0;
}

public any Native_GetSpawnPointsRedCount(Handle hPlugin, int iNumParams) {
	return SpawnPointsRedCount;
}

public any Native_SetSpawnPointsRedCount(Handle hPlugin, int iNumParams) {
	SpawnPointsRedCount = GetNativeCell(1);
	return 0;
}

public any Native_GetSpawnPointsRedClass(Handle hPlugin, int iNumParams) {
	return SpawnPointsRedClass[GetNativeCell(1)];
}

public any Native_SetSpawnPointsRedClass(Handle hPlugin, int iNumParams) {
	SpawnPointsRedClass[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetSpawnPointsRedEntity(Handle hPlugin, int iNumParams) {
	return SpawnPointsRedEntity[GetNativeCell(1)];
}

public any Native_SetSpawnPointsRedEntity(Handle hPlugin, int iNumParams) {
	SpawnPointsRedEntity[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetCurrentBluSpawn(Handle hPlugin, int iNumParams) {
	return CurrentBluSpawn;
}

public any Native_SetCurrentBluSpawn(Handle hPlugin, int iNumParams) {
	CurrentBluSpawn = GetNativeCell(1);
	return 0;
}

public any Native_GetSpawnPointsBluCount(Handle hPlugin, int iNumParams) {
	return SpawnPointsBluCount;
}

public any Native_SetSpawnPointsBluCount(Handle hPlugin, int iNumParams) {
	SpawnPointsBluCount = GetNativeCell(1);
	return 0;
}

public any Native_GetSpawnPointsBluClass(Handle hPlugin, int iNumParams) {
	return SpawnPointsBluClass[GetNativeCell(1)];
}

public any Native_SetSpawnPointsBluClass(Handle hPlugin, int iNumParams) {
	SpawnPointsBluClass[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

public any Native_GetSpawnPointsBluEntity(Handle hPlugin, int iNumParams) {
	return SpawnPointsBluEntity[GetNativeCell(1)];
}

public any Native_SetSpawnPointsBluEntity(Handle hPlugin, int iNumParams) {
	SpawnPointsBluEntity[GetNativeCell(1)] = GetNativeCell(2);
	return 0;
}

// *********************************************************************************
// NATIVES - GAMEPLAY GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRoundStarted(Handle hPlugin, int iNumParams) {
	return RoundStarted;
}

public any Native_GetRoundCount(Handle hPlugin, int iNumParams) {
	return RoundCount;
}

public any Native_GetRocketsFired(Handle hPlugin, int iNumParams) {
	return RocketsFired;
}

public any Native_GetNextSpawnTime(Handle hPlugin, int iNumParams) {
	return view_as<any>(NextSpawnTime);
}

public any Native_SetNextSpawnTime(Handle hPlugin, int iNumParams) {
	NextSpawnTime = GetNativeCell(1);
	return 0;
}

public any Native_GetLastDeadTeam(Handle hPlugin, int iNumParams) {
	return LastDeadTeam;
}

public any Native_GetLastDeadClient(Handle hPlugin, int iNumParams) {
	return LastDeadClient;
}

public any Native_GetLastStealer(Handle hPlugin, int iNumParams) {
	return LastStealer;
}

public any Native_GetStealInfo(Handle hPlugin, int iNumParams) {
	int iClient = GetNativeCell(1);
	if (iClient < 1 || iClient > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}
	SetNativeCellRef(2, StealInfo[iClient].stoleRocket);
	SetNativeCellRef(3, StealInfo[iClient].rocketsStolen);
	return 0;
}

public any Native_SetStealInfo(Handle hPlugin, int iNumParams) {
	int iClient = GetNativeCell(1);
	if (iClient < 1 || iClient > MaxClients) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", iClient);
	}
	StealInfo[iClient].stoleRocket = view_as<bool>(GetNativeCell(2));
	StealInfo[iClient].rocketsStolen = GetNativeCell(3);
	return 0;
}

// *********************************************************************************
// NATIVES - DATAPACK-BASED GETTERS/SETTERS
// *********************************************************************************

public any Native_GetRocketClassCmdsOnSpawn(Handle hPlugin, int iNumParams) {
	return CloneHandle(RocketClassCmdsOnSpawn[GetNativeCell(1)], hPlugin);
}

public any Native_SetRocketClassCmdsOnSpawn(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	DataPack hCmds = view_as<DataPack>(GetNativeCell(2));
	DataPack hClonedPack = view_as<DataPack>(CloneHandle(hCmds, GetMyHandle()));
	delete RocketClassCmdsOnSpawn[iClass];
	RocketClassCmdsOnSpawn[iClass] = hClonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnDeflect(Handle hPlugin, int iNumParams) {
	return CloneHandle(RocketClassCmdsOnDeflect[GetNativeCell(1)], hPlugin);
}

public any Native_SetRocketClassCmdsOnDeflect(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	DataPack hCmds = view_as<DataPack>(GetNativeCell(2));
	DataPack hClonedPack = view_as<DataPack>(CloneHandle(hCmds, GetMyHandle()));
	delete RocketClassCmdsOnDeflect[iClass];
	RocketClassCmdsOnDeflect[iClass] = hClonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnKill(Handle hPlugin, int iNumParams) {
	return CloneHandle(RocketClassCmdsOnKill[GetNativeCell(1)], hPlugin);
}

public any Native_SetRocketClassCmdsOnKill(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	DataPack hCmds = view_as<DataPack>(GetNativeCell(2));
	DataPack hClonedPack = view_as<DataPack>(CloneHandle(hCmds, GetMyHandle()));
	delete RocketClassCmdsOnKill[iClass];
	RocketClassCmdsOnKill[iClass] = hClonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnExplode(Handle hPlugin, int iNumParams) {
	return CloneHandle(RocketClassCmdsOnExplode[GetNativeCell(1)], hPlugin);
}

public any Native_SetRocketClassCmdsOnExplode(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	DataPack hCmds = view_as<DataPack>(GetNativeCell(2));
	DataPack hClonedPack = view_as<DataPack>(CloneHandle(hCmds, GetMyHandle()));
	delete RocketClassCmdsOnExplode[iClass];
	RocketClassCmdsOnExplode[iClass] = hClonedPack;
	return 0;
}

public any Native_GetRocketClassCmdsOnNoTarget(Handle hPlugin, int iNumParams) {
	return CloneHandle(RocketClassCmdsOnNoTarget[GetNativeCell(1)], hPlugin);
}

public any Native_SetRocketClassCmdsOnNoTarget(Handle hPlugin, int iNumParams) {
	int iClass = GetNativeCell(1);
	DataPack hCmds = view_as<DataPack>(GetNativeCell(2));
	DataPack hClonedPack = view_as<DataPack>(CloneHandle(hCmds, GetMyHandle()));
	delete RocketClassCmdsOnNoTarget[iClass];
	RocketClassCmdsOnNoTarget[iClass] = hClonedPack;
	return 0;
}

// *********************************************************************************
// NATIVES - ACTION FUNCTIONS
// *********************************************************************************

public any Native_CreateRocket(Handle hPlugin, int iNumParams) {
	CreateRocket(GetNativeCell(1), GetNativeCell(2), GetNativeCell(3), GetNativeCell(4));
	return 0;
}

public any Native_DestroyRocket(Handle hPlugin, int iNumParams) {
	DestroyRocket(GetNativeCell(1));
	return 0;
}

public any Native_DestroyRockets(Handle hPlugin, int iNumParams) {
	DestroyRockets();
	return 0;
}

public any Native_DestroyRocketClasses(Handle hPlugin, int iNumParams) {
	DestroyRocketClasses();
	return 0;
}

public any Native_DestroySpawners(Handle hPlugin, int iNumParams) {
	DestroySpawners();
	return 0;
}

public any Native_ParseConfigurations(Handle hPlugin, int iNumParams) {
	int iMaxLen;
	GetNativeStringLength(1, iMaxLen);
	char[] strBuffer = new char[iMaxLen + 1];
	GetNativeString(1, strBuffer, iMaxLen + 1);
	ParseConfigurations(strBuffer);
	return 0;
}

public any Native_PopulateSpawnPoints(Handle hPlugin, int iNumParams) {
	PopulateSpawnPoints();
	return 0;
}

public any Native_HomingRocketThink(Handle hPlugin, int iNumParams) {
	HomingRocketThink(GetNativeCell(1));
	return 0;
}

public any Native_RocketLegacyThink(Handle hPlugin, int iNumParams) {
	RocketLegacyThink(GetNativeCell(1));
	return 0;
}

// *********************************************************************************
// NATIVES - PRESETS
// *********************************************************************************

public any Native_GetPresetCount(Handle hPlugin, int iNumParams) {
	return PresetCount;
}

public any Native_GetPresetName(Handle hPlugin, int iNumParams) {
	int iPreset = GetNativeCell(1);
	int iMaxLen = GetNativeCell(3);
	SetNativeString(2, PresetName[iPreset], iMaxLen);
	return 0;
}

public any Native_ApplyPreset(Handle hPlugin, int iNumParams) {
	int iPreset = GetNativeCell(1);
	if (iPreset < 0 || iPreset >= PresetCount) return false;

	// Find the rocket class index by short name
	int iTargetClass = -1;
	for (int i = 0; i < RocketClassCount; i++)
	{
		if (StrEqual(RocketClassName[i], PresetRocketClass[iPreset], false))
		{
			iTargetClass = i;
			break;
		}
	}
	if (iTargetClass == -1) return false;

	// Destroy active rockets before changing settings
	DestroyRockets();

	// Apply to all spawners
	for (int i = 0; i < SpawnersCount; i++)
	{
		SpawnersMaxRockets[i] = PresetMaxRockets[iPreset];

		if (PresetSpawnInterval[iPreset] > 0.0)
		{
			SpawnersInterval[i] = PresetSpawnInterval[iPreset];
		}

		// Set chances table: 100% target class, 0% everything else
		ArrayList hTable = SpawnersChancesTable[i];
		for (int j = 0; j < hTable.Length; j++)
		{
			hTable.Set(j, (j == iTargetClass) ? 100 : 0);
		}
	}

	return true;
}