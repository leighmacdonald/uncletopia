/**
 * vim: set ts=4 :
 * =============================================================================
 * NativeVotes Basic Votes Plugin
 * Implements basic vote commands using NativeVotes.
 * Based on the SourceMod version.
 *
 * NativeVotes (C)2011-2014 Ross Bemrose (Powerlord).  All rights reserved.
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
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

#pragma semicolon 1

#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <nativevotes>

#define VERSION "1.5.3"

public Plugin:myinfo =
{
	name = "NativeVotes Basic Votes",
	author = "Powerlord and AlliedModders LLC",
	description = "NativeVotes Basic Vote Commands",
	version = VERSION,
	url = ""
};

#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

//new Handle:g_hVoteMenu = INVALID_HANDLE;

new Handle:g_Cvar_Limits[3] = {INVALID_HANDLE, ...};
//new Handle:g_Cvar_VoteSay = INVALID_HANDLE;

enum voteType
{
	map,
	kick,
	ban,
	question
}

new voteType:g_voteType = voteType:question;

// Menu API does not provide us with a way to pass multiple peices of data with a single
// choice, so some globals are used to hold stuff.
//
#define VOTE_CLIENTID	0
#define VOTE_USERID	1
new g_voteClient[2];		/* Holds the target's client id and user id */

#define VOTE_NAME	0
#define VOTE_AUTHID	1
#define	VOTE_IP		2
new String:g_voteInfo[3][65];	/* Holds the target's name, authid, and IP */

new String:g_voteArg[256];	/* Used to hold ban/kick reasons or vote questions */


new Handle:hTopMenu = INVALID_HANDLE;

// NativeVotes
new bool:g_NativeVotes;

//new g_Cvar_NativeVotesMenu = INVALID_HANDLE;

#include "nativevotes-basevotes/votekick.sp"
#include "nativevotes-basevotes/voteban.sp"
#include "nativevotes-basevotes/votemap.sp"

public OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("basevotes.phrases");
	LoadTranslations("plugin.basecommands");
	LoadTranslations("basebans.phrases");
	
	RegAdminCmd("sm_votemap", Command_Votemap, ADMFLAG_VOTE|ADMFLAG_CHANGEMAP, "sm_votemap <mapname> [mapname2] ... [mapname5] ");
	RegAdminCmd("sm_votekick", Command_Votekick, ADMFLAG_VOTE|ADMFLAG_KICK, "sm_votekick <player> [reason]");
	RegAdminCmd("sm_voteban", Command_Voteban, ADMFLAG_VOTE|ADMFLAG_BAN, "sm_voteban <player> [reason]");
	RegAdminCmd("sm_vote", Command_Vote, ADMFLAG_VOTE, "sm_vote <question> [Answer1] [Answer2] ... [Answer5]");

	/*
	g_Cvar_Show = FindConVar("sm_vote_show");
	if (g_Cvar_Show == INVALID_HANDLE)
	{
		g_Cvar_Show = CreateConVar("sm_vote_show", "1", "Show player's votes? Default on.", 0, true, 0.0, true, 1.0);
	}
	*/

	g_Cvar_Limits[0] = CreateConVar("sm_vote_map", "0.60", "percent required for successful map vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[1] = CreateConVar("sm_vote_kick", "0.60", "percent required for successful kick vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[2] = CreateConVar("sm_vote_ban", "0.60", "percent required for successful ban vote.", 0, true, 0.05, true, 1.0);
	CreateConVar("nativevotes_basevotes_version", VERSION, "NativeVotes Basic Votes version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);
	
	g_SelectedMaps = CreateArray(PLATFORM_MAX_PATH);
	
	g_MapList = CreateMenu(MenuHandler_Map, MenuAction_DrawItem|MenuAction_Display);
	SetMenuTitle(g_MapList, "%T", "Please select a map", LANG_SERVER);
	SetMenuExitBackButton(g_MapList, true);
	
	decl String:mapListPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapListPath, sizeof(mapListPath), "configs/adminmenu_maplist.ini");
	SetMapListCompatBind("sm_votemap menu", mapListPath);
}

public OnAllPluginsLoaded()
{
	if (FindPluginByFile("basevotes.smx") != INVALID_HANDLE)
	{
		SetFailState("This plugin replaces basevotes.  You cannot run both at once.");
	}
	
	/* Account for late loading */
	new Handle:topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	
	g_NativeVotes = LibraryExists("nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo);
}

public OnLibraryAdded(const String:name[])
{
	new Handle:topmenu;
	if (StrEqual(name, "adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
	{
		OnAdminMenuReady(topmenu);
	}
	else
	if (StrEqual(name, "nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		g_NativeVotes = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "adminmenu"))
	{
		hTopMenu = INVALID_HANDLE;
	}
	else
	if (StrEqual(name, "nativevotes"))
	{
		g_NativeVotes = false;
	}
}

public OnConfigsExecuted()
{
	g_mapCount = LoadMapList(g_MapList);
}

public OnAdminMenuReady(Handle:topmenu)
{
	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Build the "Voting Commands" category */
	new TopMenuObject:voting_commands = FindTopMenuCategory(hTopMenu, ADMINMENU_VOTINGCOMMANDS);

	if (voting_commands != INVALID_TOPMENUOBJECT)
	{
		AddToTopMenu(hTopMenu,
			"sm_votekick",
			TopMenuObject_Item,
			AdminMenu_VoteKick,
			voting_commands,
			"sm_votekick",
			ADMFLAG_VOTE|ADMFLAG_KICK);
			
		AddToTopMenu(hTopMenu,
			"sm_voteban",
			TopMenuObject_Item,
			AdminMenu_VoteBan,
			voting_commands,
			"sm_voteban",
			ADMFLAG_VOTE|ADMFLAG_BAN);
			
		AddToTopMenu(hTopMenu,
			"sm_votemap",
			TopMenuObject_Item,
			AdminMenu_VoteMap,
			voting_commands,
			"sm_votemap",
			ADMFLAG_VOTE|ADMFLAG_CHANGEMAP);
	}
}

public Action:Command_Vote(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_vote <question> [Answer1] [Answer2] ... [Answer5]");
		return Plugin_Handled;	
	}
	
	if (Internal_IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] %t", "Vote in Progress");
		return Plugin_Handled;
	}
		
	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	decl String:text[256];
	GetCmdArgString(text, sizeof(text));

	decl String:answers[5][64];
	new answerCount;	
	new len = BreakString(text, g_voteArg, sizeof(g_voteArg));
	new pos = len;
	
	while (args > 1 && pos != -1 && answerCount < 5)
	{	
		pos = BreakString(text[len], answers[answerCount], sizeof(answers[]));
		answerCount++;
		
		if (pos != -1)
		{
			len += pos;
		}	
	}

	LogAction(client, -1, "\"%L\" initiated a generic vote.", client);
	ShowActivity2(client, "[SM] ", "%t", "Initiate Vote", g_voteArg);
	
	g_voteType = voteType:question;
	new Handle:voteMenu;
    
	if (g_NativeVotes && (answerCount < 2 || NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_Mult)) )
	{
		new NativeVotesType:nVoteType = answerCount < 2 ? NativeVotesType_Custom_YesNo : NativeVotesType_Custom_Mult;
		
		voteMenu = NativeVotes_Create(Handler_NativeVoteCallback, nVoteType, MenuAction:MENU_ACTIONS_ALL);
		NativeVotes_SetTitle(voteMenu, g_voteArg);
		
		if (answerCount >= 2)
		{
			for (new i = 0; i < answerCount; i++)
			{
				NativeVotes_AddItem(voteMenu, answers[i], answers[i]);
			}	
		}
		
		//NativeVotes_SetInitiator(voteMenu, client);
		NativeVotes_DisplayToAll(voteMenu, 20);
	}
	else
	{
		voteMenu = CreateMenu(Handler_VoteCallback, MenuAction:MENU_ACTIONS_ALL);
		SetMenuTitle(voteMenu, "%s?", g_voteArg);
		
		if (answerCount < 2)
		{
			AddMenuItem(voteMenu, VOTE_YES, "Yes");
			AddMenuItem(voteMenu, VOTE_NO, "No");
		}
		else
		{
			for (new i = 0; i < answerCount; i++)
			{
				AddMenuItem(voteMenu, answers[i], answers[i]);
			}	
		}
		
		SetMenuExitButton(voteMenu, false);
		VoteMenuToAll(voteMenu, 20);		
	}
	return Plugin_Handled;	
}

public Handler_VoteCallback(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			//VoteMenuClose();
			CloseHandle(menu);
		}
		
		case MenuAction_Display:
		{
			if (g_voteType != voteType:question)
			{
				decl String:title[64];
				GetMenuTitle(menu, title, sizeof(title));
				
				decl String:buffer[255];
				Format(buffer, sizeof(buffer), "%T", title, param1, g_voteInfo[VOTE_NAME]);

				new Handle:panel = Handle:param2;
				SetPanelTitle(panel, buffer);
			}
		}
		
		case MenuAction_DisplayItem:
		{
			decl String:display[64];
			GetMenuItem(menu, param2, "", 0, _, display, sizeof(display));
		 
			if (strcmp(display, "No") == 0 || strcmp(display, "Yes") == 0)
			{
				decl String:buffer[255];
				Format(buffer, sizeof(buffer), "%T", display, param1);

				return RedrawMenuItem(buffer);
			}
		}
		
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				PrintToChatAll("[SM] %t", "No Votes Cast");
			}
		}
		
		case MenuAction_VoteEnd:
		{
			decl String:item[64], String:display[64];
			new Float:percent, Float:limit, votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			GetMenuItem(menu, param1, item, sizeof(item), _, display, sizeof(display));
			
			if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}
			
			percent = GetVotePercent(votes, totalVotes);
			
			if (g_voteType != voteType:question)
			{
				limit = GetConVarFloat(g_Cvar_Limits[g_voteType]);
			}
			
			/* :TODO: g_voteClient[userid] needs to be checked */

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
			{
				/* :TODO: g_voteClient[userid] should be used here and set to -1 if not applicable.
				 */
				LogAction(-1, -1, "Vote failed.");
				PrintToChatAll("[SM] %t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			}
			else
			{
				PrintToChatAll("[SM] %t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
				
				switch (g_voteType)
				{
					case (voteType:question):
					{
						if (strcmp(item, VOTE_NO) == 0 || strcmp(item, VOTE_YES) == 0)
						{
							for (new i = 1; i <= MaxClients; i++)
							{
								if (IsClientInGame(i) && !IsFakeClient(i))
								{
									Format(item, sizeof(item), "%T", display, i);
									PrintToChat(i, "[SM] %t", "Vote End", g_voteArg, item);
								}
							}
						}
						else
						{
							PrintToChatAll("[SM] %t", "Vote End", g_voteArg, item);
						}
					}
					
					case (voteType:map):
					{
						LogAction(-1, -1, "Changing map to %s due to vote.", item);
						PrintToChatAll("[SM] %t", "Changing map", item);
						new Handle:dp;
						CreateDataTimer(5.0, Timer_ChangeMap, dp);
						WritePackString(dp, item);		
					}
						
					case (voteType:kick):
					{
						if (g_voteArg[0] == '\0')
						{
							strcopy(g_voteArg, sizeof(g_voteArg), "Votekicked");
						}
						
						if (GetClientOfUserId(g_voteClient[VOTE_USERID]) > 0 && !IsClientInKickQueue(g_voteClient[VOTE_CLIENTID]))
						{
							PrintToChatAll("[SM] %t", "Kicked target", "_s", g_voteInfo[VOTE_NAME]);					
							LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote kick successful, kicked \"%L\" (reason \"%s\")", g_voteClient[VOTE_CLIENTID], g_voteArg);

							KickClient(g_voteClient[VOTE_CLIENTID], "%s", g_voteArg);
						}
						
					}
						
					case (voteType:ban):
					{
						if (g_voteArg[0] == '\0')
						{
							strcopy(g_voteArg, sizeof(g_voteArg), "Votebanned");
						}
						
						if (GetClientOfUserId(g_voteClient[VOTE_USERID]) > 0)
						{
							PrintToChatAll("[SM] %t", "Banned player", g_voteInfo[VOTE_NAME], 30);
							LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote ban successful, banned \"%L\" (minutes \"30\") (reason \"%s\")", g_voteClient[VOTE_CLIENTID], g_voteArg);

							BanClient(g_voteClient[VOTE_CLIENTID],
									  30,
									  BANFLAG_AUTO,
									  g_voteArg,
									  "Banned by vote",
									  "sm_voteban");
						}
					}
				}
			}
		}
	}
	
	return 0;
}

public Handler_NativeVoteCallback(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		
		case MenuAction_End:
		{
			NativeVotes_Close(menu);
		}
		
		case MenuAction_Display:
		{
			new NativeVotesType:nVoteType = NativeVotes_GetType(menu);
			if (g_voteType != voteType:question && (nVoteType == NativeVotesType_Custom_YesNo || nVoteType == NativeVotesType_Custom_Mult))
			{
				decl String:title[64];
				NativeVotes_GetTitle(menu, title, sizeof(title));
				
				decl String:buffer[255];
				Format(buffer, sizeof(buffer), "%T", title, param1, g_voteInfo[VOTE_NAME]);

				return _:NativeVotes_RedrawVoteTitle(buffer);
			}
		}
		
		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				NativeVotes_DisplayFail(menu, NativeVotesFail_NotEnoughVotes);
				PrintToChatAll("[SM] %t", "No Votes Cast");
			}
			else
			{
				NativeVotes_DisplayFail(menu, NativeVotesFail_Generic);
			}
		}
		
		case MenuAction_VoteEnd:
		{
			decl String:item[64], String:display[64];
			new Float:percent, Float:limit, votes, totalVotes;
			
			new NativeVotesType:nVoteType = NativeVotes_GetType(menu);

			NativeVotes_GetInfo(param2, votes, totalVotes);
			NativeVotes_GetItem(menu, param1, item, sizeof(item), display, sizeof(display));
			
			if (nVoteType == NativeVotesType_Custom_YesNo && param1 == NATIVEVOTES_VOTE_NO)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}
			
			percent = GetVotePercent(votes, totalVotes);
			
			if (g_voteType != voteType:question)
			{
				limit = GetConVarFloat(g_Cvar_Limits[g_voteType]);
			}
			
			/* :TODO: g_voteClient[userid] needs to be checked */

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((nVoteType != NativeVotesType_NextLevelMult && nVoteType != NativeVotesType_Custom_Mult) && ((param1 == NATIVEVOTES_VOTE_YES && FloatCompare(percent,limit) < 0) || (param1 == NATIVEVOTES_VOTE_NO)))
			{
				/* :TODO: g_voteClient[userid] should be used here and set to -1 if not applicable.
				 */
				NativeVotes_DisplayFail(menu, NativeVotesFail_Loses);
				LogAction(-1, -1, "Vote failed.");
				PrintToChatAll("[SM] %t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			}
			else
			{
				PrintToChatAll("[SM] %t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
				
				switch (g_voteType)
				{
					case (voteType:question):
					{
						if (nVoteType == NativeVotesType_Custom_YesNo)
						{
							for (new i = 1; i <= MaxClients; i++)
							{
								if (IsClientInGame(i) && !IsFakeClient(i))
								{
									Format(item, sizeof(item), "%T", display, i);
									PrintToChat(i, "[SM] %t", "Vote End", g_voteArg, item);
									NativeVotes_DisplayPassCustomToOne(menu, i, "%t", "Vote End", g_voteArg, item);
								}
							}
						}
						else
						{
							PrintToChatAll("[SM] %t", "Vote End", g_voteArg, item);
							NativeVotes_DisplayPassCustom(menu, "%t", "Vote End", g_voteArg, item);
						}
					}
					
					case (voteType:map):
					{
						if (nVoteType == NativeVotesType_ChgLevel)
						{
							NativeVotes_GetDetails(menu, item, sizeof(item));
						}
						
						//NativeVotes_DisplayPass(menu, item);
						NativeVotes_DisplayPassEx(menu, NativeVotesPass_ChgLevel, item);
						LogAction(-1, -1, "Changing map to %s due to vote.", item);
						PrintToChatAll("[SM] %t", "Changing map", item);
						new Handle:dp;
						CreateDataTimer(5.0, Timer_ChangeMap, dp);
						WritePackString(dp, item);		
					}
						
					case (voteType:kick):
					{
						if (g_voteArg[0] == '\0')
						{
							strcopy(g_voteArg, sizeof(g_voteArg), "Votekicked");
						}
						
						if (GetClientOfUserId(g_voteClient[VOTE_USERID]) > 0 && !IsClientInKickQueue(g_voteClient[VOTE_CLIENTID]))
						{
							PrintToChatAll("[SM] %t", "Kicked target", "_s", g_voteInfo[VOTE_NAME]);
							LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote kick successful, kicked \"%L\" (reason \"%s\")", g_voteClient[VOTE_CLIENTID], g_voteArg);
							
							KickClient(g_voteClient[VOTE_CLIENTID], "%s", g_voteArg);
							NativeVotes_DisplayPass(menu, g_voteInfo[VOTE_NAME]);
						}
					}
						
					case (voteType:ban):
					{
						if (g_voteArg[0] == '\0')
						{
							strcopy(g_voteArg, sizeof(g_voteArg), "Votebanned");
						}
						
						if (GetClientOfUserId(g_voteClient[VOTE_USERID]) > 0)
						{
							PrintToChatAll("[SM] %t", "Banned player", g_voteInfo[VOTE_NAME], 30);
							LogAction(-1, g_voteClient[VOTE_CLIENTID], "Vote ban successful, banned \"%L\" (minutes \"30\") (reason \"%s\")", g_voteClient[VOTE_CLIENTID], g_voteArg);
							
							BanClient(g_voteClient[VOTE_CLIENTID],
							30,
							BANFLAG_AUTO,
							g_voteArg,
							"Banned by vote",
							"sm_voteban");
							
							NativeVotes_DisplayPassCustom(menu, "[SM] %t", "Banned player", g_voteInfo[VOTE_NAME], 30);
						}
					}
				}
			}
		}
	}
	
	return 0;
}

/*
VoteSelect(Handle:menu, param1, param2 = 0)
{
	if (GetConVarInt(g_Cvar_VoteShow) == 1)
	{
		decl String:voter[64], String:junk[64], String:choice[64];
		GetClientName(param1, voter, sizeof(voter));
		GetMenuItem(menu, param2, junk, sizeof(junk), _, choice, sizeof(choice));
		PrintToChatAll("[SM] %T", "Vote Select", LANG_SERVER, voter, choice);
	}
}
*/

/*
VoteMenuClose()
{
	CloseHandle(g_hVoteMenu);
	g_hVoteMenu = INVALID_HANDLE;
}
*/

Float:GetVotePercent(votes, totalVotes)
{
	return float(votes) / float(totalVotes);
}

bool:TestVoteDelay(client)
{
 	new delay = Internal_CheckVoteDelay();
	
 	if (delay > 0)
 	{
 		if (delay > 60)
 		{
 			ReplyToCommand(client, "[SM] %t", "Vote Delay Minutes", delay % 60);
 		}
 		else
 		{
 			ReplyToCommand(client, "[SM] %t", "Vote Delay Seconds", delay);
 		}
 		
		if (g_NativeVotes)
		{
			NativeVotes_DisplayCallVoteFail(client, NativeVotesCallFail_Recent, delay);
		}
		
 		return false;
 	}
 	
	return true;
}

public Action:Timer_ChangeMap(Handle:timer, Handle:dp)
{
	decl String:mapname[65];
	
	ResetPack(dp);
	ReadPackString(dp, mapname, sizeof(mapname));
	
	ForceChangeLevel(mapname, "sm_votemap Result");
	
	return Plugin_Stop;
}

bool:Internal_IsVoteInProgress()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsVoteInProgress();
	}
	
	return IsVoteInProgress();	
}

Internal_CheckVoteDelay()
{
	if (g_NativeVotes)
	{
		return NativeVotes_CheckVoteDelay();
	}
	
	return CheckVoteDelay();	
}

bool:Internal_IsNewVoteAllowed()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsNewVoteAllowed();
	}

	return IsNewVoteAllowed();
}
