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
#if defined _nativevotes_game_included
 #endinput
#endif

#define _nativevotes_game_included

#include <sourcemod>

#define L4DL4D2_COUNT						2
#define TF2CSGO_COUNT						5

//----------------------------------------------------------------------------
// Translation strings

//----------------------------------------------------------------------------
// L4D/L4D2

#define L4DL4D2_VOTE_YES_STRING				"Yes"
#define L4DL4D2_VOTE_NO_STRING				"No"

#define L4D_VOTE_KICK_START					"#L4D_vote_kick_player"
#define L4D_VOTE_KICK_PASSED				"#L4D_vote_passed_kick_player"

// User vote to restart map.
#define L4D_VOTE_RESTART_START				"#L4D_vote_restart_game"
#define L4D_VOTE_RESTART_PASSED				"#L4D_vote_passed_restart_game"

// User vote to change maps.
#define L4D_VOTE_CHANGECAMPAIGN_START		"#L4D_vote_mission_change"
#define L4D_VOTE_CHANGECAMPAIGN_PASSED		"#L4D_vote_passed_mission_change"
#define L4D_VOTE_CHANGELEVEL_START			"#L4D_vote_chapter_change"
#define L4D_VOTE_CHANGELEVEL_PASSED			"#L4D_vote_passed_chapter_change"

// User vote to return to lobby.
#define L4D_VOTE_RETURNTOLOBBY_START		"#L4D_vote_return_to_lobby"
#define L4D_VOTE_RETURNTOLOBBY_PASSED		"#L4D_vote_passed_return_to_lobby"

// User vote to change difficulty.
#define L4D_VOTE_CHANGEDIFFICULTY_START		"#L4D_vote_change_difficulty"
#define L4D_VOTE_CHANGEDIFFICULTY_PASSED	"#L4D_vote_passed_change_difficulty"

// While not a vote string, it works just as well.
#define L4D_VOTE_CUSTOM						"#L4D_TargetID_Player"

//----------------------------------------------------------------------------
// L4D2

// User vote to change alltalk.
#define L4D2_VOTE_ALLTALK_START				"#L4D_vote_alltalk_change"
#define L4D2_VOTE_ALLTALK_PASSED			"#L4D_vote_passed_alltalk_change"
#define L4D2_VOTE_ALLTALK_ENABLE			"#L4D_vote_alltalk_enable"
#define L4D2_VOTE_ALLTALK_DISABLE			"#L4D_vote_alltalk_disable"

//----------------------------------------------------------------------------
// TF2/CSGO
#define TF2CSGO_VOTE_PREFIX					"option"

#define TF2CSGO_VOTE_STRING_KICK			"Kick"
#define TF2CSGO_VOTE_STRING_RESTART			"RestartGame"
#define TF2CSGO_VOTE_STRING_CHANGELEVEL		"ChangeLevel"
#define TF2CSGO_VOTE_STRING_NEXTLEVEL		"NextLevel"
#define TF2CSGO_VOTE_STRING_SCRAMBLE		"ScrambleTeams"

//----------------------------------------------------------------------------
// TF2

#define TF2_VOTE_STRING_CHANGEMISSION		"ChangeMission"

// User vote to kick user.
#define TF2_VOTE_KICK_IDLE_START			"#TF_vote_kick_player_idle"
#define TF2_VOTE_KICK_SCAMMING_START		"#TF_vote_kick_player_scamming"
#define TF2_VOTE_KICK_CHEATING_START		"#TF_vote_kick_player_cheating"
#define TF2_VOTE_KICK_START					"#TF_vote_kick_player_other"
#define TF2_VOTE_KICK_PASSED				"#TF_vote_passed_kick_player"

// User vote to restart map.
#define TF2_VOTE_RESTART_START				"#TF_vote_restart_game"
#define TF2_VOTE_RESTART_PASSED				"#TF_vote_passed_restart_game"

// User vote to change maps.
#define TF2_VOTE_CHANGELEVEL_START			"#TF_vote_changelevel"
#define TF2_VOTE_CHANGELEVEL_PASSED			"#TF_vote_passed_changelevel"

// User vote to change next level.
#define TF2_VOTE_NEXTLEVEL_SINGLE_START		"#TF_vote_nextlevel"
#define TF2_VOTE_NEXTLEVEL_MULTIPLE_START	"#TF_vote_nextlevel_choices" // Started by server
#define TF2_VOTE_NEXTLEVEL_EXTEND_PASSED	"#TF_vote_passed_nextlevel_extend"
#define TF2_VOTE_NEXTLEVEL_PASSED			"#TF_vote_passed_nextlevel"

// User vote to scramble teams.  Can be immediate or end of round.
#define TF2_VOTE_SCRAMBLE_IMMEDIATE_START	"#TF_vote_scramble_teams"
#define TF2_VOTE_SCRAMBLE_ROUNDEND_START	"#TF_vote_should_scramble_round"
#define TF2_VOTE_SCRAMBLE_PASSED 			"#TF_vote_passed_scramble_teams"

// User vote to change MvM mission
#define TF2_VOTE_CHANGEMISSION_START		"#TF_vote_changechallenge"
#define TF2_VOTE_CHANGEMISSION_PASSED		"#TF_vote_passed_changechallenge"

// User vote for eternaween
#define TF2_VOTE_ETERNAWEEN_START			"#TF_vote_eternaween"
#define TF2_VOTE_ETERNAWEEN_PASSED			"#TF_vote_passed_eternaween"

// User vote to start round
#define TF2_VOTE_ROUND_START				"#TF_vote_td_start_round"
#define TF2_VOTE_ROUND_PASSED				"#TF_vote_passed_td_start_round"

// User vote to enable autobalance
#define TF2_VOTE_AUTOBALANCE_ENABLE_START	"#TF_vote_autobalance_enable"
#define TF2_VOTE_AUTOBALANCE_ENABLE_PASSED	"#TF_vote_passed_autobalance_enable"

// User vote to disable autobalance
#define TF2_VOTE_AUTOBALANCE_DISABLE_START	"#TF_vote_autobalance_disable"
#define TF2_VOTE_AUTOBALANCE_DISABLE_PASSED	"#TF_vote_passed_autobalance_disable"

// User vote to enable classlimits
#define TF2_VOTE_CLASSLIMITS_ENABLE_START	"#TF_vote_classlimits_enable"
#define TF2_VOTE_CLASSLIMITS_ENABLE_PASSED	"#TF_vote_passed_classlimits_enable"

// User vote to disable classlimits
#define TF2_VOTE_CLASSLIMITS_DISABLE_START	"#TF_vote_classlimits_disable"
#define TF2_VOTE_CLASSLIMITS_DISABLE_PASSED	"#TF_vote_passed_classlimits_disable"

// While not a vote string, it works just as well.
#define TF2_VOTE_CUSTOM						"#TF_playerid_noteam"

//----------------------------------------------------------------------------
// CSGO
// User vote to kick user.
#define CSGO_VOTE_KICK_IDLE_START			"#SFUI_vote_kick_player_idle"
#define CSGO_VOTE_KICK_SCAMMING_START		"#SFUI_vote_kick_player_scamming"
#define CSGO_VOTE_KICK_CHEATING_START		"#SFUI_vote_kick_player_cheating"
#define CSGO_VOTE_KICK_START				"#SFUI_vote_kick_player_other"
#define CSGO_VOTE_KICK_OTHERTEAM			"#SFUI_otherteam_vote_kick_player"
#define CSGO_VOTE_KICK_PASSED				"#SFUI_vote_passed_kick_player"

// User vote to restart map.
#define CSGO_VOTE_RESTART_START				"#SFUI_vote_restart_game"
#define CSGO_VOTE_RESTART_PASSED			"#SFUI_vote_passed_restart_game"

// User vote to change maps.
#define CSGO_VOTE_CHANGELEVEL_START			"#SFUI_vote_changelevel"
#define CSGO_VOTE_CHANGELEVEL_PASSED			"#SFUI_vote_passed_changelevel"

// User vote to change next level.
#define CSGO_VOTE_NEXTLEVEL_SINGLE_START		"#SFUI_vote_nextlevel"
#define CSGO_VOTE_NEXTLEVEL_MULTIPLE_START	"#SFUI_vote_nextlevel_choices" // Started by server
#define CSGO_VOTE_NEXTLEVEL_EXTEND_PASSED	"#SFUI_vote_passed_nextlevel_extend"
#define CSGO_VOTE_NEXTLEVEL_PASSED			"#SFUI_vote_passed_nextlevel"

// User vote to scramble teams.  Can be immediate or end of round.
#define CSGO_VOTE_SCRAMBLE_START			"#SFUI_vote_scramble_teams"
#define CSGO_VOTE_SCRAMBLE_PASSED 			"#SFUI_vote_passed_scramble_teams"

#define CSGO_VOTE_SWAPTEAMS_START			"#SFUI_vote_swap_teams"
#define CSGO_VOTE_SWAPTEAMS_PASSED 			"#SFUI_vote_passed_swap_teams"

#define CSGO_VOTE_SURRENDER_START			"#SFUI_vote_surrender"
#define CSGO_VOTE_SURRENDER_OTHERTEAM		"#SFUI_otherteam_vote_surrender"
#define CSGO_VOTE_SURRENDER_PASSED			"#SFUI_vote_passed_surrender"

#define CSGO_VOTE_REMATCH_START				"#SFUI_vote_rematch"
#define CSGO_VOTE_REMATCH_OTHERTEAM			"#SFUI_vote_rematch"
#define CSGO_VOTE_REMATCH_PASSED			"#SFUI_vote_passed_rematch"

#define CSGO_VOTE_CONTINUE_START			"#SFUI_vote_continue"
#define CSGO_VOTE_CONTINUE_OTHERTEAM		"#SFUI_otherteam_vote_continue_or_surrender"
#define CSGO_VOTE_CONTINUE_PASSED			"#SFUI_vote_passed_continue"

#define CSGO_VOTE_UNIMPLEMENTED_OTHERTEAM	"#SFUI_otherteam_vote_unimplemented"

// While not a vote string, it works just as well.
#define CSGO_VOTE_CUSTOM					"#SFUI_Scoreboard_NormalPlayer"

//----------------------------------------------------------------------------
// Generic functions
// 

new g_VoteController = -1;
new g_bUserBuf = false;

bool:Game_IsGameSupported(String:engineName[]="", maxlength=0)
{
	g_EngineVersion = GetEngineVersion();
	g_bUserBuf = GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf;
	
	//LogMessage("Detected Engine version: %d", g_EngineVersion);
	if (maxlength > 0)
	{
		GetEngineVersionName(g_EngineVersion, engineName, maxlength);
	}
	
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2, Engine_CSGO, Engine_TF2:
		{
			return true;
		}
	}
	
	return false;
}

bool:CheckVoteController()
{
	new entity = -1;
	if (g_VoteController != -1)
	{
		entity = EntRefToEntIndex(g_VoteController);
	}
	
	if (entity == -1)
	{
		entity = FindEntityByClassname(-1, "vote_controller");
		if (entity == -1)
		{
			LogError("Could not find Vote Controller.");
			return false;
		}
		
		g_VoteController = EntIndexToEntRef(entity);
	}
	return true;
}

// All logic for choosing a game-specific function should happen here.
// There should be one per function in the game shared and specific sections
Game_ParseVote(const String:option[])
{
	new item = NATIVEVOTES_VOTE_INVALID;
	
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			item = L4DL4D2_ParseVote(option);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			item = TF2CSGO_ParseVote(option);
		}
	}
	
	return item;

}

Game_GetMaxItems()
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			return L4DL4D2_COUNT;
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			return TF2CSGO_COUNT;
		}
	}
	
	return 0; // Here to prevent warnings
}

bool:Game_CheckVoteType(NativeVotesType:type)
{
	new bool:returnVal = false;
	
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			returnVal = L4D_CheckVoteType(type);
		}
		
		case Engine_Left4Dead2:
		{
			returnVal = L4D2_CheckVoteType(type);
		}
		
		case Engine_CSGO:
		{
			returnVal = CSGO_CheckVoteType(type);
		}

		case Engine_TF2:
		{
			returnVal = TF2_CheckVoteType(type);
		}
	}
	
	return returnVal;
}

bool:Game_CheckVotePassType(NativeVotesPassType:type)
{
	new bool:returnVal = false;
	
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			returnVal = L4D_CheckVotePassType(type);
		}
		
		case Engine_Left4Dead2:
		{
			returnVal = L4D2_CheckVotePassType(type);
		}
		
		case Engine_CSGO:
		{
			returnVal = CSGO_CheckVotePassType(type);
		}
		
		case Engine_TF2:
		{
			returnVal = TF2_CheckVotePassType(type);
		}
	}
	
	return returnVal;
}

bool:Game_DisplayVoteToOne(Handle:vote, client)
{
	if (g_bCancelled)
	{
		return false;
	}
	
	new clients[1];
	clients[0] = client;
	
	return Game_DisplayVote(vote, clients, 1);
}

bool:Game_DisplayVote(Handle:vote, clients[], num_clients)
{
	if (g_bCancelled)
	{
		return false;
	}
	
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			L4D_DisplayVote(vote, num_clients);
		}
		
		case Engine_Left4Dead2:
		{
			L4D2_DisplayVote(vote, clients, num_clients);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_DisplayVote(vote, clients, num_clients);
		}
	}

	return true;
}

Game_DisplayVoteFail(Handle:vote, NativeVotesFailType:reason, client=0)
{
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			if (!client)
			{
				L4D_DisplayVoteFail(vote);
			}
		}
		
		case Engine_Left4Dead2:
		{
			L4D2_DisplayVoteFail(vote, client);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_DisplayVoteFail(vote, reason, client);
		}
	}
}

Game_DisplayVotePass(Handle:vote, const String:details[], client=0)
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			if (!client)
			{
				L4D_DisplayVotePass(vote, details);
			}
		}

		case Engine_Left4Dead2:
		{
			L4D2_DisplayVotePass(vote, details, client);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_DisplayVotePass(vote, details, client);
		}
	}
}

Game_DisplayVotePassEx(Handle:vote, NativeVotesPassType:passType, const String:details[], client=0)
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			if (!client)
			{
				L4D_DisplayVotePassEx(vote, passType, details);
			}
		}

		case Engine_Left4Dead2:
		{
			L4D2_DisplayVotePassEx(vote, passType, details, client);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_DisplayVotePassEx(vote, passType, details, client);
		}
	}
}

Game_DisplayVotePassCustom(Handle:vote, const String:translation[], client)
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			ThrowNativeError(SP_ERROR_NATIVE, "NativeVotes_DisplayPassCustom is not supported on L4D");
		}

		case Engine_Left4Dead2:
		{
			L4D2_VotePass(vote, L4D_VOTE_CUSTOM, translation, client);
		}
		
		case Engine_CSGO:
		{
			TF2CSGO_VotePass(vote, CSGO_VOTE_CUSTOM, translation, client);
		}

		case Engine_TF2:
		{
			TF2CSGO_VotePass(vote, TF2_VOTE_CUSTOM, translation, client);
		}
	}
}

Game_DisplayCallVoteFail(client, NativeVotesCallFailType:reason, time)
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			L4DL4D2_DisplayCallVoteFail(client, reason);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_DisplayCallVoteFail(client, reason, time);
		}
	}
}

Game_ClientSelectedItem(Handle:vote, client, item)
{
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			L4DL4D2_ClientSelectedItem(client, item);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_ClientSelectedItem(vote, client, item);
		}
/*
		case Engine_Left4Dead:
		{
			L4D_ClientSelectedItem(vote, client, item);
		}
		
		case Engine_Left4Dead2:
		{
			L4D2_ClientSelectedItem(client, item);
		}
*/
	}
}

Game_UpdateVoteCounts(Handle:hVoteCounts, totalClients)
{
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			L4DL4D2_UpdateVoteCounts(hVoteCounts, totalClients);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_UpdateVoteCounts(hVoteCounts);
		}
	}
}

/*
Game_DisplayVoteSetup(client, const NativeVotesType:voteTypes[])
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead:
		{
			//L4D_DisplayVoteSetup(client, voteTypes);
		}
		
		case Engine_Left4Dead2:
		{
			//L4D2_DisplayVoteSetup(client, voteTypes);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_DisplayVoteSetup(client, voteTypes);
		}
	}
}
*/
Game_UpdateClientCount(num_clients)
{
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			L4DL4D2_UpdateClientCount(num_clients);
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_UpdateClientCount(num_clients);
		}
	}
}

Game_ResetVote()
{
	switch(g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			L4DL4D2_ResetVote();
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			TF2CSGO_ResetVote();
		}
	}
}

Game_VoteYes(client)
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			FakeClientCommand(client, "Vote Yes");
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			FakeClientCommand(client, "vote option1");
		}
	}
}

Game_VoteNo(client)
{
	switch (g_EngineVersion)
	{
		case Engine_Left4Dead, Engine_Left4Dead2:
		{
			FakeClientCommand(client, "Vote No");
		}
		
		case Engine_CSGO, Engine_TF2:
		{
			FakeClientCommand(client, "vote option2");
		}
	}
}

//----------------------------------------------------------------------------
// L4D/L4D2 shared functions

// NATIVEVOTES_VOTE_INVALID means parse failed
L4DL4D2_ParseVote(const String:option[])
{
	if (StrEqual(option, "Yes", false))
	{
		return NATIVEVOTES_VOTE_YES;
	}
	else if (StrEqual(option, "No", false))
	{
		return NATIVEVOTES_VOTE_NO;
	}
	
	return NATIVEVOTES_VOTE_INVALID;
}

L4DL4D2_ClientSelectedItem(client, item)
{
	new choice;
	
	if (item == NATIVEVOTES_VOTE_NO)
	{
		choice = 0;
	}
	else if (item == NATIVEVOTES_VOTE_YES)
	{
		choice = 1;
	}
	
	new Handle:voteCast = StartMessageOne("VoteRegistered", client, USERMSG_RELIABLE);
	BfWriteByte(voteCast, choice);
	EndMessage();
}

L4DL4D2_UpdateVoteCounts(Handle:votes, totalClients)
{
	new yesVotes = GetArrayCell(votes, NATIVEVOTES_VOTE_YES);
	new noVotes = GetArrayCell(votes, NATIVEVOTES_VOTE_NO);
	new Handle:changeEvent = CreateEvent("vote_changed");
	SetEventInt(changeEvent, "yesVotes", yesVotes);
	SetEventInt(changeEvent, "noVotes", noVotes);
	SetEventInt(changeEvent, "potentialVotes", totalClients);
	FireEvent(changeEvent);
	
	if (CheckVoteController())
	{
		SetEntProp(g_VoteController, Prop_Send, "m_votesYes", yesVotes);
		SetEntProp(g_VoteController, Prop_Send, "m_votesNo", noVotes);
	}
}

L4DL4D2_UpdateClientCount(num_clients)
{
	if (CheckVoteController())
	{
		SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", num_clients);
	}
}

L4DL4D2_DisplayCallVoteFail(client, NativeVotesCallFailType:reason)
{
	new Handle:callVoteFail = StartMessageOne("CallVoteFailed", client, USERMSG_RELIABLE);

	BfWriteByte(callVoteFail, _:reason);
	
	EndMessage();
}

L4DL4D2_VoteTypeToTranslation(NativeVotesType:voteType, String:translation[], maxlength)
{
	switch(voteType)
	{
		case NativeVotesType_ChgCampaign:
		{
			strcopy(translation, maxlength, L4D_VOTE_CHANGECAMPAIGN_START);
		}
		
		case NativeVotesType_ChgDifficulty:
		{
			strcopy(translation, maxlength, L4D_VOTE_CHANGEDIFFICULTY_START);
		}
		
		case NativeVotesType_ReturnToLobby:
		{
			strcopy(translation, maxlength, L4D_VOTE_RETURNTOLOBBY_START);
		}
		
		case NativeVotesType_AlltalkOn, NativeVotesType_AlltalkOff:
		{
			strcopy(translation, maxlength, L4D2_VOTE_ALLTALK_START);
		}
		
		case NativeVotesType_Restart:
		{
			strcopy(translation, maxlength, L4D_VOTE_RESTART_START);
		}
		
		case NativeVotesType_Kick:
		{
			strcopy(translation, maxlength, L4D_VOTE_KICK_START);
		}
		
		case NativeVotesType_ChgLevel:
		{
			strcopy(translation, maxlength, L4D_VOTE_CHANGELEVEL_START);
		}
		
		default:
		{
			strcopy(translation, maxlength, L4D_VOTE_CUSTOM);
		}
	}
}

L4DL4D2_VotePassToTranslation(NativeVotesPassType:passType, String:translation[], maxlength)
{
	switch(passType)
	{
		case NativeVotesPass_Custom:
		{
			strcopy(translation, maxlength, L4D_VOTE_CUSTOM);
		}
		
		case NativeVotesPass_ChgCampaign:
		{
			strcopy(translation, maxlength, L4D_VOTE_CHANGECAMPAIGN_PASSED);
		}
		
		case NativeVotesPass_ChgDifficulty:
		{
			strcopy(translation, maxlength, L4D_VOTE_CHANGEDIFFICULTY_PASSED);
		}
		
		case NativeVotesPass_ReturnToLobby:
		{
			strcopy(translation, maxlength, L4D_VOTE_RETURNTOLOBBY_PASSED);
		}
		
		case NativeVotesPass_AlltalkOn, NativeVotesPass_AlltalkOff:
		{
			strcopy(translation, maxlength, L4D2_VOTE_ALLTALK_PASSED);
		}
		
		case NativeVotesPass_Restart:
		{
			strcopy(translation, maxlength, L4D_VOTE_RESTART_PASSED);
		}
		
		case NativeVotesPass_Kick:
		{
			strcopy(translation, maxlength, L4D_VOTE_KICK_PASSED);
		}
		
		case NativeVotesPass_ChgLevel:
		{
			strcopy(translation, maxlength, L4D_VOTE_CHANGELEVEL_PASSED);
		}
		
		default:
		{
			strcopy(translation, maxlength, L4D_VOTE_CUSTOM);
		}
	}
}

L4DL4D2_ResetVote()
{
	if (CheckVoteController())
	{
		SetEntProp(g_VoteController, Prop_Send, "m_onlyTeamToVote", NATIVEVOTES_ALL_TEAMS);
		SetEntProp(g_VoteController, Prop_Send, "m_votesYes", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_votesNo", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_activeIssueIndex", -1);
	}
}


//----------------------------------------------------------------------------
// L4D functions

/*
L4D_ClientSelectedItem(Handle:vote, client, item)
{
	if (item > NATIVEVOTES_VOTE_INVALID && item <= Game_GetMaxItems())
	{
		new Handle:castEvent;
		
		switch (item)
		{
			case NATIVEVOTES_VOTE_YES:
			{
				castEvent = CreateEvent("vote_cast_no");
			}
			
			case NATIVEVOTES_VOTE_NO:
			{
				castEvent = CreateEvent("vote_cast_yes");
			}
			
			default:
			{
				return;
			}
		}
		
		if (castEvent != INVALID_HANDLE)
		{
			SetEventInt(castEvent, "team", Data_GetTeam(vote));
			SetEventInt(castEvent, "entityid", client);
			FireEvent(castEvent);
		}
		
	}
}
*/

L4D_DisplayVote(Handle:vote, num_clients)
{
	new String:translation[TRANSLATION_LENGTH];

	new NativeVotesType:voteType = Data_GetType(vote);
	
	L4DL4D2_VoteTypeToTranslation(voteType, translation, sizeof(translation));

	decl String:details[MAX_VOTE_DETAILS_LENGTH];
	Data_GetDetails(vote, details, MAX_VOTE_DETAILS_LENGTH);
	
	new team = Data_GetTeam(vote);
	
	new Handle:voteStart = CreateEvent("vote_started");
	SetEventInt(voteStart, "team", team);
	SetEventInt(voteStart, "initiator", Data_GetInitiator(vote));
	SetEventString(voteStart, "issue", translation);
	SetEventString(voteStart, "param1", details);
	FireEvent(voteStart);
	
	if (CheckVoteController())
	{
		SetEntProp(g_VoteController, Prop_Send, "m_onlyTeamToVote", team);
		SetEntProp(g_VoteController, Prop_Send, "m_votesYes", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_votesNo", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", num_clients);
		// TODO: Need to look these values up
		SetEntProp(g_VoteController, Prop_Send, "m_activeIssueIndex", 0); // For now, set to 0 to block in-game votes
	}
}

L4D_VoteEnded()
{
	new Handle:endEvent = CreateEvent("vote_ended");
	FireEvent(endEvent);
}

L4D_DisplayVotePass(Handle:vote, const String:details[])
{
	L4D_DisplayVotePassEx(vote, VoteTypeToVotePass(Data_GetType(vote)), details);
}

L4D_DisplayVotePassEx(Handle:vote, NativeVotesPassType:passType, const String:details[])
{
	decl String:translation[TRANSLATION_LENGTH];
	L4DL4D2_VotePassToTranslation(passType, translation, sizeof(translation));

	L4D_VotePass(vote, translation, details);
}

L4D_VotePass(Handle:vote, const String:translation[], const String:details[])
{
	L4D_VoteEnded();
	
	new Handle:passEvent = CreateEvent("vote_passed");
	SetEventString(passEvent, "details", translation);
	SetEventString(passEvent, "param1", details);
	SetEventInt(passEvent, "team", Data_GetTeam(vote));
	FireEvent(passEvent);
}

L4D_DisplayVoteFail(Handle:vote)
{
	L4D_VoteEnded();

	new Handle:failEvent = CreateEvent("vote_failed");
	SetEventInt(failEvent, "team", Data_GetTeam(vote));
	FireEvent(failEvent);
}

bool:L4D_CheckVoteType(NativeVotesType:voteType)
{
	switch(voteType)
	{
		case NativeVotesType_Custom_YesNo, NativeVotesType_ChgCampaign, NativeVotesType_ChgDifficulty,
		NativeVotesType_ReturnToLobby, NativeVotesType_Restart, NativeVotesType_Kick,
		NativeVotesType_ChgLevel:
		{
			return true;
		}
	}
	
	return false;
}

bool:L4D_CheckVotePassType(NativeVotesPassType:passType)
{
	switch(passType)
	{
		case NativeVotesPass_Custom, NativeVotesPass_ChgCampaign, NativeVotesPass_ChgDifficulty,
		NativeVotesPass_ReturnToLobby, NativeVotesPass_Restart, NativeVotesPass_Kick,
		NativeVotesPass_ChgLevel:
		{
			return true;
		}
	}
	
	return false;
}

//----------------------------------------------------------------------------
// L4D2 functions

L4D2_DisplayVote(Handle:vote, clients[], num_clients)
{
	new String:translation[TRANSLATION_LENGTH];

	new NativeVotesType:voteType = Data_GetType(vote);
	
	L4DL4D2_VoteTypeToTranslation(voteType, translation, sizeof(translation));

	decl String:details[MAX_VOTE_DETAILS_LENGTH];
	
	new team = Data_GetTeam(vote);
	new bool:bCustom = false;
	
	switch (voteType)
	{
		case NativeVotesType_AlltalkOn:
		{
			strcopy(details, MAX_VOTE_DETAILS_LENGTH, L4D2_VOTE_ALLTALK_ENABLE);
		}
		
		case NativeVotesType_AlltalkOff:
		{
			strcopy(details, MAX_VOTE_DETAILS_LENGTH, L4D2_VOTE_ALLTALK_DISABLE);
		}
		
		case NativeVotesType_Custom_YesNo, NativeVotesType_Custom_Mult:
		{
			Data_GetTitle(vote, details, MAX_VOTE_DETAILS_LENGTH);
			bCustom = true;
		}
		
		default:
		{
			Data_GetDetails(vote, details, MAX_VOTE_DETAILS_LENGTH);
		}
	}
	
	new initiator = Data_GetInitiator(vote);
	new String:initiatorName[MAX_NAME_LENGTH];

	if (initiator != NATIVEVOTES_SERVER_INDEX && initiator > 0 && initiator <= MaxClients && IsClientInGame(initiator))
	{
		GetClientName(initiator, initiatorName, MAX_NAME_LENGTH);
	}

	for (new i = 0; i < num_clients; ++i)
	{
		g_newMenuTitle[0] = '\0';
		
		new MenuAction:actions = Data_GetActions(vote);
		
		new Action:changeTitle = Plugin_Continue;
		if (bCustom && actions & MenuAction_Display)
		{
			g_curDisplayClient = clients[i];
			changeTitle = Action:DoAction(vote, MenuAction_Display, clients[i], 0);
		}
		
		g_curDisplayClient = 0;
	
		new Handle:voteStart = StartMessageOne("VoteStart", clients[i], USERMSG_RELIABLE);
		BfWriteByte(voteStart, team);
		BfWriteByte(voteStart, initiator);
		BfWriteString(voteStart, translation);
		if (changeTitle == Plugin_Changed)
		{
			BfWriteString(voteStart, g_newMenuTitle);
		}
		else
		{
			BfWriteString(voteStart, details);
		}
		BfWriteString(voteStart, initiatorName);
		EndMessage();
	}
	
	if (CheckVoteController())
	{
		SetEntProp(g_VoteController, Prop_Send, "m_onlyTeamToVote", team);
		SetEntProp(g_VoteController, Prop_Send, "m_votesYes", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_votesNo", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_potentialVotes", num_clients);
		// TODO: Need to look these values up
		SetEntProp(g_VoteController, Prop_Send, "m_activeIssueIndex", 0); // For now set to 0 to block ingame votes
	}
}

L4D2_DisplayVotePass(Handle:vote, const String:details[], client=0)
{
	L4D2_DisplayVotePassEx(vote, VoteTypeToVotePass(Data_GetType(vote)), details, client);
}

L4D2_DisplayVotePassEx(Handle:vote, NativeVotesPassType:passType, const String:details[], client=0)
{
	decl String:translation[TRANSLATION_LENGTH];
	
	L4DL4D2_VotePassToTranslation(passType, translation, sizeof(translation));
	
	switch (passType)
	{
		case NativeVotesPass_AlltalkOn:
		{
			L4D2_VotePass(vote, translation, L4D2_VOTE_ALLTALK_ENABLE, client);
		}
		
		case NativeVotesPass_AlltalkOff:
		{
			L4D2_VotePass(vote, translation, L4D2_VOTE_ALLTALK_DISABLE, client);
		}
		
		default:
		{
			L4D2_VotePass(vote, translation, details, client);
		}
	}
}

L4D2_VotePass(Handle:vote, const String:translation[], const String:details[], client=0)
{
	new Handle:votePass;
	if (!client)
	{
		votePass = StartMessageAll("VotePass", USERMSG_RELIABLE);
	}
	else
	{
		votePass = StartMessageOne("VotePass", client, USERMSG_RELIABLE);
	}
	
	BfWriteByte(votePass, Data_GetTeam(vote));
	BfWriteString(votePass, translation);
	BfWriteString(votePass, details);
	EndMessage();
}

L4D2_DisplayVoteFail(Handle:vote, client=0)
{
	new Handle:voteFailed;
	if (!client)
	{
		voteFailed = StartMessageAll("VoteFail", USERMSG_RELIABLE);
	}
	else
	{
		voteFailed = StartMessageOne("VoteFail", client, USERMSG_RELIABLE);
	}
	
	BfWriteByte(voteFailed, Data_GetTeam(vote));
	EndMessage();
}

bool:L4D2_CheckVoteType(NativeVotesType:voteType)
{
	switch(voteType)
	{
		case NativeVotesType_Custom_YesNo, NativeVotesType_ChgCampaign, NativeVotesType_ChgDifficulty,
		NativeVotesType_ReturnToLobby, NativeVotesType_AlltalkOn, NativeVotesType_AlltalkOff,
		NativeVotesType_Restart, NativeVotesType_Kick, NativeVotesType_ChgLevel:
		{
			return true;
		}
	}
	
	return false;
}

bool:L4D2_CheckVotePassType(NativeVotesPassType:passType)
{
	switch(passType)
	{
		case NativeVotesPass_Custom, NativeVotesPass_ChgCampaign, NativeVotesPass_ChgDifficulty,
		NativeVotesPass_ReturnToLobby, NativeVotesPass_AlltalkOn, NativeVotesPass_AlltalkOff,
		NativeVotesPass_Restart, NativeVotesPass_Kick, NativeVotesPass_ChgLevel:
		{
			return true;
		}
	}
	
	return false;
}

//----------------------------------------------------------------------------
// TF2/CSGO shared functions

// TF2 and CSGO functions are still together in case Valve moves TF2 to protobufs.

// NATIVEVOTES_VOTE_INVALID means parse failed
TF2CSGO_ParseVote(const String:option[])
{
	// option1 <-- 7 characters exactly
	if (strlen(option) != 7)
	{
		return NATIVEVOTES_VOTE_INVALID;
	}

	return StringToInt(option[6]) - 1;
}

TF2CSGO_ClientSelectedItem(Handle:vote, client, item)
{
	new Handle:castEvent = CreateEvent("vote_cast");
	
	SetEventInt(castEvent, "team", Data_GetTeam(vote));
	SetEventInt(castEvent, "entityid", client);
	SetEventInt(castEvent, "vote_option", item);
	FireEvent(castEvent);
}

TF2CSGO_UpdateVoteCounts(Handle:votes)
{
	if (CheckVoteController())
	{
		new size = GetArraySize(votes);
		for (new i = 0; i < size; i++)
		{
			SetEntProp(g_VoteController, Prop_Send, "m_nVoteOptionCount", GetArrayCell(votes, i), 4, i);
		}
	}
}

TF2CSGO_UpdateClientCount(num_clients)
{
	if (CheckVoteController())
	{
		SetEntProp(g_VoteController, Prop_Send, "m_nPotentialVotes", num_clients);
	}
}

TF2CSGO_DisplayVote(Handle:vote, clients[], num_clients)
{
	new NativeVotesType:voteType = Data_GetType(vote);
	
	new String:translation[TRANSLATION_LENGTH];
	new String:otherTeamString[TRANSLATION_LENGTH];
	new bool:bYesNo = true;
	new bool:bCustom = false;
	
	new String:details[MAX_VOTE_DETAILS_LENGTH];
	
	switch (voteType)
	{
		case NativeVotesType_Custom_YesNo, NativeVotesType_Custom_Mult:
		{
			Data_GetTitle(vote, details, MAX_VOTE_DETAILS_LENGTH);
			bCustom = true;
		}
		
		default:
		{
			Data_GetDetails(vote, details, MAX_VOTE_DETAILS_LENGTH);
		}
	}
	
	switch(g_EngineVersion)
	{
		case Engine_CSGO:
		{
			bYesNo = CSGO_VoteTypeToTranslation(voteType, translation, sizeof(translation));
			CSGO_VoteTypeToVoteOtherTeamString(voteType, otherTeamString, sizeof(otherTeamString));
		}
		
		case Engine_TF2:
		{
			bYesNo = TF2_VoteTypeToTranslation(voteType, translation, sizeof(translation));
		}
	}
	
	// According to Source SDK 2013, vote_options is only sent for a multiple choice vote.
	if (!bYesNo)
	{
		new Handle:optionsEvent = CreateEvent("vote_options");
		
		new maxCount = Data_GetItemCount(vote);
		
		for (new i = 0; i < maxCount; i++)
		{
			decl String:option[8];
			Format(option, sizeof(option), "%s%d", TF2CSGO_VOTE_PREFIX, i+1);
			
			decl String:display[TRANSLATION_LENGTH];
			Data_GetItemDisplay(vote, i, display, sizeof(display));
			SetEventString(optionsEvent, option, display);
		}
		SetEventInt(optionsEvent, "count", maxCount);
		FireEvent(optionsEvent);
	}
	
	new team = Data_GetTeam(vote);
	
	for (new i = 0; i < num_clients; ++i)
	{
		g_newMenuTitle[0] = '\0';
		
		new MenuAction:actions = Data_GetActions(vote);
		
		new Action:changeTitle = Plugin_Continue;
		if (bCustom && actions & MenuAction_Display)
		{
			g_curDisplayClient = clients[i];
			changeTitle = Action:DoAction(vote, MenuAction_Display, clients[i], 0);
		}
		
		g_curDisplayClient = 0;
		new maxCount = Data_GetItemCount(vote);
		
		new Handle:optionsEvent = CreateEvent("vote_options");
		for (new j = 0; j < maxCount; j++)
		{
			decl String:option[8];
			Format(option, sizeof(option), "%s%d", TF2CSGO_VOTE_PREFIX, j+1);
			
			decl String:display[TRANSLATION_LENGTH];
			Data_GetItemDisplay(vote, j, display, TRANSLATION_LENGTH);
			SetEventString(optionsEvent, option, display);
		}
		SetEventInt(optionsEvent, "count", maxCount);
		FireEvent(optionsEvent);
		
		if (!bYesNo && actions & MenuAction_DisplayItem)
		{
			optionsEvent = CreateEvent("vote_options");
			
			for (new j = 0; j < maxCount; j++)
			{
				new Action:changeItem = Plugin_Continue;
				g_curItemClient = clients[i];
				g_newMenuItem[0] = '\0';
				
				changeItem = Action:DoAction(vote, MenuAction_DisplayItem, clients[i], j);
				g_curItemClient = 0;
				
				decl String:option[8];
				Format(option, sizeof(option), "%s%d", TF2CSGO_VOTE_PREFIX, j+1);
				
				decl String:display[TRANSLATION_LENGTH];
				if (changeItem == Plugin_Changed)
				{
					strcopy(display, TRANSLATION_LENGTH, g_newMenuItem);
				}
				else
				{
					Data_GetItemDisplay(vote, j, display, sizeof(display));
				}
				SetEventString(optionsEvent, option, display);
			}
			SetEventInt(optionsEvent, "count", maxCount);
			FireEvent(optionsEvent);
		}
		
		new Handle:voteStart = StartMessageOne("VoteStart", clients[i], USERMSG_RELIABLE);
		
		if(g_bUserBuf)
		{
			PbSetInt(voteStart, "team", team);
			PbSetInt(voteStart, "ent_idx", Data_GetInitiator(vote));
			PbSetString(voteStart, "disp_str", translation);
			if (bCustom && changeTitle == Plugin_Changed)
			{
				PbSetString(voteStart, "details_str", g_newMenuTitle);
			}
			else
			{
				PbSetString(voteStart, "details_str", details);
			}
			PbSetBool(voteStart, "is_yes_no_vote", bYesNo);
			PbSetString(voteStart, "other_team_str", otherTeamString);
			// TODO: Need to look these values up. These values may correspond to the order votes show up in for VoteSetup
			PbSetInt(voteStart, "vote_type", 0); // For now, set to 0 to block in-game votes
		}
		else
		{
			BfWriteByte(voteStart, team);
			BfWriteByte(voteStart, Data_GetInitiator(vote));
			BfWriteString(voteStart, translation);
			if (bCustom && changeTitle == Plugin_Changed)
			{
				BfWriteString(voteStart, g_newMenuTitle);
			}
			else
			{
				BfWriteString(voteStart, details);
			}
			BfWriteBool(voteStart, bYesNo);
		}
		EndMessage();
	}
	
	g_curDisplayClient = 0;
	
	if (CheckVoteController())
	{
		SetEntProp(g_VoteController, Prop_Send, "m_iOnlyTeamToVote", team);
		for (new i = 0; i < 5; i++)
		{
			SetEntProp(g_VoteController, Prop_Send, "m_nVoteOptionCount", 0, _, i);
		}
		SetEntProp(g_VoteController, Prop_Send, "m_nPotentialVotes", num_clients);
		SetEntProp(g_VoteController, Prop_Send, "m_bIsYesNoVote", bYesNo);
		// TODO: Need to look these values up. These values may correspond to the order votes show up in for VoteSetup
		SetEntProp(g_VoteController, Prop_Send, "m_iActiveIssueIndex", 0); // For now, set to 0 to block in-game votes
	}
}

TF2CSGO_DisplayVotePass(Handle:vote, const String:details[], client=0)
{
	TF2CSGO_DisplayVotePassEx(vote, VoteTypeToVotePass(Data_GetType(vote)), details, client);
}

TF2CSGO_DisplayVotePassEx(Handle:vote, NativeVotesPassType:passType, const String:details[], client=0)
{
	decl String:translation[TRANSLATION_LENGTH];
	
	switch(g_EngineVersion)
	{
		case Engine_CSGO:
		{
			CSGO_VotePassToTranslation(passType, translation, sizeof(translation));
		}
		
		case Engine_TF2:
		{
			TF2_VotePassToTranslation(passType, translation, sizeof(translation));
		}
	}
	
	TF2CSGO_VotePass(vote, translation, details, client);
}

TF2CSGO_VotePass(Handle:vote, const String:translation[], const String:details[], client=0)
{
	new Handle:votePass = INVALID_HANDLE;
	
	if (!client)
	{
		votePass = StartMessageAll("VotePass", USERMSG_RELIABLE);
	}
	else
	{
		votePass = StartMessageOne("VotePass", client, USERMSG_RELIABLE);
	}

	if(g_bUserBuf)
	{
		PbSetInt(votePass, "team", Data_GetTeam(vote));
		PbSetString(votePass, "disp_str", translation);
		PbSetString(votePass, "details_str", details);
		PbSetInt(votePass, "vote_type", 0); // Unknown, need to check values
	}
	else
	{
		BfWriteByte(votePass, Data_GetTeam(vote));
		BfWriteString(votePass, translation);
		BfWriteString(votePass, details);
	}
	EndMessage();
}

TF2CSGO_DisplayVoteFail(Handle:vote, NativeVotesFailType:reason, client=0)
{
	new Handle:voteFailed;
	if (!client)
	{
		voteFailed = StartMessageAll("VoteFailed", USERMSG_RELIABLE);
	}
	else
	{
		voteFailed = StartMessageOne("VoteFailed", client, USERMSG_RELIABLE);
	}
	
	if(g_bUserBuf)
	{
		PbSetInt(voteFailed, "team", Data_GetTeam(vote));
		PbSetInt(voteFailed, "reason", _:reason);
	}
	else
	{
		BfWriteByte(voteFailed, Data_GetTeam(vote));
		BfWriteByte(voteFailed, _:reason);
	}
	EndMessage();
}

TF2CSGO_DisplayCallVoteFail(client, NativeVotesCallFailType:reason, time)
{
	new Handle:callVoteFail = StartMessageOne("CallVoteFailed", client, USERMSG_RELIABLE);

	if(g_bUserBuf)
	{
		PbSetInt(callVoteFail, "reason", _:reason);
		PbSetInt(callVoteFail, "time", time);
	}
	else
	{
		BfWriteByte(callVoteFail, _:reason);
		BfWriteShort(callVoteFail, time);
	}
	EndMessage();
}

/*
TF2CSGO_VoteTypeToVoteString(NativeVotesType:voteType, String:voteString[], maxlength)
{
	new bool:valid = false;
	switch(voteType)
	{
		case NativeVotesType_Kick:
		{
			strcopy(voteString, maxlength, TF2CSGO_VOTE_STRING_KICK);
			valid = true;
		}
		
		case NativeVotesType_ChgLevel:
		{
			strcopy(voteString, maxlength, TF2CSGO_VOTE_STRING_CHANGELEVEL);
			valid = true;
		}
		
		case NativeVotesType_NextLevel:
		{
			strcopy(voteString, maxlength, TF2CSGO_VOTE_STRING_NEXTLEVEL);
			valid = true;
		}
		
		case NativeVotesType_Restart:
		{
			strcopy(voteString, maxlength, TF2CSGO_VOTE_STRING_RESTART);
			valid = true;
		}
		
		case NativeVotesType_ScrambleEnd, NativeVotesType_ScrambleNow:
		{
			strcopy(voteString, maxlength, TF2CSGO_VOTE_STRING_SCRAMBLE);
			valid = true;
		}
	}
	
	return valid;
}

NativeVotesType:TF2CSGO_VoteStringToVoteType(String:voteString[])
{
	new NativeVotesType:voteType = NativeVotesType_None;
	
	if (StrEqual(voteString, TF2CSGO_VOTE_STRING_KICK, false))
	{
		voteType = NativeVotesType_Kick;
	}
	else if (StrEqual(voteString, TF2CSGO_VOTE_STRING_CHANGELEVEL, false))
	{
		voteType = NativeVotesType_ChgLevel;
	}
	else if (StrEqual(voteString, TF2CSGO_VOTE_STRING_NEXTLEVEL, false))
	{
		voteType = NativeVotesType_NextLevel;
	}
	else if (StrEqual(voteString, TF2CSGO_VOTE_STRING_RESTART, false))
	{
		voteType = NativeVotesType_Restart;
	}
	else if (StrEqual(voteString, TF2CSGO_VOTE_STRING_SCRAMBLE, false))
	{
		voteType = NativeVotesType_ScrambleNow;
	}
	
	return voteType;
}

TF2CSGO_DisplayVoteSetup(client, const NativeVotesType:voteTypes[])
{
	new count = 0;
	new String:validVoteTypes[MAX_VOTE_ISSUES][VOTE_STRING_SIZE];
	
	for (new i = 0; i < MAX_VOTE_ISSUES; ++i)
	{
		if (voteTypes[i] == NativeVotesType_None)
		{
			break;
		}
		
		new bool:valid = Game_CheckVoteType(voteTypes[i]);
		
		if (valid && TF2CSGO_VoteTypeToVoteString(voteTypes[i], validVoteTypes[count], VOTE_STRING_SIZE))
		{
			++count;
		}
	}
	
	new Handle:voteSetup = StartMessageOne("VoteSetup", client, USERMSG_RELIABLE);
	
	if(g_bUserBuf)
	{
		for (new i = 0; i < count; ++i)
		{
			PbAddString(voteSetup, "potential_issues", validVoteTypes[i]);
		}
	}
	else
	{
		BfWriteByte(voteSetup, count);
		for (new i = 0; i < count; ++i)
		{
			BfWriteString(voteSetup, validVoteTypes[i]);
		}
	}
	
	EndMessage();
}
*/

TF2CSGO_ResetVote()
{
	if (CheckVoteController())
	{	
		SetEntProp(g_VoteController, Prop_Send, "m_iOnlyTeamToVote", NATIVEVOTES_ALL_TEAMS);
		for (new i = 0; i < 5; i++)
		{
			SetEntProp(g_VoteController, Prop_Send, "m_nVoteOptionCount", 0, _, i);
		}
		SetEntProp(g_VoteController, Prop_Send, "m_nPotentialVotes", 0);
		SetEntProp(g_VoteController, Prop_Send, "m_bIsYesNoVote", true);
		SetEntProp(g_VoteController, Prop_Send, "m_iActiveIssueIndex", -1);
	}
}

//----------------------------------------------------------------------------
// TF2 functions

bool:TF2_CheckVoteType(NativeVotesType:voteType)
{
	switch(voteType)
	{
		case NativeVotesType_Custom_YesNo, NativeVotesType_Restart,
		NativeVotesType_Kick, NativeVotesType_KickIdle, NativeVotesType_KickScamming, NativeVotesType_KickCheating,
		NativeVotesType_ChgLevel, NativeVotesType_NextLevel, NativeVotesType_ScrambleNow, NativeVotesType_ScrambleEnd,
		NativeVotesType_ChgMission, NativeVotesType_StartRound, NativeVotesType_Eternaween,
		NativeVotesType_AutoBalanceOn, NativeVotesType_AutoBalanceOff,
		NativeVotesType_ClassLimitsOn, NativeVotesType_ClassLimitsOff:
		{
			return true;
		}
		
		case NativeVotesType_Custom_Mult, NativeVotesType_NextLevelMult:
		{
			return true;
		}
	}
	
	return false;
}

bool:TF2_CheckVotePassType(NativeVotesPassType:passType)
{
	switch(passType)
	{
		case NativeVotesPass_Custom, NativeVotesPass_Restart, NativeVotesPass_ChgLevel,
		NativeVotesPass_Kick, NativeVotesPass_NextLevel, NativeVotesPass_Extend,
		NativeVotesPass_Scramble, NativeVotesPass_ChgMission, NativeVotesPass_StartRound, NativeVotesPass_Eternaween,
		NativeVotesPass_AutoBalanceOn, NativeVotesPass_AutoBalanceOff,
		NativeVotesPass_ClassLimitsOn, NativeVotesPass_ClassLimitsOff:
		{
			return true;
		}
	}
	
	return false;
}

bool:TF2_VoteTypeToTranslation(NativeVotesType:voteType, String:translation[], maxlength)
{
	new bool:bYesNo = true;
	switch(voteType)
	{
		case NativeVotesType_Custom_Mult:
		{
			strcopy(translation, maxlength, TF2_VOTE_CUSTOM);
			bYesNo = false;
		}
		
		case NativeVotesType_Restart:
		{
			strcopy(translation, maxlength, TF2_VOTE_RESTART_START);
		}
		
		case NativeVotesType_Kick:
		{
			strcopy(translation, maxlength, TF2_VOTE_KICK_START);
		}
		
		case NativeVotesType_KickIdle:
		{
			strcopy(translation, maxlength, TF2_VOTE_KICK_IDLE_START);
		}
		
		case NativeVotesType_KickScamming:
		{
			strcopy(translation, maxlength, TF2_VOTE_KICK_SCAMMING_START);
		}
		
		case NativeVotesType_KickCheating:
		{
			strcopy(translation, maxlength, TF2_VOTE_KICK_CHEATING_START);
		}
		
		case NativeVotesType_ChgLevel:
		{
			strcopy(translation, maxlength, TF2_VOTE_CHANGELEVEL_START);
		}
		
		case NativeVotesType_NextLevel:
		{
			strcopy(translation, maxlength, TF2_VOTE_NEXTLEVEL_SINGLE_START);
		}
		
		case NativeVotesType_NextLevelMult:
		{
			
			strcopy(translation, maxlength, TF2_VOTE_NEXTLEVEL_MULTIPLE_START);
			bYesNo = false;
		}
		
		case NativeVotesType_ScrambleNow:
		{
			strcopy(translation, maxlength, TF2_VOTE_SCRAMBLE_IMMEDIATE_START);
		}
		
		case NativeVotesType_ScrambleEnd:
		{
			strcopy(translation, maxlength, TF2_VOTE_SCRAMBLE_ROUNDEND_START);
		}
		
		case NativeVotesType_ChgMission:
		{
			strcopy(translation, maxlength, TF2_VOTE_CHANGEMISSION_START);
		}
		
		case NativeVotesType_StartRound:
		{
			strcopy(translation, maxlength, TF2_VOTE_ROUND_START);
		}
		
		case NativeVotesType_Eternaween:
		{
			strcopy(translation, maxlength, TF2_VOTE_ETERNAWEEN_START);
		}
		
		case NativeVotesType_AutoBalanceOn:
		{
			strcopy(translation, maxlength, TF2_VOTE_AUTOBALANCE_ENABLE_START);
		}
		
		case NativeVotesType_AutoBalanceOff:
		{
			strcopy(translation, maxlength, TF2_VOTE_AUTOBALANCE_DISABLE_START);
		}
		
		case NativeVotesType_ClassLimitsOn:
		{
			strcopy(translation, maxlength, TF2_VOTE_CLASSLIMITS_ENABLE_START);
		}
		
		case NativeVotesType_ClassLimitsOff:
		{
			strcopy(translation, maxlength, TF2_VOTE_CLASSLIMITS_DISABLE_START);
		}
		
		default:
		{
			strcopy(translation, maxlength, TF2_VOTE_CUSTOM);
		}
	}
	
	return bYesNo;
}

TF2_VotePassToTranslation(NativeVotesPassType:passType, String:translation[], maxlength)
{
	switch(passType)
	{
		case NativeVotesPass_Restart:
		{
			strcopy(translation, maxlength, TF2_VOTE_RESTART_PASSED);
		}
		
		case NativeVotesPass_Kick:
		{
			strcopy(translation, maxlength, TF2_VOTE_KICK_PASSED);
		}
		
		case NativeVotesPass_ChgLevel:
		{
			strcopy(translation, maxlength, TF2_VOTE_CHANGELEVEL_PASSED);
		}
		
		case NativeVotesPass_NextLevel:
		{
			strcopy(translation, maxlength, TF2_VOTE_NEXTLEVEL_PASSED);
		}
		
		case NativeVotesPass_Extend:
		{
			strcopy(translation, maxlength, TF2_VOTE_NEXTLEVEL_EXTEND_PASSED);
		}
		
		case NativeVotesPass_Scramble:
		{
			strcopy(translation, maxlength, TF2_VOTE_SCRAMBLE_PASSED);
		}

		case NativeVotesPass_ChgMission:
		{
			strcopy(translation, maxlength, TF2_VOTE_CHANGEMISSION_PASSED);
		}
		
		case NativeVotesPass_StartRound:
		{
			strcopy(translation, maxlength, TF2_VOTE_ROUND_PASSED);
		}
		
		case NativeVotesPass_Eternaween:
		{
			strcopy(translation, maxlength, TF2_VOTE_ETERNAWEEN_PASSED);
		}
		
		case NativeVotesPass_AutoBalanceOn:
		{
			strcopy(translation, maxlength, TF2_VOTE_AUTOBALANCE_ENABLE_PASSED);
		}
		
		case NativeVotesPass_AutoBalanceOff:
		{
			strcopy(translation, maxlength, TF2_VOTE_AUTOBALANCE_DISABLE_PASSED);
		}
		
		case NativeVotesPass_ClassLimitsOn:
		{
			strcopy(translation, maxlength, TF2_VOTE_CLASSLIMITS_ENABLE_PASSED);
		}
		
		case NativeVotesPass_ClassLimitsOff:
		{
			strcopy(translation, maxlength, TF2_VOTE_CLASSLIMITS_DISABLE_PASSED);
		}
		
		default:
		{
			strcopy(translation, maxlength, TF2_VOTE_CUSTOM);
		}
	}
}

//----------------------------------------------------------------------------
// CSGO functions

bool:CSGO_CheckVoteType(NativeVotesType:voteType)
{
	switch(voteType)
	{
		case NativeVotesType_Custom_YesNo, NativeVotesType_Restart,
		NativeVotesType_Kick, NativeVotesType_KickIdle, NativeVotesType_KickScamming, NativeVotesType_KickCheating,
		NativeVotesType_ChgLevel, NativeVotesType_NextLevel, NativeVotesType_ScrambleNow, NativeVotesType_SwapTeams,
		NativeVotesType_Surrender, NativeVotesType_Rematch, NativeVotesType_Continue:
		{
			return true;
		}
		
		case NativeVotesType_Custom_Mult, NativeVotesType_NextLevelMult:
		{
			// Until Valve fixes their menu code, this is false.
			return false;
		}
		
	}
	
	return false;
}

bool:CSGO_CheckVotePassType(NativeVotesPassType:passType)
{
	switch(passType)
	{
		case NativeVotesPass_Custom, NativeVotesPass_Restart, NativeVotesPass_Kick,
		NativeVotesPass_ChgLevel, NativeVotesPass_NextLevel, NativeVotesPass_Extend,
		NativeVotesPass_Scramble, NativeVotesPass_SwapTeams, NativeVotesPass_Surrender,
		NativeVotesPass_Rematch, NativeVotesPass_Continue:
		{
			return true;
		}
	}
	
	return false;
}

bool:CSGO_VoteTypeToTranslation(NativeVotesType:voteType, String:translation[], maxlength)
{
	new bool:bYesNo = true;
	switch(voteType)
	{
		case NativeVotesType_Custom_Mult:
		{
			strcopy(translation, maxlength, CSGO_VOTE_CUSTOM);
			bYesNo = false;
		}
		
		case NativeVotesType_Restart:
		{
			strcopy(translation, maxlength, CSGO_VOTE_RESTART_START);
		}
		
		case NativeVotesType_Kick:
		{
			strcopy(translation, maxlength, CSGO_VOTE_KICK_START);
		}
		
		case NativeVotesType_KickIdle:
		{
			strcopy(translation, maxlength, CSGO_VOTE_KICK_IDLE_START);
		}
		
		case NativeVotesType_KickScamming:
		{
			strcopy(translation, maxlength, CSGO_VOTE_KICK_SCAMMING_START);
		}
		
		case NativeVotesType_KickCheating:
		{
			strcopy(translation, maxlength, CSGO_VOTE_KICK_CHEATING_START);
		}
		
		case NativeVotesType_ChgLevel:
		{
			strcopy(translation, maxlength, CSGO_VOTE_CHANGELEVEL_START);
		}
		
		case NativeVotesType_NextLevel:
		{
			strcopy(translation, maxlength, CSGO_VOTE_NEXTLEVEL_SINGLE_START);
		}
		
		case NativeVotesType_NextLevelMult:
		{
			
			strcopy(translation, maxlength, CSGO_VOTE_NEXTLEVEL_MULTIPLE_START);
			bYesNo = false;
		}
		
		case NativeVotesType_ScrambleNow:
		{
			strcopy(translation, maxlength, CSGO_VOTE_SCRAMBLE_START);
		}
		
		case NativeVotesType_SwapTeams:
		{
			strcopy(translation, maxlength, CSGO_VOTE_SWAPTEAMS_START);
		}
		
		case NativeVotesType_Surrender:
		{
			strcopy(translation, maxlength, CSGO_VOTE_SURRENDER_START);
		}
		
		case NativeVotesType_Rematch:
		{
			strcopy(translation, maxlength, CSGO_VOTE_REMATCH_START);
		}
		
		case NativeVotesType_Continue:
		{
			strcopy(translation, maxlength, CSGO_VOTE_CONTINUE_START);
		}
		
		default:
		{
			strcopy(translation, maxlength, CSGO_VOTE_CUSTOM);
		}
	}
	
	return bYesNo;
}

CSGO_VotePassToTranslation(NativeVotesPassType:passType, String:translation[], maxlength)
{
	switch(passType)
	{
		case NativeVotesPass_Restart:
		{
			strcopy(translation, maxlength, CSGO_VOTE_RESTART_PASSED);
		}
		
		case NativeVotesPass_Kick:
		{
			strcopy(translation, maxlength, CSGO_VOTE_KICK_PASSED);
		}
		
		case NativeVotesPass_ChgLevel:
		{
			strcopy(translation, maxlength, CSGO_VOTE_CHANGELEVEL_PASSED);
		}
		
		case NativeVotesPass_NextLevel:
		{
			strcopy(translation, maxlength, CSGO_VOTE_NEXTLEVEL_PASSED);
		}
		
		case NativeVotesPass_Extend:
		{
			strcopy(translation, maxlength, CSGO_VOTE_NEXTLEVEL_EXTEND_PASSED);
		}
		
		case NativeVotesPass_Scramble:
		{
			strcopy(translation, maxlength, CSGO_VOTE_SCRAMBLE_PASSED);
		}
		
		case NativeVotesPass_SwapTeams:
		{
			strcopy(translation, maxlength, CSGO_VOTE_SWAPTEAMS_PASSED);
		}
		
		case NativeVotesPass_Surrender:
		{
			strcopy(translation, maxlength, CSGO_VOTE_SURRENDER_PASSED);
		}
		
		case NativeVotesPass_Rematch:
		{
			strcopy(translation, maxlength, CSGO_VOTE_REMATCH_PASSED);
		}
		
		case NativeVotesPass_Continue:
		{
			strcopy(translation, maxlength, CSGO_VOTE_CONTINUE_PASSED);
		}
		
		default:
		{
			strcopy(translation, maxlength, CSGO_VOTE_CUSTOM);
		}
	}
}

CSGO_VoteTypeToVoteOtherTeamString(NativeVotesType:voteType, String:otherTeamString[], maxlength)
{
	switch(voteType)
	{
		case NativeVotesType_Kick:
		{
			strcopy(otherTeamString, maxlength, CSGO_VOTE_KICK_OTHERTEAM);
		}
		
		case NativeVotesType_Surrender:
		{
			strcopy(otherTeamString, maxlength, CSGO_VOTE_SURRENDER_OTHERTEAM);
		}
		
		case NativeVotesType_Continue:
		{
			strcopy(otherTeamString, maxlength, CSGO_VOTE_CONTINUE_OTHERTEAM);
		}
		
		default:
		{
			strcopy(otherTeamString, maxlength, CSGO_VOTE_UNIMPLEMENTED_OTHERTEAM);
		}
	}

}

