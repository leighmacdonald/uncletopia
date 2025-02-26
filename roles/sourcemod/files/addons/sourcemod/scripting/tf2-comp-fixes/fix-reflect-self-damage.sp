static ConVar g_convar;
static Handle g_hook_CTFFlameThrower_DeflectEntity;
static int    g_hook_ids[MAXENTITIES + 1] = {-1, ...};

void FixReflectSelfDamage_Setup(Handle game_config) {
    g_hook_CTFFlameThrower_DeflectEntity =
        CheckedDHookCreateFromConf(game_config, "CTFFlameThrower::DeflectEntity");

    g_convar = CreateBoolConVar("sm_fix_reflect_self_damage", WhenConVarChange);
}

void FixReflectSelfDamage_OnClientPutInServer(int client) {
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
        while ((entity = FindEntityByClassname(entity, "tf_weapon_flamethrower")) != -1) {
            Hook_WeaponCanUse(0, entity);
        }
    } else {
        for (int ent = 0; ent <= MAXENTITIES; ent++) {
            if (g_hook_ids[ent] == -1) {
                continue;
            }

            LogDebug("Resetting Flamethrower with index %d", ent);
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
    char class[64];
    GetEdictClassname(weapon, class, sizeof(class));

    if (!StrEqual(class, "tf_weapon_flamethrower")) {
        return Plugin_Continue;
    }

    LogDebug("Fixing reflect self-damage for Flamethrower with index %d", weapon);
    g_hook_ids[weapon] = DHookEntity(g_hook_CTFFlameThrower_DeflectEntity, HOOK_POST, weapon,
                                     HookRemoved, Hook_CTFFlameThrower_DeflectEntity);

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

static MRESReturn Hook_CTFFlameThrower_DeflectEntity(int entity, Handle hReturn, Handle hParams) {
    int projectile = DHookGetParam(hParams, 1);
    if (!IsValidEntity(projectile)) {
        return MRES_Ignored;
    }

    char class[64];
    GetEdictClassname(projectile, class, sizeof(class));

    if (StrEqual(class, "tf_projectile_flare", false)
        || StrEqual(class, "tf_projectile_pipe", false)) {
        LogDebug("Fixing m_hLauncher for flare or pipe with index %d", projectile);
        SetEntPropEnt(projectile, Prop_Send, "m_hLauncher",
                      GetEntPropEnt(projectile, Prop_Send, "m_hOriginalLauncher"));
        return MRES_Handled;
    }

    if (StrEqual(class, "tf_projectile_sentryrocket", false)) {
        LogDebug("Fixing m_hOriginalLauncher for sentry rocket with index %d", projectile);
        SetEntPropEnt(projectile, Prop_Send, "m_hOriginalLauncher", -1);
        return MRES_Handled;
    }

    return MRES_Ignored;
}
