#if defined _dodgeball_utilities_included
  #endinput
#endif
#define _dodgeball_utilities_included

/**
 * Contains general-purpose utility and helper functions for the
 * TF2 Dodgeball plugin.
 */
 
 // Add this new function to the file
stock void StopSoundToAll(int iChannel, const char[] strSound)
{
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClientEx(iClient))
		{
			StopSound(iClient, iChannel, strSound);
		}
	}
}

// *********************************************************************************
// VECTOR & MATH UTILITIES
// *********************************************************************************

/**
 * Copies the contents from one vector to another.
 */
stock void CopyVectors(float fFrom[3], float fTo[3])
{
	fTo[0] = fFrom[0];
	fTo[1] = fFrom[1];
	fTo[2] = fFrom[2];
}

/**
 * Calculates the linear interpolation of two vectors.
 */
stock void LerpVectors(float fA[3], float fB[3], float fC[3], float t)
{
	t = (t < 0.0) ? 0.0 : (t > 1.0) ? 1.0 : t;
	
	fC[0] = fA[0] + (fB[0] - fA[0]) * t;
	fC[1] = fA[1] + (fB[1] - fA[1]) * t;
	fC[2] = fA[2] + (fB[2] - fA[2]) * t;
}

/**
 * Gets the distance between two entities.
 */
stock float GetEntitiesDistance(int iEnt1, int iEnt2)
{
	float fOrig1[3];
	GetEntPropVector(iEnt1, Prop_Send, "m_vecOrigin", fOrig1);
	
	float fOrig2[3];
	GetEntPropVector(iEnt2, Prop_Send, "m_vecOrigin", fOrig2);
	
	return GetVectorDistance(fOrig1, fOrig2);
}

/**
 * Returns the maximum of two float values.
 */
stock float FMax(float a, float b)
{
	return (a > b) ? a : b;
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
stock int GetURandomIntRange(int iMin, int iMax)
{
	return iMin + (GetURandomInt() % (iMax - iMin + 1));
}

/**
 * Returns a random float within a given range.
 */
stock float GetURandomFloatRange(float fMin, float fMax)
{
	return fMin + (GetURandomFloat() * (fMax - fMin));
}

// *********************************************************************************
// CLIENT & GAMEPLAY UTILITIES
// *********************************************************************************

/**
 * Checks if a client index is valid, connected, and optionally alive.
 */
stock bool IsValidClient(int iClient, bool bAlive = false)
{
	return iClient >= 1 &&
	       iClient <= MaxClients &&
	       IsClientInGame(iClient) &&
	       (!bAlive || IsPlayerAlive(iClient));
}

/**
 * IsValidClient() but without the index range check.
 */
stock bool IsValidClientEx(int iClient, bool bAlive = false)
{
	return IsClientInGame(iClient) && (!bAlive || IsPlayerAlive(iClient));
}

/**
 * Checks if there are living players on both teams.
 */
stock bool BothTeamsPlaying()
{
	bool bRedFound, bBluFound;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsValidClientEx(iClient, true)) continue;
		
		int iTeam = GetClientTeam(iClient);
		
		if (iTeam == view_as<int>(TFTeam_Red)) bRedFound = true;
		if (iTeam == view_as<int>(TFTeam_Blue)) bBluFound = true;
	}
	
	return bRedFound && bBluFound;
}

/**
 * Counts the number of players currently alive.
 */
stock int CountAlivePlayers()
{
	int iCount = 0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsValidClientEx(iClient, true)) iCount++;
	}
	
	return iCount;
}

/**
 * Gets the opposing team.
 */
stock int GetAnalogueTeam(int iTeam)
{
	if (iTeam == view_as<int>(TFTeam_Red)) return view_as<int>(TFTeam_Blue);
	
	return view_as<int>(TFTeam_Red);
}

/**
 * Selects a target for a homing rocket based on team and optional directional weighting.
 * Falls back to random selection if rocket entity is invalid.
 */
stock int SelectTarget(int iTeam, int iRocket = -1)
{
	int iTarget = -1;
	float fTargetWeight = 0.0;
	float fRocketPosition[3];
	float fRocketDirection[3];
	float fWeight;
	bool bUseRocket = false;
	int iOwner = -1;
	
	if (iRocket != -1)
	{
		int iEntity = EntRefToEntIndex(RocketEntity[iRocket]);
		
		// Validate entity before any property access to prevent crashes
		if (iEntity != -1 && IsValidEntity(iEntity))
		{
			int iClass = RocketClass[iRocket];
			iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
			
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fRocketPosition);
			CopyVectors(RocketDirection[iRocket], fRocketDirection);
			fWeight = RocketClassTargetWeight[iClass];
			
			bUseRocket = true;
		}
		// If entity is invalid, bUseRocket stays false and we fall back to random selection
	}
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsValidClientEx(iClient, true)) continue;
		if (iTeam && GetClientTeam(iClient) != iTeam) continue;
		if (iClient == iOwner) continue;
		
		float fNewWeight = GetURandomFloatRange(0.0, 100.0);
		
		if (bUseRocket)
		{
			float fClientPosition[3]; GetClientEyePosition(iClient, fClientPosition);
			float fDirectionToClient[3]; MakeVectorFromPoints(fRocketPosition, fClientPosition, fDirectionToClient);
			
			fNewWeight += GetVectorDotProduct(fRocketDirection, fDirectionToClient) * fWeight;
		}
		
		if ((iTarget == -1) || fNewWeight >= fTargetWeight)
		{
			iTarget = iClient;
			fTargetWeight = fNewWeight;
		}
	}
	
	return iTarget;
}

// *********************************************************************************
// EFFECT & RESOURCE UTILITIES
// *********************************************************************************

/**
 * Shows a hidden MOTD panel, often used for streaming audio.
 */
stock void ShowHiddenMOTDPanel(int iClient, char[] strTitle, char[] strMsg, char[] strType = "2")
{
	KeyValues hPanel = new KeyValues("data");
	hPanel.SetString("title", strTitle);
	hPanel.SetString("type", strType);
	hPanel.SetString("msg", strMsg);
	ShowVGUIPanel(iClient, "info", hPanel, false);
	delete hPanel;
}

/**
 * Plays a particle system.
 */
stock void PlayParticle(float fPosition[3], float fAngles[3], char[] strParticleName, float fEffectTime = 5.0, float fLifeTime = 9.0)
{
	int iEntity = CreateEntityByName("info_particle_system");
	
	if (iEntity == -1)
	{
		LogError("PlayParticle: could not create info_particle_system");
		return;
	}
	
	TeleportEntity(iEntity, fPosition, fAngles, NULL_VECTOR);
	DispatchKeyValue(iEntity, "effect_name", strParticleName);
	ActivateEntity(iEntity);
	AcceptEntityInput(iEntity, "Start");
	CreateTimer(fEffectTime, StopParticle, EntIndexToEntRef(iEntity));
	CreateTimer(fLifeTime, KillParticle, EntIndexToEntRef(iEntity));
}

/**
 * Timer callback to stop a particle system.
 */
public Action StopParticle(Handle hTimer, any iEntityRef)
{
	if (iEntityRef == INVALID_ENT_REFERENCE) return Plugin_Continue;
	
	int iEntity = EntRefToEntIndex(iEntityRef);
	if (iEntity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(iEntity, "Stop");
	}
	
	return Plugin_Continue;
}

/**
 * Timer callback to kill a particle system entity.
 */
public Action KillParticle(Handle hTimer, any iEntityRef)
{
	if (iEntityRef == INVALID_ENT_REFERENCE) return Plugin_Continue;
	
	int iEntity = EntRefToEntIndex(iEntityRef);
	if (iEntity != INVALID_ENT_REFERENCE)
	{
		RemoveEntity(iEntity);
	}
	
	return Plugin_Continue;
}

/**
 * Precaches a particle system by creating and quickly destroying it.
 */
stock void PrecacheParticle(char[] strParticleName)
{
	PlayParticle(view_as<float>({0.0, 0.0, 0.0}), view_as<float>({0.0, 0.0, 0.0}), strParticleName, 0.1, 0.1);
}

/**
 * Precaches a sound and adds it to the download table.
 */
stock void PrecacheSoundEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false)
{
	char strFinalPath[PLATFORM_MAX_PATH];
	FormatEx(strFinalPath, sizeof(strFinalPath), "sound/%s", strFileName);
	PrecacheSound(strFileName, bPreload);
	
	if (bAddToDownloadTable) AddFileToDownloadsTable(strFinalPath);
}

/**
 * Removes illegal characters from a string.
 */
stock void CleanString(char[] strBuffer)
{
	int iLength = strlen(strBuffer);
	for (int iPos = 0; iPos < iLength; iPos++)
	{
		switch (strBuffer[iPos])
		{
			case '\r', '\n', '\t': strBuffer[iPos] = ' ';
		}
	}
	TrimString(strBuffer);
}

/**
 * Precaches a model and its dependencies and adds them to the download table.
 */
stock void PrecacheModelEx(char[] strFileName, bool bPreload = false, bool bAddToDownloadTable = false)
{
	PrecacheModel(strFileName, bPreload);
	
	if (!bAddToDownloadTable) return;
	
	char strDepFileName[PLATFORM_MAX_PATH];
	FormatEx(strDepFileName, sizeof(strDepFileName), "%s.res", strFileName);
	
	if (!FileExists(strDepFileName)) return;
	
	File hStream = OpenFile(strDepFileName, "r");
	if (hStream == null)
	{
		LogError("Error, can't read file containing model dependencies: %s", strDepFileName);
		return;
	}
	
	while(!hStream.EndOfFile())
	{
		char strBuffer[PLATFORM_MAX_PATH];
		hStream.ReadLine(strBuffer, sizeof(strBuffer));
		CleanString(strBuffer);
		
		if (!FileExists(strBuffer, true)) continue;
		
		if (StrContains(strBuffer, ".vmt", false) != -1)      PrecacheDecal(strBuffer, true);
		else if (StrContains(strBuffer, ".mdl", false) != -1) PrecacheModel(strBuffer, true);
		else if (StrContains(strBuffer, ".pcf", false) != -1) PrecacheGeneric(strBuffer, true);
		
		AddFileToDownloadsTable(strBuffer);
	}
	
	delete hStream;
}

/**
 * Custom trace ray filter to exclude a specific entity.
 */
public bool TEF_ExcludeEntity(int iEntity, int iContentsMask, any aData)
{
	return (iEntity != aData);
}