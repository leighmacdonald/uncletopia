static ConVar g_convar;
static int g_offset;

void CabinetResetsCritHeals_Setup(Handle game_config) {
    g_convar = CreateBoolConVar("sm_cabinet_resets_crit_heals", WhenConVarChange);
    g_offset = GameConfGetOffset(game_config, "CTFPlayer::m_flLastDamageTime");
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    int entity = -1;
    while ((entity = FindEntityByClassname(entity, "func_regenerate")) != -1) {
        if (cvar.BoolValue) {
            EntityCreate_ReqFrame(entity);
        } else {
            SDKUnhook(entity, SDKHook_Touch, Hook_Touch);
        }
    }
}

void CabinetResetsCritHeals_OnEntityCreated(int entity, const char[] classname)
{
    if (!g_convar.BoolValue) {
        return;
    }

    if (!StrEqual(classname, "func_regenerate")) {
        return;
    }

    // A lot of entities are invalid until the frame after they spawn
    RequestFrame(EntityCreate_ReqFrame, entity);
}

static void EntityCreate_ReqFrame(int entity)
{
    if (entity < 1 || !IsValidEntity(entity)) {
        return;
    }

    SDKHook(entity, SDKHook_Touch, Hook_Touch);
}

static Action Hook_Touch(int entity, int other)
{
    // not a valid client index
    if (other < 1 || other > MaxClients) {
        return Plugin_Continue;
    }

    SetEntDataFloat(other, g_offset, 0.0);

    return Plugin_Continue;
}
