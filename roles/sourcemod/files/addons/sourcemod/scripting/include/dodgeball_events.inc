#if defined _dodgeball_events_included
  #endinput
#endif
#define _dodgeball_events_included

/**
 * Handles all game events hooked by the plugin.
 */

/** Called when a new round starts. Resets steal info and plays round start music. */
public void OnRoundStart(Event event, char[] eventName, bool dontBroadcast)
{
	if (Music[Music_RoundStart])
	{
		EmitSoundToAll(MusicPath[Music_RoundStart]);
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		StealInfo[client].stoleRocket = false;
		StealInfo[client].rocketsStolen = 0;
	}

	// Authoritative reset of cached alive counters. Catches any drift that
	// might have accumulated through the round.
	RecountAlive();
}

/** Called when setup phase ends. Initializes spawn points and starts the game timer. */
public void OnSetupFinished(Event event, char[] eventName, bool dontBroadcast)
{
	// Guard against being called twice (both teamplay_round_active and arena_round_start hook this)
	if (RoundStarted) return;
	if (!BothTeamsPlaying()) return;

	PopulateSpawnPoints();
	if (LastDeadTeam == 0) LastDeadTeam = GetURandomIntRange(view_as<int>(TFTeam_Red), view_as<int>(TFTeam_Blue));
	if (!IsValidClient(LastDeadClient)) LastDeadClient = 0;
	
	LogicTimer      = CreateTimer(FPS_LOGIC_INTERVAL, OnDodgeBallGameFrame, _, TIMER_REPEAT);
	PlayerCount     = CountAlivePlayers();
	RocketsFired    = 0;
	CurrentRedSpawn = 0;
	CurrentBluSpawn = 0;
	NextSpawnTime   = GetGameTime();
	RoundStarted    = true;
	RoundCount++;
}

/** Called when round ends. Stops timer, music, and destroys all rockets. */
public void OnRoundEnd(Event event, char[] eventName, bool dontBroadcast)
{
	if (LogicTimer != null)
	{
		KillTimer(LogicTimer);
		LogicTimer = null;
	}

	if (MusicEnabled)
	{
		if (UseWebPlayer)
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (!IsValidClientEx(client)) continue;
				ShowHiddenMOTDPanel(client, "MusicPlayerStop", "http://0.0.0.0/");
			}
		}
		else if (Music[Music_Gameplay])
		{
			StopSoundToAll(SNDCHAN_MUSIC, MusicPath[Music_Gameplay]);
		}
	}

	DestroyRockets();
	RoundStarted = false;
}

/** Called when player spawns. Forces Pyro class. */
public void OnPlayerSpawn(Event event, char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client)) return;

	// Refresh cached alive counters. Recount instead of incrementing because
	// the TF2_RespawnPlayer call below re-fires player_spawn, and a naive
	// increment would double-count on every class-force respawn. Recount is
	// O(MaxClients) but only runs on this rare event, not in a hot path.
	RecountAlive();

	TFClassType playerClass = TF2_GetPlayerClass(client);
	if ((playerClass == TFClass_Pyro || playerClass == TFClass_Unknown)) return;

	TF2_SetPlayerClass(client, TFClass_Pyro, false, true);
	TF2_RespawnPlayer(client);
}

/** Called when player dies. Updates game state and executes kill commands. */
public void OnPlayerDeath(Event event, char[] eventName, bool dontBroadcast)
{
	if (!RoundStarted) return;

	SetRandomSeed(view_as<int>(GetGameTime()));

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(victim)) return;

	// Force FL_NOTARGET on death — prevents spectator ghost airblast bug
	if (UsePushPrevention)
	{
		SetEntityFlags(victim, GetEntityFlags(victim) | FL_NOTARGET);
	}

	StealInfo[victim].stoleRocket = false;
	StealInfo[victim].rocketsStolen = 0;

	LastDeadClient = victim;
	LastDeadTeam = GetClientTeam(victim);

	// Decrement the dying player's team-bucket directly. We hook player_death
	// as EventHookMode_Pre, so IsPlayerAlive(victim) may still report true
	// here — a RecountAlive() at this moment can miss the death. The clamp
	// to 0 guards against the rare case where the victim has already been
	// counted out by another path (e.g. player_team firing first).
	if (LastDeadTeam == 2 || LastDeadTeam == 3)
	{
		if (g_AliveCount[LastDeadTeam] > 0) g_AliveCount[LastDeadTeam]--;
	}
	PlayerCount = CountAlivePlayers();
	
	int inflictor = event.GetInt("inflictor_entindex");
	int index = FindRocketByEntity(inflictor);

	if (index == -1) return;

	int rocketClass = RocketClass[index];
	int target = EntRefToEntIndex(RocketTarget[index]);
	float speed = RocketSpeed[index];
	float mphSpeed = RocketMphSpeed[index];
	int deflections = RocketDeflections[index];

	if ((RocketInstanceFlags[index] & RocketFlag_OnExplodeCmd) && !(RocketInstanceFlags[index] & RocketFlag_Exploded))
	{
		ExecuteCommands(RocketClassCmdsOnExplode[rocketClass], rocketClass, inflictor, attacker, target, LastDeadClient, speed, deflections, mphSpeed);
		RocketInstanceFlags[index] |= RocketFlag_Exploded;
	}

	// "on kill" fires only on deflected kills; "on spawn kill" fires only on undeflected (spawn) kills.
	if (deflections > 0)
	{
		if (TestFlags(RocketInstanceFlags[index], RocketFlag_OnKillCmd))
			ExecuteCommands(RocketClassCmdsOnKill[rocketClass], rocketClass, inflictor, attacker, target, LastDeadClient, speed, deflections, mphSpeed);
	}
	else
	{
		if (TestFlags(RocketInstanceFlags[index], RocketFlag_OnSpawnKillCmd))
			ExecuteCommands(RocketClassCmdsOnSpawnKill[rocketClass], rocketClass, inflictor, attacker, target, LastDeadClient, speed, deflections, mphSpeed);
	}
}

/**
 * Called on player_team. Refreshes cached alive counters because team
 * changes invalidate the per-team alive bookkeeping. We recount rather than
 * try to apply oldteam/newteam deltas — the event also fires on disconnect
 * (with disconnect=true) and on initial join (oldteam=0/Unassigned), and
 * IsPlayerAlive() semantics during the event vary; a full recount is
 * unconditionally correct.
 */
public void OnPlayerTeam(Event event, char[] eventName, bool dontBroadcast)
{
	RecountAlive();
}

/** Called when player receives inventory. Removes non-flamethrower weapons and applies built-in features. */
public void OnPlayerInventory(Event event, char[] eventName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client)) return;
	for (int slot = 1; slot < 5; slot++)
	{
		int weapon = GetPlayerWeaponSlot(client, slot);
		if (weapon != -1) RemoveEntity(weapon);
	}

	// Push prevention: set FL_NOTARGET to prevent airblast push
	if (UsePushPrevention && PushPreventionEnabled[client])
	{
		SetEntityFlags(client, GetEntityFlags(client) | FL_NOTARGET);
	}

	// NoBlock: remove player-to-player collision
	if (UseNoBlock && GetClientTeam(client) > 1)
	{
		SetEntProp(client, Prop_Data, "m_CollisionGroup", 17); // COLLISION_GROUP_PUSHAWAY
	}
}

/** Blocks primary attack when dodgeball is enabled. */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float velocity[3], float angles[3], int &weapon)
{
	if (Enabled) buttons &= ~IN_ATTACK;
	return Plugin_Continue;
}

/** Handles custom music for round start, win, and lose events. */
public Action OnBroadcastAudio(Event event, char[] eventName, bool dontBroadcast)
{
	if (!MusicEnabled) return Plugin_Continue;

	char sound[PLATFORM_MAX_PATH];
	event.GetString("sound", sound, sizeof(sound));
	int team = event.GetInt("team");

	if (StrEqual(sound, "Announcer.AM_RoundStartRandom"))
	{
		if (!UseWebPlayer)
		{
			if (!Music[Music_Gameplay]) return Plugin_Continue;
			EmitSoundToAll(MusicPath[Music_Gameplay], SOUND_FROM_PLAYER, SNDCHAN_MUSIC);
			return Plugin_Handled;
		}
		else
		{
			for (int client = 1; client <= MaxClients; client++)
			{
				if (!IsValidClientEx(client)) continue;
				ShowHiddenMOTDPanel(client, "MusicPlayerStart", WebPlayerUrl);
			}
			return Plugin_Handled;
		}
	}
	else if (StrEqual(sound, "Game.YourTeamWon"))
	{
		if (!Music[Music_RoundWin]) return Plugin_Continue;

		for (int client = 1; client <= MaxClients; client++)
		{
			if (!(IsValidClientEx(client) && (team == GetClientTeam(client)))) continue;
			EmitSoundToClient(client, MusicPath[Music_RoundWin]);
		}
		return Plugin_Handled;
	}
	else if (StrEqual(sound, "Game.YourTeamLost"))
	{
		if (!Music[Music_RoundLose]) return Plugin_Continue;
		for (int client = 1; client <= MaxClients; client++)
		{
			if (!(IsValidClientEx(client) && (team == GetClientTeam(client)))) continue;
			EmitSoundToClient(client, MusicPath[Music_RoundLose]);
		}
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/** Called when a projectile is deflected. Updates deflection count and drag state. */
public void OnObjectDeflected(Event event, char[] eventName, bool dontBroadcast)
{
	int entity = event.GetInt("object_entindex");
	int index  = FindRocketByEntity(entity);
	if (index == -1) return;

	RocketEventDeflections[index]++;

	int launcher = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
	if (launcher != -1)
	{
		SetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher", launcher);
	}

	if (RocketInstanceState[index] & RocketState_Delayed)
	{
		Internal_SetRocketState(index, (RocketInstanceState[index] & ~RocketState_Delayed));
		RocketSpeed[index] = CalculateRocketSpeed(RocketClass[index], CalculateModifier(RocketClass[index], RocketDeflections[index]));
	}

	if (RocketInstanceFlags[index] & RocketFlag_ResetBounces)
	{
		RocketBounces[index] = 0;
	}

	if (RocketInstanceFlags[index] & RocketFlag_IsNeutral)
	{
		SetEntProp(entity, Prop_Send, "m_iTeamNum", 1, 1);
	}

	// Freeze m_iDeflected at 0: the client's C_TFBaseRocket::OnDataChanged()
	// compares m_iCachedDeflect against GetDeflected(). If the networked value
	// never changes from 0, CreateTrails() never re-fires after spawn.
	// This is the primary mechanism that prevents particle stacking.
	// (Verified from Valve's SDK 2013 source: tf_weaponbase_rocket.cpp)
	SetEntProp(entity, Prop_Send, "m_iDeflected", 0);

	// m_bCritical stays 0 at all times (never set server-only either).
	// Crit damage is handled by multiplying the damage value directly.
	// The engine's Deflected() may call SetCritical(true) if the deflector
	// has crit boost — re-zero it unconditionally.
	SetEntProp(entity, Prop_Send, "m_bCritical", 0, 1);

	// Since CreateTrails no longer re-fires, the client won't swap the crit glow.
	// Swap it server-side using the rocket's new team (already set by Deflected()).
	// Only for crit rockets — non-crit rockets have no glow to swap.
	if (RocketIsCritical[index])
	{
		int newTeam = GetEntProp(entity, Prop_Send, "m_iTeamNum");
		UpdateCritGlow(index, entity, newTeam);
	}

	// --- Record event tick for deferred eye-angle read in HomingRocketThink ---
	// The event handler does NOT read eye angles. It records the moment and the deflector.
	// HomingRocketThink reads eye angles after the per-class "steering control" ticks
	// have elapsed. That gap is the drag window — mouse movement during it is captured
	// when the read finally fires.
	RocketDragEventTick[index] = GetGameTickCount();
}

/**
 * Per-rocket think dispatch. Called from OnGameFrame() per valid rocket.
 *
 * Warning: this MUST stay driven from OnGameFrame, not from SDKHook_Think.
 * SDKHook_Think fires at the entity's native think rate. For
 * `tf_projectile_rocket` that's only the rocket's own lifetime/fuel schedule
 * (~10 Hz at best), NOT per-tick like it is for players. Driving homing from
 * SDKHook_Think produces ~10 Hz homing, visible sine-wave motion from the
 * engine-gravity vs our-correction mismatch, and rockets that "fly to space"
 * against moving targets. OnGameFrame iteration is the supported path.
 *
 * Dispatches:
 *   - HomingRocketThink (per-tick, internal "think interval" gating)
 *   - RocketLegacyThink (10 Hz gated internally)
 *   - SharedRocketThink (10 Hz gated internally)
 */
void OnRocketThink(int index)
{
	float now = GetGameTime();

	// Per-tick behaviour dispatch
	if (RocketClassBehaviour[RocketClass[index]] == Behaviour_Homing)
	{
		HomingRocketThink(index);
	}

	// 10 Hz logic (legacy-behaviour think + shared think: sounds, delays, non-smooth elevation).
	// Gated internally to preserve the original timing of these systems.
	// FPS_LOGIC_INTERVAL = 0.1 in tfdb.inc.
	if ((now - RocketLastLogicThink[index]) >= FPS_LOGIC_INTERVAL)
	{
		RocketLastLogicThink[index] = now;

		if (RocketClassBehaviour[RocketClass[index]] == Behaviour_LegacyHoming)
		{
			RocketLegacyThink(index);
		}
		SharedRocketThink(index);
	}
}

/**
 * Per-tick iterator. Drives per-rocket OnRocketThink dispatch.
 * Fires every server tick (66-128 Hz). This is the reliable tick source for
 * projectile-entity logic — SDKHook_Think is NOT (see OnRocketThink docblock).
 */
public void OnGameFrame()
{
	if (!Enabled || !RoundStarted) return;

	int index = -1;
	while ((index = FindNextValidRocket(index)) != -1)
	{
		OnRocketThink(index);
	}
}

/**
 * Cleans up client state when they disconnect.
 *
 * @param client   Client index that disconnected.
 */
public void OnClientDisconnect(int client)
{
	StealInfo[client].stoleRocket = false;
	StealInfo[client].rocketsStolen = 0;
	PushPreventionEnabled[client] = false;
	LockedTarget[client] = -1;

	if (client == LastDeadClient)
	{
		LastDeadClient = 0;
	}

	if (client == LastStealer)
	{
		LastStealer = 0;
	}

	// Refresh cached alive counters. The disconnecting client may still be
	// reported as in-game/alive at this moment by some calls, so a recount
	// here may double up with player_team(disconnect=true) which fires just
	// before — that's fine, RecountAlive is idempotent.
	RecountAlive();
}

public void OnClientConnected(int client)
{
	PushPreventionEnabled[client] = true; // Default: push prevention on
	LockedTarget[client] = -1;
}

public void OnClientPutInServer(int client)
{
	if (!Enabled) return;

	// Hook WeaponCanUse for the FL_NOTARGET sound fix workaround.
	// FL_NOTARGET suppresses sentry targeting sounds as a side effect;
	// temporarily removing it during weapon pickup avoids the issue.
	if (UsePushPrevention)
	{
		SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	}
}

/**
 * SDKHook callback for rocket collision detection.
 * Handles initial checks before bouncing and player collision.
 *
 * @param entity   The rocket entity.
 * @param other    The entity being touched.
 * @return         Plugin_Handled to block touch, Plugin_Continue otherwise.
 */
public Action OnStartTouch(int entity, int other)
{
	int index = FindRocketByEntity(entity);

	if (index == -1) return Plugin_Continue;
	if (other > 0 && other <= MaxClients)
	{
		if (RocketDeflections[index] == 0)
		{
			SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", 0);
			SetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher", -1);
			SetEntPropEnt(entity, Prop_Send, "m_hLauncher", -1);
		}
		return Plugin_Continue;
	}

	int rocketClass = RocketClass[index];
	if (RocketBounces[index] >= RocketClassMaxBounces[rocketClass])
	{
		if (RocketDeflections[index] == 0)
		{
			SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", 0);
			SetEntPropEnt(entity, Prop_Send, "m_hOriginalLauncher", -1);
			SetEntPropEnt(entity, Prop_Send, "m_hLauncher", -1);
		}
		return Plugin_Continue;
	}

	SDKHook(entity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public Action OnTouch(int entity, int other)
{
	int index = FindRocketByEntity(entity);

	if (index == -1)
	{
		SDKUnhook(entity, SDKHook_Touch, OnTouch);
		return Plugin_Continue;
	}

	float origin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", origin);

	float angles[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", angles);

	float velocity[3];
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", velocity);

	Handle trace = TR_TraceRayFilterEx(origin, angles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);

	if (!TR_DidHit(trace))
	{
		delete trace;
		return Plugin_Continue;
	}

	float normal[3];
	TR_GetPlaneNormal(trace, normal);
	delete trace;

	float dotProduct = GetVectorDotProduct(normal, velocity);
	ScaleVector(normal, dotProduct);
	ScaleVector(normal, 2.0);

	// Pure reflection — v' = v - 2(v·n)n. Magnitude preserved, no artificial
	// dampening. Matches Oracle DB_Reborn's canonical implementation and the
	// feel the TFDB community expects.
	float bounceVec[3];
	SubtractVectors(velocity, normal, bounceVec);

	// Bounce ceiling — per-class cap on peak bounce arc height (HU above bounce
	// point). Optional, 0 = disabled. Derivation: under gravity g=800, peak
	// height h = v_z² / (2g), so max allowed v_z = sqrt(2g · h).
	// Energy redistribution: if v_z is clamped, boost horizontal components
	// (X,Y) to preserve total |v|. Rocket keeps speed, excess upward energy
	// becomes forward energy. Only clamps upward bounces (v_z > 0) so ceiling
	// hits (rocket bouncing DOWN) are unaffected.
	int rocketClass = RocketClass[index];
	float ceiling = RocketClassBounceCeiling[rocketClass];
	if (ceiling > 0.0 && bounceVec[2] > 0.0)
	{
		float maxVz = SquareRoot(2.0 * 800.0 * ceiling);  // g = 800 HU/s² (Source default)
		if (bounceVec[2] > maxVz)
		{
			float origMagSq = bounceVec[0]*bounceVec[0] + bounceVec[1]*bounceVec[1] + bounceVec[2]*bounceVec[2];
			float newVzSq   = maxVz * maxVz;
			float origXYSq  = bounceVec[0]*bounceVec[0] + bounceVec[1]*bounceVec[1];

			bounceVec[2] = maxVz;

			// Boost horizontal components to preserve total magnitude.
			// Skip redistribution on pure-vertical bounces (XY ≈ 0) — would divide by
			// zero. Rocket just loses speed in that degenerate case (very rare in play).
			if (origXYSq > 1.0)
			{
				float targetXYSq = origMagSq - newVzSq;
				if (targetXYSq > 0.0)
				{
					float xyScale = SquareRoot(targetXYSq / origXYSq);
					bounceVec[0] *= xyScale;
					bounceVec[1] *= xyScale;
				}
			}
		}
	}

	float newAngles[3];
	GetVectorAngles(bounceVec, newAngles);

	float newAnglesRef[3]; CopyVectors(newAngles, newAnglesRef);
	float bounceVecRef[3];
	CopyVectors(bounceVec, bounceVecRef);

	Action bounceResult = Forward_OnRocketBouncePre(index, entity, newAnglesRef, bounceVecRef);
	if (bounceResult == Plugin_Stop || bounceResult == Plugin_Handled)
	{
		SDKUnhook(entity, SDKHook_Touch, OnTouch);
		return Plugin_Continue;
	}
	else if (bounceResult == Plugin_Changed)
	{
		CopyVectors(newAnglesRef, newAngles);
		CopyVectors(bounceVecRef, bounceVec);
	}

	// Pause homing — rocket flies freely with bounce velocity until
	// HomingRocketThink re-enables it after per-class "bounce control" ticks.
	RocketHomingPaused[index]    = true;
	RocketBounceEventTick[index] = GetGameTickCount();

	TeleportEntity(entity, NULL_VECTOR, newAngles, bounceVec);
	RocketBounces[index]++;

	if ((RocketInstanceState[index] & RocketState_Delayed) || (RocketInstanceFlags[index] & RocketFlag_KeepDirection))
	{
		Internal_SetRocketState(index, (RocketInstanceState[index] | RocketState_Bouncing));
	}
	else
	{
		float direction[3];
		GetAngleVectors(newAngles, direction, NULL_VECTOR, NULL_VECTOR);
		CopyVectors(direction, RocketDirection[index]);
	}

	Forward_OnRocketBounce(index, entity);
	SDKUnhook(entity, SDKHook_Touch, OnTouch);

	return Plugin_Handled;
}

public Action OnTFExplosion(const char[] teName, const int[] clients, int numClients, float delay)
{
	static int ignoreHook;
	if (!Enabled)
	{
		return Plugin_Continue;
	}

	if (ignoreHook)
	{
		ignoreHook = false;
		return Plugin_Continue;
	}

	TE_Start("TFExplosion");

	float vecNormal[3]; TE_ReadVector("m_vecNormal", vecNormal);
	TE_WriteFloat("m_vecOrigin[0]", TE_ReadFloat("m_vecOrigin[0]"));
	TE_WriteFloat("m_vecOrigin[1]", TE_ReadFloat("m_vecOrigin[1]"));
	TE_WriteFloat("m_vecOrigin[2]", TE_ReadFloat("m_vecOrigin[2]"));
	TE_WriteVector("m_vecNormal", vecNormal);
	TE_WriteNum("m_iWeaponID", TE_ReadNum("m_iWeaponID"));
	TE_WriteNum("entindex",    TE_ReadNum("entindex"));
	TE_WriteNum("m_nDefID",    -1);
	TE_WriteNum("m_nSound",    TE_ReadNum("m_nSound"));
	TE_WriteNum("m_iCustomParticleIndex", TE_ReadNum("m_iCustomParticleIndex"));

	ignoreHook = true;
	TE_Send(clients, numClients, delay);
	return Plugin_Stop;

}

// ============================================================================
// Push Prevention (!ab command and WeaponCanUse workaround)
// ============================================================================

/**
 * Console command: toggles airblast push prevention for the calling player.
 */
public Action CmdTogglePushPrevention(int client, int args)
{
	if (client == 0 || !TFDB_IsRealHuman(client))
	{
		ReplyToCommand(client, "Command is in-game only.");
		return Plugin_Handled;
	}

	if (!Enabled)
	{
		CReplyToCommand(client, "%t", "Command_Disabled");
		return Plugin_Handled;
	}

	if (!UsePushPrevention)
	{
		CReplyToCommand(client, "[TFDB] Push prevention is disabled in general.cfg.");
		return Plugin_Handled;
	}

	if (!UsePushPreventionToggle)
	{
		CReplyToCommand(client, "[TFDB] Push prevention toggle is disabled in general.cfg.");
		return Plugin_Handled;
	}

	PushPreventionEnabled[client] = !PushPreventionEnabled[client];

	if (IsPlayerAlive(client))
	{
		int flags = GetEntityFlags(client);
		SetEntityFlags(client, PushPreventionEnabled[client] ? (flags | FL_NOTARGET) : (flags & ~FL_NOTARGET));
	}

	CReplyToCommand(client, "%t", PushPreventionEnabled[client]
		? "Dodgeball_AirblastPreventionCmd_Enabled"
		: "Dodgeball_AirblastPreventionCmd_Disabled");

	return Plugin_Handled;
}

/**
 * SDKHook callback: temporarily removes FL_NOTARGET during weapon equip
 * to avoid a sound bug where FL_NOTARGET suppresses weapon pickup sounds.
 * Re-applies FL_NOTARGET on the next frame.
 */
public Action OnWeaponCanUse(int client, int weapon)
{
	if (!UsePushPrevention) return Plugin_Continue;

	int flags = GetEntityFlags(client);
	if (!(flags & FL_NOTARGET)) return Plugin_Continue;

	SetEntityFlags(client, flags & ~FL_NOTARGET);
	RequestFrame(Frame_RestorePushPrevention, GetClientUserId(client));

	return Plugin_Continue;
}

void Frame_RestorePushPrevention(int userId)
{
	int client = GetClientOfUserId(userId);
	if (client == 0 || !IsClientInGame(client) || !PushPreventionEnabled[client]) return;

	SetEntityFlags(client, GetEntityFlags(client) | FL_NOTARGET);
}
