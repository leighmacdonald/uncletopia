#include <sourcemod>
#include <calladmin>
#include "include/discord.inc"

#define PLUGIN_VERSION "1.1"

#define REPORT_MSG "{\"username\":\"{BOTNAME}\", \"content\":\"{MENTION}\",\"attachments\": [{\"color\": \"{COLOR}\",\"title\": \"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT}){REFER_ID}\",\"fields\": [{\"title\": \"Reason\",\"value\": \"{REASON}\",\"short\": true},{\"title\": \"Reporter\",\"value\": \"{REPORTER_NAME} ({REPORTER_ID})\",\"short\": true},{\"title\": \"Target\",\"value\": \"{TARGET_NAME} ({TARGET_ID})\",\"short\": true}]}]}"
#define CLAIM_MSG "{\"username\":\"{BOTNAME}\", \"content\":\"{MSG}\",\"attachments\": [{\"color\": \"{COLOR}\",\"title\": \"{HOSTNAME} (steam://connect/{SERVER_IP}:{SERVER_PORT})\",\"fields\": [{\"title\": \"Admin\",\"value\": \"{ADMIN}\",\"short\": false}]}]}"

char sSymbols[25][1] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"};

char g_sHostPort[6];
char g_sServerName[256];
char g_sHostIP[16];

ConVar g_cBotName = null;
ConVar g_cClaimMsg = null;
ConVar g_cColor = null;
ConVar g_cColor2 = null;
ConVar g_cColor3 = null;
ConVar g_cMention = null;
ConVar g_cRemove = null;
ConVar g_cRemove2 = null;
ConVar g_cWebhook = null;
ConVar g_cIP = null;

public Plugin myinfo = 
{
	name = "Discord: CallAdmin",
	author = ".#Zipcore",
	description = "",
	version = PLUGIN_VERSION,
	url = "www.zipcore.net"
}

public void OnPluginStart()
{
	CreateConVar("discord_calladmin_version", PLUGIN_VERSION, "Discord CallAdmin version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_cBotName = CreateConVar("discord_calladmin_botname", "", "Report botname, leave this blank to use the webhook default name.");
	g_cClaimMsg = CreateConVar("discord_calladmin_claimmsg", "An admin is claiming reports on this server.", "Message to send when admin uses the claim command.");
	g_cColor = CreateConVar("discord_calladmin_color", "#ff2222", "Discord/Slack attachment color used for reports.");
	g_cColor2 = CreateConVar("discord_calladmin_color2", "#22ff22", "Discord/Slack attachment color used for admin claims.");
	g_cColor3 = CreateConVar("discord_calladmin_color3", "#ff9911", "Discord/Slack attachment color used for admin reports.");
	g_cMention = CreateConVar("discord_calladmin_mention", "@here", "This allows you to mention reports, leave blank to disable.");
	g_cRemove = CreateConVar("discord_calladmin_remove", " | By PulseServers.com", "Remove this part from servername before sending the report.");
	g_cRemove2 = CreateConVar("discord_calladmin_remove2", "3kliksphilip.com | ", "Remove this part from servername before sending the report.");
	g_cWebhook = CreateConVar("discord_calladmin_webhook", "calladmin", "Config key from configs/discord.cfg.");
	g_cIP = CreateConVar("discord_calladmin_ip", "0.0.0.0", "Set your server IP here when auto detection is not working for you. (Use 0.0.0.0 to disable manually override)");
	
	AutoExecConfig(true, "discord_calladmin");
	
	RegAdminCmd("sm_claim", Cmd_Claim, ADMFLAG_BAN);
}

public void OnAllPluginsLoaded()
{
	if (!LibraryExists("calladmin"))
	{
		SetFailState("CallAdmin not found");
		return;
	}
	
	UpdateIPPort();
	CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}

void UpdateIPPort()
{
	GetConVarString(FindConVar("hostport"), g_sHostPort, sizeof(g_sHostPort));
	
	GetConVarString(g_cIP, g_sHostIP, sizeof(g_sHostIP));
	
	if(!StrEqual(g_sHostIP, "0.0.0.0"))
		return;
	
	if(FindConVar("net_public_adr") != null)
		GetConVarString(FindConVar("net_public_adr"), g_sHostIP, sizeof(g_sHostIP));
	
	if(strlen(g_sHostIP) == 0 && FindConVar("ip") != null)
		GetConVarString(FindConVar("ip"), g_sHostIP, sizeof(g_sHostIP));
	
	if(strlen(g_sHostIP) == 0 && FindConVar("hostip") != null)
	{
		int ip = GetConVarInt(FindConVar("hostip"));
		FormatEx(g_sHostIP, sizeof(g_sHostIP), "%d.%d.%d.%d", (ip >> 24) & 0x000000FF, (ip >> 16) & 0x000000FF, (ip >> 8) & 0x000000FF, ip & 0x000000FF);
	}
}

public void CallAdmin_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal)
{
	if (type == ServerData_HostName)
		CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));
}

public Action Cmd_Claim(int client, int args)
{
	char sName[(MAX_NAME_LENGTH + 1) * 2];
	
	if (client == 0)
	{
		strcopy(sName, sizeof(sName), "CONSOLE");
	}
	else
	{
		GetClientName(client, sName, sizeof(sName));
		Discord_EscapeString(sName, sizeof(sName));
	}
	
	char sRemove[32];
	g_cRemove.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");
	
	g_cRemove2.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");
	
	Discord_EscapeString(g_sServerName, sizeof(g_sServerName));
	
	char sClaimMsg[512];
	g_cClaimMsg.GetString(sClaimMsg, sizeof(sClaimMsg));
	
	Discord_EscapeString(sClaimMsg, sizeof(sClaimMsg));
	
	char sBot[512];
	g_cBotName.GetString(sBot, sizeof(sBot));
	
	char sColor[8];
	g_cColor2.GetString(sColor, sizeof(sColor));
	
	char sMSG[512] = CLAIM_MSG;
	
	ReplaceString(sMSG, sizeof(sMSG), "{BOTNAME}", sBot);
	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);
	ReplaceString(sMSG, sizeof(sMSG), "{ADMIN}", sName);
	ReplaceString(sMSG, sizeof(sMSG), "{MSG}", sClaimMsg);
	
	UpdateIPPort();
	
	ReplaceString(sMSG, sizeof(sMSG), "{HOSTNAME}", g_sServerName);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_IP}", g_sHostIP);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_PORT}", g_sHostPort);
	
	SendMessage(sMSG);
	
	ReplyToCommand(client, "Message send.");
	
	return Plugin_Handled;
}

public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	char sColor[8];
	if(!CheckCommandAccess(client, "sm_ban", ADMFLAG_BAN, true))
		g_cColor.GetString(sColor, sizeof(sColor));
	else g_cColor3.GetString(sColor, sizeof(sColor));
	
	char sReason[(REASON_MAX_LENGTH + 1) * 2];
	strcopy(sReason, sizeof(sReason), reason);
	Discord_EscapeString(sReason, sizeof(sReason));
	
	char clientAuth[21];
	char clientName[(MAX_NAME_LENGTH + 1) * 2];
	
	if (client == REPORTER_CONSOLE)
	{
		strcopy(clientName, sizeof(clientName), "Server");
		strcopy(clientAuth, sizeof(clientAuth), "CONSOLE");
	}
	else
	{
		GetClientAuthId(client, AuthId_Steam2, clientAuth, sizeof(clientAuth));
		GetClientName(client, clientName, sizeof(clientName));
		Discord_EscapeString(clientName, sizeof(clientName));
	}
	
	char targetAuth[21];
	char targetName[(MAX_NAME_LENGTH + 1) * 2];
	
	GetClientAuthId(target, AuthId_Steam2, targetAuth, sizeof(targetAuth));
	GetClientName(target, targetName, sizeof(targetName));
	Discord_EscapeString(targetName, sizeof(targetName));
	
	char sRemove[32];
	g_cRemove.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");
	
	g_cRemove2.GetString(sRemove, sizeof(sRemove));
	if (!StrEqual(sRemove, ""))
		ReplaceString(g_sServerName, sizeof(g_sServerName), sRemove, "");

	
	Discord_EscapeString(g_sServerName, sizeof(g_sServerName));
	
	char sMention[512];
	g_cMention.GetString(sMention, sizeof(sMention));
	
	char sBot[512];
	g_cBotName.GetString(sBot, sizeof(sBot));
	
	char sMSG[4096] = REPORT_MSG;
	
	ReplaceString(sMSG, sizeof(sMSG), "{BOTNAME}", sBot);
	ReplaceString(sMSG, sizeof(sMSG), "{MENTION}", sMention);
	
	ReplaceString(sMSG, sizeof(sMSG), "{COLOR}", sColor);
	
	UpdateIPPort();
	
	ReplaceString(sMSG, sizeof(sMSG), "{HOSTNAME}", g_sServerName);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_IP}", g_sHostIP);
	ReplaceString(sMSG, sizeof(sMSG), "{SERVER_PORT}", g_sHostPort);
	
	ReplaceString(sMSG, sizeof(sMSG), "{REASON}", sReason);
	
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_NAME}", clientName);
	ReplaceString(sMSG, sizeof(sMSG), "{REPORTER_ID}", clientAuth);
	
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_NAME}", targetName);
	ReplaceString(sMSG, sizeof(sMSG), "{TARGET_ID}", targetAuth);
	
	char sRefer[16];
	Format(sRefer, sizeof(sRefer), " # %s%s-%d%d", sSymbols[GetRandomInt(0, 25-1)], sSymbols[GetRandomInt(0, 25-1)], GetRandomInt(0, 9), GetRandomInt(0, 9));
	ReplaceString(sMSG, sizeof(sMSG), "{REFER_ID}", sRefer);
	
	SendMessage(sMSG);
}

SendMessage(char[] sMessage)
{
	char sWebhook[32];
	g_cWebhook.GetString(sWebhook, sizeof(sWebhook));
	Discord_SendMessage(sWebhook, sMessage);
}