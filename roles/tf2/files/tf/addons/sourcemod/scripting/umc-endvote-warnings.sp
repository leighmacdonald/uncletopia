/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                              Ultimate Mapchooser - Vote Warnings                              *
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
#include <regex>
#include <sdktools_sound>
#include <umc-core>
#include <umc_utils>
#include <emitsoundany>

public Plugin:myinfo =
{
    name = "[UMC] End of Map Vote Warnings",
    author = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Adds vote warnings to UMC End of Map Votes.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

//Cvars
new Handle:cvar_time  = INVALID_HANDLE;
new Handle:cvar_frag  = INVALID_HANDLE;
new Handle:cvar_round = INVALID_HANDLE;
new Handle:cvar_win   = INVALID_HANDLE;

//Flags
new bool:time_enabled;
new bool:frag_enabled;
new bool:round_enabled;
new bool:win_enabled;

new bool:time_init;
new bool:frag_init;
new bool:round_init;
new bool:win_init;

//Warning adt_arrays
new Handle:time_array  = INVALID_HANDLE;
new Handle:frag_array  = INVALID_HANDLE;
new Handle:round_array = INVALID_HANDLE;
new Handle:win_array   = INVALID_HANDLE;

//Current warning indices
new current_time;
new current_frag;
new current_round;
new current_win;

//TODO:
//  -Possible bug where warnings are never updated (vote timer activates before OnConfigsExecuted
//      finishes) Possible solution is to update the warnings when the timer ticks (use flags so its
//      only done when necessary).
public OnPluginStart()
{
    cvar_time = CreateConVar(
        "sm_umc_endvote_timewarnings",
        "addons/sourcemod/configs/vote_warnings.txt",
        "Specifies which file time-based vote warnings are defined in. (uses mp_timelimit)"
    );
    
    cvar_frag = CreateConVar(
        "sm_umc_endvote_fragwarnings",
        "",
        "Specifies which file frag-based vote warnings are defined in. (uses mp_fraglimit)"
    );
    
    cvar_round = CreateConVar(
        "sm_umc_endvote_roundwarnings",
        "",
        "Specifies which file round-based vote warnings are defined in. (uses mp_maxrounds)"
    );
    
    cvar_win = CreateConVar(
        "sm_umc_endvote_winwarnings",
        "",
        "Specifies which file win-based vote warnings are defined in. (uses mp_winlimit)"
    );
    
    AutoExecConfig(true, "umc-endvote-warnings");
    
    //Initialize warning arrays
    time_array  = CreateArray();
    frag_array  = CreateArray();
    round_array = CreateArray();
    win_array   = CreateArray();
    
    LoadTranslations("ultimate-mapchooser.phrases");
}

public OnConfigsExecuted()
{
    //Clear warning arrays
    ClearHandleArray(time_array);
    ClearHandleArray(frag_array);
    ClearHandleArray(round_array);
    ClearHandleArray(win_array);
}

public OnMapStart()
{
    //Store cvar values
    decl String:timefile[256], String:fragfile[256], String:roundfile[256], String:winfile[256];
    GetConVarString(cvar_time, timefile, sizeof(timefile));
    GetConVarString(cvar_frag, fragfile, sizeof(fragfile));
    GetConVarString(cvar_round, roundfile, sizeof(roundfile));
    GetConVarString(cvar_win, winfile, sizeof(winfile));
    
    //Set vote warning flags
    time_enabled = strlen(timefile) > 0 && FileExists(timefile);
    frag_enabled = strlen(fragfile) > 0 && FileExists(fragfile);
    round_enabled = strlen(roundfile) > 0 && FileExists(roundfile);
    win_enabled = strlen(winfile) > 0 && FileExists(winfile);
    
    //Initialize warning variables if vote warnings are enabled.
    if (time_enabled)
    {
        GetVoteWarnings(timefile, time_array, current_time);
    }
    if (frag_enabled)
    {
        GetVoteWarnings(fragfile, frag_array, current_frag);
    }
    if (round_enabled)
    {
        GetVoteWarnings(roundfile, round_array, current_round);
    }
    if (win_enabled)
    {
        GetVoteWarnings(winfile, win_array, current_win);
    }
    
    time_init = false;
    frag_init = false;
    round_init = false;
    win_init = false;
}

//Comparison function for vote warnings. Used for sorting.
public CompareWarnings(index1, index2, Handle:array, Handle:hndl)
{
    new time1, time2;
    new Handle:warning = INVALID_HANDLE;
    warning = GetArrayCell(array, index1);
    GetTrieValue(warning, "time", time1);
    warning = GetArrayCell(array, index2);
    GetTrieValue(warning, "time", time2);
    return time2 - time1;
}

//Parses the vote warning definitions file and returns an adt_array of vote warnings.
GetVoteWarnings(const String:fileName[], Handle:warningArray, &next)
{
    //Get our warnings file as a Kv file.
    new Handle:kv = GetKvFromFile(fileName, "vote_warnings", false);
    
    //Do nothing if we can't find the warning definitions.
    if (kv == INVALID_HANDLE)
    {
        LogUMCMessage("Unable to parse warning file '%s', no vote warnings created.", fileName);
        return;
    }
    
    //Variables to hold default values. Initially set to defaults in the event that the user doesn't
    //specify his own.
    decl String:dMessage[255];
    FormatEx(dMessage, sizeof(dMessage), "%T", "Default Warning", LANG_SERVER); //Message
    new String:dNotification[10] = "C"; //Notification
    new String:dSound[PLATFORM_MAX_PATH] = ""; //Sound
    new String:dFlags[64] = "";
    
    //Grab defaults from the KV if...
    //    ...they are actually defined.
    if (KvJumpToKey(kv, "default"))
    {
        //Grab 'em.
        KvGetString(kv, "message", dMessage, sizeof(dMessage), dMessage);
        KvGetString(kv, "notification", dNotification, sizeof(dNotification), dNotification);
        KvGetString(kv, "sound", dSound, sizeof(dSound), dSound);
        KvGetString(kv, "adminflags", dFlags, sizeof(dFlags), dFlags);
    
        //Rewind back to root, so we can begin parsing the warnings.
        KvRewind(kv);
    }
    
    //Log an error and return nothing if it cannot find any defined warnings. 
    // If the default definition is found, this code block will not execute. We will catch this case after we attempt to parse the file.
    if (!KvGotoFirstSubKey(kv))
    {
        LogUMCMessage("No vote warnings defined, vote warnings were not created.");
        CloseHandle(kv);
        return;
    }
    
    //Counter to keep track of the number of warnings we're storing.
    new warningCount = 0;
    
    //Storage handle for each warning.
    new Handle:warning = INVALID_HANDLE;
    
    //Storage buffers for warning values.
    new warningTime; //Time (in seconds) before vote when the warning is displayed.
    decl String:nameBuffer[10]; //Buffer to hold the section name;
    decl String:message[255];
    decl String:notification[2];
    decl String:sound[PLATFORM_MAX_PATH];
    decl String:flags[64];
    
    //Storage buffer for formatted sound strings
    decl String:fsound[PLATFORM_MAX_PATH];
    decl String:timeString[10];
    
    //Regex to store sequence pattern in.
    static Handle:re = INVALID_HANDLE;
    if (re == INVALID_HANDLE)
    {
        re = CompileRegex("^([0-9]+)\\s*(?:(?:\\.\\.\\.)|-)\\s*([0-9]+)$");
    }
    
    //Variables to store sequence definition
    decl String:sequence_start[10], String:sequence_end[10];
    
    //Variable storing interval of the sequence
    new interval;
    
    //For a warning, add it to the result adt_array.
    do
    {
        //Grab the name (time) of the warning.
        KvGetSectionName(kv, nameBuffer, sizeof(nameBuffer));
        
        //Skip this warning if it is the default definition.
        if (StrEqual(nameBuffer, "default", false))
        {
            continue;
        }
        
        //Store warning info into variables.
        KvGetString(kv, "message", message, sizeof(message), dMessage);
        KvGetString(kv, "notification", notification, sizeof(notification), dNotification);
        KvGetString(kv, "sound", sound, sizeof(sound), dSound);
        KvGetString(kv, "adminflags", flags, sizeof(flags), dFlags);
        
        //Prepare to handle sequence of warnings if a sequence is what was defined.
        if (MatchRegex(re, nameBuffer) > 0)
        {
            //Get components of sequence
            GetRegexSubString(re, 1, sequence_start, sizeof(sequence_start));
            GetRegexSubString(re, 2, sequence_end, sizeof(sequence_end));
            
            //Calculate sequence interval
            warningTime = StringToInt(sequence_start);
            interval = (warningTime - StringToInt(sequence_end)) + 1;
            
            //Invert sequence if it was specified in the wrong order.
            if (interval < 0)
            {
                interval *= -1;
                warningTime += interval;
            }
        }
        else //Otherwise, just handle the single warning.
        {
            warningTime = StringToInt(nameBuffer);
            interval = 1;
        }
        
        //Store a warning for each element in the interval.
        for (new i = 0; i < interval; i++)
        {
            //Store everything in a trie which represents a warning object
            warning = CreateTrie();
            SetTrieValue(warning, "time", warningTime - i);
            SetTrieString(warning, "message", message);
            SetTrieString(warning, "notification", notification);
            SetTrieString(warning, "flags", flags);
            
            //Insert correct time remaining if the message has a place to insert it.
            if (StrContains(sound, "{TIME}") != -1)
            {
                IntToString(warningTime - i, timeString, sizeof(timeString));
                strcopy(fsound, sizeof(fsound), sound);
                ReplaceString(fsound, sizeof(fsound), "{TIME}", timeString, false);
                
                //Setup the sound for the warning.
                CacheSound(fsound);
                SetTrieString(warning, "sound", fsound);
            }
            else //Otherwise just cache the defined sound.
            {
                //Setup the sound for the warning.
                CacheSound(sound);
                SetTrieString(warning, "sound", sound);
            }
            
            //Add the new warning to the result adt_array.
            PushArrayCell(warningArray, warning);
            
            //Increment the counter.
            warningCount++;
        }
    } while(KvGotoNextKey(kv)); //Do this for every warning.
    
    //We no longer need the kv.
    CloseHandle(kv);
    
    //Log an error and return nothing if no vote warnings were found. 
    // This accounts for the case where the default definition was provided, but not actual warnings.
    if (warningCount < 1)
    {
        LogUMCMessage("No vote warnings defined, vote warnings were not created.");
    }
    else //Otherwise, log a success!
    {
        LogUMCMessage("Successfully parsed and set up %i vote warnings.", warningCount);
    
        //Sort the array in descending order of time.
        SortADTArrayCustom(warningArray, CompareWarnings);
        next = GetArraySize(warningArray);
    }
}

UpdateWarnings(Handle:array, threshold, &warningTime)
{
    //Storage variables.
    new i, arraySize;
    
    //Test if a warning is the next warning to be displayed for each warning in the warning array.
    arraySize = GetArraySize(array);
    for (i = 0; i < arraySize; i++)
    {
        GetTrieValue(GetArrayCell(array, i), "time", warningTime);
        
        //We found out answer if the trigger for the next warning hasn't passed.
        if (warningTime < threshold)
        {
            break;
        }
    }
    
    return i;
}

UpdateWinWarnings(winsleft)
{
    new warningTime;
    current_win = UpdateWarnings(win_array, winsleft, warningTime);
    
    if (current_win < GetArraySize(win_array))
    {
        win_init = true;
        LogUMCMessage("First win-warning will appear at %i wins before the end of the map.", warningTime);
    }
}

UpdateFragWarnings(fragsleft)
{
    new warningTime;
    current_frag = UpdateWarnings(frag_array, fragsleft, warningTime);
    
    if (current_round < GetArraySize(round_array))
    {
        frag_init = true;
        LogUMCMessage("First frag-warning will appear at %i frags before the end of map vote.", warningTime);
    }
}

UpdateTimeWarnings(timeleft)
{
    new warningTime;
    current_time = UpdateWarnings(time_array, timeleft, warningTime);
    
    if (current_time < GetArraySize(time_array))
    {
        time_init = true;
        LogUMCMessage("First time-warning will appear %i seconds before the end of map vote.", warningTime);
    }
}

UpdateRoundWarnings(roundsleft)
{
    new warningTime;
    current_round = UpdateWarnings(round_array, roundsleft, warningTime);
    
    if (current_round < GetArraySize(round_array))
    {
        round_init = true;
        LogUMCMessage("First round-warning will appear at %i rounds before the end of map vote.", warningTime );
    }
}

//Perform a vote warning, does nothing if there is no warning defined for this time.
stock DoVoteWarning(Handle:warningArray, &next, triggertime, param=0)
{
    //Do nothing if there are no more warnings to perform.
    if (GetArraySize(warningArray) <= next)
    {
        return;
    }
    
    //Get the current warning.
    new Handle:warning = GetArrayCell(warningArray, next);
    
    //Get the trigger time of the current warning.
    new warningTime;
    GetTrieValue(warning, "time", warningTime);
    
    //Display warning if the time to trigger it has come.
    if (triggertime <= warningTime)
    {
        DisplayVoteWarning(warning, param);
        
        //Move to the next warning.
        next++;
        
        //Repeat in the event that there are multiple warnings for this time.
        DoVoteWarning(warningArray, next, triggertime, param);
    }
}

TryDoTimeWarning(timeleft)
{
    if (time_enabled)
    {
        DoVoteWarning(time_array, current_time, timeleft);
    }
}

TryDoRoundWarning(rounds)
{
    if (round_enabled)
    {    
        DoVoteWarning(round_array, current_round, rounds);
    }
}

TryDoFragWarning(frags, client)
{
    if (frag_enabled)
    {
        DoVoteWarning(frag_array, current_frag, frags, client);
    }
}

TryDoWinWarning(wins, team)
{
    if (win_enabled)
    {
        DoVoteWarning(win_array, current_win, wins, team);
    }
}

//Displays the given vote warning to the server
DisplayVoteWarning(Handle:warning, param=0)
{
    //Get warning information.
    new time;
    decl String:message[255];
    decl String:notification[2];
    decl String:sound[PLATFORM_MAX_PATH];
    GetTrieValue(warning, "time", time);
    GetTrieString(warning, "message", message, sizeof(message));
    GetTrieString(warning, "notification", notification, sizeof(notification));
    GetTrieString(warning, "sound", sound, sizeof(sound));
    
    //Emit the warning sound if the sound is defined.
    if (strlen(sound) > 0)
    {
        EmitSoundToAllAny(sound);
    }
    
    //Stop here if there is nothing to display.
    if (strlen(message) == 0 || strlen(notification) == 0)
    {
        return;
    }
    
    //Buffer to store string replacements in the message.
    decl String:sBuffer[5];
    
    //Insert correct time remaining if the message has a place to insert it.
    if (StrContains(message, "{TIME}") != -1)
    {
        IntToString(time, sBuffer, sizeof(sBuffer));
        ReplaceString(message, sizeof(message), "{TIME}", sBuffer, false);
    }
    
    //Insert correct time remaining if the message has a place to insert it.
    if (StrContains(message, "{PLAYER}") != -1)
    {
        FormatEx(sBuffer, sizeof(sBuffer), "%N", param);
        ReplaceString(message, sizeof(message), "{PLAYER}", sBuffer, false);
    }

    //Insert a newline character if the message has a place to insert it.
    if (StrContains(message, "\\n") != -1)
    {
        FormatEx(sBuffer, sizeof(sBuffer), "%c", 13);
        ReplaceString(message, sizeof(message), "\\n", sBuffer);
    }
    
    //Display the message
    DisplayServerMessage(message, notification);
}

//************************************************************************************************//
//                                   UMC END OF MAP VOTE EVENTS                                   //
//************************************************************************************************//
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    //Stop displaying any warnings.
    DisplayServerMessage("", "");
}

public UMC_EndVote_OnTimeTimerUpdated(timeleft)
{
    UpdateTimeWarnings(timeleft);
}

public UMC_EndVote_OnRoundTimerUpdated(roundsleft)
{
    UpdateRoundWarnings(roundsleft);
}

public UMC_EndVote_OnFragTimerUpdated(fragsleft, client)
{
    UpdateFragWarnings(fragsleft);
}

public UMC_EndVote_OnWinTimerUpdated(winsleft, team)
{
    UpdateWinWarnings(winsleft);
}

public UMC_EndVote_OnTimeTimerTicked(timeleft)
{
    if (!time_init)
    {
        UpdateTimeWarnings(timeleft);
    }
    TryDoTimeWarning(timeleft);
}

public UMC_EndVote_OnRoundTimerTicked(roundsleft)
{
    if (!round_init)
    {
        UpdateRoundWarnings(roundsleft);
    }
    TryDoRoundWarning(roundsleft);
}

public UMC_EndVote_OnFragTimerTicked(fragsleft, client)
{
    if (!frag_init)
    {
        UpdateFragWarnings(fragsleft);
    }
    TryDoFragWarning(fragsleft, client);
}

public UMC_EndVote_OnWinTimerTicked(winsleft, team)
{
    if (!win_init)
    {
        UpdateWinWarnings(winsleft);
    }
    TryDoWinWarning(winsleft, team);
}
