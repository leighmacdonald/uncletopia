/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                              Ultimate Mapchooser - Player Limits                              *
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
#include <umc-playerlimits>

public Plugin:myinfo =
{
    name = "[UMC] Player Limits",
    author = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Allows users to specify player limits for maps.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

new Handle:cvar_nom_ignore = INVALID_HANDLE;
new Handle:cvar_display_ignore = INVALID_HANDLE;

public OnPluginStart()
{
    cvar_nom_ignore = CreateConVar(
        "sm_umc_playerlimits_nominations",
        "0",
        "Determines if nominations are exempt from being excluded due to Player Limits.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_display_ignore = CreateConVar(
        "sm_umc_playerlimits_display",
        "0",
        "Determines if maps being displayed are exempt from being excluded due to Player Limits.",
        0, true, 0.0, true, 1.0
    );
    
    AutoExecConfig(true, "umc-playerlimits");
}

//Called when UMC wants to know if this map is excluded
public Action:UMC_OnDetermineMapExclude(Handle:kv, const String:map[], const String:group[], bool:isNomination, bool:forMapChange)
{
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
    
    new defaultMin, defaultMax;
    new min, max;
    
    KvRewind(kv);
    if (KvJumpToKey(kv, group))
    {
        defaultMin = KvGetNum(kv, PLAYERLIMIT_KEY_GROUP_MIN, 0);
        defaultMax = KvGetNum(kv, PLAYERLIMIT_KEY_GROUP_MAX, MaxClients);
    
        if (KvJumpToKey(kv, map))
        {    
            min = KvGetNum(kv, PLAYERLIMIT_KEY_MAP_MIN, defaultMin);
            max = KvGetNum(kv, PLAYERLIMIT_KEY_MAP_MAX, defaultMax);
            KvGoBack(kv);
        }
        KvGoBack(kv);
    }
    
    if (IsPlayerCountBetween(min, max))
    {
        return Plugin_Continue;
    }
    
    return Plugin_Stop;
}

//Display Template
public UMC_OnFormatTemplateString(String:template[], maxlen, Handle:kv, const String:map[], const String:group[])
{
    new defaultMin, defaultMax;
    new min, max;
    
    KvRewind(kv);
    if (KvJumpToKey(kv, group))
    {
        defaultMin = KvGetNum(kv, PLAYERLIMIT_KEY_GROUP_MIN, 0);
        defaultMax = KvGetNum(kv, PLAYERLIMIT_KEY_GROUP_MAX, MaxClients);
    
        if (KvJumpToKey(kv, map))
        {    
            min = KvGetNum(kv, PLAYERLIMIT_KEY_MAP_MIN, defaultMin);
            max = KvGetNum(kv, PLAYERLIMIT_KEY_MAP_MAX, defaultMax);
            KvGoBack(kv);
        }
        KvGoBack(kv);
    }
    
    decl String:minString[3], String:maxString[3];
    Format(minString, sizeof(minString), "%d", min);
    Format(maxString, sizeof(maxString), "%d", max);
    
    decl String:minSearch[12], String:maxSearch[12];
    Format(minSearch, sizeof(minSearch), "{%s}", PLAYERLIMIT_KEY_MAP_MIN);
    Format(maxSearch, sizeof(maxSearch), "{%s}", PLAYERLIMIT_KEY_MAP_MAX);
    
    ReplaceString(template, maxlen, minSearch, minString, false);
    ReplaceString(template, maxlen, maxSearch, maxString, false);
}
