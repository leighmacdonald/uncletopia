#pragma semicolon 1
#pragma newdecls required

#include <files>
#include <sourcemod>

#define CRASH_ID_LENGTH 14

char g_accelerator_log_path[128];
char g_crash_log_path[128];
char g_crash_id[64];
char g_stored_crash_id[CRASH_ID_LENGTH + 1];
char g_reported_crash_id[CRASH_ID_LENGTH + 1];

Handle g_accelerator_log_handle;
Handle g_crash_log_handle;

public
void checkCrashStatus() {
    // Get last Crash id after restart
    if (g_accelerator_log_handle == null || g_crash_log_handle == null) {
        return;
    }

    int tailLength = sizeof(g_crash_id);
    if (FileSize(g_accelerator_log_path) < tailLength) {
        return;
    }

    if (!FileSeek(g_accelerator_log_handle, -tailLength, SEEK_END)) {
        LogError("Failed to seek to the end of %s", g_accelerator_log_path);

        return;
    }

    if (ReadFileString(g_accelerator_log_handle, g_crash_id, sizeof(g_crash_id)) == -1) {
        return;
    }

    int crash_id_index = StrContains(g_crash_id, "Crash ID: ");
    if (crash_id_index == -1) {
        return;
    }

    int crash_id_start = crash_id_index + 10;

    // Accelerator crash ids are always CRASH_ID_LENGTH characters. Return when
    // the log tail was truncated so the terminator is never written past the
    // end of the buffer.
    if (crash_id_start + CRASH_ID_LENGTH > strlen(g_crash_id)) {
        return;
    }

    g_crash_id[crash_id_start + CRASH_ID_LENGTH] = '\0';
    TrimString(g_crash_id[crash_id_start]);

    char sLine[128];
    while (!IsEndOfFile(g_crash_log_handle) && ReadFileLine(g_crash_log_handle, sLine, sizeof(sLine))) {
        // Get Stored Crash id after restart
        strcopy(g_stored_crash_id, sizeof(g_stored_crash_id), sLine);
        TrimString(g_stored_crash_id);
    }

    if (StrEqual(g_stored_crash_id, g_crash_id[crash_id_start])) {
        return;
    }

    strcopy(g_reported_crash_id, sizeof(g_reported_crash_id), g_crash_id[crash_id_start]);

    JSON_Object obj = new JSON_Object();
    obj.SetString("crashId", g_reported_crash_id);

    postHTTPRequest("/connect/discord.v1.DiscordService/SendMessageCrash", obj, onCrashRespReceived);
}

void onCrashRespReceived(Handle request, bool failure, bool successful, EHTTPStatusCode status, any value1,
                         any value2) {
    if (status != k_EHTTPStatusCode200OK) {
        PrintRPCError(request, failure, status);
        delete request;

        return;
    }

    delete request;

    WriteFileLine(g_crash_log_handle, "%s", g_reported_crash_id);
    FlushFile(g_crash_log_handle);
}
