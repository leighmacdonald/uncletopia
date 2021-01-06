/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Vote Tester
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
#include <nativevotes>

#define VERSION "1.0"

public Plugin:myinfo = 
{
	name = "NativeVotes Vote Tester",
	author = "Powerlord",
	description = "Various NativeVotes vote type tests",
	version = "1.0",
	url = "https://forums.alliedmods.net/showthread.php?t=208008"
}

public OnPluginStart()
{
	CreateConVar("nativevotestest_version", VERSION, "NativeVotes Vote Tester version", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegAdminCmd("voteyesno", Cmd_TestYesNo, ADMFLAG_VOTE, "Test Yes/No votes");
	RegAdminCmd("votemult", Cmd_TestMult, ADMFLAG_VOTE, "Test Multiple Choice votes");
	RegAdminCmd("voteyesnocustom", Cmd_TestYesNoCustom, ADMFLAG_VOTE, "Test Multiple Choice vote with Custom Display text");
	RegAdminCmd("votemultcustom", Cmd_TestMultCustom, ADMFLAG_VOTE, "Test Multiple Choice vote with Custom Display text");
}

public Action:Cmd_TestYesNo(client, args)
{
	if (!NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		ReplyToCommand(client, "Game does not support Custom Yes/No votes.");
		return Plugin_Handled;
	}
	
	if (!NativeVotes_IsNewVoteAllowed())
	{
		new seconds = NativeVotes_CheckVoteDelay();
		ReplyToCommand(client, "Vote is not allowed for %d more seconds", seconds);
	}
	
	new Handle:vote = NativeVotes_Create(YesNoHandler, NativeVotesType_Custom_YesNo);
	
	NativeVotes_SetInitiator(vote, client);
	NativeVotes_SetDetails(vote, "Test Yes/No Vote");
	NativeVotes_DisplayToAll(vote, 30);
	
	return Plugin_Handled;
}

public YesNoHandler(Handle:vote, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
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
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else
			{
				NativeVotes_DisplayPass(vote, "Test Yes/No Vote Passed!");
				// Do something because it passed
			}
		}
	}
}

public Action:Cmd_TestMult(client, args)
{
	if (!NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_Mult))
	{
		ReplyToCommand(client, "Game does not support Custom Multiple Choice votes.");
		return Plugin_Handled;
	}

	if (!NativeVotes_IsNewVoteAllowed())
	{
		new seconds = NativeVotes_CheckVoteDelay();
		ReplyToCommand(client, "Vote is not allowed for %d more seconds", seconds);
	}
	
	new Handle:vote = NativeVotes_Create(MultHandler, NativeVotesType_Custom_Mult);
	
	NativeVotes_SetInitiator(vote, client);
	NativeVotes_SetDetails(vote, "Test Mult Vote");
	NativeVotes_AddItem(vote, "choice1", "Choice 1");
	NativeVotes_AddItem(vote, "choice2", "Choice 2");
	NativeVotes_AddItem(vote, "choice3", "Choice 3");
	NativeVotes_AddItem(vote, "choice4", "Choice 4");
	NativeVotes_AddItem(vote, "choice5", "Choice 5");
	// 5 is currently the maximum number of choices in any game
	NativeVotes_DisplayToAll(vote, 30);
	
	return Plugin_Handled;
}

public MultHandler(Handle:vote, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
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
			new String:info[64];
			new String:display[64];
			NativeVotes_GetItem(vote, param1, info, sizeof(info), display, sizeof(display));
			
			NativeVotes_DisplayPass(vote, display);
			
			// Do something with info
		}
	}
}

public Action:Cmd_TestYesNoCustom(client, args)
{
	if (!NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		ReplyToCommand(client, "Game does not support Custom Yes/No votes.");
		return Plugin_Handled;
	}

	if (!NativeVotes_IsNewVoteAllowed())
	{
		new seconds = NativeVotes_CheckVoteDelay();
		ReplyToCommand(client, "Vote is not allowed for %d more seconds", seconds);
	}
	
	new Handle:vote = NativeVotes_Create(YesNoCustomHandler, NativeVotesType_Custom_YesNo, NATIVEVOTES_ACTIONS_DEFAULT|MenuAction_Display);
	
	NativeVotes_SetInitiator(vote, client);
	NativeVotes_SetDetails(vote, "Test Yes/No Vote");
	NativeVotes_DisplayToAll(vote, 30);
	
	return Plugin_Handled;
}

public YesNoCustomHandler(Handle:vote, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
		case MenuAction_Display:
		{
			new String:display[64];
			Format(display, sizeof(display), "%N Test Yes/No Vote", param1);
			PrintToChat(param1, "New Menu Title: %s", display);
			NativeVotes_RedrawVoteTitle(display);
			return _:Plugin_Changed;
		}
		
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
			if (param1 == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else
			{
				NativeVotes_DisplayPass(vote, "Test Custom Yes/No Vote Passed!");
				// Do something because it passed
			}
		}
	}
	
	return 0;
}

public Action:Cmd_TestMultCustom(client, args)
{
	if (!NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_Mult))
	{
		ReplyToCommand(client, "Game does not support Custom Multiple Choice votes.");
		return Plugin_Handled;
	}

	if (!NativeVotes_IsNewVoteAllowed())
	{
		new seconds = NativeVotes_CheckVoteDelay();
		ReplyToCommand(client, "Vote is not allowed for %d more seconds", seconds);
	}
	
	new Handle:vote = NativeVotes_Create(MultCustomHandler, NativeVotesType_Custom_Mult, NATIVEVOTES_ACTIONS_DEFAULT|MenuAction_Display|MenuAction_DisplayItem);
	
	NativeVotes_SetInitiator(vote, client);
	NativeVotes_SetDetails(vote, "Test Mult Vote");
	NativeVotes_AddItem(vote, "choice1", "Choice 1");
	NativeVotes_AddItem(vote, "choice2", "Choice 2");
	NativeVotes_AddItem(vote, "choice3", "Choice 3");
	NativeVotes_AddItem(vote, "choice4", "Choice 4");
	NativeVotes_AddItem(vote, "choice5", "Choice 5");
	// 5 is currently the maximum number of choices in any game
	NativeVotes_DisplayToAll(vote, 30);
	
	return Plugin_Handled;
}

public MultCustomHandler(Handle:vote, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			NativeVotes_Close(vote);
		}
		
		case MenuAction_Display:
		{
			new String:display[64];
			Format(display, sizeof(display), "%N Test Mult Vote", param1);
			PrintToChat(param1, "New Menu Title: %s", display);
			NativeVotes_RedrawVoteTitle(display);
			return _:Plugin_Changed;
		}
		
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
			new String:info[64];
			new String:display[64];
			NativeVotes_GetItem(vote, param1, info, sizeof(info), display, sizeof(display));
			
			// Do something with info
			//NativeVotes_DisplayPassCustom(vote, "%t Mult passed", "Translation Phrase");
			NativeVotes_DisplayPassCustom(vote, "%s passed", display);
		}
		
		case MenuAction_DisplayItem:
		{
			new String:info[64];
			new String:display[64];
			
			new String:buffer[64];
			
			NativeVotes_GetItem(vote, param2, info, sizeof(info), display, sizeof(display));
			
			// This is generally how you'd do translations, but normally with %T and a format phrase
			new bool:bReplace = false;
			if (StrEqual(info, "choice1"))
			{
				Format(buffer, sizeof(buffer), "%N %s", param1, display);
				bReplace = true;
			}
			else if (StrEqual(info, "choice2"))
			{
				Format(buffer, sizeof(buffer), "%N %s", param1, display);
				bReplace = true;
			}
			else if (StrEqual(info, "choice3"))
			{
				Format(buffer, sizeof(buffer), "%N %s", param1, display);
				bReplace = true;
			}
			else if (StrEqual(info, "choice4"))
			{
				Format(buffer, sizeof(buffer), "%N %s", param1, display);
				bReplace = true;
			}
			else if (StrEqual(info, "choice5"))
			{
				Format(buffer, sizeof(buffer), "%N %s", param1, display);
				bReplace = true;
			}
			
			PrintToChat(param1, "New Menu Item %d: %s", param2, buffer);
			
			if (bReplace)
			{
				NativeVotes_RedrawVoteItem(buffer);
				return _:Plugin_Changed;
			}
		}
	}
	
	return 0;
}

