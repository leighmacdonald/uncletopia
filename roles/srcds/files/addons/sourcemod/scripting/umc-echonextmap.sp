/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 *                               Ultimate Mapchooser - Echo Nextmap                              *
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
    name = "[UMC] Echo Nextmap",
    author = "Previous:Steell,Powerlord - Current: Mr.Silence",
    description = "Displays messages to the server when the next map is set.",
    version = PL_VERSION,
    url = "http://forums.alliedmods.net/showthread.php?t=134190"
}

//Cvars
new Handle:cvar_center  = INVALID_HANDLE;
new Handle:cvar_hint    = INVALID_HANDLE;
new Handle:cvar_display = INVALID_HANDLE;


//Called when the plugin loads.
public OnPluginStart()
{
    cvar_display = CreateConVar(
        "sm_umc_echonextmap_display",
        "0",
        "If enabled, the displayed map name will be the real name of the map, not the name taken from the map's \"display\" setting.",
        0, true, 0.0, true, 1.0
    );

    cvar_center = CreateConVar(
        "sm_umc_echonextmap_center",
        "1",
        "If enabled, a message will be displayed in the center of the screen when the next map is set.",
        0, true, 0.0, true, 1.0
    );
    
    cvar_hint = CreateConVar(
        "sm_umc_exchonextmap_hint",
        "0",
        "If enabled, a message will be displayed in the hint box when the next map is set.",
        0, true, 0.0, true, 1.0
    );

    //Create the config if it doesn't exist, and then execute it.
    AutoExecConfig(true, "umc-echonextmap");
    
    //Load the translations file
    LoadTranslations("ultimate-mapchooser.phrases");

}

//Called when UMC has set the next map.
public UMC_OnNextmapSet(Handle:kv, const String:map[], const String:group[], const String:display[])
{
    new bool:disp = !GetConVarBool(cvar_display);

    if (GetConVarBool(cvar_center))
    {
        new String:msg[256];
        if (disp && strlen(display) > 0)
        {
            Format(msg, sizeof(msg), "[UMC] %t", "Next Map", display);
        }
        else
        {
            Format(msg, sizeof(msg), "[UMC] %t", "Next Map", map);
        }
        DisplayServerMessage(msg, "C");
    }
    if (GetConVarBool(cvar_hint))
    {
        if (disp && strlen(display) > 0)
        {
            PrintHintTextToAll("[UMC] %t", "Next Map", display);
        }
        else
        {
            PrintHintTextToAll("[UMC] %t", "Next Map", map);
        }
    }
}