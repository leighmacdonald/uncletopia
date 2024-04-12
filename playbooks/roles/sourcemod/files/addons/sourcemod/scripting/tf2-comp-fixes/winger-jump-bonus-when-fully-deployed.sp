#define ATTR_MOD_JUMP_HEIGHT_FROM_WEAPON (524)
#define WEAPON_ID_THE_WINGER             (449)

static ConVar g_convar;
static Handle g_hook_CBaseCombatWeapon_Deploy;
static Handle g_timers[MAXENTITIES + 1]   = {INVALID_HANDLE, ...};
static int    g_hook_ids[MAXENTITIES + 1] = {-1, ...};

void WingerJumpBonusWhenFullyDeployed_Setup(Handle game_config) {
    g_hook_CBaseCombatWeapon_Deploy =
        CheckedDHookCreateFromConf(game_config, "CBaseCombatWeapon::Deploy");

    g_convar = CreateBoolConVar("sm_winger_jump_bonus_when_fully_deployed", WhenConVarChange);

    HookEvent("teamplay_round_start", WhenRoundStart);
}

void WingerJumpBonusWhenFullyDeployed_OnClientPutInServer(int client) {
    if (!g_convar.BoolValue) {
        return;
    }

    SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (cvar.BoolValue) {
        int entity = -1;
        while ((entity = FindEntityByClassname(entity, "tf_weapon_handgun_scout_secondary"))
               != -1) {
            Hook_WeaponCanUse(0, entity);
        }
    } else {
        for (int ent = 0; ent <= MAXENTITIES; ent++) {
            if (g_hook_ids[ent] == -1) {
                continue;
            }

            LogDebug("Resetting Winger Bonus with index %d", ent);
            DHookRemoveHookID(g_hook_ids[ent]);
            g_hook_ids[ent] = -1;
        }
    }

    for (int client = 1; client <= MaxClients; client++) {
        if (!IsClientInGame(client)) {
            continue;
        }

        if (cvar.BoolValue) {
            SDKHook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
        } else {
            SDKUnhook(client, SDKHook_WeaponCanUse, Hook_WeaponCanUse);
        }
    }
}

static Action Hook_WeaponCanUse(int client, int weapon) {
    int weapon_id = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

    if (weapon_id != WEAPON_ID_THE_WINGER) {
        return Plugin_Continue;
    }

    LogDebug("Nullifying Winger Bonus with index %d", weapon);
    g_hook_ids[weapon] = DHookEntity(g_hook_CBaseCombatWeapon_Deploy, HOOK_PRE, weapon, HookRemoved,
                                     Hook_CBaseCombatWeapon_Deploy);

    return Plugin_Continue;
}

static void HookRemoved(int hookid) {
    for (int i = 1; i <= MAXENTITIES; i++) {
        if (g_hook_ids[i] != hookid) {
            continue;
        }

        g_hook_ids[i] = -1;
    }
}

static MRESReturn Hook_CBaseCombatWeapon_Deploy(int weapon, Handle ret) {
    if (g_timers[weapon] != INVALID_HANDLE) {
        KillTimer(g_timers[weapon]);
        g_timers[weapon] = INVALID_HANDLE;
    }

    SetAttribute(weapon, ATTR_MOD_JUMP_HEIGHT_FROM_WEAPON, 1.0);

    g_timers[weapon] = CreateTimer(0.2, TimerFinished, weapon);

    return MRES_Handled;
}

static Action TimerFinished(Handle timer, int weapon) {
    g_timers[weapon] = INVALID_HANDLE;

    if (!IsValidEntity(weapon)) {
        return Plugin_Continue;
    }

    SetAttribute(weapon, ATTR_MOD_JUMP_HEIGHT_FROM_WEAPON, 1.25);

    return Plugin_Continue;
}

static void WhenRoundStart(Event event, const char[] name, bool dontBroadcast) {
    for (int ent = 0; ent <= MAXENTITIES; ent++) {
        if (g_timers[ent] == INVALID_HANDLE) {
            continue;
        }

        KillTimer(g_timers[ent]);
        g_timers[ent] = INVALID_HANDLE;
    }
}
