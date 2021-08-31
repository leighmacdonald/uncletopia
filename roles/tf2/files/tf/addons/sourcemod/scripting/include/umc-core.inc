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
//Header file for Ultimate Mapchooser v3.0 by Steell.
#if defined _umc_core_included
    #endinput
#endif
#define _umc_core_included

#pragma semicolon 1

#define PL_VERSION "3.7.1"
#define UMC_DEBUG 1
#define AUTOUPDATE_ENABLE 0
#define AUTOUPDATE_DEV 0

//SourceMod Malarky
public SharedPlugin:__pl_umccore =
{
    name = "umccore",
    file = "umc-core.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_umccore_SetNTVOptional()
{
    MarkNativeAsOptional("UMC_AddWeightModifier");
    MarkNativeAsOptional("UMC_StartVote");
    MarkNativeAsOptional("UMC_GetCurrentMapGroup");
    MarkNativeAsOptional("UMC_GetRandomMap");
    MarkNativeAsOptional("UMC_SetNextMap");
    MarkNativeAsOptional("UMC_IsMapNominated");
    MarkNativeAsOptional("UMC_NominateMap");
    MarkNativeAsOptional("UMC_CreateValidMapArray");
    MarkNativeAsOptional("UMC_CreateValidMapGroupArray");
    MarkNativeAsOptional("UMC_IsMapValid");
    MarkNativeAsOptional("UMC_FilterMapcycle");
    MarkNativeAsOptional("UMC_IsVoteInProgress");
    MarkNativeAsOptional("UMC_StopVote");
    MarkNativeAsOptional("UMC_RegisterVoteManager");
    MarkNativeAsOptional("UMC_UnregisterVoteManager");
    MarkNativeAsOptional("UMC_VoteManagerVoteCompleted");
    MarkNativeAsOptional("UMC_VoteManagerVoteCancelled");
    MarkNativeAsOptional("UMC_VoteManagerClientVoted");
    MarkNativeAsOptional("UMC_FormatDisplayString");
    MarkNativeAsOptional("UMC_IsNewVoteAllowed");
}

#define INVALID_GROUP ""
#define MAP_LENGTH PLATFORM_MAX_PATH

#define MAP_TRIE_MAP_KEY   "map"
#define MAP_TRIE_GROUP_KEY "group"

#define DONT_CHANGE_OPTION "?DontChange?"
#define EXTEND_MAP_OPTION "?Extend?"

enum UMC_VoteType
{
    VoteType_Map = 0,
    VoteType_Group,
    VoteType_Tier,
};

enum UMC_ChangeMapTime
{
    ChangeMapTime_Now = 0,
    ChangeMapTime_RoundEnd,
    ChangeMapTime_MapEnd,
};

enum UMC_VoteFailAction
{
    VoteFailAction_Nothing = 0,
    VoteFailAction_Runoff,
};

enum UMC_RunoffFailAction
{
    RunoffFailAction_Nothing = 0,
    RunoffFailAction_Accept,
};

enum UMC_VoteResponse
{
    VoteResponse_Success = 0,
    VoteResponse_Runoff,
    VoteResponse_Tiered,
    VoteResponse_Fail,
};


/**
 * Called when a nomination was removed from UMC.
 *
 * @param map  The name of the map
 * @param client    The client that the nomination belonged to.
 *
 * @noreturn
 */
//Commented out to compile on SourceMod 1.7 or newer
//forward OnNominationRemoved(const String:map[], client);


/**
 * Called when a map's weight is being reweighted. Allows plugin to modify the
 * weight by calling UMC_AddWeightModifier.
 *
 * @param kv    The mapcycle being used.
 * @param map   The name of the map we're reweighting.
 * @param group The group that the map belongs to.
 * @noreturn
 */
forward UMC_OnReweightMap(Handle:kv, const String:map[], const String:group[]);


/**
 * Called when a group's weight is being reweighted.
 *
 * @param kv    The mapcycle being used
 * @param group The group being reweighted.
 *
 * @noreturn
 */
forward UMC_OnReweightGroup(Handle:kv, const String:group[]);


/**
 * Adds a MapWeightModifier to UMC's internal modifier list.
 *
 * @param amt  Amount to modify the currently weighted map's weight with.
 *
 * @noreturn
 */
native UMC_AddWeightModifier(Float:amt);


/**
 * Called when a map is being considered for exclusion.
 *
 * @param kv    The mapcycle being used.
 * @param map   The name of the map being considered.
 * @param group The group that the map belongs to.
 * @param isNomination  Specifies whether this is a nominated map or not.
 * @param forMapChange  Whether or not this map will be used this game frame for a mapchange.
 *
 * @return  Plugin_Continue to keep the map, Plugin_Stop to exclude the map.
 */
forward Action:UMC_OnDetermineMapExclude(Handle:kv, const String:map[], const String:group[],
    bool:isNomination, bool:forMapChange);


/**
 * Starts a UMC map vote.
 *
 * @param id
 * @param mapcycle  The mapcycle to use for the vote.
 * @param originalMapcycle  Original mapcycle, contains all information the user has defined.
 * @param type  The type of vote.
 * @param time  How long the vote should remain acive (in seconds).
 * @param scramble  Determines if the vote menu is scrambled.
 * @param startSound    Sound to be played when the vote starts (must be precached already).
 * @param endSound      Sound to be played when the vote ends (must be precached already).
 * @param extendOption  Determines if an "Extend Map" option is displayed.
 * @param timestep       How long to extend the time limit.
 * @param roundstep      How long to extend the round limit.
 * @param fragstep       How long to extend the frag limit.
 * @param dontChangeOption  Determines if a "Don't Change" option is displayed.
 * @param threshold Percentage winning vote must exceed in order for the vote to change the map.
 * @param successAction Action to be taken if the vote is successful (threshold was exceeded).
 * @param failAction    Action to be taken if the vote is unsuccessful (threshold wasn't exceeded).
 * @param maxRunoffs    Maximum amount of runoffs that will be performed. 0 = no max
 * @param maxRunoffMaps Maximum amount of maps that appear in runoffs. 0 = no max
 * @param runoffFailAction  Action to be taken should the maximum amount of runoffs is reached and there is still no winning map.
 * @param runoffSound   Sound to be played when the runoff vote starts (must be precached already).
 * @param nominationStrictness  Specifies how nominations should be handled.
 * @param allowDuplicates   Determines if the same map (in different groups) can appear in the vote.
 * @param clients   String of flags required for players to see the vote.
 * @param numClients    Number of clients to read from clients array.
 * @param runExclusion  Determines if UMC will filter the mapcycle through the Map Exclusion system.
 *
 * @return True on success, false on failure.
 */
native bool:UMC_StartVote(const String:id[], Handle:mapcycle, Handle:originalMapcycle,
    UMC_VoteType:type, time, bool:scramble, const String:startSound[], const String:endSound[],
    bool:extendOption, Float:timestep, roundstep, fragstep, bool:dontChangeOption, Float:threshold,
    UMC_ChangeMapTime:successAction, UMC_VoteFailAction:failAction, maxRunoffs, maxRunoffMaps,
    UMC_RunoffFailAction:runoffFailAction, const String:runoffSound[], bool:nominationStrictness,
    bool:allowDuplicates, const clients[], numClients, bool:runExclusion=true);


/**
 * Fetches a random map from a given map group in a given mapcycle.
 *
 * @param mapcycle  The mapcycle to use for the vote.
 * @param originalMapcycle  Original mapcycle, contains all information the user has defined.
 * @param group Group to look for a map in. If INVALID_GROUP then it will look in all groups.
 * @param buffer    Buffer to store the fetched map in.
 * @param size  Max size of the buffer.
 * @param groupBuffer   Buffer to store the group of the map in.
 * @param gBufferSize   Max size of the group buffer.
 * @param isNomination Whether or not this map should be treated as a nomination.
 * @param forMapChange Whether or not this map will be used this game frame for a mapchange.
 *
 * @return True on success, false on failure.
 */
native bool:UMC_GetRandomMap(Handle:mapcycle, Handle:originalMapcycle, const String:group[],
                             String:buffer[], size, String:groupBuffer[], gBufferSize,
                             bool:isNomination, bool:forMapChange);


/**
 * Sets the next map and map group for UMC.
 *
 * @param mapcycle  Mapcycle containing the map and map group. Should contain all information the user has defined.
 * @param map   The name of the map
 * @param group The name of the map group containing the map.
 * @param when  When the map should be changed to the set next map.
 *
 * @noreturn
 */
native UMC_SetNextMap(Handle:mapcycle, const String:map[], const String:group[],
                      UMC_ChangeMapTime:when);


/**
 * Determines if the given map from the given group is nominated.
 *
 * @param map   The name of the map.
 * @param group The name of the map group containing the map.
 *
 * @return True if the map is nominated, false otherwise.
 */
native bool:UMC_IsMapNominated(const String:map[], const String:group[]);


/**
 * Nominates a map for UMC.
 *
 * @param mapcycle  Mapcycle containing the nomination. Should contain all information the user has defined.
 * @param map   The name of the map.
 * @param group The name of the map group containing the map.
 * @param client    The client who is nominating this map.
 * @param nominationGroup   The group which this nomination should be associated with. If INVALID_GROUP, it will be associated with the given group.
 *
 * @return True on success, false otherwise.
 */
native bool:UMC_NominateMap(Handle:mapcycle, const String:map[], const String:group[], client,
                            const String:nominationGroup[]=INVALID_HANDLE);


/**
 * Determines if the given group is valid (has at least 1 valid map in it) for the given mapcycle.
 *
 * @param mapcycle  Mapcycle containing the group. Should contain all information the user has defined.
 * @param group The group to be checked.
 *
 * @return True if the group is valid, false otherwise.
 */
//native bool:UMC_IsGroupValid(Handle:mapcycle, const String:group[]);


/**
 * Determines if the given map is valid for the given mapcycle.
 *
 * @param mapcycle  Mapcycle containing the map. Should contain all information the user has defined.
 * @param map   The name of the map.
 * @param group The name of the group containing the map.
 * @param isNom
 * @param forMapChange
 *
 * @return True if the map is valid, false otherwise.
 */
native bool:UMC_IsMapValid(Handle:mapcycle, const String:map[], const String:group[], bool:isNom,
                           bool:forMapChange);


/**
 * Returns a copy of the given mapcycle with all invalid maps and groups filtered out.
 *
 * @param mapcycle  Mapcycle to filter. Should contain all information the user has defined.
 * @param isNomination  Are we filtering for nomination?
 * @param forMapChange  Are we filtering for maps we will be using this frame for a map change?
 *
 * @return Handle to the new mapcycle KV.
 */
native Handle:UMC_FilterMapcycle(Handle:mapcycle, Handle:originalMapcycle, bool:isNomination,
                                 bool:forMapChange);


/**
 * Returns an array consisting of all the valid maps in the given mapcycle.
 *
 * @param mapcycle  Mapcycle to look for maps in.
 * @param originalMapcycle  Original mapcycle, contains all information that the user has defined.
 * @param group Group to select maps from. If INVALID_GROUP, all groups are looked in.
 * @param isNom Are these maps to be considered nominations?
 * @param forMapChange  Are any of these maps going to be used to change the map this game frame?
 *
 * @return Handle to the new array containing all of the valid map tries.
 */
native Handle:UMC_CreateValidMapArray(Handle:mapcycle, Handle:originalMapcycle,
                                      const String:group[], bool:isNom, bool:forMapChange);


/**
 * Returns an array consisting of all the valid groups in the given mapcycle. A valid group is a
 * group with 1 or more valid maps in it.
 *
 * @param kv    Mapcycle to look for maps in.
 * @param originalMapcycle  Original mapcycle, contains all information that the user has defined.
 * @param isNom Are the maps in these groups to be considered nominations?
 * @param forMapChange  Are any of the maps in these groups going to be used to change the map this game frame?
 *
 * @return Handle to the new array containing all of the valid map groups.
 */
native Handle:UMC_CreateValidMapGroupArray(Handle:kv, Handle:originalMapcycle, bool:isNom,
                                           bool:forMapChange);


/**
 * Called when has extended the map.
 *
 * @noreturn
 */
forward UMC_OnMapExtended();


/**
 * Called when a vote has failed. This can be due to the Don't Change option winning the vote or the
 * winning map not winning by a high enough percentage.
 *
 * @noreturn
 */
forward UMC_OnVoteFailed(); //UMC_FailReason:reason);


/**
 * Called immediately after UMC has set a next map.
 *
 * @param kv    The mapcycle used for the vote.
 * @param map   The name of the winning map.
 * @param group The group of the winning map.
 * @param display    The "display name" of the winning map.
 *
 * @noreturn
 */
forward UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[],
                         const String:display[]);


/**
 * Called when the "sm_umc_reload" command is used. If your plugin has its own mapcycle, you should
 * reload it in this forward.
 *
 * @noreturn
 */
forward UMC_RequestReloadMapcycle();


/**
 * Retrieves the name of the current map group.
 *
 * @param buffer    Buffer to store the group name in.
 * @param size  Maximum length of the buffer.
 *
 * @noreturn
 */
native UMC_GetCurrentMapGroup(String:buffer[], size);


/**
 * Determines if UMC currently has a vote in progress.
 *
 * @param id
 *
 * @return True if vote is in progress, false otherwise.
 */
native bool:UMC_IsVoteInProgress(const String:id[]);


/**
 * Stops a UMC vote that is currently in progress.
 *
 * @param id
 *
 * @return True on success, false otherwise.
 */
native bool:UMC_StopVote(const String:id[]);


/**
 * Callback for when a vote is to be started by UMC. Note that all Handles will be freed after the
 * call is complete, so if you want to store them, make sure to clone them first with CloneHandle.
 *
 * @param duration
 * @param vote_items
 * @param clients
 * @param extend
 * @param dontChange
 * @param startSound
 *
 * @return Plugin_Continue on success, Plugin_Stop to prevent the vote.
 */
typedef UMC_VoteHandler = function Action (int duration, Handle vote_items, const int clients[], int numClients, const char startSound[]);

/**
 *
 */
typedef UMC_VoteCancelledHandler = function void();

typedef UMC_VoteInProgressHandler = function bool();

/**
 * Registers a new VoteManager for UMC votes.
 *
 * @param id    Unique string identifier for this VoteManager.
 * @param callback  Function to be called when a vote is ready to be started.
 * @param cancelCallback  Function to be called when a vote is cancelled.
 * @param progressCallback  Function to be called to check if a vote is in progress.  Set to INVALID_FUNCTION to use IsVoteInProgress()
 *
 * @noreturn
 */
native UMC_RegisterVoteManager(const String:id[], UMC_VoteHandler:mapCallback,
                               UMC_VoteHandler:groupCallback,
                               UMC_VoteCancelledHandler:cancelCallback,
                               UMC_VoteInProgressHandler:progressCallback=INVALID_FUNCTION);


/**
 *
 */
typedef UMC_VoteResponseHandler = function void(UMC_VoteResponse response, const char param[]);

/**
 * Notifies UMC that the current vote has completed.
 *
 * @param id Id of the Vote Manager which has completed.
 * @param voteOptions adt_array of options in the vote
 * @param callback Callback for processing the results of the vote.
 *
 * @noreturn
 */
native UMC_VoteManagerVoteCompleted(const String:id[], Handle:voteOptions, UMC_VoteResponseHandler:callback);


/**
 * Notifies UMC that the current vote has been cancelled by the vote Handler. This will cause the
 * UMC_VoteCancelledHandler provided to UMC_RegisterVoteManager to be called as well.
 *
 * @param id ID of the Vote Manager to cancel.
 */
native UMC_VoteManagerVoteCancelled(const String:id[]);


/**
 * Unregisters a Vote Manager from UMC.
 *
 * @param id ID of the Vote Manager to unregister.
 */
native UMC_UnregisterVoteManager(const String:id[]);


/**
 * Called when UMC requests a Map Cycle to be displayed.
 *
 * @param client Client to display the Map Cycle to.
 * @param filtered If true, it is requested that mapcycle only shows maps which pass UMC exclusion.
 */
forward UMC_DisplayMapCycle(client, bool:filtered);


/**
 *
 */
forward UMC_VoteStarted(const String:voteManagerId[], const clients[], numClients,
                        Handle:voteOptions);


/**
 *
 */
forward UMC_VoteEnded(const String:voteManagerId[], UMC_VoteResponse:reason);


/**
 *
 */
forward UMC_ClientVoted(const String:voteManagerId[], client, Handle:option);


/**
 *
 */
native UMC_VoteManagerClientVoted(const String:id[], client, Handle:option);


/**
 *
 */
forward UMC_OnFormatTemplateString(String:template[], maxlen, Handle:kv, const String:map[],
                                   const String:group[]);


/**
 *
 */
native UMC_FormatDisplayString(String:display[], maxlen, Handle:mapcycle, const String:map[],
                               const String:group[]);

/**
 * Is a new vote allowed on this vote manager?
 *
 * @param id  ID of the Vote Manager to check. Defaults to "core".
 * @return  True if we can start a new vote, false otherwise.
 */
native bool:UMC_IsNewVoteAllowed(const String:id[]="core");

// vim: set ft=sourcepawn:
