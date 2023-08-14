void InhibitExtendfreeze_Setup() { CreateBoolConVar("sm_inhibit_extendfreeze", WhenConVarChange); }

static void WhenConVarChange(ConVar cvar, const char[] before, const char[] after) {
    if (cvar.BoolValue == TruthyConVar(before)) {
        return;
    }

    if (cvar.BoolValue) {
        AddCommandListener(WhenExtendfreeze, "extendfreeze");
    } else {
        RemoveCommandListener(WhenExtendfreeze, "extendfreeze");
    }
}

static Action WhenExtendfreeze(int client, const char[] command, int argc) {
    LogDebug("Inhibiting `extendfreeze` from %N", client);
    return Plugin_Handled;
}
