#include <sourcemod>
#include <discord>

#define PLUGIN_VERSION "1.0"

#define MSG_BAN "{\"content\":\"{MENTION}\",\"attachments\": [{\"color\": \"{COLOR}\",\"title\": \"View on Sourcebans\",\"title_link\": \"{SOURCEBANS}\",\"fields\": [{\"title\": \"Player\",\"value\": \"{NICKNAME} ( {STEAMID} )\",\"short\": true},{\"title\": \"Admin\",\"value\": \"{ADMIN}\",\"short\": true},{\"title\": \"Ban Length\",\"value\": \"{BANLENGTH}\",\"short\": true},{\"title\": \"Reason\",\"value\": \"{REASON}\",\"short\": true}]}]}"

ConVar g_cColor = null;
ConVar g_cSourcebans = null;
ConVar g_cWebhook = null;
ConVar g_cMention = null;

public Plugin myinfo = 
{
	name = "Discord: SourceBans",
	author = ".#Zipcore",
	description = "",
	version = PLUGIN_VERSION,
	url = "www.zipcore.net"
}

public void OnPluginStart()
{
	CreateConVar("discord_sourcebans_version", PLUGIN_VERSION, "Discord SourceBans version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_cColor = CreateConVar("discord_sourcebans_color", "#ff2222", "Discord/Slack attachment color.");
	g_cSourcebans = CreateConVar("discord_sourcebans_url", "https://sb.eu.3kliksphilip.com/index.php?p=banlist&searchText={STEAMID}", "Link to sourcebans.");
	g_cWebhook = CreateConVar("discord_sourcebans_webhook", "sourcebans", "Config key from configs/discord.cfg.");
	g_cMention = CreateConVar("discord_sourcebans_mention", "@here", "This allows you to mention reports, leave blank to disable.");
	
	AutoExecConfig(true, "discord_sourcebans");
}

public int SBPP_OnBanPlayer(int iAdmin, int iTarget, int iTime, const char[] sReason)
{
	PrePareMsg(iAdmin, iTarget, iTime, sReason);
}

public int OnSBBanPlayer(int client, int target, int time, char[] reason)
{
	PrePareMsg(client, target, time, reason);
}

void PrePareMsg(int client, int target, int time, const char[] reason)
{
	char sColor[8];
	g_cColor.GetString(sColor, sizeof(sColor));
	
	char sAuth[32];
	GetClientAuthId(target, AuthId_Steam2, sAuth, sizeof(sAuth));
	
	char sName[32];
	GetClientName(target, sName, sizeof(sName));
	
	char sAdminName[32];
	if(client && IsClientInGame(client))
		GetClientName(client, sAdminName, sizeof(sAdminName));
	else sAdminName = "CONSOLE";
	
	char sLength[32];
	if(time == 0)
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
	else if (time > 0) Format(sLength, sizeof(sLength), "%d min%s", time, time == 1 ? "" : "s");
	else return;
    
	Discord_EscapeString(sName, strlen(sName));
	Discord_EscapeString(sAdminName, strlen(sAdminName));
	
	char sMSG[2048] = MSG_BAN;
	
	char sSourcebans[512];
	g_cSourcebans.GetString(sSourcebans, sizeof(sSourcebans));
	
	char sReason[64];
	strcopy(sReason, sizeof(sReason), reason);
	Discord_EscapeString(sReason, sizeof(sReason));
	
	char sMention[512];
	g_cMention.GetString(sMention, sizeof(sMention));
	
	ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);
	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);
	ReplaceString(sMSG, sizeof(sMSG), "{SOURCEBANS}", sSourcebans);
	ReplaceString(sMSG, sizeof(sMSG), "{STEAMID}", sAuth);
	ReplaceString(sMSG, sizeof(sMSG), "{REASON}", sReason);
	ReplaceString(sMSG, sizeof(sMSG), "{BANLENGTH}", sLength);
	ReplaceString(sMSG, sizeof(sMSG), "{ADMIN}", sAdminName);
	ReplaceString(sMSG, sizeof(sMSG), "{NICKNAME}", sName);
	
	SendMessage(sMSG);
}

SendMessage(char[] sMessage)
{
	char sWebhook[32];
	g_cWebhook.GetString(sWebhook, sizeof(sWebhook));
	Discord_SendMessage(sWebhook, sMessage);
}