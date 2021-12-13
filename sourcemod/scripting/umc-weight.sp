/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                                Ultimate Mapchooser - Map Weight                               *
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

public Plugin:myinfo =
{
    name = "[UMC] Map Weight",
    author = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Allows users to specify weights for maps and groups, making them more or less likely to be picked randomly.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

#define WEIGHT_KEY_MAP   "weight"
#define WEIGHT_KEY_GROUP "group_weight"

//Excludes maps with a set weight of 0
public Action:UMC_OnDetermineMapExclude(Handle:kv, const String:map[], const String:group[], bool:isNom, bool:forMapChange)
{
    if (kv == INVALID_HANDLE)
    {
        return Plugin_Continue;
    }
    
    KvRewind(kv);
    
    if (KvJumpToKey(kv, group))
    {
        if (KvJumpToKey(kv, map))
        {
            if (KvGetFloat(kv, WEIGHT_KEY_MAP, 1.0) == 0.0)
            {
                KvGoBack(kv);
                KvGoBack(kv);
                return Plugin_Stop;
            }
            KvGoBack(kv);
        }
        KvGoBack(kv);
    }
    return Plugin_Continue;
}

//Reweights a map when UMC requests.
public UMC_OnReweightMap(Handle:kv, const String:map[], const String:group[])
{
    if (kv == INVALID_HANDLE)
    {
        return;
    }
    
    KvRewind(kv);
    if (KvJumpToKey(kv, group))
    {
        if (KvJumpToKey(kv, map))
        {
            UMC_AddWeightModifier(KvGetFloat(kv, WEIGHT_KEY_MAP, 1.0));
            KvGoBack(kv);
        }
        KvGoBack(kv);
    }
}

//Reweights a group when UMC requests.
public UMC_OnReweightGroup(Handle:kv, const String:group[])
{
    if (kv == INVALID_HANDLE)
    {
        return;
    }
    
    KvRewind(kv);
    if (KvJumpToKey(kv, group))
    {
        UMC_AddWeightModifier(KvGetFloat(kv, WEIGHT_KEY_GROUP, 1.0));
        KvGoBack(kv);
    }
}
