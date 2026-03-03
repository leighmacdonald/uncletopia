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
	for (int iIndex = 0; iIndex < RocketClassCount; iIndex++)
	{
		DataPack hCmdOnSpawn    = RocketClassCmdsOnSpawn[iIndex];
		DataPack hCmdOnKill     = RocketClassCmdsOnKill[iIndex];
		DataPack hCmdOnExplode  = RocketClassCmdsOnExplode[iIndex];
		DataPack hCmdOnDeflect  = RocketClassCmdsOnDeflect[iIndex];
		DataPack hCmdOnNoTarget = RocketClassCmdsOnNoTarget[iIndex];

		if (hCmdOnSpawn   != null)  delete hCmdOnSpawn;
		if (hCmdOnKill    != null)  delete hCmdOnKill;
		if (hCmdOnExplode != null)  delete hCmdOnExplode;
		if (hCmdOnDeflect != null)  delete hCmdOnDeflect;
		if (hCmdOnNoTarget != null) delete hCmdOnNoTarget;

		RocketClassCmdsOnSpawn[iIndex]    = null;
		RocketClassCmdsOnKill[iIndex]     = null;
		RocketClassCmdsOnExplode[iIndex]  = null;
		RocketClassCmdsOnDeflect[iIndex]  = null;
		RocketClassCmdsOnNoTarget[iIndex] = null;
	}
	RocketClassCount = 0;
}

/** Clears all spawner class definitions and spawn point data. */
void DestroySpawners()
{
	for (int iIndex = 0; iIndex < SpawnersCount; iIndex++)
	{
		delete SpawnersChancesTable[iIndex];
	}

	SpawnersCount  = 0;
	SpawnPointsRedCount = 0;
	SpawnPointsBluCount = 0;
	DefaultRedSpawner = -1;
	DefaultBluSpawner = -1;
	SpawnersTrie.Clear();
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
	int iEntity = -1;
	while ((iEntity = FindEntityByClassname(iEntity, "info_target")) != -1)
	{
		char strName[32]; GetEntPropString(iEntity, Prop_Data, "m_iName", strName, sizeof(strName));
		if ((StrContains(strName, "rocket_spawn_red") != -1) || (StrContains(strName, "tf_dodgeball_red") != -1))
		{
			int iIndex = FindSpawnerByName(strName);
			if (iIndex == -1) iIndex = DefaultRedSpawner;
			SpawnPointsRedClass [SpawnPointsRedCount] = iIndex;
			SpawnPointsRedEntity[SpawnPointsRedCount] = iEntity;
			SpawnPointsRedCount++;
		}

		if ((StrContains(strName, "rocket_spawn_blu") != -1) || (StrContains(strName, "tf_dodgeball_blu") != -1))
		{
			int iIndex = FindSpawnerByName(strName);
			if (iIndex == -1) iIndex = DefaultBluSpawner;

			SpawnPointsBluClass [SpawnPointsBluCount] = iIndex;
			SpawnPointsBluEntity[SpawnPointsBluCount] = iEntity;
			SpawnPointsBluCount++;
		}
	}

	// New code block starts here
	if (SpawnPointsRedCount == 0 && SpawnPointsBluCount == 0)
	{
		SetFailState("No 'info_target' entities found on this map.");
		return;
	}
	// New code block ends here

	if (SpawnPointsRedCount == 0) SetFailState("No RED spawn points found on this map.");
	if (SpawnPointsBluCount == 0) SetFailState("No BLU spawn points found on this map.");
}

/**
 * Finds a spawner class index by name using the spawners trie.
 *
 * @param strName   The spawner name to search for.
 * @return          The spawner class index, or -1 if not found.
 */
int FindSpawnerByName(char strName[32])
{
	int iIndex = -1;
	SpawnersTrie.GetValue(strName, iIndex);
	return iIndex;
}

/** Registers server commands for explosion and shockwave effects. */
void RegisterCommands()
{
	RegServerCmd("tf_dodgeball_explosion", CmdExplosion);
	RegServerCmd("tf_dodgeball_shockwave", CmdShockwave);
}

/**
 * Server command: Creates nuke particle effects at a client's position.
 * Usage: tf_dodgeball_explosion <client>
 *
 * @param iArgs     Number of command arguments.
 * @return          Plugin_Handled after processing.
 */
public Action CmdExplosion(int iArgs)
{
	if (!Enabled)
	{
		CPrintToServer("%t", "Command_Disabled");
		return Plugin_Handled;
	}

	if (iArgs != 1)
	{
		CPrintToServer("%t", "Command_DBShockwave_Usage");
		return Plugin_Handled;
	}

	char strBuffer[8];
	int iClient;
	GetCmdArg(1, strBuffer, sizeof(strBuffer));
	iClient = StringToInt(strBuffer);

	if (!IsValidClient(iClient)) return Plugin_Handled;

	float fPosition[3];
	GetClientAbsOrigin(iClient, fPosition);
	switch (GetURandomIntRange(0, 4))
	{
		case 0: PlayParticle(fPosition, PARTICLE_NUKE_1_ANGLES, PARTICLE_NUKE_1);
		case 1: PlayParticle(fPosition, PARTICLE_NUKE_2_ANGLES, PARTICLE_NUKE_2);
		case 2: PlayParticle(fPosition, PARTICLE_NUKE_3_ANGLES, PARTICLE_NUKE_3);
		case 3: PlayParticle(fPosition, PARTICLE_NUKE_4_ANGLES, PARTICLE_NUKE_4);
		case 4: PlayParticle(fPosition, PARTICLE_NUKE_5_ANGLES, PARTICLE_NUKE_5);
	}
	PlayParticle(fPosition, PARTICLE_NUKE_COLLUMN_ANGLES, PARTICLE_NUKE_COLLUMN);

	return Plugin_Handled;
}

/**
 * Server command: Creates a shockwave that damages and pushes players.
 * Usage: tf_dodgeball_shockwave <client> <damage> <push_strength> <radius> <falloff_radius>
 *
 * @param iArgs     Number of command arguments.
 * @return          Plugin_Handled after processing.
 */
public Action CmdShockwave(int iArgs)
{
	if (!Enabled)
	{
		CPrintToServer("%t", "Command_Disabled");
		return Plugin_Handled;
	}

	if (iArgs != 5)
	{
		CPrintToServer("%t", "Command_DBShockwave_Usage");
		return Plugin_Handled;
	}

	char strBuffer[32];
	int iClient, iTeam;
	float fPosition[3];
	int iDamage;
	float fPushStrength, fRadius, fFalloffRadius;
	
	GetCmdArg(1, strBuffer, sizeof(strBuffer)); iClient        = StringToInt(strBuffer);
	GetCmdArg(2, strBuffer, sizeof(strBuffer)); iDamage        = StringToInt(strBuffer);
	GetCmdArg(3, strBuffer, sizeof(strBuffer)); fPushStrength  = StringToFloat(strBuffer);
	GetCmdArg(4, strBuffer, sizeof(strBuffer)); fRadius        = StringToFloat(strBuffer);
	GetCmdArg(5, strBuffer, sizeof(strBuffer)); fFalloffRadius = StringToFloat(strBuffer);

	if (!IsValidClient(iClient)) return Plugin_Handled;
	
	iTeam = GetClientTeam(iClient);
	GetClientAbsOrigin(iClient, fPosition);

	for (iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!(IsValidClientEx(iClient, true) && (GetClientTeam(iClient) == iTeam))) continue;
		
		float fPlayerPosition[3];
		GetClientEyePosition(iClient, fPlayerPosition);
		float fDistanceToShockwave = GetVectorDistance(fPosition, fPlayerPosition);

		if (!(fDistanceToShockwave < fRadius)) continue;

		float fImpulse[3];
		float fFinalPush;
		int iFinalDamage;
		fImpulse[0] = fPlayerPosition[0] - fPosition[0];
		fImpulse[1] = fPlayerPosition[1] - fPosition[1];
		fImpulse[2] = fPlayerPosition[2] - fPosition[2];
		NormalizeVector(fImpulse, fImpulse);
		
		if (fImpulse[2] < 0.4) { fImpulse[2] = 0.4; NormalizeVector(fImpulse, fImpulse); }

		if (fDistanceToShockwave < fFalloffRadius)
		{
			fFinalPush = fPushStrength;
			iFinalDamage = iDamage;
		}
		else
		{
			float fImpact = (1.0 - ((fDistanceToShockwave - fFalloffRadius) / (fRadius - fFalloffRadius)));
			fFinalPush   = fImpact * fPushStrength;
			iFinalDamage = RoundToFloor(fImpact * iDamage);
		}

		ScaleVector(fImpulse, fFinalPush);
		SlapPlayer(iClient, iFinalDamage, true);
		SetEntPropVector(iClient, Prop_Data, "m_vecAbsVelocity", fImpulse);
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
 * @param hDataPack         DataPack containing commands to execute.
 * @param iClass            Rocket class index.
 * @param iRocket           Rocket entity index.
 * @param iOwner            Owner client index.
 * @param iTarget           Target client index.
 * @param iLastDead         Last dead client index.
 * @param fSpeed            Current rocket speed (Hammer units/s).
 * @param iNumDeflections   Number of deflections.
 * @param fMphSpeed         Current rocket speed (MPH).
 */
void ExecuteCommands(DataPack hDataPack, int iClass, int iRocket, int iOwner, int iTarget, int iLastDead, float fSpeed, int iNumDeflections, float fMphSpeed)
{
	hDataPack.Reset(false);
	int iNumCommands = hDataPack.ReadCell();

	while (iNumCommands-- > 0)
	{
		char strCmd[256], strBuffer[32];

		hDataPack.ReadString(strCmd, sizeof(strCmd));
		ReplaceString(strCmd, sizeof(strCmd), "@name", RocketClassLongName[iClass]);
		FormatEx(strBuffer, sizeof(strBuffer), "%i", iRocket);                           ReplaceString(strCmd, sizeof(strCmd), "@rocket", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%i", iOwner);                            ReplaceString(strCmd, sizeof(strCmd), "@owner", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%i", iTarget);                           ReplaceString(strCmd, sizeof(strCmd), "@target", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%i", iLastDead);                         ReplaceString(strCmd, sizeof(strCmd), "@dead", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%i", iNumDeflections);                   ReplaceString(strCmd, sizeof(strCmd), "@deflections", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%f", fSpeed);                            ReplaceString(strCmd, sizeof(strCmd), "@speed", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%i", RoundToNearest(fMphSpeed));         ReplaceString(strCmd, sizeof(strCmd), "@mphspeed", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%i", RoundToNearest(fSpeed * HAMMER_TO_MPH)); ReplaceString(strCmd, sizeof(strCmd), "@capmphspeed", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%f", fMphSpeed / HAMMER_TO_MPH);              ReplaceString(strCmd, sizeof(strCmd), "@nocapspeed", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%.2f", fSpeed);                          ReplaceString(strCmd, sizeof(strCmd), "@2dspeed", strBuffer);
		FormatEx(strBuffer, sizeof(strBuffer), "%.2f", fMphSpeed / HAMMER_TO_MPH);            ReplaceString(strCmd, sizeof(strCmd), "@2dnocapspeed", strBuffer);

		ServerCommand(strCmd);
	}
}

/**
 * Parses a dodgeball configuration file (KeyValues format).
 * Loads general settings, rocket classes, and spawner classes.
 */
void ParseConfigurations(char[] strConfigFile = "general.cfg")
{
	char strPath[PLATFORM_MAX_PATH];
	char strFileName[PLATFORM_MAX_PATH];
	FormatEx(strFileName, sizeof(strFileName), "configs/dodgeball/%s", strConfigFile);
	BuildPath(Path_SM, strPath, sizeof(strPath), strFileName);
	LogMessage("Executing configuration file %s", strPath);

	if (!FileExists(strPath, true)) return;

	KeyValues kvConfig = new KeyValues("TF2_Dodgeball");
	if (!kvConfig.ImportFromFile(strPath)) SetFailState("Error while parsing the configuration file.");

	kvConfig.GotoFirstSubKey();
	do
	{
		char strSection[64]; kvConfig.GetSectionName(strSection, sizeof(strSection));
		if (StrEqual(strSection, "general"))       ParseGeneral(kvConfig);
		else if (StrEqual(strSection, "classes"))  ParseClasses(kvConfig);
		else if (StrEqual(strSection, "spawners")) ParseSpawners(kvConfig);
		else if (StrEqual(strSection, "presets"))  ParsePresets(kvConfig);
	}
	while (kvConfig.GotoNextKey());

	delete kvConfig;
	Forward_OnRocketsConfigExecuted(strConfigFile);
}

/** Parses the "general" section of the config (music and scaling settings). */
void ParseGeneral(KeyValues kvConfig)
{
	// Scaling mode flags (read before music to avoid early return)
	UseOrbitCoefficient   = view_as<bool>(kvConfig.GetNum("orbit coefficient", 0));
	UseTargetSpeedScaling = view_as<bool>(kvConfig.GetNum("target speed scaling", 0));
	UseSmoothElevation    = view_as<bool>(kvConfig.GetNum("smooth elevation", 0));
	UseBounceVerticalScale = view_as<bool>(kvConfig.GetNum("bounce vertical scale", 0));

	MusicEnabled = view_as<bool>(kvConfig.GetNum("music", 0));
	if (!MusicEnabled) return;

	UseWebPlayer = view_as<bool>(kvConfig.GetNum("use web player", 0));
	kvConfig.GetString("web player url", WebPlayerUrl, sizeof(WebPlayerUrl));
	Music[Music_RoundStart] = kvConfig.GetString("round start",      MusicPath[Music_RoundStart], PLATFORM_MAX_PATH) && MusicPath[Music_RoundStart][0];
	Music[Music_RoundWin]   = kvConfig.GetString("round end (win)",  MusicPath[Music_RoundWin],   PLATFORM_MAX_PATH) && MusicPath[Music_RoundWin][0];
	Music[Music_RoundLose]  = kvConfig.GetString("round end (lose)", MusicPath[Music_RoundLose],  PLATFORM_MAX_PATH) && MusicPath[Music_RoundLose][0];
	Music[Music_Gameplay]   = kvConfig.GetString("gameplay",         MusicPath[Music_Gameplay],   PLATFORM_MAX_PATH) && MusicPath[Music_Gameplay][0];
}

/** Parses the "classes" section of the config (rocket class definitions). */
void ParseClasses(KeyValues kvConfig)
{
	char strName[64];
	char strBuffer[256];
	kvConfig.GotoFirstSubKey();
	do
	{
		int iIndex = RocketClassCount;
		RocketFlags iFlags;

		kvConfig.GetSectionName(strName, sizeof(strName));        strcopy(RocketClassName[iIndex], 16, strName);
		kvConfig.GetString("name", strBuffer, sizeof(strBuffer)); strcopy(RocketClassLongName[iIndex], 32, strBuffer);
		
		if (kvConfig.GetString("model", strBuffer, sizeof(strBuffer)))
		{
			strcopy(RocketClassModel[iIndex], PLATFORM_MAX_PATH, strBuffer);
			if (RocketClassModel[iIndex][0])
			{
				iFlags |= RocketFlag_CustomModel;
				if (kvConfig.GetNum("is animated", 0)) iFlags |= RocketFlag_IsAnimated;
			}
		}

		kvConfig.GetString("behaviour", strBuffer, sizeof(strBuffer), "homing");
		if (StrEqual(strBuffer, "homing")) RocketClassBehaviour[iIndex] = Behaviour_Homing;
		else if (StrEqual(strBuffer, "legacy homing")) RocketClassBehaviour[iIndex] = Behaviour_LegacyHoming;
		else RocketClassBehaviour[iIndex] = Behaviour_Unknown;

		if (kvConfig.GetNum("play spawn sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlaySpawnSound;
			if (kvConfig.GetString("spawn sound", RocketClassSpawnSound[iIndex], PLATFORM_MAX_PATH) && RocketClassSpawnSound[iIndex][0])
			{
				iFlags |= RocketFlag_CustomSpawnSound;
			}
		}

		if (kvConfig.GetNum("play beep sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlayBeepSound;
			RocketClassBeepInterval[iIndex] = kvConfig.GetFloat("beep interval", 0.5);
			if (kvConfig.GetString("beep sound", RocketClassBeepSound[iIndex], PLATFORM_MAX_PATH) && RocketClassBeepSound[iIndex][0])
			{
				iFlags |= RocketFlag_CustomBeepSound;
			}
		}

		if (kvConfig.GetNum("play alert sound", 0) == 1)
		{
			iFlags |= RocketFlag_PlayAlertSound;
			if (kvConfig.GetString("alert sound", RocketClassAlertSound[iIndex], PLATFORM_MAX_PATH) && RocketClassAlertSound[iIndex][0])
			{
				iFlags |= RocketFlag_CustomAlertSound;
			}
		}

		if (kvConfig.GetNum("elevate on deflect", 0) == 1) iFlags |= RocketFlag_ElevateOnDeflect;
		if (kvConfig.GetNum("neutral rocket", 0) == 1)     iFlags |= RocketFlag_IsNeutral;
		if (kvConfig.GetNum("keep direction", 0) == 1)     iFlags |= RocketFlag_KeepDirection;
		if (kvConfig.GetNum("teamless deflects", 0) == 1)  iFlags |= RocketFlag_TeamlessHits;
		if (kvConfig.GetNum("reset bounces", 0) == 1)      iFlags |= RocketFlag_ResetBounces;
		if (kvConfig.GetNum("no bounce drags", 0) == 1)    iFlags |= RocketFlag_NoBounceDrags;
		if (kvConfig.GetNum("can be stolen", 0) == 1)      iFlags |= RocketFlag_CanBeStolen;
		if (kvConfig.GetNum("steal team check", 0) == 1)   iFlags |= RocketFlag_StealTeamCheck;

		RocketClassDamage[iIndex]            = kvConfig.GetFloat("damage");
		RocketClassDamageIncrement[iIndex]   = kvConfig.GetFloat("damage increment");
		RocketClassCritChance[iIndex]        = kvConfig.GetFloat("critical chance");
		RocketClassSpeed[iIndex]             = kvConfig.GetFloat("speed");
		RocketClassSpeedIncrement[iIndex]    = kvConfig.GetFloat("speed increment");
		if ((RocketClassSpeedLimit[iIndex] = kvConfig.GetFloat("speed limit")) != 0.0)
		{
			iFlags |= RocketFlag_IsSpeedLimited;
		}

		RocketClassTurnRate[iIndex]          = kvConfig.GetFloat("turn rate");
		RocketClassTurnRateIncrement[iIndex] = kvConfig.GetFloat("turn rate increment");
		if ((RocketClassTurnRateLimit[iIndex] = kvConfig.GetFloat("turn rate limit")) != 0.0)
		{
			iFlags |= RocketFlag_IsTRLimited;
		}

		RocketClassElevationRate[iIndex]     = kvConfig.GetFloat("elevation rate");
		RocketClassElevationLimit[iIndex]    = kvConfig.GetFloat("elevation limit");
		RocketClassControlDelay[iIndex]      = kvConfig.GetFloat("control delay");
		RocketClassMaxBounces[iIndex]        = kvConfig.GetNum("max bounces");
		RocketClassBounceScale[iIndex]       = kvConfig.GetFloat("bounce scale", 1.0);
		RocketClassPlayerModifier[iIndex]    = kvConfig.GetFloat("no. players modifier");
		RocketClassRocketsModifier[iIndex]   = kvConfig.GetFloat("no. rockets modifier");
		RocketClassTargetWeight[iIndex]      = kvConfig.GetFloat("direction to target weight");

		// Scaling mode: orbit coefficient
		RocketClassOrbitTightness[iIndex]    = kvConfig.GetFloat("orbit tightness", 0.0);

		// Scaling mode: target speed
		RocketClassMaxSpeed[iIndex]          = kvConfig.GetFloat("max speed", 0.0);
		RocketClassMaxDeflections[iIndex]    = kvConfig.GetNum("max deflections", 0);
		if (UseTargetSpeedScaling && RocketClassMaxDeflections[iIndex] > 0)
		{
			RocketClassSpeedIncrement[iIndex] = (RocketClassMaxSpeed[iIndex] - RocketClassSpeed[iIndex]) / float(RocketClassMaxDeflections[iIndex]);
		}

		// Scaling mode: bounce vertical scale
		RocketClassBounceVerticalScale[iIndex] = kvConfig.GetFloat("bounce vertical ratio", 1.0);
		RocketClassBounceMaxVerticalSpeed[iIndex] = kvConfig.GetFloat("bounce max vertical speed", 0.0);
		RocketClassDragPauseDuration[iIndex] = kvConfig.GetFloat("drag pause duration", 0.1);
		
		DataPack hCmds = null;
		kvConfig.GetString("on spawn", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != null) { iFlags |= RocketFlag_OnSpawnCmd; RocketClassCmdsOnSpawn[iIndex] = hCmds; }
		
		kvConfig.GetString("on deflect", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != null) { iFlags |= RocketFlag_OnDeflectCmd; RocketClassCmdsOnDeflect[iIndex] = hCmds; }

		kvConfig.GetString("on kill", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != null) { iFlags |= RocketFlag_OnKillCmd; RocketClassCmdsOnKill[iIndex] = hCmds; }

		kvConfig.GetString("on explode", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != null) { iFlags |= RocketFlag_OnExplodeCmd; RocketClassCmdsOnExplode[iIndex] = hCmds; }

		kvConfig.GetString("on no target", strBuffer, sizeof(strBuffer));
		if ((hCmds = ParseCommands(strBuffer)) != null) { iFlags |= RocketFlag_OnNoTargetCmd; RocketClassCmdsOnNoTarget[iIndex] = hCmds; }

		RocketClassFlags[iIndex] = iFlags;
		RocketClassCount++;

		if (RocketClassCount >= MAX_ROCKET_CLASSES)
		{
			LogError("Reached maximum rocket classes (%d). Remaining classes will be ignored.", MAX_ROCKET_CLASSES);
			break;
		}
	}
	while (kvConfig.GotoNextKey());
	kvConfig.GoBack();
}

/** Parses the "spawners" section of the config (spawner class definitions). */
void ParseSpawners(KeyValues kvConfig)
{
	char strBuffer[256];
	kvConfig.GotoFirstSubKey();
	do
	{
		int iIndex = SpawnersCount;

		kvConfig.GetSectionName(strBuffer, sizeof(strBuffer)); strcopy(SpawnersName[iIndex], 32, strBuffer);
		SpawnersMaxRockets[iIndex] = kvConfig.GetNum("max rockets", 1);
		SpawnersInterval[iIndex]   = kvConfig.GetFloat("interval", 1.0);

		SpawnersChancesTable[iIndex] = new ArrayList();
		for (int iClassIndex = 0; iClassIndex < RocketClassCount; iClassIndex++)
		{
			FormatEx(strBuffer, sizeof(strBuffer), "%s%%", RocketClassName[iClassIndex]);
			SpawnersChancesTable[iIndex].Push(kvConfig.GetNum(strBuffer, 0));
		}

		SpawnersTrie.SetValue(SpawnersName[iIndex], iIndex);
		SpawnersCount++;
	}
	while (kvConfig.GotoNextKey());

	kvConfig.GoBack();
	SpawnersTrie.GetValue("red", DefaultRedSpawner);
	SpawnersTrie.GetValue("blu", DefaultBluSpawner);
}

/** Parses the "presets" section of the config (gameplay preset definitions). */
void ParsePresets(KeyValues kvConfig)
{
	kvConfig.GotoFirstSubKey();
	do
	{
		int iIndex = PresetCount;

		kvConfig.GetString("name", PresetName[iIndex], sizeof(PresetName[]));
		kvConfig.GetString("rocket class", PresetRocketClass[iIndex], sizeof(PresetRocketClass[]));
		PresetMaxRockets[iIndex]    = kvConfig.GetNum("max rockets", 1);
		PresetSpawnInterval[iIndex] = kvConfig.GetFloat("spawn interval", 0.0);

		PresetCount++;

		if (PresetCount >= MAX_PRESETS)
		{
			LogError("Reached maximum presets (%d). Remaining presets will be ignored.", MAX_PRESETS);
			break;
		}
	}
	while (kvConfig.GotoNextKey());
	kvConfig.GoBack();
}

/**
 * Parses a semicolon-separated command string into a DataPack.
 * Each command between semicolons becomes a separate entry.
 *
 * @param strLine   The command string to parse (e.g., "sm_slay @target; sm_beacon @owner").
 * @return          DataPack containing the commands, or null if empty.
 */
DataPack ParseCommands(char[] strLine)
{
    TrimString(strLine);
    if (!strLine[0]) return null;

    // Use static array to avoid heap allocation on each call
    // This prevents "Not enough space on the heap" when parsing many rocket classes
    static char strParts[32][256];
    int iNumParts = ExplodeString(strLine, ";", strParts, 32, 256);
    
    ArrayList hCommands = new ArrayList(ByteCountToCells(256));
    char strBuffer[256];

    for (int i = 0; i < iNumParts; i++)
    {
        TrimString(strParts[i]);
        if (strParts[i][0]) hCommands.PushString(strParts[i]);
    }
    
    int iNumCommands = hCommands.Length;
    if (iNumCommands == 0)
    {
        delete hCommands;
        return null;
    }

    DataPack hDataPack = new DataPack();
    hDataPack.WriteCell(iNumCommands);
    for (int i = 0; i < iNumCommands; i++)
    {
        hCommands.GetString(i, strBuffer, sizeof(strBuffer));
        hDataPack.WriteString(strBuffer);
    }

    delete hCommands;
    return hDataPack;
}