/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                              Ultimate Mapchooser - Rock The Vote                              *
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
    name        = "[UMC] Rock The Vote",
    author      = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Extends Ultimate Mapchooser to provide RTV map voting.",
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
new Handle:cvar_rtv_enable           = INVALID_HANDLE;
new Handle:cvar_rtv_changetime       = INVALID_HANDLE;
new Handle:cvar_rtv_delay            = INVALID_HANDLE;
new Handle:cvar_rtv_minplayers       = INVALID_HANDLE;
new Handle:cvar_rtv_postaction       = INVALID_HANDLE;
new Handle:cvar_rtv_needed           = INVALID_HANDLE;
new Handle:cvar_rtv_interval         = INVALID_HANDLE;
new Handle:cvar_rtv_mem              = INVALID_HANDLE;
new Handle:cvar_rtv_catmem           = INVALID_HANDLE;
new Handle:cvar_rtv_type             = INVALID_HANDLE;
new Handle:cvar_rtv_dontchange       = INVALID_HANDLE;
new Handle:cvar_rtv_startsound       = INVALID_HANDLE;
new Handle:cvar_rtv_endsound         = INVALID_HANDLE;
new Handle:cvar_voteflags            = INVALID_HANDLE;
new Handle:cvar_enterflags           = INVALID_HANDLE;
new Handle:cvar_enterbonusflags      = INVALID_HANDLE;
new Handle:cvar_enterbonusamt        = INVALID_HANDLE;
////----/CONVARS-----/////

//Mapcycle KV
new Handle:map_kv = INVALID_HANDLE;        
new Handle:umc_mapcycle = INVALID_HANDLE;

//Memory queues.
new Handle:vote_mem_arr = INVALID_HANDLE;
new Handle:vote_catmem_arr = INVALID_HANDLE;

//Array of players who have RTV'd
new Handle:rtv_clients = INVALID_HANDLE;

//Stores whether or not players have seen the long RTV message.
new bool:rtv_message[MAXPLAYERS+1];

//Keeps track of a delay before we are able to RTV.
new Float:rtv_delaystart;

//How many people are required to trigger an RTV.
new rtv_threshold;

//Flags
new bool:rtv_completed;    //Has an rtv been completed?
new bool:rtv_enabled;      //Is RTV enabled right now?
new bool:vote_completed;   //Has UMC completed a vote?
new bool:rtv_inprogress;   //Is the rtv vote in progress?

//Sounds to be played at the start and end of votes.
new String:vote_start_sound[PLATFORM_MAX_PATH], String:vote_end_sound[PLATFORM_MAX_PATH],
    String:runoff_sound[PLATFORM_MAX_PATH];

//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//
//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_enterbonusflags = CreateConVar(
        "sm_umc_rtv_enteradminflags_bonusflags",
        "",
        "If specified, players with any of these admin flags will be given bonus RTV entrance votes, of the amount determined by \"sm_umc_rtv_enteradminflags_bonusamt\"."
    );

    cvar_enterbonusamt = CreateConVar(
        "sm_umc_rtv_enteradminflags_bonusamt",
        "2",
        "The amount of entrance votes to be given to players who have at least one of the admin flags specified by \"sm_umc_rtv_enteradminflags_bonusflags\".",
        0, true, 1.0
    );

    cvar_voteflags = CreateConVar(
        "sm_umc_rtv_voteadminflags",
        "",
        "Specifies which admin flags are necessary for a player to participate in a vote. If empty, all players can participate."
    );
    
    cvar_enterflags = CreateConVar(
        "sm_umc_rtv_enteradminflags",
        "",
        "Specifies which admin flags are necessary for a player to enter RTV. If empty, all players can participate."
    );

    cvar_fail_action = CreateConVar(
        "sm_umc_rtv_failaction",
        "0",
        "Specifies what action to take if the vote doesn't reach the set theshold.\n 0 - Do Nothing,\n 1 - Perform Runoff Vote",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_fail_action = CreateConVar(
        "sm_umc_rtv_runoff_failaction",
        "0",
        "Specifies what action to take if the runoff vote reaches the maximum amount of runoffs and the set threshold has not been reached.\n 0 - Do Nothing,\n 1 - Change Map to Winner",
        0, true, 0.0, true, 1.0
    );

    cvar_runoff_max = CreateConVar(
        "sm_umc_rtv_runoff_max",
        "0",
        "Specifies the maximum number of maps to appear in a runoff vote.\n 1 or 0 sets no maximum.",
        0, true, 0.0
    );

    cvar_vote_allowduplicates = CreateConVar(
        "sm_umc_rtv_allowduplicates",
        "1",
        "Allows a map to appear in the vote more than once. This should be enabled if you want the same map in different categories to be distinct.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_threshold = CreateConVar(
        "sm_umc_rtv_threshold",
        "0",
        "If the winning option has less than this percentage of total votes, a vote will fail and the action specified in \"sm_umc_rtv_failaction\" cvar will be performed.",
        0, true, 0.0, true, 1.0
    );

    cvar_runoff = CreateConVar(
        "sm_umc_rtv_runoffs",
        "0",
        "Specifies a maximum number of runoff votes to run for any given vote.\n 0 disables runoff votes.",
        0, true, 0.0
    );
    
    cvar_runoff_sound = CreateConVar(
        "sm_umc_rtv_runoff_sound",
        "",
        "If specified, this sound file (relative to sound folder) will be played at the beginning of a runoff vote. If not specified, it will use the normal start vote sound."
    );
    
    cvar_rtv_catmem = CreateConVar(
        "sm_umc_rtv_groupexclude",
        "0",
        "Specifies how many past map groups to exclude from RTVs.",
        0, true, 0.0
    );
    
    cvar_rtv_startsound = CreateConVar(
        "sm_umc_rtv_startsound",
        "",
        "Sound file (relative to sound folder) to play at the start of a vote."
    );
    
    cvar_rtv_endsound = CreateConVar(
        "sm_umc_rtv_endsound",
        "",
        "Sound file (relative to sound folder) to play at the completion of a vote."
    );
    
    cvar_strict_noms = CreateConVar(
        "sm_umc_rtv_nominate_strict",
        "0",
        "Specifies whether the number of nominated maps appearing in the vote for a map group should be limited by the group's \"maps_invote\" setting.",
        0, true, 0.0, true, 1.0
    );

    cvar_rtv_interval = CreateConVar(
        "sm_umc_rtv_interval",
        "240",
        "Time (in seconds) after a failed RTV before another can be held.",
        0, true, 0.0
    );

    cvar_rtv_dontchange = CreateConVar(
        "sm_umc_rtv_dontchange",
        "1",
        "Adds a \"Don't Change\" option to RTVs.",
        0, true, 0.0, true, 1.0
    );

    cvar_rtv_postaction = CreateConVar(
        "sm_umc_rtv_postvoteaction",
        "0",
        "What to do with RTVs after another UMC vote has completed.\n 0 - Allow, success = instant change,\n 1 - Deny,\n 2 - Hold a normal RTV vote",
        0, true, 0.0, true, 2.0
    );

    cvar_rtv_minplayers = CreateConVar(
        "sm_umc_rtv_minplayers",
        "0",
        "Number of players required before RTV will be enabled.",
        0, true, 0.0, true, float(MAXPLAYERS)
    );

    cvar_rtv_delay = CreateConVar(
        "sm_umc_rtv_initialdelay",
        "30",
        "Time (in seconds) before first RTV can be held.",
        0, true, 0.0
    );

    cvar_rtv_changetime = CreateConVar(
        "sm_umc_rtv_changetime",
        "0",
        "When to change the map after a successful RTV:\n 0 - Instant,\n 1 - Round End,\n 2 - Map End",
        0, true, 0.0, true, 2.0
    );

    cvar_rtv_needed = CreateConVar(
        "sm_umc_rtv_percent",
        "0.65",
        "Percentage of players required to trigger an RTV vote.",
        0, true, 0.0, true, 1.0
    );

    cvar_rtv_enable = CreateConVar(
        "sm_umc_rtv_enabled",
        "1",
        "Enables RTV.",
        0, true, 0.0, true, 1.0
    );

    cvar_rtv_type = CreateConVar(
        "sm_umc_rtv_type",
        "0",
        "Controls RTV vote type:\n 0 - Maps,\n 1 - Groups,\n 2 - Tiered Vote (vote for a group, then vote for a map from the group).",
        0, true, 0.0, true, 2.0
    );

    cvar_vote_time = CreateConVar(
        "sm_umc_rtv_duration",
        "20",
        "Specifies how long a vote should be available for.",
        0, true, 10.0
    );

    cvar_filename = CreateConVar(
        "sm_umc_rtv_cyclefile",
        "umc_mapcycle.txt",
        "File to use for Ultimate Mapchooser's map rotation."
    );

    cvar_rtv_mem = CreateConVar(
        "sm_umc_rtv_mapexclude",
        "4",
        "Specifies how many past maps to exclude from RTVs. 1 = Current Map Only",
        0, true, 0.0
    );

    cvar_scramble = CreateConVar(
        "sm_umc_rtv_menuscrambled",
        "0",
        "Specifies whether vote menu items are displayed in a random order.",
        0, true, 0.0, true, 1.0
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-rockthevote");
    
    //Register the rtv command, hooks "!rtv" and "/rtv" in chat.
    RegConsoleCmd("sm_rtv", Command_RTV);
    RegConsoleCmd("sm_rockthevote", Command_RTV);
    
    //Make listeners for player chat. Needed to recognize chat commands ("rtv", etc.)
    AddCommandListener(OnPlayerChat, "say");
    AddCommandListener(OnPlayerChat, "say2"); //Insurgency Only
    AddCommandListener(OnPlayerChat, "say_team");

    //Hook all necessary cvar changes
    HookConVarChange(cvar_rtv_mem,    Handle_RTVMemoryChange);
    HookConVarChange(cvar_rtv_enable, Handle_RTVChange);
    HookConVarChange(cvar_rtv_needed, Handle_ThresholdChange);
    
    //Initialize our memory arrays
    new numCells = ByteCountToCells(MAP_LENGTH);
    vote_mem_arr    = CreateArray(numCells);
    vote_catmem_arr = CreateArray(numCells);
    
    //Initialize rtv array
    rtv_clients = CreateArray();
    
    //Load the translations file
    LoadTranslations("ultimate-mapchooser.phrases");
}

//************************************************************************************************//
//                                           GAME EVENTS                                          //
//************************************************************************************************//
//Called after all config files were executed.
public OnConfigsExecuted()
{
    //We have not completed an RTV.
    rtv_completed = false;
    rtv_enabled = false;
    rtv_inprogress = false;
    
    //UMC hasn't done any votes.
    vote_completed = false;
    
    //Set the amount of time required before players are able to RTV.
    rtv_delaystart = GetConVarFloat(cvar_rtv_delay);
    
    new bool:reloaded = ReloadMapcycle();
    
    //Setup RTV if the RTV cvar is enabled.
    if (reloaded && GetConVarBool(cvar_rtv_enable))
    {
        rtv_enabled = true;
    
        //Set RTV threshold.
        UpdateRTVThreshold();
        
        //Make timer to activate RTV (player's cannot RTV before this timer finishes).
        MakeRTVTimer();
    }
    
    //Grab the name of the current map.
    decl String:mapName[MAP_LENGTH];
    GetCurrentMap(mapName, sizeof(mapName));
    
    decl String:groupName[MAP_LENGTH];
    UMC_GetCurrentMapGroup(groupName, sizeof(groupName));
    
    if (reloaded && StrEqual(groupName, INVALID_GROUP, false))
    {
        KvFindGroupOfMap(umc_mapcycle, mapName, groupName, sizeof(groupName));
    }
    
    //Add the map to all the memory queues.
    new mapmem = GetConVarInt(cvar_rtv_mem);
    new catmem = GetConVarInt(cvar_rtv_catmem);
    AddToMemoryArray(mapName, vote_mem_arr, mapmem);
    AddToMemoryArray(groupName, vote_catmem_arr, (mapmem > catmem) ? mapmem : catmem);
    
    if (reloaded)
    {
        RemovePreviousMapsFromCycle();
    }
}

public OnMapStart()
{
    //Setup vote sounds.
    SetupVoteSounds();
}

//Called when a client enters the server. Required for updating the RTV threshold.
public OnClientPutInServer(client)
{
    //Update the RTV threshold if RTV is enabled.
    if (GetConVarBool(cvar_rtv_enable))
    {
        UpdateRTVThreshold();
    }
}

//Called when a player types in chat. Required to handle user commands.
public Action:OnPlayerChat(client, const String:command[], argc)
{
    //Return immediately if nothing was typed.
    if (argc == 0) 
    {
        return Plugin_Continue;
    }
    
    //Get what was typed.
    decl String:text[13];
    GetCmdArg(1, text, sizeof(text));
    
    // Handle RTV client-command if RTV is enabled AND the client typed a valid RTV command AND
    // the required number of clients for RTV hasn't been reached already AND the client isn't the console.
    if (StrEqual(text, "rtv", false) || StrEqual(text, "rockthevote", false))
    {
        AttemptRTV(client);
    }
    return Plugin_Continue;
}

//Called after a client has left the server. Required for updating the RTV threshold.
public OnClientDisconnect_Post(client)
{
    //Remove this client from people who have seen the extended RTV message.
    rtv_message[client] = false;
    
    new index;
    //Remove the client from the RTV array if the client is in the array to begin with.
    while ((index = FindValueInArray(rtv_clients, client)) != -1)
    {
        RemoveFromArray(rtv_clients, index);
    }
    
    //Recalculate the RTV threshold.
    UpdateRTVThreshold();
    
    //Start RTV if we haven't had an RTV already AND the new amount of players on the server as passed the required threshold.
    if (!rtv_completed && GetArraySize(rtv_clients) >= rtv_threshold)
    {
        PrintToChatAll("[UMC] %t", "Player Disconnect RTV");
        StartRTV();
    }
}

//Called at the end of a map.
public OnMapEnd()
{
    //Empty array of clients who have entered RTV.
    ClearArray(rtv_clients);
}

//************************************************************************************************//
//                                            COMMANDS                                            //
//************************************************************************************************//
//sm_rtv or sm_rockthevote
public Action:Command_RTV(client, args)
{
    AttemptRTV(client);
    return Plugin_Handled;
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
    GetConVarString(cvar_rtv_startsound, vote_start_sound, sizeof(vote_start_sound));
    GetConVarString(cvar_rtv_endsound, vote_end_sound, sizeof(vote_end_sound));
    GetConVarString(cvar_runoff_sound, runoff_sound, sizeof(runoff_sound));
    
    //Gotta cache 'em all!
    CacheSound(vote_start_sound);
    CacheSound(vote_end_sound);
    CacheSound(runoff_sound);
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
    FilterMapcycleFromArrays(map_kv, vote_mem_arr, vote_catmem_arr, GetConVarInt(cvar_rtv_catmem));
}

//************************************************************************************************//
//                                          CVAR CHANGES                                          //
//************************************************************************************************//
//Called when the cvar to enable RTVs has been changed.
public Handle_RTVChange(Handle:convar, const String:oldVal[], const String:newVal[])
{
    //If the new value is 0, we ignore the change until next map.
    //Update (in this case set) the RTV threshold if the new value of the changed cvar is 1.
    if (StringToInt(newVal) == 1)
    {
        UpdateRTVThreshold();
    }
}

//Called when the number of excluded previous maps from RTVs has changed.
public Handle_RTVMemoryChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
    //Trim the memory array for RTVs.
    //We pass 1 extra to the argument in order to account for the current map, which should always be excluded.
    TrimArray(vote_mem_arr, StringToInt(newValue));
}

//Called when the cvar specifying the required RTV threshold percentage has changed.
public Handle_ThresholdChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
    //Recalculate the required threshold.
    UpdateRTVThreshold();
    
    //Start an RTV if the amount of clients who have RTVd is greater than the new RTV threshold.
    if (GetArraySize(rtv_clients) >= rtv_threshold)
    {
        StartRTV();
    }
}

//************************************************************************************************//
//                                          ROCK THE VOTE                                         //
//************************************************************************************************//
//Tries to enter the given client into RTV.
AttemptRTV(client)
{
    //Get the number of clients who have RTV'd.
    new size = GetArraySize(rtv_clients);

    if (!rtv_enabled || !GetConVarBool(cvar_rtv_enable) || size >= rtv_threshold || client == 0)
    {
        return;
    }
    
    decl String:flags[64];
    GetConVarString(cvar_enterflags, flags, sizeof(flags));
    
    if (!ClientHasAdminFlags(client, flags))
    {
        PrintToChat(client, "[UMC] %t","No RTV Admin");
        return;
    }
        
    new clients = GetRealClientCount();
    new minPlayers = GetConVarInt(cvar_rtv_minplayers);

    //Print a message if an RTV has already been completed OR a vote has already been completed and RTVs after votes aren't allowed.
    if (rtv_completed || (vote_completed && GetConVarInt(cvar_rtv_postaction) == 1))
    {
        PrintToChat(client, "[UMC] %t", "No RTV Nextmap");
        return;
    }
    //Otherwise, print a message if the number of players on the server is less than the minimum required to RTV.
    else if (clients < minPlayers)
    {
        PrintToChat(client, "[UMC] %t", "No RTV Player Count", minPlayers - clients);
        return;
    }
    //Otherwise, print a message if it is too early to RTV.
    else if (rtv_delaystart > 0)
    {
        PrintToChat(client, "[UMC] %t", "No RTV Time", rtv_delaystart);
        return;
    }
    //Otherwise, accept RTV command if the client hasn't already RTV'd.
    else if (FindValueInArray(rtv_clients, client) == -1)
    {
        //Get the flags for bonus RTV entrance points
        GetConVarString(cvar_enterbonusflags, flags, sizeof(flags));
        
        //Calc the amount of entrance points for this user
        new amt = strlen(flags) > 0 && ClientHasAdminFlags(client, flags) ? GetConVarInt(cvar_enterbonusamt) : 1;

        //Apply entrance points
        size += amt;
        while (amt-- > 0)
        {
            //Add client to RTV array.
            PushArrayCell(rtv_clients, client);
        }
        
        //Get the name of the client.
        decl String:name[MAX_NAME_LENGTH];
        GetClientName(client, name, sizeof(name));
        
        //Display an RTV message to a client for each client on the server.
        for (new i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i))
            {
                //Display initial (long) RTV message if the client hasn't seen it yet.
                if (!rtv_message[i])
                {
                    //Remember that the client has now seen this message.
                    rtv_message[i] = true;
                    PrintToChat(
                        i, 
                        "[UMC] %t %t (%t)",
                        "RTV Entered",
                            name,
                        "RTV Info Msg",
                        "More Required",
                            rtv_threshold - size
                    );
                }
                else //Otherwise, print the standard message.
                {
                    PrintToChat(
                        i,
                        "[UMC] %t (%t)",
                        "RTV Entered",
                            name,
                        "More Required",
                            rtv_threshold - size
                    );
                }
            }
        }
        
        //Start RTV if the new size has surpassed the threshold required to RTV.
        if (size >= rtv_threshold)
        {
            //Start the vote if there isn't one happening already.
            if (UMC_IsNewVoteAllowed("core"))
            {
                PrintToChatAll("[UMC] %t", "RTV Start");
                StartRTV();
            }
            else //Otherwise, display a message.
            {
                PrintToChat(client, "[UMC] %t", "Vote In Progress");
                MakeRetryVoteTimer(StartRTV);
            }
        }
    }
    //Otherwise, display a message to the client if the client has already RTV'd.
    else if (FindValueInArray(rtv_clients, client) != -1)
    {
        PrintToChat(
            client,
            "[UMC] %t (%t)",
            "RTV Already Entered",
            "More Required",
                rtv_threshold - size
        );
    }
}

//Creates the RTV timer. While this timer is active, players are not able to RTV.
MakeRTVTimer()
{
    //We are re-enabling RTV at this point.
    rtv_completed = false;
    
    if (rtv_delaystart > 0)
    {
        //Log a message
        LogUMCMessage("RTV will be made available in %.f seconds.", rtv_delaystart);
        
        //Create timer that lasts every second.
        CreateTimer(1.0, Handle_RTVTimer, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    }
    else
    {
        //rtv_enabled = true;
        LogUMCMessage("RTV is now available.");
    }
}

//Callback for the RTV timer, is called every second the timer is running.
public Action:Handle_RTVTimer(Handle:timer)
{
    //Continue ticking if there is still time left on the counter.
    if (--rtv_delaystart >= 0.0)
    {
        return Plugin_Continue;
    }
    
    LogUMCMessage("RTV is now available.");
    return Plugin_Stop;
}

//Recalculated the RTV threshold based off of the given playercount.
UpdateRTVThreshold()
{
    decl String:flags[64];
    GetConVarString(cvar_voteflags, flags, sizeof(flags));
    new count = GetClientWithFlagsCount(flags);
    rtv_threshold = (count > 1) ? RoundToCeil(float(count) * GetConVarFloat(cvar_rtv_needed)) : 1;
}

//Starts an RTV.
public StartRTV()
{
    LogUMCMessage("Starting RTV.");
    
    //Clear the array of clients who have entered RTV.
    ClearArray(rtv_clients);
    rtv_completed = true;
    new postAction = GetConVarInt(cvar_rtv_postaction);
    
    //Change the map immediately if there has already been an end-of-map vote AND
    //the cvar that handles RTV actions after end-of-map votes specifies to change the map.
    if (vote_completed && postAction == 0)
    {
        //Get the next map set by the vote.
        decl String:temp[MAP_LENGTH];
        GetNextMap(temp, sizeof(temp));
        
        LogUMCMessage("End of map vote has already been completed, changing map.");
        
        //Change to it.
        ForceChangeInFive(temp, "RTV");
    }
    //Otherwise, build the RTV vote if a vote hasn't already been completed.
    else if (!vote_completed || postAction == 2)
    {
        //Do nothing if there is a vote already in progress.
        if (!UMC_IsNewVoteAllowed("core")) 
        {
            LogUMCMessage("There is a vote already in progress, cannot start a new vote.");
            MakeRetryVoteTimer(StartRTV);
            return;
        }
        
        rtv_inprogress = true;
        decl String:flags[64];
        GetConVarString(cvar_voteflags, flags, sizeof(flags));
        
        new clients[MAXPLAYERS+1];
        new numClients;
        GetClientsWithFlags(flags, clients, sizeof(clients), numClients);
        
        //Start the UMC vote.
        new bool:result = UMC_StartVote(
            "core",
            map_kv,                                                     //Mapcycle
            umc_mapcycle,                                               //Complete Mapcycle
            UMC_VoteType:GetConVarInt(cvar_rtv_type),                   //Vote Type (map, group, tiered)
            GetConVarInt(cvar_vote_time),                               //Vote duration
            GetConVarBool(cvar_scramble),                               //Scramble
            vote_start_sound,                                           //Start Sound
            vote_end_sound,                                             //End Sound
            false,                                                      //Extend option
            0.0,                                                        //How long to extend the timelimit by,
            0,                                                          //How much to extend the roundlimit by,
            0,                                                          //How much to extend the fraglimit by,
            GetConVarBool(cvar_rtv_dontchange),                         //Don't Change option
            GetConVarFloat(cvar_vote_threshold),                        //Threshold
            UMC_ChangeMapTime:GetConVarInt(cvar_rtv_changetime),        //Success Action (when to change the map)
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
        
        if (!result)
        {
            LogUMCMessage("Could not start UMC vote.");
        }
    }
}

//************************************************************************************************//
//                                   ULTIMATE MAPCHOOSER EVENTS                                   //
//************************************************************************************************//
//Called when a vote fails, either due to Don't Change or no votes.
public UMC_OnVoteFailed()
{
    if (rtv_inprogress)
    {
        rtv_inprogress = false;
        vote_completed = false;
        rtv_delaystart = GetConVarFloat(cvar_rtv_interval);
        MakeRTVTimer();
    }
}

//Called when UMC has set a next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    vote_completed = true;
    rtv_inprogress = false;
}

//Called when UMC requests that the mapcycle should be reloaded.
public UMC_RequestReloadMapcycle()
{
    if (!ReloadMapcycle())
    {
        rtv_enabled = false;
    }
    else
    {
        RemovePreviousMapsFromCycle();
    }
}

//Called when UMC requests that the mapcycle is printed to the console.
public UMC_DisplayMapCycle(client, bool:filtered)
{
    PrintToConsole(client, "Module: Rock The Vote");
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
