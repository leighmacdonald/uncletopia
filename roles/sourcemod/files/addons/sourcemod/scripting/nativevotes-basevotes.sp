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
#pragma newdecls required
#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <adminmenu>
#include <nativevotes>

#define VERSION "1.5.3"

public Plugin myinfo =
{
	name = "NativeVotes Basic Votes",
	author = "Powerlord and AlliedModders LLC",
	description = "NativeVotes Basic Vote Commands",
	version = VERSION,
	url = ""
};

#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

ConVar g_Cvar_Limits[3] = {null, ...};
// ConVar g_Cvar_VoteSay = null;

enum VoteType
{
	VoteType_Map,
	VoteType_Kick,
	VoteType_Ban,
	VoteType_Question
}

VoteType g_voteType = VoteType_Question;

// Menu API does not provide us with a way to pass multiple pieces of data with a single
// choice, so some globals are used to hold stuff.
//
#define VOTE_CLIENTID	0
#define VOTE_USERID	1
int g_voteClient[2];		/* Holds the target's client id and user id */

#define VOTE_NAME	0
#define VOTE_AUTHID	1
#define	VOTE_IP		2
char g_voteInfo[3][65];	/* Holds the target's name, authid, and IP */

char g_voteArg[256];	/* Used to hold ban/kick reasons or vote questions */


TopMenu hTopMenu;

// NativeVotes
bool g_NativeVotes;

// ConVar g_Cvar_NativeVotesMenu;

#include "nativevotes-basevotes/votekick.sp"
#include "nativevotes-basevotes/voteban.sp"
#include "nativevotes-basevotes/votemap.sp"

public void OnPluginStart()
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
	ConVar g_Cvar_Show = FindConVar("sm_vote_show");
	if (g_Cvar_Show == null)
	{
		g_Cvar_Show = CreateConVar("sm_vote_show", "1", "Show player's votes? Default on.", 0, true, 0.0, true, 1.0);
	}
	*/

	g_Cvar_Limits[0] = CreateConVar("sm_vote_map", "0.60", "percent required for successful map vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[1] = CreateConVar("sm_vote_kick", "0.60", "percent required for successful kick vote.", 0, true, 0.05, true, 1.0);
	g_Cvar_Limits[2] = CreateConVar("sm_vote_ban", "0.60", "percent required for successful ban vote.", 0, true, 0.05, true, 1.0);
	CreateConVar("nativevotes_basevotes_version", VERSION, "NativeVotes Basic Votes version", FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY);

	g_SelectedMaps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));

	g_MapList = new Menu(MenuHandler_Map, MenuAction_DrawItem|MenuAction_Display);
	g_MapList.SetTitle("%T", "Please select a map", LANG_SERVER);
	g_MapList.ExitBackButton = true;

	char mapListPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, mapListPath, sizeof(mapListPath), "configs/adminmenu_maplist.ini");
	SetMapListCompatBind("sm_votemap menu", mapListPath);
}

public void OnAllPluginsLoaded()
{
	if (FindPluginByFile("basevotes.smx") != null)
	{
		SetFailState("This plugin replaces basevotes.  You cannot run both at once.");
	}

	/* Account for late loading */
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}

	g_NativeVotes = LibraryExists("nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo);
}

public void OnLibraryAdded(const char[] name)
{
	TopMenu topmenu;
	if (StrEqual(name, "adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
	else if (StrEqual(name, "nativevotes") && NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_YesNo))
	{
		g_NativeVotes = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "adminmenu"))
	{
		hTopMenu = null;
	}
	else if (StrEqual(name, "nativevotes"))
	{
		g_NativeVotes = false;
	}
}

public void OnConfigsExecuted()
{
	g_mapCount = LoadMapList(g_MapList);
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}

	/* Save the Handle */
	hTopMenu = topmenu;

	/* Build the "Voting Commands" category */
	TopMenuObject voting_commands = hTopMenu.FindCategory(ADMINMENU_VOTINGCOMMANDS);

	if (voting_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_votekick", AdminMenu_VoteKick, voting_commands, "sm_votekick", ADMFLAG_VOTE|ADMFLAG_KICK);
		hTopMenu.AddItem("sm_voteban", AdminMenu_VoteBan, voting_commands, "sm_voteban", ADMFLAG_VOTE|ADMFLAG_BAN);
		hTopMenu.AddItem("sm_votemap", AdminMenu_VoteMap, voting_commands, "sm_votemap", ADMFLAG_VOTE|ADMFLAG_CHANGEMAP);
	}
}

public Action Command_Vote(int client, int args)
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

	char text[256];
	GetCmdArgString(text, sizeof(text));

	char answers[5][64];
	int answerCount;
	int len = BreakString(text, g_voteArg, sizeof(g_voteArg));
	int pos = len;

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

	g_voteType = VoteType_Question;

	if (g_NativeVotes && (answerCount < 2 || NativeVotes_IsVoteTypeSupported(NativeVotesType_Custom_Mult)) )
	{
		NativeVotesType nVoteType = answerCount < 2 ? NativeVotesType_Custom_YesNo : NativeVotesType_Custom_Mult;

		NativeVote voteMenu = NativeVotes_Create(Handler_NativeVoteCallback, nVoteType, MENU_ACTIONS_ALL);
		voteMenu.SetTitle(g_voteArg);

		if (answerCount >= 2)
		{
			for (int i = 0; i < answerCount; i++)
			{
				voteMenu.AddItem(answers[i], answers[i]);
			}
		}

		//voteMenu.SetInitiator(client);
		voteMenu.DisplayVoteToAll(20);
	}
	else
	{
		Menu voteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
		voteMenu.SetTitle("%s?", g_voteArg);

		if (answerCount < 2)
		{
			voteMenu.AddItem(VOTE_YES, "Yes");
			voteMenu.AddItem(VOTE_NO, "No");
		}
		else
		{
			for (int i = 0; i < answerCount; i++)
			{
				voteMenu.AddItem(answers[i], answers[i]);
			}
		}

		voteMenu.ExitButton = false;
		voteMenu.DisplayVoteToAll(20);
	}
	return Plugin_Handled;
}

public int Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			//VoteMenuClose();
			delete menu;
		}

		case MenuAction_Display:
		{
			if (g_voteType != VoteType_Question)
			{
				char title[64];
				menu.GetTitle(title, sizeof(title));

				char buffer[255];
				Format(buffer, sizeof(buffer), "%T", title, param1, g_voteInfo[VOTE_NAME]);

				Panel panel = view_as<Panel>(param2);
				panel.SetTitle(buffer);
			}
		}

		case MenuAction_DisplayItem:
		{
			char display[64];
			menu.GetItem(param2, "", 0, _, display, sizeof(display));

			if (strcmp(display, "No") == 0 || strcmp(display, "Yes") == 0)
			{
				char buffer[255];
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
			char item[64], display[64];
			float percent, limit;
			int votes, totalVotes;

			GetMenuVoteInfo(param2, votes, totalVotes);
			menu.GetItem(param1, item, sizeof(item), _, display, sizeof(display));

			if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}

			percent = GetVotePercent(votes, totalVotes);

			if (g_voteType != VoteType_Question)
			{
				limit = g_Cvar_Limits[g_voteType].FloatValue;
			}

			/* :TODO: g_voteClient[userid] needs to be checked */

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((strcmp(item, VOTE_YES) == 0 && percent < limit && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
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
					case VoteType_Question:
					{
						if (strcmp(item, VOTE_NO) == 0 || strcmp(item, VOTE_YES) == 0)
						{
							for (int i = 1; i <= MaxClients; i++)
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

					case VoteType_Map:
					{
						LogAction(-1, -1, "Changing map to %s due to vote.", item);
						PrintToChatAll("[SM] %t", "Changing map", item);
						DataPack dp;
						CreateDataTimer(5.0, Timer_ChangeMap, dp);
						dp.WriteString(item);
					}

					case VoteType_Kick:
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

					case VoteType_Ban:
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

public int Handler_NativeVoteCallback(NativeVote vote, MenuAction action, int param1, int param2)
{
	switch (action)
	{

		case MenuAction_End:
		{
			vote.Close();
		}

		case MenuAction_Display:
		{
			NativeVotesType nVoteType = vote.VoteType;
			if (g_voteType != VoteType_Question && (nVoteType == NativeVotesType_Custom_YesNo || nVoteType == NativeVotesType_Custom_Mult))
			{
				char title[64];
				vote.GetTitle(title, sizeof(title));

				char buffer[255];
				Format(buffer, sizeof(buffer), "%T", title, param1, g_voteInfo[VOTE_NAME]);

				return view_as<int>(NativeVotes_RedrawVoteTitle(buffer));
			}
		}

		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes)
			{
				vote.DisplayFail(NativeVotesFail_NotEnoughVotes);
				PrintToChatAll("[SM] %t", "No Votes Cast");
			}
			else
			{
				vote.DisplayFail(NativeVotesFail_Generic);
			}
		}

		case MenuAction_VoteEnd:
		{
			char item[64], display[64];
			float percent, limit;
			int votes, totalVotes;

			NativeVotesType nVoteType = vote.VoteType;

			NativeVotes_GetInfo(param2, votes, totalVotes);
			vote.GetItem(param1, item, sizeof(item), display, sizeof(display));

			if (nVoteType == NativeVotesType_Custom_YesNo && param1 == NATIVEVOTES_VOTE_NO)
			{
				votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
			}

			percent = GetVotePercent(votes, totalVotes);

			if (g_voteType != VoteType_Question)
			{
				limit = g_Cvar_Limits[g_voteType].FloatValue;
			}

			/* :TODO: g_voteClient[userid] needs to be checked */

			// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
			if ((nVoteType != NativeVotesType_NextLevelMult && nVoteType != NativeVotesType_Custom_Mult) && ((param1 == NATIVEVOTES_VOTE_YES && percent < limit) || (param1 == NATIVEVOTES_VOTE_NO)))
			{
				/* :TODO: g_voteClient[userid] should be used here and set to -1 if not applicable.
				 */
				vote.DisplayFail(NativeVotesFail_Loses);
				LogAction(-1, -1, "Vote failed.");
				PrintToChatAll("[SM] %t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
			}
			else
			{
				PrintToChatAll("[SM] %t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);

				switch (g_voteType)
				{
					case VoteType_Question:
					{
						if (nVoteType == NativeVotesType_Custom_YesNo)
						{
							for (int i = 1; i <= MaxClients; i++)
							{
								if (IsClientInGame(i) && !IsFakeClient(i))
								{
									Format(item, sizeof(item), "%T", display, i);
									PrintToChat(i, "[SM] %t", "Vote End", g_voteArg, item);
									vote.DisplayPassCustomToOne(i, "%t", "Vote End", g_voteArg, item);
								}
							}
						}
						else
						{
							PrintToChatAll("[SM] %t", "Vote End", g_voteArg, item);
							vote.DisplayPassCustom("%t", "Vote End", g_voteArg, item);
						}
					}

					case VoteType_Map:
					{
						if (nVoteType == NativeVotesType_ChgLevel)
						{
							vote.GetDetails(item, sizeof(item));
						}

						//vote.DisplayPass(item);
						vote.DisplayPassEx(NativeVotesPass_ChgLevel, item);
						LogAction(-1, -1, "Changing map to %s due to vote.", item);
						PrintToChatAll("[SM] %t", "Changing map", item);
						DataPack dp;
						CreateDataTimer(5.0, Timer_ChangeMap, dp);
						dp.WriteString(item);
					}

					case VoteType_Kick:
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
							vote.DisplayPass(g_voteInfo[VOTE_NAME]);
						}
					}

					case VoteType_Ban:
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

							vote.DisplayPassCustom("[SM] %t", "Banned player", g_voteInfo[VOTE_NAME], 30);
						}
					}
				}
			}
		}
	}

	return 0;
}

/*
void VoteSelect(Menu menu, int param1, int param2 = 0)
{
	if (GetConVarInt(g_Cvar_VoteShow) == 1)
	{
		char voter[64], junk[64], choice[64];
		GetClientName(param1, voter, sizeof(voter));
		menu.GetItem(param2, junk, sizeof(junk), _, choice, sizeof(choice));
		PrintToChatAll("[SM] %T", "Vote Select", LANG_SERVER, voter, choice);
	}
}
*/

/*
void VoteMenuClose()
{
	delete g_hVoteMenu;
}
*/

float GetVotePercent(int votes, int totalVotes)
{
	return float(votes) / float(totalVotes);
}

bool TestVoteDelay(int client)
{
	int delay = Internal_CheckVoteDelay();

	if (delay > 0)
	{
		if (delay > 60)
		{
			ReplyToCommand(client, "[SM] %t", "Vote Delay Minutes", delay / 60);
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

public Action Timer_ChangeMap(Handle timer, DataPack dp)
{
	char mapname[65];

	dp.Reset();
	dp.ReadString(mapname, sizeof(mapname));

	ForceChangeLevel(mapname, "sm_votemap Result");

	return Plugin_Stop;
}

bool Internal_IsVoteInProgress()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsVoteInProgress();
	}

	return IsVoteInProgress();
}

int Internal_CheckVoteDelay()
{
	if (g_NativeVotes)
	{
		return NativeVotes_CheckVoteDelay();
	}

	return CheckVoteDelay();
}

bool Internal_IsNewVoteAllowed()
{
	if (g_NativeVotes)
	{
		return NativeVotes_IsNewVoteAllowed();
	}

	return IsNewVoteAllowed();
}
