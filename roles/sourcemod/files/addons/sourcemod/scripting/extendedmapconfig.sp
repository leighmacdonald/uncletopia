/**
 * Application:      extendedmapconfig.smx
 * Author:           Milo <milo@corks.nl>
 * Target platform:  Sourcemod 1.1.0 + Metamod 1.7.0 + Team Fortress 2 (20090212)
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma semicolon 1
#include <sourcemod>

#define VERSION                      "1.1.1"

#define PATH_PREFIX_ACTUAL           "cfg/"
#define PATH_PREFIX_VISIBLE          "mapconfig/"
#define PATH_PREFIX_VISIBLE_GENERAL  "mapconfig/general/"
#define PATH_PREFIX_VISIBLE_GAMETYPE "mapconfig/gametype/"
#define PATH_PREFIX_VISIBLE_MAP      "mapconfig/maps/"

#define TYPE_GENERAL                 0
#define TYPE_MAP                     1
#define TYPE_GAMETYPE                2

public Plugin:myinfo = {
	name        = "Extended mapconfig package",
	author      = "Milo",
	description = "Allows you to use seperate config files for each gametype and map.",
	version     = VERSION,
	url         = "http://sourcemod.corks.nl/"
};

public OnPluginStart() {
	CreateConVar("extendedmapconfig_version", VERSION, "Current version of the extended mapconfig plugin", FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	createConfigFiles();
}

public OnConfigsExecuted() {
	new String:configFilename[PLATFORM_MAX_PATH];
	new String:name[PLATFORM_MAX_PATH];
	// Execute general config
	name = "all";
	getConfigFilename(configFilename, sizeof(configFilename), name, TYPE_GENERAL);
	PrintToServer("Loading mapconfig: general configfile (%s.cfg).", name);
	ServerCommand("exec \"%s\"", configFilename);
	// Execute gametype config
	GetCurrentMap(name, sizeof(name));
	if (SplitString(name, "_", name, sizeof(name)) != -1) {
		getConfigFilename(configFilename, sizeof(configFilename), name, TYPE_GAMETYPE);
		PrintToServer("Loading mapconfig: gametype configfile (%s.cfg).", name);
		ServerCommand("exec \"%s\"", configFilename);
	}
	// Execute map's config
	GetCurrentMap(name, sizeof(name));
	getConfigFilename(configFilename, sizeof(configFilename), name, TYPE_MAP);
	PrintToServer("Loading mapconfig: mapspecific configfile (%s.cfg).", name);
	ServerCommand("exec \"%s\"", configFilename);
}

createConfigFiles() {
	new String:game[64];
	new String:name[PLATFORM_MAX_PATH];
	// Fetch the current game/mod
	GetGameFolderName(game, sizeof(game));
	// Create the directory structure (if it doesnt exist already)
	createConfigDir(PATH_PREFIX_VISIBLE,           PATH_PREFIX_ACTUAL);
	createConfigDir(PATH_PREFIX_VISIBLE,           PATH_PREFIX_ACTUAL);
	createConfigDir(PATH_PREFIX_VISIBLE_GENERAL,   PATH_PREFIX_ACTUAL);
	createConfigDir(PATH_PREFIX_VISIBLE_GAMETYPE,  PATH_PREFIX_ACTUAL);
	createConfigDir(PATH_PREFIX_VISIBLE_MAP,       PATH_PREFIX_ACTUAL);
	// Create general config
	createConfigFile("all",     TYPE_GENERAL,  "All maps");
	// For Team Fortress 2
	if (strcmp(game, "tf", false) == 0) {
		createConfigFile("cp",    TYPE_GAMETYPE, "Control-point maps");
		createConfigFile("ctf",   TYPE_GAMETYPE, "Capture-the-Flag maps");
		createConfigFile("pl",    TYPE_GAMETYPE, "Payload maps");
		createConfigFile("arena", TYPE_GAMETYPE, "Arena-style maps");
		createConfigFile("plr",	  TYPE_GAMETYPE, "Payload Race maps");
		createConfigFile("tc",    TYPE_GAMETYPE, "Territory Control maps");
		createConfigFile("koth",  TYPE_GAMETYPE, "King of the Hill maps");
	// For Counter-strike and Counter-strike:Source
	} else if (strcmp(game, "cstrike", false) == 0) {
		createConfigFile("cs",    TYPE_GAMETYPE, "Hostage maps");
		createConfigFile("de",    TYPE_GAMETYPE, "Defuse maps");
		createConfigFile("as",    TYPE_GAMETYPE, "Assasination maps");
		createConfigFile("es",    TYPE_GAMETYPE, "Escape maps");
	}
	new Handle:adtMaps = CreateArray(16, 0);
	new serial = -1;
	// Fetch dynamic array of all existing maps on the server
	ReadMapList(adtMaps, serial, "allexistingmaps__", MAPLIST_FLAG_MAPSFOLDER|MAPLIST_FLAG_NO_DEFAULT);
	new mapcount = GetArraySize(adtMaps);
	// Create a cfgfile for each one
	if (mapcount > 0) for (new i = 0; i < mapcount; i++) {
		GetArrayString(adtMaps, i, name, sizeof(name));
		createConfigFile(name, TYPE_MAP, name);
	}
}

// Determine the full path to a config file.
getConfigFilename(String:buffer[], const maxlen, const String:filename[], const type=TYPE_MAP, const bool:actualPath=false) {
	Format(
		buffer, maxlen, "%s%s%s.cfg", (actualPath ? PATH_PREFIX_ACTUAL : ""), (
		type == TYPE_GENERAL ? PATH_PREFIX_VISIBLE_GENERAL : (type == TYPE_GAMETYPE ? PATH_PREFIX_VISIBLE_GAMETYPE : PATH_PREFIX_VISIBLE_MAP)
		), filename
	);
}

createConfigDir(const String:filename[], const String:prefix[]="") {
	new String:dirname[PLATFORM_MAX_PATH];
	Format(dirname, sizeof(dirname), "%s%s", prefix, filename);
	CreateDirectory(
		dirname,  
		FPERM_U_READ + FPERM_U_WRITE + FPERM_U_EXEC + 
		FPERM_G_READ + FPERM_G_WRITE + FPERM_G_EXEC + 
		FPERM_O_READ + FPERM_O_WRITE + FPERM_O_EXEC
	);
}

createConfigFile(const String:filename[], type=TYPE_MAP, const String:label[]="") {
	new String:configFilename[PLATFORM_MAX_PATH];
	new String:configLabel[128];
	new Handle:fileHandle = INVALID_HANDLE;
	getConfigFilename(configFilename, sizeof(configFilename), filename, type, true);
	// Check if config exists
	if (FileExists(configFilename)) return;
	// If it doesnt, create it
	fileHandle = OpenFile(configFilename, "w+");
	// Determine content
	if (strlen(label) > 0) strcopy(configLabel, sizeof(configLabel), label);
	else                   strcopy(configLabel, sizeof(configLabel), configFilename);
	if (fileHandle != INVALID_HANDLE) {
		WriteFileLine(fileHandle, "// Configfile for: %s", configLabel);
		CloseHandle(fileHandle);
	}
}