void ProjectilesIgnoreTeammates_Setup() {
    CreateBoolConVar("sm_projectiles_ignore_teammates", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    DHookToggleEntityListener(ListenType_Created, WhenEntityCreated, cvar.BoolValue);
}

static void WhenEntityCreated(int entity, const char[] classname) {
    if (strncmp(classname, "tf_projectile_", 14) != 0) {
        return;
    }

    if (StrEqual(classname[14], "healing_bolt")) {
        return;
    }

    if (StrEqual(classname[14], "ball_ornament")) {
        LogDebug("Hooking Touch for Ornament projectile with index %d", entity);

        SDKHook(entity, SDKHook_Touch, Hook_Touch);
    }

    if (INVALID_HOOK_ID
        == DHookEntity(g_hook_CBaseProjectile_CanCollideWithTeammates, HOOK_PRE, entity, _,
                       Hook_CBaseProjectile_CanCollideWithTeammates)) {
        LogDebug("Nullifying teammate collide for projectile with index %d", entity);
        SetFailState("Failed to hook CBaseProjectile::CanCollideWithTeammates");
    }
}

static MRESReturn Hook_CBaseProjectile_CanCollideWithTeammates(int self, Handle ret) {
    DHookSetReturn(ret, false);
    return MRES_Supercede;
}

static Action Hook_Touch(int self, int other) {
    int owner = GetEntPropEnt(self, Prop_Data, "m_hOwnerEntity");

    if (other > 0 && other <= MaxClients && TF2_GetClientTeam(owner) == TF2_GetClientTeam(other)) {
        return Plugin_Continue;
    }

    return Plugin_Continue;
}
