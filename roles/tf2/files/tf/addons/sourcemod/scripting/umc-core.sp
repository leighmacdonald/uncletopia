/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                                  Ultimate Mapchooser - Core                                   *
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

//Dependencies
#include <umc-core>
#include <umc_utils>
#include <sourcemod>
#include <sdktools_sound>
#include <emitsoundany>

//Some definitions
#define NOTHING_OPTION "?nothing?"
#define WEIGHT_KEY "___calculated-weight"

//Plugin Information
public Plugin:myinfo =
{
    name        = "[UMC] Ultimate Mapchooser Core",
    author      = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Core component for [UMC]",
    version     = PL_VERSION,
    url         = "http://forums.alliedmods.net/showthread.php?t=134190"
};

//************************************************************************************************//
//                                        GLOBAL VARIABLES                                        //
//************************************************************************************************//
////----CONVARS-----/////
new Handle:cvar_runoff_display      = INVALID_HANDLE;
new Handle:cvar_runoff_selective    = INVALID_HANDLE;        
new Handle:cvar_vote_tieramount     = INVALID_HANDLE;
new Handle:cvar_vote_tierdisplay    = INVALID_HANDLE;
new Handle:cvar_logging             = INVALID_HANDLE;
new Handle:cvar_extend_display      = INVALID_HANDLE;
new Handle:cvar_dontchange_display  = INVALID_HANDLE;
new Handle:cvar_valvemenu           = INVALID_HANDLE;
new Handle:cvar_version             = INVALID_HANDLE;
new Handle:cvar_count_sound         = INVALID_HANDLE;
new Handle:cvar_extend_command      = INVALID_HANDLE;
new Handle:cvar_default_vm          = INVALID_HANDLE;
new Handle:cvar_block_slots         = INVALID_HANDLE;
new Handle:cvar_novote              = INVALID_HANDLE;
new Handle:cvar_nommsg_disp         = INVALID_HANDLE;
new Handle:cvar_mapnom_display      = INVALID_HANDLE;

//Stores the current category.
new String:current_cat[MAP_LENGTH];

//Stores the category of the next map.
new String:next_cat[MAP_LENGTH];

//Array of nomination tries.
new Handle:nominations_arr = INVALID_HANDLE;

//Forward for when a nomination is removed.
new Handle:nomination_reset_forward = INVALID_HANDLE;

//Sound used during countdown to map vote
new String:countdown_sound[PLATFORM_MAX_PATH];

/* Reweight System */
new Handle:reweight_forward = INVALID_HANDLE;
new Handle:reweight_group_forward = INVALID_HANDLE;
new bool:reweight_active = false;
new Float:current_weight;

/* Exclusion System */
new Handle:exclude_forward = INVALID_HANDLE;

/* Reload System */
new Handle:reload_forward = INVALID_HANDLE;

/* Extend System */
new Handle:extend_forward = INVALID_HANDLE;

/* Nextmap System */
new Handle:nextmap_forward = INVALID_HANDLE;

/* Failure System */
new Handle:failure_forward = INVALID_HANDLE;

/* Vote Notification System */
new Handle:vote_start_forward = INVALID_HANDLE;
new Handle:vote_end_forward = INVALID_HANDLE;
new Handle:client_voted_forward = INVALID_HANDLE;

/* Vote Management System */
new Handle:vote_managers = INVALID_HANDLE;
new Handle:vote_manager_ids = INVALID_HANDLE;

/* Maplist Display */
new Handle:maplistdisplay_forward = INVALID_HANDLE;

/* Template System */
new Handle:template_forward = INVALID_HANDLE;

//Flags
new bool:change_map_round; //Change map when the round ends?

//Misc ConVars
new Handle:cvar_maxrounds = INVALID_HANDLE;
new Handle:cvar_fraglimit = INVALID_HANDLE;
new Handle:cvar_winlimit  = INVALID_HANDLE;
new Handle:cvar_nextlevel = INVALID_HANDLE;  //GE:S
new Handle:cvar_zpsmaxrnds = INVALID_HANDLE; // ZPS Survival
new Handle:cvar_zpomaxrnds = INVALID_HANDLE; // ZPS Objective

//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//
//Called before the plugin loads, sets up our natives.
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    CreateNative("UMC_AddWeightModifier", Native_UMCAddWeightModifier);
    CreateNative("UMC_StartVote", Native_UMCStartVote);
    CreateNative("UMC_GetCurrentMapGroup", Native_UMCGetCurrentGroup);
    CreateNative("UMC_GetRandomMap", Native_UMCGetRandomMap);
    CreateNative("UMC_SetNextMap", Native_UMCSetNextMap);
    CreateNative("UMC_IsMapNominated", Native_UMCIsMapNominated);
    CreateNative("UMC_NominateMap", Native_UMCNominateMap);
    CreateNative("UMC_CreateValidMapArray", Native_UMCCreateMapArray);
    CreateNative("UMC_CreateValidMapGroupArray", Native_UMCCreateGroupArray);
    CreateNative("UMC_IsMapValid", Native_UMCIsMapValid);
    CreateNative("UMC_FilterMapcycle", Native_UMCFilterMapcycle);
    CreateNative("UMC_IsVoteInProgress", Native_UMCIsVoteInProgress);
    CreateNative("UMC_StopVote", Native_UMCStopVote);
    CreateNative("UMC_RegisterVoteManager", Native_UMCRegVoteManager);
    CreateNative("UMC_UnregisterVoteManager", Native_UMCUnregVoteManager);
    CreateNative("UMC_VoteManagerVoteCompleted", Native_UMCVoteManagerComplete);
    CreateNative("UMC_VoteManagerVoteCancelled", Native_UMCVoteManagerCancel);
    CreateNative("UMC_VoteManagerClientVoted", Native_UMCVoteManagerVoted);
    CreateNative("UMC_FormatDisplayString", Native_UMCFormatDisplay);
    CreateNative("UMC_IsNewVoteAllowed", Native_UMCIsNewVoteAllowed);
    
    RegPluginLibrary("umccore");
    
    return APLRes_Success;
}

//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_nommsg_disp = CreateConVar(
        "sm_umc_nommsg_display",
        "^",
        "String to replace the {NOMINATED} map display-template string with."
    );

    cvar_novote = CreateConVar(
        "sm_umc_votemanager_core_novote",
        "0",
        "Enable No Vote option at the top of vote menus. Requires SourceMod >= 1.4",
        0, true, 0.0, true, 1.0
    );

    cvar_block_slots = CreateConVar(
        "sm_umc_votemanager_core_blockslots",
        "0",
        "Specifies how many slots in a vote are disabled to prevent accidental voting.",
        0, true, 0.0, true, 5.0
    );

    cvar_default_vm = CreateConVar(
        "sm_umc_votemanager_default",
        "core",
        "Specifies the default UMC Vote Manager to be used for voting. The default value of \"core\" means that Sourcemod's built-in voting will be used."
    );

    cvar_extend_command = CreateConVar(
        "sm_umc_extend_command",
        "",
        "Specifies a server command to be executed when the map is extended by UMC."
    );

    cvar_count_sound = CreateConVar(
        "sm_umc_countdown_sound",
        "",
        "Specifies a sound to be played each second during the countdown time between runoff and tiered votes. (Sound will be precached and added to the download table.)"
    );
    
    cvar_valvemenu = CreateConVar(
        "sm_umc_votemanager_core_menu_esc",
        "0",
        "If enabled, votes will use Valve-Stlye menus (players will be required to press ESC in order to vote). NOTE: this may not work in TF2!",
        0, true, 0.0, true, 1.0
    );

    cvar_extend_display = CreateConVar(
        "sm_umc_extend_display",
        "0",
        "Determines where in votes the \"Extend Map\" option will be displayed.\n 0 - Bottom,\n 1 - Top",
        0, true, 0.0, true, 1.0
    );
    
    cvar_dontchange_display = CreateConVar(
        "sm_umc_dontchange_display",
        "0",
        "Determines where in votes the \"Don't Change\" option will be displayed.\n 0 - Bottom,\n 1 - Top",
        0, true, 0.0, true, 1.0
    );
    
    cvar_mapnom_display = CreateConVar(
        "sm_umc_mapnom_display",
        "0",
        "Determines where in votes the nominated maps will be displayed.\n 0 - Bottom,\n 1 - Top",
        0, true, 0.0, true, 1.0
    );
    
    cvar_logging = CreateConVar(
        "sm_umc_logging_verbose",
        "1",
        "Enables in-depth logging. Use this to have the plugin log how votes are being populated.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_selective = CreateConVar(
        "sm_umc_runoff_selective",
        "0",
        "Specifies whether runoff votes are only displayed to players whose votes were eliminated in the runoff and players who did not vote.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_tieramount = CreateConVar(
        "sm_umc_vote_tieramount",
        "6",
        "Specifies the maximum number of maps to appear in the second part of a tiered vote.",
        0, true, 2.0
    );
    
    cvar_runoff_display = CreateConVar(
        "sm_umc_runoff_display",
        "C",
        "Determines where the Runoff Vote Message is displayed on the screen.\n C - Center Message\n S - Chat Message\n T - Top Message\n H - Hint Message"
    );
    
    cvar_vote_tierdisplay = CreateConVar(
        "sm_umc_vote_tierdisplay",
        "C",
        "Determines where the Tiered Vote Message is displayed on the screen.\n C - Center Message\n S - Chat Message\n T - Top Message\n H - Hint Message"
    );

    //Version
    cvar_version = CreateConVar(
        "improved_map_randomizer_version", PL_VERSION, "Ultimate Mapchooser's version",
        FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "ultimate-mapchooser");

    // Admin commands 
    RegAdminCmd("sm_setnextmap", Command_SetNextmap, ADMFLAG_CHANGEMAP, "sm_setnextmap <map>");
    RegAdminCmd("sm_umc_reload_mapcycles", Command_Reload, ADMFLAG_RCON, "Reloads the mapcycle file.");
    RegAdminCmd("sm_umc_stopvote", Command_StopVote, ADMFLAG_CHANGEMAP, "Stops all UMC votes that are in progress.");
    RegAdminCmd("sm_umc_maphistory", Command_MapHistory, ADMFLAG_CHANGEMAP, "Shows the most recent maps played");
    RegAdminCmd("sm_umc_displaymaplists", Command_DisplayMapLists, ADMFLAG_CHANGEMAP, "Displays the current maplist for all UMC modules.");

    //Hook round end events
    HookEvent("round_end",            Event_RoundEnd); //Generic
    HookEventEx("game_round_end",     Event_RoundEnd); //Hidden: Source, Neotokyo
    HookEventEx("teamplay_win_panel", Event_RoundEnd); //TF2
    HookEventEx("arena_win_panel",    Event_RoundEnd); //TF2
    HookEventEx("round_win",          Event_RoundEnd); //Nuclear Dawn
    HookEventEx("game_end",           Event_RoundEnd); //EmpiresMod
    HookEventEx("game_round_restart", Event_RoundEnd); //ZPS

    //Initialize our vote arrays
    nominations_arr = CreateArray();

    //Make listeners for player chat. Needed to recognize chat commands ("rtv", etc.)
    AddCommandListener(OnPlayerChat, "say");
    AddCommandListener(OnPlayerChat, "say2"); //Insurgency Only
    AddCommandListener(OnPlayerChat, "say_team");

    //Fetch Cvars
    cvar_maxrounds = FindConVar("mp_maxrounds");
    cvar_fraglimit = FindConVar("mp_fraglimit");
    cvar_winlimit  = FindConVar("mp_winlimit");
    cvar_zpsmaxrnds = FindConVar("zps_survival_rounds"); // ZPS only!
    cvar_zpomaxrnds = FindConVar("zps_objective_rounds"); // ZPS only!

    //GE:S Fix
    new String:game[20];
    GetGameFolderName(game, sizeof(game));
    if (StrEqual(game, "gesource", false))
    {    
        cvar_nextlevel = FindConVar("nextlevel");
    }

    //Load the translations file
    LoadTranslations("ultimate-mapchooser.phrases");

    //Setup our forward for when a nomination is removed
    nomination_reset_forward    = CreateGlobalForward("OnNominationRemoved", ET_Ignore, Param_String, Param_Cell);
    reweight_forward            = CreateGlobalForward("UMC_OnReweightMap", ET_Ignore, Param_Cell, Param_String, Param_String);
    reweight_group_forward      = CreateGlobalForward("UMC_OnReweightGroup", ET_Ignore, Param_Cell, Param_String);
    exclude_forward             = CreateGlobalForward("UMC_OnDetermineMapExclude", ET_Hook, Param_Cell, Param_String, Param_String, Param_Cell, Param_Cell);
    reload_forward              = CreateGlobalForward("UMC_RequestReloadMapcycle", ET_Ignore);
    extend_forward              = CreateGlobalForward("UMC_OnMapExtended", ET_Ignore);
    nextmap_forward             = CreateGlobalForward("UMC_OnNextmapSet", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);
    failure_forward             = CreateGlobalForward("UMC_OnVoteFailed", ET_Ignore);
    maplistdisplay_forward      = CreateGlobalForward("UMC_DisplayMapCycle", ET_Ignore, Param_Cell, Param_Cell);
    vote_start_forward          = CreateGlobalForward("UMC_VoteStarted", ET_Ignore, Param_String, Param_Array, Param_Cell, Param_Cell);
    vote_end_forward            = CreateGlobalForward("UMC_VoteEnded", ET_Ignore, Param_String, Param_Cell);
    client_voted_forward        = CreateGlobalForward("UMC_ClientVoted", ET_Ignore, Param_String, Param_Cell, Param_Cell);
    template_forward            = CreateGlobalForward("UMC_OnFormatTemplateString", ET_Ignore, Param_String, Param_Cell, Param_Cell, Param_String, Param_String);

    vote_managers = CreateTrie();
    vote_manager_ids = CreateArray(ByteCountToCells(64));

    UMC_RegisterVoteManager("core", VM_MapVote, VM_GroupVote, VM_CancelVote, VM_IsVoteInProgress);
}

//************************************************************************************************//
//                                           GAME EVENTS                                          //
//************************************************************************************************//
//Called before any configs are executed.
public OnMapStart()
{
    decl String:map[MAP_LENGTH];
    GetCurrentMap(map, sizeof(map));

    LogUMCMessage("---------------------MAP CHANGE: %s---------------------", map);

    //Update the current category.
    strcopy(current_cat, sizeof(current_cat), next_cat);
    strcopy(next_cat, sizeof(next_cat), INVALID_GROUP);

    CreateTimer(5.0, UpdateTrackingCvar);

    CacheSound(countdown_sound);
}

public Action:UpdateTrackingCvar(Handle:timer)
{
    SetConVarString(cvar_version, PL_VERSION, false, false);
}

//Called after all config files were executed.
public OnConfigsExecuted()
{
    reweight_active = false;
    change_map_round = false;
    GetConVarString(cvar_count_sound, countdown_sound, sizeof(countdown_sound));
}

//Called when a player types in chat required to handle user commands.
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
    
    if (StrEqual(text, "umc", false) || StrEqual(text, "!umc", false) || StrEqual(text, "/umc", false))
    {
        PrintToChat(client,"[SM] Ultimate Mapchooser (UMC) Plugin v%s ", PL_VERSION);
    }
    return Plugin_Continue;
}

//Called when a client has left the server. Needed to update nominations.
public OnClientDisconnect(client)
{
    //Find this client in the array of clients who have entered RTV.
    new index = FindClientNomination(client);
    
    //Remove the client from the nomination pool if the client is in the pool to begin with.
    if (index != -1)
    {
        new Handle:nomination = GetArrayCell(nominations_arr, index);
        decl String:oldMap[MAP_LENGTH];
        GetTrieString(nomination, MAP_TRIE_MAP_KEY, oldMap, sizeof(oldMap));
        new owner;
        GetTrieValue(nomination, "client", owner);
        Call_StartForward(nomination_reset_forward);
        Call_PushString(oldMap);
        Call_PushCell(owner);
        Call_Finish();

        // Nomination KV, local scope
        new Handle:nomKV;
        GetTrieValue(nomination, "mapcycle", nomKV);
        CloseHandle(nomKV);
        CloseHandle(nomination);
        RemoveFromArray(nominations_arr, index);
    }
}

// Called when a round ends.
public Event_RoundEnd(Handle:evnt, const String:name[], bool:dontBroadcast)
{
    if (change_map_round)
    {
        change_map_round = false;
        decl String:map[MAP_LENGTH];
        GetNextMap(map, sizeof(map));
        ForceChangeInFive(map, "CORE");
    }
}

//Called at the end of a map.
public OnMapEnd()
{
    //Empty array of nominations (and close all handles).
    ClearNominations();
    
    //End all votes currently in progress.
    new size = GetArraySize(vote_manager_ids);
    new Handle:vM;
    new bool:inProgress;
    decl String:id[64];
    for (new i = 0; i < size; i++)
    {
        GetArrayString(vote_manager_ids, i, id, sizeof(id));
        GetTrieValue(vote_managers, id, vM);
        GetTrieValue(vM, "in_progress", inProgress);
        if (inProgress)
        {
            VoteCancelled(vM);
        }
    }
}

//************************************************************************************************//
//                                             NATIVES                                            //
//************************************************************************************************//
public Native_UMCIsNewVoteAllowed(Handle:plugin, numParams)
{
    //Retrieve the vote manager.
    new len;
    GetNativeStringLength(1, len);
    new String:voteManagerID[len+1];
    if (len > 0)
    {
        GetNativeString(1, voteManagerID, len+1);
    }
    
    if (strlen(voteManagerID) == 0)
    {
        GetConVarString(cvar_default_vm, voteManagerID, len+1);
    }
    
    new Handle:voteManager = INVALID_HANDLE;
    if (!GetTrieValue(vote_managers, voteManagerID, voteManager))
    {
        if (StrEqual(voteManagerID, "core"))
        {
            LogError("FATAL: Could not find core vote manager. Aborting vote.");
            return _:false;
        }
        LogError("Could not find a vote manager matching ID \"%s\". Using \"core\" instead.");
        if (!GetTrieValue(vote_managers, "core", voteManager))
        {
            LogError("FATAL: Could not find core vote manager. Aborting vote.");
            return _:false;
        }
        strcopy(voteManagerID, len+1, "core");
    }
    
    new bool:vote_inprogress;
    GetTrieValue(voteManager, "in_progress", vote_inprogress);
    
    if (vote_inprogress)
    {
        return _:false;
    }
    
    return _:!IsVMVoteInProgress(voteManager);
}

public Native_UMCFormatDisplay(Handle:plugin, numParams)
{
    new maxlen = GetNativeCell(2);
    new Handle:kv = CreateKeyValues("umc_mapcycle");
    KvCopySubkeys(Handle:GetNativeCell(3), kv);
    
    new len;
    GetNativeStringLength(4, len);
    new String:map[len+1];
    if (len > 0)
    {
        GetNativeString(4, map, len+1);
    }
    
    GetNativeStringLength(5, len);
    new String:group[len+1];
    
    if (len > 0)
    {
        GetNativeString(5, group, len+1);
    }
    
    decl String:display[MAP_LENGTH], String:gDisp[MAP_LENGTH];
    KvJumpToKey(kv, group);
    KvGetString(kv, "display-template", gDisp, sizeof(gDisp), "{MAP}");
    KvGoBack(kv);
    
    GetMapDisplayString(kv, group, map, gDisp, display, sizeof(display));
    CloseHandle(kv);
    
    SetNativeString(1, display, maxlen);
}

public Native_UMCVoteManagerVoted(Handle:plugin, numParams)
{
    new len;
    GetNativeStringLength(1, len);
    new String:id[len+1];
    if (len > 0)
    {
        GetNativeString(1, id, len+1);
    }
    new client = GetNativeCell(2);

    new Handle:option = Handle:GetNativeCell(3);

    Call_StartForward(client_voted_forward);
    Call_PushString(id);
    Call_PushCell(client);
    Call_PushCell(option);
    Call_Finish();
}

public Native_UMCFilterMapcycle(Handle:plugin, numParams)
{
    new Handle:kv = CreateKeyValues("umc_rotation");
    new Handle:arg = Handle:GetNativeCell(1);
    KvCopySubkeys(arg, kv);

    new Handle:mapcycle = Handle:GetNativeCell(2);

    new bool:isNom = bool:GetNativeCell(3);
    new bool:forMapChange = bool:GetNativeCell(4);

    FilterMapcycle(kv, mapcycle, isNom, forMapChange);

    return _:CloseAndClone(kv, plugin);
}

public Native_UMCVoteManagerCancel(Handle:plugin, numParams)
{
    new len;
    GetNativeStringLength(1, len);
    new String:id[len+1];
    if (len > 0)
    {
        GetNativeString(1, id, len+1);
    }    
    new Handle:voteManager;
    if (!GetTrieValue(vote_managers, id, voteManager))
    {
        ThrowNativeError(SP_ERROR_PARAM, "A Vote Manager with the ID \"%s\" does not exist!", id);
    }

    VoteCancelled(voteManager);
}

public Native_UMCRegVoteManager(Handle:plugin, numParams)
{
    new Handle:voteManager;

    new len;
    GetNativeStringLength(1, len);
    new String:id[len+1];
    if (len > 0)
    {
        GetNativeString(1, id, len+1);
    }    
    if (GetTrieValue(vote_managers, id, voteManager))
    {
        UMC_UnregisterVoteManager(id);
    }

    voteManager = CreateTrie();

    SetTrieValue(vote_managers, id, voteManager);

    // NOTE: In SM 1.7.3 and on, we cannot coerce functions to values.
    // Instead, we need to create callbacks to alleviate any potential issues.
    new Handle:mapCallback = CreateForward(ET_Single, Param_Cell, Param_Cell, Param_Array, Param_Cell, Param_String);
    AddToForward(mapCallback, plugin, GetNativeFunction(2));

    new Handle:groupCallback = CreateForward(ET_Single, Param_Cell, Param_Cell, Param_Array, Param_Cell, Param_String);
    AddToForward(groupCallback, plugin, GetNativeFunction(3));

    new Handle:cancelCallback = CreateForward(ET_Ignore);
    AddToForward(cancelCallback, plugin, GetNativeFunction(4));

    new Handle:progressCallback = CreateForward(ET_Single);
    new Function:progressFunction = GetNativeFunction(5);

    if (progressFunction != INVALID_FUNCTION)
    {
        AddToForward(progressCallback, plugin, progressFunction);
    }

    SetTrieValue(voteManager, "plugin", plugin);
    SetTrieValue(voteManager, "map", mapCallback);
    SetTrieValue(voteManager, "group", groupCallback);
    SetTrieValue(voteManager, "cancel", cancelCallback);
    SetTrieValue(voteManager, "checkprogress", progressCallback);
    SetTrieValue(voteManager, "vote_storage", CreateArray());
    SetTrieValue(voteManager, "in_progress", false);
    SetTrieValue(voteManager, "active", false);
    SetTrieValue(voteManager, "total_votes", 0);
    SetTrieValue(voteManager, "prev_vote_count", 0);
    SetTrieValue(voteManager, "map_vote", CreateArray());

    PushArrayString(vote_manager_ids, id);
}

public Native_UMCUnregVoteManager(Handle:plugin, numParams)
{
    new len;
    GetNativeStringLength(1, len);
    new String:id[len+1];
    if (len > 0)
    {
        GetNativeString(1, id, len+1);
    }
    new Handle:vM;

    if (!GetTrieValue(vote_managers, id, vM))
    {
        ThrowNativeError(SP_ERROR_PARAM, "A Vote Manager with the ID \"%s\" does not exist!", id);
    }

    if (UMC_IsVoteInProgress(id))
    {
        UMC_StopVote(id);
    }

    new Handle:hndl;
    GetTrieValue(vM, "vote_storage", hndl);
    CloseHandle(hndl);
    GetTrieValue(vM, "map_vote", hndl);
    CloseHandle(hndl);
    GetTrieValue(vM, "map", hndl);
    CloseHandle(hndl);
    GetTrieValue(vM, "group", hndl);
    CloseHandle(hndl);
    GetTrieValue(vM, "cancel", hndl);
    CloseHandle(hndl);
    GetTrieValue(vM, "checkprogress", hndl);
    CloseHandle(hndl);

    CloseHandle(vM);

    RemoveFromTrie(vote_managers, id);

    new index = FindStringInArray(vote_manager_ids, id);
    if (index != -1)
    {
        RemoveFromArray(vote_manager_ids, index);
    }

    if (StrEqual(id, "core", false))
    {
        UMC_RegisterVoteManager("core", VM_MapVote, VM_GroupVote, VM_CancelVote, VM_IsVoteInProgress);
    }
}

public Native_UMCVoteManagerComplete(Handle:plugin, numParams)
{
    new len;
    GetNativeStringLength(1, len);
    new String:id[len+1];
    if (len > 0)
    {
        GetNativeString(1, id, len+1);
    }
    new Handle:voteOptions = Handle:GetNativeCell(2);

    new Handle:vM;
    GetTrieValue(vote_managers, id, vM);

    new Handle:response = ProcessVoteResults(vM, voteOptions);

    new UMC_VoteResponseHandler:handler = UMC_VoteResponseHandler:GetNativeFunction(3);

    new UMC_VoteResponse:result;
    new String:param[MAP_LENGTH];
    GetTrieValue(response, "response", result);
    GetTrieString(response, "param", param, sizeof(param));

    Call_StartFunction(plugin, handler);
    Call_PushCell(result);
    Call_PushString(param);
    Call_Finish();

    Call_StartForward(vote_end_forward);
    Call_PushString(id);
    Call_PushCell(result);
    Call_Finish();

    CloseHandle(response);
}

//native Handle:UMC_CreateValidMapArray(Handle:kv, const String:group[], bool:isNom, bool:forMapChange);
public Native_UMCCreateMapArray(Handle:plugin, numParams)
{
    new Handle:kv = CreateKeyValues("umc_rotation");
    new Handle:arg = Handle:GetNativeCell(1);
    KvCopySubkeys(arg, kv);

    new Handle:mapcycle = Handle:GetNativeCell(2);

    new len;
    GetNativeStringLength(3, len);
    new String:group[len+1];
    if (len > 0)
    {
        GetNativeString(3, group, len+1);
    }
    new bool:isNom = bool:GetNativeCell(4);
    new bool:forMapChange = bool:GetNativeCell(5);

    new Handle:result = CreateMapArray(kv, mapcycle, group, isNom, forMapChange);

    CloseHandle(kv);

    if (result == INVALID_HANDLE)
    {
        ThrowNativeError(SP_ERROR_PARAM, "Could not generate valid map array from provided mapcycle.");
    }

    //Clone all of the handles in the array to prevent memory leaks.
    new Handle:cloned = CreateArray();

    new size = GetArraySize(result);
    new Handle:map;
    for (new i = 0; i < size; i++)
    {
        map = GetArrayCell(result, i);
        PushArrayCell(cloned, CloseAndClone(map, plugin));
    }

    CloseHandle(result);

    return _:CloseAndClone(cloned, plugin);
}

//Create an array of valid maps from the given mapcycle and group.
Handle:CreateMapArray(Handle:kv, Handle:mapcycle, const String:group[], bool:isNom, bool:forMapChange)
{
    if (kv == INVALID_HANDLE)
    {
        LogError("NATIVE: Cannot build map array, mapcycle is invalid.");
        return INVALID_HANDLE;
    }

    new bool:oneSection = false; 
    if (StrEqual(group, INVALID_GROUP))
    {
        if (!KvGotoFirstSubKey(kv))
        {
            LogError("NATIVE: Cannot build map array, mapcycle has no groups.");
            return INVALID_HANDLE;
        }
    }
    else
    {
        if (!KvJumpToKey(kv, group))
        {
            LogError("NATIVE: Cannot build map array, mapcycle has no group '%s'", group);
            return INVALID_HANDLE;
        }

        oneSection = true;
    }

    new Handle:result = CreateArray();
    decl String:mapName[MAP_LENGTH], String:groupName[MAP_LENGTH];
    do
    {
        KvGetSectionName(kv, groupName, sizeof(groupName));
        
        if (!KvGotoFirstSubKey(kv))
        {
            if (!oneSection)
            {
                continue;
            }
            else
            {
                break;
            }
        }

        do
        {
            if (IsValidMap(kv, mapcycle, groupName, isNom, forMapChange))
            {
                KvGetSectionName(kv, mapName, sizeof(mapName));
                PushArrayCell(result, CreateMapTrie(mapName, groupName));
            }
        }
        while (KvGotoNextKey(kv));

        KvGoBack(kv);

        if (oneSection) 
        {
            break;
        }
    }
    while (KvGotoNextKey(kv));

    KvGoBack(kv);

    return result;
}

//native Handle:UMC_CreateValidMapGroupArray(Handle:kv, bool:isNom, bool:forMapChange);
public Native_UMCCreateGroupArray(Handle:plugin, numParams)
{
    new Handle:arg = Handle:GetNativeCell(1);
    new Handle:kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(arg, kv);
    new Handle:mapcycle = Handle:GetNativeCell(2);
    new bool:isNom = bool:GetNativeCell(3);
    new bool:forMapChange = bool:GetNativeCell(4);
    
    new Handle:result = CreateMapGroupArray(kv, mapcycle, isNom, forMapChange);
    
    CloseHandle(kv);
    
    return _:CloseAndClone(result, plugin);
}

//Create an array of valid maps from the given mapcycle and group.
Handle:CreateMapGroupArray(Handle:kv, Handle:mapcycle, bool:isNom, bool:forMapChange)
{
    if (!KvGotoFirstSubKey(kv))
    {
        LogError("NATIVE: Cannot build map array, mapcycle has no groups.");
        return INVALID_HANDLE;
    }
    
    new Handle:result = CreateArray(ByteCountToCells(MAP_LENGTH));
    decl String:groupName[MAP_LENGTH];
    do
    {
        if (IsValidCat(kv, mapcycle, isNom, forMapChange))
        {
            KvGetSectionName(kv, groupName, sizeof(groupName));
            PushArrayString(result, groupName);
        }    
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
    
    return result;
}

//native bool:UMC_IsMapNominated(const String:map[], const String:group[]);
public Native_UMCIsMapNominated(Handle:plugin, numParams)
{
    new len;
    GetNativeStringLength(1, len);
    new String:map[len+1];
    if (len > 0)
    {
        GetNativeString(1, map, len+1);
    }    
    GetNativeStringLength(2, len);
    new String:group[len+1];
    if (len > 0)
    {
        GetNativeString(2, group, len+1);
    }
    return _:(FindNominationIndex(map, group) != -1);
}

//native bool:UMC_NominateMap(const String:map[], const String:group[]);
public Native_UMCNominateMap(Handle:plugin, numParams)
{
    new Handle:kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(Handle:GetNativeCell(1), kv);
    
    new len;
    GetNativeStringLength(2, len);
    new String:map[len+1];
    if (len > 0)
    {
        GetNativeString(2, map, len+1);
    }

    GetNativeStringLength(3, len);
    new String:group[len+1];
    
    if (len > 0)
    {
        GetNativeString(3, group, len+1);
    }

    new String:nomGroup[MAP_LENGTH];
    if (numParams > 4)
    {
        GetNativeStringLength(5, len);
        if (len > 0)
        {
            GetNativeString(5, nomGroup, sizeof(nomGroup));
        }
    }
    else
    {
        strcopy(nomGroup, sizeof(nomGroup), INVALID_GROUP);
    }

    return _:InternalNominateMap(kv, map, group, GetNativeCell(4), nomGroup);
}

//native AddWeightModifier(MapWeightModifier:func);
public Native_UMCAddWeightModifier(Handle:plugin, numParams)
{
    if (reweight_active)
    {
        current_weight *= Float:GetNativeCell(1);
    }
    else
    {
        LogError("REWEIGHT: Attempted to add weight modifier outside of UMC_OnReweightMap forward.");
    }
}

//native bool:UMC_StartVote( ...20+ params... );
public Native_UMCStartVote(Handle:plugin, numParams)
{
    //Retrieve the many, many parameters.
    new len;
    GetNativeStringLength(1, len);
    new String:voteManagerID[len+1];
    
    if (len > 0)
    {
        GetNativeString(1, voteManagerID, len+1);
    }    
    
    if (strlen(voteManagerID) == 0)
    {
        GetConVarString(cvar_default_vm, voteManagerID, len+1);
    }    
    new Handle:voteManager = INVALID_HANDLE;
    
    if (!GetTrieValue(vote_managers, voteManagerID, voteManager))
    {
        if (StrEqual(voteManagerID, "core"))
        {
            LogError("FATAL: Could not find core vote manager. Aborting vote.");
            return _:false;
        }
        
        LogError("Could not find a vote manager matching ID \"%s\". Using \"core\" instead.");
        if (!GetTrieValue(vote_managers, "core", voteManager))
        {
            LogError("FATAL: Could not find core vote manager. Aborting vote.");
            return _:false;
        }
        strcopy(voteManagerID, len+1, "core");
    }
    
    new bool:vote_inprogress;
    GetTrieValue(voteManager, "in_progress", vote_inprogress);
    
    if (vote_inprogress)
    {
        LogError("Cannot start a vote, vote manager \"%s\" already has a vote in progress.", voteManagerID);
        return _:false;
    }
    
    //Get the name of the calling plugin.
    decl String:stored_reason[PLATFORM_MAX_PATH];
    GetPluginFilename(plugin, stored_reason, sizeof(stored_reason));
    SetTrieString(voteManager, "stored_reason", stored_reason);
    new Handle:kv = Handle:GetNativeCell(2);
    new Handle:mapcycle = Handle:GetNativeCell(3);
    new UMC_VoteType:type = UMC_VoteType:GetNativeCell(4);
    new time = GetNativeCell(5);
    new bool:scramble = bool:GetNativeCell(6);
    
    GetNativeStringLength(7, len);
    new String:startSound[len+1];
    if (len > 0)
    {
        GetNativeString(7, startSound, len+1);
    }
    
    GetNativeStringLength(8, len);
    new String:endSound[len+1];
    if (len > 0)
    {
        GetNativeString(8, endSound, len+1);
    }
    
    new bool:extend = bool:GetNativeCell(9);
    new Float:timestep = Float:GetNativeCell(10);
    new roundstep = GetNativeCell(11);
    new fragstep = GetNativeCell(12);
    new bool:dontChange = bool:GetNativeCell(13);
    new Float:threshold = Float:GetNativeCell(14);
    new UMC_ChangeMapTime:successAction = UMC_ChangeMapTime:GetNativeCell(15);
    new UMC_VoteFailAction:failAction = UMC_VoteFailAction:GetNativeCell(16);
    new maxRunoffs = GetNativeCell(17);
    new maxRunoffMaps = GetNativeCell(18);
    new UMC_RunoffFailAction:runoffFailAction = UMC_RunoffFailAction:GetNativeCell(19);
    
    GetNativeStringLength(20, len);
    new String:runoffSound[len+1];
    if (len > 0)
    {
        GetNativeString(20, runoffSound, len+1);
    }
    
    new bool:nominationStrictness = bool:GetNativeCell(21);
    new bool:allowDuplicates = bool:GetNativeCell(22);
    
    new voteClients[MAXPLAYERS+1];
    GetNativeArray(23, voteClients, sizeof(voteClients));
    new numClients = GetNativeCell(24);
    
    new bool:runExclusionCheck = (numParams >= 25) ? (bool:GetNativeCell(25)) : true;
    
    //OK now that that's done, let's save 'em.
    SetTrieValue(voteManager, "stored_type", type);
    SetTrieValue(voteManager, "stored_scramble", scramble);
    SetTrieValue(voteManager, "stored_ignoredupes", allowDuplicates);
    SetTrieValue(voteManager, "stored_strictnoms", nominationStrictness);

    if (failAction == VoteFailAction_Nothing)
    {
        SetTrieValue(voteManager, "stored_fail_action", RunoffFailAction_Nothing);
        SetTrieValue(voteManager, "remaining_runoffs", 0);
    }
    else if (failAction == VoteFailAction_Runoff)
    {    
        SetTrieValue(voteManager, "stored_fail_action", runoffFailAction);
        SetTrieValue(voteManager, "remaining_runoffs", (maxRunoffs == 0) ? -1 : maxRunoffs);
    }
    else
    {
        // Do Nothing
    }
    
    SetTrieValue(voteManager, "extend_timestep", timestep);
    SetTrieValue(voteManager, "extend_roundstep", roundstep);
    SetTrieValue(voteManager, "extend_fragstep", fragstep);
    SetTrieValue(voteManager, "stored_threshold", threshold);
    SetTrieValue(voteManager, "stored_runoffmaps_max", maxRunoffMaps);
    SetTrieValue(voteManager, "stored_votetime", time);
    
    SetTrieValue(voteManager, "change_map_when", successAction);
    
    new Handle:stored_kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(kv, stored_kv);
    SetTrieValue(voteManager, "stored_kv", stored_kv);
    
    new Handle:stored_mapcycle = CreateKeyValues("umc_rotation");
    KvCopySubkeys(mapcycle, stored_mapcycle);
    SetTrieValue(voteManager, "stored_mapcycle", stored_mapcycle);
    
    SetTrieString(voteManager, "stored_start_sound", startSound);
    SetTrieString(voteManager, "stored_end_sound", endSound);
    SetTrieString(voteManager, "stored_runoff_sound", (strlen(runoffSound) > 0) ? runoffSound : startSound);
    
    new users[MAXPLAYERS+1];
    ConvertClientsToUserIDs(voteClients, users, numClients);
    SetTrieArray(voteManager, "stored_users", users, numClients);
    SetTrieValue(voteManager, "stored_exclude", runExclusionCheck);
    
    //Make the vote menu.
    new Handle:options = BuildVoteItems(voteManager, stored_kv, stored_mapcycle, type, scramble,
                                        allowDuplicates, nominationStrictness, runExclusionCheck,
                                        extend, dontChange);
    
    //Run the vote if the menu was created successfully.
    if (options != INVALID_HANDLE)
    {
        new bool:vote_active = PerformVote(voteManager, type, options, time, voteClients, numClients, startSound);
        if (vote_active)
        {
            Call_StartForward(vote_start_forward);
            Call_PushString(voteManagerID);
            Call_PushArray(voteClients, numClients);
            Call_PushCell(numClients);
            Call_PushCell(options);
            Call_Finish();
        }
        else
        {
            DeleteVoteParams(voteManager);
            ClearVoteArrays(voteManager);
        }        
        
        FreeOptions(options);
        return _:vote_active;
    }
    else
    {
        DeleteVoteParams(voteManager);
        return _:false;
    }
}

//native bool:UMC_GetRandomMap(Handle:kv, const String:group=INVALID_GROUP, String:buffer[], size,
//                             Handle:excludedMaps, Handle:excludedGroups, bool:forceGroup);
public Native_UMCGetRandomMap(Handle:plugin, numParams)
{
    new Handle:kv = Handle:GetNativeCell(1);
    new Handle:filtered = CreateKeyValues("umc_rotation");
    KvCopySubkeys(kv, filtered);

    new Handle:mapcycle = Handle:GetNativeCell(2);
    new len;
    GetNativeStringLength(3, len);
    new String:group[len+1];
    if (len > 0)
    {
        GetNativeString(3, group, len+1);
    }
    
    new bool:isNom = bool:GetNativeCell(8);
    new bool:forMapChange = bool:GetNativeCell(9);
    
    FilterMapcycle(filtered, mapcycle, isNom, forMapChange);
    WeightMapcycle(filtered, mapcycle);
    
    decl String:map[MAP_LENGTH], String:groupResult[MAP_LENGTH];
    new bool:result = GetRandomMapFromCycle(filtered, group, map, sizeof(map), groupResult, sizeof(groupResult));
    
    CloseHandle(filtered);
    
    if (result)
    {
        SetNativeString(4, map, GetNativeCell(5), false);
        SetNativeString(6, groupResult, GetNativeCell(7), false);
        return true;
    }
    return false;
}

//native bool:UMC_SetNextMap(Handle:kv, const String:map[], const String:group[]);
public Native_UMCSetNextMap(Handle:plugin, numParams)
{
    new Handle:kv = Handle:GetNativeCell(1);
    
    new len;
    GetNativeStringLength(2, len);
    new String:map[len+1];
    if (len > 0)
    {
        GetNativeString(2, map, len+1);
    }
    GetNativeStringLength(3, len);
    new String:group[len+1];
    if (len > 0)
    {
        GetNativeString(3, group, len+1);
    }
    if (!IsMapValid(map))
    {
        LogError("SETMAP: Map %s is invalid!", map);
        return;
    }
    
    new UMC_ChangeMapTime:when = UMC_ChangeMapTime:GetNativeCell(4);
    
    decl String:reason[PLATFORM_MAX_PATH];
    GetPluginFilename(plugin, reason, sizeof(reason));
    
    DoMapChange(when, kv, map, group, reason, map);
}

public Native_UMCIsVoteInProgress(Handle:plugin, numParams)
{
    if (numParams > 0)
    {
        new len;
        GetNativeStringLength(1, len);
        new String:voteManagerID[len+1];
        if (len > 0)
        {
            GetNativeString(1, voteManagerID, len+1);
        }
        
        if (strlen(voteManagerID) > 0)
        {
            new bool:inProgress;
            new Handle:vM;
            if (!GetTrieValue(vote_managers, voteManagerID, vM))
            {
                ThrowNativeError(SP_ERROR_PARAM, "A Vote Manager with the ID \"%s\" does not exist!", voteManagerID);
            }
            GetTrieValue(vM, "in_progress", inProgress);
            return inProgress;
        }
    }
    decl String:buffer[64];
    new size = GetArraySize(vote_manager_ids);
    new Handle:vM;
    new bool:inProgress;
    for (new i = 0; i < size; i++)
    {
        GetArrayString(vote_manager_ids, i, buffer, sizeof(buffer));
        GetTrieValue(vote_managers, buffer, vM);
        GetTrieValue(vM, "in_progress", inProgress);
        if (inProgress)
        {
            return _:true;
        }
    }
    return _:false;
}

//"sm_umc_stopvote"
public Native_UMCStopVote(Handle:plugin, numParams)
{
    Native_UMCVoteManagerCancel(plugin, numParams);
}

public Native_UMCIsMapValid(Handle:plugin, numParams)
{
    new Handle:arg = Handle:GetNativeCell(1);
    new Handle:kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(arg, kv);
    
    new len;
    GetNativeStringLength(2, len);
    new String:map[len+1];
    if (len > 0)
    {
        GetNativeString(2, map, len+1);
    }
    GetNativeStringLength(3, len);
    new String:group[len+1];
    if (len > 0)
    {
        GetNativeString(3, group, len+1);
    }
    new bool:isNom = bool:GetNativeCell(4);
    new bool:forMapChange = bool:GetNativeCell(5);
    
    if (!KvJumpToKey(kv, group))
    {
        LogError("NATIVE: No group '%s' in mapcycle.", group);
        return _:false;
    }
    if (!KvJumpToKey(kv, map))
    {
        LogError("NATIVE: No map %s found in group '%s'", map, group);
        return _:false;
    }
    
    return _:IsValidMap(kv, arg, group, isNom, forMapChange);
}

public Native_UMCGetCurrentGroup(Handle:plugin, numParams)
{
    SetNativeString(1, current_cat, GetNativeCell(2), false);
}

//************************************************************************************************//
//                                            COMMANDS                                            //
//************************************************************************************************//
public Action:Command_DisplayMapLists(client, args)
{
    new bool:filtered;
    if (args < 1)
    {
        filtered = false;
    }
    else
    {
        decl String:arg[5];
        GetCmdArg(1, arg, sizeof(arg));
        filtered = StringToInt(arg) > 0;
    }

    PrintToConsole(client, "UMC Maplists:");
    
    Call_StartForward(maplistdisplay_forward);
    Call_PushCell(client);
    Call_PushCell(filtered);
    Call_Finish();
    
    return Plugin_Handled;
}

public Action:Command_MapHistory(client, args)
{
    PrintToConsole(client, "Map History:");

    new size = GetMapHistorySize();
    decl String:map[MAP_LENGTH], String:reason[100], String:timeString[100];
    new time;
    for (new i = 0; i < size; i++)
    {
        GetMapHistory(i, map, sizeof(map), reason, sizeof(reason), time);
        FormatTime(timeString, sizeof(timeString), NULL_STRING, time);
        ReplyToCommand(client, "%02i. %s : %s : %s", i+1, map, reason, timeString);
    }
    return Plugin_Handled;
}

//Called when the command to set the nextmap is called.
public Action:Command_SetNextmap(client, args)
{
    if (args < 1)
    {
        ReplyToCommand(client,"[UMC] Usage: sm_setnextmap <map> <0|1|2>\n 0 - Change Now\n 1 - Change at end of round\n 2 - Change at end of map.");
        return Plugin_Handled;
    }
    
    decl String:map[MAP_LENGTH];
    GetCmdArg(1, map, sizeof(map));
    
    if (!IsMapValid(map))
    {
        ReplyToCommand(client, "[UMC] Map '%s' was not found.", map);
        return Plugin_Handled;
    }
    
    new UMC_ChangeMapTime:when = ChangeMapTime_MapEnd;
    if (args > 1)
    {
        decl String:whenArg[2];
        GetCmdArg(2, whenArg, sizeof(whenArg));
        when = UMC_ChangeMapTime:StringToInt(whenArg);
    }
    
    //DisableVoteInProgress(id);
    DoMapChange(when, INVALID_HANDLE, map, INVALID_GROUP, "sm_setnextmap", map);
    
    //TODO: Make this a translation
    ShowActivity(client, "Changed nextmap to \"%s\".", map);
    LogUMCMessage("%L changed nextmap to \"%s\"", client, map);
    
    //vote_completed = true;
    
    return Plugin_Handled;
}

//Called when the command to reload the mapcycle has been triggered.
public Action:Command_Reload(client, args)
{
    //Call the reload forward.
    Call_StartForward(reload_forward);
    Call_Finish();
    
    ReplyToCommand(client, "[UMC] UMC Mapcycles Reloaded.");    
    
    //Return success
    return Plugin_Handled;
}

//"sm_umc_stopvote"
public Action:Command_StopVote(client, args)
{
    //End all votes currently in progress.
    new size = GetArraySize(vote_manager_ids);
    new Handle:vM;
    new bool:inProgress;
    decl String:id[64];
    new bool:stopped = false;
    for (new i = 0; i < size; i++)
    {
        GetArrayString(vote_manager_ids, i, id, sizeof(id));
        GetTrieValue(vote_managers, id, vM);
        GetTrieValue(vM, "in_progress", inProgress);
        if (inProgress)
        {
            //DEBUG_MESSAGE("Ending vote in progress: %s", id)
            stopped = true;
            VoteCancelled(vM);
        }
    }
    if (!stopped)
    {
        ReplyToCommand(client, "[UMC] No map vote running!"); //TODO Translation?
    }
    return Plugin_Handled;
}

//************************************************************************************************//
//                                        CORE VOTE MANAGER                                       //
//************************************************************************************************//
new bool:core_vote_active;

public bool:VM_IsVoteInProgress()
{
	return IsVoteInProgress();
}

public Action:VM_MapVote(duration, Handle:vote_items, const clients[], numClients, const String:startSound[])
{
    if (VM_IsVoteInProgress())
    {
        LogUMCMessage("Could not start core vote, another SM vote is already in progress.");
        return Plugin_Stop;
    }

    new bool:verboseLogs = GetConVarBool(cvar_logging);

    if (verboseLogs)
    {
        LogUMCMessage("Adding Clients to Vote:");
    }
    decl clientArr[MAXPLAYERS+1];
    new count = 0;
    new client;
    for (new i = 0; i < numClients; i++)
    {
        client = clients[i];
        if (client != 0 && IsClientInGame(client))
        {
            if (verboseLogs)
            {
                LogUMCMessage("%i: %N (%i)", i, client, client);
            }
            clientArr[count++] = client;
        }
    }
    
    if (count == 0)
    {
        LogUMCMessage("Could not start core vote, no players to display vote to!");
        return Plugin_Stop;
    }
    
    new Handle:menu = BuildVoteMenu(vote_items, "Map Vote Menu Title", Handle_MapVoteResults);
    
    core_vote_active = menu != INVALID_HANDLE && VoteMenu(menu, clientArr, count, duration);
    
    if (core_vote_active)
    {
        if (strlen(startSound) > 0)
        {
            EmitSoundToAllAny(startSound);
        }
        return Plugin_Continue;
    }
    else
    {    
        LogError("Could not start core vote.");
        return Plugin_Stop;
    }
}

public Action:VM_GroupVote(duration, Handle:vote_items, const clients[], numClients, const String:startSound[])
{
    if (VM_IsVoteInProgress())
    {
        LogUMCMessage("Could not start core vote, another SM vote is already in progress.");
        return Plugin_Stop;
    }

    new bool:verboseLogs = GetConVarBool(cvar_logging);

    if (verboseLogs)
    {
        LogUMCMessage("Adding Clients to Vote:");
    }
    decl clientArr[MAXPLAYERS+1];
    new count = 0;
    new client;
    for (new i = 0; i < numClients; i++)
    {
        client = clients[i];
        if (client != 0 && IsClientInGame(client))
        {
            if (verboseLogs)
            {
                LogUMCMessage("%i: %N (%i)", i, client, client);
            }
            clientArr[count++] = client;
        }
    }
    
    if (count == 0)
    {
        LogUMCMessage("Could not start core vote, no players to display vote to!");
        return Plugin_Stop;
    }
    
    new Handle:menu = BuildVoteMenu(vote_items, "Group Vote Menu Title", Handle_MapVoteResults);
    core_vote_active = true;
    
    if (menu != INVALID_HANDLE && VoteMenu(menu, clientArr, count, duration))
    {
        if (strlen(startSound) > 0)
        {
            EmitSoundToAllAny(startSound);
        }
        return Plugin_Continue;
    }

    core_vote_active = false;
    LogError("Could not start core vote.");
    return Plugin_Stop;
}

Handle:BuildVoteMenu(Handle:vote_items, const String:title[], VoteHandler:callback)
{
    new bool:verboseLogs = GetConVarBool(cvar_logging);

    if (verboseLogs)
    {
        LogUMCMessage("VOTE MENU:");
    }
    
    //Begin creating menu
    new Handle:menu = (GetConVarBool(cvar_valvemenu))
        ? CreateMenuEx(GetMenuStyleHandle(MenuStyle_Valve), Handle_VoteMenu,
                       MenuAction_DisplayItem|MenuAction_Display)
        : CreateMenu(Handle_VoteMenu, MenuAction_DisplayItem|MenuAction_Display);
        
    SetVoteResultCallback(menu, callback); //Set callback
    SetMenuExitButton(menu, false); //Don't want an exit button.
        
    //Set the title
    SetMenuTitle(menu, title);
    
    //Keep track of slots taken up in the vote.
    new blockSlots = GetConVarInt(cvar_block_slots);
    new voteSlots = blockSlots;
    
    if (GetConVarBool(cvar_novote))
    {
        SetMenuOptionFlags(menu, MENUFLAG_BUTTON_NOVOTE);
        voteSlots++;
        
        if (verboseLogs)
        {
            LogUMCMessage("1: No Vote");
        }
    }
    
    //Add blocked slots if the cvar for blocked slots is enabled.
    AddSlotBlockingToMenu(menu, blockSlots);
    new size = GetArraySize(vote_items);
    
    //Throw an error and return nothing if the number of items in the vote is less than 2 (hence no point in voting).
    if (size <= 1)
    {
        LogError("VOTING: Not enough options to run a vote. %i options available.", size);
        CloseHandle(menu);
        return INVALID_HANDLE;
    }
    
    new Handle:voteItem;
    decl String:info[MAP_LENGTH], String:display[MAP_LENGTH];
    for (new i = 0; i < size; i++)
    {
        voteSlots++;
        voteItem = GetArrayCell(vote_items, i);
        GetTrieString(voteItem, "info", info, sizeof(info));
        GetTrieString(voteItem, "display", display, sizeof(display));
        AddMenuItem(menu, info, display);
        
        if (verboseLogs)
        {
            LogUMCMessage("%i: %s (%s)", voteSlots, display, info);
        }
    }
    
    SetCorrectMenuPagination(menu, voteSlots);

    return menu; //Return the finished menu.
}

public VM_CancelVote()
{
    if (core_vote_active)
    {
        core_vote_active = false;
        CancelVote();
    }
}

//Adds slot blocking to a menu
AddSlotBlockingToMenu(Handle:menu, blockSlots)
{
    //Add blocked slots if the cvar for blocked slots is enabled.
    if (blockSlots > 3)
    {
        AddMenuItem(menu, NOTHING_OPTION, "", ITEMDRAW_SPACER);
    }
    if (blockSlots > 0)
    {
        AddMenuItem(menu, NOTHING_OPTION, "Slot Block Message 1", ITEMDRAW_DISABLED);
    }
    if (blockSlots > 1)
    {
        AddMenuItem(menu, NOTHING_OPTION, "Slot Block Message 2", ITEMDRAW_DISABLED);
    }
    if (blockSlots > 2)
    {
        AddMenuItem(menu, NOTHING_OPTION, "", ITEMDRAW_SPACER);
    }
    if (blockSlots > 4)
    {
        AddMenuItem(menu, NOTHING_OPTION, "", ITEMDRAW_SPACER);
    }
}

//Called when a vote has finished.
public Handle_VoteMenu(Handle:menu, MenuAction:action, param1, param2)
{
    switch(action)
    {
        case MenuAction_Display:
        {
            new Handle:panel = Handle:param2;
            
            decl String:phrase[255];
            GetMenuTitle(menu, phrase, sizeof(phrase));
            
            decl String:buffer[255];
            FormatEx(buffer, sizeof(buffer), "%T", phrase, param1);
            
            SetPanelTitle(panel, buffer);
        }
        case MenuAction_Select:
        {
            if (GetConVarBool(cvar_logging))
            {
                LogUMCMessage("%L selected menu item %i", param1, param2);
            }
            UMC_VoteManagerClientVoted("core", param1, INVALID_HANDLE);
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
            if (GetConVarBool(cvar_logging))
            {
                LogUMCMessage("Vote has concluded.");
            }
        }
        case MenuAction_VoteCancel:
        {
            if (core_vote_active)
            {
                //Vote was cancelled generically, notify UMC.                
                core_vote_active = false;
                UMC_VoteManagerVoteCancelled("core");
            }
        }
        case MenuAction_DisplayItem:
        {
            decl String:map[MAP_LENGTH], String:display[MAP_LENGTH];
            GetMenuItem(menu, param2, map, sizeof(map), _, display, sizeof(display));
            
            if (StrEqual(map, EXTEND_MAP_OPTION) || StrEqual(map, DONT_CHANGE_OPTION) || (StrEqual(map, NOTHING_OPTION) && strlen(display) > 0))
            {
                decl String:buffer[255];
                FormatEx(buffer, sizeof(buffer), "%T", display, param1);
                
                return RedrawMenuItem(buffer);
            }
        }
    }
    return 0;
}

//Handles the results of a vote.
public Handle_MapVoteResults(Handle:menu, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
    core_vote_active = false;
    new Handle:results = ConvertVoteResults(menu, num_clients, client_info, num_items, item_info);
    UMC_VoteManagerVoteCompleted("core", results, Handle_Response);
    
    //Free Memory
    new size = GetArraySize(results);
    new Handle:item;
    new Handle:clients;
    for (new i = 0; i < size; i++)
    {
        item = GetArrayCell(results, i);
        GetTrieValue(item, "clients", clients);
        CloseHandle(clients);
        CloseHandle(item);
    }
    CloseHandle(results);
}

public Handle_Response(UMC_VoteResponse:response, const String:param[])
{
    //Do Nothing
}

//Converts results of a vote to the format required for UMC to process votes.
Handle:ConvertVoteResults(Handle:menu, num_clients, const client_info[][2], num_items, const item_info[][2])
{
    new Handle:result = CreateArray();
    new itemIndex;
    new Handle:voteItem, Handle:voteClientArray;
    decl String:info[MAP_LENGTH], String:disp[MAP_LENGTH];
    for (new i = 0; i < num_items; i++)
    {
        itemIndex = item_info[i][VOTEINFO_ITEM_INDEX];
        GetMenuItem(menu, itemIndex, info, sizeof(info), _, disp, sizeof(disp));
        
        voteItem = CreateTrie();
        voteClientArray = CreateArray();
        
        SetTrieString(voteItem, "info", info);
        SetTrieString(voteItem, "display", disp);
        SetTrieValue(voteItem, "clients", voteClientArray);
        
        PushArrayCell(result, voteItem);
        
        for (new j = 0; j < num_clients; j++)
        {
            if (client_info[j][VOTEINFO_CLIENT_ITEM] == itemIndex)
            {
                PushArrayCell(voteClientArray, client_info[j][VOTEINFO_CLIENT_INDEX]);
            }
        }
    }
    return result;
}

//************************************************************************************************//
//                                        VOTING UTILITIES                                        //
//************************************************************************************************//
DisableVoteInProgress(Handle:vM)
{
    SetTrieValue(vM, "in_progress", false);
}

FreeOptions(Handle:options)
{
    new size = GetArraySize(options);
    new Handle:item;
    for (new i = 0; i < size; i++)
    {
        item = GetArrayCell(options, i);
        CloseHandle(item);
    }
    CloseHandle(options);
}

bool:IsVMVoteInProgress(Handle:voteManager)
{
    new Handle:progressCheck;
    GetTrieValue(voteManager, "checkprogress", progressCheck);
    new bool:result;
	
    if (GetForwardFunctionCount(progressCheck) == 0)
    {
        result = IsVoteInProgress();
    }
    else
    {
        Call_StartForward(progressCheck);
        Call_Finish(result);
    }

    return result;
}

bool:PerformVote(Handle:voteManager, UMC_VoteType:type, Handle:options, time, const clients[], numClients, const String:startSound[])
{
    new Handle:handler;
    switch (type)
    {
        case VoteType_Map:
        {
            LogUMCMessage("Initiating Vote Type: Map");
            GetTrieValue(voteManager, "map", handler);
        }
        case VoteType_Group:
        {
            LogUMCMessage("Initiating Vote Type: Group");
            GetTrieValue(voteManager, "group", handler);
        }        
        case VoteType_Tier:
        {
            LogUMCMessage("Initiating Vote Type: Stage 1 Tiered");
            GetTrieValue(voteManager, "group", handler);
        }
    }
    
    new Action:result;
    Call_StartForward(handler);
    Call_PushCell(time);
    Call_PushCell(options);
    Call_PushArray(clients, numClients);
    Call_PushCell(numClients);
    Call_PushString(startSound);
    Call_Finish(result);
    
    new bool:started = result == Plugin_Continue;
    
    if (started)
    {
        SetTrieValue(voteManager, "in_progress", true);
        SetTrieValue(voteManager, "active", true);
    }
    
    return started;
}

enum UMC_BuildOptionsError
{
    BuildOptionsError_InvalidMapcycle,
    BuildOptionsError_NoMapGroups,
    BuildOptionsError_NotEnoughOptions,
    BuildOptionsError_Success
};

//Build and returns a new vote menu.
Handle:BuildVoteItems(Handle:vM, Handle:kv, Handle:mapcycle, &UMC_VoteType:type, bool:scramble,
                      bool:allowDupes, bool:strictNoms, bool:exclude, bool:extend, bool:dontChange)
{
    new Handle:result = CreateArray();
    new UMC_BuildOptionsError:error;

    switch (type)
    {
        case (VoteType_Map):
        {
            error = BuildMapVoteItems(vM, result, kv, mapcycle, scramble, extend, dontChange, allowDupes, strictNoms, .exclude=exclude);
        }
        case (VoteType_Group):
        {
            error = BuildCatVoteItems(vM, result, kv, mapcycle, scramble, extend, dontChange, strictNoms, exclude);
        }
        case (VoteType_Tier):
        {
            error = BuildCatVoteItems(vM, result, kv, mapcycle, scramble, extend, dontChange, strictNoms, exclude);
        }
    }

    if ((type == VoteType_Group || type == VoteType_Tier) && error == BuildOptionsError_NotEnoughOptions)
    {
        type = VoteType_Map;
        error = BuildMapVoteItems(vM, result, kv, mapcycle, scramble, extend, dontChange, allowDupes, strictNoms, .exclude=exclude);
    }

    if (error == BuildOptionsError_InvalidMapcycle || error == BuildOptionsError_NoMapGroups)
    {
        CloseHandle(result);
        result = INVALID_HANDLE;
    }
    
    return result;
}

//Builds and returns a menu for a map vote.
UMC_BuildOptionsError:BuildMapVoteItems(Handle:voteManager, Handle:result, Handle:okv, 
                                        Handle:mapcycle, bool:scramble, bool:extend, 
                                        bool:dontChange, bool:ignoreDupes=false, 
                                        bool:strictNoms=false, bool:ignoreInvoteSetting=false, 
                                        bool:exclude=true)
{
    //Throw an error and return nothing if the mapcycle is invalid.
    if (okv == INVALID_HANDLE)
    {
        LogError("VOTING: Cannot build map vote menu, rotation file is invalid.");
        return BuildOptionsError_InvalidMapcycle;
    }
    
    //Duplicate the kv handle, because we will be deleting some keys.
    KvRewind(okv); //rewind original
    new Handle:kv = CreateKeyValues("umc_rotation"); //new handle
    KvCopySubkeys(okv, kv); //copy everything to the new handle
    
    //Filter mapcycle
    if (exclude)
    {
        FilterMapcycle(kv, mapcycle, .deleteEmpty=false);
    }
    
    //Log an error and return nothing if it cannot find a category.
    if (!KvGotoFirstSubKey(kv))
    {
        LogError("VOTING: No map groups found in rotation. Vote menu was not built.");
        CloseHandle(kv);
        return BuildOptionsError_NoMapGroups;
    }
    
    ClearVoteArrays(voteManager);

    //Determine how we're logging
    new bool:verboseLogs = GetConVarBool(cvar_logging);
    
    //Buffers
    new String:mapName[MAP_LENGTH];     //Name of the map
    new String:display[MAP_LENGTH];     //String to be displayed in the vote
    new String:gDisp[MAP_LENGTH];
    new String:catName[MAP_LENGTH];     //Name of the category.
    
    //Other variables
    new voteCounter = 0; //Number of maps in the vote currently
    new numNoms = 0;     //Number of nominated maps in the vote.
    new Handle:nominationsFromCat = INVALID_HANDLE; //adt_array containing all nominations from the
                                                    //current category.
    new Handle:tempCatNoms = INVALID_HANDLE;
    new Handle:trie        = INVALID_HANDLE; //a nomination
    new Handle:nameArr     = INVALID_HANDLE; //adt_array of map names from nominations
    new Handle:weightArr   = INVALID_HANDLE; //adt_array of map weights from nominations.
    
    new Handle:map_vote;
    GetTrieValue(voteManager, "map_vote", map_vote);
    
    new Handle:map_vote_display = CreateArray(ByteCountToCells(MAP_LENGTH));
    
    new nomIndex, position, numMapsFromCat, nomCounter, inVote, index; //, cIndex;
    
    new tierAmount = GetConVarInt(cvar_vote_tieramount);
    
    new Handle:nomKV;
    decl String:nomGroup[MAP_LENGTH];
    
    //Add maps to vote array from current category.
    do
    {
        WeightMapGroup(kv, mapcycle);
    
        //Store the name of the current category.
        KvGetSectionName(kv, catName, sizeof(catName));
        
        //Get the map-display template from the categeory definition.
        KvGetString(kv, "display-template", gDisp, sizeof(gDisp), "{MAP}");
        
        //Get all nominations for the current category.
        if (exclude)
        {
            tempCatNoms = GetCatNominations(catName);
            nominationsFromCat = FilterNominationsArray(tempCatNoms);        
            CloseHandle(tempCatNoms);
        }
        else
        {
            nominationsFromCat = GetCatNominations(catName);
        }
        //Get the amount of nominations for the current category.
        numNoms = GetArraySize(nominationsFromCat);

        //Get the total amount of maps to appear in the vote from this category.
        inVote = ignoreInvoteSetting ? tierAmount : KvGetNum(kv, "maps_invote", 1);
        
        if (verboseLogs)
        {
            if (ignoreInvoteSetting)
            {
                LogUMCMessage("VOTE MENU: (Verbose) Second stage tiered vote. See cvar \"sm_umc_vote_tieramount.\"");
            }
            LogUMCMessage("VOTE MENU: (Verbose) Fetching %i maps from group '%s'", inVote, catName);
        }
        
        //Calculate the number of maps we still need to fetch from the mapcycle.
        numMapsFromCat = inVote - numNoms;
        
        // Populate vote with nomination maps from this category if we do not need to fetch any maps from the mapcycle AND
        // the number of nominated maps in the vote is limited to the maps_invote setting for the category.
        if (numMapsFromCat < 0 && strictNoms)
        {
            //////
            //The piece of code inside this block is for the case where the current category's
            //nominations exceeds it's number of maps allowed in the vote.
            //
            //In order to solve this problem, we first fetch all nominations where the map has
            //appropriate min and max players for the amount of players on the server, and then
            //randomly pick from this pool based on the weights if the maps, until the number
            //of maps in the vote from this category is reached.
            //////
            if (verboseLogs)
            {
                LogUMCMessage(
                    "VOTE MENU: (Verbose) Number of nominations (%i) exceeds allowable maps in vote for the map group '%s'. Limiting nominated maps to %i. (See cvar \"sm_umc_nominate_strict\")",
                    numNoms, catName, inVote
                );
            }
        
            //No nominations have been fetched from pool of possible nomination.
            nomCounter = 0;
            
            //Populate vote array with nominations from this category if we have nominations from this category.
            if (numNoms > 0)
            {
                //Initialize name and weight adt_arrays.
                nameArr = CreateArray(ByteCountToCells(MAP_LENGTH));
                weightArr = CreateArray();
                new Handle:cycleArr = CreateArray();
          
                //Store data from a nomination for each index of the adt_array of nominations from this category.
                for (new i = 0; i < numNoms; i++)
                {
                    //Store nomination.
                    trie = GetArrayCell(nominationsFromCat, i);
                    
                    //Get the map name from the nomination.
                    GetTrieString(trie, MAP_TRIE_MAP_KEY, mapName, sizeof(mapName));

                    // Add map to list of possible maps to be added to vote from the nominations 
                    // if the map is valid (correct number of players, correct time)
                    if (!ignoreDupes && FindStringInVoteArray(mapName, MAP_TRIE_MAP_KEY, map_vote) != -1)
                    {
                        if (verboseLogs)
                        {
                            LogUMCMessage("VOTE MENU: (Verbose) Skipping nominated map '%s' from map group '%s' because it already is in the vote.", mapName, catName);
                        }
                    }
                    else
                    {
                        //Increment number of noms fetched.
                        nomCounter++;
                        
                        //Fetch mapcycle for weighting
                        GetTrieValue(trie, "mapcycle", nomKV);
                        
                        //Add map name to the pool.
                        PushArrayString(nameArr, mapName);
                        
                        //Add map weight to the pool.
                        PushArrayCell(weightArr, GetMapWeight(nomKV, mapName, catName));
                        PushArrayCell(cycleArr, trie);
                    }
                }

                //Populate vote array with maps from the pool if the number of nominations fetched is greater than zero.
                if (nomCounter > 0)
                {
                    //Add a nominated map from the pool into the vote arrays for the number of available spots there are from the category.
                    new min = (inVote < nomCounter) ? inVote : nomCounter;

                    for (new i = 0; i < min; i++)
                    {
                        //Get a random map from the pool.
                        GetWeightedRandomSubKey(mapName, sizeof(mapName), weightArr, nameArr, index);
                        new Handle:nom = GetArrayCell(cycleArr, index);
                        GetTrieValue(nom, "mapcycle", nomKV);
                        GetTrieString(nom, "nom_group", nomGroup, sizeof(nomGroup));

                        //Get the position in the vote array to add the map to
                        position = GetNextMenuIndex(voteCounter, scramble);
                        
                        //Template
                        new Handle:dispKV = CreateKeyValues("umc_mapcycle");
                        KvCopySubkeys(nomKV, dispKV);
                        GetMapDisplayString(dispKV, nomGroup, mapName, gDisp, display, sizeof(display));
                        CloseHandle(dispKV);
                        
                        new Handle:map = CreateMapTrie(mapName, catName);
                        new Handle:nomMapcycle = CreateKeyValues("umc_mapcycle");
                        KvCopySubkeys(nomKV, nomMapcycle);
                        SetTrieValue(map, "mapcycle", nomMapcycle);
                        
                        InsertArrayCell(map_vote, position, map);
                        InsertArrayString(map_vote_display, position, display);
                        
                        //Increment number of maps added to the vote.
                        voteCounter++;
                        
                        //Delete the map so it can't be picked again.
                        KvDeleteSubKey(kv, mapName);

                        //Remove map from pool.
                        RemoveFromArray(nameArr, index);
                        RemoveFromArray(weightArr, index);
                        RemoveFromArray(cycleArr, index);
                        
                        if (verboseLogs)
                        {
                            LogUMCMessage("VOTE MENU: (Verbose) Nominated map '%s' from group '%s' was added to the vote.", mapName, catName);
                        }
                    }
                }
                
                //Close handles for the pool.
                CloseHandle(nameArr);
                CloseHandle(weightArr);
                CloseHandle(cycleArr);
                
                //Update numMapsFromCat to reflect the actual amount still required.
                numMapsFromCat = inVote - nomCounter;
            }
        }
        // Otherwise, we fill the vote with nominations then fill the rest with random maps from the mapcycle.
        else
        {
            //Add nomination to the vote array for each index in the nomination array.
            for (new i = 0; i < numNoms; i++)
            {
                //Get map name.
                new Handle:nom = GetArrayCell(nominationsFromCat, i);
                GetTrieString(nom, MAP_TRIE_MAP_KEY, mapName, sizeof(mapName));
                
                // Add nominated map to the vote array if the map isn't already in the vote AND
                // the server has a valid number of players for the map.
                if (!ignoreDupes && FindStringInVoteArray(mapName, MAP_TRIE_MAP_KEY, map_vote) != -1)
                {
                    if (verboseLogs)
                    {
                        LogUMCMessage("VOTE MENU: (Verbose) Skipping nominated map '%s' from map group '%s' because it is already in the vote.", mapName, catName);
                    }
                }
                else
                {
                    GetTrieValue(nom, "mapcycle", nomKV);
                    GetTrieString(nom, "nom_group", nomGroup, sizeof(nomGroup));
                
                    //Get extra fields from the map
                    new Handle:dispKV = CreateKeyValues("umc_mapcycle");
                    KvCopySubkeys(nomKV, dispKV);
                    GetMapDisplayString(dispKV, nomGroup, mapName, gDisp, display, sizeof(display));
                    CloseHandle(dispKV);
                                        
                    //Get the position in the vote array to add the map to.
                    position = GetNextMenuIndex(voteCounter, scramble);
                    new Handle:map = CreateMapTrie(mapName, catName);
                    new Handle:nomMapcycle = CreateKeyValues("umc_mapcycle");
                    KvCopySubkeys(nomKV, nomMapcycle);
                    
                    SetTrieValue(map, "mapcycle", nomMapcycle);
                    InsertArrayCell(map_vote, position, map);
                    InsertArrayString(map_vote_display, position, display);
                    
                    //Increment number of maps added to the vote.
                    voteCounter++;
                        
                    //Delete the map so it cannot be picked again.
                    KvDeleteSubKey(kv, mapName);
                    
                    if (verboseLogs)
                    {
                        LogUMCMessage("VOTE MENU: (Verbose) Nominated map '%s' from group '%s' was added to the vote.", mapName, catName);
                    }
                }
            }
        }
        
        //////
        //At this point in the algorithm, we have already handled nominations for this category.
        //If there are maps which still need to be added to the vote, we will be fetching them
        //from the mapcycle directly.
        //////
        if (verboseLogs)
        {
            LogUMCMessage("VOTE MENU: (Verbose) Finished parsing nominations for map group '%s'", catName);
            
            if (numMapsFromCat > 0)
            {
                LogUMCMessage("VOTE MENU: (Verbose) Still need to fetch %i maps from the group.", numMapsFromCat);
            }
        }
        
        //We no longer need the nominations array, so we close the handle.
        CloseHandle(nominationsFromCat);
        
        // Add a map to the vote array from the current category while 
        // maps still need to be added from the current category.
        while (numMapsFromCat > 0)
        {
            //Skip the category if there are no more maps that can be added to the vote.
            if (!GetRandomMap(kv, mapName, sizeof(mapName)))
            {
                if (verboseLogs)
                {
                    LogUMCMessage("VOTE MENU: (Verbose) No more maps in map group '%s'", catName);
                }
                break;
            }

            // Remove the map from the category (so it cannot be selected again) and repick a map 
            // if the map has already been added to the vote (through nomination or another category
            if (!ignoreDupes && FindStringInVoteArray(mapName, MAP_TRIE_MAP_KEY, map_vote) != -1)
            {
                KvDeleteSubKey(kv, mapName);
                if (verboseLogs)
                {
                    LogUMCMessage("VOTE MENU: (Verbose) Skipping selected map '%s' from map group '%s' because it is already in the vote.", mapName, catName);
                }
                continue;
            }
            
            //At this point we have a map which we are going to add to the vote array.
            if (verboseLogs)
            {
                LogUMCMessage("VOTE MENU: (Verbose) Selected map '%s' from group '%s' was added to the vote.", mapName, catName);
            }
            
            //Find this map in the list of nominations.
            nomIndex = FindNominationIndex(mapName, catName);
            
            //Remove the nomination if it was found.
            if (nomIndex != -1)
            {
                new Handle:nom = GetArrayCell(nominations_arr, nomIndex);
                
                new owner;
                GetTrieValue(nom, "client", owner);
                
                Call_StartForward(nomination_reset_forward);
                Call_PushString(mapName);
                Call_PushCell(owner);
                Call_Finish();

                new Handle:oldnomKV;
                GetTrieValue(nom, "mapcycle", oldnomKV);
                CloseHandle(oldnomKV);
                CloseHandle(nom);
                RemoveFromArray(nominations_arr, nomIndex);
                if (verboseLogs)
                {
                    LogUMCMessage("VOTE MENU: (Verbose) Removing selected map '%s' from nominations.", mapName);
                }
            }
            
            //Get extra fields from the map
            new Handle:dispKV = CreateKeyValues("umc_mapcycle");
            KvCopySubkeys(okv, dispKV);
            GetMapDisplayString(dispKV, catName, mapName, gDisp, display, sizeof(display));
            CloseHandle(dispKV);
            new Handle:map = CreateMapTrie(mapName, catName);
            new Handle:mapMapcycle = CreateKeyValues("umc_mapcycle");
            KvCopySubkeys(mapcycle, mapMapcycle);
            SetTrieValue(map, "mapcycle", mapMapcycle);
                
            // Depending on the cvar, we will display all nominations in the vote either at the top or at the bottom
            // Bottom of the map vote
            if (!GetConVarBool(cvar_mapnom_display))
            {
                InsertArrayCell(map_vote, 0, map);
                InsertArrayString(map_vote_display, 0, display);
            }
            // Top of the map vote
            if (GetConVarBool(cvar_mapnom_display))
            {
                //Get the position in the vote array to add the map to.
                position = GetNextMenuIndex(voteCounter, scramble);
                InsertArrayCell(map_vote, position, map);
                InsertArrayString(map_vote_display, position, display);
            }
            
            //Increment number of maps added to the vote.
            voteCounter++;
            
            //Delete the map from the KV so we can't pick it again.
            KvDeleteSubKey(kv, mapName);
            
            //One less map to be added to the vote from this category.
            numMapsFromCat--;
        }
    }
    while (KvGotoNextKey(kv)); //Do this for each category.
    
    //We no longer need the copy of the mapcycle
    CloseHandle(kv);
    
    new Handle:infoArr = BuildNumArray(voteCounter);
    
    new Handle:voteItem = INVALID_HANDLE;
    decl String:buffer[MAP_LENGTH];
    for (new i = 0; i < voteCounter; i++)
    {
        voteItem = CreateTrie();
        GetArrayString(infoArr, i, buffer, sizeof(buffer));
        SetTrieString(voteItem, "info", buffer);
        GetArrayString(map_vote_display, i, buffer, sizeof(buffer));
        SetTrieString(voteItem, "display", buffer);
        PushArrayCell(result, voteItem);
    }
    
    CloseHandle(map_vote_display);
    CloseHandle(infoArr);
    
    if (extend)
    {
        voteItem = CreateTrie();
        SetTrieString(voteItem, "info", EXTEND_MAP_OPTION);
        SetTrieString(voteItem, "display", "Extend Map");
        if (GetConVarBool(cvar_extend_display))
        {
            InsertArrayCell(result, 0, voteItem);
        }
        else
        {
            PushArrayCell(result, voteItem);
        }
    }
    
    if (dontChange)
    {
        voteItem = CreateTrie();
        SetTrieString(voteItem, "info", DONT_CHANGE_OPTION);
        SetTrieString(voteItem, "display", "Don't Change");
        if (GetConVarBool(cvar_dontchange_display))
        {
            InsertArrayCell(result, 0, voteItem);
        }
        else
        {
            PushArrayCell(result, voteItem);
        }
    }
    
    return BuildOptionsError_Success;
}

//Builds and returns a menu for a group vote.
UMC_BuildOptionsError:BuildCatVoteItems(Handle:vM, Handle:result, Handle:okv, Handle:mapcycle, 
                                        bool:scramble, bool:extend, bool:dontChange, 
                                        bool:strictNoms=false, bool:exclude=true)
{
    //Throw an error and return nothing if the mapcycle is invalid.
    if (okv == INVALID_HANDLE)
    {
        LogError("VOTING: Cannot build map group vote menu, rotation file is invalid.");
        return BuildOptionsError_InvalidMapcycle;
    }
    
    //Rewind our mapcycle.
    KvRewind(okv); //rewind original
    new Handle:kv = CreateKeyValues("umc_rotation"); //new handle
    KvCopySubkeys(okv, kv);
    
    //Log an error and return nothing if it cannot find a category.
    if (!KvGotoFirstSubKey(kv))
    {
        LogError("VOTING: No map groups found in rotation. Vote menu was not built.");
        CloseHandle(kv);
        return BuildOptionsError_NoMapGroups;
    }
    
    ClearVoteArrays(vM);
    
    new bool:verboseLogs = GetConVarBool(cvar_logging);
    
    decl String:catName[MAP_LENGTH]; //Buffer to store category name in.
    decl String:mapName[MAP_LENGTH];
    decl String:nomGroup[MAP_LENGTH];
    new voteCounter = 0;      //Number of categories in the vote.
    new Handle:catArray = CreateArray(ByteCountToCells(MAP_LENGTH), 0); //Array of categories in the vote.
    new Handle:catNoms = INVALID_HANDLE;
    new Handle:nom = INVALID_HANDLE;
    new size;
    new bool:haveNoms = false;
    
    new Handle:nomKV;
    new Handle:nomMapcycle;
    
    //Add the current category to the vote.
    do
    {
        KvGetSectionName(kv, catName, sizeof(catName));
        haveNoms = false;
        if (exclude)
        {
            catNoms = GetCatNominations(catName);
            size = GetArraySize(catNoms);
            for (new i = 0; i < size; i++)
            {
                nom = GetArrayCell(catNoms, i);
                GetTrieValue(nom, "mapcycle", nomMapcycle);
                
                nomKV = CreateKeyValues("umc_rotation");
                KvCopySubkeys(nomMapcycle, nomKV);
                
                GetTrieString(nom, "nom_group", nomGroup, sizeof(nomGroup));
                
                GetTrieString(nom, MAP_TRIE_MAP_KEY, mapName, sizeof(mapName));
                
                KvJumpToKey(nomKV, nomGroup);
                
                if (IsValidMapFromCat(nomKV, nomMapcycle, mapName, .isNom=true))
                {
                    haveNoms = true;            
                    CloseHandle(nomKV);
                    break;
                }
                
                CloseHandle(nomKV);
            }
            CloseHandle(catNoms);
        }
        else if (!KvGotoFirstSubKey(kv))
        {
            if (verboseLogs)
            {
                LogUMCMessage("VOTE MENU: (Verbose) Skipping empty map group '%s'.", catName);
            }
            continue;
        }
        else
        {
            KvGoBack(kv);
            haveNoms = true;
        }
        
        // Skip this category if the server doesn't have the required amount of players or all maps are excluded OR
        // the number of maps in the vote from the category is less than 1.
        if (!haveNoms)
        {
            if (!IsValidCat(kv, mapcycle))
            {
                if (verboseLogs)
                {
                    LogUMCMessage("VOTE MENU: (Verbose) Skipping excluded map group '%s'.", catName);
                }
                continue;
            }
            else if (KvGetNum(kv, "maps_invote", 1) < 1 && strictNoms)
            {
                if (verboseLogs)
                {
                    LogUMCMessage("VOTE MENU: (Verbose) Skipping map group '%s' due to \"maps_invote\" setting of 0.", catName);
                }
                continue;
            }
        }
        
        if (verboseLogs)
        {
            LogUMCMessage("VOTE MENU: (Verbose) Group '%s' was added to the vote.", catName);
        }
        
        //Add category to the vote array...
        InsertArrayString(catArray, GetNextMenuIndex(voteCounter, scramble), catName);
        
        //Increment number of categories in the vote.
        voteCounter++;
    }
    while (KvGotoNextKey(kv)); //Do this for each category.
    
    //No longer need the copied mapcycle
    CloseHandle(kv);

    //Fall back to a map vote if only one group is available.
    if (GetArraySize(catArray) == 1)
    {
        CloseHandle(catArray);
        LogUMCMessage("Not enough groups available for group vote, performing map vote with only group available.");
        return BuildOptionsError_NotEnoughOptions;
    }
    
    new Handle:voteItem = INVALID_HANDLE;
    decl String:buffer[MAP_LENGTH];
    for (new i = 0; i < voteCounter; i++)
    {
        voteItem = CreateTrie();
        GetArrayString(catArray, i, buffer, sizeof(buffer));
        SetTrieString(voteItem, "info", buffer);
        SetTrieString(voteItem, "display", buffer);
        PushArrayCell(result, voteItem);
    }
    
    CloseHandle(catArray);
    
    if (extend)
    {
        voteItem = CreateTrie();
        SetTrieString(voteItem, "info", EXTEND_MAP_OPTION);
        SetTrieString(voteItem, "display", "Extend Map");
        if (GetConVarBool(cvar_extend_display))
        {
            InsertArrayCell(result, 0, voteItem);
        }
        else
        {
            PushArrayCell(result, voteItem);
        }
    }
    
    if (dontChange)
    {
        voteItem = CreateTrie();
        SetTrieString(voteItem, "info", DONT_CHANGE_OPTION);
        SetTrieString(voteItem, "display", "Don't Change");
        if (GetConVarBool(cvar_dontchange_display))
        {
            InsertArrayCell(result, 0, voteItem);
        }
        else
        {
            PushArrayCell(result, voteItem);
        }
    }

    return BuildOptionsError_Success;
}

//Calls the templating system to format a map's display string.
//  kv: Mapcycle containing the template info to use
//  group:  Group of the map we're getting display info for.
//  map:    Name of the map we're getting display info for.
//  buffer: Buffer to store the display string.
//  maxlen: Maximum length of the buffer.
GetMapDisplayString(Handle:kv, const String:group[], const String:map[], const String:template[], String:buffer[], maxlen)
{
    strcopy(buffer, maxlen, "");
    if (KvJumpToKey(kv, group))
    {
        if (KvJumpToKey(kv, map))
        {
            KvGetString(kv, "display", buffer, maxlen, template);
            KvGoBack(kv);
        }
        KvGoBack(kv);
    }
    
    Call_StartForward(template_forward);
    Call_PushStringEx(buffer, maxlen, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
    Call_PushCell(maxlen);
    Call_PushCell(kv);
    Call_PushString(map);
    Call_PushString(group);
    Call_Finish();
}

//Replaces {MAP} and {NOMINATED} in template strings.
public UMC_OnFormatTemplateString(String:template[], maxlen, Handle:kv, const String:map[], const String:group[])
{
    decl String:resolvedMap[MAP_LENGTH];
    GetMapDisplayName(map, resolvedMap, sizeof(resolvedMap));
        
    if (strlen(template) == 0)
    {
        strcopy(template, maxlen, resolvedMap);
        return;
    }
    
    ReplaceString(template, maxlen, "{MAP}", resolvedMap, false);
    
    decl String:nomString[16];
    GetConVarString(cvar_nommsg_disp, nomString, sizeof(nomString));
    ReplaceString(template, maxlen, "{NOMINATED}", nomString, false);
}

//Selects a random map from a category based off of the supplied weights for the maps.
//    kv:     a mapcycle whose traversal stack is currently at the level of the category to choose 
//            from.
//    buffer:    a string to store the selected map in
//    key:  the key containing the weight information (for maps, 'weight', for cats, 'group_weight')
//    excluded: an adt_array of maps to exclude from the selection.
//bool:GetRandomMap(Handle:kv, String:buffer[], size, Handle:excluded, Handle:excludedCats, 
//                  bool:isNom=false, bool:forMapChange=true, bool:memory=true)
bool:GetRandomMap(Handle:kv, String:buffer[], size)
{
    decl String:catName[MAP_LENGTH];
    KvGetSectionName(kv, catName, sizeof(catName));
    
    //Return failure if there are no maps in the category.
    if (!KvGotoFirstSubKey(kv))
    {
        return false;
    }

    new index = 0; //counter of maps in the random pool
    new Handle:nameArr = CreateArray(ByteCountToCells(MAP_LENGTH)); //Array to store possible map names
    new Handle:weightArr = CreateArray();  //Array to store possible map weights.
    decl String:temp[MAP_LENGTH]; //Buffer to store map names in.
    
    //Add a map to the random pool.
    do
    {
        //Get the name of the map.
        KvGetSectionName(kv, temp, sizeof(temp));
        
        //Add the map to the random pool.
        PushArrayCell(weightArr, GetWeight(kv));
        PushArrayString(nameArr, temp);
        
        //One more map in the pool.
        index++;
    }
    while (KvGotoNextKey(kv)); //Do this for each map.

    //Go back to the category level.
    KvGoBack(kv);

    //Close pool and fail if no maps are selectable.
    if (index == 0)
    {
        CloseHandle(nameArr);
        CloseHandle(weightArr);
        return false;
    }
    
    //Use weights to randomly select a map from the pool.
    new bool:result = GetWeightedRandomSubKey(buffer, size, weightArr, nameArr, _);
    
    //Close the pool.
    CloseHandle(nameArr);
    CloseHandle(weightArr);
    
    //Done!
    return result;
}

//Searches array for given string. Returns -1 on failure.
FindStringInVoteArray(const String:target[], const String:val[], Handle:arr)
{
    new size = GetArraySize(arr);
    decl String:buffer[MAP_LENGTH];
    for (new i = 0; i < size; i++)
    {
        GetTrieString(GetArrayCell(arr, i), val, buffer, sizeof(buffer));
        if (StrEqual(buffer, target))
        {
            return i;
        }
    }
    return -1;
}

//Catches the case where a vote occurred but nobody voted.
VoteCancelled(Handle:vM)
{
    new Handle:handler;
    new bool:vote_inprogress;//, bool:vote_active;
    GetTrieValue(vM, "in_progress", vote_inprogress);

    if (vote_inprogress)
    {
        GetTrieValue(vM, "cancel", handler);
        
        ClearVoteArrays(vM);
        EmptyStorage(vM);
        DeleteVoteParams(vM);
        VoteFailed(vM);
        
        Call_StartForward(handler);
        Call_Finish();
    }
}

//Utility function to clear all the voting storage arrays.
ClearVoteArrays(Handle:voteManager)
{
    new Handle:map_vote;
    GetTrieValue(voteManager, "map_vote", map_vote);
    
    new size = GetArraySize(map_vote);
    new Handle:mapTrie;
    new Handle:kv;
    for (new i = 0; i < size; i++)
    {
        mapTrie = GetArrayCell(map_vote, i);
        GetTrieValue(mapTrie, "mapcycle", kv);
        CloseHandle(kv);
        CloseHandle(mapTrie);
    }
    ClearArray(map_vote);
}

//Get the winner from a vote.
any:GetWinner(Handle:vM)
{
    new Handle:vote_storage;
    GetTrieValue(vM, "vote_storage", vote_storage);
    
    new counter = 1;
    new Handle:voteItem = GetArrayCell(vote_storage, 0);
    new Handle:voteClients = INVALID_HANDLE;
    GetTrieValue(voteItem, "clients", voteClients);
    new most_votes = GetArraySize(voteClients);
    new num_items = GetArraySize(vote_storage);
    while (counter < num_items)
    {
        GetTrieValue(GetArrayCell(vote_storage, counter), "clients", voteClients);
        if (GetArraySize(voteClients) < most_votes)
        {
            break;
        }
        counter++;
    }
    if (counter > 1)
    {
        return GetArrayCell(vote_storage, GetRandomInt(0, counter - 1));
    }
    else
    {
        return GetArrayCell(vote_storage, 0);
    }
}

//Generates a list of categories to be excluded from the second stage of a tiered vote.
stock Handle:MakeSecondTieredCatExclusion(Handle:kv, const String:cat[])
{
    //Log an error and return nothing if there are no categories in the cycle (for some reason).
    if (!KvJumpToKey(kv, cat))
    {
        LogError("TIERED VOTE: Cannot create second stage of vote, rotation file is invalid (no groups were found.)");
        return INVALID_HANDLE;
    }
    
    //Array to return at the end.
    new Handle:result = CreateKeyValues("umc_rotation");
    KvJumpToKey(result, cat, true);
    
    KvCopySubkeys(kv, result);
    
    //Return to the root.
    KvGoBack(kv);
    KvGoBack(result);
    
    //Success!
    return result;
}

//Updates the display for the interval between tiered votes.
DisplayTierMessage(timeleft)
{
    decl String:msg[255], String:notification[10];
    FormatEx(msg, sizeof(msg), "%t", "Another Vote", timeleft);
    GetConVarString(cvar_vote_tierdisplay, notification, sizeof(notification));
    DisplayServerMessage(msg, notification);
}

//Empties the vote storage
EmptyStorage(Handle:vM)
{
    new Handle:vote_storage;
    GetTrieValue(vM, "vote_storage", vote_storage);
    
    new size = GetArraySize(vote_storage);
    for (new i = 0; i < size; i++)
    {
        RemoveFromStorage(vM, 0);
    }
    SetTrieValue(vM, "total_votes", 0);
}

//Removes a vote item from the storage
RemoveFromStorage(Handle:vM, index)
{
    new Handle:vote_storage, total_votes;
    GetTrieValue(vM, "vote_storage", vote_storage);
    GetTrieValue(vM, "total_votes", total_votes);
    
    new Handle:stored = GetArrayCell(vote_storage, index);
    new Handle:clients = INVALID_HANDLE;
    GetTrieValue(stored, "clients", clients);
    SetTrieValue(vM, "total_votes", total_votes - GetArraySize(clients));
    CloseHandle(clients);
    CloseHandle(stored);
    RemoveFromArray(vote_storage, index);
}

//Gets the winning info for the vote
GetVoteWinner(Handle:vM, String:info[], maxinfo, &Float:percentage, String:disp[]="", maxdisp=0)
{
    new total_votes;
    GetTrieValue(vM, "total_votes", total_votes);

    new Handle:winner = GetWinner(vM);
    new Handle:clients = INVALID_HANDLE;
    GetTrieString(winner, "info", info, maxinfo);
    GetTrieString(winner, "display", disp, maxdisp);
    GetTrieValue(winner, "clients", clients);
    percentage = float(GetArraySize(clients)) / total_votes * 100;
}

//Finds the index of the given vote item in the storage array. Returns -1 on failure.
FindVoteInStorage(Handle:vote_storage, const String:info[])
{
    new arraySize = GetArraySize(vote_storage);
    new Handle:vote = INVALID_HANDLE;
    decl String:infoBuf[255];
    for (new i = 0; i < arraySize; i++)
    {
        vote = GetArrayCell(vote_storage, i);
        GetTrieString(vote, "info", infoBuf, sizeof(infoBuf));
        if (StrEqual(info, infoBuf))
        {
            return i;
        }
    }
    return -1;
}

//Comparison function for stored vote items. Used for sorting.
public CompareStoredVoteItems(index1, index2, Handle:array, Handle:hndl)
{
    new size1, size2;
    new Handle:vote = INVALID_HANDLE;
    new Handle:clientArray = INVALID_HANDLE;
    vote = GetArrayCell(array, index1);
    GetTrieValue(vote, "clients", clientArray);
    size1 = GetArraySize(clientArray);
    vote = GetArrayCell(array, index2);
    GetTrieValue(vote, "clients", clientArray);
    size2 = GetArraySize(clientArray);
    return size2 - size1;
}

//Adds vote results to the vote storage
AddToStorage(Handle:vM, Handle:vote_results)
{
    new Handle:vote_storage;
    GetTrieValue(vM, "vote_storage", vote_storage);
    SetTrieValue(vM, "prev_vote_count", GetArraySize(vote_storage));
    
    new num_items = GetArraySize(vote_results);
    new storageIndex;
    new num_votes = 0;
    new Handle:voteItem = INVALID_HANDLE;
    new Handle:voteClientArray = INVALID_HANDLE;
    decl String:infoBuffer[255], String:dispBuffer[255];
    for (new i = 0; i < num_items; i++)
    {
        voteItem = GetArrayCell(vote_results, i);
        GetTrieString(voteItem, "info", infoBuffer, sizeof(infoBuffer));
        storageIndex = FindVoteInStorage(vote_storage, infoBuffer);
        GetTrieValue(voteItem, "clients", voteClientArray);
        num_votes += GetArraySize(voteClientArray);
        if (storageIndex == -1)
        {
            new Handle:newItem = CreateTrie();
            SetTrieString(newItem, "info", infoBuffer);
            GetTrieString(voteItem, "display", dispBuffer, sizeof(dispBuffer));
            SetTrieString(newItem, "display", dispBuffer);
            SetTrieValue(newItem, "clients", CloneArray(voteClientArray));
            PushArrayCell(vote_storage, newItem);
        }
        else
        {
            new Handle:storageClientArray;
            GetTrieValue(GetArrayCell(vote_storage, storageIndex), "client", storageClientArray);
            ArrayAppend(storageClientArray, voteClientArray);
        }
    }
    SortADTArrayCustom(vote_storage, CompareStoredVoteItems);
    
    new total_votes;
    GetTrieValue(vM, "total_votes", total_votes);
    SetTrieValue(vM, "total_votes", total_votes + num_votes);
}

//Handles the results of a vote
Handle:ProcessVoteResults(Handle:vM, Handle:vote_results)
{
    new Handle:result = CreateTrie();
    
    //Vote is no longer running.
    SetTrieValue(vM, "active", false);
    
    // Adds these results to the storage.
    AddToStorage(vM, vote_results);
    
    // Perform a runoff vote if it is necessary.
    if (NeedRunoff(vM))
    {
        new remaining_runoffs, prev_vote_count;
        GetTrieValue(vM, "remaining_runoffs", remaining_runoffs);
        GetTrieValue(vM, "prev_vote_count", prev_vote_count);

        //If we can't runoff anymore
        if (remaining_runoffs == 0 || prev_vote_count == 2)
        {
            //Retrieve
            new UMC_RunoffFailAction:stored_fail_action;
            GetTrieValue(vM, "stored_fail_action", stored_fail_action);
            
            if (stored_fail_action == RunoffFailAction_Accept)
            {
                ProcessVoteWinner(vM, result);
            }
            else if (stored_fail_action == RunoffFailAction_Nothing)
            {
                new total_votes;
                GetTrieValue(vM, "total_votes", total_votes);
                new Float:percentage;
                GetVoteWinner(vM, "", 0, percentage);
                PrintToChatAll(
                    "[UMC] %t (%t)",
                    "Vote Failed",
                    "Vote Win Percentage",
                        percentage,
                        total_votes
                );
                LogUMCMessage("MAPVOTE: Vote failed, winning map did not reach threshold.");
                VoteFailed(vM);                
                DeleteVoteParams(vM);
                ClearVoteArrays(vM);
                SetTrieValue(result, "response", VoteResponse_Fail);
            }
            EmptyStorage(vM);
        }
        else
        {
            DoRunoffVote(vM, result);
        }
    }
    else //Otherwise set the results.
    {
        ProcessVoteWinner(vM, result);
        EmptyStorage(vM);
    }
    return result;
}

//Processes the winner from the vote.
ProcessVoteWinner(Handle:vM, Handle:response)
{
    //Detemine winner information.
    decl String:winner[255], String:disp[255];
    new Float:percentage;
    GetVoteWinner(vM, winner, sizeof(winner), percentage, disp, sizeof(disp));
    
    new UMC_VoteType:stored_type;
    GetTrieValue(vM, "stored_type", stored_type);
    
    SetTrieValue(response, "response", VoteResponse_Success);
    SetTrieString(response, "param", disp);
    
    switch (stored_type)
    {
        case VoteType_Map:
        {
            Handle_MapVoteWinner(vM, winner, disp, percentage);
        }
        case VoteType_Group:
        {
            Handle_CatVoteWinner(vM, winner, disp, percentage);
        }
        case VoteType_Tier:
        {
            SetTrieValue(response, "response", VoteResponse_Tiered);
            Handle_TierVoteWinner(vM, winner, disp, percentage);
        }
    }
}

//Determines if a runoff vote is needed.
bool:NeedRunoff(Handle:vM)
{
    //Retrive
    new Float:stored_threshold, total_votes;
    new Handle:vote_storage;
    GetTrieValue(vM, "stored_threshold", stored_threshold);
    GetTrieValue(vM, "total_votes", total_votes);
    GetTrieValue(vM, "vote_storage", vote_storage);
    
    //Get the winning vote item.
    new Handle:voteItem = GetArrayCell(vote_storage, 0);
    new Handle:clients = INVALID_HANDLE;
    GetTrieValue(voteItem, "clients", clients);
    
    new numClients = GetArraySize(clients);
    new bool:result = (float(numClients) / total_votes) < stored_threshold;
    return result;
}

//Sets up a runoff vote.
DoRunoffVote(Handle:vM, Handle:response)
{   
    new remaining_runoffs;
    GetTrieValue(vM, "remaining_runoffs", remaining_runoffs);
    SetTrieValue(vM, "remaining_runoffs", remaining_runoffs - 1);

    //Array to store clients the menu will be displayed to.
    new Handle:runoffClients = CreateArray();
    
    //Build the runoff vote based off of the results of the failed vote.
    new Handle:runoffOptions = BuildRunoffOptions(vM, runoffClients);

    //Setup the timer if the menu was built successfully
    if (runoffOptions != INVALID_HANDLE)
    {   
        new clients[MAXPLAYERS+1];
        new numClients;
    
        //Empty storage and add all clients if we're revoting completely.
        if (!GetConVarBool(cvar_runoff_selective))
        {
            ClearArray(runoffClients);
            EmptyStorage(vM);
            
            new users[MAXPLAYERS+1];
            GetTrieArray2(vM, "stored_users", users, sizeof(users), numClients);
            ConvertUserIDsToClients(users, clients, numClients);
            
            //runoffClients = GetClientsWithFlags(adminFlags);
            ConvertArray(clients, numClients, runoffClients);
        }
        
        //Setup timer to delay the start of the runoff vote.
        SetTrieValue(vM, "runoff_delay", 7);
        
        //Display the first message
        DisplayRunoffMessage(8);
        
        //Setup data pack to go along with the timer.
        new Handle:pack;    
        CreateDataTimer(
            1.0,
            Handle_RunoffVoteTimer,
            pack,
            TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT
        );
        //Add info to the pack.
        WritePackCell(pack, _:vM);
        WritePackCell(pack, _:runoffOptions);
        WritePackCell(pack, _:runoffClients);
        SetTrieValue(response, "response", VoteResponse_Runoff);
    }
    else //Otherwise, cleanup
    {
        LogError("RUNOFF: Unable to create runoff vote menu, runoff aborted.");
        CloseHandle(runoffClients);
        VoteFailed(vM);
        EmptyStorage(vM);
        DeleteVoteParams(vM);
        ClearVoteArrays(vM);
        SetTrieValue(response, "response", VoteResponse_Fail);
    }
}

//Builds a runoff vote menu.
//  clientArray:    adt_array to be populated with clients whose votes were eliminated
Handle:BuildRunoffOptions(Handle:vM, Handle:clientArray)
{
    new Handle:vote_storage, Float:stored_threshold;
    GetTrieValue(vM, "vote_storage", vote_storage);
    GetTrieValue(vM, "stored_threshold", stored_threshold);

    new bool:verboseLogs = GetConVarBool(cvar_logging);
    if (verboseLogs)
    {
        LogUMCMessage("RUNOFF MENU: (Verbose) Building runoff vote menu.");
    }
    
    new Float:runoffThreshold = stored_threshold;
    
    //Copy the current total number of votes. Needed because the number will change as we remove items.
    new totalVotes;
    GetTrieValue(vM, "total_votes", totalVotes);
    
    new Handle:voteItem = INVALID_HANDLE;
    new Handle:voteClients = INVALID_HANDLE;
    new voteNumVotes;
    new num_items = GetArraySize(vote_storage);
    
    //Array determining which clients have voted
    new bool:clientVotes[MAXPLAYERS + 1];
    for (new i = 0; i < num_items; i++)
    {
        voteItem = GetArrayCell(vote_storage, i);
        GetTrieValue(voteItem, "clients", voteClients);
        voteNumVotes = GetArraySize(voteClients);
        for (new j = 0; j < voteNumVotes; j++)
        {
            clientVotes[GetArrayCell(voteClients, j)] = true;
        }
    }
    for (new i = 1; i <= MaxClients; i++)
    {
        if (!clientVotes[i])
        {
            PushArrayCell(clientArray, i);
        }
    }
    
    new Handle:winning = GetArrayCell(vote_storage, 0);
    new winningNumVotes;
    new Handle:winningClients = INVALID_HANDLE;
    GetTrieValue(winning, "clients", winningClients);
    winningNumVotes = GetArraySize(winningClients);
    
    //Starting max possible percentage of the winning item in this vote.
    new Float:percent = float(winningNumVotes) / float(totalVotes) * 100;
    new Float:newPercent;
    
    //Max number of maps in the runoff vote
    new maxMaps;
    GetTrieValue(vM, "stored_runoffmaps_max", maxMaps);
    new bool:checkMax = maxMaps > 1;
    
    //Starting at the item with the least votes, calculate the new possible max percentage
    //of the winning item. Stop when this percentage is greater than the threshold.
    for (new i = num_items - 1; i > 1; i--)
    {
        voteItem = GetArrayCell(vote_storage, i);
        GetTrieValue(voteItem, "clients", voteClients);
        voteNumVotes = GetArraySize(voteClients);
        ArrayAppend(clientArray, voteClients);
        
        newPercent = float(voteNumVotes) / float(totalVotes) * 100;
        percent += newPercent;
        
        if (verboseLogs)
        {
            new String:dispBuf[255];
            GetTrieString(voteItem, "display", dispBuf, sizeof(dispBuf));
            LogUMCMessage("RUNOFF MENU: (Verbose) '%s' was removed from the vote. It had %i votes (%.f%% of total)", dispBuf, voteNumVotes, newPercent);
        }
        
        //No longer store the map
        RemoveFromStorage(vM, i);
        num_items--;
        
        //Stop if the new percentage is over the threshold AND the number of maps in the vote is under the max.
        if (percent >= runoffThreshold && (!checkMax || num_items <= maxMaps))
        {
            break;
        }
    }
    
    if (verboseLogs)
    {
        LogUMCMessage("RUNOFF MENU: (Verbose) Stopped removing options from the vote. Maximum possible winning vote percentage is %.f%%.", percent);
    }
    
    //Start building the new vote menu.
    new Handle:newMenu = CreateArray();
    
    //Populate the new menu with what remains of the storage.
    new count = 0;
    decl String:info[255], String:disp[255];
    new Handle:item;
    for (new i = 0; i < num_items; i++)
    {
        voteItem = GetArrayCell(vote_storage, i);
        GetTrieString(voteItem, "info", info, sizeof(info));
        GetTrieString(voteItem, "display", disp, sizeof(disp));
        
        item = CreateTrie();
        SetTrieString(item, "info", info);
        SetTrieString(item, "display", disp);
        PushArrayCell(newMenu, item);
        
        count++;
    }
    
    //Log an error and do nothing if there weren't enough items added to the runoff vote.
    //  *This shouldn't happen if the algorithm is working correctly*
    if (count < 2)
    {
        for (new i = 0; i < count; i++)
        {
            CloseHandle(GetArrayCell(newMenu, i));
        }
        CloseHandle(newMenu);
        LogError("RUNOFF: Not enough remaining maps to perform runoff vote. %i maps remaining. Please notify plugin author.",count);
        return INVALID_HANDLE;
    }
    
    return newMenu;
}

//Called when the runoff timer for an end-of-map vote completes.
public Action:Handle_RunoffVoteTimer(Handle:timer, Handle:datapack)
{    
    ResetPack(datapack);
    new Handle:vM = Handle:ReadPackCell(datapack);

    new bool:vote_inprogress;
    GetTrieValue(vM, "in_progress", vote_inprogress);

    if (!vote_inprogress)
    {
        VoteFailed(vM);
        EmptyStorage(vM);
        DeleteVoteParams(vM);
        ClearVoteArrays(vM);
        
        new Handle:options = Handle:ReadPackCell(datapack);
        new Handle:clients = Handle:ReadPackCell(datapack);
        FreeOptions(options);
        CloseHandle(clients);
        
        return Plugin_Stop;
    }
    
    new runoff_delay;
    GetTrieValue(vM, "runoff_delay", runoff_delay);
    DisplayRunoffMessage(runoff_delay);

    //Display a message and continue timer if the timer hasn't finished yet.
    if (runoff_delay > 0)
    {
        if (strlen(countdown_sound) > 0)
        {
            EmitSoundToAllAny(countdown_sound);
        }
        
        SetTrieValue(vM, "runoff_delay", runoff_delay - 1);
        return Plugin_Continue;
    }

    LogUMCMessage("RUNOFF: Starting runoff vote.");
    
    //Log an error and do nothing if another vote is currently running for some reason.
    if (IsVMVoteInProgress(vM)) 
    {
        LogUMCMessage("RUNOFF: There is a vote already in progress, cannot start a new vote.");
        return Plugin_Continue;
    }
    
    new Handle:options = Handle:ReadPackCell(datapack);
    new Handle:voteClients = Handle:ReadPackCell(datapack);
    new clients[MAXPLAYERS+1];
    new numClients = GetArraySize(voteClients);
    ConvertAdtArray(voteClients, clients, sizeof(clients));
    
    CloseHandle(voteClients);
    
    new UMC_VoteType:type;
    GetTrieValue(vM, "stored_type", type);
    new time;
    GetTrieValue(vM, "stored_votetime", time);
    decl String:sound[PLATFORM_MAX_PATH];
    GetTrieString(vM, "stored_runoff_sound", sound, sizeof(sound));
    
    new bool:vote_active = PerformVote(vM, type, options, time, clients, numClients, sound);
    if (!vote_active)
    {
        DeleteVoteParams(vM);
        ClearVoteArrays(vM);
        EmptyStorage(vM);
        VoteFailed(vM);
    }
    
    FreeOptions(options);

    return Plugin_Stop;
}

//Displays a notification for the impending runoff vote.
DisplayRunoffMessage(timeRemaining)
{
    decl String:msg[255], String:notification[10];
    if (timeRemaining > 5)
    {
        FormatEx(msg, sizeof(msg), "%t", "Runoff Msg");
    }
    else
    {
        FormatEx(msg, sizeof(msg), "%t", "Another Vote", timeRemaining);
    }
    GetConVarString(cvar_runoff_display, notification, sizeof(notification));
    DisplayServerMessage(msg, notification);
}

//Handles the winner of an end-of-map map vote.
public Handle_MapVoteWinner(Handle:vM, const String:info[], const String:disp[], Float:percentage)
{
    new total_votes;
    GetTrieValue(vM, "total_votes", total_votes);

    //Print a message and extend the current map if the server voted to extend the map.
    if (StrEqual(info, EXTEND_MAP_OPTION))
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "Map Extended",
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        LogUMCMessage("MAPVOTE: Players voted to extend the map.");
        ExtendMap(vM);
    }
    else if (StrEqual(info, DONT_CHANGE_OPTION))
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "Map Unchanged",
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        
        LogUMCMessage("MAPVOTE: Players voted to stay on the map (Don't Change).");
        VoteFailed(vM);
    }
    else //Otherwise, we print a message and then set the new map.
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "End of Map Vote Map Won",
                disp,
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        
        new Handle:map_vote, UMC_ChangeMapTime:change_map_when;
        GetTrieValue(vM, "map_vote", map_vote);
        GetTrieValue(vM, "change_map_when", change_map_when);
        decl String:stored_reason[PLATFORM_MAX_PATH];
        GetTrieString(vM, "stored_reason", stored_reason, sizeof(stored_reason));
        
        //Find the index of the winning map in the stored vote array.
        new index = StringToInt(info);
        decl String:map[MAP_LENGTH], String:group[MAP_LENGTH];
        
        new Handle:mapData = GetArrayCell(map_vote, index);
        GetTrieString(mapData, MAP_TRIE_MAP_KEY, map, sizeof(map));
        GetTrieString(mapData, MAP_TRIE_GROUP_KEY, group, sizeof(group));

        new Handle:mapcycle;
        GetTrieValue(mapData, "mapcycle", mapcycle);
        
        //Set it.
        DisableVoteInProgress(vM);
        DoMapChange(change_map_when, mapcycle, map, group, stored_reason, disp);
        
        LogUMCMessage("MAPVOTE: Players voted for map '%s' from group '%s'", map, group);
    }
    
    decl String:stored_end_sound[PLATFORM_MAX_PATH];
    GetTrieString(vM, "stored_end_sound", stored_end_sound, sizeof(stored_end_sound));
    
    //Play the vote completed sound if the vote completed sound is defined.
    if (strlen(stored_end_sound) > 0)
    {
        EmitSoundToAllAny(stored_end_sound);
    }
    
    //No longer need the vote array.
    ClearVoteArrays(vM);
    DeleteVoteParams(vM);
}

//Handles the winner of an end-of-map category vote.
public Handle_CatVoteWinner(Handle:vM, const String:cat[], const String:disp[],
                            Float:percentage)
{
    new total_votes;
    GetTrieValue(vM, "total_votes", total_votes);
    
    //Print a message and extend the map if the server voted to extend the map.
    if (StrEqual(cat, EXTEND_MAP_OPTION))
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "Map Extended",
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        LogUMCMessage("Players voted to extend the map.");
        ExtendMap(vM);
    }
    else if (StrEqual(cat, DONT_CHANGE_OPTION))
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "Map Unchanged",
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        
        LogUMCMessage("Players voted to stay on the map (Don't Change).");
        VoteFailed(vM);
    }
    else //Otherwise, we pick a random map from the category and set that as the next map.
    {
        decl String:map[MAP_LENGTH];
        new Handle:stored_kv, Handle:stored_mapcycle;
        new UMC_ChangeMapTime:change_map_when;
        decl String:stored_reason[PLATFORM_MAX_PATH];
        new bool:stored_exclude;
        GetTrieValue(vM, "stored_kv", stored_kv);
        GetTrieValue(vM, "stored_mapcycle", stored_mapcycle);
        GetTrieValue(vM, "change_map_when", change_map_when);
        GetTrieString(vM, "stored_reason", stored_reason, sizeof(stored_reason));
        GetTrieValue(vM, "stored_exclude", stored_exclude);
        
        //Rewind the mapcycle.
        KvRewind(stored_kv); //rewind original
        new Handle:kv = CreateKeyValues("umc_rotation");
        KvCopySubkeys(stored_kv, kv);
                    
        //Jump to the category in the mapcycle.
        KvJumpToKey(kv, cat);
        
        if (stored_exclude)
        {
            FilterMapGroup(kv, stored_mapcycle);
        }

        WeightMapGroup(kv, stored_mapcycle);
        
        new Handle:nominationsFromCat;
        
        //An adt_array of nominations from the given category.
        if (stored_exclude)
        {
            new Handle:tempCatNoms = GetCatNominations(cat);
            nominationsFromCat = FilterNominationsArray(tempCatNoms);
            CloseHandle(tempCatNoms);
        }
        else
        {
            nominationsFromCat = GetCatNominations(cat);
        }
        
        // If there are nominations for this category.
        if (GetArraySize(nominationsFromCat) > 0)
        {
            //Array of nominated map names.
            new Handle:nameArr = CreateArray(ByteCountToCells(MAP_LENGTH));
            
            //Array of nominated map weights (linked to the previous by index).
            new Handle:weightArr = CreateArray();
            new Handle:cycleArr = CreateArray();
            
            //Buffer to store the map name
            decl String:nameBuffer[MAP_LENGTH];
            decl String:nomGroup[MAP_LENGTH];
            
            //A nomination.
            new Handle:trie = INVALID_HANDLE;
            new Handle:nomKV;
            new index;
            
            //Add nomination to name and weight array for each nomination in the nomination array for this category.
            new arraySize = GetArraySize(nominationsFromCat);
            for (new i = 0; i < arraySize; i++)
            {
                //Get the nomination at the current index.
                trie = GetArrayCell(nominationsFromCat, i);
                
                //Get the map name from the nomination.
                GetTrieString(trie, MAP_TRIE_MAP_KEY, nameBuffer, sizeof(nameBuffer));    
                GetTrieValue(trie, "mapcycle", nomKV);
                
                //Add the map to the map name array.
                PushArrayString(nameArr, nameBuffer);
                PushArrayCell(weightArr, GetMapWeight(nomKV, nameBuffer, cat));
                PushArrayCell(cycleArr, trie);
            }
            
            //Pick a random map from the nominations if there are nominations to choose from.
            if (GetWeightedRandomSubKey(map, sizeof(map), weightArr, nameArr, index))
            {
                trie = GetArrayCell(cycleArr, index);
                GetTrieValue(trie, "mapcycle", nomKV);
                GetTrieString(trie, "nom_group", nomGroup, sizeof(nomGroup));
                DisableVoteInProgress(vM);
                DoMapChange(change_map_when, nomKV, map, nomGroup, stored_reason, map);
            }
            else //Otherwise, we select a map randomly from the category.
            {
                GetRandomMap(kv, map, sizeof(map));
                DisableVoteInProgress(vM);
                DoMapChange(change_map_when, stored_mapcycle, map, cat, stored_reason, map);
            }
            
            //Close the handles for the storage arrays.
            CloseHandle(nameArr);
            CloseHandle(weightArr);
            CloseHandle(cycleArr);
        }
        
        //Otherwise, there are no nominations to worry about so we just pick a map randomly from the winning category.
        else 
        {
            GetRandomMap(kv, map, sizeof(map)); //, stored_exmaps, stored_exgroups);
            DisableVoteInProgress(vM);
            DoMapChange(change_map_when, stored_mapcycle, map, cat, stored_reason, map);
        }
        
        //We no longer need the adt_array to store nominations.
        CloseHandle(nominationsFromCat);
        
        //We no longer need the copy of the mapcycle.
        CloseHandle(kv);
        
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "End of Map Vote Group Won",
                map, cat,
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        LogUMCMessage("MAPVOTE: Players voted for map group '%s' and the map '%s' was randomly selected.", cat, map);
    }
    
    decl String:stored_end_sound[PLATFORM_MAX_PATH];
    GetTrieString(vM, "stored_end_sound", stored_end_sound, sizeof(stored_end_sound));
    
    //Play the vote completed sound if the vote completed sound is defined.
    if (strlen(stored_end_sound) > 0)
    {
        EmitSoundToAllAny(stored_end_sound);
    }   
    
    DeleteVoteParams(vM);
}

//Handles the winner of an end-of-map tiered vote.
public Handle_TierVoteWinner(Handle:vM, const String:cat[], const String:disp[], Float:percentage)
{
    new total_votes;
    GetTrieValue(vM, "total_votes", total_votes);
    
    //Print a message and extend the map if the server voted to extend the map.
    if (StrEqual(cat, EXTEND_MAP_OPTION))
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "Map Extended",
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        LogUMCMessage("MAPVOTE: Players voted to extend the map.");
        DeleteVoteParams(vM);
        ExtendMap(vM);
    }
    else if (StrEqual(cat, DONT_CHANGE_OPTION))
    {
        PrintToChatAll(
            "[UMC] %t %t (%t)",
            "End of Map Vote Over",
            "Map Unchanged",
            "Vote Win Percentage",
                percentage,
                total_votes
        );
        
        LogUMCMessage("MAPVOTE: Players voted to stay on the map (Don't Change).");
        DeleteVoteParams(vM);
        VoteFailed(vM);
    }
    else //Otherwise, we set up the second stage of the tiered vote
    {
        LogUMCMessage("MAPVOTE (Tiered): Players voted for map group '%s'", cat);
        new vMapCount;
        
        //Get the number of valid nominations from the group
        new Handle:tempNoms = GetCatNominations(cat);
        new bool:stored_exclude;
        GetTrieValue(vM, "stored_exclude", stored_exclude);
        
        if (stored_exclude)
        {
            new Handle:catNoms = FilterNominationsArray(tempNoms);
            vMapCount = GetArraySize(catNoms);        
            CloseHandle(catNoms);
        }
        else
        {
            vMapCount = GetArraySize(tempNoms);
        }
        CloseHandle(tempNoms);
        
        new Handle:stored_kv;
        GetTrieValue(vM, "stored_kv", stored_kv);
        
        //Jump to the map group
        KvRewind(stored_kv);
        new Handle:kv = CreateKeyValues("umc_rotation");
        KvCopySubkeys(stored_kv, kv);

        if (!KvJumpToKey(kv, cat))
        {
            LogError("KV Error: Unable to find map group \"%s\". Try removing any punctuation from the group's name.", cat);
            CloseHandle(kv);
            return;
        }
        
        if (stored_exclude)
        {
            new Handle:stored_mapcycle;
            GetTrieValue(vM, "stored_mapcycle", stored_mapcycle);
            FilterMapGroup(kv, stored_mapcycle);
        }

        //Get the number of valid maps from the group
        vMapCount += CountMapsFromGroup(kv);

        //Return to the root.
        KvGoBack(kv);
        
        //Just parse the results as a normal map group vote if the total number of valid maps is 1.
        if (vMapCount <= 1)
        {
            LogUMCMessage("MAPVOTE (Tiered): Only one valid map found in group. Handling results as a Map Group Vote.");
            CloseHandle(kv);
            Handle_CatVoteWinner(vM, cat, disp, percentage);
            return;
        }
        
        //Setup timer to delay the next vote for a few seconds.
        SetTrieValue(vM, "tiered_delay", 4);
        
        //Display the first message
        DisplayTierMessage(5);
        new Handle:tieredKV = MakeSecondTieredCatExclusion(kv, cat);
        CloseHandle(kv);
        
        //Setup timer to delay the next vote for a few seconds.
        new Handle:pack = CreateDataPack();
        CreateDataTimer(
            1.0,
            Handle_TieredVoteTimer,
            pack,
            TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT
        );
        WritePackCell(pack, _:vM);
        WritePackCell(pack, _:tieredKV);
    }
    
    decl String:stored_end_sound[PLATFORM_MAX_PATH];
    GetTrieString(vM, "stored_end_sound", stored_end_sound, sizeof(stored_end_sound));
    
    //Play the vote completed sound if the vote completed sound is defined.
    if (strlen(stored_end_sound) > 0)
    {
        EmitSoundToAllAny(stored_end_sound);
    }
}

//Called when the timer for the tiered end-of-map vote triggers.
public Action:Handle_TieredVoteTimer(Handle:timer, Handle:pack)
{
    ResetPack(pack);
    new Handle:vM = Handle:ReadPackCell(pack);
    
    new bool:vote_inprogress;
    GetTrieValue(vM, "in_progress", vote_inprogress);

    if (!vote_inprogress)
    {
        VoteFailed(vM);
        DeleteVoteParams(vM);
        return Plugin_Stop;
    }
    
    new tiered_delay;
    GetTrieValue(vM, "tiered_delay", tiered_delay);
    
    DisplayTierMessage(tiered_delay);
    
    if (tiered_delay > 0)
    {
        if (strlen(countdown_sound) > 0)
        {
            EmitSoundToAllAny(countdown_sound);
        }
        SetTrieValue(vM, "tiered_delay", tiered_delay - 1);
        return Plugin_Continue;
    }
        
    if (IsVMVoteInProgress(vM))
    {
        return Plugin_Continue;
    }
    
    new Handle:tieredKV = Handle:ReadPackCell(pack);
    
    //Log a message
    LogUMCMessage("MAPVOTE (Tiered): Starting second stage of tiered vote.");

    new Handle:stored_mapcycle, bool:stored_scramble, bool:stored_ignoredupes, bool:stored_strictnoms, bool:stored_exclude;
    GetTrieValue(vM, "stored_mapcycle", stored_mapcycle);
    GetTrieValue(vM, "stored_scramble", stored_scramble);
    GetTrieValue(vM, "stored_ignoredupes", stored_ignoredupes);
    GetTrieValue(vM, "stored_strictnoms", stored_strictnoms);
    GetTrieValue(vM, "stored_exclude", stored_exclude);

    //Initialize the menu.
    new Handle:options = CreateArray();

    new UMC_BuildOptionsError:error = BuildMapVoteItems(
        vM, options, stored_mapcycle,
        tieredKV, stored_scramble, false,
        false, stored_ignoredupes,
        stored_strictnoms, true, stored_exclude);
    
    if (error == BuildOptionsError_Success)
    {
        decl String:stored_start_sound[PLATFORM_MAX_PATH]; //, String:adminFlags[64];
        GetTrieString(vM, "stored_start_sound", stored_start_sound, sizeof(stored_start_sound));
        //GetTrieString(vM, "stored_adminflags", adminFlags, sizeof(adminFlags));
        
        new users[MAXPLAYERS+1];
        new numClients;
        new clients[MAXPLAYERS+1];
        GetTrieArray2(vM, "stored_users", users, sizeof(users), numClients);
        ConvertUserIDsToClients(users, clients, numClients);
        
        SetTrieValue(vM, "stored_type", VoteType_Map);
        
        new stored_votetime;
        GetTrieValue(vM, "stored_votetime", stored_votetime);
        
        //vote_active = true;
        new bool:vote_active = PerformVote(vM, VoteType_Map, options, stored_votetime, clients, numClients, stored_start_sound);
        
        FreeOptions(options);
        
        if (!vote_active)
        {
            DeleteVoteParams(vM);
            ClearVoteArrays(vM);
            VoteFailed(vM);
        }
    }
    else
    {
        LogError("MAPVOTE (Tiered): Unable to create second stage vote menu. Vote aborted.");
        VoteFailed(vM);
        DeleteVoteParams(vM);
    }
        
    return Plugin_Stop;
}

//Extend the current map.
ExtendMap(Handle:vM)
{
    DisableVoteInProgress(vM);
    new Float:extend_timestep;
    new extend_roundstep;
    new extend_fragstep;
    GetTrieValue(vM, "extend_timestep", extend_timestep);
    GetTrieValue(vM, "extend_roundstep", extend_roundstep);
    GetTrieValue(vM, "extend_fragstep", extend_fragstep);
    
    // Generic/Used in most games
    if (cvar_maxrounds != INVALID_HANDLE && GetConVarInt(cvar_maxrounds) > 0)
    {
        SetConVarInt(cvar_maxrounds, GetConVarInt(cvar_maxrounds) + extend_roundstep);
    }
    if (cvar_winlimit != INVALID_HANDLE && GetConVarInt(cvar_winlimit) > 0)
    {
        SetConVarInt(cvar_winlimit, GetConVarInt(cvar_winlimit) + extend_roundstep);
    }
    if (cvar_fraglimit != INVALID_HANDLE && GetConVarInt(cvar_fraglimit) > 0)
    {    
        SetConVarInt(cvar_fraglimit, GetConVarInt(cvar_fraglimit) + extend_fragstep);
    }
    // ZPS specific
    if (cvar_zpsmaxrnds != INVALID_HANDLE && GetConVarInt(cvar_zpsmaxrnds) > 0)
    {
        SetConVarInt(cvar_zpsmaxrnds, GetConVarInt(cvar_zpsmaxrnds) + extend_roundstep);
    }
    if (cvar_zpomaxrnds != INVALID_HANDLE && GetConVarInt(cvar_zpomaxrnds) > 0)
    {
        SetConVarInt(cvar_zpomaxrnds, GetConVarInt(cvar_zpomaxrnds) + extend_roundstep);
    }
    
    //Extend the time limit.
    ExtendMapTimeLimit(RoundToNearest(extend_timestep * 60));
    
    //Execute the extend command
    decl String:command[64];
    GetConVarString(cvar_extend_command, command, sizeof(command));
    if (strlen(command) > 0)
    {
        ServerCommand(command);
    }
    //Call the extend forward.
    Call_StartForward(extend_forward);
    Call_Finish();
    
    //Log some stuff.
    LogUMCMessage("MAPVOTE: Map extended.");
}

//Called when the vote has failed.
VoteFailed(Handle:vM)
{    
    DisableVoteInProgress(vM);
    Call_StartForward(failure_forward);
    Call_Finish();
}

//Sets the next map and when to change to it.
DoMapChange(UMC_ChangeMapTime:when, Handle:kv, const String:map[], const String:group[], const String:reason[], const String:display[]="")
{   
    //Set the next map group
    strcopy(next_cat, sizeof(next_cat), group);

    //Set the next map in SM
    LogUMCMessage("Setting nextmap to: %s", map);
    SetNextMap(map);
    
    //GE:S Fix
    if (cvar_nextlevel != INVALID_HANDLE)
    {
        SetConVarString(cvar_nextlevel, map);
    }
    
    //Call UMC forward for next map being set
    new Handle:new_kv = INVALID_HANDLE;
    
    if (kv != INVALID_HANDLE)
    {
        new_kv = CreateKeyValues("umc_rotation");
        KvCopySubkeys(kv, new_kv);
    }
    else
    {
        LogUMCMessage("Mapcycle handle is invalid. Map change reason: %s", reason);
    }
    
    Call_StartForward(nextmap_forward);
    Call_PushCell(new_kv);
    Call_PushString(map);
    Call_PushString(group);
    Call_PushString(display);
    Call_Finish();

    if (new_kv != INVALID_HANDLE)
    {
        CloseHandle(new_kv);
    }
    
    //Perform the map change setup
    switch (when)
    {
        case ChangeMapTime_Now: //We change the map in 5 seconds.
        {
            decl String:game[20];
            GetGameFolderName(game, sizeof(game));
            if (!StrEqual(game, "gesource", false) && !StrEqual(game, "zps", false))
            {
                //Routine by Tsunami to end the map
                new iGameEnd = FindEntityByClassname(-1, "game_end");
                if (iGameEnd == -1 && (iGameEnd = CreateEntityByName("game_end")) == -1)
                {
                    ForceChangeInFive(map, reason);
                } 
                else 
                {     
                    AcceptEntityInput(iGameEnd, "EndGame");
                }
            }
            else
            {
                ForceChangeInFive(map, reason);
            }
        }
        case ChangeMapTime_RoundEnd: //We change the map at the end of the round.
        {
            LogUMCMessage("%s: Map will change to '%s' at the end of the round.", reason, map);
            
            change_map_round = true;
            
            //Print a message.
            PrintToChatAll("[UMC] %t", "Map Change at Round End");
        }
    }
}

//Deletes the stored parameters for the vote.
DeleteVoteParams(Handle:vM)
{
    new Handle:stored_kv, Handle:stored_mapcycle;
    GetTrieValue(vM, "stored_kv", stored_kv);
    GetTrieValue(vM, "stored_mapcycle", stored_mapcycle);
    
    CloseHandle(stored_kv);
    CloseHandle(stored_mapcycle);
    
    SetTrieValue(vM, "stored_kv", INVALID_HANDLE);
    SetTrieValue(vM, "stored_mapcycle", INVALID_HANDLE);
}

//************************************************************************************************//
//                                        VALIDITY TESTING                                        //
//************************************************************************************************//
//Checks to see if the server has the required number of players for the given map, and is in the
//required time range.
//    kv:       a mapcycle whose traversal stack is currently at the level of the map's category.
//    map:      the map to check
bool:IsValidMapFromCat(Handle:kv, Handle:mapcycle, const String:map[], bool:isNom=false, bool:forMapChange=true)
{   
    decl String:catName[MAP_LENGTH];
    KvGetSectionName(kv, catName, sizeof(catName));
    
    //Return that the map is not valid if the map doesn't exist in the category.
    if (!KvJumpToKey(kv, map))
    {
        return false;
    }
    
    //Determine if the map is valid, store the answer.
    new bool:result = IsValidMap(kv, mapcycle, catName, isNom, forMapChange);
    
    //Rewind back to the category.
    KvGoBack(kv);
    
    //Return the result.
    return result;
}

//Determines if the server has the required number of players for the given map.
//    kv:       a mapcycle whose traversal stack is currently at the level of the map.
bool:IsValidMap(Handle:kv, Handle:mapcycle, const String:groupName[], bool:isNom=false, bool:forMapChange=true)
{
    decl String:mapName[MAP_LENGTH];
    KvGetSectionName(kv, mapName, sizeof(mapName));
    
    if (!IsMapValid(mapName))
    {
        LogUMCMessage("WARNING: Map \"%s\" does not exist on the server. (Group: \"%s\")", mapName, groupName);
        return false;
    }
    
    new Action:result;
    
    new Handle:new_kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(mapcycle, new_kv);
    
    Call_StartForward(exclude_forward);
    Call_PushCell(new_kv);
    Call_PushString(mapName);
    Call_PushString(groupName);
    Call_PushCell(isNom);
    Call_PushCell(forMapChange);
    Call_Finish(result);
    
    CloseHandle(new_kv);
    
    new bool:re = result == Plugin_Continue;
    
    return re;
}

//Determines if the server has the required number of players for the given category and the required time.
//    kv: a mapcycle whose traversal stack is currently at the level of the category.
bool:IsValidCat(Handle:kv, Handle:mapcycle, bool:isNom=false, bool:forMapChange=true)
{
    //Get the name of the cat.
    decl String:catName[MAP_LENGTH];
    KvGetSectionName(kv, catName, sizeof(catName));
    
    //Return that the map is invalid if there are no maps to check.
    if (!KvGotoFirstSubKey(kv))
    {
        return false;
    }
    
    //Check to see if the server's player count satisfies the min/max conditions for a map in the category.
    do
    {
        //Return to the category level of the mapcycle and return true if a map was found to be satisfied by the server's player count.
        if (IsValidMap(kv, mapcycle, catName, isNom, forMapChange))
        {
            KvGoBack(kv);
            return true;
        }
    }
    while (KvGotoNextKey(kv)); //Goto the next map in the category.

    //Return to the category level.
    KvGoBack(kv);
    
    //No maps in the category can be played with the current amount of players on the server.
    return false;
}

//Counts the number of maps in the given group.
CountMapsFromGroup(Handle:kv)
{
    new result = 0;
    if (!KvGotoFirstSubKey(kv))
    {
        return result;
    }
    
    do
    {
        result++;
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
    
    return result;
}

//Calculates the weight of a map by running it through all of the weight modifiers.
Float:GetMapWeight(Handle:mapcycle, const String:map[], const String:group[])
{
    //Get the starting weight
    current_weight = 1.0;
    
    new Handle:kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(mapcycle, kv);
    
    reweight_active = true;
    
    Call_StartForward(reweight_forward);
    Call_PushCell(kv);
    Call_PushString(map);
    Call_PushString(group);
    Call_Finish();
    
    reweight_active = false;
    
    CloseHandle(kv);
    
    //And return our calculated weight.
    return (current_weight >= 0.0) ? current_weight : 0.0;
}

//Calculates the weight of a map group
Float:GetMapGroupWeight(Handle:originalMapcycle, const String:group[])
{
    current_weight = 1.0;
    
    new Handle:kv = CreateKeyValues("umc_rotation");
    KvCopySubkeys(originalMapcycle, kv);
    
    reweight_active = true;
    
    Call_StartForward(reweight_group_forward);
    Call_PushCell(kv);
    Call_PushString(group);
    Call_Finish();
    
    reweight_active = false;
    
    CloseHandle(kv);
    
    return (current_weight >= 0.0) ? current_weight : 0.0;
}

//Calculates weights for a mapcycle
WeightMapcycle(Handle:kv, Handle:originalMapcycle)
{
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    
    decl String:group[MAP_LENGTH];
    do
    {
        KvGetSectionName(kv, group, sizeof(group));
        
        KvSetFloat(kv, WEIGHT_KEY, GetMapGroupWeight(originalMapcycle, group));
    
        WeightMapGroup(kv, originalMapcycle);
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
}

//Calculates weights for a map group.
WeightMapGroup(Handle:kv, Handle:originalMapcycle)
{
    decl String:map[MAP_LENGTH], String:group[MAP_LENGTH];
    KvGetSectionName(kv, group, sizeof(group));
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    
    do
    {
        KvGetSectionName(kv, map, sizeof(map));
        
        KvSetFloat(kv, WEIGHT_KEY, GetMapWeight(originalMapcycle, map, group));
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
}

//Returns the weight of a given map or map group
Float:GetWeight(Handle:kv)
{
    return KvGetFloat(kv, WEIGHT_KEY, 1.0);
}

//Filters a mapcycle with all invalid entries filtered out.
FilterMapcycle(Handle:kv, Handle:originalMapcycle, bool:isNom=false, bool:forMapChange=true, bool:deleteEmpty=true)
{
    //Do nothing if there are no map groups.
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }

    decl String:group[MAP_LENGTH];
    for ( ; ; )
    {
        //Filter all the maps.
        FilterMapGroup(kv, originalMapcycle, isNom, forMapChange);
        
        //Delete the group if there are no valid maps in it.
        if (deleteEmpty) 
        {
            if (!KvGotoFirstSubKey(kv))
            {
                KvGetSectionName(kv, group, sizeof(group));
        
                if (KvDeleteThis(kv) == -1)
                {
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
    
    //Return to the root.
    KvGoBack(kv);
}

//Filters the kv at the level of the map group.
FilterMapGroup(Handle:kv, Handle:mapcycle, bool:isNom=false, bool:forMapChange=true)
{
    decl String:group[MAP_LENGTH];
    KvGetSectionName(kv, group, sizeof(group));
    
    if (!KvGotoFirstSubKey(kv))
    {
        return;
    }
    
    decl String:mapName[MAP_LENGTH];
    for ( ; ; )
    {
        if (!IsValidMap(kv, mapcycle, group, isNom, forMapChange))
        {
            KvGetSectionName(kv, mapName, sizeof(mapName));
            if (KvDeleteThis(kv) == -1)
            {
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
}

//************************************************************************************************//
//                                           NOMINATIONS                                          //
//************************************************************************************************//
//Filters an array of nominations so that only valid maps remain.
Handle:FilterNominationsArray(Handle:nominations, bool:forMapChange=true)
{
    new Handle:result = CreateArray();

    new size = GetArraySize(nominations);
    new Handle:nom;
    decl String:gBuffer[MAP_LENGTH], String:mBuffer[MAP_LENGTH];
    new Handle:mapcycle;
    new Handle:kv;
    for (new i = 0; i < size; i++)
    {
        nom = GetArrayCell(nominations, i);
        GetTrieString(nom, MAP_TRIE_MAP_KEY, mBuffer, sizeof(mBuffer));
        GetTrieString(nom, MAP_TRIE_GROUP_KEY, gBuffer, sizeof(gBuffer));
        GetTrieValue(nom, "mapcycle", mapcycle);
        
        kv = CreateKeyValues("umc_rotation");
        KvCopySubkeys(mapcycle, kv);
        
        if (!KvJumpToKey(kv, gBuffer))
        {
            continue;
        }
        
        if (IsValidMapFromCat(kv, mapcycle, mBuffer, .isNom=true, .forMapChange=forMapChange))
        {
            PushArrayCell(result, nom);
        }
        
        CloseHandle(kv);
    }
    
    return result;
}

//Nominated a map and group
bool:InternalNominateMap(Handle:kv, const String:map[], const String:group[], client, const String:nomGroup[])
{
    if (FindNominationIndex(map, group) != -1)
    {
        return false;
    }
    
    //Create the nomination trie.
    new Handle:nomination = CreateMapTrie(map, StrEqual(nomGroup, INVALID_GROUP) ? group : nomGroup);
    SetTrieValue(nomination, "client", client); //Add the client
    SetTrieValue(nomination, "mapcycle", kv); //Add the mapcycle
    SetTrieString(nomination, "nom_group", group);

    //Remove the client's old nomination, if it exists.
    new index = FindClientNomination(client);
    if (index != -1)
    {
        new Handle:oldNom = GetArrayCell(nominations_arr, index);
        decl String:oldName[MAP_LENGTH];
        GetTrieString(oldNom, MAP_TRIE_MAP_KEY, oldName, sizeof(oldName));
        Call_StartForward(nomination_reset_forward);
        Call_PushString(oldName);
        Call_PushCell(client);
        Call_Finish();
        
        new Handle:nomKV;
        GetTrieValue(oldNom, "mapcycle", nomKV);
        CloseHandle(nomKV);
        CloseHandle(oldNom);
        RemoveFromArray(nominations_arr, index);
    }

    // Display Bottom
    if (!GetConVarBool(cvar_mapnom_display))
    {
        InsertArrayCell(nominations_arr, 0, nomination);
    }
    // Display Top
    if (GetConVarBool(cvar_mapnom_display))
    {   
        PushArrayCell(nominations_arr, nomination);
    }
    
    return true;
}

//Returns the index of the given client in the nomination pool. -1 is returned if the client isn't in the pool.
FindClientNomination(client)
{
    new buffer;
    new arraySize = GetArraySize(nominations_arr);
    for (new i = 0; i < arraySize; i++)
    {
        GetTrieValue(GetArrayCell(nominations_arr, i), "client", buffer);
        if (buffer == client)
        {
            return i;
        }
    }
    return -1;
}

//Utility function to find the index of a map in the nomination pool.
FindNominationIndex(const String:map[], const String:group[])
{
    decl String:mName[MAP_LENGTH];
    decl String:gName[MAP_LENGTH];
    new Handle:nom = INVALID_HANDLE;
    new arraySize = GetArraySize(nominations_arr);
    for (new i = 0; i < arraySize; i++)
    {
        nom = GetArrayCell(nominations_arr, i);
        GetTrieString(nom, MAP_TRIE_MAP_KEY, mName, sizeof(mName));
        GetTrieString(nom, MAP_TRIE_GROUP_KEY, gName, sizeof(gName));
        if (StrEqual(mName, map, false) && StrEqual(gName, group, false))
        {
            return i;
        }
    }
    return -1;
}

//Utility function to get all nominations from a group.
Handle:GetCatNominations(const String:cat[])
{
    new Handle:arr1 = FilterNominations(MAP_TRIE_GROUP_KEY, cat);
    new Handle:arr2 = FilterNominations(MAP_TRIE_GROUP_KEY, INVALID_GROUP);
    ArrayAppend(arr1, arr2);
    CloseHandle(arr2);
    return arr1;
}

//Utility function to filter out nominations whose value for the given key matches the given value.
Handle:FilterNominations(const String:key[], const String:value[])
{
    new Handle:result = CreateArray();
    new Handle:buffer;
    decl String:temp[255];
    new arraySize = GetArraySize(nominations_arr);
    for (new i = 0; i < arraySize; i++)
    {
        buffer = GetArrayCell(nominations_arr, i);
        GetTrieString(GetArrayCell(nominations_arr, i), key, temp, sizeof(temp));
        if (StrEqual(temp, value, false))
        {
            PushArrayCell(result, buffer);
        }
    }
    return result;
}

//Clears all stored nominations.
ClearNominations()
{
    new size = GetArraySize(nominations_arr);
    new Handle:nomination = INVALID_HANDLE;
    new owner;
    decl String:map[MAP_LENGTH];
    for (new i = 0; i < size; i++)
    {
        nomination = GetArrayCell(nominations_arr, i);
        GetTrieString(nomination, MAP_TRIE_MAP_KEY, map, sizeof(map));
        GetTrieValue(nomination, "client", owner);

        Call_StartForward(nomination_reset_forward);
        Call_PushString(map);
        Call_PushCell(owner);
        Call_Finish();
        
        new Handle:nomKV;
        GetTrieValue(nomination, "mapcycle", nomKV);
        CloseHandle(nomKV);
        CloseHandle(nomination);
    }
    ClearArray(nominations_arr);
}

//************************************************************************************************//
//                                         RANDOM NEXTMAP                                         //
//************************************************************************************************//

//bool:GetRandomMapFromCycle(Handle:kv, const String:group[], String:buffer[], size, String:gBuffer[],
//                           gSize, Handle:exMaps, Handle:exGroups, numEGroups, bool:isNom=false,
//                           bool:forMapChange=true)
bool:GetRandomMapFromCycle(Handle:kv, const String:group[], String:buffer[], size, String:gBuffer[],
                           gSize)
{
    //Buffer to store the name of the category we will be looking for a map in.
    decl String:gName[MAP_LENGTH];
    
    strcopy(gName, sizeof(gName), group);

    if (StrEqual(gName, INVALID_GROUP, false) || !KvJumpToKey(kv, gName))
    {
        if (!GetRandomCat(kv, gName, sizeof(gName)))
        {
            LogError("RANDOM MAP: Cannot pick a random map, no available map groups found in rotation.");
            return false;
        }
        KvJumpToKey(kv, gName);
    }
    
    //Buffer to store the name of the new map.
    decl String:mapName[MAP_LENGTH];
    
    //Log an error and fail if there were no maps found in the category.
    if (!GetRandomMap(kv, mapName, sizeof(mapName)))
    {
        LogError("RANDOM MAP: Cannot pick a random map, no available maps found. Parent Group: %s", gName);
        return false;
    }

    KvGoBack(kv);
    
    //Copy results into the buffers.
    strcopy(buffer, size, mapName);
    strcopy(gBuffer, gSize, gName);
    
    //Return success!
    return true;
}

//Selects a random category based off of the supplied weights for the categories.
//    kv:       a mapcycle whose traversal stack is currently at the root level.
//    buffer:      a string to store the selected category in.
//    key:      the key containing the weight information (most likely 'group_weight')
//    excluded: adt_array of excluded maps
//bool:GetRandomCat(Handle:kv, String:buffer[], size, Handle:excludedCats, numExcludedCats,
//                  Handle:excluded, bool:isNom=false, bool:forMapChange=true)
bool:GetRandomCat(Handle:kv, String:buffer[], size)
{
    //Fail if there are no categories in the mapcycle.
    if (!KvGotoFirstSubKey(kv))
    {
        return false;
    }
    
    new index = 0; //counter of categories in the random pool
    new Handle:nameArr = CreateArray(ByteCountToCells(MAP_LENGTH)); //Array to store possible category names.
    new Handle:weightArr = CreateArray();  //Array to store possible category weights.
    
    //Add a category to the random pool.
    do
    {
        decl String:temp[MAP_LENGTH]; //Buffer to store the name of the category.
        
        //Get the name of the category.
        KvGetSectionName(kv, temp, sizeof(temp));
        
        //Add the category to the random pool.
        PushArrayCell(weightArr, GetWeight(kv));
        PushArrayString(nameArr, temp);
        
        //One more category in the pool.
        index++;
    }
    while (KvGotoNextKey(kv)); //Do this for each category.

    //Return to the root level.
    KvGoBack(kv);
    
    //Fail if no categories are selectable.
    if (index == 0)
    {
        CloseHandle(nameArr);
        CloseHandle(weightArr);
        return false;
    }

    //Use weights to randomly select a category from the pool.
    new bool:result = GetWeightedRandomSubKey(buffer, size, weightArr, nameArr);
    
    //Close the pool.
    CloseHandle(nameArr);
    CloseHandle(weightArr);
    
    //Booyah!
    return result;
}