#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

public bool OnClientConnect(int clientId, char[] rejectMsg, int maxLen)
{
	gPlayers[clientId].authed = false;
	gPlayers[clientId].banType = BSUnknown;
	return true;
}


public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = gHideConnections.BoolValue;
	return Plugin_Continue;
}


public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = gHideConnections.BoolValue;
	return Plugin_Continue;
}


public void OnClientAuthorized(int clientId, const char[] auth)
{
	char ip[16];
	GetClientIP(clientId, ip, sizeof ip);

	char name[32];
	GetClientName(clientId, name, sizeof name);

	/* Do not check bots nor check player with lan steamid. */
	if(auth[0] == 'B'/*|| auth[9] == 'L'*/)
	{
		gPlayers[clientId].authed = true;
		gPlayers[clientId].ip = ip;
		gPlayers[clientId].banType = BSUnknown;
		return ;
	}
#if defined DEBUG	
	gbLog("Checking ban state for: %s", auth);
#endif	
	checkPlayer(clientId, auth, ip, name);
}


public bool OnClientPreConnectEx(const char[] name, char password[255]  , const char[] ip, const char[] steamID, char rejectReason[255]  )
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
