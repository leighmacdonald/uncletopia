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

	// Initialize the O(1) entity -> rocket-slot reverse-lookup cache.
	// SourcePawn does not zero-init globals between map changes the way you'd
	// expect, and 0 is a valid slot index — so explicitly fill with -1.
	for (int i = 0; i < sizeof(g_EntityIndexToRocketSlot); i++)
	{
		g_EntityIndexToRocketSlot[i] = ROCKET_SLOT_NONE;
	}

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
		HookEventEx("player_team",  OnPlayerTeam,  EventHookMode_Post);
		HookEventEx("post_inventory_application", OnPlayerInventory, EventHookMode_Post);
		HookEventEx("teamplay_broadcast_audio", OnBroadcastAudio, EventHookMode_Pre);
		HookEventEx("object_deflected", OnObjectDeflected);
		EventsHooked = true;
	}

	// Existing clients are not guaranteed to pass through OnClientPutInServer
	// after mode toggles, so apply WeaponCanUse hook here as well.
	if (UsePushPrevention)
	{
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
			}
		}
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

	// Authoritative alive-counter reset. Subsequent maintenance is incremental
	// via player_spawn / player_death / player_team / OnClientDisconnect.
	RecountAlive();

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

	// Do NOT manually UnhookEvent here. SourceMod automatically cleans up
	// event hooks when a plugin unloads. Manual unhooking causes cascading
	// "has no active hook" / "Invalid hook callback" errors when subplugins
	// (trails, FFA, etc.) unhook shared events first, which aborts this
	// callback and leaves EventsHooked=true permanently.
	//
	// The event callbacks themselves already guard with Enabled/RoundStarted
	// checks, so leaving hooks active during map transitions is safe.

	// Explicitly unhook to keep behavior isolated to active Dodgeball mode.
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
		}
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
 * Spawner bookkeeping timer — creates new rockets when NextSpawnTime elapses.
 * Per-rocket think (homing, legacy-behaviour step, shared logic) runs in
 * OnRocketThink, dispatched from OnGameFrame — not here.
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

	// Per-rocket think (legacy-behaviour step + shared logic) runs inside OnRocketThink,
	// dispatched from OnGameFrame and gated internally to 10 Hz. This timer only handles
	// spawner bookkeeping now — rockets manage their own cadence.

	return Plugin_Continue;
}
