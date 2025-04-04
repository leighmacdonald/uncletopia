#pragma semicolon 1

public void NotifyForward(int clientID, const char[] detection, int detections) {
    static GlobalForward hNotifyForward;

    if (hNotifyForward == null) {
		hNotifyForward = new GlobalForward("Stac_OnNotify", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	}

    // playername
    char clientName[64];
    GetClientName(clientID, clientName, sizeof(clientName));
    Discord_EscapeString(clientName, sizeof(clientName));
    json_escape_string(clientName, sizeof(clientName));

    char steamid[MAX_AUTHID_LENGTH];
    // ok we store these on client connect & auth, this shouldn't be null
    if ( SteamAuthFor[clientID][0]) {
        strcopy(steamid, sizeof(steamid), SteamAuthFor[clientID]);
    } else { 
        steamid = "";
    }

    Call_StartForward(hNotifyForward);

    Call_PushCell(clientID);
    Call_PushString(clientName);
    Call_PushString(steamid);
    Call_PushCell(detections);

    Call_Finish();
}