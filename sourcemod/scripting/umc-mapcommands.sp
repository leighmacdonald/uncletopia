/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                               Ultimate Mapchooser - Map Commands                              *
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

public Plugin:myinfo =
{
    name = "[UMC] Map Commands",
    author = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Allows users to specify commands to be executed for maps and map groups.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

#define COMMAND_KEY          "command"
#define PRE_COMMAND_KEY      "pre-command"
#define POSTVOTE_COMMAND_KEY "postvote-command"

new String:map_command[256];
new String:group_command[256];
new String:map_precommand[256];
new String:group_precommand[256];

//Execute commands after all configs have been executed.
public OnConfigsExecuted()
{
    if (strlen(group_command) == 0 || strlen(map_command) == 0)
    {
        new Handle:kv = GetKvFromFile("umc_mapcycle.txt", "umc_mapcycle");
        decl String:CurrentMapGroup[64], String:CurrentMap[64];
        
        GetCurrentMap(CurrentMap, sizeof(CurrentMap));
        KvFindGroupOfMap(kv, CurrentMap, CurrentMapGroup, sizeof(CurrentMapGroup));
        
        if (KvJumpToKey(kv, CurrentMapGroup))
        {
            if (strlen(group_command) == 0)
            {
                KvGetString(kv, COMMAND_KEY, group_command, sizeof(group_command), "");
            }
            if (KvJumpToKey(kv, CurrentMap) && strlen(map_command) == 0)
            {
                KvGetString(kv, COMMAND_KEY, map_command, sizeof(map_command), "");
            }
        }
        CloseHandle( kv );
    }
    
    if (strlen(group_command) > 0)
    {
        LogUMCMessage("SETUP: Executing map group command: '%s'", group_command);
        ServerCommand(group_command);
        strcopy(group_command, sizeof(group_command), "");
    }
    
    if (strlen(map_command) > 0)
    {
        LogUMCMessage("SETUP: Executing map command: '%s'", map_command);
        ServerCommand(map_command);
        strcopy(map_command, sizeof(map_command), "");
    }
}


//Execute pre-commands when map ends
public OnMapEnd()
{
    if (strlen(group_precommand) > 0)
    {
        LogUMCMessage("SETUP: Executing map group pre-command: '%s'", group_precommand);
        ServerCommand(group_precommand);
        strcopy(group_precommand, sizeof(group_precommand), "");
    }
    
    if (strlen(map_precommand) > 0)
    {
        LogUMCMessage("SETUP: Executing map pre-command: '%s'", map_precommand);
        ServerCommand(map_precommand);
        strcopy(map_precommand, sizeof(map_precommand), "");
    }
}


//Called when UMC has set the next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    if (kv == INVALID_HANDLE)
    {
        return;
    }
    
    decl String:gPVCommand[256], String:mPVCommand[256];

    KvRewind(kv); //TODO: Remove
    if (KvJumpToKey(kv, group))
    {    
        KvGetString(kv, COMMAND_KEY, group_command, sizeof(group_command), "");
        KvGetString(kv, POSTVOTE_COMMAND_KEY, gPVCommand, sizeof(gPVCommand), "");
        KvGetString(kv, PRE_COMMAND_KEY, group_precommand, sizeof(group_precommand), "");
        
        if (strlen(gPVCommand) > 0)
        {
            LogUMCMessage("SETUP: Executing map group postvote-command: '%s'", gPVCommand);
            ServerCommand(gPVCommand);
        }
            
        if (KvJumpToKey(kv, map))
        {
            KvGetString(kv, COMMAND_KEY, map_command, sizeof(map_command), "");
            KvGetString(kv, POSTVOTE_COMMAND_KEY, mPVCommand, sizeof(mPVCommand), "");
            KvGetString(kv, PRE_COMMAND_KEY, map_precommand, sizeof(map_precommand), "");
            
            if (strlen(mPVCommand) > 0)
            {
                LogUMCMessage("SETUP: Executing map postvote-command: '%s'", mPVCommand);
                ServerCommand(mPVCommand);
            }
            KvGoBack(kv);
        }
        KvGoBack(kv);
    }
}
