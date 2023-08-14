static ConVar g_cvar;

void Debug_Setup() {
    g_cvar = CreateConVar("sm_cf_debug", "0", "Print debug statements in chat", FCVAR_NOTIFY, true,
                          0.0, true, 2.0);
}

void LogDebug(const char[] format, any...) {
    if (!g_cvar.BoolValue) {
        return;
    }

    char message[256];

    VFormat(message, sizeof(message), format, 2);

    if (g_cvar.IntValue >= 1) {
        LogMessage(message);
    }

    if (g_cvar.IntValue >= 2) {
        PrintToChatAll("[TF2 Competitive Fixes] Debug: %s", message);
    }
}
