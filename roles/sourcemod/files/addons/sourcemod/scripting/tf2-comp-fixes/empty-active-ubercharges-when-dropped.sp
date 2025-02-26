static Handle g_detour_CTFDroppedWeapon_InitDroppedWeapon;

void EmptyActiveUberchargesWhenDropped_Setup(Handle game_config) {
    g_detour_CTFDroppedWeapon_InitDroppedWeapon =
        CheckedDHookCreateFromConf(game_config, "CTFDroppedWeapon::InitDroppedWeapon");

    CreateBoolConVar("sm_empty_active_ubercharges_when_dropped", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFDroppedWeapon_InitDroppedWeapon, HOOK_PRE, Detour_Pre,
                           cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFDroppedWeapon::InitDroppedWeapon");
    }
}

static MRESReturn Detour_Pre(int self, Handle params) {
    int weapon = DHookGetParam(params, 2);

    char classname[64];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (StrEqual(classname, "tf_weapon_medigun")
        && GetEntProp(weapon, Prop_Send, "m_bChargeRelease", 1)) {
        LogDebug("Emptying active ubercharge of %N's dropped medigun with index %d",
                 DHookGetParam(params, 1), weapon);

        SetEntPropFloat(weapon, Prop_Send, "m_flChargeLevel", 0.0);

        return MRES_Handled;
    }

    return MRES_Ignored;
}
