#if defined _dodgeball_events_included
  #endinput
#endif
#define _dodgeball_events_included

/**
 * Handles all game events hooked by the plugin.
 */

/** Called when a new round starts. Resets steal info and plays round start music. */
public void OnRoundStart(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	if (Music[Music_RoundStart])
	{
		EmitSoundToAll(MusicPath[Music_RoundStart]);
	}

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		StealInfo[iClient].stoleRocket = false;
		StealInfo[iClient].rocketsStolen = 0;
	}
}

/** Called when setup phase ends. Initializes spawn points and starts the game timer. */
public void OnSetupFinished(Event hEvent, char[] strEventName, bool bDontBroadcast)
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
public void OnRoundEnd(Event hEvent, char[] strEventName, bool bDontBroadcast)
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
			for (int iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsValidClientEx(iClient)) continue;
				ShowHiddenMOTDPanel(iClient, "MusicPlayerStop", "http://0.0.0.0/");
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

/** Called when player spawns. Forces Pyro class for dodgeball. */
public void OnPlayerSpawn(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!IsValidClient(iClient)) return;

	TFClassType iClass = TF2_GetPlayerClass(iClient);
	if ((iClass == TFClass_Pyro || iClass == TFClass_Unknown)) return;

	TF2_SetPlayerClass(iClient, TFClass_Pyro, false, true);
	TF2_RespawnPlayer(iClient);
}

/** Called when player dies. Updates game state and executes kill commands. */
public void OnPlayerDeath(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	if (!RoundStarted) return;

	SetRandomSeed(view_as<int>(GetGameTime()));

	int iAttacker = GetClientOfUserId(hEvent.GetInt("attacker"));
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!IsValidClient(iVictim)) return;

	StealInfo[iVictim].stoleRocket = false;
	StealInfo[iVictim].rocketsStolen = 0;

	LastDeadClient = iVictim;
	LastDeadTeam = GetClientTeam(iVictim);
	PlayerCount = CountAlivePlayers();
	
	int iInflictor = hEvent.GetInt("inflictor_entindex");
	int iIndex = FindRocketByEntity(iInflictor);

	if (iIndex == -1) return;

	int iClass = RocketClass[iIndex];
	int iTarget = EntRefToEntIndex(RocketTarget[iIndex]);
	float fSpeed = RocketSpeed[iIndex];
	float fMphSpeed = RocketMphSpeed[iIndex];
	int iDeflections = RocketDeflections[iIndex];

	if ((RocketInstanceFlags[iIndex] & RocketFlag_OnExplodeCmd) && !(RocketInstanceFlags[iIndex] & RocketFlag_Exploded))
	{
		ExecuteCommands(RocketClassCmdsOnExplode[iClass], iClass, iInflictor, iAttacker, iTarget, LastDeadClient, fSpeed, iDeflections, fMphSpeed);
		RocketInstanceFlags[iIndex] |= RocketFlag_Exploded;
	}

	if (TestFlags(RocketInstanceFlags[iIndex], RocketFlag_OnKillCmd))
	{
		ExecuteCommands(RocketClassCmdsOnKill[iClass], iClass, iInflictor, iAttacker, iTarget, LastDeadClient, fSpeed, iDeflections, fMphSpeed);
	}
}

/** Called when player receives inventory. Removes non-flamethrower weapons. */
public void OnPlayerInventory(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));

	if (!IsValidClient(iClient)) return;
	for (int iSlot = 1; iSlot < 5; iSlot++)
	{
		int iEntity = GetPlayerWeaponSlot(iClient, iSlot);
		if (iEntity != -1) RemoveEdict(iEntity);
	}
}

/** Blocks primary attack when dodgeball is enabled. */
public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (Enabled) iButtons &= ~IN_ATTACK;
	return Plugin_Continue;
}

/** Handles custom music for round start, win, and lose events. */
public Action OnBroadcastAudio(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	if (!MusicEnabled) return Plugin_Continue;

	char strSound[PLATFORM_MAX_PATH];
	hEvent.GetString("sound", strSound, sizeof(strSound));
	int iTeam = hEvent.GetInt("team");

	if (StrEqual(strSound, "Announcer.AM_RoundStartRandom"))
	{
		if (!UseWebPlayer)
		{
			if (!Music[Music_Gameplay]) return Plugin_Continue;
			EmitSoundToAll(MusicPath[Music_Gameplay], SOUND_FROM_PLAYER, SNDCHAN_MUSIC);
			return Plugin_Handled;
		}
		else
		{
			for (int iClient = 1; iClient <= MaxClients; iClient++)
			{
				if (!IsValidClientEx(iClient)) continue;
				ShowHiddenMOTDPanel(iClient, "MusicPlayerStart", WebPlayerUrl);
			}
			return Plugin_Handled;
		}
	}
	else if (StrEqual(strSound, "Game.YourTeamWon"))
	{
		if (!Music[Music_RoundWin]) return Plugin_Continue;

		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!(IsValidClientEx(iClient) && (iTeam == GetClientTeam(iClient)))) continue;
			EmitSoundToClient(iClient, MusicPath[Music_RoundWin]);
		}
		return Plugin_Handled;
	}
	else if (StrEqual(strSound, "Game.YourTeamLost"))
	{
		if (!Music[Music_RoundLose]) return Plugin_Continue;
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!(IsValidClientEx(iClient) && (iTeam == GetClientTeam(iClient)))) continue;
			EmitSoundToClient(iClient, MusicPath[Music_RoundLose]);
		}
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/** Called when a projectile is deflected. Updates deflection count and drag state. */
public Action OnObjectDeflected(Event hEvent, const char[] strEventName, bool bDontBroadcast)
{
	int iEntity = hEvent.GetInt("object_entindex");
	int iIndex  = FindRocketByEntity(iEntity);
	if (iIndex == -1) return Plugin_Continue;

	RocketEventDeflections[iIndex]++;

	int iLauncher = GetEntPropEnt(iEntity, Prop_Send, "m_hLauncher");
	if (iLauncher != -1)
	{
		SetEntPropEnt(iEntity, Prop_Send, "m_hOriginalLauncher", iLauncher);
	}

	if (RocketInstanceState[iIndex] & RocketState_Delayed)
	{
		Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] & ~RocketState_Delayed));
		RocketSpeed[iIndex] = CalculateRocketSpeed(RocketClass[iIndex], CalculateModifier(RocketClass[iIndex], RocketDeflections[iIndex]));
	}

	if (RocketInstanceFlags[iIndex] & RocketFlag_ResetBounces)
	{
		RocketBounces[iIndex] = 0;
	}

	if (RocketInstanceFlags[iIndex] & RocketFlag_IsNeutral)
	{
		SetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1, 1);
	}

	return Plugin_Continue;
}

/**
 * This hook runs every server frame.
 * It's responsible for the smooth "homing" behaviour.
 * "legacy homing" is handled by the 20Hz timer OnDodgeBallGameFrame.
 */
public void OnGameFrame()
{
	if (!Enabled || !RoundStarted) return;

	int iIndex = -1;
	while ((iIndex = FindNextValidRocket(iIndex)) != -1)
	{
		if (RocketClassBehaviour[RocketClass[iIndex]] == Behaviour_Homing)
		{
			HomingRocketThink(iIndex);
		}
	}
}

/**
 * Cleans up client state when they disconnect.
 *
 * @param iClient   Client index that disconnected.
 */
public void OnClientDisconnect(int iClient)
{
	StealInfo[iClient].stoleRocket = false;
	StealInfo[iClient].rocketsStolen = 0;

	if (iClient == LastDeadClient)
	{
		LastDeadClient = 0;
	}

	if (iClient == LastStealer)
	{
		LastStealer = 0;
	}
}

/**
 * SDKHook callback for rocket collision detection.
 * Handles initial checks before bouncing and player collision.
 *
 * @param iEntity   The rocket entity.
 * @param iOther    The entity being touched.
 * @return          Plugin_Handled to block touch, Plugin_Continue otherwise.
 */
public Action OnStartTouch(int iEntity, int iOther)
{
	int iIndex = FindRocketByEntity(iEntity);

	if (iIndex == -1) return Plugin_Continue;
	if (iOther > 0 && iOther <= MaxClients)
	{
		if (RocketDeflections[iIndex] == 0)
		{
			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", 0);
			SetEntPropEnt(iEntity, Prop_Send, "m_hOriginalLauncher", -1);
			SetEntPropEnt(iEntity, Prop_Send, "m_hLauncher", -1);
		}
		return Plugin_Continue;
	}

	int iClass = RocketClass[iIndex];
	if (RocketBounces[iIndex] >= RocketClassMaxBounces[iClass])
	{
		if (RocketDeflections[iIndex] == 0)
		{
			SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", 0);
			SetEntPropEnt(iEntity, Prop_Send, "m_hOriginalLauncher", -1);
			SetEntPropEnt(iEntity, Prop_Send, "m_hLauncher", -1);
		}
		return Plugin_Continue;
	}

	SDKHook(iEntity, SDKHook_Touch, OnTouch);
	return Plugin_Handled;
}

public Action OnTouch(int iEntity, int iOther)
{
	int iIndex = FindRocketByEntity(iEntity);

	if (iIndex == -1)
	{
		SDKUnhook(iEntity, SDKHook_Touch, OnTouch);
		return Plugin_Continue;
	}

	int iClass = RocketClass[iIndex];

	float vOrigin[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", vOrigin);

	float vAngles[3];
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", vAngles);
	
	float vVelocity[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", vVelocity);

	Handle hTrace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, iEntity);

	if (!TR_DidHit(hTrace))
	{
		delete hTrace;
		return Plugin_Continue;
	}

	float vNormal[3];
	TR_GetPlaneNormal(hTrace, vNormal);
	delete hTrace;
	
	float dotProduct = GetVectorDotProduct(vNormal, vVelocity);
	ScaleVector(vNormal, dotProduct);
	ScaleVector(vNormal, 2.0);

	float vBounceVec[3];
	SubtractVectors(vVelocity, vNormal, vBounceVec);
	int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
	if (!(RocketInstanceFlags[iIndex] & RocketFlag_CrawlBounce))
	{
		if (IsValidClient(iOwner, true))
		{
			float fOwnerAngles[3];
			GetClientEyeAngles(iOwner, fOwnerAngles);
	
			if (fOwnerAngles[0] >= RocketClassBounceForceAngle[iClass])
				ScaleVector(vBounceVec, RocketClassBounceScale[iClass] * RocketClassBounceForceScale[iClass]);
			else
				ScaleVector(vBounceVec, RocketClassBounceScale[iClass]);
		}
		else
		{
			ScaleVector(vBounceVec, RocketClassBounceScale[iClass]);
		}
	}
	else
	{
		float fBounceScale = RocketClassBounceScale[iClass];

		if (IsValidClient(iOwner, true))
		{
			float fOwnerAngles[3];
			GetClientEyeAngles(iOwner, fOwnerAngles);
			if (fOwnerAngles[0] >= RocketClassBounceForceAngle[iClass])
				fBounceScale *= RocketClassBounceForceScale[iClass];
		}

		// Crawl mode: preserve horizontal carry, suppress/clamp upward pop.
		vBounceVec[0] *= fBounceScale;
		vBounceVec[1] *= fBounceScale;
		vBounceVec[2] *= fBounceScale * RocketClassCrawlBounceScale[iClass];

		if (RocketClassCrawlBounceMaxUp[iClass] > 0.0 && vBounceVec[2] > RocketClassCrawlBounceMaxUp[iClass])
			vBounceVec[2] = RocketClassCrawlBounceMaxUp[iClass];
	}


	float vNewAngles[3];
	GetVectorAngles(vBounceVec, vNewAngles);

	float vNewAnglesRef[3]; CopyVectors(vNewAngles, vNewAnglesRef);
	float vBounceVecRef[3];
	CopyVectors(vBounceVec, vBounceVecRef);

	Action aResult = Forward_OnRocketBouncePre(iIndex, iEntity, vNewAnglesRef, vBounceVecRef);
	if (aResult == Plugin_Stop || aResult == Plugin_Handled)
	{
		SDKUnhook(iEntity, SDKHook_Touch, OnTouch);
		return Plugin_Continue;
	}
	else if (aResult == Plugin_Changed)
	{
		CopyVectors(vNewAnglesRef, vNewAngles);
		CopyVectors(vBounceVecRef, vBounceVec);
	}

	TeleportEntity(iEntity, NULL_VECTOR, vNewAngles, vBounceVec);
	RocketBounces[iIndex]++;
	if (RocketInstanceFlags[iIndex] & RocketFlag_NoBounceDrags)
	{
		Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] & ~RocketState_CanDrag));
	}

	if ((RocketInstanceState[iIndex] & RocketState_Delayed) || (RocketInstanceFlags[iIndex] & RocketFlag_KeepDirection))
	{
		Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] | RocketState_Bouncing));
	}
	else
	{
		float fDirection[3];
		GetAngleVectors(vNewAngles,fDirection,NULL_VECTOR,NULL_VECTOR);
		CopyVectors(fDirection, RocketDirection[iIndex]);
	}

	Forward_OnRocketBounce(iIndex, iEntity);
	SDKUnhook(iEntity, SDKHook_Touch, OnTouch);

	return Plugin_Handled;
}

public Action OnTFExplosion(const char[] strTEName, const int[] iClients, int iNumClients, float fDelay)
{
	static int bIgnoreHook;
	if (!Enabled)
	{
		return Plugin_Continue;
	}

	if (bIgnoreHook)
	{
		bIgnoreHook = false;
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

	bIgnoreHook = true;
	TE_Send(iClients, iNumClients, fDelay);
	return Plugin_Stop;

}
