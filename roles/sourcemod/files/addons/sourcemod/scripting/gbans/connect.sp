#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public
Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
    event.BroadcastDisabled = GetConVarBool(gb_hide_connections);
    return Plugin_Continue;
}

public
Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    event.BroadcastDisabled = GetConVarBool(gb_hide_connections);
    return Plugin_Continue;
}
