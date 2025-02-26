enum SolidToPlayerType {
    SolidToPlayerUseDefault = 0,
    SolidToPlayerYes,
    SolidToPlayerNo
}

void SolidBuildings_Setup() {
    CreateBoolConVar("sm_solid_buildings", WhenConVarChange);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    DHookToggleEntityListener(ListenType_Created, WhenEntityCreated, cvar.BoolValue);

    int entity = -1;

    while ((entity = FindEntityByClassname(entity, "obj_dispenser")) != -1) {
        SetSolidToPlayer(entity, cvar.BoolValue ? SolidToPlayerYes : SolidToPlayerNo);
    }

    while ((entity = FindEntityByClassname(entity, "obj_sentrygun")) != -1) {
        SetSolidToPlayer(entity, cvar.BoolValue ? SolidToPlayerYes : SolidToPlayerNo);
    }
}

static void WhenEntityCreated(int entity, const char[] classname) {
    if (StrEqual(classname, "obj_dispenser") || StrEqual(classname, "obj_sentrygun")) {
        LogDebug("Making %s with index %d solid to players", classname, entity);
        SetSolidToPlayer(entity, SolidToPlayerYes);
    }
}

static void SetSolidToPlayer(int entity, SolidToPlayerType val) {
    SetVariantInt(view_as<int>(val));
    AcceptEntityInput(entity, "SetSolidToPlayer");
}
