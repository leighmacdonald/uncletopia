#if defined _dodgeball_rockets_included
  #endinput
#endif
#define _dodgeball_rockets_included

/**
 * All logic directly related to creating, managing, and controlling rockets.
 */

/**
 * Creates and spawns a new rocket from a spawner.
 *
 * @param iSpawnerEntity    The spawner entity to spawn from.
 * @param iSpawnerClass     The spawner class index (determines spawn chances).
 * @param iTeam             The team the rocket belongs to (TFTeam_Red or TFTeam_Blue).
 * @param iClass            Optional rocket class (-1 for random from spawner chances).
 */
void CreateRocket(int iSpawnerEntity, int iSpawnerClass, int iTeam, int iClass = -1)
{
	int iIndex = FindFreeRocketSlot();
	if (iIndex == -1) return;

	iClass = iClass == -1 ? GetRandomRocketClass(iSpawnerClass) : iClass;
	RocketFlags iFlags = RocketClassFlags[iClass];

	int iClassRef = iClass;
	RocketFlags iFlagsRef = iFlags;
	Action aResult = Forward_OnRocketCreatedPre(iIndex, iClassRef, iFlagsRef);

	if (aResult == Plugin_Stop || aResult == Plugin_Handled)
	{
		return;
	}
	else if (aResult == Plugin_Changed)
	{
		iClass = iClassRef;
		iFlags = iFlagsRef;
	}

	int iEntity = CreateEntityByName(TestFlags(iFlags, RocketFlag_IsAnimated) ? "tf_projectile_sentryrocket" : "tf_projectile_rocket");
	if (iEntity == -1) return;

	float fPosition[3], fAngles[3], fDirection[3];
	GetEntPropVector(iSpawnerEntity, Prop_Send, "m_vecOrigin", fPosition);
	GetEntPropVector(iSpawnerEntity, Prop_Send, "m_angRotation", fAngles);
	GetAngleVectors(fAngles, fDirection, NULL_VECTOR, NULL_VECTOR);

	SetEntProp(iEntity,    Prop_Send, "m_bCritical",    (GetURandomFloatRange(0.0, 100.0) <= RocketClassCritChance[iClass]) ? 1 : 0, 1);
	SetEntProp(iEntity,    Prop_Send, "m_iTeamNum",     (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 1 : iTeam, 1);
	SetEntProp(iEntity,    Prop_Send, "m_iDeflected",   0);
	TeleportEntity(iEntity, fPosition, fAngles, view_as<float>({0.0, 0.0, 0.0}));

	int iTargetTeam = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
	int iTarget     = SelectTarget(iTargetTeam);
	int iRocketOwner = SelectTarget(GetAnalogueTeam(GetClientTeam(iTarget)));
	
	SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", iRocketOwner);
	int iWeapon = GetPlayerWeaponSlot(iRocketOwner, TFWeaponSlot_Primary);
	SetEntPropEnt(iEntity, Prop_Send, "m_hOriginalLauncher", iWeapon == -1 ? iEntity : iWeapon);
	SetEntPropEnt(iEntity, Prop_Send, "m_hLauncher", iWeapon == -1 ? iEntity : iWeapon);

	float fModifier = CalculateModifier(iClass, 0);
	RocketIsValid[iIndex]            = true;
	RocketInstanceFlags[iIndex]              = iFlags;
	RocketEntity[iIndex]             = EntIndexToEntRef(iEntity);
	RocketTarget[iIndex]             = EntIndexToEntRef(iTarget);
	RocketClass[iIndex]              = iClass;
	RocketDeflections[iIndex]        = 0;
	RocketEventDeflections[iIndex]   = 0;
	RocketBounces[iIndex]            = 0;
	RocketHomingPaused[iIndex]       = false;
	RocketIsDragPause[iIndex]        = false;
	RocketDragPauseEnd[iIndex]       = 0.0;
	RocketLastDeflectionTime[iIndex] = GetGameTime();
	RocketLastBeepTime[iIndex]       = GetGameTime();
	RocketSpeed[iIndex]              = CalculateRocketSpeed(iClass, fModifier);
	RocketMphSpeed[iIndex]           = RocketSpeed[iIndex] * HAMMER_TO_MPH;
	Internal_SetRocketState(iIndex, RocketState_None);

	CopyVectors(fDirection, RocketDirection[iIndex]);
	SetEntDataFloat(iEntity, DamageOffset, CalculateRocketDamage(iClass, fModifier), true);
	DispatchSpawn(iEntity);

	if (TestFlags(iFlags, RocketFlag_CustomModel))
	{
		SetEntityModel(iEntity, RocketClassModel[iClass]);
		UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));
	}

	if (TestFlags(iFlags, RocketFlag_OnSpawnCmd))
	{
		ExecuteCommands(RocketClassCmdsOnSpawn[iClass], iClass, iEntity, 0, iTarget, LastDeadClient, RocketSpeed[iIndex], 0, RocketMphSpeed[iIndex]);
	}

	EmitRocketSound(RocketSound_Spawn, iClass, iEntity, iTarget, iFlags);
	EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);

	RocketCount++;
	RocketsFired++;
	LastSpawnTime[iIndex] = GetGameTime();
	NextSpawnTime = GetGameTime() + SpawnersInterval[iSpawnerClass];

	SDKHook(iEntity, SDKHook_StartTouch, OnStartTouch);
	Forward_OnRocketCreated(iIndex, iEntity);
}

/**
 * Destroys a rocket by its internal index.
 *
 * @param iIndex    The rocket's internal index.
 */
void DestroyRocket(int iIndex)
{
	if (!IsValidRocket(iIndex)) return;

	int iEntity = EntRefToEntIndex(RocketEntity[iIndex]);
	if (iEntity != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(iEntity);
	}
	RocketIsValid[iIndex] = false;
	RocketCount--;
}

/**
 * Destroys all active rockets.
 */
void DestroyRockets()
{
	for (int iIndex = 0; iIndex < MAX_ROCKETS; iIndex++)
	{
		DestroyRocket(iIndex);
	}
	RocketCount = 0;
}

/**
 * Checks if a rocket index is valid and the rocket exists.
 *
 * @param iIndex    The rocket's internal index.
 * @return          True if valid, false otherwise.
 */
bool IsValidRocket(int iIndex)
{
	if (!((iIndex >= 0) && RocketIsValid[iIndex])) return false;
	
	if (EntRefToEntIndex(RocketEntity[iIndex]) != -1) return true;

	RocketIsValid[iIndex] = false;
	RocketCount--;

	return false;
}

/**
 * Finds the next valid rocket after the given index.
 *
 * @param iIndex    Starting index to search from.
 * @return          Next valid rocket index, or -1 if none found.
 */
int FindNextValidRocket(int iIndex)
{
	for (int iCurrent = iIndex + 1; iCurrent < MAX_ROCKETS; iCurrent++)
	{
		if (IsValidRocket(iCurrent)) return iCurrent;
	}
	return -1;
}

/**
 * Finds a free slot in the rocket array.
 *
 * @return          Free rocket index, or -1 if array is full.
 */
int FindFreeRocketSlot()
{
	for (int iCurrent = 0; iCurrent < MAX_ROCKETS; iCurrent++)
	{
		if (!IsValidRocket(iCurrent)) return iCurrent;
	}

	return -1;
}

/**
 * Finds a rocket's internal index by its entity index.
 *
 * @param iEntity   The rocket's entity index.
 * @return          Internal rocket index, or -1 if not found.
 */
int FindRocketByEntity(int iEntity)
{
	int iIndex = -1;
	while ((iIndex = FindNextValidRocket(iIndex)) != -1)
	{
		if (EntRefToEntIndex(RocketEntity[iIndex]) == iEntity) return iIndex;
	}
	return -1;
}

/**
 * Processes a rocket deflection: reads the deflector's aim, selects a new target,
 * recalculates speed/damage, checks for steals, and fires forwards/commands.
 * Shared by HomingRocketThink, SharedRocketThink, and RocketLegacyThink.
 *
 * @param iIndex            Rocket internal index.
 * @param iEntity           Rocket entity index.
 * @param iClass            Rocket class index.
 * @param iFlags            Rocket instance flags.
 * @param iTeam             Rocket's current team.
 * @param iTargetTeam       Team to select new target from.
 * @param iDeflectionCount  Current event deflection count.
 * @param fModifier         Speed/damage modifier for current deflection count.
 * @param bClearDragging    True to clear RocketState_Dragging (homing/shared).
 *                          False for legacy (never enters drag state).
 * @return                  False if Forward_OnRocketDeflectPre blocked the deflection.
 */
bool ProcessDeflection(int iIndex, int iEntity, int iClass, RocketFlags iFlags,
                       int iTeam, int iTargetTeam, int iDeflectionCount, float fModifier,
                       bool bClearDragging)
{
	int iClient = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");

	if (bClearDragging)
		Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] & ~(RocketState_Dragging | RocketState_Stolen)));
	else
		Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] & ~RocketState_Stolen));

	if (iClient >= 1)
	{
		float fViewAngles[3], fDirection[3];
		GetClientEyeAngles(iClient, fViewAngles);
		GetAngleVectors(fViewAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
		CopyVectors(fDirection, RocketDirection[iIndex]);
		UpdateRocketSkin(iEntity, iTeam, TestFlags(iFlags, RocketFlag_IsNeutral));

		if (!(iFlags & RocketFlag_CanBeStolen))
		{
			CheckStolenRocket(iClient, iIndex);
		}
	}

	int iTarget = SelectTarget(iTargetTeam, iIndex);
	RocketTarget[iIndex]             = EntIndexToEntRef(iTarget);
	RocketDeflections[iIndex]        = iDeflectionCount;
	RocketLastDeflectionTime[iIndex] = GetGameTime();
	RocketSpeed[iIndex]              = CalculateRocketSpeed(iClass, fModifier);
	SetEntDataFloat(iEntity, DamageOffset, CalculateRocketDamage(iClass, fModifier), true);

	if (TestFlags(iFlags, RocketFlag_ElevateOnDeflect)) RocketInstanceFlags[iIndex] |= RocketFlag_Elevating;

	if ((iFlags & RocketFlag_IsSpeedLimited) && (RocketSpeed[iIndex] >= RocketClassSpeedLimit[iClass]))
	{
		RocketSpeed[iIndex] = RocketClassSpeedLimit[iClass];
	}

	RocketMphSpeed[iIndex] = RocketSpeed[iIndex] * HAMMER_TO_MPH;

	if (CvarStealPreventionDamage.BoolValue && (RocketInstanceState[iIndex] & RocketState_Stolen))
	{
		SetEntDataFloat(iEntity, DamageOffset, 0.0, true);
	}

	if (iFlags & RocketFlag_TeamlessHits)
	{
		SetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1, 1);
	}

	int iTargetRef = iTarget;
	Action aResult = Forward_OnRocketDeflectPre(iIndex, iEntity, iClient, iTargetRef);

	if (aResult == Plugin_Stop || aResult == Plugin_Handled)
	{
		return false;
	}
	else if (aResult == Plugin_Changed)
	{
		iTarget = iTargetRef;
		RocketTarget[iIndex] = EntIndexToEntRef(iTarget);
	}

	EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);
	if (TestFlags(iFlags, RocketFlag_OnDeflectCmd))
	{
		ExecuteCommands(RocketClassCmdsOnDeflect[iClass], iClass, iEntity, iClient, iTarget, LastDeadClient, RocketSpeed[iIndex], iDeflectionCount, RocketMphSpeed[iIndex]);
	}
	Forward_OnRocketDeflect(iIndex, iEntity, iClient);

	return true;
}

/**
 * Main think function for homing rockets. Handles tracking, dragging,
 * deflection, target switching, and all per-frame rocket behaviour.
 * Called from the logic timer in dodgeball_core.inc (~10Hz due to SourceMod's 0.1s min timer).
 *
 * @param iIndex    The rocket's internal index.
 */
void HomingRocketThink(int iIndex)
{
	int iEntity          = EntRefToEntIndex(RocketEntity[iIndex]);
	int iClass           = RocketClass[iIndex];
	RocketFlags iFlags   = RocketInstanceFlags[iIndex];
	int iTarget          = EntRefToEntIndex(RocketTarget[iIndex]);
	int iTeam            = GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1);
	int iTargetTeam      = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
	int iDeflectionCount = RocketEventDeflections[iIndex];
	float fModifier      = CalculateModifier(iClass, iDeflectionCount);
	
	// --- Deflection detected: pause homing, defer aim reading to per-frame check ---
	if ((iDeflectionCount > RocketDeflections[iIndex]) && !(RocketInstanceState[iIndex] & RocketState_Dragging))
	{
		RocketHomingPaused[iIndex] = true;
		RocketIsDragPause[iIndex] = true;
		
		// Snap drag pause to tick boundary so it ends on a deterministic frame.
		// GetTickInterval() is the canonical frame duration from SM 1.12 (timers.inc).
		float tickInterval = GetTickInterval();
		int pauseTicks = RoundToNearest(RocketClassDragPauseDuration[iClass] / tickInterval);
		RocketDragPauseEnd[iIndex] = GetGameTime() + (pauseTicks * tickInterval);
		
		Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] | (RocketState_CanDrag | RocketState_Dragging)));
	}

	// --- Drag pause expired: process deflection per-frame (allows sub-100ms drag) ---
	if (RocketHomingPaused[iIndex] && RocketIsDragPause[iIndex] && GetGameTime() >= RocketDragPauseEnd[iIndex])
	{
		if (iDeflectionCount > RocketDeflections[iIndex])
		{
			if (!ProcessDeflection(iIndex, iEntity, iClass, iFlags, iTeam, iTargetTeam, iDeflectionCount, fModifier, true))
			{
				RocketHomingPaused[iIndex] = false;
				RocketIsDragPause[iIndex] = false;
				return;
			}
		}

		// Apply parameters and re-enable smooth homing
		ApplyRocketParameters(iIndex);
		RocketHomingPaused[iIndex] = false;
		RocketIsDragPause[iIndex] = false;
	}

	// --- Normal homing: lerp toward target (only when not paused) ---
	if (!RocketHomingPaused[iIndex])
	{
		if (!IsValidClient(iTarget, true))
		{
			int iOwner = iTarget;
			iTarget = SelectTarget(iTargetTeam, iIndex);

			if (!IsValidClient(iTarget, true)) return;
			RocketTarget[iIndex] = EntIndexToEntRef(iTarget);
			EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);

			if (TestFlags(iFlags, RocketFlag_OnNoTargetCmd))
			{
				ExecuteCommands(RocketClassCmdsOnNoTarget[iClass], iClass, iEntity, iOwner, iTarget, LastDeadClient, RocketSpeed[iIndex], iDeflectionCount, RocketMphSpeed[iIndex]);
			}

			if (CvarNoTargetRedirectDamage.BoolValue)
			{
				SetEntDataFloat(iEntity, DamageOffset, 0.0, true);
			}
			Forward_OnRocketNoTarget(iIndex, iTarget, iOwner);
		}
		else
		{
			if ((GetGameTime() - RocketLastDeflectionTime[iIndex]) >= RocketClassControlDelay[iClass])
			{
				// Scale turn rate from "per TICK_BASE_INTERVAL" to "per frame" using GetTickInterval().
				float fTickScale = GetTickInterval() / TICK_BASE_INTERVAL;
				float fTurnrate = CalculateRocketTurnRate(iClass, fModifier) * fTickScale;
				float fDirectionToTarget[3]; CalculateDirectionToClient(iEntity, iTarget, fDirectionToTarget);

				if (RocketInstanceFlags[iIndex] & RocketFlag_Elevating)
				{
					fDirectionToTarget[2] = RocketDirection[iIndex][2];
				}

				if ((RocketInstanceFlags[iIndex] & RocketFlag_IsTRLimited) && (fTurnrate >= RocketClassTurnRateLimit[iClass] * fTickScale))
				{
					fTurnrate = RocketClassTurnRateLimit[iClass] * fTickScale;
				}
				LerpVectors(RocketDirection[iIndex], fDirectionToTarget, RocketDirection[iIndex], fTurnrate);
			}
		}

		// --- Smooth elevation (OnGameFrame, frame-rate independent) ---
		if (UseSmoothElevation && (RocketInstanceFlags[iIndex] & RocketFlag_Elevating))
		{
			if ((GetGameTime() - RocketLastDeflectionTime[iIndex]) >= RocketClassControlDelay[iClass])
			{
				float fElevRate = RocketClassElevationRate[iClass] * (GetTickInterval() / TICK_BASE_INTERVAL);
				if (RocketDirection[iIndex][2] < RocketClassElevationLimit[iClass])
				{
					RocketDirection[iIndex][2] = FMin(RocketDirection[iIndex][2] + fElevRate, RocketClassElevationLimit[iClass]);
				}
				else
				{
					RocketInstanceFlags[iIndex] &= ~RocketFlag_Elevating;
				}
			}
		}

		if (!(RocketInstanceState[iIndex] & RocketState_Bouncing))
		{
			ApplyRocketParameters(iIndex);
		}
	}
}

/**
 * Handles logic that is shared between all rocket behaviours, like sounds and delay checks.
 * This is called from the logic timer in dodgeball_core.inc
 */
void SharedRocketThink(int iIndex)
{
	int iEntity          = EntRefToEntIndex(RocketEntity[iIndex]);
	int iClass           = RocketClass[iIndex];
	RocketFlags iFlags   = RocketInstanceFlags[iIndex];
	int iTarget          = EntRefToEntIndex(RocketTarget[iIndex]);
	int iTeam            = GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1);
	int iTargetTeam      = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
	int iDeflectionCount = RocketEventDeflections[iIndex];
	float fModifier      = CalculateModifier(iClass, iDeflectionCount);
	
	// --- Handle paused state: bounce unpauses are handled here (timer-based) ---
	// Drag unpauses are handled per-frame in HomingRocketThink for sub-100ms precision.
	if (RocketHomingPaused[iIndex] && !RocketIsDragPause[iIndex])
	{
		// Process pending deflection on the logic timer (bounce unpause)
		if (iDeflectionCount > RocketDeflections[iIndex])
		{
			if (!ProcessDeflection(iIndex, iEntity, iClass, iFlags, iTeam, iTargetTeam, iDeflectionCount, fModifier, true))
			{
				RocketHomingPaused[iIndex] = false;
				return;
			}
		}

		// Apply parameters once on unpause and re-enable smooth homing
		ApplyRocketParameters(iIndex);
		RocketHomingPaused[iIndex] = false;
	}

	// --- Elevation (runs at logic timer rate when smooth elevation is off) ---
	if (!(iDeflectionCount > RocketDeflections[iIndex]))
	{
		if (((GetGameTime() - RocketLastDeflectionTime[iIndex]) >= RocketClassControlDelay[iClass]) &&
		    (RocketInstanceFlags[iIndex] & RocketFlag_Elevating) && !UseSmoothElevation)
		{
			if (RocketDirection[iIndex][2] < RocketClassElevationLimit[iClass])
			{
				RocketDirection[iIndex][2] = FMin(RocketDirection[iIndex][2] + RocketClassElevationRate[iClass], RocketClassElevationLimit[iClass]);
			}
			else
			{
				RocketInstanceFlags[iIndex] &= ~RocketFlag_Elevating;
			}
		}

		if ((GetGameTime() - RocketLastBeepTime[iIndex]) >= RocketClassBeepInterval[iClass])
		{
			EmitRocketSound(RocketSound_Beep, iClass, iEntity, iTarget, iFlags);
			RocketLastBeepTime[iIndex] = GetGameTime();
		}

		if (CvarDelayPrevention.BoolValue)
		{
			CheckRoundDelays(iIndex);
		}
	}

	Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] & ~RocketState_Bouncing));
}

/**
 * Think function for legacy homing rockets. Uses instant direction changes
 * instead of smooth tracking. Called from the logic timer.
 *
 * @param iIndex    The rocket's internal index.
 */
void RocketLegacyThink(int iIndex)
{
	int iEntity          = EntRefToEntIndex(RocketEntity[iIndex]);
	int iClass           = RocketClass[iIndex];
	RocketFlags iFlags   = RocketInstanceFlags[iIndex];
	int iTarget          = EntRefToEntIndex(RocketTarget[iIndex]);
	int iTeam            = GetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1);
	int iTargetTeam      = (TestFlags(iFlags, RocketFlag_IsNeutral)) ? 0 : GetAnalogueTeam(iTeam);
	int iDeflectionCount = RocketEventDeflections[iIndex];
	float fModifier      = CalculateModifier(iClass, iDeflectionCount);

	if (!IsValidClient(iTarget, true))
	{
		int iOwner = iTarget;
		iTarget = SelectTarget(iTargetTeam, iIndex);

		if (!IsValidClient(iTarget, true)) return;
		
		RocketTarget[iIndex] = EntIndexToEntRef(iTarget);
		EmitRocketSound(RocketSound_Alert, iClass, iEntity, iTarget, iFlags);

		if (TestFlags(iFlags, RocketFlag_OnNoTargetCmd))
		{
			ExecuteCommands(RocketClassCmdsOnNoTarget[iClass], iClass, iEntity, iOwner, iTarget, LastDeadClient, RocketSpeed[iIndex], iDeflectionCount, RocketMphSpeed[iIndex]);
		}

		if (CvarNoTargetRedirectDamage.BoolValue)
		{
			SetEntDataFloat(iEntity, DamageOffset, 0.0, true);
		}
		Forward_OnRocketNoTarget(iIndex, iTarget, iOwner);
	}
	else if (iDeflectionCount > RocketDeflections[iIndex])
	{
		if (!ProcessDeflection(iIndex, iEntity, iClass, iFlags, iTeam, iTargetTeam, iDeflectionCount, fModifier, false))
		{
			return;
		}
	}
	else
	{
		if ((GetGameTime() - RocketLastDeflectionTime[iIndex]) >= RocketClassControlDelay[iClass])
		{
			float fTurnrate = CalculateRocketTurnRate(iClass, fModifier);
			float fDirectionToTarget[3];
			CalculateDirectionToClient(iEntity, iTarget, fDirectionToTarget);

			if (RocketInstanceFlags[iIndex] & RocketFlag_Elevating)
			{
				if (RocketDirection[iIndex][2] < RocketClassElevationLimit[iClass])
				{
					RocketDirection[iIndex][2] = FMin(RocketDirection[iIndex][2] + RocketClassElevationRate[iClass], RocketClassElevationLimit[iClass]);
					fDirectionToTarget[2] = RocketDirection[iIndex][2];
				}
				else
				{
					RocketInstanceFlags[iIndex] &= ~RocketFlag_Elevating;
				}
			}

			if ((RocketInstanceFlags[iIndex] & RocketFlag_IsTRLimited) && (fTurnrate >= RocketClassTurnRateLimit[iClass]))
			{
				fTurnrate = RocketClassTurnRateLimit[iClass];
			}
			LerpVectors(RocketDirection[iIndex], fDirectionToTarget, RocketDirection[iIndex], fTurnrate);
		}
	}
	ApplyRocketParameters(iIndex);
}

/** Calculates the modifier based on deflections, rockets fired, and player count. */
float CalculateModifier(int iClass, int iDeflections)
{
	return iDeflections +
	       (RocketsFired * RocketClassRocketsModifier[iClass]) +
	       (PlayerCount * RocketClassPlayerModifier[iClass]);
}

/** Calculates rocket damage based on class settings and modifier. */
float CalculateRocketDamage(int iClass, float fModifier)
{
	return RocketClassDamage[iClass] + RocketClassDamageIncrement[iClass] * fModifier;
}

/** Calculates rocket speed based on class settings and modifier. */
float CalculateRocketSpeed(int iClass, float fModifier)
{
	return RocketClassSpeed[iClass] + RocketClassSpeedIncrement[iClass] * fModifier;
}

/** Calculates turn rate based on class settings and modifier. */
float CalculateRocketTurnRate(int iClass, float fModifier)
{
	if (UseOrbitCoefficient && RocketClassOrbitTightness[iClass] > 0.0)
	{
		// Scale by 0.001 so config values use a friendly 0.1–1.0 range
		// (0.3 ≈ default turn rate feel, 0.1 = loose, 1.0 = tight)
		return CalculateRocketSpeed(iClass, fModifier) * RocketClassOrbitTightness[iClass] * 0.001;
	}
	return RocketClassTurnRate[iClass] + RocketClassTurnRateIncrement[iClass] * fModifier;
}

/** Calculates the normalized direction vector from rocket to client. */
void CalculateDirectionToClient(int iEntity, int iClient, float fOut[3])
{
	float fRocketPosition[3]; GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
	GetClientEyePosition(iClient, fOut);
	MakeVectorFromPoints(fRocketPosition, fOut, fOut);
	NormalizeVector(fOut, fOut);
}

/** Applies rocket direction and speed to the entity's velocity. */
void ApplyRocketParameters(int iIndex)
{
	int iEntity = EntRefToEntIndex(RocketEntity[iIndex]);
	float fAngles[3]; GetVectorAngles(RocketDirection[iIndex], fAngles);
	float fVelocity[3]; CopyVectors(RocketDirection[iIndex], fVelocity);

	ScaleVector(fVelocity, RocketSpeed[iIndex]);
	SetEntPropVector(iEntity, Prop_Data, "m_vecAbsVelocity", fVelocity);
	SetEntPropVector(iEntity, Prop_Send, "m_angRotation", fAngles);
}

/** Updates the rocket's skin based on team and neutral status. */
void UpdateRocketSkin(int iEntity, int iTeam, bool bNeutral)
{
	if (bNeutral) SetEntProp(iEntity, Prop_Send, "m_nSkin", 2);
	else          SetEntProp(iEntity, Prop_Send, "m_nSkin", (iTeam == view_as<int>(TFTeam_Blue)) ? 0 : 1);
}

/** Gets a random rocket class based on spawner spawn chances. */
int GetRandomRocketClass(int iSpawnerClass)
{
	int iRandom = GetURandomIntRange(1, 100);
	ArrayList hTable = SpawnersChancesTable[iSpawnerClass];
	int iTableSize = hTable.Length;
	int iChancesLower = 0;
	int iChancesUpper = 0;

	for (int iEntry = 0; iEntry < iTableSize; iEntry++)
	{
		iChancesLower += iChancesUpper;
		iChancesUpper  = iChancesLower + hTable.Get(iEntry);

		if ((iRandom >= iChancesLower) && (iRandom <= iChancesUpper))
		{
			return iEntry;
		}
	}
	return 0;
}

/**
 * Emits a rocket sound (spawn, beep, or alert) based on class settings.
 * Note: Beep timing is managed by SharedRocketThink - this function only plays sounds.
 */
void EmitRocketSound(RocketSound iSound, int iClass, int iEntity, int iTarget, RocketFlags iFlags)
{
	switch (iSound)
	{
		case RocketSound_Spawn:
		{
			if (TestFlags(iFlags, RocketFlag_PlaySpawnSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomSpawnSound)) EmitSoundToAll(RocketClassSpawnSound[iClass], iEntity);
				else                                                EmitSoundToAll(SOUND_DEFAULT_SPAWN, iEntity);
			}
		}
		case RocketSound_Beep:
		{
			// Beep interval timing is handled by SharedRocketThink before calling this function
			if (TestFlags(iFlags, RocketFlag_PlayBeepSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomBeepSound)) EmitSoundToAll(RocketClassBeepSound[iClass], iEntity);
				else                                               EmitSoundToAll(SOUND_DEFAULT_BEEP, iEntity);
			}
		}
		case RocketSound_Alert:
		{
			if (TestFlags(iFlags, RocketFlag_PlayAlertSound))
			{
				if (TestFlags(iFlags, RocketFlag_CustomAlertSound)) EmitSoundToClient(iTarget, RocketClassAlertSound[iClass]);
				else                                                EmitSoundToClient(iTarget, SOUND_DEFAULT_ALERT, _, _, _, _, 0.5);
			}
		}
	}
}

/**
 * Checks if a rocket deflection was a steal and applies penalties.
 * Uses guard clauses for clarity and safety.
 */
void CheckStolenRocket(int iClient, int iIndex)
{
	int iTarget = EntRefToEntIndex(RocketTarget[iIndex]);

	// Guard clauses - each condition is clear and prevents potential crashes
	if (iTarget == -1) return;                                        // Invalid target entity
	if (!IsValidClient(iTarget, true)) return;                        // Target not valid/alive
	if (iTarget == iClient) return;                                   // Can't steal from yourself  
	if (StealInfo[iClient].stoleRocket) return;                       // Already processed a steal this round
	if (RocketInstanceState[iIndex] & RocketState_Delayed) return;    // Delayed rockets exempt from steal check
	if (GetEntitiesDistance(iTarget, iClient) <= CvarStealDistance.FloatValue) return;  // Too close to target
	
	// Team check: if enabled, only count as steal if on same team as target
	if ((RocketInstanceFlags[iIndex] & RocketFlag_StealTeamCheck) && 
	    (GetClientTeam(iTarget) != GetClientTeam(iClient))) return;

	// All conditions met - this is a steal
	StealInfo[iClient].stoleRocket = true;

	if (StealInfo[iClient].rocketsStolen < CvarStealPreventionNumber.IntValue)
	{
		StealInfo[iClient].rocketsStolen++;
		SlapPlayer(iClient, 0, true);
		CPrintToChat(iClient, "%t", "DBSteal_Warning_Client", StealInfo[iClient].rocketsStolen, CvarStealPreventionNumber.IntValue);

		if (CvarStealMessage.BoolValue)
		{
			CSkipNextClient(iClient);
			CPrintToChatAll("%t", "DBSteal_Announce_All", iClient, iTarget);
		}
		StealInfo[iClient].stoleRocket = false;
	}
	else
	{
		ForcePlayerSuicide(iClient);
		CPrintToChat(iClient, "%t", "DBSteal_Slay_Client");
		if (CvarStealMessage.BoolValue)
		{
			CSkipNextClient(iClient);
			CPrintToChatAll("%t", "DBSteal_Announce_Slay_All", iClient);
		}
	}

	Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] | RocketState_Stolen));
	LastStealer = iClient;
	Forward_OnRocketSteal(iIndex, iClient, iTarget, StealInfo[iClient].rocketsStolen);
}

void CheckRoundDelays(int iIndex)
{
	int iEntity = EntRefToEntIndex(RocketEntity[iIndex]);
	int iTarget = EntRefToEntIndex(RocketTarget[iIndex]);
	float fTimeToCheck = RocketDeflections[iIndex] == 0 ? LastSpawnTime[iIndex] : RocketLastDeflectionTime[iIndex];
	
	if (iTarget == -1 || (GetGameTime() - fTimeToCheck) < CvarDelayPreventionTime.FloatValue) return;

	if (!(RocketInstanceState[iIndex] & RocketState_Delayed))
	{
		if (CvarDelayMessage.BoolValue)
		{
			CPrintToChatAll("%t", "DBDelay_Announce_All", iTarget);
		}
		EmitSoundToAll(SOUND_DEFAULT_SPEEDUP, iEntity, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
		Internal_SetRocketState(iIndex, (RocketInstanceState[iIndex] | RocketState_Delayed));
		Forward_OnRocketDelay(iIndex, iTarget);
	}
	else
	{
		RocketSpeed[iIndex] += CvarDelayPreventionSpeedup.FloatValue;
	}
}
