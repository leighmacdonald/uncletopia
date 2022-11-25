#if defined _gbans_globals_included
 #endinput
#endif
#define _gbans_globals_included

#define PLUGIN_AUTHOR "Leigh MacDonald"
#define PLUGIN_VERSION "0.00"
#define PLUGIN_NAME "gbans"

#define MAX_SCORES 256

// clang-format off
enum struct PlayerInfo {
    bool authed;
    char ip[16];
    int ban_type;
    int permission_level;
    char message[256];
}
// clang-format on


// Globals must all start with g_
PlayerInfo g_players[MAXPLAYERS + 1];

// Core gbans options
ConVar g_port  = null;
ConVar g_host  = null;
ConVar g_server_name = null;
ConVar g_server_key = null;

// STV options
ConVar g_hTvEnabled = null;
ConVar g_hAutoRecord = null;
ConVar g_hMinPlayersStart = null;
ConVar g_hIgnoreBots = null;
ConVar g_hTimeStart = null;
ConVar g_hTimeStop = null;
ConVar g_hFinishMap = null;
ConVar g_hDemoPath = null;
ConVar g_hDemoPathComplete = null;

char g_access_token[512];

// Store temp clientId for networked callbacks 
int g_reply_to_client_id = 0;

