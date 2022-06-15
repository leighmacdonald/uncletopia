// Credits to https://github.com/laurirasanen/groundfix

static Handle g_detour_CTFGameMovement_SetGroundEntity;
static int    g_offset_CBaseTrace_plane_normal;
static int    g_offset_CGameMovement_player;

void FixSlopeBug_Setup(Handle game_config) {
    g_detour_CTFGameMovement_SetGroundEntity =
        CheckedDHookCreateFromConf(game_config, "CTFGameMovement::SetGroundEntity");

    g_offset_CBaseTrace_plane_normal =
        CheckedGameConfGetKeyValueInt(game_config, "CBaseTrace::plane::normal");

    g_offset_CGameMovement_player =
        CheckedGameConfGetKeyValueInt(game_config, "CGameMovement::player");

    CreateBoolConVar("sm_fix_slope_bug", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFGameMovement_SetGroundEntity, HOOK_PRE,
                           Detour_CTFGameMovement_SetGroundEntity, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFGameMovement::SetGroundEntity");
    }
}

static MRESReturn Detour_CTFGameMovement_SetGroundEntity(Address self, Handle params) {
    if (DHookIsNullParam(params, 1)) {
        return MRES_Ignored;
    }

    int player_ptr =
        LoadFromAddress(self + view_as<Address>(g_offset_CGameMovement_player), NumberType_Int32);

    int player = GetEntityFromAddress(view_as<Address>(player_ptr));

    if (GetEntityMoveType(player) != MOVETYPE_WALK) {
        return MRES_Ignored;
    }

    float plane[3], abs_velocity[3];

    DHookGetParamObjectPtrVarVector(params, 1, g_offset_CBaseTrace_plane_normal,
                                    ObjectValueType_Vector, plane);

    GetEntPropVector(player, Prop_Data, "m_vecAbsVelocity", abs_velocity);

    if (1 > plane[2] > 0.7 && GetVectorDotProduct(abs_velocity, plane) < 0.0) {
        float predicted_velocity[3];

        ClipVelocity(abs_velocity, plane, predicted_velocity);

        if (predicted_velocity[2] > 250.0) {
            LogDebug("Preventing Slope Bug for player %N", player);
            return MRES_Supercede;
        }
    }

    return MRES_Ignored;
}
