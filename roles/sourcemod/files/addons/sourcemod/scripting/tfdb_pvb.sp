#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>
#include <multicolors>
#include <tfdb_clientcheck>

// TFDB support - use TFDB natives to get rocket ownership
// Falls back to non-TFDB mode if TFDB not loaded
#undef REQUIRE_PLUGIN
#tryinclude <tfdb>
#tryinclude <tfdb_guardian>
#tryinclude <tfdb_deathmatch>
#tryinclude <tfdb_ffa>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION "2.2.0"

// Runtime detection of TFDB plugin (compile-time #if is not enough)
bool TFDBAvailable = false;

// --- Trick Actions (applied AFTER airblast) ---
enum TrickType {
    TRICK_NONE = 0,
    TRICK_LEFT_FLICK,
    TRICK_RIGHT_FLICK,
    TRICK_DOWN_SPIKE,
    TRICK_UP_SPIKE,
    TRICK_WAVE,
    TRICK_SPIN           // AJAX-style: spin with the rocket before deflecting
}

#define NUM_TRICKS 7

// --- Bot Types (fully dynamic - loaded from config) ---
// Every class (built-in or user-defined) is discovered by iterating the
// "classes" section of pvb.cfg at load time. No hardcoded identities.
// Class index 0 is always the "default" fallback if the config has no classes.
#define MAX_BOT_TYPES 32     // Maximum supported classes
int NumBotTypes = 0;      // Populated by LoadPvBConfig from .cfg

// Legacy indices retained ONLY for movement-mode default weighting; they
// match the built-in class order in the stock config and are safe fallbacks.
#define BOT_TYPE_UNIVERSAL   0
#define BOT_TYPE_STATUE      1
#define BOT_TYPE_MIDRANGE    2
#define BOT_TYPE_AGGRESSIVE  3

// Per-class identity (loaded from .cfg)
char BotClassKey[MAX_BOT_TYPES][32];       // Lowercase key as written in cfg (e.g. "statue")
char BotDisplayName[MAX_BOT_TYPES][64];    // Human-readable (e.g. "Statue (Rally/Deflect)")
bool ClassIsStatueLike[MAX_BOT_TYPES];     // Per-class: force-idle behavior (was the STATUE-only hardcode)

// --- Evasion Actions ---
enum EvadeAction {
    EVADE_NONE = 0,
    EVADE_JUMP,
    EVADE_CROUCH
}

#define NUM_EVADE 3

// --- Orbit Phases (for multi-rotation WASD orbit) ---
enum OrbitPhase {
    ORBIT_PHASE_NONE = 0,
    ORBIT_PHASE_RIGHT,    // Strafe right (D)
    ORBIT_PHASE_BACK,     // Move back (S)
    ORBIT_PHASE_LEFT,     // Strafe left (A)
    ORBIT_PHASE_FORWARD   // Move forward (W)
}

#define NUM_ORBIT_PHASES 4

// --- Movement Modes ---
enum MoveMode {
    MOVE_WANDER = 0,
    MOVE_APPROACH,
    MOVE_MIRROR,
    MOVE_CIRCLE,
    MOVE_IDLE
}

// --- Look States (after deflection) ---
enum LookState {
    LOOK_ROCKET = 0,     // Looking at incoming rocket
    LOOK_PLAYER,         // Looking at last deflected player
    LOOK_IDLE            // Random idle look
}

// --- Global server-wide config (loaded from pvb.cfg "settings") ---
bool CfgEnabled = true;          // Master enable
int CfgBotType = 0;              // Active class index in normal mode
int CfgMinPlayers = 1;           // Auto-enable when players <= this
int CfgMaxPlayers = 2;           // Auto-disable when players > this (e.g. max_players 2 = bot allowed up to 2 humans, kicked at 3+)
bool CfgSpeech = true;           // Master taunt toggle

// --- Per-class config arrays (loaded from pvb.cfg "classes") ---
// Every bot in training mode indexes these by its own type, so classes
// don't stomp each other's tunings.
float CfgReactMin[MAX_BOT_TYPES];
float CfgReactMax[MAX_BOT_TYPES];
float CfgMaxOrbitTime[MAX_BOT_TYPES];
int   CfgMaxOrbitLoops[MAX_BOT_TYPES];
float CfgAngleRandomChance[MAX_BOT_TYPES];
float CfgAngleRandomStrength[MAX_BOT_TYPES];
float CfgEvadeChance[MAX_BOT_TYPES];
float CfgCqcFloorDist[MAX_BOT_TYPES];   // Hard floor - no class can EVER go closer
float CfgCqcMinDist[MAX_BOT_TYPES];
float CfgCqcMaxDist[MAX_BOT_TYPES];
float CfgCqcRetreatDist[MAX_BOT_TYPES];
float CfgIdleChance[MAX_BOT_TYPES];
float CfgIdleDuration[MAX_BOT_TYPES];
float CfgLookAtPlayerTime[MAX_BOT_TYPES];

// --- Capability-by-presence flags -------------------------------------------
// Each CfgCan* flag is TRUE iff the corresponding config key(s) were present in
// the class section of pvb.cfg. Remove the keys from the class block and the
// bot becomes physically incapable of that action — not just "chance 0", but
// gated out of the code path entirely. Defaults to TRUE so classes with
// complete configs behave exactly as before.
//
//   CfgCanOrbit[t]   — orbit_time / orbit_max_loops / orbit_chance present
//   CfgCanEvade[t]   — evade_chance present
//   CfgCanCqc[t]     — any cqc_*_dist key present
//   CfgCanIdle[t]    — idle_chance present (gates both look-idle and move-idle)
//   CfgIdleAlways[t] — idle_chance >= 100 (permanent idle, no duration roll)
bool CfgCanOrbit[MAX_BOT_TYPES];
bool CfgCanEvade[MAX_BOT_TYPES];
bool CfgCanCqc[MAX_BOT_TYPES];
bool CfgCanIdle[MAX_BOT_TYPES];
bool CfgIdleAlways[MAX_BOT_TYPES];

// --- Speech file paths per bot type ---
char SpeechPlayerDeath[MAX_BOT_TYPES][PLATFORM_MAX_PATH];
char SpeechBotDeath[MAX_BOT_TYPES][PLATFORM_MAX_PATH];

// --- Runtime State ---
bool BotEnabled = false;         // Is the bot system currently active?
bool CommandForced = false;   // Was it force-enabled by admin?
bool CommandDisabled = false; // Was it force-disabled by admin?
bool MapChanged = false;

// Cached player counts (updated on connect/disconnect/team change, not every frame)
int CachedRealCount = 0;
int CachedFakeCount = 0;
bool BotNameDirty = false;    // Only set bot name when changed

// Bot Stats
int BotWins = 0;              // Rounds bot's team won
int BotLosses = 0;            // Rounds bot's team lost
int TotalDeflects = 0;        // Total deflects achieved
int TotalKills = 0;           // Kills by bot
int TotalDeaths = 0;          // Times bot died
int RoundDeflects = 0;        // Deflects THIS round (for stat display)
// (Disable-vote globals removed 2026-04-24 — unified into class vote menu.)
int VoteMaxPlayers = 12;      // Max players allowed to vote (loaded from config)

// Class vote system - players vote for which bot type to play against.
// Array is sized MAX_BOT_TYPES+1: slots 0..NumBotTypes-1 = bot types,
// slot NumBotTypes = "Disable bot" votes.
int ClassVotes[MAX_BOT_TYPES + 1];
int ClassVoted[MAXPLAYERS + 1]; // Which slot this player voted for (-1 = not voted; NumBotTypes = disable)
bool ClassVoteActive = false; // Is a class vote in progress
bool PendingMaxPlayerDisable = false; // OnGameFrame queued a "too many players" disable; drained at round end so bot finishes the current rally
int  PendingHotSwapType = -1;          // Vote winner queued for next-round hot-swap; -1 = no swap pending
bool SoloMenuShown = false;   // Was the solo player menu shown
Handle ClassVoteTimer = null;

// Training mode
bool TrainingMode = false;    // Are we in training mode (bots on both teams)?
int TrainingBotCount = 0;     // Number of training bots spawned

// --- League-style self-play diversity ---------------------------------------
// Tracks per-type win rate so we can detect when one bot class dominates the
// meta. When a type crosses a threshold, we convert one of its bots to an
// under-represented type ("exploiter") at the next round boundary. This
// forces the dominant type to face fresh counter-play instead of stagnating
// against a monoculture it has already solved.
#define DIVERSITY_MIN_MATCHES 8      // rounds required before dominance calls fire
#define DIVERSITY_WIN_THRESHOLD 0.65 // win rate that triggers exploiter spawn
int TypeWins[MAX_BOT_TYPES];         // session-total wins attributed to this type
int TypeMatches[MAX_BOT_TYPES];      // session-total rounds this type participated in
int ExploiterTargetType = -1;        // -1 = none; else type index to counter next round

// Per-client
bool Allowed[MAXPLAYERS + 1];  // autoreflect permission

// Movement
float MoveYaw[MAXPLAYERS + 1];
float NextDirChange[MAXPLAYERS + 1];
float NextWallCheck[MAXPLAYERS + 1];
MoveMode CurrentMoveMode[MAXPLAYERS + 1];    // 0=wander, 1=approach enemy, 2=mirror enemy, 3=circle enemy
float MoveModeEnd[MAXPLAYERS + 1];    // When to pick a new mode
int TargetEnemy[MAXPLAYERS + 1];      // Which enemy we're focused on

// Movement and look enums are defined at top of file

// Airblast state machine (per bot)
bool HasRocket[MAXPLAYERS + 1];
bool TimingDecided[MAXPLAYERS + 1];
bool Orbiting[MAXPLAYERS + 1];
bool ApplyingTrick[MAXPLAYERS + 1];
bool MissedAirblast[MAXPLAYERS + 1];    // True if we airblasted but missed the rocket
float ReactDistance[MAXPLAYERS + 1];   // Distance at which to fire IN_ATTACK2
float OrbitEnd[MAXPLAYERS + 1];
float OrbitDir[MAXPLAYERS + 1];
float TrickEnd[MAXPLAYERS + 1];
TrickType Trick[MAXPLAYERS + 1];
int Deflects = 0;    // Global deflect counter for current rocket
int CachedRocketRef = INVALID_ENT_REFERENCE; // Last-spawned rocket (for stats tracking)
int ClientRocketRef[MAXPLAYERS + 1];          // Per-client best rocket entity ref
float NextRocketScan[MAXPLAYERS + 1];         // Throttle per-client rocket scans

// Reward shaping timer: periodic small positive/negative signals between
// sparse deflect/death events. Throttled to ~3-5s per bot to avoid drowning
// the policy in shaping reward; real rewards still dominate.
float NextShapingReward[MAXPLAYERS + 1];

// Batched brain SQL writes.
// AdjustBrain used to issue INSERT OR REPLACE synchronously on every reward.
// At ~240 writes/round in heavy play, that's wasteful I/O. Now we buffer
// pending writes into a StringMap keyed by "state_key|trick_id" (the SQL
// primary key). Repeated updates to the same cell collapse into one write.
// Flushed on round end and map end via FlushBrainWrites().
StringMap BrainWriteQueue = null;

// When true, QueueBrainWrite silently drops incoming writes and FlushBrainWrites
// bails at its top. Set during admin brain-reset DELETE so late writes from
// in-flight timers don't recreate rows that were meant to be wiped. Cleared by
// the reset-success callback. See ai-bots/pvb-brain-reset-protocol.md.
bool BrainDraining = false;

// Multi-loop WASD orbit state
int OrbitPhaseIdx[MAXPLAYERS + 1];        // Current WASD phase (1-4)
float OrbitPhaseEnd[MAXPLAYERS + 1];   // When current phase expires
int OrbitLoopCount[MAXPLAYERS + 1];    // How many full loops completed
float OrbitPhaseTime[MAXPLAYERS + 1];  // Duration per phase (adapts to speed)

// Evasion state (jump/crouch over low rockets)
bool Evading[MAXPLAYERS + 1];          // Currently in evasion action
EvadeAction CurrentEvadeAction[MAXPLAYERS + 1]; // EVADE_JUMP or EVADE_CROUCH
float EvadeEnd[MAXPLAYERS + 1];        // When evasion action ends
float NextEvadeCheck[MAXPLAYERS + 1];  // Throttle evasion checks

// Rate-limit per-tick CountIncomingThreats scan (full rocket loop is expensive
// at 66 Hz x N bots). 0.1s cadence is plenty — multi-threat state doesn't
// change faster than that in practice.
float NextThreatScan[MAXPLAYERS + 1];
int   CachedThreatCount[MAXPLAYERS + 1];

// Post-deflect look behavior
LookState CurrentLookState[MAXPLAYERS + 1];   // LOOK_ROCKET, LOOK_PLAYER, LOOK_IDLE
int LastDeflectedPlayer[MAXPLAYERS + 1]; // Who we last deflected
float LookAtPlayerEnd[MAXPLAYERS + 1]; // When to stop looking at player
float LookAtIdleEnd[MAXPLAYERS + 1];   // When to switch from idle look
float NextLookChange[MAXPLAYERS + 1];   // When to change look direction
float LastRocketYaw[MAXPLAYERS + 1];    // Last known rocket travel yaw (bounce detection)
float AimDampen[MAXPLAYERS + 1];        // Temporary aim dampening after rocket bounce (0-1)

// Learning
Database BrainDB = null;
StringMap BrainMemory = null;
int LastTrick[MAXPLAYERS + 1];
char LastState[MAXPLAYERS + 1][32];

// Taunts - per bot type
ArrayList TauntsPlayerDeath[MAX_BOT_TYPES];
ArrayList TauntsBotDeath[MAX_BOT_TYPES];

// Bot name cache
char BotName[MAX_NAME_LENGTH];                    // Active bot name (set from current type)
char BotNames[MAX_BOT_TYPES][MAX_NAME_LENGTH];    // Per-type names from config

// Per-bot type override for training mode (each bot uses its own type)
int TrainingBotType[MAXPLAYERS + 1];

// ============================================================================
// PERSISTENT DEBUG SYSTEM
// Captures per-bot decision data every N ticks to a CSV log file.
// Runs continuously until manually stopped — survives map changes.
// Use: sm_botdebug to start, sm_botdebug again (or sm_stopdebug) to stop.
// ============================================================================
bool DebugActive = false;
int  BotDebugTick[MAXPLAYERS + 1];  // Per-bot tick counter (was global, caused 4x logging with 4 bots)
int  DebugSampleRate = 10;          // Log every N ticks (10 = ~6.6 samples/sec at 66 tick)
int  DebugLinesWritten = 0;
int  DebugTotalLines = 0;            // Cumulative across rotations — drives hard-cap shutoff (DebugLinesWritten resets on rotate)
#define DEBUG_MAX_LINES 50000        // Rotate log file after this many lines (~400/bot/minute at rate=10, 66 tick)
#define DEBUG_MAX_TOTAL_LINES 500000 // Hard cap: auto-stop logging if user forgets sm_stopdebug (prevents unbounded rotated-file growth)
char DebugLogPath[PLATFORM_MAX_PATH];
File DebugFile = null;               // File handle for high-frequency writes (avoids console spam)

// Player data collection — logs human player state when debug is active.
// Same sample rate as bots so data is directly comparable.
// Use this data to study real player behavior and improve bot movesets.
int  PlayerDebugTick[MAXPLAYERS + 1];   // Per-player tick counter for sampling
float PlayerLastYaw[MAXPLAYERS + 1];    // Last aim yaw (track aim smoothness)
float PlayerLastVelX[MAXPLAYERS + 1];   // Last velocity X (track movement changes)
float PlayerLastVelY[MAXPLAYERS + 1];   // Last velocity Y

// ============================================================================
// ADAPTIVE LEARNING v2 - reaction drift, opponent persistence, map heatmaps
// ============================================================================

// Feature toggles from pvb.cfg "settings"
bool  CfgLearnReactionTime = true;    // Allow per-class react_min/max drift
bool  CfgRememberOpponents = true;    // Persist OpponentProfile keyed by SteamID
bool  CfgUseHeatmap        = true;    // Track player death/deflect cells per map
int   CfgMaxTrainingBots   = 16;      // Safety cap on training-mode bot spawn

// --- Reaction drift (per class) ---------------------------------------------
// Persistent offsets applied on top of cfg react_min / react_max. Bounded so
// runaway learning can never break the bot. Negative = faster, positive = slower.
float ReactMinDelta[MAX_BOT_TYPES];
float ReactMaxDelta[MAX_BOT_TYPES];
#define REACT_DELTA_MIN -0.09    // Can learn up to 90 ms faster
#define REACT_DELTA_MAX  0.10    // Or 100 ms slower if aggression fails
#define REACT_LEARN_RATE 0.003   // Drift per success/failure event

// --- Opponent persistence ---------------------------------------------------
// Loaded from bot_opponent_v1 on auth, written back on disconnect.
// steam_id is the 32-bit account id from GetSteamAccountID.
bool OpProfileLoaded[MAXPLAYERS + 1];
int  OpSteamId[MAXPLAYERS + 1];

// --- Map heatmaps -----------------------------------------------------------
// In-memory cell cache keyed by "mapName|botType|gx|gy" -> {deflects, deaths}.
// Flushed to bot_heatmap_v1 on round end / map end.
#define HEATMAP_CELL_SIZE    128.0
#define HEATMAP_PRIOR        5.0   // Bayesian prior so unseen cells aren't 0% danger
#define HEATMAP_DECAY_FACTOR 0.85  // Per-map-load multiplier. After ~10 maps of no
                                   // activity, a cell's signal falls below ~20% of
                                   // its peak. Prevents "dead middle" feedback loop
                                   // where old death data freezes bots out of zones
                                   // that would now be contested if fresh data existed.
StringMap HeatmapCells = null;  // Key -> int[2] = {deflects, deaths}
char      CurrentMap[64];
bool      HeatmapDirty = false;

// --- Default weights per decision type ---
// (must be global so all functions can reference them)
int DefTrick[NUM_TRICKS] = {80, 30, 30, 25, 25, 15, 20};
int DefOrbit[2] = {70, 30};
int DefMove[5] = {40, 25, 20, 20, 15};
int DefReact[3] = {30, 50, 20};
int DefAim[5] = {40, 15, 15, 25, 10};
int DefEvade[NUM_EVADE] = {60, 25, 15};  // none, jump, crouch

// --- Per-client last-decision tracking for reinforcement ---
char LastTrickKey[MAXPLAYERS + 1][48];
char LastOrbitKey[MAXPLAYERS + 1][48];
char LastMoveKey[MAXPLAYERS + 1][48];
char LastReactKey[MAXPLAYERS + 1][48];
char LastAimKey[MAXPLAYERS + 1][48];
char LastEvadeKey[MAXPLAYERS + 1][48];
int LastOrbitChoice[MAXPLAYERS + 1];
int LastMoveChoice[MAXPLAYERS + 1];
int LastReactChoice[MAXPLAYERS + 1];
int LastAimChoice[MAXPLAYERS + 1];
int LastEvadeChoice[MAXPLAYERS + 1];

// ============================================================================
// OPPONENT PROFILING - Per-player tendency tracking
// Bot remembers how each player behaves and adapts.
// Stored in-memory (resets on map change) - lightweight but effective.
// ============================================================================

// Per-opponent profile (indexed by client slot, lives for session)
enum struct OpponentProfile {
    int strafeLeftCount;     // Times this player strafed left when deflecting
    int strafeRightCount;    // Times this player strafed right
    int stoodStillCount;     // Times they stood still (statue style)
    int orbitedCount;        // Times they orbited
    int jumpedCount;         // Times they jumped near rocket
    int crouchedCount;       // Times they crouched near rocket
    int flickUpCount;        // Times they upspiked
    int flickDownCount;      // Times they downspiked
    int flickLeftCount;      // Times they flicked left
    int flickRightCount;     // Times they flicked right
    int cqcApproachCount;    // Times they pushed CQC close
    int cqcRetreatCount;     // Times they backed off
    int totalDeflects;       // Total deflects we've tracked
    int totalKills;          // Times they killed a bot
    int totalDeaths;         // Times they died to a bot
    float avgDeflectSpeed;   // Running average speed when they deflect
    float lastSeenPos[3];    // Last position we saw them at
    float lastSeenVel[3];    // Last velocity we saw
    float lastSeenTime;      // When we last profiled them
}

OpponentProfile OpProfile[MAXPLAYERS + 1];

// Continuous movement blend weights (used instead of discrete modes)
float MoveBlendIdle[MAXPLAYERS + 1];     // Desire to stand still (0-1)
float MoveBlendToward[MAXPLAYERS + 1];   // Desire to move toward enemy (0-1)
float MoveBlendCircle[MAXPLAYERS + 1];   // Desire to circle/strafe (0-1)
float MoveBlendAway[MAXPLAYERS + 1];     // Desire to back off (0-1)
float MoveBlendUpdate[MAXPLAYERS + 1];   // When to next recalculate blend

// TFDB-based deflect tracking (more accurate than m_iDeflected)
int ConfirmedDeflects[MAXPLAYERS + 1];   // Per-bot confirmed deflects via TFDB forward
int RoundDeflectsBot[MAXPLAYERS + 1];    // Per-bot deflects THIS round (reset on round start)
float LastDeflectSpeed = 0.0;            // Speed of last deflected rocket

// Get the effective bot type for a given client (training vs normal)
int GetEffectiveBotType(int client) {
    if (TrainingMode && IsFakeClient(client)) {
        return TrainingBotType[client];
    }
    return CfgBotType;
}

public Plugin myinfo = {
    name        = "[TFDB] Player vs Bot",
    author      = "Silorak",
    description = "Self-learning TFDB bot. Training mode, proper orbiting, evasion, personality speech.",
    version     = PLUGIN_VERSION,
    url         = ""
};

// Fix: Mark TFDB natives as optional so plugin loads even without TFDB
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    // Expose PvB state to other subplugins (Guardian, FFA, etc.) so they can
    // refuse to activate during PvB mode.
    CreateNative("TFDB_IsPvBActive",   Native_IsPvBActive);
    CreateNative("TFDB_IsPvBTraining", Native_IsPvBTraining);
    RegPluginLibrary("tfdb_pvb");

    // Reverse direction: we mark Guardian's natives optional so we can
    // query guardian state before activating PvB (without hard-requiring
    // the Guardian plugin to be loaded).
    MarkNativeAsOptional("TFDB_IsGuardianActive");

    #if defined _tfdb_included
    MarkNativeAsOptional("TFDB_IsDodgeballEnabled");
    MarkNativeAsOptional("TFDB_FindRocketByEntity");
    MarkNativeAsOptional("TFDB_GetRocketOwner");
    MarkNativeAsOptional("TFDB_GetRocketTarget");
    MarkNativeAsOptional("TFDB_IsValidRocket");
    MarkNativeAsOptional("TFDB_GetRocketSpeed");
    MarkNativeAsOptional("TFDB_GetRocketMphSpeed");
    MarkNativeAsOptional("TFDB_GetRocketDeflections");
    MarkNativeAsOptional("TFDB_GetRocketClass");
    MarkNativeAsOptional("TFDB_GetRocketClassTurnRate");
    MarkNativeAsOptional("TFDB_GetRocketClassTurnRateIncrement");
    MarkNativeAsOptional("TFDB_GetRocketClassSpeed");
    MarkNativeAsOptional("TFDB_GetRocketClassSpeedIncrement");
    MarkNativeAsOptional("TFDB_GetRocketClassOrbitTightness");
    MarkNativeAsOptional("TFDB_GetRocketLastDeflectionTime");
    MarkNativeAsOptional("TFDB_GetRocketEntity");
    #endif
    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, "tfdb")) {
        TFDBAvailable = true;
    }
}

public void OnLibraryRemoved(const char[] name) {
    if (StrEqual(name, "tfdb")) {
        TFDBAvailable = false;
    }
}

// ============================================================================
// INITIALIZATION
// ============================================================================

public void OnPluginStart() {
    LoadTranslations("tfdb.phrases.txt");

    // Per-plugin log folder. Heatmap dumps + debug traces go here so they
    // don't pollute the shared addons/sourcemod/logs/ root. Mirrors the
    // pattern AntiCheat uses (logs/tfdb_ac/) and Guardian (logs/tfdb_guardian/).
    char pvbLogDir[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, pvbLogDir, sizeof(pvbLogDir), "logs/tfdb_pvb");
    if (!DirExists(pvbLogDir))
    {
        CreateDirectory(pvbLogDir, 511);  // 0777
    }

    BrainMemory = new StringMap();
    HeatmapCells = new StringMap();
    BrainWriteQueue = new StringMap();

    // Lock down TF2's bot quota so the server never auto-spawns replacement bots
    // after our PvB bot is kicked. This is the fix for the "map change spawns a
    // generic vanilla bot that just stands there" bug.
    //   tf_bot_quota_mode normal  = never add/remove bots without explicit command
    //   tf_bot_quota 0            = belt & suspenders (has no effect in 'normal' mode)
    //   tf_bot_auto_vacate 0      = don't boot our bot when humans join
    LockBotQuota();

    // Pre-allocate all possible taunt slots up front. LoadPvBConfig
    // decides how many slots are actually populated based on the .cfg.
    for (int t = 0; t < MAX_BOT_TYPES; t++) {
        TauntsPlayerDeath[t] = new ArrayList(256);
        TauntsBotDeath[t] = new ArrayList(256);
    }

    // Only version ConVar - everything else is config-driven (matches TFDB ecosystem)
    CreateConVar("sm_pvb_version", PLUGIN_VERSION, "PvB Version", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);

    // Load config (all settings come from pvb.cfg)
    LoadPvBConfig();

    // Hooks. Use HookEventEx (returns false instead of throwing) so if any of
    // these event names ever get renamed / removed in a TF2 update, the plugin
    // logs a warning and keeps loading instead of hard-erroring on startup.
    if (!HookEventEx("teamplay_round_start", Event_RoundStart, EventHookMode_PostNoCopy))
        LogError("[PvB] Failed to hook teamplay_round_start");
    if (!HookEventEx("teamplay_round_win", Event_RoundEnd, EventHookMode_Post))
        LogError("[PvB] Failed to hook teamplay_round_win");
    if (!HookEventEx("player_death", Event_PlayerDeath))
        LogError("[PvB] Failed to hook player_death");
    if (!HookEventEx("player_spawn", Event_PlayerSpawn))
        LogError("[PvB] Failed to hook player_spawn");
    if (!HookEventEx("player_connect", Event_PlayerConnect))
        LogError("[PvB] Failed to hook player_connect");

    // Pre-emptive team-join protection. Without this, humans can spawn on
    // the bot's team for 1-2 ticks before ManageTeams reactively yanks
    // them — which destroys spawn state via forced TF2_RespawnPlayer.
    if (!HookEventEx("player_team", Event_PlayerTeamChange, EventHookMode_Pre))
        LogError("[PvB] Failed to hook player_team");
    AddCommandListener(Listener_BlockPvBTeamCollision, "jointeam");
    AddCommandListener(Listener_BlockPvBTeamCollision, "autoteam");

    // === ROOT Commands ===
    RegAdminCmd("sm_pvb", Cmd_Toggle, ADMFLAG_KICK, "Force enable/disable the PvB bot.");
    RegAdminCmd("sm_spawnpvb", Cmd_Toggle, ADMFLAG_KICK, "Alias for sm_pvb.");
    RegAdminCmd("sm_trainbots", Cmd_TrainBots, ADMFLAG_ROOT, "[ROOT] Spawn all classes on both teams for training.");
    RegAdminCmd("sm_stoptraining", Cmd_StopTraining, ADMFLAG_ROOT, "[ROOT] Stop training mode and kick all bots.");
    
    // === ADMIN Commands ===
    RegAdminCmd("sm_botadmin", Cmd_BotAdmin, ADMFLAG_KICK, "[ADMIN] Open bot administration menu.");
    RegAdminCmd("sm_setbottype", Cmd_SetBotType, ADMFLAG_KICK, "[ADMIN] Set bot type by class index (see pvb.cfg for available classes).");
    RegAdminCmd("sm_reloadbotcfg", Cmd_ReloadConfig, ADMFLAG_CONFIG, "[ADMIN] Reload pvb.cfg");
    RegAdminCmd("sm_resetbrain", Cmd_ResetBrain, ADMFLAG_ROOT, "[ROOT] Reset bot brain (all learning data).");
    RegAdminCmd("sm_botdebug", Cmd_BotDebug, ADMFLAG_ROOT, "[ROOT] Toggle persistent bot debug logging to CSV.");

    // Brain inspection commands — let admins see what the bot has actually
    // learned. All ROOT because they expose raw policy weights and SteamID
    // profiles. See subplugins/PvB-brain-inspection.md.
    RegAdminCmd("sm_brainstats",     Cmd_BrainStats,     ADMFLAG_ROOT, "[ROOT] High-level brain summary: counts per policy table, heatmap cells, opponent rows.");
    RegAdminCmd("sm_brainshow",      Cmd_BrainShow,      ADMFLAG_ROOT, "[ROOT] Show weights for a specific brain key. Usage: sm_brainshow <key>");
    RegAdminCmd("sm_brainopponent",  Cmd_BrainOpponent,  ADMFLAG_ROOT, "[ROOT] Show stored opponent profile for a player. Usage: sm_brainopponent <#userid|name>");
    RegAdminCmd("sm_brainheatmap",   Cmd_BrainHeatmap,   ADMFLAG_ROOT, "[ROOT] Dump current-map danger heatmap to log file. Usage: sm_brainheatmap [bot_type]");
    RegAdminCmd("sm_stopdebug", Cmd_StopDebug, ADMFLAG_ROOT, "[ROOT] Stop bot debug logging.");
    
    // === PLAYER Commands ===
    RegConsoleCmd("sm_botstats", Cmd_BotStats, "Show PvB bot stats.");
    RegConsoleCmd("sm_botmenu", Cmd_BotMenu, "Show bot type selection menu.");
    RegConsoleCmd("sm_votepvb", Cmd_BotVote, "Vote to enable PvB bot.");
    RegConsoleCmd("sm_botvote", Cmd_BotVote, "Alias for sm_votepvb.");
    RegConsoleCmd("sm_votebot", Cmd_BotVote, "Alias for sm_votepvb.");

    // Check if TFDB is already loaded (late load support)
    TFDBAvailable = LibraryExists("tfdb");

    // Database: use SourceMod's built-in SQLite store so the brain lives at
    // addons/sourcemod/data/sqlite/tfdb_pvb.sq3 without a databases.cfg entry.
    ConnectBrainDatabase();
}

void ConnectBrainDatabase() {
    char error[256];
    Database db = SQLite_UseDatabase("tfdb_pvb", error, sizeof(error));
    OnDatabaseConnected(db, error, 0);
}

void LoadTauntFile(const char[] relPath, ArrayList list) {
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), relPath);

    File file = OpenFile(path, "r");
    if (file == null) {
        LogError("[PvB] Could not open %s", path);
        return;
    }

    char line[256];
    while (file.ReadLine(line, sizeof(line))) {
        TrimString(line);
        if (line[0] != '\0' && !(line[0] == '/' && line[1] == '/')) {
            list.PushString(line);
        }
    }
    delete file;
    PrintToServer("[PvB] Loaded %d lines from %s", list.Length, relPath);
}

// ============================================================================
// DATABASE
// ============================================================================

public void OnDatabaseConnected(Database db, const char[] error, any data) {
    if (db == null) {
        LogError("[PvB] Brain DB failed: %s", error);
        return;
    }
    BrainDB = db;

    BrainDB.Query(SQL_Generic,
        "CREATE TABLE IF NOT EXISTS bot_brain_v3 ("
    ... "state_key VARCHAR(32), "
    ... "trick_id INTEGER, "
    ... "weight INTEGER DEFAULT 50, "
    ... "PRIMARY KEY (state_key, trick_id))");

    BrainDB.Query(SQL_Generic,
        "CREATE TABLE IF NOT EXISTS bot_reaction_v1 ("
    ... "bot_type INTEGER PRIMARY KEY, "
    ... "react_min_delta REAL DEFAULT 0.0, "
    ... "react_max_delta REAL DEFAULT 0.0)");

    BrainDB.Query(SQL_Generic,
        "CREATE TABLE IF NOT EXISTS bot_opponent_v1 ("
    ... "steam_id INTEGER PRIMARY KEY, "
    ... "strafe_left INTEGER DEFAULT 0, "
    ... "strafe_right INTEGER DEFAULT 0, "
    ... "stood_still INTEGER DEFAULT 0, "
    ... "jumped INTEGER DEFAULT 0, "
    ... "crouched INTEGER DEFAULT 0, "
    ... "cqc_approach INTEGER DEFAULT 0, "
    ... "cqc_retreat INTEGER DEFAULT 0, "
    ... "total_deflects INTEGER DEFAULT 0, "
    ... "total_kills INTEGER DEFAULT 0, "
    ... "total_deaths INTEGER DEFAULT 0, "
    ... "avg_deflect_speed REAL DEFAULT 0.0)");

    BrainDB.Query(SQL_Generic,
        "CREATE TABLE IF NOT EXISTS bot_heatmap_v1 ("
    ... "map_name VARCHAR(64), "
    ... "bot_type INTEGER, "
    ... "gx INTEGER, "
    ... "gy INTEGER, "
    ... "deflects INTEGER DEFAULT 0, "
    ... "deaths INTEGER DEFAULT 0, "
    ... "PRIMARY KEY (map_name, bot_type, gx, gy))");

    BrainDB.Query(SQL_LoadBrain,      "SELECT state_key, trick_id, weight FROM bot_brain_v3");
    BrainDB.Query(SQL_LoadReaction,   "SELECT bot_type, react_min_delta, react_max_delta FROM bot_reaction_v1");
    LoadHeatmapForCurrentMap();
}

public void SQL_LoadReaction(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0] != '\0') { LogError("[PvB] Reaction load error: %s", error); return; }
    while (results.FetchRow()) {
        int t = results.FetchInt(0);
        if (t < 0 || t >= MAX_BOT_TYPES) continue;
        ReactMinDelta[t] = results.FetchFloat(1);
        ReactMaxDelta[t] = results.FetchFloat(2);
    }
}

public void SQL_LoadHeatmap(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0] != '\0') { LogError("[PvB] Heatmap load error: %s", error); return; }
    if (HeatmapCells == null) HeatmapCells = new StringMap();
    while (results.FetchRow()) {
        char mapName[64];
        results.FetchString(0, mapName, sizeof(mapName));
        int botType = results.FetchInt(1);
        int gx      = results.FetchInt(2);
        int gy      = results.FetchInt(3);
        int cell[2];
        cell[0] = results.FetchInt(4); // deflects
        cell[1] = results.FetchInt(5); // deaths

        char key[96];
        FormatEx(key, sizeof(key), "%s|%d|%d|%d", mapName, botType, gx, gy);
        HeatmapCells.SetArray(key, cell, 2);
    }
    // Apply decay AFTER load so cells that haven't been refreshed since last
    // session lose influence. Zero-valued cells get pruned on the next flush.
    DecayHeatmap(HEATMAP_DECAY_FACTOR);
}

void LoadHeatmapForCurrentMap() {
    if (BrainDB == null || !CfgUseHeatmap) return;
    if (CurrentMap[0] == '\0') GetCurrentMap(CurrentMap, sizeof(CurrentMap));

    char escMap[128];
    BrainDB.Escape(CurrentMap, escMap, sizeof(escMap));
    char query[256];
    FormatEx(query, sizeof(query),
        "SELECT map_name, bot_type, gx, gy, deflects, deaths FROM bot_heatmap_v1 WHERE map_name='%s'",
        escMap);
    BrainDB.Query(SQL_LoadHeatmap, query);
}

public void SQL_LoadBrain(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0] != '\0') { LogError("[PvB] Brain load error: %s", error); return; }

    while (results.FetchRow()) {
        char key[32];
        results.FetchString(0, key, sizeof(key));
        int trickId = results.FetchInt(1);
        int weight = results.FetchInt(2);

        int weights[NUM_TRICKS];
        if (BrainMemory != null && !BrainMemory.GetArray(key, weights, NUM_TRICKS)) {
            InitDefaultWeights(weights);
        }
        if (trickId >= 0 && trickId < NUM_TRICKS) {
            weights[trickId] = weight;
        }
        if (BrainMemory != null) {
            BrainMemory.SetArray(key, weights, NUM_TRICKS);
        }
    }
    PrintToServer("[PvB] Brain loaded successfully.");
}

public void SQL_Generic(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0] != '\0') LogError("[PvB] DB Error: %s", error);
}

// Completion callback for admin brain-reset DELETEs. Clears BrainDraining so
// normal writes resume, then reloads the in-memory brain from the (now empty
// or pruned) table. If the DELETE failed we still clear the flag — keeping it
// set would permanently block writes; the error is logged and the admin can retry.
public void SQL_BrainResetComplete(Database db, DBResultSet results, const char[] error, any data) {
    if (error[0] != '\0') {
        LogError("[PvB] Brain reset DELETE failed: %s", error);
    }
    BrainDraining = false;
    if (db != null) {
        db.Query(SQL_LoadBrain, "SELECT state_key, trick_id, weight FROM bot_brain_v3");
    }
}

// ============================================================================
// MAP LIFECYCLE
// ============================================================================

public void OnMapStart() {
    bool wasTraining = TrainingMode;  // Remember if we were training

    // Re-enforce quota lock: map configs (server.cfg, map-specific cfg) can
    // reset tf_bot_quota_mode back to "fill". Without this, the server would
    // auto-spawn a replacement vanilla bot on the new map.
    LockBotQuota();

    // Flush any pending heatmap data from the prior map, then swap map name
    if (HeatmapDirty) FlushHeatmap();
    GetCurrentMap(CurrentMap, sizeof(CurrentMap));
    if (HeatmapCells != null) HeatmapCells.Clear();
    LoadHeatmapForCurrentMap();

    
    CommandForced = false;
    CommandDisabled = false;
    BotNameDirty = true;
    CachedRocketRef = INVALID_ENT_REFERENCE;
    CachedRealCount = 0;
    CachedFakeCount = 0;

    PrecacheModel("models/bots/pyro/bot_pyro.mdl", true);

    CreateTimer(5.0, Timer_ClearMapChanged);

    // Debug logging persists across map changes — rotate to new file per map
    if (DebugActive) {
        RotateDebugFile();
    }

    // If training was active before map change, re-spawn all training bots
    if (wasTraining) {
        TrainingMode = false; // Reset so StartTraining can set it fresh
        TrainingBotCount = 0;
        CreateTimer(3.0, Timer_StartTraining, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        TrainingMode = false;
        TrainingBotCount = 0;
    }
}

public void OnMapEnd() {
    MapChanged = true;
    if (BotEnabled && !TrainingMode) {
        DisablePvB();
    }
    FlushHeatmap();
    FlushBrainWrites();
    SaveReactionDeltas();

    // Reset vote state cleanly across map change. Without this, ClassVoteActive
    // could survive into the next map, causing the next !votepvb to bounce off
    // PvB_Vote_InProgress until something else clears it.
    delete ClassVoteTimer;
    ClassVoteTimer = null;
    ClassVoteActive = false;
    PendingHotSwapType = -1;
    PendingMaxPlayerDisable = false;
    for (int i = 1; i <= MaxClients; i++) {
        ClassVoted[i] = -1;
    }
    for (int t = 0; t <= MAX_BOT_TYPES; t++) {
        ClassVotes[t] = 0;
    }

    // Training mode persists across map changes - bots will respawn in OnMapStart
}

public Action Timer_ClearMapChanged(Handle timer) {
    MapChanged = false;
    return Plugin_Stop;
}

// ============================================================================
// CLIENT LIFECYCLE
// ============================================================================

public void OnClientDisconnect(int client) {
    Allowed[client] = false;
    ClassVoted[client] = -1;
    SaveOpponentToDB(client);
    ResetCombatState(client);
    ResetOpponentProfile(client);

    // Client is still "in-game" during OnClientDisconnect, so UpdateCachedCounts
    // would still count them. Instead, check if this was the last human — if so,
    // kick the bot NOW before the server hibernates and OnGameFrame stops firing.
    if (!IsFakeClient(client) && BotEnabled && !TrainingMode)
    {
        int humansLeft = 0;
        for (int i = 1; i <= MaxClients; i++)
        {
            if (i == client) continue;  // Skip the leaving player
            if (!TFDB_IsRealHuman(i)) continue;
            humansLeft++;
        }

        if (humansLeft == 0)
        {
            DisablePvB();
            CommandForced = false;
            CommandDisabled = false;
        }
    }

    UpdateCachedCounts();
}

public void OnClientPostAdminCheck(int client) {
    UpdateCachedCounts();
    LoadOpponentFromDB(client);
}

void UpdateCachedCounts() {
    // CachedRealCount = real humans on a PLAY team (RED/BLU). Spectators don't count.
    // Every consumer of CachedRealCount asks "how many humans can play?" — a
    // spec player is not a participant. Excluding them here is what makes
    // PvB auto-disable when the last human goes to spec (bug 2026-04-26).
    int real = 0, fake = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;
        if (IsClientReplay(i) || IsClientSourceTV(i)) continue;
        if (IsFakeClient(i)) { fake++; continue; }
        int team = GetClientTeam(i);
        if (team == view_as<int>(TFTeam_Red) || team == view_as<int>(TFTeam_Blue)) real++;
    }
    CachedRealCount = real;
    CachedFakeCount = fake;
}

// RequestFrame target — defers UpdateCachedCounts to one frame after a
// player_team event so GetClientTeam returns the post-transition value.
public void Frame_RefreshCachedCounts(any data) {
    UpdateCachedCounts();
}

// ============================================================================
// ENABLE / DISABLE
// ============================================================================

// Lock down TF2's bot quota so the server never auto-spawns replacement bots.
// Called from OnPluginStart, OnMapStart, and before EnablePvB adds our bot.
// Redundant by design — some map configs can reset cvars between ticks.
void LockBotQuota() {
    ServerCommand("tf_bot_quota_mode normal");
    ServerCommand("tf_bot_quota 0");
    ServerCommand("tf_bot_auto_vacate 0");
}

void EnablePvB() {
    // Refuse to activate during a Guardian round. Three-gate check avoids the
    // "Plugin owning this native is currently paused" exception when the partner
    // plugin crashed/paused after load — FeatureStatus_Available alone isn't
    // enough because the native binding survives a pause; LibraryExists is the
    // authoritative runtime gate.
    if (LibraryExists("tfdb_guardian") &&
        GetFeatureStatus(FeatureType_Native, "TFDB_IsGuardianActive") == FeatureStatus_Available &&
        TFDB_IsGuardianActive()) {
        CPrintToChatAll("{olive}[TFDB]{default} Cannot enable PvB while a Guardian round is active.");
        LogMessage("[PvB] EnablePvB refused: TFDB_IsGuardianActive() returned true");
        return;
    }

    // DeathMatch (NER / Solo) mutual exclusion — DM swaps teams which corrupts
    // the PvB bot-vs-humans team layout. Same three-gate pattern as above.
    if (LibraryExists("tfdb_deathmatch") &&
        GetFeatureStatus(FeatureType_Native, "TFDB_IsDeathMatchActive") == FeatureStatus_Available &&
        TFDB_IsDeathMatchActive()) {
        CPrintToChatAll("{olive}[TFDB]{default} Cannot enable PvB while DeathMatch (NER/Solo) is active.");
        LogMessage("[PvB] EnablePvB refused: TFDB_IsDeathMatchActive() returned true");
        return;
    }

    // FFA mutex — FFA flips rocket teams to neutral. With PvB's bot-on-BLU layout,
    // the bot ends up neutral and friendly-fires its own teammates (paradoxical
    // since "team" means nothing in FFA, but the bot AI doesn't model that). Plus
    // PvB assumes 1v1 bot-vs-human team semantics throughout. Guard at activation.
    if (LibraryExists("tfdb_ffa") &&
        GetFeatureStatus(FeatureType_Native, "TFDB_IsFFAActive") == FeatureStatus_Available &&
        TFDB_IsFFAActive()) {
        CPrintToChatAll("{olive}[TFDB]{default} Cannot enable PvB while FFA is active.");
        LogMessage("[PvB] EnablePvB refused: TFDB_IsFFAActive() returned true");
        return;
    }

    LockBotQuota();   // ensure no auto-replacement will fight our tf_bot_add
    ServerCommand("mp_autoteambalance 0");

    // Arena mode enforces mp_teams_unbalance_limit when ChangeClientTeam is called.
    // Set to 0 so we can freely shuffle humans between teams during activation
    // and steady-state enforcement. Restored in DisablePvB().
    ServerCommand("mp_teams_unbalance_limit 0");

    // CRITICAL: move all non-spectator humans to RED BEFORE spawning the bot on BLU.
    //
    // Arena warmup ("Waiting for N more players") gates on BOTH teams having ≥1
    // player. If we add the bot to BLU while the invoking human is also on BLU,
    // RED stays empty → arena never transitions out of warmup → the bot spawns
    // stuck dead → ManageTeams's forced respawn silently fails because the
    // round hasn't started. This is the deadlock Guardian avoids by spawning
    // its boss on BLU *after* humans have already landed on RED in OnRoundStart.
    //
    // Since PvB activates mid-round (menu pick or !pvb), we have to pre-seed
    // RED ourselves. One human on RED + one bot on BLU = CheckReadyRestart()
    // fires → arena_round_start → everyone respawns alive. The prior
    // ManageTeams-based enforcement runs forever as a backstop.
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i)) continue;
        int teamBefore = GetClientTeam(i);
        // Gate on TEAM, not IsClientObserver. During arena pregame, dead/not-
        // yet-spawned players on BLU/RED are in freeze-cam observer mode but
        // they are NOT on the spectator team — IsClientObserver would skip
        // them incorrectly. We only leave actual spectators (team 1) alone.
        if (teamBefore <= view_as<int>(TFTeam_Spectator)) continue;
        if (teamBefore == view_as<int>(TFTeam_Red)) continue;
        ChangeClientTeam(i, view_as<int>(TFTeam_Red));
    }

    ServerCommand("tf_bot_add 1 Pyro blue easy \"%s\"", BotName);
    ServerCommand("tf_bot_difficulty 0");
    ServerCommand("tf_bot_keep_class_after_death 1");
    ServerCommand("tf_bot_taunt_victim_chance 0");
    ServerCommand("tf_bot_join_after_player 0");

    BotEnabled = true;
    BotNameDirty = true;
    UpdateCachedCounts();
    CPrintToChatAll("%t", "PvB_Entered", BotName);
    LogMessage("[PvB] EnablePvB complete — humans forced to RED, bot added to BLU (bot=%s).", BotName);

    ApplyBotTypeSettings();
}

void ApplyBotTypeSettings() {
    LoadBotTypeSettings(CfgBotType);
}

void DisablePvB() {
    if (TrainingMode) {
        StopTraining();
        return;
    }
    ServerCommand("mp_autoteambalance 1");
    ServerCommand("mp_teams_unbalance_limit 1");  // restore default — undo EnablePvB override
    ServerCommand("tf_bot_kick all");
    BotEnabled = false;
    PendingMaxPlayerDisable = false;  // bot is gone, drain any stale queue
    PendingHotSwapType = -1;          // any queued vote-swap is moot now
    CachedRocketRef = INVALID_ENT_REFERENCE;
    CPrintToChatAll("%t", "PvB_Left", BotName);
}

// ============================================================================
// TRAINING MODE (ROOT ONLY)
// Spawns all 4 bot types on BOTH teams so they train against each other.
// Bots on RED fight bots on BLU, learning from every deflect and death.
// ============================================================================

public Action Cmd_TrainBots(int client, int args) {
    if (TrainingMode) {
        CReplyToCommand(client, "%t", "PvB_Training_AlreadyActive");
        return Plugin_Handled;
    }
    
    if (BotEnabled) {
        // Kill the normal mode bot first - need enough delay for kick to complete
        BotEnabled = false;
        CommandDisabled = true;  // Prevent auto-enable from respawning during transition
        CachedRocketRef = INVALID_ENT_REFERENCE;
        ServerCommand("tf_bot_kick all");
        CreateTimer(2.0, Timer_StartTraining, _, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        // No existing bot, but still kick any strays and set flag
        CommandDisabled = true;
        ServerCommand("tf_bot_kick all");
        CreateTimer(1.0, Timer_StartTraining, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    CReplyToCommand(client, "%t", "PvB_Training_Started");
    return Plugin_Handled;
}

public Action Timer_StartTraining(Handle timer) {
    StartTraining();
    return Plugin_Stop;
}

void StartTraining() {
    // Safety cap: max bots per team = half of max_training_bots, never > num classes
    int perTeam = NumBotTypes;
    int halfCap = CfgMaxTrainingBots / 2;
    if (perTeam > halfCap) perTeam = halfCap;
    if (perTeam < 1) perTeam = 1;
    // Force quota_mode to "normal" BEFORE doing anything else. In normal mode
    // the server never adds or removes bots on its own - only explicit
    // tf_bot_add / tf_bot_kick calls take effect. If the server.cfg (or another
    // plugin) left quota_mode as "fill" or "match", the engine will silently
    // trim our named bots to match the quota, which is what was happening.
    // ref: https://developer.valvesoftware.com/wiki/Bot_quota
    ServerCommand("tf_bot_quota_mode normal");
    ServerCommand("tf_bot_quota 0");               // Ignored in normal mode, set for safety
    ServerCommand("mp_teams_unbalance_limit 0");   // Allow 4v5 when player joins
    ServerCommand("mp_autoteambalance 0");

    // Disable hibernation while training. When the server hibernates (empty or
    // via tf_allow_server_hibernation), SourceMod timers stop firing and TF2
    // kicks any connected bots - which would silently destroy a training
    // session the moment the last human leaves. We restore defaults in
    // StopTraining. ref: https://developer.valvesoftware.com/wiki/Server_Hibernation
    ServerCommand("tf_allow_server_hibernation 0");

    ServerCommand("tf_bot_kick all");

    TrainingMode = true;
    BotEnabled = true;
    CommandDisabled = false;  // Clear so training can manage its own state
    CommandForced = true;     // Prevent auto-disable from killing training bots
    TrainingBotCount = 0;

    // Reset diversity tracking for a fresh session
    for (int t = 0; t < MAX_BOT_TYPES; t++) {
        TypeWins[t] = 0;
        TypeMatches[t] = 0;
    }
    ExploiterTargetType = -1;

    ServerCommand("tf_bot_difficulty 0");
    ServerCommand("tf_bot_keep_class_after_death 1");
    ServerCommand("tf_bot_taunt_victim_chance 0");
    ServerCommand("tf_bot_join_after_player 0");

    for (int i = 0; i < perTeam; i++) {
        char bluName[MAX_NAME_LENGTH];
        FormatEx(bluName, sizeof(bluName), "%s [BLU]", BotNames[i]);
        ServerCommand("tf_bot_add 1 Pyro blue easy \"%s\"", bluName);
        TrainingBotCount++;
    }

    for (int i = 0; i < perTeam; i++) {
        char redName[MAX_NAME_LENGTH];
        FormatEx(redName, sizeof(redName), "%s [RED]", BotNames[i]);
        ServerCommand("tf_bot_add 1 Pyro red easy \"%s\"", redName);
        TrainingBotCount++;
    }

    // Don't re-raise tf_bot_quota here - normal mode ignores it entirely,
    // and we don't want the engine auto-adding unnamed replacements anyway.

    if (perTeam < NumBotTypes) {
        CPrintToChatAll("%t", "PvB_Training_Capped", CfgMaxTrainingBots, perTeam);
    }
    
    CPrintToChatAll("%t", "PvB_Training_Spawned", perTeam * 2, perTeam);
    CPrintToChatAll("%t", "PvB_Training_HowToStop");
    
    // Assign bot types based on name after they connect
    CreateTimer(2.0, Timer_AssignTrainingTypes, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_AssignTrainingTypes(Handle timer) {
    if (!TrainingMode) return Plugin_Stop;
    
    for (int i = 1; i <= MaxClients; i++) {
        if (!TFDB_IsLiveBot(i)) continue;

        char name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));
        
        // Match against config names to assign type
        // Check most specific first (in case names share substrings)
        bool matched = false;
        for (int t = NumBotTypes - 1; t >= 0; t--) {
            if (StrContains(name, BotNames[t]) != -1) {
                TrainingBotType[i] = t;
                matched = true;
                break;
            }
        }
        
        if (!matched) {
            // Fallback: match on class key substring, else default to first class
            TrainingBotType[i] = 0;
            for (int t = NumBotTypes - 1; t >= 0; t--) {
                if (BotClassKey[t][0] == '\0') continue;
                if (StrContains(name, BotClassKey[t], false) != -1) {
                    TrainingBotType[i] = t;
                    break;
                }
            }
        }
    }
    
    UpdateCachedCounts();
    return Plugin_Stop;
}


public Action Cmd_StopTraining(int client, int args) {
    if (!TrainingMode) {
        CReplyToCommand(client, "%t", "PvB_Training_NotActive");
        return Plugin_Handled;
    }
    
    StopTraining();
    CReplyToCommand(client, "%t", "PvB_Training_Ended_Admin");
    return Plugin_Handled;
}

void StopTraining() {
    TrainingMode = false;
    BotEnabled = false;
    TrainingBotCount = 0;
    CachedRocketRef = INVALID_ENT_REFERENCE;

    // Restore TF2 cvars we stomped on for training
    ServerCommand("tf_bot_quota 0");
    ServerCommand("tf_bot_kick all");
    ServerCommand("mp_teams_unbalance_limit 1");
    ServerCommand("mp_autoteambalance 1");
    ServerCommand("tf_allow_server_hibernation 1");

    CPrintToChatAll("%t", "PvB_Training_Ended");
}

// ============================================================================
// ADMIN MENU SYSTEM
// ============================================================================

public Action Cmd_BotAdmin(int client, int args) {
    // Menu commands require an active client to display to. RCON path is fatal.
    if (client == 0 || !IsClientInGame(client) || IsFakeClient(client)) {
        CReplyToCommand(client, "%t", "PvB_ConsoleOnly_Admin");
        return Plugin_Handled;
    }

    ShowAdminMainMenu(client);
    return Plugin_Handled;
}

void ShowAdminMainMenu(int client) {
    Menu menu = new Menu(MenuHandler_AdminMain);
    char title[128];
    FormatEx(title, sizeof(title), "%T", "PvB_Menu_Admin_Panel", client,
        BotEnabled ? "ACTIVE" : "INACTIVE",
        TrainingMode ? "TRAINING" : "Normal");
    menu.SetTitle(title);
    
    menu.AddItem("toggle", BotEnabled ? "Disable Bot" : "Enable Bot");
    menu.AddItem("type", "Change Bot Type");
    menu.AddItem("stats", "View Bot Stats");
    menu.AddItem("reload", "Reload Config");
    menu.AddItem("brain", "Brain Management");
    menu.AddItem("speech", "Speech Settings");
    
    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_AdminMain(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "toggle")) {
            if (!BotEnabled) {
                EnablePvB();
                CommandForced = true;
                CommandDisabled = false;
            } else {
                DisablePvB();
                CommandDisabled = true;
                CommandForced = false;
            }
            ShowAdminMainMenu(param1);
        }
        else if (StrEqual(info, "type")) {
            ShowAdminTypeMenu(param1);
        }
        else if (StrEqual(info, "stats")) {
            ShowBotStatsMenu(param1);
        }
        else if (StrEqual(info, "reload")) {
            LoadPvBConfig();
            CPrintToChat(param1, "%t", "PvB_ConfigReloaded");
            ShowAdminMainMenu(param1);
        }
        else if (StrEqual(info, "brain")) {
            ShowAdminBrainMenu(param1);
        }
        else if (StrEqual(info, "speech")) {
            ShowAdminSpeechMenu(param1);
        }
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowAdminTypeMenu(int client) {
    Menu menu = new Menu(MenuHandler_AdminType);

    char currentName[32];
    GetBotTypeNameSafe(CfgBotType, currentName, sizeof(currentName));
    char title[96];
    FormatEx(title, sizeof(title), "%T", "PvB_Menu_Choose_Type", client, currentName);
    menu.SetTitle(title);

    for (int t = 0; t < NumBotTypes; t++) {
        char info[8], display[96];
        IntToString(t, info, sizeof(info));
        if (t == CfgBotType) {
            FormatEx(display, sizeof(display), ">> %s <<", BotDisplayName[t]);
        } else {
            strcopy(display, sizeof(display), BotDisplayName[t]);
        }
        menu.AddItem(info, display);
    }

    menu.ExitBackButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_AdminType(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[8];
        menu.GetItem(param2, info, sizeof(info));
        int type = StringToInt(info);
        LoadBotTypeSettings(type);
        
        char typeName[32];
        GetBotTypeNameSafe(CfgBotType, typeName, sizeof(typeName));
        CPrintToChatAll("%t", "PvB_Admin_TypeChanged", typeName);
        ShowAdminMainMenu(param1);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowAdminMainMenu(param1);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowAdminBrainMenu(int client) {
    Menu menu = new Menu(MenuHandler_AdminBrain);
    char title[64];
    FormatEx(title, sizeof(title), "%T", "PvB_Menu_Brain_Mgmt", client);
    menu.SetTitle(title);
    
    int brainSize = BrainMemory != null ? BrainMemory.Size : 0;
    char sizeInfo[64];
    FormatEx(sizeInfo, sizeof(sizeInfo), "Brain entries: %d", brainSize);
    menu.AddItem("info", sizeInfo, ITEMDRAW_DISABLED);
    
    // Only ROOT can reset brain data
    bool isRoot = (client == 0 || (GetUserFlagBits(client) & ADMFLAG_ROOT) != 0);
    menu.AddItem("reset", "!! RESET ALL BRAIN DATA !!", isRoot ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    menu.AddItem("resettype", "Reset brain for current type only", isRoot ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    
    if (!isRoot) {
        menu.AddItem("rootonly", "[Requires ROOT access]", ITEMDRAW_DISABLED);
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_AdminBrain(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        // Double-check ROOT access before actually resetting
        bool isRoot = (param1 == 0 || (GetUserFlagBits(param1) & ADMFLAG_ROOT) != 0);
        if (!isRoot) {
            CPrintToChat(param1, "%t", "PvB_Brain_RequiresRoot");
            ShowAdminMainMenu(param1);
            return 0;
        }
        
        if (StrEqual(info, "reset")) {
            ResetAllBrainData();
            CPrintToChat(param1, "%t", "PvB_Brain_ResetAll");
        }
        else if (StrEqual(info, "resettype")) {
            ResetBrainForType(CfgBotType);
            char typeName[32];
            GetBotTypeNameSafe(CfgBotType, typeName, sizeof(typeName));
            CPrintToChat(param1, "%t", "PvB_Brain_ResetType", typeName);
        }
        
        ShowAdminMainMenu(param1);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowAdminMainMenu(param1);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void ShowAdminSpeechMenu(int client) {
    Menu menu = new Menu(MenuHandler_AdminSpeech);
    char title[64];
    FormatEx(title, sizeof(title), "%T", "PvB_Menu_Speech", client, CfgSpeech ? "ON" : "OFF");
    menu.SetTitle(title);
    
    menu.AddItem("toggle", CfgSpeech ? "Disable Speech" : "Enable Speech");
    
    for (int t = 0; t < NumBotTypes; t++) {
        char info[8], display[128];
        IntToString(t, info, sizeof(info));
        char typeName[32];
        GetBotTypeNameSafe(t, typeName, sizeof(typeName));
        FormatEx(display, sizeof(display), "%s: %d kill / %d death lines",
            typeName, 
            TauntsPlayerDeath[t].Length,
            TauntsBotDeath[t].Length);
        menu.AddItem(info, display, ITEMDRAW_DISABLED);
    }
    
    menu.ExitBackButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_AdminSpeech(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "toggle")) {
            CfgSpeech = !CfgSpeech;
            CPrintToChat(param1, "%t", "PvB_Speech_Toggled", CfgSpeech ? "enabled" : "disabled");
        }
        ShowAdminMainMenu(param1);
    }
    else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowAdminMainMenu(param1);
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

public Action Cmd_SetBotType(int client, int args) {
    if (args < 1) {
        CReplyToCommand(client, "%t", "PvB_SetBotType_Usage", NumBotTypes);
        for (int t = 0; t < NumBotTypes; t++) {
            CReplyToCommand(client, "  %d = %s (%s)", t, BotClassKey[t], BotDisplayName[t]);
        }
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));

    int type = -1;
    if (arg[0] >= '0' && arg[0] <= '9') {
        type = StringToInt(arg);
        if (type < 0 || type >= NumBotTypes) type = -1;
    }
    if (type < 0) type = FindClassIndexByName(arg);

    if (type < 0) {
        CReplyToCommand(client, "%t", "PvB_SetBotType_Unknown", arg, NumBotTypes);
        return Plugin_Handled;
    }

    LoadBotTypeSettings(type);
    char typeName[32];
    GetBotTypeNameSafe(CfgBotType, typeName, sizeof(typeName));
    CPrintToChatAll("%t", "PvB_BotType_Set", typeName);
    return Plugin_Handled;
}

public Action Cmd_ReloadConfig(int client, int args) {
    LoadPvBConfig();
    // Re-apply settings to the live bot so cfg edits take effect without
    // requiring a hot-swap or map change. Previous behavior left runtime state
    // (BotName, weapon attributes, taunt lines) using stale pre-reload values
    // until next bot spawn. ApplyBotTypeSettings re-reads CfgBotType and
    // re-pushes settings.
    if (BotEnabled) {
        ApplyBotTypeSettings();
    }
    CReplyToCommand(client, "%t", "PvB_ConfigReloaded");
    return Plugin_Handled;
}

public Action Cmd_ResetBrain(int client, int args) {
    ResetAllBrainData();
    CReplyToCommand(client, "%t", "PvB_Brain_ResetAll");
    return Plugin_Handled;
}

// Admin-issued full brain wipe. Drain-flush-delete protocol:
//   1. Set BrainDraining (QueueBrainWrite + FlushBrainWrites now bail).
//   2. FlushBrainWrites persists any pending queue — then we clear BrainMemory.
//   3. Issue DELETE via the threaded driver; driver serializes it after the
//      flush's COMMIT so no race.
//   4. Completion callback (SQL_BrainResetComplete) clears BrainDraining.
// Late writes arriving between step 1 and step 4 are silently dropped, which
// is correct — the admin asked for a wipe. See ai-bots/pvb-brain-reset-protocol.md.
void ResetAllBrainData() {
    BrainDraining = true;

    // Persist anything already queued (so if the DELETE fails, we haven't lost
    // pre-reset state). Runs synchronously from the caller's POV — FlushBrainWrites
    // fires its queries through the serialized driver.
    if (BrainWriteQueue != null) {
        // Bypass the BrainDraining gate for this one intentional flush.
        BrainDraining = false;
        FlushBrainWrites();
        BrainDraining = true;
    }

    if (BrainMemory != null) {
        BrainMemory.Clear();
    }
    if (BrainDB != null) {
        BrainDB.Query(SQL_BrainResetComplete, "DELETE FROM bot_brain_v3");
    } else {
        BrainDraining = false;  // no DB, nothing will call back
    }
}

void ResetBrainForType(int botType) {
    BrainDraining = true;

    if (BrainWriteQueue != null) {
        BrainDraining = false;
        FlushBrainWrites();
        BrainDraining = true;
    }

    if (BrainMemory != null) {
        BrainMemory.Clear();
    }
    if (BrainDB != null) {
        char query[256];
        FormatEx(query, sizeof(query), "DELETE FROM bot_brain_v3 WHERE state_key LIKE '%%_t%d_%%'", botType);
        BrainDB.Query(SQL_BrainResetComplete, query);
        // reload happens on the reset-complete callback's follow-up
    } else {
        BrainDraining = false;
    }
}

// ============================================================================
// PLAYER COMMANDS - Toggle, Vote, Stats, Menu
// ============================================================================

public Action Cmd_Toggle(int client, int args) {
    if (!CfgEnabled) return Plugin_Handled;

    if (!BotEnabled) {
        EnablePvB();
        CommandForced = true;
        CommandDisabled = false;
    } else {
        DisablePvB();
        CommandDisabled = true;
        CommandForced = false;
    }
    return Plugin_Handled;
}

public Action Cmd_BotMenu(int client, int args) {
    if (client == 0 || !IsClientInGame(client) || IsFakeClient(client)) {
        CReplyToCommand(client, "%t", "PvB_ConsoleOnly_Player");
        return Plugin_Handled;
    }

    if (!CfgEnabled) {
        CReplyToCommand(client, "%t", "PvB_Disabled");
        return Plugin_Handled;
    }

    ShowBotTypeMenu(client);
    return Plugin_Handled;
}

public Action Cmd_BotStats(int client, int args) {
    if (client == 0) {
        CReplyToCommand(client, "%t", "PvB_ConsoleOnly_Stats");
        return Plugin_Handled;
    }
    
    if (!BotEnabled) {
        CReplyToCommand(client, "%t", "PvB_Bot_NotActive");
        return Plugin_Handled;
    }
    
    int totalRounds = BotWins + BotLosses;
    float winRate = (totalRounds > 0) ? (float(BotWins) / float(totalRounds) * 100.0) : 0.0;
    
    CPrintToChat(client, "%t", "PvB_Stats_Header");
    char typeName[32];
    GetBotTypeNameSafe(CfgBotType, typeName, sizeof(typeName));
    CPrintToChat(client, "%t", "PvB_Stats_Type", typeName);
    CPrintToChat(client, "%t", "PvB_Stats_Rounds", totalRounds, BotWins, BotLosses);
    CPrintToChat(client, "%t", "PvB_Stats_WinRate", winRate);
    CPrintToChat(client, "%t", "PvB_Stats_Deflects", TotalDeflects, RoundDeflects);
    CPrintToChat(client, "%t", "PvB_Stats_Kills", TotalKills);
    CPrintToChat(client, "%t", "PvB_Stats_Deaths", TotalDeaths);
    CPrintToChat(client, "%t", "PvB_Stats_Brain", BrainMemory != null ? BrainMemory.Size : 0);
    CPrintToChat(client, "%t", "PvB_Stats_Footer");
    
    return Plugin_Handled;
}

void GetBotTypeNameSafe(int botType, char[] buffer, int maxLen) {
    if (botType < 0 || botType >= NumBotTypes || BotDisplayName[botType][0] == '\0') {
        strcopy(buffer, maxLen, "Unknown");
        return;
    }
    strcopy(buffer, maxLen, BotDisplayName[botType]);
}

// ============================================================================
// VOTING SYSTEM
// ============================================================================

public Action Cmd_BotVote(int client, int args) {
    if (client == 0 || !IsClientInGame(client) || IsFakeClient(client)) {
        CReplyToCommand(client, "%t", "PvB_ConsoleOnly_Player");
        return Plugin_Handled;
    }

    if (!CfgEnabled) {
        CPrintToChat(client, "%t", "PvB_Disabled");
        return Plugin_Handled;
    }

    if (ClassVoteActive) {
        CPrintToChat(client, "%t", "PvB_Vote_InProgress");
        return Plugin_Handled;
    }

    if (TrainingMode) {
        CPrintToChat(client, "%t", "PvB_Vote_TrainingBlock");
        return Plugin_Handled;
    }

    // Spectators can't start a vote that affects active gameplay state. They
    // CAN view stats via sm_botstats / sm_botmenu — that path doesn't gate on
    // team. This only blocks vote initiation.
    if (GetClientTeam(client) <= view_as<int>(TFTeam_Spectator)) {
        if (TranslationPhraseExists("PvB_Vote_MustBeOnTeam")) {
            CPrintToChat(client, "%t", "PvB_Vote_MustBeOnTeam");
        } else {
            CPrintToChat(client, "[TFDB] You must be on RED or BLU to vote for the bot.");
        }
        return Plugin_Handled;
    }

    // Preemptive mutex check — reject the vote up-front if a partner mode is
    // active (Guardian / DeathMatch / FFA). Without this the vote runs to
    // completion, then EnablePvB() silently fails on the same gates inside —
    // bot never spawns and players are confused. Better to tell them now.
    if (LibraryExists("tfdb_guardian") &&
        GetFeatureStatus(FeatureType_Native, "TFDB_IsGuardianActive") == FeatureStatus_Available &&
        TFDB_IsGuardianActive()) {
        CPrintToChat(client, "{olive}[TFDB]{default} Cannot vote for bot while a Guardian round is active.");
        return Plugin_Handled;
    }
    if (LibraryExists("tfdb_deathmatch") &&
        GetFeatureStatus(FeatureType_Native, "TFDB_IsDeathMatchActive") == FeatureStatus_Available &&
        TFDB_IsDeathMatchActive()) {
        CPrintToChat(client, "{olive}[TFDB]{default} Cannot vote for bot while DeathMatch is active.");
        return Plugin_Handled;
    }
    if (LibraryExists("tfdb_ffa") &&
        GetFeatureStatus(FeatureType_Native, "TFDB_IsFFAActive") == FeatureStatus_Available &&
        TFDB_IsFFAActive()) {
        CPrintToChat(client, "{olive}[TFDB]{default} Cannot vote for bot while FFA is active.");
        return Plugin_Handled;
    }

    int currentPlayers = CachedRealCount;
    if (VoteMaxPlayers > 0 && currentPlayers > VoteMaxPlayers) {
        CPrintToChat(client, "%t", "PvB_Vote_TooManyPlayers", currentPlayers, VoteMaxPlayers);
        return Plugin_Handled;
    }

    // Preemptive check vs CfgMaxPlayers — if the vote would pass but the bot
    // would auto-kick the next tick due to humans > max_players, tell the
    // player upfront with the actual cap instead of running the silent
    // enable-then-disable cycle. Only enforce when bot is OFF (enabling); a
    // vote to DISABLE while humans > max is fine. Skip when bot is already on
    // and the vote could be a hot-swap or disable.
    if (!BotEnabled && CfgMaxPlayers > 0 && currentPlayers > CfgMaxPlayers) {
        // Guard the translation lookup — same rationale as other PvB phrases
        // (stale global phrase cache could throw before the user runs
        // sm_reload_translations). See sourcemod-practices/translations.md.
        if (TranslationPhraseExists("PvB_Vote_AbovePvBLimit")) {
            CPrintToChat(client, "%t", "PvB_Vote_AbovePvBLimit", currentPlayers, CfgMaxPlayers);
        } else {
            CPrintToChat(client, "[TFDB] Bot can't run with this many players (%d > %d max). Have an admin force it with !pvb.",
                currentPlayers, CfgMaxPlayers);
        }
        return Plugin_Handled;
    }

    // Unified class vote. Always shows the bot-type menu with a final
    // "Disable bot" option. This lets players:
    //   - enable the bot by picking a type (when bot is off)
    //   - switch to a different type (when bot is on with a different type)
    //   - disable the bot (pick "Disable bot" from the same menu)
    // One menu, all use cases.
    CPrintToChatAll("%t", "PvB_Vote_StartClass", client);
    StartClassVote();

    return Plugin_Handled;
}

// ============================================================================
// STATS MENU
// ============================================================================

void ShowBotStatsMenu(int client) {
    if (!BotEnabled && !TrainingMode) {
        CPrintToChat(client, "%t", "PvB_Bot_NoActive");
        return;
    }
    
    Menu menu = new Menu(MenuHandler_BotStats);
    
    int totalRounds = BotWins + BotLosses;
    float winRate = (totalRounds > 0) ? (float(BotWins) / float(totalRounds) * 100.0) : 0.0;
    
    char title[256];
    char statsTypeName[32];
    GetBotTypeNameSafe(CfgBotType, statsTypeName, sizeof(statsTypeName));
    FormatEx(title, sizeof(title), "PvB Bot Stats\nType: %s\nWins: %d | Losses: %d (%.1f%%)\nRound Deflects: %d",
           statsTypeName, BotWins, BotLosses, winRate, RoundDeflects);
    menu.SetTitle(title);
    
    char stats[64];
    FormatEx(stats, sizeof(stats), "Total Deflects: %d", TotalDeflects);
    menu.AddItem("deflects", stats, ITEMDRAW_DISABLED);
    
    FormatEx(stats, sizeof(stats), "Kills: %d", TotalKills);
    menu.AddItem("kills", stats, ITEMDRAW_DISABLED);
    
    FormatEx(stats, sizeof(stats), "Deaths: %d", TotalDeaths);
    menu.AddItem("deaths", stats, ITEMDRAW_DISABLED);
    
    FormatEx(stats, sizeof(stats), "Brain Entries: %d", BrainMemory != null ? BrainMemory.Size : 0);
    menu.AddItem("brain", stats, ITEMDRAW_DISABLED);
    
    menu.ExitButton = true;
    menu.Display(client, 20);
}

public int MenuHandler_BotStats(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

// ============================================================================
// CLIENT JOIN / CLASS SELECTION
// ============================================================================

public void OnClientPutInServer(int client) {
    if (IsFakeClient(client)) return;
    ClassVoted[client] = -1;
    
    CreateTimer(3.0, Timer_CheckPlayerJoin, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_CheckPlayerJoin(Handle timer, int userId) {
    int client = GetClientOfUserId(userId);
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop;
    
    if (!CfgEnabled) return Plugin_Stop;
    
    int humans = CachedRealCount;
    
    if (humans == 1 && !BotEnabled && !ClassVoteActive) {
        SoloMenuShown = true;
        ShowClassPickMenu(client);
    }
    else if (humans >= 2 && SoloMenuShown) {
        SoloMenuShown = false;
        if (BotEnabled && !TrainingMode) {
            DisablePvB();
            CPrintToChatAll("%t", "PvB_PlayerJoined_BotDisabled");
        }
    }
    
    return Plugin_Stop;
}

void ShowClassPickMenu(int client) {
    Menu menu = new Menu(MenuHandler_ClassPick);
    char title[64];
    FormatEx(title, sizeof(title), "%T", "PvB_Menu_Choose_Opponent", client);
    menu.SetTitle(title);
    for (int t = 0; t < NumBotTypes; t++) {
        char info[8];
        IntToString(t, info, sizeof(info));
        menu.AddItem(info, BotDisplayName[t]);
    }
    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_ClassPick(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        if (CachedRealCount != 1) {
            CPrintToChat(param1, "%t", "PvB_PlayerJoined_Cancelled");
            SoloMenuShown = false;
        } else {
            char info[8];
            menu.GetItem(param2, info, sizeof(info));
            int type = StringToInt(info);
            
            LoadBotTypeSettings(type);
            
            char typeName[32];
            GetBotTypeNameSafe(CfgBotType, typeName, sizeof(typeName));
            CPrintToChatAll("%t", "PvB_PvB_Starting", typeName);
            
            if (!BotEnabled) {
                EnablePvB();
            }
            SoloMenuShown = false;
        }
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

// ============================================================================
// CLASS VOTE - Multiple players vote for bot type
// ============================================================================

void StartClassVote() {
    if (ClassVoteActive) return;

    // Zero tallies + per-client ballot BEFORE flipping the active flag — if any
    // call below throws (e.g. stale translation cache in ShowClassVoteMenu),
    // the flag stays false so the next !votepvb can retry cleanly.
    for (int t = 0; t <= NumBotTypes; t++) {  // +1 covers the "disable" slot
        ClassVotes[t] = 0;
    }
    for (int i = 1; i <= MaxClients; i++) {
        ClassVoted[i] = -1;
    }

    CPrintToChatAll("%t", "PvB_ClassVote_Start");

    // Show ballot only to players on RED or BLU. Spectators don't get to vote
    // on active gameplay state — same rationale as the starter gate above.
    for (int i = 1; i <= MaxClients; i++) {
        if (TFDB_IsRealHumanPlaying(i)) {
            ShowClassVoteMenu(i);
        }
    }

    // Only now commit to the active state. Even if the menu loop above partial-
    // fails, the timer below guarantees ResolveClassVote runs and clears the flag.
    ClassVoteActive = true;
    delete ClassVoteTimer;
    ClassVoteTimer = CreateTimer(20.0, Timer_EndClassVote, _, TIMER_FLAG_NO_MAPCHANGE);
}

// Special vote value used by the "Disable bot" menu item. Out-of-range of any
// real bot type index (valid types are 0..NumBotTypes-1).
#define PVB_VOTE_DISABLE  -1

void ShowClassVoteMenu(int client) {
    Menu menu = new Menu(MenuHandler_ClassVote);
    char title[64];
    FormatEx(title, sizeof(title), "%T", "PvB_Menu_Vote_Type", client);
    menu.SetTitle(title);
    for (int t = 0; t < NumBotTypes; t++) {
        char info[8];
        IntToString(t, info, sizeof(info));
        menu.AddItem(info, BotDisplayName[t]);
    }
    // "Disable bot" menu entry — only when the bot is currently active. No
    // point offering "disable" when nothing is running. Uses project translation
    // convention (shared `tfdb.phrases.txt`, PvB_* prefix). TranslationPhraseExists
    // guards a stale translation cache (SM's global phrase cache doesn't auto-
    // refresh on plugin reload; requires `sm_reload_translations` or map change).
    if (BotEnabled) {
        char disableLabel[48];
        if (TranslationPhraseExists("PvB_Menu_Vote_Disable_Option")) {
            FormatEx(disableLabel, sizeof(disableLabel), "%T", "PvB_Menu_Vote_Disable_Option", client);
        } else {
            strcopy(disableLabel, sizeof(disableLabel), "Disable bot");
        }
        char disableInfo[8];
        IntToString(PVB_VOTE_DISABLE, disableInfo, sizeof(disableInfo));
        menu.AddItem(disableInfo, disableLabel);
    }

    // Exit button lets a player abstain from the vote. Cancel-as-abstain is
    // counted toward the early-resolve check so a solo player hitting Exit
    // doesn't leave the 20s timer running on nothing.
    menu.ExitButton = true;
    menu.Display(client, 20);
}

public int MenuHandler_ClassVote(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        if (ClassVoted[param1] != -1) return 0;

        char info[8];
        menu.GetItem(param2, info, sizeof(info));
        int type = StringToInt(info);

        // Clamp: valid type (0..NumBotTypes-1), or PVB_VOTE_DISABLE (-1).
        // Disable votes are tallied in ClassVotes[NumBotTypes] — the slot
        // just past the last real type. MAX_BOT_TYPES leaves room for it.
        int voteSlot;
        if (type == PVB_VOTE_DISABLE) {
            voteSlot = NumBotTypes;  // dedicated "disable" tally slot
        } else {
            if (type < 0 || type >= NumBotTypes) type = 0;
            voteSlot = type;
        }

        ClassVoted[param1] = voteSlot;
        ClassVotes[voteSlot]++;

        char typeName[32];
        if (type == PVB_VOTE_DISABLE) {
            if (TranslationPhraseExists("PvB_Menu_Vote_Disable_Option")) {
                FormatEx(typeName, sizeof(typeName), "%T", "PvB_Menu_Vote_Disable_Option", LANG_SERVER);
            } else {
                strcopy(typeName, sizeof(typeName), "Disable bot");
            }
        } else {
            GetBotTypeNameSafe(type, typeName, sizeof(typeName));
        }
        CPrintToChatAll("%t", "PvB_ClassVote_Voted", param1, typeName);

        // Early-resolve: if every human in game has voted, skip the remaining
        // timer — no point waiting 20s when the result is already decided.
        // Count live non-fake clients directly (don't rely on CachedRealCount
        // which updates on a separate tick).
        int humans = 0, voted = 0;
        for (int i = 1; i <= MaxClients; i++) {
            if (!TFDB_IsRealHumanPlaying(i)) continue;  // specs don't vote
            humans++;
            if (ClassVoted[i] != -1) voted++;
        }
        if (voted >= humans && humans > 0) {
            delete ClassVoteTimer;
            ClassVoteTimer = null;
            ResolveClassVote();
        }
    }
    else if (action == MenuAction_Cancel) {
        // Client hit Exit on the vote menu. Count them as abstained (-2) so
        // early-resolve doesn't wait 20s for a client who has opted out.
        // -2 is distinct from -1 (never voted) so they can't re-open + vote.
        if (param1 >= 1 && param1 <= MaxClients && ClassVoted[param1] == -1) {
            ClassVoted[param1] = -2;
            // Guard the translation lookup — same reason as PvB_Menu_Vote_Disable_Option,
            // stale global phrase cache could throw. See sourcemod-practices/translations.md.
            if (TranslationPhraseExists("PvB_ClassVote_Abstained")) {
                CPrintToChatAll("%t", "PvB_ClassVote_Abstained", param1);
            }

            // Same early-resolve check as MenuAction_Select — if every human
            // has either voted or abstained, wrap the vote now.
            int humans = 0, done = 0;
            for (int i = 1; i <= MaxClients; i++) {
                if (!TFDB_IsRealHuman(i)) continue;
                humans++;
                if (ClassVoted[i] != -1) done++;
            }
            if (done >= humans && humans > 0) {
                delete ClassVoteTimer;
                ClassVoteTimer = null;
                ResolveClassVote();
            }
        }
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

public Action Timer_EndClassVote(Handle timer) {
    ClassVoteTimer = null;
    ResolveClassVote();
    return Plugin_Stop;
}

void ResolveClassVote() {
    ClassVoteActive = false;

    // Ballot slots 0..NumBotTypes-1 = each bot type; slot NumBotTypes = "Disable bot".
    int totalSlots = NumBotTypes + 1;

    int maxVotes = 0;
    for (int i = 0; i < totalSlots; i++) {
        if (ClassVotes[i] > maxVotes) {
            maxVotes = ClassVotes[i];
        }
    }

    if (maxVotes == 0) {
        // No one voted — keep current state. If bot wasn't on, don't enable.
        CPrintToChatAll("%t", "PvB_ClassVote_NoVotes");
        if (!BotEnabled) LoadBotTypeSettings(CfgBotType);
        // Don't call EnablePvB() in no-vote case — silent cancel.
        return;
    }

    // Find tied winners, pick one at random.
    int tied[MAX_BOT_TYPES + 1];
    int tiedCount = 0;
    for (int i = 0; i < totalSlots; i++) {
        if (ClassVotes[i] == maxVotes) {
            tied[tiedCount++] = i;
        }
    }
    int winnerSlot = tied[GetRandomInt(0, tiedCount - 1)];

    // Slot NumBotTypes = "Disable bot" winner.
    if (winnerSlot == NumBotTypes) {
        char disableLabel[48];
        if (TranslationPhraseExists("PvB_Menu_Vote_Disable_Option")) {
            FormatEx(disableLabel, sizeof(disableLabel), "%T", "PvB_Menu_Vote_Disable_Option", LANG_SERVER);
        } else {
            strcopy(disableLabel, sizeof(disableLabel), "Disable bot");
        }
        CPrintToChatAll("%t", "PvB_ClassVote_Result", disableLabel, maxVotes);
        if (BotEnabled) DisablePvB();
        return;
    }

    // Bot-type winner — switch (or enable) to that type.
    char typeName[32];
    GetBotTypeNameSafe(winnerSlot, typeName, sizeof(typeName));

    if (!BotEnabled) {
        // Bot is OFF — vote enables it. Apply type immediately + spawn the bot.
        LoadBotTypeSettings(winnerSlot);
        CPrintToChatAll("%t", "PvB_ClassVote_Result", typeName, maxVotes);
        EnablePvB();
    } else if (winnerSlot == CfgBotType) {
        // Vote winner is already the active type — nothing to do, no respawn needed.
        CPrintToChatAll("%t", "PvB_ClassVote_Result", typeName, maxVotes);
    } else {
        // Hot-swap to a DIFFERENT type while bot is running. Defer to round end
        // so the current rally isn't interrupted mid-fight (mirrors the
        // PendingMaxPlayerDisable pattern). If round-state is between rounds
        // already, swap immediately.
        PendingHotSwapType = winnerSlot;
        if (GameRules_GetRoundState() == RoundState_RoundRunning) {
            if (TranslationPhraseExists("PvB_HotSwap_Deferred")) {
                CPrintToChatAll("%t", "PvB_HotSwap_Deferred", typeName);
            } else {
                CPrintToChatAll("[TFDB] Vote passed: bot will switch to %s at end of this round.", typeName);
            }
        } else {
            // Already between rounds — apply now, no rally to interrupt.
            ApplyHotSwap();
        }
    }
}

/**
 * Drain a pending bot hot-swap. Called from Event_RoundEnd. Kicks the current
 * bot, loads the new type's settings, spawns a fresh bot under the new type.
 * Deliberately NOT called mid-round so the active rally doesn't get a phantom
 * bot disappearance.
 */
void ApplyHotSwap()
{
    if (PendingHotSwapType < 0 || PendingHotSwapType >= NumBotTypes) {
        PendingHotSwapType = -1;
        return;
    }

    LoadBotTypeSettings(PendingHotSwapType);
    PendingHotSwapType = -1;

    // BotName was updated by LoadBotTypeSettings; the fresh tf_bot_add uses it.
    ServerCommand("tf_bot_kick all");
    ServerCommand("tf_bot_add 1 Pyro blue easy \"%s\"", BotName);
    BotNameDirty = true;
    ApplyBotTypeSettings();
}

// ============================================================================
// BOT INFO MENU (for players) - View only! No type changing.
// Players can see what's active, check stats, and start/stop votes.
// ============================================================================

void ShowBotTypeMenu(int client) {
    Menu menu = new Menu(MenuHandler_BotType);
    
    char typeName[32];
    GetBotTypeNameSafe(CfgBotType, typeName, sizeof(typeName));
    
    char title[128];
    if (BotEnabled) {
        FormatEx(title, sizeof(title), "%T", "PvB_Menu_Info_Active", client, typeName, RoundDeflects);
    } else {
        FormatEx(title, sizeof(title), "%T", "PvB_Menu_Info_Inactive", client);
    }
    menu.SetTitle(title);
    
    menu.AddItem("stats", "View Bot Stats");
    
    if (BotEnabled) {
        menu.AddItem("votedisable", "Vote to Disable Bot");
    } else {
        menu.AddItem("voteenable", "Vote to Enable Bot");
    }
    
    menu.ExitButton = true;
    menu.Display(client, 30);
}

public int MenuHandler_BotType(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[32];
        menu.GetItem(param2, info, sizeof(info));
        
        if (StrEqual(info, "stats")) {
            ShowBotStatsMenu(param1);
        }
        else if (StrEqual(info, "voteenable")) {
            if (!BotEnabled && !ClassVoteActive) {
                FakeClientCommandEx(param1, "sm_botvote");
            } else if (BotEnabled) {
                CPrintToChat(param1, "%t", "PvB_Bot_AlreadyActive");
            } else {
                CPrintToChat(param1, "%t", "PvB_Vote_InProgress");
            }
        }
        else if (StrEqual(info, "votedisable")) {
            if (BotEnabled && !ClassVoteActive) {
                FakeClientCommandEx(param1, "sm_botvote");
            } else if (!BotEnabled) {
                CPrintToChat(param1, "%t", "PvB_Bot_AlreadyDisabled");
            } else {
                CPrintToChat(param1, "%t", "PvB_Vote_InProgress");
            }
        }
    }
    else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

// ============================================================================
// GAME FRAME - Team management & auto enable/disable
// ============================================================================

public void OnGameFrame() {
    if (!CfgEnabled) return;

    static int tickCount = 0;
    tickCount++;
    
    bool isEvenTick = (tickCount % 2 == 0);

    if (BotEnabled) {
        if (isEvenTick) {
            if (TrainingMode) {
                ManageTrainingTeams();
            } else {
                ManageTeams();
            }
        }
    }

    if (MapChanged && BotEnabled && !TrainingMode) {
        DisablePvB();
        return;
    }

    int humans = CachedRealCount;

    if (humans == 0 && BotEnabled && !TrainingMode) {
        DisablePvB();
        CommandForced = false;
        CommandDisabled = false;
        return;
    }

    if (CachedFakeCount > 1 && !TrainingMode) {
        DisablePvB();
        return;
    }

    int minP = CfgMinPlayers;
    int maxP = CfgMaxPlayers;

    if (isEvenTick && minP != 0 && humans > 0 && humans <= minP && !BotEnabled && !CommandDisabled && !MapChanged && !TrainingMode) {
        // Don't auto-enable. Timer_CheckPlayerJoin will show the class pick menu
        // after the player fully loads. The menu handler enables the bot.
        // Without this block, nothing happens here - we just skip auto-enable.
    }

    // Auto-disable when humans EXCEED max_players. Strict > (not >=) so a
    // vote-confirmed bot at exactly max_players doesn't get kicked the next
    // tick. Override with `!pvb` admin toggle (sets CommandForced).
    //
    // Deferred to round end (queued via PendingMaxPlayerDisable). Triggering
    // mid-round was jarring — bot would vanish mid-rally when a 3rd player
    // joins. The flag is checked + drained in OnRoundWin / OnRoundEnd.
    if (isEvenTick && maxP != 0 && humans > 0 && humans > maxP && BotEnabled && !CommandForced && !MapChanged && !TrainingMode) {
        if (!PendingMaxPlayerDisable) {
            PendingMaxPlayerDisable = true;
            // Guarded translation lookup — see sourcemod-practices/translations.md.
            if (TranslationPhraseExists("PvB_TooManyPlayers_DeferredDisable")) {
                CPrintToChatAll("%t", "PvB_TooManyPlayers_DeferredDisable", humans, maxP);
            } else {
                CPrintToChatAll("[TFDB] %d players exceeds PvB max (%d). Bot will leave at end of this round.", humans, maxP);
            }
        }
    }
}

// Normal mode: keep bot on BLU, all humans on RED
void ManageTeams() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;

        if (IsFakeClient(i) && !IsClientReplay(i) && !IsClientSourceTV(i)) {
            if (GetClientTeam(i) != 3) {
                ChangeClientTeam(i, 3);
                // Only force-respawn the bot if the round is already running.
                // During arena pregame, TF2_RespawnPlayer silently fails and
                // leaves the bot stuck in death limbo — let the natural
                // arena_round_start respawn wave handle it instead.
                if (!IsPlayerAlive(i) && GameRules_GetRoundState() == RoundState_RoundRunning) {
                    TF2_RespawnPlayer(i);
                }
            }
            if (BotNameDirty) {
                SetClientInfo(i, "name", BotName);
            }
        }
        else if (BotEnabled) {
            // Gate on TEAM (not IsClientObserver). During arena pregame, humans
            // on BLU/RED are in freeze-cam "observer mode" but aren't on the
            // spec team — we must still force them to RED. IsClientObserver
            // would skip them incorrectly. Leave actual spec-team players alone.
            int humanTeam = GetClientTeam(i);
            if (humanTeam <= view_as<int>(TFTeam_Spectator)) continue;
            if (humanTeam != 2) {
                FakeClientCommand(i, "jointeam red");
                RequestFrame(Frame_PvBVerifyTeam, GetClientUserId(i));
            }
        }
    }
    BotNameDirty = false;
}

/**
 * Respawn the human after FakeClientCommand("jointeam red") has been fully
 * processed by the engine. Called via RequestFrame so the team change is
 * already applied when this runs — otherwise TF2_RespawnPlayer would fire
 * on the old BLU team.
 */
void Frame_PvBVerifyTeam(any userId) {
    int client = GetClientOfUserId(userId);
    if (client <= 0 || !IsClientInGame(client)) return;
    if (GetClientTeam(client) == view_as<int>(TFTeam_Red) && !IsPlayerAlive(client)) {
        TF2_RespawnPlayer(client);
    }
}

// Training mode: keep bots on their assigned teams, humans to spectator.
void ManageTrainingTeams() {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i)) continue;

        if (IsFakeClient(i) && !IsClientReplay(i) && !IsClientSourceTV(i)) {
            // Bots stay on their spawned team (encoded in name suffix)
            char name[MAX_NAME_LENGTH];
            GetClientName(i, name, sizeof(name));

            int targetTeam = 3; // Default BLU
            if (StrContains(name, "[RED]") != -1) {
                targetTeam = 2;
            }

            if (GetClientTeam(i) != targetTeam) {
                ChangeClientTeam(i, targetTeam);
                TF2_RespawnPlayer(i);
            }
        }
        // Real humans during training: no forced team — humans can freely join
        // RED or BLU to participate alongside the training bots, or spectate to
        // watch bot-vs-bot rounds. The listener also allows any team choice in
        // training mode.
    }
}

// ============================================================================
// EVENTS
// ============================================================================

// ============================================================================
// TEAM-JOIN PROTECTION
// ============================================================================
// Three layers:
//   1. AddCommandListener for "jointeam"/"autoteam" — intercepts user commands
//      BEFORE the engine processes them. FakeClientCommandEx reroutes.
//   2. player_team event hook (Pre) — catches engine-level team changes that
//      bypass the command (mp_autoteambalance, trigger_multiple, etc).
//      Schedules Timer_PvBForceTeam 0.1s later as fallback.
//   3. ManageTeams() reactive polling every 2 frames (pre-existing) — last
//      line of defense.
//
// Contract:
//   - Normal PvB (BotEnabled): humans on RED (team 2); bot on BLU (team 3)
//   - Training mode: humans on SPECTATOR (team 1); bots on both teams
//   - Neither mode active: no intervention, plugin is passive
// ============================================================================

public Action Listener_BlockPvBTeamCollision(int client, const char[] command, int argc)
{
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) return Plugin_Continue;
    if (!BotEnabled && !TrainingMode) return Plugin_Continue;
    if (IsFakeClient(client)) return Plugin_Continue;  // bots route through their own logic

    // autoteam: redirect to RED in normal PvB. In training, leave autoteam alone
    // (the engine picks a team; human can participate on either side).
    if (strcmp(command, "autoteam", false) == 0 && !TrainingMode) {
        FakeClientCommandEx(client, "jointeam red");
        return Plugin_Handled;
    }

    // jointeam <arg>: only restrict in normal PvB mode (human-vs-bot 1v1 requires
    // humans on RED, bot on BLU). Training mode allows humans on ANY team so a
    // real player can test/participate alongside the bot-vs-bot training.
    if (strcmp(command, "jointeam", false) == 0 && argc >= 1) {
        char arg[16];
        GetCmdArg(1, arg, sizeof(arg));

        bool shouldRedirect = false;
        if (!TrainingMode) {
            // Normal PvB: block blue/3/auto (allow red/2/spec/1)
            if (strcmp(arg, "blue", false) == 0 ||
                strcmp(arg, "3", false)    == 0 ||
                strcmp(arg, "auto", false) == 0) {
                shouldRedirect = true;
            }
        }
        // TrainingMode: no restrictions — humans can join any team.

        if (shouldRedirect) {
            FakeClientCommandEx(client, "jointeam red");
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Action Event_PlayerTeamChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || client > MaxClients) return Plugin_Continue;
    if (IsFakeClient(client)) return Plugin_Continue;

    int newTeam = event.GetInt("team");

    // Refresh playing-human count on EVERY transition — this is what makes
    // PvB auto-disable when the last human goes to spec. The OnGameFrame
    // disable check at line ~2114 reads CachedRealCount; without this update
    // it stays stale until next disconnect / admincheck.
    //
    // Hook is EventHookMode_Pre — GetClientTeam still returns the OLD team at
    // this moment. Defer to next frame so UpdateCachedCounts sees the real
    // post-transition state. (2026-04-26 fix: bot lingered when last human
    // went to spec because the count was sampled pre-transition.)
    RequestFrame(Frame_RefreshCachedCounts);

    // Solo-player bot menu: when a human transitions FROM spec TO a play team
    // and is the only one playing, offer them the bot menu. The
    // OnClientPutInServer path covers fresh connections / map changes; this
    // covers the spec→play case which has no putinserver event. (2026-04-28
    // regression fix: pre-clientcheck migration the menu fired because old
    // counts included spectators; now it needs an explicit trigger.)
    if (newTeam == view_as<int>(TFTeam_Red) || newTeam == view_as<int>(TFTeam_Blue)) {
        // Defer 1.5s — gives Frame_RefreshCachedCounts time to land AND lets
        // the player's spawn settle so the menu doesn't pop during freezecam.
        CreateTimer(1.5, Timer_CheckPlayerJoin, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }

    // The remaining BLU collision backstop only matters in active PvB mode.
    if (!BotEnabled || TrainingMode) return Plugin_Continue;

    // Human on BLU is a collision → schedule force-to-RED backstop.
    // ManageTeams handles the steady-state, this covers the race where the
    // engine pre-empts ManageTeams (spawn points, arena queue, etc.).
    if (newTeam == view_as<int>(TFTeam_Blue)) {
        CreateTimer(0.1, Timer_PvBForceTeam, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }

    return Plugin_Continue;
}

// ============================================================================
// Natives — exposed for other subplugins to query PvB state before they
// activate conflicting modes (e.g. Guardian refuses to start during PvB).
// ============================================================================

public any Native_IsPvBActive(Handle plugin, int numParams)
{
    return BotEnabled && !TrainingMode;
}

public any Native_IsPvBTraining(Handle plugin, int numParams)
{
    return TrainingMode;
}

public Action Timer_PvBForceTeam(Handle timer, any userId)
{
    // Only normal PvB mode force-moves humans off BLU (bot-only team).
    // Training mode is permissive — humans can join any team to participate.
    if (!BotEnabled || TrainingMode) return Plugin_Stop;

    int client = GetClientOfUserId(userId);
    if (client <= 0 || !IsClientInGame(client) || IsFakeClient(client)) return Plugin_Stop;

    if (GetClientTeam(client) == view_as<int>(TFTeam_Blue)) {
        FakeClientCommand(client, "jointeam red");
        RequestFrame(Frame_PvBVerifyTeam, userId);
    }

    return Plugin_Stop;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    Deflects = 0;
    RoundDeflects = 0;
    for (int i = 1; i <= MaxClients; i++) RoundDeflectsBot[i] = 0;
    return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if (!BotEnabled) return Plugin_Continue;

    int winner = event.GetInt("team");

    if (winner == 3) {
        BotWins++;
    } else if (winner == 2) {
        BotLosses++;
    }

    DumpRoundTelemetry(winner);
    FlushBrainWrites();  // persist batched brain updates once per round

    // Persist opponent profiles for every connected human. SaveOpponentToDB
    // alone on OnClientDisconnect was insufficient — server crash or admin
    // map-change with players still on it = lost profile data. Round end is
    // the natural commit point for the bot/player tendency table. The save
    // path early-outs on zero-activity rows so this is cheap for fresh joins.
    for (int i = 1; i <= MaxClients; i++) {
        if (TFDB_IsRealHumanPlaying(i)) SaveOpponentToDB(i);
    }

    // League diversity tracking runs only in training mode, where both teams
    // are bots and a "type vs type" win means something. In normal PvB (humans
    // vs one bot class) the data is one-sided and not useful.
    if (TrainingMode) {
        TrackTypeOutcomes(winner);
        CheckDiversityAndFlagExploiter();
        RebalanceTrainingTypes();
    }

    // Drain the deferred "too many players" disable now — current rally has
    // ended, safe to kick the bot. OnGameFrame queues this when humans > maxP
    // so the bot finishes the round before disappearing.
    if (PendingMaxPlayerDisable && !TrainingMode) {
        PendingMaxPlayerDisable = false;
        // Re-check the condition — humans may have left during the round.
        if (CachedRealCount > CfgMaxPlayers && !CommandForced) {
            DisablePvB();
            CommandDisabled = false;
        }
    }

    // Drain pending hot-swap (vote-driven type change). Doing this AFTER the
    // disable check above means a hot-swap that was queued just before a
    // max-player overflow won't try to swap a bot that's about to be kicked.
    if (PendingHotSwapType >= 0 && BotEnabled && !TrainingMode) {
        ApplyHotSwap();
    } else {
        PendingHotSwapType = -1;  // bot got disabled before the swap could fire
    }

    return Plugin_Continue;
}

// Credit each bot type that appeared this round with a match; credit wins to
// the types that were on the winning team. One match = one round.
void TrackTypeOutcomes(int winner) {
    // Collect per-team type-presence: did any bot of type t play on team T?
    bool present[MAX_BOT_TYPES];
    bool wonThisRound[MAX_BOT_TYPES];

    for (int i = 1; i <= MaxClients; i++) {
        if (!TFDB_IsLiveBot(i)) continue;
        int bt = GetEffectiveBotType(i);
        if (bt < 0 || bt >= NumBotTypes) continue;
        present[bt] = true;
        if (GetClientTeam(i) == winner) wonThisRound[bt] = true;
    }

    for (int t = 0; t < NumBotTypes; t++) {
        if (present[t]) TypeMatches[t]++;
        if (wonThisRound[t]) TypeWins[t]++;
    }
}

// Detect monoculture. A type that wins >65% of its last N matches (after at
// least 8 matches) is flagged as dominant; next round, one bot of that type
// gets re-keyed to an under-represented type.
void CheckDiversityAndFlagExploiter() {
    int bestType = -1;
    float bestRate = 0.0;

    for (int t = 0; t < NumBotTypes; t++) {
        if (TypeMatches[t] < DIVERSITY_MIN_MATCHES) continue;
        float rate = float(TypeWins[t]) / float(TypeMatches[t]);
        if (rate > bestRate) {
            bestRate = rate;
            bestType = t;
        }
    }

    if (bestType >= 0 && bestRate >= DIVERSITY_WIN_THRESHOLD) {
        if (ExploiterTargetType != bestType) {
            LogMessage("[PvB-LEAGUE] Dominance detected: type %d (%s) at %.1f%% win rate over %d matches. Flagging exploiter spawn.",
                bestType, BotClassKey[bestType], bestRate * 100.0, TypeMatches[bestType]);
        }
        ExploiterTargetType = bestType;
    } else {
        ExploiterTargetType = -1;
    }
}

// Pick the type with the FEWEST session matches as the "underdog" — it needs
// the reps and is least likely to already have a hard counter in the policy
// tables. If all types have equal matches (e.g., first few rounds), default
// to a random non-dominant pick.
int PickUnderdogType(int excludeType) {
    int bestType = -1;
    int minMatches = 999999;
    for (int t = 0; t < NumBotTypes; t++) {
        if (t == excludeType) continue;
        if (ClassIsStatueLike[t]) continue;  // statues make bad exploiters
        if (TypeMatches[t] < minMatches) {
            minMatches = TypeMatches[t];
            bestType = t;
        }
    }
    if (bestType < 0) {
        // Fallback: random non-dominant
        int attempts = 0;
        do {
            bestType = GetRandomInt(0, NumBotTypes - 1);
            attempts++;
        } while ((bestType == excludeType || ClassIsStatueLike[bestType]) && attempts < 8);
    }
    return bestType;
}

// When an exploiter is flagged, convert one dominant-type bot's effective type
// to the underdog. The bot name stays the same (it's cosmetic); only the
// brain-routing type changes. Done at round end so next round's decisions
// already use the new type.
void RebalanceTrainingTypes() {
    if (ExploiterTargetType < 0) return;

    int underdog = PickUnderdogType(ExploiterTargetType);
    if (underdog < 0 || underdog == ExploiterTargetType) return;

    // Convert ONE bot of the dominant type to the underdog. Prefer a bot that
    // wasn't on the losing team (so we're taking from the "stronger" side).
    int candidate = -1;
    for (int i = 1; i <= MaxClients; i++) {
        if (!TFDB_IsLiveBot(i)) continue;
        if (TrainingBotType[i] != ExploiterTargetType) continue;
        candidate = i;
        break;  // first match is fine; randomness comes from turn-order
    }

    if (candidate > 0) {
        TrainingBotType[candidate] = underdog;
        char botName[MAX_NAME_LENGTH];
        GetClientName(candidate, botName, sizeof(botName));
        LogMessage("[PvB-LEAGUE] Exploiter spawned: bot=\"%s\" type %d (%s) -> %d (%s) to counter dominance.",
            botName,
            ExploiterTargetType, BotClassKey[ExploiterTargetType],
            underdog, BotClassKey[underdog]);
    }

    // Clear the flag so we don't keep converting the same slot every round;
    // if the type remains dominant next round, the check will flag it again.
    ExploiterTargetType = -1;
}

// ============================================================================
// TELEMETRY
// Dumps one structured log line per active bot at round end so you can track
// whether learning is converging (deflects climbing, drift stabilizing) or
// thrashing (reaction drift flipping sign every round, deflects flat).
// Parseable format: grep "PVB-TEL" addons/sourcemod/logs/L*.log
// ============================================================================
void DumpRoundTelemetry(int winner) {
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));

    int activeBots = 0;
    int totalBotDeflects = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (!TFDB_IsLiveBot(i)) continue;

        int botType = GetEffectiveBotType(i);
        if (botType < 0 || botType >= NumBotTypes) continue;

        char botName[MAX_NAME_LENGTH];
        GetClientName(i, botName, sizeof(botName));

        int team = GetClientTeam(i);
        int defl = RoundDeflectsBot[i];
        int totalDefl = ConfirmedDeflects[i];
        float rxMinDelta = ReactMinDelta[botType];
        float rxMaxDelta = ReactMaxDelta[botType];

        LogMessage("[PVB-TEL] map=%s mode=%s winner=%d team=%d bot=\"%s\" class=%s roundDeflects=%d totalDeflects=%d rxMinDelta=%.3f rxMaxDelta=%.3f",
            mapName,
            TrainingMode ? "training" : "normal",
            winner,
            team,
            botName,
            BotClassKey[botType],
            defl,
            totalDefl,
            rxMinDelta,
            rxMaxDelta);

        activeBots++;
        totalBotDeflects += defl;
    }

    // Global round summary: heatmap coverage + opponent profile count
    int heatmapCells = (HeatmapCells != null) ? HeatmapCells.Size : 0;
    int opProfileCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (OpProfileLoaded[i]) opProfileCount++;
    }

    LogMessage("[PVB-TEL-SUM] map=%s mode=%s winner=%d bots=%d totalDeflects=%d heatmapCells=%d opProfiles=%d botWins=%d botLosses=%d",
        mapName,
        TrainingMode ? "training" : "normal",
        winner,
        activeBots,
        totalBotDeflects,
        heatmapCells,
        opProfileCount,
        BotWins,
        BotLosses);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && client <= MaxClients) {
        ResetCombatState(client);
    }
    return Plugin_Continue;
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
    char sNetworkID[64];
    event.GetString("networkid", sNetworkID, sizeof(sNetworkID));
    
    if (StrContains(sNetworkID, "BOT") == -1) {
        CreateTimer(2.0, Timer_ShowBotMenu, _, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    return Plugin_Continue;
}

public Action Timer_ShowBotMenu(Handle timer) {
    if (!BotEnabled && CfgEnabled && GetRealClientCount() == 1) {
        ShowBotTypeMenuToAll();
    }
    return Plugin_Stop;
}

void ShowBotTypeMenuToAll() {
    for (int i = 1; i <= MaxClients; i++) {
        if (TFDB_IsRealHuman(i)) {
            ShowBotTypeMenu(i);
            break;
        }
    }
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
    if (!CfgEnabled) return Plugin_Continue;

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (victim <= 0 || victim > MaxClients) return Plugin_Continue;

    // Bot died
    if (IsClientBot(victim)) {
        // In training mode don't force red win
        if (!TrainingMode) {
            ForceRedWin();
        }

        int botType = GetEffectiveBotType(victim);
        
        // Difficulty-scaled death penalty: dying during a high-speed rally
        // means the decisions were worse than dying at slow speed
        int deathPenalty = -5;
        if (LastDeflectSpeed > 3000.0) {
            deathPenalty = -3;  // Less penalty at extreme speed (death is expected)
        } else if (LastDeflectSpeed > 2000.0) {
            deathPenalty = -5;
        } else if (LastDeflectSpeed > 1000.0) {
            deathPenalty = -8;  // Should have survived this
        } else {
            deathPenalty = -12; // Dying at slow speed = big mistake
        }
        
        RewardWithAttribution(victim, deathPenalty, botType, REWARD_DEATH);
        TotalDeaths++;

        // TEAMMATE PROXIMITY LEARNING: if the bot died while near a teammate,
        // apply an extra movement penalty. The brain key includes tm0/tm1, so
        // this specifically teaches "when near teammate, my movement choice was
        // wrong" — over time bots learn to spread out on their own.
        float tmDeathDist = NearestTeammateDist(victim);
        if (tmDeathDist > 0.0 && tmDeathDist < 400.0) {
            AdjustBrain(LastMoveKey[victim], LastMoveChoice[victim], -8, DefMove, 5);
        }

        // Bot died = reaction time failed. Nudge slower so we don't over-commit.
        NudgeReactionTime(botType, false);

        // Bot death speech (use type-specific speech)
        if (CfgSpeech && attacker > 0 && attacker != victim) {
            SpeakTaunt(victim, attacker, TauntsBotDeath[botType]);
        }

        // Profile the attacker who killed us
        if (attacker > 0 && attacker <= MaxClients && !IsFakeClient(attacker)) {
            OpProfile[attacker].totalKills++;
        }
    }

    // Bot killed a human (or another bot in training)
    if (attacker > 0 && attacker <= MaxClients && attacker != victim && IsClientBot(attacker)) {
        int botType = GetEffectiveBotType(attacker);
        
        // Difficulty-scaled kill reward
        int killReward = CalcDifficultyReward(LastDeflectSpeed, Deflects) + 5;
        RewardWithAttribution(attacker, killReward, botType, REWARD_KILL);
        TotalKills++;

        // Player death speech
        if (CfgSpeech && !IsClientBot(victim)) {
            SpeakTaunt(attacker, victim, TauntsPlayerDeath[botType]);
        }
        
        // Profile the victim
        if (!IsFakeClient(victim)) {
            OpProfile[victim].totalDeaths++;

            // Record player-death into this class's heatmap at the death position
            float deathPos[3];
            GetClientAbsOrigin(victim, deathPos);
            HeatmapRecord(botType, deathPos, 1);
        }
    }

    return Plugin_Continue;
}

void SpeakTaunt(int speaker, int target, ArrayList list) {
    if (list == null || list.Length == 0) return;
    
    char speech[256];
    list.GetString(GetRandomInt(0, list.Length - 1), speech, sizeof(speech));

    char targetName[MAX_NAME_LENGTH];
    GetClientName(target, targetName, sizeof(targetName));
    
    // Sanitize player name to prevent command injection via quotes/semicolons
    ReplaceString(targetName, sizeof(targetName), "\"", "");
    ReplaceString(targetName, sizeof(targetName), ";", "");
    ReplaceString(targetName, sizeof(targetName), "\n", "");
    
    ReplaceString(speech, sizeof(speech), "#playername", targetName);

    char deflectStr[16];
    IntToString(Deflects, deflectStr, sizeof(deflectStr));
    ReplaceString(speech, sizeof(speech), "#deflects", deflectStr);
    
    char roundDeflectStr[16];
    IntToString(RoundDeflects, roundDeflectStr, sizeof(roundDeflectStr));
    ReplaceString(speech, sizeof(speech), "#rounddeflects", roundDeflectStr);
    
    // Sanitize final speech to prevent command injection
    ReplaceString(speech, sizeof(speech), "\"", "'");
    ReplaceString(speech, sizeof(speech), ";", ",");

    char cmd[512];
    FormatEx(cmd, sizeof(cmd), "say \"%s\"", speech);
    FakeClientCommandEx(speaker, cmd);
}

// ============================================================================
// ROCKET TRACKING
// ============================================================================

public void OnEntityCreated(int entity, const char[] classname) {
    if (StrEqual(classname, "tf_projectile_rocket") || StrEqual(classname, "tf_projectile_sentryrocket")) {
        Deflects = 0;
        CachedRocketRef = EntIndexToEntRef(entity);
        
        for (int i = 1; i <= MaxClients; i++) {
            MissedAirblast[i] = false;
            HasRocket[i] = false;
        }
    }
}

public void OnEntityDestroyed(int entity) {
    if (entity > 0 && EntIndexToEntRef(entity) == CachedRocketRef) {
        CachedRocketRef = INVALID_ENT_REFERENCE;
    }
}

void TrackRocketStats() {
    int rocket = GetCachedRocket();
    if (rocket == -1) return;

    // Prefer TFDB natives for accurate deflect count and speed
    #if defined _tfdb_included
    if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
        int rocketIdx = TFDB_FindRocketByEntity(rocket);
        if (rocketIdx != -1) {
            int deflects = TFDB_GetRocketDeflections(rocketIdx);
            if (deflects > Deflects) {
                Deflects = deflects;
            }
            return;
        }
    }
    #endif

    // Fallback: read from entity props
    int deflects = GetEntProp(rocket, Prop_Send, "m_iDeflected") - 1;
    if (deflects < 0) deflects = 0;
    if (deflects > Deflects) {
        Deflects = deflects;

        float vel[3];
        GetEntPropVector(rocket, Prop_Data, "m_vecAbsVelocity", vel);
    }
}

// ============================================================================
// TFDB DEFLECT FORWARD - Fires when a rocket is ACTUALLY deflected.
// This is the authoritative deflect counter, not the airblast button press.
// Also profiles the opponent who deflected for adaptive learning.
// ============================================================================

#if defined _tfdb_included
public void TFDB_OnRocketDeflect(int iIndex, int iEntity, int iOwner) {
    if (!BotEnabled && !TrainingMode) return;
    
    // Get rocket speed at moment of deflect for difficulty scaling
    float rocketSpeed = 800.0;
    if (TFDBAvailable) {
        rocketSpeed = TFDB_GetRocketSpeed(iIndex);
        Deflects = TFDB_GetRocketDeflections(iIndex);
    }
    LastDeflectSpeed = rocketSpeed;
    
    // If a BOT deflected, count it as confirmed
    if (iOwner > 0 && iOwner <= MaxClients && IsClientInGame(iOwner) && IsClientBot(iOwner)) {
        ConfirmedDeflects[iOwner]++;
        RoundDeflectsBot[iOwner]++;
        TotalDeflects++;
        RoundDeflects++;
        
        // Difficulty-scaled reinforcement: deflecting a fast rocket is worth more
        int botType = GetEffectiveBotType(iOwner);
        int reward = CalcDifficultyReward(rocketSpeed, Deflects);
        
        PenalizeProximityOnDeflect(iOwner, botType);
        RewardWithAttribution(iOwner, reward, botType, REWARD_DEFLECT);

        // Successful deflect = reaction window worked. Nudge faster.
        NudgeReactionTime(botType, true);
    }

    // If a HUMAN deflected, profile their behavior + record heatmap sample
    if (iOwner > 0 && iOwner <= MaxClients && IsClientInGame(iOwner) && !IsFakeClient(iOwner)) {
        ProfileOpponentDeflect(iOwner, rocketSpeed);

        // Heatmap: player survived here, against whichever class is currently active
        float playerPos[3];
        GetClientAbsOrigin(iOwner, playerPos);
        HeatmapRecord(CfgBotType, playerPos, 0);
    }
}
#endif

// Calculate reward based on difficulty (speed + deflect count)
// Slow easy deflect = +3, fast hard deflect = +12
int CalcDifficultyReward(float speed, int deflects) {
    int reward = 3; // Base reward
    
    if (speed > 3000.0) {
        reward = 12;  // Extreme speed
    } else if (speed > 2200.0) {
        reward = 8;   // High speed
    } else if (speed > 1500.0) {
        reward = 5;   // Medium speed
    }
    
    // Bonus for sustained rallies
    if (deflects > 50) {
        reward += 3;
    } else if (deflects > 20) {
        reward += 1;
    }
    
    return reward;
}

// ============================================================================
// OPPONENT PROFILING - Track how each human player behaves
// Called every frame for live opponents, and on deflect events.
// This data is used to modulate bot decisions.
// ============================================================================

void ProfileOpponentDeflect(int client, float speed) {
    // Track their deflect tendency
    OpProfile[client].totalDeflects++;
    
    // Running average of deflect speed
    float n = float(OpProfile[client].totalDeflects);
    OpProfile[client].avgDeflectSpeed = 
        OpProfile[client].avgDeflectSpeed * ((n - 1.0) / n) + speed * (1.0 / n);
    
    // Check what they were doing at deflect moment
    float vel[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
    float hSpeed = SquareRoot(vel[0] * vel[0] + vel[1] * vel[1]);
    
    if (hSpeed < 10.0) {
        OpProfile[client].stoodStillCount++;
    } else if (hSpeed > 200.0) {
        // Check strafe direction relative to their facing
        float eyeAngles[3];
        GetClientEyeAngles(client, eyeAngles);
        float moveYaw = RadToDeg(ArcTangent2(vel[1], vel[0]));
        float diff = moveYaw - eyeAngles[1];
        if (diff > 180.0) diff -= 360.0;
        if (diff < -180.0) diff += 360.0;
        
        if (diff > 45.0 && diff < 135.0) {
            OpProfile[client].strafeLeftCount++;
        } else if (diff < -45.0 && diff > -135.0) {
            OpProfile[client].strafeRightCount++;
        }
    }
    
    // Check if they jumped or crouched
    int flags = GetEntityFlags(client);
    if (!(flags & FL_ONGROUND)) {
        OpProfile[client].jumpedCount++;
    }
    if (flags & FL_DUCKING) {
        OpProfile[client].crouchedCount++;
    }
}

// Update opponent position/velocity profile (called from OnPlayerRunCmd for bots)
void ProfileOpponentLive(int enemy) {
    if (enemy <= 0 || enemy > MaxClients) return;
    if (!IsClientInGame(enemy) || !IsPlayerAlive(enemy)) return;
    if (IsFakeClient(enemy)) return;
    
    float now = GetEngineTime();
    // Throttle to every 0.2s to avoid per-frame overhead
    if (now - OpProfile[enemy].lastSeenTime < 0.2) return;
    OpProfile[enemy].lastSeenTime = now;
    
    GetClientAbsOrigin(enemy, OpProfile[enemy].lastSeenPos);
    GetEntPropVector(enemy, Prop_Data, "m_vecVelocity", OpProfile[enemy].lastSeenVel);
    
    // Track CQC tendencies by checking if they're approaching bots
    float hSpeed = SquareRoot(
        OpProfile[enemy].lastSeenVel[0] * OpProfile[enemy].lastSeenVel[0] + 
        OpProfile[enemy].lastSeenVel[1] * OpProfile[enemy].lastSeenVel[1]);
    
    if (hSpeed > 50.0) {
        // Find closest bot to this enemy
        int closestBot = -1;
        float closestDist = 999999.0;
        for (int i = 1; i <= MaxClients; i++) {
            if (i == enemy || !IsClientInGame(i) || !IsPlayerAlive(i)) continue;
            if (!IsClientBot(i)) continue;
            if (GetClientTeam(i) == GetClientTeam(enemy)) continue;
            
            float bPos[3];
            GetClientAbsOrigin(i, bPos);
            float d = GetVectorDistance(OpProfile[enemy].lastSeenPos, bPos);
            if (d < closestDist) {
                closestDist = d;
                closestBot = i;
            }
        }
        
        if (closestBot > 0 && closestDist < 800.0) {
            // Are they moving toward or away from the bot?
            float bPos[3];
            GetClientAbsOrigin(closestBot, bPos);
            float toBot[3];
            SubtractVectors(bPos, OpProfile[enemy].lastSeenPos, toBot);
            NormalizeVector(toBot, toBot);
            float velNorm[3];
            velNorm[0] = OpProfile[enemy].lastSeenVel[0];
            velNorm[1] = OpProfile[enemy].lastSeenVel[1];
            velNorm[2] = 0.0;
            NormalizeVector(velNorm, velNorm);
            
            float dot = GetVectorDotProduct(toBot, velNorm);
            if (dot > 0.5) {
                OpProfile[enemy].cqcApproachCount++;
            } else if (dot < -0.5) {
                OpProfile[enemy].cqcRetreatCount++;
            }
        }
    }
}

// Get opponent's dominant tendency (for aim offset decisions)
// Returns: 0=unknown, 1=strafe-left-heavy, 2=strafe-right-heavy, 3=statue, 4=aggressive-cqc
int GetOpponentTendency(int enemy) {
    if (enemy <= 0 || enemy > MaxClients) return 0;
    
    int total = OpProfile[enemy].strafeLeftCount + OpProfile[enemy].strafeRightCount + 
                OpProfile[enemy].stoodStillCount;
    if (total < 5) return 0; // Not enough data
    
    // Check dominant behavior
    if (OpProfile[enemy].stoodStillCount > total / 2) return 3; // Statue player
    if (OpProfile[enemy].strafeLeftCount > OpProfile[enemy].strafeRightCount * 2) return 1;
    if (OpProfile[enemy].strafeRightCount > OpProfile[enemy].strafeLeftCount * 2) return 2;
    
    int cqcTotal = OpProfile[enemy].cqcApproachCount + OpProfile[enemy].cqcRetreatCount;
    if (cqcTotal > 5 && OpProfile[enemy].cqcApproachCount > OpProfile[enemy].cqcRetreatCount * 2) return 4;
    
    return 0;
}

int GetCachedRocket() {
    if (CachedRocketRef == INVALID_ENT_REFERENCE) return -1;
    int entity = EntRefToEntIndex(CachedRocketRef);
    if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity)) {
        CachedRocketRef = INVALID_ENT_REFERENCE;
        return -1;
    }
    return entity;
}

// Per-client rocket finder. Priorities:
// 1. Rocket targeting THIS client (highest priority — must airblast)
// 2. Rocket flying TOWARD this client within threat range (dodge/avoid)
// 3. Fallback to global cached rocket if TFDB not available
// Scans are throttled to every 0.1s per client to avoid perf issues.
int GetCachedRocketForClient(int client) {
    float engineTime = GetEngineTime();

    // Return cached result if still fresh
    if (engineTime < NextRocketScan[client]) {
        int cached = ClientRocketRef[client];
        if (cached != INVALID_ENT_REFERENCE) {
            int ent = EntRefToEntIndex(cached);
            if (ent != INVALID_ENT_REFERENCE && IsValidEntity(ent))
                return ent;
            ClientRocketRef[client] = INVALID_ENT_REFERENCE;
        }
        return -1;
    }
    NextRocketScan[client] = engineTime + 0.1;

    #if defined _tfdb_included
    if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
        float eyePos[3];
        GetClientEyePosition(client, eyePos);

        int bestEntity = -1;
        float bestDist = 999999.0;
        bool bestIsTargeted = false;

        int rocketCount = TFDB_GetRocketCount();
        for (int i = 0; i < rocketCount; i++) {
            if (!TFDB_IsValidRocket(i)) continue;
            int ent = TFDB_GetRocketEntity(i);
            if (ent <= 0 || !IsValidEntity(ent)) continue;

            float rPos[3];
            GetEntPropVector(ent, Prop_Data, "m_vecOrigin", rPos);
            float dist = GetVectorDistance(eyePos, rPos);

            int target = TFDB_GetRocketTarget(i);
            bool targeted = (target == client || target <= 0);

            // Targeted rockets always beat non-targeted
            if (targeted && !bestIsTargeted) {
                bestEntity = ent;
                bestDist = dist;
                bestIsTargeted = true;
            }
            else if (targeted == bestIsTargeted && dist < bestDist) {
                bestEntity = ent;
                bestDist = dist;
                bestIsTargeted = targeted;
            }
            // Non-targeted rocket: only consider if close and approaching
            else if (!targeted && !bestIsTargeted && dist < 600.0) {
                float rVel[3];
                GetEntPropVector(ent, Prop_Data, "m_vecAbsVelocity", rVel);
                float toBot[3];
                SubtractVectors(eyePos, rPos, toBot);
                NormalizeVector(toBot, toBot);
                float dot = GetVectorDotProduct(rVel, toBot);
                // Rocket is heading toward us
                if (dot > 200.0 && dist < bestDist) {
                    bestEntity = ent;
                    bestDist = dist;
                }
            }
        }

        if (bestEntity != -1) {
            ClientRocketRef[client] = EntIndexToEntRef(bestEntity);
            return bestEntity;
        }

        ClientRocketRef[client] = INVALID_ENT_REFERENCE;
        return -1;
    }
    #endif

    // Fallback: no TFDB — use global cached rocket
    int entity = GetCachedRocket();
    if (entity != -1) {
        ClientRocketRef[client] = EntIndexToEntRef(entity);
    } else {
        ClientRocketRef[client] = INVALID_ENT_REFERENCE;
    }
    return entity;
}

// Multi-rocket threat count.
// Counts how many rockets are both (a) close enough to matter and (b) moving
// toward this bot with closing velocity. Used by the movement layer to shift
// to defensive stance when multiple rockets converge (can't orbit safely,
// should hold position and focus on timing).
//
// Returns 0..N. Callers typically branch on >= 2 as "multi-threat."
// Cheap: O(rocket count) which is typically <= 4 in TFDB.
int CountIncomingThreats(int client) {
    if (!IsPlayerAlive(client)) return 0;

    float bPos[3];
    GetClientAbsOrigin(client, bPos);
    int count = 0;

#if defined _tfdb_included
    if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
        int rocketCount = TFDB_GetRocketCount();
        for (int i = 0; i < rocketCount; i++) {
            if (!TFDB_IsValidRocket(i)) continue;
            int ent = TFDB_GetRocketEntity(i);
            if (ent <= 0 || !IsValidEntity(ent)) continue;

            float rPos[3], rVel[3];
            GetEntPropVector(ent, Prop_Data, "m_vecOrigin",      rPos);
            GetEntPropVector(ent, Prop_Data, "m_vecAbsVelocity", rVel);

            float dist = GetVectorDistance(bPos, rPos);
            if (dist > 1800.0) continue;  // too far to threaten within reaction

            // Closing check: is the rocket moving toward the bot?
            float toBot[3];
            SubtractVectors(bPos, rPos, toBot);
            NormalizeVector(toBot, toBot);
            float dot = GetVectorDotProduct(rVel, toBot);
            if (dot > 200.0) count++;
        }
    }
#endif

    return count;
}

// Returns true if the given rocket entity is specifically targeting this client.
// Used to decide whether bot should airblast vs just dodge.
bool IsRocketTargetingClient(int entity, int client) {
    #if defined _tfdb_included
    if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
        int rocketIdx = TFDB_FindRocketByEntity(entity);
        if (rocketIdx != -1) {
            int target = TFDB_GetRocketTarget(rocketIdx);
            return (target == client || target <= 0);
        }
    }
    #endif
    return true; // If no TFDB, assume it's ours
}

// ============================================================================
// CORE BOT LOGIC - OnPlayerRunCmd
// ============================================================================

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
    if (!CfgEnabled || !IsPlayerAlive(client)) return Plugin_Continue;

    // Log human player data when debug is active — study real player behavior
    // to improve bot movesets. Same sample rate as bots for direct comparison.
    bool isBot = IsClientBot(client);
    if (DebugActive && !isBot && !IsClientReplay(client) && !IsClientSourceTV(client)) {
        PlayerDebugTick[client]++;
        if (PlayerDebugTick[client] >= DebugSampleRate) {
            PlayerDebugTick[client] = 0;
            DebugLogPlayerState(client, vel, angles, buttons);
        }
    }

    if (!((BotEnabled && isBot) || Allowed[client])) return Plugin_Continue;

    float engineTime = GetEngineTime();
    
    // Get effective bot type for this specific bot
    int botType = GetEffectiveBotType(client);

    if (isBot) TrackRocketStats();

    // Periodic shaping reward for bots. Runs every ~4s per bot so
    // the learning signal between sparse deflect/death events isn't zero.
    // Pro tip from RL literature: keep shaping rewards an order of magnitude
    // smaller than terminal rewards (deflect = +5..+20, shaping = ±1..±2).
    if (isBot && engineTime >= NextShapingReward[client]) {
        NextShapingReward[client] = engineTime + GetRandomFloat(3.5, 4.5);
        ApplyShapingReward(client, botType);
    }

    // Debug sampling: log bot state every N ticks
    if (DebugActive && isBot) {
        BotDebugTick[client]++;
        if (BotDebugTick[client] >= DebugSampleRate) {
            BotDebugTick[client] = 0;
            DebugLogBotState(client, vel, angles, "");
        }
    }

    float eyePos[3];
    GetClientEyePosition(client, eyePos);

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(activeWeapon)) return Plugin_Continue;

    // =====================================================================
    // MOVEMENT - Opponent-aware with multiple modes
    // STATUE TYPE: Always IDLE - stand still and focus on deflects
    // =====================================================================

    // STATUE-LIKE CLASS: skip ALL movement logic. Stand still. That's it.
    if (ClassIsStatueLike[botType]) {
        if (CurrentMoveMode[client] != MOVE_IDLE && DebugActive) {
            char det[96];
            FormatEx(det, sizeof(det), "ClassIsStatueLike=1 -> MOVE_IDLE (forced)");
            DebugLogDecision(client, "MoveMode", det);
        }
        CurrentMoveMode[client] = MOVE_IDLE;
    }

    // IDLE-ALWAYS (idle_chance >= 100 in config): permanent idle.
    // Functionally equivalent to statue_like but keyed off idle_chance so
    // users can convert any class into "always idle" without renaming it.
    // The mode-reroll block below is guarded on !CfgIdleAlways, so no
    // expiry-timer trickery is needed.
    if (CfgIdleAlways[botType]) {
        if (CurrentMoveMode[client] != MOVE_IDLE && DebugActive) {
            char det[96];
            FormatEx(det, sizeof(det), "CfgIdleAlways=1 (idle_chance>=100) -> MOVE_IDLE (forced)");
            DebugLogDecision(client, "MoveMode", det);
        }
        CurrentMoveMode[client] = MOVE_IDLE;
    }

    if (!ClassIsStatueLike[botType] && !CfgIdleAlways[botType] && engineTime > MoveModeEnd[client]) {
        float moveSpeed = 800.0;
        int moveRocket = GetCachedRocketForClient(client);
        if (moveRocket != -1) {
            float moveVel[3];
            GetEntPropVector(moveRocket, Prop_Data, "m_vecAbsVelocity", moveVel);
            moveSpeed = GetVectorLength(moveVel);
            if (moveSpeed < 100.0) moveSpeed = 800.0;
        }

        // HIGH DEFLECT SURVIVAL: at extreme speeds, override movement.
        // Prefers idle (80% roll) but falls back to WANDER for non-idle-capable
        // classes so the override still functions without an idle capability.
        else if (moveSpeed > 2800.0 || Deflects > 80) {
            bool wantIdle = CfgCanIdle[botType] && (GetRandomFloat(0.0, 100.0) < 80.0);
            CurrentMoveMode[client] = wantIdle ? MOVE_IDLE : MOVE_WANDER;
            MoveModeEnd[client] = engineTime + GetRandomFloat(1.0, 3.0);

            if (DebugActive) {
                char det[160];
                FormatEx(det, sizeof(det),
                    "HIGH_DEFLECT_OVERRIDE moveSpeed=%.0f Deflects=%d CfgCanIdle=%d roll<80? wantIdle=%d -> %s",
                    moveSpeed, Deflects, CfgCanIdle[botType] ? 1 : 0, wantIdle ? 1 : 0,
                    wantIdle ? "MOVE_IDLE" : "MOVE_WANDER");
                DebugLogDecision(client, "MoveMode", det);
            }
        } else {
            CurrentMoveMode[client] = DecideMovement(client, moveSpeed, botType);
        }
        
        if (MoveModeEnd[client] <= engineTime) {
            switch (CurrentMoveMode[client]) {
                case MOVE_IDLE: MoveModeEnd[client] = engineTime + GetRandomFloat(0.5, 2.5);
                case MOVE_APPROACH: MoveModeEnd[client] = engineTime + GetRandomFloat(2.0, 5.0);
                case MOVE_MIRROR: MoveModeEnd[client] = engineTime + GetRandomFloat(1.5, 4.0);
                case MOVE_CIRCLE: MoveModeEnd[client] = engineTime + GetRandomFloat(2.0, 5.0);
                default: MoveModeEnd[client] = engineTime + GetRandomFloat(2.0, 5.0);
            }
        }

        TargetEnemy[client] = FindClosestEnemy(client);
    }

    int enemy = TargetEnemy[client];
    bool hasEnemy = (enemy > 0 && enemy <= MaxClients && IsClientInGame(enemy) && IsPlayerAlive(enemy) && GetClientTeam(enemy) != GetClientTeam(client));

    // Profile opponent behavior for adaptive AI
    if (hasEnemy && isBot) {
        ProfileOpponentLive(enemy);
    }

    if (!hasEnemy && CurrentMoveMode[client] != MOVE_WANDER && CurrentMoveMode[client] != MOVE_IDLE) {
        CurrentMoveMode[client] = MOVE_WANDER;
    }

    float botPos[3];
    GetClientAbsOrigin(client, botPos);

    if (CurrentMoveMode[client] == MOVE_IDLE) {
        // === IDLE MODE - Force complete standstill ===
        // TF2's built-in bot AI may have already set vel/buttons before our hook.
        // We MUST explicitly zero everything to override the engine AI.
        vel[0] = 0.0;
        vel[1] = 0.0;
        vel[2] = 0.0;
        buttons &= ~IN_FORWARD;
        buttons &= ~IN_BACK;
        buttons &= ~IN_MOVELEFT;
        buttons &= ~IN_MOVERIGHT;
    }
    else if (!hasEnemy) {
        // No enemy: wander randomly — actually MOVE, not just pick a direction
        if (engineTime > NextDirChange[client]) {
            MoveYaw[client] = GetRandomFloat(-180.0, 180.0);
            NextDirChange[client] = engineTime + GetRandomFloat(1.5, 4.0);
        }
        // Apply wander velocity (statue bots don't wander)
        if (!ClassIsStatueLike[botType]) {
            float viewYaw = angles[1];
            float wanderRel = MoveYaw[client] - viewYaw;
            vel[0] = Cosine(DegToRad(wanderRel)) * 240.0;
            vel[1] = -Sine(DegToRad(wanderRel)) * 240.0;
            buttons |= IN_FORWARD;
        }
    }
    else {
        // === CONTINUOUS BLENDED MOVEMENT ===
        // Instead of picking one mode for 3 seconds, compute a blend of desires
        // every frame. This creates smooth, fluid, human-like movement.
        
        float enemyPos[3];
        GetClientAbsOrigin(enemy, enemyPos);
        float toEnemy[3];
        SubtractVectors(enemyPos, botPos, toEnemy);
        float enemyDist = GetVectorLength(toEnemy);
        float enemyYaw = RadToDeg(ArcTangent2(toEnemy[1], toEnemy[0]));
        
        // Recalculate blend weights periodically (not every frame - saves CPU)
        if (engineTime >= MoveBlendUpdate[client]) {
            MoveBlendUpdate[client] = engineTime + 0.3; // Update 3x/sec
            
            // Base desires from brain decision (the mode the brain picked)
            float bIdle = 0.0, bToward = 0.0, bCircle = 0.0, bAway = 0.0;
            
            switch (CurrentMoveMode[client]) {
                case MOVE_IDLE: bIdle = 0.8;
                case MOVE_APPROACH: bToward = 0.7;
                case MOVE_MIRROR: { bCircle = 0.4; bToward = 0.3; }
                case MOVE_CIRCLE: bCircle = 0.7;
                case MOVE_WANDER: { bCircle = 0.3; bToward = 0.2; }
            }
            
            // HARD CQC FLOOR: No bot can EVER go closer than this distance.
            // This prevents toxic face-hugging gameplay. Non-negotiable.
            // Entire CQC distance-aware block gated on CfgCanCqc — classes
            // without any cqc_* keys just walk/idle per the brain's choice
            // without distance gating.
            if (CfgCanCqc[botType] && enemyDist < CfgCqcFloorDist[botType]) {
                bAway = 1.0;   // Maximum retreat urgency
                bToward = 0.0; // Zero approach desire
                bCircle = 0.0; // Don't circle, just GET OUT
                bIdle = 0.0;
            }
            // Modulate by distance - back off if inside comfort zone
            else if (CfgCanCqc[botType] && enemyDist < CfgCqcRetreatDist[botType]) {
                bAway = 0.9;  // Strong retreat
                bToward = 0.0;
            } else if (CfgCanCqc[botType] && enemyDist < CfgCqcMinDist[botType]) {
                bAway += 0.4;
                bToward *= 0.3;
            } else if (CfgCanCqc[botType] && enemyDist > CfgCqcMaxDist[botType]) {
                bToward += 0.3;
                bAway *= 0.2;
            }

            // SAFETY CAP: Even if brain says approach, never let toward desire
            // push bot closer than the floor distance would allow.
            // Only enforced when the class has CQC capability — without CQC
            // keys the bot has no defined "floor" to defend.
            if (CfgCanCqc[botType] && enemyDist < CfgCqcFloorDist[botType] + 100.0) {
                // Within 100 units of floor - reduce approach aggressively
                bToward *= 0.1;
            }
            
            // Modulate by opponent profile
            int tendency = GetOpponentTendency(enemy);
            if (tendency == 4) {
                // Aggressive player coming at us - back off more
                bAway += 0.2;
            } else if (tendency == 3) {
                // Statue player - we can approach safely
                bToward += 0.15;
            }

            // Modulate by heatmap: avoid zones where this bot type dies often.
            // danger > 0.6 = players die here a lot (GOOD for bot, stay)
            // danger < 0.3 = players survive here (fine for bot too)
            // We check the BOT's own position: if the bot is standing in a
            // zone where deaths are high, that means rockets converge here —
            // the bot should move away to avoid crossfire.
            // Heatmap movement influence — skip in training mode because bots
            // generate their own death data and would flee the entire play area.
            if (CfgUseHeatmap && !ClassIsStatueLike[botType] && !TrainingMode) {
                float botDanger = HeatmapDangerAt(botType, botPos);
                // Only react to extreme danger (>0.8 = clear kill zone from real player data)
                if (botDanger > 0.8) {
                    bAway += 0.2;
                    bIdle *= 0.5;
                } else if (botDanger > 0.7) {
                    bCircle += 0.15;
                }
            }
            
            // Modulate by rocket state.
            // If rocket targets THIS bot: fast rockets -> prefer stillness.
            // If rocket targets someone else: stay put, don't crowd.
            int mRocket = GetCachedRocketForClient(client);
            if (mRocket != -1) {
                bool rocketTargetsMe = IsRocketTargetingClient(mRocket, client);
                if (rocketTargetsMe) {
                    float mVel[3];
                    GetEntPropVector(mRocket, Prop_Data, "m_vecAbsVelocity", mVel);
                    float mSpeed = GetVectorLength(mVel);
                    if (mSpeed > 2500.0) {
                        bIdle += 0.5;
                        bToward *= 0.3;
                        bCircle *= 0.3;
                    }
                } else {
                    // Not our rocket — don't rush toward it, but keep moving naturally.
                    // Players still strafe and move even when the rocket isn't theirs.
                    bToward *= 0.3;  // Reduce approach desire, don't add idle
                }
            }

            // Multi-rocket defensive stance.
            // When 2+ rockets are closing on this bot simultaneously, orbit
            // and approach become suicidal (back-phase of orbit = perpendicular
            // to one rocket but straight into the other). Force a defensive
            // blend weighted toward idle + retreat.
            int threats = CountIncomingThreats(client);
            if (threats >= 2) {
                bIdle  += 0.3;
                bAway  += 0.3;
                bToward *= 0.2;
                bCircle *= 0.2;
            }

            // Teammate awareness: strategic spacing is handled by the brain
            // (the tm0/tm1 dimension in the move key learns that clustering = death).
            // This is just a minimal physics guard to prevent walking THROUGH a
            // teammate — softens forward desire within 200u, nothing more.
            for (int t = 1; t <= MaxClients; t++) {
                if (t == client) continue;
                if (!IsClientInGame(t) || !IsFakeClient(t) || !IsPlayerAlive(t)) continue;
                if (GetClientTeam(t) != GetClientTeam(client)) continue;
                float tmPos[3];
                GetClientAbsOrigin(t, tmPos);
                float tmDist = GetVectorDistance(botPos, tmPos);
                if (tmDist < 200.0 && tmDist > 1.0) {
                    bToward *= 0.5;
                    break;
                }
            }
            
            // Store blended weights. Snap to idle/retreat immediately to prevent
            // residual forward drift; lerp other transitions for smoothness.
            if (bIdle > 0.6 || bAway > 0.7) {
                // Snap: idle or strong retreat — no lingering forward velocity
                MoveBlendIdle[client]   = bIdle;
                MoveBlendToward[client] = bToward;
                MoveBlendCircle[client] = bCircle;
                MoveBlendAway[client]   = bAway;
            } else {
                float lerpRate = 0.4;
                MoveBlendIdle[client]   += (bIdle - MoveBlendIdle[client]) * lerpRate;
                MoveBlendToward[client] += (bToward - MoveBlendToward[client]) * lerpRate;
                MoveBlendCircle[client] += (bCircle - MoveBlendCircle[client]) * lerpRate;
                MoveBlendAway[client]   += (bAway - MoveBlendAway[client]) * lerpRate;
            }
        }
        
        // Compute final yaw from blended desires.
        // IMPORTANT: Idle weight is NOT a direction — it produces no bx/by component.
        // Only directional weights (toward/circle/away) determine movement direction
        // and strength. Idle weight acts as a gate: high idle = stop moving.
        float dirWeight = MoveBlendToward[client] + MoveBlendCircle[client] +
                          MoveBlendAway[client];

        if (dirWeight <= 0.0 || MoveBlendIdle[client] > 0.85) {
            // No directional desire, or overwhelmingly idle — zero velocity.
            vel[0] = 0.0; vel[1] = 0.0;
        } else {
            // Compute yaw components
            float awayYaw = enemyYaw + 180.0;
            if (awayYaw > 180.0) awayYaw -= 360.0;

            float circleDir = (OrbitDir[client] > 0.0) ? 90.0 : -90.0;
            float circleYaw = enemyYaw + circleDir;

            // Blend: weighted average of direction angles (handle wraparound via sin/cos)
            float bx = 0.0, by = 0.0;
            bx += Cosine(DegToRad(enemyYaw)) * MoveBlendToward[client];
            by += Sine(DegToRad(enemyYaw)) * MoveBlendToward[client];
            bx += Cosine(DegToRad(awayYaw)) * MoveBlendAway[client];
            by += Sine(DegToRad(awayYaw)) * MoveBlendAway[client];
            bx += Cosine(DegToRad(circleYaw)) * MoveBlendCircle[client];
            by += Sine(DegToRad(circleYaw)) * MoveBlendCircle[client];

            MoveYaw[client] = RadToDeg(ArcTangent2(by, bx));

            // Scale speed by directional coherence: single strong direction = full speed,
            // conflicting directions = slower. Divide by dirWeight (NOT totalWeight) so
            // idle blend doesn't dilute movement. Then scale down by idle proportion so
            // partially-idle bots move slower without stopping completely.
            float moveStrength = SquareRoot(bx * bx + by * by) / dirWeight;
            if (moveStrength > 1.0) moveStrength = 1.0;

            // Idle damping: when idle blend is significant, reduce speed proportionally.
            // At MoveBlendIdle=0.5, speed is halved. At 0.85+, zeroed above.
            float idleRatio = MoveBlendIdle[client] / (MoveBlendIdle[client] + dirWeight);
            moveStrength *= (1.0 - idleRatio);

            // Apply movement
            float viewYaw = angles[1];
            float moveRelative = MoveYaw[client] - viewYaw;
            vel[0] = Cosine(DegToRad(moveRelative)) * 400.0 * moveStrength;
            vel[1] = -Sine(DegToRad(moveRelative)) * 400.0 * moveStrength;
            buttons |= IN_FORWARD;
        }
    }

    // STATUE SAFETY NET: Regardless of what happened above, statues NEVER move.
    // This catches any velocity leak from any code path (dodge, blend, wander, etc.)
    if (ClassIsStatueLike[botType]) {
        vel[0] = 0.0; vel[1] = 0.0; vel[2] = 0.0;
        buttons &= ~IN_FORWARD;
        buttons &= ~IN_BACK;
        buttons &= ~IN_MOVELEFT;
        buttons &= ~IN_MOVERIGHT;
    }

    // Wall check and pit avoidance (skip during IDLE or when blend chose idle)
    if (CurrentMoveMode[client] != MOVE_IDLE && (vel[0] != 0.0 || vel[1] != 0.0)) {
        if (engineTime >= NextWallCheck[client]) {
            NextWallCheck[client] = engineTime + 0.08;

            float startPos[3], fwd[3], endPos[3];
            GetClientEyePosition(client, startPos);
            float feetPos[3];
            GetClientAbsOrigin(client, feetPos);

            float walkAng[3];
            walkAng[1] = MoveYaw[client];
            GetAngleVectors(walkAng, fwd, NULL_VECTOR, NULL_VECTOR);

            endPos[0] = startPos[0] + (fwd[0] * 150.0);
            endPos[1] = startPos[1] + (fwd[1] * 150.0);
            endPos[2] = startPos[2];

            bool shouldReverse = false;

            TR_TraceRayFilter(startPos, endPos, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
            if (TR_GetFraction() < 1.0) {
                shouldReverse = true;
            }
            
            if (!shouldReverse) {
                float pitStart[3], pitEnd[3];
                pitStart[0] = feetPos[0] + (fwd[0] * 120.0);
                pitStart[1] = feetPos[1] + (fwd[1] * 120.0);
                pitStart[2] = feetPos[2] + 10.0;
                pitEnd[0] = pitStart[0];
                pitEnd[1] = pitStart[1];
                pitEnd[2] = pitStart[2] - 250.0;
                TR_TraceRayFilter(pitStart, pitEnd, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
                if (TR_GetFraction() == 1.0) {
                    shouldReverse = true;
                }
            }
            
            if (!shouldReverse) {
                float groundEnd[3];
                groundEnd[0] = feetPos[0];
                groundEnd[1] = feetPos[1];
                groundEnd[2] = feetPos[2] - 80.0;
                TR_TraceRayFilter(feetPos, groundEnd, MASK_PLAYERSOLID, RayType_EndPoint, TraceFilter_NoPlayers, client);
                if (TR_GetFraction() == 1.0) {
                    shouldReverse = true;
                }
            }

            if (shouldReverse) {
                // Reverse direction and re-apply vel from corrected yaw
                MoveYaw[client] += 180.0;
                if (MoveYaw[client] > 180.0) MoveYaw[client] -= 360.0;
                
                float viewYaw = angles[1];
                float moveRelative = MoveYaw[client] - viewYaw;
                vel[0] = Cosine(DegToRad(moveRelative)) * 400.0;
                vel[1] = -Sine(DegToRad(moveRelative)) * 400.0;
                buttons |= IN_FORWARD;
            }
        }
    }

    // =====================================================================
    // EVASION: Jump/Crouch over low rockets
    // If rocket is low (below eye level) and coming toward us, 
    // we can jump over it or crouch to change our hitbox
    // =====================================================================
    
    if (Evading[client]) {
        if (engineTime < EvadeEnd[client]) {
            if (CurrentEvadeAction[client] == EVADE_JUMP) {
                buttons |= IN_JUMP;
            } else if (CurrentEvadeAction[client] == EVADE_CROUCH) {
                buttons |= IN_DUCK;
            }
        } else {
            Evading[client] = false;
        }
    }
    
    // Check for evasion opportunity
    if (!Evading[client] && engineTime > NextEvadeCheck[client]) {
        NextEvadeCheck[client] = engineTime + 0.15;
        
        int evadeRocket = GetCachedRocketForClient(client);
        if (evadeRocket != -1) {
            float rPos[3];
            GetEntPropVector(evadeRocket, Prop_Data, "m_vecOrigin", rPos);
            float rVel[3];
            GetEntPropVector(evadeRocket, Prop_Data, "m_vecAbsVelocity", rVel);
            
            float dist = GetVectorDistance(eyePos, rPos);
            
            // Only try evasion at moderate range, when rocket is approaching
            if (dist > 300.0 && dist < 800.0) {
                float toRocket[3];
                SubtractVectors(rPos, eyePos, toRocket);
                NormalizeVector(toRocket, toRocket);
                float dot = GetVectorDotProduct(rVel, toRocket);
                
                // Rocket is approaching us (negative dot = coming toward)
                if (dot < -200.0) {
                    // Check if rocket is LOW (below our feet or at feet level)
                    float rocketHeight = rPos[2] - botPos[2];
                    
                    if (rocketHeight < 20.0 && rocketHeight > -50.0) {
                        // Rocket is low enough to jump over!
                        EvadeAction evadeChoice = DecideEvasion(client, GetVectorLength(rVel), botType);
                        if (evadeChoice != EVADE_NONE) {
                            Evading[client] = true;
                            CurrentEvadeAction[client] = evadeChoice;
                            EvadeEnd[client] = engineTime + (evadeChoice == EVADE_JUMP ? 0.3 : 0.25);
                            DebugLogEvent(client, vel, angles, evadeChoice == EVADE_JUMP ? "evade_jump" : "evade_crouch");
                        }
                    }
                    else if (rocketHeight > 50.0 && rocketHeight < 120.0) {
                        // Rocket is high - crouch under it
                        EvadeAction evadeChoice = DecideEvasion(client, GetVectorLength(rVel), botType);
                        if (evadeChoice != EVADE_NONE) {
                            Evading[client] = true;
                            CurrentEvadeAction[client] = EVADE_CROUCH;
                            EvadeEnd[client] = engineTime + 0.25;
                            DebugLogEvent(client, vel, angles, "evade_crouch_high");
                        }
                    }
                }
            }
        }
    }

    // =====================================================================
    // POST-AIRBLAST TRICK
    // =====================================================================
    if (ApplyingTrick[client]) {
        if (engineTime < TrickEnd[client]) {
            float trickAngles[3];
            GetClientEyeAngles(client, trickAngles);
            ApplyTrick(trickAngles, Trick[client], engineTime);
            
            if (GetRandomFloat(0.0, 100.0) < CfgAngleRandomChance[botType]) {
                float arStrength = CfgAngleRandomStrength[botType];
                trickAngles[0] += GetRandomFloat(-arStrength, arStrength);
                trickAngles[1] += GetRandomFloat(-arStrength, arStrength);
            }
            
            ClampAngles(trickAngles);
            TeleportEntity(client, NULL_VECTOR, trickAngles, NULL_VECTOR);
            return Plugin_Changed;
        }
        ApplyingTrick[client] = false;
    }

    // =====================================================================
    // FIND CLOSEST INCOMING ROCKET
    // =====================================================================
    int bestRocket = GetCachedRocketForClient(client);
    float bestDist = 999999.0;

    // --- bestRocket cache (perf): resolve once per usercmd, reuse below ---
    // bestRocket is not reassigned after this point in OnPlayerRunCmd, so these
    // values stay valid for the rest of the function. Saves ~9 prop reads,
    // 4 IsRocketTargetingClient calls, and 3 TFDB_FindRocketByEntity calls.
    float rocketPosCache[3], rocketVelCache[3];
    float rocketSpeedCache = 0.0;
    int   rocketIdxCache       = -1;
    int   rocketTargetCache    = -1;
    bool  rocketTargetsMeCache = false;
    if (bestRocket > 0 && IsValidEntity(bestRocket)) {
        GetEntPropVector(bestRocket, Prop_Data, "m_vecOrigin",      rocketPosCache);
        GetEntPropVector(bestRocket, Prop_Data, "m_vecAbsVelocity", rocketVelCache);
        rocketSpeedCache = GetVectorLength(rocketVelCache);
        // Mirror IsRocketTargetingClient semantics: target==client or untargeted
        // counts as "targets me"; if TFDB isn't loaded, treat as ours (true).
        rocketTargetsMeCache = true;
        #if defined _tfdb_included
        if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
            rocketIdxCache = TFDB_FindRocketByEntity(bestRocket);
            if (rocketIdxCache >= 0) {
                rocketTargetCache = TFDB_GetRocketTarget(rocketIdxCache);
                rocketTargetsMeCache = (rocketTargetCache == client || rocketTargetCache <= 0);
            }
            // If rocketIdxCache == -1, the rocket isn't tracked by TFDB; the
            // original IsRocketTargetingClient returns true in that path too.
        }
        #endif
        bestDist = GetVectorDistance(eyePos, rocketPosCache);
    }

    // =====================================================================
    // NATURAL LOOK BEHAVIOR
    // =====================================================================
    
    if (bestRocket == -1) {
        if (CurrentLookState[client] == LOOK_PLAYER && engineTime < LookAtPlayerEnd[client]) {
            int targetPlayer = LastDeflectedPlayer[client];
            if (targetPlayer > 0 && targetPlayer <= MaxClients &&
                IsClientInGame(targetPlayer) && IsPlayerAlive(targetPlayer)) {
                float playerPos[3];
                GetClientEyePosition(targetPlayer, playerPos);

                float lookAngles[3];
                CalcAimAngles(eyePos, playerPos, lookAngles);
                SmoothAim(client, lookAngles, 0.15);

                // Don't freeze velocity — let movement code keep running.
                // The bot looks at the player while still moving naturally.
                return Plugin_Changed;
            }
        }
        
        if (CfgCanIdle[botType] && CurrentLookState[client] != LOOK_IDLE) {
            if (GetRandomFloat(0.0, 100.0) < CfgIdleChance[botType]) {
                CurrentLookState[client] = LOOK_IDLE;
                LookAtIdleEnd[client] = engineTime + CfgIdleDuration[botType];
            }
        }
        
        // Idle-always classes hold the look-idle state regardless of the
        // duration timer; normal classes expire per CfgIdleDuration.
        if (CurrentLookState[client] == LOOK_IDLE && (CfgIdleAlways[botType] || engineTime < LookAtIdleEnd[client])) {
            if (engineTime >= NextLookChange[client]) {
                NextLookChange[client] = engineTime + GetRandomFloat(0.5, 2.0);
                MoveYaw[client] = GetRandomFloat(-180.0, 180.0);
            }

            float idleTarget[3];
            idleTarget[0] = 0.0;
            idleTarget[1] = MoveYaw[client];
            idleTarget[2] = 0.0;
            SmoothAim(client, idleTarget, 0.08);

            // Fidget: players move ~22% of the time while idle. Small random
            // strafes and steps to look natural instead of standing perfectly still.
            if (!ClassIsStatueLike[botType] && GetRandomFloat(0.0, 100.0) < 25.0) {
                float fidgetYaw = angles[1] + GetRandomFloat(-90.0, 90.0);
                vel[0] = Cosine(DegToRad(fidgetYaw - angles[1])) * 150.0;
                vel[1] = -Sine(DegToRad(fidgetYaw - angles[1])) * 150.0;
            } else {
                vel[0] = 0.0; vel[1] = 0.0;
            }
            return Plugin_Changed;
        }
        
        if (CurrentLookState[client] == LOOK_IDLE && engineTime >= LookAtIdleEnd[client]) {
            CurrentLookState[client] = LOOK_ROCKET;
        }

        // No rocket active — stay in current look state (idle/player), don't force rocket
        return Plugin_Changed;
    }
    
    if (CurrentLookState[client] == LOOK_PLAYER && engineTime >= LookAtPlayerEnd[client]) {
        CurrentLookState[client] = LOOK_ROCKET;
    }

    if (bestDist < 400.0 && CurrentLookState[client] == LOOK_PLAYER) {
        CurrentLookState[client] = LOOK_ROCKET;
    }

    // Human-like awareness: players watch rockets even when not targeted — they
    // track them with peripheral vision (soft aim factor handled later).
    // Only drop to idle for very far, very non-threatening situations.
    bool rocketTargetsUs = rocketTargetsMeCache;
    if (rocketTargetsUs) {
        // Our rocket — always track it
        CurrentLookState[client] = LOOK_ROCKET;
    } else if (bestDist > 1200.0) {
        // Very far non-targeted rocket: only then go idle
        if (CurrentLookState[client] == LOOK_ROCKET) {
            CurrentLookState[client] = LOOK_IDLE;
            LookAtIdleEnd[client] = engineTime + GetRandomFloat(0.5, 1.5);
        }
    } else {
        // Non-targeted but within awareness range — keep tracking softly
        // (the aimFactor will be low at distance, creating peripheral awareness)
        if (CurrentLookState[client] == LOOK_IDLE && engineTime >= LookAtIdleEnd[client]) {
            CurrentLookState[client] = LOOK_ROCKET;
        }
    }

    // FIDGETING: When a rocket exists but doesn't target us, players still
    // move around — little strafes, steps, position adjustments. Without this,
    // bots stand perfectly still ~92% of the time between their own rockets.
    // Only fidgets when in LOOK_IDLE or when rocket is far and non-targeted.
    if (!rocketTargetsUs && !ClassIsStatueLike[botType] && bestDist > 500.0) {
        if (GetRandomFloat(0.0, 100.0) < 20.0) {
            float fidgetYaw = angles[1] + GetRandomFloat(-90.0, 90.0);
            float fidgetRel = fidgetYaw - angles[1];
            vel[0] += Cosine(DegToRad(fidgetRel)) * 130.0;
            vel[1] += -Sine(DegToRad(fidgetRel)) * 130.0;
        }
    }

    // Skip if we own this rocket
    #if defined _tfdb_included
    if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
        if (rocketIdxCache != -1 && TFDB_GetRocketOwner(rocketIdxCache) == client) {
            return Plugin_Changed;
        }
    }
    #endif

    // =====================================================================
    // NON-TARGETED ROCKET: DODGE only if it will pass very close
    // Uses closest-approach prediction to avoid dodging harmless rockets.
    // Blends dodge into existing movement instead of overriding it.
    // Statue bots don't dodge — standing still is their identity.
    // =====================================================================
    if (!rocketTargetsMeCache && !ClassIsStatueLike[botType]) {
        float rPos[3], rVel[3];
        rPos = rocketPosCache;
        rVel = rocketVelCache;

        // Predict closest approach distance: how close will this rocket pass?
        float toBot[3];
        SubtractVectors(botPos, rPos, toBot);
        float rSpeed2 = rVel[0] * rVel[0] + rVel[1] * rVel[1] + rVel[2] * rVel[2];

        // Only dodge if: rocket is close (<350u), moving, and will pass within 150u
        if (bestDist < 350.0 && rSpeed2 > 1.0) {
            float dot = GetVectorDotProduct(toBot, rVel);
            float t = dot / rSpeed2;  // time of closest approach

            // Only care about rockets approaching (t > 0) and arriving soon (t < 0.5s)
            if (t > 0.0 && t < 0.5) {
                float closest[3];
                closest[0] = rPos[0] + rVel[0] * t - botPos[0];
                closest[1] = rPos[1] + rVel[1] * t - botPos[1];
                closest[2] = rPos[2] + rVel[2] * t - botPos[2];
                float closestDist = GetVectorLength(closest);

                if (closestDist < 150.0) {
                    DebugLogEvent(client, vel, angles, "dodge_nontarget");

                    // Gentle perpendicular sidestep (not full sprint)
                    float rocketYaw = RadToDeg(ArcTangent2(rVel[1], rVel[0]));
                    float leftYaw = rocketYaw + 90.0;
                    float rightYaw = rocketYaw - 90.0;
                    float botAngle = RadToDeg(ArcTangent2(botPos[1] - rPos[1], botPos[0] - rPos[0]));
                    float diffLeft = FloatAbs(leftYaw - botAngle);
                    if (diffLeft > 180.0) diffLeft = 360.0 - diffLeft;
                    float diffRight = FloatAbs(rightYaw - botAngle);
                    if (diffRight > 180.0) diffRight = 360.0 - diffRight;
                    float dodgeYaw = (diffLeft < diffRight) ? leftYaw : rightYaw;

                    // Blend dodge into existing velocity instead of replacing it
                    float viewYaw = angles[1];
                    float moveRelative = dodgeYaw - viewYaw;
                    float dodgeStrength = 200.0;  // half of old 400 — sidestep, not sprint
                    vel[0] += Cosine(DegToRad(moveRelative)) * dodgeStrength;
                    vel[1] += -Sine(DegToRad(moveRelative)) * dodgeStrength;

                    // Glance at the rocket
                    float dodgeAim[3];
                    CalcAimAngles(eyePos, rPos, dodgeAim);
                    SmoothAim(client, dodgeAim, 0.3);
                }
            }
        }
        // Don't return early — fall through to normal movement/aim logic
    }

    // =====================================================================
    // COMPUTE AIM - intercept prediction for high-speed rockets
    // =====================================================================
    if (!IsValidEntity(bestRocket)) return Plugin_Changed;
    float rocketPos[3];
    rocketPos = rocketPosCache;

    float rocketVelPredict[3];
    rocketVelPredict = rocketVelCache;
    float currentSpeed = rocketSpeedCache;
    
    float aimAngle[3];
    
    if (currentSpeed > 1200.0 && bestDist > 200.0) {
        float timeToReach = bestDist / currentSpeed;
        
        float predictionFactor = 0.0;
        if (currentSpeed > 3000.0) {
            predictionFactor = 0.7;
        } else if (currentSpeed > 2200.0) {
            predictionFactor = 0.5;
        } else if (currentSpeed > 1600.0) {
            predictionFactor = 0.3;
        } else {
            predictionFactor = 0.15;
        }
        
        float predictTime = timeToReach * predictionFactor;
        
        float predictedPos[3];
        predictedPos[0] = rocketPos[0] + rocketVelPredict[0] * predictTime;
        predictedPos[1] = rocketPos[1] + rocketVelPredict[1] * predictTime;
        predictedPos[2] = rocketPos[2] + rocketVelPredict[2] * predictTime;
        
        CalcAimAngles(eyePos, predictedPos, aimAngle);
    } else {
        CalcAimAngles(eyePos, rocketPos, aimAngle);
    }

    // =====================================================================
    // DECIDE TIMING (once per incoming rocket)
    // =====================================================================
    float rocketSpeed = 800.0;
    if (!TimingDecided[client]) {
        TimingDecided[client] = true;
        HasRocket[client] = true;

        // React timing: config sets STARTING personality, brain learns from there.
        // The brain's DecideReactMultiplier returns 0.7 (late/risky) to 1.3 (early/safe)
        // This modulates the base react time, letting the bot discover its own sweet spot.
        float learnedReactMin, learnedReactMax;
        GetLearnedReactionWindow(botType, learnedReactMin, learnedReactMax);
        float reactTime = GetRandomFloat(learnedReactMin, learnedReactMax);
        rocketSpeed = rocketSpeedCache;
        if (rocketSpeed < 100.0) rocketSpeed = 800.0;
        
        float reactMult = DecideReactMultiplier(client, rocketSpeed, botType);
        ReactDistance[client] = rocketSpeed * reactTime * reactMult;
        
        // Dynamic react distance bounds scale with speed and deflects.
        // These are SOFT bounds - the brain's multiplier is the real driver.
        // At high deflects/speed, widen the range so the brain has room to adapt.
        float minReact = 100.0;
        float maxReact = 650.0;
        
        if (Deflects > 100) {
            minReact = 180.0;
            maxReact = 1000.0;
        } else if (Deflects > 50) {
            minReact = 160.0;
            maxReact = 900.0;
        } else if (Deflects > 20) {
            minReact = 140.0;
            maxReact = 800.0;
        }
        
        // Speed-based range extension
        if (rocketSpeed > 3000.0) {
            maxReact += 250.0;
            minReact += 50.0;
        } else if (rocketSpeed > 2200.0) {
            maxReact += 120.0;
        }
        
        if (ReactDistance[client] < minReact) ReactDistance[client] = minReact;
        if (ReactDistance[client] > maxReact) ReactDistance[client] = maxReact;

        Trick[client] = DecideTrick(client, rocketSpeed, botType);
        ComputeStateKey(client, rocketSpeed, botType);
    } else {
        rocketSpeed = rocketSpeedCache;
        if (rocketSpeed < 100.0) rocketSpeed = 800.0;
    }

    // =====================================================================
    // ORBITING - FULL WASD multi-loop orbit system
    // Players use WASD keys to orbit: step right, back, left, forward
    // in a full circle. Multiple loops are possible to delay timing.
    // =====================================================================
    
    float rocketTurnRate = 0.0;
    #if defined _tfdb_included
    if (TFDBAvailable && TFDB_IsDodgeballEnabled() && bestRocket != -1) {
        if (rocketIdxCache != -1) {
            int rocketClass = TFDB_GetRocketClass(rocketIdxCache);
            if (rocketClass >= 0) {
                rocketTurnRate = TFDB_GetRocketClassTurnRate(rocketClass);
            }
        }
    }
    #endif
    
    bool orbitSafe = (rocketTurnRate < 0.30);

    // Statue bots never orbit — standing still is the whole point
    if (ClassIsStatueLike[botType]) {
        Orbiting[client] = false;
    }

    // Traversal gate: if the bot's target enemy is far away, the bot is
    // crossing the map rather than engaging in CQC. Orbit's WASD back-phase
    // cancels approach momentum, which caused bots to get stuck in 4v4
    // training when several tried to cross together.
    //
    // Reuses TargetEnemy[client] (refreshed at :2659 on MoveModeEnd) instead
    // of calling FindClosestEnemy again — avoids an extra O(MaxClients) scan
    // per tick per bot. Staleness is fine here; we're gating on >1200u which
    // is well past tick-scale target drift.
    bool isTraversing = false;
    {
        int tgt = TargetEnemy[client];
        if (tgt > 0 && tgt <= MaxClients && IsClientInGame(tgt) && IsPlayerAlive(tgt)) {
            float bPosG[3], ePosG[3];
            GetClientAbsOrigin(client, bPosG);
            GetClientAbsOrigin(tgt, ePosG);
            if (GetVectorDistance(bPosG, ePosG) > 1200.0) {
                isTraversing = true;
            }
        }
    }

    // Recovery orbit on miss
    if (!ClassIsStatueLike[botType] && CfgCanOrbit[botType] && MissedAirblast[client] && bestRocket != -1 && bestDist > ReactDistance[client]) {
        if (rocketSpeed < 2200.0 && GetRandomFloat(0.0, 100.0) < 60.0) {
            Orbiting[client] = true;
            MissedAirblast[client] = false;
            OrbitPhaseIdx[client] = ORBIT_PHASE_RIGHT;
            OrbitLoopCount[client] = 0;
            
            // Phase timing scales with rocket speed - faster rocket = faster orbit
            OrbitPhaseTime[client] = (rocketSpeed > 1500.0) ? 0.12 : 0.2;
            OrbitPhaseEnd[client] = engineTime + OrbitPhaseTime[client];
            OrbitEnd[client] = engineTime + GetRandomFloat(0.8, CfgMaxOrbitTime[botType]);
            
            float toRocket[3];
            SubtractVectors(rocketPos, eyePos, toRocket);
            float rocketAngle = RadToDeg(ArcTangent2(toRocket[1], toRocket[0]));
            float currentAngle = angles[1];
            float angleDiff = rocketAngle - currentAngle;
            OrbitDir[client] = (angleDiff > 0.0) ? -1.0 : 1.0;
        } else {
            MissedAirblast[client] = false;
        }
    }
    
    // Block orbit entry when multi-threat detected. Orbit's back-phase is
    // safe against ONE rocket (strafe perpendicular) but catastrophic
    // against two (back-phase into second rocket's path).
    if (engineTime >= NextThreatScan[client]) {
        CachedThreatCount[client] = CountIncomingThreats(client);
        NextThreatScan[client]    = engineTime + 0.1;
    }
    int incomingThreats = CachedThreatCount[client];
    bool multiThreat = (incomingThreats >= 2);

    // Normal orbit decision (not for statue bots, not during traversal, not multi-threat, not if orbit capability removed)
    if (!ClassIsStatueLike[botType] && CfgCanOrbit[botType] && !Orbiting[client] && !isTraversing && !multiThreat && rocketSpeed < 2000.0 && orbitSafe) {
        bool shouldOrbit = DecideOrbit(client, rocketSpeed, rocketTurnRate, botType);
        if (shouldOrbit) {
            Orbiting[client] = true;
            OrbitDir[client] = (GetRandomFloat(0.0, 1.0) > 0.5) ? 1.0 : -1.0;
            OrbitPhaseIdx[client] = ORBIT_PHASE_RIGHT;
            OrbitLoopCount[client] = 0;
            OrbitPhaseTime[client] = (rocketSpeed > 1200.0) ? 0.15 : 0.25;
            OrbitPhaseEnd[client] = engineTime + OrbitPhaseTime[client];
            OrbitEnd[client] = engineTime + GetRandomFloat(0.5, CfgMaxOrbitTime[botType]);
        }
    }
    
    // Execute WASD orbit if active
    if (Orbiting[client]) {
        // End conditions: time expired, rocket too close, max loops reached,
        // bot moved into traversal range (enemy far away), orbit capability
        // revoked via config reload, OR multi-threat appeared mid-orbit.
        if (engineTime >= OrbitEnd[client] ||
            bestDist < ReactDistance[client] + 50.0 ||
            OrbitLoopCount[client] >= CfgMaxOrbitLoops[botType] ||
            isTraversing ||
            !CfgCanOrbit[botType] ||
            multiThreat) {
            Orbiting[client] = false;
            OrbitPhaseIdx[client] = ORBIT_PHASE_NONE;
        } else {
            // Advance orbit phase (WASD cycle)
            if (engineTime >= OrbitPhaseEnd[client]) {
                OrbitPhaseIdx[client]++;
                if (OrbitPhaseIdx[client] > NUM_ORBIT_PHASES) {
                    OrbitPhaseIdx[client] = ORBIT_PHASE_RIGHT;
                    OrbitLoopCount[client]++;
                }
                OrbitPhaseEnd[client] = engineTime + OrbitPhaseTime[client];
            }
            
            // Apply WASD movement for current orbit phase
            // This creates true circular WASD orbiting like real players do
            float orbitMoveYaw = aimAngle[1]; // Base direction toward rocket
            
            switch (OrbitPhaseIdx[client]) {
                case ORBIT_PHASE_RIGHT: {
                    // Strafe right (D key equivalent)
                    orbitMoveYaw += 90.0 * OrbitDir[client];
                }
                case ORBIT_PHASE_BACK: {
                    // Move backward (S key equivalent)  
                    orbitMoveYaw += 180.0;
                }
                case ORBIT_PHASE_LEFT: {
                    // Strafe left (A key equivalent)
                    orbitMoveYaw -= 90.0 * OrbitDir[client];
                }
                case ORBIT_PHASE_FORWARD: {
                    // Move forward (W key equivalent)
                    // Already pointing at rocket, slight angle
                    orbitMoveYaw += 10.0 * OrbitDir[client];
                }
            }
            
            // Apply orbit movement
            float viewYaw = angles[1];
            float orbitRelative = orbitMoveYaw - viewYaw;
            vel[0] = Cosine(DegToRad(orbitRelative)) * 400.0;
            vel[1] = -Sine(DegToRad(orbitRelative)) * 400.0;
            buttons |= IN_FORWARD;
            
            // Look toward rocket during orbit (smooth track)
            float orbitOffset = 50.0;
            if (rocketSpeed > 1500.0) orbitOffset = 35.0;
            if (rocketTurnRate > 0.15) orbitOffset = 25.0;
            
            float orbitAim[3];
            orbitAim[0] = aimAngle[0];
            orbitAim[1] = aimAngle[1] + (orbitOffset * OrbitDir[client]);
            orbitAim[2] = 0.0;
            ClampAngles(orbitAim);
            SmoothAim(client, orbitAim, 0.3);
            return Plugin_Changed;
        }
    }

    // =====================================================================
    // AIM AT ROCKET - human-like awareness tracking
    // Real players don't laser-lock rockets. They maintain awareness of
    // the rocket's general area and only snap to it when it's close.
    // At distance, tracking is soft (peripheral vision). Up close, tight.
    // Bounces cause a brief dampening — camera doesn't snap instantly.
    // =====================================================================

    // Bounce detection: if rocket yaw changed sharply, dampen aim briefly
    float rocketYaw = RadToDeg(ArcTangent2(rocketVelPredict[1], rocketVelPredict[0]));
    float yawDelta = FloatAbs(rocketYaw - LastRocketYaw[client]);
    if (yawDelta > 180.0) yawDelta = 360.0 - yawDelta;
    LastRocketYaw[client] = rocketYaw;

    if (yawDelta > 45.0 && bestDist > 300.0) {
        // Rocket bounced or changed direction — dampen tracking briefly
        AimDampen[client] = 0.7;  // Strong dampening
    }
    // Decay dampening over time
    if (AimDampen[client] > 0.0) {
        AimDampen[client] -= 0.03;  // ~23 ticks to fully recover
        if (AimDampen[client] < 0.0) AimDampen[client] = 0.0;
    }

    float aimFactor;

    if (rocketSpeed > 3000.0) {
        // Very fast rocket: tight tracking needed to survive
        aimFactor = (bestDist < 400.0) ? 0.95 : 0.5;
    } else if (rocketSpeed > 2200.0) {
        aimFactor = (bestDist < 400.0) ? 0.85 : 0.35;
    } else if (rocketSpeed > 1500.0) {
        aimFactor = (bestDist < 300.0) ? 0.7 : 0.2;
    } else {
        // Slow rocket — peripheral awareness, not hard tracking
        if (bestDist < 250.0) {
            aimFactor = 0.8;   // Close: tighten up for airblast
        } else if (bestDist < 500.0) {
            aimFactor = 0.25;  // Mid: loose awareness
        } else if (bestDist < 1000.0) {
            aimFactor = 0.1;   // Far: barely tracking, just aware
        } else {
            aimFactor = 0.05;  // Very far: subtle drift toward rocket
        }
    }

    // Apply aim dampening
    aimFactor *= (1.0 - AimDampen[client]);

    SmoothAim(client, aimAngle, aimFactor);

    // =====================================================================
    // AIRBLAST when rocket is close enough, approaching, AND airblast ready
    // Key rule: ONLY airblast rockets heading TOWARD us. Never airblast a
    // rocket heading away (teammate just deflected it toward the enemy).
    // Also don't steal a teammate's targeted rocket.
    // =====================================================================
    if (bestDist < ReactDistance[client] && IsAirblastReady(activeWeapon)) {
        // Is this rocket actually heading toward me?
        float abDir[3];
        SubtractVectors(eyePos, rocketPos, abDir);
        NormalizeVector(abDir, abDir);
        float approachDot = GetVectorDotProduct(rocketVelPredict, abDir);
        bool isApproaching = (approachDot > 0.0);

        int targetOfRocket = -1;
        #if defined _tfdb_included
        if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
            if (rocketIdxCache != -1) {
                targetOfRocket = rocketTargetCache;
            }
        }
        #endif

        // Check if rocket is targeting a teammate (steal prevention)
        bool isTeammateRocket = false;
        if (targetOfRocket > 0 && targetOfRocket <= MaxClients &&
            IsClientInGame(targetOfRocket) && targetOfRocket != client &&
            GetClientTeam(targetOfRocket) == GetClientTeam(client)) {
            isTeammateRocket = true;
        }

        // Decision: should we airblast?
        bool shouldAirblast = false;
        if (!isApproaching) {
            // Rocket heading away — never airblast (teammate's deflect or miss)
            DebugLogEvent(client, vel, angles, "skip_heading_away");
            if (DebugActive) {
                char abReason[64];
                FormatEx(abReason, sizeof(abReason), "skip_heading_away approachDot=%.0f", approachDot);
                DebugLogDecision(client, "Airblast", abReason);
            }
        } else if (isTeammateRocket && bestDist > 150.0) {
            // Approaching but targets a teammate — let them handle it
            DebugLogEvent(client, vel, angles, "skip_teammate_rocket");
            if (DebugActive) {
                char abReason[64];
                FormatEx(abReason, sizeof(abReason), "skip_teammate_rocket dist=%.0f tgt=#%d", bestDist, targetOfRocket);
                DebugLogDecision(client, "Airblast", abReason);
            }
        } else if (rocketTargetsMeCache) {
            // Rocket targeting US — always airblast
            shouldAirblast = true;
            if (DebugActive) {
                char abReason[64];
                FormatEx(abReason, sizeof(abReason), "AIRBLAST targeting_us=1 dist=%.0f spd=%.0f", bestDist, rocketSpeed);
                DebugLogDecision(client, "Airblast", abReason);
            }
        } else if (bestDist < 150.0 && !ClassIsStatueLike[botType]) {
            // Not targeted at us but dangerously close — emergency airblast
            // Statue bots (The Wall) ONLY airblast rockets targeting them.
            // They stand still and let non-targeted rockets pass — no stealing.
            shouldAirblast = true;
            DebugLogEvent(client, vel, angles, "airblast_emergency");
            if (DebugActive) {
                char abReason[64];
                FormatEx(abReason, sizeof(abReason), "AIRBLAST emergency dist=%.0f<150", bestDist);
                DebugLogDecision(client, "Airblast", abReason);
            }
        } else {
            // Approaching, not targeting us, not dangerously close — skip
            DebugLogEvent(client, vel, angles, "skip_not_targeted");
            if (DebugActive) {
                char abReason[64];
                FormatEx(abReason, sizeof(abReason), "skip_not_targeted dist=%.0f tgt=#%d statue=%d",
                    bestDist, targetOfRocket, ClassIsStatueLike[botType] ? 1 : 0);
                DebugLogDecision(client, "Airblast", abReason);
            }
        }

        if (shouldAirblast) {
            buttons |= IN_ATTACK2;
            DebugLogEvent(client, vel, angles, "airblast");

            HasRocket[client] = true;

            if (rocketSpeed < 2500.0 && targetOfRocket > 0 && targetOfRocket <= MaxClients &&
                IsClientInGame(targetOfRocket) && IsPlayerAlive(targetOfRocket)) {
                CurrentLookState[client] = LOOK_PLAYER;
                LastDeflectedPlayer[client] = targetOfRocket;
                // Randomize look duration: 30-70% of configured time to avoid robotic staring.
                // Fast rockets get shorter looks (bot should refocus quickly).
                float lookScale = (rocketSpeed > 1500.0) ? GetRandomFloat(0.2, 0.5) : GetRandomFloat(0.3, 0.7);
                LookAtPlayerEnd[client] = engineTime + CfgLookAtPlayerTime[botType] * lookScale;
            }

            TimingDecided[client] = false;

            // Deflect counting: TFDB_OnRocketDeflect handles confirmed deflects + rewards
            // Only count here as fallback if TFDB is not loaded
            if (!TFDBAvailable) {
                TotalDeflects++;
                RoundDeflects++;
                LastDeflectSpeed = rocketSpeed;
                int fallbackReward = CalcDifficultyReward(rocketSpeed, Deflects);

                PenalizeProximityOnDeflect(client, botType);
                RewardWithAttribution(client, fallbackReward, botType, REWARD_DEFLECT);
            }
            // (When TFDB IS available, TFDB_OnRocketDeflect fires with difficulty-scaled reward)

            float aimOffset = DecideAimOffset(client, rocketSpeed, botType);

            TrickType effectiveTrick = Trick[client];
            if (rocketSpeed > 2500.0) {
                if (effectiveTrick == TRICK_SPIN || effectiveTrick == TRICK_WAVE) {
                    effectiveTrick = TRICK_NONE;
                }
            }

            if (effectiveTrick != TRICK_NONE) {
                ApplyingTrick[client] = true;
                TrickEnd[client] = engineTime + (effectiveTrick == TRICK_SPIN ? 0.35 : 0.2);
            }

            if (aimOffset != 0.0) {
                float biasAngles[3];
                GetClientEyeAngles(client, biasAngles);
                biasAngles[1] += aimOffset;
                ClampAngles(biasAngles);
                TeleportEntity(client, NULL_VECTOR, biasAngles, NULL_VECTOR);
            }
        } // end if (shouldAirblast)
    }

    // =====================================================================
    // CHECK IF WE MISSED — and emit near-miss penalty reward
    // =====================================================================
    if (HasRocket[client] && bestRocket != -1) {
        float missCheckVel[3];
        missCheckVel = rocketVelCache;

        float toRocketDir[3];
        SubtractVectors(rocketPos, eyePos, toRocketDir);
        NormalizeVector(toRocketDir, toRocketDir);

        float dot = GetVectorDotProduct(missCheckVel, toRocketDir);

        if (dot < -100.0 && bestDist > ReactDistance[client] + 200.0) {
            MissedAirblast[client] = true;
            HasRocket[client] = false;

            // --- Near-miss signal ---
            // When the bot airblasted and the rocket is now moving AWAY but
            // we were never credited with a deflect, that's a near-miss:
            //   - bestDist < ReactDistance + 300  → very close near-miss
            //   - bestDist < ReactDistance + 600  → moderate near-miss
            // Inject small proportional penalty so the policy learns "slightly
            // late / slightly off-aim → try the other direction." Without
            // this, the reward signal is sparse: policy only learns from
            // confirmed deflects/deaths and ignores the ~30% of airblasts
            // that miss by inches.
            float missDist = bestDist - ReactDistance[client];
            int nearMissPenalty = 0;
            if (missDist < 300.0)      nearMissPenalty = -4;  // very close
            else if (missDist < 600.0) nearMissPenalty = -2;  // moderate
            // Penalty only applied to TIMING and AIM — the two decisions
            // that actually control airblast success. Movement/orbit/evade
            // don't cause an airblast to miss; timing and aim do.
            if (nearMissPenalty != 0) {
                AdjustBrain(LastReactKey[client], LastReactChoice[client], nearMissPenalty, DefReact, 3);
                AdjustBrain(LastAimKey[client],   LastAimChoice[client],   nearMissPenalty, DefAim,   5);
            }
        }
    }

    return Plugin_Changed;
}

// ============================================================================
// TRICK APPLICATION
// ============================================================================

void ApplyTrick(float angles[3], int trick, float time) {
    switch (trick) {
        case TRICK_DOWN_SPIKE: {
            angles[0] = 89.0;
        }
        case TRICK_UP_SPIKE: {
            angles[0] = -89.0;
        }
        case TRICK_LEFT_FLICK: {
            angles[1] -= 90.0;
        }
        case TRICK_RIGHT_FLICK: {
            angles[1] += 90.0;
        }
        case TRICK_WAVE: {
            angles[1] += Sine(time * 12.0) * 45.0;
            angles[0] += Cosine(time * 12.0) * 20.0;
        }
        case TRICK_SPIN: {
            angles[1] += Sine(time * 20.0) * 180.0;
            angles[0] += Cosine(time * 15.0) * 10.0;
        }
    }
}

// ============================================================================
// LEARNING SYSTEM - Multi-dimensional adaptive brain
// Now takes botType parameter so each personality learns separately
// even in training mode where multiple types coexist.
// ============================================================================

#define MAX_BRAIN_OPTIONS 8

int ChooseWeighted(const char[] brainKey, const int[] defaults, int numOptions) {
    int weights[MAX_BRAIN_OPTIONS];
    bool classHasData = false;

    // Null-safe: if brain not loaded yet, use defaults
    if (BrainMemory == null || !BrainMemory.GetArray(brainKey, weights, numOptions)) {
        for (int i = 0; i < numOptions; i++) weights[i] = defaults[i];
        if (BrainMemory != null) {
            BrainMemory.SetArray(brainKey, weights, numOptions);
        }
    } else {
        classHasData = true;
    }

    // Shared base policy read-side blend.
    // If the class key has little accumulated signal (sum close to defaults
    // sum, i.e. it hasn't learned much yet), blend in the shared-base key.
    // This accelerates new-class learning while letting mature classes
    // diverge from the base.
    //
    // Blend rule: classWeight = (classEvidence / totalEvidence) as a simple
    // 0.0-1.0 ratio, where "evidence" = sum of class weights above default.
    // When a class is new, evidence = 0, blend is 100% shared. As it learns,
    // class dominates.
    if (classHasData && BrainMemory != null) {
        char sharedKey[64];
        if (DeriveSharedKey(brainKey, sharedKey, sizeof(sharedKey))) {
            int sharedWeights[MAX_BRAIN_OPTIONS];
            if (BrainMemory.GetArray(sharedKey, sharedWeights, numOptions)) {
                // Evidence = sum of (weight - default), clamped positive.
                // Higher evidence = class has moved away from defaults.
                int classEvidence = 0;
                int sharedEvidence = 0;
                for (int i = 0; i < numOptions; i++) {
                    int cDelta = weights[i] - defaults[i];
                    int sDelta = sharedWeights[i] - defaults[i];
                    if (cDelta < 0) cDelta = -cDelta;
                    if (sDelta < 0) sDelta = -sDelta;
                    classEvidence += cDelta;
                    sharedEvidence += sDelta;
                }
                int totalEvidence = classEvidence + sharedEvidence;
                if (totalEvidence > 0 && sharedEvidence > 0) {
                    // Blend. Weight vector = (classWeight * classEv + sharedWeight * sharedEv) / totalEv
                    for (int i = 0; i < numOptions; i++) {
                        int blended = (weights[i] * classEvidence + sharedWeights[i] * sharedEvidence) / totalEvidence;
                        if (blended < 1) blended = 1;
                        if (blended > 200) blended = 200;
                        weights[i] = blended;
                    }
                }
            }
        }
    }

    int total = 0;
    for (int i = 0; i < numOptions; i++) {
        if (weights[i] > 0) total += weights[i];
    }
    if (total <= 0) return 0;

    int roll = GetRandomInt(1, total);
    int cum = 0;
    for (int i = 0; i < numOptions; i++) {
        if (weights[i] <= 0) continue;
        cum += weights[i];
        if (roll <= cum) return i;
    }
    return 0;
}

void AdjustBrain(const char[] brainKey, int optionId, int adjustment, const int[] defaults, int numOptions) {
    if (brainKey[0] == '\0' || optionId < 0 || optionId >= numOptions) return;
    if (BrainMemory == null) return;

    int weights[MAX_BRAIN_OPTIONS];
    bool wasInBrain = BrainMemory.GetArray(brainKey, weights, numOptions);
    if (!wasInBrain) {
        for (int i = 0; i < numOptions; i++) weights[i] = defaults[i];
    }

    int oldWeight = weights[optionId];
    weights[optionId] += adjustment;
    if (weights[optionId] < 1) weights[optionId] = 1;
    if (weights[optionId] > 200) weights[optionId] = 200;
    int newWeight = weights[optionId];

    BrainMemory.SetArray(brainKey, weights, numOptions);
    QueueBrainWrite(brainKey, optionId, weights[optionId]);

    // Reward-signal trace — proves learning is firing. Each line here means
    // a class state's weight just got nudged. If the debug log shows DECISION
    // events but ZERO REWARD events, the learning loop is broken upstream.
    // 2026-04-27: added because frozen-weights audit couldn't distinguish
    // "reward never fires" vs "reward fires but blend hides it".
    if (DebugActive && DebugFile != null) {
        // SourcePawn's Format does not support the "+" flag (%+d). Build the
        // sign manually. Without this fix, %+d printed as the literal "+d"
        // and consumed zero args, shifting every subsequent %d left by one
        // — the 04-27 session's logs all read weight=ADJ->OLD defaultsKnown=NEW.
        char signStr[2];
        signStr[0] = (adjustment >= 0) ? '+' : '\0';  // negative numbers carry their own sign
        signStr[1] = '\0';

        DebugFile.WriteLine("[REWARD] key=%s opt=%d adj=%s%d weight=%d->%d seeded=%d",
            brainKey, optionId, signStr, adjustment, oldWeight, newWeight, wasInBrain ? 1 : 0);
        DebugBumpLineCount();
    }

    // Shared base policy propagation.
    // After updating the class-specific key, also propagate a HALF-magnitude
    // update to the shared key (same key with the "_t%d" segment stripped).
    // New classes will inherit aggregate wisdom from the shared key until
    // their own class key accumulates enough data to dominate.
    char sharedKey[64];
    if (DeriveSharedKey(brainKey, sharedKey, sizeof(sharedKey))) {
        int sharedAdj = HalfCredit(adjustment);
        if (sharedAdj != 0) {
            int sweights[MAX_BRAIN_OPTIONS];
            if (!BrainMemory.GetArray(sharedKey, sweights, numOptions)) {
                for (int i = 0; i < numOptions; i++) sweights[i] = defaults[i];
            }
            sweights[optionId] += sharedAdj;
            if (sweights[optionId] < 1)   sweights[optionId] = 1;
            if (sweights[optionId] > 200) sweights[optionId] = 200;
            BrainMemory.SetArray(sharedKey, sweights, numOptions);
            QueueBrainWrite(sharedKey, optionId, sweights[optionId]);
        }
    }
}

// Queue a brain-weight write for batched SQL flush.
// Key is "state_key|trick_id" (compound PK). Repeated queues to the same
// (key, option) overwrite — latest weight wins. Flushed via FlushBrainWrites.
void QueueBrainWrite(const char[] brainKey, int optionId, int weight) {
    if (BrainWriteQueue == null) return;
    if (BrainDraining) return;  // reset in progress; drop write
    char qkey[72];
    FormatEx(qkey, sizeof(qkey), "%s|%d", brainKey, optionId);
    BrainWriteQueue.SetValue(qkey, weight);
}

// Flush all queued brain writes as a single SQL transaction. Called on
// round end and map end. Deduplicated: the StringMap naturally collapses
// repeated writes to the same cell.
void FlushBrainWrites() {
    if (BrainWriteQueue == null || BrainDB == null) return;
    if (BrainDraining) return;  // reset in progress; skip this flush cycle
    int n = BrainWriteQueue.Size;
    if (n == 0) return;

    BrainDB.Query(SQL_Generic, "BEGIN TRANSACTION");

    StringMapSnapshot snap = BrainWriteQueue.Snapshot();
    for (int i = 0; i < snap.Length; i++) {
        char qkey[72];
        snap.GetKey(i, qkey, sizeof(qkey));

        int weight = 0;
        if (!BrainWriteQueue.GetValue(qkey, weight)) continue;

        // Split "state_key|trick_id" back out.
        int bar = FindCharInString(qkey, '|', true);
        if (bar <= 0) continue;
        char stateKey[64];
        strcopy(stateKey, sizeof(stateKey), qkey);
        stateKey[bar] = '\0';
        int optionId = StringToInt(qkey[bar + 1]);

        char escapedKey[96];
        BrainDB.Escape(stateKey, escapedKey, sizeof(escapedKey));
        char query[256];
        FormatEx(query, sizeof(query),
            "INSERT OR REPLACE INTO bot_brain_v3 (state_key, trick_id, weight) VALUES ('%s', %d, %d)",
            escapedKey, optionId, weight);
        BrainDB.Query(SQL_Generic, query);
    }
    delete snap;

    BrainDB.Query(SQL_Generic, "COMMIT");
    BrainWriteQueue.Clear();
}

// Strip the "_t%d" segment from a brain key to produce a type-agnostic
// shared key. Example:
//   "T_t2_s3_d1_o0"  ->  "T_shared_s3_d1_o0"
//   "M_t0_s2_e1_tm0" ->  "M_shared_s2_e1_tm0"
//
// Returns true if a shared key was derived, false if the input didn't
// contain a recognizable "_t%d_" segment (e.g. legacy keys).
bool DeriveSharedKey(const char[] src, char[] dest, int destSize) {
    // Find the "_t" marker — all our keys have one.
    int tPos = StrContains(src, "_t", true);
    if (tPos < 0) return false;
    // Must be followed by at least one digit.
    if (!IsCharNumeric(src[tPos + 2])) return false;

    // Copy prefix up to (not including) "_t"
    int writeIdx = 0;
    for (int i = 0; i < tPos && writeIdx < destSize - 1; i++) {
        dest[writeIdx++] = src[i];
    }

    // Insert "_shared"
    char shared[] = "_shared";
    for (int i = 0; shared[i] != '\0' && writeIdx < destSize - 1; i++) {
        dest[writeIdx++] = shared[i];
    }

    // Skip over the "_t%d" segment in source — find the next '_' after tPos+2
    int rest = tPos + 2;
    while (src[rest] != '\0' && IsCharNumeric(src[rest])) rest++;
    // Copy the rest (starts with '_' or '\0')
    while (src[rest] != '\0' && writeIdx < destSize - 1) {
        dest[writeIdx++] = src[rest++];
    }
    dest[writeIdx] = '\0';
    return true;
}

// --- Speed/turnrate tier helpers ---

int GetSpeedTier(float speed) {
    if (speed < 1000.0) return 0;
    if (speed < 1800.0) return 1;
    if (speed < 2800.0) return 2;
    return 3;
}

int GetTurnRateTier(float turnRate) {
    if (turnRate < 0.10) return 0;
    if (turnRate < 0.20) return 1;
    if (turnRate < 0.35) return 2;
    return 3;
}

int GetDeflectTier() {
    if (Deflects < 5) return 0;
    if (Deflects < 15) return 1;
    if (Deflects < 50) return 2;
    return 3;  // Added tier 3 for very high deflect counts
}

int GetEnemyDistTier(int client) {
    int closestEnemy = FindClosestEnemy(client);
    if (closestEnemy <= 0) return 1;
    float bPos[3], ePos[3];
    GetClientAbsOrigin(client, bPos);
    GetClientAbsOrigin(closestEnemy, ePos);
    float dist = GetVectorDistance(bPos, ePos);
    if (dist > 800.0) return 0; // Far
    if (dist > 350.0) return 1; // Mid
    return 2;                    // Close
}

// --- Decision functions - now take botType parameter ---

TrickType DecideTrick(int client, float speed, int botType) {
    int sTier = GetSpeedTier(speed);
    int dTier = GetDeflectTier();
    // Key the trick policy on the opponent's learned tendency so the bot can
    // differentiate "downspikes fail against jumpers" from "side-flick beats
    // strafers." Uses TargetEnemy (whoever the bot is currently aiming at);
    // matches DecideAimOffset's source of truth at :3830.
    int tgtEnemy = TargetEnemy[client];
    int opponentTendency = GetOpponentTendency(tgtEnemy);
    BuildTrickKey(LastTrickKey[client], sizeof(LastTrickKey[]), sTier, dTier, botType, opponentTendency);

    // --- HEATMAP BIAS ----------------------------------------------------
    // Look up how dangerous the player's current cell is historically.
    // >0.6 = player dies here often -> double down on current policy (no bias).
    // <0.3 = player handles this cell well -> push toward rarer tricks so
    //        they can't rely on muscle memory.
    int enemy = FindClosestEnemy(client);
    float biasedWeights[NUM_TRICKS];
    bool useBiased = false;
    if (CfgUseHeatmap && enemy > 0 && !ClassIsStatueLike[botType]) {
        float ePos[3];
        GetClientAbsOrigin(enemy, ePos);
        float danger = HeatmapDangerAt(botType, ePos);

        if (danger < 0.3) {
            // Player is comfortable here -> fetch current weights and amplify
            // the tail (rarer tricks) so the bot breaks their pattern.
            int raw[NUM_TRICKS];
            if (BrainMemory == null || !BrainMemory.GetArray(LastTrickKey[client], raw, NUM_TRICKS)) {
                for (int i = 0; i < NUM_TRICKS; i++) raw[i] = DefTrick[i];
            }
            // Sort-free amplification: find max, multiply non-max entries by 1.8.
            int maxIdx = 0;
            for (int i = 1; i < NUM_TRICKS; i++) if (raw[i] > raw[maxIdx]) maxIdx = i;
            for (int i = 0; i < NUM_TRICKS; i++) {
                biasedWeights[i] = (i == maxIdx) ? float(raw[i]) : float(raw[i]) * 1.8;
            }
            useBiased = true;
        }
    }

    int choice;
    if (useBiased) {
        choice = ChooseWeightedFloat(biasedWeights, NUM_TRICKS);
    } else {
        choice = ChooseWeighted(LastTrickKey[client], DefTrick, NUM_TRICKS);
    }
    LastTrick[client] = choice;

    if (DebugActive) {
        static const char trickNames[NUM_TRICKS][] = {
            "NONE", "LEFT_FLICK", "RIGHT_FLICK", "DOWN_SPIKE", "UP_SPIKE", "WAVE", "SPIN"
        };
        char det[224];
        FormatEx(det, sizeof(det),
            "DecideTrick key=%s sTier=%d dTier=%d oppTendency=%d biased=%d -> %s",
            LastTrickKey[client], sTier, dTier, opponentTendency,
            useBiased ? 1 : 0,
            (choice >= 0 && choice < NUM_TRICKS) ? trickNames[choice] : "?");
        DebugLogDecision(client, "Trick", det);
    }

    return view_as<TrickType>(choice);
}

// Weighted pick against an arbitrary float array (used by heatmap bias)
int ChooseWeightedFloat(const float[] weights, int numOptions) {
    float total = 0.0;
    for (int i = 0; i < numOptions; i++) {
        total += (weights[i] > 0.0) ? weights[i] : 0.0;
    }
    if (total <= 0.0) return 0;
    float roll = GetRandomFloat(0.0, total);
    float acc = 0.0;
    for (int i = 0; i < numOptions; i++) {
        if (weights[i] > 0.0) acc += weights[i];
        if (roll <= acc) return i;
    }
    return numOptions - 1;
}

bool DecideOrbit(int client, float speed, float turnRate, int botType) {
    int sTier = GetSpeedTier(speed);
    int trTier = GetTurnRateTier(turnRate);
    BuildOrbitKey(LastOrbitKey[client], sizeof(LastOrbitKey[]), sTier, trTier, botType);
    int choice = ChooseWeighted(LastOrbitKey[client], DefOrbit, 2);
    LastOrbitChoice[client] = choice;

    if (DebugActive) {
        char det[160];
        FormatEx(det, sizeof(det),
            "DecideOrbit key=%s sTier=%d trTier=%d weights=[no=%d,yes=%d] -> %s",
            LastOrbitKey[client], sTier, trTier, DefOrbit[0], DefOrbit[1],
            (choice == 1) ? "ORBIT" : "no_orbit");
        DebugLogDecision(client, "Orbit", det);
    }

    return (choice == 1);
}

// Check if a bot has a same-team bot within the given radius.
// Returns the distance to the nearest teammate, or -1.0 if none found.
float NearestTeammateDist(int client) {
    float myPos[3];
    GetClientAbsOrigin(client, myPos);
    float closest = -1.0;
    int myTeam = GetClientTeam(client);
    for (int t = 1; t <= MaxClients; t++) {
        if (t == client) continue;
        if (!IsClientInGame(t) || !IsFakeClient(t) || !IsPlayerAlive(t)) continue;
        if (GetClientTeam(t) != myTeam) continue;
        float tPos[3];
        GetClientAbsOrigin(t, tPos);
        float d = GetVectorDistance(myPos, tPos);
        if (closest < 0.0 || d < closest) closest = d;
    }
    return closest;
}

MoveMode DecideMovement(int client, float speed, int botType) {
    int sTier = GetSpeedTier(speed);
    int eTier = GetEnemyDistTier(client);

    // Teammate proximity as a brain dimension: the bot learns DIFFERENT
    // movement preferences when near a teammate vs alone. Over time it
    // discovers that APPROACH/IDLE near teammates leads to deaths (because
    // of rocket crossfire and stealing) and shifts toward CIRCLE/WANDER.
    float tmDist = NearestTeammateDist(client);
    int nearTeam = (tmDist > 0.0 && tmDist < 400.0) ? 1 : 0;
    BuildMoveKey(LastMoveKey[client], sizeof(LastMoveKey[]), sTier, eTier, botType, nearTeam);

    int modDefaults[5];
    modDefaults[MOVE_WANDER]   = DefMove[MOVE_WANDER];
    modDefaults[MOVE_APPROACH] = DefMove[MOVE_APPROACH];
    modDefaults[MOVE_MIRROR]   = DefMove[MOVE_MIRROR];
    modDefaults[MOVE_CIRCLE]   = DefMove[MOVE_CIRCLE];
    modDefaults[MOVE_IDLE]     = CfgCanIdle[botType] ? DefMove[MOVE_IDLE] : 0;

    // Statue-like classes: idle dominates everything. Flag comes from config.
    if (ClassIsStatueLike[botType]) {
        modDefaults[MOVE_IDLE]     = DefMove[MOVE_IDLE] + 200;
        modDefaults[MOVE_WANDER]   = 1;
        modDefaults[MOVE_APPROACH] = 1;
        modDefaults[MOVE_MIRROR]   = 1;
        modDefaults[MOVE_CIRCLE]   = 1;
    } else {
        // Soft key-name heuristics for starting personality weights. These only
        // nudge the defaults - the brain learns the real weights over time.
        if (StrContains(BotClassKey[botType], "aggress") != -1 ||
            StrContains(BotClassKey[botType], "berserk") != -1) {
            modDefaults[MOVE_APPROACH] += 40;
            modDefaults[MOVE_CIRCLE]   += 20;
            modDefaults[MOVE_IDLE]     -= 10;
        }
        if (StrContains(BotClassKey[botType], "midrange") != -1 ||
            StrContains(BotClassKey[botType], "tactic") != -1) {
            modDefaults[MOVE_MIRROR] += 20;
            modDefaults[MOVE_CIRCLE] += 15;
        }

        // Starting hint when near a teammate: prefer spreading out.
        // The brain will learn the REAL weights from experience — these
        // just give it a head start so it doesn't cluster on day one.
        if (nearTeam) {
            modDefaults[MOVE_CIRCLE]   += 25;   // Strafe to own lane
            modDefaults[MOVE_WANDER]   += 15;   // Wander away
            modDefaults[MOVE_APPROACH] -= 15;   // Don't stack forward
            modDefaults[MOVE_IDLE]     -= 10;   // Don't park next to them
        }
    }

    for (int i = 0; i < 5; i++) {
        if (modDefaults[i] < 1) modDefaults[i] = 1;
    }
    // Hard-zero MOVE_IDLE after the clamp when the class has idle capability
    // removed. Without this the clamp floors it to 1 and the brain still
    // picks idle ~1% of the time. Zero weight = never picked.
    if (!CfgCanIdle[botType] && !ClassIsStatueLike[botType]) {
        modDefaults[MOVE_IDLE] = 0;
    }

    int choice = ChooseWeighted(LastMoveKey[client], modDefaults, 5);

    // Final safety: if the weighted roll somehow landed on IDLE for a class
    // without idle capability (e.g. persisted brain row with high idle
    // weight from before the key was removed), coerce to WANDER.
    bool coerced = false;
    if (choice == view_as<int>(MOVE_IDLE) && !CfgCanIdle[botType] && !ClassIsStatueLike[botType]) {
        choice = view_as<int>(MOVE_WANDER);
        coerced = true;
    }

    // Decision log: emit the resolved weights + final choice. Helps debug
    // "why did class X pick mode Y" — you'll see the cfg-driven defaults,
    // the personality nudges, the teammate-proximity nudges, and what the
    // brain actually voted for. The brain key encodes (speedTier, enemyTier,
    // botType, nearTeam) so similar lines for the same key should converge
    // to similar weights as the brain learns.
    if (DebugActive) {
        static const char modeNames[5][] = { "WANDER", "APPROACH", "MIRROR", "CIRCLE", "IDLE" };
        char det[256];
        FormatEx(det, sizeof(det),
            "DecideMovement key=%s sTier=%d eTier=%d nearTeam=%d weights=[W%d,A%d,M%d,C%d,I%d] -> %s%s",
            LastMoveKey[client], sTier, eTier, nearTeam,
            modDefaults[0], modDefaults[1], modDefaults[2], modDefaults[3], modDefaults[4],
            modeNames[choice],
            coerced ? " (COERCED from IDLE)" : "");
        DebugLogDecision(client, "MoveMode", det);
    }

    LastMoveChoice[client] = choice;
    return view_as<MoveMode>(choice);
}

float DecideReactMultiplier(int client, float speed, int botType) {
    int sTier = GetSpeedTier(speed);
    BuildReactKey(LastReactKey[client], sizeof(LastReactKey[]), sTier, botType);
    int choice = ChooseWeighted(LastReactKey[client], DefReact, 3);
    LastReactChoice[client] = choice;

    float mult = 1.0;
    if      (choice == 0) mult = 1.3;
    else if (choice == 2) mult = 0.7;

    if (DebugActive) {
        static const char reactNames[3][] = { "SLOW", "NORMAL", "FAST" };
        char det[160];
        FormatEx(det, sizeof(det),
            "DecideReact key=%s sTier=%d -> %s (mult=%.2f)",
            LastReactKey[client], sTier,
            (choice >= 0 && choice < 3) ? reactNames[choice] : "?",
            mult);
        DebugLogDecision(client, "React", det);
    }

    return mult;
}

float DecideAimOffset(int client, float speed, int botType) {
    int sTier = GetSpeedTier(speed);
    int dTier = GetDeflectTier();
    BuildAimKey(LastAimKey[client], sizeof(LastAimKey[]), sTier, dTier, botType);
    int choice = ChooseWeighted(LastAimKey[client], DefAim, 5);
    LastAimChoice[client] = choice;

    // Get opponent profile to modulate aim
    int enemy = TargetEnemy[client];
    int tendency = GetOpponentTendency(enemy);

    if (DebugActive) {
        static const char aimNames[5][] = { "STRAIGHT", "LEFT15", "RIGHT15", "TRACK", "RANDOM" };
        char det[192];
        FormatEx(det, sizeof(det),
            "DecideAim key=%s sTier=%d dTier=%d brain_choice=%s tendency=%d (override possible)",
            LastAimKey[client], sTier, dTier,
            (choice >= 0 && choice < 5) ? aimNames[choice] : "?",
            tendency);
        DebugLogDecision(client, "Aim", det);
    }
    
    // Override aim based on opponent profiling when we have data
    // If opponent always strafes left, aim right to catch them
    if (tendency == 1 && GetRandomFloat(0.0, 100.0) < 60.0) {
        // They strafe left a lot -> aim right to lead them
        return 20.0;
    }
    else if (tendency == 2 && GetRandomFloat(0.0, 100.0) < 60.0) {
        // They strafe right a lot -> aim left to lead them
        return -20.0;
    }
    else if (tendency == 3 && GetRandomFloat(0.0, 100.0) < 50.0) {
        // Statue player - aim directly at them, they won't dodge
        if (enemy > 0 && enemy <= MaxClients && IsClientInGame(enemy) && IsPlayerAlive(enemy)) {
            float bPos[3], ePos[3];
            GetClientEyePosition(client, bPos);
            GetClientEyePosition(enemy, ePos);
            float toEnemy = RadToDeg(ArcTangent2(ePos[1] - bPos[1], ePos[0] - bPos[0]));
            float curAngles[3];
            GetClientEyeAngles(client, curAngles);
            float diff = toEnemy - curAngles[1];
            if (diff > 180.0) diff -= 360.0;
            if (diff < -180.0) diff += 360.0;
            return diff * 0.6; // Stronger lock-on for statue targets
        }
    }
    else if (tendency == 4 && GetRandomFloat(0.0, 100.0) < 50.0) {
        // Aggressive CQC player - scatter aim to keep them guessing
        return GetRandomFloat(-30.0, 30.0);
    }
    
    // Default: use brain-weighted choice
    switch (choice) {
        case 1: return -15.0;
        case 2: return 15.0;
        case 3: {
            int closestEnemy = FindClosestEnemy(client);
            if (closestEnemy > 0 && IsClientInGame(closestEnemy) && IsPlayerAlive(closestEnemy)) {
                float bPos[3], ePos[3];
                GetClientEyePosition(client, bPos);
                GetClientEyePosition(closestEnemy, ePos);
                float toEnemy = RadToDeg(ArcTangent2(ePos[1] - bPos[1], ePos[0] - bPos[0]));
                float curAngles[3];
                GetClientEyeAngles(client, curAngles);
                float diff = toEnemy - curAngles[1];
                if (diff > 180.0) diff -= 360.0;
                if (diff < -180.0) diff += 360.0;
                return diff * 0.4;
            }
            return 0.0;
        }
        case 4: return GetRandomFloat(-25.0, 25.0);
    }
    return 0.0;
}

// Evasion decision - learn when jumping/crouching is effective
EvadeAction DecideEvasion(int client, float speed, int botType) {
    if (!CfgCanEvade[botType]) {
        if (DebugActive) {
            DebugLogDecision(client, "Evade", "CfgCanEvade=0 -> EVADE_NONE (capability missing)");
        }
        return EVADE_NONE;  // capability removed in config
    }
    float roll = GetRandomFloat(0.0, 100.0);
    if (roll > CfgEvadeChance[botType]) {
        if (DebugActive) {
            char det[96];
            FormatEx(det, sizeof(det), "evade_chance=%.0f roll=%.0f -> EVADE_NONE (rolled out)",
                CfgEvadeChance[botType], roll);
            DebugLogDecision(client, "Evade", det);
        }
        return EVADE_NONE;
    }

    int sTier = GetSpeedTier(speed);
    BuildEvadeKey(LastEvadeKey[client], sizeof(LastEvadeKey[]), sTier, botType);
    int choice = ChooseWeighted(LastEvadeKey[client], DefEvade, NUM_EVADE);
    LastEvadeChoice[client] = choice;

    if (DebugActive) {
        static const char evadeNames[NUM_EVADE][] = { "NONE", "JUMP", "CROUCH" };
        char det[160];
        FormatEx(det, sizeof(det),
            "DecideEvasion key=%s sTier=%d evade_chance=%.0f roll=%.0f -> %s",
            LastEvadeKey[client], sTier, CfgEvadeChance[botType], roll,
            (choice >= 0 && choice < NUM_EVADE) ? evadeNames[choice] : "?");
        DebugLogDecision(client, "Evade", det);
    }

    return view_as<EvadeAction>(choice);
}

// Penalize movement if bot is too close to an enemy when deflecting.
// Shared by both TFDB and fallback paths to avoid duplicate logic.
// No-op when CQC capability removed — bot has no defined "too close."
void PenalizeProximityOnDeflect(int client, int botType) {
    if (!CfgCanCqc[botType]) return;
    int closestEnemy = FindClosestEnemy(client);
    if (closestEnemy <= 0) return;
    float bPos[3], ePos[3];
    GetClientAbsOrigin(client, bPos);
    GetClientAbsOrigin(closestEnemy, ePos);
    float dist = GetVectorDistance(bPos, ePos);
    if (dist < CfgCqcFloorDist[botType] + 50.0) {
        AdjustBrain(LastMoveKey[client], LastMoveChoice[client], -10, DefMove, 5);
    } else if (dist < CfgCqcMinDist[botType]) {
        AdjustBrain(LastMoveKey[client], LastMoveChoice[client], -4, DefMove, 5);
    }
}

// --- Reinforcement: called on success/failure ---

// Credit-assignment-aware reward dispatch.
// Replaces the "everyone gets equal credit" pattern with outcome-specific
// attribution. Research: naive uniform credit violates the policy gradient —
// decisions that had nothing to do with the outcome get reinforced anyway,
// slowing convergence and causing policy drift.
//
// Attribution model (integer scaling for tabular clarity):
//   DEFLECT (bot survived via airblast): timing/aim/trick caused success.
//     Positioning was "not fatal" but did not DRIVE the win.
//     → timing, aim, trick  = full reward
//     → move, orbit, evade  = half reward  (floor ±1 so signal isn't lost)
//
//   DEATH (bot got hit): positioning + reaction are what failed.
//     Trick/aim were irrelevant because the airblast failed or never fired.
//     → move, orbit, evade  = full penalty
//     → react               = full penalty (timing window missed)
//     → trick, aim          = half penalty
//
//   KILL (bot killed opponent via deflect): trick/aim/timing executed the hit.
//     → trick, aim, react   = full reward
//     → move, orbit, evade  = half reward
//
// Kept RewardAllDecisions as a fallback for call sites that genuinely want
// uniform credit (e.g. catastrophic penalties where everything was wrong).
enum RewardKind {
    REWARD_DEFLECT = 0,  // bot airblasted successfully
    REWARD_KILL    = 1,  // bot's rocket killed a target
    REWARD_DEATH   = 2,  // bot died (amount should be negative)
};

// Half-reward with ±1 floor so the signal never drops to zero when the
// base reward is small. Preserves direction of gradient.
static int HalfCredit(int amount) {
    if (amount == 0) return 0;
    int half = amount / 2;
    if (half == 0) half = (amount > 0) ? 1 : -1;
    return half;
}

void RewardWithAttribution(int client, int amount, int botType, RewardKind kind) {
    #pragma unused botType  // reserved for per-type reward scaling
    int full = amount;
    int half = HalfCredit(amount);

    int rTrick, rAim, rReact, rMove, rOrbit, rEvade;
    switch (kind) {
        case REWARD_DEFLECT: {
            rTrick = full; rAim = full; rReact = full;
            rMove  = half; rOrbit = half; rEvade = half;
        }
        case REWARD_KILL: {
            rTrick = full; rAim = full; rReact = full;
            rMove  = half; rOrbit = half; rEvade = half;
        }
        case REWARD_DEATH: {
            rMove  = full; rOrbit = full; rEvade = full;
            rReact = full;
            rTrick = half; rAim = half;
        }
        default: {
            // Shouldn't happen; fall through to uniform for safety.
            rTrick = full; rAim = full; rReact = full;
            rMove  = full; rOrbit = full; rEvade = full;
        }
    }

    AdjustBrain(LastTrickKey[client], LastTrick[client],       rTrick, DefTrick, NUM_TRICKS);
    AdjustBrain(LastOrbitKey[client], LastOrbitChoice[client], rOrbit, DefOrbit, 2);
    AdjustBrain(LastMoveKey[client],  LastMoveChoice[client],  rMove,  DefMove,  5);
    AdjustBrain(LastReactKey[client], LastReactChoice[client], rReact, DefReact, 3);
    AdjustBrain(LastAimKey[client],   LastAimChoice[client],   rAim,   DefAim,   5);
    AdjustBrain(LastEvadeKey[client], LastEvadeChoice[client], rEvade, DefEvade, NUM_EVADE);
}

// Periodic shaping reward. Called every ~4s per bot. Nudges the
// MOVEMENT policy based on positional heuristics. Signal magnitude is small
// (±1) so terminal rewards still dominate — this just fills silence between
// deflects with "your positioning looks good/bad right now."
//
// Heuristics (each ±1 independent):
//   + bot is not clustering with teammates (>=400u nearest teammate)
//   + bot is at comfortable distance from enemy (400-800u)
//   - bot is too close to any enemy (<250u)
//   - bot is too far from all enemies (>1500u) — not engaged
//   - bot is clustering (<200u teammate)
//
// Only movement/orbit are shaped — timing/aim/trick/evade are event-driven
// and don't benefit from periodic shaping.
void ApplyShapingReward(int client, int botType) {
    // Skip statue/idle-always — positional heuristics don't apply.
    if (ClassIsStatueLike[botType]) return;
    if (CfgIdleAlways[botType]) return;
    if (!IsPlayerAlive(client)) return;

    int shapingReward = 0;

    // Enemy distance heuristic
    int enemy = FindClosestEnemy(client);
    if (enemy > 0) {
        float bPos[3], ePos[3];
        GetClientAbsOrigin(client, bPos);
        GetClientAbsOrigin(enemy, ePos);
        float eDist = GetVectorDistance(bPos, ePos);

        if (eDist < 250.0)       shapingReward -= 1;  // too close (danger)
        else if (eDist < 800.0)  shapingReward += 1;  // comfortable engagement range
        else if (eDist > 1500.0) shapingReward -= 1;  // disengaged / map-crossing idle
    }

    // Teammate clustering heuristic
    float tmDist = NearestTeammateDist(client);
    if (tmDist > 0.0) {
        if (tmDist < 200.0)      shapingReward -= 1;  // clustering (rocket crossfire risk)
        else if (tmDist > 400.0) shapingReward += 1;  // good spacing
    }

    if (shapingReward == 0) return;

    // Only movement-family decisions get shaped by position. Clamp magnitude
    // to ±2 total so no single shaping event can outweigh a real deflect (+5).
    if (shapingReward >  2) shapingReward =  2;
    if (shapingReward < -2) shapingReward = -2;

    AdjustBrain(LastMoveKey[client],  LastMoveChoice[client],  shapingReward, DefMove,  5);
    AdjustBrain(LastOrbitKey[client], LastOrbitChoice[client], shapingReward, DefOrbit, 2);
}


void ComputeStateKey(int client, float speed, int botType) {
    int sTier = GetSpeedTier(speed);
    int dTier = GetDeflectTier();
    FormatEx(LastState[client], sizeof(LastState[]), "T_t%d_s%d_d%d", botType, sTier, dTier);
}

void InitDefaultWeights(int weights[NUM_TRICKS]) {
    for (int i = 0; i < NUM_TRICKS; i++) weights[i] = DefTrick[i];
}

// --- State key builders (include botType) ---

void BuildTrickKey(char[] out, int maxLen, int speedTier, int deflectTier, int botType, int opponentTendency = 0) {
    // opponentTendency (from GetOpponentTendency):
    //   0 = unknown / insufficient data
    //   1 = strafe-left-heavy
    //   2 = strafe-right-heavy
    //   3 = statue
    //   4 = aggressive-cqc
    // Adding this dimension lets the bot learn DIFFERENT trick preferences per
    // opponent class (e.g., side-flick vs strafers, downspike vs statues).
    // State space ~5x wider than before; existing T_*_s*_d* rows in SQL become
    // orphaned and will be re-learned organically in the new keyspace.
    FormatEx(out, maxLen, "T_t%d_s%d_d%d_o%d", botType, speedTier, deflectTier, opponentTendency);
}

void BuildOrbitKey(char[] out, int maxLen, int speedTier, int turnRateTier, int botType) {
    FormatEx(out, maxLen, "O_t%d_s%d_tr%d", botType, speedTier, turnRateTier);
}

void BuildMoveKey(char[] out, int maxLen, int speedTier, int distTier, int botType, int nearTeam = 0) {
    FormatEx(out, maxLen, "M_t%d_s%d_e%d_tm%d", botType, speedTier, distTier, nearTeam);
}

void BuildReactKey(char[] out, int maxLen, int speedTier, int botType) {
    FormatEx(out, maxLen, "R_t%d_s%d", botType, speedTier);
}

void BuildAimKey(char[] out, int maxLen, int speedTier, int deflectTier, int botType) {
    FormatEx(out, maxLen, "A_t%d_s%d_d%d", botType, speedTier, deflectTier);
}

void BuildEvadeKey(char[] out, int maxLen, int speedTier, int botType) {
    FormatEx(out, maxLen, "E_t%d_s%d", botType, speedTier);
}

// ============================================================================
// CONFIG LOADING
// ============================================================================

// Case-insensitive lowercase copy (used for class key normalization)
void StrLower(const char[] src, char[] dst, int maxLen) {
    int i = 0;
    for (; i < maxLen - 1 && src[i] != '\0'; i++) {
        int c = src[i];
        if (c >= 'A' && c <= 'Z') c += 32;
        dst[i] = view_as<char>(c);
    }
    dst[i] = '\0';
}

// Return the class index matching a name/key, or -1 if not found.
// Matches against both the lowercase key and the display name (case-insensitive).
int FindClassIndexByName(const char[] name) {
    if (name[0] == '\0') return -1;
    for (int i = 0; i < NumBotTypes; i++) {
        if (StrEqual(name, BotClassKey[i], false)) return i;
        if (StrEqual(name, BotDisplayName[i], false)) return i;
    }
    return -1;
}

// Fill [botType] config slots with safe defaults. Used before reading a class
// section, so missing keys fall back to sane values rather than zero.
void InitClassDefaults(int t) {
    CfgReactMin[t]            = 0.12;
    CfgReactMax[t]            = 0.28;
    CfgMaxOrbitTime[t]        = 2.0;
    CfgMaxOrbitLoops[t]       = 3;
    CfgAngleRandomChance[t]   = 30.0;
    CfgAngleRandomStrength[t] = 20.0;
    CfgEvadeChance[t]         = 40.0;
    CfgCqcFloorDist[t]        = 250.0;
    CfgCqcMinDist[t]          = 300.0;
    CfgCqcMaxDist[t]          = 600.0;
    CfgCqcRetreatDist[t]      = 250.0;
    CfgIdleChance[t]          = 40.0;
    CfgIdleDuration[t]        = 3.0;
    CfgLookAtPlayerTime[t]    = 1.5;
    ClassIsStatueLike[t]     = false;
    // Capabilities default ON — fallback class (see LoadPvBConfig error path)
    // gets all behaviors enabled. LoadSingleClass will demote to FALSE when a
    // class config removes the relevant keys.
    CfgCanOrbit[t]    = true;
    CfgCanEvade[t]    = true;
    CfgCanCqc[t]      = true;
    CfgCanIdle[t]     = true;
    CfgIdleAlways[t]  = false;
    BotNames[t][0]           = '\0';
    BotDisplayName[t][0]     = '\0';
    BotClassKey[t][0]        = '\0';
    SpeechPlayerDeath[t][0]  = '\0';
    SpeechBotDeath[t][0]     = '\0';
}

// Read the class section currently positioned at `kv` into slot `t`.
// The caller must have already JumpToKey'd into the class section.
void LoadSingleClass(KeyValues kv, int t, const char[] sectionKey) {
    InitClassDefaults(t);

    // Store the lowercase section key and a display name (falls back to key)
    StrLower(sectionKey, BotClassKey[t], sizeof(BotClassKey[]));

    char displayBuf[64];
    kv.GetString("display_name", displayBuf, sizeof(displayBuf), "");
    if (displayBuf[0] == '\0') {
        // Capitalize first letter of the key for nicer display
        strcopy(displayBuf, sizeof(displayBuf), sectionKey);
        if (displayBuf[0] >= 'a' && displayBuf[0] <= 'z') {
            displayBuf[0] -= 32;
        }
    }
    strcopy(BotDisplayName[t], sizeof(BotDisplayName[]), displayBuf);

    // Per-class bot scoreboard name (falls back to display name)
    kv.GetString("bot_name", BotNames[t], sizeof(BotNames[]), displayBuf);

    // LEARNABLE tunings
    CfgReactMin[t]            = kv.GetFloat("react_min", 0.12);
    CfgReactMax[t]            = kv.GetFloat("react_max", 0.28);
    CfgAngleRandomChance[t]   = float(kv.GetNum("angle_random_chance", 30));
    CfgAngleRandomStrength[t] = kv.GetFloat("angle_random_strength", 20.0);

    // -----------------------------------------------------------------------
    // Capability-by-presence detection.
    // KV readers return 0 / 0.0 when a key is absent. All our capability
    // values are strictly positive in normal use, so "value <= 0" cleanly
    // means "key absent OR explicitly disabled" — treated identically.
    // -----------------------------------------------------------------------

    // --- Orbit capability ---
    float orbitTime    = kv.GetFloat("orbit_time",      0.0);
    int   orbitLoops   = kv.GetNum("orbit_max_loops",   0);
    int   orbitChance  = kv.GetNum("orbit_chance",      0);  // used only as presence marker
    CfgCanOrbit[t]      = (orbitTime > 0.0) || (orbitLoops > 0) || (orbitChance > 0);
    CfgMaxOrbitTime[t]  = (orbitTime > 0.0) ? orbitTime  : 2.0;
    CfgMaxOrbitLoops[t] = (orbitLoops > 0)  ? orbitLoops : 3;

    // --- Evade capability ---
    int evadeChance    = kv.GetNum("evade_chance", 0);
    CfgCanEvade[t]     = (evadeChance > 0);
    CfgEvadeChance[t]  = float(evadeChance);

    // --- CQC capability (any one key triggers CQC-aware movement) ---
    float cqcFloor    = kv.GetFloat("cqc_floor_dist",   0.0);
    float cqcMin      = kv.GetFloat("cqc_min_dist",     0.0);
    float cqcMax      = kv.GetFloat("cqc_max_dist",     0.0);
    float cqcRetreat  = kv.GetFloat("cqc_retreat_dist", 0.0);
    CfgCanCqc[t]      = (cqcFloor > 0.0) || (cqcMin > 0.0) || (cqcMax > 0.0) || (cqcRetreat > 0.0);
    CfgCqcFloorDist[t]   = (cqcFloor   > 0.0) ? cqcFloor   : 250.0;
    CfgCqcMinDist[t]     = (cqcMin     > 0.0) ? cqcMin     : 300.0;
    CfgCqcMaxDist[t]     = (cqcMax     > 0.0) ? cqcMax     : 600.0;
    CfgCqcRetreatDist[t] = (cqcRetreat > 0.0) ? cqcRetreat : 250.0;

    // --- Idle capability + idle-always mode ---
    int idleChance     = kv.GetNum("idle_chance", 0);
    CfgCanIdle[t]      = (idleChance > 0);
    CfgIdleChance[t]   = float(idleChance);
    CfgIdleAlways[t]   = (idleChance >= 100);
    CfgIdleDuration[t] = kv.GetFloat("idle_duration", 3.0);

    CfgLookAtPlayerTime[t]    = kv.GetFloat("look_at_player_time", 1.5);

    // "statue_like" flag: forces this class into permanent idle movement mode.
    // Auto-detected for backward compat when the lowercase key contains "statue".
    bool statueLike = (kv.GetNum("statue_like", 0) != 0);
    if (!statueLike && StrContains(BotClassKey[t], "statue") != -1) {
        statueLike = true;
    }
    ClassIsStatueLike[t] = statueLike;

    // Sanity enforcement
    if (CfgCqcRetreatDist[t] < CfgCqcFloorDist[t]) {
        CfgCqcRetreatDist[t] = CfgCqcFloorDist[t];
    }
    if (CfgCqcMinDist[t] < CfgCqcFloorDist[t]) {
        CfgCqcMinDist[t] = CfgCqcFloorDist[t] + 50.0;
    }
}

void LoadPvBConfig() {
    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/dodgeball/pvb.cfg");

    KeyValues kv = new KeyValues("PvB");
    if (!kv.ImportFromFile(configPath)) {
        LogError("[PvB] Could not load config file: %s", configPath);
        delete kv;
        // Fall back to a single universal default so the plugin still works
        NumBotTypes = 1;
        InitClassDefaults(0);
        strcopy(BotClassKey[0], sizeof(BotClassKey[]), "universal");
        strcopy(BotDisplayName[0], sizeof(BotDisplayName[]), "Universal");
        strcopy(BotNames[0], sizeof(BotNames[]), "Mann Co. Bot");
        strcopy(BotName, sizeof(BotName), BotNames[0]);
        CfgBotType = 0;
        BotNameDirty = true;
        return;
    }

    // --- Phase 1: read global "settings" section ---
    char requestedType[32] = "0";
    if (kv.JumpToKey("settings")) {
        CfgEnabled      = (kv.GetNum("enabled", 1) != 0);
        VoteMaxPlayers = kv.GetNum("vote_max_players", 12);
        CfgMinPlayers   = kv.GetNum("min_players", 1);
        CfgMaxPlayers   = kv.GetNum("max_players", 2);
        CfgSpeech       = (kv.GetNum("speech", 1) != 0);
        kv.GetString("bot_type", requestedType, sizeof(requestedType), "0");

        // Adaptive learning toggles (all default ON)
        CfgLearnReactionTime = (kv.GetNum("learn_reaction_time", 1) != 0);
        CfgRememberOpponents = (kv.GetNum("remember_opponents",  1) != 0);
        CfgUseHeatmap        = (kv.GetNum("use_heatmap",         1) != 0);
        CfgMaxTrainingBots   = kv.GetNum("max_training_bots",   16);
        if (CfgMaxTrainingBots < 2)  CfgMaxTrainingBots = 2;
        if (CfgMaxTrainingBots > 30) CfgMaxTrainingBots = 30;
        kv.GoBack();
    }

    // --- Phase 2: iterate "classes" section and load every class we find ---
    NumBotTypes = 0;

    // Clear taunt ArrayLists (they are pre-allocated in OnPluginStart)
    for (int t = 0; t < MAX_BOT_TYPES; t++) {
        if (TauntsPlayerDeath[t] != null) TauntsPlayerDeath[t].Clear();
        if (TauntsBotDeath[t] != null)    TauntsBotDeath[t].Clear();
    }

    // Per-settings legacy name overrides (only honored when a class with the
    // matching key exists). We collect them here and apply after class load.
    char legacyNames[4][MAX_NAME_LENGTH];
    char legacyKeys[4][16];
    strcopy(legacyKeys[0], sizeof(legacyKeys[]), "universal");
    strcopy(legacyKeys[1], sizeof(legacyKeys[]), "statue");
    strcopy(legacyKeys[2], sizeof(legacyKeys[]), "midrange");
    strcopy(legacyKeys[3], sizeof(legacyKeys[]), "aggressive");
    if (kv.JumpToKey("settings")) {
        kv.GetString("bot_name_universal",  legacyNames[0], sizeof(legacyNames[]), "");
        kv.GetString("bot_name_statue",     legacyNames[1], sizeof(legacyNames[]), "");
        kv.GetString("bot_name_midrange",   legacyNames[2], sizeof(legacyNames[]), "");
        kv.GetString("bot_name_aggressive", legacyNames[3], sizeof(legacyNames[]), "");
        kv.GoBack();
    }

    if (kv.JumpToKey("classes")) {
        if (kv.GotoFirstSubKey()) {
            do {
                if (NumBotTypes >= MAX_BOT_TYPES) {
                    LogError("[PvB] Too many classes in config (max %d), stopping", MAX_BOT_TYPES);
                    break;
                }
                char secName[32];
                if (!kv.GetSectionName(secName, sizeof(secName))) continue;
                if (secName[0] == '\0') continue;

                LoadSingleClass(kv, NumBotTypes, secName);
                LogMessage("[PvB] Loaded class [%d] '%s' -> %s",
                    NumBotTypes, BotClassKey[NumBotTypes], BotNames[NumBotTypes]);
                NumBotTypes++;
            } while (kv.GotoNextKey());
            kv.GoBack(); // undo GotoFirstSubKey
        }
        kv.GoBack(); // undo JumpToKey("classes")
    }

    // If the config had no classes section or an empty one, synthesize a default
    if (NumBotTypes == 0) {
        InitClassDefaults(0);
        strcopy(BotClassKey[0], sizeof(BotClassKey[]), "universal");
        strcopy(BotDisplayName[0], sizeof(BotDisplayName[]), "Universal");
        strcopy(BotNames[0], sizeof(BotNames[]), "Mann Co. Bot");
        NumBotTypes = 1;
        LogMessage("[PvB] No classes in config, synthesized 'universal' default");
    }

    // Apply legacy bot_name_* overrides to matching classes
    for (int i = 0; i < 4; i++) {
        if (legacyNames[i][0] == '\0') continue;
        int idx = FindClassIndexByName(legacyKeys[i]);
        if (idx >= 0) {
            strcopy(BotNames[idx], sizeof(BotNames[]), legacyNames[i]);
        }
    }

    // --- Phase 3: resolve active class from "bot_type" setting ---
    // Accepts numeric index OR class key name (case-insensitive)
    int resolved = -1;
    if (requestedType[0] >= '0' && requestedType[0] <= '9') {
        int asInt = StringToInt(requestedType);
        if (asInt >= 0 && asInt < NumBotTypes) resolved = asInt;
    }
    if (resolved < 0) resolved = FindClassIndexByName(requestedType);
    if (resolved < 0) resolved = 0;
    CfgBotType = resolved;

    // --- Phase 4: per-class speech files ---
    LoadSpeechConfig(kv);

    delete kv;

    strcopy(BotName, sizeof(BotName), BotNames[CfgBotType]);
    BotNameDirty = true;
    LogMessage("[PvB] Active class: [%d] %s (%s)",
        CfgBotType, BotClassKey[CfgBotType], BotNames[CfgBotType]);
}

// Switch active class at runtime. All per-class settings are already loaded
// into arrays, so this just flips the index and updates the bot name.
void LoadBotTypeSettings(int botType) {
    if (botType < 0 || botType >= NumBotTypes) {
        LogError("[PvB] LoadBotTypeSettings: invalid index %d (have %d classes)", botType, NumBotTypes);
        return;
    }
    CfgBotType = botType;
    strcopy(BotName, sizeof(BotName), BotNames[botType]);
    BotNameDirty = true;
    LogMessage("[PvB] Switched to class [%d] %s", botType, BotClassKey[botType]);
}

// Load speech files per bot type. Uses each class's lowercase key to look up
// "<key>_playerdeath" and "<key>_botdeath" entries in the "speech" section.
// Defaults fall back to the shipped universal taunts so a missing/incomplete
// "speech" section degrades gracefully instead of silently logging open errors.
void LoadSpeechConfig(KeyValues kv) {
    char defaultPlayerDeath[PLATFORM_MAX_PATH] = "configs/dodgeball/speech/speech_universal_kill.txt";
    char defaultBotDeath[PLATFORM_MAX_PATH]    = "configs/dodgeball/speech/speech_universal_death.txt";

    // ArrayLists were already cleared in LoadPvBConfig
    bool haveSpeechSection = kv.JumpToKey("speech");

    for (int t = 0; t < NumBotTypes; t++) {
        char playerDeathPath[PLATFORM_MAX_PATH];
        char botDeathPath[PLATFORM_MAX_PATH];
        strcopy(playerDeathPath, sizeof(playerDeathPath), defaultPlayerDeath);
        strcopy(botDeathPath, sizeof(botDeathPath), defaultBotDeath);

        if (haveSpeechSection) {
            char keyPlayerDeath[96], keyBotDeath[96];
            FormatEx(keyPlayerDeath, sizeof(keyPlayerDeath), "%s_playerdeath", BotClassKey[t]);
            FormatEx(keyBotDeath,    sizeof(keyBotDeath),    "%s_botdeath",    BotClassKey[t]);
            kv.GetString(keyPlayerDeath, playerDeathPath, sizeof(playerDeathPath), defaultPlayerDeath);
            kv.GetString(keyBotDeath,    botDeathPath,    sizeof(botDeathPath),    defaultBotDeath);
        }

        // Pre-flight existence check with resolved SM path, fall back to
        // universal if the configured file is missing. BuildPath + FileExists
        // is the idiomatic SM 1.12 pattern for config-driven file loading.
        char resolved[PLATFORM_MAX_PATH];
        BuildPath(Path_SM, resolved, sizeof(resolved), playerDeathPath);
        if (!FileExists(resolved)) {
            LogMessage("[PvB] speech file missing for %s_playerdeath: %s — using universal fallback",
                BotClassKey[t], playerDeathPath);
            strcopy(playerDeathPath, sizeof(playerDeathPath), defaultPlayerDeath);
        }
        BuildPath(Path_SM, resolved, sizeof(resolved), botDeathPath);
        if (!FileExists(resolved)) {
            LogMessage("[PvB] speech file missing for %s_botdeath: %s — using universal fallback",
                BotClassKey[t], botDeathPath);
            strcopy(botDeathPath, sizeof(botDeathPath), defaultBotDeath);
        }

        strcopy(SpeechPlayerDeath[t], sizeof(SpeechPlayerDeath[]), playerDeathPath);
        strcopy(SpeechBotDeath[t],    sizeof(SpeechBotDeath[]),    botDeathPath);

        LoadTauntFile(playerDeathPath, TauntsPlayerDeath[t]);
        LoadTauntFile(botDeathPath,    TauntsBotDeath[t]);
    }

    if (haveSpeechSection) kv.GoBack();
}

// ============================================================================
// PERSISTENT DEBUG SYSTEM - Commands and Logging
// ============================================================================

public Action Cmd_BotDebug(int client, int args) {
    if (DebugActive) {
        StopDebugLogging();
        CReplyToCommand(client, "[PvB] Debug logging STOPPED. %d lines -> %s", DebugLinesWritten, DebugLogPath);
        return Plugin_Handled;
    }

    // Parse optional sample rate: sm_botdebug [rate]
    if (args >= 1) {
        char arg[16];
        GetCmdArg(1, arg, sizeof(arg));
        int rate = StringToInt(arg);
        if (rate >= 1 && rate <= 66) DebugSampleRate = rate;
    }

    // Fresh user-initiated session — reset cumulative-line counter so the hard
    // cap measures THIS session, not the previous one. (RotateDebugFile also
    // calls StartDebugLogging but must NOT reset DebugTotalLines, otherwise the
    // hard cap would never trigger across rotations.)
    DebugTotalLines = 0;
    StartDebugLogging();
    CReplyToCommand(client, "[PvB] Debug logging STARTED (every %d ticks). sm_stopdebug to stop.", DebugSampleRate);
    CReplyToCommand(client, "[PvB] Log: %s", DebugLogPath);
    return Plugin_Handled;
}

public Action Cmd_StopDebug(int client, int args) {
    if (!DebugActive) {
        CReplyToCommand(client, "[PvB] Debug logging is not active.");
        return Plugin_Handled;
    }
    StopDebugLogging();
    CReplyToCommand(client, "[PvB] Debug logging STOPPED. %d lines -> %s", DebugLinesWritten, DebugLogPath);
    return Plugin_Handled;
}

// ============================================================================
// BRAIN INSPECTION COMMANDS
// Expose what the bot has learned to admins. All ROOT because raw policy
// weights and SteamID-keyed opponent profiles are sensitive. Output goes to
// admin's console (via ReplyToCommand) — no chat spam.
//
// See subplugins/PvB-brain-inspection.md for usage examples.
// ============================================================================

public Action Cmd_BrainStats(int client, int args) {
    if (BrainMemory == null) {
        ReplyToCommand(client, "[PvB][BrainStats] BrainMemory not initialized.");
        return Plugin_Handled;
    }

    // Bucket BrainMemory keys by builder prefix. Format reference (BuildXXXKey):
    //   M_ = move (5 options), T_ = trick (7), E_ = evade (3), O_ = orbit (2),
    //   R_ = react, A_ = aim. Shared-base keys contain "_shared" instead of
    //   "_t<bot>" (DeriveSharedKey replaces the bot-type token).
    int moveCount = 0, trickCount = 0, evadeCount = 0, orbitCount = 0;
    int reactCount = 0, aimCount = 0, sharedCount = 0, otherCount = 0;
    StringMapSnapshot snap = BrainMemory.Snapshot();
    int total = snap.Length;
    char buf[64];
    for (int i = 0; i < total; i++) {
        snap.GetKey(i, buf, sizeof(buf));

        // Check for "_shared" first — it's a sub-variant of any policy family.
        bool isShared = (StrContains(buf, "_shared", false) >= 0);
        if (isShared) sharedCount++;

        // Family bucket from the leading prefix. M_, T_, etc. are case-sensitive
        // (uppercase per BuildXXXKey FormatEx templates).
        if      (StrContains(buf, "M_", true) == 0) moveCount++;
        else if (StrContains(buf, "T_", true) == 0) trickCount++;
        else if (StrContains(buf, "E_", true) == 0) evadeCount++;
        else if (StrContains(buf, "O_", true) == 0) orbitCount++;
        else if (StrContains(buf, "R_", true) == 0) reactCount++;
        else if (StrContains(buf, "A_", true) == 0) aimCount++;
        else                                        otherCount++;
    }
    delete snap;

    int heatmapSize = (HeatmapCells != null) ? HeatmapCells.Size : 0;

    ReplyToCommand(client, "[PvB][BrainStats] === Brain Snapshot ===");
    ReplyToCommand(client, "[PvB][BrainStats] BrainMemory: %d total keys", total);
    ReplyToCommand(client, "[PvB][BrainStats]   M_ move policy:   %d", moveCount);
    ReplyToCommand(client, "[PvB][BrainStats]   T_ trick policy:  %d", trickCount);
    ReplyToCommand(client, "[PvB][BrainStats]   E_ evade policy:  %d", evadeCount);
    ReplyToCommand(client, "[PvB][BrainStats]   O_ orbit policy:  %d", orbitCount);
    ReplyToCommand(client, "[PvB][BrainStats]   R_ react policy:  %d", reactCount);
    ReplyToCommand(client, "[PvB][BrainStats]   A_ aim policy:    %d", aimCount);
    ReplyToCommand(client, "[PvB][BrainStats]   _shared base:     %d (overlaps families)", sharedCount);
    ReplyToCommand(client, "[PvB][BrainStats]   other/unknown:    %d", otherCount);
    ReplyToCommand(client, "[PvB][BrainStats] HeatmapCells: %d", heatmapSize);

    if (BrainDB != null) {
        // Async COUNT for opponent rows. Reply lands later in the handler.
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        BrainDB.Query(SQL_BrainStatsOpponentCount,
            "SELECT COUNT(*) FROM bot_opponent_v1", pack);
    } else {
        ReplyToCommand(client, "[PvB][BrainStats] BrainDB: not connected (in-memory only).");
    }

    return Plugin_Handled;
}

public void SQL_BrainStatsOpponentCount(Database db, DBResultSet rs, const char[] error, DataPack pack) {
    pack.Reset();
    int userid = pack.ReadCell();
    delete pack;

    int caller = GetClientOfUserId(userid);
    if (caller == 0) return;  // admin disconnected; SQL still finished, just don't reply

    if (rs == null || error[0]) {
        ReplyToCommand(caller, "[PvB][BrainStats] opponent count query failed: %s", error);
        return;
    }
    if (rs.FetchRow()) {
        ReplyToCommand(caller, "[PvB][BrainStats] opponent profiles: %d", rs.FetchInt(0));
    }
}

public Action Cmd_BrainShow(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[PvB][BrainShow] Usage: sm_brainshow <key>");
        ReplyToCommand(client, "[PvB][BrainShow] Examples:");
        ReplyToCommand(client, "[PvB][BrainShow]   M_t2_s1_e1_tm0   (move: tier_speed_enemy_teammate)");
        ReplyToCommand(client, "[PvB][BrainShow]   T_t2_s1_d1_o0    (trick: tier_speed_deflects_opponent)");
        ReplyToCommand(client, "[PvB][BrainShow]   E_t2_s1          (evade: tier_speed)");
        ReplyToCommand(client, "[PvB][BrainShow]   O_t2_s1_tr1      (orbit: tier_speed_traversal)");
        ReplyToCommand(client, "[PvB][BrainShow]   R_t2_s1, A_t2_s1_d1 (react/aim)");
        ReplyToCommand(client, "[PvB][BrainShow] Shared-base variants replace _t<bot> with _shared.");
        return Plugin_Handled;
    }
    if (BrainMemory == null) {
        ReplyToCommand(client, "[PvB][BrainShow] BrainMemory not initialized.");
        return Plugin_Handled;
    }

    char key[64];
    GetCmdArg(1, key, sizeof(key));

    int weights[MAX_BRAIN_OPTIONS];
    if (!BrainMemory.GetArray(key, weights, MAX_BRAIN_OPTIONS)) {
        ReplyToCommand(client, "[PvB][BrainShow] key '%s' not found in brain (untrained or wrong format).", key);
        return Plugin_Handled;
    }

    // Pretty-print weights with the right semantic labels based on prefix.
    static const char moveNames[5][]  = { "WANDER", "APPROACH", "MIRROR", "CIRCLE", "IDLE" };
    static const char trickNames[7][] = { "NONE", "L_FLICK", "R_FLICK", "DOWN_SPIKE", "UP_SPIKE", "WAVE", "SPIN" };
    static const char evadeNames[3][] = { "NONE", "JUMP", "CROUCH" };
    static const char orbitNames[2][] = { "NO", "YES" };

    int numOpts = MAX_BRAIN_OPTIONS;
    // Match the actual BuildXXXKey format: leading uppercase letter + underscore.
    bool isMove  = (StrContains(key, "M_", true) == 0);
    bool isTrick = (StrContains(key, "T_", true) == 0);
    bool isEvade = (StrContains(key, "E_", true) == 0);
    bool isOrbit = (StrContains(key, "O_", true) == 0);
    if      (isMove)  numOpts = 5;
    else if (isTrick) numOpts = 7;
    else if (isEvade) numOpts = 3;
    else if (isOrbit) numOpts = 2;
    // R_ react and A_ aim families fall through with default MAX_BRAIN_OPTIONS;
    // labels show as opt0..optN (no semantic names defined).

    int total = 0;
    for (int i = 0; i < numOpts; i++) total += weights[i];

    ReplyToCommand(client, "[PvB][BrainShow] key='%s' total_weight=%d", key, total);
    for (int i = 0; i < numOpts; i++) {
        char name[16];
        if      (isMove  && i < 5) strcopy(name, sizeof(name), moveNames[i]);
        else if (isTrick && i < 7) strcopy(name, sizeof(name), trickNames[i]);
        else if (isEvade && i < 3) strcopy(name, sizeof(name), evadeNames[i]);
        else if (isOrbit && i < 2) strcopy(name, sizeof(name), orbitNames[i]);
        else                       FormatEx(name, sizeof(name), "opt%d", i);
        float pct = (total > 0) ? (float(weights[i]) / float(total) * 100.0) : 0.0;
        ReplyToCommand(client, "[PvB][BrainShow]   [%d] %-12s weight=%4d (%.1f%%)", i, name, weights[i], pct);
    }
    return Plugin_Handled;
}

public Action Cmd_BrainOpponent(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "[PvB][BrainOpponent] Usage: sm_brainopponent <#userid|name>");
        return Plugin_Handled;
    }
    if (BrainDB == null) {
        ReplyToCommand(client, "[PvB][BrainOpponent] BrainDB not connected.");
        return Plugin_Handled;
    }

    char arg[64];
    GetCmdArg(1, arg, sizeof(arg));
    int target = FindTarget(client, arg, true, false);
    if (target == -1) return Plugin_Handled;

    // Get account ID (the brain stores 32-bit Steam2 account IDs).
    int accountId = GetSteamAccountID(target);
    if (accountId == 0) {
        ReplyToCommand(client, "[PvB][BrainOpponent] %N has no SteamID (probably bot or unauth'd).", target);
        return Plugin_Handled;
    }

    char query[256];
    FormatEx(query, sizeof(query),
        "SELECT strafe_left, strafe_right, stood_still, jumped, crouched, " ...
        "cqc_approach, cqc_retreat, total_deflects, total_kills, total_deaths, avg_deflect_speed " ...
        "FROM bot_opponent_v1 WHERE steam_id=%d", accountId);

    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(GetClientUserId(target));
    BrainDB.Query(SQL_BrainOpponentResult, query, pack);

    return Plugin_Handled;
}

public void SQL_BrainOpponentResult(Database db, DBResultSet rs, const char[] error, DataPack pack) {
    pack.Reset();
    int callerUid = pack.ReadCell();
    int targetUid = pack.ReadCell();
    delete pack;

    int caller = GetClientOfUserId(callerUid);
    int target = GetClientOfUserId(targetUid);
    if (caller == 0) return;

    if (rs == null || error[0]) {
        ReplyToCommand(caller, "[PvB][BrainOpponent] query failed: %s", error);
        return;
    }
    if (!rs.FetchRow()) {
        ReplyToCommand(caller, "[PvB][BrainOpponent] no profile stored for that player.");
        return;
    }

    int strafeL = rs.FetchInt(0), strafeR = rs.FetchInt(1), stood = rs.FetchInt(2);
    int jumped  = rs.FetchInt(3), crouched = rs.FetchInt(4);
    int cqcA    = rs.FetchInt(5), cqcR    = rs.FetchInt(6);
    int defl    = rs.FetchInt(7), kills   = rs.FetchInt(8), deaths = rs.FetchInt(9);
    float avgSpd = rs.FetchFloat(10);

    // Tendency = argmax of the 5 movement dimensions
    int tendencies[5];
    tendencies[0] = strafeL; tendencies[1] = strafeR; tendencies[2] = stood;
    tendencies[3] = jumped;  tendencies[4] = crouched;
    int topIdx = 0;
    for (int i = 1; i < 5; i++) if (tendencies[i] > tendencies[topIdx]) topIdx = i;
    static const char tendNames[5][] = { "STRAFE_LEFT", "STRAFE_RIGHT", "STATUE", "JUMPER", "CROUCHER" };

    char nameStr[MAX_NAME_LENGTH];
    if (target > 0) GetClientName(target, nameStr, sizeof(nameStr));
    else            strcopy(nameStr, sizeof(nameStr), "<disconnected>");

    ReplyToCommand(caller, "[PvB][BrainOpponent] === %s ===", nameStr);
    ReplyToCommand(caller, "[PvB][BrainOpponent] Tendency: %s (top=%d)", tendNames[topIdx], tendencies[topIdx]);
    ReplyToCommand(caller, "[PvB][BrainOpponent] Movement: L=%d R=%d still=%d jump=%d crouch=%d", strafeL, strafeR, stood, jumped, crouched);
    ReplyToCommand(caller, "[PvB][BrainOpponent] CQC bias: approach=%d retreat=%d (delta=%+d)", cqcA, cqcR, cqcA - cqcR);
    ReplyToCommand(caller, "[PvB][BrainOpponent] Lifetime: %d deflects, %d kills, %d deaths (KDR=%.2f)",
        defl, kills, deaths, deaths > 0 ? float(kills) / float(deaths) : float(kills));
    ReplyToCommand(caller, "[PvB][BrainOpponent] Avg deflect speed: %.0f HU/s", avgSpd);
}

public Action Cmd_BrainHeatmap(int client, int args) {
    if (HeatmapCells == null || HeatmapCells.Size == 0) {
        ReplyToCommand(client, "[PvB][BrainHeatmap] heatmap is empty for this map.");
        return Plugin_Handled;
    }

    int filterType = -1;  // -1 = all classes
    if (args >= 1) {
        char arg[16];
        GetCmdArg(1, arg, sizeof(arg));
        filterType = StringToInt(arg);
        if (filterType < 0 || filterType >= NumBotTypes) {
            ReplyToCommand(client, "[PvB][BrainHeatmap] invalid bot_type %d (have %d types).", filterType, NumBotTypes);
            return Plugin_Handled;
        }
    }

    // Open log file timestamped. Write all matching cells with sortable score
    // (deaths-deflects). Console gets a brief summary.
    char timestamp[32], path[PLATFORM_MAX_PATH];
    FormatTime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S");
    BuildPath(Path_SM, path, sizeof(path), "logs/tfdb_pvb/heatmap_%s_%s.log", CurrentMap, timestamp);

    File f = OpenFile(path, "w");
    if (f == null) {
        ReplyToCommand(client, "[PvB][BrainHeatmap] could not open log file: %s", path);
        return Plugin_Handled;
    }
    f.WriteLine("=== HEATMAP DUMP map=%s filter=%d at %s ===", CurrentMap, filterType, timestamp);
    f.WriteLine("# format: bot_type gx gy deflects deaths score(deaths-deflects)");

    int written = 0;
    StringMapSnapshot snap = HeatmapCells.Snapshot();
    char key[64];
    int data[2];
    for (int i = 0; i < snap.Length; i++) {
        snap.GetKey(i, key, sizeof(key));
        // Key format: "<map>_<botType>_<gx>_<gy>" — split.
        // Skip cells whose map prefix doesn't match current map (defensive).
        if (StrContains(key, CurrentMap, false) != 0) continue;
        if (!HeatmapCells.GetArray(key, data, 2)) continue;

        int score = data[1] - data[0];  // deaths minus deflects
        // Per-class filter
        if (filterType >= 0) {
            char prefix[64];
            FormatEx(prefix, sizeof(prefix), "%s_%d_", CurrentMap, filterType);
            if (StrContains(key, prefix, false) != 0) continue;
        }
        f.WriteLine("%s deflects=%d deaths=%d score=%d", key, data[0], data[1], score);
        written++;
    }
    delete snap;
    f.WriteLine("=== END (%d cells written) ===", written);
    delete f;

    ReplyToCommand(client, "[PvB][BrainHeatmap] wrote %d cells to %s", written, path);
    return Plugin_Handled;
}

void StartDebugLogging() {
    char timestamp[32];
    FormatTime(timestamp, sizeof(timestamp), "%Y%m%d_%H%M%S");
    BuildPath(Path_SM, DebugLogPath, sizeof(DebugLogPath), "logs/tfdb_pvb/debug_%s.log", timestamp);

    // Open file handle for high-frequency writes (File.WriteLine doesn't spam console)
    DebugFile = OpenFile(DebugLogPath, "a");
    if (DebugFile == null) {
        LogError("[PvB] Could not open debug log: %s", DebugLogPath);
        return;
    }

    // Write header
    DebugFile.WriteLine("=== PVB DEBUG START === map=%s rate=%d ===", CurrentMap, DebugSampleRate);
    DebugFile.WriteLine("FORMAT: [TICK] #clientIdx name team=(2R/3B) (type alive) | pos(x y z) | move=MODE blend(idle toward circle away) | look=STATE(aimDampen) | rocket(ent mine=targeted tgtcl=actualTarget dist spd approach=headingToMe) | orbit(active/phase) | trick=NAME(applying) | danger | enemy=#idx(dist) | teammate=name(dist) | react=airblastDist | vel(x y) | ang(pitch yaw) | btn=MOETR | EVENT");
    DebugFile.WriteLine("DECISION events: MoveMode (M_*), Trick (T_*), Evade (E_*), Orbit (O_*), Aim (A_*), React (R_*). Each prints brain key + sTier + chosen option.");
    DebugFile.WriteLine("[REWARD] events: brain weight adjustment. Format: key=<...> opt=N adj=+/-N weight=OLD->NEW seeded=0/1 (1 = key was already in BrainMemory). Zero REWARD lines + many DECISION lines = learning loop broken.");

    DebugActive = true;
    for (int i = 1; i <= MaxClients; i++) BotDebugTick[i] = 0;
    DebugLinesWritten = 0;
    PrintToServer("[PvB] Debug logging started: %s", DebugLogPath);
}

void StopDebugLogging() {
    if (DebugActive && DebugFile != null) {
        DebugFile.WriteLine("=== PVB DEBUG STOP === lines=%d ===", DebugLinesWritten);
    }
    delete DebugFile;
    DebugFile = null;
    DebugActive = false;
    PrintToServer("[PvB] Debug logging stopped. %d lines written.", DebugLinesWritten);
}

void RotateDebugFile() {
    StopDebugLogging();
    StartDebugLogging();
}

// Shared post-write bookkeeping: bumps line counters, enforces the hard cap
// (auto-stops logging if the user forgot sm_stopdebug — otherwise rotated
// files would grow unbounded), then rotates the current file at DEBUG_MAX_LINES.
// Call after every DebugFile.WriteLine() that participates in the line budget.
void DebugBumpLineCount() {
    DebugLinesWritten++;
    DebugTotalLines++;

    if (DebugTotalLines >= DEBUG_MAX_TOTAL_LINES) {
        PrintToServer("[PvB] Debug log hit hard cap (%d lines) — auto-stopping. Use sm_stopdebug next time.", DEBUG_MAX_TOTAL_LINES);
        StopDebugLogging();
        return;
    }

    if (DebugLinesWritten >= DEBUG_MAX_LINES) {
        RotateDebugFile();
    }
}

// Called from OnPlayerRunCmd for each bot every DebugSampleRate ticks.
// Captures a complete snapshot of the bot's decision state.
void DebugLogBotState(int client, float vel[3], float angles[3], const char[] event) {
    if (!DebugActive || DebugFile == null) return;

    int botType = GetEffectiveBotType(client);
    char botName[32];
    GetClientName(client, botName, sizeof(botName));

    float pos[3];
    GetClientAbsOrigin(client, pos);

    int team = GetClientTeam(client);

    // Rocket info
    int rocketEnt = GetCachedRocketForClient(client);
    float rocketDist = -1.0;
    float rocketSpeed = 0.0;
    bool rocketTargeted = false;
    int rocketTargetClient = -1;
    bool rocketApproaching = false;
    if (rocketEnt != -1) {
        float rPos[3];
        GetEntPropVector(rocketEnt, Prop_Data, "m_vecOrigin", rPos);
        float eyePos[3];
        GetClientEyePosition(client, eyePos);
        rocketDist = GetVectorDistance(eyePos, rPos);

        float rVel[3];
        GetEntPropVector(rocketEnt, Prop_Data, "m_vecAbsVelocity", rVel);
        rocketSpeed = GetVectorLength(rVel);

        rocketTargeted = IsRocketTargetingClient(rocketEnt, client);

        // Who does the rocket actually target?
        #if defined _tfdb_included
        if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
            int rIdx = TFDB_FindRocketByEntity(rocketEnt);
            if (rIdx != -1) {
                rocketTargetClient = TFDB_GetRocketTarget(rIdx);
            }
        }
        #endif

        // Is the rocket heading toward or away from us?
        float toMe[3];
        SubtractVectors(eyePos, rPos, toMe);
        NormalizeVector(toMe, toMe);
        rocketApproaching = (GetVectorDotProduct(rVel, toMe) > 0.0);
    }

    // Enemy info
    int enemy = TargetEnemy[client];
    float enemyDist = -1.0;
    if (enemy > 0 && enemy <= MaxClients && IsClientInGame(enemy) && IsPlayerAlive(enemy)) {
        float ePos[3], bPos[3];
        GetClientAbsOrigin(enemy, ePos);
        GetClientAbsOrigin(client, bPos);
        enemyDist = GetVectorDistance(bPos, ePos);
    }

    // Nearest same-team bot + distance (clustering detection)
    int nearTeammate = -1;
    float nearTmDist = 99999.0;
    for (int t = 1; t <= MaxClients; t++) {
        if (t == client) continue;
        if (!IsClientInGame(t) || !IsFakeClient(t) || !IsPlayerAlive(t)) continue;
        if (GetClientTeam(t) != team) continue;
        float tmPos[3];
        GetClientAbsOrigin(t, tmPos);
        float d = GetVectorDistance(pos, tmPos);
        if (d < nearTmDist) {
            nearTmDist = d;
            nearTeammate = t;
        }
    }

    // Heatmap danger at bot's current position
    float danger = 0.5;
    if (CfgUseHeatmap && botType >= 0 && botType < NumBotTypes) {
        danger = HeatmapDangerAt(botType, pos);
    }

    // Look state names
    char lookName[16];
    switch (CurrentLookState[client]) {
        case LOOK_ROCKET: strcopy(lookName, sizeof(lookName), "rocket");
        case LOOK_PLAYER: strcopy(lookName, sizeof(lookName), "player");
        case LOOK_IDLE:   strcopy(lookName, sizeof(lookName), "idle");
        default:          strcopy(lookName, sizeof(lookName), "unknown");
    }

    // Move mode names
    char moveName[16];
    switch (CurrentMoveMode[client]) {
        case MOVE_WANDER:   strcopy(moveName, sizeof(moveName), "wander");
        case MOVE_APPROACH: strcopy(moveName, sizeof(moveName), "approach");
        case MOVE_MIRROR:   strcopy(moveName, sizeof(moveName), "mirror");
        case MOVE_CIRCLE:   strcopy(moveName, sizeof(moveName), "circle");
        case MOVE_IDLE:     strcopy(moveName, sizeof(moveName), "idle");
        default:            strcopy(moveName, sizeof(moveName), "unknown");
    }

    // Trick names
    char trickName[16];
    switch (Trick[client]) {
        case TRICK_NONE:        strcopy(trickName, sizeof(trickName), "none");
        case TRICK_LEFT_FLICK:  strcopy(trickName, sizeof(trickName), "left_flick");
        case TRICK_RIGHT_FLICK: strcopy(trickName, sizeof(trickName), "right_flick");
        case TRICK_DOWN_SPIKE:  strcopy(trickName, sizeof(trickName), "down_spike");
        case TRICK_UP_SPIKE:    strcopy(trickName, sizeof(trickName), "up_spike");
        case TRICK_WAVE:        strcopy(trickName, sizeof(trickName), "wave");
        case TRICK_SPIN:        strcopy(trickName, sizeof(trickName), "spin");
        default:                strcopy(trickName, sizeof(trickName), "unknown");
    }

    // Build button flags string
    char btnStr[32];
    FormatEx(btnStr, sizeof(btnStr), "%s%s%s%s%s",
        (vel[0] != 0.0 || vel[1] != 0.0) ? "M" : "-",  // Moving
        (Orbiting[client]) ? "O" : "-",                   // Orbiting
        (Evading[client]) ? "E" : "-",                    // Evading
        (ApplyingTrick[client]) ? "T" : "-",              // Tricking
        (HasRocket[client]) ? "R" : "-");                  // Has rocket

    // Nearest teammate name for clustering visibility
    char tmName[32];
    if (nearTeammate > 0 && nearTeammate <= MaxClients && IsClientInGame(nearTeammate)) {
        GetClientName(nearTeammate, tmName, sizeof(tmName));
    } else {
        strcopy(tmName, sizeof(tmName), "none");
    }

    DebugFile.WriteLine(
        "[tick %d] #%d %s team=%d (type=%d alive=%d) pos=(%.0f %.0f %.0f) "
    ... "move=%s blend=(idle=%.2f toward=%.2f circle=%.2f away=%.2f) "
    ... "look=%s(damp=%.2f) rocket=(ent=%d mine=%d tgtcl=%d dist=%.0f spd=%.0f approach=%d) "
    ... "orbit=%d/%d trick=%s(%d) danger=%.2f "
    ... "enemy=#%d(%.0f) teammate=%s(%.0f) react=%.0f "
    ... "vel=(%.0f %.0f) ang=(%.1f %.1f) btn=%s %s",
        GetGameTickCount(), client, botName, team, botType, IsPlayerAlive(client) ? 1 : 0,
        pos[0], pos[1], pos[2],
        moveName, MoveBlendIdle[client], MoveBlendToward[client], MoveBlendCircle[client], MoveBlendAway[client],
        lookName, AimDampen[client],
        rocketEnt, rocketTargeted ? 1 : 0, rocketTargetClient, rocketDist, rocketSpeed, rocketApproaching ? 1 : 0,
        Orbiting[client] ? 1 : 0, OrbitPhaseIdx[client],
        trickName, ApplyingTrick[client] ? 1 : 0, danger,
        enemy, enemyDist, tmName, nearTmDist, ReactDistance[client],
        vel[0], vel[1],
        angles[0], angles[1],
        btnStr, event);

    DebugBumpLineCount();
}

// Log a one-off event (deflect, kill, death, trick, etc.) - always written regardless of sample rate
void DebugLogEvent(int client, float vel[3], float angles[3], const char[] event) {
    if (!DebugActive || DebugFile == null) return;
    DebugLogBotState(client, vel, angles, event);
}

// ============================================================================
// DECISION-TRACE LOGGING
// Captures the RATIONALE behind a bot's choice (cfg values consulted, rolls
// made, branches taken) — not just the final state. Use at every pivotal
// branch in the AI so post-hoc analysis can answer "why did statue walk
// instead of idle?", "why did 3 bots all idle the same tick?", etc.
//
// Lines are tagged DECISION/<where> for grep-by-decision-point. Always logged
// regardless of sample rate — these are rare events, not per-tick noise.
//
// Format: [tick N] DECISION/<where> #idx name type=T <free-form details>
// Example: [tick 12345] DECISION/MoveMode #2 TBotV64 type=1 cfg.idle_chance=100 roll=42 wantIdle=1 -> MOVE_IDLE
// ============================================================================

void DebugLogDecision(int client, const char[] where, const char[] details)
{
    if (!DebugActive || DebugFile == null) return;
    if (client < 1 || client > MaxClients || !IsClientInGame(client)) return;

    int botType = GetEffectiveBotType(client);
    char botName[32];
    GetClientName(client, botName, sizeof(botName));

    DebugFile.WriteLine(
        "[tick %d] DECISION/%s #%d %s type=%d %s",
        GetGameTickCount(), where, client, botName, botType, details);

    DebugBumpLineCount();
}

// ============================================================================
// PLAYER DATA COLLECTION
// Logs human player state in the same debug file as bot data. Prefixed with
// [PLAYER] so it's easy to filter. Captures movement, aim, buttons, position,
// and rocket awareness — everything needed to study how real players behave
// and derive better bot movesets from the data.
// ============================================================================
void DebugLogPlayerState(int client, float vel[3], float angles[3], int buttons) {
    if (!DebugActive || DebugFile == null) return;

    char playerName[32];
    GetClientName(client, playerName, sizeof(playerName));

    int team = GetClientTeam(client);
    float pos[3];
    GetClientAbsOrigin(client, pos);
    float eyePos[3];
    GetClientEyePosition(client, eyePos);

    // Aim delta: how fast is the player turning? (degrees per sample)
    float yawDelta = angles[1] - PlayerLastYaw[client];
    if (yawDelta > 180.0) yawDelta -= 360.0;
    if (yawDelta < -180.0) yawDelta += 360.0;
    PlayerLastYaw[client] = angles[1];

    // Velocity delta: acceleration / direction changes
    float velDeltaX = vel[0] - PlayerLastVelX[client];
    float velDeltaY = vel[1] - PlayerLastVelY[client];
    PlayerLastVelX[client] = vel[0];
    PlayerLastVelY[client] = vel[1];

    // Button flags — full input picture
    char btnStr[48];
    FormatEx(btnStr, sizeof(btnStr), "%s%s%s%s%s%s%s%s",
        (buttons & IN_FORWARD)  ? "W" : "-",
        (buttons & IN_BACK)     ? "S" : "-",
        (buttons & IN_MOVELEFT) ? "A" : "-",
        (buttons & IN_MOVERIGHT)? "D" : "-",
        (buttons & IN_ATTACK)   ? "M1" : "--",  // Flame
        (buttons & IN_ATTACK2)  ? "M2" : "--",  // Airblast
        (buttons & IN_JUMP)     ? "J" : "-",
        (buttons & IN_DUCK)     ? "C" : "-");   // Crouch

    // Ground speed (actual movement speed regardless of input direction)
    float actualVel[3];
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", actualVel);
    float groundSpeed = SquareRoot(actualVel[0] * actualVel[0] + actualVel[1] * actualVel[1]);

    // Nearest rocket info (same scan as bots use)
    int rocketEnt = -1;
    float rocketDist = -1.0;
    float rocketSpeed = 0.0;
    bool rocketTargeted = false;
    int rocketTargetClient = -1;
    bool rocketApproaching = false;

    #if defined _tfdb_included
    if (TFDBAvailable && TFDB_IsDodgeballEnabled()) {
        float bestDist = 999999.0;
        int rocketCount = TFDB_GetRocketCount();
        for (int i = 0; i < rocketCount; i++) {
            if (!TFDB_IsValidRocket(i)) continue;
            int ent = TFDB_GetRocketEntity(i);
            if (ent <= 0 || !IsValidEntity(ent)) continue;
            float rPos[3];
            GetEntPropVector(ent, Prop_Data, "m_vecOrigin", rPos);
            float d = GetVectorDistance(eyePos, rPos);
            if (d < bestDist) {
                bestDist = d;
                rocketEnt = ent;
            }
        }
        if (rocketEnt != -1) {
            float rPos[3];
            GetEntPropVector(rocketEnt, Prop_Data, "m_vecOrigin", rPos);
            rocketDist = GetVectorDistance(eyePos, rPos);
            float rVel[3];
            GetEntPropVector(rocketEnt, Prop_Data, "m_vecAbsVelocity", rVel);
            rocketSpeed = GetVectorLength(rVel);
            rocketTargeted = IsRocketTargetingClient(rocketEnt, client);
            int rIdx = TFDB_FindRocketByEntity(rocketEnt);
            if (rIdx != -1) {
                rocketTargetClient = TFDB_GetRocketTarget(rIdx);
            }
            float toMe[3];
            SubtractVectors(eyePos, rPos, toMe);
            NormalizeVector(toMe, toMe);
            rocketApproaching = (GetVectorDotProduct(rVel, toMe) > 0.0);
        }
    }
    #endif

    // Nearest enemy distance
    int nearEnemy = -1;
    float nearEnemyDist = 99999.0;
    for (int i = 1; i <= MaxClients; i++) {
        if (i == client) continue;
        if (!IsClientInGame(i) || !IsPlayerAlive(i)) continue;
        if (GetClientTeam(i) == team) continue;
        float ePos[3];
        GetClientAbsOrigin(i, ePos);
        float d = GetVectorDistance(pos, ePos);
        if (d < nearEnemyDist) {
            nearEnemyDist = d;
            nearEnemy = i;
        }
    }

    DebugFile.WriteLine(
        "[PLAYER tick %d] #%d %s team=%d pos=(%.0f %.0f %.0f) "
    ... "vel=(%.0f %.0f) velDelta=(%.0f %.0f) speed=%.0f ang=(%.1f %.1f) yawDelta=%.1f "
    ... "rocket=(ent=%d mine=%d tgtcl=%d dist=%.0f spd=%.0f approach=%d) "
    ... "enemy=#%d(%.0f) btn=%s",
        GetGameTickCount(), client, playerName, team,
        pos[0], pos[1], pos[2],
        vel[0], vel[1], velDeltaX, velDeltaY, groundSpeed,
        angles[0], angles[1], yawDelta,
        rocketEnt, rocketTargeted ? 1 : 0, rocketTargetClient, rocketDist, rocketSpeed, rocketApproaching ? 1 : 0,
        nearEnemy, nearEnemyDist,
        btnStr);

    DebugBumpLineCount();
}

// ============================================================================
// COMBAT STATE RESET
// ============================================================================

void ResetCombatState(int client) {
    HasRocket[client] = false;
    TimingDecided[client] = false;
    Orbiting[client] = false;
    ApplyingTrick[client] = false;
    Evading[client] = false;
    ClientRocketRef[client] = INVALID_ENT_REFERENCE;
    NextRocketScan[client] = 0.0;
    TrickEnd[client] = 0.0;
    Trick[client] = TRICK_NONE;
    LastState[client][0] = '\0';
    NextDirChange[client] = 0.0;
    NextWallCheck[client] = 0.0;
    MoveYaw[client] = GetRandomFloat(-180.0, 180.0);
    
    // Set initial movement mode based on bot type
    // Statue MUST start idle - not wander. Otherwise it moves at round start.
    int spawnType = GetEffectiveBotType(client);
    bool isStatueLike = (spawnType >= 0 && spawnType < NumBotTypes) ? ClassIsStatueLike[spawnType] : false;
    if (isStatueLike) {
        CurrentMoveMode[client] = MOVE_IDLE;
    } else {
        CurrentMoveMode[client] = MOVE_WANDER;
        MoveModeEnd[client] = 0.0; // Decide immediately on first frame
    }
    
    TargetEnemy[client] = -1;
    OrbitPhaseIdx[client] = ORBIT_PHASE_NONE;
    OrbitLoopCount[client] = 0;
    ConfirmedDeflects[client] = 0;
    
    // Reset movement blend weights
    MoveBlendIdle[client] = isStatueLike ? 1.0 : 0.0;
    MoveBlendToward[client] = 0.0;
    MoveBlendCircle[client] = 0.0;
    MoveBlendAway[client] = 0.0;
    MoveBlendUpdate[client] = 0.0;
}

// Reset opponent profile when a player disconnects
void ResetOpponentProfile(int client) {
    OpponentProfile blank;
    OpProfile[client] = blank;
    OpProfileLoaded[client] = false;
    OpSteamId[client] = 0;
}

// ============================================================================
// ADAPTIVE LEARNING v2 - helpers
// ============================================================================

// --- Reaction drift ---------------------------------------------------------
// Call on a successful deflect (reward) or death (punish). `delta` is applied
// to BOTH min and max so the whole reaction window shifts, preserving spread.
void NudgeReactionTime(int botType, bool rewarded) {
    if (!CfgLearnReactionTime) return;
    if (botType < 0 || botType >= NumBotTypes) return;

    // Success: shift toward faster (negative). Failure: shift toward slower.
    float delta = rewarded ? -REACT_LEARN_RATE : REACT_LEARN_RATE;
    ReactMinDelta[botType] += delta;
    ReactMaxDelta[botType] += delta;

    // Clamp
    if (ReactMinDelta[botType] < REACT_DELTA_MIN) ReactMinDelta[botType] = REACT_DELTA_MIN;
    if (ReactMinDelta[botType] > REACT_DELTA_MAX) ReactMinDelta[botType] = REACT_DELTA_MAX;
    if (ReactMaxDelta[botType] < REACT_DELTA_MIN) ReactMaxDelta[botType] = REACT_DELTA_MIN;
    if (ReactMaxDelta[botType] > REACT_DELTA_MAX) ReactMaxDelta[botType] = REACT_DELTA_MAX;
}

// Returns current reaction window, cfg base + learned drift, floored at 0.03 s.
void GetLearnedReactionWindow(int botType, float &rMin, float &rMax) {
    rMin = CfgReactMin[botType] + ReactMinDelta[botType];
    rMax = CfgReactMax[botType] + ReactMaxDelta[botType];
    if (rMin < 0.03) rMin = 0.03;         // Physical floor (~30 ms, superhuman but not impossible)
    if (rMax < rMin + 0.02) rMax = rMin + 0.02;
}

void SaveReactionDeltas() {
    if (BrainDB == null || !CfgLearnReactionTime) return;
    char query[256];
    for (int t = 0; t < NumBotTypes; t++) {
        FormatEx(query, sizeof(query),
            "INSERT OR REPLACE INTO bot_reaction_v1 (bot_type, react_min_delta, react_max_delta) VALUES (%d, %f, %f)",
            t, ReactMinDelta[t], ReactMaxDelta[t]);
        BrainDB.Query(SQL_Generic, query);
    }
}

// --- Opponent persistence ---------------------------------------------------
void LoadOpponentFromDB(int client) {
    if (!CfgRememberOpponents) return;
    if (BrainDB == null) return;
    if (client <= 0 || client > MaxClients || !IsClientInGame(client)) return;
    if (IsFakeClient(client)) return;

    int sid = GetSteamAccountID(client, true);
    if (sid == 0) return;
    OpSteamId[client] = sid;

    char query[256];
    FormatEx(query, sizeof(query),
        "SELECT strafe_left, strafe_right, stood_still, jumped, crouched, cqc_approach, cqc_retreat, total_deflects, total_kills, total_deaths, avg_deflect_speed FROM bot_opponent_v1 WHERE steam_id=%d",
        sid);

    // Pack (userid, expectedSid) so the callback can verify the slot still
    // holds the SAME player it queried for. Prevents slot-reuse hijacks where
    // player A disconnects mid-query and player B reconnects into slot A
    // before the callback fires, causing B to inherit A's brain profile.
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteCell(sid);
    BrainDB.Query(SQL_LoadOpponent, query, pack);
}

public void SQL_LoadOpponent(Database db, DBResultSet results, const char[] error, DataPack pack) {
    pack.Reset();
    int userid     = pack.ReadCell();
    int expectedSid = pack.ReadCell();
    delete pack;

    if (error[0] != '\0') { LogError("[PvB] Opponent load error: %s", error); return; }

    int client = GetClientOfUserId(userid);
    if (client <= 0 || !IsClientInGame(client)) return;
    // Slot-reuse guard: if the slot now holds a different player than the one
    // we queried for, drop the result silently. The new player gets their own
    // load via OnClientPostAdminCheck.
    if (GetSteamAccountID(client, true) != expectedSid) return;

    if (results.FetchRow()) {
        OpProfile[client].strafeLeftCount  = results.FetchInt(0);
        OpProfile[client].strafeRightCount = results.FetchInt(1);
        OpProfile[client].stoodStillCount  = results.FetchInt(2);
        OpProfile[client].jumpedCount      = results.FetchInt(3);
        OpProfile[client].crouchedCount    = results.FetchInt(4);
        OpProfile[client].cqcApproachCount = results.FetchInt(5);
        OpProfile[client].cqcRetreatCount  = results.FetchInt(6);
        OpProfile[client].totalDeflects    = results.FetchInt(7);
        OpProfile[client].totalKills       = results.FetchInt(8);
        OpProfile[client].totalDeaths      = results.FetchInt(9);
        OpProfile[client].avgDeflectSpeed  = results.FetchFloat(10);
    }
    OpProfileLoaded[client] = true;
}

void SaveOpponentToDB(int client) {
    if (!CfgRememberOpponents) return;
    if (BrainDB == null) return;
    if (OpSteamId[client] == 0) return;
    // Only persist if we actually saw meaningful activity
    if (OpProfile[client].totalDeflects == 0 && OpProfile[client].totalDeaths == 0 &&
        OpProfile[client].totalKills == 0) {
        return;
    }

    char query[640];
    FormatEx(query, sizeof(query),
        "INSERT OR REPLACE INTO bot_opponent_v1 (steam_id, strafe_left, strafe_right, stood_still, jumped, crouched, cqc_approach, cqc_retreat, total_deflects, total_kills, total_deaths, avg_deflect_speed) VALUES (%d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %d, %f)",
        OpSteamId[client],
        OpProfile[client].strafeLeftCount,
        OpProfile[client].strafeRightCount,
        OpProfile[client].stoodStillCount,
        OpProfile[client].jumpedCount,
        OpProfile[client].crouchedCount,
        OpProfile[client].cqcApproachCount,
        OpProfile[client].cqcRetreatCount,
        OpProfile[client].totalDeflects,
        OpProfile[client].totalKills,
        OpProfile[client].totalDeaths,
        OpProfile[client].avgDeflectSpeed);
    BrainDB.Query(SQL_Generic, query);
}

// --- Map heatmaps -----------------------------------------------------------
void HeatmapKey(int botType, int gx, int gy, char[] buf, int bufSize) {
    FormatEx(buf, bufSize, "%s|%d|%d|%d", CurrentMap, botType, gx, gy);
}

void WorldToGrid(const float pos[3], int &gx, int &gy) {
    gx = RoundToFloor(pos[0] / HEATMAP_CELL_SIZE);
    gy = RoundToFloor(pos[1] / HEATMAP_CELL_SIZE);
}

// Record an event for the PLAYER at `pos`. type: 0=deflect, 1=death.
// Only tracks events vs. PvB bots of the given class.
void HeatmapRecord(int botType, const float pos[3], int type) {
    if (!CfgUseHeatmap) return;
    if (HeatmapCells == null) return;
    if (botType < 0 || botType >= NumBotTypes) return;
    if (ClassIsStatueLike[botType]) return;  // Statues don't care about positioning

    int gx, gy;
    WorldToGrid(pos, gx, gy);
    char key[96];
    HeatmapKey(botType, gx, gy, key, sizeof(key));

    int cell[2];
    if (!HeatmapCells.GetArray(key, cell, 2)) {
        cell[0] = 0;
        cell[1] = 0;
    }
    if (type == 0)      cell[0]++;   // deflect
    else if (type == 1) cell[1]++;   // death
    HeatmapCells.SetArray(key, cell, 2);
    HeatmapDirty = true;
}

// Bayesian danger score in [0,1]. 0 = safe for player, 1 = certain death.
float HeatmapDangerAt(int botType, const float pos[3]) {
    if (!CfgUseHeatmap) return 0.5;
    if (HeatmapCells == null) return 0.5;
    if (botType < 0 || botType >= NumBotTypes) return 0.5;

    int gx, gy;
    WorldToGrid(pos, gx, gy);
    char key[96];
    HeatmapKey(botType, gx, gy, key, sizeof(key));

    int cell[2];
    if (!HeatmapCells.GetArray(key, cell, 2)) return 0.5;

    float deaths   = float(cell[1]);
    float deflects = float(cell[0]);
    return deaths / (deaths + deflects + HEATMAP_PRIOR);
}

void FlushHeatmap() {
    if (!HeatmapDirty || BrainDB == null || HeatmapCells == null) return;
    if (CurrentMap[0] == '\0') return;

    StringMapSnapshot snap = HeatmapCells.Snapshot();
    char key[96];
    int cell[2];
    char query[320];
    char escMap[128];
    BrainDB.Escape(CurrentMap, escMap, sizeof(escMap));

    for (int i = 0; i < snap.Length; i++) {
        snap.GetKey(i, key, sizeof(key));
        if (!HeatmapCells.GetArray(key, cell, 2)) continue;

        // Parse the key: "map|bot|gx|gy"
        // The mapName portion might itself contain '|'? Very unlikely. Use strtok-ish scan.
        int p1 = FindCharInString(key, '|', false);
        if (p1 == -1) continue;
        int p2 = FindCharInString(key[p1 + 1], '|', false);
        if (p2 == -1) continue;
        p2 += p1 + 1;
        int p3 = FindCharInString(key[p2 + 1], '|', false);
        if (p3 == -1) continue;
        p3 += p2 + 1;

        int botType = StringToInt(key[p1 + 1]);
        int gx      = StringToInt(key[p2 + 1]);
        int gy      = StringToInt(key[p3 + 1]);

        if (cell[0] == 0 && cell[1] == 0) {
            // Decayed to nothing — prune from DB and memory so it doesn't
            // keep loading back on every map change.
            FormatEx(query, sizeof(query),
                "DELETE FROM bot_heatmap_v1 WHERE map_name='%s' AND bot_type=%d AND gx=%d AND gy=%d",
                escMap, botType, gx, gy);
            BrainDB.Query(SQL_Generic, query);
            HeatmapCells.Remove(key);
        } else {
            FormatEx(query, sizeof(query),
                "INSERT OR REPLACE INTO bot_heatmap_v1 (map_name, bot_type, gx, gy, deflects, deaths) VALUES ('%s', %d, %d, %d, %d, %d)",
                escMap, botType, gx, gy, cell[0], cell[1]);
            BrainDB.Query(SQL_Generic, query);
        }
    }
    delete snap;
    HeatmapDirty = false;
}

// Multiply every cell's deflect+death counts by `factor`. Called once per map
// load. Addresses "dead middle" feedback loop: a cell that racked up 50 deaths
// one session used to stay scary forever. With decay, that signal fades over
// ~10 map loads unless it keeps getting refreshed by current play.
void DecayHeatmap(float factor) {
    if (HeatmapCells == null) return;
    if (factor >= 1.0 || factor <= 0.0) return;  // no-op on bad factor

    StringMapSnapshot snap = HeatmapCells.Snapshot();
    int touched = 0;
    for (int i = 0; i < snap.Length; i++) {
        char key[96];
        snap.GetKey(i, key, sizeof(key));
        int cell[2];
        if (!HeatmapCells.GetArray(key, cell, 2)) continue;

        cell[0] = RoundToNearest(float(cell[0]) * factor);
        cell[1] = RoundToNearest(float(cell[1]) * factor);
        HeatmapCells.SetArray(key, cell, 2);
        touched++;
    }
    delete snap;
    if (touched > 0) {
        HeatmapDirty = true;
        LogMessage("[PvB] Heatmap decay x%.2f applied to %d cells on %s", factor, touched, CurrentMap);
    }
}

// ============================================================================
// FIND CLOSEST ENEMY
// ============================================================================

int FindClosestEnemy(int client) {
    float bPos[3];
    GetClientAbsOrigin(client, bPos);
    int botTeam = GetClientTeam(client);

    int closest = -1;
    float closestDist = 999999.0;

    for (int i = 1; i <= MaxClients; i++) {
        if (i == client) continue;
        if (!IsClientInGame(i) || !IsPlayerAlive(i)) continue;
        // In training mode, bots CAN target other bots (that's the point)
        if (!TrainingMode && IsFakeClient(i)) continue;
        if (GetClientTeam(i) == botTeam) continue;

        float pos[3];
        GetClientAbsOrigin(i, pos);
        float dist = GetVectorDistance(bPos, pos);
        if (dist < closestDist) {
            closestDist = dist;
            closest = i;
        }
    }

    return closest;
}

// ============================================================================
// ANGLE UTILITIES
// ============================================================================

void ClampAngles(float angles[3]) {
    if (angles[0] > 89.0) angles[0] = 89.0;
    else if (angles[0] < -89.0) angles[0] = -89.0;
    
    while (angles[1] > 180.0) angles[1] -= 360.0;
    while (angles[1] < -180.0) angles[1] += 360.0;
    
    angles[2] = 0.0;
}

void SmoothAim(int client, float targetAngles[3], float factor) {
    float current[3];
    GetClientEyeAngles(client, current);
    
    float pitchDiff = targetAngles[0] - current[0];
    current[0] += pitchDiff * factor;
    
    float yawDiff = targetAngles[1] - current[1];
    if (yawDiff > 180.0) yawDiff -= 360.0;
    if (yawDiff < -180.0) yawDiff += 360.0;
    current[1] += yawDiff * factor;
    
    current[2] = 0.0;
    ClampAngles(current);
    TeleportEntity(client, NULL_VECTOR, current, NULL_VECTOR);
}

void CalcAimAngles(const float from[3], const float to[3], float out[3]) {
    float dx = to[0] - from[0];
    float dy = to[1] - from[1];
    float dz = to[2] - from[2];
    float flatDist = SquareRoot(dx * dx + dy * dy);
    
    out[0] = 0.0 - RadToDeg(ArcTangent2(dz, flatDist));
    out[1] = RadToDeg(ArcTangent2(dy, dx));
    out[2] = 0.0;
    ClampAngles(out);
}

// ============================================================================
// TRACE FILTER
// ============================================================================

public bool TraceFilter_NoPlayers(int entity, int contentsMask, any data) {
    return entity != data && (entity <= 0 || entity > MaxClients);
}

// ============================================================================
// UTILITY STOCKS
// ============================================================================

bool IsClientBot(int client) {
    return (client > 0 && client <= MaxClients && TFDB_IsLiveBot(client));
}

int GetRealClientCount() {
    // Counts real humans on a PLAY team (RED/BLU). Spectators excluded — same
    // semantics as CachedRealCount (see UpdateCachedCounts).
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (TFDB_IsRealHumanPlaying(i)) {
            count++;
        }
    }
    return count;
}

bool IsAirblastReady(int weap) {
    if (weap < 1 || !IsValidEntity(weap)) return false;
    
    float nextSecondaryAttack = GetEntPropFloat(weap, Prop_Send, "m_flNextSecondaryAttack");
    float gameTime = GetGameTime();
    
    return (nextSecondaryAttack <= gameTime);
}

void ForceRedWin() {
    int ent = FindEntityByClassname(-1, "game_round_win");
    if (ent < 1) {
        ent = CreateEntityByName("game_round_win");
        if (IsValidEntity(ent)) {
            DispatchSpawn(ent);
        } else {
            LogError("[PvB] Could not create game_round_win entity!");
            return;
        }
    }

    SetVariantInt(2);
    AcceptEntityInput(ent, "SetTeam");
    AcceptEntityInput(ent, "RoundWin");
}

public void OnPluginEnd() {
    if (BotEnabled) {
        DisablePvB();
    }
    if (TrainingMode) {
        StopTraining();
    }
    if (DebugActive) {
        StopDebugLogging();
    }

    // Belt-and-suspenders: always restore hibernation on unload, even if
    // StopTraining already ran or we never entered training this session.
    // If the plugin is unloaded mid-session (sm plugins unload, crash recover,
    // reload), we must not leave the server stuck in no-hibernate state.
    ServerCommand("tf_allow_server_hibernation 1");

    // Flush any dirty learning data before we tear down the DB handle
    FlushHeatmap();
    FlushBrainWrites();
    SaveReactionDeltas();

    delete BrainMemory;
    BrainMemory = null;
    for (int t = 0; t < MAX_BOT_TYPES; t++) {
        delete TauntsPlayerDeath[t];
        TauntsPlayerDeath[t] = null;
        delete TauntsBotDeath[t];
        TauntsBotDeath[t] = null;
    }
    delete BrainDB;
    BrainDB = null;
}
