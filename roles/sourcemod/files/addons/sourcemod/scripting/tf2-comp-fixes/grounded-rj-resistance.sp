static Handle g_detour_CTFPlayer_OnTakeDamage_Alive;

static int g_offset_CTakeDamageInfo_m_hAttacker;
static int g_offset_CTakeDamageInfo_m_flDamage;
static int g_offset_CTakeDamageInfo_m_bitsDamageType;

void GroundedRjResistance_Setup(Handle game_config) {
    if (GetOs(game_config) == Windows) {
        CreateConVar("sm_grounded_rj_resistance", "0", "NOT SUPPORTED ON WINDOWS", FCVAR_NOTIFY,
                     true, 0.0, true, 0.0);
        return;
    }

    g_detour_CTFPlayer_OnTakeDamage_Alive =
        CheckedDHookCreateFromConf(game_config, "CTFPlayer::OnTakeDamage_Alive");

    g_offset_CTakeDamageInfo_m_hAttacker =
        CheckedGameConfGetKeyValueInt(game_config, "CTakeDamageInfo::m_hAttacker");
    g_offset_CTakeDamageInfo_m_flDamage =
        CheckedGameConfGetKeyValueInt(game_config, "CTakeDamageInfo::m_flDamage");
    g_offset_CTakeDamageInfo_m_bitsDamageType =
        CheckedGameConfGetKeyValueInt(game_config, "CTakeDamageInfo::m_bitsDamageType");

    CreateBoolConVar("sm_grounded_rj_resistance", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFPlayer_OnTakeDamage_Alive, HOOK_PRE,
                           Detour_CTFPlayer_OnTakeDamage_Alive, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFPlayer_OnTakeDamage_Alive");
    }
}

static MRESReturn Detour_CTFPlayer_OnTakeDamage_Alive(int victim, Handle hReturn,
                                                      DHookParam hParams) {
    int attacker = DHookGetParamObjectPtrVar(hParams, 1, g_offset_CTakeDamageInfo_m_hAttacker,
                                             ObjectValueType_Ehandle);

    if (victim != attacker || TF2_GetPlayerClass(attacker) != TFClass_Soldier
        || !(GetEntityFlags(victim) & (FL_ONGROUND | FL_INWATER))) {
        return MRES_Ignored;
    }

    int damage_type = DHookGetParamObjectPtrVar(
        hParams, 1, g_offset_CTakeDamageInfo_m_bitsDamageType, ObjectValueType_Int);
    if (!(damage_type & DMG_BLAST)) {
        return MRES_Ignored;
    }

    float damage = DHookGetParamObjectPtrVar(hParams, 1, g_offset_CTakeDamageInfo_m_flDamage,
                                             ObjectValueType_Float);

    float scale = FindConVar("tf_damagescale_self_soldier").FloatValue;

    LogDebug("Applying self-damage resistance (%f -> %f)", damage, damage * scale);

    damage *= scale;
    DHookSetParamObjectPtrVar(hParams, 1, g_offset_CTakeDamageInfo_m_flDamage,
                              ObjectValueType_Float, damage);

    return MRES_Handled;
}
