#if defined _f2stocks_included
 #endinput
#endif
#define _f2stocks_included


/*

TODO:
- Check if !IsClientSourceTV(client) is necessary in IsRealPlayer()

*/

#include <tf2_stocks>


new Float:g_fCapMultipliers[] = { 0.0, // Harmonic numbers
	1.0000, 1.5000, 1.8333, 2.0833, 2.2833, 2.4500, 2.5929, 2.7179, 
	2.8290, 2.9290, 3.0199, 3.1032, 3.1801, 3.2516, 3.3182, 3.3807, 
	3.4396, 3.4951, 3.5477, 3.5977, 3.6454, 3.6908, 3.7343, 3.7760, 
	3.8160, 3.8544, 3.8915, 3.9272, 3.9617, 3.9950, 4.0272, 4.0585, 
	4.0888, 4.1182, 4.1468, 4.1746, 4.2016, 4.2279, 4.2535, 4.2785, 
	4.3029, 4.3267, 4.3500, 4.3727, 4.3949, 4.4167, 4.4380, 4.4588, 
	4.4792, 4.4992, 4.5188, 4.5380, 4.5569, 4.5754, 4.5936, 4.6115, 
	4.6290, 4.6463, 4.6632, 4.6799, 4.6963, 4.7124, 4.7283, 4.7439
};


new String:g_sClassNames[TFClassType][16] = {
	"Unknown", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer"
};

stock F2STOCKS_Dummy() {
	g_fCapMultipliers[0] = 0.0; // To avoid getting a "not used" warning
	g_sClassNames[0] = "Unknown";
}




new PrintToSTV_iLastStvClient; // Cached STV client id
stock PrintToSTV(const String:format[], any:...) {
	new stv = FindSTV();
	if (stv < 1)
		return;
	
	decl String:buffer[512];
	VFormat(buffer, sizeof(buffer), format, 2);
	PrintToChat(stv, "%s", buffer);
}

stock FindSTV() {
	if (!(PrintToSTV_iLastStvClient >= 1 && PrintToSTV_iLastStvClient <= MaxClients && IsClientConnected(PrintToSTV_iLastStvClient) && IsClientInGame(PrintToSTV_iLastStvClient) && IsClientSourceTV(PrintToSTV_iLastStvClient))) {
		PrintToSTV_iLastStvClient = -1;
		
		for (new client = 1; client <= MaxClients; client++) {
			if (IsClientConnected(client) && IsClientInGame(client) && IsClientSourceTV(client)) {
				PrintToSTV_iLastStvClient = client;
				break;
			}
		}
	}
	
	return PrintToSTV_iLastStvClient;
}

stock float TF2_GetPlayerUberLevel(int client, int &medigunEntity = -1) { // This function won't work if the player is dead, unless the correct medigunEntity is passed.
	int index = GetPlayerWeaponSlot(client, 1);
	if (index <= 0)
		index = medigunEntity;
	medigunEntity = -1;
	if (index > 0) {
		char classname[64];
		GetEntityNetClass(index, classname, sizeof(classname));
		if (StrEqual(classname, "CWeaponMedigun")) {
			medigunEntity = index;
			float value = GetEntPropFloat(index, Prop_Send, "m_flChargeLevel");
			return value;
		}
	}
	
	return 0.0;
}

stock Float:TF2_GetPlayerUberBuildTime(client) {
	if (IsRealPlayer(client) && TF2_GetPlayerClass(client) == TFClass_Medic) {
		new index = GetPlayerWeaponSlot(client, 1);
		if (index >= 0) {
			new defid = GetEntProp(index, Prop_Send, "m_iItemDefinitionIndex");
			if (defid == 35)
				return 32.0; // Kritzkrieg
			
			if (defid == 411)
				return 32.0; // Quickfix
			
			if (defid == 998)
				return 26.67; // Vaccinator, although this can be triggered already after 6.67 s
		}
	}
	return 40.0;
}

stock TF2_GetMedigunName(client, String:medigun[], medigunLen) {
	new weaponid = GetPlayerWeaponSlot(client, 1);
	if (weaponid >= 0) {
		new defid = GetEntProp(weaponid, Prop_Send, "m_iItemDefinitionIndex");
		if (defid == 29 || defid == 211 || defid == 663 || defid == 796 || defid == 805 || defid == 885 || defid == 894 || defid == 903 || defid == 912 || defid == 961 || defid == 970)
			strcopy(medigun, medigunLen, "medigun");
		else if (defid == 35)
			strcopy(medigun, medigunLen, "kritzkrieg");
		else if (defid == 411)
			strcopy(medigun, medigunLen, "quickfix");
		else if (defid == 998)
			strcopy(medigun, medigunLen, "vaccinator");
		else
			strcopy(medigun, medigunLen, "unknown"); // TODO: Doesn't work for skins.
	} else {
		strcopy(medigun, medigunLen, "");
	}
}

stock TF2_GetHealingTarget(client) {
	new String:classname[64];
	new index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (index > 0) {
		GetEntityNetClass(index, classname, sizeof(classname));
	
		if(StrEqual(classname, "CWeaponMedigun")) {
			if(GetEntProp(index, Prop_Send, "m_bHealing") == 1)
				return GetEntPropEnt(index, Prop_Send, "m_hHealingTarget");
		}
	}
	
	return -1;
}

stock TF2_GetCurrentWeaponClass(client, String:name[], maxlength) {
	if (client > 0) {
		new index = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (index > 0)
			GetEntityNetClass(index, name, maxlength);
	}
}

stock any:max(any:val1, any:val2) {
	return val1 > val2 ? val1 : val2;
}

stock any:min(any:val1, any:val2) {
	return val1 < val2 ? val1 : val2;
}

stock bool:IsClientValid(client) {
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}
stock bool:IsValidClient(client) {
	return IsClientValid(client);
}

stock bool:IsClientValid2(client) {
	return IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}
stock bool:IsValidClient2(client) {
	return IsClientValid2(client);
}

stock bool:IsRealPlayer(client) {
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}

stock bool:IsRealPlayer2(client) {
	return IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}

stock GetRealPlayerCount() {
	new c = 0;
	for (new client = 1; client <= MaxClients; client++)
		if (IsRealPlayer2(client))
			c++;
	return c;
}


// As opposed to CPrintToChatEx, this function only colorizes message, NOT the parameters
// Requires <morecolors>
stock CPrintToChatEx2(client, author, const String:message[], any:...) {
	CCheckTrie();
	if(client <= 0 || client > MaxClients) {
		ThrowError("Invalid client index %i", client);
	}
	if(!IsClientInGame(client)) {
		ThrowError("Client %i is not in game", client);
	}
	if(author <= 0 || author > MaxClients) {
		ThrowError("Invalid client index %i", author);
	}
	if(!IsClientInGame(author)) {
		ThrowError("Client %i is not in game", author);
	}
	decl String:buffer[MAX_MESSAGE_LENGTH], String:buffer2[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	Format(buffer, sizeof(buffer), "\x01%s", message);
	CReplaceColorCodes(buffer, author);
	VFormat(buffer2, sizeof(buffer2), buffer, 4);
	CSendMessage(client, buffer2, author);
}

// As opposed to CPrintToChatAllEx, this function only colorizes message, NOT the parameters
// Requires <morecolors>
stock CPrintToChatAllEx2(author, const String:message[], any:...) {
	CCheckTrie();
	if(author <= 0 || author > MaxClients) {
		ThrowError("Invalid client index %i", author);
	}
	if(!IsClientInGame(author)) {
		ThrowError("Client %i is not in game", author);
	}
	decl String:buffer[MAX_MESSAGE_LENGTH], String:buffer2[MAX_MESSAGE_LENGTH];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || CSkipList[i]) {
			CSkipList[i] = false;
			continue;
		}
		SetGlobalTransTarget(i);
		Format(buffer, sizeof(buffer), "\x01%s", message);
		CReplaceColorCodes(buffer, author);
		VFormat(buffer2, sizeof(buffer2), buffer, 3);
		CSendMessage(i, buffer2, author);
	}
}

// As opposed to CPrintToChat, this function only colorizes message, NOT the parameters
// Requires <morecolors>
stock CPrintToChat2(client, const String:message[], any:...) {
	CCheckTrie();
	if(client <= 0 || client > MaxClients) {
		ThrowError("Invalid client index %i", client);
	}
	if(!IsClientInGame(client)) {
		ThrowError("Client %i is not in game", client);
	}
	decl String:buffer[MAX_MESSAGE_LENGTH], String:buffer2[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	Format(buffer, sizeof(buffer), "\x01%s", message);
	CReplaceColorCodes(buffer);
	VFormat(buffer2, sizeof(buffer2), buffer, 3);
	CSendMessage(client, buffer2);
}

// As opposed to CPrintToChatAll, this function only colorizes message, NOT the parameters
// Requires <morecolors>
stock CPrintToChatAll2(const String:message[], any:...) {
	CCheckTrie();
	decl String:buffer[MAX_MESSAGE_LENGTH], String:buffer2[MAX_MESSAGE_LENGTH];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || CSkipList[i]) {
			CSkipList[i] = false;
			continue;
		}
		SetGlobalTransTarget(i);
		Format(buffer, sizeof(buffer), "\x01%s", message);
		CReplaceColorCodes(buffer);
		VFormat(buffer2, sizeof(buffer2), buffer, 2);
		CSendMessage(i, buffer2);
	}
}


stock GetPlayerTeamStr(team, String:teamstr[], teamstrLen) {
	switch (team) {
		case (_:TFTeam_Red):
			strcopy(teamstr, teamstrLen, "Red");
		case (_:TFTeam_Blue):
			strcopy(teamstr, teamstrLen, "Blue");
		default:
			strcopy(teamstr, teamstrLen, "unknown");
	}
}

stock TF2_GetPlayerScore(client) {
	if (!IsClientConnected(client))
		return -1;
	
	new offset = FindSendPropInfo("CTFPlayerResource", "m_iTotalScore");
	if (offset < 1)
		return -1;	
				
	new entity = GetPlayerResourceEntity();
	if (entity == -1)
		return -1;
	
	return GetEntData(entity, offset + (client*4));
}

// Based on smlib's implementation File_Copy
stock bool:CopyFile(const String:source[], const String:destination[]) {
	new Handle:file_source = OpenFile(source, "rb");
	if (file_source == INVALID_HANDLE)
		return false;

	new Handle:file_destination = OpenFile(destination, "wb");
	if (file_destination == INVALID_HANDLE) {
		CloseHandle(file_source);
		return false;
	}

	new buffer[4096];
	new cache;

	while (!IsEndOfFile(file_source)) {
		cache = ReadFile(file_source, buffer, sizeof(buffer), 1);
		WriteFile(file_destination, buffer, cache, 1);
	}

	CloseHandle(file_source);
	CloseHandle(file_destination);

	return true;
}


stock SetPlayerOutline(client, bool:enable) {
	SetEntProp(client, Prop_Send, "m_bGlowEnabled", enable ? 1 : 0, 1);
}

stock bool:GetPlayerOutline(client) {
	return GetEntProp(client, Prop_Send, "m_bGlowEnabled", 1) != 0;
}



// Based on psychonic's post https://forums.alliedmods.net/showpost.php?p=1865459&postcount=3
new Handle:fnGetMaxHealth = INVALID_HANDLE;
stock GetMaxHealth(client) {
	if (fnGetMaxHealth == INVALID_HANDLE) {
		new Handle:hConf = LoadGameConfigFile("sdkhooks.games");
		if (hConf == INVALID_HANDLE)
			SetFailState("Cannot find sdkhooks.games gamedata");
		
		StartPrepSDKCall(SDKCall_Entity);
		PrepSDKCall_SetFromConf(hConf, SDKConf_Virtual, "GetMaxHealth");
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
		fnGetMaxHealth = EndPrepSDKCall();
		
		if (fnGetMaxHealth == INVALID_HANDLE)
			SetFailState("Failed to set up GetMaxHealth sdkcall");
		
		CloseHandle(hConf);
	}
	
	return SDKCall(fnGetMaxHealth, client);
}

stock IntToBits(val, String:bitval[33]) {
	bitval[32] = '\0';
	for (new pos = 31; pos >= 0; pos--) {
		bitval[pos] = (val&1) == 1 ? '1' : '0';
		val >>= 1;
	}
}

stock bool:F2_String_StartsWith(const String:haystack[], const String:needle[], bool:caseSensitive = true) {
	new needleLen = strlen(needle);
	return strncmp(haystack, needle, needleLen, caseSensitive) == 0;
}

stock bool:F2_String_EndsWith(const String:haystack[], const String:needle[], bool:caseSensitive = true) {
	new haystackLen = strlen(haystack);
	new needleLen = strlen(needle);
	if (needleLen > haystackLen)
		return false;
	
	for (new i = haystackLen - needleLen, j = 0; j < needleLen; i++, j++) {
		if (haystack[i] != needle[j] && (caseSensitive || CharToLower(haystack[i]) != CharToLower(needle[j])))
			return false;
	}
	
	return true;
}

stock bool:SteamID_Equal(const String:id1[], const String:id2[]) {
	// Compares two SteamIDs in the form of STEAM_0:X:YYYY, [U:1:ZZZZ] or X:YYYY
	
	new steam1, steam2;
	
	if (F2_String_StartsWith(id1, "STEAM_0:", false)) {
		new a = id1[8] == '1' ? 1 : 0;
		steam1 = StringToInt(id1[10]);
		if (steam1 == 0)
			return false;
		steam1 = steam1 * 2 + a;
	} else if (F2_String_StartsWith(id1, "[U:1:", false) && String_EndsWith(id1, "]")) {
		if (StringToIntEx(id1[5], steam1) != strlen(id1) - 5 - 1)
			return false;
	} else {
		new a = id1[0] == '1' ? 1 : 0;
		steam1 = StringToInt(id1[2]);
		if (steam1 == 0)
			return false;
		steam1 = steam1 * 2 + a;
	}
	
	if (F2_String_StartsWith(id2, "STEAM_0:", false)) {
		new a = id2[8] == '1' ? 1 : 0;
		steam2 = StringToInt(id2[10]);
		if (steam2 == 0)
			return false;
		steam2 = steam2 * 2 + a;
	} else if (F2_String_StartsWith(id2, "[U:1:", false) && String_EndsWith(id2, "]")) {
		if (StringToIntEx(id2[5], steam2) != strlen(id2) - 5 - 1)
			return false;
	} else {
		new a = id2[0] == '1' ? 1 : 0;
		steam2 = StringToInt(id2[2]);
		if (steam2 == 0)
			return false;
		steam2 = steam2 * 2 + a;
	}
	
	return steam1 == steam2;
}

stock bool:SteamID_ToOldFormat(String:oldID[], oldIDsize, const String:newID[]) {
	// Converts [U:1:ZZZZ] to STEAM_0:X:YYYY
	
	new steamidNum;
	if (StringToIntEx(newID[5], steamidNum) != strlen(newID) - 5 - 1)
		return false;
	
	FormatEx(oldID, oldIDsize, "STEAM_0:%i:%i", steamidNum & 1, steamidNum >> 1);
	return true;
}


stock bool:GetClientAuthStringOld(client, String:steamid[], steamidSize, bool:validate = true) {
	if (!GetClientAuthString(client, steamid, steamidSize, validate)) {
		strcopy(steamid, steamidSize, "");
		return false;
	}
	if (F2_String_StartsWith(steamid, "STEAM_", false))
		return true;
	if (!SteamID_ToOldFormat(steamid, steamidSize, steamid))
		return false;
	return true;
}

stock bool:GetClientAuthStringNew(client, String:steamid[], steamidSize, bool:validate = true) {
	if (IsFakeClient(client)) {
		strcopy(steamid, steamidSize, "BOT");
		return true;
	}
	
	new accountID = GetSteamAccountID(client, validate);
	if (accountID == 0) {
		strcopy(steamid, steamidSize, "");
		return false;
	}
	Format(steamid, steamidSize, "[U:1:%i]", accountID);
	return true;
}

stock int GetClientBySteamId(const char[] auth, AuthIdType idtype, bool validate = true) {
	char clientAuth[64];
	for (int client = 1; client <= MaxClients; client++) {
		if (!IsClientConnected(client))
			continue;
		
		if (!GetClientAuthId(client, idtype, clientAuth, sizeof(clientAuth), validate))
			continue;

		if (StrEqual(auth, clientAuth, false))
			return client;
	}
	
	return -1;
}



stock void HtmlDecodeSpecialChars(char[] str, int maxlen) {
	ReplaceString(str, maxlen, "&lt;", "<");
	ReplaceString(str, maxlen, "&gt;", ">");
	ReplaceString(str, maxlen, "&quot;", "\"");
	ReplaceString(str, maxlen, "&amp;", "&");
}


enum MapType {
	MapType_Unknown,
	MapType_5CP,
	MapType_TC,
	MapType_AD,
	MapType_Arena,
	MapType_CTF,
	MapType_Koth,
	MapType_Payload,
	MapType_PayloadRace
};
stock MapType:GetMapType() {
	/*
	5cp: round count == 0
	tc: Round count > 0, switch teams on win: no
	A/D: Switch teams on win: yes
	arena: tf_logic_arena
	ctf: item_teamflag
	koth: tf_logic_koth
	pl: mapobj_cart_dispenser
	*/
	new ent = -1;
	
	if (FindEntityByClassname(-1, "tf_logic_arena") != -1)
		return MapType_Arena;
	
	if (FindEntityByClassname(-1, "tf_logic_koth") != -1)
		return MapType_Koth;
	
	if (FindEntityByClassname(-1, "item_teamflag") != -1)
		return MapType_CTF;
	
	ent = -1;
	new cartcount = 0;
	while ((ent = FindEntityByClassname(ent, "mapobj_cart_dispenser")) != -1) {
		cartcount++;
	}
	if (cartcount == 1)
		return MapType_Payload;
	else if (cartcount > 1)
		return MapType_PayloadRace;
	
	ent = -1;
	new cpcount = 0;
	while ((ent = FindEntityByClassname(ent, "team_control_point")) != -1) {
		cpcount++;
	}
	
	ent = -1;
	new roundcount = 0;
	while ((ent = FindEntityByClassname(ent, "team_control_point_round")) != -1) {
		roundcount++;
	}
	
	ent = -1;
	new bool:switchonwin = false;
	new bool:scorepercapture = false;
	if ((ent = FindEntityByClassname(ent, "team_control_point_master")) != -1) {
		switchonwin = GetEntProp(ent, Prop_Data, "m_bSwitchTeamsOnWin", 4) == 1;
		scorepercapture = GetEntProp(ent, Prop_Data, "m_bScorePerCapture", 4) == 1;
	}
	
	if (cpcount > 0) {
		if (switchonwin == true)
			return MapType_AD;
			
		if (roundcount == 0)
			return MapType_5CP;
		
		if (scorepercapture == false)
			return MapType_TC;
	}
	
	return MapType_Unknown;
}
