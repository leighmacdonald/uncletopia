#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <gamemode>

#pragma newdecls required

public Plugin myinfo =
{
    name        = "[TF2] Waiting Doors",
    author      = "stephanie, Nanochip, & Lange",
    description = "Open spawn doors during waiting for players round.",
    version     = "0.0.6",
    url         = "https://sappho.io/"
};

public void TF2_OnWaitingForPlayersStart()
{
    TF2_GameMode mode = TF2_DetectGameMode();

    if (mode == TF2_GameMode_PL || mode == TF2_GameMode_ADCP)
    {
        CreateTimer(0.25, openDoorsTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

/* OpenDoors - from SOAP-TF2DM - https://github.com/Lange/SOAP-TF2DM/blob/master/addons/sourcemod/scripting/soap_tf2dm.sp#L1181-L1207
 *
 * Initially forces all doors open and keeps them unlocked even when they close.
 * -------------------------------------------------------------------------- */

public Action openDoorsTimer(Handle timer)
{
    int ent = -1;
    // search for all func doors
    while ((ent = FindEntityByClassname(ent, "func_door")) > 0)
    {
        if (IsValidEntity(ent))
        {
            AcceptEntityInput(ent, "unlock", -1);
            AcceptEntityInput(ent, "open", -1);
            FixNearbyDoorRelatedThings(ent);
        }
    }
    // reset ent
    ent = -1;
    // search for all other possible doors
    while ((ent = FindEntityByClassname(ent, "prop_dynamic")) > 0)
    {
        if (IsValidEntity(ent))
        {
            char iName[64];
            char modelName[64];
            GetEntPropString(ent, Prop_Data, "m_iName", iName, sizeof(iName));
            GetEntPropString(ent, Prop_Data, "m_ModelName", modelName, sizeof(modelName));
            if
            (
                    StrContains(iName, "door", false)       != -1
                 || StrContains(iName, "gate", false)       != -1
                 || StrContains(iName, "exit", false)       != -1
                 || StrContains(iName, "grate", false)      != -1
                 || StrContains(modelName, "door", false)   != -1
                 || StrContains(modelName, "gate", false)   != -1
                 || StrContains(modelName, "exit", false)   != -1
                 || StrContains(modelName, "grate", false)  != -1
            )
            {
                AcceptEntityInput(ent, "unlock", -1);
                AcceptEntityInput(ent, "open", -1);
                FixNearbyDoorRelatedThings(ent);
            }
        }
    }
    // reset ent
    ent = -1;
    // search for all other possible doors
    while ((ent = FindEntityByClassname(ent, "func_brush")) > 0)
    {
        if (IsValidEntity(ent))
        {
            char brushName[64];
            GetEntPropString(ent, Prop_Data, "m_iName", brushName, sizeof(brushName));
            if
            (
                    StrContains(brushName, "door", false)   != -1
                 || StrContains(brushName, "gate", false)   != -1
                 || StrContains(brushName, "exit", false)   != -1
                 || StrContains(brushName, "grate", false)  != -1
            )
            {
                RemoveEntity(ent);
                FixNearbyDoorRelatedThings(ent);
            }
        }
    }
}

// remove any func_brushes that could be blockbullets and open area portals near those func_brushes
void FixNearbyDoorRelatedThings(int ent)
{
    float doorLocation[3];
    float brushLocation[3];

    GetEntPropVector(ent, Prop_Send, "m_vecOrigin", doorLocation);

    int iterEnt = -1;
    while ((iterEnt = FindEntityByClassname(iterEnt, "func_brush")) > 0)
    {
        if (IsValidEntity(iterEnt))
        {
            GetEntPropVector(iterEnt, Prop_Send, "m_vecOrigin", brushLocation);
            if (GetVectorDistance(doorLocation, brushLocation) < 50.0)
            {
                char brushName[32];
                GetEntPropString(iterEnt, Prop_Data, "m_iName", brushName, sizeof(brushName));
                if
                (
                        StrContains(brushName, "bullet", false) != -1
                     || StrContains(brushName, "door", false)   != -1
                )
                {
                    RemoveEntity(iterEnt);
                }
            }
        }
    }

    // iterate thru all area portals on the map and open them
    // don't worry - the client immediately closes ones that aren't neccecary to be open. probably.
    iterEnt = -1;
    while ((iterEnt = FindEntityByClassname(iterEnt, "func_areaportal")) > 0)
    {
        if (IsValidEntity(iterEnt))
        {
            AcceptEntityInput(iterEnt, "Open");
        }
    }
}
