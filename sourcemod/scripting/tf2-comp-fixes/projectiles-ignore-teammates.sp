Handle g_detour_CTFGrenadePipebombProjectile_PipebombTouch;

void ProjectilesIgnoreTeammates_Setup(Handle game_config) {
    g_detour_CTFGrenadePipebombProjectile_PipebombTouch =
        CheckedDHookCreateFromConf(game_config, "CTFGrenadePipebombProjectile::PipebombTouch");

    CreateBoolConVar("sm_projectiles_ignore_teammates", OnConVarChange);
}

static void OnConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    DHookToggleEntityListener(ListenType_Created, OnEntityCreated, cvar.BoolValue);
}

static void OnEntityCreated(int entity, const char[] classname) {
    if (StrContains(classname, "tf_projectile_") != 0) {
        return;
    }

    if (StrEqual(classname[14], "healing_bolt")) {
        return;
    }

    if (StrEqual(classname[14], "ball_ornament")) {
        LogDebug("Hooking Touch for Ornament projectile with index %d", entity);
        if (INVALID_HOOK_ID == DHookEntity(g_detour_CTFGrenadePipebombProjectile_PipebombTouch,
                                           HOOK_PRE, entity, _,
                                           Hook_CTFGrenadePipebombProjectile_PipebombTouch)) {
            SetFailState("Failed to hook CTFGrenadePipebombProjectile::PipebombTouch");
        }
    }

    if (INVALID_HOOK_ID == DHookEntity(g_hook_CBaseProjectile_CanCollideWithTeammates, HOOK_PRE,
                                       entity, _, Hook_CBaseProjectile_CanCollideWithTeammates)) {
        LogDebug("Nullifying teammate collide for projectile with index %d", entity);
        SetFailState("Failed to hook CBaseProjectile::CanCollideWithTeammates");
    }
}

static MRESReturn Hook_CBaseProjectile_CanCollideWithTeammates(int self, Handle ret) {
    DHookSetReturn(ret, false);
    return MRES_Supercede;
}

static MRESReturn Hook_CTFGrenadePipebombProjectile_PipebombTouch(int self, Handle params) {
    int owner = GetEntPropEnt(self, Prop_Data, "m_hOwnerEntity");
    int other = DHookGetParam(params, 1);

    if (other > 0 && other <= MaxClients && TF2_GetClientTeam(owner) == TF2_GetClientTeam(other)) {
        return MRES_Supercede;
    }

    return MRES_Ignored;
}
