#define PIPEBOMB_REMOTE 4 // sticky bomb launcher
#define PIPEBOMB_REMOTE_PRACTICE 14 // sticky jumper

#define MASK 31 // 0b11111
#define MASK_SIZE 5

static ConVar g_convar_pitch_speed;

static Handle g_call_CTFGrenadeLauncher_GetProjectileSpeed;

static Handle g_detour_CTFWeaponBaseGun_FirePipeBomb;
static Handle g_detour_CTFGrenadePipebombProjectile_Create;

void RemovePipeSpread_Setup(Handle game_config) {
    if (GetOs(game_config) == Windows) {
        CreateConVar("sm_remove_pipe_spread", "0", "NOT SUPPORTED ON WINDOWS",
                     FCVAR_NOTIFY, true, 0.0, true, 0.0);
        return;
    }

    StartPrepSDKCall(SDKCall_Entity);

    if (!PrepSDKCall_SetFromConf(game_config, SDKConf_Signature,
                                 "CTFGrenadeLauncher::GetProjectileSpeed")) {
        SetFailState("Failed to finalize SDK call to CTFGrenadeLauncher::GetProjectileSpeed");
    }

    PrepSDKCall_SetReturnInfo(SDKType_Float, SDKPass_Plain);
    g_call_CTFGrenadeLauncher_GetProjectileSpeed = EndPrepSDKCall();

    g_detour_CTFWeaponBaseGun_FirePipeBomb =
        CheckedDHookCreateFromConf(game_config, "CTFWeaponBaseGun::FirePipeBomb");
    g_detour_CTFGrenadePipebombProjectile_Create =
        CheckedDHookCreateFromConf(game_config, "CTFGrenadePipebombProjectile::Create");

    CreateBoolConVar("sm_remove_pipe_spread", OnConVarChange);
    g_convar_pitch_speed = CreateConVar("sm_remove_pipe_spread_pitch_speed", "-1125.89",
                    "Rotation speed in the forward direction to give to pipes after their spread has been fixed",
                     FCVAR_NOTIFY, true, -10000.0, true, 10000.0);
}

static void OnConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (!DHookToggleDetour(g_detour_CTFWeaponBaseGun_FirePipeBomb, HOOK_PRE,
                           Detour_CTFWeaponBaseGun_FirePipeBomb, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFWeaponBaseGun::FirePipeBomb");
    }

    if (!DHookToggleDetour(g_detour_CTFGrenadePipebombProjectile_Create, HOOK_PRE,
                           Detour_CTFGrenadePipebombProjectile_Create, cvar.BoolValue)) {
        SetFailState("Failed to toggle detour on CTFGrenadePipebombProjectile::Create");
    }
}

static MRESReturn Detour_CTFWeaponBaseGun_FirePipeBomb(int weapon, Handle hReturn, DHookParam hParams) {
    int projectile_type = hParams.Get(2);

    if (IsStickyBomb(projectile_type)) {
        return MRES_Ignored;
    }

    // The fractional part of the speed is always zero, so we don't lose anything by using RoundToFloor
    int speed = RoundToFloor(SDKCall(g_call_CTFGrenadeLauncher_GetProjectileSpeed, weapon));

    LogDebug("Projectile speed: %d, type: %d", speed, projectile_type);

    /*
      We use iPipeBombType parameter to store two values:
       - projectile speed
       - projectile type
      Since the max value of iPipeBombType is 17 (Cannonball), we only need 5 bits to store the projectile type
      The remaining bits are used to store the speed value
    */
    speed = speed << MASK_SIZE;
    hParams.Set(2, speed | projectile_type);

    return MRES_ChangedHandled;
}

static MRESReturn Detour_CTFGrenadePipebombProjectile_Create(Handle hReturn, DHookParam hParams) {
    // Now we need to "unpack" the projectile speed and type from iPipeBombType
    int param = hParams.Get(7);
    int projectile_type = param & MASK;

    if (IsStickyBomb(projectile_type)) {
        return MRES_Ignored;
    }

    hParams.Set(7, projectile_type);

    int speed = (param & ~MASK) >> MASK_SIZE;
    float launchSpeed = float(speed);

    LogDebug("Pipe launch speed: %.2f", launchSpeed);

    float eye_angles[3], velocity[3], fwd[3], up[3];

    hParams.GetVector(2, eye_angles);
    GetAngleVectors(eye_angles, fwd, NULL_VECTOR, up);

    // Velocity: launchSpeed * forward + 200 * up;
    ScaleVector(fwd, launchSpeed);
    ScaleVector(up, 200.0);
    AddVectors(fwd, up, velocity);

    hParams.SetVector(3, velocity);

    float ang_velocity[3];
    hParams.GetVector(4, ang_velocity);

    LogDebug("Angular velocity before: { %.2f, %.2f, %.2f }", ang_velocity[0], ang_velocity[1], ang_velocity[2]);

    // If the x-component is nonzero, then the y-component is randomized
    if (ang_velocity[0] != 0) {
        ang_velocity[1] = g_convar_pitch_speed.FloatValue;
        hParams.SetVector(4, ang_velocity);
    }

    LogDebug("Angular velocity after: { %.2f, %.2f, %.2f }", ang_velocity[0], ang_velocity[1], ang_velocity[2]);

    return MRES_ChangedHandled;
}

static bool IsStickyBomb(int projectile_type) {
    return projectile_type == PIPEBOMB_REMOTE || projectile_type == PIPEBOMB_REMOTE_PRACTICE;
}
