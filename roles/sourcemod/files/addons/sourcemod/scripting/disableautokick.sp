#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo = 
{
	name = "Disable Auto-Kick",
	author = "The-Killer",
	description = "Protects players with reserve slot from being autokicked",
	version = "0.3",
	url = "http://www.righttorule.com/"
};

public void OnPluginStart()
{
   LoadTranslations("common.phrases");
   CreateConVar("sm_disable_autokick_version", "0.1", "Disable Autokick version");
   RegAdminCmd("sm_disable_autokick", Command_disable_autokick, ADMFLAG_GENERIC, "sm_disable_autokick <userid>","");
}

public Action Command_disable_autokick(int client, int args)
{
  if (args < 2) {
      ReplyToCommand(client, "[SM] Usage: sm_disable_autokick <userid>");
      return Plugin_Handled;
  }
    
  char target[64];
  GetCmdArg(1,target,sizeof(target));

  //Search for clients
  int foundClient = FindTarget(client, target, false, false);
  int targetid = GetClientUserId(foundClient);
  ServerCommand("mp_disable_autokick %d", targetid);

  return Plugin_Handled;
}

public void OnClientPostAdminCheck(int client)
{
    int flags = GetUserFlagBits(client);
    if (flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION) {
    int id = GetClientUserId(client);
        ServerCommand("mp_disable_autokick %d", id);
		}
}