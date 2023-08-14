static Handle g_detour_CTFGameRules_DropHalloweenSoulPack;

void RemoveHalloweenSouls_Setup(Handle game_config) {
    g_detour_CTFGameRules_DropHalloweenSoulPack =
        CheckedDHookCreateFromConf(game_config, "CTFGameRules::DropHalloweenSoulPack");

    CreateBoolConVar("sm_remove_halloween_souls", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFGameRules_DropHalloweenSoulPack, HOOK_PRE,
                           Detour_CTFGameRules_DropHalloweenSoulPack, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFGameRules::DropHalloweenSoulPack");
    }
}

static MRESReturn Detour_CTFGameRules_DropHalloweenSoulPack(Address self, Handle ret,
                                                            Handle params) {
    LogDebug("Preventing Halloween Souls from spawning");
    return MRES_Supercede;
}
