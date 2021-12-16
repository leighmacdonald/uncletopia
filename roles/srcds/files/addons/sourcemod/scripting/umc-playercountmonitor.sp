/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                           Ultimate Mapchooser - Player Count Monitor                          *
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
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
#pragma semicolon 1

#include <sourcemod>
#include <sdktools_sound>
#include <umc-core>
#include <umc_utils>
#include <emitsoundany>

#undef REQUIRE_PLUGIN
#include <umc-playerlimits>

#define NO_OPTION "?no?"

enum PlayerLimit_Action
{
    PLAction_Nothing = 0,
    PLAction_Now,
    PLAction_YesNo,
    PLAction_Vote
}

//Plugin Information
public Plugin:myinfo =
{
    name        = "[UMC] Player Count Monitor",
    author      = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Extends Ultimate Mapchooser to watch for Player Limits and changing the map if they're broken.",
    version     = PL_VERSION,
    url         = "http://forums.alliedmods.net/showthread.php?t=134190"
};

////----CONVARS-----/////
new Handle:cvar_filename             = INVALID_HANDLE;
new Handle:cvar_scramble             = INVALID_HANDLE;
new Handle:cvar_vote_time            = INVALID_HANDLE;
new Handle:cvar_strict_noms          = INVALID_HANDLE;
new Handle:cvar_runoff               = INVALID_HANDLE;
new Handle:cvar_runoff_sound         = INVALID_HANDLE;
new Handle:cvar_runoff_max           = INVALID_HANDLE;
new Handle:cvar_vote_allowduplicates = INVALID_HANDLE;
new Handle:cvar_vote_threshold       = INVALID_HANDLE;
new Handle:cvar_fail_action          = INVALID_HANDLE;
new Handle:cvar_runoff_fail_action   = INVALID_HANDLE;
new Handle:cvar_invalid_min          = INVALID_HANDLE;
new Handle:cvar_invalid_max          = INVALID_HANDLE;
new Handle:cvar_invalid_post         = INVALID_HANDLE;
new Handle:cvar_invalid_delay        = INVALID_HANDLE;
new Handle:cvar_mem                  = INVALID_HANDLE;
new Handle:cvar_catmem               = INVALID_HANDLE;
new Handle:cvar_vote_type            = INVALID_HANDLE;
new Handle:cvar_dontchange           = INVALID_HANDLE;
new Handle:cvar_startsound           = INVALID_HANDLE;
new Handle:cvar_endsound             = INVALID_HANDLE;
new Handle:cvar_flags                = INVALID_HANDLE;

////----/CONVARS-----/////
//Mapcycle KV
new Handle:map_kv = INVALID_HANDLE;    
new Handle:umc_mapcycle = INVALID_HANDLE;

//Memory queues.
new Handle:vote_mem_arr = INVALID_HANDLE;
new Handle:vote_catmem_arr = INVALID_HANDLE;

//Keeps track of the minimum and maximum allowed players for this map.
new map_min_players;
new map_max_players;

//Sounds to be played at the start and end of votes.
new String:vote_start_sound[PLATFORM_MAX_PATH], String:vote_end_sound[PLATFORM_MAX_PATH],
    String:runoff_sound[PLATFORM_MAX_PATH];
    
//String to store the group for a map in a YES/NO vote.
new String:vote_group[MAP_LENGTH];

new bool:validity_enabled;

//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//

//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_flags = CreateConVar(
        "sm_umc_playerlimit_adminflags",
        "",
        "Specifies which admin flags are necessary for a player to participate in a vote. If empty, all players can participate."
    );

    cvar_filename = CreateConVar(
        "sm_umc_playerlimit_cyclefile",
        "umc_mapcycle.txt",
        "File to use for Ultimate Mapchooser's map rotation."
    );
    
    cvar_scramble = CreateConVar(
        "sm_umc_playerlimit_menuscrambled",
        "0",
        "Specifies whether vote menu items are displayed in a random order.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_time = CreateConVar(
        "sm_umc_playerlimit_duration",
        "20",
        "Specifies how long a vote should be available for.",
        0, true, 10.0
    );
    
    cvar_strict_noms = CreateConVar(
        "sm_umc_playerlimit_nominate_strict",
        "0",
        "Specifies whether the number of nominated maps appearing in the vote for a map group should be limited by the group's \"maps_invote\" setting.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff = CreateConVar(
        "sm_umc_playerlimit_runoffs",
        "0",
        "Specifies a maximum number of runoff votes to run for a vote.\n 0 disables runoff votes.",
        0, true, 0.0
    );
    
    cvar_runoff_sound = CreateConVar(
        "sm_umc_playerlimit_runoff_sound",
        "",
        "If specified, this sound file (relative to sound folder) will be played at the beginning of a runoff vote. If not specified, it will use the normal vote start sound."
    );
    
    cvar_runoff_max = CreateConVar(
        "sm_umc_playerlimit_runoff_max",
        "0",
        "Specifies the maximum number of maps to appear in a runoff vote.\n 1 or 0 sets no maximum.",
        0, true, 0.0
    );
    
    cvar_vote_allowduplicates = CreateConVar(
        "sm_umc_playerlimit_allowduplicates",
        "1",
        "Allows a map to appear in the vote more than once. This should be enabled if you want the same map in different categories to be distinct.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_threshold = CreateConVar(
        "sm_umc_playerlimit_threshold",
        "0",
        "If the winning option has less than this percentage of total votes, a vote will fail and the action specified in \"sm_umc_playerlimits_failaction\" cvar will be performed.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_fail_action = CreateConVar(
        "sm_umc_playerlimit_failaction",
        "0",
        "Specifies what action to take if the vote doesn't reach the set theshold.\n 0 - Do Nothing,\n 1 - Perform Runoff Vote",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_fail_action = CreateConVar(
        "sm_umc_playerlimit_runoff_failaction",
        "0",
        "Specifies what action to take if the runoff vote reaches the maximum amount of runoffs and the set threshold has not been reached.\n 0 - Do Nothing,\n 1 - Change Map to Winner",
        0, true, 0.0, true, 1.0
    );
    
    cvar_invalid_min = CreateConVar(
        "sm_umc_playerlimit_minaction",
        "0",
        "Specifies what action to take when the number of players on the server is less than what the current map allows.\n 0 - Do Nothing,\n 1 - Pick a map, change to it,\n 2 - Pick a map, run a yes/no vote to change,\n 3 - Run a full mapvote, change to the winner.",
        0, true, 0.0, true, 3.0
    );

    cvar_invalid_max = CreateConVar(
        "sm_umc_playerlimit_maxaction",
        "0",
        "Specifies what action to take when the number of players on the server is more than what the current map allows.\n 0 - Do Nothing,\n 1 - Pick a map, change to it,\n 2 - Pick a map, run a yes/no vote to change,\n 3 - Run a full mapvote, change to the winner.",
        0, true, 0.0, true, 3.0
    );

    cvar_invalid_post = CreateConVar(
        "sm_umc_playerlimit_voteaction",
        "0",
        "Specifies when to change the map after an action is taken due to too many or too little players.\n 0 - Change instantly,\n 1 - Change at the end of the round",
        0, true, 0.0, true, 1.0
    );
    
    cvar_invalid_delay = CreateConVar(
        "sm_umc_playerlimit_delay",
        "240.0",
        "Time in seconds before the plugin will check to see if the current number of players is within the map's bounds.",
        0, true, 0.0
    );
    
    cvar_mem = CreateConVar(
        "sm_umc_playerlimit_mapexclude",
        "4",
        "Specifies how many past maps to exclude from Player Count Monitor votes. 1 = Current Map Only",
        0, true, 0.0
    );
    
    cvar_catmem = CreateConVar(
        "sm_umc_playerlimit_groupexclude",
        "0",
        "Specifies how many past map groups to exclude from Player Count Monitor votes.",
        0, true, 0.0
    );
    
    cvar_vote_type = CreateConVar(
        "sm_umc_playerlimit_type",
        "0",
        "Controls vote type:\n 0 - Maps,\n 1 - Groups,\n 2 - Tiered Vote (vote for a group, then vote for a map from the group).",
        0, true, 0.0, true, 2.0
    );
    
    cvar_dontchange = CreateConVar(
        "sm_umc_playerlimit_dontchange",
        "1",
        "Adds a \"Don't Change\" option to votes.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_startsound = CreateConVar(
        "sm_umc_playerlimit_startsound",
        "",
        "Sound file (relative to sound folder) to play at the start of a vote."
    );
    
    cvar_endsound = CreateConVar(
        "sm_umc_playerlimit_endsound",
        "",
        "Sound file (relative to sound folder) to play at the completion of a vote."
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-playercountmonitor");
    
    //Initialize our memory arrays
    new numCells = ByteCountToCells(MAP_LENGTH);
    vote_mem_arr    = CreateArray(numCells);
    vote_catmem_arr = CreateArray(numCells);
    
    //Load the translations file
    LoadTranslations("ultimate-mapchooser.phrases");
}

//************************************************************************************************//
//                                           GAME EVENTS                                          //
//************************************************************************************************//
//Called after all config files were executed.
public OnConfigsExecuted()
{
    validity_enabled = false;
    
    //Set triggers for min and max number of players.
    new bool:setup = ReloadMapcycle();    
    
    //Grab the name of the current map.
    decl String:mapName[MAP_LENGTH], String:groupName[MAP_LENGTH];
    GetCurrentMap(mapName, sizeof(mapName));
    UMC_GetCurrentMapGroup(groupName, sizeof(groupName));
    
    if (setup && StrEqual(groupName, INVALID_GROUP, false))
    {
        KvFindGroupOfMap(umc_mapcycle, mapName, groupName, sizeof(groupName));
    }
    
    //Add the map to all the memory queues.
    new mapmem = GetConVarInt(cvar_mem);
    new catmem = GetConVarInt(cvar_catmem);
    AddToMemoryArray(mapName, vote_mem_arr, mapmem);
    AddToMemoryArray(groupName, vote_catmem_arr, (mapmem > catmem) ? mapmem : catmem);
    
    if (setup)
    {
        SetupMinMaxPlayers(mapName, groupName);
        RemovePreviousMapsFromCycle();
    }
}

public OnMapStart()
{
    SetupVoteSounds();
}


// Called when a client enters the server.
// Required for checking for min/max players and updating the RTV threshold.
public OnClientPutInServer(client)
{
    //Get the number of players.
    new clientCount = GetRealClientCount();
        
    // Change the map if...
    //    ...the flag to perform the min/max player check is enabled AND
    //    ...the cvar to check for max players is enabled AND
    //    ...the number of players on the server exceeds the limit set by the map.
    if (validity_enabled && clientCount > map_max_players && GetConVarInt(cvar_invalid_max) != _:PLAction_Nothing)
    {
        LogUMCMessage("Number of clients above player threshold. %i clients, %i max.", clientCount, map_max_players);
        PrintToChatAll("[UMC] %t", "Too Many Players", map_max_players);
        ChangeToValidMap(cvar_invalid_max);
    }
}

// Called after a client has left the server.
// Needed to update RTV and the check that the server has the required number of players for the map.
public OnClientDisconnect_Post(client)
{
    //Get the number of players.
    new clientCount = GetRealClientCount();
    
    if (clientCount == 0)
    {
        return;
    }
    
    if (validity_enabled && clientCount < map_min_players && GetConVarInt(cvar_invalid_min) != _:PLAction_Nothing)
    {
        LogUMCMessage("Number of clients below player threshold: %i clients, %i min", clientCount, map_min_players);
        PrintToChatAll("[UMC] %t", "Not Enough Players", map_min_players);
        ChangeToValidMap(cvar_invalid_min);
    }
}

//************************************************************************************************//
//                                              SETUP                                             //
//************************************************************************************************//
//Parses the mapcycle file and returns a KV handle representing the mapcycle.
Handle:GetMapcycle()
{
    //Grab the file name from the cvar.
    decl String:filename[PLATFORM_MAX_PATH];
    GetConVarString(cvar_filename, filename, sizeof(filename));
    
    //Get the kv handle from the file.
    new Handle:result = GetKvFromFile(filename, "umc_rotation");
    
    //Log an error and return empty handle if the mapcycle file failed to parse.
    if (result == INVALID_HANDLE)
    {
        LogError("SETUP: Mapcycle failed to load!");
        return INVALID_HANDLE;
    }
    
    //Success!
    return result;
}

//Sets up the vote sounds.
SetupVoteSounds()
{
    //Grab sound files from cvars.
    GetConVarString(cvar_startsound, vote_start_sound, sizeof(vote_start_sound));
    GetConVarString(cvar_endsound, vote_end_sound, sizeof(vote_end_sound));
    GetConVarString(cvar_runoff_sound, runoff_sound, sizeof(runoff_sound));
    
    //Gotta cache 'em all!
    CacheSound(vote_start_sound);
    CacheSound(vote_end_sound);
    CacheSound(runoff_sound);
}

//Sets the min and max player values for the current map.
SetupMinMaxPlayers(const String:map[], const String:group[])
{
    //Set defaults in the event we error out.
    map_min_players = 0;
    map_max_players = MaxClients;
        
    KvRewind(umc_mapcycle); //rewind the mapcycle handle
    new dmin, dmax; //variables to store default values for the category.
    
    //Set appropriate min and max player variables if we can reach the current 
    // category in the mapcycle OR we can jump to the map somewhere in the mapcycle
    if (!StrEqual(group, INVALID_GROUP) && KvJumpToKey(umc_mapcycle, group))
    {
        //Store defaults for the category
        dmin = KvGetNum(umc_mapcycle, PLAYERLIMIT_KEY_GROUP_MIN, 0);
        dmax = KvGetNum(umc_mapcycle, PLAYERLIMIT_KEY_GROUP_MAX, MaxClients);
        
        //Set the map's min and max player variables if we can reach the current map in the mapcycle.
        if (KvJumpToKey(umc_mapcycle, map))
        {
            //Set variables for min and max players, using the category defaults if they are not available.
            map_min_players = KvGetNum(umc_mapcycle, PLAYERLIMIT_KEY_MAP_MIN, dmin);
            map_max_players = KvGetNum(umc_mapcycle, PLAYERLIMIT_KEY_MAP_MAX, dmax);
            
            //Return to the root.
            KvRewind(umc_mapcycle);
            
            //Log Info
            LogUMCMessage("Min Players: %i, Max Players: %i", map_min_players, map_max_players);
    
            //Make timer to do min/max player check.
            MakePlayerLimitCheckTimer();
            return;
        }
        KvGoBack(umc_mapcycle);
    }
    
    //Error, was not able to find the appropriate data.
    LogUMCMessage("Current Map Group could not be determined. (Non-UMC mapchange or plugin just loaded.)");
    
    //Log Info
    LogUMCMessage("Min Players: %i, Max Players: %i", map_min_players, map_max_players);
}

//Reloads the mapcycle. Returns true on success, false on failure.
bool:ReloadMapcycle()
{
    if (umc_mapcycle != INVALID_HANDLE)
    {
        CloseHandle(umc_mapcycle);
        umc_mapcycle = INVALID_HANDLE;
    }

    if (map_kv != INVALID_HANDLE)
    {
        CloseHandle(map_kv);
        map_kv = INVALID_HANDLE;
    }
    umc_mapcycle = GetMapcycle();
    
    return umc_mapcycle != INVALID_HANDLE;
}

RemovePreviousMapsFromCycle()
{
    map_kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(umc_mapcycle, map_kv);
    FilterMapcycleFromArrays(map_kv, vote_mem_arr, vote_catmem_arr, GetConVarInt(cvar_catmem));
}

//************************************************************************************************//
//                                          PLAYER LIMITS                                         //
//************************************************************************************************//
//Creates the timer to check for when the amount of players is within the min and max bounds.
MakePlayerLimitCheckTimer()
{
    //We are currently not checking for valid player amounts.
    validity_enabled = false;
    
    //Get the timer delay
    new Float:delay = GetConVarFloat(cvar_invalid_delay);
    
    LogUMCMessage("Server will begin watching for inproper number of players in %.f seconds.", delay);
    
    //Create the timer.
    CreateTimer(delay, Handle_PlayerLimitTimer, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
}

// Callback for the min and max player check timer. Once the timer ends, we begin testing for valid amounts of players.
public Action:Handle_PlayerLimitTimer(Handle:Timer)
{
    //We are now checking for valid player amounts.
    validity_enabled = true;
    LogUMCMessage("Server is now watching for inproper number of players.");
    
    //Check player limits now.
    RunPlayerLimitCheck();
}

//Checks to see if the amount of players on the server is withing the required bounds set by the
//map. Changes to a map that does satisfy the requirement if this map doesn't.
public RunPlayerLimitCheck()
{
    //Get the number of players.
    new clientCount = GetRealClientCount();
    
    if (clientCount == 0)
    {
        return;
    }
    
    //Change the map if...
    //    ...the flag to perform the min/max player check is enabled AND
    //    ...the cvar to check for max players is enabled AND
    //    ...the number of players on the server exceeds the limit set by the map.
    if (validity_enabled && clientCount > map_max_players && GetConVarInt(cvar_invalid_max) != _:PLAction_Nothing)
    {
        LogUMCMessage("Number of clients above player threshold. %i clients, %i max.", clientCount, map_max_players);
        PrintToChatAll("[UMC] %t", "Too Many Players", map_max_players);
        ChangeToValidMap(cvar_invalid_max);
    }
    //Otherwise, change the map if...
    //    ...the cvar to check for min players is enabled AND
    //    ...the number of players on the server is less than the minimum required by the map.
    else if (validity_enabled && clientCount < map_min_players && GetConVarInt(cvar_invalid_min) != _:PLAction_Nothing)
    {
        LogUMCMessage("Number of clients below player threshold: %i clients, %i min",
            clientCount, map_min_players);
        PrintToChatAll("[UMC] %t", "Not Enough Players", map_min_players);
        ChangeToValidMap(cvar_invalid_min);
    }
}

//Handles changing to a map in the event the number of players on the server is outside of the 
//bounds defined by the map.
//    cvar:    the cvar defining what action to take in this event.
ChangeToValidMap(Handle:cvar)
{
    validity_enabled = false;

    switch (PlayerLimit_Action:GetConVarInt(cvar))
    {
        case PLAction_Now: //Pick a map and change to it.
        {
            //Log message
            LogUMCMessage("Changing to a map that can support %i players.", GetRealClientCount());
            
            //Get the picked map.
            decl String:map[MAP_LENGTH], String:group[MAP_LENGTH];
            if (UMC_GetRandomMap(map_kv, umc_mapcycle, INVALID_GROUP, map, sizeof(map), group, sizeof(group), false, true))
            {
                UMC_SetNextMap(map_kv, map, group, UMC_ChangeMapTime:GetConVarInt(cvar_invalid_post));
            }
        }
        case PLAction_YesNo: //Pick a map and run yes/no vote.
        {
            LogUMCMessage("Picking a map that can support %i players.", GetRealClientCount());
            
            //Get the picked map.
            decl String:map[MAP_LENGTH];
            if (UMC_GetRandomMap(map_kv, umc_mapcycle, INVALID_GROUP, map, sizeof(map), vote_group, sizeof(vote_group), false, true))
            {
                LogUMCMessage("Perfoming YES/NO vote to change the map to '%s'", map);
            
                //Run the yes/no vote if there isn't already a vote in progress.
                if (!IsVoteInProgress() && !UMC_IsVoteInProgress("core"))
                {
                    //Initialize the menu.
                    new Handle:menu = CreateMenu(Handle_YesNoVoteMenu, MenuAction_DisplayItem|MenuAction_Display);
                    SetVoteResultCallback(menu, Handle_YesNoMapVote);

                    //Set the title
                    SetMenuTitle(menu, "Yes/No Menu Title");
                    
                    //Add options
                    AddMenuItem(menu, map, "Yes");
                    AddMenuItem(menu, NO_OPTION, "No");
                    SetMenuExitButton(menu, false);
                    
                    //Admin flags
                    decl String:flags[64];
                    GetConVarString(cvar_flags, flags, sizeof(flags));
                    
                    //Display it.
                    VoteMenuToAllWithFlags(menu, GetConVarInt(cvar_vote_time), flags);
                    
                    //Play the vote start sound if the vote start sound is defined.
                    if (strlen(vote_start_sound) > 0)
                    {
                        EmitSoundToAllAny(vote_start_sound);
                    }
                }
                else
                {
                    LogUMCMessage("Unable to start YES/NO vote, another vote is in progress.");
                    MakeRetryVoteTimer(RunPlayerLimitCheck);
                }
            }
        }
        case PLAction_Vote: //Run a full mapvote.
        {
            LogUMCMessage("Performing map vote to change to a map that can support %i players.", GetRealClientCount());
        
            //Run the mapvote if there isn't already a vote in progress.
            if (!IsVoteInProgress())
            {
                decl String:flags[64];
                GetConVarString(cvar_flags, flags, sizeof(flags));
                
                new clients[MAXPLAYERS+1];
                new numClients;
                GetClientsWithFlags(flags, clients, sizeof(clients), numClients);
            
                //Start the UMC vote.
                UMC_StartVote(
                    "core",
                    map_kv,                                                     //Mapcycle
                    umc_mapcycle,                                               //Complete mapcycle
                    UMC_VoteType:GetConVarInt(cvar_vote_type),                  //Vote Type (map, group, tiered)
                    GetConVarInt(cvar_vote_time),                               //Vote duration
                    GetConVarBool(cvar_scramble),                               //Scramble
                    vote_start_sound,                                           //Start Sound
                    vote_end_sound,                                             //End Sound
                    false,                                                      //Extend option
                    0.0,                                                        //How long to extend the timelimit by,
                    0,                                                          //How much to extend the roundlimit by,
                    0,                                                          //How much to extend the fraglimit by,
                    GetConVarBool(cvar_dontchange),                             //Don't Change option
                    GetConVarFloat(cvar_vote_threshold),                        //Threshold
                    UMC_ChangeMapTime:GetConVarInt(cvar_invalid_post),          //Success Action (when to change the map)
                    UMC_VoteFailAction:GetConVarInt(cvar_fail_action),          //Fail Action (runoff / nothing)
                    GetConVarInt(cvar_runoff),                                  //Max Runoffs
                    GetConVarInt(cvar_runoff_max),                              //Max maps in the runoff
                    UMC_RunoffFailAction:GetConVarInt(cvar_runoff_fail_action), //Runoff Fail Action
                    runoff_sound,                                               //Runoff Sound
                    GetConVarBool(cvar_strict_noms),                            //Nomination Strictness
                    GetConVarBool(cvar_vote_allowduplicates),                   //Ignore Duplicates
                    clients,
                    numClients
                );
            }
            else
            {
                LogUMCMessage("Unable to start map vote, another vote is in progress.");
                MakeRetryVoteTimer(RunPlayerLimitCheck);
            }
        }
    }
}

//Handles actions from the yes/no map vote.
public Handle_YesNoVoteMenu(Handle:menu, MenuAction:action, param1, param2)
{
    if (action == MenuAction_Display)
    {
        new Handle:panel = Handle:param2;
        
        decl String:map[MAP_LENGTH];
        GetMenuItem(menu, 0, map, sizeof(map));
        
        decl String:phrase[255];
        GetMenuTitle(menu, phrase, sizeof(phrase));
        
        decl String:buffer[255];
        FormatEx(buffer, sizeof(buffer), "%T", phrase, param1, map);
        
        SetPanelTitle(panel, buffer);
    }
    else if (action == MenuAction_DisplayItem)
    {
        decl String:display[MAP_LENGTH];
        GetMenuItem(menu, param2, "", 0, _, display, sizeof(display));
        
        decl String:buffer[255];
        FormatEx(buffer, sizeof(buffer), "%T", display, param1);
        
        return RedrawMenuItem(buffer);
    }
    else if (action == MenuAction_End)
    {
        CloseHandle(menu);
    }
    return 0;
}

//Called at the end of a yes/no map vote.
public Handle_YesNoMapVote(Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
    //Play the vote completed sound if the vote completed sound is defined.
    if (strlen(vote_end_sound) > 0)
    {
        EmitSoundToAllAny(vote_end_sound);
    }
    
    //Get the map used.
    decl String:map[MAP_LENGTH];
    GetMenuItem(menu, 0, map, sizeof(map));
    
    //Change the map if the answer wasn't No OR there was a tie.
    if (item_info[0][VOTEINFO_ITEM_INDEX] == 1 && (num_votes <= 1 || item_info[0][VOTEINFO_ITEM_VOTES] != item_info[1][VOTEINFO_ITEM_VOTES]))
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "Map Unchanged",
            "Vote Win Percentage",
                float(item_info[0][VOTEINFO_ITEM_VOTES]) / float(num_votes) * 100,
                num_votes
        );
    }
    else //Otherwise, just display the result.
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "End of Map Vote Map Won",
                map,
            "Vote Win Percentage",
                float(item_info[0][VOTEINFO_ITEM_VOTES]) / float(num_votes) * 100,
                num_votes
        );
        
        UMC_SetNextMap(map_kv, map, vote_group, UMC_ChangeMapTime:GetConVarInt(cvar_invalid_post));
    }
}

//************************************************************************************************//
//                                   ULTIMATE MAPCHOOSER EVENTS                                   //
//************************************************************************************************//
//Called when UMC has set a next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    validity_enabled = false;
}

//Called when UMC requests that the mapcycle should be reloaded.
public UMC_RequestReloadMapcycle()
{
    if (!ReloadMapcycle())
    {
        validity_enabled = false;
    }
    else
    {
        RemovePreviousMapsFromCycle();
    }
}

//Called when UMC requests that the mapcycle is printed to the console.
public UMC_DisplayMapCycle(client, bool:filtered)
{
    PrintToConsole(client, "Module: Player Count Monitor");
    if (filtered)
    {
        new Handle:filteredMapcycle = UMC_FilterMapcycle(map_kv, umc_mapcycle, false, true);
        PrintKvToConsole(filteredMapcycle, client);
        CloseHandle(filteredMapcycle);
    }
    else
    {
        PrintKvToConsole(umc_mapcycle, client);
    }
}
