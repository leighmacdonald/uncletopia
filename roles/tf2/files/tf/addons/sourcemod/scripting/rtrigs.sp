#pragma semicolon 1
#include <sourcemod>
#define PL_VERSION "1.10"
new Handle:g_enabled = INVALID_HANDLE;
new Handle:g_start = INVALID_HANDLE;
new Handle:g_end = INVALID_HANDLE;
new Handle:g_sd = INVALID_HANDLE;
new Handle:g_wfp = INVALID_HANDLE;
new Handle:g_notify = INVALID_HANDLE;
new Handle:g_mapend = INVALID_HANDLE;
new g_rounds;
new bool:g_bIntermissionCalled;
new UserMsg:VGuiMenu;
public Plugin:myinfo =
{
	name = "Round Triggers",
	author = "MikeJS",
	description = "Execute server commands on round start/end.",
	version = PL_VERSION,
	url = "http://mikejs.byethost18.com/"
};
public OnPluginStart() {
	CreateConVar("sm_rtrigs_version", PL_VERSION, "FF Humiliation version.", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_enabled = CreateConVar("sm_rtrigs", "1", "Enable/disable Round Triggers.", FCVAR_PLUGIN|FCVAR_NOTIFY);
	g_start = CreateConVar("sm_rtrigs_start", "", "Commands to execute when a round starts.", FCVAR_PLUGIN);
	g_end = CreateConVar("sm_rtrigs_end", "", "Commands to execute when a round ends.", FCVAR_PLUGIN);
	g_sd = CreateConVar("sm_rtrigs_sd", "", "Commands to execute when sudden death starts.", FCVAR_PLUGIN);
	g_wfp = CreateConVar("sm_rtrigs_wfp", "", "Commands to execute when the waiting for players period begins.", FCVAR_PLUGIN);
	g_mapend = CreateConVar("sm_rtrigs_mapend", "", "Commands to execute on map end.", FCVAR_PLUGIN);
	g_notify = CreateConVar("sm_rtrigs_notify", "sv_tags", "Cvars to strip the FCVAR_NOTIFY tag from.", FCVAR_PLUGIN);
	RegServerCmd("sm_printca", Command_printca, "Print a message to chat.");
	RegServerCmd("sm_printct", Command_printct, "Print a center text message.");
	RegServerCmd("sm_rtrigs_cvar", Command_cvar, "Change a cvar's value.");
	HookEvent("teamplay_round_start", Event_teamplay_round_start);
	HookEvent("teamplay_round_win", Event_teamplay_round_win);
	HookEvent("teamplay_restart_round", Event_teamplay_round_start);
	HookEvent("teamplay_round_stalemate", Event_teamplay_suddendeath_b);
	HookConVarChange(g_notify, Cvar_notify);
	VGuiMenu = GetUserMessageId("VGUIMenu");
	HookUserMessage(VGuiMenu, VGuiMenuHook);
}
public OnMapStart() {
	g_rounds = 0;
}
public OnMapEnd() {
	if(!g_bIntermissionCalled)
		DoMapEnd();
	g_bIntermissionCalled = false;
}
public OnConfigsExecuted() {
	CvarsNotify();
}
public Cvar_notify(Handle:convar, const String:oldValue[], const String:newValue[]) {
	CvarsNotify();
}
public Action:Command_printca(args) {
	decl String:cmdstr[192];
	GetCmdArgString(cmdstr, sizeof(cmdstr));
	PrintToChatAll("%s", cmdstr);
	return Plugin_Handled;
}
public Action:Command_printct(args) {
	decl String:cmdstr[192];
	GetCmdArgString(cmdstr, sizeof(cmdstr));
	PrintCenterTextAll("%s", cmdstr);
	return Plugin_Handled;
}
public Action:Command_cvar(args) {
	decl String:arg1[64], String:arg2[64];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	SetConVarString(FindConVar(arg1), arg2, true);
	return Plugin_Handled;
}
public Action:Event_teamplay_round_start(Handle:event, const String:name[], bool:dontBroadcast) {
	if(GetConVarBool(g_enabled)) {
		decl String:cmds[1024], String:excmds[16][64];
		if(g_rounds==0) {
			GetConVarString(g_wfp, cmds, sizeof(cmds));
		} else {
			GetConVarString(g_start, cmds, sizeof(cmds));
		}
		if(strcmp(cmds, "", false)!=0) {
			new count = ExplodeString(cmds, ",", excmds, 16, 64);
			for(new i=0;i<count;i++) {
				TrimString(excmds[i]);
				ServerCommand(excmds[i]);
			}
		}
	}
	g_rounds++;
}
public Action:Event_teamplay_round_win(Handle:event, const String:name[], bool:dontBroadcast) {
	if(GetConVarBool(g_enabled)) {
		decl String:cmds[1024], String:excmds[16][64];
		GetConVarString(g_end, cmds, sizeof(cmds));
		if(strcmp(cmds, "", false)!=0) {
			new count = ExplodeString(cmds, ",", excmds, 16, 64);
			for(new i=0;i<count;i++) {
				TrimString(excmds[i]);
				ServerCommand(excmds[i]);
			}
		}
	}
}
public Action:Event_teamplay_suddendeath_b(Handle:event, const String:name[], bool:dontBroadcast) {
	if(GetConVarBool(g_enabled)) {
		decl String:cmds[1024], String:excmds[16][64];
		GetConVarString(g_sd, cmds, sizeof(cmds));
		if(strcmp(cmds, "", false)!=0) {
			new count = ExplodeString(cmds, ",", excmds, 16, 64);
			for(new i=0;i<count;i++) {
				TrimString(excmds[i]);
				ServerCommand(excmds[i]);
			}
		}
	}
}
public Action:VGuiMenuHook(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init) {
	if(g_bIntermissionCalled)
		return;
	new String:Type[10];
	BfReadString(bf, Type, sizeof(Type));
	if(strcmp(Type, "scores", false)==0) {
		if(BfReadByte(bf)==1 && BfReadByte(bf)==0) {
			DoMapEnd();
		}
	}
}
DoMapEnd() {
	g_bIntermissionCalled = true;
	if(GetConVarBool(g_enabled)) {
		decl String:cmds[1024], String:excmds[16][64];
		GetConVarString(g_mapend, cmds, sizeof(cmds));
		if(strcmp(cmds, "", false)!=0) {
			new count = ExplodeString(cmds, ",", excmds, 16, 64);
			for(new i=0;i<count;i++) {
				TrimString(excmds[i]);
				ServerCommand(excmds[i]);
			}
		}
	}
}
CvarsNotify() {
	decl String:cvars[1024], String:ncvars[16][64];
	GetConVarString(g_notify, cvars, sizeof(cvars));
	if(strcmp(cvars, "", false)!=0) {
		new cvarc = ExplodeString(cvars, ",", ncvars, 16, 64);
		for(new i=0;i<cvarc;i++) {
			TrimString(ncvars[i]);
			new Handle:cvar = FindConVar(ncvars[i]);
			new flags = GetConVarFlags(cvar);
			flags &= ~FCVAR_NOTIFY;
			SetConVarFlags(cvar, flags);
		}
	}
}