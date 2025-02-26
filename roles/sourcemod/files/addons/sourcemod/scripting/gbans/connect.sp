#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = GetConVarBool(gb_hide_connections);
	return Plugin_Continue;
}


public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = GetConVarBool(gb_hide_connections);
	return Plugin_Continue;
}

public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255]  )
{
	gbLog("OnClientPreConnectEx: %s : %s : %s : %s", name, password, ip, steamID);
	if(GetClientCount(false) < MaxClients)
	{
		return true;
	}

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamID);
	if(admin == INVALID_ADMIN_ID)
	{
		return true;
	}
	
	if(GetAdminFlag(admin, Admin_Reservation))
	{
		int target = selectKickClient();
		if(target)
		{
			KickClientEx(target, "%s", "Dropped for admin");
		}
	}

	return true;
}

int selectKickClient()
{
	float highestValue;
	int highestValueId;
	float highestSpecValue;
	int highestSpecValueId;
	bool specFound;
	float value;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientConnected(i))
		{
			continue;
		}

		int flags = GetUserFlagBits(i);
		if(IsFakeClient(i) || flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION || CheckCommandAccess(i, "sm_reskick_immunity", ADMFLAG_RESERVATION, false))
		{
			continue;
		}

		value = 0.0;
		if(IsClientInGame(i))
		{
			value = GetClientTime(i);
			if(IsClientObserver(i))
			{
				specFound = true;
				if(value > highestSpecValue)
				{
					highestSpecValue = value;
					highestSpecValueId = i;
				}
			}
		}

		if(value >= highestValue)
		{
			highestValue = value;
			highestValueId = i;
		}
	}

	if(specFound)
	{
		return highestSpecValueId;
	}

	return highestValueId;
}
