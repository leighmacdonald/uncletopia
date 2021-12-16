/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                             Ultimate Mapchooser - Prefix Exclusion                            *
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
#include <regex>

public Plugin:myinfo =
{
    name = "[UMC] Prefix Exclusion",
    author = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Excludes maps with the same prefix from being played consecutively.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

new Handle:cvar_nom_ignore = INVALID_HANDLE;
new Handle:cvar_display_ignore = INVALID_HANDLE;
new Handle:cvar_prev = INVALID_HANDLE;
new Handle:cvar_amt = INVALID_HANDLE;
new Handle:prefix_array = INVALID_HANDLE;

public OnPluginStart()
{
    cvar_amt = CreateConVar(
        "sm_umc_prefixexclude_amount",
        "1",
        "Specifies how many times the prefix can be in the memory before it is excluded.",
        0, true, 1.0
    );

    cvar_prev = CreateConVar(
        "sm_umc_prefixexclude_memory",
        "0",
        "Specifies how many previously played prefixes to remember. 1 = Current Only, 0 = Disable",
        0, true, 0.0
    );

    cvar_nom_ignore = CreateConVar(
        "sm_umc_prefixexclude_nominations",
        "0",
        "Determines if nominations are exempt from being excluded due to Prefix Exclusion.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_display_ignore = CreateConVar(
        "sm_umc_prefixexclude_display",
        "0",
        "Determines if maps being displayed are exempt from being excluded due to Prefix Exclusion.",
        0, true, 0.0, true, 1.0
    );
    
    AutoExecConfig(true, "umc-prefixexclude");
    
    prefix_array = CreateArray(ByteCountToCells(MAP_LENGTH));
}

public OnConfigsExecuted()
{
    decl String:prefix[MAP_LENGTH];
    GetCurrentMapPrefix(prefix, sizeof(prefix));
    AddToMemoryArray(prefix, prefix_array, GetConVarInt(cvar_prev));
}

GetCurrentMapPrefix(String:buffer[], maxlen)
{
    decl String:currentMap[MAP_LENGTH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    
    GetMapPrefix(currentMap, buffer, maxlen);
}

stock GetMapPrefix(const String:map[], String:buffer[], maxlen)
{
    static Handle:re = INVALID_HANDLE;
    if (re == INVALID_HANDLE)
    {
        re = CompileRegex("^([a-zA-Z0-9]*)_(.*)$");
    }
    
    if (MatchRegex(re, map) > 1)
    {
        GetRegexSubString(re, 1, buffer, maxlen);
    }
    else
    {
        strcopy(buffer, maxlen, "");
    }
}

//Called when UMC wants to know if this map is excluded
public Action:UMC_OnDetermineMapExclude(Handle:kv, const String:map[], const String:group[], bool:isNomination, bool:forMapChange)
{
    new size = GetArraySize(prefix_array);
    
    if (size == 0 || GetConVarInt(cvar_prev) == 0)
    {
        return Plugin_Continue;
    }
    if (isNomination && GetConVarBool(cvar_nom_ignore))
    {
        return Plugin_Continue;
    }
    if (!forMapChange && GetConVarBool(cvar_display_ignore))
    {
        return Plugin_Continue;
    }
    if (kv == INVALID_HANDLE)
    {
        return Plugin_Continue;
    }
    decl String:mapPrefix[MAP_LENGTH];
    GetMapPrefix(map, mapPrefix, sizeof(mapPrefix));
    
    new amt = GetConVarInt(cvar_amt);
    decl String:prefix[MAP_LENGTH];
    for (new i = 0; i < size; i++)
    {
        GetArrayString(prefix_array, i, prefix, sizeof(prefix));
        if (StrEqual(mapPrefix, prefix, false) && (--amt == 0))
        {
            return Plugin_Stop;
        }
    }
    
    return Plugin_Continue;
}
