#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

const reportTimeout      = 30;
const reportMinReasonLen = 10;

public
Action onCmdReport(int clientId, int argc) {
    if (gReportStartedAtTime > 0) {
        ReplyToCommand(clientId, "A report is current in progress, please wait for it to complete");
        return Plugin_Stop;
    }
    gReportStartedAtTime = GetTime();
    ShowTargetMenu(clientId);
    return Plugin_Handled;
}

public
void ShowTargetMenu(int clientId) {
    Menu menu = CreateMenu(MenuHandler_Target);
    AddTargetsToMenu2(menu, clientId, COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_MULTI | COMMAND_FILTER_NO_BOTS);
    SetMenuTitle(menu, "Select A Player:");
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, clientId, MENU_TIME_FOREVER);
}

void resetReportStatus() {
    gReportSourceId         = -1;
    gReportTargetId         = -1;
    gReportStartedAtTime    = -1;
    gReportTargetReason     = unknown;
    gReportWaitingForReason = false;
}

public
Action OnClientSayCommand(int clientId, const char[] command, const char[] args) {
    if (!gReportWaitingForReason || clientId != gReportSourceId && gReportSourceId == -1
        || gReportTargetReason != custom) {
        return Plugin_Continue;
    } else if (StrEqual(args, "cancel", false)) {
        PrintToChat(gReportSourceId, "Report cancelled");
        resetReportStatus();
        return Plugin_Stop;
    } else if (strlen(args) < reportMinReasonLen) {
        PrintToChat(gReportSourceId, "Report reason too short, try again or type \"cancel\" to reset");
        return Plugin_Continue;
    }

    LogMessage("Got report reason: %s", args);
    report(gReportSourceId, gReportTargetId, gReportTargetReason, args);

    return Plugin_Continue;
}

public
bool report(int sourceId, int targetId, GB_BanReason reason, const char[] reasonText) {
    char sourceSid[32];
    if (!GetClientAuthId(sourceId, AuthId_SteamID64, sourceSid, sizeof sourceSid)) {
        PrintToChat(sourceId, "Failed to get sourceId of user: %d", sourceId);
        resetReportStatus();
        return false;
    }
    char targetSid[32];
    if (!GetClientAuthId(targetId, AuthId_SteamID64, targetSid, sizeof targetSid)) {
        PrintToChat(sourceId, "Failed to get targetId of user: %d", targetId);
        resetReportStatus();
        return false;
    }

    char reasonStr[64];
    if (!BanReasonToApiString(reason, reasonStr, sizeof reasonStr)) {
        PrintToChat(sourceId, "Invalid report reason");
        resetReportStatus();
        return false;
    }

    char description[512];
    if (reason == custom) {
        if (strlen(reasonText) < 10) {
            PrintToChat(sourceId, "Report reason too short, must be at least 10 characters");
            resetReportStatus();
            return false;
        }
        strcopy(description, sizeof description, reasonText);
    } else {
        char reasonName[32];
        if (!BanReasonDisplayName(reason, reasonName, sizeof reasonName)) {
            PrintToChat(sourceId, "Invalid report reason");
            resetReportStatus();
            return false;
        }
        Format(description, sizeof description, "In-game report: %s", reasonName);
    }

    JSONObject obj = new JSONObject();
    obj.SetString("sourceId", sourceSid);
    obj.SetString("targetId", targetSid);
    obj.SetString("description", description);
    obj.SetString("reason", reasonStr);
    if (reason == custom) {
        obj.SetString("reasonText", reasonText);
    }

    if (SourceTV_IsRecording()) {
        int tick = SourceTV_GetRecordingTick();
        if (tick >= 0) {
            obj.SetInt("demoTick", tick);
        }
    }

    postHTTPRequest("/connect/ban.v1.ReportService/ReportCreate", obj, onReportRespReceived, sourceId);

    return true;
}

void onReportRespReceived(HTTPResponse response, any clientId) {
    if (response.Status != HTTPStatus_OK) {
        if (response.Status == HTTPStatus_Conflict) {
            PrintToChat(clientId, "[Report] User has already been reported, thanks.");
            resetReportStatus();
            return;
        }

        LogError("Invalid report response status: %d", response.Status);

        PrintToChat(clientId, "[Report] Error creating report");
        resetReportStatus();
        return;
    }

    JSONObject data             = view_as<JSONObject>(response.Data);
    JSONObject reportWithAuthor = view_as<JSONObject>(data.Get("report"));
    JSONObject createdReport    = view_as<JSONObject>(reportWithAuthor.Get("report"));

    int reportId = createdReport.GetInt("reportId");

    char path[PLATFORM_MAX_PATH];
    Format(path, sizeof path, "/report/%d", reportId);

    char url[1024];
    makeURL(path, url, sizeof url);

    PrintToChat(clientId, "[Report] Report created succesfully, thanks for your help");
    PrintToChat(clientId, "[Report] %s", url);

    resetReportStatus();
}

public
void ShowReasonMenu(int clientId) {
    Menu menu = CreateMenu(MenuHandler_Reason);
    menu.AddItem("cheating", "Cheating");
    menu.AddItem("racism", "Racism");
    menu.AddItem("harassment", "Harassment");
    menu.AddItem("exploiting", "Exploiting");
    menu.AddItem("spam", "Spam");
    menu.AddItem("languageUsed", "Language");
    menu.AddItem("profile", "Profile");
    menu.AddItem("itemDescriptions", "Items/Descriptions");
    menu.AddItem("custom", "Custom");

    SetMenuTitle(menu, "Select A Reason:");
    SetMenuExitBackButton(menu, true);
    DisplayMenu(menu, clientId, MENU_TIME_FOREVER);
}

public
Action Timer_checkReportState() {
    if (gReportStartedAtTime - GetTime() > reportTimeout) {
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public
int MenuHandler_Target(Menu menu, MenuAction action, int clientId, int selectedId) {
    if (action == MenuAction_Cancel) {
        resetReportStatus();
        CloseHandle(menu);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    } else if (action == MenuAction_Select) {
        int  userId, targetId;
        char sTargetUserID[30];
        menu.GetItem(selectedId, sTargetUserID, sizeof sTargetUserID);
        userId = StringToInt(sTargetUserID);

        if ((targetId = GetClientOfUserId(userId)) == 0) {
            PrintToChat(clientId, "[Report] %t", "Player no longer available");
            resetReportStatus();
            return -1;
        }
        gReportSourceId = clientId;
        gReportTargetId = targetId;
        ShowReasonMenu(gReportSourceId);
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

public
int MenuHandler_Reason(Menu menu, MenuAction action, int clientId, int selectedId) {
    if (action == MenuAction_Cancel) {
        resetReportStatus();
        CloseHandle(menu);
    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    } else if (action == MenuAction_Select) {
        char sInfo[64];
        GetMenuItem(menu, selectedId, sInfo, sizeof sInfo);
        if (StrEqual(sInfo, "cheating")) {
            gReportTargetReason = cheating;
        } else if (StrEqual(sInfo, "racism")) {
            gReportTargetReason = racism;
        } else if (StrEqual(sInfo, "harassment")) {
            gReportTargetReason = harassment;
        } else if (StrEqual(sInfo, "exploiting")) {
            gReportTargetReason = exploiting;
        } else if (StrEqual(sInfo, "spam")) {
            gReportTargetReason = spam;
        } else if (StrEqual(sInfo, "languageUsed")) {
            gReportTargetReason = languageUsed;
        } else if (StrEqual(sInfo, "profile")) {
            gReportTargetReason = profile;
        } else if (StrEqual(sInfo, "itemDescriptions")) {
            gReportTargetReason = itemDescriptions;
        } else if (StrEqual(sInfo, "custom")) {
            gReportTargetReason = custom;
        } else {
            PrintToChat(gReportSourceId, "[Report] Unsupported reason value");
            resetReportStatus();
            return -1;
        }
        if (gReportTargetReason == custom) {
            PrintToChat(gReportSourceId, "[Report] Enter your reason in chat, it will be hidden from other users");
            gReportWaitingForReason = true;
            return 0;
        }
        return report(gReportSourceId, gReportTargetId, gReportTargetReason, "");
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}
