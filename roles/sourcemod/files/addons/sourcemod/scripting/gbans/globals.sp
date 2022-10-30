
#define PLUGIN_AUTHOR "Leigh MacDonald"
#define PLUGIN_VERSION "0.00"
#define PLUGIN_NAME "gbans"

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

int g_port;
char g_host[128];

char g_server_name[128];
char g_server_key[41];
char g_access_token[512];

// Store temp clientId for networked callbacks 
int g_reply_to_client_id = 0;

