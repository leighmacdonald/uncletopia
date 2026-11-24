#define ORDER_LEN 11
static const TFClassType ORDER[ORDER_LEN] = {
    TFClass_DemoMan,
    TFClass_Medic,
    TFClass_Soldier,
    TFClass_Soldier,
    TFClass_Scout,
    TFClass_Scout,
    TFClass_Pyro,
    TFClass_Heavy,
    TFClass_Engineer,
    TFClass_Sniper,
    TFClass_Spy,
};

#define COLLISION_GROUP_PLAYER 5
#define COLLISION_GROUP_IN_VEHICLE 10

#define MAX_LAST_SPAWNS 64

static ConVar g_convar;

static int g_labels[MAX_LAST_SPAWNS * 2];
static int g_label_count = 0;

void ClassOrderedSpawnpoints_Setup() {
    g_convar = CreateBoolConVar("sm_class_ordered_spawnpoints", WhenConVarChange);
    CreateBoolConVar("cf_spawn_order", WhenDebugConVarChange);
    HookEvent("recalculate_holidays", WhenRoundSetup, EventHookMode_Pre);
}

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (cvar.BoolValue) {
        PresetBase();
    } else {
        UnsetAll();
    }
}

static void WhenRoundSetup(Event event, const char[] name, bool dontBroadcast) {
    if (!g_convar.BoolValue) {
        return;
    }

    PresetBase();

    for (int client = 1; client <= MaxClients; client++) {
        if (IsClientInGame(client) && IsPlayerAlive(client)) {
            SetEntityCollisionGroup(client, COLLISION_GROUP_IN_VEHICLE);
        }
    }

    RequestFrame(RestoreCollisionGroups);
}

static void UnsetAll() {
    int entity;

    while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1) {
        int old = GetEntProp(entity, Prop_Data, "m_spawnflags");
        LogDebug("- It was %d before", old);
        SetEntProp(entity, Prop_Data, "m_spawnflags", 0x1ff); // 9 bits all high
    }
}

static void PresetBase() {
    char red_last[64] = "";
    char blu_last[64] = "";

    int entity;
    int red = 0;
    int blu = 0;

    while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1) {
        int team = GetEntProp(entity, Prop_Data, "m_iTeamNum");

        if (team == 0) {
            team = GetEntProp(entity, Prop_Data, "m_iInitialTeamNum");
        }

        if (team != 2 && team != 3) continue;

        LogDebug("Found a RED/BLU spawn point: %d", entity);

        int wrote = 0;
        char control_point_name[64];
        if (HasEntProp(entity, Prop_Data, "m_iszControlPointName")) {
            wrote = GetEntPropString(entity, Prop_Data, "m_iszControlPointName", control_point_name, sizeof(control_point_name));
        }

        if (wrote == 0) {
            LogDebug("- It's not attached to a control point");
            // This is most likely KOTH, in which we process all team spawnpoints
        } else if (team == 2 && StrEqual(control_point_name, red_last)) {
            LogDebug("- It's attached to known RED last");
        } else if (team == 3 && StrEqual(control_point_name, blu_last)) {
            LogDebug("- It's attached to known BLU last");
        } else {
            int control_point = FindControlPointByName(control_point_name);
            if (control_point == -1) {
                LogDebug("- Couldn't find which control point it's attached to!!!");
                continue;
            }

            int index = GetEntProp(control_point, Prop_Data, "m_iPointIndex");

            if (index == 4) {
                red_last = control_point_name;
                LogDebug("- It's attached to the RED last, by the way iTeamNum is %d", team);
            } else if (index == 0) {
                blu_last = control_point_name;
                LogDebug("- It's attached to the BLU last, by the way iTeamNum is %d", team);
            } else {
                LogDebug("- It's attached to a control point we don't care about: %d", index);
                continue;
            }
        }

        TFClassType cls;
        if (team == 2) {
            cls = red < ORDER_LEN ? ORDER[red] : TFClass_Unknown;
            red += 1;
        } else if (team == 3) {
            cls = blu < ORDER_LEN ? ORDER[blu] : TFClass_Unknown;
            blu += 1;
        }

        LogDebug("- Limiting it to this class type only: %d", cls);
        SetSpawnClass(entity, cls);
    }
}

static int FindControlPointByName(const char[] target) {
    int entity;
    char name[64];

    while ((entity = FindEntityByClassname(entity, "team_control_point")) != -1) {
        if (!GetEntPropString(entity, Prop_Data, "m_iName", name, sizeof(name))) {
            continue;
        }

        if (StrEqual(name, target)) {
            return entity;
        }
    }

    return -1;
}

static void SetSpawnClass(int entity, TFClassType cls) {
    int flags;

    if (cls == TFClass_Unknown) {
        flags = 0x200; // toggle the tenth bit, it will not match any class, but it is not zero
                       // we don't want it to be zero because the game skips the check if it is
    } else {
        flags = 1 << view_as<int>(cls) - 1;
    }

    int old = GetEntProp(entity, Prop_Data, "m_spawnflags");
    LogDebug("- It was %d before", old);
    SetEntProp(entity, Prop_Data, "m_spawnflags", flags);
}

static void RestoreCollisionGroups() {
    for (int client = 1; client <= MaxClients; client++) {
        if (IsClientInGame(client)
            && GetEntProp(client, Prop_Send, "m_CollisionGroup") == COLLISION_GROUP_IN_VEHICLE) {
            SetEntityCollisionGroup(client, COLLISION_GROUP_PLAYER);
        }
    }
}

static void WhenDebugConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (cvar.BoolValue) {
        CreateLabels();
    } else {
        DestroyLabels();
    }
}

static void CreateLabels() {
    char red_last[64] = "";
    char blu_last[64] = "";

    int entity;
    int red = 0;
    int blu = 0;

    while ((entity = FindEntityByClassname(entity, "info_player_teamspawn")) != -1) {
        int team = GetEntProp(entity, Prop_Data, "m_iTeamNum");

        if (team == 0) {
            team = GetEntProp(entity, Prop_Data, "m_iInitialTeamNum");
        }

        if (team != 2 && team != 3) continue;

        int wrote = 0;
        char control_point_name[64];
        if (HasEntProp(entity, Prop_Data, "m_iszControlPointName")) {
            wrote = GetEntPropString(entity, Prop_Data, "m_iszControlPointName", control_point_name, sizeof(control_point_name));
        }

        if (wrote == 0) {
        } else if (team == 2 && StrEqual(control_point_name, red_last)) {
        } else if (team == 3 && StrEqual(control_point_name, blu_last)) {
        } else {
            int control_point = FindControlPointByName(control_point_name);
            if (control_point == -1) {
                continue;
            }

            int index = GetEntProp(control_point, Prop_Data, "m_iPointIndex");

            if (index == 4) {
                red_last = control_point_name;
            } else if (index == 0) {
                blu_last = control_point_name;
            } else {
                continue;
            }
        }

        if (team == 2) {
            CreateLabel(entity, team, red);
            red += 1;
        } else if (team == 3) {
            CreateLabel(entity, team, blu);
            blu += 1;
        }
    }
}

static void CreateLabel(int spawn, int team, int slot) {
    if (g_label_count == sizeof(g_labels)) {
        return;
    }

    int label = CreateEntityByName("point_worldtext");

    if (label == -1) {
        LogDebug("Failed to create point_worldtext");
        return;
    }

    char text[4];
    Format(text, sizeof(text), "%d", slot);

    float origin[3];
    GetEntPropVector(spawn, Prop_Data, "m_vecAbsOrigin", origin);
    origin[2] += 10.0;

    DispatchKeyValue(label, "message", text);
    DispatchKeyValue(label, "color", team == 2 ? "255 100 100 255" : "120 170 255 255");
    DispatchKeyValue(label, "textsize", "12");
    DispatchKeyValue(label, "orientation", "2");
    DispatchKeyValueVector(label, "origin", origin);
    DispatchSpawn(label);

    g_labels[g_label_count++] = EntIndexToEntRef(label);
}

void DestroyLabels() {
    for (int i = 0; i < g_label_count; i++) {
        int label = EntRefToEntIndex(g_labels[i]);

        if (label != INVALID_ENT_REFERENCE) {
            RemoveEntity(label);
        }
    }

    g_label_count = 0;
}
