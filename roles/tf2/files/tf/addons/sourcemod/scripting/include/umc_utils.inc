/*************************************************************************
*************************************************************************
This plugin is free software: you can redistribute 
it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or
later version. 

This plugin is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this plugin.  If not, see <http://www.gnu.org/licenses/>.
*************************************************************************
*************************************************************************/
#if defined _umc_utils_included
    #endinput
#endif
#define _umc_utils_included

#pragma semicolon 1

#include <sourcemod>
#include <umc-core>
#include <sdktools_functions>
#include <sdktools_entinput>
#include <sdktools_stringtables>
#include <regex>
#include <emitsoundany>

//************************************************************************************************//
//                                        GENERAL UTILITIES                                       //
//************************************************************************************************//

#if UMC_DEBUG
//Prints a debug message.
stock DebugMessage(const String:message[], any:...)
{
    new size = strlen(message) + 255;
    decl String:fMessage[size];
    VFormat(fMessage, size, message, 2);
    
    LogUMCMessage("DEBUG: %s", fMessage);
}
#define DEBUG_MESSAGE(%0) DebugMessage(%0);

#else

#define DEBUG_MESSAGE(%0)

#endif


#define MIN(%0, %1) ((%0) < (%1)) ? (%0) : (%1)


stock LogUMCMessage(const String:message[], any:...)
{
    new size = strlen(message) + 255;
    decl String:fMessage[size];
    VFormat(fMessage, size, message, 2);
    
    decl String:fileName[PLATFORM_MAX_PATH];
    decl String:timeStamp[64];
    FormatTime(timeStamp, sizeof(timeStamp), "%Y%m%d", GetTime());
    BuildPath(Path_SM, fileName, sizeof(fileName), "logs/UMC_%s.log", timeStamp);
    
    LogToFile(fileName, fMessage);
}


stock StringToUpper(String:str[])
{
    new i = 0;
    while (str[i] != 0)
    {
        str[i] = CharToUpper(str[i]);
    }
}


//Utility function to build a map trie.
stock Handle:CreateMapTrie(const String:map[], const String:group[])
{
    new Handle:trie = CreateTrie();
    SetTrieString(trie, MAP_TRIE_MAP_KEY, map);
    SetTrieString(trie, MAP_TRIE_GROUP_KEY, group);
    return trie;
}


//Utility function to get a KeyValues Handle from a filename, with the specified root key.
stock Handle:GetKvFromFile(const String:filename[], const String:rootKey[], bool:checkNorm=true)
{
    new Handle:kv = CreateKeyValues(rootKey);
    
    //Log an error and return empty handle if the kv file fails to parse.
    if (!(checkNorm && ConvertNormalMapcycle(kv, filename)) && !FileToKeyValues(kv, filename))
    {
        LogError("KV ERROR: Unable to load KV file: %s", filename);
        CloseHandle(kv);
        return INVALID_HANDLE;
    }
    
#if UMC_DEBUG
    LogKv(kv);
#endif
    
    return kv;
}


stock bool:ConvertNormalMapcycle(Handle:kv, const String:filename[])
{
    //DEBUG_MESSAGE("Opening Mapcycle File %s", filename)
    new Handle:file = OpenFile(filename, "r");
    
    if (file == INVALID_HANDLE)
    {    
        return false;
    }
    
    //DEBUG_MESSAGE("Fetching first line.")
    new String:firstLine[256];
    new bool:foundDef;
    while (ReadFileLine(file, firstLine, sizeof(firstLine)))
    {
        TrimString(firstLine);
        if (strlen(firstLine) > 0)
        {
            foundDef = true;
            break;
        }
    }
    
    if (!foundDef)
    {
        //DEBUG_MESSAGE("Couldn't find first line")
        CloseHandle(file);
        return false;
    }
    
    //DEBUG_MESSAGE("Checking first line for UMC header: \"%s\"", firstLine)
    static Handle:re = INVALID_HANDLE;
    if (re == INVALID_HANDLE)
    {
        re = CompileRegex("^//!UMC\\s+([0-9]+)\\s*$");
    }
    
    decl String:buffer[5];
    
    if (MatchRegex(re, firstLine) > 1)
    {
        GetRegexSubString(re, 1, buffer, sizeof(buffer));
    }
    else
    {
        //DEBUG_MESSAGE("Header was not found. Aborting.")
        CloseHandle(file);
        return false;
    }
    
    //DEBUG_MESSAGE("Making a map group.")
    static Handle:re2 = INVALID_HANDLE;
    if (re2 == INVALID_HANDLE)
    {
        re2 = CompileRegex("^\\s*([^/\\\\:*?'\"<>|\\s]+)\\s*(?://.*)?$");
    }
    
    KvJumpToKey(kv, "Mapcycle", true);
    KvSetNum(kv, "maps_invote", StringToInt(buffer));
    
    //DEBUG_MESSAGE("Parsing maps.")
    
    decl String:map[MAP_LENGTH];
    decl String:line[256];
    while (ReadFileLine(file, line, sizeof(line)))
    {
        TrimString(line);
        if (MatchRegex(re2, line) > 1)
        {
            GetRegexSubString(re2, 1, map, sizeof(map));
            //DEBUG_MESSAGE("Adding map: %s", map)
            KvJumpToKey(kv, map, true);
            KvGoBack(kv);
        }
    }
    
    CloseHandle(file);
    KvGoBack(kv);
    return true;
}


//Utility function to jump to a specific map in a mapcycle.
//  kv: Mapcycle Keyvalues that must be at the root value.
stock bool:KvJumpToMap(Handle:kv, const String:map[])
{
    if (!KvGotoFirstSubKey(kv))
    {
        return false;
    }    
    decl String:mapName[MAP_LENGTH];
    
    do
    {
        if (!KvGotoFirstSubKey(kv))
        {
            continue;
        }
        
        do
        {
            KvGetSectionName(kv, mapName, sizeof(mapName));
            if (StrEqual(mapName, map))
            {
                return true;
            }
        }
        while (KvGotoNextKey(kv));
        
        KvGoBack(kv);
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
    return false;
}


//Utility function to search for a group that contains the given map.
//  kv: Mapcycle
//  map: Map whose group we're looking for.
//  buffer: Buffer to store the found group name.
//  maxlen: Maximum length of the buffer.
stock bool:KvFindGroupOfMap(Handle:kv, const String:map[], String:buffer[], maxlen)
{
    if (!KvGotoFirstSubKey(kv))
    {
        return false;
    }
    
    decl String:mapName[MAP_LENGTH], String:groupName[MAP_LENGTH];
    do
    {
        KvGetSectionName(kv, groupName, sizeof(groupName));
        
        if (!KvGotoFirstSubKey(kv))
        {
            continue;
        }
        
        do
        {
            KvGetSectionName(kv, mapName, sizeof(mapName));
            if (StrEqual(mapName, map, false))
            {
                KvGoBack(kv);
                KvGoBack(kv);
                strcopy(buffer, maxlen, groupName);
                return true;
            }
        }
        while (KvGotoNextKey(kv));
        
        KvGoBack(kv);
    }
    while (KvGotoNextKey(kv));
    KvGoBack(kv);
    return false;
}


enum CustomHudFallbackType 
{
    HudFallback_Chat,
    HudFallback_Hint,
    HudFallback_Center,
	HudFallback_None
};

//Color Arrays for colors in warning messages.
static g_iSColors[7]             = {1, 3, 3, 4, 4, 5, 6};
static String:g_sSColors[7][13]  = {"{DEFAULT}", "{LIGHTGREEN}", "{TEAM}", "{GREEN}", "{RED}",
                                    "{DARKGREEN}", "{YELLOW}"};
static g_iTColors[13][3]         = {{255, 255, 255}, {255,   0,   0}, {  0, 255,   0}, 
                                    {  0,   0, 255}, {255, 255,   0}, {255,   0, 255},
                                    {  0, 255, 255}, {255, 128,   0}, {255,   0, 128},
                                    {128, 255,   0}, {  0, 255, 128}, {128,   0, 255}, 
                                    {  0, 128, 255}};
static String:g_sTColors[13][12] = {"{WHITE}", "{RED}", "{GREEN}", "{BLUE}", "{YELLOW}", "{PURPLE}",
                                    "{CYAN}", "{ORANGE}", "{PINK}", "{OLIVE}", "{LIME}", "{VIOLET}",    
                                    "{LIGHTBLUE}"};

//Handle to the Center Message timer. For Vote Warnings.
static Handle:center_message_timer = INVALID_HANDLE;
static bool:center_warning_active = false;

//Displays a message to the server
stock DisplayServerMessage(const String:msg[], const String:type[])
{
    if (center_warning_active)
    {   
        center_warning_active = false;
        TriggerTimer(center_message_timer);
    }
    
    if (strlen(msg) == 0)
    {    
        return;
    }
    decl String:message[255];
    strcopy(message, sizeof(message), msg);
    
    //Display a chat message ("S") if the user specifies.
    if (StrContains(type, "S") != -1)
    {
        new String:sColor[4];
        Format(message, sizeof(message), "%c%s", 1, message);
        for (new c = 0; c < sizeof(g_iSColors); c++)
        {
            if (StrContains(message, g_sSColors[c]))
            {
                FormatEx(sColor, sizeof(sColor), "%c", g_iSColors[c]);
                ReplaceString(message, sizeof(message), g_sSColors[c], sColor);
            }
        }
        PrintToChatAll(message);
    }
    
    //Buffer to hold message in order to manipulate it.
    decl String:sTextTmp[255];
    
    //Display a top message ("T") if the user specifies.
    if (StrContains(type, "T") != -1)
    {
        strcopy(sTextTmp, sizeof(sTextTmp), message);
        decl String:sColor[16];
        new iColor = -1, iPos = BreakString(sTextTmp, sColor, sizeof(sColor));
        
        for (new i = 0; i < sizeof(g_sTColors); i++)
        {
            if (StrEqual(sColor, g_sTColors[i]))
            {    
                iColor = i;
            }
        }
        
        if (iColor == -1)
        {
            iPos   = 0;
            iColor = 0;
        }
        
        new Handle:hKv = CreateKeyValues("Stuff", "title", sTextTmp[iPos]);
        KvSetColor(hKv, "color", g_iTColors[iColor][0], g_iTColors[iColor][1], g_iTColors[iColor][2], 255);
        KvSetNum(hKv, "level", 1);
        KvSetNum(hKv, "time",  10);
        
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {    
                CreateDialog(i, hKv, DialogType_Msg);
            }
        }
        CloseHandle(hKv);
    }
    
    // Remove colors, because C,H,M methods do not support colors.
    //Remove a color from the message string for each color in the Say color array.
    for (new c = 0; c < sizeof(g_iSColors); c++)
    {
        if (StrContains(message, g_sSColors[c]) != -1)
        {    
            ReplaceString(message, sizeof(message), g_sSColors[c], "");
        }
    }
    
    //Remove a color from the message string for each color in the Top color array.
    for (new c = 0; c < sizeof(g_iTColors); c++)
    {
        if (StrContains(message, g_sTColors[c]) != -1)
        {    
            ReplaceString(message, sizeof(message), g_sTColors[c], "");
        }
    }
    
    //Display a center message ("C") if the user specifies.
    if (StrContains(type, "C") != -1)
    {
        PrintCenterTextAll(message);
        
        //Setup timer to keep the center message visible.
        new Handle:hCenterAd;
        center_message_timer = CreateDataTimer(1.0, Timer_CenterAd, hCenterAd, TIMER_REPEAT);
        WritePackString(hCenterAd, message);
        
        center_warning_active = center_message_timer != INVALID_HANDLE;
        if (!center_warning_active)
        {    
            CloseHandle(hCenterAd);
        }
    }
    
    //Display a hint message ("H") if the user specifies.
    if (StrContains(type, "H") != -1)
    {    
        PrintHintTextToAll(message);
    }    
}


//Called with each tick of the timer for center messages. Used to keep the message visible for an
//extended period.
public Action:Timer_CenterAd(Handle:timer, Handle:pack)
{
    decl String:sText[256];
    static iCount = 0;
    
    ResetPack(pack);
    ReadPackString(pack, sText, sizeof(sText));
    
    if (center_warning_active && ++iCount < 5)
    {
        PrintCenterTextAll(sText);
        return Plugin_Continue;
    }
    else
    {
        iCount = 0;
        center_message_timer = INVALID_HANDLE;
        center_warning_active = false;
        return Plugin_Stop;
    }
}


//Sets all elements of an array of booleans to false.
stock ResetArray(bool:arr[], size)
{
    for (new i = 0; i < size; i++)
    {    
        arr[i] = false;
    }
}


//Utility function to cache a sound.
stock CacheSound(const String:sound[])
{
    //Handle the sound if it is defined.
    if (strlen(sound) > 0)
    {
        //Filepath buffer
        decl String:filePath[PLATFORM_MAX_PATH];
    
        //Format sound to the correct directory.
        FormatEx(filePath, sizeof(filePath), "sound/%s", sound);
        
        //Log an error and don't cache the sound if the sound file does not exist
        if (!FileExists(filePath, true))
        {
            LogError("SOUND ERROR: Sound file '%s' does not exist.", filePath);
        }
        //Otherwise, cache the sound.
        else
        {
            //Make sure clients download the sound if they don't have it.
            AddFileToDownloadsTable(filePath);
            
            //Cache it.
            PrecacheSoundAny(sound, true);
            
            //Log an error if the sound failed to be cached.
            if (!IsSoundPrecached(filePath))
            {    
                LogError("SOUND ERROR: Failed to precache sound file '%s'", sound);
            }
        }
    }
}


//Fetch the next index of the menu.
//    size: the size of the menu
//    scramble: whether or not a random index should be picked.
stock GetNextMenuIndex(size, bool:scramble)
{
    return scramble ? GetRandomInt(0, size) : size;
}


//Inserts given string into given array at given index.
stock InsertArrayString(Handle:arr, index, const String:value[])
{
    if (GetArraySize(arr) > index)
    {
        ShiftArrayUp(arr, index);
        SetArrayString(arr, index, value);
    }
    else
    {    
        PushArrayString(arr, value);
    }
}


//Inserts given cell into given adt_array at given index,
stock InsertArrayCell(Handle:arr, index, any:cell)
{
    if (GetArraySize(arr) > index)
    {
        ShiftArrayUp(arr, index);
        SetArrayCell(arr, index, cell);
    }
    else
    {
        PushArrayCell(arr, cell);
    }
}


//Deletes values off the end of an array until it is down to the given size.
stock TrimArray(Handle:arr, size)
{
    //Remove elements from the start of an array while the size of the array is greater than the required size.
    new asize = GetArraySize(arr);
    while (asize > size)
    {    
        RemoveFromArray(arr, --asize);
    }
}


//Adds the given map to the given memory array.
//    mapName: the name of the map
//    arr:     the memory array we're adding to
//    size:    the maximum size of the memory array
stock AddToMemoryArray(const String:mapName[], Handle:arr, size)
{
    //Add the new map to the beginning of the array.
    InsertArrayString(arr, 0, mapName);
    
    //Trim the array down to size.
    TrimArray(arr, size);
}


//Adds entire array to the given menu.
stock AddArrayToMenu(Handle:menu, Handle:arr, Handle:dispArr=INVALID_HANDLE)
{
    decl String:map[MAP_LENGTH], String:disp[MAP_LENGTH];
    new arrSize = GetArraySize(arr);
    new dispSize = (dispArr != INVALID_HANDLE) ? GetArraySize(dispArr) : 0;
    for (new i = 0; i < arrSize; i++)
    {
        GetArrayString(arr, i, map, sizeof(map));
        if (i >= dispSize)
        {
            disp = map;
        }
        else
        {
            GetArrayString(dispArr, i, disp, sizeof(disp));
        }
        
        AddMenuItem(menu, map, disp);
    }
}


//Changes the map in 5 seconds.
stock ForceChangeInFive(const String:map[], const String:reason[]="")
{
    //Notify the server.
    PrintToChatAll("\x03[UMC]\x01 %t", "Map Change in 5");
    
    //Setup the change.
    ForceChangeMap(map, 5.0, reason);
}


//Changes the map after the specified time period.
stock ForceChangeMap(const String:map[], Float:time, const String:reason[]="")
{
    LogUMCMessage("%s: Changing map to '%s' in %.f seconds.", reason, map, time);

    //Setup the timer.
    new Handle:pack;
    CreateDataTimer(
        time,
        Handle_MapChangeTimer,
        pack,
        TIMER_FLAG_NO_MAPCHANGE
    );
    WritePackString(pack, map);
    WritePackString(pack, reason);
}


//Called after the mapchange timer is completed.
public Action:Handle_MapChangeTimer(Handle:timer, Handle:pack)
{
    //Get map from the timer's pack.
    decl String:map[MAP_LENGTH], String:reason[255];
    ResetPack(pack);
    ReadPackString(pack, map, sizeof(map));
    ReadPackString(pack, reason, sizeof(reason));
    
    //DEBUG_MESSAGE("Changing map to %s: %s", map, reason)
    
    //Change the map.
    ForceChangeLevel(map, reason);
}


//Determines if the current server time is between the given min and max.
stock bool:IsTimeBetween(min, max)
{
    //Get the current server time.
    decl String:time[5];
    FormatTime(time, sizeof(time), "%H%M");
    new theTime = StringToInt(time);
    
    //Handle wrap-around case if...
    //  ...max time is less than min time.
    if (max <= min)
    {
        max += 2400;
        if (theTime <= min)
        {
            theTime += 2400;
        }
    }
    return min <= theTime && theTime <= max;
}


//Determines if the current server player count is between the given min and max.
stock bool:IsPlayerCountBetween(min, max)
{
    //Get the current number of players.
    new numplayers = GetRealClientCount();
    return min <= numplayers && numplayers <= max;
}


//Converts an adt_array to a standard array.
stock ConvertAdtArray(Handle:arr, any:newArr[], size)
{
    new arraySize = GetArraySize(arr);
    new min = size < arraySize ? size : arraySize;
    for (new i = 0; i < min; i++)
    {    
        newArr[i] = GetArrayCell(arr, i);
    }
}


stock ConvertArray(const any:arr[], amt, Handle:newArr)
{
    for (new i = 0; i < amt; i++)
    {
        PushArrayCell(newArr, arr[i]);
    }
}


//Selects one random name from the given name array, using the weights in the supplies weight array.
//Stores the result in buffer.
stock bool:GetWeightedRandomSubKey(String:buffer[], size, Handle:weightArr, Handle:nameArr, &index=0)
{
    //Calc total number of maps we're choosing.
    new total = GetArraySize(weightArr);
    
    //DEBUG_MESSAGE("Getting number of items in the pool - %i", total)
    
    //Return an answer immediately if there's only one map to choose from.
    if (total == 1)
    {   
        //DEBUG_MESSAGE("Only 1 item in pool, setting it as the winner.")
        //WE HAVE A WINNER!
        GetArrayString(nameArr, 0, buffer, size);
        return true;
    }
    //Otherwise, we immediately do nothing and return, if there are no maps to choose from.
    else if (total == 0)
    {
        //DEBUG_MESSAGE("No items in the pool. Returning false.")
        return false;
    }

    //DEBUG_MESSAGE("Setting up array of weights.")
    //Convert the adt_array of weights to a normal array.
    new Float:weights[total];
    ConvertAdtArray(weightArr, weights, total);

    //DEBUG_MESSAGE("Picking a random number.")
    //We select a random number here by getting a random Float in the
    //range [0, 1), and then multiply it by the sum of the weights, to
    //make the effective range [0, totalweight).
    new Float:rand = GetURandomFloat() * ArraySum(weights, total);
    new Float:runningTotal = 0.0; //keeps track of total so far
    
    //DEBUG_MESSAGE("Find the winner in the pool.")
    //Determine if a map is the winner for each map in the arrays.
    for (new i = 0; i < total; i++)
    {
        //DEBUG_MESSAGE("Update running total of weights.")
        //add weight onto the total
        runningTotal += weights[i];
        
        //DEBUG_MESSAGE("Check if we're at the right item.")
        //We have found an answer if the running total has reached the random number.
        if (runningTotal > rand)
        {
            //DEBUG_MESSAGE("Item found.")
            GetArrayString(nameArr, i, buffer, size);
            index = i;
            return true;
        }
    }
    
    //DEBUG_MESSAGE("ERROR WITH THE RANDOMIZATION ALGORITHM!")
    //This shouldn't ever happen, but alas the compiler complains.
    index = -1;
    return false;
}


//Utility function to sum up an array of floats.
stock Float:ArraySum(const Float:floats[], size)
{
    new Float:result = 0.0;
    for (new i = 0; i < size; i++)
    {
        result += floats[i];
    }
    return result;
}


//Utility function to clear an array of Handles and close each Handle.
stock ClearHandleArray(Handle:arr)
{
    new arraySize = GetArraySize(arr);
    for (new i = 0; i < arraySize; i++)
    {
        CloseHandle(GetArrayCell(arr, i));
    }
    ClearArray(arr);
}


//Utility function to get the true count of active clients on the server.
stock GetRealClientCount(bool:inGameOnly=true)
{
    new clients = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if ((inGameOnly ? IsClientInGame(i) : IsClientConnected(i)) && !IsFakeClient(i))
        {
            clients++;
        }
    }
    return clients;
}


//Utiliy function to append arrays
stock ArrayAppend(Handle:arr1, Handle:arr2)
{
    new arraySize = GetArraySize(arr2);
    for (new i = 0; i < arraySize; i++)
    {
        PushArrayCell(arr1, GetArrayCell(arr2, i));
    }
}


//Builds an adt_array of numbers from 0 to max-1.
stock Handle:BuildNumArray(max)
{
    new size = 2 + max / 10;
    new Handle:result = CreateArray(ByteCountToCells(size));
    decl String:buffer[size];
    for (new i = 0; i < max; i++)
    {
        //IntToString(i, buffer, size);
        FormatEx(buffer, size, "%i", i);
        PushArrayString(result, buffer);
    }
    return result;
}


//Determines the correct time to paginate a menu. Menu passed to this argument should have
//pagination enabled.
stock SetCorrectMenuPagination(Handle:menu, numSlots)
{
    if (GetMenuStyleHandle(MenuStyle_Valve) != GetMenuStyleHandle(MenuStyle_Radio) && numSlots < 10)
    {
        SetMenuPagination(menu, MENU_NO_PAGINATION);
    }
}


//Finds a string in an array starting at a specific index.
stock FindStringInArrayEx(Handle:arr, const String:value[], start=0)
{
    new size = GetArraySize(arr);
    decl String:buffer[255];
    for (new i = start; i < size; i++)
    {
        GetArrayString(arr, i, buffer, sizeof(buffer));
        if (StrEqual(value, buffer))
        {
            return i;
        }
    }
    return -1;
}


//Closes a handle and sets the variable pointer to INVALID_HANDLE
stock CloseHandleEx(&Handle:handle)
{
    CloseHandle(handle);
    handle = INVALID_HANDLE;
}


//Creates a copy of an adt_array.
stock Handle:CopyStringArray(Handle:arr, blocksize=1)
{
    new size = GetArraySize(arr);
    new Handle:result = CreateArray(blocksize);
    new len = 4 * blocksize;
    decl String:buffer[len];
    for (new i = 0; i < size; i++)
    {
        GetArrayString(arr, i, buffer, len);
        PushArrayString(result, buffer);
    }
    return result;
}


//Makes the timer to retry running a vote every second.
stock MakeRetryVoteTimer(Function:callback)
{
    new Handle:callbackForward = CreateForward(ET_Single);
    AddToForward(callbackForward, INVALID_HANDLE, callback);
    CreateTimer(1.0, Handle_RetryVoteTimer, callbackForward, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}


//Handles the retry timer for votes that were attempted to be started.
public Action:Handle_RetryVoteTimer(Handle:timer, Handle:callback)
{
    if (!UMC_IsNewVoteAllowed())
    {
        return Plugin_Continue;
    }
    
    Call_StartForward(callback);
    Call_Finish();
    
    return Plugin_Stop;
}


//Comparison function for map tries <Map, MapGroup>. Used for sorting.
public CompareMapTries(index1, index2, Handle:array, Handle:hndl)
{
    decl String:map1[MAP_LENGTH], String:map2[MAP_LENGTH],
         String:group1[MAP_LENGTH], String:group2[MAP_LENGTH];
    
    new Handle:map = INVALID_HANDLE;
    map = GetArrayCell(array, index1);
    GetTrieString(map, MAP_TRIE_MAP_KEY, map1, sizeof(map1));
    GetTrieString(map, MAP_TRIE_GROUP_KEY, group1, sizeof(group1));
    map = GetArrayCell(array, index2);
    GetTrieString(map, MAP_TRIE_MAP_KEY, map2, sizeof(map2));
    GetTrieString(map, MAP_TRIE_GROUP_KEY, group2, sizeof(group2));
    
    new result = strcmp(map1, map2);
    if (result == 0)
    {
        result = strcmp(group1, group2);
    }
    return result;
}


//Sorts an array of map tries
stock SortMapTrieArray(Handle:array)
{
    SortADTArrayCustom(array, CompareMapTries);
}


//Prints the sections of a kv to the log.
stock PrintKvToConsole(Handle:kv, client, depth=0)
{
    decl String:section[64];
    KvGetSectionName(kv, section, sizeof(section));
    
    new whitespace = depth*2+1;
    decl String:space[whitespace];
    FillWhiteSpace(space, whitespace);
    
    PrintToConsole(client, "%s\"%s\"", space, section);
    
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    
    do
    {
        PrintKvToConsole(kv, client, depth + 1);
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
}


//Prints the sections of a kv to the log.
stock LogKv(Handle:kv, depth=0)
{
    decl String:section[64];
    KvGetSectionName(kv, section, sizeof(section));
    
    new whitespace = depth*2+1;
    decl String:space[whitespace];
    FillWhiteSpace(space, whitespace);
    
    //LogUMCMessage("%i: %s\"%s\"", depth+1, space, section);
    
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    do
    {
        LogKv(kv, depth + 1);
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
}


//Fills a string with whitespace.
stock FillWhiteSpace(String:buffer[], maxlen)
{
    new limit = maxlen - 1;
    for (new i = 0; i < limit; i++)
    {
        buffer[i] = ' ';
    }
    buffer[limit] = 0;
}


stock PrintNominationArray(Handle:array)
{
    new Handle:nom;
    decl String:map[MAP_LENGTH], String:group[MAP_LENGTH];
    new size = GetArraySize(array);
    for (new i = 0; i < size; i++)
    {
        nom = GetArrayCell(array, i);
        GetTrieString(nom, MAP_TRIE_MAP_KEY, map, sizeof(map));
        GetTrieString(nom, MAP_TRIE_GROUP_KEY, group, sizeof(group));
        //LogUMCMessage("%20s   |    %20s", map, group);
    }
}


stock bool:VoteMenuToAllWithFlags(Handle:menu, time, const String:flagstring[]="")
{
    if (strlen(flagstring) > 0)
    {
        new flags = ReadFlagString(flagstring);
        decl clients[MAXPLAYERS+1];
        new count = 0;
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && (flags & GetUserFlagBits(i)))
            {
                clients[count++] = i;
            }
        }
        return VoteMenu(menu, clients, count, time);
    }
    else
    {
        return bool:VoteMenuToAll(menu, time);
    }
}


stock GetClientsWithFlags(const String:flagstring[], clients[], maxlen, &amt)
{
    new bool:checkFlags = strlen(flagstring) > 0;
    new flags = ReadFlagString(flagstring);
    new limit = maxlen < MaxClients ? maxlen : MaxClients;
    new count = 0;
    for (new i = 1; i <= limit; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && (!checkFlags || (flags & GetUserFlagBits(i))))
        {
            //DEBUG_MESSAGE("Client has correct flags: %L (%i) [F: %s]", i, i, flagstring)
            clients[count++] = i;
        }
    }
    amt = count;
}


stock GetClientWithFlagsCount(const String:flagstring[])
{
    new bool:checkFlags = strlen(flagstring) > 0;
    new flags = ReadFlagString(flagstring);
    new count = 0;
    for (new i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && (!checkFlags || (flags & GetUserFlagBits(i))))
        {
            count++;
        }
    }
    return count;
}


stock bool:ClientHasAdminFlags(client, const String:flagString[])
{
    return strlen(flagString) == 0 || (ReadFlagString(flagString) & GetUserFlagBits(client));
}


//Filters a mapcycle with all invalid entries filtered out. 
// NOTE: Our journey starts here! This gets called first and runs through the KV that we sent to it.
// First, it deletes all groups and maps that have been excluded from the search before we return to the first
// sub key in the KV to run the search.
// Second, it searchs the updated KV for the group that our map is in and filters the information until we only
// have the map and group information left over.
stock FilterMapcycleFromArrays(Handle:kv, Handle:exMaps, Handle:exGroups, numExGroups, bool:deleteEmpty=false)
{
    new size = GetArraySize(exGroups);
    new len = size < numExGroups ? size : numExGroups;
    decl String:group[MAP_LENGTH];
    for (new i = 0; i < len; i++)
    {
        GetArrayString(exGroups, i, group, sizeof(group));
        if (!deleteEmpty)
        {
            KvJumpToKey(kv, group);
            KvDeleteAllSubKeys(kv);
            KvGoBack(kv);
        }
        else
        {
            KvDeleteSubKey(kv, group);
        }
    }
    
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    
    for ( ; ; )
    {
        FilterMapGroupFromArrays(kv, exMaps, exGroups);
        
        //Delete the group if there are no valid maps in it.
        if (deleteEmpty) 
        {
            if (!KvGotoFirstSubKey(kv))
            {
                //DEBUG_MESSAGE("Removing empty group \"%s\".", group)
                if (KvDeleteThis(kv) == -1)
                {
                   // DEBUG_MESSAGE("Mapcycle filtering completed.")
                    return;
                }
                else
                {
                    continue;
                }
            }
            
            KvGoBack(kv);
        }
        if (!KvGotoNextKey(kv))
        {
            break;
        }
    }
    
    KvGoBack(kv);
    
    //DEBUG_MESSAGE("Mapcycle filtering completed.")
}


//Filters the kv at the level of the map group.
stock FilterMapGroupFromArrays(Handle:kv, Handle:exMaps, Handle:exGroups)
{
    decl String:group[MAP_LENGTH];
    KvGetSectionName(kv, group, sizeof(group));
    
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    
    //DEBUG_MESSAGE("Starting filtering of map group \"%s\".", group)
    
    decl String:mapName[MAP_LENGTH];
    for ( ; ; )
    {
        KvGetSectionName(kv, mapName, sizeof(mapName));
        if (IsMapInArrays(mapName, group, exMaps, exGroups))
        {
            //DEBUG_MESSAGE("Removing invalid map \"%s\" from group \"%s\".", mapName, group)
            if (KvDeleteThis(kv) == -1)
            {
                //DEBUG_MESSAGE("Map Group filtering completed for group \"%s\".", group)
                return;
            }
        }
        else
        {
            if (!KvGotoNextKey(kv))
            {
                break;
            }
        }
    }
    
    KvGoBack(kv);
    
    //DEBUG_MESSAGE("Map Group filtering completed for group \"%s\".", group)
}


stock bool:IsMapInArrays(const String:map[], const String:group[], Handle:exMaps, Handle:exGroups)
{
    //DEBUG_MESSAGE("Starting exclusion traversal...")
    new index = -1;
    new bool:isExcluded = false;
    decl String:exGroup[MAP_LENGTH];
    if (exMaps != INVALID_HANDLE && exGroups != INVALID_HANDLE)
    {
        new gSize = GetArraySize(exGroups);
        do
        {
            index = FindStringInArrayEx(exMaps, map, index+1);
            if (index >= 0 && index < gSize)
            {
                //DEBUG_MESSAGE("Map found at %i", index)
                GetArrayString(exGroups, index, exGroup, sizeof(exGroup));
                isExcluded = StrEqual(exGroup, group, false);
                //DEBUG_MESSAGE("Map Excluded? %i (%s | %s)", _:isExcluded, exGroup, group)
            }
        }
        while (!isExcluded && index != -1);
    }
    
    return isExcluded;
}


stock bool:GroupExcludedPreviouslyPlayed(const String:group[], Handle:exGroups, numExGroups)
{
    if (numExGroups <= 0) 
    {
        return false;
    }
    
    new i = FindStringInArray(exGroups, group);
    return i != -1 && i < numExGroups;
}


stock bool:MapExcludedPreviouslyPlayed(const String:map[], const String:group[], Handle:exMaps, Handle:exGroups, numExGroups)
{
    return GroupExcludedPreviouslyPlayed(group, exGroups, numExGroups) || IsMapInArrays(map, group, exMaps, exGroups);
}


stock bool:KvDeleteSubKey(Handle:kv, const String:name[])
{
    return KvJumpToKey(kv, name) && (KvDeleteThis(kv) == -1 || KvGoBack(kv));
}


stock KvDeleteAllSubKeys(Handle:kv)
{
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    
    for ( ; ; )
    {
        if (KvDeleteThis(kv) == -1)
        {
            return;
        }
    }
}


stock Handle:CloseAndClone(Handle:hndl, Handle:newOwner)
{
    new Handle:result = CloneHandle(hndl, newOwner);
    CloseHandle(hndl);
    return result;
}


stock ConvertClientsToUserIDs(const clients[], userIds[], amt)
{
    for (new i = 0; i < amt; i++)
    {
        userIds[i] = GetClientUserId(clients[i]);
    }
}


stock ConvertUserIDsToClients(const userIds[], clients[], amt)
{
    for (new i = 0; i < amt; i++)
    {
        clients[i] = GetClientOfUserId(userIds[i]);
    }
}


stock bool:GetTrieArray2(Handle:trie, const String:key[], any:arr[], max_size, &size=0) 
{ 
    new bool:result = GetTrieArray(trie, key, arr, max_size, size); 
    if (!result) 
    {
        result = GetTrieValue(trie, key, arr[0]); 
        if (result) 
        { 
            size = 1;
        }
    }
    
    return result; 
}


stock ArrayMin(const arr[], maxlen, &idx=0)
{
    if (maxlen <= 0)
    {
        return 0;
    }
    
    new minIdx = 0;
    new min = arr[0];
    new tmp;
    for (new i = 1; i < maxlen; i++)
    {
        tmp = arr[i];
        if (tmp < min)
        {
            min = tmp;
            minIdx = i;
        }
    }
    return min;
}


stock ArrayMax(const arr[], maxlen, &idx=0)
{
    if (maxlen <= 0)
    {
        return 0;
    }
    
    new maxIdx = 0;
    new max = arr[0];
    new tmp;
    for (new i = 1; i < maxlen; i++)
    {
        tmp = arr[i];
        if (tmp > max)
        {
            max = tmp;
            maxIdx = i;
        }
    }
    return max;
}