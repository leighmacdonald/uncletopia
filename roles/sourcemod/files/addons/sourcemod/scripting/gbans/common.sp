#pragma semicolon 1

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
    char server_host[PLATFORM_MAX_PATH];
    g_host.GetString(server_host, sizeof(server_host));
    int port = g_port.IntValue;
    char fullAddr[1024];
    Format(fullAddr, sizeof(fullAddr), "%s%s", server_host, path);
    System2HTTPRequest httpRequest = new System2HTTPRequest(cb, fullAddr);
    httpRequest.SetPort(port);
    httpRequest.SetHeader("Content-Type", "application/json");
    if (strlen(g_access_token) > 0) {
        httpRequest.SetHeader("Authorization", g_access_token);
    }
    return httpRequest;
}
