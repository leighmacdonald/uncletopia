#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public Action onCmdAutoTeamAction(int clientId, int argc)
{
    if (gDisableAutoTeam.BoolValue) {
        KickClient(clientId, "Please stop trying to stack :(");

        char auth_id[50];
        if(!GetClientAuthId(clientId, AuthId_Steam3, auth_id, sizeof auth_id, true))
        {
            ReplyToCommand(clientId, "Failed to get auth_id of user: %d", clientId);
            return Plugin_Continue;
        }

        char name[64];
        if(!GetClientName(clientId, name, sizeof name))
        {
            gbLog("Failed to get user name?");
            return Plugin_Continue;
        }

        gbLog("Autoteam blocked: %s [%s]", name, auth_id);
        return Plugin_Handled;
    }

	return Plugin_Continue;
}