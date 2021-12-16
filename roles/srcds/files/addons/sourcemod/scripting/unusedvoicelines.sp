#include <sourcemod>
#include <gamemode>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1

#define PLUGIN_VERSION "1.0"

public Plugin myinfo =
{
	name = "[TF2] Unused Voicelines",
	author = "Nanochip",
	description = "Plays unused voicelines & sounds.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/xNanochip/"
};

TF2_GameMode g_Gamemode;
bool g_bWaitingForPlayers;
bool g_bFight;
//bool g_bDontFailAgain;
bool g_bTeamWipe;
bool g_bDoPrepareAD; // "prepare to attack the enemy control points" voiceline
int g_iRoundTime;
bool g_bRoundActive; // is the current round active
int g_iLastTeamWon; // which team won the most recent round
bool g_toBlockVictorySound;

char g_sClassNames[TFClassType][16] = { "Unknown", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer"};

public void OnPluginStart()
{
	CreateConVar("unusedvoicelines_version", PLUGIN_VERSION, "[TF2] Unused Voicelines Version", FCVAR_DONTRECORD);
	
	HookEvent("teamplay_round_active", OnRoundActive);
	HookEvent("teamplay_setup_finished", OnSetupFinished);
	HookEvent("teamplay_alert", OnTeamplayAlert);
	HookEvent("teamplay_win_panel", OnRoundWin);
	HookEvent("tf_game_over", OnGameOver); //when scoreboard is shown.
	HookEvent("teamplay_game_over", OnGameOver); 
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("teamplay_broadcast_audio", OnBroadcastAudio, EventHookMode_Pre);
	
	RegAdminCmd("sm_playgamewinsounds", Cmd_WinSound, ADMFLAG_RCON); // debug command
}

public void OnMapStart()
{
	g_Gamemode = TF2_DetectGameMode();
	g_bFight = false;
	//g_bDontFailAgain = false;
	g_bTeamWipe = false;
	g_bDoPrepareAD = true;
	g_bRoundActive = false;
	g_iLastTeamWon = 0;
	g_toBlockVictorySound = false;
	
	char map[64];
	GetCurrentMap(map, sizeof(map));
	if (strcmp(map, "cp_gravelpit") == 0 || strcmp(map, "cp_steel") == 0)
    {
    	g_bDoPrepareAD = false;
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "team_round_timer") == 0)
    {
    	if (g_bWaitingForPlayers) HookSingleEntityOutput(entity, "On30SecRemain", OnEntityOutput, false);
    }
}

public void OnEntityOutput(const char[] output, int caller, int activator, float delay)
{
	if (strcmp(output, "On30SecRemain") == 0)
	{
		PlaySound("30");
		g_iRoundTime = 30;
		CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Countdown(Handle hTimer, any data)
{
	if (g_iRoundTime < 1) return Plugin_Stop;
	
	switch (g_iRoundTime-2)
	{
		case 10: PlaySound("10");
		case 7: PlaySound("7");
		case 5: PlaySound("5");
		case 4: PlaySound("4");
		case 3: PlaySound("3");
		case 2: PlaySound("2");
		case 1: PlaySound("1");
	}
	
	g_iRoundTime--;
	return Plugin_Continue;
}

public void OnRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bWaitingForPlayers) return;
	g_bRoundActive = true;
	
	//bool playedSound = false;
	
	if ((g_Gamemode == TF2_GameMode_5CP || g_Gamemode == TF2_GameMode_KOTH || g_Gamemode == TF2_GameMode_CTF) && !g_bFight)
	{
		g_bFight = false; //only say this sound for the first round.
		PlaySound("fight");
		//playedSound = true;
	}
	if (g_Gamemode == TF2_GameMode_ADCP && g_bDoPrepareAD)
	{
		PlaySound("defendCP", 2);
		PlaySound("attackCP", 3);
		//playedSound = true;
	}
	/*if (!playedSound)
	{
		DontFailAgainLogic();
	}
	else CreateTimer(3.0, Timer_SoundDelay, _, TIMER_FLAG_NO_MAPCHANGE); //wait 3 seconds since there was already a sound that played*/
}

/*public Action Timer_SoundDelay(Handle hTimer)
{
	DontFailAgainLogic();
}

void DontFailAgainLogic()
{
	if (g_bDontFailAgain || g_iLastTeamWon == 0) return;
	g_bDontFailAgain = true;
	if (g_iLastTeamWon == 2) PlaySound("dontFailAgain", 2);
	if (g_iLastTeamWon == 3) PlaySound("dontFailAgain", 3);
}*/

public void OnSetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Gamemode == TF2_GameMode_PL)
	{
		PlaySound("payloadSetupFinishedRed", 2);
		PlaySound("payloadSetupFinishedBlu", 3);
	}
}

public void OnTeamplayAlert(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("alert_type") == 0) CreateTimer(5.0, Timer_Delay, _, TIMER_FLAG_NO_MAPCHANGE); //do team scramble voice lines in 5 seconds
}

public Action Timer_Delay(Handle hTimer)
{
	PlaySound("teamScramble");
}

public Action Cmd_WinSound(int client, int args) // this is just a debug command which will be removed later.
{
	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	ProcessWinSounds(-1, StringToInt(arg1));
}

public void OnRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	g_iLastTeamWon = event.GetInt("winning_team");
	g_bRoundActive = false;
	int gameOver = event.GetInt("game_over");
	ProcessWinSounds(g_iLastTeamWon, gameOver);
	if (gameOver) g_toBlockVictorySound = true;
}

public void OnGameOver(Event event, const char[] name, bool dontBroadcast)
{
	ProcessWinSounds(g_iLastTeamWon, 1);
}

public void OnBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	if (g_toBlockVictorySound)
	{
		char sound[64];
		event.GetString("sound", sound, sizeof(sound));
		int team = event.GetInt("team");
		
		if (strcmp(sound, "Game.YourTeamLost") == 0 || strcmp(sound, "Game.Stalemate") == 0)
		{
			event.BroadcastDisabled = true;
			PlaySound("yourTeamLost", team);
		}
		if (strcmp(sound, "Game.YourTeamWon") == 0)
		{
			event.BroadcastDisabled = true;
			PlaySound("yourTeamWon", team);
		}
	}
}

void ProcessWinSounds(int team, int gameOver)
{
	DataPack pk;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (40 > GetRandomInt(0, 100)) // make this a 40% chance of happening
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && (team == -1 || GetClientTeam(i) == team))
			{
				CreateDataTimer(view_as<float>(GetRandomInt(2, 5)), Timer_ResponseDelay, pk, TIMER_FLAG_NO_MAPCHANGE); // these sounds are randomly spread out 2-5 seconds.
				pk.WriteCell(GetClientUserId(i));
				pk.WriteCell(gameOver);
			}
		}
	}
}

public Action Timer_ResponseDelay(Handle hTimer, DataPack pk)
{
	pk.Reset();
	int client = GetClientOfUserId(pk.ReadCell());
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	
	PlayWinResponse(client, pk.ReadCell());
}

void PlayWinResponse(int client, int gameOver = 0)
{
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Pyro || class == TFClass_Medic) return;
	
	SetVariantString("OnWinningTeam:1");
	AcceptEntityInput(client, "AddContext");
	
	char playerClassContext[64];
	Format(playerClassContext, sizeof(playerClassContext), "playerclass:%s", g_sClassNames[class]);
	AcceptEntityInput(client, "AddContext");
	
	SetVariantString("randomnum:100");
	AcceptEntityInput(client, "AddContext");
	
	if (!view_as<bool>(gameOver)) SetVariantString("TLK_GAME_OVER_COMP"); // round over
	else SetVariantString("TLK_MATCH_OVER_COMP"); // actual game/match over
	AcceptEntityInput(client, "SpeakResponseConcept");
	
	AcceptEntityInput(client, "ClearContext");
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	//teamwipe logic
	if (g_bTeamWipe || !g_bRoundActive) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (GetClientCount() >= 10) // let's only play this sound if there's at least 10 people in the game
	{
		if (GetClientTeam(client) == 2 && GetPlayerCountTeam(2) <= 1)
		{
			g_bTeamWipe = true;
			PlaySound("teamWipe", 2);
			PlaySound("teamWipeOther", 3);
		}
		if (GetClientTeam(client) == 3 && GetPlayerCountTeam(3) <= 1)
		{
			g_bTeamWipe = true;
			PlaySound("teamWipe", 3);
			PlaySound("teamWipeOther", 2);
		}
		if (g_bTeamWipe) CreateTimer(30.0, Timer_TeamWipeCooldown, _, TIMER_FLAG_NO_MAPCHANGE); // put a cooldown on this just in case it somehow gets spammed
	}
}

public Action Timer_TeamWipeCooldown(Handle hTimer)
{
	g_bTeamWipe = false;
}

void PlaySound(const char[] sound, int team = -1) //-1 = all, 2 = red, 3 = blu
{
	char path[256];
	
	//countdown sounds
	if (strcmp(sound, "30") == 0) Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins30_0%d.mp3", GetRandomInt(1, 2));
	if (strcmp(sound, "10") == 0) 
	{
		bool rare = view_as<bool>(GetRandomInt(0, 1));
		if (!rare) Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins10_0%d.mp3", GetRandomInt(1, 2));
		else Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins10_rare_0%d.mp3", GetRandomInt(1, 3));
	}
	if (strcmp(sound, "7") == 0) Format(path, sizeof(path), "ui/mm_round_start_casual.wav");
	if (strcmp(sound, "5") == 0) Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins05.mp3");
	if (strcmp(sound, "4") == 0) Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins04.mp3");
	if (strcmp(sound, "3") == 0) Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins03.mp3");
	if (strcmp(sound, "2") == 0) Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins02.mp3");
	if (strcmp(sound, "1") == 0) Format(path, sizeof(path), "vo/compmode/cm_admin_compbegins01.mp3");
	
	//koth, 5cp, plr round active "fight!"
	if (strcmp(sound, "fight") == 0)
	{
		bool voice = view_as<bool>(GetRandomInt(0, 1));
		int randCompStart = GetRandomInt(1, 7);
		int randRoundStart = GetRandomInt(1, 11);
		
		if (!voice)
		{
			Format(path, sizeof(path), "vo/compmode/cm_admin_compbeginsstart_0%d.mp3", randCompStart);
		}
		else
		{
			Format(path, sizeof(path), "vo/compmode/cm_admin_round_start_");
			if (randRoundStart < 10) Format(path, sizeof(path), "%s0%d.mp3", path, randRoundStart);
			else Format(path, sizeof(path), "%s%d.mp3", path, randRoundStart);
		}
	}
	
	//attack/defend round active
	if (strcmp(sound, "defendCP") == 0) Format(path, sizeof(path), "");
	if (strcmp(sound, "attackCP") == 0) Format(path, sizeof(path), "");
	
	//payload setup finished
	if (strcmp(sound, "payloadSetupFinishedRed") == 0) Format(path, sizeof(path), "");
	if (strcmp(sound, "payloadSetupFinishedBlu") == 0) Format(path, sizeof(path), "");
	
	//on team scramble
	if (strcmp(sound, "teamScramble") == 0) Format(path, sizeof(path), "vo/announcer_am_teamscramble0%d.mp3", GetRandomInt(1, 3));
	
	/*if (strcmp(sound, "dontFailAgain") == 0)
	{
		switch(GetRandomInt(1, 4))
		{
			case 1: Format(path, sizeof(path), "vo/announcer_do_not_fail_again.mp3");
			case 2: Format(path, sizeof(path), "vo/announcer_do_not_fail_this_time.mp3");
			case 3: Format(path, sizeof(path), "vo/announcer_you_must_not_fail_again.mp3");
			case 4: Format(path, sizeof(path), "vo/announcer_you_must_not_fail_this_time.mp3");
		}
	}*/
	
	if (strcmp(sound, "teamWipe") == 0) // the team that got wiped
	{
		int rand = GetRandomInt(1, 12); // "teamwipe" is 1-4, mvm all dead is 5-7, "oh dear" is 8-9, "unfortunate" is 10, "I can't say Im surprised" is 11, "What are you doing!" is 12. 
		if (rand <= 4) Format(path, sizeof(path), "vo/compmode/cm_admin_teamwipe_0%d.mp3", rand);
		if (rand >= 5 && rand <= 7) Format(path, sizeof(path), "vo/mvm_all_dead0%d.mp3", rand-4);
		switch(rand)
		{
			case 8: Format(path, sizeof(path), "vo/compmode/cm_admin_misc_01.mp3"); 
			case 9: Format(path, sizeof(path), "vo/compmode/cm_admin_misc_09.mp3"); 
			case 10: Format(path, sizeof(path), "vo/compmode/cm_admin_misc_02.mp3"); 
			case 11: Format(path, sizeof(path), "vo/compmode/cm_admin_misc_07.mp3"); 
			case 12: Format(path, sizeof(path), "vo/compmode/cm_admin_misc_08.mp3"); 
		}
	}
	
	if (strcmp(sound, "teamWipeOther") == 0) // the team that wiped the other team
	{
		int rand = GetRandomInt(1, 13);
		if (rand == 1) Format(path, sizeof(path), "vo/compmode/cm_admin_teamwipe_05.mp3");
		if (rand >= 2 && rand <= 4) Format(path, sizeof(path), "vo/compmode/cm_admin_teamwipe_%d.mp3", rand+10);
		if (team == 2)
		{
			if (rand == 5) Format(path, sizeof(path), "vo/compmode/cm_admin_teamwipe_07.mp3");
			if (rand == 6) Format(path, sizeof(path), "vo/compmode/cm_admin_teamwipe_10.mp3");
			if (rand >= 7) Format(path, sizeof(path), "", rand-6); // there are 7 of these sounds
		}
		if (team == 3)
		{
			if (rand == 5) Format(path, sizeof(path), "vo/compmode/cm_admin_teamwipe_06.mp3");
			if (rand == 6) Format(path, sizeof(path), "vo/compmode/cm_admin_teamwipe_08.mp3");
			if (rand >= 7 && rand <= 8) Format(path, sizeof(path), "", rand+1); // there are 5 of these sounds
			if (rand >= 9 && rand <= 11) Format(path, sizeof(path), "", rand+1); // had to get rid of the "0" from the previous line.
			if (rand >= 12) PlaySound("teamWipeOther", 3); // just re-roll the dice since we don't have anymore sounds to play.
		}
	}
	
	if (strcmp(sound, "yourTeamWon") == 0) // game over to the winning team
	{
		Format(path, sizeof(path), "ui/mm_match_end_win_music_casual.wav");
	}
	
	if (strcmp(sound, "yourTeamLost") == 0) // game over to the losing team
	{
		Format(path, sizeof(path), "ui/mm_match_end_lose_music_casual.wav");
	}
	
	if (!StrEqual(path[0], "\0"))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (team == -1 || team == GetClientTeam(i)) ClientCommand(i, "playgamesound %s", path);
			}
		}
	}
}

public void TF2_OnWaitingForPlayersStart()
{
	g_bWaitingForPlayers = true;
}

public void TF2_OnWaitingForPlayersEnd()
{
	g_bWaitingForPlayers = false;
}

stock int GetPlayerCountTeam(int team)
{
	int players_team;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team && IsPlayerAlive(i))
			players_team++;
	}
	return players_team;
}