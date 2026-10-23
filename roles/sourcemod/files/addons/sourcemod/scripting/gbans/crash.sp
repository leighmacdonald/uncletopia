#pragma semicolon 1
#pragma newdecls required

#include <files>
#include <sourcemod>

char g_accelerator_log_path[128];
char g_crash_log_path[128];
char g_crash_id[64];
char g_stored_crash_id[15];
char g_reported_crash_id[15];

Handle g_accelerator_log_handle;
Handle g_crash_log_handle;

public
void checkCrashStatus() {
    // Get last Crash id after restart
    if (!g_accelerator_log_handle || !g_crash_log_handle) {
        return;
    }

    FileSeek(g_accelerator_log_handle, -sizeof(g_crash_id), SEEK_END);
    ReadFileString(g_accelerator_log_handle, g_crash_id, sizeof(g_crash_id));
    int crash_id_index = StrContains(g_crash_id, "Crash ID: ");
    if (crash_id_index == -1) {
        return;
    }

    g_crash_id[crash_id_index + 10 + 14] = '\0';
    ReplaceString(g_crash_id[crash_id_index], sizeof(g_crash_id), "Crash ID: ", "", false);
    TrimString(g_crash_id[crash_id_index]);

    char sLine[128];
    while (!IsEndOfFile(g_crash_log_handle) && ReadFileLine(g_crash_log_handle, sLine, sizeof(sLine))) {
        // Get Stored Crash id after restart
        strcopy(g_stored_crash_id, sizeof(g_stored_crash_id), sLine);
        TrimString(g_stored_crash_id);
    }

    if (StrEqual(g_stored_crash_id, g_crash_id[crash_id_index])) {
        return;
    }

    strcopy(g_reported_crash_id, sizeof(g_reported_crash_id), g_crash_id[crash_id_index]);

    JSONObject obj = new JSONObject();
    obj.SetString("crashId", g_reported_crash_id);

    postHTTPRequest("/connect/discord.v1.DiscordService/SendMessageCrash", obj, onCrashRespReceived);
}

void onCrashRespReceived(HTTPResponse response, any value) {
    if (response.Status != HTTPStatus_OK) {
        PrintRPCError(response);
        return;
    }

    WriteFileLine(g_crash_log_handle, "%s", g_reported_crash_id);
    FlushFile(g_crash_log_handle);
}
