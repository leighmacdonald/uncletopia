void FixGhostCrossbowBolts_Setup() {
    CreateBoolConVar("sm_fix_ghost_crossbow_bolts", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    DHookToggleEntityListener(ListenType_Created, WhenEntityCreated, cvar.BoolValue);
}

static void WhenEntityCreated(int entity, const char[] classname) {
    if (StrEqual(classname, "tf_projectile_healing_bolt")) {
        LogDebug("Hooking Healing Bolt with index %d", entity);
        if (INVALID_HOOK_ID
            == DHookEntity(g_hook_CBaseProjectile_CanCollideWithTeammates, HOOK_PRE, entity, _,
                           Hook_CBaseProjectile_CanCollideWithTeammates)) {
            SetFailState("Failed to hook CBaseProjectile::CanCollideWithTeammates");
        }
    }
}

static MRESReturn Hook_CBaseProjectile_CanCollideWithTeammates(int self, Handle ret) {
    DHookSetReturn(ret, true);
    return MRES_Supercede;
}
