#include <sourcemod>
#include <clientprefs>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required
#pragma semicolon 1
#define PLUGIN_VERSION  "1.3"

public Plugin myinfo = {
  name = "No MOTD",
  author = "Original by MasterOfTheXP, modified by GC",
  description = "Removes the MOTD, autojoin random team, and autojoins classes.",
  version = PLUGIN_VERSION,
  url = "http://mstr.ca/"
};

bool clientMOTDBlocked[MAXPLAYERS + 1];

ConVar enableNoMotdCvar = null;
ConVar alwaysNoMotdCvar = null;

ConVar enableRandomTeamCvar = null;
ConVar alwaysRandomTeamCvar = null;

ConVar enableRandomClassCvar = null;
ConVar alwaysRandomClassCvar = null;

ConVar enableRememberClassCvar = null;
ConVar alwaysRememberClassCvar = null;

// Opt in to skipping the MOTD.
Cookie noMotdCookie = null;
// Opt in to auto joining a random team.
Cookie randomTeamCookie = null;
// Opt in to rejoining as a random class.
Cookie randomClassCookie = null;
// Opt in to rejoining as last played class.
Cookie rememberClassCookie = null;
// Store last played class.
Cookie latestClassCookie = null;

bool CvarEnabled(ConVar cvar) {
  char value[20];
  GetConVarString(cvar, value, sizeof(value));
  return StrEqual(value, "1");
}

bool CookieEnabled(int client, Cookie cookie) {
  char value[4];
  GetClientCookie(client, cookie, value, sizeof(value));
  return StrEqual(value, "1");
}

public void OnPluginStart()
{
  enableNoMotdCvar = CreateConVar("sm_nomotd", "", "If 1, allow clients to opt into skipping the MOTD.");
  alwaysNoMotdCvar = CreateConVar("sm_nomotd_force", "", "If 1, make all clients skip MOTD.");

  enableRandomTeamCvar = CreateConVar("sm_nomotd_randomteam", "", "If 1, allow clients to opt in to automatically joining a random team.");
  alwaysRandomTeamCvar = CreateConVar("sm_nomotd_randomteam_force", "", "If 1, make all clients automatically joining a random team.");

  enableRandomClassCvar = CreateConVar("sm_nomotd_randomclass", "", "If 1, allow clients to opt in to automatically joining a random class.");
  alwaysRandomClassCvar = CreateConVar("sm_nomotd_randomclass_force", "", "If 1, make all clients automatically join a random class.");

  enableRememberClassCvar = CreateConVar("sm_nomotd_rememberclass", "", "If 1, allow clients to opt in to automatically joining the last class they played.");
  alwaysRememberClassCvar = CreateConVar("sm_nomotd_rememberclass_force", "", "If 1, make all clients automatically join the last class they played.");

  CreateConVar("sm_nomotd_version", PLUGIN_VERSION, "No MOTD version", FCVAR_NOTIFY|FCVAR_SPONLY);

  noMotdCookie = RegClientCookie("no_motd", "No MOTD", CookieAccess_Protected);
  randomTeamCookie = RegClientCookie("random_team", "Random Team", CookieAccess_Protected);
  randomClassCookie = RegClientCookie("random_class", "Random Class", CookieAccess_Protected);
  rememberClassCookie = RegClientCookie("remember_class", "Remember Class", CookieAccess_Protected);

  // Register sm_settings menus. These can't be unregistered(?) so if
  // cvars are changed after server startpu, the menu will be out of
  // sync until the plugin is reloaded.
  if (CvarEnabled(enableNoMotdCvar) && !CvarEnabled(alwaysNoMotdCvar)) {
    SetCookiePrefabMenu(noMotdCookie, CookieMenu_OnOff_Int, "Skip MOTD");
  }
  if (CvarEnabled(enableRandomTeamCvar) && !CvarEnabled(alwaysRandomTeamCvar)) {
    SetCookiePrefabMenu(randomTeamCookie, CookieMenu_OnOff_Int, "Auto join random team");
  }
  if (CvarEnabled(enableRandomClassCvar) && !CvarEnabled(alwaysRandomClassCvar)) {
    SetCookiePrefabMenu(randomClassCookie, CookieMenu_OnOff_Int, "Auto join random class");
  }
  if (CvarEnabled(enableRememberClassCvar) && !CvarEnabled(alwaysRememberClassCvar)) {
    SetCookiePrefabMenu(rememberClassCookie, CookieMenu_OnOff_Int, "Auto join latest class");
  }

  // Cookie for storing the player's most recently played class.
  latestClassCookie = RegClientCookie("latest_class", "No MOTD", CookieAccess_Private);

  for (int i = 1; i <= MaxClients; i++) {
    clientMOTDBlocked[i] = IsClientInGame(i);
  }

  HookEvent("player_changeclass", Event_ChangeClass);
  HookUserMessage(GetUserMessageId("Train"), UserMessageHook, true);
}

void JoinClassName(TFClassType id, char[] name) {
  if (id == TFClass_Scout) {strcopy(name, 12, "scout");}
  else if (id == TFClass_Sniper) {strcopy(name, 12, "sniper");}
  else if (id == TFClass_Soldier) {strcopy(name, 12, "soldier");}
  else if (id == TFClass_DemoMan) {strcopy(name, 12, "demoman");}
  else if (id == TFClass_Medic) {strcopy(name, 12, "medic");}
  else if (id == TFClass_Heavy) {strcopy(name, 16, "heavyweapons");}
  else if (id == TFClass_Pyro) {strcopy(name, 12, "pyro");}
  else if (id == TFClass_Spy) {strcopy(name, 12, "spy");}
  else if (id == TFClass_Engineer) {strcopy(name, 12, "engineer");}
  else {strcopy(name, 12, "random");}
}

public void Event_ChangeClass(Handle event, const char[] name, bool dontBroadcast)
{
  int client = GetClientOfUserId(GetEventInt(event, "userid"));
  char to[20];
  JoinClassName(view_as<TFClassType>(GetEventInt(event, "class")), to);
  SetClientCookie(client, latestClassCookie, to);
}

public void OnClientDisconnect(int client) {
  clientMOTDBlocked[client] = false;
}

public Action UserMessageHook(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init)
{
  if (playersNum == 1 && IsClientConnected(players[0]) && !clientMOTDBlocked[players[0]] && !IsFakeClient(players[0]))
  {
    clientMOTDBlocked[players[0]] = true;
    CreateTimer(0.0, KillMOTD, GetClientUserId(players[0]), TIMER_FLAG_NO_MAPCHANGE);
  }

  return Plugin_Continue;
}

public Action KillMOTD(Handle timer, int uid)
{
  int client = GetClientOfUserId(uid);
  if (!client) return Plugin_Handled;

  if ((CvarEnabled(enableNoMotdCvar) && CookieEnabled(client, noMotdCookie)) || CvarEnabled(alwaysNoMotdCvar)) {
    ShowVGUIPanel(client, "info", _, false);
  }

  if ((CvarEnabled(enableRandomTeamCvar) && CookieEnabled(client, randomTeamCookie)) || CvarEnabled(alwaysRandomTeamCvar)) {
    FakeClientCommand(client, "jointeam auto");
  } else {
    ShowVGUIPanel(client, "team", _, true);
  }

  if ((CvarEnabled(enableRandomClassCvar) && CookieEnabled(client, randomClassCookie)) || CvarEnabled(alwaysRandomClassCvar)) {
    FakeClientCommand(client, "joinclass random");
    ShowVGUIPanel(client, "class_blue", _, false);
    ShowVGUIPanel(client, "class_red", _, false);
    return Plugin_Handled;
  }

  if ((CvarEnabled(enableRememberClassCvar) && CookieEnabled(client, rememberClassCookie)) || CvarEnabled(alwaysRememberClassCvar)) {
    char class[64];
    GetClientCookie(client, latestClassCookie, class, sizeof(class));
    if (StrEqual(class, "")) {
      strcopy(class, 10, "random");
    }
    FakeClientCommand(client, "joinclass %s", class);
    ShowVGUIPanel(client, "class_blue", _, false);
    ShowVGUIPanel(client, "class_red", _, false);
    return Plugin_Handled;
  }

  return Plugin_Handled;
}
