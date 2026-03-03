#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tfdb> // Include the Dodgeball plugin's natives
#include <clientprefs> // Include for cookie functions
#include <multicolors> // Include for colored chat and translations

#define PLUGIN_VERSION "2.0"

public Plugin myinfo =
{
	name = "[TF2] Dodgeball Speed HUD",
	author = "Silorak",
	description = "Displays the speed of active rockets to all players.",
	version = PLUGIN_VERSION,
	url = "https://github.com/Silorak/TF2-Dodgeball-Modified"
};

// ====================================================================================================
// Global Variables
// ====================================================================================================

ConVar CvarHudEnabled;
Handle DisplayTimer;
Handle CookieHudPref; // Handle for the client's HUD preference cookie.

// Tracks if the HUD is currently being displayed for a client.
bool IsHudVisible[MAXPLAYERS + 1];
// Tracks a client's personal preference for seeing the HUD.
bool HudEnabledForClient[MAXPLAYERS + 1];

// ====================================================================================================
// Plugin Lifecycle
// ====================================================================================================

public void OnPluginStart()
{
	CreateConVar("tfdb_speedhud_version", PLUGIN_VERSION, "Dodgeball Speed HUD Version", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_DONTRECORD);
	CvarHudEnabled = CreateConVar("tfdb_speedhud_enabled", "1", "Enable the rocket speed HUD for all players.", _, true, 0.0, true, 1.0);

	// Register the command for players to toggle the HUD.
	RegConsoleCmd("sm_speedhud", Command_ToggleHud, "Toggles the rocket speed HUD display.");
	RegConsoleCmd("sm_shud", Command_ToggleHud, "Toggles the rocket speed HUD display."); // Alias

	// Load the translations from the main Dodgeball plugin.
	LoadTranslations("tfdb.phrases.txt");

	// Register the cookie. The second argument is the default value.
	CookieHudPref = RegClientCookie("tfdb_speedhud_pref", "Toggle for the Dodgeball Speed HUD", CookieAccess_Public);

	// Hook the ConVar change to enable/disable the timer on the fly.
	CvarHudEnabled.AddChangeHook(OnConVarChanged);

	// Hook client connection to load their preference from cookies.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPostAdminCheck(i);
		}
	}

	// Start the timer if the plugin is loaded while the cvar is enabled.
	if (CvarHudEnabled.BoolValue)
	{
		StartDisplayTimer();
	}
}

public void OnPluginEnd()
{
	// Clean up the timer when the plugin unloads.
	StopDisplayTimer();
}

public void OnMapStart()
{
    // Check if the Dodgeball plugin is running and if the HUD is enabled.
    if (LibraryExists("tfdb") && CvarHudEnabled.BoolValue)
    {
        StartDisplayTimer();
    }
}

public void OnMapEnd()
{
	// Clean up the timer at the end of the map.
	StopDisplayTimer();
}

public void OnClientPostAdminCheck(int client)
{
	// Load the client's preference when they fully connect.
	char sCookie[8];
	GetClientCookie(client, CookieHudPref, sCookie, sizeof(sCookie));

	// Default to ON if the cookie is not set or is set to "1".
	if (sCookie[0] == '0')
	{
		HudEnabledForClient[client] = false;
	}
	else
	{
		HudEnabledForClient[client] = true;
	}
}

// ====================================================================================================
// ConVar & Command Management
// ====================================================================================================

public Action Command_ToggleHud(int client, int args)
{
	// This command is for players only.
	if (client == 0)
	{
		PrintToServer("This command can only be used by players.");
		return Plugin_Handled;
	}

	// Flip the player's preference.
	HudEnabledForClient[client] = !HudEnabledForClient[client];

	if (HudEnabledForClient[client])
	{
		// Set cookie to "1" for ON.
		SetClientCookie(client, CookieHudPref, "1");
		CPrintToChat(client, "%t", "Hud_Enabled");
	}
	else
	{
		// Set cookie to "0" for OFF.
		SetClientCookie(client, CookieHudPref, "0");
		CPrintToChat(client, "%t", "Hud_Disabled");
	}

	return Plugin_Handled;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == CvarHudEnabled)
	{
		if (StringToInt(newValue) == 1)
		{
			StartDisplayTimer();
		}
		else
		{
			StopDisplayTimer();
		}
	}
}

/**
 * Starts the main timer for displaying the HUD.
 */
void StartDisplayTimer()
{
	// Don't create a new timer if one already exists.
	if (DisplayTimer != null)
	{
		return;
	}
	// Create a repeating timer that calls DisplayHud every 0.1 seconds.
	DisplayTimer = CreateTimer(0.1, DisplayHud, _, TIMER_REPEAT);
}

/**
 * Stops the main display timer and clears the HUD for all players.
 */
void StopDisplayTimer()
{
	if (DisplayTimer != null)
	{
		KillTimer(DisplayTimer);
		DisplayTimer = null;
	}

	// Clear the HUD for any player who might still have it open.
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsHudVisible[i])
		{
			// Set an empty message to clear the HUD.
			SetHudTextParams(0.0, 0.0, 0.1, 255, 255, 255, 0, 0, 0.0, 0.0, 0.0);
			ShowHudText(i, 4, " ");
			IsHudVisible[i] = false;
		}
	}
}

// ====================================================================================================
// Core Logic
// ====================================================================================================

/**
 * Timer callback that runs continuously to update the HUD for all players.
 */
public Action DisplayHud(Handle timer)
{
	// Only run if the main Dodgeball plugin is enabled and the cvar is on.
	if (!CvarHudEnabled.BoolValue || !TFDB_IsDodgeballEnabled())
	{
		// Ensure the HUD is cleared if the plugin is disabled globally.
		StopDisplayTimer();
		return Plugin_Continue;
	}

	// --- Collect and sort active rockets ---
	int rocketIndices[MAX_ROCKETS];
	float rocketSpeeds[MAX_ROCKETS];
	int rocketCount = 0;

	for (int i = 0; i < MAX_ROCKETS; i++)
	{
		if (TFDB_IsValidRocket(i))
		{
			rocketIndices[rocketCount] = i;
			rocketSpeeds[rocketCount] = TFDB_GetRocketMphSpeed(i);
			rocketCount++;
		}
	}

	// --- Display logic based on rocket count ---
	if (rocketCount == 0)
	{
		// No rockets are active, clear the HUD for anyone who has it visible.
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsHudVisible[i] && IsClientInGame(i))
			{
				SetHudTextParams(0.0, 0.0, 0.1, 255, 255, 255, 0, 0, 0.0, 0.0, 0.0);
				ShowHudText(i, 4, " ");
				IsHudVisible[i] = false;
			}
		}
	}
	else if (rocketCount == 1)
	{
		// Single rocket: Display in the center.
		int rocketIndex = rocketIndices[0];
		float mphSpeed = rocketSpeeds[0];
		float huSpeed = TFDB_GetRocketSpeed(rocketIndex);
		int deflections = TFDB_GetRocketDeflections(rocketIndex);
		int rocketClass = TFDB_GetRocketClass(rocketIndex);
		char className[64];
		TFDB_GetRocketClassLongName(rocketClass, className, sizeof(className));
		
		char hudMessage[256];
		// Format the string first to avoid issues with ShowHudText.
		FormatEx(hudMessage, sizeof(hudMessage), "%t", "Hud_Speedometer", mphSpeed, huSpeed, deflections, rocketIndex + 1, className);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (HudEnabledForClient[i])
				{
					SetHudTextParams(-1.0, 0.85, 0.15, 100, 255, 100, 255, 0, 0.0, 0.0, 0.15);
					ShowHudText(i, 4, hudMessage);
					IsHudVisible[i] = true;
				}
				else if (IsHudVisible[i])
				{
					SetHudTextParams(0.0, 0.0, 0.1, 255, 255, 255, 0, 0, 0.0, 0.0, 0.0);
					ShowHudText(i, 4, " ");
					IsHudVisible[i] = false;
				}
			}
		}
	}
	else // Multiple rockets
	{
		// Sort rockets by speed (descending) using a simple bubble sort.
		for (int i = 0; i < rocketCount - 1; i++)
		{
			for (int j = 0; j < rocketCount - i - 1; j++)
			{
				if (rocketSpeeds[j] < rocketSpeeds[j + 1])
				{
					// Swap speeds
					float tempSpeed = rocketSpeeds[j];
					rocketSpeeds[j] = rocketSpeeds[j + 1];
					rocketSpeeds[j + 1] = tempSpeed;
					// Swap indices
					int tempIndex = rocketIndices[j];
					rocketIndices[j] = rocketIndices[j + 1];
					rocketIndices[j + 1] = tempIndex;
				}
			}
		}

		// Build the multi-line HUD message.
		char hudMessage[1024];
		int maxRocketsToShow = 5; // Limit to prevent screen clutter.
		int numToShow = rocketCount < maxRocketsToShow ? rocketCount : maxRocketsToShow;

		for (int i = 0; i < numToShow; i++)
		{
			int rocketIndex = rocketIndices[i];
			float mphSpeed = rocketSpeeds[i];
			float huSpeed = TFDB_GetRocketSpeed(rocketIndex);
			int deflections = TFDB_GetRocketDeflections(rocketIndex);
			int rocketClass = TFDB_GetRocketClass(rocketIndex);
			char className[64];
			TFDB_GetRocketClassLongName(rocketClass, className, sizeof(className));

			char line[256];
			// Pass the floats directly, the translation file will format them.
			Format(line, sizeof(line), "%t\n", "Hud_SpeedometerEx", mphSpeed, huSpeed, deflections, i + 1, className);
			
			if (i == 0)
				strcopy(hudMessage, sizeof(hudMessage), line);
			else
				Format(hudMessage, sizeof(hudMessage), "%s%s", hudMessage, line);
		}

		// Display the list on the left side for all players.
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (HudEnabledForClient[i])
				{
					SetHudTextParams(0.05, 0.4, 0.15, 100, 255, 100, 255, 0, 0.0, 0.0, 0.15);
					ShowHudText(i, 4, hudMessage);
					IsHudVisible[i] = true;
				}
				else if (IsHudVisible[i])
				{
					SetHudTextParams(0.0, 0.0, 0.1, 255, 255, 255, 0, 0, 0.0, 0.0, 0.0);
					ShowHudText(i, 4, " ");
					IsHudVisible[i] = false;
				}
			}
		}
	}
	return Plugin_Continue;
}
