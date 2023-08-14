#include <sourcemod>
#include <sdktools>

// These correspond to tf_gamerules m_nGameType netprop
enum
{
	TF2_GameType_Unknown,
	TF2_GameType_CTF = 1,
	TF2_GameType_CP = 2,
	TF2_GameType_PL = 3,
	TF2_GameType_Arena = 4,
}

enum TF2_GameMode
{
	TF2_GameMode_Unknown,
	TF2_GameMode_CTF,
	TF2_GameMode_5CP,
	TF2_GameMode_PL,
	TF2_GameMode_Arena,
	TF2_GameMode_ADCP,
	TF2_GameMode_TC,
	TF2_GameMode_PLR,
	TF2_GameMode_KOTH,
	TF2_GameMode_SD,
	TF2_GameMode_MvM,
	TF2_GameMode_Training,
	TF2_GameMode_ItemTest,
}

stock TF2_GameMode TF2_DetectGameMode()
{

	// If we can get the map type through netprops, do so.
	if (GameRules_GetProp("m_bIsInTraining"))
	{
		return TF2_GameMode_Training;
	}

	if (GameRules_GetProp("m_bIsInItemTestingMode"))
	{
		return TF2_GameMode_ItemTest;
	}

	if (GameRules_GetProp("m_bPlayingSpecialDeliveryMode"))
	{
		return TF2_GameMode_SD;
	}

	if (GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		return TF2_GameMode_MvM;
	}

	if (GameRules_GetProp("m_bPlayingKoth"))
	{
		return TF2_GameMode_KOTH;
	}

	// Netprops didn't help, lets check the game type
	int gameType = GameRules_GetProp("m_nGameType");

	switch (gameType)
	{
		case TF2_GameType_CTF:
		{
			return TF2_GameMode_CTF;
		}

		// 5cp, a/d cp, and tc all show up as this game type
        // koth and mvm too, but we already filtered those
		case TF2_GameType_CP:
		{
			// Check for multi-stage maps first.
			int roundCount = 0;
			int roundCP = -1;
			int priority = -1;

			int restrictWinner = -1;
			int restrictCount = 0;

			while ((roundCP = FindEntityByClassname(roundCP, "team_control_point_round")) != -1)
			{
				roundCount++;

				restrictWinner = GetEntProp(roundCP, Prop_Data, "m_iInvalidCapWinner");
				if (restrictWinner > 1)
				{
					restrictCount++;
				}

				int newPriority = GetEntProp(roundCP, Prop_Data, "m_nPriority");
				if (newPriority > priority)
				{
					priority = newPriority;
				}
				else if (newPriority == priority)
				{
					// Only TC maps have multiple rounds with the same priority, and it's the highest priority
					// Sadly, this will fail to detect push/pull TC maps
					return TF2_GameMode_TC;
				}
			}

			// All rounds have a winner restriction, so it must be a A/D cp map
			if (roundCount > 1 && roundCount == restrictCount)
			{
				return TF2_GameMode_ADCP;
			}
			else if (roundCount > 1)
			{
				// We had multiple rounds, but not all of them were restricted...
				// must be a push/pull TC map
				return TF2_GameMode_TC;
			}

			// Now for single round maps... same check on control point master
			int masterCP = FindEntityByClassname(-1, "team_control_point_master");

			if (masterCP > -1)
			{
				// Single round restricted are always A/D (gorge, gravelpit)
				restrictWinner = GetEntProp(masterCP, Prop_Data, "m_iInvalidCapWinner");
				if (restrictWinner > 1)
				{
					return TF2_GameMode_ADCP;
				}
			}

			return TF2_GameMode_5CP;
		}

		// pl and plr both show up as this game type
		case TF2_GameType_PL:
		{
			// All plr maps have this entity
			if (FindEntityByClassname(-1, "tf_logic_multiple_escort") > -1)
			{
				return TF2_GameMode_PLR;
			}

			return TF2_GameMode_PL;
		}

		case TF2_GameType_Arena:
		{
			return TF2_GameMode_Arena;
		}
	}
	return TF2_GameMode_Unknown;
}