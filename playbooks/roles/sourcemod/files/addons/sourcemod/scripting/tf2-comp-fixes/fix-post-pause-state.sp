static ConVar g_convar_pausable;
static bool   g_paused = false;

static float g_ubercharge[MAXPLAYERS + 1];
static int   g_medigun[MAXPLAYERS + 1];

void FixPostPauseState_Setup() {
    g_convar_pausable = FindConVar("sv_pausable");

    if (g_convar_pausable == INVALID_HANDLE) {
        SetFailState("Failed to find sv_pausable");
    }

    CreateBoolConVar("sm_fix_post_pause_state", WhenConVarChange);
}

void FixPostPauseState_OnMapStart() { g_paused = false; }

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (cvar.BoolValue) {
        AddCommandListener(WhenPause, "pause");
    } else {
        RemoveCommandListener(WhenPause, "pause");
    }
}

static Action WhenPause(int author, const char[] command, int argc) {
    if (!g_convar_pausable.BoolValue) {
        return Plugin_Continue;
    }

    if (!g_paused) {
        for (int client = 1; client <= MaxClients; client++) {
            g_medigun[client]    = -1;
            g_ubercharge[client] = 0.0;
        }
    }

    for (int client = 1; client <= MaxClients; client++) {
        if (!IsClientInGame(client)) {
            continue;
        }

        if (TF2_GetPlayerClass(client) != TFClass_Medic) {
            continue;
        }

        int medigun = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

        if (medigun == -1) {
            // Weird
            continue;
        }

        if (!g_paused) {
            g_medigun[client]    = medigun;
            g_ubercharge[client] = GetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel");
            LogDebug("Saving %N's ubercharge as %.0f%", client, g_ubercharge[client] * 100);
        } else if (medigun == g_medigun[client]) {
            SetEntPropFloat(medigun, Prop_Send, "m_flChargeLevel", g_ubercharge[client]);
            LogDebug("Restoring %N's ubercharge to %.0f%", client, g_ubercharge[client] * 100);
        } else {
            LogDebug("Ignoring %N's ubercharge because the medigun has changed (was %d, now is %d)",
                     client, g_medigun[client], medigun);
        }
    }

    g_paused = !g_paused;

    return Plugin_Continue;
}
