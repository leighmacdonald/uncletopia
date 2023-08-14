#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#define PLUGIN_AUTHOR "Nanochip, viora, raspy"
#define PLUGIN_VERSION "1.5"

#include <sourcemod>
#include <sdktools>
#include <nativevotes>

public Plugin myinfo =
{
	name = "[TF2] Vote Scramble",
	author = PLUGIN_AUTHOR,
	description = "Vote to scramble teams.",
	version = PLUGIN_VERSION,
	url = "https://uncletopia.com"
};

ConVar cvarVoteTime;
ConVar cvarVoteTimeDelay;
ConVar cvarVoteChatPercent;
ConVar cvarVoteMenuPercent;
ConVar cvarTimeLimit;
ConVar cvarMinimumVotesNeeded;
ConVar cvarSkipSecondVote;
ConVar cvarMaxRounds;
ConVar cvarWinLimit;

int g_iVoters;
int g_iVotes;
int g_iVotesNeeded;
int g_iRoundsSinceLastScramble;
int g_iMinutesSinceLastScramble;
bool g_bVoted[MAXPLAYERS + 1]; 
int g_bVoteCooldown;
int g_bScrambleTeams;
int g_bBonusRoundTime;
int g_bScrambleDuringBRT;

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
	// -- use commented code below if using teamplay_win_panel event
	// if (event.GetBool("full_round")) {
	// 	g_iRoundsSinceLastScramble++;
	// }

	if (event.GetInt("round_complete") == 1 || StrEqual(name, "arena_win_panel")) {
		g_iRoundsSinceLastScramble++;
	}

	g_bBonusRoundTime = true;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bBonusRoundTime = false;

	if (g_bScrambleTeams) {
		g_bScrambleTeams = false;

		// scrambles occur twice if done during bonusroundtime (why??) with 5s between
		if (g_bScrambleDuringBRT) {
			CreateTimer(6.0, Timer_DelayLimitsUpdate);
		}
		else {
			CreateTimer(1.0, Timer_DelayLimitsUpdate);
		}
		g_bScrambleDuringBRT = false;
	}
}

public void OnPluginStart()
{
	CreateConVar("nano_votescramble_version", PLUGIN_VERSION, "Vote Scramble Version", FCVAR_DONTRECORD);

	cvarVoteTime = CreateConVar("nano_votescramble_time", "20.0", "Time in seconds the vote menu should last.", 0);
	cvarVoteTimeDelay = CreateConVar("nano_votescramble_delay", "180.0", "Time in seconds before players can initiate another team scramble vote.", 0);
	cvarVoteChatPercent = CreateConVar("nano_votescramble_chat_percentage", "0.20", "How many players are required for the chat vote to pass? 0.20 = 20%.", 0, true, 0.05, true, 1.0);
	cvarVoteMenuPercent = CreateConVar("nano_votescramble_menu_percentage", "0.60", "How many players are required for the menu vote to pass? 0.60 = 60%.", 0, true, 0.05, true, 1.0);
	cvarMinimumVotesNeeded = CreateConVar("nano_votescramble_minimum", "3", "What are the minimum number of votes needed to initiate a chat vote?", 0);
	cvarSkipSecondVote = CreateConVar("nano_votescramble_skip_second_vote", "0", "Should the second vote be skipped?", 0, true, 0.0, true, 1.0);

	cvarTimeLimit = FindConVar("mp_timelimit");
	cvarMaxRounds = FindConVar("mp_maxrounds");
	cvarWinLimit = FindConVar("mp_winlimit");

	RegConsoleCmd("sm_votescramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_vscramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegConsoleCmd("sm_scramble", Cmd_VoteScramble, "Initiate a vote to scramble teams!");
	RegAdminCmd("sm_forcescramble", Cmd_ForceScramble, ADMFLAG_VOTE, "Force a team scramble vote.");

	HookEvent("teamplay_win_panel", Event_RoundWin);
	HookEvent("teamplay_round_start", Event_RoundStart);

	CreateTimer(60.0, Timer_CountMinutes, _, TIMER_REPEAT);
}

public void OnMapStart()
{
	g_iVoters = 0;
	g_iVotesNeeded = 0;
	g_iVotes = 0;
	g_iRoundsSinceLastScramble = 0;
	g_iMinutesSinceLastScramble = 0;
	g_bVoteCooldown = false;
	g_bScrambleTeams = false;
	g_bBonusRoundTime = false;
	g_bScrambleDuringBRT = false;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!StrEqual(auth, "BOT"))
	{
		g_bVoted[client] = false;
		g_iVoters++;
		g_iVotesNeeded = RoundToCeil(float(g_iVoters) * cvarVoteChatPercent.FloatValue);
		if (g_iVotesNeeded < cvarMinimumVotesNeeded.IntValue) g_iVotesNeeded = cvarMinimumVotesNeeded.IntValue;
	}
}

public void OnClientDisconnect(int client)
{
	if (g_iVotes > 0 && g_bVoted[client]) g_iVotes--;
	g_iVoters--;
	g_iVotesNeeded = RoundToCeil(float(g_iVoters) * cvarVoteChatPercent.FloatValue);
	if (g_iVotesNeeded < cvarMinimumVotesNeeded.IntValue) g_iVotesNeeded = cvarMinimumVotesNeeded.IntValue;
}

public Action Cmd_ForceScramble(int client, int args)
{
	StartVoteScramble();
	return Plugin_Handled;
}

public Action Cmd_VoteScramble(int client, int args)
{
	AttemptVoteScramble(client);
	return Plugin_Handled;
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (strcmp(sArgs, "votescramble", false) == 0 || strcmp(sArgs, "vscramble", false) == 0 || strcmp(sArgs, "scramble", false) == 0 || strcmp(sArgs, "scrimblo", false) == 0 )
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		AttemptVoteScramble(client);

		SetCmdReplySource(old);
	}
}

void AttemptVoteScramble(int client)
{
	if (g_bScrambleTeams)
	{
		ReplyToCommand(client, "A previous vote scramble has succeeded. Teams will be scrambled next round.");
		return;
	}
	if (g_bVoteCooldown)
	{
		ReplyToCommand(client, "Sorry, votescramble is currently on cool-down.");
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	if (g_bVoted[client])
	{
		ReplyToCommand(client, "You have already voted for a team scramble. [%d/%d votes required]", g_iVotes, g_iVotesNeeded);
		return;
	}

	g_iVotes++;
	g_bVoted[client] = true;
	PrintToChatAll("%s wants to scramble teams. [%d/%d votes required]", name, g_iVotes, g_iVotesNeeded);

	if (g_iVotes >= g_iVotesNeeded)
	{
		StartVoteScramble();
	}
}

void StartVoteScramble()
{
	if (cvarSkipSecondVote.IntValue == 1) {
		CreateTimer(0.1, Timer_Scramble);
	} else {
		VoteScrambleMenu();
	}

	ResetVoteScramble();
	g_bVoteCooldown = true;
	CreateTimer(cvarVoteTimeDelay.FloatValue, Timer_Delay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Delay(Handle timer)
{
	g_bVoteCooldown = false;
	return Plugin_Continue;
}

void ResetVoteScramble()
{
	g_iVotes = 0;
	for (int i = 1; i <= MAXPLAYERS; i++) g_bVoted[i] = false;
}

void VoteScrambleMenu()
{
	if (NativeVotes_IsVoteInProgress())
	{
		CreateTimer(10.0, Timer_Retry, _, TIMER_FLAG_NO_MAPCHANGE);
		PrintToConsoleAll("[SM] Can't vote scramble because there is already a vote in progress. Retrying in 10 seconds...");
		return;
	}

	Handle vote = NativeVotes_Create(NativeVote_Handler, NativeVotesType_Custom_Mult);

	NativeVotes_SetTitle(vote, "Scramble teams?");

	NativeVotes_AddItem(vote, "yes", "Yes");
	NativeVotes_AddItem(vote, "no", "No");
	NativeVotes_DisplayToAll(vote, cvarVoteTime.IntValue);
}

public int NativeVote_Handler(Handle vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End: NativeVotes_Close(vote);
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			}
			else
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			}
		}
		case MenuAction_VoteEnd:
		{
			char item[64];
			float percent, limit;
			int votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			NativeVotes_GetItem(vote, param1, item, sizeof(item));

			percent = float(votes) / float(totalVotes);
			limit = cvarVoteMenuPercent.FloatValue;

			if (FloatCompare(percent, limit) >= 0 && StrEqual(item, "yes"))
			{

					NativeVotes_DisplayPass(vote, "Scrambling teams...");
					CreateTimer(0.1, Timer_Scramble);


			}
			else NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
		}
	}
	return 0;
}

public Action Timer_CountMinutes(Handle timer) {
	g_iMinutesSinceLastScramble++;
	return Plugin_Continue;
}

public Action Timer_Scramble(Handle timer) {
	ServerCommand("mp_scrambleteams");

	g_bScrambleTeams = true;
	if (g_bBonusRoundTime) {
		g_bScrambleDuringBRT = true;
	}

	PrintToChatAll("Scrambling the teams due to vote.");
	return Plugin_Continue;
}

public Action Timer_DelayLimitsUpdate(Handle timer) {
	// subtract from maxrounds/winlimit after scramble to prevent artificial superextension of maps
	// assume no limit if 0, don't set negatives
	if (cvarMaxRounds.IntValue != 0) {
		SetConVarInt(cvarMaxRounds, cvarMaxRounds.IntValue - g_iRoundsSinceLastScramble, false, true);
	}

	if (cvarWinLimit.IntValue != 0) {
		int rounds;
		rounds = cvarWinLimit.IntValue - g_iRoundsSinceLastScramble;
		rounds = rounds > 1 ? rounds : 1;
		SetConVarInt(cvarWinLimit, rounds, false, true);
	}

	if (cvarTimeLimit.IntValue != 0) {
		int time = cvarTimeLimit.IntValue - g_iMinutesSinceLastScramble;
		time = time > 5 ? time : 5;
		SetConVarInt(cvarTimeLimit, time, false, true);
	}

	g_iRoundsSinceLastScramble = 0;
	g_iMinutesSinceLastScramble = 0;

	return Plugin_Continue;
}

public Action Timer_DelayRTS(Handle timer, any mins)
{
	cvarTimeLimit.SetInt(mins);
	return Plugin_Continue;
}

public Action Timer_Retry(Handle timer)
{
	VoteScrambleMenu();
	return Plugin_Continue;
}