/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes
 * Copyright (C) 2011-2013 Ross Bemrose (Powerlord).  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#include "include/nativevotes.inc"

new EngineVersion:g_EngineVersion = Engine_Unknown;

#include "nativevotes/data-keyvalues.sp"

#define LOGTAG "NV"

#define MAX_VOTE_DETAILS_LENGTH				256		// This is higher than Source SDK 2013 says, but...
#define TRANSLATION_LENGTH					192

#define VOTE_DELAY_TIME 					3.0

// SourceMod uses these internally, so... we do too.
#define VOTE_NOT_VOTING 					-2
#define VOTE_PENDING 						-1

#define VERSION 							"0.8.3"

#define MAX_VOTE_ISSUES					20
#define VOTE_STRING_SIZE					32

//----------------------------------------------------------------------------
// These values are swapped from their NativeVotes equivalent
#define L4D2_VOTE_YES_INDEX					1
#define L4D2_VOTE_NO_INDEX					0

#define L4DL4D2_COUNT						2
#define TF2CSGO_COUNT						5


//----------------------------------------------------------------------------
// Global Variables
new g_NextVote = 0;

//----------------------------------------------------------------------------
// CVars
new Handle:g_Cvar_VoteHintbox;
new Handle:g_Cvar_VoteChat;
new Handle:g_Cvar_VoteConsole;
new Handle:g_Cvar_VoteClientConsole;
new Handle:g_Cvar_VoteDelay;

//new Handle:g_Forward_VoteResults;

// Public Forwards

//new Handle:g_Forward_OnCallVoteSetup;
//new Handle:g_Forward_OnCallVote;

//----------------------------------------------------------------------------
// Used to track current vote data
new Handle:g_hVoteTimer;
new Handle:g_hDisplayTimer;

new g_Clients;
new g_TotalClients;
new g_Items;
new Handle:g_hVotes;
new Handle:g_hCurVote;
new g_curDisplayClient = 0;
new String:g_newMenuTitle[TRANSLATION_LENGTH];
new g_curItemClient = 0;
new String:g_newMenuItem[TRANSLATION_LENGTH];

new bool:g_bStarted;
new bool:g_bCancelled;
new g_NumVotes;
new g_VoteTime;
new g_VoteFlags;
new Float:g_fStartTime;
new g_TimeLeft;
new g_ClientVotes[MAXPLAYERS+1];
new bool:g_bRevoting[MAXPLAYERS+1];
new String:g_LeaderList[1024];

#include "nativevotes/game.sp"

public Plugin:myinfo = 
{
	name = "NativeVotes",
	author = "Powerlord",
	description = "Voting API to use the game's native vote panels. Compatible with L4D, L4D2, TF2, and CS:GO.",
	version = VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=208008"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("GetUserMessageType");
	MarkNativeAsOptional("GetEngineVersion");
	
	new String:engineName[64];
	if (!Game_IsGameSupported(engineName, sizeof(engineName)))
	{
		Format(error, err_max, "Unsupported game: %s", engineName);
		//strcopy(error, err_max, "Unsupported game");
		return APLRes_Failure;
	}
	
	CreateNative("NativeVotes_IsVoteTypeSupported", Native_IsVoteTypeSupported);
	CreateNative("NativeVotes_Create", Native_Create);
	CreateNative("NativeVotes_Close", Native_Close);
	CreateNative("NativeVotes_Display", Native_Display);
	CreateNative("NativeVotes_AddItem", Native_AddItem);
	CreateNative("NativeVotes_InsertItem", Native_InsertItem);
	CreateNative("NativeVotes_RemoveItem", Native_RemoveItem);
	CreateNative("NativeVotes_RemoveAllItems", Native_RemoveAllItems);
	CreateNative("NativeVotes_GetItem", Native_GetItem);
	CreateNative("NativeVotes_GetItemCount", Native_GetItemCount);
	CreateNative("NativeVotes_SetDetails", Native_SetDetails);
	CreateNative("NativeVotes_GetDetails", Native_GetDetails);
	CreateNative("NativeVotes_SetTitle", Native_SetTitle);
	CreateNative("NativeVotes_GetTitle", Native_GetTitle);
	CreateNative("NativeVotes_SetTarget", Native_SetTarget);
	CreateNative("NativeVotes_GetTarget", Native_GetTarget);
	CreateNative("NativeVotes_GetTargetSteam", Native_GetTargetSteam);
	CreateNative("NativeVotes_IsVoteInProgress", Native_IsVoteInProgress);
	CreateNative("NativeVotes_GetMaxItems", Native_GetMaxItems);
	CreateNative("NativeVotes_SetOptionFlags", Native_SetOptionFlags);
	CreateNative("NativeVotes_GetOptionFlags", Native_GetOptionFlags);
	CreateNative("NativeVotes_Cancel", Native_Cancel);
	CreateNative("NativeVotes_SetResultCallback", Native_SetResultCallback);
	CreateNative("NativeVotes_CheckVoteDelay", Native_CheckVoteDelay);
	CreateNative("NativeVotes_IsClientInVotePool", Native_IsClientInVotePool);
	CreateNative("NativeVotes_RedrawClientVote", Native_RedrawClientVote);
	CreateNative("NativeVotes_GetType", Native_GetType);
	CreateNative("NativeVotes_SetTeam", Native_SetTeam);
	CreateNative("NativeVotes_GetTeam", Native_GetTeam);
	CreateNative("NativeVotes_SetInitiator", Native_SetInitiator);
	CreateNative("NativeVotes_GetInitiator", Native_GetInitiator);
	CreateNative("NativeVotes_DisplayPass", Native_DisplayPass);
	CreateNative("NativeVotes_DisplayPassCustomToOne", Native_DisplayPassCustomToOne);
	CreateNative("NativeVotes_DisplayPassEx", Native_DisplayPassEx);
	CreateNative("NativeVotes_DisplayFail", Native_DisplayFail);
	//CreateNative("NativeVotes_RegisterVoteManager", Native_RegisterVoteManager);
	CreateNative("NativeVotes_DisplayCallVoteFail", Native_DisplayCallVoteFail);
	CreateNative("NativeVotes_RedrawVoteTitle", Native_RedrawVoteTitle);
	CreateNative("NativeVotes_RedrawVoteItem", Native_RedrawVoteItem);
	
	RegPluginLibrary("nativevotes");
	
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("core.phrases");
	LoadTranslations("nativevotes.phrases.txt");
	
	CreateConVar("nativevotes_version", VERSION, "NativeVotes API version", FCVAR_DONTRECORD | FCVAR_NOTIFY);

	g_Cvar_VoteHintbox = CreateConVar("nativevotes_progress_hintbox", "0", "Show current vote progress in a hint box", FCVAR_NONE, true, 0.0, true, 1.0);
	g_Cvar_VoteChat = CreateConVar("nativevotes_progress_chat", "0", "Show current vote progress as chat messages", FCVAR_NONE, true, 0.0, true, 1.0);
	g_Cvar_VoteConsole = CreateConVar("nativevotes_progress_console", "0", "Show current vote progress as console messages", FCVAR_NONE, true, 0.0, true, 1.0);
	g_Cvar_VoteClientConsole = CreateConVar("nativevotes_progress_client_console", "0", "Show current vote progress as console messages to clients", FCVAR_NONE, true, 0.0, true, 1.0);
	g_Cvar_VoteDelay = CreateConVar("nativevotes_vote_delay", "30", "Sets the recommended time in between public votes", FCVAR_NONE, true, 0.0, true);
	
	HookConVarChange(g_Cvar_VoteDelay, OnVoteDelayChange);

	AddCommandListener(Command_Vote, "vote"); // TF2, CS:GO
	//AddCommandListener(Command_Vote, "Vote"); // L4D, L4D2
	
	// This is basically dead as of the 2014-10-15 update
	//g_Forward_OnCallVoteSetup = CreateForward(ET_Event, Param_Cell, Param_Array);
	//g_Forward_OnCallVote = CreateForward(ET_Event, Param_Cell, Param_Cell, Param_String, Param_Cell);
	
	//AddCommandListener(Command_CallVote, "callvote"); // All games
	
	g_hVotes = CreateArray(_, Game_GetMaxItems());
	
	AutoExecConfig(true, "nativevotes");
}

public OnClientDisconnect_Post(client)
{
	if (!Internal_IsVoteInProgress() || !Internal_IsClientInVotePool(client))
	{
		return;
	}

	new item = g_ClientVotes[client];
	if (item >= VOTE_PENDING)
	{
		if (item > VOTE_PENDING)
		{
			SetArrayCell(g_hVotes, item, GetArrayCell(g_hVotes, item) - 1);
		}
		
		g_ClientVotes[client] = VOTE_NOT_VOTING;
		
		g_TotalClients--;
		
		Game_UpdateClientCount(g_TotalClients);
		Game_UpdateVoteCounts(g_hVotes, g_TotalClients);
		BuildVoteLeaders();
		DrawHintProgress();
		
		if (item == VOTE_PENDING)
		{
			DecrementPlayerCount();
		}
	}
}

/*
public Action:Command_CallVote(client, const String:command[], argc)
{
	if (Internal_IsVoteInProgress())
	{
		return Plugin_Handled;
	}
	
	new Action:result = Plugin_Continue;
	
	switch (argc)
	{
		case 0:
		{
			new NativeVotesType:voteTypes[MAX_VOTE_ISSUES];
			
			Call_StartForward(g_Forward_OnCallVoteSetup);
			Call_PushCell(client);
			Call_PushArrayEx(voteTypes, MAX_VOTE_ISSUES, SM_PARAM_COPYBACK);
			Call_Finish(result);
			
			switch (result)
			{
				case Plugin_Continue:
				{
					return Plugin_Continue;
				}
				
				case Plugin_Handled:
				{
					// Make sure the vote list is empty
					voteTypes[0] = NativeVotesType_None;
				}
				
				case Plugin_Stop:
				{
					return Plugin_Stop;
				}
			}
			
			// Plugin_Changed goes here without any special handling
			Game_DisplayVoteSetup(client, voteTypes);
		}
		
		default:
		{
			decl String:voteString[VOTE_STRING_SIZE];
			GetCmdArg(1, voteString, VOTE_STRING_SIZE);
			
			new String:argument[64];
			
			new NativeVotesType:voteType = TF2CSGO_VoteStringToVoteType(voteString);
			
			new target = 0;
			
			if (voteType == NativeVotesType_Kick)
			{
				decl String:param1[20];
				GetCmdArg(2, param1, sizeof(param1));
				
				decl String:params[2][20];
				ExplodeString(param1, " ", params, sizeof(params), sizeof(params[]));
				
				target = StringToInt(params[0]);
				
				if (!IsValidEntity(target))
				{
					return Plugin_Continue;
				}
				
				if (StrEqual(params[1], "cheating", false))
				{
					voteType = NativeVotesType_KickCheating;
				}
				else if (StrEqual(params[1], "idle", false))
				{
					voteType = NativeVotesType_KickIdle;
				}
				else if (StrEqual(params[1], "scamming", false))
				{
					voteType = NativeVotesType_KickScamming;
				}
				
				GetClientName(GetClientOfUserId(target), argument, sizeof(argument));
			}
			else
			{
				GetCmdArg(2, argument, sizeof(argument));
			}
			
			Call_StartForward(g_Forward_OnCallVote);
			Call_PushCell(client);
			Call_PushCell(voteType);
			Call_PushString(argument);
			Call_PushCell(target);
			Call_Finish(result);
			// Don't process result here as the return line below will handle it
		}
		
	}
	
	// Default to continue if we're not processing things
	return result;

}
*/
public OnVoteDelayChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	/* See if the new vote delay isn't something we need to account for */
	if (GetConVarInt(convar) < 1)
	{
		g_NextVote = 0;
		return;
	}
	
	/* If there was never a last vote, ignore this change */
	if (g_NextVote <= 0)
	{
		return;
	}
	
	/* Subtract the original value, then add the new one. */
	g_NextVote -= StringToInt(oldValue);
	g_NextVote += StringToInt(newValue);
}

public OnMapEnd()
{
	if (g_hCurVote != INVALID_HANDLE)
	{
		// Cancel the ongoing vote, but don't close the handle, as the other plugins may still re-use it
		CancelVoting();
		//OnVoteCancel(g_hCurVote, VoteCancel_Generic);
		g_hCurVote = INVALID_HANDLE;
	}
	
	if (g_hDisplayTimer != INVALID_HANDLE)
	{
		g_hDisplayTimer = INVALID_HANDLE;
	}

	g_hVoteTimer = INVALID_HANDLE;
}

public Action:Command_Vote(client, const String:command[], argc)
{
	// If we're not running a vote, return the vote control back to the server
	if (!Internal_IsVoteInProgress())
	{
		return Plugin_Continue;
	}
	
	decl String:option[32];
	GetCmdArg(1, option, sizeof(option));
	
	new item = Game_ParseVote(option);
	
	if (item == NATIVEVOTES_VOTE_INVALID)
	{
		return Plugin_Handled;
	}
	
	OnVoteSelect(g_hCurVote, client, item);

	return Plugin_Handled;
}

OnVoteSelect(Handle:vote, client, item)
{
	if (Internal_IsVoteInProgress() && g_ClientVotes[client] == VOTE_PENDING)
	{
		/* Check by our item count, NOT the vote array size */
		if (item < g_Items)
		{
			Game_ClientSelectedItem(vote, client, item);
			
			g_ClientVotes[client] = item;
			SetArrayCell(g_hVotes, item, GetArrayCell(g_hVotes, item) + 1);
			g_NumVotes++;
			
			Game_UpdateVoteCounts(g_hVotes, g_TotalClients);
			
			if (GetConVarBool(g_Cvar_VoteChat) || GetConVarBool(g_Cvar_VoteConsole) || GetConVarBool(g_Cvar_VoteClientConsole))
			{
				decl String:choice[128];
				decl String:name[MAX_NAME_LENGTH];
				Data_GetItemDisplay(vote, item, choice, sizeof(choice));
				
				GetClientName(client, name, MAX_NAME_LENGTH);
				
				if (GetConVarBool(g_Cvar_VoteConsole))
				{
					PrintToServer("[%s] %T", LOGTAG, "Voted For", LANG_SERVER, name, choice);
				}
				
				if (GetConVarBool(g_Cvar_VoteChat) || GetConVarBool(g_Cvar_VoteClientConsole))
				{
					decl String:phrase[30];
					
					if (g_bRevoting[client])
					{
						strcopy(phrase, sizeof(phrase), "Changed Vote");
					}
					else
					{
						strcopy(phrase, sizeof(phrase), "Voted For");
					}
					
					if (GetConVarBool(g_Cvar_VoteChat))
					{
						PrintToChatAll("[%s] %t", LOGTAG, phrase, name, choice);
					}
					
					if (GetConVarBool(g_Cvar_VoteClientConsole))
					{
						for (new i = 1; i <= MaxClients; i++)
						{
							if (IsClientInGame(i) && !IsFakeClient(i))
							{
								PrintToConsole(i, "[%s] %t", LOGTAG, phrase, name, choice);
							}
						}
					}
				}
			}
			
			BuildVoteLeaders();
			DrawHintProgress();
			
			OnSelect(g_hCurVote, client, item);
			DecrementPlayerCount();
		}
	}
}

//MenuAction_Select
OnSelect(Handle:vote, client, item)
{
	new MenuAction:actions = Data_GetActions(vote);
	if (actions & MenuAction_Select)
	{
		DoAction(vote, MenuAction_Select, client, item);
	}
}

//MenuAction_End
OnEnd(Handle:vote, item)
{
	// Always called
	DoAction(vote, MenuAction_End, item, 0);
}


stock OnVoteEnd(Handle:vote, item)
{
	// Always called
	DoAction(vote, MenuAction_VoteEnd, item, 0);
}

OnVoteStart(Handle:vote)
{
	// Fire both Start and VoteStart in the other plugin.
	
	new MenuAction:actions = Data_GetActions(vote);
	if (actions & MenuAction_Start)
	{
		DoAction(vote, MenuAction_Start, 0, 0);
	}
	
	// Always called
	DoAction(vote, MenuAction_VoteStart, 0, 0);
}

OnVoteCancel(Handle:vote, reason)
{
	// Always called
	DoAction(vote, MenuAction_VoteCancel, reason, 0);
}

DoAction(Handle:vote, MenuAction:action, param1, param2, Action:def_res = Plugin_Continue)
{
	new Action:res = def_res;
	
	new Handle:handler = Data_GetHandler(vote);
	Call_StartForward(handler);
	Call_PushCell(vote);
	Call_PushCell(action);
	Call_PushCell(param1);
	Call_PushCell(param2);
	Call_Finish(res);
	return _:res;
}

OnVoteResults(Handle:vote, const votes[][], num_votes, item_count, const client_list[][], num_clients)
{
	new Handle:resultsHandler = Data_GetResultCallback(vote);
	
	if (resultsHandler == INVALID_HANDLE || !GetForwardFunctionCount(resultsHandler))
	{
		/* Call MenuAction_VoteEnd instead.  See if there are any extra winners. */
		new num_items = 1;
		for (new i = 1; i < num_votes; i++)
		{
			if (votes[i][VOTEINFO_ITEM_VOTES] != votes[0][VOTEINFO_ITEM_VOTES])
			{
				break;
			}
			num_items++;
		}
		
		/* See if we need to pick a random winner. */
		new winning_item;
		if (num_items > 1)
		{
			/* Yes, we do */
			winning_item = GetRandomInt(0, num_items - 1);
			winning_item = votes[winning_item][VOTEINFO_ITEM_INDEX];
		}
		else 
		{
			/* No, take the first */
			winning_item = votes[0][VOTEINFO_ITEM_INDEX];
		}
		
		new winning_votes = votes[0][VOTEINFO_ITEM_VOTES];
		
		DoAction(vote, MenuAction_VoteEnd, winning_item, (num_votes << 16) | (winning_votes & 0xFFFF));
	}
	else
	{
		// This code is quite different than its C++ version, as we're reversing the logic previously done
		
		new client_indexes[num_clients];
		new client_items[num_clients];
		new vote_items[item_count];
		new vote_votes[item_count];
		
		/* First array */
		for (new i = 0; i < item_count; i++)
		{
			vote_items[i] = votes[i][VOTEINFO_ITEM_INDEX];
			vote_votes[i] = votes[i][VOTEINFO_ITEM_VOTES];
		}
		
		/* Second array */
		for (new i = 0; i < num_clients; i++)
		{
			client_indexes[i] = client_list[i][VOTEINFO_CLIENT_INDEX];
			client_items[i] = client_list[i][VOTEINFO_CLIENT_ITEM];
		}
		
		Call_StartForward(resultsHandler);
		Call_PushCell(vote);
		Call_PushCell(num_votes);
		Call_PushCell(num_clients);
		Call_PushArray(client_indexes, num_clients);
		Call_PushArray(client_items, num_clients);
		Call_PushCell(item_count);
		Call_PushArray(vote_items, item_count);
		Call_PushArray(vote_votes, item_count);
		Call_Finish();
	}
}

/*
VoteEnd(Handle:vote)
{
	if (g_NumVotes == 0)
	{
		// Fire VoteCancel in the other plugin
		OnVoteCancel(vote, VoteCancel_NoVotes);
	}
	else
	{
		new num_items;
		new num_votes;
		
		new slots = Game_GetMaxItems();
		new votes[slots][2];
		
		Internal_GetResults(votes, slots);
		
		if (!SendResultCallback(vote, num_votes, num_items, votes))
		{
			new Handle:handler = Data_GetHandler(g_hCurVote);
			
			Call_StartForward(handler);
			Call_PushCell(g_CurVote);
			Call_PushCell(MenuAction_VoteEnd);
			Call_PushCell(votes[0][VOTEINFO_ITEM_INDEX]);
			Call_PushCell(0);
			Call_Finish();
		}
	}
	
}

bool:SendResultCallback(Handle:vote, num_votes, num_items, const votes[][])
{
	new Handle:voteResults = Data_GetResultCallback(g_CurVote);
	if (GetForwardFunctionCount(voteResults) == 0)
	{
		return false;
	}
	
	// This block is present because we can't pass 2D arrays to other plugins' functions
	new item_indexes[];
	new item_votes[];
	
	for (int i = 0, i < num_items; i++)
	{
		item_indexes[i] = votes[i][VOTEINFO_ITEM_INDEX];
		item_votes[i] = votes[i][VOTEINFO_ITEM_VOTES];
	}
	
	// Client block
	new client_indexes[MaxClients];
	new client_votes[MaxClients];
	
	new num_clients;
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_ClientVotes[i] > VOTE_PENDING)
		{
			client_indexes[num_clients] = i;
			client_votes[num_clients] = g_ClientVotes[i];
			num_clients++;
		}
	}
	
	Call_StartForward(voteResults);
	Call_PushCell(_:vote);
	Call_PushCell(num_votes);
	Call_PushCell(num_clients);
	Call_PushArray(client_indexes, num_clients);
	Call_PushArray(client_votes, num_clients);
	Call_PushCell(num_items);
	Call_PushArray(item_indexes, num_items);
	Call_PushArray(item_votes, num_items);
	Call_Finish();
	
	return true;
}
*/

DrawHintProgress()
{
	if (!GetConVarBool(g_Cvar_VoteHintbox))
	{
		return;
	}
	
	new Float:timeRemaining = (g_fStartTime + g_VoteTime) - GetGameTime();
	
	if (timeRemaining < 0.0)
	{
		timeRemaining = 0.0;
	}
	
	new iTimeRemaining = RoundFloat(timeRemaining);

	PrintHintTextToAll("%t%s", "Vote Count", g_NumVotes, g_TotalClients, iTimeRemaining, g_LeaderList);
}

BuildVoteLeaders()
{
	if (g_NumVotes == 0 || !GetConVarBool(g_Cvar_VoteHintbox))
	{
		return;
	}
	
	// Since we can't have structs, we get "struct" with this instead
	
	new slots = Game_GetMaxItems();
	new votes[slots][2];
	
	new num_items = Internal_GetResults(votes);
	
	/* Take the top 3 (if applicable) and draw them */
	g_LeaderList[0] = '\0';
	
	for (new i = 0; i < num_items && i < 3; i++)
	{
		new cur_item = votes[i][VOTEINFO_ITEM_INDEX];
		decl String:choice[256];
		Data_GetItemDisplay(g_hCurVote, cur_item, choice, sizeof(choice));
		Format(g_LeaderList, sizeof(g_LeaderList), "%s\n%i. %s: (%i)", g_LeaderList, i+1, choice, votes[i][VOTEINFO_ITEM_VOTES]);
	}
	
}

public SortVoteItems(a[], b[], const array[][], Handle:hndl)
{
	if (b[VOTEINFO_ITEM_VOTES] == a[VOTEINFO_ITEM_VOTES])
	{
		return 0;
	}
	else if (b[VOTEINFO_ITEM_VOTES] > a[VOTEINFO_ITEM_VOTES])
	{
		return 1;
	}
	else
	{
		return -1;
	}
}

DecrementPlayerCount()
{
	g_Clients--;
	
	// The vote is running and we have no clients left, so end the vote.
	if (g_bStarted && g_Clients == 0)
	{
		EndVoting();
	}
	
}


EndVoting()
{
	new voteDelay = GetConVarInt(g_Cvar_VoteDelay);
	if (voteDelay < 1)
	{
		g_NextVote = 0;
	}
	else
	{
		g_NextVote = GetTime() + voteDelay;
	}
	
	if (g_hDisplayTimer != INVALID_HANDLE)
	{
		KillTimer(g_hDisplayTimer);
		g_hDisplayTimer = INVALID_HANDLE;
	}
	
	if (g_bCancelled)
	{
		/* If we were cancelled, don't bother tabulating anything.
		 * Reset just in case someone tries to redraw, which means
		 * we need to save our states.
		 */
		new Handle:vote = g_hCurVote;
		Internal_Reset();
		OnVoteCancel(vote, VoteCancel_Generic);
		OnEnd(vote, MenuEnd_VotingCancelled);
		return;
	}
	
	new slots = Game_GetMaxItems();
	new votes[slots][2];
	new num_votes;
	new num_items = Internal_GetResults(votes, num_votes);
	
	if (!num_votes)
	{
		new Handle:vote = g_hCurVote;
		Internal_Reset();
		OnVoteCancel(vote, VoteCancel_NoVotes);
		OnEnd(vote, MenuEnd_VotingCancelled);
		return;
	}
	
	new client_list[MaxClients][2];
	new num_clients = Internal_GetClients(client_list);
	
	/* Save states, then clear what we've saved.
	 * This makes us re-entrant, which is always the safe way to go.
	 */
	new Handle:vote = g_hCurVote;
	Internal_Reset();
	
	/* Send vote info */
	OnVoteResults(vote, votes, num_votes, num_items, client_list, num_clients);
	OnEnd(vote, MenuEnd_VotingDone);
}

bool:StartVote(Handle:vote, num_clients, clients[], max_time, flags)
{
	if (!InitializeVoting(vote, max_time, flags))
	{
		return false;
	}
	
	/* Due to hibernating servers, we no longer use GameTime, but instead standard timestamps.
	 */

	new voteDelay = GetConVarInt(g_Cvar_VoteDelay);
	if (voteDelay < 1)
	{
		g_NextVote = 0;
	}
	else
	{
		/* This little trick break for infinite votes!
		 * However, we just ignore that since those 1) shouldn't exist and
		 * 2) people must be checking IsVoteInProgress() beforehand anyway.
		 */
		g_NextVote = GetTime() + voteDelay + max_time;
	}
	
	g_fStartTime = GetGameTime();
	g_VoteTime = max_time;
	g_TimeLeft = max_time;
	
	new clientCount = 0;
	
	for (new i = 0; i < num_clients; ++i)
	{
		if (clients[i] < 1 || clients[i] > MaxClients)
		{
			continue;
		}
		
		g_ClientVotes[clients[i]] = VOTE_PENDING;
		clientCount++;
	}
	
	g_Clients = clientCount;
	
	Game_UpdateVoteCounts(g_hVotes, clientCount);
	
	DoClientVote(vote, clients, num_clients);	
	
	StartVoting();
	
	DrawHintProgress();
	
	return true;
}

bool:DoClientVote(Handle:vote, clients[], num_clients)
{
	new totalPlayers = 0;
	new realClients[MaxClients+1];
	
	for (new i = 0; i < num_clients; ++i)
	{
		if (clients[i] < 1 || clients[i] > MaxClients || !IsClientInGame(clients[i]) || IsFakeClient(clients[i]))
		{
			continue;
		}
		
		realClients[totalPlayers++] = clients[i];
	}
	
	if (totalPlayers > 0)
	{
		Game_DisplayVote(vote, realClients, totalPlayers);
		return true;
	}
	else
	{
		return false;
	}
}

bool:InitializeVoting(Handle:vote, time, flags)
{
	if (Internal_IsVoteInProgress())
	{
		return false;
	}
	
	Internal_Reset();
	
	/* Mark all clients as not voting */
	for (new i = 1; i <= MaxClients; ++i)
	{
		g_ClientVotes[i] = VOTE_NOT_VOTING;
		g_bRevoting[i] = false;
	}
	
	g_Items = Data_GetItemCount(vote);
	
	// Clear all items
	for (new i = 0; i < GetArraySize(g_hVotes); ++i)
	{
		SetArrayCell(g_hVotes, i, 0);
	}
	
	g_hCurVote = vote;
	g_VoteTime = time;
	g_VoteFlags = flags;
	
	return true;
}

StartVoting()
{
	if (g_hCurVote == INVALID_HANDLE)
	{
		return;
	}
	
	g_bStarted = true;
	
	OnVoteStart(g_hCurVote);
	
	g_hDisplayTimer = CreateTimer(1.0, DisplayTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	g_TotalClients = g_Clients;

	/* By now we know how many clients were set.
	 * If there are none, we should end IMMEDIATELY.
	 */
	if (g_Clients == 0)
	{
		EndVoting();
		return;
	}
	
	// Kick targets automatically vote no if they're in the pool
	new NativeVotesType:voteType = Data_GetType(g_hCurVote);
	
	switch (voteType)
	{
		case NativeVotesType_Kick, NativeVotesType_KickCheating, NativeVotesType_KickIdle, NativeVotesType_KickScamming:
		{
			new target = Data_GetTarget(g_hCurVote);
			
			if (target > 0 && target <= MaxClients && IsClientConnected(target) && Internal_IsClientInVotePool(target))
			{
				Game_VoteNo(target);
			}
		}
	}
	
	// Initiators always vote yes when they're in the pool.
	if (voteType != NativeVotesType_Custom_Mult && voteType != NativeVotesType_NextLevelMult)
	{
		new initiator = Data_GetInitiator(g_hCurVote);
		
		if (initiator > 0 && initiator <= MaxClients && IsClientConnected(initiator) && Internal_IsClientInVotePool(initiator))
		{
			Game_VoteYes(initiator);
		}
	}
}

public Action:DisplayTimer(Handle:timer, any:data)
{
	DrawHintProgress();
	if (--g_TimeLeft == 0)
	{
		if (g_hDisplayTimer != INVALID_HANDLE)
		{
			g_hDisplayTimer = INVALID_HANDLE;
			EndVoting();
		}
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

Internal_GetResults(votes[][], &num_votes=0)
{
	if (!Internal_IsVoteInProgress())
	{
		return 0;
	}
	
	// Since we can't have structs, we get "struct" with this instead
	new num_items;
	
	num_votes = 0;
	
	for (new i = 0; i < g_Items; i++)
	{
		new voteCount = GetArrayCell(g_hVotes, i);
		if (voteCount > 0)
		{
			votes[num_items][VOTEINFO_ITEM_INDEX] = i;
			votes[num_items][VOTEINFO_ITEM_VOTES] = voteCount;
			num_votes += voteCount;
			num_items++;
		}
	}
	
	/* Sort the item list descending like we promised */
	SortCustom2D(votes, num_items, SortVoteItems);

	return num_items;
}

Internal_GetClients(client_vote[][])
{
	if (!Internal_IsVoteInProgress())
	{
		return 0;
	}
	
	/* Build the client list */
	new num_clients;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_ClientVotes[i] >= VOTE_PENDING)
		{
			client_vote[num_clients][VOTEINFO_CLIENT_INDEX] = i;
			client_vote[num_clients][VOTEINFO_CLIENT_ITEM] = g_ClientVotes[i];
			num_clients++;
		}
	}
	
	return num_clients;
}

Internal_IsCancelling()
{
	return g_bCancelled;
}

stock Internal_GetCurrentVote()
{
	return g_hCurVote;
}

Internal_Reset()
{
	g_Clients = 0;
	g_Items = 0;
	g_bStarted = false;
	g_hCurVote = INVALID_HANDLE;
	g_NumVotes = 0;
	g_bCancelled = false;
	g_LeaderList[0] = '\0';
	g_TotalClients = 0;
	
	if (g_hDisplayTimer != INVALID_HANDLE)
	{
		KillTimer(g_hDisplayTimer);
		g_hDisplayTimer = INVALID_HANDLE;
	}
	
	Game_ResetVote();
}

bool:Internal_IsVoteInProgress()
{
	return (g_hCurVote != INVALID_HANDLE);
}

bool:Internal_IsClientInVotePool(client)
{
	if (client < 1
		|| client > MaxClients
		|| g_hCurVote == INVALID_HANDLE)
	{
		return false;
	}

	return (g_ClientVotes[client] > VOTE_NOT_VOTING);
}

bool:Internal_RedrawToClient(client, bool:revotes)
{
	if (!Internal_IsVoteInProgress() || !Internal_IsClientInVotePool(client))
	{
		return false;
	}
	
	if (g_ClientVotes[client] >= 0)
	{
		if ((g_VoteFlags & VOTEFLAG_NO_REVOTES) || !revotes || g_VoteTime <= VOTE_DELAY_TIME)
		{
			return false;
		}
		
		g_Clients++;
		SetArrayCell(g_hVotes, g_ClientVotes[client], GetArrayCell(g_hVotes, g_ClientVotes[client]) - 1);
		g_ClientVotes[client] = VOTE_PENDING;
		g_bRevoting[client] = true;
		g_NumVotes--;
		Game_UpdateVoteCounts(g_hVotes, g_TotalClients);
	}
	
	// Display the vote fail screen for a few seconds
	//Game_DisplayVoteFail(g_hCurVote, NativeVotesFail_Generic, client);
	
	// No, display a vote pass screen because that's nicer and we can customize it.
	// Note: This isn't inside the earlier if because some players have had issues where the display
	//   doesn't always appear the first time.
	new String:revotePhrase[128];
	Format(revotePhrase, sizeof(revotePhrase), "%T", "NativeVotes Revote", client);
	Game_DisplayVotePassCustom(g_hCurVote, revotePhrase, client);
	
	new Handle:data;
	
	CreateDataTimer(VOTE_DELAY_TIME, RedrawTimer, data, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(data, client);
	WritePackCell(data, _:g_hCurVote);
	
	return true;
}

public Action:RedrawTimer(Handle:timer, Handle:data)
{
	ResetPack(data);
	new client = ReadPackCell(data);
	new Handle:vote = Handle:ReadPackCell(data);
	
	if (Internal_IsVoteInProgress() && !Internal_IsCancelling())
	{
		Game_DisplayVoteToOne(vote, client);
	}
	
	return Plugin_Stop;
}

CancelVoting()
{
	if (g_bCancelled || g_hCurVote == INVALID_HANDLE)
	{
		return;
	}
	
	g_bCancelled = true;
	
	EndVoting();
}


//----------------------------------------------------------------------------
// Natives

public Native_IsVoteTypeSupported(Handle:plugin, numParams)
{
	new NativeVotesType:type = GetNativeCell(1);
	
	return Game_CheckVoteType(type);
}

public Native_Create(Handle:plugin, numParams)
{
	new MenuHandler:handler = GetNativeCell(1);
	new NativeVotesType:voteType = GetNativeCell(2);
	new MenuAction:actions = GetNativeCell(3);
	
	if (handler == INVALID_FUNCTION)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Menuhandler handle %x is invalid", handler);
	}
	
	new Handle:vote;
	if (Game_CheckVoteType(voteType))
	{
		vote = Data_CreateVote(voteType, actions);
	}
	else
	{
		return _:INVALID_HANDLE;
	}
	
	if (voteType != NativeVotesType_NextLevelMult && voteType != NativeVotesType_Custom_Mult)
	{
		Data_AddItem(vote, "yes", "Yes");
		Data_AddItem(vote, "no", "No");
	}
	
	new Handle:menuForward = Data_GetHandler(vote);
	
	AddToForward(menuForward, plugin, handler);
	
	return _:vote;
}

public Native_Close(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	
	if (vote == INVALID_HANDLE)
	{
		return;
	}
	
	if (g_hCurVote == vote)
	{
		g_hCurVote = INVALID_HANDLE;
		
		if (g_hVoteTimer != INVALID_HANDLE)
		{
			KillTimer(g_hVoteTimer);
			g_hVoteTimer = INVALID_HANDLE;
		}
	}
	
	Data_CloseVote(vote);
}

// native bool:NativeVotes_Display(Handle:vote, clients[], numClients, time);
public Native_Display(Handle:plugin, numParams)
{
	if (Internal_IsVoteInProgress())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "A vote is already in progress");
	}
	
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return false;
	}
	
	new count = GetNativeCell(3);
	new clients[count];
	GetNativeArray(2, clients, count);
	
	new flags = 0;
	
	if (numParams >= 5)
	{
		flags = GetNativeCell(5);
	}
	
	if (!StartVote(vote, count, clients, GetNativeCell(4), flags))
	{
		return 0;
	}
	
	return 1;
	
}

public Native_AddItem(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return false;
	}

	new NativeVotesType:voteType = Data_GetType(vote);
	
	if (voteType != NativeVotesType_NextLevelMult && voteType != NativeVotesType_Custom_Mult)
	{
		return false;
	}

	decl String:info[256];
	decl String:display[256];
	GetNativeString(2, info, sizeof(info));
	GetNativeString(3, display, sizeof(display));
	
	return Data_AddItem(vote, info, display);
}

public Native_InsertItem(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return false;
	}

	new NativeVotesType:voteType = Data_GetType(vote);
	
	if (voteType != NativeVotesType_NextLevelMult && voteType != NativeVotesType_Custom_Mult)
	{
		return false;
	}

	new position = GetNativeCell(2);
	
	if (position < 0)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Vote index can't be negative: %d", position);
		return false;
	}
	
	decl String:info[256];
	decl String:display[256];
	GetNativeString(3, info, sizeof(info));
	GetNativeString(4, display, sizeof(display));
	
	return Data_InsertItem(vote, position, info, display);
	
}

public Native_RemoveItem(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return false;
	}
	
	new NativeVotesType:voteType = Data_GetType(vote);
	
	if (voteType != NativeVotesType_NextLevelMult && voteType != NativeVotesType_Custom_Mult)
	{
		return false;
	}

	new position = GetNativeCell(2);
	
	return Data_RemoveItem(vote, position);
}

public Native_RemoveAllItems(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	Data_RemoveAllItems(vote);
}

public Native_GetItem(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new position = GetNativeCell(2);
	
	new infoLength = GetNativeCell(4);
	new String:info[infoLength];
	Data_GetItemInfo(vote, position, info, infoLength);
	SetNativeString(3, info, infoLength);
	
	if (numParams >= 6)
	{
		new displayLength = GetNativeCell(6);
		if (displayLength > 0)
		{
			new String:display[displayLength];
			Data_GetItemDisplay(vote, position, display, displayLength);
			SetNativeString(5, display, displayLength);
		}
	}
}

public Native_GetItemCount(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return 0;
	}
	
	return Data_GetItemCount(vote);
}

public Native_GetDetails(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new len = GetNativeCell(3);

	decl String:details[len];
	
	Data_GetDetails(vote, details, len);
	
	SetNativeString(2, details, len);
}

public Native_SetDetails(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new len;
	GetNativeStringLength(2, len);
	
	decl String:details[len+1];
	GetNativeString(2, details, len+1);
	
	Data_SetDetails(vote, details);
}

public Native_GetTitle(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new len = GetNativeCell(3);

	decl String:title[len];
	
	Data_GetTitle(vote, title, len);
	
	SetNativeString(2, title, len);
}

public Native_SetTitle(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new len;
	GetNativeStringLength(2, len);
	
	decl String:details[len+1];
	GetNativeString(2, details, len+1);
	
	Data_SetTitle(vote, details);
}

public Native_IsVoteInProgress(Handle:plugin, numParams)
{
	return Internal_IsVoteInProgress();
}

public Native_GetMaxItems(Handle:plugin, numParams)
{
	return Game_GetMaxItems();
}

public Native_GetOptionFlags(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	//TODO
}

public Native_SetOptionFlags(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	//TODO
}

public Native_Cancel(Handle:plugin, numParams)
{
	if (!Internal_IsVoteInProgress())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "No vote is in progress");
		return;
	}
	
	CancelVoting();
}

public Native_SetResultCallback(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new NativeVotes_VoteHandler:function = GetNativeCell(2);
	
	if (function == INVALID_FUNCTION)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes_VoteHandler function %x is invalid", function);
		return;
	}
	
	new Handle:voteResults = Data_GetResultCallback(vote);
	
	RemoveAllFromForward(voteResults, plugin);
	if (!AddToForward(voteResults, plugin, function))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes_VoteHandler function %x is invalid", function);
	}
}

public Native_CheckVoteDelay(Handle:plugin, numParams)
{
	new curTime = GetTime();
	if (g_NextVote <= curTime)
	{
		return 0;
	}
	
	return (g_NextVote - curTime);
}

public Native_IsClientInVotePool(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (client <= 0 || client > MaxClients)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}
	
	if (!Internal_IsVoteInProgress())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "No vote is in progress");
		return false;
	}
	
	return Internal_IsClientInVotePool(client);
}

public Native_RedrawClientVote(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	if (client < 1 || client > MaxClients || !IsClientConnected(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index %d", client);
		return false;
	}
	
	if (!Internal_IsVoteInProgress())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "No vote is in progress");
		return false;
	}
	
	if (!Internal_IsClientInVotePool(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client is not in the voting pool");
		return false;
	}
	
	new bool:revote = true;
	if (numParams >= 2 && !bool:GetNativeCell(2))
	{
		revote = false;
	}
	
	return Internal_RedrawToClient(client, revote);
}

public Native_GetType(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return 0;
	}
	
	return _:Data_GetType(vote);
}

public Native_GetTeam(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return NATIVEVOTES_ALL_TEAMS;
	}
	
	return Data_GetTeam(vote);
	
}

public Native_SetTeam(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new team = GetNativeCell(2);
	
	// Teams are numbered starting with 0
	// Currently 4 is the maximum (Unassigned, Spectator, Team 1, Team 2)
	if (team >= GetTeamCount())
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Team %d is invalid", team);
		return;
	}
	
	if (g_EngineVersion == Engine_TF2 && team == NATIVEVOTES_ALL_TEAMS)
	{
		team = NATIVEVOTES_TF2_ALL_TEAMS;
	}
	
	Data_SetTeam(vote, team);
}

public Native_GetInitiator(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return NATIVEVOTES_SERVER_INDEX;
	}
	
	return Data_GetInitiator(vote);
}

public Native_SetInitiator(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new initiator = GetNativeCell(2);
	Data_SetInitiator(vote, initiator);
}

public Native_DisplayPass(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}

	new len;
	GetNativeStringLength(2, len);
	new String:winner[len+1];
	GetNativeString(2, winner, len+1);

	Game_DisplayVotePass(vote, winner);
}

public Native_DisplayPassCustomToOne(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}

	new client = GetNativeCell(2);
	
	new String:translation[TRANSLATION_LENGTH];
	
	FormatNativeString(0, 3, 4, TRANSLATION_LENGTH, _, translation);

	Game_DisplayVotePassCustom(vote, translation, client);
}

public Native_DisplayPassEx(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new NativeVotesPassType:passType = NativeVotesPassType:GetNativeCell(2);
	
	if (!Game_CheckVotePassType(passType))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid vote pass type: %d", passType);
	}

	new len;
	GetNativeStringLength(3, len);
	new String:winner[len+1];
	GetNativeString(3, winner, len+1);

	Game_DisplayVotePassEx(vote, passType, winner);
}

public Native_DisplayFail(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new NativeVotesFailType:reason = NativeVotesFailType:GetNativeCell(2);
	
	Game_DisplayVoteFail(vote, reason);
}

public Native_GetTarget(Handle:plugin,  numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return 0;
	}
	
	return Data_GetTarget(vote);
}

public Native_GetTargetSteam(Handle:plugin, numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new size = GetNativeCell(3);
	decl String:steamId[size];
	GetNativeString(2, steamId, size);
	
	Data_GetTargetSteam(vote, steamId, size);
}

public Native_SetTarget(Handle:plugin,  numParams)
{
	new Handle:vote = GetNativeCell(1);
	if (vote == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes handle %x is invalid", vote);
		return;
	}
	
	new client = GetNativeCell(2);
	
	if (client <= 0 || client > MaxClients || !IsClientConnected(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client index %d is invalid", client);
		return;
	}
	
	if (!IsClientConnected(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Client %d is not connected", client);
		return;
	}
	
	new userid = GetClientUserId(client);

	Data_SetTarget(vote, userid);
	
	decl String:steamId[19];
	GetClientAuthString(client, steamId, sizeof(steamId));
	
	Data_SetTargetSteam(vote, steamId);

	new bool:changeDetails = GetNativeCell(3);
	if (changeDetails)
	{
		decl String:name[MAX_NAME_LENGTH];
		if (client > 0)
		{
			GetClientName(client, name, MAX_NAME_LENGTH);
			Data_SetDetails(vote, name);
		}
	}
}

public Native_RegisterVoteManager(Handle:plugin, numParams)
{
	ThrowNativeError(SP_ERROR_NATIVE, "Vote Manager not yet implemented");
}

public Native_DisplayCallVoteFail(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	
	new NativeVotesCallFailType:reason = NativeVotesCallFailType:GetNativeCell(2);
	
	new time = GetNativeCell(3);
	
	Game_DisplayCallVoteFail(client, reason, time);
}

public Native_RedrawVoteTitle(Handle:plugin, numParams)
{
	if (!g_curDisplayClient)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "You can only call this once from a MenuAction_Display callback");
	}
	
	new NativeVotesType:voteType = Data_GetType(g_hCurVote);
	
	if (voteType != NativeVotesType_Custom_Mult && voteType != NativeVotesType_Custom_YesNo)
	{
		return _:Plugin_Continue;
	}
	
	GetNativeString(1, g_newMenuTitle, TRANSLATION_LENGTH);
	return _:Plugin_Changed;
}

public Native_RedrawVoteItem(Handle:plugin, numParams)
{
	if (!g_curItemClient)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "You can only call this once from a MenuAction_DisplayItem callback");
	}
	
	if (Game_GetMaxItems() == L4DL4D2_COUNT)
	{
		return _:Plugin_Continue;
	}
	
	GetNativeString(1, g_newMenuItem, TRANSLATION_LENGTH);
	return _:Plugin_Changed;
}

//----------------------------------------------------------------------------
// Data functions

NativeVotesPassType:VoteTypeToVotePass(NativeVotesType:voteType)
{
	new NativeVotesPassType:passType = NativeVotesPass_None;
	
	switch(voteType)
	{
		case NativeVotesType_Custom_YesNo, NativeVotesType_Custom_Mult:
		{
			passType = NativeVotesPass_Custom;
		}
		
		case NativeVotesType_ChgCampaign:
		{
			passType = NativeVotesPass_ChgCampaign;
		}
		
		case NativeVotesType_ChgDifficulty:
		{
			passType = NativeVotesPass_ChgDifficulty;
		}
		
		case NativeVotesType_ReturnToLobby:
		{
			passType = NativeVotesPass_ReturnToLobby;
		}
		
		case NativeVotesType_AlltalkOn:
		{
			passType = NativeVotesPass_AlltalkOn;
		}
		
		case NativeVotesType_AlltalkOff:
		{
			passType = NativeVotesPass_AlltalkOff;
		}
		
		case NativeVotesType_Restart:
		{
			passType = NativeVotesPass_Restart;
		}
		
		case NativeVotesType_Kick, NativeVotesType_KickIdle, NativeVotesType_KickScamming, NativeVotesType_KickCheating:
		{
			passType = NativeVotesPass_Kick;
		}
		
		case NativeVotesType_ChgLevel:
		{
			passType = NativeVotesPass_ChgLevel;
		}
		
		case NativeVotesType_NextLevel, NativeVotesType_NextLevelMult:
		{
			passType = NativeVotesPass_NextLevel;
		}
		
		case NativeVotesType_ScrambleNow, NativeVotesType_ScrambleEnd:
		{
			passType = NativeVotesPass_Scramble;
		}
		
		case NativeVotesType_ChgMission:
		{
			passType = NativeVotesPass_ChgMission;
		}
		
		case NativeVotesType_SwapTeams:
		{
			passType = NativeVotesPass_SwapTeams;
		}
		
		case NativeVotesType_Surrender:
		{
			passType = NativeVotesPass_Surrender;
		}
		
		case NativeVotesType_Rematch:
		{
			passType = NativeVotesPass_Rematch;
		}
		
		case NativeVotesType_Continue:
		{
			passType = NativeVotesPass_Continue;
		}
		
		case NativeVotesType_StartRound:
		{
			passType = NativeVotesPass_StartRound;
		}
		
		case NativeVotesType_Eternaween:
		{
			passType = NativeVotesPass_Eternaween;
		}
		
		case NativeVotesType_AutoBalanceOn:
		{
			passType = NativeVotesPass_AutoBalanceOn;
		}
		
		case NativeVotesType_AutoBalanceOff:
		{
			passType = NativeVotesPass_AutoBalanceOff;
		}
		
		case NativeVotesType_ClassLimitsOn:
		{
			passType = NativeVotesPass_ClassLimitsOn;
		}
		
		case NativeVotesType_ClassLimitsOff:
		{
			passType = NativeVotesPass_ClassLimitsOff;
		}
		
		default:
		{
			passType = NativeVotesPass_Custom;
		}
	}
	
	return passType;
}

stock GetEngineVersionName(EngineVersion:version, String:printName[], maxlength)
{
	switch (version)
	{
		case Engine_Unknown:
		{
			strcopy(printName, maxlength, "Unknown");
		}
		
		case Engine_Original:				
		{
			strcopy(printName, maxlength, "Original");
		}
		
		case Engine_SourceSDK2006:
		{
			strcopy(printName, maxlength, "Source SDK 2006");
		}
		
		case Engine_SourceSDK2007:
		{
			strcopy(printName, maxlength, "Source SDK 2007");
		}
		
		case Engine_Left4Dead:
		{
			strcopy(printName, maxlength, "Left 4 Dead ");
		}
		
		case Engine_DarkMessiah:
		{
			strcopy(printName, maxlength, "Dark Messiah");
		}
		
		case Engine_Left4Dead2:
		{
			strcopy(printName, maxlength, "Left 4 Dead 2");
		}
		
		case Engine_AlienSwarm:
		{
			strcopy(printName, maxlength, "Alien Swarm");
		}
		
		case Engine_BloodyGoodTime:
		{
			strcopy(printName, maxlength, "Bloody Good Time");
		}
		
		case Engine_EYE:
		{
			strcopy(printName, maxlength, "E.Y.E. Divine Cybermancy");
		}
		
		case Engine_Portal2:
		{
			strcopy(printName, maxlength, "Portal 2");
		}
		
		case Engine_CSGO:
		{
			strcopy(printName, maxlength, "Counter-Strike: Global Offensive");
		}
		
		case Engine_CSS:
		{
			strcopy(printName, maxlength, "Counter-Strike: Source");
		}
		
		case Engine_DOTA:
		{
			strcopy(printName, maxlength, "DOTA 2");
		}
		
		case Engine_HL2DM:
		{
			strcopy(printName, maxlength, "Half-Life 2: Deathmatch");
		}
		
		case Engine_DODS:
		{
			strcopy(printName, maxlength, "Day of Defeat: Source");
		}
		
		case Engine_TF2:
		{
			strcopy(printName, maxlength, "Team Fortress 2");
		}
		
		case Engine_NuclearDawn:
		{
			strcopy(printName, maxlength, "Nuclear Dawn");
		}
		
		default:
		{
			strcopy(printName, maxlength, "Not listed");
		}
	}
}