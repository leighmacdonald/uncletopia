/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                                Ultimate Mapchooser - Admin Menu                               *
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
#include <adminmenu>
#include <regex>

#undef REQUIRE_PLUGIN

#define AMMENU_ITEM_INDEX_AUTO 0
#define AMMENU_ITEM_INDEX_MANUAL 1
#define AMMENU_ITEM_INFO_AUTO "auto"
#define AMMENU_ITEM_INFO_MANUAL "manual"

#define VTMENU_ITEM_INDEX_MAP 0
#define VTMENU_ITEM_INDEX_GROUP 1
#define VTMENU_ITEM_INDEX_TIER 2
#define VTMENU_ITEM_INFO_MAP "map"
#define VTMENU_ITEM_INFO_GROUP "group"
#define VTMENU_ITEM_INFO_TIER "tier"

#define VOTE_POP_STOP_INFO "stop"

#define DMENU_ITEM_INDEX_DEFAULTS 0
#define DMENU_ITEM_INDEX_MANUAL 1
#define DMENU_ITEM_INFO_DEFAULTS "0"
#define DMENU_ITEM_INFO_MANUAL "1"

#define SMENU_ITEM_INFO_NO "no"
#define SMENU_ITEM_INFO_YES "yes"

#define TMENU_ITEM_INFO_DEFAULT "def"
#define TMENU_ITEM_INFO_PREV "prev"

#define FAMENU_ITEM_INFO_NOTHING "nothing"
#define FAMENU_ITEM_INFO_RUNOFF "runoff"

#define MRMENU_ITEM_INFO_DEFAULT "def"
#define MRMENU_ITEM_INFO_PREV "prev"

#define RFAMENU_ITEM_INFO_NOTHING "nothing"
#define RFAMENU_ITEM_INFO_ACCEPT "accept"

#define EMENU_ITEM_INFO_NO "no"
#define EMENU_ITEM_INFO_YES "yes"

#define DCMENU_ITEM_INFO_NO "no"
#define DCMENU_ITEM_INFO_YES "yes"

#define ADMINMENU_ADMINFLAG_KEY "adminmenu_flags"


//Plugin Information
public Plugin:myinfo =
{
    name        = "[UMC] Admin Menu",
    author      = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Adds an Ultimate Mapchooser entry in the SourceMod Admin Menu.",
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
new Handle:cvar_vote_startsound      = INVALID_HANDLE;
new Handle:cvar_vote_endsound        = INVALID_HANDLE;
new Handle:cvar_vote_catmem          = INVALID_HANDLE;
new Handle:cvar_dontchange           = INVALID_HANDLE;
new Handle:cvar_defaultsflags        = INVALID_HANDLE;
new Handle:cvar_flags                = INVALID_HANDLE;
new Handle:cvar_ignoreexcludeflags   = INVALID_HANDLE;
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

//Admin Menu
new Handle:admin_menu = INVALID_HANDLE;
//new TopMenuObject:umc_menu;

//Tries to store menu selections / build options.
new Handle:menu_tries[MAXPLAYERS];

//Flags for Chat Triggers
new bool:runoff_trigger[MAXPLAYERS];
new bool:runoff_menu_trigger[MAXPLAYERS];
new bool:threshold_trigger[MAXPLAYERS];
new bool:threshold_menu_trigger[MAXPLAYERS];

//Regex objects for chat triggers
new Handle:runoff_regex = INVALID_HANDLE;
new Handle:threshold_regex = INVALID_HANDLE;

//************************************************************************************************//
//                                        SOURCEMOD EVENTS                                        //
//************************************************************************************************//
//Called when the plugin is finished loading.
public OnPluginStart()
{
    cvar_ignoreexcludeflags = CreateConVar(
        "sm_umc_am_adminflags_exclude",
        "",
        "Flags required for admins to be able to select maps which would normally be excluded by UMC. If empty, all admins can select excluded maps."
    );
    
    cvar_defaultsflags = CreateConVar(
        "sm_umc_am_adminflags_default",
        "",
        "Flags required for admins to be able to manually select settings for the vote. If the admin does not have the proper priveleges, the vote will automatically use the cvars in this file. If empty, all admins have access."
    );
    
    cvar_flags = CreateConVar(
        "sm_umc_am_vote_adminflags",
        "",
        "Specifies which admin flags are necessary for a player to participate in a vote. If empty, all players can participate."
    );
    
    cvar_fail_action = CreateConVar(
        "sm_umc_am_failaction",
        "0",
        "Specifies what action to take if the vote doesn't reach the set theshold.\n 0 - Do Nothing,\n 1 - Perform Runoff Vote",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_fail_action = CreateConVar(
        "sm_umc_am_runoff_failaction",
        "0",
        "Specifies what action to take if the runoff vote reaches the maximum amount of runoffs and the set threshold has not been reached.\n 0 - Do Nothing,\n 1 - Change Map to Winner",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff_max = CreateConVar(
        "sm_umc_am_runoff_max",
        "0",
        "Specifies the maximum number of maps to appear in a runoff vote.\n 1 or 0 sets no maximum.",
        0, true, 0.0
    );

    cvar_vote_allowduplicates = CreateConVar(
        "sm_umc_am_allowduplicates",
        "1",
        "Allows a map to appear in the vote more than once. This should be enabled if you want the same map in different categories to be distinct.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_vote_threshold = CreateConVar(
        "sm_umc_am_threshold",
        "0",
        "If the winning option has less than this percentage of total votes, a vote will fail and the action specified in \"sm_umc_vc_failaction\" cvar will be performed.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_runoff = CreateConVar(
        "sm_umc_am_runoffs",
        "0",
        "Specifies a maximum number of runoff votes to run for a vote.\n 0 = unlimited.",
        0, true, 0.0
    );
    
    cvar_runoff_sound = CreateConVar(
        "sm_umc_am_runoff_sound",
        "",
        "If specified, this sound file (relative to sound folder) will be played at the beginning of a runoff vote. If not specified, it will use the normal vote start sound."
    );
    
    cvar_vote_catmem = CreateConVar(
        "sm_umc_am_groupexclude",
        "0",
        "Specifies how many past map groups to exclude from votes.",
        0, true, 0.0, true, 10.0
    );
    
    cvar_vote_startsound = CreateConVar(
        "sm_umc_am_startsound",
        "",
        "Sound file (relative to sound folder) to play at the start of a vote."
    );
    
    cvar_vote_endsound = CreateConVar(
        "sm_umc_am_endsound",
        "",
        "Sound file (relative to sound folder) to play at the completion of a vote."
    );
    
    cvar_strict_noms = CreateConVar(
        "sm_umc_am_nominate_strict",
        "0",
        "Specifies whether the number of nominated maps appearing in the vote for a map group should be limited by the group's \"maps_invote\" setting.",
        0, true, 0.0, true, 1.0
    );

    cvar_extend_rounds = CreateConVar(
        "sm_umc_am_extend_roundstep",
        "5",
        "Specifies how many more rounds each extension adds to the round limit.",
        0, true, 1.0
    );

    cvar_extend_time = CreateConVar(
        "sm_umc_am_extend_timestep",
        "15",
        "Specifies how many more minutes each extension adds to the time limit.",
        0, true, 1.0
    );

    cvar_extend_frags = CreateConVar(
        "sm_umc_am_extend_fragstep",
        "10",
        "Specifies how many more frags each extension adds to the frag limit.",
        0, true, 1.0
    );

    cvar_extensions = CreateConVar(
        "sm_umc_am_extend",
        "0",
        "Adds an \"Extend\" option to votes.",
        0, true, 0.0, true, 1.0
    );

    cvar_vote_time = CreateConVar(
        "sm_umc_am_duration",
        "20",
        "Specifies how long a vote should be available for.",
        0, true, 10.0
    );

    cvar_filename = CreateConVar(
        "sm_umc_am_cyclefile",
        "umc_mapcycle.txt",
        "File to use for Ultimate Mapchooser's map rotation."
    );

    cvar_vote_mem = CreateConVar(
        "sm_umc_am_mapexclude",
        "4",
        "Specifies how many past maps to exclude from votes. 1 = Current Map Only",
        0, true, 0.0, true, 10.0
    );

    cvar_scramble = CreateConVar(
        "sm_umc_am_menuscrambled",
        "0",
        "Specifies whether vote menu items are displayed in a random order.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_dontchange = CreateConVar(
        "sm_umc_am_dontchange",
        "1",
        "Adds a \"Don't Change\" option to votes.",
        0, true, 0.0, true, 1.0
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-adminmenu");
    
    //Make listeners for player chat. Needed to recognize chat input.
    AddCommandListener(OnPlayerChat, "say");
    AddCommandListener(OnPlayerChat, "say2"); //Insurgency Only
    AddCommandListener(OnPlayerChat, "say_team");
    
    //Initialize our memory arrays
    new numCells = ByteCountToCells(MAP_LENGTH);
    vote_mem_arr    = CreateArray(numCells);
    vote_catmem_arr = CreateArray(numCells);
    
    //Manually fire AdminMenu callback.
    new Handle:topmenu;
    if ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE)
    {
        OnAdminMenuReady(topmenu);
    }
    
    runoff_regex    = CompileRegex("^([0-9]+)\\s*$");
    threshold_regex = CompileRegex("^([0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)%?\\s*$");
    
    //Load the translations file
    LoadTranslations("ultimate-mapchooser.phrases");
    LoadTranslations("ultimate-mapchooser-adminmenu.phrases");
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
    
    //TODO -- Set to 11, add options in menus to specify a smaller amount
    //Add the map to all the memory queues.
    new mapmem = GetConVarInt(cvar_vote_mem);
    new catmem = GetConVarInt(cvar_vote_catmem);
    AddToMemoryArray(mapName, vote_mem_arr, mapmem); //11); 
    AddToMemoryArray(groupName, vote_catmem_arr, (mapmem > catmem) ? mapmem : catmem); //11);
    
    if (can_vote)
    {
        RemovePreviousMapsFromCycle();
    }
}

public OnMapStart()
{
    SetupVoteSounds();
}

//Called when a player types in chat
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
    
    if (threshold_trigger[client] && ProcessThresholdText(client, text))
    {
        return Plugin_Handled;
    }
    
    if (runoff_trigger[client] && ProcessRunoffText(client, text))
    {
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
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
//                                           ADMIN MENU                                           //
//************************************************************************************************//
//Sets up the admin menu when it is ready to be set up.
public OnAdminMenuReady(Handle:topmenu)
{
    //Block this from being called twice
    if (topmenu == admin_menu)
    {
        return;
    }
    
    //Setup menu...
    admin_menu = topmenu;
    
    new TopMenuObject:umc_menu = AddToTopMenu(
        admin_menu, "Ultimate Mapchooser", TopMenuObject_Category,
        Adm_CategoryHandler, INVALID_TOPMENUOBJECT
    );
    
    AddToTopMenu(
        admin_menu, "umc_changemap", TopMenuObject_Item, UMCMenu_ChangeMap,
        umc_menu, "umc_changemap", ADMFLAG_CHANGEMAP
    );
    
    AddToTopMenu(
        admin_menu, "umc_setnextmap", TopMenuObject_Item, UMCMenu_NextMap,
        umc_menu, "sm_umc_setnextmap", ADMFLAG_CHANGEMAP
    );
    
    AddToTopMenu(
        admin_menu, "umc_mapvote", TopMenuObject_Item, UMCMenu_MapVote,
        umc_menu, "sm_umc_startmapvote", ADMFLAG_CHANGEMAP
    );
}

//Handles the UMC category in the admin menu.
public Adm_CategoryHandler(Handle:topmenu, TopMenuAction:action, TopMenuObject:object_id, param, String:buffer[], maxlength)
{
    if (action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
    {
        strcopy(buffer, maxlength, "Ultimate Mapchooser");
    }
}

//Handles the Change Map option in the menu.
public UMCMenu_ChangeMap(Handle:topmenu, TopMenuAction:action, TopMenuObject:objectID, client,
                         String:buffer[], maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        FormatEx(buffer, maxlength, "%T", "AM Change Map", client);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        CreateAMChangeMap(client);
    }
}

//Handles the Change Map option in the menu.
public UMCMenu_NextMap(Handle:topmenu, TopMenuAction:action, TopMenuObject:objectID, client,
                       String:buffer[], maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        FormatEx(buffer, maxlength, "%T", "AM Set Next Map", client);
    }
    else if (action == TopMenuAction_SelectOption)
    {
        CreateAMNextMap(client);
    }
}

//Handles the Change Map option in the menu.
public UMCMenu_MapVote(Handle:topmenu, TopMenuAction:action, TopMenuObject:objectID, client, String:buffer[], maxlength)
{
    if (action == TopMenuAction_DisplayOption)
    {
        if (UMC_IsVoteInProgress("core")) //TODO FIXME
        {
            FormatEx(buffer, maxlength, "%T", "AM Stop Vote", client);
        }
        else
        {
            FormatEx(buffer, maxlength, "%T", "AM Start Vote", client);
        }
    }
    else if (action == TopMenuAction_SelectOption)
    {
        /*
        Order:
            1. Vote Type
            2. Auto/Manual
            --IF MANUAL--
                A. Pick Group/END
                --IF END--
                    I. Goto 3
                B. Pick Map
                C. Goto A
            3. Defaults/Override
            --IF OVERRIDE--
                A. Scramble
                B. Threshold
                C. Fail Action
                --IF RUNOFF--
                    I. Max Runoffs
                    II. Runoff Fail Action
                D. Extend Option
                E. Don't Change Option
            4. When
            
        Trie Structure: *incomplete*
        {
            int type
            bool auto
            adt_array maps
            bool defaults
            bool scramble
            Float threshold
            int fail_action
            int max_runoffs
            int runoff_fail_action
            bool extend
            bool dont_change
            int when
        }
        
        Trie "Methods":
            bool VoteAutoPopulated(client)
            bool RunoffIsEnabled(client)
            bool UsingDefaults(client)
        */
        
        if (UMC_IsVoteInProgress("core")) //TODO FIXME
        {
            UMC_StopVote("core"); //TODO FIXME
            RedisplayAdminMenu(topmenu, client);
        }
        else
        {
            menu_tries[client] = CreateVoteMenuTrie(client);
            DisplayVoteTypeMenu(client);
        }
    }
}

Handle:CreateVoteMenuTrie(client)
{
    new Handle:trie = CreateTrie();
    new Handle:mapList = CreateArray();
    SetTrieValue(trie, "maps", mapList);
    
    new bool:ignoreExclude = false;
    decl String:flags[64];
    GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
    
    if (flags[0] != '\0')
    {
        if (ReadFlagString(flags) & GetUserFlagBits(client))
        {
            ignoreExclude = true;
        }
    }
    else
    {
        ignoreExclude = true;
    }
    
    SetTrieValue(trie, "ignore_exclusion", ignoreExclude);
    return trie;
}

DisplayVoteTypeMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_VoteType, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Vote Type");
    
    AddMenuItem(menu, VTMENU_ITEM_INFO_MAP, "Maps");
    AddMenuItem(menu, VTMENU_ITEM_INFO_GROUP, "Groups");
    AddMenuItem(menu, VTMENU_ITEM_INFO_TIER, "Tiered");
    
    DisplayMenu(menu, client, 0);
}

public Handle_MenuTranslation(Handle:menu, MenuAction:action, client, param2)
{
    switch(action)
    {
        case MenuAction_Display:
        {
            new Handle:panel = Handle:param2;
            
            decl String:translation[256];
            GetMenuTitle(menu, translation, sizeof(translation));
            
            if (strlen(translation) > 0)
            {
                decl String:buffer[256];
                FormatEx(buffer, sizeof(buffer), "%T", translation, client);
                
                SetPanelTitle(panel, buffer);
            }
        }
        case MenuAction_DisplayItem:
        {
            decl String:info[256], String:display[256];
            GetMenuItem(menu, param2, info, sizeof(info), _, display, sizeof(display));
            
            if (strlen(display) > 0)
            {
                decl String:buffer[255];
                FormatEx(buffer, sizeof(buffer), "%T", display, client);
                    
                return RedrawMenuItem(buffer);
            }
        }
    }
    return 0;
}

public HandleMV_VoteType(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            SetTrieValue(menu_tries[param1], "type", param2);
            DisplayAutoManualMenu(param1);
        }
        case MenuAction_Cancel:
        {
            CloseClientVoteTrie(param1);
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

DisplayAutoManualMenu(client)
{
    new Handle:menu = CreateAutoManualMenu(HandleMV_AutoManual, "AM Populate Vote");
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 0);
}

public HandleMV_AutoManual(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case AMMENU_ITEM_INDEX_AUTO:
                {
                    AutoBuildVote(param1, true);
                    DisplayDefaultsMenu(param1);
                }
                case AMMENU_ITEM_INDEX_MANUAL:
                {
                    AutoBuildVote(param1, false);
                    DisplayGroupSelectMenu(param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                DisplayVoteTypeMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

AutoBuildVote(client, bool:value)
{
    SetTrieValue(menu_tries[client], "auto", value);
}

CloseClientVoteTrie(client)
{
    new Handle:trie = menu_tries[client];
    menu_tries[client] = INVALID_HANDLE;
    
    new Handle:mapList;
    GetTrieValue(trie, "maps", mapList);
    ClearHandleArray(mapList);
    CloseHandle(mapList);
    
    CloseHandle(trie);
}

DisplayGroupSelectMenu(client)
{
    new bool:ignoreLimits;
    GetTrieValue(menu_tries[client], "ignore_exclusion", ignoreLimits);
    
    new Handle:menu = CreateGroupMenu(HandleMV_Groups, !ignoreLimits, client);
    
    new Handle:voteArray;
    GetTrieValue(menu_tries[client], "maps", voteArray);
    if (GetArraySize(voteArray) > 1)
    {
        InsertMenuItem(menu, 0, VOTE_POP_STOP_INFO, "Stop Adding Maps"); //TODO: Make Translation
    }
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_Groups(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            decl String:group[MAP_LENGTH];
            GetMenuItem(menu, param2, group, sizeof(group));
            
            if (StrEqual(group, VOTE_POP_STOP_INFO))
            {
                decl String:flags[64];
                GetConVarString(cvar_defaultsflags, flags, sizeof(flags));
                
                if (!ClientHasAdminFlags(param1, flags))
                {
                    UseVoteDefaults(param1);
                    DisplayChangeWhenMenu(param1);
                }
                else
                {
                    DisplayDefaultsMenu(param1);
                }
            }
            else
            {
                SetTrieString(menu_tries[param1], "group", group);   
                DisplayMapSelectMenu(param1, group);
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                DisplayAutoManualMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }    
    return 0;
}

DisplayMapSelectMenu(client, const String:group[])
{
    new bool:ignoreLimits;
    GetTrieValue(menu_tries[client], "ignore_exclusion", ignoreLimits);
    
    new Handle:newMenu = CreateMapMenu(HandleMV_Maps, group, !ignoreLimits, client);
    DisplayMenu(newMenu, client, 0);
}

public HandleMV_Maps(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            decl String:map[MAP_LENGTH], String:group[MAP_LENGTH];
            GetMenuItem(menu, param2, map, sizeof(map));
            GetTrieString(menu_tries[param1], "group", group, sizeof(group));
            
            AddToVoteList(param1, map, group);
            
            DisplayGroupSelectMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                DisplayGroupSelectMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
}

AddToVoteList(client, const String:map[], const String:group[])
{
    new Handle:mapTrie = CreateMapTrie(map, group);
    new Handle:mapList;
    GetTrieValue(menu_tries[client], "maps", mapList);
    PushArrayCell(mapList, mapTrie);
}

DisplayDefaultsMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_Defaults, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Vote Settings");
    
    AddMenuItem(menu, DMENU_ITEM_INFO_DEFAULTS, "AM-VS Defaults");
    AddMenuItem(menu, DMENU_ITEM_INFO_MANUAL, "Manually Choose");
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_Defaults(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case DMENU_ITEM_INDEX_DEFAULTS:
                {
                    UseVoteDefaults(param1);
                    DisplayChangeWhenMenu(param1);
                }
                case DMENU_ITEM_INDEX_MANUAL:
                {
                    SetTrieValue(menu_tries[param1], "defaults", false);
                    DisplayScrambleMenu(param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                if (VoteAutoPopulated(param1))
                    DisplayAutoManualMenu(param1);
                else
                    DisplayGroupSelectMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

UseVoteDefaults(client)
{
    new Handle:trie = menu_tries[client];
    
    SetTrieValue(trie, "defaults", true);
    
    SetTrieValue(trie, "scramble",           GetConVarBool(cvar_scramble));
    SetTrieValue(trie, "extend",             GetConVarBool(cvar_extensions));
    SetTrieValue(trie, "dont_change",        GetConVarBool(cvar_dontchange));
    SetTrieValue(trie, "threshold",          GetConVarFloat(cvar_vote_threshold));
    SetTrieValue(trie, "fail_action",        GetConVarInt(cvar_fail_action));
    SetTrieValue(trie, "runoff_fail_action", GetConVarInt(cvar_runoff_fail_action));
    SetTrieValue(trie, "max_runoffs",        GetConVarInt(cvar_runoff));
    
    decl String:flags[64];
    GetConVarString(cvar_flags, flags, sizeof(flags));
    SetTrieString(trie, "flags", flags);
}

bool:VoteAutoPopulated(client)
{
    new bool:autoPop;
    GetTrieValue(menu_tries[client], "auto", autoPop);
    
    return autoPop;
}

DisplayScrambleMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_Scramble, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Scramble Menu");
    
    if (GetConVarBool(cvar_scramble))
    {
        AddMenuItem(menu, SMENU_ITEM_INFO_NO, "No");
        AddMenuItem(menu, SMENU_ITEM_INFO_YES, "Default Yes");
    }
    else
    {
        AddMenuItem(menu, SMENU_ITEM_INFO_NO, "Default No");
        AddMenuItem(menu, SMENU_ITEM_INFO_YES, "Yes");
    }
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_Scramble(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            SetTrieValue(menu_tries[param1], "scramble", param2);
        
            DisplayThresholdMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                decl String:flags[64];
                GetConVarString(cvar_defaultsflags, flags, sizeof(flags));
                
                if (!ClientHasAdminFlags(param1, flags))
                {
                    if (VoteAutoPopulated(param1))
                    {
                        DisplayAutoManualMenu(param1);
                    }
                    else
                    {
                        DisplayGroupSelectMenu(param1);
                    }
                }
                else
                {
                    DisplayDefaultsMenu(param1);
                }
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

DisplayThresholdMenu(client)
{
    threshold_trigger[client] = true;
    
    new Handle:menu = CreateMenu(HandleMV_Threshold, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Threshold Menu");
    
    AddMenuItem(menu, "", "AM Threshold Menu Message 1", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "", "AM Threshold Menu Message 2", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "", "", ITEMDRAW_SPACER);
    
    new Float:threshold;
    if (GetTrieValue(menu_tries[client], "threshold", threshold))
    {
        decl String:fmt2[20];
        FormatEx(fmt2, sizeof(fmt2), "%.f%% (previously entered)", threshold * 100);
        AddMenuItem(menu, TMENU_ITEM_INFO_PREV, fmt2);
    }
    
    decl String:fmt[20];
    FormatEx(fmt, sizeof(fmt), "%.f%% (default)", GetConVarFloat(cvar_vote_threshold) * 100);
    AddMenuItem(menu, TMENU_ITEM_INFO_DEFAULT, fmt);
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_Threshold(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            threshold_trigger[param1] = false;
            
            decl String:info[255];
            GetMenuItem(menu, param2, info, sizeof(info));
            
            if (StrEqual(info, TMENU_ITEM_INFO_DEFAULT))
            {
                SetTrieValue(menu_tries[param1], "threshold", GetConVarFloat(cvar_vote_threshold));
            }
            DisplayFailActionMenu(param1);
        }
        case MenuAction_Cancel:
        {
            threshold_trigger[param1] = false;
            
            if (!threshold_menu_trigger[param1])
            {
                if (param2 == MenuCancel_ExitBack)
                {
                    DisplayScrambleMenu(param1);
                }
                else
                {
                    CloseClientVoteTrie(param1);
                }
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
        case MenuAction_DisplayItem:
        {
            decl String:info[256], String:disp[256];
            GetMenuItem(menu, param2, info, sizeof(info), _, disp, sizeof(disp));
        
            if (StrEqual(info, TMENU_ITEM_INFO_PREV))
            {
                new Float:threshold;
                GetTrieValue(menu_tries[param1], "threshold", threshold);
            
                decl String:buffer[255];
                FormatEx(buffer, sizeof(buffer), "%.f%% (%T)", threshold * 100, "Previously Entered", param1);

                return RedrawMenuItem(buffer);
            }
            else if (StrEqual(info, TMENU_ITEM_INFO_DEFAULT))
            {
                decl String:buffer[255];
                FormatEx(buffer, sizeof(buffer), "%.f%% (%T)", GetConVarFloat(cvar_vote_threshold) * 100, "Default", param1);
                    
                return RedrawMenuItem(buffer);
            }
            else if (strlen(disp) > 0)
            {
                return Handle_MenuTranslation(menu, action, param1, param2);
            }
        }
    }
    return 0;
}

bool:ProcessThresholdText(client, const String:text[])
{
    decl String:num[20];
    new Float:percent;
    if (MatchRegex(threshold_regex, text))
    {
        GetRegexSubString(threshold_regex, 1, num, sizeof(num));
        percent = StringToFloat(num);
        
        if (percent <= 100.0 && percent >= 0.0)
        {
            SetTrieValue(menu_tries[client], "threshold", percent / 100.0);
            CancelThresholdMenu(client);
            DisplayFailActionMenu(client);
            return true;
        }
    }
    return false;
}

CancelThresholdMenu(client)
{
    threshold_menu_trigger[client] = true;
    CancelClientMenu(client);
    threshold_menu_trigger[client] = false;
}

DisplayFailActionMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_FailAction, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Fail Action Menu");
    
    if (GetConVarBool(cvar_fail_action))
    {
        AddMenuItem(menu, FAMENU_ITEM_INFO_NOTHING, "Do Nothing");
        AddMenuItem(menu, FAMENU_ITEM_INFO_RUNOFF, "Default Perform Runoff Vote");
    }
    else
    {
        AddMenuItem(menu, FAMENU_ITEM_INFO_NOTHING, "Default Do Nothing");
        AddMenuItem(menu, FAMENU_ITEM_INFO_RUNOFF, "Perform Runoff Vote");
    }
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_FailAction(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            SetTrieValue(menu_tries[param1], "fail_action", param2);
            
            switch (UMC_VoteFailAction:param2)
            {
                case VoteFailAction_Nothing:
                {
                    DisplayExtendMenu(param1);
                }
                case VoteFailAction_Runoff:
                {
                    DisplayMaxRunoffMenu(param1);
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                DisplayThresholdMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

DisplayMaxRunoffMenu(client)
{
    runoff_trigger[client] = true;
    
    new Handle:menu = CreateMenu(HandleMV_MaxRunoff, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Max Runoff Menu");
    
    AddMenuItem(menu, "", "AM Max Runoff Menu Message 1", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "", "AM Max Runoff Menu Message 2", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "", "AM Max Runoff Menu Message 3", ITEMDRAW_DISABLED);
    AddMenuItem(menu, "", "", ITEMDRAW_SPACER);
    
    new runoffs;
    if (GetTrieValue(menu_tries[client], "max_runoffs", runoffs))
    {
        decl String:fmt2[20];
        FormatEx(fmt2, sizeof(fmt2), "%i (previously entered)", runoffs);
        AddMenuItem(menu, MRMENU_ITEM_INFO_PREV, fmt2);
    }
    
    decl String:fmt[20];
    FormatEx(fmt, sizeof(fmt), "%i (default)", GetConVarInt(cvar_runoff_max));
    AddMenuItem(menu, MRMENU_ITEM_INFO_DEFAULT, fmt);
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_MaxRunoff(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            runoff_trigger[param1] = false;
            
            decl String:info[255];
            GetMenuItem(menu, param2, info, sizeof(info));
            
            if (StrEqual(info, MRMENU_ITEM_INFO_DEFAULT))
            {
                SetTrieValue(menu_tries[param1], "max_runoffs", GetConVarInt(cvar_runoff_max));
            }
            //TODO:
            //I don't think I need to handle the case where we reselect the previously entered amount,
            //since it should already be stored in the trie.
        
            DisplayRunoffFailActionMenu(param1);
        }
        case MenuAction_Cancel:
        {
            runoff_trigger[param1] = false;
            
            if (!runoff_menu_trigger[param1])
            {
                if (param2 == MenuCancel_ExitBack)
                {
                    DisplayFailActionMenu(param1);
                }
                else
                {
                    CloseClientVoteTrie(param1);
                }
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
        case MenuAction_DisplayItem:
        {
            decl String:info[256];
            GetMenuItem(menu, param2, info, sizeof(info));
        
            if (StrEqual(info, MRMENU_ITEM_INFO_PREV))
            {
                new maxrunoffs;
                GetTrieValue(menu_tries[param1], "max_runoffs", maxrunoffs);
            
                decl String:buffer[255];
                FormatEx(buffer, sizeof(buffer), "%i (%T)", maxrunoffs, "Previously Entered", param1);
                    
                return RedrawMenuItem(buffer);
            }
            else if (StrEqual(info, MRMENU_ITEM_INFO_DEFAULT))
            {
                decl String:buffer[255];
                FormatEx(buffer, sizeof(buffer), "%i (%T)", GetConVarInt(cvar_runoff_max), "Default", param1);
                    
                return RedrawMenuItem(buffer);
            }
            else
            {
                return Handle_MenuTranslation(menu, action, param1, param2);
            }
        }
    }
    return 0;
}

bool:ProcessRunoffText(client, const String:text[])
{
    decl String:num[20];
    new amt;
    if (MatchRegex(runoff_regex, text))
    {
        GetRegexSubString(runoff_regex, 1, num, sizeof(num));
        amt = StringToInt(num);
        
        if (amt >= 0)
        {
            SetTrieValue(menu_tries[client], "max_runoffs", amt);
            CancelRunoffMenu(client);
            DisplayRunoffFailActionMenu(client);
            return true;
        }
    }
    return false;
}

CancelRunoffMenu(client)
{
    runoff_menu_trigger[client] = true;
    CancelClientMenu(client);
    runoff_menu_trigger[client] = false;        
}

DisplayRunoffFailActionMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_RunoffFailAction, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Runoff Fail Action Menu");
    
    if (GetConVarBool(cvar_runoff_fail_action))
    {
        AddMenuItem(menu, RFAMENU_ITEM_INFO_NOTHING, "Do Nothing");
        AddMenuItem(menu, RFAMENU_ITEM_INFO_ACCEPT, "Default Accept Winner");
    }
    else
    {
        AddMenuItem(menu, RFAMENU_ITEM_INFO_NOTHING, "Default Do Nothing");
        AddMenuItem(menu, RFAMENU_ITEM_INFO_ACCEPT, "Accept Winner");
    }
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_RunoffFailAction(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            SetTrieValue(menu_tries[param1], "runoff_fail_action", param2);
            
            DisplayExtendMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                DisplayMaxRunoffMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

DisplayExtendMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_Extend, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Extend Menu");
    
    if (GetConVarBool(cvar_extensions))
    {
        AddMenuItem(menu, EMENU_ITEM_INFO_NO, "No");
        AddMenuItem(menu, EMENU_ITEM_INFO_YES, "Default Yes");
    }
    else
    {
        AddMenuItem(menu, EMENU_ITEM_INFO_NO, "Default No");
        AddMenuItem(menu, EMENU_ITEM_INFO_YES, "Yes");
    }
    
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, client, 0);
}

public HandleMV_Extend(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            SetTrieValue(menu_tries[param1], "extend", param2);
            
            DisplayDontChangeMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                if (RunoffIsEnabled(param1))
                {
                    DisplayMaxRunoffMenu(param1);
                }
                else
                {
                    DisplayFailActionMenu(param1);
                }
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

bool:RunoffIsEnabled(client)
{
    new UMC_VoteFailAction:failAction;
    GetTrieValue(menu_tries[client], "fail_action", failAction);

    return failAction == VoteFailAction_Runoff;
}

DisplayDontChangeMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_DontChange, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Don't Change Menu");
    
    if (GetConVarBool(cvar_dontchange))
    {
        AddMenuItem(menu, DCMENU_ITEM_INFO_NO, "No");
        AddMenuItem(menu, DCMENU_ITEM_INFO_YES, "Default Yes");
    }
    else
    {
        AddMenuItem(menu, DCMENU_ITEM_INFO_NO, "Default No");
        AddMenuItem(menu, DCMENU_ITEM_INFO_YES, "Yes");
    }
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_DontChange(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            new Handle:trie = menu_tries[param1];
            SetTrieValue(trie, "dont_change", param2);
            
            decl String:flags[64];
            GetConVarString(cvar_flags, flags, sizeof(flags));
            
            if (flags[0] != '\0')
            {
                SetTrieValue(trie, "skip_admin", false);
                DisplayAdminFlagsMenu(param1);
            }
            else
            {
                SkipAdminFlags(param1);
                DisplayChangeWhenMenu(param1);
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                DisplayExtendMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

SkipAdminFlags(client)
{
    new Handle:trie = menu_tries[client];
    SetTrieString(trie, "flags", "");
    SetTrieValue(trie, "skip_admin", true);
}

bool:SkippingAdminFlags(client)
{
    new bool:result;
    return GetTrieValue(menu_tries[client], "skip_admin", result) && result;
}

DisplayAdminFlagsMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_AdminFlags, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Admin Flag Menu");
    
    decl String:flags[64];
    GetConVarString(cvar_flags, flags, sizeof(flags));
    
    AddMenuItem(menu, "", "Everyone");
    AddMenuItem(menu, flags, "Admins Only");
    
    SetMenuExitBackButton(menu, true);
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_AdminFlags(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            decl String:info[64];
            GetMenuItem(menu, param2, info, sizeof(info));
            
            SetTrieString(menu_tries[param1], "flags", info);
            
            DisplayChangeWhenMenu(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                DisplayDontChangeMenu(param1);
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

DisplayChangeWhenMenu(client)
{
    new Handle:menu = CreateMenu(HandleMV_When, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Change When Menu");
    
    SetMenuExitBackButton(menu, true);

    decl String:info1[2];
    FormatEx(info1, sizeof(info1), "%i", ChangeMapTime_Now);
    AddMenuItem(menu, info1, "Now");
    
    decl String:info2[2];
    FormatEx(info2, sizeof(info2), "%i", ChangeMapTime_RoundEnd);
    AddMenuItem(menu, info2, "End of Round");
    
    decl String:info3[2];
    FormatEx(info3, sizeof(info3), "%i", ChangeMapTime_MapEnd);
    AddMenuItem(menu, info3, "End of Map");
    
    DisplayMenu(menu, client, 0);
}

public HandleMV_When(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            decl String:info[2];
            GetMenuItem(menu, param2, info, sizeof(info));
            
            SetTrieValue(menu_tries[param1], "when", StringToInt(info));
            
            DoMapVote(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                if (UsingDefaults(param1))
                {
                    decl String:flags[64];
                    GetConVarString(cvar_defaultsflags, flags, sizeof(flags));
                    
                    if (!ClientHasAdminFlags(param1, flags))
                    {
                        if (VoteAutoPopulated(param1))
                        {
                            DisplayAutoManualMenu(param1);
                        }
                        else
                        {
                            DisplayGroupSelectMenu(param1);
                        }
                    }
                    else
                    {
                        DisplayDefaultsMenu(param1);
                    }
                }
                else
                {
                    if (SkippingAdminFlags(param1))
                    {
                        DisplayDontChangeMenu(param1);
                    }
                    else
                    {
                        DisplayAdminFlagsMenu(param1);
                    }
                }
            }
            else
            {
                CloseClientVoteTrie(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

bool:UsingDefaults(client)
{
    new bool:defaults;
    GetTrieValue(menu_tries[client], "defaults", defaults);
    
    return defaults;
}

DoMapVote(client)
{
    new Handle:trie = menu_tries[client];
    new Handle:selectedMaps;
    
    new UMC_VoteType:type, bool:scramble, bool:extend, bool:dontChange, Float:threshold,
        UMC_ChangeMapTime:when, UMC_VoteFailAction:failAction, runoffs,
        UMC_RunoffFailAction:runoffFailAction;
        
    decl String:flags[64];
    
    new bool:ignoreExclusion;
        
    GetTrieValue(trie, "maps", selectedMaps);

    new bool:autoPop = VoteAutoPopulated(client);
    new Handle:mapcycle = autoPop ? map_kv : CreateVoteKV(selectedMaps);

    GetTrieValue(trie, "type",               type);
    GetTrieValue(trie, "scramble",           scramble);
    GetTrieValue(trie, "extend",             extend);
    GetTrieValue(trie, "dont_change",        dontChange);
    GetTrieValue(trie, "threshold",          threshold);
    GetTrieValue(trie, "when",               when);
    GetTrieValue(trie, "fail_action",        failAction);
    GetTrieValue(trie, "runoff_fail_action", runoffFailAction);
    GetTrieValue(trie, "max_runoffs",        runoffs);
    
    GetTrieString(trie, "flags", flags, sizeof(flags));
    
    new clients[MAXPLAYERS+1];
    new numClients;
    GetClientsWithFlags(flags, clients, sizeof(clients), numClients);
    
    GetTrieValue(trie, "ignore_exclusion", ignoreExclusion);
    
    CloseClientVoteTrie(client);

    UMC_StartVote(
        "core",
        mapcycle, umc_mapcycle, type, GetConVarInt(cvar_vote_time), scramble, vote_start_sound,
        vote_end_sound, extend, GetConVarFloat(cvar_extend_time), GetConVarInt(cvar_extend_rounds),
        GetConVarInt(cvar_extend_frags), dontChange, threshold, when, failAction, runoffs,
        GetConVarInt(cvar_runoff_max), runoffFailAction, runoff_sound,
        GetConVarBool(cvar_strict_noms), GetConVarBool(cvar_vote_allowduplicates), clients, 
        numClients, !ignoreExclusion
    );
    
    if (!autoPop)
    {
        CloseHandle(mapcycle);
    }
}

Handle:CreateVoteKV(Handle:maps)
{
    new Handle:result = CreateKeyValues("umc_rotation");
    KvRewind(map_kv);
    KvCopySubkeys(map_kv, result);
    
    if (!KvGotoFirstSubKey(result))
    {
        return result;
    }
    
    decl String:group[MAP_LENGTH];
    decl String:map[MAP_LENGTH];
    new bool:goBackMap;
    new bool:goBackGroup = true;
    new groupMapCount;
    for ( ; ; )
    {
        groupMapCount = 0;
        goBackMap = true;
    
        KvGetSectionName(result, group, sizeof(group));
        
        if (!KvGotoFirstSubKey(result))
        {
            if (!KvGotoNextKey(result))
            {
                break;
            }
            continue;
        }
 
        for ( ; ; )
        {
            KvGetSectionName(result, map, sizeof(map));
            
            if (!FindMapInList(maps, map, group))
            {
                if (KvDeleteThis(result) == -1)
                {
                    goBackMap = false;
                    break;
                }
                else
                {
                    continue;
                }
            }
            else
            {
                groupMapCount++;
            }
            
            if (!KvGotoNextKey(result))
            {
                break;
            }
        }
        
        if (goBackMap)
        {
            KvGoBack(result);
        }
        
        if (!KvGotoFirstSubKey(result))
        {
            if (KvDeleteThis(result) == -1)
            {
                goBackGroup = false;
                break;
            }
            else
            {
                continue;
            }
        }
        else
        {
            KvGoBack(result);
            KvSetNum(result, "maps_invote", groupMapCount);
        }
            
        if (!KvGotoNextKey(result))
        {
            break;
        }
    }
    
    if (goBackGroup)
    {
        KvGoBack(result);
    }
    
    return result;
}

bool:FindMapInList(Handle:maps, const String:map[], const String:group[])
{
    decl String:gBuffer[MAP_LENGTH], String:mBuffer[MAP_LENGTH];
    new Handle:trie;
    new size = GetArraySize(maps);
    for (new i = 0; i < size; i++)
    {
        trie = GetArrayCell(maps, i);
        GetTrieString(trie, MAP_TRIE_MAP_KEY, mBuffer, sizeof(mBuffer));
        if (StrEqual(mBuffer, map, false))
        {
            GetTrieString(trie, MAP_TRIE_GROUP_KEY, gBuffer, sizeof(gBuffer));
            if (StrEqual(gBuffer, group, false))
            {
                return true;
            }
        }
    }
    return false;
}

CreateAMNextMap(client)
{
    new Handle:menu = CreateAutoManualMenu(HandleAM_NextMap, "Select A Map");
    DisplayMenu(menu, client, 0);
}

CreateAMChangeMap(client)
{
    new Handle:menu = CreateAutoManualMenu(HandleAM_ChangeMap, "Select A Map");
    DisplayMenu(menu, client, 0);
}

public HandleAM_ChangeMap(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == AMMENU_ITEM_INDEX_AUTO)
            {
                AutoChangeMap(param1);
            }
            else
            {
                ManualChangeMap(param1);
            }
        }
        case MenuAction_Cancel:
        {
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

ManualChangeMap(client)
{
    menu_tries[client] = CreateTrie();
    
    new bool:ignoreExclude = false;
    decl String:flags[64];
    GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
    
    if (flags[0] != '\0')
    {
        if (ReadFlagString(flags) & GetUserFlagBits(client))
        {
            ignoreExclude = true;
        }
    }
    else
    {
        ignoreExclude = true;
    }
    
    new Handle:menu = CreateGroupMenu(HandleGM_ChangeMap, !ignoreExclude, client);
    DisplayMenu(menu, client, 0);
}

public HandleGM_ChangeMap(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            decl String:group[MAP_LENGTH];
            GetMenuItem(menu, param2, group, sizeof(group));
            
            SetTrieString(menu_tries[param1], "group", group);
            
            new bool:ignoreExclude = false;
            decl String:flags[64];
            GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
            
            if (flags[0] != '\0')
            {
                if (ReadFlagString(flags) & GetUserFlagBits(param1))
                {
                    ignoreExclude = true;
                }
            }
            else
            {
                ignoreExclude = true;
            }
            
            new Handle:newMenu = CreateMapMenu(HandleMM_ChangeMap, group, !ignoreExclude, param1);
            DisplayMenu(newMenu, param1, 0);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                CreateAMChangeMap(param1);
            }
            else
            {
                CloseHandle(menu_tries[param1]);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
}

public HandleMM_ChangeMap(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            decl String:map[MAP_LENGTH];
            GetMenuItem(menu, param2, map, sizeof(map));
            
            SetTrieString(menu_tries[param1], "map", map);
            
            ManualChangeMapWhen(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                new bool:ignoreExclude = false;
                decl String:flags[64];
                GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
                
                if (flags[0] != '\0')
                {
                    if (ReadFlagString(flags) & GetUserFlagBits(param1))
                    {
                        ignoreExclude = true;
                    }
                }
                else
                {
                    ignoreExclude = true;
                }
            
                new Handle:newMenu = CreateGroupMenu(HandleGM_ChangeMap, !ignoreExclude, param1);
                DisplayMenu(newMenu, param1, 0);
            }
            else
            {
                CloseHandle(menu_tries[param1]);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
}

ManualChangeMapWhen(client)
{
    new Handle:menu = CreateMenu(Handle_ManualChangeWhenMenu, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Change When Menu");
    
    SetMenuExitBackButton(menu, true);

    decl String:info1[2];
    FormatEx(info1, sizeof(info1), "%i", ChangeMapTime_Now);
    AddMenuItem(menu, info1, "Now");
    
    decl String:info2[2];
    FormatEx(info2, sizeof(info2), "%i", ChangeMapTime_RoundEnd);
    AddMenuItem(menu, info2, "End of Round");
    
    DisplayMenu(menu, client, 0);
}

public Handle_ManualChangeWhenMenu(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            decl String:info[2];
            GetMenuItem(menu, param2, info, sizeof(info));
            
            SetTrieValue(menu_tries[param1], "when", StringToInt(info));
            DoManualMapChange(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                new bool:ignoreExclude = false;
                decl String:flags[64];
                GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
                
                if (flags[0] != '\0')
                {
                    if (ReadFlagString(flags) & GetUserFlagBits(param1))
                    {
                        ignoreExclude = true;
                    }
                }
                else
                {
                    ignoreExclude = true;
                }
            
                new Handle:newMenu = CreateGroupMenu(HandleGM_ChangeMap, !ignoreExclude, param1);
                DisplayMenu(newMenu, param1, 0);
            }
            else
            {
                CloseHandle(menu_tries[param1]);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

DoManualMapChange(client)
{
    new Handle:trie = menu_tries[client];
    
    decl String:nextMap[MAP_LENGTH], String:nextGroup[MAP_LENGTH];
    new when;
    
    GetTrieString(trie, "map", nextMap, sizeof(nextMap));
    GetTrieString(trie, "group", nextGroup, sizeof(nextGroup));
    GetTrieValue(trie, "when", when);
    
    CloseHandle(trie);
    
    DoMapChange(client, UMC_ChangeMapTime:when, nextMap, nextGroup);
}

AutoChangeMap(client)
{
    new Handle:menu = CreateMenu(Handle_AutoChangeWhenMenu, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "AM Change When Menu");
    
    SetMenuExitBackButton(menu, true);

    decl String:info1[2];
    FormatEx(info1, sizeof(info1), "%i", ChangeMapTime_Now);
    AddMenuItem(menu, info1, "Now");
    
    decl String:info2[2];
    FormatEx(info2, sizeof(info2), "%i", ChangeMapTime_RoundEnd);
    AddMenuItem(menu, info2, "End of Round");
    
    DisplayMenu(menu, client, 0);
}

public Handle_AutoChangeWhenMenu(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            decl String:info[2];
            GetMenuItem(menu, param2, info, sizeof(info));
            
            DoAutoMapChange(param1, UMC_ChangeMapTime:StringToInt(info));
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                CreateAMChangeMap(param1);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

DoAutoMapChange(client, UMC_ChangeMapTime:when)
{
    decl String:nextMap[MAP_LENGTH], String:nextGroup[MAP_LENGTH];
    if (UMC_GetRandomMap(map_kv, umc_mapcycle, INVALID_GROUP, nextMap, sizeof(nextMap), nextGroup, sizeof(nextGroup), false, true))
    {
        DoMapChange(client, when, nextMap, nextGroup);
    }
    else
    {
        LogError("Could not automatically change the map, no valid maps available.");
    }
}

DoMapChange(client, UMC_ChangeMapTime:when, const String:map[], const String:group[])
{
    UMC_SetNextMap(map_kv, map, group, when);
    LogUMCMessage("%L set the next map to %s from group %s.", client, map, group);
}

public HandleAM_NextMap(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == AMMENU_ITEM_INDEX_AUTO)
            {
                AutoNextMap(param1);
            }
            else
            {
                ManualNextMap(param1);
            }
        }
        case MenuAction_Cancel:
        {   
            // Do Nothing
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
    return Handle_MenuTranslation(menu, action, param1, param2);
}

ManualNextMap(client)
{
    menu_tries[client] = CreateTrie();
    
    new bool:ignoreExclude = false;
    decl String:flags[64];
    GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
    
    if (flags[0] != '\0')
    {
        if (ReadFlagString(flags) & GetUserFlagBits(client))
        {
            ignoreExclude = true;
        }
    }
    else
    {
        ignoreExclude = true;
    }
    
    new Handle:menu = CreateGroupMenu(HandleGM_NextMap, !ignoreExclude, client);
    DisplayMenu(menu, client, 0);
}

public HandleGM_NextMap(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            decl String:group[MAP_LENGTH];
            GetMenuItem(menu, param2, group, sizeof(group));
            
            SetTrieString(menu_tries[param1], "group", group);
            
            new bool:ignoreExclude = false;
            decl String:flags[64];
            GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
            
            if (flags[0] != '\0')
            {
                if (ReadFlagString(flags) & GetUserFlagBits(param1))
                {
                    ignoreExclude = true;
                }
            }
            else
            {
                ignoreExclude = true;
            }
            
            new Handle:newMenu = CreateMapMenu(HandleMM_NextMap, group, !ignoreExclude, param1);
            DisplayMenu(newMenu, param1, 0);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                CreateAMNextMap(param1);
            }
            else
            {
                CloseHandle(menu_tries[param1]);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
}

public HandleMM_NextMap(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Display:
        {
            Handle_MenuTranslation(menu, action, param1, param2);
        }
        case MenuAction_Select:
        {
            decl String:map[MAP_LENGTH];
            GetMenuItem(menu, param2, map, sizeof(map));
            
            SetTrieString(menu_tries[param1], "map", map);
            
            DoManualNextMap(param1);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                new bool:ignoreExclude = false;
                decl String:flags[64];
                GetConVarString(cvar_ignoreexcludeflags, flags, sizeof(flags));
                
                if (flags[0] != '\0')
                {
                    if (ReadFlagString(flags) & GetUserFlagBits(param1))
                    {
                        ignoreExclude = true;
                    }
                }
                else
                {
                    ignoreExclude = true;
                }
            
                new Handle:newMenu = CreateGroupMenu(HandleGM_ChangeMap, !ignoreExclude, param1);
                DisplayMenu(newMenu, param1, 0);
            }
            else
            {
                CloseHandle(menu_tries[param1]);
            }
        }
        case MenuAction_End:
        {
            CloseHandle(menu);
        }
    }
}

DoManualNextMap(client)
{
    new Handle:trie = menu_tries[client];
    
    decl String:nextMap[MAP_LENGTH], String:nextGroup[MAP_LENGTH];
    GetTrieString(trie, "map", nextMap, sizeof(nextMap));
    GetTrieString(trie, "group", nextGroup, sizeof(nextGroup));
    
    CloseHandle(trie);
    
    DoMapChange(client, ChangeMapTime_MapEnd, nextMap, nextGroup);
}

AutoNextMap(client)
{
    decl String:nextMap[MAP_LENGTH], String:nextGroup[MAP_LENGTH];
    if (UMC_GetRandomMap(map_kv, umc_mapcycle, INVALID_GROUP, nextMap, sizeof(nextMap), nextGroup, sizeof(nextGroup), false, true))
    {
        DoMapChange(client, ChangeMapTime_MapEnd, nextMap, nextGroup);
    }
    else
    {
        LogError("Could not automatically set the next map, no valid maps available.");
    }
}

stock Handle:FetchGroupNames(Handle:kv)
{
    new Handle:result = CreateArray(ByteCountToCells(MAP_LENGTH));
    if (!KvGotoFirstSubKey(kv))
    {
        return result;
    }
    
    decl String:group[MAP_LENGTH];
    
    do
    {
        KvGetSectionName(kv, group, sizeof(group));
        PushArrayString(result, group);
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
    
    return result;
}

stock Handle:FetchMapsFromGroup(Handle:kv, const String:group[])
{
    new Handle:mapcycle = CreateKeyValues("umc_rotation");
    KvCopySubkeys(kv, mapcycle);

    if (!KvJumpToKey(kv, group))
    {
        LogError("Cannot jump to map group '%s'", group);
        CloseHandle(mapcycle);
        return INVALID_HANDLE;
    }
    
    new Handle:result = CreateArray();
    
    if (!KvGotoFirstSubKey(kv))
    {
        CloseHandle(mapcycle);
        return result;
    }
        
    decl String:map[MAP_LENGTH];
    new Handle:trie;
    
    do
    {
        KvGetSectionName(kv, map, sizeof(map));
        trie = CreateTrie();
        SetTrieString(trie, MAP_TRIE_MAP_KEY, map);
        SetTrieString(trie, MAP_TRIE_GROUP_KEY, group);
        SetTrieValue(trie, "excluded", !UMC_IsMapValid(mapcycle, map, group, false, true));
        PushArrayCell(result, trie);
    }
    while (KvGotoNextKey(kv));
    
    KvGoBack(kv);
    KvGoBack(kv);
    
    return result;
}

FilterGroupArrayForAdmin(Handle:groups, admin)
{
    new userflags = GetUserFlagBits(admin);
    
    decl String:group[MAP_LENGTH];
    decl String:gFlags[64], String:mFlags[64];
    new size = GetArraySize(groups);
    for (new i = 0; i < size; i++)
    {
        new bool:excluded = true;
        
        GetArrayString(groups, i, group, sizeof(group));
        KvJumpToKey(map_kv, group);
        KvGetString(map_kv, ADMINMENU_ADMINFLAG_KEY, gFlags, sizeof(gFlags), "");
        
        if (KvGotoFirstSubKey(map_kv))
        {
            do
            {
                KvGetString(map_kv, ADMINMENU_ADMINFLAG_KEY, mFlags, sizeof(mFlags), gFlags);
                if (mFlags[0] == '\0' || (userflags & ReadFlagString(mFlags)))
                {
                    excluded = false;
                    break;
                }
            }
            while (KvGotoNextKey(map_kv));
            
            KvGoBack(map_kv);
        }
        
        if (excluded)
        {
            RemoveFromArray(groups, i);
            size--;
            i--;
        }
        
        KvGoBack(map_kv);
    }
}

//Builds and returns a map group selection menu.
Handle:CreateGroupMenu(MenuHandler:handler, bool:limits, client)
{
    //Initialize the menu
    new Handle:menu = CreateMenu(handler, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, "Select A Group");
    
    SetMenuExitBackButton(menu, true);
    
    KvRewind(map_kv);
    
    //Get group array.
    new Handle:groupArray;
    if (limits)
    {
        groupArray = UMC_CreateValidMapGroupArray(map_kv, umc_mapcycle, false, true);
    }
    else
    {
        groupArray = FetchGroupNames(umc_mapcycle);
    }
    
    FilterGroupArrayForAdmin(groupArray, client);
    
    new size = GetArraySize(groupArray);
    
    //Log an error and return nothing if the number of maps available to be nominated
    if (size == 0)
    {
        LogError("No map groups available to build menu.");
        CloseHandle(menu);
        CloseHandle(groupArray);
        return INVALID_HANDLE;
    }
    
    decl String:group[MAP_LENGTH], String:buffer[MAP_LENGTH];
    for (new i = 0; i < size; i++)
    {
        GetArrayString(groupArray, i, group, sizeof(group));
        if (!limits)
        {
            KvJumpToKey(umc_mapcycle, group);
            if (!KvGotoFirstSubKey(umc_mapcycle))
            {
                KvGoBack(umc_mapcycle);
                continue;
            }
            KvGoBack(umc_mapcycle);
            KvGoBack(umc_mapcycle);
            
            if (GroupExcludedPreviouslyPlayed(group, vote_catmem_arr, GetConVarInt(cvar_vote_catmem)))
            {
                FormatEx(buffer, sizeof(buffer), "%s (!)", group);
                AddMenuItem(menu, group, buffer);
            }
            else
            {
                AddMenuItem(menu, group, group);
            }
        }
        else
        {
            AddMenuItem(menu, group, group);
        }
    }
    
    //No longer need the array.
    CloseHandle(groupArray);

    //Success!
    return menu;
}

//Builds and returns a map selection menu.
Handle:CreateMapMenu(MenuHandler:handler, const String:group[], bool:limits, client)
{
    //Initialize the menu
    new Handle:menu = CreateMenu(handler, MenuAction_DisplayItem|MenuAction_Display);
    
    //Set the title.
    SetMenuTitle(menu, "Select A Map");
    
    SetMenuExitBackButton(menu, true);
    
    KvRewind(map_kv);
    
    new Handle:dispKV = CreateKeyValues("umc_mapcycle");
    KvCopySubkeys(umc_mapcycle, dispKV);

    //Get map array.
    new Handle:mapArray;
    if (limits)
    {
        mapArray = UMC_CreateValidMapArray(map_kv, umc_mapcycle, group, false, true);
    }
    else
    {
        mapArray = FetchMapsFromGroup(umc_mapcycle, group);
    }
    
    new size = GetArraySize(mapArray);
    if (size == 0)
    {
        LogError("No maps available to build menu.");
        CloseHandle(menu);
        CloseHandle(mapArray);
        CloseHandle(dispKV);
        return INVALID_HANDLE;
    }
    
    //Variables
    new numCells = ByteCountToCells(MAP_LENGTH);
    new Handle:menuItems = CreateArray(numCells);
    new Handle:menuItemDisplay = CreateArray(numCells);
    decl String:display[MAP_LENGTH+4]; //, String:gDisp[MAP_LENGTH];
    new Handle:mapTrie = INVALID_HANDLE;
    decl String:mapBuff[MAP_LENGTH], String:groupBuff[MAP_LENGTH];
    new bool:excluded;
    decl String:gAdminFlags[64], String:mAdminFlags[64];
    for (new i = 0; i < size; i++)
    {
        mapTrie = GetArrayCell(mapArray, i);
        GetTrieString(mapTrie, MAP_TRIE_MAP_KEY, mapBuff, sizeof(mapBuff));
        GetTrieString(mapTrie, MAP_TRIE_GROUP_KEY, groupBuff, sizeof(groupBuff));
        GetTrieValue(mapTrie, "excluded", excluded);
        
        KvJumpToKey(umc_mapcycle, groupBuff);
        KvGetString(umc_mapcycle, ADMINMENU_ADMINFLAG_KEY, gAdminFlags, sizeof(gAdminFlags), "");
        KvJumpToKey(umc_mapcycle, mapBuff);

        //Get the name of the current map.
        KvGetSectionName(umc_mapcycle, mapBuff, sizeof(mapBuff));
        KvGetString(umc_mapcycle, ADMINMENU_ADMINFLAG_KEY, mAdminFlags, sizeof(mAdminFlags), gAdminFlags);
        
        if (!ClientHasAdminFlags(client, mAdminFlags))
        {
            continue;
        }
        
        UMC_FormatDisplayString(display, sizeof(display), dispKV, mapBuff, groupBuff);
            
        if (UMC_IsMapNominated(mapBuff, groupBuff))
        {
            decl String:buff[MAP_LENGTH];
            strcopy(buff, sizeof(buff), display);
            FormatEx(display, sizeof(display), "%s (*)", buff);
        }
            
        if (excluded || MapExcludedPreviouslyPlayed(mapBuff, groupBuff, vote_mem_arr, vote_catmem_arr, GetConVarInt(cvar_vote_catmem)))
        {
            decl String:buff[MAP_LENGTH];
            strcopy(buff, sizeof(buff), display);
            FormatEx(display, sizeof(display), "%s (!)", buff);
        }
            
        //Add map data to the arrays.
        PushArrayString(menuItems, mapBuff);
        PushArrayString(menuItemDisplay, display);
        
        KvRewind(umc_mapcycle);
    }
    
    //Add all maps from the nominations array to the menu.
    AddArrayToMenu(menu, menuItems, menuItemDisplay);
    
    //No longer need the arrays.
    CloseHandle(menuItems);
    CloseHandle(menuItemDisplay);
    ClearHandleArray(mapArray);
    CloseHandle(mapArray);
    
    //Or the display KV
    CloseHandle(dispKV);
    
    //Success!
    return menu;
}

//Builds a menu with Auto and Manual options.
Handle:CreateAutoManualMenu(MenuHandler:handler, const String:title[])
{
    new Handle:menu = CreateMenu(handler, MenuAction_DisplayItem|MenuAction_Display);
    SetMenuTitle(menu, title);
    
    AddMenuItem(menu, AMMENU_ITEM_INFO_AUTO, "Auto Select");
    AddMenuItem(menu, AMMENU_ITEM_INFO_MANUAL, "Manual Select");
    
    return menu;
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
    PrintToConsole(client, "Module: UMC Admin Menu");
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
