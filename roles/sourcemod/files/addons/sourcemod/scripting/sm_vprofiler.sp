#define PLUGIN_VERSION "1.1"

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
	name = "[ANY] [Debugger] Valve Profiler",
	description = "Measures per-plugin performance and provides a log with various counters",
	author = "Alex Dragokas",
	version = PLUGIN_VERSION,
	url = "https://github.com/dragokas/"
};

/*
	Commands:
	
	 - sm_debug - Start / stop vprof debug tracing
	
	Logfile:
	
	 - addons/sourcemod/logs/profiler__<DATE>_<TIME>.log
	 
	For details of implementation see also:
	https://github.com/alliedmodders/sourcemod/issues/1162
*/

const float LOG_MAX_WAITTIME = 60.0;
const float LOG_CHECK_INTERVAL = 5.0;

char 	g_PathPrefix[PLATFORM_MAX_PATH],
		g_PathOrig[PLATFORM_MAX_PATH],
		g_PathProfilerLog[PLATFORM_MAX_PATH],
		g_PathCosole[] = "console.log";
ConVar 	g_CVarLogFile;
Handle 	g_hTimer;
bool 	g_bL4D2;
int 	g_ptrFile;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_bL4D2 = (GetEngineVersion() == Engine_Left4Dead2);
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("sm_prof_version", PLUGIN_VERSION, "Plugin Version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_CVarLogFile = FindConVar("con_logfile");
	
	RegAdminCmd("sm_debug", Cmd_Debug, ADMFLAG_ROOT, "Start / stop the valve profiler");
	
	BuildPath(Path_SM, g_PathPrefix, sizeof(g_PathPrefix), "logs/profiler_");
}

public void OnConfigsExecuted()
{
	g_CVarLogFile.GetString(g_PathOrig, sizeof(g_PathOrig));
}

public Action Cmd_Debug(int client, int args)
{
	static bool start;
	char sTime[32];
	
	if( !start )
	{
		delete g_hTimer;
		
		FormatTime(sTime, sizeof(sTime), "%F_%H-%M-%S", GetTime());
		FormatEx(g_PathProfilerLog, sizeof(g_PathProfilerLog), "%s_%s.log", g_PathPrefix, sTime);
		
		if( g_bL4D2 )
		{
			g_ptrFile = FileSize(g_PathCosole);
		}
		else {
			SetCvarSilent(g_CVarLogFile, g_PathProfilerLog);
		}
		
		ReplyToCommand(client, "\x04[START]\x05 Profiler is started...");
		ServerCommand("vprof_on");
		ServerExecute();
		RequestFrame(OnFrameDelay);
	}
	else
	{
		ServerCommand("sm prof stop vprof");
		ServerCommand("sm prof dump vprof");
		ServerCommand("vprof_off");
		ReplyToCommand(client, "\x04[STOP]\x05 Saving profiler log to: %s", g_PathProfilerLog);
		
		// Profiler needs some time for analysis
		
		if( g_bL4D2 )
		{
			// L4D2 has bugged con_logfile: https://github.com/ValveSoftware/Source-1-Games/issues/3601
			g_hTimer = CreateTimer(LOG_CHECK_INTERVAL, Timer_MirrorLog, 1);
		}
		else {
			g_hTimer = CreateTimer(LOG_MAX_WAITTIME, Timer_RestoreCvar);
		}
	}
	start = !start;
	return Plugin_Handled;
}

public void OnFrameDelay()
{
	ServerCommand("sm prof start vprof");
}

void SetCvarSilent(ConVar cvar, char[] value)
{
	int flags = cvar.Flags;
	cvar.Flags &= ~ FCVAR_NOTIFY;
	cvar.SetString(value);
	cvar.Flags = flags;
}

public Action Timer_RestoreCvar(Handle timer)
{
	SetCvarSilent(g_CVarLogFile, g_PathOrig);
	g_hTimer = null;
}

public Action Timer_MirrorLog(Handle timer, int init)
{
	static float sec;
	
	if( init ) sec = 0.0;
	sec += LOG_CHECK_INTERVAL;
	
	if( sec > LOG_MAX_WAITTIME )
	{
		g_hTimer = null;
		return;
	}
	if( FileSize(g_PathCosole) != g_ptrFile )
	{
		File hr = OpenFile(g_PathCosole, "rb");
		if( !hr )
		{
			LogError("Cannot open file: %s", g_PathCosole);
			g_hTimer = null;
			return;
		}
		if( g_ptrFile != -1 )
		{
			hr.Seek(g_ptrFile, SEEK_SET);
		}
		File hw = OpenFile(g_PathProfilerLog, "ab");	
		if( hw )
		{
			static int bytesRead, buff[1024];
			
			while( !hr.EndOfFile() )
			{
				bytesRead = hr.Read(buff, sizeof(buff), 1);
				hw.Write(buff, bytesRead, 1);
			}
			delete hw;
		}
		g_ptrFile = hr.Position;
		delete hr;
	}
	g_hTimer = CreateTimer(LOG_CHECK_INTERVAL, Timer_MirrorLog, 0);
}