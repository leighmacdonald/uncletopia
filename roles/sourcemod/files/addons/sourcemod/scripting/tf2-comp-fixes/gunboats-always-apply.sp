static Handle g_detour_CTFGameRules_ApplyOnDamageAliveModifyRules;
static int    g_offset_CTakeDamageInfo_m_iDamagedOtherPlayers;

void GunboatsAlwaysApply_Setup(Handle game_config) {
    g_detour_CTFGameRules_ApplyOnDamageAliveModifyRules =
        CheckedDHookCreateFromConf(game_config, "CTFGameRules::ApplyOnDamageAliveModifyRules");

    g_offset_CTakeDamageInfo_m_iDamagedOtherPlayers =
        CheckedGameConfGetKeyValueInt(game_config, "CTakeDamageInfo::m_iDamagedOtherPlayers");

    CreateBoolConVar("sm_gunboats_always_apply", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFGameRules_ApplyOnDamageAliveModifyRules, HOOK_PRE,
                           Detour_CTFGameRules_ApplyOnDamageAliveModifyRules, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFGameRules::ApplyOnDamageAliveModifyRules");
    }
}

static MRESReturn Detour_CTFGameRules_ApplyOnDamageAliveModifyRules(Address self, Handle ret,
                                                                    Handle params) {
    DHookSetParamObjectPtrVar(params, 1, g_offset_CTakeDamageInfo_m_iDamagedOtherPlayers,
                              ObjectValueType_Int, 0);
    return MRES_Handled;
}
