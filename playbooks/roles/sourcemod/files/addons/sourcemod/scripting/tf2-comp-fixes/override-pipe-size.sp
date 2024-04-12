static ConVar g_cvar;

static Handle g_call_CBaseEntity_SetCollisionBounds;
static Handle g_detour_CTFWeaponBaseGun_FirePipeBomb;

void OverridePipeSize_Setup(Handle game_config) {
    StartPrepSDKCall(SDKCall_Entity);

    if (!PrepSDKCall_SetFromConf(game_config, SDKConf_Signature,
                                 "CBaseEntity::SetCollisionBounds")) {
        SetFailState("Failed to finalize SDK call to CBaseEntity::SetCollisionBounds");
    }

    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
    PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);

    g_call_CBaseEntity_SetCollisionBounds = EndPrepSDKCall();
    g_detour_CTFWeaponBaseGun_FirePipeBomb =
        CheckedDHookCreateFromConf(game_config, "CTFWeaponBaseGun::FirePipeBomb");

    g_cvar = CreateConVar("sm_override_pipe_size", "0", _, FCVAR_NOTIFY, true, 0.0, true, 1000.0);

    g_cvar.AddChangeHook(WhenConVarChange);

    CallConVarUpdateHook(g_cvar, WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFWeaponBaseGun_FirePipeBomb, HOOK_POST,
                           Detour_CTFWeaponBaseGun_FirePipeBomb, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFWeaponBaseGun::FirePipeBomb");
    }
}

static MRESReturn Detour_CTFWeaponBaseGun_FirePipeBomb(Handle hReturn, Handle hParams) {
    int entity = DHookGetReturn(hReturn);

    if (entity == -1) {
        return MRES_Ignored;
    }

    bool cf_debug = FindConVar("sm_cf_debug").BoolValue;
    if (cf_debug) {
        LogDebug("Pipe collision bounds before");
        LogDebugCollisionBounds(entity);
    }

    float mins[3], maxs[3], x = g_cvar.FloatValue / 2.0;
    mins[0] = mins[1] = mins[2] = -x;
    maxs[0] = maxs[1] = maxs[2] = x;

    SDKCall(g_call_CBaseEntity_SetCollisionBounds, entity, mins, maxs);

    if (cf_debug) {
        LogDebug("Pipe collision bounds after");
        LogDebugCollisionBounds(entity);
    }

    return MRES_Handled;
}

static void LogDebugCollisionBounds(int entity) {
    float mins[3], maxs[3];

    GetEntPropVector(entity, Prop_Data, "m_vecMins", mins);
    GetEntPropVector(entity, Prop_Data, "m_vecMaxs", maxs);

    // clang-format off
    LogDebug(
        "{ %.2f, %.2f, %.2f }, { %.2f, %.2f, %.2f }",
        mins[0], mins[1], mins[2],
        maxs[0], maxs[1], maxs[2]
    );
    // clang-format on
}
