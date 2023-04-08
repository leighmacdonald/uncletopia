#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

// clang-format off
#if defined _gbans_globals_included
#endinput
#endif
// clang-format on

#define _gbans_globals_included

#define PLUGIN_AUTHOR "Leigh MacDonald"
#define PLUGIN_VERSION "0.0.1"
#define PLUGIN_NAME "gbans"

#define MAX_SCORES 256

// clang-format off
enum struct PlayerInfo {
    bool authed;
    char ip[16];
    int banType;
    int permissionLevel;
    char message[256];
}
// clang-format on

// Globals must all start with g
PlayerInfo gPlayers[MAXPLAYERS + 1];

// Core gbans options
ConVar gPort = null;
ConVar gHost = null;
ConVar gServerName = null;
ConVar gServerKey = null;

// STV options
ConVar gTvEnabled = null;
ConVar gAutoRecord = null;
ConVar gMinPlayersStart = null;
ConVar gIgnoreBots = null;
ConVar gTimeStart = null;
ConVar gTimeStop = null;
ConVar gFinishMap = null;
ConVar gDemoPathActive = null;
ConVar gDemoPathComplete = null;

// Stopwatch options
ConVar gStopwatchEnabled = null;
ConVar gStopwatchNameRed = null;
ConVar gStopwatchNameBlu = null;
ConVar gStopwatchChangelvlTime = null;

// Game ruleset options
ConVar gRulesRoundTime = null;

ConVar gHideConnections = null;

char gAccessToken[512];

// Store temp clientId for networked callbacks
int gReplyToClientId = 0;

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
JSON_Object gScores = null;
