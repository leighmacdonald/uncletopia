#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>          // TFTeam_Red/Blue/Spectator enum
#include <multicolors>

#include <tfdb>
#include <tfdb_clientcheck>

#define PLUGIN_NAME        "[TFDB] Votes"
#define PLUGIN_AUTHOR      "x07x08, Silorak"
#define PLUGIN_DESCRIPTION "Various rocket votes."
#define PLUGIN_VERSION     "2.2.0"
#define PLUGIN_URL         "https://github.com/Silorak/TF2-Dodgeball"

int SpawnersCount;

ConVar CvarVoteBounceDuration;
ConVar CvarVoteClassDuration;
ConVar CvarVoteCountDuration;
ConVar CvarVoteBounceTimeout;
ConVar CvarVoteClassTimeout;
ConVar CvarVoteCountTimeout;
ConVar CvarVotePresetDuration;
ConVar CvarVotePresetTimeout;

bool VoteBounceAllowed;
bool VoteClassAllowed;
bool VoteCountAllowed;
bool VotePresetAllowed;

float LastVoteBounceTime;
float LastVoteClassTime;
float LastVoteCountTime;
float LastVotePresetTime;

// Per-client spam throttle — prevents a single player from spamming any vote
// command the instant a server-wide cooldown elapses. Enforced across ALL vote
// commands so griefers can't chain-call vrb / vrc / vrp.
#define CLIENT_VOTE_COOLDOWN 10.0
float LastClientVoteTime[MAXPLAYERS + 1];

// Returns true if the client is throttled (caller must reply + early-return).
bool IsClientVoteThrottled(int client)
{
	if (!TFDB_IsRealHuman(client)) return true;
	return (GetGameTime() - LastClientVoteTime[client]) < CLIENT_VOTE_COOLDOWN;
}

// Returns true if client is on a play team (RED or BLU). Use to gate vote
// commands that mutate live gameplay — spectators/unassigned can't call them.
// Replies with the standard message and expects caller to early-return.
bool IsCallerOnPlayingTeam(int client)
{
	int team = GetClientTeam(client);
	if (team <= view_as<int>(TFTeam_Spectator))
	{
		CReplyToCommand(client, "%t", "Dodgeball_Vote_MustBeOnTeam");
		return false;
	}
	return true;
}

// Clear the per-client throttle on connect so a reused slot can't inherit cooldown.
public void OnClientPutInServer(int client)
{
	LastClientVoteTime[client] = 0.0;
}

bool BounceEnabled;
int MainRocketClass = -1;
int RocketsCount = -1;

int SavedMaxRockets[MAX_SPAWNER_CLASSES];

bool Loaded;

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
	
	CvarVoteBounceDuration = CreateConVar("tf_dodgeball_votes_bounce_duration", "20", _, _, true, 0.0);
	CvarVoteClassDuration  = CreateConVar("tf_dodgeball_votes_class_duration", "20", _, _, true, 0.0);
	CvarVoteCountDuration  = CreateConVar("tf_dodgeball_votes_count_duration", "20", _, _, true, 0.0);
	CvarVoteBounceTimeout  = CreateConVar("tf_dodgeball_votes_bounce_timeout", "150", _, _, true, 0.0);
	CvarVoteClassTimeout   = CreateConVar("tf_dodgeball_votes_class_timeout", "150", _, _, true, 0.0);
	CvarVoteCountTimeout   = CreateConVar("tf_dodgeball_votes_count_timeout", "150", _, _, true, 0.0);
	CvarVotePresetDuration = CreateConVar("tf_dodgeball_votes_preset_duration", "20", _, _, true, 0.0);
	CvarVotePresetTimeout  = CreateConVar("tf_dodgeball_votes_preset_timeout", "150", _, _, true, 0.0);
	
	RegConsoleCmd("sm_vrb", CmdVoteBounce, "Start a rocket bounce vote");
	RegConsoleCmd("sm_vrc", CmdVoteClass, "Start a rocket class vote");
	RegConsoleCmd("sm_vrcount", CmdVoteCount, "Start a rocket count vote");
	RegConsoleCmd("sm_vrp", CmdVotePreset, "Start a preset vote");
	RegConsoleCmd("sm_votebounce", CmdVoteBounce, "Start a rocket bounce vote");
	RegConsoleCmd("sm_voteclass", CmdVoteClass, "Start a rocket class vote");
	RegConsoleCmd("sm_votecount", CmdVoteCount, "Start a rocket count vote");
	RegConsoleCmd("sm_votepreset", CmdVotePreset, "Start a preset vote");
	RegConsoleCmd("sm_voterocketbounce", CmdVoteBounce, "Start a rocket bounce vote");
	RegConsoleCmd("sm_voterocketclass", CmdVoteClass, "Start a rocket class vote");
	RegConsoleCmd("sm_voterocketcount", CmdVoteCount, "Start a rocket count vote");
	RegConsoleCmd("sm_voterocketpreset", CmdVotePreset, "Start a preset vote");
	
	if (!TFDB_IsDodgeballEnabled()) return;
	
	char mapName[64]; GetCurrentMap(mapName, sizeof(mapName));
	GetMapDisplayName(mapName, mapName, sizeof(mapName));
	char mapFile[PLATFORM_MAX_PATH]; FormatEx(mapFile, sizeof(mapFile), "%s.cfg", mapName);
	
	TFDB_OnRocketsConfigExecuted("general.cfg");
	TFDB_OnRocketsConfigExecuted(mapFile);
}

public void OnMapEnd()
{
	if (!Loaded) return;
	
	VoteBounceAllowed =
	VoteClassAllowed  =
	VoteCountAllowed  =
	VotePresetAllowed = false;
	
	LastVoteBounceTime =
	LastVoteClassTime  =
	LastVoteCountTime  =
	LastVotePresetTime = 0.0;
	
	BounceEnabled = false;
	MainRocketClass = -1;
	RocketsCount = -1;
	
	Loaded = false;
	
	SpawnersCount = 0;
}

public void TFDB_OnRocketsConfigExecuted(const char[] configFile)
{
	if (!Loaded)
	{
		VoteBounceAllowed =
		VoteClassAllowed  =
		VoteCountAllowed  =
		VotePresetAllowed = true;
		
		LastVoteBounceTime =
		LastVoteClassTime  =
		LastVoteCountTime  =
		LastVotePresetTime = 0.0;
		
		BounceEnabled = false;
		MainRocketClass = -1;
		RocketsCount = -1;
		
		Loaded = true;
	}
	
	if (strcmp(configFile, "general.cfg") == 0)
	{
		SpawnersCount = 0;
	}
	
	ParseConfigurations(configFile);
}

public Action CmdVoteBounce(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Command is in-game only.");

		return Plugin_Handled;
	}

	if (IsClientVoteThrottled(client))
	{
		CReplyToCommand(client, "%t", "Dodgeball_BounceVote_Cooldown",
		                RoundToCeil(CLIENT_VOTE_COOLDOWN - (GetGameTime() - LastClientVoteTime[client])));
		return Plugin_Handled;
	}

	if (!IsCallerOnPlayingTeam(client)) return Plugin_Handled;

	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(client, "%t", "Command_Disabled");

		return Plugin_Handled;
	}

	if (IsVoteInProgress())
	{
		CReplyToCommand(client, "%t", "Dodgeball_FFAVote_Conflict");

		return Plugin_Handled;
	}

	if (VoteBounceAllowed)
	{
		VoteBounceAllowed  = false;
		LastVoteBounceTime = GetGameTime();
		LastClientVoteTime[client] = GetGameTime();

		StartBounceVote();
		CreateTimer(CvarVoteBounceTimeout.FloatValue, VoteBounceTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(client, "%t", "Dodgeball_BounceVote_Cooldown",
		                RoundToCeil((LastVoteBounceTime + CvarVoteBounceTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartBounceVote()
{
	char strMode[16];
	strMode = !BounceEnabled ? "Enable" : "Disable";
	
	Menu menu = new Menu(VoteMenuHandler);
	menu.VoteResultCallback = VoteBounceResultHandler;
	
	menu.SetTitle("%s no rocket bounce mode?", strMode);
	
	menu.AddItem("0", "Yes");
	menu.AddItem("1", "No");
	
	int total;
	int[] clients = new int[MaxClients];
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!TFDB_IsRealHumanPlaying(client))
		{
			continue;
		}
		
		clients[total++] = client;
	}

	if (total < 1)
	{
		delete menu;
		return;
	}
	
	menu.DisplayVote(clients, total, CvarVoteBounceDuration.IntValue);
}

public int VoteMenuHandler(Menu menu, MenuAction iMenuActions, int iParam1, int iParam2)
{
	switch (iMenuActions)
	{
		case MenuAction_End :
		{
			delete menu;
		}
	}
	
	return 0;
}

public void VoteBounceResultHandler(Menu menu,
                                    int iNumVotes,
                                    int iNumClients,
                                    const int[][] iClientInfo,
                                    int numItems,
                                    const int[][] itemInfo)
{
	int winnerIndex = 0;
	
	if (numItems > 1 &&
	    (itemInfo[0][VOTEINFO_ITEM_VOTES] == itemInfo[1][VOTEINFO_ITEM_VOTES]))
	{
		winnerIndex = GetRandomInt(0, 1);
	}
	
	char winner[8]; menu.GetItem(itemInfo[winnerIndex][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	
	if (StrEqual(winner, "0"))
	{
		ToggleBounce();
	}
	else
	{
		CPrintToChatAll("%t", "Dodgeball_BounceVote_Failed");
	}
}

void ToggleBounce()
{
	if (!BounceEnabled)
	{
		EnableBounce();
	}
	else
	{
		DisableBounce();
	}
}

void EnableBounce()
{
	BounceEnabled = true;
	
	for (int index = 0; index < MAX_ROCKETS; index++)
	{
		if (!TFDB_IsValidRocket(index)) continue;
		
		TFDB_SetRocketBounces(index, TFDB_GetRocketClassMaxBounces(TFDB_GetRocketClass(index)));
	}
	
	CPrintToChatAll("%t", "Dodgeball_BounceVote_Enabled");
}

void DisableBounce()
{
	BounceEnabled = false;
	
	for (int index = 0; index < MAX_ROCKETS; index++)
	{
		if (!TFDB_IsValidRocket(index)) continue;
		
		TFDB_SetRocketBounces(index, 0);
	}
	
	CPrintToChatAll("%t", "Dodgeball_BounceVote_Disabled");
}

public Action CmdVoteClass(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Command is in-game only.");

		return Plugin_Handled;
	}

	if (IsClientVoteThrottled(client))
	{
		CReplyToCommand(client, "%t", "Dodgeball_ClassVote_Cooldown",
		                RoundToCeil(CLIENT_VOTE_COOLDOWN - (GetGameTime() - LastClientVoteTime[client])));
		return Plugin_Handled;
	}

	if (!IsCallerOnPlayingTeam(client)) return Plugin_Handled;

	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(client, "%t", "Command_Disabled");

		return Plugin_Handled;
	}

	if (IsVoteInProgress())
	{
		CReplyToCommand(client, "%t", "Dodgeball_FFAVote_Conflict");

		return Plugin_Handled;
	}

	if (VoteClassAllowed)
	{
		VoteClassAllowed  = false;
		LastVoteClassTime = GetGameTime();
		LastClientVoteTime[client] = GetGameTime();

		StartClassVote();
		CreateTimer(CvarVoteClassTimeout.FloatValue, VoteClassTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(client, "%t", "Dodgeball_ClassVote_Cooldown",
		                RoundToCeil((LastVoteClassTime + CvarVoteClassTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartClassVote()
{
	Menu menu = new Menu(VoteMenuHandler);
	menu.VoteResultCallback = VoteClassResultHandler;
	
	menu.SetTitle("Change main rocket class?");
	
	if (MainRocketClass != -1)
	{
		menu.AddItem("-1", "Reset the spawn chances");
	}
	
	char strClass[8], rocketLongName[32];
	
	for (int classIndex = 0; classIndex < TFDB_GetRocketClassCount(); classIndex++)
	{
		IntToString(classIndex, strClass, sizeof(strClass));
		TFDB_GetRocketClassLongName(classIndex, rocketLongName, sizeof(rocketLongName));
		
		menu.AddItem(strClass, rocketLongName, ITEMDRAW_DEFAULT);
	}
	
	int total;
	int[] clients = new int[MaxClients];
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!TFDB_IsRealHumanPlaying(client))
		{
			continue;
		}
		
		clients[total++] = client;
	}

	if (total < 1)
	{
		delete menu;
		return;
	}
	
	menu.DisplayVote(clients, total, CvarVoteClassDuration.IntValue);
}

public void VoteClassResultHandler(Menu menu,
                                   int iNumVotes,
                                   int iNumClients,
                                   const int[][] iClientInfo,
                                   int numItems,
                                   const int[][] itemInfo)
{
	int winnerIndex = 0;
	int iClassCount = TFDB_GetRocketClassCount();

	if (MainRocketClass != -1) iClassCount++;

	int iBound = numItems < iClassCount ? numItems : iClassCount;

	bool isEqual = AreVotesEqual(itemInfo, iBound);

	if (isEqual) winnerIndex = GetRandomInt(0, (iBound - 1));
	
	char winner[8], strClassLongName[32];
	
	menu.GetItem(itemInfo[winnerIndex][VOTEINFO_ITEM_INDEX], winner, sizeof(winner), _, strClassLongName, sizeof(strClassLongName));
	
	MainRocketClass = StringToInt(winner);
	
	if (MainRocketClass == -1)
	{
		CPrintToChatAll("%t", "Dodgeball_ClassVote_Reset");
	}
	else
	{
		CPrintToChatAll("%t", "Dodgeball_ClassVote_Changed", strClassLongName);
	}
	
	TFDB_DestroyRockets();
}

public Action CmdVoteCount(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Command is in-game only.");

		return Plugin_Handled;
	}

	if (IsClientVoteThrottled(client))
	{
		CReplyToCommand(client, "%t", "Dodgeball_CountVote_Cooldown",
		                RoundToCeil(CLIENT_VOTE_COOLDOWN - (GetGameTime() - LastClientVoteTime[client])));
		return Plugin_Handled;
	}

	if (!IsCallerOnPlayingTeam(client)) return Plugin_Handled;

	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(client, "%t", "Command_Disabled");

		return Plugin_Handled;
	}

	if (IsVoteInProgress())
	{
		CReplyToCommand(client, "%t", "Dodgeball_FFAVote_Conflict");

		return Plugin_Handled;
	}

	if (VoteCountAllowed)
	{
		VoteCountAllowed  = false;
		LastVoteCountTime = GetGameTime();
		LastClientVoteTime[client] = GetGameTime();

		StartCountVote();
		CreateTimer(CvarVoteCountTimeout.FloatValue, VoteCountTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(client, "%t", "Dodgeball_CountVote_Cooldown",
		                RoundToCeil((LastVoteCountTime + CvarVoteCountTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartCountVote()
{
	Menu menu = new Menu(VoteMenuHandler);
	menu.VoteResultCallback = VoteCountResultHandler;
	
	menu.SetTitle("Change rockets count?");
	
	if (RocketsCount != -1)
	{
		menu.AddItem("-1", "Reset rockets count");
	}
	
	menu.AddItem("0", "One rocket");
	menu.AddItem("1", "Two rockets");
	menu.AddItem("2", "Three rockets");
	menu.AddItem("3", "Four rockets");
	menu.AddItem("4", "Five rockets");
	
	int total;
	int[] clients = new int[MaxClients];
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!TFDB_IsRealHumanPlaying(client))
		{
			continue;
		}
		
		clients[total++] = client;
	}

	if (total < 1)
	{
		delete menu;
		return;
	}
	
	menu.DisplayVote(clients, total, CvarVoteCountDuration.IntValue);
}

public void VoteCountResultHandler(Menu menu,
                                   int iNumVotes,
                                   int iNumClients,
                                   const int[][] iClientInfo,
                                   int numItems,
                                   const int[][] itemInfo)
{
	int winnerIndex = 0;
	int iVotesCount = 5;

	if (RocketsCount != -1) iVotesCount++;

	int iBound = numItems < iVotesCount ? numItems : iVotesCount;

	bool isEqual = AreVotesEqual(itemInfo, iBound);

	if (isEqual) winnerIndex = GetRandomInt(0, (iBound - 1));
	
	char winner[8]; menu.GetItem(itemInfo[winnerIndex][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	
	RocketsCount = StringToInt(winner);
	
	for (int index = 0; index < TFDB_GetSpawnersCount(); index++)
	{
		TFDB_SetSpawnersMaxRockets(index, RocketsCount == -1 ? SavedMaxRockets[index] : (RocketsCount + 1));
	}
	
	if (RocketsCount == -1)
	{
		CPrintToChatAll("%t", "Dodgeball_CountVote_Reset");
	}
	else
	{
		CPrintToChatAll("%t", "Dodgeball_CountVote_Changed", (RocketsCount + 1));
	}
}

public Action CmdVotePreset(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "Command is in-game only.");

		return Plugin_Handled;
	}

	if (IsClientVoteThrottled(client))
	{
		CReplyToCommand(client, "%t", "Dodgeball_PresetVote_Cooldown",
		                RoundToCeil(CLIENT_VOTE_COOLDOWN - (GetGameTime() - LastClientVoteTime[client])));
		return Plugin_Handled;
	}

	if (!IsCallerOnPlayingTeam(client)) return Plugin_Handled;

	if (!TFDB_IsDodgeballEnabled())
	{
		CReplyToCommand(client, "%t", "Command_Disabled");

		return Plugin_Handled;
	}

	if (IsVoteInProgress())
	{
		CReplyToCommand(client, "%t", "Dodgeball_FFAVote_Conflict");

		return Plugin_Handled;
	}

	if (TFDB_GetPresetCount() == 0)
	{
		CReplyToCommand(client, "%t", "Dodgeball_PresetVote_NoPresets");

		return Plugin_Handled;
	}

	if (VotePresetAllowed)
	{
		VotePresetAllowed  = false;
		LastVotePresetTime = GetGameTime();
		LastClientVoteTime[client] = GetGameTime();
		
		StartPresetVote();
		CreateTimer(CvarVotePresetTimeout.FloatValue, VotePresetTimeoutCallback, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		CReplyToCommand(client, "%t", "Dodgeball_PresetVote_Cooldown",
		                RoundToCeil((LastVotePresetTime + CvarVotePresetTimeout.FloatValue) - GetGameTime()));
	}
	
	return Plugin_Handled;
}

void StartPresetVote()
{
	Menu menu = new Menu(VoteMenuHandler);
	menu.VoteResultCallback = VotePresetResultHandler;
	
	menu.SetTitle("Select gameplay preset:");
	
	int iPresetCount = TFDB_GetPresetCount();
	for (int i = 0; i < iPresetCount; i++)
	{
		char indexStr[8], name[64];
		IntToString(i, indexStr, sizeof(indexStr));
		TFDB_GetPresetName(i, name, sizeof(name));
		menu.AddItem(indexStr, name);
	}
	
	int total;
	int[] clients = new int[MaxClients];
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!TFDB_IsRealHumanPlaying(client))
		{
			continue;
		}
		
		clients[total++] = client;
	}

	if (total < 1)
	{
		delete menu;
		return;
	}
	
	menu.DisplayVote(clients, total, CvarVotePresetDuration.IntValue);
}

public void VotePresetResultHandler(Menu menu,
                                    int iNumVotes,
                                    int iNumClients,
                                    const int[][] iClientInfo,
                                    int numItems,
                                    const int[][] itemInfo)
{
	int winnerIndex = 0;
	
	bool isEqual = AreVotesEqual(itemInfo, numItems);
	
	if (isEqual) winnerIndex = GetRandomInt(0, (numItems - 1));
	
	char winner[8]; menu.GetItem(itemInfo[winnerIndex][VOTEINFO_ITEM_INDEX], winner, sizeof(winner));
	
	int iPreset = StringToInt(winner);
	
	if (TFDB_ApplyPreset(iPreset))
	{
		char name[64];
		TFDB_GetPresetName(iPreset, name, sizeof(name));
		CPrintToChatAll("%t", "Dodgeball_PresetVote_Applied", name);
	}
}

public Action VoteBounceTimeoutCallback(Handle hTimer)
{
	VoteBounceAllowed = true;
	
	return Plugin_Continue;
}

public Action VoteClassTimeoutCallback(Handle hTimer)
{
	VoteClassAllowed = true;
	
	return Plugin_Continue;
}

public Action VoteCountTimeoutCallback(Handle hTimer)
{
	VoteCountAllowed = true;
	
	return Plugin_Continue;
}

public Action VotePresetTimeoutCallback(Handle hTimer)
{
	VotePresetAllowed = true;
	
	return Plugin_Continue;
}

public Action TFDB_OnRocketCreatedPre(int index, int &classIndex, RocketFlags &iFlags)
{
	if (MainRocketClass == -1) return Plugin_Continue;
	
	classIndex = MainRocketClass;
	iFlags = TFDB_GetRocketClassFlags(MainRocketClass);
	
	return Plugin_Changed;
}

public void TFDB_OnRocketCreated(int index, int entity)
{
	if (!BounceEnabled) return;

	TFDB_SetRocketBounces(index, TFDB_GetRocketClassMaxBounces(TFDB_GetRocketClass(index)));
}

/**
 * Re-apply max-bounces every time a rocket is deflected (airblasted).
 *
 * Why: rocket classes with `"reset bounces" "1"` (RocketFlag_ResetBounces) zero
 * the rocket's bounce counter on every deflect (`dodgeball_events.inc:248-251`).
 * Without this hook, a no-bounce-mode vote ONLY affects the spawn rocket — the
 * moment a player airblasts it, the deflect-reset undoes the vote and the
 * rocket bounces freely. Re-locking on every deflect makes the vote stick.
 *
 * Forward fires AFTER core's deflect processing, so RocketBounces[i] is
 * already 0 by the time this runs — we restore it to MaxBounces[class].
 */
public void TFDB_OnRocketDeflect(int index, int entity, int owner)
{
	if (!BounceEnabled) return;

	TFDB_SetRocketBounces(index, TFDB_GetRocketClassMaxBounces(TFDB_GetRocketClass(index)));
}

void ParseConfigurations(const char[] configFile)
{
	char path[PLATFORM_MAX_PATH];
	char strFileName[PLATFORM_MAX_PATH];
	FormatEx(strFileName, sizeof(strFileName), "configs/dodgeball/%s", configFile);
	BuildPath(Path_SM, path, sizeof(path), strFileName);
	
	if (!FileExists(path, true)) return;
	
	KeyValues kvConfig = new KeyValues("TF2_Dodgeball");
	
	if (kvConfig.ImportFromFile(path) == false) SetFailState("[TFDB Votes] Error while parsing configuration file: %s", path);
	
	kvConfig.GotoFirstSubKey();
	
	do
	{
		char section[64]; kvConfig.GetSectionName(section, sizeof(section));
		
		if (StrEqual(section, "spawners")) ParseSpawners(kvConfig);
	}
	while (kvConfig.GotoNextKey());
	
	delete kvConfig;
}

void ParseSpawners(KeyValues kvConfig)
{
	kvConfig.GotoFirstSubKey();
	
	do
	{
		if (SpawnersCount >= MAX_SPAWNER_CLASSES)
		{
			LogError("Reached maximum spawner classes (%d). Remaining spawners will be ignored.", MAX_SPAWNER_CLASSES);
			break;
		}

		int index = SpawnersCount;
		
		SavedMaxRockets[index] = kvConfig.GetNum("max rockets", 1);
		
		SpawnersCount++;
	}
	while (kvConfig.GotoNextKey());
	
	kvConfig.GoBack();
}

bool AreVotesEqual(const int[][] iVoteItems, int iSize)
{
	int iFirst = iVoteItems[0][VOTEINFO_ITEM_VOTES];
	
	for (int index = 1; index < iSize; index++)
	{
		if (iVoteItems[index][VOTEINFO_ITEM_VOTES] != iFirst) return false;
	}
	
	return true;
}
