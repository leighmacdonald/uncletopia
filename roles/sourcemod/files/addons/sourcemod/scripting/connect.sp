#pragma semicolon 1 // Force strict semicolon mode.
#pragma newdecls required // Force new syntax

#include <sourcemod>
#define REQUIRE_EXTENSIONS
#include <connect>

public bool OnClientPreConnectEx(const char[] name, char password[255], const char[] ip, const char[] steamID, char rejectReason[255])
{
	PrintToServer("----------------\nName: %s\nPassword: %s\nIP: %s\nSteamID: %s\n----------------", name, password, ip, steamID);

	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, steamID);

	if (admin == INVALID_ADMIN_ID)
	{
		return true;
	}

	if (GetAdminFlag(admin, Admin_Root))
	{
		GetConVarString(FindConVar("sv_password"), password, 255);
	}

	return true;
}
