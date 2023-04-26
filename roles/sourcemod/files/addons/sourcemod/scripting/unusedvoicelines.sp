#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sourcemod>
#include <gamemode>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.1"

public Plugin myinfo =
{
	name = "[TF2] Unused Voicelines",
	author = "Nanochip",
	description = "Plays unused announcer voicelines, class speeches, & sounds/music.",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/xNanochip/"
};

ConVar cvTeamScramble;
ConVar cvPayloadCart;
ConVar cvPregameMusic;
ConVar cvPregameCountdown;
ConVar cvRoundActiveFight;
ConVar cvRoundActiveCP;
ConVar cvDontFailAgain;
ConVar cvTeamWipe;
ConVar cvGameEnd;
ConVar cvSpeechRoundStart;
ConVar cvSpeechRoundWin;

ConVar cvWaitingForPlayers;

TF2_GameMode g_Gamemode;
bool g_bWaitingForPlayers;
bool g_bDoFight;
bool g_bDoDontFailAgain;
bool g_bDoTeamWipe;
bool g_bDoPrepareAD; // "prepare to attack the enemy control points" voiceline
bool g_toBlockVictorySound;
bool g_bTeamsScrambled;

int g_iRoundTime;
bool g_bRoundActive; // is the current round active
int g_iLastTeamWon; // which team won the most recent round

char g_sClassNames[TFClassType][16] = { "Unknown", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer"};

public void OnPluginStart()
{
	CreateConVar("unusedvoicelines_version", PLUGIN_VERSION, "[TF2] Unused Voicelines Version", FCVAR_DONTRECORD);
	cvTeamScramble = CreateConVar("uv_teamscramble", "1", "Enable/Disable the teamscramble voiceline.");
	cvPayloadCart = CreateConVar("uv_payloadcart", "1", "Enable/Disable the 'Defend our cart!' or 'Get to the cart!' announcer voicelines on payload when setup is finished.");
	cvPregameMusic = CreateConVar("uv_pregame_music", "3", "0 = No Pregame music, 1 = Casual pregame music, 2 = Competitive pregame music, 3 = Randomly pick either casual/comp pregame music.");
	cvPregameCountdown = CreateConVar("uv_pregame_countdown", "1", "Enable/Disable pregame announcer countdown.");
	cvRoundActiveFight = CreateConVar("uv_roundactive_fight", "1", "Enable/Disable the 'Fight!' announcer voiceline when round first becomes active.");
	cvRoundActiveCP = CreateConVar("uv_roundactive_cp", "1", "Enable/Disable the 'prepare to attack/defend the enemy control points' announcer voiceline when the round first becomes active.");
	cvDontFailAgain = CreateConVar("uv_dontfailagain", "0", "Enable/Disable the 'Dont Fail Me Again' announcer voiceline at the start of the round if the team failed last round");
	cvTeamWipe = CreateConVar("uv_teamwipe", "1", "Enable/Disable the announcer team wipe voicelines");
	cvGameEnd = CreateConVar("uv_game_end", "1", "Enable/Disable 'You Failed'/'Victory' and music after the last round of the map has ended.");
	cvSpeechRoundStart = CreateConVar("uv_speech_roundstart", "1", "Enable/Disable character speeches at the start of rounds.");
	cvSpeechRoundWin = CreateConVar("uv_speech_roundwin", "1", "Enable/Disable character speeches when the round is won/lost.");
	
	cvWaitingForPlayers = FindConVar("mp_waitingforplayers_time");
	
	HookEvent("teamplay_round_active", OnRoundActive);
	HookEvent("teamplay_setup_finished", OnSetupFinished);
	HookEvent("teamplay_alert", OnTeamplayAlert); //team scramble sound
	HookEvent("teamplay_win_panel", OnRoundWin);
	HookEvent("tf_game_over", OnGameOver); //when scoreboard is shown.
	HookEvent("teamplay_game_over", OnGameOver); 
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	HookEvent("teamplay_broadcast_audio", OnBroadcastAudio, EventHookMode_Pre);
	
	AutoExecConfig(true, "unused_voicelines");
}

public void OnMapStart()
{
	g_Gamemode = TF2_DetectGameMode();
	g_bDoFight = cvRoundActiveFight.BoolValue;
	g_bDoDontFailAgain = cvDontFailAgain.BoolValue;
	g_bDoTeamWipe = cvTeamWipe.BoolValue;
	g_bDoPrepareAD = cvRoundActiveCP.BoolValue;
	g_bRoundActive = false;
	g_iLastTeamWon = 0;
	g_toBlockVictorySound = false;
	g_bTeamsScrambled = false;
	
	char map[64];
	GetCurrentMap(map, sizeof map);
	if (strcmp(map, "cp_gravelpit") == 0 || strcmp(map, "cp_steel") == 0)
	{
		// these are the only maps that have this voiceline already as ambient sounds. Not sure why valve made them ambient though..
		g_bDoPrepareAD = false;
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "team_round_timer") == 0)
	{
		if (g_bWaitingForPlayers && cvWaitingForPlayers.IntValue > 30) 
		{
			HookSingleEntityOutput(entity, "On30SecRemain", OnEntityOutput, false);
		}
		if (g_bWaitingForPlayers && cvWaitingForPlayers.IntValue <= 30 && cvWaitingForPlayers.IntValue > 10)
		{
			HookSingleEntityOutput(entity, "On10SecRemain", OnEntityOutput, false);
		}
	}
}

public void OnEntityOutput(const char[] output, int caller, int activator, float delay)
{
	if (strcmp(output, "On30SecRemain") == 0) // this actually outputs when the timer says "29". ohwell..
	{
		int rand = cvPregameMusic.IntValue;
		if (rand == 3) rand = GetRandomInt(1, 2);
		
		PlaySound("30");
		g_iRoundTime = 30;
		CreateTimer(1.0, Timer_Countdown, rand, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	if (strcmp(output, "On10SecRemain") == 0)
	{
		int rand = cvPregameMusic.IntValue;
		if (rand == 3) rand = GetRandomInt(1, 2);
		
		PlaySound("10");
		g_iRoundTime = 10;
		CreateTimer(1.0, Timer_Countdown, rand, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Countdown(Handle hTimer, any rand)
{
	if (g_iRoundTime < 1) return Plugin_Stop;
	
	bool countdown = cvPregameCountdown.BoolValue;
	
	switch (g_iRoundTime-2)
	{
		case 10: if (countdown) PlaySound("10");
		case 8: if (rand == 2) PlaySound("pregameMusicComp"); //play this one at 9 seconds because right at the end of it, players can move.
		case 7: if (rand == 1) PlaySound("pregameMusicCasual"); //play this one at 7 seconds because right at the end of it, players can move.
		case 5: if (countdown) PlaySound("5");
		case 4: if (countdown) PlaySound("4");
		case 3: if (countdown) PlaySound("3");
		case 2: if (countdown) PlaySound("2");
		case 1: if (countdown) PlaySound("1");
	}
	
	g_iRoundTime--;
	return Plugin_Continue;
}

public void OnRoundActive(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bWaitingForPlayers) return;
	g_bRoundActive = true;
	
	if (cvSpeechRoundStart.BoolValue) ProcessRoundStartSpeeches();
	
	bool playedSound = false;
	
	switch (g_Gamemode)
	{
		case TF2_GameMode_PLR:
		{
			if (g_bDoFight)
			{
				if (GetRandomInt(1, 3) == 1) // make it a 1 in 3 chance to play this one
				{
					PlaySound("payloadSetupFinishedBlu");
				}
				else
				{
					PlaySound("fight");
				}
				g_bDoFight = false;
				playedSound = true;
			}
		}
		case TF2_GameMode_5CP, TF2_GameMode_KOTH, TF2_GameMode_CTF:
		{
			if (g_bDoFight)
			{
				g_bDoFight = false; //only say this sound for the first round.
				PlaySound("fight");
				playedSound = true;
			}
		}
		case TF2_GameMode_ADCP:
		{
			if (g_bDoPrepareAD)
			{
				PlaySound("defendCP", 2);
				PlaySound("attackCP", 3);
				playedSound = true;
			}
		}
	}
	
	if (!playedSound)
	{
		DontFailAgainLogic();
	}
	else CreateTimer(3.0, Timer_SoundDelay, _, TIMER_FLAG_NO_MAPCHANGE); //wait 3 seconds since there was already a sound that played
}

void ProcessRoundStartSpeeches(int lastTeamWon = -1)
{
	if (lastTeamWon == -1) lastTeamWon = g_iLastTeamWon;
	DataPack pk;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (GetRandomFloat() <= 0.4) // make this a 40% chance of happening, which is the same as competitive
		{
			if (IsClientInGame(i) && IsPlayerAlive(i))
			{
				CreateDataTimer(GetRandomFloat(1.0, 5.0), Timer_RoundStartSpeechDelay, pk, TIMER_FLAG_NO_MAPCHANGE); // these sounds are randomly spread out 1-5 seconds, again same as competitive.
				pk.WriteCell(GetClientUserId(i));
				pk.WriteCell(lastTeamWon);
			}
		}
	}
}

public Action Timer_RoundStartSpeechDelay(Handle hTimer, DataPack pk)
{
	pk.Reset();
	int client = GetClientOfUserId(pk.ReadCell());
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	
	PlayRoundStartSpeech(client, pk.ReadCell());
}

void PlayRoundStartSpeech(int client, int lastTeamWon)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		int team = GetClientTeam(client);
		
		TFClassType class = TF2_GetPlayerClass(client);
		if (class == TFClass_Pyro || class == TFClass_Medic) return;
		
		char playerClassContext[64];
		Format(playerClassContext, sizeof playerClassContext, "playerclass:%s", g_sClassNames[class]);
		AcceptEntityInput(client, "AddContext");
		
		if (lastTeamWon > 0)
		{
			SetVariantString("RoundsPlayed:1");
			AcceptEntityInput(client, "AddContext");
			
			if (lastTeamWon == team)
			{
				SetVariantString("LostRound:0");
				AcceptEntityInput(client, "AddContext");
			}
			else
			{
				SetVariantString("LostRound:1");
				AcceptEntityInput(client, "AddContext");
			}
			
			SetVariantString("PrevRoundWasTie:0");
			AcceptEntityInput(client, "AddContext");
		}
		else
		{
			SetVariantString("RoundsPlayed:0");
			AcceptEntityInput(client, "AddContext");
		}
		
		SetVariantString("IsComp6v6:0");
		AcceptEntityInput(client, "AddContext");
		
		SetVariantString("randomnum:100");
		AcceptEntityInput(client, "AddContext");
		
		SetVariantString("TLK_ROUND_START_COMP");
		AcceptEntityInput(client, "SpeakResponseConcept");
		
		AcceptEntityInput(client, "ClearContext");
	}
}

public Action Timer_SoundDelay(Handle hTimer)
{
	DontFailAgainLogic();
}

void DontFailAgainLogic()
{
	//TODO: Make this only play for specific clients that failed last round, rather than the failing team as a whole, because new clients could've connected just now..
	if (!g_bDoDontFailAgain || g_iLastTeamWon == 0 || g_bTeamsScrambled) return;
	g_bDoDontFailAgain = false; // only say this sound once
	if (g_Gamemode == TF2_GameMode_PL || g_Gamemode == TF2_GameMode_ADCP)
	{
		// only pl and a/d swap teams on the next round.
		if (g_iLastTeamWon == 2) PlaySound("dontFailAgain", 2);
		if (g_iLastTeamWon == 3) PlaySound("dontFailAgain", 3);
	}
	else
	{
		if (g_iLastTeamWon == 2) PlaySound("dontFailAgain", 3);
		if (g_iLastTeamWon == 3) PlaySound("dontFailAgain", 2);
	}
}

public void OnSetupFinished(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Gamemode == TF2_GameMode_PL && cvPayloadCart.BoolValue)
	{
		PlaySound("payloadSetupFinishedRed", 2);
		PlaySound("payloadSetupFinishedBlu", 3);
	}
}

public void OnTeamplayAlert(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetInt("alert_type") == 0) 
	{
		g_bTeamsScrambled = true;
		if (cvTeamScramble.BoolValue) CreateTimer(5.0, Timer_Delay, _, TIMER_FLAG_NO_MAPCHANGE); //do team scramble voice lines in 5 seconds
	}
}

public Action Timer_Delay(Handle hTimer)
{
	PlaySound("teamScramble");
}

public void OnRoundWin(Event event, const char[] name, bool dontBroadcast)
{
	g_iLastTeamWon = event.GetInt("winning_team");
	g_bRoundActive = false;
	g_bTeamsScrambled = false;
	int gameOver = event.GetInt("game_over");
	if (cvSpeechRoundWin.BoolValue) ProcessWinSpeeches(g_iLastTeamWon, gameOver);
	if (gameOver) g_toBlockVictorySound = true;
}

public void OnGameOver(Event event, const char[] name, bool dontBroadcast)
{
	ProcessWinSpeeches(g_iLastTeamWon, 1);
}

public void OnBroadcastAudio(Event event, const char[] name, bool dontBroadcast)
{
	if (g_toBlockVictorySound && cvGameEnd.BoolValue)
	{
		char sound[64];
		event.GetString("sound", sound, sizeof sound);
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

void ProcessWinSpeeches(int team, int gameOver)
{
	DataPack pk;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (GetRandomFloat() <= 0.4) // make this a 40% chance of happening, which is the same as competitive
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && (team == -1 || GetClientTeam(i) == team))
			{
				CreateDataTimer(GetRandomFloat(2.0, 5.0), Timer_WinSpeechDelay, pk, TIMER_FLAG_NO_MAPCHANGE); // these sounds are randomly spread out 2-5 seconds, again same as competitive.
				pk.WriteCell(GetClientUserId(i));
				pk.WriteCell(gameOver);
			}
		}
	}
}

public Action Timer_WinSpeechDelay(Handle hTimer, DataPack pk)
{
	pk.Reset();
	int client = GetClientOfUserId(pk.ReadCell());
	if (client < 1 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	
	PlayWinSpeech(client, pk.ReadCell());
}

void PlayWinSpeech(int client, int gameOver = 0)
{
	TFClassType class = TF2_GetPlayerClass(client);
	if (class == TFClass_Pyro || class == TFClass_Medic) return;
	
	SetVariantString("OnWinningTeam:1");
	AcceptEntityInput(client, "AddContext");
	
	char playerClassContext[64];
	Format(playerClassContext, sizeof playerClassContext, "playerclass:%s", g_sClassNames[class]);
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
	if (!g_bDoTeamWipe || !g_bRoundActive) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (GetClientCount() >= 10) // let's only play this sound if there's at least 10 people in the game
	{
		if (GetClientTeam(client) == 2 && GetPlayerCountTeam(2) <= 1)
		{
			g_bDoTeamWipe = false;
			PlaySound("teamWipe", 2);
			PlaySound("teamWipeOther", 3);
		}
		if (GetClientTeam(client) == 3 && GetPlayerCountTeam(3) <= 1)
		{
			g_bDoTeamWipe = false;
			PlaySound("teamWipe", 3);
			PlaySound("teamWipeOther", 2);
		}
		if (!g_bDoTeamWipe) CreateTimer(30.0, Timer_TeamWipeCooldown, _, TIMER_FLAG_NO_MAPCHANGE); // put a cooldown on this just in case it somehow gets spammed
	}
}

public Action Timer_TeamWipeCooldown(Handle hTimer)
{
	g_bDoTeamWipe = true;
}

void PlaySound(const char[] sound, int team = -1) //-1 = all, 2 = red, 3 = blu
{
	char path[256];
	
	//countdown sounds
	if (strcmp(sound, "30") == 0) Format(path, sizeof path, "vo/compmode/cm_admin_compbegins30_0%d.mp3", GetRandomInt(1, 2));
	if (strcmp(sound, "10") == 0) 
	{
		if (GetRandomInt(1, 2) == 1) Format(path, sizeof path, "vo/compmode/cm_admin_compbegins10_0%d.mp3", GetRandomInt(1, 2));
		else Format(path, sizeof path, "vo/compmode/cm_admin_compbegins10_rare_0%d.mp3", GetRandomInt(1, 3));
	}
	// "#" before the sound path will tell source engine to play the music at a volume based on the client's music slider in their audio options
	if (strcmp(sound, "pregameMusicCasual") == 0) Format(path, sizeof path, "#ui/mm_round_start_casual.wav");
	if (strcmp(sound, "pregameMusicComp") == 0) Format(path, sizeof path, "#ui/mm_round_start.wav");
	if (strcmp(sound, "5") == 0) Format(path, sizeof path, "vo/compmode/cm_admin_compbegins05.mp3");
	if (strcmp(sound, "4") == 0) Format(path, sizeof path, "vo/compmode/cm_admin_compbegins04.mp3");
	if (strcmp(sound, "3") == 0) Format(path, sizeof path, "vo/compmode/cm_admin_compbegins03.mp3");
	if (strcmp(sound, "2") == 0) Format(path, sizeof path, "vo/compmode/cm_admin_compbegins02.mp3");
	if (strcmp(sound, "1") == 0) Format(path, sizeof path, "vo/compmode/cm_admin_compbegins01.mp3");
	
	//koth, 5cp, plr round active "fight!"
	if (strcmp(sound, "fight") == 0)
	{
		bool voice = view_as<bool>(GetRandomInt(0, 1));
		int randCompStart = GetRandomInt(1, 7);
		int randRoundStart = GetRandomInt(1, 11);
		
		if (!voice)
		{
			Format(path, sizeof path, "vo/compmode/cm_admin_compbeginsstart_0%d.mp3", randCompStart);
		}
		else
		{
			Format(path, sizeof path, "vo/compmode/cm_admin_round_start_");
			if (randRoundStart < 10) Format(path, sizeof path, "%s0%d.mp3", path, randRoundStart);
			else Format(path, sizeof path, "%s%d.mp3", path, randRoundStart);
		}
	}
	
	//attack/defend round active
	if (strcmp(sound, "defendCP") == 0) Format(path, sizeof path, "vo/announcer_defend_controlpoints.mp3");
	if (strcmp(sound, "attackCP") == 0) Format(path, sizeof path, "vo/announcer_attack_controlpoints.mp3");
	
	//payload setup finished
	if (strcmp(sound, "payloadSetupFinishedRed") == 0) Format(path, sizeof path, "vo/announcer_am_gamestarting03.mp3");
	if (strcmp(sound, "payloadSetupFinishedBlu") == 0) Format(path, sizeof path, "vo/announcer_am_gamestarting0%d.mp3", GetRandomInt(1, 2));
	
	//on team scramble
	if (strcmp(sound, "teamScramble") == 0) Format(path, sizeof path, "vo/announcer_am_teamscramble0%d.mp3", GetRandomInt(1, 3));
	
	if (strcmp(sound, "dontFailAgain") == 0)
	{
		switch(GetRandomInt(1, 4))
		{
			case 1: Format(path, sizeof path, "vo/announcer_do_not_fail_again.mp3");
			case 2: Format(path, sizeof path, "vo/announcer_do_not_fail_this_time.mp3");
			case 3: Format(path, sizeof path, "vo/announcer_you_must_not_fail_again.mp3");
			case 4: Format(path, sizeof path, "vo/announcer_you_must_not_fail_this_time.mp3");
		}
	}
	
	if (strcmp(sound, "teamWipe") == 0) // the team that got wiped
	{
		int rand = GetRandomInt(1, 12); // "teamwipe" is 1-4, mvm all dead is 5-7, "oh dear" is 8-9, "unfortunate" is 10, "I can't say Im surprised" is 11, "What are you doing!" is 12. 
		if (rand <= 4) Format(path, sizeof path, "vo/compmode/cm_admin_teamwipe_0%d.mp3", rand);
		if (rand >= 5 && rand <= 7) Format(path, sizeof path, "vo/mvm_all_dead0%d.mp3", rand-4);
		switch(rand)
		{
			case 8: Format(path, sizeof path, "vo/compmode/cm_admin_misc_01.mp3");
			case 9: Format(path, sizeof path, "vo/compmode/cm_admin_misc_09.mp3");
			case 10: Format(path, sizeof path, "vo/compmode/cm_admin_misc_02.mp3");
			case 11: Format(path, sizeof path, "vo/compmode/cm_admin_misc_07.mp3");
			case 12: Format(path, sizeof path, "vo/compmode/cm_admin_misc_08.mp3");
		}
	}
	
	if (strcmp(sound, "teamWipeOther") == 0) // the team that wiped the other team
	{
		int rand = GetRandomInt(1, 13);
		if (rand == 1) Format(path, sizeof path, "vo/compmode/cm_admin_teamwipe_05.mp3");
		if (rand >= 2 && rand <= 4) Format(path, sizeof path, "vo/compmode/cm_admin_teamwipe_%d.mp3", rand+10);
		if (team == 2)
		{
			if (rand == 5) Format(path, sizeof path, "vo/compmode/cm_admin_teamwipe_07.mp3");
			if (rand == 6) Format(path, sizeof path, "vo/compmode/cm_admin_teamwipe_10.mp3");
			if (rand >= 7) Format(path, sizeof path, "vo/compmode/cm_admin_killstreak_0%d.mp3", rand-6); // there are 7 of these sounds
		}
		if (team == 3)
		{
			if (rand == 5) Format(path, sizeof path, "vo/compmode/cm_admin_teamwipe_06.mp3");
			if (rand == 6) Format(path, sizeof path, "vo/compmode/cm_admin_teamwipe_08.mp3");
			if (rand >= 7 && rand <= 8) Format(path, sizeof path, "vo/compmode/cm_admin_killstreak_0%d.mp3", rand+1); // there are 5 of these sounds
			if (rand >= 9 && rand <= 11) Format(path, sizeof path, "vo/compmode/cm_admin_killstreak_%d.mp3", rand+1); // had to get rid of the "0" from the previous line.
			if (rand >= 12) PlaySound("teamWipeOther", 3); // just re-roll the dice since we don't have anymore sounds to play.
		}
	}
	
	if (strcmp(sound, "yourTeamWon") == 0) // game over to the winning team
	{
		Format(path, sizeof path, "#ui/mm_match_end_win_music_casual.wav");
	}
	
	if (strcmp(sound, "yourTeamLost") == 0) // game over to the losing team
	{
		Format(path, sizeof path, "#ui/mm_match_end_lose_music_casual.wav");
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
