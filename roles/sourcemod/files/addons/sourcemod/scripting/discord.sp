#pragma semicolon 1
#pragma newdecls required

#include <ripext>
#include <sourcemod>

#define PLUGIN_VERSION "2.0.0"

#define WEBHOOK_MAXLEN 64
#define URL_MAXLEN 512
#define MSG_MAXLEN 4096

ArrayList g_aMsgs = null;
ArrayList g_aWebhook = null;

Handle g_hTimer = INVALID_HANDLE;

bool g_bSending = false;
bool g_bSlowdown = false;

public Plugin myinfo = {
    name = "Discord API (ripext)",
    author = ".#Zipcore, Credits: Shavit, bara, ImACow and Phire, leighmacdonald",
    description = "This plugin lets you send messages to discord and slack",
    version = PLUGIN_VERSION,
    url = "https://github.com/leighmacdonald/sm-discord" // originally from www.zipcore.net
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("Discord_SendMessage", Native_SendMessage);

    RegPluginLibrary("discord");

    return APLRes_Success;
}

public void OnPluginStart() {
    CreateConVar("discord_version", PLUGIN_VERSION, "Discord API version",
                 FCVAR_DONTRECORD | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);

    RegAdminCmd("sm_testdiscord", Command_Test, ADMFLAG_ROOT, "Sends a test msg.");
}

public void OnMapStart() {
    RestartMessageTimer(false);
}

public void OnMapEnd() {
    if (g_hTimer != INVALID_HANDLE) {
        delete g_hTimer;
        g_hTimer = INVALID_HANDLE;
    }
    g_bSending = false;
}

public Action Command_Test(int client, int args) {
    if (args < 2) {
        ReplyToCommand(client, "sm_testdiscord <webhook> <message>");
        return Plugin_Handled;
    }

    char sWebhook[WEBHOOK_MAXLEN];
    GetCmdArg(1, sWebhook, sizeof(sWebhook));

    char sMessage[MSG_MAXLEN];
    GetCmdArg(2, sMessage, sizeof(sMessage));

    char sBuffer[URL_MAXLEN];
    for (int i = 3; i <= args; i++) {
        GetCmdArg(i, sBuffer, sizeof(sBuffer));
        Format(sMessage, sizeof(sMessage), "%s %s", sMessage, sBuffer);
    }

    char sUrl[URL_MAXLEN];
    if (!GetWebHook(sWebhook, sUrl, sizeof(sUrl))) {
        ReplyToCommand(client, "Error: Webhook: %s - Url: %s", sWebhook, sUrl);
        return Plugin_Handled;
    }

    StoreMsg(sWebhook, sMessage);
    ReplyToCommand(client, "Message Send: Webhook: %s - Message: %s", sWebhook, sMessage);

    return Plugin_Handled;
}

public any Native_SendMessage(Handle plugin, int numParams) {
    char sWebhook[WEBHOOK_MAXLEN];
    GetNativeString(1, sWebhook, sizeof(sWebhook));

    char sMessage[MSG_MAXLEN];
    GetNativeString(2, sMessage, sizeof(sMessage));

    char sUrl[URL_MAXLEN];
    if (!GetWebHook(sWebhook, sUrl, sizeof(sUrl))) {
        LogError("Webhook config not found or invalid! Webhook: %s Url: %s", sWebhook, sUrl);
        LogError("Message: %s", sMessage);
        return 1;
    }

    StoreMsg(sWebhook, sMessage);

    return 0;
}

void StoreMsg(const char[] sWebhook, const char[] sMessage) {
    char sUrl[URL_MAXLEN];
    if (!GetWebHook(sWebhook, sUrl, sizeof(sUrl))) {
        LogError("Webhook config not found or invalid! Webhook: %s Url: %s", sWebhook, sUrl);
        LogError("Message: %s", sMessage);
        return;
    }

    if (g_aWebhook == null) {
        g_aWebhook = new ArrayList(WEBHOOK_MAXLEN);
        g_aMsgs = new ArrayList(MSG_MAXLEN);
    }

    g_aWebhook.PushString(sWebhook);
    g_aMsgs.PushString(sMessage);
}

public Action Timer_SendNextMessage(Handle timer, any data) {
    SendNextMsg();
    return Plugin_Continue;
}

void SendNextMsg() {
    // Still waiting for the previous request to complete.
    if (g_bSending) {
        return;
    }

    // Nothing to send.
    if (g_aWebhook == null || g_aWebhook.Length < 1) {
        return;
    }

    char sWebhook[WEBHOOK_MAXLEN];
    g_aWebhook.GetString(0, sWebhook, sizeof(sWebhook));

    char sMessage[MSG_MAXLEN];
    g_aMsgs.GetString(0, sMessage, sizeof(sMessage));

    char sUrl[URL_MAXLEN];
    if (!GetWebHook(sWebhook, sUrl, sizeof(sUrl)) || sUrl[0] == '\0') {
        LogError("Webhook config not found or invalid! Webhook: %s Url: %s", sWebhook, sUrl);
        LogError("Message: %s", sMessage);
        DropNextMsg();
        SendNextMsg();
        return;
    }

    bool bSlack = StrContains(sUrl, "slack") != -1;

    JSONObject obj = BuildPayload(sMessage, bSlack);
    if (obj == null) {
        // BuildPayload already logged the reason; the API would never accept it.
        DropNextMsg();
        SendNextMsg();
        return;
    }

    // sUrl is non-empty here (checked above); a malformed URL surfaces as a transport failure in the callback.
    HTTPRequest request = new HTTPRequest(sUrl);
    request.Timeout = 10;
    // The request handle is closed automatically once the request completes.
    request.Post(obj, OnRipComplete);
    delete obj;

    // Don't send new messages as long as we wait for a reply to this one (Discord rate limits).
    g_bSending = true;
}

// Builds the JSON body for a queued message. Returns null on failure.
JSONObject BuildPayload(const char[] sMessage, bool bSlack) {
    // Pre-formatted JSON payload (embeds etc. from sourcebans/calladmin) — pass it through.
    if (sMessage[0] == '{') {
        JSONObject obj = JSONObject.FromString(sMessage);
        if (obj == null) {
            LogError("[discord] Dropping malformed JSON payload: \"%s\"", sMessage);
        }
        return obj;
    }

    // Plain text — let ripext handle JSON escaping (quotes/newlines break manual string formatting).
    JSONObject obj = new JSONObject();
    if (obj == null) {
        LogError("[discord] Failed to allocate JSON payload");
        return null;
    }
    obj.SetString(bSlack ? "text" : "content", sMessage);
    return obj;
}

void DropNextMsg() {
    if (g_aWebhook != null && g_aWebhook.Length > 0) {
        g_aWebhook.Erase(0);
        g_aMsgs.Erase(0);
    }
}

void OnRipComplete(HTTPResponse response, any value, const char[] error) {
    // Transport-level failure (DNS, timeout, no route) — response is null, keep the message queued.
    if (response == null) {
        LogError("[discord] Request failed: %s", error);
        if (!g_bSlowdown) {
            RestartMessageTimer(true);
        }
        g_bSending = false;
        return;
    }

    HTTPStatus status = response.Status;
    if (status == HTTPStatus_TooManyRequests || status == HTTPStatus_InternalServerError) {
        // API is busy or too many messages sent recently — back off and retry the same message.
        if (!g_bSlowdown) {
            RestartMessageTimer(true);
        }
    } else if (status == HTTPStatus_BadRequest) {
        // Wrong msg format, API doesn't like it.
        char sMessage[MSG_MAXLEN];
        g_aMsgs.GetString(0, sMessage, sizeof(sMessage));

        LogError("[discord] Bad Request! Error Code: [400]. Check your message, the API doesn't like it! Message: \"%s\"",
                 sMessage);

        // Remove it, the API will never accept it like this.
        DropNextMsg();
    } else if (status == HTTPStatus_OK || status == HTTPStatus_NoContent) {
        if (g_bSlowdown) {
            RestartMessageTimer(false);
        }

        DropNextMsg();
    } else {
        // Unknown error.
        LogError("[discord] Error Code: [%d]", view_as<int>(status));

        DropNextMsg();
    }

    g_bSending = false;
    // Pump the next queued message immediately instead of waiting for the next timer tick.
    SendNextMsg();
}

void RestartMessageTimer(bool slowdown) {
    g_bSlowdown = slowdown;

    if (g_hTimer != INVALID_HANDLE) {
        delete g_hTimer;
        g_hTimer = INVALID_HANDLE;
    }

    g_hTimer = CreateTimer(slowdown ? 1.0 : 0.1, Timer_SendNextMessage, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

bool GetWebHook(const char[] sWebhook, char[] sUrl, int iLength) {
    KeyValues kv = new KeyValues("Discord");

    char sFile[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sFile, sizeof(sFile), "configs/discord.cfg");

    if (!FileExists(sFile)) {
        delete kv;
        SetFailState("[GetWebHook] \"%s\" not found!", sFile);
        return false;
    }

    kv.ImportFromFile(sFile);

    if (!kv.GotoFirstSubKey()) {
        delete kv;
        SetFailState("[GetWebHook] Can't find webhook for \"%s\"!", sFile);
        return false;
    }

    char sBuffer[WEBHOOK_MAXLEN];

    do {
        kv.GetSectionName(sBuffer, sizeof(sBuffer));

        if (StrEqual(sBuffer, sWebhook, false)) {
            kv.GetString("url", sUrl, iLength);
            delete kv;
            return true;
        }
    } while (kv.GotoNextKey());

    delete kv;

    return false;
}
