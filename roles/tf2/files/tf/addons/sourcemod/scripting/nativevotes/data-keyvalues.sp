/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes
 * Copyright (C) 2011-2012 Ross Bemrose (Powerlord).  All rights reserved.
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

#if defined _nativevotes_data_included
 #endinput
#endif

#define _nativevotes_data_included

#include <sourcemod>

#define INFO_LENGTH 128
#define INFO "item_info"
#define DISPLAY "item_display"

bool:Data_GetItemInfo(Handle:vote, item, String:choice[], choiceSize)
{
	if (item >= Data_GetItemCount(vote))
	{
		return false;
	}
	
	new Handle:array = Handle:KvGetNum(vote, INFO, _:INVALID_HANDLE);

	// Shouldn't happen, but just in case...
	if (array == INVALID_HANDLE)
	{
		return false;
	}
	
	GetArrayString(array, item, choice, choiceSize);
	return true;
}

bool:Data_GetItemDisplay(Handle:vote, item, String:choice[], choiceSize)
{
	if (item >= Data_GetItemCount(vote))
	{
		return false;
	}
	
	new Handle:array = Handle:KvGetNum(vote, DISPLAY, _:INVALID_HANDLE);

	// Shouldn't happen, but just in case...
	if (array == INVALID_HANDLE)
	{
		return false;
	}
	
	GetArrayString(array, item, choice, choiceSize);
	return true;
}

Data_GetItemCount(Handle:vote)
{
	new Handle:array = Handle:KvGetNum(vote, INFO, _:INVALID_HANDLE);
	if (array == INVALID_HANDLE)
	{
		return 0;
	}
	
	return GetArraySize(array);
}

Data_GetTeam(Handle:vote)
{
	return KvGetNum(vote, "team", NATIVEVOTES_ALL_TEAMS);
}

Data_SetTeam(Handle:vote, team)
{
	KvSetNum(vote, "team", team);
}

Data_GetInitiator(Handle:vote)
{
	return KvGetNum(vote, "initiator", NATIVEVOTES_SERVER_INDEX);
}

Data_SetInitiator(Handle:vote, initiator)
{
	KvSetNum(vote, "initiator", initiator);
}

Data_GetDetails(Handle:vote, String:details[], maxlength)
{
	KvGetString(vote, "details", details, maxlength);
}

Data_SetDetails(Handle:vote, const String:details[])
{
	KvSetString(vote, "details", details);
}

Data_GetTitle(Handle:vote, String:title[], maxlength)
{
	// Shim for older code that sets custom vote titles in details
	KvGetString(vote, "custom_title", title, maxlength);
	if (strlen(title) == 0)
	{
		KvGetString(vote, "details", title, maxlength);
	}
}

Data_SetTitle(Handle:vote, const String:title[])
{
	KvSetString(vote, "custom_title", title);
}

Data_GetTarget(Handle:vote)
{
	return KvGetNum(vote, "target");
}

Data_SetTarget(Handle:vote, target)
{
	KvSetNum(vote, "target", target);
}

Data_GetTargetSteam(Handle:vote, String:steamId[], maxlength)
{
	KvGetString(vote, "target_steam", steamId, maxlength);
}

Data_SetTargetSteam(Handle:vote, const String:steamId[])
{
	KvSetString(vote, "target_steam", steamId);	
}

NativeVotesType:Data_GetType(Handle:vote)
{
	return NativeVotesType:KvGetNum(vote, "vote_type", _:NativeVotesType_Custom_YesNo);
}

Handle:Data_GetHandler(Handle:vote)
{
	if (vote == INVALID_HANDLE)
		return INVALID_HANDLE;
	
	return Handle:KvGetNum(vote, "handler_callback");
}

Handle:Data_GetResultCallback(Handle:vote)
{
	if (vote == INVALID_HANDLE)
		return INVALID_HANDLE;
	
	return Handle:KvGetNum(vote, "result_callback");
}

Handle:Data_CreateVote(NativeVotesType:voteType, MenuAction:actions)
{
	new Handle:handler = CreateForward(ET_Single, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
	new Handle:voteResults = CreateForward(ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Array, Param_Array, Param_Cell, Param_Array, Param_Array);
	
	new Handle:vote = CreateKeyValues("NativeVote");

	KvSetNum(vote, "handler_callback", _:handler);
	KvSetNum(vote, "vote_type", _:voteType);
	KvSetString(vote, "details", "");
	KvSetNum(vote, "target", 0);
	KvSetString(vote, "target_steam", "");
	KvSetNum(vote, "actions", _:actions);
	KvSetNum(vote, "result_callback", _:voteResults);
	KvSetNum(vote, "initiator", NATIVEVOTES_SERVER_INDEX);
	if (g_EngineVersion == Engine_TF2)
	{
		KvSetNum(vote, "team", NATIVEVOTES_TF2_ALL_TEAMS);
	}
	else
	{
		KvSetNum(vote, "team", NATIVEVOTES_ALL_TEAMS);
	}
	KvSetString(vote, "custom_title", "");
	
	KvSetNum(vote, INFO, _:CreateArray(ByteCountToCells(INFO_LENGTH)));
	KvSetNum(vote, DISPLAY, _:CreateArray(ByteCountToCells(INFO_LENGTH)));
	
	return vote;
}

MenuAction:Data_GetActions(Handle:vote)
{
	return MenuAction:KvGetNum(vote, "actions");
}

bool:Data_AddItem(Handle:vote, const String:info[], const String:display[])
{
	new Handle:infoArray = Handle:KvGetNum(vote, INFO, _:INVALID_HANDLE);
	new Handle:displayArray = Handle:KvGetNum(vote, DISPLAY, _:INVALID_HANDLE);
	
	if (infoArray == INVALID_HANDLE || displayArray == INVALID_HANDLE ||
		GetArraySize(infoArray) >= Game_GetMaxItems() ||
		GetArraySize(displayArray) >= Game_GetMaxItems())
	{
		return false;
	}
	
	PushArrayString(infoArray, info);
	PushArrayString(displayArray, display);
	
	return true;
}

bool:Data_InsertItem(Handle:vote, position, const String:info[], const String:display[])
{
	new Handle:infoArray = Handle:KvGetNum(vote, INFO, _:INVALID_HANDLE);
	new Handle:displayArray = Handle:KvGetNum(vote, DISPLAY, _:INVALID_HANDLE);
	
	if (infoArray == INVALID_HANDLE || displayArray == INVALID_HANDLE ||
		GetArraySize(infoArray) >= Game_GetMaxItems() ||
		GetArraySize(displayArray) >= Game_GetMaxItems() ||
		position >= GetArraySize(infoArray))
	{
		return false;
	}
	
	ShiftArrayUp(infoArray, position);
	ShiftArrayUp(displayArray, position);

	SetArrayString(infoArray, position, info);
	SetArrayString(displayArray, position, display);
	
	return true;
}

bool:Data_RemoveItem(Handle:vote, position)
{
	new Handle:infoArray = Handle:KvGetNum(vote, INFO, _:INVALID_HANDLE);
	new Handle:displayArray = Handle:KvGetNum(vote, DISPLAY, _:INVALID_HANDLE);
	
	if (infoArray == INVALID_HANDLE || displayArray == INVALID_HANDLE ||
		position >= GetArraySize(infoArray) || position < 0)
	{
		return false;
	}
	
	RemoveFromArray(infoArray, position);
	RemoveFromArray(displayArray, position);

	return true;
}

Data_RemoveAllItems(Handle:vote)
{
	new Handle:infoArray = Handle:KvGetNum(vote, INFO, _:INVALID_HANDLE);
	new Handle:displayArray = Handle:KvGetNum(vote, DISPLAY, _:INVALID_HANDLE);
	
	ClearArray(infoArray);
	ClearArray(displayArray);
}

Data_CloseVote(Handle:vote)
{
	if (vote == INVALID_HANDLE)
	{
		return;
	}
	
	new Handle:handler = Handle:KvGetNum(vote, "handler_callback", _:INVALID_HANDLE);
	if (handler != INVALID_HANDLE)
	{
		CloseHandle(handler);
	}
	
	new Handle:voteResults = Handle:KvGetNum(vote, "results_callback", _:INVALID_HANDLE);
	if (voteResults != INVALID_HANDLE)
	{
		CloseHandle(voteResults);
	}
	
	new Handle:infoArray = Handle:KvGetNum(vote, INFO, _:INVALID_HANDLE);
	
	if (infoArray != INVALID_HANDLE)
	{
		CloseHandle(infoArray);
	}
	
	new Handle:displayArray = Handle:KvGetNum(vote, DISPLAY, _:INVALID_HANDLE);
	if (displayArray != INVALID_HANDLE)
	{
		CloseHandle(displayArray);
	}
	
	CloseHandle(vote);
}
