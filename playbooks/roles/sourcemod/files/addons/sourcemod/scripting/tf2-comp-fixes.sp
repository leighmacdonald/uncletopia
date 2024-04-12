#undef REQUIRE_PLUGIN
#include "include/updater.inc"
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#include <dhooks>
#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>

#include "tf2-comp-fixes/common.sp"

// Here
#include "tf2-comp-fixes/concede.sp"
#include "tf2-comp-fixes/debug.sp"
#include "tf2-comp-fixes/deterministic-fall-damage.sp"
#include "tf2-comp-fixes/empty-active-ubercharges-when-dropped.sp"
#include "tf2-comp-fixes/fix-ghost-crossbow-bolts.sp"
#include "tf2-comp-fixes/fix-post-pause-state.sp"
#include "tf2-comp-fixes/fix-reflect-self-damage.sp"
#include "tf2-comp-fixes/fix-slope-bug.sp"
#include "tf2-comp-fixes/fix-sticky-delay.sp"
#include "tf2-comp-fixes/ghostify-soldier-statue.sp"
#include "tf2-comp-fixes/grounded-rj-resistance.sp"
#include "tf2-comp-fixes/gunboats-always-apply.sp"
#include "tf2-comp-fixes/inhibit-extendfreeze.sp"
#include "tf2-comp-fixes/override-pipe-size.sp"
#include "tf2-comp-fixes/prevent-respawning.sp"
#include "tf2-comp-fixes/projectiles-collide-with-cylinders.sp"
#include "tf2-comp-fixes/projectiles-ignore-teammates.sp"
#include "tf2-comp-fixes/remove-halloween-souls.sp"
#include "tf2-comp-fixes/remove-medic-attach-speed.sp"
#include "tf2-comp-fixes/remove-pipe-spin.sp"
#include "tf2-comp-fixes/solid-buildings.sp"
#include "tf2-comp-fixes/tournament-end-ignores-whitelist.sp"
#include "tf2-comp-fixes/winger-jump-bonus-when-fully-deployed.sp"

#define PLUGIN_VERSION "1.16.14"

// clang-format off
public
Plugin myinfo = {
    name = "TF2 Competitive Fixes",
    author = "ldesgoui",
    description = "Various technical or gameplay changes catered towards competitive play",
    version = PLUGIN_VERSION,
    url = "https://github.com/ldesgoui/tf2-comp-fixes"
};
// clang-format on

public
void OnPluginStart() {
    Handle game_config = LoadGameConfigFile("tf2-comp-fixes.games");

    if (game_config == INVALID_HANDLE) {
        SetFailState("Failed to load addons/sourcemod/gamedata/tf2-comp-fixes.games.txt");
    }

    // clang-format off
    switch (GetOs(game_config)) {
        case Windows: {
            LogMessage("Support for the server's operating system has been deprecated, "
                       ... "some features are disabled");
        }
        case Mac: {
            delete game_config;
            SetFailState("The server's operating system is not supported");
        }
        case Unknown: {
            delete game_config;
            SetFailState("SourceMod is returning garbage data from addons/sourcemod/gamedata/tf2-comp-fixes.games.txt, "
                         ... "please try reloading the plugin, SourceMod itself or restart the server");
        }
    }
    // clang-format on

    RegConsoleCmd("sm_cf", Command_Cf, "Batch update of TF2 Competitive Fixes cvars");

    Common_Setup(game_config);
    Debug_Setup();

    // Here
    Concede_Setup();
    DeterministicFallDamage_Setup(game_config);
    EmptyActiveUberchargesWhenDropped_Setup(game_config);
    FixGhostCrossbowBolts_Setup();
    FixPostPauseState_Setup();
    FixReflectSelfDamage_Setup(game_config);
    FixSlopeBug_Setup(game_config);
    FixStickyDelay_Setup(game_config);
    GhostifySoldierStatue_Setup();
    GroundedRjResistance_Setup(game_config);
    GunboatsAlwaysApply_Setup(game_config);
    InhibitExtendfreeze_Setup();
    OverridePipeSize_Setup(game_config);
    PreventRespawning_Setup(game_config);
    ProjectilesCollideWithCylinders_Setup(game_config);
    ProjectilesIgnoreTeammates_Setup();
    RemoveHalloweenSouls_Setup(game_config);
    RemoveMedicAttachSpeed_Setup(game_config);
    RemovePipeSpin_Setup();
    SolidBuildings_Setup();
    TournamentEndIgnoresWhitelist_Setup(game_config);
    WingerJumpBonusWhenFullyDeployed_Setup(game_config);

    delete game_config;

    if (LibraryExists("updater")) {
        OnLibraryAdded("updater");
    }
}

public
void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, "updater")) {
        Updater_AddPlugin(
            "https://raw.githubusercontent.com/ldesgoui/tf2-comp-fixes/updater/updatefile.txt");
    }
}

public
void OnMapStart() { FixPostPauseState_OnMapStart(); }

public
void OnClientPutInServer(int client) {
    FixReflectSelfDamage_OnClientPutInServer(client);
    RemovePipeSpin_OnClientPutInServer(client);
    WingerJumpBonusWhenFullyDeployed_OnClientPutInServer(client);
}

public
Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3],
                      int &active_weapon, int &subtype, int &cmdnum, int &tickcount, int &seed,
                      int mouse[2]) {
    FixStickyDelay_OnPlayerRunCmd(client, buttons);

    return Plugin_Continue;
}

Action Command_Cf(int client, int args) {
    char full[256];
    bool all   = false;
    bool fixes = false;
    bool asf   = false;
    bool etf2l = false;
    bool ozf   = false;
    bool rgl   = false;

    GetCmdArgString(full, sizeof(full));

    if (StrEqual(full, "list")) {
        // Here
        ReplyToCommand(client, "--- Fixes");
        ReplyDiffConVar(client, "sm_deterministic_fall_damage");
        ReplyDiffConVar(client, "sm_empty_active_ubercharges_when_dropped");
        ReplyDiffConVar(client, "sm_fix_ghost_crossbow_bolts");
        ReplyDiffConVar(client, "sm_fix_post_pause_state");
        ReplyDiffConVar(client, "sm_fix_reflect_self_damage");
        ReplyDiffConVar(client, "sm_fix_slope_bug");
        ReplyDiffConVar(client, "sm_fix_sticky_delay");
        ReplyDiffConVar(client, "sm_inhibit_extendfreeze");
        ReplyDiffConVar(client, "sm_override_pipe_size");
        ReplyDiffConVar(client, "sm_projectiles_collide_with_cylinders");
        ReplyDiffConVar(client, "sm_projectiles_ignore_teammates");
        ReplyDiffConVar(client, "sm_remove_halloween_souls");
        ReplyDiffConVar(client, "sm_remove_pipe_spin");
        ReplyDiffConVar(client, "sm_rest_in_peace_rick_may");
        ReplyDiffConVar(client, "sm_tournament_end_ignores_whitelist");

        ReplyToCommand(client, "--- Balance changes");
        ReplyDiffConVar(client, "sm_grounded_rj_resistance");
        ReplyDiffConVar(client, "sm_gunboats_always_apply");
        ReplyDiffConVar(client, "sm_prevent_respawning");
        ReplyDiffConVar(client, "sm_remove_medic_attach_speed");
        ReplyDiffConVar(client, "sm_solid_buildings");
        ReplyDiffConVar(client, "sm_winger_jump_bonus_when_fully_deployed");

        return Plugin_Handled;
    } else if (StrEqual(full, "all")) {
        all = true;
    } else if (StrEqual(full, "fixes")) {
        fixes = true;
    } else if (StrEqual(full, "asf")) {
        asf = true;
    } else if (StrEqual(full, "etf2l")) {
        etf2l = true;
    } else if (StrEqual(full, "ozf")) {
        ozf = true;
    } else if (StrEqual(full, "rgl")) {
        rgl = true;
    } else if (StrEqual(full, "none")) {
    } else {
        ReplyToCommand(client, "TF2 Competitive Fixes");
        ReplyToCommand(client, "Version: %s", PLUGIN_VERSION);
        ReplyToCommand(client,
                       "Usage: sm_cf (list | all | fixes | none | asf | etf2l | ozf | rgl)");
        return Plugin_Handled;
    }

    if (client != 0
        && !(GetUserFlagBits(client) & (ADMFLAG_CONVARS | ADMFLAG_RCON | ADMFLAG_ROOT))) {
        ReplyToCommand(client, "You do not have permissions to edit ConVars");
        return Plugin_Handled;
    }

    // Here
    // clang-format off
    FindConVar("sm_deterministic_fall_damage")
        .SetBool(all || fixes || asf || etf2l || ozf || rgl);

    FindConVar("sm_empty_active_ubercharges_when_dropped")
        .SetBool(all || fixes || etf2l);

    FindConVar("sm_fix_ghost_crossbow_bolts")
        .SetBool(all || fixes || etf2l || ozf || rgl);

    FindConVar("sm_fix_post_pause_state")
        .SetBool(all || fixes || etf2l);

    FindConVar("sm_fix_reflect_self_damage")
        .SetBool(all || fixes || rgl);

    FindConVar("sm_fix_slope_bug")
        .SetBool(all || fixes || asf || etf2l || ozf || rgl);

    FindConVar("sm_fix_sticky_delay")
        .SetBool(all || fixes || etf2l || ozf || rgl);

    FindConVar("sm_inhibit_extendfreeze")
        .SetBool(all || fixes || etf2l || ozf || rgl);

    FindConVar("sm_override_pipe_size")
        .SetFloat(all || fixes || etf2l || ozf ? 4.0 : 0.0);

    FindConVar("sm_projectiles_collide_with_cylinders")
        .SetBool(all || fixes);

    FindConVar("sm_projectiles_ignore_teammates")
        .SetBool(all || fixes || asf || etf2l);

    FindConVar("sm_remove_halloween_souls")
        .SetBool(all || fixes || etf2l || ozf || rgl);

    FindConVar("sm_remove_pipe_spin")
        .SetBool(all);

    FindConVar("sm_rest_in_peace_rick_may")
        .SetInt(all || fixes || rgl ? 128 : ozf ? 255 : 0);

    ///

    FindConVar("sm_grounded_rj_resistance")
        .SetBool(all);

    FindConVar("sm_gunboats_always_apply")
        .SetBool(all || etf2l);

    FindConVar("sm_prevent_respawning")
        .SetBool(all);

    FindConVar("sm_remove_medic_attach_speed")
        .SetBool(all);

    FindConVar("sm_solid_buildings")
        .SetBool(all);

    FindConVar("sm_winger_jump_bonus_when_fully_deployed")
        .SetBool(all || etf2l);
    // clang-format on

    PrintToChatAll("[TF2 Competitive Fixes] Successfully applied '%s' preset", full);

    return Plugin_Handled;
}

void ReplyDiffConVar(int client, const char[] name) {
    ConVar cvar = FindConVar(name);
    char   current[128];
    cvar.GetString(current, sizeof(current));

    ReplyToCommand(client, "%s %s", name, current);
}
