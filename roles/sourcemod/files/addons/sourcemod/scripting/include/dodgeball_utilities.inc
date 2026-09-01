#if defined _dodgeball_utilities_included
  #endinput
#endif
#define _dodgeball_utilities_included

/**
 * Contains general-purpose utility and helper functions for the
 * TF2 Dodgeball plugin.
 */
 
/**
 * Converts a duration in seconds to server ticks on the current tickrate.
 * Used to author drag / bounce windows in real time (seconds) in cfg files
 * so feel is identical across 66 / 100 / 128-tick servers.
 *
 * 0.0 returns 0 (no window). Any positive value returns at least 1 tick so a
 * tiny cfg value doesn't round to 0.
 */
stock int SecondsToTicks(float seconds)
{
	if (seconds <= 0.0) return 0;
	int out = RoundToNearest(seconds / GetTickInterval());
	return (out < 1) ? 1 : out;
}

stock void StopSoundToAll(int channel, const char[] sound)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsValidClientEx(client))
		{
			StopSound(client, channel, sound);
		}
	}
}

// *********************************************************************************
// VECTOR & MATH UTILITIES
// *********************************************************************************

/**
 * Copies the contents from one vector to another.
 */
stock void CopyVectors(float from[3], float to[3])
{
	to[0] = from[0];
	to[1] = from[1];
	to[2] = from[2];
}

/**
 * Calculates the linear interpolation of two vectors.
 */
stock void LerpVectors(float a[3], float b[3], float c[3], float t)
{
	t = (t < 0.0) ? 0.0 : (t > 1.0) ? 1.0 : t;
	
	c[0] = a[0] + (b[0] - a[0]) * t;
	c[1] = a[1] + (b[1] - a[1]) * t;
	c[2] = a[2] + (b[2] - a[2]) * t;
}

/**
 * Gets the distance between two entities.
 */
stock float GetEntitiesDistance(int ent1, int ent2)
{
	float origin1[3];
	GetEntPropVector(ent1, Prop_Send, "m_vecOrigin", origin1);
	
	float origin2[3];
	GetEntPropVector(ent2, Prop_Send, "m_vecOrigin", origin2);
	
	return GetVectorDistance(origin1, origin2);
}

/**
 * Returns the minimum of two float values.
 */
stock float FMin(float a, float b)
{
	return (a < b) ? a : b;
}

/**
 * Returns a random integer within a given range (inclusive).
 */
stock int GetURandomIntRange(int min, int max)
{
	return min + (GetURandomInt() % (max - min + 1));
}

/**
 * Returns a random float within a given range.
 */
stock float GetURandomFloatRange(float min, float max)
{
	return min + (GetURandomFloat() * (max - min));
}

// *********************************************************************************
// CLIENT & GAMEPLAY UTILITIES
// *********************************************************************************

/**
 * Checks if a client index is valid, connected, and optionally alive.
 */
stock bool IsValidClient(int client, bool alive = false)
{
	return client >= 1 &&
	       client <= MaxClients &&
	       IsClientInGame(client) &&
	       (!alive || IsPlayerAlive(client));
}

/**
 * IsValidClient() but without the index range check.
 */
stock bool IsValidClientEx(int client, bool alive = false)
{
	return IsClientInGame(client) && (!alive || IsPlayerAlive(client));
}

/**
 * Full recount of g_AliveCount[] from scratch. Authoritative reset path —
 * called at round_start, EnableDodgeBall, and as a safety net if drift is
 * ever suspected. Counters are also maintained incrementally via the player
 * spawn / death / team-change / disconnect events.
 */
void RecountAlive()
{
	g_AliveCount[2] = 0;
	g_AliveCount[3] = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i)) continue;
		int t = GetClientTeam(i);
		if (t == 2 || t == 3) g_AliveCount[t]++;
	}
}

/**
 * Checks if there are living players on both teams.
 *
 * Fast-path: reads the cached per-team alive counts maintained by the
 * player_spawn / player_death / player_team / OnClientDisconnect handlers.
 * Replaces the previous O(MaxClients) IsValidClientEx scan, which fired
 * every 0.1 s from OnDodgeBallGameFrame.
 */
stock bool BothTeamsPlaying()
{
	return (g_AliveCount[2] > 0 && g_AliveCount[3] > 0);

	// --- DORMANT: original linear-scan implementation. Kept for reference /
	// quick revert if the cached counters ever drift. ---
	// bool redFound, bluFound;
	// for (int client = 1; client <= MaxClients; client++)
	// {
	// 	if (!IsValidClientEx(client, true)) continue;
	// 	int team = GetClientTeam(client);
	// 	if (team == view_as<int>(TFTeam_Red)) redFound = true;
	// 	if (team == view_as<int>(TFTeam_Blue)) bluFound = true;
	// }
	// return redFound && bluFound;
}

/**
 * Counts the number of players currently alive.
 *
 * Fast-path: returns RED + BLU from the cached counters. Spectator (team 1)
 * is intentionally excluded — the original loop counted any in-game alive
 * player, but in dodgeball spectators are never alive and team-0/1 alive
 * players don't exist in practice.
 */
stock int CountAlivePlayers()
{
	return g_AliveCount[2] + g_AliveCount[3];

	// --- DORMANT: original linear-scan implementation. ---
	// int count = 0;
	// for (int client = 1; client <= MaxClients; client++)
	// {
	// 	if (IsValidClientEx(client, true)) count++;
	// }
	// return count;
}

/**
 * Gets the opposing team.
 */
stock int GetAnalogueTeam(int team)
{
	if (team == view_as<int>(TFTeam_Red)) return view_as<int>(TFTeam_Blue);
	
	return view_as<int>(TFTeam_Red);
}

/**
 * Selects a target for a homing rocket based on team and optional directional weighting.
 * Falls back to random selection if rocket entity is invalid.
 */
stock int SelectTarget(int team, int rocket = -1)
{
	// Fast no-target early-out: if the cached counter says zero alive on
	// the requested team, there's nothing to pick. team==0 means "any"
	// (neutral rocket), so we still need the full scan in that case.
	if ((team == 2 || team == 3) && g_AliveCount[team] == 0)
	{
		return -1;
	}

	int target = -1;
	float targetWeight = 0.0;
	float rocketPosition[3];
	float rocketDirection[3];
	float weight;
	bool useRocket = false;
	int owner = -1;
	
	if (rocket != -1)
	{
		int entity = EntRefToEntIndex(RocketEntity[rocket]);
		
		// Validate entity before any property access to prevent crashes
		if (entity != -1 && IsValidEntity(entity))
		{
			int rocketClass = RocketClass[rocket];
			owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", rocketPosition);
			CopyVectors(RocketDirection[rocket], rocketDirection);
			weight = RocketClassTargetWeight[rocketClass];
			
			useRocket = true;
		}
		// If entity is invalid, useRocket stays false and we fall back to random selection
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsValidClientEx(client, true)) continue;
		if (team && GetClientTeam(client) != team) continue;
		if (client == owner) continue;
		
		float newWeight = GetURandomFloatRange(0.0, 100.0);
		
		if (useRocket)
		{
			float clientPosition[3]; GetClientEyePosition(client, clientPosition);
			float directionToClient[3]; MakeVectorFromPoints(rocketPosition, clientPosition, directionToClient);
			
			newWeight += GetVectorDotProduct(rocketDirection, directionToClient) * weight;
		}
		
		if ((target == -1) || newWeight >= targetWeight)
		{
			target = client;
			targetWeight = newWeight;
		}
	}
	
	return target;
}

// *********************************************************************************
// EFFECT & RESOURCE UTILITIES
// *********************************************************************************

/**
 * Shows a hidden MOTD panel, often used for streaming audio.
 */
stock void ShowHiddenMOTDPanel(int client, char[] title, char[] msg, char[] type = "2")
{
	KeyValues panel = new KeyValues("data");
	panel.SetString("title", title);
	panel.SetString("type", type);
	panel.SetString("msg", msg);
	ShowVGUIPanel(client, "info", panel, false);
	delete panel;
}

/**
 * Spawn an info_particle_system entity. Unified primitive for all particle spawns.
 * Handles both the "positioned + auto-destruct" shape (PlayParticle, nuke effects)
 * and the "parented + persistent" shape (UpdateCritGlow, attached trails).
 *
 * @param particleName      Particle effect name. Must be in the ParticleEffectNames
 *                          string table (precached) or nothing renders.
 * @param position          World position. Used only when parent = 0.
 * @param angles            World angles. Used only when parent = 0.
 * @param parent            Parent entity to attach to via SetParent. 0 = unparented.
 * @param attachmentName    Attachment point on parent. "" = parent origin only.
 * @param effectTime        Seconds until "Stop" input fires. 0 = no stop timer (persistent).
 * @param lifeTime          Seconds until entity is killed. 0 = no kill timer (manual cleanup).
 * @return                  Entity index on success, -1 on failure.
 */
stock int SpawnParticleSystem(const char[] particleName,
                              const float position[3]  = NULL_VECTOR,
                              const float angles[3]    = NULL_VECTOR,
                              int parent               = 0,
                              const char[] attachmentName = "",
                              float effectTime         = 0.0,
                              float lifeTime           = 0.0)
{
	int entity = CreateEntityByName("info_particle_system");
	if (entity == -1)
	{
		LogError("SpawnParticleSystem: could not create info_particle_system");
		return -1;
	}

	DispatchKeyValue(entity, "effect_name", particleName);
	DispatchSpawn(entity);
	ActivateEntity(entity);

	if (parent > 0 && IsValidEntity(parent))
	{
		SetVariantString("!activator");
		AcceptEntityInput(entity, "SetParent", parent, entity);

		if (attachmentName[0] != '\0' && LookupEntityAttachment(parent, attachmentName) > 0)
		{
			SetVariantString(attachmentName);
			AcceptEntityInput(entity, "SetParentAttachment", parent, entity);
		}
	}
	else
	{
		TeleportEntity(entity, position, angles, NULL_VECTOR);
	}

	AcceptEntityInput(entity, "Start");

	if (effectTime > 0.0)
	{
		CreateTimer(effectTime, StopParticle, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}
	if (lifeTime > 0.0)
	{
		CreateTimer(lifeTime, KillParticle, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);
	}

	return entity;
}

/**
 * Plays a one-shot positioned particle system with auto-destruction.
 * Thin wrapper over SpawnParticleSystem.
 */
stock void PlayParticle(float position[3], float angles[3], char[] particleName, float effectTime = 5.0, float lifeTime = 9.0)
{
	SpawnParticleSystem(particleName, position, angles, 0, "", effectTime, lifeTime);
}

/**
 * Timer callback to stop a particle system.
 */
public Action StopParticle(Handle timer, any entityRef)
{
	if (entityRef == INVALID_ENT_REFERENCE) return Plugin_Continue;
	
	int entity = EntRefToEntIndex(entityRef);
	if (entity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(entity, "Stop");
	}
	
	return Plugin_Continue;
}

/**
 * Timer callback to kill a particle system entity.
 */
public Action KillParticle(Handle timer, any entityRef)
{
	if (entityRef == INVALID_ENT_REFERENCE) return Plugin_Continue;
	
	int entity = EntRefToEntIndex(entityRef);
	if (entity != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(entity);
	}
	
	return Plugin_Continue;
}

/**
 * Precaches a particle system by creating and quickly destroying it.
 */
stock void PrecacheParticle(char[] particleName)
{
	PlayParticle(view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), particleName, 0.1, 0.1);
}

/**
 * Precaches a sound and adds it to the download table.
 */
stock void PrecacheSoundEx(char[] fileName, bool preload = false, bool addToDownloadTable = false)
{
	char finalPath[PLATFORM_MAX_PATH];
	FormatEx(finalPath, sizeof(finalPath), "sound/%s", fileName);
	PrecacheSound(fileName, preload);
	
	if (addToDownloadTable) AddFileToDownloadsTable(finalPath);
}

/**
 * Removes illegal characters from a string.
 */
stock void CleanString(char[] buffer)
{
	int length = strlen(buffer);
	for (int pos = 0; pos < length; pos++)
	{
		switch (buffer[pos])
		{
			case '\r', '\n', '\t': buffer[pos] = ' ';
		}
	}
	TrimString(buffer);
}

/**
 * Precaches a model and its dependencies and adds them to the download table.
 */
stock void PrecacheModelEx(char[] fileName, bool preload = false, bool addToDownloadTable = false)
{
	PrecacheModel(fileName, preload);
	
	if (!addToDownloadTable) return;
	
	char depFileName[PLATFORM_MAX_PATH];
	FormatEx(depFileName, sizeof(depFileName), "%s.res", fileName);
	
	if (!FileExists(depFileName)) return;
	
	File stream = OpenFile(depFileName, "r");
	if (stream == null)
	{
		LogError("Error, can't read file containing model dependencies: %s", depFileName);
		return;
	}
	
	while(!stream.EndOfFile())
	{
		char buffer[PLATFORM_MAX_PATH];
		stream.ReadLine(buffer, sizeof(buffer));
		CleanString(buffer);
		
		if (!FileExists(buffer, true)) continue;
		
		if (StrContains(buffer, ".vmt", false) != -1)      PrecacheDecal(buffer, true);
		else if (StrContains(buffer, ".mdl", false) != -1) PrecacheModel(buffer, true);
		else if (StrContains(buffer, ".pcf", false) != -1) PrecacheGeneric(buffer, true);
		
		AddFileToDownloadsTable(buffer);
	}
	
	delete stream;
}

/**
 * Custom trace ray filter to exclude a specific entity.
 */
public bool TEF_ExcludeEntity(int entity, int contentsMask, any data)
{
	return (entity != data);
}