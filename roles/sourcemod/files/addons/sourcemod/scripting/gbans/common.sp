#pragma semicolon 1

void readConfig() {
    char localPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, localPath, sizeof(localPath), "configs/%s", "gbans.cfg");
#if defined DEBUG
    PrintToServer("[GB] Using config file: %s", localPath);
#endif
    KeyValues kv = new KeyValues("gbans");
    if (!kv.ImportFromFile(localPath)) {
        PrintToServer("[GB] No config file could be found");
    } else {
        kv.GetString("host", g_host, sizeof(g_host), "http://localhost");
        g_port = kv.GetNum("port", 6006);
        kv.GetString("server_name", g_server_name, sizeof(g_server_name), "default");
        kv.GetString("server_key", g_server_key, sizeof(g_server_key), "");
    }
    delete kv;
}

public
bool parseReason(const char[] reasonStr, banReason &reason) {
    int reasonInt = StringToInt(reasonStr, 10);
    if (reasonInt <= 0 || reasonInt < view_as<int>(custom) || reasonInt > view_as<int>(itemDescriptions)) {
        return false;
    }
    reason = view_as<banReason>(reasonInt);
    return true;
}

System2HTTPRequest newReq(System2HTTPResponseCallback cb, const char[] path) {
    char fullAddr[1024];
    Format(fullAddr, sizeof(fullAddr), "%s%s", g_host, path);
    System2HTTPRequest httpRequest = new System2HTTPRequest(cb, fullAddr);
    httpRequest.SetPort(g_port);
    httpRequest.SetHeader("Content-Type", "application/json");
    if (strlen(g_access_token) > 0) {
        httpRequest.SetHeader("Authorization", g_access_token);
    }
    return httpRequest;
}
