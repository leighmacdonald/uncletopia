/**
 * -----------------------------------------------------
 * File        cronjobs.sp
 * Authors     David Ordnung
 * License     GPLv3
 * Web         http://dordnung.de
 * -----------------------------------------------------
 * 
 * Copyright (C) 2018 David Ordnung
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>
 */

#include <sourcemod>
#include <autoexecconfig>

#undef REQUIRE_EXTENSIONS
#include <system2>

#undef REQUIRE_PLUGIN
#include <updater>

#pragma semicolon 1
#pragma newdecls required

#define UPDATE_URL_PLUGIN "https://dordnung.de/sourcemod/cronjobs/update.txt"

// All keys of the times map of a cronjob
#define CRON_SEC "seconds"
#define CRON_MIN "minutes"
#define CRON_HOUR "hours"
#define CRON_DAY "days"
#define CRON_MONTH "months"
#define CRON_WEEK "weeks"

// All keys of a cronjob map
#define CRON_SPECIAL "special"
#define CRON_TYPE "type"
#define CRON_COMMAND "command"
#define CRON_TIMES "times"

// Available cronjob types
#define CRON_CONSOLE "console"
#define CRON_SYSTEM "system"
#define CRON_PLAYER "player"

// Available cronjob special times
#define CRON_PLUGIN_START "plugin_start"
#define CRON_PLUGIN_END "plugin_end"
#define CRON_MAP_START "map_start"
#define CRON_MAP_END "map_end"

// Enum for the times in the cronjob table
enum CronTime
{
	CRON_TIME_SECOND,
	CRON_TIME_MINUTE,
	CRON_TIME_HOUR,
	CRON_TIME_DAY,
	CRON_TIME_MONTH,
	CRON_TIME_WEEK
};


// The debug convar
ConVar g_hDebugEnabled;
bool g_bDebugEnabled;

// The list of loaded cronjobs
ArrayList g_hCronjobs;
StringMap g_hHookedEvents;

// Bool for first load check
bool g_bIsFirstLoad;


public Plugin myinfo =
{
	name = "Cronjobs",
	author = "dordnung",
	version = "2.0",
	description = "A cronjobs plugin for Sourcemod",
	url = "https://forums.alliedmods.net/showthread.php?t=205962"
};


public void OnPluginStart()
{
	// This is the first load
	g_bIsFirstLoad = true;

	// Register the cronjobs_reload command
	RegServerCmd("cronjobs_reload", ReloadCronjobs, "Reloads all cronjobs from the cronjob configuration file");

	// Create the config
	AutoExecConfig_SetFile("plugin.cronjobs");

	AutoExecConfig_CreateConVar("crontab_version", "2.0", "Cronjobs plugin by dordnung", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	AutoExecConfig_CreateConVar("cronjobs_version", "2.0", "Cronjobs plugin by dordnung", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_hDebugEnabled = AutoExecConfig_CreateConVar("cronjobs_debug", "0", "Logging cronjobs executions and outputs", FCVAR_NONE, true, 0.0, true, 1.0);
	
	AutoExecConfig(true, "plugin.cronjobs");
	AutoExecConfig_CleanFile();
	
	// Create the structure to store cronjobs and hooked events
	g_hCronjobs = new ArrayList();
	g_hHookedEvents = new StringMap();

	// Start the timer which executes the cronjobs
	CreateTimer(1.0, ExecuteCronjobs, _, TIMER_REPEAT);
}

public void OnConfigsExecuted()
{
	g_bDebugEnabled = g_hDebugEnabled.BoolValue;

	// Do a few things on first load
	if (g_bIsFirstLoad)
	{
		g_bIsFirstLoad = false;

		// Enable updating
		if (LibraryExists("updater"))
		{
			Updater_AddPlugin(UPDATE_URL_PLUGIN);
		}

		// Load the cronjobs
		LoadCronjobs();

		// Start the first special cronjob
		ExecuteSpecialCronjobs(CRON_PLUGIN_START);
	}
}

public Action ReloadCronjobs(int args)
{
	// Just reload the cronjobs from the configuration file
	LoadCronjobs();

	return Plugin_Handled;
}



void LoadCronjobs()
{
	// First delete all old cronjobs
	if (g_hCronjobs.Length > 0)
	{
		if (g_bDebugEnabled)
		{
			LogMessage("Deleting %d already loaded cronjobs", g_hCronjobs.Length);
		}

		for (int i=0; i < g_hCronjobs.Length; i++)
		{
			DeleteCronjob(view_as<StringMap>(g_hCronjobs.Get(i)));
		}

		g_hCronjobs.Clear();
	}

	if (g_bDebugEnabled)
	{
		LogMessage("Loading cronjobs from file");
	}

	// Open the cronjobs file
	File file = OpenFile("cfg/cronjobs.txt", "rb");
	if (file == null)
	{
		LogError("Couldn't find the cronjob configuration file at 'cfg/cronjobs.txt'!");
		return;
	}

	// Read line by line
	char fileLine[2048];
	char fileLineOriginal[2048];

	while (file.ReadLine(fileLine, sizeof(fileLine)))
	{
		// Keep copy for log messages
		strcopy(fileLineOriginal, sizeof(fileLineOriginal), fileLine);

		if (g_bDebugEnabled)
		{
			LogMessage("Analyzing cronjob line '%s'", fileLineOriginal);
		}
		
		// Check if line is invalid
		TrimString(fileLine);
		if (!strlen(fileLine) || StrEqual(fileLine, "\0") || fileLine[0] == '#' || (fileLine[0] == '/' && fileLine[1] == '/'))
		{
			if (g_bDebugEnabled)
			{
				LogMessage("Skipping empty line or line with comment");
			}

			continue;
		}

		// Get all parts of the line - manually to allow as much whitespace as wanted
		char parts[7][1024];
		int currentPart = 0;
		int currentPos = 0;
		bool lastCharWhitespace = false;

		for (int i=0; i < strlen(fileLine) && currentPart < sizeof(parts) && currentPos < sizeof(parts[]); i++)
		{
			if (IsCharSpace(fileLine[i]))
			{
				if (!lastCharWhitespace)
				{
					parts[currentPart][currentPos] = '\0';
					
					// Stop if we found a valid type
					if (IsValidType(parts[currentPart]))
					{
						break;
					}

					// Go to the next part
					currentPart++;
					currentPos = 0;
				}

				lastCharWhitespace = true;
			}
			else
			{
				// Just append char to current part
				lastCharWhitespace = false;
				parts[currentPart][currentPos++] = fileLine[i];
			}
		}

		// Check if it is a valid cronjob line
		int numParts = currentPart;
		if (numParts != 1 && numParts != 5 && numParts != 6)
		{
			LogError("Couldn't add cronjob '%s': wrong number of parts detected (%d)", fileLineOriginal, numParts);
			continue;
		}

		if (g_bDebugEnabled)
		{
			LogMessage("Found %d parts in cronjob line", numParts);
		}

		// The type is the current part
		char type[64];
		strcopy(type, sizeof(type), parts[currentPart]);

		// Calculate where the type argument starts
		int typeStart = StrContains(fileLine, type);
		if (typeStart == -1)
		{
			LogError("Couldn't add cronjob '%s': Couldn't find type in the line (%d parts detected)", fileLineOriginal, numParts);
			continue;
		}

		// Get the command out of the file line (command follows the type)
		char command[1024];
		strcopy(command, sizeof(command), fileLine[typeStart + strlen(type)]);
		TrimString(command);

		// Finally parse the cronjob
		StringMap cronjob = new StringMap();
		if (numParts == 1)
		{
			// Parse a line with special time
			if (!ParseSpecial(cronjob, parts[0]) || !ParseType(cronjob, type) || !ParseCommand(cronjob, command))
			{
				LogError("Error on parsing cronjob line '%s'", fileLineOriginal);
				DeleteCronjob(cronjob);

				continue;
			}
		}
		else
		{
			// Set all seconds to false (expect zero) if no seconds part is given
			if (numParts == 5)
			{
				for (int i=1; i < 60; i++)
				{
					SetTimeValueOfCronjob(cronjob, CRON_SEC, i, false);
				}

				SetTimeValueOfCronjob(cronjob, CRON_SEC, 0, true);
			}

			// Now parse all time arguments
			bool foundError = false;
			for (int i=0; i < numParts; i++)
			{
				// Skip seconds if only five parts are given
				CronTime cronTime = view_as<CronTime>(i);
				if (numParts == 5)
				{
					cronTime = view_as<CronTime>(i + 1);
				}

				// Pare the time
				if (!ParseTime(cronjob, parts[i], cronTime))
				{
					foundError = true;
					break;
				}
				
				// 7 and 0 is the same day but for sourcemod sunday is 0
				if (cronTime == CRON_TIME_WEEK && GetTimeValueOfCronjob(cronjob, CRON_WEEK, 7))
				{
					SetTimeValueOfCronjob(cronjob, CRON_WEEK, 0, true);
				}
			}
			
			// After time there is the type and the command
			if (foundError || !ParseType(cronjob, type) || !ParseCommand(cronjob, command))
			{
				LogError("Error on parsing cronjob line '%s'", fileLineOriginal);
				DeleteCronjob(cronjob);

				continue;
			}
		}

		// On success add the cronjob to the list of cronjobs
		g_hCronjobs.Push(cronjob);

		if (g_bDebugEnabled)
		{
			LogMessage("Cronjob successfully added");
		}
	}

	file.Close();
}



bool ParseSpecial(StringMap cronjob, const char[] special)
{
	if (strlen(special) < 2 || special[0] != '@')
	{
		LogError("Special part must begin with an '@'");
		return false;
	}

	// Check if the given special is a pre defined one
	if (!IsPreDefinedSpecial(special[1]))
	{
		bool hooked = false;
		if (!g_hHookedEvents.GetValue(special[1], hooked) || !hooked)
		{
			if (g_bDebugEnabled)
			{
				LogMessage("Hook event '%s'", special[1]);
			}

			HookEvent(special[1], ExecuteEventCronjobs);
			g_hHookedEvents.SetValue(special[1], true);
		}

	}

	// Set the special of the cronjob
	SetSpecialOfCronjob(cronjob, special[1]);

	if (g_bDebugEnabled)
	{
		LogMessage("Found cronjob special '%s'", special[1]);
	}

	return true;
}

bool IsPreDefinedSpecial(const char[] special)
{
	// Check if the given special is one of the pre defined specials
	return StrEqual(special, CRON_PLUGIN_START) || StrEqual(special, CRON_PLUGIN_END) || StrEqual(special, CRON_MAP_START) || StrEqual(special, CRON_MAP_END);
}

bool ParseType(StringMap cronjob, const char[] type)
{
	// Check if the given type is valid
	if (!IsValidType(type))
	{
		LogError("Cronjob type '%s' is invalid!", type);
		return false;
	}

	// Set the type of the cronjob
	SetTypeOfCronjob(cronjob, type);

	if (g_bDebugEnabled)
	{
		LogMessage("Found cronjob type '%s'", type);
	}

	return true;
}

bool IsValidType(const char[] type)
{
	// Check if the given type is valid
	return StrEqual(type, CRON_PLAYER) || StrEqual(type, CRON_SYSTEM) || StrEqual(type, CRON_CONSOLE);
}

bool ParseCommand(StringMap cronjob, const char[] command)
{
	// We can't check if command is valid
	SetCommandOfCronjob(cronjob, command);

	if (g_bDebugEnabled)
	{
		LogMessage("Found cronjob command '%s'", command);
	}

	return true;
}

bool ParseTime(StringMap cronjob, const char[] part, CronTime cronTime)
{
	int min;
	int max;
	char cronTimeStr[32];
	
	// Get allowed min and max values
	switch (cronTime)
	{
		case CRON_TIME_SECOND:
		{
			min = 0;
			max = 59;

			strcopy(cronTimeStr, sizeof(cronTimeStr), CRON_SEC);
		}
		case CRON_TIME_MINUTE:
		{
			min = 0;
			max = 59;

			strcopy(cronTimeStr, sizeof(cronTimeStr), CRON_MIN);
		}
		case CRON_TIME_HOUR:
		{
			min = 0;
			max = 23;

			strcopy(cronTimeStr, sizeof(cronTimeStr), CRON_HOUR);
		}
		case CRON_TIME_DAY:
		{
			min = 1;
			max = 31;
			
			// Set special max value to check for asterix
			SetTimeValueOfCronjob(cronjob, CRON_DAY, max + 1, false);

			strcopy(cronTimeStr, sizeof(cronTimeStr), CRON_DAY);
		}
		case CRON_TIME_MONTH:
		{
			min = 1;
			max = 12;

			strcopy(cronTimeStr, sizeof(cronTimeStr), CRON_MONTH);
		}
		default:
		{
			min = 0;
			max = 7;
			
			// Set special max value to check for asterix
			SetTimeValueOfCronjob(cronjob, CRON_WEEK, max + 1, false);

			strcopy(cronTimeStr, sizeof(cronTimeStr), CRON_WEEK);
		}
	}

	if (g_bDebugEnabled)
	{
		LogMessage("Processing time part '%s' (min: %d, max: %d)", cronTimeStr, min, max);
	}

	char exploded[128][16];
	int found = ExplodeString(part, ",", exploded, sizeof(exploded), sizeof(exploded[]));

	for (int i=0; i < found; i++)
	{
		TrimString(exploded[i]);

		if (!strlen(exploded[i]) || StrEqual(exploded[i], "\0"))
		{
			LogError("Found an empty string on '%s'", part);
			return false;
		}

		if (StrContains(exploded[i], "*/") > -1)
		{
			ReplaceString(exploded[i], sizeof(exploded[]), "*/", "");
			
			int number = StringToInt(exploded[i]);
			if (number)
			{
				// Set all times in step range
				for (int j=min; j <= max; j++)
				{
					if (!(j % number))
					{
						SetTimeValueOfCronjob(cronjob, cronTimeStr, j, true);
					}
				}

				if (g_bDebugEnabled)
				{
					LogMessage("Found '*/%d'", number);
				}
			}
			else
			{
				LogError("After '*/' a number greater 0 must follow: '%s' (on '%s')", exploded[i], part);
				return false;
			}
		}
		else if (StrContains(exploded[i], "-") > -1)
		{
			char buffer[3][8];
			
			int parts = ExplodeString(exploded[i], "-", buffer, sizeof(buffer), sizeof(buffer[]));
			if (parts <= 1)
			{
				LogError("Two numbers must used when using '-': '%s' (on '%s')", exploded[i], part);
				return false;
			}

			int number1 = StringToInt(buffer[0]);
			int number2 = StringToInt(buffer[1]);

			if (number1 <= 0)
			{
				// Zero is allowed!
				if (StrEqual(buffer[0], "0") || StrEqual(buffer[0], "00"))
				{
					number1 = 0;
				}
				else
				{
					LogError("Two valid numbers must used when using '-': '%s' (on '%s')", exploded[i], part);
					return false;
				}
			}
			
			if (number1 >= min && number2 >= number1 && number2 <= max)
			{
				if (g_bDebugEnabled)
				{
					LogMessage("Found '%d-%d'", number1, number2);
				}

				// Set all times in range to true
				for (int j=number1; j <= number2; j++)
				{
					SetTimeValueOfCronjob(cronjob, cronTimeStr, j, true);
				}
			}
			else
			{
				LogError("First number must be less then second number when using '-': '%s' (on '%s')", exploded[i], part);
				return false;
			}
		}
		else if (StrEqual(exploded[i], "*"))
		{
			if (g_bDebugEnabled)
			{
				LogMessage("Found '*'");
			}

			// Set all values from min to max
			for (int j=min; j <= max; j++)
			{
				SetTimeValueOfCronjob(cronjob, cronTimeStr, j, true);
			}
			
			// Set special max value to check for asterix
			if (cronTime == CRON_TIME_WEEK || cronTime == CRON_TIME_DAY)
			{
				SetTimeValueOfCronjob(cronjob, cronTimeStr, max + 1, true);
			}
		}
		else
		{
			int number = StringToInt(exploded[i]);
			if (number <= 0)
			{
				// Zero is allowed!
				if (StrEqual(exploded[i], "0") || StrEqual(exploded[i], "00"))
				{
					number = 0;
				}
				else
				{
					LogError("Valid numbers must used: '%s' (on '%s')", exploded[i], part);
					return false;
				}
			}
			
			// Check number is in correct range
			if (number >= min && number <= max)
			{
				if (g_bDebugEnabled)
				{
					LogMessage("Found number '%d'", number);
				}

				// Set the single number
				SetTimeValueOfCronjob(cronjob, cronTimeStr, number, true);
			}
			else
			{
				LogError("Number must be in range: '%s' (on '%s')", exploded[i], part);
				return false;
			}
		}
	}

	return true;
}



public Action ExecuteCronjobs(Handle timer)
{
	char buffer[10];
	
	FormatTime(buffer, sizeof(buffer), "%S");
	int second = StringToInt(buffer);
	
	FormatTime(buffer, sizeof(buffer), "%M");
	int minute = StringToInt(buffer);
	
	FormatTime(buffer, sizeof(buffer), "%H");
	int hour = StringToInt(buffer);
	
	FormatTime(buffer, sizeof(buffer), "%d");
	int day = StringToInt(buffer);
	
	FormatTime(buffer, sizeof(buffer), "%m");
	int month = StringToInt(buffer);
	
	FormatTime(buffer, sizeof(buffer), "%w");
	int week = StringToInt(buffer);

	for (int i=0; i < g_hCronjobs.Length; i++)
	{
		StringMap cronjob = g_hCronjobs.Get(i);
		
		// Check if week asterix is used
		if (GetTimeValueOfCronjob(cronjob, CRON_WEEK, 8))
		{
			// When week asterix is used the following times must be correct: second, minute, hour, day and month
			if (GetTimeValueOfCronjob(cronjob, CRON_SEC, second) && GetTimeValueOfCronjob(cronjob, CRON_MIN, minute) && GetTimeValueOfCronjob(cronjob, CRON_HOUR, hour) 
				&& GetTimeValueOfCronjob(cronjob, CRON_DAY, day) && GetTimeValueOfCronjob(cronjob, CRON_MONTH, month))
			{
				if (g_bDebugEnabled)
				{
					LogMessage("Execute time based cronjob - week asterix");
				}

				ExecuteCronjob(cronjob);
			}
		}
		else
		{
			// Check if day asterix is used
			if (GetTimeValueOfCronjob(cronjob, CRON_DAY, 32))
			{
				// When day asterix is used the following times must be correct: second, minute, hour, month and week
				if (GetTimeValueOfCronjob(cronjob, CRON_SEC, second) && GetTimeValueOfCronjob(cronjob, CRON_MIN, minute) && GetTimeValueOfCronjob(cronjob, CRON_HOUR, hour)
					&& GetTimeValueOfCronjob(cronjob, CRON_MONTH, month) && GetTimeValueOfCronjob(cronjob, CRON_WEEK, week))
				{
					if (g_bDebugEnabled)
					{
						LogMessage("Execute time based cronjob - day asterix");
					}

					ExecuteCronjob(cronjob);
				}
			}
			else
			{
				// When whether daynor week asterix is used the following times must be correct: second, minute, hour, and day or month or month and week
				if (GetTimeValueOfCronjob(cronjob, CRON_SEC, second) && GetTimeValueOfCronjob(cronjob, CRON_MIN, minute) && GetTimeValueOfCronjob(cronjob, CRON_HOUR, hour) 
					&& ((GetTimeValueOfCronjob(cronjob, CRON_DAY, day) && GetTimeValueOfCronjob(cronjob, CRON_MONTH, month)) 
						|| (GetTimeValueOfCronjob(cronjob, CRON_MONTH, month) && GetTimeValueOfCronjob(cronjob, CRON_WEEK, week))))
				{
					if (g_bDebugEnabled)
					{
						LogMessage("Execute time based cronjob - no day/week asterix");
					}

					ExecuteCronjob(cronjob);
				}
			}
		}
	}

	return Plugin_Continue;
}



public Action ExecuteEventCronjobs(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bDebugEnabled)
	{
		LogMessage("Cronjob event %s fired", name);
	}

	ExecuteSpecialCronjobs(name);

	return Plugin_Continue;
}

public void OnPluginEnd()
{
	ExecuteSpecialCronjobs(CRON_PLUGIN_END);
}

public void OnMapStart()
{
	ExecuteSpecialCronjobs(CRON_MAP_START);
}

public void OnMapEnd()
{
	ExecuteSpecialCronjobs(CRON_MAP_END);
}

void ExecuteSpecialCronjobs(const char[] special)
{
	char cronjobSpecial[64];
	for (int i=0; i < g_hCronjobs.Length; i++)
	{
		StringMap cronjob = g_hCronjobs.Get(i);
		if (GetSpecialOfCronjob(cronjob, cronjobSpecial, sizeof(cronjobSpecial)) && StrEqual(cronjobSpecial, special)) {
			if (g_bDebugEnabled)
			{
				LogMessage("Execute special cronjob '%s'", special);
			}

			ExecuteCronjob(cronjob);
		}
	}
}

void ExecuteCronjob(StringMap cronjob)
{
	char cronType[32];
	GetTypeOfCronjob(cronjob, cronType, sizeof(cronType));

	char cronCommand[1024];
	GetCommandOfCronjob(cronjob, cronCommand, sizeof(cronCommand));

	if (StrEqual(cronType, CRON_CONSOLE))
	{
		if (g_bDebugEnabled)
		{
			char output[1024];
			ServerCommandEx(output, sizeof(output), cronCommand);
			
			LogMessage("Executed cronjob console command '%s'", cronCommand);
			LogMessage("Cronjob output is: %s", output);
		}
		else
		{
			ServerCommand(cronCommand);
		}
	}
	else if (StrEqual(cronType, CRON_PLAYER))
	{
		for (int client=1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client))
			{
				FakeClientCommandEx(client, cronCommand);
			}
		}
		
		if (g_bDebugEnabled)
		{
			LogMessage("Executed cronjob player command '%s'", cronCommand);
		}
	}
	else if (StrEqual(cronType, CRON_SYSTEM))
	{
		if (LibraryExists("system2"))
		{
			System2_ExecuteThreaded(OnCommandExecuted, cronCommand);
		}
		else
		{
			LogError("Couldn't run system command! Couldn't find system2 extension! Please install it from here: https://forums.alliedmods.net/showthread.php?t=146019");
		}
	}
}



public void OnCommandExecuted(bool success, const char[] command, System2ExecuteOutput output)
{
	char out[1024];
	output.GetOutput(out, sizeof(out));

	// Check if command execution was successfull
	if (!success)
	{
		LogError("Error on executing command '%s' (%d): %s", command, output.ExitStatus, out);
	}
	else if (g_bDebugEnabled)
	{
		LogMessage("Executed cronjob system command '%s' (%d): %s", command, output.ExitStatus, out);
	}
}



bool GetSpecialOfCronjob(StringMap cronjob, char[] special, int sizeofSpecial)
{
	return cronjob.GetString(CRON_SPECIAL, special, sizeofSpecial);
}

void GetTypeOfCronjob(StringMap cronjob, char[] type, int sizeofType)
{
	cronjob.GetString(CRON_TYPE, type, sizeofType);
}

void GetCommandOfCronjob(StringMap cronjob, char[] command, int sizeofCommand)
{
	cronjob.GetString(CRON_COMMAND, command, sizeofCommand);
}

bool GetTimeValueOfCronjob(StringMap cronjob, const char[] timeType, int timeIndex)
{
	StringMap times;
	if (!cronjob.GetValue(CRON_TIMES, times))
	{
		return false;
	}

	ArrayList time;
	if (!times.GetValue(timeType, time))
	{
		return false;
	}

	return time.Get(timeIndex);
}

void SetSpecialOfCronjob(StringMap cronjob, const char[] special)
{
	cronjob.SetString(CRON_SPECIAL, special, true);
}

void SetTypeOfCronjob(StringMap cronjob, const char[] type)
{
	cronjob.SetString(CRON_TYPE, type, true);
}

void SetCommandOfCronjob(StringMap cronjob, const char[] command)
{
	cronjob.SetString(CRON_COMMAND, command, true);
}

void SetTimeValueOfCronjob(StringMap cronjob, const char[] timeType, int timeIndex, bool value)
{
	StringMap times;
	if (!cronjob.GetValue(CRON_TIMES, times))
	{
		// Create times map if not found
		times = new StringMap();
		cronjob.SetValue(CRON_TIMES, times, true);
	}

	ArrayList time;
	if (!times.GetValue(timeType, time))
	{
		// Create time array if not found (use 60 values as this is max))
		time = new ArrayList();
		for (int i=0; i < 60; i++)
		{
			time.Push(false);
		}

		times.SetValue(timeType, time);
	}

	time.Set(timeIndex, value);
}

void DeleteCronjob(StringMap cronjob)
{
	if (cronjob != null)
	{
		// Delete all times in the cronjob
		StringMap times;
		if (cronjob.GetValue(CRON_TIMES, times))
		{
			DeleteCronjobTime(times, CRON_SEC);
			DeleteCronjobTime(times, CRON_MIN);
			DeleteCronjobTime(times, CRON_HOUR);
			DeleteCronjobTime(times, CRON_DAY);
			DeleteCronjobTime(times, CRON_WEEK);
			DeleteCronjobTime(times, CRON_MONTH);

			delete times;
		}

		delete cronjob;
	}
}

void DeleteCronjobTime(StringMap times, const char[] timeType)
{
	ArrayList time;
	if (times.GetValue(timeType, time))
	{
		delete time;
	}
}