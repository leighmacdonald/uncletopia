#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sourcemod>
#include <accelerator>
#include <discord>

#define MSG_CRASH "{\"username\":\"{HOOKNAME}\", \"content\":\"{MENTION} {CRASHMESSAGE} ({SERVERNAME}) > {CRASHURL}{CRASHID}\"}"
#define DEFAULT_URL "https://crash.limetech.org/?id="
#define PLUGIN_VERSION "1.0"
#define URL_ENTRY "MinidumpUrl"

ConVar g_cMention = null;
ConVar g_cHookName = null;
ConVar g_cServerName = null;
ConVar g_cWebhook = null;
ConVar g_cCrashMessage = null;

public Plugin myinfo = 
{
    name = "Discord: Accelerator",
    author = "Prefix",
    description = "Sends discord message when server crashed.",
    version = "1.0",
    url = ""
}

public void OnPluginStart()
{
    CreateConVar("discord_accelerator_version", PLUGIN_VERSION, "Discord Accelerator version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
    
    g_cMention = CreateConVar("discord_accelerator_mention", "", "Role ID ir User ID to mention.\nYou can get Role ID or User ID by making \\@User or \\@Group\nIf you want to mention group add & before ID");
    g_cHookName = CreateConVar("discord_accelerator_hookname", "Captain Crash", "What nickname hook will have.");
    g_cServerName = CreateConVar("discord_accelerator_servername", "", "Short server name");
    g_cWebhook = CreateConVar("discord_accelerator_webhook", "accelerator", "Config key from configs/discord.cfg."); 
    g_cCrashMessage = CreateConVar("discord_accelerator_message", "Server crashed", "Information text that server crashed in message."); 
    AutoExecConfig(true, "discord_accelerator");
}

public void OnCrashUpdated(int num, const char [] crashId)
{
    char sMSG[2048] = MSG_CRASH;

    char sMention[40];
    g_cMention.GetString(sMention, sizeof(sMention));

    if (strlen(sMention) > 1) {
        Format(sMention, sizeof(sMention), "<@%s>, ", sMention);
        ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);
    } else {
        ReplaceString(sMSG, sizeof(sMSG), "{MENTION} ", "");
    }

    char sHookName[40];
    g_cHookName.GetString(sHookName, sizeof(sHookName));
    if (strlen(sHookName) > 1)
        ReplaceString(sMSG, sizeof(sMSG), "{HOOKNAME}", sHookName);
    else
        ReplaceString(sMSG, sizeof(sMSG), "\"username\":\"{HOOKNAME}\",", "");
        
    char sServerName[65];
    g_cServerName.GetString(sServerName, sizeof(sServerName));
    if (strlen(sHookName) > 1) {
        ReplaceString(sMSG, sizeof(sMSG), "{SERVERNAME}", sServerName);
    } else {
        ReplaceString(sMSG, sizeof(sMSG), "({SERVERNAME})", "");
    }
    char sUrlPath[50];
    if (GetFromCoreFile(URL_ENTRY, sUrlPath, sizeof(sUrlPath))) {
        ReplaceString(sUrlPath, sizeof(sUrlPath), "/submit", sUrlPath);
        Format(sUrlPath, sizeof(sUrlPath), "%s/?id=", sUrlPath);
        ReplaceString(sMSG, sizeof(sMSG), "{CRASHURL}", sUrlPath);
    } else {
        ReplaceString(sMSG, sizeof(sMSG), "{CRASHURL}", DEFAULT_URL);
    }
    ReplaceString(sMSG, sizeof(sMSG), "{CRASHID}", crashId);

    char sCrashMessage[60];
    g_cCrashMessage.GetString(sCrashMessage, sizeof(sCrashMessage));
    if (strlen(sCrashMessage) > 0) {
        ReplaceString(sMSG, sizeof(sMSG), "{CRASHMESSAGE}", sCrashMessage);
    } else {
        ReplaceString(sMSG, sizeof(sMSG), "{CRASHMESSAGE}", "Server crashed");
    }

    SendMessage(sMSG);
}

void SendMessage(char[] sMessage)
{
    char sWebhook[32];
    g_cWebhook.GetString(sWebhook, sizeof(sWebhook));
    Discord_SendMessage(sWebhook, sMessage);    
}

bool GetFromCoreFile(const char[] entry, char[] value, int maxlength)
{
    char path_core[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path_core, sizeof(path_core), "configs/core.cfg");
    KeyValues kv = new KeyValues("Core");
    kv.ImportFromFile(path_core);
    if (!kv.JumpToKey(entry)) {
        delete kv;
        return false;
    }
    kv.GetString(entry, value, maxlength);
    delete kv;
    return true;
}