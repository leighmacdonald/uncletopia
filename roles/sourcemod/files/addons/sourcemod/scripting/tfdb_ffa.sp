#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2>
#include <multicolors>

#include <tfdb>

#define PLUGIN_NAME        "[TFDB] Free-for-All"
#define PLUGIN_AUTHOR      "x07x08"
#define PLUGIN_DESCRIPTION "Makes all rockets neutral"
#define PLUGIN_VERSION     "1.1.3"
#define PLUGIN_URL         "https://github.com/x07x08/TF2-Dodgeball-Modified"

bool  Loaded;
bool  FFAEnabled;
int   BotCount;
bool  VoteAllowed;
float LastVoteTime;
int   OldTeam[MAXPLAYERS + 1];

Address MyWearables;

ConVar CvarDisableOnBot;
ConVar CvarVoteTimeout;
ConVar CvarVoteDuration;
ConVar CvarToggleMode;
ConVar CvarAllowStealing;
ConVar CvarDisableConfig;
ConVar CvarEnableConfig;
ConVar CvarSwitchTeams;
ConVar CvarFriendlyFire;

public Plugin myinfo =
{
	name        = PLUGIN_NAME,
	author      = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version     = PLUGIN_VERSION,
	url         = PLUGIN_URL
};

public void OnPluginStart()
{
	LoadTranslations("tfdb.phrases.txt");
	
	MyWearables = view_as<Address>(FindSendPropInfo("CTFPlayer", "m_hMyWearables"));
	
	CvarDisableOnBot  = CreateConVar("tf_dodgeball_ffa_bot", "1", "Disable FFA when a bot joins?", _, true, 0.0, true, 1.0);
	CvarVoteTimeout   = CreateConVar("tf_dodgeball_ffa_timeout", "150", "Vote timeout (in seconds)", _, true, 0.0);
	CvarVoteDuration  = CreateConVar("tf_dodgeball_ffa_duration", "20", "Vote duration (in seconds)", _, true, 0.0);
	CvarToggleMode    = CreateConVar("tf_dodgeball_ffa_mode", "1", "How does changing FFA affect the rockets?\n 0 - No effect, wait for the next spawn\n 1 - Destroy all active rockets\n 2 - Immediately change the rockets to be neutral", _, true, 0.0);
	CvarAllowStealing = CreateConVar("tf_dodgeball_ffa_stealing", "1", "Allow stealing in FFA mode?", _, true, 0.0, true, 1.0);
	CvarDisableConfig = CreateConVar("tf_dodgeball_ffa_disablecfg", "sourcemod/dodgeball_ffa_disable.cfg", "Config file to execute when disabling FFA mode");
	CvarEnableConfig  = CreateConVar("tf_dodgeball_ffa_enablecfg", "sourcemod/dodgeball_ffa_enable.cfg", "Config file to execute when enabling FFA mode");
	CvarSwitchTeams   = CreateConVar("tf_dodgeball_ffa_teams", "1", "Automatically swap players when a team is empty in FFA mode?", _, true, 0.0, true, 1.0);
	CvarFriendlyFire  = FindConVar("mp_friendlyfire");
	
	RegAdminCmd("sm_ffa", CmdToggleFFA, ADMFLAG_CONFIG, "Forcefully toggle FFA");
	RegConsoleCmd("sm_voteffa", CmdVoteFFA, "Start a vote to toggle FFA");
	
	if (!TFDB_IsDodgeballEnabled()) return;
	
	TFDB_OnRocketsConfigExecuted("general.cfg");
}

public void TFDB_OnRocketsConfigExecuted(const char[] strConfigFile)
{
	if (Loaded) return;
	
	int iTeam;
	
	VoteAllowed  = true;
	FFAEnabled   = false;
	BotCount     = 0;
	LastVoteTime = 0.0;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient)) continue;
		
		iTeam = GetClientTeam(iClient);
		
		if (!(iTeam >= 2)) continue;
		
		OldTeam[iClient] = iTeam;
		
		if (IsFakeClient(iClient)) BotCount++;
	}
	
	CvarDisableOnBot.AddChangeHook(DisableOnBotCallback);
	
	HookEvent("player_team", OnPlayerTeam);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("teamplay_round_start", OnRoundStart);
	
	Loaded = true;
}

public void OnMapEnd()
{
	if (!Loaded) return;
	
	UnhookEvent("player_team", OnPlayerTeam);
	UnhookEvent("player_death", OnPlayerDeath);
	UnhookEvent("teamplay_round_start", OnRoundStart);
	
	CvarDisableOnBot.RemoveChangeHook(DisableOnBotCallback);
	
	VoteAllowed  = false;
	FFAEnabled   = false;
	BotCount     = 0;
	LastVoteTime = 0.0;
	
	CvarFriendlyFire.RestoreDefault();
	ExecuteDisableConfig();
	
	Loaded = false;
}

public void OnClientDisconnect(int iClient)
{
	OldTeam[iClient] = 0;
	
	if (!FFAEnabled ||
	    !CvarSwitchTeams.BoolValue ||
	    (CvarDisableOnBot.BoolValue && BotCount) ||
	    !TFDB_GetRoundStarted())
	{
		return;
	}
	
	int iTeam = GetClientTeam(iClient);
	
	if (iTeam <= 1) return;
	
	int iOtherTeam = GetAnalogueTeam(iTeam);
	
	if (((GetTeamAliveClientCount(iTeam) - view_as<int>(IsPlayerAlive(iClient))) == 0) &&
	    ((GetTeamAliveClientCount(iOtherTeam) - 1) >= 1))
	{
		ChangeAliveClientTeam(GetRandomTeamAliveClient(iOtherTeam), iTeam);
	}
}

public void OnClientConnected(int iClient)
{
	OldTeam[iClient] = 0;
}

public void OnPlayerTeam(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	int iClient  = GetClientOfUserId(hEvent.GetInt("userid"));
	int iTeam    = hEvent.GetInt("team");
	int iOldTeam = hEvent.GetInt("oldteam");
	
	if (!FFAEnabled ||
	    !CvarSwitchTeams.BoolValue ||
	    (CvarDisableOnBot.BoolValue && BotCount) ||
	    !TFDB_GetRoundStarted())
	{
		OldTeam[iClient] = iTeam;
	}
	else
	{
		// If you swap between RED and BLU, this event gets fired first instead of player_death.
		// This makes GetClientTeam report the new team instead of the old one when used inside a player_death callback.
		
		if (iTeam <= 1)
		{
			OldTeam[iClient] = iTeam;
		}
		else if ((iOldTeam >= 2) &&
		         ((GetTeamAliveClientCount(iOldTeam) - view_as<int>(IsPlayerAlive(iClient))) == 0) &&
		         ((GetTeamAliveClientCount(iTeam) - 1) >= 1))
		{
			ChangeAliveClientTeam(GetRandomTeamAliveClient(iTeam), iOldTeam);
		}
	}
	
	if (!IsFakeClient(iClient)) return;
	
	if ((iOldTeam <= 1) && (iTeam >= 2))
	{
		BotCount++;
		
		if (FFAEnabled && (BotCount == 1) && CvarDisableOnBot.BoolValue)
		{
			CPrintToChatAll("%t", "Dodgeball_FFABot_Joined");
			CvarFriendlyFire.RestoreDefault();
			ExecuteDisableConfig();
		}
	}
	else if ((iOldTeam >= 2) && (iTeam <= 1))
	{
		BotCount--;
		
		if (FFAEnabled && (BotCount == 0) && CvarDisableOnBot.BoolValue)
		{
			CPrintToChatAll("%t", "Dodgeball_FFABot_Left");
			CvarFriendlyFire.SetBool(true);
			ExecuteEnableConfig();
		}
	}
}

public void OnPlayerDeath(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	if (!FFAEnabled ||
	    !CvarSwitchTeams.BoolValue ||
	    (CvarDisableOnBot.BoolValue && BotCount) ||
	    !TFDB_GetRoundStarted())
	{
		return;
	}
	
	int iVictim = GetClientOfUserId(hEvent.GetInt("userid"));
	
	int iTeam = GetClientTeam(iVictim);
	
	if (iTeam <= 1) return; // ...
	
	int iOtherTeam = GetAnalogueTeam(iTeam);
	
	// Checking the alive players count in here doesn't exclude the player that has just died.
	// Doing this check in a SDKHook_OnTakeDamagePost callback excludes him for some reason...
	
	if (((GetTeamAliveClientCount(iTeam) - 1) == 0) && ((GetTeamAliveClientCount(iOtherTeam) - 1) >= 1))
	{
		ChangeAliveClientTeam(GetRandomTeamAliveClient(iOtherTeam), iTeam);
	}
}

public void OnRoundStart(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	if (!FFAEnabled ||
	    !CvarSwitchTeams.BoolValue ||
	    (CvarDisableOnBot.BoolValue && BotCount))
	{
		return;
	}
	
	int iTeam;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || ((iTeam = GetClientTeam(iClient)) <= 1)) continue;
		
		if ((OldTeam[iClient] >= 2) &&
		    (OldTeam[iClient] != iTeam) &&
		    ((GetTeamAliveClientCount(iTeam) - view_as<int>(IsPlayerAlive(iClient))) >= 1))
		{
			ChangeClientTeam(iClient, OldTeam[iClient]);
		}
		
		if (OldTeam[iClient] <= 1) OldTeam[iClient] = iTeam;
	}
}

public Action CmdToggleFFA(int iClient, int iArgs)
{
	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(iClient, "%t", "Command_Disabled");
		
		return Plugin_Handled;
	}
	
	ToggleFFA();
	
	return Plugin_Handled;
}

public Action CmdVoteFFA(int iClient, int iArgs)
{
	if (iClient == 0)
	{
		// CReplyToCommand prints the message twice...
		ReplyToCommand(iClient, "Command is in-game only.");
		
		return Plugin_Handled;
	}
	
	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(iClient, "%t", "Command_Disabled");
		
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_FFAVote_Conflict");
		
		return Plugin_Handled;
	}
	
	if (VoteAllowed)
	{
		VoteAllowed  = false;
		LastVoteTime = GetGameTime();
		
		StartFFAVote();
		CreateTimer(CvarVoteTimeout.FloatValue, VoteTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(iClient, "%t", "Dodgeball_FFAVote_Cooldown",
		                RoundToCeil((LastVoteTime + CvarVoteTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

public void DisableOnBotCallback(ConVar hConvar, const char[] strOldValue, const char[] strNewValue)
{
	if (!FFAEnabled || !BotCount) return;
	
	if (hConvar.BoolValue)
	{
		CvarFriendlyFire.RestoreDefault();
		ExecuteDisableConfig();
	}
	else
	{
		CvarFriendlyFire.SetBool(true);
		ExecuteEnableConfig();
	}
}

void StartFFAVote()
{
	char strMode[16];
	strMode = !FFAEnabled ? "Enable" : "Disable";
	
	Menu hMenu = new Menu(VoteMenuHandler);
	hMenu.VoteResultCallback = VoteResultHandler;
	
	hMenu.SetTitle("%s FFA mode?", strMode);
	
	hMenu.AddItem("0", "Yes");
	hMenu.AddItem("1", "No");
	
	int iTotal;
	int[] iClients = new int[MaxClients];
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient) || IsFakeClient(iClient) || GetClientTeam(iClient) <= 1)
		{
			continue;
		}
		
		iClients[iTotal++] = iClient;
	}
	
	hMenu.DisplayVote(iClients, iTotal, CvarVoteDuration.IntValue);
}

public int VoteMenuHandler(Menu hMenu, MenuAction iMenuActions, int iParam1, int iParam2)
{
	switch (iMenuActions)
	{
		case MenuAction_End :
		{
			delete hMenu;
		}
	}
	
	return 0;
}

public void VoteResultHandler(Menu hMenu,
                              int iNumVotes,
                              int iNumClients,
                              const int[][] iClientInfo,
                              int iNumItems,
                              const int[][] iItemInfo)
{
	int iWinnerIndex = 0;
	
	if (iNumItems > 1 &&
	    (iItemInfo[0][VOTEINFO_ITEM_VOTES] == iItemInfo[1][VOTEINFO_ITEM_VOTES]))
	{
		iWinnerIndex = GetRandomInt(0, 1);
	}
	
	char strWinner[8]; hMenu.GetItem(iItemInfo[iWinnerIndex][VOTEINFO_ITEM_INDEX], strWinner, sizeof(strWinner));
	
	if (StrEqual(strWinner, "0"))
	{
		ToggleFFA();
	}
	else
	{
		CPrintToChatAll("%t", "Dodgeball_FFAVote_Failed");
	}
}

void EnableFFA()
{
	FFAEnabled = true;
	
	if (CvarDisableOnBot.BoolValue && BotCount)
	{
		CPrintToChatAll("%t", "Dodgeball_FFAVote_LateEnabled");
	}
	else
	{
		CvarFriendlyFire.SetBool(true);
		ExecuteEnableConfig();
		
		switch (CvarToggleMode.IntValue)
		{
			case 1 :
			{
				TFDB_DestroyRockets();
			}
			
			case 2 :
			{
				ChangeRockets();
			}
		}
		
		CPrintToChatAll("%t", "Dodgeball_FFAVote_Enabled");
	}
}

void DisableFFA()
{
	FFAEnabled = false;
	CvarFriendlyFire.RestoreDefault();
	ExecuteDisableConfig();
	
	switch (CvarToggleMode.IntValue)
	{
		case 1 :
		{
			TFDB_DestroyRockets();
		}
		
		case 2 :
		{
			ChangeRockets();
		}
	}
	
	CPrintToChatAll("%t", "Dodgeball_FFAVote_Disabled");
}

void ToggleFFA()
{
	if (!FFAEnabled)
	{
		EnableFFA();
	}
	else
	{
		DisableFFA();
	}
}

void ChangeRockets()
{
	RocketFlags iFlags, iClassFlags;
	int iEntity;
	
	for (int iIndex = 0; iIndex < MAX_ROCKETS; iIndex++)
	{
		if (!TFDB_IsValidRocket(iIndex)) continue;
		
		iFlags = TFDB_GetRocketFlags(iIndex);
		iClassFlags = TFDB_GetRocketClassFlags(TFDB_GetRocketClass(iIndex));
		iEntity = EntRefToEntIndex(TFDB_GetRocketEntity(iIndex));
		
		if (FFAEnabled)
		{
			iFlags |= RocketFlag_IsNeutral;
			
			if (CvarAllowStealing.BoolValue) iFlags |= RocketFlag_CanBeStolen;
			
			SetEntProp(iEntity, Prop_Send, "m_iTeamNum", 1, 1);
			
			TFDB_SetRocketFlags(iIndex, iFlags);
		}
		else
		{
			if (!(iClassFlags & RocketFlag_IsNeutral)) iFlags &= ~RocketFlag_IsNeutral;
			
			if (CvarAllowStealing.BoolValue && !(iClassFlags & RocketFlag_CanBeStolen)) iFlags &= ~RocketFlag_CanBeStolen;
			
			int iOwner = GetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity");
			SetEntProp(iEntity, Prop_Send, "m_iTeamNum", GetClientTeam(iOwner), 1);
			
			TFDB_SetRocketFlags(iIndex, iFlags);
		}
	}
}

public Action VoteTimeoutCallback(Handle hTimer)
{
	VoteAllowed = true;
	
	return Plugin_Continue;
}

public Action TFDB_OnRocketCreatedPre(int iIndex, int &iClass, RocketFlags &iFlags)
{
	if (FFAEnabled && (!CvarDisableOnBot.BoolValue || !BotCount))
	{
		iFlags |= RocketFlag_IsNeutral;
		
		if (CvarAllowStealing.BoolValue) iFlags |= RocketFlag_CanBeStolen;
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

void ExecuteDisableConfig()
{
	char strConfigPath[64]; CvarDisableConfig.GetString(strConfigPath, sizeof(strConfigPath));
	ServerCommand("exec \"%s\"", strConfigPath);
}

void ExecuteEnableConfig()
{
	char strConfigPath[64]; CvarEnableConfig.GetString(strConfigPath, sizeof(strConfigPath));
	ServerCommand("exec \"%s\"", strConfigPath);
}

int GetTeamAliveClientCount(int iTeam)
{
	int iCount;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient)) continue;
		
		if ((GetClientTeam(iClient) == iTeam) && IsPlayerAlive(iClient)) iCount++;
	}
	
	return iCount;
}

stock int GetAnalogueTeam(int iTeam)
{
	if (iTeam == view_as<int>(TFTeam_Red)) return view_as<int>(TFTeam_Blue);
	
	return view_as<int>(TFTeam_Red);
}

// https://forums.alliedmods.net/showthread.php?t=286924

int GetRandomTeamAliveClient(int iTeam)
{
	int[] iClients = new int[MaxClients];
	int iCount;
	
	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (!IsClientInGame(iClient)) continue;
		
		if ((GetClientTeam(iClient) == iTeam) && IsPlayerAlive(iClient)) iClients[iCount++] = iClient;
	}
	
	return iCount == 0 ? -1 : iClients[GetRandomInt(0, iCount - 1)];
}

// https://forums.alliedmods.net/showthread.php?t=314271

void ChangeAliveClientTeam(int iClient, int iTeam)
{
	int iLifeState = GetEntProp(iClient, Prop_Send, "m_lifeState");
	SetEntProp(iClient, Prop_Send, "m_lifeState", 2);
	
	ChangeClientTeam(iClient, iTeam);
	SetEntProp(iClient, Prop_Send, "m_lifeState", iLifeState);
	
	int iWearable;
	int iWearablesCount = GetPlayerWearablesCount(iClient);
	Address pData = DereferencePointer(GetEntityAddress(iClient) + MyWearables);
	
	for (int iIndex = 0; iIndex < iWearablesCount; iIndex++)
	{
		iWearable = LoadEntityHandleFromAddress(pData + view_as<Address>(0x04 * iIndex));
		
		SetEntProp(iWearable, Prop_Send, "m_nSkin", (iTeam == view_as<int>(TFTeam_Blue)) ? 1 : 0);
		SetEntProp(iWearable, Prop_Send, "m_iTeamNum", iTeam);
	}
}

/*
	https://github.com/nosoop/SM-TFUtils/blob/master/scripting/tf2utils.sp
	https://github.com/nosoop/stocksoup/blob/master/memory.inc
*/

stock int LoadEntityHandleFromAddress(Address pAddress)
{
	return EntRefToEntIndex(LoadFromAddress(pAddress, NumberType_Int32) | (1 << 31));
}

stock Address DereferencePointer(Address pAddress)
{
	// maybe someday we'll do 64-bit addresses
	return view_as<Address>(LoadFromAddress(pAddress, NumberType_Int32));
}

int GetPlayerWearablesCount(int iClient)
{
	return GetEntData(iClient, view_as<int>(MyWearables) + 0x0C);
}
