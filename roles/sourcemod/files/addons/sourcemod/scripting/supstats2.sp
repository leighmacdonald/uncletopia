/*
Release notes:

---- 2.0.0 (23/12/2013) ----
- Logs damage and real damage per weapon
- Logs damage taken
- Logs airshots
- Logs self-healing (eg. by blackbox)
- Logs headshots (not just headshot kills)
- Logs medkit pickups including amount of healing
- Logs which medigun is used when ubering
- Logs crits and mini crits
- Logs non-buffed heals (as in v1)
- Logs ammo pickups (as in v1)
- Logs players spawning (as in v1)
- Logs game pauses (as in v1)


---- 2.1.0 (01/01/2014) ----
- NEW: Accuracy Stats
- Rocket jumping and building uber does not affect accuracy
- Clearing stickies does not affect accuracy
- Post-mortem damage now correctly logged (it sometimes wrote "Player" as weapon)
- Fixed spy backstabs sometimes counting as taunt kills
- Minimum airshot distance-to-ground changed from 80 to 170 units
- Minor bug fixes


---- 2.1.1 (28/01/2014) ----
- Fixed SteamIDs sometimes being wrong in the logs


---- 2.1.2 (01/02/2014) ----
- Fixed minicrits being logged as normal crits


---- 2.2.0 (26/07/2014) ----
- Added accuracy for Crusaders Crossbow. Hitting a teammate also counts as a hit.
- Added accuracy for Stickybombs. Stickyjumping and building uber doesn't affect accuracy.
- Fixed a minor bug with "pause" logs


---- 2.2.1 (31/07/2014) ----
- Fixed crash on startup caused by the latest TF2 update


---- 2.2.2 (25/08/2014) ----
- Fixed problem with snapshot version of SourceMod (regarding new SteamID format)


---- 2.2.3 (03/07/2015) ----
- Fixed bugs introduced by Gun Mettle update


---- 2.3.0 (21/10/2015) ----
- Fixed skinned mediguns being logged as 'unknown'
- Fixed skinned weapons being logged as 'unknown'
- Added accuracy for revolver


---- 2.3.1 (21/08/2016) ----
- Do not crash if the healer/patient is reported as 0
- Do not log self-heal


---- 2.4.0 (02/10/2022) ----
- Added pause length to logs
- Fixed 'pause' logs being wrong
- Fixed SM error logs when picking up medpacks


---- 2.5.0 (15/10/2022) ----
- Added logs for crossbow airshots - by Bv


---- 2.5.1 (21/03/2023) ----
- Added height prop to airshot logs - by Bv
- Switched to using HullRayTracing to eliminate edge-cases - by Bv


TODO:
- Use GetGameTime() instead of GetEngineTime()?
- Write comments in code :D
- Make a separate file that deals with special weapon log-names
- It might be possible to detect the owner of a rocket using m_hOwnerEntity
- Log Blackbox healing more precisely (perhaps use player_healonhit instead)
*/

#pragma semicolon 1 // Force strict semicolon mode.
#pragma newdecls required

#include <sourcemod>
#include <tf2_stocks>
#include <f2stocks>
#include <sdkhooks>
#include <smlib>
#include <kvizzle>
#undef REQUIRE_PLUGIN
#include <updater>

#define PLUGIN_VERSION "2.5.1"
#define UPDATE_URL		"https://sourcemod.krus.dk/supstats2/update.txt"

#define NAMELEN 64

#define MAXWEAPONS 2048
#define MAXWEPSLOTS 5
#define MAXWEPNAMELEN 72
#define MAXITEMCLASSLEN 64

public Plugin myinfo = {
	name = "Supplemental Stats v2",
	author = "F2 (v1 by Jean-Denis Caron)",
	description = "Logs additional information about the game.",
	version = PLUGIN_VERSION,
	url = "https://github.com/F2/F2s-sourcemod-plugins"
};


bool g_bIsPaused;
bool g_bBlockLog = false;
char g_sBlockLog[64];

char lastWeaponDamage[MAXPLAYERS+1][MAXWEPNAMELEN];
char lastPostHumousWeaponDamage[MAXPLAYERS+1][MAXWEPNAMELEN]; 
float lastPostHumousWeaponDamageTime[MAXPLAYERS+1]; 
int lastHealth[MAXPLAYERS+1];
int lastHealingOnHit[MAXPLAYERS+1]; 
bool lastHeadshot[MAXPLAYERS+1]; 
bool lastAirshot[MAXPLAYERS+1]; 
int lastAirshotHeight[MAXPLAYERS+1];
bool g_bPlayerTakenDirectHit[MAXPLAYERS+1];
int medpackHealAmount[MAXPLAYERS+1];
float g_fPauseStartTime;
char g_sTauntNames[][] = { "", "taunt_scout", "taunt_sniper", "taunt_soldier", "taunt_demoman", "taunt_medic", "taunt_heavy", "taunt_pyro", "taunt_spy", "taunt_engineer" };


// ---- ACCURACY ----
Handle g_hCvarEnableAccuracy = INVALID_HANDLE;
bool g_bEnableAccuracy;

int g_iIgnoreDamageEnt[5];
float g_fLastHitscanHit[MAXPLAYERS+1];

const MAXROCKETS = 5;
int g_iRocketCreatedEntity[MAXROCKETS];
float g_fRocketCreatedTime[MAXROCKETS];
int g_iRocketCreatedNext = 0;

const float MAXROCKETJUMPTIME = 0.15;
bool g_bRocketHurtMe[MAXPLAYERS+1];
bool g_bRocketHurtEnemy[MAXPLAYERS+1];
char g_sRocketFiredLogLine[MAXPLAYERS+1][1024];

const float MAXHITSCANTIME = 0.05;
bool g_bHitscanHurtEnemy[MAXPLAYERS+1];
char g_sHitscanFiredLogLine[MAXPLAYERS+1][1024];

const MAXSTICKIES = 14;
bool g_bStickyHurtMe[MAXPLAYERS+1][MAXSTICKIES];
bool g_bStickyHurtEnemy[MAXPLAYERS+1][MAXSTICKIES];
int g_iStickyId[MAXPLAYERS+1][MAXSTICKIES];

const SHOT_PROJECTILE_MIN = 0; // inclusive
const SHOT_ROCKET = 0;
const SHOT_NEEDLE = 1;
const SHOT_HEALINGBOLT = 2;
const SHOT_PIPE = 3;
const SHOT_STICKY = 4;
const SHOT_PROJECTILE_MAX = 8; // exclusive
const SHOT_HITSCAN_MIN = 16; // inclusive
const SHOT_HITSCAN = 16;
const SHOT_HITSCAN_MAX = 32; // exclusive
Handle g_tShotTypes = INVALID_HANDLE; // Using a Trie seems to be over twice as fast as StrEqual()
// ---- ACCURACY ----


public void OnPluginStart() {
	if (LibraryExists("updater"))
		Updater_AddPlugin(UPDATE_URL);
	
	
	g_tShotTypes = CreateTrie();
	SetTrieValue(g_tShotTypes, "tf_weapon_rocketlauncher", SHOT_ROCKET);
	SetTrieValue(g_tShotTypes, "tf_weapon_particle_cannon", SHOT_ROCKET);
	SetTrieValue(g_tShotTypes, "tf_weapon_rocketlauncher_directhit", SHOT_ROCKET);
	SetTrieValue(g_tShotTypes, "tf_projectile_rocket", SHOT_ROCKET);
	SetTrieValue(g_tShotTypes, "tf_projectile_energy_ball", SHOT_ROCKET);
	
	SetTrieValue(g_tShotTypes, "tf_weapon_grenadelauncher", SHOT_PIPE);
	SetTrieValue(g_tShotTypes, "tf_projectile_pipe", SHOT_PIPE);
	//SetTrieValue(g_tShotTypes, "tf_weapon_pipebomblauncher", SHOT_STICKY); // Should NOT be added.. causes a bug in OnEntityDestroyed
	SetTrieValue(g_tShotTypes, "tf_projectile_pipe_remote", SHOT_STICKY);
	
	SetTrieValue(g_tShotTypes, "tf_weapon_syringegun_medic", SHOT_NEEDLE);
	SetTrieValue(g_tShotTypes, "tf_weapon_crossbow", SHOT_HEALINGBOLT);
	SetTrieValue(g_tShotTypes, "tf_projectile_healing_bolt", SHOT_HEALINGBOLT);
	
	SetTrieValue(g_tShotTypes, "tf_weapon_scattergun", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_shotgun_soldier", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_shotgun_primary", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_shotgun_hwg", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_shotgun_pyro", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_pistol_scout", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_pistol", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_smg", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_sniperrifle", SHOT_HITSCAN);
	SetTrieValue(g_tShotTypes, "tf_weapon_revolver", SHOT_HITSCAN);
	
	
	
	
	AddGameLogHook(GameLog);
	
	ImportWeaponDefinitions();
	
	g_hCvarEnableAccuracy = CreateConVar("supstats_accuracy", "1", "Enable accuracy");
	HookConVarChange(g_hCvarEnableAccuracy, CvarChange_EnableAccuracy);
	char cvarEnableAccuracy[16];
	GetConVarString(g_hCvarEnableAccuracy, cvarEnableAccuracy, sizeof(cvarEnableAccuracy));
	CvarChange_EnableAccuracy(g_hCvarEnableAccuracy, cvarEnableAccuracy, cvarEnableAccuracy);
	
	
	HookEvent("item_pickup", Event_ItemPickup);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_healed", Event_PlayerHealed);
	HookEvent("player_spawn", Event_PlayerSpawned);
	//HookEvent("player_healonhit", Event_PlayerHealOnHit);
	
	HookEvent("player_chargedeployed", EventPre_player_chargedeployed, EventHookMode_Pre);
	HookEvent("player_chargedeployed", Event_player_chargedeployed);

	AddCommandListener(Listener_Pause, "pause");
	
	
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && !IsClientSourceTV(client)) {
			SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
	
	char map[64];
	GetCurrentMap(map, sizeof(map));
	LogToGame("Loading map \"%s\"", map);

	g_fPauseStartTime = GetEngineTime(); // Just in case it is already paused
}

public void OnLibraryAdded(const char[] name) {
	// Set up auto updater
	if (StrEqual(name, "updater"))
		Updater_AddPlugin(UPDATE_URL);
}

public void OnMapStart() {
	for (int i = 0; i < sizeof(g_iIgnoreDamageEnt); i++)
		g_iIgnoreDamageEnt[i] = 0;
	
	for (int client = 0; client < MaxClients; client++) {
		for (int i = 0; i < MAXSTICKIES; i++)
			g_iStickyId[client][i] = 0;
	}
	g_bIsPaused = false; // The game is automatically unpaused during a map change
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	lastPostHumousWeaponDamage[client][0] = '\0';
}

public void OnPluginEnd() {
	for (int client = 1; client <= MaxClients; client++) {
		if (IsClientInGame(client) && !IsClientSourceTV(client)) {
			SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}

	RemoveGameLogHook(GameLog);
}

public void CvarChange_EnableAccuracy(Handle cvar, const char[] oldVal, const char[] newVal) {
	g_bEnableAccuracy = StringToInt(newVal) != 0;
}


public Action BlockLogLine(const char[] logline) {
	if (g_bBlockLog && (g_sBlockLog[0] == '\0' || StrContains(logline, g_sBlockLog, false) != -1))
		// If we don't use g_sBlockLog, then chargeready is sometimes blocked
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action GameLog(const char[] message) {
	return BlockLogLine(message);
}


public Action Listener_Pause(int client, const char[] command, int argc) {
	if (client == 0)
		return Plugin_Continue; // Using "rcon pause" won't do anything
	
	CreateTimer(0.1, CheckPause, client);

	return Plugin_Continue;
}


public Action CheckPause(Handle timer, int client) {
	bool isPaused = !IsServerProcessing();
	int userId = GetClientUserId(client);
	char userSteamId[64];
	char userTeam[64];

	if (isPaused && !g_bIsPaused) {
		g_fPauseStartTime = GetEngineTime();

		LogToGame("World triggered \"Game_Paused\"");

		GetClientAuthStringNew(client, userSteamId, sizeof(userSteamId), false);
		GetPlayerTeamStr(GetClientTeam(client), userTeam, sizeof(userTeam));

		LogToGame("\"%N<%d><%s><%s>\" triggered \"matchpause\"", client, userId, userSteamId, userTeam);
	}
	if (!isPaused && g_bIsPaused) {
		float pauseDuration = GetEngineTime() - g_fPauseStartTime;

		LogToGame("World triggered \"Game_Unpaused\"");

		GetClientAuthStringNew(client, userSteamId, sizeof(userSteamId), false);
		GetPlayerTeamStr(GetClientTeam(client), userTeam, sizeof(userTeam));

		LogToGame("\"%N<%d><%s><%s>\" triggered \"matchunpause\"", client, userId, userSteamId, userTeam);
		LogToGame("World triggered \"Pause_Length\" (seconds \"%.2f\")", pauseDuration);
	}

	g_bIsPaused = isPaused;
	return Plugin_Continue;
}

public Action Event_PlayerHealed(Handle event, const char[] name, bool dontBroadcast) {
	char patientName[NAMELEN];
	char healerName[NAMELEN];
	char patientSteamId[64];
	char healerSteamId[64];
	char patientTeam[64];
	char healerTeam[64];
	char strAirshot[64] = "";

	int patientId = GetEventInt(event, "patient");
	int healerId = GetEventInt(event, "healer");
	int patient = GetClientOfUserId(patientId);
	int healer = GetClientOfUserId(healerId);
	int amount = GetEventInt(event, "amount");
	
	if (lastAirshot[healer]) {
		Format(strAirshot, sizeof(strAirshot), " (airshot \"1\") (height \"%i\")", lastAirshotHeight[healer]);
		lastAirshot[healer] = false;
	}

	if (healer == 0 && patient != 0) {
		// Healed by a medpack
		medpackHealAmount[patient] = amount;
		return Plugin_Continue;
	}

	if (patient == 0 || healer == 0) {
		// This has been observed to happen by http://www.teamfortress.tv/post/631052/medicstats-sourcemod-plugin
		LogMessage("Wrong player-healed event detected: patient=%i/%i, healer=%i/%i, amount=%i", patientId, patient, healerId, healer, amount);
		return Plugin_Continue;
	}

	if (patient == healer) {
		// Do not log self-heal
		return Plugin_Continue;
	}
	
	GetClientAuthStringNew(patient, patientSteamId, sizeof(patientSteamId), false);
	GetClientName(patient, patientName, sizeof(patientName));
	GetClientAuthStringNew(healer, healerSteamId, sizeof(healerSteamId), false);
	GetClientName(healer, healerName, sizeof(healerName));
	
	GetPlayerTeamStr(GetClientTeam(patient), patientTeam, sizeof(patientTeam));
	GetPlayerTeamStr(GetClientTeam(healer), healerTeam, sizeof(healerTeam));
	
	LogToGame("\"%s<%d><%s><%s>\" triggered \"healed\" against \"%s<%d><%s><%s>\" (healing \"%d\")%s",
		healerName,
		healerId,
		healerSteamId,
		healerTeam,
		patientName,
		patientId,
		patientSteamId,
		patientTeam,
		amount,
		strAirshot);
	
	return Plugin_Continue;
}




char classNames[][] = {
	"undefined",
	"scout",
	"sniper",
	"soldier",
	"demoman",
	"medic",
	"heavyweapons",
	"pyro",
	"spy",
	"engineer"
};


//public Event_PlayerHealOnHit(Handle event, const string name[], bool dontBroadcast) {
//	PrintToChatAll("heal on hit - amount(%i) client(%i)", GetEventInt(event, "amount"), GetEventInt(event, "entindex"));
//}

public void Event_PlayerSpawned(Handle event, const char[] name, bool dontBroadcast) {
	char playerName[NAMELEN];
	char playerSteamID[64];
	char playerTeam[64];
	
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	int clss = GetEventInt(event, "class");
	
	if (!IsRealPlayer(client))
		return; // eg. SourceTV
	
	for (int i = 0; i < MAXSTICKIES; i++)
		g_iStickyId[client][i] = 0;
	
	GetClientName(client, playerName, sizeof(playerName));
	GetClientAuthStringNew(client, playerSteamID, sizeof(playerSteamID), false);
	GetPlayerTeamStr(GetClientTeam(client), playerTeam, sizeof(playerTeam));
	LogToGame("\"%s<%d><%s><%s>\" spawned as \"%s\"",
		playerName,
		userid,
		playerSteamID,
		playerTeam,
		classNames[clss]);
}


// "%s<%i><%s><%s>" triggered "chargedeployed" (medigun "%s")
public void EventPre_player_chargedeployed(Handle event, const char[] name, bool dontBroadcast) {
	g_bBlockLog = true;
	strcopy(g_sBlockLog, sizeof(g_sBlockLog), "chargedeployed");
}

public void Event_player_chargedeployed(Handle event, const char[] name, bool dontBroadcast) {
	g_bBlockLog = false;
	g_sBlockLog = "";
	
	char playerName[NAMELEN];
	char playerAuth[64];
	char playerTeam[16];
	char medigun[64];
	
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	GetClientName(client, playerName, sizeof(playerName));
	GetClientAuthStringNew(client, playerAuth, sizeof(playerAuth), false);
	GetPlayerTeamStr(GetClientTeam(client), playerTeam, sizeof(playerTeam));
	GetMedigunName(client, medigun, sizeof(medigun));
	
	
	LogToGame("\"%s<%i><%s><%s>\" triggered \"chargedeployed\" (medigun \"%s\")", playerName, userid, playerAuth, playerTeam, medigun);
}

void GetMedigunName(int client, char[] medigun, int medigunLen) {
	int weaponid = GetPlayerWeaponSlot(client, 1);
	if (weaponid >= 0) {
		int healing;
		bool postHumousDamage;
		int defid;
		if (GetWeaponLogName(medigun, medigunLen, client, weaponid, healing, defid, postHumousDamage, client)) {
			// We found the weapon
		} else {
			strcopy(medigun, medigunLen, "unknown");
		}
	} else {
		strcopy(medigun, medigunLen, "");
	}
}


// Medkit pickup with healing
public void Event_ItemPickup(Handle event, const char[] name, bool dontBroadcast) {
	char item[64];
	GetEventString(event, "item", item, sizeof(item));
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	
	if (strncmp(item, "medkit_", 7, true) == 0 && medpackHealAmount[client] != 0) {
		LogItemPickup(userid, item, medpackHealAmount[client]);
		medpackHealAmount[client] = 0;
		return;
	}
	
	LogItemPickup(userid, item);
}

void LogItemPickup(int userid, char[] item, int healing = 0) {
	char playerName[NAMELEN];
	char playerSteamId[64];
	char playerTeam[64];
	char strHealing[64] = "";
	
	int client = GetClientOfUserId(userid);
	GetClientAuthStringNew(client, playerSteamId, sizeof(playerSteamId), false);
	GetClientName(client, playerName, sizeof(playerName));
	GetPlayerTeamStr(GetClientTeam(client), playerTeam, sizeof(playerTeam));
	
	if (healing != 0)
		FormatEx(strHealing, sizeof(strHealing), " (healing \"%i\")", healing);
	
	LogToGame("\"%s<%d><%s><%s>\" picked up item \"%s\"%s",
		playerName,
		userid,
		playerSteamId,
		playerTeam,
		item,
		strHealing);
}



int FindStickySpot(int client, int inflictor, bool mayCreate = false) {
	int emptyStickyPos = -1, foundStickyPos = -1;
	for (int i = 0; i < MAXSTICKIES; i++) {
		if (g_iStickyId[client][i] == inflictor) {
			foundStickyPos = i;
			break;
		}
		if (emptyStickyPos == -1 && g_iStickyId[client][i] == 0)
			emptyStickyPos = i;
	}
	
	if (foundStickyPos == -1 && mayCreate) {
		if (emptyStickyPos == -1) {
			LogError("Could not find empty sticky pos for player %i", client);
		} else {
			foundStickyPos = emptyStickyPos;
			g_bStickyHurtMe[client][foundStickyPos] = false; // no need - it is set below
			g_bStickyHurtEnemy[client][foundStickyPos] = false;
			g_iStickyId[client][foundStickyPos] = inflictor;
		}
	}
	
	return foundStickyPos;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom) {
	bool wasDirect = g_bPlayerTakenDirectHit[victim];
	g_bPlayerTakenDirectHit[victim] = false; // Make sure to reset it before leaving the function
	
	if (victim == attacker) {
		if (g_bEnableAccuracy && IsRealPlayer(attacker) && inflictor > MaxClients) {
			TFClassType cls = TF2_GetPlayerClass(attacker);
			if (cls == TFClass_Soldier) {
				for (int i = 0; i < MAXROCKETS; i++) {
					if (g_iRocketCreatedEntity[i] == inflictor && g_fRocketCreatedTime[i] >= GetEngineTime() - MAXROCKETJUMPTIME) {
						g_bRocketHurtMe[attacker] = true;
						break;
					}
				}
			} else if (cls == TFClass_DemoMan) {
				if (inflictor > MaxClients) {
					char entityName[32];
					GetEntityClassname(inflictor, entityName, sizeof(entityName));
					int shotType;
					if (GetTrieValue(g_tShotTypes, entityName, shotType) && shotType == SHOT_STICKY) {
						int stickyPos = FindStickySpot(attacker, inflictor, true);
						
						if (stickyPos != -1) {
							g_bStickyHurtMe[attacker][stickyPos] = true;
						}
					}
				}
			}
		}
		return Plugin_Continue;
	}
	if (!(victim > 0 && victim <= MaxClients && attacker > 0 && attacker <= MaxClients))
		return Plugin_Continue;
	if (!IsPlayerAlive(victim))
		return Plugin_Continue; // Sometimes this function is triggered even for dead players.
	
	int attackerTeam = GetClientTeam(attacker);
	int victimTeam = GetClientTeam(victim);
	if (attackerTeam == victimTeam)
		return Plugin_Continue; // The function is triggered for team mates too
	
	TFClassType attackerClass = TF2_GetPlayerClass(attacker);
	lastHealingOnHit[attacker] = 0;
	lastHealth[attacker] = GetClientHealth(attacker);
	lastHeadshot[attacker] = false;
	lastAirshot[attacker] = false;

	lastWeaponDamage[attacker][0] = '\0';
	
	
	//string strDamagetype[33], String:strDamagecustom[33];
	//IntToBits(damagetype, strDamagetype);
	//IntToBits(damagecustom, strDamagecustom);
	//PrintToChatAll("vic(%i) att(%i) infl(%i) weap(%i) dmg(%.0f) dmgtype(%s) dmgcus(%s)", victim, attacker, inflictor, weapon, damage, strDamagetype, strDamagecustom);
	
	if ((damagetype & DMG_CRIT) != DMG_CRIT && ((damage >= 500.0 && (damagetype & (1 << 27)) != (1 << 27) /* not a backstab */) || (damage >= 300.0 && (damagetype & DMG_BLAST) == DMG_BLAST /* soldier equalizer taunt, perhaps others */))) {
		strcopy(lastWeaponDamage[attacker], MAXWEPNAMELEN, g_sTauntNames[attackerClass]);
	} else {
		int healing; 
		int defid;
		bool postHumousDamage;
		if (!GetWeaponLogName(lastWeaponDamage[attacker], MAXWEPNAMELEN, attacker, weapon, healing, defid, postHumousDamage, inflictor)) {
			float now = GetEngineTime();
			if (lastPostHumousWeaponDamageTime[attacker] >= now - 15.0) {
				strcopy(lastWeaponDamage[attacker], MAXWEPNAMELEN, lastPostHumousWeaponDamage[attacker]);
				lastPostHumousWeaponDamageTime[attacker] = now;
				return Plugin_Continue;
			} else {
				strcopy(lastWeaponDamage[attacker], MAXWEPNAMELEN, "unknown");
				return Plugin_Continue;
			}
		}
		
		if (healing > 0) {
			if (StrEqual(lastWeaponDamage[attacker], "blackbox")) {
				// TODO: Handle this more generic using the add_health_on_radius_damage attribute. Also, this is not perfectly precise.
				int actualHealing = RoundToNearest(damage / 4.25);
				if (actualHealing > healing)
					actualHealing = healing; // The healing variable decides the maximum amount of healing
				
				healing = actualHealing;
			}
			
			int maxHealth = GetMaxHealth(attacker);
			if (lastHealth[attacker] < maxHealth) {
				lastHealingOnHit[attacker] = min(maxHealth - lastHealth[attacker], healing);
			}
		}
	
		if (attackerClass == TFClass_Sniper && GetPlayerWeaponSlot(attacker, 0) == weapon) {
			if (defid == 56 || defid == 1005) {
				// Huntsman
				lastHeadshot[attacker] = (damagecustom & 1) != 0;
			} else {
				// All other sniper rifles
				lastHeadshot[attacker] = (damagecustom & 8) == 0;
			}
		} else if (defid == 61 || defid == 1006) {
			// Ambassador
			lastHeadshot[attacker] = (damagecustom & 1) != 0;
		}
		
		if (wasDirect && (attackerClass == TFClass_Soldier || attackerClass == TFClass_DemoMan) && GetPlayerWeaponSlot(attacker, 0) == weapon) {
			SetLastAirshotValues(attacker, victim);
		}
		
		if (attackerClass == TFClass_Medic && GetPlayerWeaponSlot(attacker, 0) == weapon) {
			if (StrEqual(lastWeaponDamage[attacker], "crusaders_crossbow")) {
				SetLastAirshotValues(attacker, victim);
			}
		}

		if (postHumousDamage) {
			// Sometimes these "Post Humous Damage" weapons can do damage AFTER you die or change class (like Boston Basher, Flamethrower, etc.)
			// Remember the weapon, and if we deal damage from an unknown weapon, then credit it to the last Post Humous Damage weapon.
			strcopy(lastPostHumousWeaponDamage[attacker], MAXWEPNAMELEN, lastWeaponDamage[attacker]);
			lastPostHumousWeaponDamageTime[attacker] = GetEngineTime();
		}
		
		
		// ---- ACCURACY ----
		if (g_bEnableAccuracy) {
			if (inflictor > MaxClients && IsValidEntity(inflictor)) {
				// Projectile shot
				
				char classname[128];
				GetEntityClassname(inflictor, classname, sizeof(classname));
				
				int shotType;
				if (GetTrieValue(g_tShotTypes, classname, shotType)) {
					// The class checks are required to avoid pyros getting a shot_hit on a reflect rocket, without any shot_fired.
					bool isRocket = shotType == SHOT_ROCKET && attackerClass == TFClass_Soldier;
					bool isGrenade = shotType == SHOT_PIPE && attackerClass == TFClass_DemoMan;
					bool isSticky = shotType == SHOT_STICKY && attackerClass == TFClass_DemoMan;
					bool isNeedle = shotType == SHOT_NEEDLE && attackerClass == TFClass_Medic;
					if (isRocket || isGrenade || isNeedle) {
						bool foundIgnore = false;
						int foundEmpty = -1;
						if (!isNeedle) {
							for (int i = 0; i < sizeof(g_iIgnoreDamageEnt); i++) {
								if (g_iIgnoreDamageEnt[i] == inflictor) {
									foundIgnore = true;
									break;
								}
								
								if (foundEmpty == -1 && g_iIgnoreDamageEnt[i] == 0)
									foundEmpty = i;
							}
						}
						
						if (!foundIgnore) {
							if (!isNeedle) {
								if (foundEmpty != -1)
										g_iIgnoreDamageEnt[foundEmpty] = inflictor;
								else
									LogError("Did not find empty IgnoreDamage spot (%i,%i,%i,%i,%i)", g_iIgnoreDamageEnt[0], g_iIgnoreDamageEnt[1], g_iIgnoreDamageEnt[2], g_iIgnoreDamageEnt[3], g_iIgnoreDamageEnt[4]);
							}
							
							if (isRocket) {
								g_bRocketHurtEnemy[attacker] = true;
								LogHit(attacker, lastWeaponDamage[attacker]);
							} else if (isGrenade)
								LogHit(attacker, lastWeaponDamage[attacker]);
							else if (isNeedle)
								LogHit(attacker, lastWeaponDamage[attacker]);
						}
					} else if (isSticky) {
						int stickyPos = FindStickySpot(attacker, inflictor, true);
						
						if (stickyPos != -1) {
							g_bStickyHurtEnemy[attacker][stickyPos] = true;
						}
					}
				}
			} else if (inflictor > 0 && inflictor <= MaxClients && IsValidEntity(weapon)) {
				// Hitscan shot
				
				char classname[128];
				GetEntityClassname(weapon, classname, sizeof(classname));
				
				int shotType;
				if (GetTrieValue(g_tShotTypes, classname, shotType) && shotType >= SHOT_HITSCAN_MIN && shotType < SHOT_HITSCAN_MAX) {
					float now = GetEngineTime();
					if ((now - g_fLastHitscanHit[attacker]) > 0.05) {
						LogHit(attacker, lastWeaponDamage[attacker]);
						
						g_fLastHitscanHit[attacker] = now;
						g_bHitscanHurtEnemy[attacker] = true;
					}
				}
			} else {
				char attackerName[64];
				char victimName[64];
				GetClientName(attacker, attackerName, sizeof(attackerName));
				GetClientName(victim, victimName, sizeof(victimName));
				LogError("Accuracy: attacker(%s) victim(%s) inflictor(%i) weapon(%i) defid(%i)", attackerName, victimName, inflictor, weapon, defid);
			}
		}
		// ---- ACCURACY ----
	}
	
	return Plugin_Continue;
}

public void Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast) {
	int victimid = GetEventInt(event, "userid");
	int victim = GetClientOfUserId(victimid);
	int attackerid = GetEventInt(event, "attacker");
	int attacker = GetClientOfUserId(attackerid);
	int damage = GetEventInt(event, "damageamount");
	
	bool crit = GetEventBool(event, "crit");
	bool minicrit = GetEventBool(event, "minicrit");
	
	if (victim != attacker && attacker != 0) {
		char attackerName[NAMELEN];
		char attackerSteamID[64];
		char attackerTeam[32];
		char victimName[NAMELEN];
		char victimSteamID[64];
		char victimTeam[32];
		
		GetClientName(attacker, attackerName, sizeof(attackerName));
		GetClientAuthStringNew(attacker, attackerSteamID, sizeof(attackerSteamID), false);
		GetPlayerTeamStr(GetClientTeam(attacker), attackerTeam, sizeof(attackerTeam));
		
		GetClientName(victim, victimName, sizeof(victimName));
		GetClientAuthStringNew(victim, victimSteamID, sizeof(victimSteamID), false);
		GetPlayerTeamStr(GetClientTeam(victim), victimTeam, sizeof(victimTeam));
		
		char strHealing[32] = "";
		char strCrit[32] = "";
		char strRealDamage[32] = "";
		char strHeadshot[32] = "";
		char strAirshot[64] = "";

		int healing = lastHealingOnHit[attacker];
		if (healing != 0 && IsPlayerAlive(attacker))
			FormatEx(strHealing, sizeof(strHealing), " (healing \"%i\")", healing);
		
		if (minicrit)
			strcopy(strCrit, sizeof(strCrit), " (crit \"mini\")");
		else if (crit)
			strcopy(strCrit, sizeof(strCrit), " (crit \"crit\")");
		
		// When a person with 20 health takes 50 damage, his health will be -30.
		// So the real damage done is 50 + (-30) = 20.
		int clienthealth = GetClientHealth(victim);
		int realdamage = damage;
		if (clienthealth < 0) {
			realdamage += clienthealth;
			FormatEx(strRealDamage, sizeof(strRealDamage), " (realdamage \"%i\")", realdamage);
		}
		
		if (lastHeadshot[attacker])
			strcopy(strHeadshot, sizeof(strHeadshot), " (headshot \"1\")");
		
		if (lastAirshot[attacker]) {
			Format(strAirshot, sizeof(strAirshot), " (airshot \"1\") (height \"%i\")", lastAirshotHeight[attacker]);
			lastAirshot[attacker] = false;
		}

		// Remember: The attacker can be dead!
		
		LogToGame("\"%s<%d><%s><%s>\" triggered \"damage\" against \"%s<%d><%s><%s>\" (damage \"%d\")%s (weapon \"%s\")%s%s%s%s",
			attackerName,
			attackerid,
			attackerSteamID,
			attackerTeam,
			victimName,
			victimid,
			victimSteamID,
			victimTeam,
			damage,
			strRealDamage,
			lastWeaponDamage[attacker],
			strHealing,
			strCrit,
			strAirshot,
			strHeadshot);
	}
}

public void OnProjectileTouch(int entity, int other) {
	if (other > 0 && other <= MaxClients) {
		g_bPlayerTakenDirectHit[other] = true;
	}
}

// ---- ACCURACY ----
public void OnEntityCreated(int entity, const char[] classname) {
	int shotType;
	if (!GetTrieValue(g_tShotTypes, classname, shotType))
		return;
	
	if (shotType == SHOT_ROCKET || shotType == SHOT_PIPE) {
		SDKHook(entity, SDKHook_Touch, OnProjectileTouch); // Detecting direct hits
		
		if (g_bEnableAccuracy) {
			float now = GetEngineTime();
			float oldestTime = now + 1.0;
			int oldest = -1;
			bool found = false;
			
			for (int j = 0; j < MAXROCKETS; j++) {
				if (g_iRocketCreatedEntity[g_iRocketCreatedNext] == 0) {
					g_iRocketCreatedEntity[g_iRocketCreatedNext] = entity;
					g_fRocketCreatedTime[g_iRocketCreatedNext] = now;
					found = true;
					break;
				}
				
				if (g_fRocketCreatedTime[g_iRocketCreatedNext] < oldestTime) {
					oldest = j;
					oldestTime = g_fRocketCreatedTime[g_iRocketCreatedNext];
				}
				
				g_iRocketCreatedNext++;
				if (g_iRocketCreatedNext == MAXROCKETS)
					g_iRocketCreatedNext = 0;
			}
			
			if (!found) {
				g_iRocketCreatedNext = oldest;
				g_iRocketCreatedEntity[g_iRocketCreatedNext] = entity;
				g_fRocketCreatedTime[g_iRocketCreatedNext] = now;
			}
			
			g_iRocketCreatedNext++;
			if (g_iRocketCreatedNext == MAXROCKETS)
				g_iRocketCreatedNext = 0;
		}
	} else if (shotType == SHOT_HEALINGBOLT) {
		SDKHook(entity, SDKHook_Touch, OnHealArrowTouch); // Detecting when a healing arrow hits
	}
}

public void OnHealArrowTouch(int entity, int other) {
	if (other > 0 && other <= MaxClients) {
		TFTeam team = view_as<TFTeam>(GetClientTeam(other));
		if (team == TFTeam_Red || team == TFTeam_Blue) { // Ignore if we hit a spectator. (This check might not be necessary.)
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
			if (IsClientValid(owner) && TF2_GetPlayerClass(owner) == TFClass_Medic) {
				int weapon = GetEntPropEnt(entity, Prop_Send, "m_hLauncher");
				if (IsValidEntity(weapon)) {
					// Enables logging of airshots for healing arrows
					lastAirshot[owner] = false;
					SetLastAirshotValues(owner, other);

					if (g_bEnableAccuracy) {
						int healing;
						int defid;
						bool postHumousDamage;
						char weap[64];
						weap[0] = '\0';
						if (GetWeaponLogName(weap, sizeof(weap), owner, weapon, healing, defid, postHumousDamage, entity)) {
							LogHit(owner, weap);
						}
					}
				}
			}
		}
	}
}

public void OnEntityDestroyed(int entity) {
	if (entity <= MaxClients)
		return;
	
	for (int i = 0; i < sizeof(g_iIgnoreDamageEnt); i++) {
		if (g_iIgnoreDamageEnt[i] == entity) {
			g_iIgnoreDamageEnt[i] = 0;
			break;
		}
	}
	
	for (int i = 0; i < MAXROCKETS; i++) {
		if (g_iRocketCreatedEntity[i] == entity) {
			g_iRocketCreatedEntity[i] = 0;
			break;
		}
	}
	
	if (g_bEnableAccuracy) {
		char clsname[32];
		GetEntityClassname(entity, clsname, sizeof(clsname));
		int shotType;
		if (GetTrieValue(g_tShotTypes, clsname, shotType) && shotType == SHOT_STICKY) {
			int owner = GetEntPropEnt(entity, Prop_Send, "m_hThrower");
			if (IsRealPlayer(owner)) { // Check that the owner didn't disconnect
				int stickyPos = FindStickySpot(owner, entity);
				
				bool shot = true;
				bool hit = false;
				if (stickyPos != -1) {
					hit = g_bStickyHurtEnemy[owner][stickyPos];
					if (!hit)
						shot = !g_bStickyHurtMe[owner][stickyPos];
					
					g_iStickyId[owner][stickyPos] = 0;
				}
				
				if (shot || hit) {
					char weap[64];
					weap[0] = '\0';
					int healing;
					int defid;
					bool postHumousDamage;
					GetWeaponLogName(weap, sizeof(weap), owner, GetPlayerWeaponSlot(owner, 1), healing, defid, postHumousDamage, entity); // We are setting inflictor = attacker
					
					if (shot) 
						LogShot(owner, weap);
					if (hit)
						LogHit(owner, weap);
				}
			}
		}
	}
}


public Action LogRocketShot(Handle timer, any client) {
	if (!IsRealPlayer(client))
		return Plugin_Continue;
	
	if (!g_bRocketHurtMe[client] || g_bRocketHurtEnemy[client]) {
		LogToGame("%s", g_sRocketFiredLogLine[client]);
	}
	return Plugin_Continue;
}

public Action LogHitscanShot(Handle timer, any client) {
	if (!IsRealPlayer(client))
		return Plugin_Continue;
	
	if (g_bHitscanHurtEnemy[client]) {
		LogToGame("%s", g_sHitscanFiredLogLine[client]);
	}
	return Plugin_Continue;
}

public Action TF2_CalcIsAttackCritical(int attacker, int weapon, char[] weaponname, bool &result) {
	if (!g_bEnableAccuracy)
		return Plugin_Continue;
	
	if (attacker > 0 && attacker <= MaxClients) {
		int healing;
		int defid;
		bool postHumousDamage;
		int shotType;
		if (GetTrieValue(g_tShotTypes, weaponname, shotType)) {
			char weap[64];
			weap[0] = '\0';
			GetWeaponLogName(weap, sizeof(weap), attacker, weapon, healing, defid, postHumousDamage, attacker); // We are setting inflictor = attacker
			
			if (shotType == SHOT_ROCKET) {
				FormatShot(attacker, weap, g_sRocketFiredLogLine[attacker], sizeof(g_sRocketFiredLogLine[]));
				g_bRocketHurtMe[attacker] = false;
				g_bRocketHurtEnemy[attacker] = false;
				CreateTimer(MAXROCKETJUMPTIME, LogRocketShot, attacker, TIMER_FLAG_NO_MAPCHANGE);
			} else if (shotType == SHOT_PIPE || shotType == SHOT_NEEDLE || shotType == SHOT_HEALINGBOLT) {
				LogShot(attacker, weap);
			} else if (shotType == SHOT_HITSCAN) {
				bool sticky = false;
				int aiment = GetClientAimTarget(attacker, false);
				if (aiment >= 0 && IsValidEntity(aiment)) {
					char aimentstr[64];
					Entity_GetClassName(aiment, aimentstr, sizeof(aimentstr));
					if (StrEqual(aimentstr, "tf_projectile_pipe_remote", false)) {
						sticky = true;
					}
				}
				
				if (sticky) {
					FormatShot(attacker, weap, g_sHitscanFiredLogLine[attacker], sizeof(g_sHitscanFiredLogLine[]));
					g_bHitscanHurtEnemy[attacker] = false;
					CreateTimer(MAXHITSCANTIME, LogHitscanShot, attacker, TIMER_FLAG_NO_MAPCHANGE);
				} else {
					LogShot(attacker, weap);
				}
			}
		}
	}
	
	return Plugin_Continue;
}

void LogShot(int attacker, const char[] weapon) {
	// For performance, don't use FormatShot.
	
	int attackerid = GetClientUserId(attacker);
	char attackerName[NAMELEN];
	char attackerSteamID[64];
	char attackerTeam[32];
	
	GetClientName(attacker, attackerName, sizeof(attackerName));
	GetClientAuthStringNew(attacker, attackerSteamID, sizeof(attackerSteamID), false);
	GetPlayerTeamStr(GetClientTeam(attacker), attackerTeam, sizeof(attackerTeam));
	
	LogToGame(
		"\"%s<%d><%s><%s>\" triggered \"shot_fired\" (weapon \"%s\")",
		attackerName,
		attackerid,
		attackerSteamID,
		attackerTeam,
		weapon);
}

void FormatShot(int attacker, const char[] weapon, char[] dest, int destlen) {
	int attackerid = GetClientUserId(attacker);
	char attackerName[NAMELEN];
	char attackerSteamID[64];
	char attackerTeam[32];
	
	GetClientName(attacker, attackerName, sizeof(attackerName));
	GetClientAuthStringNew(attacker, attackerSteamID, sizeof(attackerSteamID), false);
	GetPlayerTeamStr(GetClientTeam(attacker), attackerTeam, sizeof(attackerTeam));
	
	Format(dest, destlen, 
		"\"%s<%d><%s><%s>\" triggered \"shot_fired\" (weapon \"%s\")",
		attackerName,
		attackerid,
		attackerSteamID,
		attackerTeam,
		weapon);
	
	
}

void LogHit(int attacker, const char[] weapon) {
	int attackerid = GetClientUserId(attacker);
	char attackerName[NAMELEN];
	char attackerSteamID[64];
	char attackerTeam[32];
	
	GetClientName(attacker, attackerName, sizeof(attackerName));
	GetClientAuthStringNew(attacker, attackerSteamID, sizeof(attackerSteamID), false);
	GetPlayerTeamStr(GetClientTeam(attacker), attackerTeam, sizeof(attackerTeam));
	
	LogToGame("\"%s<%d><%s><%s>\" triggered \"shot_hit\" (weapon \"%s\")",
		attackerName,
		attackerid,
		attackerSteamID,
		attackerTeam,
		weapon);
}
// ---- ACCURACY ----


void SetLastAirshotValues(int attacker, int victim) {
	if ((GetEntityFlags(victim) & (FL_ONGROUND | FL_INWATER)) == 0) {
		// The victim is in the air
		float distance = DistanceAboveGroundBox(victim);
		if (distance >= 170.0) {
			lastAirshot[attacker] = true;
			lastAirshotHeight[attacker] = RoundToFloor(distance);
		}
	}
}


float DistanceAboveGroundBox(int victim) {
	float vStart[3];
	float vDirection[3] = { 0.0, 0.0, -16384.0 };
	float vHullMins[3]  = { -24.0, -24.0, 0.0 };
	float vHullMaxs[3]  = { 24.0, 24.0, 0.0 };
	
	GetClientAbsOrigin(victim, vStart);
	float vEnd[3];
	AddVectors(vDirection, vStart, vEnd);

	Handle trace = TR_TraceHullFilterEx(vStart, vEnd, vHullMins, vHullMaxs, MASK_PLAYERSOLID, TraceEntityFilterPlayer);
	
	float distance = -1.0;
	if (TR_DidHit(trace)) {
		TR_GetEndPosition(vEnd, trace);
		distance = GetVectorDistance(vStart, vEnd, false);
	} else {
		LogError("trace error. victim %N(%d)", victim, victim);
	}
	
	CloseHandle(trace);
	return distance;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
	return entity > MaxClients || !entity;
}




// F2's WeaponLogName
bool GetWeaponLogName(char[] logname, int lognameLen, int attacker, int weapon, int &healing, int &defid, bool &postHumousDamage, int inflictor = -1) {
	defid = -1;
	if (IsValidEntity(weapon))
		defid = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	//PrintToChatAll("attacker(%i) weapon(%i) inflictor(%i) defid(%i)", attacker, weapon, inflictor, defid);
	
	if (defid == -1) {
		// Weapon was -1. It is probably a sentry shooting.
		if (inflictor > MaxClients && IsValidEntity(inflictor)) {
			int sentry = inflictor;
			GetEntityClassname(sentry, logname, lognameLen);
			if (StrEqual(logname, "tf_projectile_sentryrocket")) {
				// A sentry rocket hurt the victim. Find the sentry entity, and consider that the inflictor.
				sentry = GetEntPropEnt(sentry, Prop_Send, "m_hOwnerEntity");
				GetEntityClassname(sentry, logname, lognameLen);
			}
			
			if (StrEqual(logname, "obj_sentrygun")) {
				// Match the "killed" logs
				// - Level 1: obj_sentrygun
				// - Level 2: obj_sentrygun2
				// - Level 3: obj_sentrygun3
				// - Minisentry: obj_minisentry
				// - Wrangler: wrangler_kill
				
				int shield = GetEntProp(sentry, Prop_Send, "m_nShieldLevel");
				if (shield != 0) {
					// Wrangler is used (valid for sentries of all levels, and mini sentries)
					strcopy(logname, lognameLen, "wrangler_kill");
				} else if (GetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1)) {
					// It is a mini non-wrangled sentry
					strcopy(logname, lognameLen, "obj_minisentry");
				} else {
					// It is a non-wrangled normal sentry
					int sentryLevel = GetEntProp(sentry, Prop_Send, "m_iUpgradeLevel");
					if (sentryLevel != 1) {
						logname[13] = '0' + sentryLevel;
						logname[14] = '\0';
					}
				}
				
				return true;
			}
		}
	} else if (inflictor >= 1 && inflictor <= MaxClients) {
		// Hitscan / melee
		
		bool res = WeaponFromDefid(defid, logname, lognameLen, healing, postHumousDamage);
		 
		TFClassType attackerClass = TF2_GetPlayerClass(attacker);
		
		if (StrEqual(logname, "shotgun") || StrEqual(logname, "shotgun_primary")) {		
			// Upgradable shotgun - it has the same name for all classes in items_game.txt, but not in logs.
			if (attackerClass == TFClass_Soldier) {
				strcopy(logname, lognameLen, "shotgun_soldier");
			} else if (attackerClass == TFClass_Pyro) {
				strcopy(logname, lognameLen, "shotgun_pyro");
			} else if (attackerClass == TFClass_Heavy) {
				strcopy(logname, lognameLen, "shotgun_hwg");
			} else { // Engy
				strcopy(logname, lognameLen, "shotgun_primary");
			}
			res = true;
		} else if (StrEqual(logname, "pistol")) {
			// Upgradable pistol - it has the same name for all classes in items_game.txt, but not in logs.
			if (attackerClass == TFClass_Scout) {
				strcopy(logname, lognameLen, "pistol_scout");
			} else { // Engy
				strcopy(logname, lognameLen, "pistol");
			}
			res = true;
		}
		
		return res;
	} else if ((defid <= 30 /*standard weapons*/ || defid == 56 /*huntsman*/ || (defid >= 190 && defid <= 212 /*named standard weapons*/)) && inflictor > MaxClients && IsValidEntity(inflictor)) {
		// Projectiles from standard weapons + huntsman. These are named after the projectile.
		GetEntityClassname(inflictor, logname, lognameLen);
		
		if (StrContains(logname, "tf_weapon_") == 0)
			strcopy(logname, lognameLen, logname[10]);
		
		return true;
	} else {
		// Projectiles from non-standard weapons. These are named after the weapon.
		return WeaponFromDefid(defid, logname, lognameLen, healing, postHumousDamage);
	}
	
	return false;
}

// F2's Weapon Info Importer
Handle g_hAllWeaponsName = INVALID_HANDLE; // names of all weapons saved in an Array
int g_iAllWeaponsDefid[MAXWEAPONS]; // defids of all weapons
int g_iAllWeaponsHealingOnHit[MAXWEAPONS];
bool g_bAllWeaponsPostHumousDamage[MAXWEAPONS];
int g_iAllWeaponsCount = 0;
f
int g_iSlotWeaponDefid[MAXWEAPONS];
int g_iSlotWeaponSlot[MAXWEAPONS]; // translates defid -> weapon slot
int g_iSlotWeaponCount = 0;

int WeaponIndexFromName(const char[] weaponname) {
	int size = GetArraySize(g_hAllWeaponsName);
	
	int partialmatch = -1;
	
	for (int i = 0; i < size; i++) {
		char cname[MAXWEPNAMELEN];
		GetArrayString(g_hAllWeaponsName, i, cname, sizeof(cname));
		
		if (StrEqual(cname, weaponname, false)) {
			return g_iAllWeaponsDefid[i];
		}
		
		if (partialmatch == -1 && StrContains(cname, weaponname, false) != -1) {
			partialmatch = g_iAllWeaponsDefid[i];
		}
	}
	
	return partialmatch;
}

const int WEPCACHESIZE = 50;
const int MAXDEFID = 2048;
int g_iCachedWeaponBucket[MAXDEFID+1];
int g_iCachedWeaponDefid[WEPCACHESIZE];
int g_iCachedWeaponTime[WEPCACHESIZE];
char g_sCachedWeaponName[WEPCACHESIZE][MAXWEPNAMELEN];
int g_iCachedWeaponHealing[WEPCACHESIZE];
bool g_bCachedWeaponPostHumousDamage[WEPCACHESIZE];
int g_iCachedWeaponLength = 0;

void InitWeaponCache() {
	g_iCachedWeaponLength = 0;
	Array_Fill(g_iCachedWeaponBucket, sizeof(g_iCachedWeaponBucket), -1);
	Array_Fill(g_iCachedWeaponDefid, sizeof(g_iCachedWeaponDefid), -1);
}

bool WeaponFromDefid(int defid, char[] name, int maxlen, int &healing, bool &postHumousDamage) {
	if (defid <= MAXDEFID) {
		int bucket = g_iCachedWeaponBucket[defid];
		if (bucket != -1) {
			g_iCachedWeaponTime[bucket] = GetTime(); // I benchmarked GetTime(). On my computer it can run roughly 10,000,000 times per second. That is 18,000,000,000 per 30 minutes. In a normal match there are around 2,500 damage log lines.
			strcopy(name, maxlen, g_sCachedWeaponName[bucket]);
			healing = g_iCachedWeaponHealing[bucket];
			postHumousDamage = g_bCachedWeaponPostHumousDamage[bucket];
			return true;
		}
	} else {
		for (int i = 0; i < g_iCachedWeaponLength; i++) {
			if (g_iCachedWeaponDefid[i] == defid) {
				g_iCachedWeaponTime[i] = GetTime();
				strcopy(name, maxlen, g_sCachedWeaponName[i]);
				healing = g_iCachedWeaponHealing[i];
				postHumousDamage = g_bCachedWeaponPostHumousDamage[i];
				return true;
			}
		}
	}
	
	//LogToGame2("[WeaponFromDefid] Cache miss: %i", defid);
	
	for (int i = 0; i < g_iAllWeaponsCount; i++) {
		if (g_iAllWeaponsDefid[i] == defid) {
			GetArrayString(g_hAllWeaponsName, i, name, maxlen);
			healing = g_iAllWeaponsHealingOnHit[i];
			postHumousDamage = g_bAllWeaponsPostHumousDamage[i];
			
			int insertAt = -1;
			int time = GetTime();
			if (g_iCachedWeaponLength < WEPCACHESIZE) {
				insertAt = g_iCachedWeaponLength;
				g_iCachedWeaponLength++;
			} else {
				int minTime = time + 1;
				for (int j = 0; j < g_iCachedWeaponLength; j++) {
					if (g_iCachedWeaponTime[j] < minTime) {
						minTime = g_iCachedWeaponTime[j];
						insertAt = j;
					}
				}
				
				if (g_iCachedWeaponDefid[insertAt] <= MAXDEFID)
					g_iCachedWeaponBucket[g_iCachedWeaponDefid[insertAt]] = -1;
			}
			
			g_iCachedWeaponDefid[insertAt] = defid;
			strcopy(g_sCachedWeaponName[insertAt], MAXWEPNAMELEN, name);
			g_iCachedWeaponHealing[insertAt] = healing;
			g_bCachedWeaponPostHumousDamage[insertAt] = postHumousDamage;
			if (defid <= MAXDEFID)
				g_iCachedWeaponBucket[defid] = insertAt;
			
			return true;
		}
	}
	
	return false;
}

void ImportWeaponDefinitions() {
	g_hAllWeaponsName = CreateArray(MAXWEPNAMELEN);
	g_iAllWeaponsCount = 0;
	g_iSlotWeaponCount = 0;
	
	char path[] = "scripts/items/items_game.txt";
	
	if (!FileExists(path, true))
		SetFailState("Could not find items_game.txt: %s", path);
	
	// Load items_game.txt for prefabs
	Handle kvPrefabs = KvizCreateFromFile("items_game", path);
	if (kvPrefabs == INVALID_HANDLE)
		SetFailState("Could not load items_game.txt");
	
	// Go to prefabs section
	if (!KvizJumpToKey(kvPrefabs, false, "prefabs"))
		SetFailState("items_game.txt: '%s' key not found", "prefabs");
	
	// Load items_game.txt for items traversal
	Handle kv = KvizCreateFromFile("items_game", path);
	if (kvPrefabs == INVALID_HANDLE)
		SetFailState("Could not load items_game.txt");
	
	// Go to items section
	if (!KvizJumpToKey(kv, false, "items"))
		SetFailState("items_game.txt: '%s' key not found", "items");
	
	for (int itemId = 1; KvizJumpToKey(kv, false, ":nth-child(%i)", itemId); KvizGoBack(kv), itemId++) {
		// Get the item defid
		int defid;
		if (!KvizGetNumExact(kv, defid, ":section-name"))
			continue;
		
		//if (KvizExist(kv, ":nth-child(%i).item_paintkit", itemId)) {
		//	char prefab[64];
		//	if (KvizGetStringExact(kv, ":nth-child(%i).prefab", itemId)) {
		//		
		//	}
		//}
		
		// Check if it is a stock weapon or a named stock weapon
		bool isStockWeapon = defid <= 30;
		bool isUpgradableStockWeapon = (defid >= 190 && defid <= 212);
		
		// Get the craft class
		char craftclass[32];
		GetItemString(kv, kvPrefabs, "craft_class", craftclass, sizeof(craftclass), "");
		
		// Get the slot for the item
		char itemslot[32];
		GetItemString(kv, kvPrefabs, "item_slot", itemslot, sizeof(itemslot));
		int slot = -1;
		if (StrEqual(itemslot, "primary", false))
			slot = 0;
		else if (StrEqual(itemslot, "secondary", false))
			slot = 1;
		else if (StrEqual(itemslot, "melee", false))
			slot = 2;
		else if (StrEqual(itemslot, "pda", false))
			slot = 3;
		else if (StrEqual(itemslot, "pda2", false))
			slot = 4;
		else if (StrEqual(itemslot, "head", false))
			slot = 5;
		else if (StrEqual(itemslot, "misc", false))
			slot = 6;
		else if (StrEqual(itemslot, "action", false))
			slot = 7;
		
		// Get the item class
		char itemclass[MAXITEMCLASSLEN];
		GetItemString(kv, kvPrefabs, "item_class", itemclass, sizeof(itemclass));
		
		// Check if the item is a weapon
		bool isWeapon = (slot >= 0 && slot <= 4) && (StrEqual(craftclass, "weapon", false) == true || StrEqual(craftclass, "", false) == true);
		
		// Check if the item is a hat
		bool isHat = (slot == 5 || slot == 6) && (StrEqual(itemclass, "tf_wearable_item", false) == true);
		
		// Check if the item is a medigun
		bool isMedigun = StrEqual(itemclass, "tf_weapon_medigun");
		
		// Save the slot (in case we want to replace the player's weapon later)
		if (isWeapon || isHat) {
			if (g_iSlotWeaponCount >= MAXWEAPONS)
				SetFailState("Too many weapons. (%i)", g_iSlotWeaponCount);
			
			int pos = g_iSlotWeaponCount - 1;
			
			// Insert slot & defid using insertion sort
			while (pos >= 0 && g_iSlotWeaponDefid[pos] > defid) {
				g_iSlotWeaponDefid[pos + 1] = g_iSlotWeaponDefid[pos];
				g_iSlotWeaponSlot[pos + 1] = g_iSlotWeaponSlot[pos];
				
				pos--;
			}
			g_iSlotWeaponDefid[pos + 1] = defid;
			g_iSlotWeaponSlot[pos + 1] = slot;
			
			g_iSlotWeaponCount++;
		}
		
		// Save the weapon and corresponding defid if it's not a stock weapon
		if (isWeapon) {
			if (g_iAllWeaponsCount >= MAXWEAPONS)
				SetFailState("Too many weapons. (%i)", g_iAllWeaponsCount);
			
			char itemname[MAXWEPNAMELEN] = "";
			
			if (defid == 130) {
				strcopy(itemname, sizeof(itemname), "sticky_resistance"); // Scottish Resistance has the wrong name in items_game.txt
			} else if (defid == 35) {
				strcopy(itemname, sizeof(itemname), "kritzkrieg");
			} else if (defid == 411) {
				strcopy(itemname, sizeof(itemname), "quickfix");
			} else if (defid == 998) {
				strcopy(itemname, sizeof(itemname), "vaccinator");
			} else if (isMedigun) {
				// It is some other medigun. As of this writing, the only other possibility is a normal medigun (or skin of it). /F2, 21-10-2015
				GetItemString(kv, kvPrefabs, "name", itemname, sizeof(itemname));
				strcopy(itemname, sizeof(itemname), "medigun");
			} else {
				GetItemString(kv, kvPrefabs, "item_logname", itemname, sizeof(itemname));
				if (StrEqual(itemname, "")) {
					if (isStockWeapon || isUpgradableStockWeapon || isMedigun)
						GetItemString(kv, kvPrefabs, "name", itemname, sizeof(itemname));
					
					if (!StrEqual(itemname, "")) {
						if (F2_String_StartsWith(itemname, "Upgradeable ", false))
							strcopy(itemname, sizeof(itemname), itemname[12]);
						if (F2_String_StartsWith(itemname, "tf_weapon_", false))
							strcopy(itemname, sizeof(itemname), itemname[10]);
					} else {
						GetItemString(kv, kvPrefabs, "item_class", itemname, sizeof(itemname));
					}
					
					if (!StrEqual(itemname, "")) {
						if (F2_String_StartsWith(itemname, "tf_weapon_", false))
							strcopy(itemname, sizeof(itemname), itemname[10]);
						if (StrEqual(itemname, "rocketlauncher", false))
							strcopy(itemname, sizeof(itemname), "tf_projectile_rocket");
						else if (StrEqual(itemname, "pipebomblauncher", false))
							strcopy(itemname, sizeof(itemname), "tf_projectile_pipe_remote");
						else if (StrEqual(itemname, "grenadelauncher", false))
							strcopy(itemname, sizeof(itemname), "tf_projectile_pipe");
					}
				}
			}
			
			if (StrEqual(itemname, ""))
				Format(itemname, sizeof(itemname), "unknown(%i)", defid);
			
			String_ToLower(itemname, itemname, sizeof(itemname));
			
			PushArrayString(g_hAllWeaponsName, itemname);
			g_iAllWeaponsDefid[g_iAllWeaponsCount] = defid;
			g_iAllWeaponsHealingOnHit[g_iAllWeaponsCount] = 0;
			char attr[16];
			if (GetItemAttribute(kv, kvPrefabs, "add_onhit_addhealth", attr, sizeof(attr)) || GetItemAttribute(kv, kvPrefabs, "add_health_on_radius_damage", attr, sizeof(attr))) {
				//PrintToChatAll("health on hit(%i) name(%s)", attr, itemname);
				g_iAllWeaponsHealingOnHit[g_iAllWeaponsCount] = StringToInt(attr);
			}
			g_bAllWeaponsPostHumousDamage[g_iAllWeaponsCount] = GetItemTag(kv, kvPrefabs, "can_deal_posthumous_damage", false);
			g_iAllWeaponsCount++;
		
		}
	}
	
	// Clean up
	KvizGoBack(kv); // items
	KvizGoBack(kvPrefabs); // prefabs
	
	KvizClose(kv);
	KvizClose(kvPrefabs);
	
	InitWeaponCache();
}

void GetItemString(Handle kv, Handle kvPrefabs, const char[] key, char[] value, int valueLen, const char[] def = "") {
	if (KvizGetString(kv, value, valueLen, "", key))
		return;
	
	char prefabs[128];
	KvizGetString(kv, prefabs, sizeof(prefabs), "", "prefab");
	if (StrEqual(prefabs, "")) {
		strcopy(value, valueLen, def);
		return;
	}
	
	int pos;
	char prefab[64];
	do {
		pos = FindCharInString(prefabs, ' ', true);
		if (pos == -1) {
			strcopy(prefab, sizeof(prefab), prefabs);
		} else {
			strcopy(prefab, sizeof(prefab), prefabs[pos+1]);
			prefabs[pos] = '\0';
		}
		
		if (GetItemStringFromPrefab(kvPrefabs, prefab, key, value, valueLen))
			return;
	} while(pos != -1);
	
	strcopy(value, valueLen, def);
}

bool GetItemStringFromPrefab(Handle kvPrefabs, const char[] prefab, const char[] key, char[] value, int valueLen) {
	if (KvizGetStringExact(kvPrefabs, value, valueLen, "%s.%s", prefab, key))
		return true;
	
	char prefabs[128];
	KvizGetString(kvPrefabs, prefabs, sizeof(prefabs), "", "%s.prefab", prefab);
	if (StrEqual(prefabs, ""))
		return false;
	
	int pos;
	char nextPrefab[64];
	do {
		pos = FindCharInString(prefabs, ' ', true);
		if (pos == -1) {
			strcopy(nextPrefab, sizeof(nextPrefab), prefabs);
		} else {
			strcopy(nextPrefab, sizeof(nextPrefab), prefabs[pos+1]);
			prefabs[pos] = '\0';
		}
		
		if (!StrEqual(nextPrefab, "paintkit_weapon", false)) {
			if (GetItemStringFromPrefab(kvPrefabs, nextPrefab, key, value, valueLen))
				return true;
		}
	} while(pos != -1);
	
	return false;
}


bool GetItemTag(Handle kv, Handle kvPrefabs, const char[] key, bool def = false) {
	int ret;
	if (KvizGetNumExact(kv, ret, "tags.%s", key))
		return ret != 0;
	
	char prefabs[128];
	KvizGetString(kv, prefabs, sizeof(prefabs), "", "prefab");
	if (StrEqual(prefabs, ""))
		return def;
	
	int pos;
	char prefab[64];
	do {
		pos = FindCharInString(prefabs, ' ', true);
		if (pos == -1) {
			strcopy(prefab, sizeof(prefab), prefabs);
		} else {
			strcopy(prefab, sizeof(prefab), prefabs[pos+1]);
			prefabs[pos] = '\0';
		}
		
		if (KvizGetNumExact(kvPrefabs, ret, "%s.tags.%s", prefab, key))
			return ret != 0;
	} while (pos != -1);
	
	return def;
}

bool GetItemAttribute(Handle kv, Handle kvPrefabs, const char[] attr, char[] value, int valueLen) {
	if (KvizGetStringExact(kv, value, valueLen, "attributes:any-child.attribute_class:has-value(%s):parent.value", attr))
		return true;
	
	char prefabs[128];
	KvizGetString(kv, prefabs, sizeof(prefabs), "", "prefab");
	if (StrEqual(prefabs, ""))
		return false;
	
	int pos;
	char prefab[64];
	do {
		pos = FindCharInString(prefabs, ' ', true);
		if (pos == -1) {
			strcopy(prefab, sizeof(prefab), prefabs);
		} else {
			strcopy(prefab, sizeof(prefab), prefabs[pos+1]);
			prefabs[pos] = '\0';
		}
		
		if (KvizGetStringExact(kvPrefabs, value, valueLen, "%s.attributes:any-child.attribute_class:has-value(%s):parent.value", prefab, attr))
			return true;
	} while(pos != -1);
	
	return false;
}
