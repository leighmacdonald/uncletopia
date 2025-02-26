static Handle g_detour_PassServerEntityFilter;

void ProjectilesCollideWithCylinders_Setup(Handle game_config) {
    if (GetOs(game_config) == Windows) {
        CreateConVar("sm_projectiles_collide_with_cylinders", "0", "NOT SUPPORTED ON WINDOWS",
                     FCVAR_NOTIFY, true, 0.0, true, 0.0);
        return;
    }

    g_detour_PassServerEntityFilter =
        CheckedDHookCreateFromConf(game_config, "PassServerEntityFilter");

    CreateBoolConVar("sm_projectiles_collide_with_cylinders", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_PassServerEntityFilter, HOOK_POST,
                           Detour_PassServerEntityFilter, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on PassServerEntityFilter");
    }
}

static MRESReturn Detour_PassServerEntityFilter(Handle ret, Handle params) {
    // Not colliding
    if (!DHookGetReturn(ret)) {
        return MRES_Ignored;
    }

    int touch_ent = DHookGetParam(params, 1);
    int pass_ent  = DHookGetParam(params, 2);

    if (!IsValidEntity(touch_ent) || !IsValidEntity(pass_ent)) {
        return MRES_Ignored;
    }

    bool touch_is_player = touch_ent > 0 && touch_ent <= MaxClients && IsPlayerAlive(touch_ent);
    bool pass_is_player  = pass_ent > 0 && pass_ent <= MaxClients && IsPlayerAlive(pass_ent);

    if (touch_is_player && pass_is_player) {
        return MRES_Ignored;
    }

    int projectile_ent = touch_is_player ? pass_ent : touch_ent;

    char classname[64];
    GetEntityClassname(projectile_ent, classname, sizeof(classname));

    if (strncmp(classname, "tf_projectile_", 14) != 0) {
        return MRES_Ignored;
    }

    if (StrEqual(classname, "tf_projectile_pipe_remote")
        && GetEntProp(projectile_ent, Prop_Send, "m_bTouched")) {
        return MRES_Ignored;
    }

    float touch_pos[3], touch_mins[3], touch_maxs[3];
    float pass_pos[3], pass_mins[3], pass_maxs[3];

    GetEntPropVector(touch_ent, Prop_Send, "m_vecOrigin", touch_pos);
    GetEntPropVector(touch_ent, Prop_Send, "m_vecMins", touch_mins);
    GetEntPropVector(touch_ent, Prop_Send, "m_vecMaxs", touch_maxs);
    GetEntPropVector(pass_ent, Prop_Send, "m_vecOrigin", pass_pos);
    GetEntPropVector(pass_ent, Prop_Send, "m_vecMins", pass_mins);
    GetEntPropVector(pass_ent, Prop_Send, "m_vecMaxs", pass_maxs);

    float radius  = ((touch_maxs[X] - touch_mins[X]) + (pass_maxs[X] - pass_mins[X])) / 2.0;
    float sqrt_dx = touch_pos[X] - pass_pos[X], sqrt_dy = touch_pos[Y] - pass_pos[Y];

    if (sqrt_dx * sqrt_dx + sqrt_dy * sqrt_dy > radius * radius) {
        if (FindConVar("sm_cf_debug").BoolValue) {
            LogDebug("Projectile is in AABB but not in cylinder");
            LogDebug(" - Distance = %f", SquareRoot(sqrt_dx * sqrt_dx + sqrt_dy * sqrt_dy));
            LogDebug(" - Radius   = %f (%f + %f)", radius, (touch_maxs[X] - touch_mins[X]) / 2.0,
                     (pass_maxs[X] - pass_mins[X]) / 2.0);
        }

        DHookSetReturn(ret, false);
        return MRES_Override;
    }

    return MRES_Ignored;
}
