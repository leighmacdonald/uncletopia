#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#define PLUGIN_VERSION "0.5.15-next2"

#define MAX_SCORES 256

// Core gbans options
ConVar gb_core_host;
ConVar gb_core_port;
ConVar gb_core_server_name;
ConVar gb_core_server_key;

// In Game Tweaks
ConVar gb_disable_autoteam;
ConVar gb_hide_connections;

// STV options
ConVar gb_stv_enable;
ConVar gb_auto_record;
ConVar gb_stv_minplayers;
ConVar gb_stv_ignorebots;
ConVar gb_stv_timestart;
ConVar gb_stv_timestop;
ConVar gb_stv_finishmap;
ConVar gb_stv_path;
ConVar gb_stv_path_complete;

// clang-format off
enum struct PlayerInfo
{
	bool authed;
	char ip[16] ;
	int banType;
	int permissionLevel;
	char message[256];
}
// clang-format on

// Globals must all start with g
PlayerInfo gPlayers[MAXPLAYERS + 1];

char gAccessToken[512];

// Reports command
int gReportSourceId = -1;
int gReportTargetId = -1;
bool gReportWaitingForReason = false;
GB_BanReason gReportTargetReason;
int gReportStartedAtTime = -1;

// Stv
bool gStvMapChanged = false;
bool gIsRecording = false;
bool gIsManual = false;
