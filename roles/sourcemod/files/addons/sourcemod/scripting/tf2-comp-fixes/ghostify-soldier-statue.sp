void GhostifySoldierStatue_Setup() {
    ConVar cvar =
        CreateConVar("sm_rest_in_peace_rick_may", "0", _, FCVAR_NOTIFY, true, 0.0, true, 255.0);

    cvar.AddChangeHook(WhenConVarChange);

    CallConVarUpdateHook(cvar, WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    int i = -1;

    while ((i = FindEntityByClassname(i, "entity_soldier_statue")) != -1) {
        GhostifySoldierStatue(i, cvar.IntValue);
    }

    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    DHookToggleEntityListener(ListenType_Created, WhenEntityCreated, cvar.BoolValue);
}

static void WhenEntityCreated(int entity, const char[] classname) {
    if (StrEqual(classname, "entity_soldier_statue")) {
        int alpha = FindConVar("sm_rest_in_peace_rick_may").IntValue;
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
