static Handle g_detour_CTFPlayer_TeamFortress_CalculateMaxSpeed;

void RemoveMedicAttachSpeed_Setup(Handle game_config) {
    g_detour_CTFPlayer_TeamFortress_CalculateMaxSpeed =
        CheckedDHookCreateFromConf(game_config, "CTFPlayer::TeamFortress_CalculateMaxSpeed");

    CreateBoolConVar("sm_remove_medic_attach_speed", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFPlayer_TeamFortress_CalculateMaxSpeed, HOOK_PRE, Detour_Pre,
                           cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFPlayer::TeamFortress_CalculateMaxSpeed");
    }
}

static MRESReturn Detour_Pre(int self, Handle ret, Handle params) {
    if (DHookGetParam(params, 1)) {
        DHookSetReturn(ret, 0.0);
        return MRES_Override;
    }

    return MRES_Ignored;
}
