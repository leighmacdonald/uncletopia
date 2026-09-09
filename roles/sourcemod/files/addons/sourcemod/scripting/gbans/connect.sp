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


// Snapshot incumbents (and admin incumbents) before the mass reconnect.
// Called from gbans.sp OnMapEnd. Cannot define OnMapEnd here because the
// main plugin file already implements that forward.
void Connect_OnMapEnd()
{
	if (g_ReturningPlayers == null)
	{
		g_ReturningPlayers = new StringMap();
	}
	if (g_RejoinAdminSnapshot == null)
	{
		g_RejoinAdminSnapshot = new StringMap();
	}
	g_ReturningPlayers.Clear();
	g_RejoinAdminSnapshot.Clear();

	char auth[32];
	char norm[32];
	int count = 0;
	int adminCount = 0;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i) || IsClientSourceTV(i) || IsClientReplay(i))
		{
			continue;
		}
		if (!GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth), false))
		{
			continue;
		}
		NormalizeRejoinSteamID(auth, norm, sizeof(norm));
		g_ReturningPlayers.SetValue(norm, GetTime());
		count++;

		int flags = GetUserFlagBits(i);
		if (flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION || CheckCommandAccess(i, "sm_reskick_immunity", ADMFLAG_RESERVATION, false))
		{
			g_RejoinAdminSnapshot.SetValue(norm, 1);
			adminCount++;
		}
	}

	gbLog("Rejoin snapshot: %d returning, %d admins", count, adminCount);
}


// Timestamp the start of the rejoin window. Called from gbans.sp OnMapStart.
void Connect_OnMapStart()
{
	g_MapStartTime = GetTime();
	if (gb_rejoin_grace != null && gb_rejoin_grace.IntValue > 0)
	{
		CreateTimer(float(gb_rejoin_grace.IntValue) + 30.0, Timer_ClearRejoinSnapshot, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}


public Action Timer_ClearRejoinSnapshot(Handle timer)
{
	if (!IsGraceActive())
	{
		if (g_ReturningPlayers != null)
		{
			g_ReturningPlayers.Clear();
		}
		if (g_RejoinAdminSnapshot != null)
		{
			g_RejoinAdminSnapshot.Clear();
		}
		gbLog("Rejoin snapshot cleared (grace expired)");
	}
	else
	{
		CreateTimer(30.0, Timer_ClearRejoinSnapshot, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	return Plugin_Stop;
}


// STEAM_0 vs STEAM_1 universe prefix differs between engine versions.
// Normalize so snapshot lookups match the Connect extension format.
stock void NormalizeRejoinSteamID(const char[] input, char[] output, int maxlen)
{
	strcopy(output, maxlen, input);
	if (StrContains(output, "STEAM_0:") == 0)
	{
		output[6] = '1';
	}
}


stock bool IsGraceActive()
{
	if (gb_rejoin_grace == null)
	{
		return false;
	}
	int grace = gb_rejoin_grace.IntValue;
	if (grace <= 0 || g_MapStartTime <= 0)
	{
		return false;
	}
	return (GetTime() - g_MapStartTime) < grace;
}


// Admins with reservation (or root) always bypass the rejoin queue.
// Falls back to the OnMapEnd admin snapshot because the admin cache is
// rebuilt async via HTTP and may be cold during the post-mapchange burst.
stock bool IsAdminSteamID(const char[] steamID, const char[] normalized)
{
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamID);
	if (admin == INVALID_ADMIN_ID && !StrEqual(steamID, normalized))
	{
		admin = FindAdminByIdentity(AUTHMETHOD_STEAM, normalized);
	}
	if (admin != INVALID_ADMIN_ID)
	{
		if (GetAdminFlag(admin, Admin_Reservation) || GetAdminFlag(admin, Admin_Root))
		{
			return true;
		}
		return false;
	}
	if (g_RejoinAdminSnapshot != null)
	{
		int dummy;
		if (g_RejoinAdminSnapshot.GetValue(normalized, dummy))
		{
			return true;
		}
	}
	return false;
}


stock bool IsReturningSteamID(const char[] normalized)
{
	if (!IsGraceActive() || g_ReturningPlayers == null)
	{
		return false;
	}
	int dummy;
	return g_ReturningPlayers.GetValue(normalized, dummy);
}


// Counts real human slots currently held (includes connecting clients,
// excludes bots/STV/Replay). The connecting client that triggered
// OnClientPreConnectEx is not counted yet, so >= MaxClients means full.
stock int CountRealClients()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i) && !IsClientSourceTV(i) && !IsClientReplay(i))
		{
			count++;
		}
	}
	return count;
}


stock bool IsClientProtected(int client)
{
	int flags = GetUserFlagBits(client);
	if (IsFakeClient(client) || flags & ADMFLAG_ROOT || flags & ADMFLAG_RESERVATION || CheckCommandAccess(client, "sm_reskick_immunity", ADMFLAG_RESERVATION, false))
	{
		return true;
	}
	return false;
}


stock bool IsClientReturning(int client)
{
	char auth[32];
	char norm[32];
	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), false))
	{
		return false;
	}
	NormalizeRejoinSteamID(auth, norm, sizeof(norm));
	return IsReturningSteamID(norm);
}


// Evict a SteamID from the returning-players queue. Only removes from
// g_ReturningPlayers; g_RejoinAdminSnapshot is intentionally left intact
// so AFK-kicked admins keep their reservation bypass.
stock void RemoveReturningSteamID(const char[] norm)
{
	if (g_ReturningPlayers == null)
	{
		return;
	}
	g_ReturningPlayers.Remove(norm);
}


stock void RemoveReturningClient(int client)
{
	if (client < 1 || client > MaxClients || !IsClientConnected(client))
	{
		return;
	}
	char auth[32];
	char norm[32];
	if (!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), false))
	{
		return;
	}
	NormalizeRejoinSteamID(auth, norm, sizeof(norm));
	RemoveReturningSteamID(norm);
	gbLog("Removed AFK-kicked player %N (%s) from returning queue", client, norm);
}


// Called by afk_manager before KickClient(). The forward is optional:
// afk_manager.inc defaults to required=0, so gbans loads fine when
// afk_manager.smx is disabled. Only "afk_kick" evicts; all other events
// (afk_move, afk_spawn_move) keep queue priority.
public Action AFKM_OnAFKEvent(const char[] name, int client)
{
	if (StrEqual(name, "afk_kick"))
	{
		RemoveReturningClient(client);
	}
	return Plugin_Continue;
}


public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255]  )
{
	gbLog("OnClientPreConnectEx: %s : %s : %s : %s", name, password, ip, steamID);

	char norm[32];
	NormalizeRejoinSteamID(steamID, norm, sizeof(norm));
	bool debug = gb_rejoin_debug != null && gb_rejoin_debug.BoolValue;

	// 1. Admins (reservation/root) always get in, never kick. They bypass
	// the rejoin queue and sv_visiblemaxplayers; the engine owns the final
	// slot decision (reserved slots / MaxClients).
	if (IsAdminSteamID(steamID, norm))
	{
		return true;
	}

	// 2. Returning incumbents win the race during the grace window.
	if (IsReturningSteamID(norm))
	{
		if (debug)
		{
			gbLog("Returning player %s (%s) prioritized", name, steamID);
		}
		if (CountRealClients() >= MaxClients)
		{
			int victim = selectKickClient(false);
			if (victim)
			{
				KickClientEx(victim, "%s", "Slot reserved for returning player, please retry");
				gbLog("Returning %s (%s) displaced newcomer %d", name, steamID, victim);
			}
			else
			{
				gbLog("Returning %s (%s) joined full server, no newcomer victim", name, steamID);
			}
		}
		return true;
	}

	// 3. Newcomers get in when there is space.
	if (CountRealClients() < MaxClients)
	{
		return true;
	}

	// 4. Full server: reject newcomers with retry so incumbents win the race.
	if (IsGraceActive())
	{
		int remaining = gb_rejoin_grace.IntValue - (GetTime() - g_MapStartTime);
		if (remaining < 5)
		{
			remaining = 5;
		}
		Format(rejectReason, 255, "Server is reserving slots for returning players, please retry in ~%d seconds", remaining);
		gbLog("Rejected newcomer %s (%s): grace active, %ds remaining", name, steamID, remaining);
	}
	else
	{
		Format(rejectReason, 255, "%s", "Server is full, please try again");
		gbLog("Rejected newcomer %s (%s): server full", name, steamID);
	}
	return false;
}


// Victim selection for making room for a returning incumbent.
// Only newcomers are eligible, never fellow returners, admins, or otherwise
// protected clients. Prefers connecting clients, then spectators, then the
// newest in-game players. Returns 0 when nobody is kickable.
// (Admins never displace anyone; they bypass the queue entirely.)
// Previously this picked the longest-connected (highest GetClientTime)
// player, which punished loyal incumbents.
int selectKickClient(bool forAdmin = true)
{
	int best = 0;
	int bestScore = -1;
	float bestTime = 0.0;
	bool haveBest = false;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i) || IsClientSourceTV(i) || IsClientReplay(i))
		{
			continue;
		}
		if (IsClientProtected(i))
		{
			continue;
		}

		bool returning = IsClientReturning(i);
		if (!forAdmin && returning)
		{
			continue;
		}

		int score;
		if (!IsClientInGame(i))
		{
			score = 30;
		}
		else if (IsClientObserver(i))
		{
			score = 20;
		}
		else
		{
			score = 10;
		}
		if (forAdmin && returning)
		{
			score -= 5;
		}

		float time = 0.0;
		if (IsClientInGame(i))
		{
			time = GetClientTime(i);
		}

		if (score > bestScore || (score == bestScore && (!haveBest || time < bestTime)))
		{
			best = i;
			bestScore = score;
			bestTime = time;
			haveBest = true;
		}
	}

	return best;
}
