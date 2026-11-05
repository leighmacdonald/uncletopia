#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include "common.sp"
#include "globals.sp"

// STATS_MAX_BUCKETS bounds the per-client stats cache; the backend currently
// reports one entry per time bucket (daily, weekly, monthly, yearly, alltime).
#define STATS_MAX_BUCKETS 8
// STATS_MAX_CLIENTS bounds the per-client cache. The Source engine caps
// MaxClients at 64, so 65 covers every valid client index.
#define STATS_MAX_CLIENTS 65

// Per-client cache of the /stats menu contents. The backend returns every
// time bucket in a single response; each bucket's rank and kills are stashed
// here when the menu is built so a selection can be printed to chat without a
// second round-trip to gbans.
int  gStatsRank[STATS_MAX_CLIENTS][STATS_MAX_BUCKETS];
int  gStatsKills[STATS_MAX_CLIENTS][STATS_MAX_BUCKETS];
char gStatsBucket[STATS_MAX_CLIENTS][STATS_MAX_BUCKETS][32];

/**
 * /stats opens a menu of the player's stats, one option per time bucket
 * showing that window's rank and kills. The backend rate limits each player to
 * a single lookup every five minutes and answers with HTTP 429 while cooling
 * down.
 */
public
Action onCmdStats(int clientId, int argc) {
    if (!isValidClient(clientId)) {
        return Plugin_Continue;
    }

    if (gToken[0] == '\0') {
        ReplyToCommand(clientId, "[GB] Not authenticated with gbans yet, try again later");
        authenticateServer();
        return Plugin_Handled;
    }

    char authId[32];
    if (!GetClientAuthId(clientId, AuthId_SteamID64, authId, sizeof authId)) {
        ReplyToCommand(clientId, "Failed to get auth_id of user: %d", clientId);
        return Plugin_Continue;
    }

    JSON_Object obj = new JSON_Object();
    obj.SetString("steamId", authId);

    postHTTPRequest("/connect/sourcemod.v1.PluginService/SMPlayerStats", obj, onStatsRespReceived, clientId);

    return Plugin_Handled;
}

void onStatsRespReceived(Handle request, bool failure, bool successful, EHTTPStatusCode status, any value, any unused) {
    int clientId = view_as<int>(value);
    if (!isValidClient(clientId)) {
        delete request;
        return;
    }

    switch (status) {
    case k_EHTTPStatusCode429TooManyRequests: {
        delete request;
        PrintToChat(clientId, "[Stats] You can only use /stats once every 5 minutes");
        return;
    }
    case k_EHTTPStatusCode401Unauthorized: {
        PrintRPCError(request, failure, status);
        delete request;
        authenticateServer();
        PrintToChat(clientId, "[Stats] Server authentication expired, re-authenticating. Please try again shortly.");
        return;
    }
    case k_EHTTPStatusCode200OK: {
        JSON_Object data = GetResponseJSON(request);
        if (data == null) {
            delete request;
            PrintToChat(clientId, "[Stats] Failed to load your stats, please try again later");
            return;
        }

        showStatsMenu(clientId, data);
        json_cleanup_and_delete(data);
        delete request;
        return;
    }
    default: {
        PrintRPCError(request, failure, status);
        delete request;
        PrintToChat(clientId, "[Stats] Failed to load your stats, please try again later");
        return;
    }
    }
}

void showStatsMenu(int clientId, JSON_Object data) {
    if (clientId < 1 || clientId >= STATS_MAX_CLIENTS) {
        return;
    }

    JSON_Array buckets = view_as<JSON_Array>(data.GetObject("buckets"));
    int        count   = buckets != null ? buckets.Length : 0;
    if (count > STATS_MAX_BUCKETS) {
        count = STATS_MAX_BUCKETS;
    }

    if (count < 1) {
        PrintToChat(clientId, "[Stats] No stats are available for you yet");
        return;
    }

    Menu menu = CreateMenu(MenuHandler_Stats);
    SetMenuTitle(menu, "Your Stats:");

    char bucketStr[32];
    char itemText[128];
    char itemValue[8];
    for (int i = 0; i < count; i++) {
        JSON_Object bucket = buckets.GetObject(i);
        if (bucket == null) {
            continue;
        }

        if (!bucket.GetString("timeBucket", bucketStr, sizeof bucketStr)) {
            bucketStr[0] = '\0';
        }
        int rank  = readJsonUint64(bucket, "rank");
        int kills = readJsonUint64(bucket, "kills");

        strcopy(gStatsBucket[clientId][i], sizeof gStatsBucket[clientId], bucketStr);
        gStatsRank[clientId][i]  = rank;
        gStatsKills[clientId][i] = kills;

        Format(itemValue, sizeof itemValue, "%d", i);
        formatBucketItem(itemText, sizeof itemText, bucketStr, rank, kills);
        menu.AddItem(itemValue, itemText);
    }

    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, clientId, MENU_TIME_FOREVER);
}

public
int MenuHandler_Stats(Menu menu, MenuAction action, int clientId, int selectedId) {
    if (action == MenuAction_Select) {
        char itemValue[8];
        menu.GetItem(selectedId, itemValue, sizeof itemValue);
        int bucketIndex = StringToInt(itemValue);
        if (bucketIndex < 0 || bucketIndex >= STATS_MAX_BUCKETS) {
            return 0;
        }

        printBucketToChat(clientId, bucketIndex);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

void printBucketToChat(int clientId, int bucketIndex) {
    if (clientId < 1 || clientId >= STATS_MAX_CLIENTS || bucketIndex < 0 || bucketIndex >= STATS_MAX_BUCKETS) {
        return;
    }

    char playerName[64];
    if (!GetClientName(clientId, playerName, sizeof playerName)) {
        strcopy(playerName, sizeof playerName, "Player");
    }

    char name[32];
    if (!timeBucketDisplayName(gStatsBucket[clientId][bucketIndex], name, sizeof name)) {
        strcopy(name, sizeof name, "stats");
    }

    int rank  = gStatsRank[clientId][bucketIndex];
    int kills = gStatsKills[clientId][bucketIndex];

    if (rank > 0) {
        PrintToChat(clientId, "[Stats] %s (%s): Rank #%d with %d kills", playerName, name, rank, kills);
    } else {
        PrintToChat(clientId, "[Stats] %s (%s): Unranked with %d kills", playerName, name, kills);
    }
}

// readJsonUint64 reads a protobuf uint64 field. ConnectRPC's JSON encoding
// emits uint64 as a decimal string, so the value is read as a string and
// parsed instead.
stock int readJsonUint64(JSON_Object obj, const char[] key) {
    char buf[32];
    if (!obj.GetString(key, buf, sizeof buf)) {
        return 0;
    }
    return StringToInt(buf);
}

// timeBucketDisplayName maps the wire time-bucket enum name to a friendly label.
stock bool timeBucketDisplayName(const char[] bucket, char[] out, int outLen) {
    if (StrEqual(bucket, "TIME_BUCKET_DAILY")) {
        strcopy(out, outLen, "today");
        return true;
    } else if (StrEqual(bucket, "TIME_BUCKET_WEEKLY")) {
        strcopy(out, outLen, "week");
        return true;
    } else if (StrEqual(bucket, "TIME_BUCKET_MONTHLY")) {
        strcopy(out, outLen, "month");
        return true;
    } else if (StrEqual(bucket, "TIME_BUCKET_YEARLY")) {
        strcopy(out, outLen, "year");
        return true;
    } else if (StrEqual(bucket, "TIME_BUCKET_ALLTIME")) {
        strcopy(out, outLen, "all time");
        return true;
    }
    return false;
}

// formatBucketItem builds the menu option text for a single time bucket.
stock void formatBucketItem(char[] out, int outLen, const char[] bucket, int rank, int kills) {
    char name[32];
    if (!timeBucketDisplayName(bucket, name, sizeof name)) {
        strcopy(name, sizeof name, "Unknown");
    }

    if (rank > 0) {
        Format(out, outLen, "%s: Rank #%d, %d kills", name, rank, kills);
    } else {
        Format(out, outLen, "%s: Unranked, %d kills", name, kills);
    }
}
