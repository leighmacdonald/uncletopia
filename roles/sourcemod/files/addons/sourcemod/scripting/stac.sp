#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

#define PLUGIN_VERSION  "5.4.1"

#define UPDATE_URL      "https://raw.githubusercontent.com/sapphonie/StAC-tf2/master/updatefile.txt"

public Plugin myinfo =
{
    name             =  "Steph's AntiCheat [StAC]",
    author           =  "https://sappho.io",
    description      =  "AntiCheat plugin for TF2 written by https://sappho.io . Originally forked from IntegriTF2 by Miggy, RIP",
    version          =   PLUGIN_VERSION,
    url              =  "https://sappho.io"
}


public void OnPluginStart()
{
    PrintToServer("\n\n----> StAC version [%s] loaded\n", PLUGIN_VERSION);

}

public void OnPluginEnd()
{
    PrintToServer("\n\n----> StAC version [%s] unloaded\n", PLUGIN_VERSION);
}

