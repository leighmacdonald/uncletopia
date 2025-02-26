#include <sourcemod>
#include <discord>

#define PLUGIN_VERSION "1.1"

#define MSG_BAN "{\"content\":\"{MENTION}\",\"attachments\": [{\"color\": \"{COLOR}\",\"title\": \"View on Sourcebans\",\"title_link\": \"{SOURCEBANS}\",\"fields\": [{\"title\": \"Player\",\"value\": \"{NICKNAME} ( {STEAMID} )\",\"true\": false},{\"title\": \"Admin\",\"value\": \"{ADMIN}\",\"short\": true},{\"title\": \"{COMMTYPE} Length\",\"value\": \"{BANLENGTH}\",\"short\": true},{\"title\": \"Reason\",\"value\": \"{REASON}\",\"short\": true}]}]}"

ConVar g_cColorGag = null;
ConVar g_cColorMute = null;
ConVar g_cColorSilence = null;
ConVar g_cSourcebans = null;
ConVar g_cWebhookGag = null;
ConVar g_cWebhookMute = null;
ConVar g_cWebhookSilence = null;
ConVar g_cWebhookUnGag = null;
ConVar g_cWebhookUnMute = null;
ConVar g_cWebhookUnSilence = null;
ConVar g_cWebhookUnGagTmp = null;
ConVar g_cWebhookUnMuteTmp = null;
ConVar g_cWebhookUnSilenceTmp = null;
ConVar g_cMention = null;

public Plugin myinfo = 
{
	name = "Discord: SourceComms",
	author = ".#Zipcore",
	description = "",
	version = PLUGIN_VERSION,
	url = "www.zipcore.net"
}

public void OnPluginStart()
{
	CreateConVar("discord_sourcecomms_version", PLUGIN_VERSION, "Discord SourceComms version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_cColorGag = CreateConVar("discord_sourcecomms_color_gag", "#ffff22", "Discord/Slack attachment gag color.");
	g_cColorMute = CreateConVar("discord_sourcecomms_color_mute", "#2222ff", "Discord/Slack attachment mute color.");
	g_cColorSilence = CreateConVar("discord_sourcecomms_color_silence", "#ff22ff", "Discord/Slack attachment silence color.");
	g_cSourcebans = CreateConVar("discord_sourcecomms_url", "https://sb.eu.3kliksphilip.com/index.php?p=commslist&searchText={STEAMID}", "Link to sourcebans.");
	g_cWebhookGag = CreateConVar("discord_sourcecomms_webhook_gag", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookMute = CreateConVar("discord_sourcecomms_webhook_mute", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookSilence = CreateConVar("discord_sourcecomms_webhook_silence", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookUnGag = CreateConVar("discord_sourcecomms_webhook_ungag", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookUnMute = CreateConVar("discord_sourcecomms_webhook_unmute", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookUnSilence = CreateConVar("discord_sourcecomms_webhook_unsilence", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookUnGagTmp = CreateConVar("discord_sourcecomms_webhook_ungag_tmp", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookUnMuteTmp = CreateConVar("discord_sourcecomms_webhook_unmute_tmp", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cWebhookUnSilenceTmp = CreateConVar("discord_sourcecomms_webhook_unsilence_tmp", "sourcecomms", "Config key from configs/discord.cfg.");
	g_cMention = CreateConVar("discord_sourcecomms_mention", "@here", "This allows you to mention reports, leave blank to disable.");
	
	AutoExecConfig(true, "discord_sourcecomms");
}

public int SourceComms_OnMutePlayer(int client, int target, int time, char[] reason)
{
	PrePareMsg(client, target, time, 1, reason);
}

public int SourceComms_OnGagPlayer(int client, int target, int time, char[] reason)
{
	PrePareMsg(client, target, time, 2, reason);
}

public int SourceComms_OnSilencePlayer(int client, int target, int time, char[] reason)
{
	PrePareMsg(client, target, time, 3, reason);
}

public int SourceComms_OnBlockAdded(int client, int target, int time, int commstype, char[] reason)
{
	PrePareMsg(client, target, time, commstype, reason);
}

public int PrePareMsg(int client, int target, int time, int commstype, char[] reason)
{
	char sAuth[32];
	GetClientAuthId(target, AuthId_Steam2, sAuth, sizeof(sAuth));
	
	char sName[32];
	GetClientName(target, sName, sizeof(sName));
	
	char sAdminName[32];
	if(client && IsClientInGame(client))
		GetClientName(client, sAdminName, sizeof(sAdminName));
	else sAdminName = "CONSOLE";
	
	char sLength[32];
	if(time < 0)
	{
		sLength = "Session";
	}
	else if(time == 0)
	{
		sLength = "Permanent";
	}
	else if (time >= 525600)
	{
		int years = RoundToFloor(time / 525600.0);
		Format(sLength, sizeof(sLength), "%d mins (%d year%s)", time, years, years == 1 ? "" : "s");
	}
	else if (time >= 10080)
	{
		int weeks = RoundToFloor(time / 10080.0);
		Format(sLength, sizeof(sLength), "%d mins (%d week%s)", time, weeks, weeks == 1 ? "" : "s");
	}
	else if (time >= 1440)
	{
		int days = RoundToFloor(time / 1440.0);
		Format(sLength, sizeof(sLength), "%d mins (%d day%s)", time, days, days == 1 ? "" : "s");
	}
	else if (time >= 60)
	{
		int hours = RoundToFloor(time / 60.0);
		Format(sLength, sizeof(sLength), "%d mins (%d hour%s)", time, hours, hours == 1 ? "" : "s");
	}
	else Format(sLength, sizeof(sLength), "%d min%s", time, time == 1 ? "" : "s");
    
	Discord_EscapeString(sName, strlen(sName));
	Discord_EscapeString(sAdminName, strlen(sAdminName));
	
	char sMSG[2048] = MSG_BAN;
	
	char sSourcebans[512];
	g_cSourcebans.GetString(sSourcebans, sizeof(sSourcebans));
	
	char sColor[512];
	char sType[64];
	
	switch(commstype)
	{
		case 1: 
		{
			g_cColorMute.GetString(sColor, sizeof(sColor));
			sType = "Mute";
		}
		case 2: 
		{
			g_cColorGag.GetString(sColor, sizeof(sColor));
			sType = "Gag";
		}
		case 3: 
		{
			g_cColorSilence.GetString(sColor, sizeof(sColor));
			sType = "Silence";
		}
		case 4: 
		{
			g_cColorSilence.GetString(sColor, sizeof(sColor));
			sType = "UnMute";
		}
		case 5: 
		{
			g_cColorSilence.GetString(sColor, sizeof(sColor));
			sType = "UnGag";
		}
		case 6: 
		{
			g_cColorSilence.GetString(sColor, sizeof(sColor));
			sType = "UnSilence";
		}
		case 14: 
		{
			g_cColorSilence.GetString(sColor, sizeof(sColor));
			sType = "UnMute (tmp)";
		}
		case 15: 
		{
			g_cColorSilence.GetString(sColor, sizeof(sColor));
			sType = "UnGag (tmp)";
		}
		case 16: 
		{
			g_cColorSilence.GetString(sColor, sizeof(sColor));
			sType = "UnSilence (tmp)";
		}
		
		default:
		{
			LogError("Commstype %i not found!", commstype);
			return;
		}
	}
	
	char sReason[64];
	strcopy(sReason, sizeof(sReason), reason);
	Discord_EscapeString(sReason, sizeof(sReason));
	
	char sMention[512];
	g_cMention.GetString(sMention, sizeof(sMention));
	
	ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);
	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);
	ReplaceString(sMSG, sizeof(sMSG), "{COMMTYPE}", sType);
	ReplaceString(sMSG, sizeof(sMSG), "{SOURCEBANS}", sSourcebans);
	ReplaceString(sMSG, sizeof(sMSG), "{STEAMID}", sAuth);
	ReplaceString(sMSG, sizeof(sMSG), "{REASON}", sReason);
	ReplaceString(sMSG, sizeof(sMSG), "{BANLENGTH}", sLength);
	ReplaceString(sMSG, sizeof(sMSG), "{ADMIN}", sAdminName);
	ReplaceString(sMSG, sizeof(sMSG), "{NICKNAME}", sName);
	
	SendMessage(sMSG, commstype);
}

SendMessage(char[] sMessage, int commstype)
{
	char sWebhook[32];
	switch(commstype)
	{
		case 1: 
		{
			g_cWebhookMute.GetString(sWebhook, sizeof(sWebhook));
		}
		case 2: 
		{
			g_cWebhookGag.GetString(sWebhook, sizeof(sWebhook));
		}
		case 3: 
		{
			g_cWebhookSilence.GetString(sWebhook, sizeof(sWebhook));
		}
		case 4: 
		{
			g_cWebhookUnMute.GetString(sWebhook, sizeof(sWebhook));
		}
		case 5: 
		{
			g_cWebhookUnGag.GetString(sWebhook, sizeof(sWebhook));
		}
		case 6: 
		{
			g_cWebhookUnSilence.GetString(sWebhook, sizeof(sWebhook));
		}
		case 14: 
		{
			g_cWebhookUnMuteTmp.GetString(sWebhook, sizeof(sWebhook));
		}
		case 15: 
		{
			g_cWebhookUnGagTmp.GetString(sWebhook, sizeof(sWebhook));
		}
		case 16: 
		{
			g_cWebhookUnSilenceTmp.GetString(sWebhook, sizeof(sWebhook));
		}
	}
	
	Discord_SendMessage(sWebhook, sMessage);
}