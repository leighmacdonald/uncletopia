#if defined _dodgeball_core_included
  #endinput
#endif
#define _dodgeball_core_included

/**
 * Contains core gamemode logic: enabling/disabling the mod and the main game timer.
 */

// Tracks whether game events have been hooked (to prevent double-unhook errors)
static bool EventsHooked = false;

/** Checks if the current map is a dodgeball map (starts with "tfdb_", "db_", or "dbs_"). */
bool IsDodgeBallMap()
{
	char map[64]; GetCurrentMap(map, sizeof(map));
	GetMapDisplayName(map, map, sizeof(map));
	return (StrContains(map, "tfdb_", false) == 0 ||
	        StrContains(map, "db_", false) == 0 ||
	        StrContains(map, "dbs_", false) == 0);
}

/**
 * Enables the dodgeball gamemode. Loads configuration, hooks events,
 * precaches sounds/models, and starts the game timer.
 */
void EnableDodgeBall()
{
	if (Enabled) return;

	char mapName[64]; GetCurrentMap(mapName, sizeof(mapName));
	GetMapDisplayName(mapName, mapName, sizeof(mapName));
	char mapFile[PLATFORM_MAX_PATH]; FormatEx(mapFile, sizeof(mapFile), "%s.cfg", mapName);

	ParseConfigurations();
	ParseConfigurations("presets.cfg");
	ParseConfigurations(mapFile);

	if (RocketClassCount == 0)   SetFailState("No rocket class defined.");
	if (SpawnersCount == 0)      SetFailState("No spawner class defined.");
	if (DefaultRedSpawner == -1) SetFailState("No spawner class definition for the Red spawners exists in the config file.");
	if (DefaultBluSpawner == -1) SetFailState("No spawner class definition for the Blu spawners exists in the config file.");

	// Only hook events if not already hooked
	if (!EventsHooked)
	{
		HookEventEx("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy);
		HookEventEx("teamplay_round_active", OnSetupFinished, EventHookMode_PostNoCopy);  // For non-Arena modes
		HookEventEx("arena_round_start", OnSetupFinished, EventHookMode_PostNoCopy);      // For Arena mode
		HookEventEx("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
		HookEventEx("player_spawn", OnPlayerSpawn, EventHookMode_Post);
		HookEventEx("player_death", OnPlayerDeath, EventHookMode_Pre);
		HookEventEx("post_inventory_application", OnPlayerInventory, EventHookMode_Post);
		HookEventEx("teamplay_broadcast_audio", OnBroadcastAudio, EventHookMode_Pre);
		HookEventEx("object_deflected", OnObjectDeflected);
		EventsHooked = true;
	}

	AddMultiTargetFilter("@stealer", MLTargetFilterStealer, "last stealer", false);
	AddMultiTargetFilter("@!stealer", MLTargetFilterStealer, "non last stealer", false);

	PrecacheSound(SOUND_DEFAULT_SPAWN, true);
	PrecacheSound(SOUND_DEFAULT_BEEP, true);
	PrecacheSound(SOUND_DEFAULT_ALERT, true);
	PrecacheSound(SOUND_DEFAULT_SPEEDUP, true);

	if (MusicEnabled)
	{
		if (Music[Music_RoundStart]) PrecacheSoundEx(MusicPath[Music_RoundStart], true, true);
		if (Music[Music_RoundWin])   PrecacheSoundEx(MusicPath[Music_RoundWin], true, true);
		if (Music[Music_RoundLose])  PrecacheSoundEx(MusicPath[Music_RoundLose], true, true);
		if (Music[Music_Gameplay])   PrecacheSoundEx(MusicPath[Music_Gameplay], true, true);
	}

	PrecacheParticle(PARTICLE_NUKE_1);
	PrecacheParticle(PARTICLE_NUKE_2);
	PrecacheParticle(PARTICLE_NUKE_3);
	PrecacheParticle(PARTICLE_NUKE_4);
	PrecacheParticle(PARTICLE_NUKE_5);
	PrecacheParticle(PARTICLE_NUKE_COLLUMN);

	for (int i = 0; i < RocketClassCount; i++)
	{
		RocketFlags flags = RocketClassFlags[i];
		if (TestFlags(flags, RocketFlag_CustomModel))      PrecacheModelEx(RocketClassModel[i], true, true);
		if (TestFlags(flags, RocketFlag_CustomSpawnSound)) PrecacheSoundEx(RocketClassSpawnSound[i], true, true);
		if (TestFlags(flags, RocketFlag_CustomBeepSound))  PrecacheSoundEx(RocketClassBeepSound[i], true, true);
		if (TestFlags(flags, RocketFlag_CustomAlertSound)) PrecacheSoundEx(RocketClassAlertSound[i], true, true);
	}

	char cfgFile[64];
	CvarEnableCfgFile.GetString(cfgFile, sizeof(cfgFile));
	ServerCommand("exec \"%s\"", cfgFile);

	Enabled      = true;
	RoundStarted = false;
	RoundCount   = 0;
}

/**
 * Disables the dodgeball gamemode. Cleans up rockets, unhooks events,
 * and resets state.
 */
void DisableDodgeBall()
{
	if (!Enabled) return;

	DestroyRockets();
	DestroyRocketClasses();
	DestroySpawners();
	PresetCount = 0;

	if (LogicTimer != null) KillTimer(LogicTimer);
	LogicTimer = null;

	Music[Music_RoundStart] =
	Music[Music_RoundWin]   =
	Music[Music_RoundLose]  =
	Music[Music_Gameplay]   = false;

	// Only unhook events if they were previously hooked
	if (EventsHooked)
	{
		UnhookEvent("teamplay_round_start", OnRoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_active", OnSetupFinished, EventHookMode_PostNoCopy);
		UnhookEvent("arena_round_start", OnSetupFinished, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);
		UnhookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
		UnhookEvent("post_inventory_application", OnPlayerInventory, EventHookMode_Post);
		UnhookEvent("teamplay_broadcast_audio", OnBroadcastAudio, EventHookMode_Pre);
		UnhookEvent("object_deflected", OnObjectDeflected);
		EventsHooked = false;
	}

	RemoveMultiTargetFilter("@stealer", MLTargetFilterStealer);
	RemoveMultiTargetFilter("@!stealer", MLTargetFilterStealer);

	char cfgFile[64]; CvarDisableCfgFile.GetString(cfgFile, sizeof(cfgFile));
	ServerCommand("exec \"%s\"", cfgFile);

	Enabled      = false;
	RoundStarted = false;
	RoundCount   = 0;
}

/**
 * This is the main logic timer for the gamemode.
 * It handles rocket spawning and the logic for "legacy homing" rockets.
 * It also calls shared logic functions like sound updates.
 */
public Action OnDodgeBallGameFrame(Handle timer, any data)
{
	if (!BothTeamsPlaying()) return Plugin_Continue;

	// Rocket Spawning Logic
	if (GetGameTime() >= NextSpawnTime)
	{
		if (LastDeadTeam == view_as<int>(TFTeam_Red))
		{
			int spawnerEntity = SpawnPointsRedEntity[CurrentRedSpawn];
			int spawnerClass  = SpawnPointsRedClass[CurrentRedSpawn];

			if (RocketCount < SpawnersMaxRockets[spawnerClass])
			{
				CreateRocket(spawnerEntity, spawnerClass, view_as<int>(TFTeam_Red));
				CurrentRedSpawn = (CurrentRedSpawn + 1) % SpawnPointsRedCount;
			}
		}
		else
		{
			int spawnerEntity = SpawnPointsBluEntity[CurrentBluSpawn];
			int spawnerClass  = SpawnPointsBluClass[CurrentBluSpawn];

			if (RocketCount < SpawnersMaxRockets[spawnerClass])
			{
				CreateRocket(spawnerEntity, spawnerClass, view_as<int>(TFTeam_Blue));
				CurrentBluSpawn = (CurrentBluSpawn + 1) % SpawnPointsBluCount;
			}
		}
	}

	// Rocket Think Logic
	int index = -1;
	while ((index = FindNextValidRocket(index)) != -1)
	{
		// This timer handles legacy homing rockets and shared logic for all rockets.
		switch (RocketClassBehaviour[RocketClass[index]])
		{
			case Behaviour_LegacyHoming:
			{
				RocketLegacyThink(index);
			}
		}
		// Shared logic (sounds, delays) is called for all rockets from here.
		SharedRocketThink(index);
	}

	return Plugin_Continue;
}
