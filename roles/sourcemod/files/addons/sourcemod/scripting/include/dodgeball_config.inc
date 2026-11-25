#if defined _dodgeball_config_included
  #endinput
#endif
#define _dodgeball_config_included

/**
 * Handles parsing of configuration files and server commands.
 */

/** Clears all rocket class definitions and frees associated command DataPacks. */
void DestroyRocketClasses()
{
	for (int index = 0; index < RocketClassCount; index++)
	{
		ResetRocketClass(index);
	}
	RocketClassCount = 0;
}

void ResetRocketClass(int index)
{
	DataPack cmdOnSpawn     = RocketClassCmdsOnSpawn[index];
	DataPack cmdOnKill      = RocketClassCmdsOnKill[index];
	DataPack cmdOnSpawnKill = RocketClassCmdsOnSpawnKill[index];
	DataPack cmdOnExplode   = RocketClassCmdsOnExplode[index];
	DataPack cmdOnDeflect   = RocketClassCmdsOnDeflect[index];
	DataPack cmdOnNoTarget  = RocketClassCmdsOnNoTarget[index];

	if (cmdOnSpawn     != null) delete cmdOnSpawn;
	if (cmdOnKill      != null) delete cmdOnKill;
	if (cmdOnSpawnKill != null) delete cmdOnSpawnKill;
	if (cmdOnExplode   != null) delete cmdOnExplode;
	if (cmdOnDeflect   != null) delete cmdOnDeflect;
	if (cmdOnNoTarget  != null) delete cmdOnNoTarget;

	RocketClassName[index][0]       = '\0';
	RocketClassLongName[index][0]   = '\0';
	RocketClassModel[index][0]      = '\0';
	RocketClassSpawnSound[index][0] = '\0';
	RocketClassBeepSound[index][0]  = '\0';
	RocketClassAlertSound[index][0] = '\0';

	RocketClassBehaviour[index]         = Behaviour_Unknown;
	RocketClassFlags[index]             = RocketFlag_None;
	RocketClassBeepInterval[index]      = 0.0;
	RocketClassCritChance[index]        = 0.0;
	RocketClassDamage[index]            = 0.0;
	RocketClassDamageIncrement[index]   = 0.0;
	RocketClassSpeed[index]             = 0.0;
	RocketClassSpeedIncrement[index]    = 0.0;
	RocketClassSpeedLimit[index]        = 0.0;
	RocketClassTurnRate[index]          = 0.0;
	RocketClassTurnRateIncrement[index] = 0.0;
	RocketClassTurnRateLimit[index]     = 0.0;
	RocketClassElevationRate[index]     = 0.0;
	RocketClassElevationLimit[index]    = 0.0;
	RocketClassRocketsModifier[index]   = 0.0;
	RocketClassPlayerModifier[index]    = 0.0;
	RocketClassControlDelay[index]      = 0.0;
	RocketClassTargetWeight[index]      = 0.0;
	RocketClassMaxBounces[index]        = 0;
	RocketClassBounceCeiling[index]     = 0.0;
	RocketClassCritGlowStack[index]     = 1;
	RocketClassCritGlowParticleRed[index][0]     = '\0';  // empty = use default "critical_rocket_red"
	RocketClassCritGlowParticleBlue[index][0]    = '\0';  // empty = use default "critical_rocket_blue"
	RocketClassCritGlowParticleNeutral[index][0] = '\0';  // empty = use default "eyeboss_projectile"
	RocketClassOrbitTightness[index]    = 0.0;
	RocketClassMaxSpeed[index]          = 0.0;
	RocketClassMaxDeflections[index]    = 0;
	RocketClassSteeringControl[index]   = 0;
	RocketClassBounceControl[index]     = 0;
	RocketClassThinkInterval[index]     = 0.0;

	RocketClassCmdsOnSpawn[index]     = null;
	RocketClassCmdsOnKill[index]      = null;
	RocketClassCmdsOnSpawnKill[index] = null;
	RocketClassCmdsOnExplode[index]   = null;
	RocketClassCmdsOnDeflect[index]   = null;
	RocketClassCmdsOnNoTarget[index]  = null;
}

int FindRocketClassByName(const char[] name)
{
	char key[16];
	strcopy(key, sizeof(key), name);

	for (int index = 0; index < RocketClassCount; index++)
	{
		if (StrEqual(RocketClassName[index], key)) return index;
	}

	return -1;
}

/** Clears all spawner class definitions and spawn point data. */
void DestroySpawners()
{
	for (int index = 0; index < SpawnersCount; index++)
	{
		ResetSpawner(index);
	}

	SpawnersCount  = 0;
	SpawnPointsRedCount = 0;
	SpawnPointsBluCount = 0;
	DefaultRedSpawner = -1;
	DefaultBluSpawner = -1;
	SpawnersTrie.Clear();
}

void ResetSpawner(int index)
{
	if (SpawnersChancesTable[index] != null) delete SpawnersChancesTable[index];
	SpawnersChancesTable[index] = null;
	SpawnersName[index][0] = '\0';
	SpawnersMaxRockets[index] = 0;
	SpawnersInterval[index] = 0.0;
}

/**
 * Scans the map for info_target entities and populates spawn point arrays.
 * Looks for entities named "rocket_spawn_red", "tf_dodgeball_red",
 * "rocket_spawn_blu", or "tf_dodgeball_blu".
 * Calls SetFailState if no spawn points are found.
 */
void PopulateSpawnPoints()
{
	SpawnPointsRedCount = 0;
	SpawnPointsBluCount = 0;
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "info_target")) != -1)
	{
		char name[32]; GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name));
		if ((StrContains(name, "rocket_spawn_red") != -1) || (StrContains(name, "tf_dodgeball_red") != -1))
		{
			if (SpawnPointsRedCount >= MAX_SPAWN_POINTS)
			{
				LogError("Reached maximum RED spawn points (%d). Remaining points will be ignored.", MAX_SPAWN_POINTS);
				continue;
			}

			int index = FindSpawnerByName(name);
			if (index == -1) index = DefaultRedSpawner;
			SpawnPointsRedClass [SpawnPointsRedCount] = index;
			SpawnPointsRedEntity[SpawnPointsRedCount] = entity;
			SpawnPointsRedCount++;
		}

		if ((StrContains(name, "rocket_spawn_blu") != -1) || (StrContains(name, "tf_dodgeball_blu") != -1))
		{
			if (SpawnPointsBluCount >= MAX_SPAWN_POINTS)
			{
				LogError("Reached maximum BLU spawn points (%d). Remaining points will be ignored.", MAX_SPAWN_POINTS);
				continue;
			}

			int index = FindSpawnerByName(name);
			if (index == -1) index = DefaultBluSpawner;

			SpawnPointsBluClass [SpawnPointsBluCount] = index;
			SpawnPointsBluEntity[SpawnPointsBluCount] = entity;
			SpawnPointsBluCount++;
		}
	}

	// Spawn-point failures are NON-FATAL: admins can load non-TFDB maps with
	// tf_dodgeball_enabled=1 without taking down the entire plugin. Rockets
	// just won't spawn (downstream code already guards on zero counts).
	// LogMessage (not LogError) — plugin may run on non-dodgeball maps where
	// missing TFDB spawn entities is an expected condition, not a configuration
	// error. LogError would trigger false alarms in monitoring dashboards.
	if (SpawnPointsRedCount == 0 && SpawnPointsBluCount == 0)
	{
		LogMessage("[TFDB] No 'info_target' entities found on this map — rocket spawning disabled for this map.");
		return;
	}

	if (SpawnPointsRedCount == 0) LogMessage("[TFDB] No RED spawn points found on this map — rockets won't spawn for RED.");
	if (SpawnPointsBluCount == 0) LogMessage("[TFDB] No BLU spawn points found on this map — rockets won't spawn for BLU.");
}

/**
 * Finds a spawner class index by name using the spawners trie.
 *
 * @param name   The spawner name to search for.
 * @return       The spawner class index, or -1 if not found.
 */
int FindSpawnerByName(const char[] name)
{
	int index = -1;
	SpawnersTrie.GetValue(name, index);
	return index;
}

/** Registers server commands for explosion and shockwave effects. */
void RegisterCommands()
{
	RegServerCmd("tf_dodgeball_explosion", CmdExplosion);
	RegServerCmd("tf_dodgeball_shockwave", CmdShockwave);
	RegConsoleCmd("sm_ab", CmdTogglePushPrevention, "Toggle airblast push prevention.");
}

/**
 * Server command: Creates nuke particle effects at a client's position.
 * Usage: tf_dodgeball_explosion <client>
 *
 * @param args   Number of command arguments.
 * @return       Plugin_Handled after processing.
 */
public Action CmdExplosion(int args)
{
	if (!Enabled)
	{
		CPrintToServer("%t", "Command_Disabled");
		return Plugin_Handled;
	}

	if (args != 1)
	{
		CPrintToServer("%t", "Command_DBShockwave_Usage");
		return Plugin_Handled;
	}

	char buffer[8];
	int client;
	GetCmdArg(1, buffer, sizeof(buffer));
	client = StringToInt(buffer);

	if (!IsValidClient(client)) return Plugin_Handled;

	float position[3];
	GetClientAbsOrigin(client, position);
	switch (GetURandomIntRange(0, 4))
	{
		case 0: PlayParticle(position, PARTICLE_NUKE_1_ANGLES, PARTICLE_NUKE_1);
		case 1: PlayParticle(position, PARTICLE_NUKE_2_ANGLES, PARTICLE_NUKE_2);
		case 2: PlayParticle(position, PARTICLE_NUKE_3_ANGLES, PARTICLE_NUKE_3);
		case 3: PlayParticle(position, PARTICLE_NUKE_4_ANGLES, PARTICLE_NUKE_4);
		case 4: PlayParticle(position, PARTICLE_NUKE_5_ANGLES, PARTICLE_NUKE_5);
	}
	PlayParticle(position, PARTICLE_NUKE_COLLUMN_ANGLES, PARTICLE_NUKE_COLLUMN);

	return Plugin_Handled;
}

/**
 * Server command: Creates a shockwave that damages and pushes players.
 * Usage: tf_dodgeball_shockwave <client> <damage> <push_strength> <radius> <falloff_radius>
 *
 * @param args   Number of command arguments.
 * @return       Plugin_Handled after processing.
 */
public Action CmdShockwave(int args)
{
	if (!Enabled)
	{
		CPrintToServer("%t", "Command_Disabled");
		return Plugin_Handled;
	}

	if (args != 5)
	{
		CPrintToServer("%t", "Command_DBShockwave_Usage");
		return Plugin_Handled;
	}

	char buffer[32];
	int client, team;
	float position[3];
	int damage;
	float pushStrength, radius, falloffRadius;
	
	GetCmdArg(1, buffer, sizeof(buffer)); client       = StringToInt(buffer);
	GetCmdArg(2, buffer, sizeof(buffer)); damage       = StringToInt(buffer);
	GetCmdArg(3, buffer, sizeof(buffer)); pushStrength = StringToFloat(buffer);
	GetCmdArg(4, buffer, sizeof(buffer)); radius       = StringToFloat(buffer);
	GetCmdArg(5, buffer, sizeof(buffer)); falloffRadius = StringToFloat(buffer);

	if (!IsValidClient(client)) return Plugin_Handled;
	
	team = GetClientTeam(client);
	GetClientAbsOrigin(client, position);

	for (client = 1; client <= MaxClients; client++)
	{
		if (!(IsValidClientEx(client, true) && (GetClientTeam(client) == team))) continue;
		
		float playerPosition[3];
		GetClientEyePosition(client, playerPosition);
		float distanceToShockwave = GetVectorDistance(position, playerPosition);

		if (!(distanceToShockwave < radius)) continue;

		float impulse[3];
		float finalPush;
		int finalDamage;
		impulse[0] = playerPosition[0] - position[0];
		impulse[1] = playerPosition[1] - position[1];
		impulse[2] = playerPosition[2] - position[2];
		NormalizeVector(impulse, impulse);
		
		if (impulse[2] < 0.4) { impulse[2] = 0.4; NormalizeVector(impulse, impulse); }

		if (distanceToShockwave < falloffRadius)
		{
			finalPush = pushStrength;
			finalDamage = damage;
		}
		else
		{
			float impact = (1.0 - ((distanceToShockwave - falloffRadius) / (radius - falloffRadius)));
			finalPush   = impact * pushStrength;
			finalDamage = RoundToFloor(impact * damage);
		}

		ScaleVector(impulse, finalPush);
		SlapPlayer(client, finalDamage, true);
		SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", impulse);
	}

	return Plugin_Handled;
}

/**
 * Executes stored commands from a DataPack, replacing placeholders with actual values.
 * Used for on-spawn, on-deflect, on-kill, on-explode, and on-no-target commands.
 *
 * Supported placeholders:
 *   @name        - Rocket class long name
 *   @rocket      - Rocket entity index
 *   @owner       - Owner client index
 *   @target      - Target client index
 *   @dead        - Last dead client index
 *   @deflections - Number of deflections
 *   @speed       - Current speed (Hammer units/s)
 *   @mphspeed    - Current speed (MPH, rounded)
 *   @capmphspeed - Capped MPH speed
 *   @nocapspeed  - Uncapped speed
 *   @2dspeed     - Speed with 2 decimal places
 *   @2dnocapspeed - Uncapped speed with 2 decimal places
 *
 * @param dataPack        DataPack containing commands to execute.
 * @param rocketClass     Rocket class index.
 * @param rocket          Rocket entity index.
 * @param owner           Owner client index.
 * @param target          Target client index.
 * @param lastDead        Last dead client index.
 * @param speed           Current rocket speed (Hammer units/s).
 * @param numDeflections  Number of deflections.
 * @param mphSpeed        Current rocket speed (MPH).
 */
void ExecuteCommands(DataPack dataPack, int rocketClass, int rocket, int owner, int target, int lastDead, float speed, int numDeflections, float mphSpeed)
{
	dataPack.Reset(false);
	int numCommands = dataPack.ReadCell();

	while (numCommands-- > 0)
	{
		char cmd[256], buffer[32];

		dataPack.ReadString(cmd, sizeof(cmd));
		ReplaceString(cmd, sizeof(cmd), "@name", RocketClassLongName[rocketClass]);
		FormatEx(buffer, sizeof(buffer), "%i", rocket);                           ReplaceString(cmd, sizeof(cmd), "@rocket", buffer);
		FormatEx(buffer, sizeof(buffer), "%i", owner);                            ReplaceString(cmd, sizeof(cmd), "@owner", buffer);
		FormatEx(buffer, sizeof(buffer), "%i", target);                           ReplaceString(cmd, sizeof(cmd), "@target", buffer);
		FormatEx(buffer, sizeof(buffer), "%i", lastDead);                         ReplaceString(cmd, sizeof(cmd), "@dead", buffer);
		FormatEx(buffer, sizeof(buffer), "%i", numDeflections);                   ReplaceString(cmd, sizeof(cmd), "@deflections", buffer);
		FormatEx(buffer, sizeof(buffer), "%f", speed);                            ReplaceString(cmd, sizeof(cmd), "@speed", buffer);
		FormatEx(buffer, sizeof(buffer), "%i", RoundToNearest(mphSpeed));         ReplaceString(cmd, sizeof(cmd), "@mphspeed", buffer);
		FormatEx(buffer, sizeof(buffer), "%i", RoundToNearest(speed * HAMMER_TO_MPH)); ReplaceString(cmd, sizeof(cmd), "@capmphspeed", buffer);
		FormatEx(buffer, sizeof(buffer), "%f", mphSpeed / HAMMER_TO_MPH);              ReplaceString(cmd, sizeof(cmd), "@nocapspeed", buffer);
		FormatEx(buffer, sizeof(buffer), "%.2f", speed);                          ReplaceString(cmd, sizeof(cmd), "@2dspeed", buffer);
		FormatEx(buffer, sizeof(buffer), "%.2f", mphSpeed / HAMMER_TO_MPH);            ReplaceString(cmd, sizeof(cmd), "@2dnocapspeed", buffer);

		ServerCommand(cmd);
	}
}

/**
 * Parses a dodgeball configuration file (KeyValues format).
 * Loads general settings, rocket classes, and spawner classes.
 *
 * IMPORTANT: per-map cfgs (`tfdb_mapname.cfg`) ADD to and override the classes
 * loaded from `general.cfg` — they do NOT replace them. Wiping state here
 * between `general.cfg` and `mapname.cfg` parses would leave the server with
 * zero classes on maps whose cfg only overrides spawners or a subset.
 *
 * For a true fresh reload, call `DisableDodgeBall` / `EnableDodgeBall` which
 * handle cleanup explicitly (see `dodgeball_core.inc:DisableDodgeBall`).
 */
void ParseConfigurations(char[] configFile = "general.cfg")
{
	char path[PLATFORM_MAX_PATH];
	char fileName[PLATFORM_MAX_PATH];
	FormatEx(fileName, sizeof(fileName), "configs/dodgeball/%s", configFile);
	BuildPath(Path_SM, path, sizeof(path), fileName);
	LogMessage("Executing configuration file %s", path);

	if (!FileExists(path, true))
	{
		// Per-map cfgs are optional. general.cfg missing will be caught downstream
		// by "no rocket classes defined" — but we log a hint so admins aren't lost.
		LogMessage("[TFDB] Config file not found, skipping: %s", path);
		return;
	}

	KeyValues config = new KeyValues("TF2_Dodgeball");
	if (!config.ImportFromFile(path))
	{
		// Malformed cfg: log + skip instead of nuking the entire plugin. A broken
		// tfdb_mapname.cfg should NOT take down the plugin for the rest of the session.
		LogError("[TFDB] Error while parsing configuration file: %s (continuing with existing classes)", path);
		delete config;
		return;
	}

	config.GotoFirstSubKey();
	do
	{
		char section[64]; config.GetSectionName(section, sizeof(section));
		if (StrEqual(section, "general"))       ParseGeneral(config);
		else if (StrEqual(section, "classes"))  ParseClasses(config);
		else if (StrEqual(section, "spawners")) ParseSpawners(config);
		else if (StrEqual(section, "presets"))  ParsePresets(config);
	}
	while (config.GotoNextKey());

	delete config;
	Forward_OnRocketsConfigExecuted(configFile);
}

/** Parses the "general" section of the config (music and scaling settings). */
void ParseGeneral(KeyValues config)
{
	// Scaling mode flags (read before music to avoid early return)
	UseOrbitCoefficient   = view_as<bool>(config.GetNum("orbit coefficient", 0));
	UseTargetSpeedScaling = view_as<bool>(config.GetNum("target speed scaling", 0));
	UseSmoothElevation    = view_as<bool>(config.GetNum("smooth elevation", 0));

	MusicEnabled = view_as<bool>(config.GetNum("music", 0));

	// Built-in features (previously separate subplugins, now cfg-only)
	UsePushPrevention       = view_as<bool>(config.GetNum("push prevention", 1));
	UsePushPreventionToggle = view_as<bool>(config.GetNum("push prevention toggle", 1));
	UseNoBlock              = view_as<bool>(config.GetNum("noblock", 1));
	UseTargetLock           = view_as<bool>(config.GetNum("target lock", 0));
	UseTargetLockBotOnly    = view_as<bool>(config.GetNum("target lock bot only", 1));

	// Engine-wide projectile speed cap. Ports the Unified fork's feature.
	// 0 = leave engine default (3500). Any positive value overrides via sv_maxvelocity.
	// Without this, per-class "speed limit" values above 3500 are silently clamped by engine.
	float maxVel = config.GetFloat("max velocity", 0.0);
	if (maxVel > 0.0)
	{
		ConVar maxVelCvar = FindConVar("sv_maxvelocity");
		if (maxVelCvar != null) maxVelCvar.FloatValue = maxVel;
	}

	if (!MusicEnabled) return;

	UseWebPlayer = view_as<bool>(config.GetNum("use web player", 0));
	config.GetString("web player url", WebPlayerUrl, sizeof(WebPlayerUrl));
	Music[Music_RoundStart] = config.GetString("round start",      MusicPath[Music_RoundStart], PLATFORM_MAX_PATH) && MusicPath[Music_RoundStart][0];
	Music[Music_RoundWin]   = config.GetString("round end (win)",  MusicPath[Music_RoundWin],   PLATFORM_MAX_PATH) && MusicPath[Music_RoundWin][0];
	Music[Music_RoundLose]  = config.GetString("round end (lose)", MusicPath[Music_RoundLose],  PLATFORM_MAX_PATH) && MusicPath[Music_RoundLose][0];
	Music[Music_Gameplay]   = config.GetString("gameplay",         MusicPath[Music_Gameplay],   PLATFORM_MAX_PATH) && MusicPath[Music_Gameplay][0];
}

/** Parses the "classes" section of the config (rocket class definitions). */
void ParseClasses(KeyValues config)
{
	char name[64];
	char buffer[256];
	config.GotoFirstSubKey();
	do
	{
		config.GetSectionName(name, sizeof(name));

		int index = FindRocketClassByName(name);
		bool newClass = (index == -1);
		if (newClass)
		{
			if (RocketClassCount >= MAX_ROCKET_CLASSES)
			{
				LogError("Reached maximum rocket classes (%d). Remaining classes will be ignored.", MAX_ROCKET_CLASSES);
				break;
			}

			index = RocketClassCount;
		}

		ResetRocketClass(index);
		RocketFlags flags = RocketFlag_None;

		strcopy(RocketClassName[index], 16, name);
		config.GetString("name", buffer, sizeof(buffer)); strcopy(RocketClassLongName[index], 32, buffer);
		
		if (config.GetString("model", buffer, sizeof(buffer)))
		{
			strcopy(RocketClassModel[index], PLATFORM_MAX_PATH, buffer);
			if (RocketClassModel[index][0])
			{
				flags |= RocketFlag_CustomModel;
				if (config.GetNum("is animated", 0)) flags |= RocketFlag_IsAnimated;
			}
		}

		config.GetString("behaviour", buffer, sizeof(buffer), "homing");
		if (StrEqual(buffer, "homing")) RocketClassBehaviour[index] = Behaviour_Homing;
		else if (StrEqual(buffer, "legacy homing")) RocketClassBehaviour[index] = Behaviour_LegacyHoming;
		else RocketClassBehaviour[index] = Behaviour_Unknown;

		if (config.GetNum("play spawn sound", 0) == 1)
		{
			flags |= RocketFlag_PlaySpawnSound;
			if (config.GetString("spawn sound", RocketClassSpawnSound[index], PLATFORM_MAX_PATH) && RocketClassSpawnSound[index][0])
			{
				flags |= RocketFlag_CustomSpawnSound;
			}
		}

		if (config.GetNum("play beep sound", 0) == 1)
		{
			flags |= RocketFlag_PlayBeepSound;
			RocketClassBeepInterval[index] = config.GetFloat("beep interval", 0.5);
			if (config.GetString("beep sound", RocketClassBeepSound[index], PLATFORM_MAX_PATH) && RocketClassBeepSound[index][0])
			{
				flags |= RocketFlag_CustomBeepSound;
			}
		}

		if (config.GetNum("play alert sound", 0) == 1)
		{
			flags |= RocketFlag_PlayAlertSound;
			if (config.GetString("alert sound", RocketClassAlertSound[index], PLATFORM_MAX_PATH) && RocketClassAlertSound[index][0])
			{
				flags |= RocketFlag_CustomAlertSound;
			}
		}

		if (config.GetNum("elevate on deflect", 0) == 1) flags |= RocketFlag_ElevateOnDeflect;
		if (config.GetNum("neutral rocket", 0) == 1)     flags |= RocketFlag_IsNeutral;
		if (config.GetNum("keep direction", 0) == 1)     flags |= RocketFlag_KeepDirection;
		if (config.GetNum("teamless deflects", 0) == 1)  flags |= RocketFlag_TeamlessHits;
		if (config.GetNum("reset bounces", 0) == 1)      flags |= RocketFlag_ResetBounces;
		if (config.GetNum("can be stolen", 0) == 1)      flags |= RocketFlag_CanBeStolen;
		if (config.GetNum("steal team check", 0) == 1)   flags |= RocketFlag_StealTeamCheck;

		RocketClassDamage[index]            = config.GetFloat("damage");
		RocketClassDamageIncrement[index]   = config.GetFloat("damage increment");
		RocketClassCritChance[index]        = config.GetFloat("critical chance");
		RocketClassSpeed[index]             = config.GetFloat("speed");
		RocketClassSpeedIncrement[index]    = config.GetFloat("speed increment");
		if ((RocketClassSpeedLimit[index] = config.GetFloat("speed limit")) != 0.0)
		{
			flags |= RocketFlag_IsSpeedLimited;
		}

		RocketClassTurnRate[index]          = config.GetFloat("turn rate");
		RocketClassTurnRateIncrement[index] = config.GetFloat("turn rate increment");
		if ((RocketClassTurnRateLimit[index] = config.GetFloat("turn rate limit")) != 0.0)
		{
			flags |= RocketFlag_IsTRLimited;
		}

		RocketClassElevationRate[index]     = config.GetFloat("elevation rate");
		RocketClassElevationLimit[index]    = config.GetFloat("elevation limit");
		RocketClassControlDelay[index]      = config.GetFloat("control delay");
		RocketClassMaxBounces[index]        = config.GetNum("max bounces");
		RocketClassBounceCeiling[index]     = config.GetFloat("bounce ceiling", 0.0);
		if (RocketClassBounceCeiling[index] < 0.0) RocketClassBounceCeiling[index] = 0.0;
		RocketClassCritGlowStack[index]     = config.GetNum("crit glow stack", 1);
		if (RocketClassCritGlowStack[index] < 1)              RocketClassCritGlowStack[index] = 1;
		if (RocketClassCritGlowStack[index] > MAX_CRIT_STACK) RocketClassCritGlowStack[index] = MAX_CRIT_STACK;

		// Per-class crit glow particle override per team. Empty string = use the
		// engine default for that team (red/blue/neutral; see UpdateCritGlow).
		// Particle name MUST exist in the ParticleEffectNames string table or it
		// renders nothing — use stock TF2 particle names.
		config.GetString("crit glow particle red",     RocketClassCritGlowParticleRed[index],     32, "");
		config.GetString("crit glow particle blue",    RocketClassCritGlowParticleBlue[index],    32, "");
		config.GetString("crit glow particle neutral", RocketClassCritGlowParticleNeutral[index], 32, "");
		RocketClassPlayerModifier[index]    = config.GetFloat("no. players modifier");
		RocketClassRocketsModifier[index]   = config.GetFloat("no. rockets modifier");
		RocketClassTargetWeight[index]      = config.GetFloat("direction to target weight");

		// Scaling mode: orbit coefficient
		RocketClassOrbitTightness[index]    = config.GetFloat("orbit tightness", 0.0);

		// Scaling mode: target speed
		RocketClassMaxSpeed[index]          = config.GetFloat("max speed", 0.0);
		RocketClassMaxDeflections[index]    = config.GetNum("max deflections", 0);
		if (UseTargetSpeedScaling && RocketClassMaxDeflections[index] > 0)
		{
			RocketClassSpeedIncrement[index] = (RocketClassMaxSpeed[index] - RocketClassSpeed[index]) / float(RocketClassMaxDeflections[index]);
		}

		// Steering control: drag window between object_deflected and eye-angle read.
		// Cfg value is seconds. Converted to real ticks so the window is identical
		// in real time across 66/100/128-tick servers. Default 0.045 = master-like.
		float cfgSteering = config.GetFloat("steering control", 0.045);
		if (cfgSteering < 0.0) cfgSteering = 0.0;
		RocketClassSteeringControl[index] = SecondsToTicks(cfgSteering);

		// Bounce control: post-bounce blind window before homing resumes.
		// Cfg value is seconds. Default 0.045 = master-like.
		float cfgBounce = config.GetFloat("bounce control", 0.045);
		if (cfgBounce < 0.0) cfgBounce = 0.0;
		RocketClassBounceControl[index] = SecondsToTicks(cfgBounce);

		// Think interval (seconds): how often the homing lerp runs.
		// 0    = per-tick (default, current smooth behavior)
		// 0.05 = 20 Hz (authentic YADB/Damizean lerp cadence)
		// 0.1  = 10 Hz (chunky, matches 2.2.0 legacy timer)
		// When >0: turn rate applies RAW per fire (no tick-scale compensation) — matches Damizean's
		// math semantic, which means Damizean-era turn rate values (e.g. 0.233) just work.
		RocketClassThinkInterval[index] = config.GetFloat("think interval", 0.0);
		if (RocketClassThinkInterval[index] < 0.0) RocketClassThinkInterval[index] = 0.0;

		DataPack cmds = null;
		config.GetString("on spawn", buffer, sizeof(buffer));
		if ((cmds = ParseCommands(buffer)) != null) { flags |= RocketFlag_OnSpawnCmd; RocketClassCmdsOnSpawn[index] = cmds; }
		
		config.GetString("on deflect", buffer, sizeof(buffer));
		if ((cmds = ParseCommands(buffer)) != null) { flags |= RocketFlag_OnDeflectCmd; RocketClassCmdsOnDeflect[index] = cmds; }

		config.GetString("on kill", buffer, sizeof(buffer));
		if ((cmds = ParseCommands(buffer)) != null) { flags |= RocketFlag_OnKillCmd; RocketClassCmdsOnKill[index] = cmds; }

		config.GetString("on spawn kill", buffer, sizeof(buffer));
		if ((cmds = ParseCommands(buffer)) != null) { flags |= RocketFlag_OnSpawnKillCmd; RocketClassCmdsOnSpawnKill[index] = cmds; }

		config.GetString("on explode", buffer, sizeof(buffer));
		if ((cmds = ParseCommands(buffer)) != null) { flags |= RocketFlag_OnExplodeCmd; RocketClassCmdsOnExplode[index] = cmds; }

		config.GetString("on no target", buffer, sizeof(buffer));
		if ((cmds = ParseCommands(buffer)) != null) { flags |= RocketFlag_OnNoTargetCmd; RocketClassCmdsOnNoTarget[index] = cmds; }

		RocketClassFlags[index] = flags;
		if (newClass) RocketClassCount++;
	}
	while (config.GotoNextKey());
	config.GoBack();
}

/** Parses the "spawners" section of the config (spawner class definitions). */
void ParseSpawners(KeyValues config)
{
	char buffer[256];
	config.GotoFirstSubKey();
	do
	{
		config.GetSectionName(buffer, sizeof(buffer));

		int index = FindSpawnerByName(buffer);
		bool newSpawner = (index == -1);
		if (newSpawner)
		{
			if (SpawnersCount >= MAX_SPAWNER_CLASSES)
			{
				LogError("Reached maximum spawner classes (%d). Remaining spawners will be ignored.", MAX_SPAWNER_CLASSES);
				break;
			}

			index = SpawnersCount;
		}

		ResetSpawner(index);
		strcopy(SpawnersName[index], 32, buffer);
		SpawnersMaxRockets[index] = config.GetNum("max rockets", 1);
		SpawnersInterval[index]   = config.GetFloat("interval", 1.0);

		SpawnersChancesTable[index] = new ArrayList();
		for (int classIndex = 0; classIndex < RocketClassCount; classIndex++)
		{
			FormatEx(buffer, sizeof(buffer), "%s%%", RocketClassName[classIndex]);
			SpawnersChancesTable[index].Push(config.GetNum(buffer, 0));
		}

		SpawnersTrie.SetValue(SpawnersName[index], index);
		if (newSpawner) SpawnersCount++;
	}
	while (config.GotoNextKey());

	config.GoBack();
	SpawnersTrie.GetValue("red", DefaultRedSpawner);
	SpawnersTrie.GetValue("blu", DefaultBluSpawner);
}

/** Parses the "presets" section of the config (gameplay preset definitions).
 *  Resets PresetCount so mid-map config reload doesn't double-count.
 */
void ParsePresets(KeyValues config)
{
	PresetCount = 0;
	config.GotoFirstSubKey();
	do
	{
		int index = PresetCount;

		config.GetString("name", PresetName[index], sizeof(PresetName[]));
		config.GetString("rocket class", PresetRocketClass[index], sizeof(PresetRocketClass[]));
		PresetMaxRockets[index]    = config.GetNum("max rockets", 1);
		PresetSpawnInterval[index] = config.GetFloat("spawn interval", 0.0);

		PresetCount++;

		if (PresetCount >= MAX_PRESETS)
		{
			LogError("Reached maximum presets (%d). Remaining presets will be ignored.", MAX_PRESETS);
			break;
		}
	}
	while (config.GotoNextKey());
	config.GoBack();
}

/**
 * Parses a semicolon-separated command string into a DataPack.
 * Each command between semicolons becomes a separate entry.
 *
 * @param line   The command string to parse (e.g., "sm_slay @target; sm_beacon @owner").
 * @return       DataPack containing the commands, or null if empty.
 */
DataPack ParseCommands(char[] line)
{
    TrimString(line);
    if (!line[0]) return null;

    // Use static array to avoid heap allocation on each call
    // This prevents "Not enough space on the heap" when parsing many rocket classes
    static char parts[32][256];
    int numParts = ExplodeString(line, ";", parts, 32, 256);
    
    ArrayList commands = new ArrayList(ByteCountToCells(256));
    char buffer[256];

    for (int i = 0; i < numParts; i++)
    {
        TrimString(parts[i]);
        if (parts[i][0]) commands.PushString(parts[i]);
    }
    
    int numCommands = commands.Length;
    if (numCommands == 0)
    {
        delete commands;
        return null;
    }

    DataPack dataPack = new DataPack();
    dataPack.WriteCell(numCommands);
    for (int i = 0; i < numCommands; i++)
    {
        commands.GetString(i, buffer, sizeof(buffer));
        dataPack.WriteString(buffer);
    }

    delete commands;
    return dataPack;
}
