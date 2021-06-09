void GhostifySoldierStatue_Setup() {
    ConVar cvar =
        CreateConVar("sm_rest_in_peace_rick_may", "0", _, FCVAR_NOTIFY, true, 0.0, true, 255.0);

    cvar.AddChangeHook(OnConVarChange);

    CallConVarUpdateHook(cvar, OnConVarChange);
}

static void OnConVarChange(ConVar cvar, const char[] before, const char[] after) {
    int i = -1;

    while ((i = FindEntityByClassname(i, "entity_soldier_statue")) != -1) {
        GhostifySoldierStatue(i, cvar.IntValue);
    }

    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    DHookToggleEntityListener(ListenType_Created, OnEntityCreated, cvar.BoolValue);
}

static void OnEntityCreated(int entity, const char[] classname) {
    int alpha = FindConVar("sm_rest_in_peace_rick_may").IntValue;

    if (StrEqual(classname, "entity_soldier_statue")) {
        GhostifySoldierStatue(entity, alpha);
    }
}

static void GhostifySoldierStatue(int entity, int alpha) {
    if (alpha) {
        LogDebug("Ghostifying statue with index %d", entity);
        SetEntityRenderMode(entity, RENDER_TRANSTEXTURE);
        SetEntityRenderColor(entity, 255, 255, 255, 255 - alpha);

        SetEntProp(entity, Prop_Data, "m_nSolidType", 0);
        SetEntProp(entity, Prop_Send, "m_CollisionGroup", 1);
    } else {
        LogDebug("Un-Ghostifying statue with index %d", entity);
        SetEntityRenderMode(entity, RENDER_NORMAL);

        SetEntProp(entity, Prop_Data, "m_nSolidType", 2);
        SetEntProp(entity, Prop_Send, "m_CollisionGroup", 0);
    }
}
