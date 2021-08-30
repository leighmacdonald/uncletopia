/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                               Ultimate Mapchooser - Vote Command                              *
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
#include <umc-core>
#include <umc_utils>

//Plugin Information
public Plugin:myinfo =
{
    name        = "[UMC] Vote Command",
    author      = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Extends Ultimate Mapchooser to allow admins to spawn votes.",
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
new Handle:cvar_extend_rounds        = INVALID_HANDLE;
new Handle:cvar_extend_frags         = INVALID_HANDLE;
new Handle:cvar_extend_time          = INVALID_HANDLE;
new Handle:cvar_extensions           = INVALID_HANDLE;
new Handle:cvar_vote_mem             = INVALID_HANDLE;
new Handle:cvar_vote_type            = INVALID_HANDLE;
new Handle:cvar_vote_startsound      = INVALID_HANDLE;
new Handle:cvar_vote_endsound        = INVALID_HANDLE;
new Handle:cvar_vote_catmem          = INVALID_HANDLE;
new Handle:cvar_dontchange           = INVALID_HANDLE;
new Handle:cvar_flags                = INVALID_HANDLE;
////----/CONVARS-----/////

//Mapcycle KV
new Handle:map_kv = INVALID_HANDLE;
new Handle:umc_mapcycle = INVALID_HANDLE;

//Memory queues. Used to store the previously played maps.
new Handle:vote_mem_arr    = INVALID_HANDLE;
new Handle:vote_catmem_arr = INVALID_HANDLE;

//Sounds to be played at the start and end of votes.
new String:vote_start_sound[PLATFORM_MAX_PATH], String:vote_end_sound[PLATFORM_MAX_PATH],
    String:runoff_sound[PLATFORM_MAX_PATH];
    
//Can we start a vote (is the mapcycle valid?)
new bool:can_vote;

//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//
//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_flags = CreateConVar(
        "sm_umc_vc_adminflags",
        "",
        "Specifies which admin flags are necessary for a player to participate in a vote. If empty, all players can participate."
    );

    cvar_fail_action = CreateConVar(
        "sm_umc_vc_failaction",
        "0",
        "Specifies what action to take if the vote doesn't reach the set theshold.\n 0 - Do Nothing,\n 1 - Perform Runoff Vote",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_fail_action = CreateConVar(
        "sm_umc_vc_runoff_failaction",
        "0",
        "Specifies what action to take if the runoff vote reaches the maximum amount of runoffs and the set threshold has not been reached.\n 0 - Do Nothing,\n 1 - Change Map to Winner",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_max = CreateConVar(
        "sm_umc_vc_runoff_max",
        "0",
        "Specifies the maximum number of maps to appear in a runoff vote.\n 1 or 0 sets no maximum.",
        0, true, 0.0
    );

    cvar_vote_allowduplicates = CreateConVar(
        "sm_umc_vc_allowduplicates",
        "1",
        "Allows a map to appear in the vote more than once. This should be enabled if you want the same map in different categories to be distinct.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_threshold = CreateConVar(
        "sm_umc_vc_threshold",
        "0",
        "If the winning option has less than this percentage of total votes, a vote will fail and the action specified in \"sm_umc_vc_failaction\" cvar will be performed.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff = CreateConVar(
        "sm_umc_vc_runoffs",
        "0",
        "Specifies a maximum number of runoff votes to run for a vote.\n 0 = unlimited.",
        0, true, 0.0
    );
    
    cvar_runoff_sound = CreateConVar(
        "sm_umc_vc_runoff_sound",
        "",
        "If specified, this sound file (relative to sound folder) will be played at the beginning of a runoff vote. If not specified, it will use the normal vote start sound."
    );
    
    cvar_vote_catmem = CreateConVar(
        "sm_umc_vc_groupexclude",
        "0",
        "Specifies how many past map groups to exclude from votes.",
        0, true, 0.0
    );
    
    cvar_vote_startsound = CreateConVar(
        "sm_umc_vc_startsound",
        "",
        "Sound file (relative to sound folder) to play at the start of a vote."
    );
    
    cvar_vote_endsound = CreateConVar(
        "sm_umc_vc_endsound",
        "",
        "Sound file (relative to sound folder) to play at the completion of a vote."
    );
    
    cvar_strict_noms = CreateConVar(
        "sm_umc_vc_nominate_strict",
        "0",
        "Specifies whether the number of nominated maps appearing in the vote for a map group should be limited by the group's \"maps_invote\" setting.",
        0, true, 0.0, true, 1.0
    );

    cvar_extend_rounds = CreateConVar(
        "sm_umc_vc_extend_roundstep",
        "5",
        "Specifies how many more rounds each extension adds to the round limit.",
        0, true, 1.0
    );

    cvar_extend_time = CreateConVar(
        "sm_umc_vc_extend_timestep",
        "15",
        "Specifies how many more minutes each extension adds to the time limit.",
        0, true, 1.0
    );

    cvar_extend_frags = CreateConVar(
        "sm_umc_vc_extend_fragstep",
        "10",
        "Specifies how many more frags each extension adds to the frag limit.",
        0, true, 1.0
    );

    cvar_extensions = CreateConVar(
        "sm_umc_vc_extend",
        "0",
        "Adds an \"Extend\" option to votes.",
        0, true, 0.0, true, 1.0
    );

    cvar_vote_type = CreateConVar(
        "sm_umc_vc_type",
        "0",
        "Controls vote type:\n 0 - Maps,\n 1 - Groups,\n 2 - Tiered Vote (vote for a group, then vote for a map from the group).",
        0, true, 0.0, true, 2.0
    );

    cvar_vote_time = CreateConVar(
        "sm_umc_vc_duration",
        "20",
        "Specifies how long a vote should be available for.",
        0, true, 10.0
    );

    cvar_filename = CreateConVar(
        "sm_umc_vc_cyclefile",
        "umc_mapcycle.txt",
        "File to use for Ultimate Mapchooser's map rotation."
    );

    cvar_vote_mem = CreateConVar(
        "sm_umc_vc_mapexclude",
        "4",
        "Specifies how many past maps to exclude from votes. 1 = Current Map Only",
        0, true, 0.0
    );

    cvar_scramble = CreateConVar(
        "sm_umc_vc_menuscrambled",
        "0",
        "Specifies whether vote menu items are displayed in a random order.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_dontchange = CreateConVar(
        "sm_umc_vc_dontchange",
        "1",
        "Adds a \"Don't Change\" option to votes.",
        0, true, 0.0, true, 1.0
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-votecommand");
    
    //Admin command to immediately start a mapvote.
    RegAdminCmd("sm_umc_mapvote", Command_Vote, ADMFLAG_CHANGEMAP, "Starts an Ultimate Mapchooser map vote.");
    
    //Initialize our memory arrays
    new numCells = ByteCountToCells(MAP_LENGTH);
    vote_mem_arr    = CreateArray(numCells);
    vote_catmem_arr = CreateArray(numCells);
}

//************************************************************************************************//
//                                           GAME EVENTS                                          //
//************************************************************************************************//
//Called after all config files were executed.
public OnConfigsExecuted()
{
    can_vote = ReloadMapcycle();   
    
    //Grab the name of the current map.
    decl String:mapName[MAP_LENGTH];
    GetCurrentMap(mapName, sizeof(mapName));
    decl String:groupName[MAP_LENGTH];
    UMC_GetCurrentMapGroup(groupName, sizeof(groupName));
    
    if (can_vote && StrEqual(groupName, INVALID_GROUP, false))
    {
        KvFindGroupOfMap(umc_mapcycle, mapName, groupName, sizeof(groupName));
    }
    
    //Add the map to all the memory queues.
    new mapmem = GetConVarInt(cvar_vote_mem);
    new catmem = GetConVarInt(cvar_vote_catmem);
    AddToMemoryArray(mapName, vote_mem_arr, mapmem);
    AddToMemoryArray(groupName, vote_catmem_arr, (mapmem > catmem) ? mapmem : catmem);
    
    if (can_vote)
    {
        RemovePreviousMapsFromCycle();
    }
}

public OnMapStart()
{
    SetupVoteSounds();
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
    FilterMapcycleFromArrays(map_kv, vote_mem_arr, vote_catmem_arr, GetConVarInt(cvar_vote_catmem));
}

//Sets up the vote sounds.
SetupVoteSounds()
{
    //Grab sound files from cvars.
    GetConVarString(cvar_vote_startsound, vote_start_sound, sizeof(vote_start_sound));
    GetConVarString(cvar_vote_endsound, vote_end_sound, sizeof(vote_end_sound));
    GetConVarString(cvar_runoff_sound, runoff_sound, sizeof(runoff_sound));
    
    //Gotta cache 'em all!
    CacheSound(vote_start_sound);
    CacheSound(vote_end_sound);
    CacheSound(runoff_sound);
}

//************************************************************************************************//
//                                            COMMANDS                                            //
//************************************************************************************************//
//Called when the command to start a map vote is called
public Action:Command_Vote(client, args)
{
    if (!can_vote)
    {
        ReplyToCommand(client, "[UMC] Mapcycle is invalid, cannot start a vote.");
        return Plugin_Handled;
    }
    
    if (args < 1)
    {
        ReplyToCommand(client, "[UMC] Usage: sm_umc_mapvote <0|1|2>\n 0: Change now, 1: Change at end of round, 2: Change at end of map.");
        return Plugin_Handled;
    }
    
    decl String:arg[128];
    GetCmdArg(1, arg, sizeof(arg));
    new changeTime = StringToInt(arg);
    
    if (changeTime < 0 || changeTime > 2)
    {
        ReplyToCommand(client, "[UMC] Usage: sm_umc_mapvote <0|1|2>\n 0: Change now, 1: Change at end of round, 2: Change at end of map.");
        return Plugin_Handled;
    }
    
    decl String:flags[64];
    GetConVarString(cvar_flags, flags, sizeof(flags));
    
    new clients[MAXPLAYERS+1];
    new numClients;
    GetClientsWithFlags(flags, clients, sizeof(clients), numClients);

    //Start the UMC vote.
    new bool:result = UMC_StartVote(
        "core",
        map_kv,                                                     //Mapcycle
        umc_mapcycle,                                               //Complete Mapcycle
        UMC_VoteType:GetConVarInt(cvar_vote_type),                  //Vote Type (map, group, tiered)
        GetConVarInt(cvar_vote_time),                               //Vote duration
        GetConVarBool(cvar_scramble),                               //Scramble
        vote_start_sound,                                           //Start Sound
        vote_end_sound,                                             //End Sound
        GetConVarBool(cvar_extensions),                             //Extend option
        GetConVarFloat(cvar_extend_time),                           //How long to extend the timelimit by,
        GetConVarInt(cvar_extend_rounds),                           //How much to extend the roundlimit by,
        GetConVarInt(cvar_extend_frags),                            //How much to extend the fraglimit by,
        GetConVarBool(cvar_dontchange),                             //Don't Change option
        GetConVarFloat(cvar_vote_threshold),                        //Threshold
        UMC_ChangeMapTime:changeTime,                               //Success Action (when to change the map)
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
    
    if (result)
    {
        ReplyToCommand(client, "[UMC] Started Vote.");
    }
    else
    {    
        ReplyToCommand(client, "[UMC] Could not start vote. See log for details.");
    }
    return Plugin_Handled;
}

//************************************************************************************************//
//                                   ULTIMATE MAPCHOOSER EVENTS                                   //
//************************************************************************************************//
//Called when UMC requests that the mapcycle should be reloaded.
public UMC_RequestReloadMapcycle()
{
    can_vote = ReloadMapcycle();
    if (can_vote)
    {
        RemovePreviousMapsFromCycle();
    }
}

//Called when UMC requests that the mapcycle is printed to the console.
public UMC_DisplayMapCycle(client, bool:filtered)
{
    PrintToConsole(client, "Module: Vote Command");
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
