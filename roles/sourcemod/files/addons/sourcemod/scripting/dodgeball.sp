// *********************************************************************************
// PREPROCESSOR
// *********************************************************************************
#pragma semicolon 1
#pragma newdecls required

// *********************************************************************************
// INCLUDES
// *********************************************************************************
#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>
#include <multicolors>

#include <tfdb>

// *********************************************************************************
// CONSTANTS
// *********************************************************************************
#define PLUGIN_NAME             "[TF2] Dodgeball"
#define PLUGIN_AUTHOR           "Damizean, x07x08 continued by Silorak"
#define PLUGIN_VERSION          "2.0.2"
#define PLUGIN_CONTACT          "https://github.com/Silorak/TF2-Dodgeball-Modified"

enum Musics
{
	Music_RoundStart,
	Music_RoundWin,
	Music_RoundLose,
	Music_Gameplay,
	SizeOfMusicsArray
}

// *********************************************************************************
// VARIABLES
// *********************************************************************************

// -----<<< Cvars >>>-----
ConVar CvarEnabled;
ConVar CvarEnableCfgFile;
ConVar CvarDisableCfgFile;
ConVar CvarStealPreventionNumber;
ConVar CvarStealPreventionDamage;
ConVar CvarStealDistance;
ConVar CvarDelayPrevention;
ConVar CvarDelayPreventionTime;
ConVar CvarDelayPreventionSpeedup;
ConVar CvarNoTargetRedirectDamage;
ConVar CvarStealMessage;
ConVar CvarDelayMessage;
// New CVar for bounce mechanic
ConVar CvarBounceForceAngle;
ConVar CvarBounceForceScale;


// -----<<< Gameplay >>>-----
bool   Enabled;
bool   RoundStarted;
int    RoundCount;
int    RocketsFired;
Handle LogicTimer;
float  NextSpawnTime;
int    LastDeadTeam;
int    LastDeadClient;
int    PlayerCount;
float  TickModifier;
int    LastStealer;

eRocketSteal StealInfo[MAXPLAYERS + 1];

// -----<<< Configuration >>>-----
bool MusicEnabled;
bool Music[view_as<int>(SizeOfMusicsArray)];
char MusicPath[view_as<int>(SizeOfMusicsArray)][PLATFORM_MAX_PATH];
bool UseWebPlayer;
char WebPlayerUrl[256];

// -----<<< Structures >>>-----
// Rockets
bool        RocketIsValid[MAX_ROCKETS];
int         RocketEntity[MAX_ROCKETS];
int         RocketTarget[MAX_ROCKETS];
int         RocketClass[MAX_ROCKETS];
RocketFlags RocketInstanceFlags[MAX_ROCKETS];
RocketState RocketInstanceState[MAX_ROCKETS];
float       RocketSpeed[MAX_ROCKETS];
float       RocketMphSpeed[MAX_ROCKETS];
float       RocketDirection[MAX_ROCKETS][3];
int         RocketDeflections[MAX_ROCKETS];
int         RocketEventDeflections[MAX_ROCKETS];
float       RocketLastDeflectionTime[MAX_ROCKETS];
float       RocketLastBeepTime[MAX_ROCKETS];
float       LastSpawnTime[MAX_ROCKETS];
int         RocketBounces[MAX_ROCKETS];
int         RocketCount;

// Classes
char           RocketClassName[MAX_ROCKET_CLASSES][16];
char           RocketClassLongName[MAX_ROCKET_CLASSES][32];
BehaviourTypes RocketClassBehaviour[MAX_ROCKET_CLASSES];
char           RocketClassModel[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
RocketFlags    RocketClassFlags[MAX_ROCKET_CLASSES];
float          RocketClassBeepInterval[MAX_ROCKET_CLASSES];
char           RocketClassSpawnSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
char           RocketClassBeepSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
char           RocketClassAlertSound[MAX_ROCKET_CLASSES][PLATFORM_MAX_PATH];
float          RocketClassCritChance[MAX_ROCKET_CLASSES];
float          RocketClassDamage[MAX_ROCKET_CLASSES];
float          RocketClassDamageIncrement[MAX_ROCKET_CLASSES];
float          RocketClassSpeed[MAX_ROCKET_CLASSES];
float          RocketClassSpeedIncrement[MAX_ROCKET_CLASSES];
float          RocketClassSpeedLimit[MAX_ROCKET_CLASSES];
float          RocketClassTurnRate[MAX_ROCKET_CLASSES];
float          RocketClassTurnRateIncrement[MAX_ROCKET_CLASSES];
float          RocketClassTurnRateLimit[MAX_ROCKET_CLASSES];
float          RocketClassElevationRate[MAX_ROCKET_CLASSES];
float          RocketClassElevationLimit[MAX_ROCKET_CLASSES];
float          RocketClassRocketsModifier[MAX_ROCKET_CLASSES];
float          RocketClassPlayerModifier[MAX_ROCKET_CLASSES];
float          RocketClassControlDelay[MAX_ROCKET_CLASSES];
float          RocketClassDragTimeMin[MAX_ROCKET_CLASSES];
float          RocketClassDragTimeMax[MAX_ROCKET_CLASSES];
float          RocketClassTargetWeight[MAX_ROCKET_CLASSES];
DataPack       RocketClassCmdsOnSpawn[MAX_ROCKET_CLASSES];
DataPack       RocketClassCmdsOnDeflect[MAX_ROCKET_CLASSES];
DataPack       RocketClassCmdsOnKill[MAX_ROCKET_CLASSES];
DataPack       RocketClassCmdsOnExplode[MAX_ROCKET_CLASSES];
DataPack       RocketClassCmdsOnNoTarget[MAX_ROCKET_CLASSES];
int            RocketClassMaxBounces[MAX_ROCKET_CLASSES];
float          RocketClassBounceScale[MAX_ROCKET_CLASSES];
float          RocketClassCrawlBounceScale[MAX_ROCKET_CLASSES];
float          RocketClassCrawlBounceMaxUp[MAX_ROCKET_CLASSES];
float          RocketClassBounceForceAngle[MAX_ROCKET_CLASSES];
float          RocketClassBounceForceScale[MAX_ROCKET_CLASSES];
int            RocketClassCount;

// Spawner classes
char      SpawnersName[MAX_SPAWNER_CLASSES][32];
int       SpawnersMaxRockets[MAX_SPAWNER_CLASSES];
float     SpawnersInterval[MAX_SPAWNER_CLASSES];
ArrayList SpawnersChancesTable[MAX_SPAWNER_CLASSES];
StringMap SpawnersTrie;
int       SpawnersCount;

int CurrentRedSpawn;
int SpawnPointsRedCount;
int SpawnPointsRedClass[MAX_SPAWN_POINTS];
int SpawnPointsRedEntity[MAX_SPAWN_POINTS];

int CurrentBluSpawn;
int SpawnPointsBluCount;
int SpawnPointsBluClass[MAX_SPAWN_POINTS];
int SpawnPointsBluEntity[MAX_SPAWN_POINTS];

int DefaultRedSpawner;
int DefaultBluSpawner;

// -----<<< Forward handles >>>-----
Handle ForwardOnRocketCreated;
Handle ForwardOnRocketCreatedPre;
Handle ForwardOnRocketDeflect;
Handle ForwardOnRocketDeflectPre;
Handle ForwardOnRocketSteal;
Handle ForwardOnRocketNoTarget;
Handle ForwardOnRocketDelay;
Handle ForwardOnRocketBounce;
Handle ForwardOnRocketBouncePre;
Handle ForwardOnRocketsConfigExecuted;
Handle ForwardOnRocketStateChanged;

// *********************************************************************************
// PLUGIN LOGIC (INCLUDES)
// *********************************************************************************
#include <dodgeball_utilities>
#include <dodgeball_config.inc>
#include <dodgeball_rockets.inc>
#include <dodgeball_events.inc>
#include <dodgeball_core.inc>
#include <dodgeball_natives.inc>

// *********************************************************************************
// PLUGIN INFO & LIFECYCLE
// *********************************************************************************
public Plugin myinfo =
{
	name        = PLUGIN_NAME,
	author      = PLUGIN_AUTHOR,
	description = PLUGIN_NAME,
	version     = PLUGIN_VERSION,
	url         = PLUGIN_CONTACT
};

public void OnPluginStart()
{
	char modName[32]; GetGameFolderName(modName, sizeof(modName));
	if (!StrEqual(modName, "tf")) SetFailState("This plugin is only for Team Fortress 2.");

	LoadTranslations("tfdb.phrases.txt");

	CreateConVar("tf_dodgeball_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DONTRECORD);
	CvarEnabled = CreateConVar("tf_dodgeball_enabled", "1", "Enable Dodgeball on TFDB maps?", _, true, 0.0, true, 1.0);
	CvarEnableCfgFile = CreateConVar("tf_dodgeball_enablecfg", "sourcemod/dodgeball_enable.cfg", "Config file to execute when enabling the Dodgeball game mode.");
	CvarDisableCfgFile = CreateConVar("tf_dodgeball_disablecfg", "sourcemod/dodgeball_disable.cfg", "Config file to execute when disabling the Dodgeball game mode.");
	CvarStealPreventionNumber = CreateConVar("tf_dodgeball_sp_number", "3", "How many steals before you get slayed?", _, true, 0.0, false);
	CvarStealPreventionDamage = CreateConVar("tf_dodgeball_sp_damage", "0", "Reduce all damage on stolen rockets?", _, true, 0.0, true, 1.0);
	CvarStealDistance = CreateConVar("tf_dodgeball_sp_distance", "48.0", "The distance between players for a steal to register.", _, true, 0.0, false);
	CvarDelayPrevention = CreateConVar("tf_dodgeball_delay_prevention", "1", "Enable delay prevention?", _, true, 0.0, true, 1.0);
	CvarDelayPreventionTime = CreateConVar("tf_dodgeball_dp_time", "5", "How much time (in seconds) before delay prevention activates?", _, true, 0.0, false);
	CvarDelayPreventionSpeedup = CreateConVar("tf_dodgeball_dp_speedup", "100", "How much speed (in hammer units per second) should the rocket gain when delayed?", _, true, 0.0, false);
	CvarNoTargetRedirectDamage = CreateConVar("tf_dodgeball_redirect_damage", "1", "Reduce all damage when a rocket has an invalid target?", _, true, 0.0, true, 1.0);
	CvarStealMessage = CreateConVar("tf_dodgeball_sp_message", "1", "Display the steal message(s)?", _, true, 0.0, true, 1.0);
	CvarDelayMessage = CreateConVar("tf_dodgeball_dp_message", "1", "Display the delay message(s)?", _, true, 0.0, true, 1.0);
	CvarBounceForceAngle = CreateConVar("tf_dodgeball_bounce_force_angle", "45.0", "Minimum downward angle (pitch) for a player to trigger a forced bounce.", _, true, 0.0, true, 90.0);
	CvarBounceForceScale = CreateConVar("tf_dodgeball_bounce_force_scale", "1.5", "How much stronger a player-forced bounce is. (Multiplier)", _, true, 1.0);


	SpawnersTrie = new StringMap();
	TickModifier = 0.1 / GetTickInterval();

	AddTempEntHook("TFExplosion", OnTFExplosion);

	RegisterCommands();
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] strError, int iErrMax)
{
	CreateNative("TFDB_IsValidRocket", Native_IsValidRocket);
	CreateNative("TFDB_FindRocketByEntity", Native_FindRocketByEntity);
	CreateNative("TFDB_IsDodgeballEnabled", Native_IsDodgeballEnabled);
	CreateNative("TFDB_GetRocketEntity", Native_GetRocketEntity);
	CreateNative("TFDB_GetRocketFlags", Native_GetRocketFlags);
	CreateNative("TFDB_SetRocketFlags", Native_SetRocketFlags);
	CreateNative("TFDB_GetRocketTarget", Native_GetRocketTarget);
	CreateNative("TFDB_SetRocketTarget", Native_SetRocketTarget);
	CreateNative("TFDB_GetRocketEventDeflections", Native_GetRocketEventDeflections);
	CreateNative("TFDB_SetRocketEventDeflections", Native_SetRocketEventDeflections);
	CreateNative("TFDB_GetRocketDeflections", Native_GetRocketDeflections);
	CreateNative("TFDB_SetRocketDeflections", Native_SetRocketDeflections);
	CreateNative("TFDB_GetRocketClass", Native_GetRocketClass);
	CreateNative("TFDB_SetRocketClass", Native_SetRocketClass);
	CreateNative("TFDB_GetRocketClassCount", Native_GetRocketClassCount);
	CreateNative("TFDB_GetRocketClassBehaviour", Native_GetRocketClassBehaviour);
	CreateNative("TFDB_SetRocketClassBehaviour", Native_SetRocketClassBehaviour);
	CreateNative("TFDB_GetRocketClassFlags", Native_GetRocketClassFlags);
	CreateNative("TFDB_SetRocketClassFlags", Native_SetRocketClassFlags);
	CreateNative("TFDB_GetRocketClassDamage", Native_GetRocketClassDamage);
	CreateNative("TFDB_SetRocketClassDamage", Native_SetRocketClassDamage);
	CreateNative("TFDB_GetRocketClassDamageIncrement", Native_GetRocketClassDamageIncrement);
	CreateNative("TFDB_SetRocketClassDamageIncrement", Native_SetRocketClassDamageIncrement);
	CreateNative("TFDB_GetRocketClassSpeed", Native_GetRocketClassSpeed);
	CreateNative("TFDB_SetRocketClassSpeed", Native_SetRocketClassSpeed);
	CreateNative("TFDB_GetRocketClassSpeedIncrement", Native_GetRocketClassSpeedIncrement);
	CreateNative("TFDB_SetRocketClassSpeedIncrement", Native_SetRocketClassSpeedIncrement);
	CreateNative("TFDB_GetRocketClassSpeedLimit", Native_GetRocketClassSpeedLimit);
	CreateNative("TFDB_SetRocketClassSpeedLimit", Native_SetRocketClassSpeedLimit);
	CreateNative("TFDB_GetRocketClassTurnRate", Native_GetRocketClassTurnRate);
	CreateNative("TFDB_SetRocketClassTurnRate", Native_SetRocketClassTurnRate);
	CreateNative("TFDB_GetRocketClassTurnRateIncrement", Native_GetRocketClassTurnRateIncrement);
	CreateNative("TFDB_SetRocketClassTurnRateIncrement", Native_SetRocketClassTurnRateIncrement);
	CreateNative("TFDB_GetRocketClassTurnRateLimit", Native_GetRocketClassTurnRateLimit);
	CreateNative("TFDB_SetRocketClassTurnRateLimit", Native_SetRocketClassTurnRateLimit);
	CreateNative("TFDB_GetRocketClassElevationRate", Native_GetRocketClassElevationRate);
	CreateNative("TFDB_SetRocketClassElevationRate", Native_SetRocketClassElevationRate);
	CreateNative("TFDB_GetRocketClassElevationLimit", Native_GetRocketClassElevationLimit);
	CreateNative("TFDB_SetRocketClassElevationLimit", Native_SetRocketClassElevationLimit);
	CreateNative("TFDB_GetRocketClassRocketsModifier", Native_GetRocketClassRocketsModifier);
	CreateNative("TFDB_SetRocketClassRocketsModifier", Native_SetRocketClassRocketsModifier);
	CreateNative("TFDB_GetRocketClassPlayerModifier", Native_GetRocketClassPlayerModifier);
	CreateNative("TFDB_SetRocketClassPlayerModifier", Native_SetRocketClassPlayerModifier);
	CreateNative("TFDB_GetRocketClassControlDelay", Native_GetRocketClassControlDelay);
	CreateNative("TFDB_SetRocketClassControlDelay", Native_SetRocketClassControlDelay);
	CreateNative("TFDB_GetRocketClassDragTimeMin", Native_GetRocketClassDragTimeMin);
	CreateNative("TFDB_SetRocketClassDragTimeMin", Native_SetRocketClassDragTimeMin);
	CreateNative("TFDB_GetRocketClassDragTimeMax", Native_GetRocketClassDragTimeMax);
	CreateNative("TFDB_SetRocketClassDragTimeMax", Native_SetRocketClassDragTimeMax);
	CreateNative("TFDB_SetRocketClassCount", Native_SetRocketClassCount);
	CreateNative("TFDB_SetRocketEntity", Native_SetRocketEntity);
	CreateNative("TFDB_GetRocketClassMaxBounces", Native_GetRocketClassMaxBounces);
	CreateNative("TFDB_SetRocketClassMaxBounces", Native_SetRocketClassMaxBounces);
	CreateNative("TFDB_GetSpawnersName", Native_GetSpawnersName);
	CreateNative("TFDB_SetSpawnersName", Native_SetSpawnersName);
	CreateNative("TFDB_GetSpawnersMaxRockets", Native_GetSpawnersMaxRockets);
	CreateNative("TFDB_SetSpawnersMaxRockets", Native_SetSpawnersMaxRockets);
	CreateNative("TFDB_GetSpawnersInterval", Native_GetSpawnersInterval);
	CreateNative("TFDB_SetSpawnersInterval", Native_SetSpawnersInterval);
	CreateNative("TFDB_GetSpawnersChancesTable", Native_GetSpawnersChancesTable);
	CreateNative("TFDB_SetSpawnersChancesTable", Native_SetSpawnersChancesTable);
	CreateNative("TFDB_GetSpawnersCount", Native_GetSpawnersCount);
	CreateNative("TFDB_SetSpawnersCount", Native_SetSpawnersCount);
	CreateNative("TFDB_GetCurrentRedSpawn", Native_GetCurrentRedSpawn);
	CreateNative("TFDB_SetCurrentRedSpawn", Native_SetCurrentRedSpawn);
	CreateNative("TFDB_GetSpawnPointsRedCount", Native_GetSpawnPointsRedCount);
	CreateNative("TFDB_SetSpawnPointsRedCount", Native_SetSpawnPointsRedCount);
	CreateNative("TFDB_GetSpawnPointsRedClass", Native_GetSpawnPointsRedClass);
	CreateNative("TFDB_SetSpawnPointsRedClass", Native_SetSpawnPointsRedClass);
	CreateNative("TFDB_GetSpawnPointsRedEntity", Native_GetSpawnPointsRedEntity);
	CreateNative("TFDB_SetSpawnPointsRedEntity", Native_SetSpawnPointsRedEntity);
	CreateNative("TFDB_GetCurrentBluSpawn", Native_GetCurrentBluSpawn);
	CreateNative("TFDB_SetCurrentBluSpawn", Native_SetCurrentBluSpawn);
	CreateNative("TFDB_GetSpawnPointsBluCount", Native_GetSpawnPointsBluCount);
	CreateNative("TFDB_SetSpawnPointsBluCount", Native_SetSpawnPointsBluCount);
	CreateNative("TFDB_GetSpawnPointsBluClass", Native_GetSpawnPointsBluClass);
	CreateNative("TFDB_SetSpawnPointsBluClass", Native_SetSpawnPointsBluClass);
	CreateNative("TFDB_GetSpawnPointsBluEntity", Native_GetSpawnPointsBluEntity);
	CreateNative("TFDB_SetSpawnPointsBluEntity", Native_SetSpawnPointsBluEntity);
	CreateNative("TFDB_GetRoundStarted", Native_GetRoundStarted);
	CreateNative("TFDB_GetRoundCount", Native_GetRoundCount);
	CreateNative("TFDB_GetRocketsFired", Native_GetRocketsFired);
	CreateNative("TFDB_GetNextSpawnTime", Native_GetNextSpawnTime);
	CreateNative("TFDB_SetNextSpawnTime", Native_SetNextSpawnTime);
	CreateNative("TFDB_GetLastDeadTeam", Native_GetLastDeadTeam);
	CreateNative("TFDB_GetLastDeadClient", Native_GetLastDeadClient);
	CreateNative("TFDB_GetLastStealer", Native_GetLastStealer);
	CreateNative("TFDB_GetRocketSpeed", Native_GetRocketSpeed);
	CreateNative("TFDB_SetRocketSpeed", Native_SetRocketSpeed);
	CreateNative("TFDB_GetRocketMphSpeed", Native_GetRocketMphSpeed);
	CreateNative("TFDB_SetRocketMphSpeed", Native_SetRocketMphSpeed);
	CreateNative("TFDB_GetRocketDirection", Native_GetRocketDirection);
	CreateNative("TFDB_SetRocketDirection", Native_SetRocketDirection);
	CreateNative("TFDB_GetRocketLastDeflectionTime", Native_GetRocketLastDeflectionTime);
	CreateNative("TFDB_SetRocketLastDeflectionTime", Native_SetRocketLastDeflectionTime);
	CreateNative("TFDB_GetRocketLastBeepTime", Native_GetRocketLastBeepTime);
	CreateNative("TFDB_SetRocketLastBeepTime", Native_SetRocketLastBeepTime);
	CreateNative("TFDB_GetRocketCount", Native_GetRocketCount);
	CreateNative("TFDB_GetLastSpawnTime", Native_GetLastSpawnTime);
	CreateNative("TFDB_GetRocketBounces", Native_GetRocketBounces);
	CreateNative("TFDB_SetRocketBounces", Native_SetRocketBounces);
	CreateNative("TFDB_GetRocketClassName", Native_GetRocketClassName);
	CreateNative("TFDB_SetRocketClassName", Native_SetRocketClassName);
	CreateNative("TFDB_GetRocketClassLongName", Native_GetRocketClassLongName);
	CreateNative("TFDB_SetRocketClassLongName", Native_SetRocketClassLongName);
	CreateNative("TFDB_GetRocketClassModel", Native_GetRocketClassModel);
	CreateNative("TFDB_SetRocketClassModel", Native_SetRocketClassModel);
	CreateNative("TFDB_GetRocketClassBeepInterval", Native_GetRocketClassBeepInterval);
	CreateNative("TFDB_SetRocketClassBeepInterval", Native_SetRocketClassBeepInterval);
	CreateNative("TFDB_GetRocketClassSpawnSound", Native_GetRocketClassSpawnSound);
	CreateNative("TFDB_SetRocketClassSpawnSound", Native_SetRocketClassSpawnSound);
	CreateNative("TFDB_GetRocketClassBeepSound", Native_GetRocketClassBeepSound);
	CreateNative("TFDB_SetRocketClassBeepSound", Native_SetRocketClassBeepSound);
	CreateNative("TFDB_GetRocketClassAlertSound", Native_GetRocketClassAlertSound);
	CreateNative("TFDB_SetRocketClassAlertSound", Native_SetRocketClassAlertSound);
	CreateNative("TFDB_GetRocketClassCritChance", Native_GetRocketClassCritChance);
	CreateNative("TFDB_SetRocketClassCritChance", Native_SetRocketClassCritChance);
	CreateNative("TFDB_GetRocketClassTargetWeight", Native_GetRocketClassTargetWeight);
	CreateNative("TFDB_SetRocketClassTargetWeight", Native_SetRocketClassTargetWeight);
	CreateNative("TFDB_GetRocketClassCmdsOnSpawn", Native_GetRocketClassCmdsOnSpawn);
	CreateNative("TFDB_SetRocketClassCmdsOnSpawn", Native_SetRocketClassCmdsOnSpawn);
	CreateNative("TFDB_GetRocketClassCmdsOnDeflect", Native_GetRocketClassCmdsOnDeflect);
	CreateNative("TFDB_SetRocketClassCmdsOnDeflect", Native_SetRocketClassCmdsOnDeflect);
	CreateNative("TFDB_GetRocketClassCmdsOnKill", Native_GetRocketClassCmdsOnKill);
	CreateNative("TFDB_SetRocketClassCmdsOnKill", Native_SetRocketClassCmdsOnKill);
	CreateNative("TFDB_GetRocketClassCmdsOnExplode", Native_GetRocketClassCmdsOnExplode);
	CreateNative("TFDB_SetRocketClassCmdsOnExplode", Native_SetRocketClassCmdsOnExplode);
	CreateNative("TFDB_GetRocketClassCmdsOnNoTarget", Native_GetRocketClassCmdsOnNoTarget);
	CreateNative("TFDB_SetRocketClassCmdsOnNoTarget", Native_SetRocketClassCmdsOnNoTarget);
	CreateNative("TFDB_GetRocketClassBounceScale", Native_GetRocketClassBounceScale);
	CreateNative("TFDB_SetRocketClassBounceScale", Native_SetRocketClassBounceScale);
	CreateNative("TFDB_CreateRocket", Native_CreateRocket);
	CreateNative("TFDB_DestroyRocket", Native_DestroyRocket);
	CreateNative("TFDB_DestroyRockets", Native_DestroyRockets);
	CreateNative("TFDB_DestroyRocketClasses", Native_DestroyRocketClasses);
	CreateNative("TFDB_DestroySpawners", Native_DestroySpawners);
	CreateNative("TFDB_ParseConfigurations", Native_ParseConfigurations);
	CreateNative("TFDB_PopulateSpawnPoints", Native_PopulateSpawnPoints);
	CreateNative("TFDB_HomingRocketThink", Native_HomingRocketThink);
	CreateNative("TFDB_RocketLegacyThink", Native_RocketLegacyThink);
	CreateNative("TFDB_GetRocketState", Native_GetRocketState);
	CreateNative("TFDB_SetRocketState", Native_SetRocketState);
	CreateNative("TFDB_GetStealInfo", Native_GetStealInfo);
	CreateNative("TFDB_SetStealInfo", Native_SetStealInfo);

	SetupForwards();

	RegPluginLibrary("tfdb");

	return APLRes_Success;
}

void SetupForwards()
{
	ForwardOnRocketCreated = CreateGlobalForward("TFDB_OnRocketCreated", ET_Ignore, Param_Cell, Param_Cell);
	ForwardOnRocketCreatedPre = CreateGlobalForward("TFDB_OnRocketCreatedPre", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef);
	ForwardOnRocketDeflect = CreateGlobalForward("TFDB_OnRocketDeflect", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	ForwardOnRocketDeflectPre = CreateGlobalForward("TFDB_OnRocketDeflectPre", ET_Event, Param_Cell, Param_Cell, Param_Cell, Param_CellByRef);
	ForwardOnRocketSteal = CreateGlobalForward("TFDB_OnRocketSteal", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	ForwardOnRocketNoTarget = CreateGlobalForward("TFDB_OnRocketNoTarget", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	ForwardOnRocketDelay = CreateGlobalForward("TFDB_OnRocketDelay", ET_Ignore, Param_Cell, Param_Cell);
	ForwardOnRocketBounce = CreateGlobalForward("TFDB_OnRocketBounce", ET_Ignore, Param_Cell, Param_Cell);
	ForwardOnRocketBouncePre = CreateGlobalForward("TFDB_OnRocketBouncePre", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	ForwardOnRocketsConfigExecuted = CreateGlobalForward("TFDB_OnRocketsConfigExecuted", ET_Ignore, Param_String);
	ForwardOnRocketStateChanged = CreateGlobalForward("TFDB_OnRocketStateChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
}

public void OnConfigsExecuted()
{
	if (!(CvarEnabled.BoolValue && IsDodgeBallMap())) return;

	EnableDodgeBall();
}

public void OnMapEnd()
{
	DisableDodgeBall();
}

void Forward_OnRocketCreated(int index, int entity)
{
	Call_StartForward(ForwardOnRocketCreated);
	Call_PushCell(index);
	Call_PushCell(entity);
	Call_Finish();
}

Action Forward_OnRocketCreatedPre(int index, int &rocketClass, RocketFlags &flags)
{
	Action result;

	Call_StartForward(ForwardOnRocketCreatedPre);
	Call_PushCell(index);
	Call_PushCellRef(rocketClass);
	Call_PushCellRef(flags);
	Call_Finish(result);

	return result;
}

void Forward_OnRocketDeflect(int index, int entity, int owner)
{
	Call_StartForward(ForwardOnRocketDeflect);
	Call_PushCell(index);
	Call_PushCell(entity);
	Call_PushCell(owner);
	Call_Finish();
}

Action Forward_OnRocketDeflectPre(int index, int entity, int owner, int &target)
{
	Action result;

	Call_StartForward(ForwardOnRocketDeflectPre);
	Call_PushCell(index);
	Call_PushCell(entity);
	Call_PushCell(owner);
	Call_PushCellRef(target);
	Call_Finish(result);

	return result;
}

void Forward_OnRocketSteal(int index, int owner, int target, int stealCount)
{
	Call_StartForward(ForwardOnRocketSteal);
	Call_PushCell(index);
	Call_PushCell(owner);
	Call_PushCell(target);
	Call_PushCell(stealCount);
	Call_Finish();
}

void Forward_OnRocketNoTarget(int index, int target, int owner)
{
	Call_StartForward(ForwardOnRocketNoTarget);
	Call_PushCell(index);
	Call_PushCell(target);
	Call_PushCell(owner);
	Call_Finish();
}

void Forward_OnRocketDelay(int index, int target)
{
	Call_StartForward(ForwardOnRocketDelay);
	Call_PushCell(index);
	Call_PushCell(target);
	Call_Finish();
}

void Forward_OnRocketBounce(int index, int entity)
{
	Call_StartForward(ForwardOnRocketBounce);
	Call_PushCell(index);
	Call_PushCell(entity);
	Call_Finish();
}

Action Forward_OnRocketBouncePre(int index, int entity, float angles[3], float velocity[3])
{
	Action result;

	Call_StartForward(ForwardOnRocketBouncePre);
	Call_PushCell(index);
	Call_PushCell(entity);
	Call_PushArrayEx(angles, sizeof(angles), SM_PARAM_COPYBACK);
	Call_PushArrayEx(velocity, sizeof(velocity), SM_PARAM_COPYBACK);
	Call_Finish(result);

	return result;
}

void Forward_OnRocketsConfigExecuted(const char[] configFile)
{
	Call_StartForward(ForwardOnRocketsConfigExecuted);
	Call_PushString(configFile);
	Call_Finish();
}

void Forward_OnRocketStateChanged(int index, RocketState state, RocketState newState)
{
	Call_StartForward(ForwardOnRocketStateChanged);
	Call_PushCell(index);
	Call_PushCell(state);
	Call_PushCell(newState);
	Call_Finish();
}

void Internal_SetRocketState(int index, RocketState newState)
{
	RocketState state = RocketInstanceState[index];
	if (state == newState)
	{
		return;
	}

	RocketInstanceState[index] = newState;
	Forward_OnRocketStateChanged(index, state, newState);
}

public bool MLTargetFilterStealer(const char[] pattern, ArrayList clients)
{
	bool reverse = (StrContains(pattern, "!", false) == 1);
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!(IsClientInGame(client) && (clients.FindValue(client) == -1))) continue;

		if (client == LastStealer)
		{
			if (!reverse)
			{
				clients.Push(client);
			}
		}
		else if (reverse)
		{
			clients.Push(client);
		}
	}

	return !!clients.Length;
}

#if defined _multicolors_included && defined _more_colors_included && defined _colors_included
stock void CSkipNextClient(int client)
{
	if (!IsSource2009())
	{
		C_SkipNextClient(client);
	}
	else
	{
		MC_SkipNextClient(client);
	}
}

#endif
