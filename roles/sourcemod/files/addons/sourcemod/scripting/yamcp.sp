/**
 * YAMCP - "Yet Another Map Config Plugin"
 * 
 * Just another plugin that does map configs.  This one supports your standard map
 * configurations and your map prefixes, but it also detects certain sub-modes (it currently
 * only differentiates between A/D CP and Standard CP in TF2), and Workshop maps (tracked by
 * ID; standard map configurations are also checked with the display name).
 * 
 * Uses a similar configuration hierarchy as the one available in Extended Map Configs:
 * https://forums.alliedmods.net/showthread.php?p=760501
 * 
 * Main difference is that there is no "general" subdirectory; The "all" config file is in the
 * root of the "mapconfig" subdirectory.
 */

#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required
#include <sourcemod>

#include <tf2>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_VERSION "1.0.4"
public Plugin myinfo = {
	name = "Yet Another Map Config Plugin",
	author = "nosoop",
	description = "Just another way to do map configs",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-YetAnotherMapConfigPlugin/"
}

#define MAP_NAME_LENGTH 96

#define SERVER_OUTPUT_PREFIX "[yamcp] "
#define GAME_CONFIG_PATH "cfg"

char ConfigPaths[][] = {
	"mapconfig",
	"gametype",
	"maps",
	"workshop"
};

enum ConfigPathType {
	ConfigPath_Root = 0,
	ConfigPath_GameType,
	ConfigPath_Maps,
	ConfigPath_Workshop
};

public void OnPluginStart() {
	SetupMapConfigDirectories();
	
	CreateConVar("yamcp_version", PLUGIN_VERSION, "Current version of YAMCP",
			FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	RegAdminCmd("sm_mapconfig_load", AdminCmd_LoadConfigs, ADMFLAG_CONFIG,
			"Reloads the map configs.");
}

public Action AdminCmd_LoadConfigs(int client, int argc) {
	OnAutoConfigsBuffered();
	LogAction(client, -1, "\"%L\" reloaded the map config files", client);
	
	return Plugin_Handled;
}

public void OnAutoConfigsBuffered() {
	char map[MAP_NAME_LENGTH];
	GetCurrentMap(map, sizeof(map));
	FindMap(map, map, sizeof(map));
	
	// Uses full map name
	int workshop = GetWorkshopID(map);
	
	GetMapDisplayName(map, map, sizeof(map));
	
	ExecuteGlobalConfig();
	ExecuteGameTypeConfig(map);
	ExecuteMapPrefixConfigs(map);
	
	if (workshop) {
		ExecuteWorkshopConfig(workshop);
	}
}

/**
 * Creates the base configuration directories and adds the "stock" configuration files.
 */
void SetupMapConfigDirectories() {
	int max = view_as<int>(ConfigPath_Workshop);

	for (int i = 0; i < max; i++) {
		GenerateConfigDirectory(view_as<ConfigPathType>(i));
	}
	
	GenerateConfig(ConfigPath_Root, "all", "All maps");
	
	switch (GetEngineVersion()) {
		case Engine_TF2: {
			GenerateConfig(ConfigPath_GameType, "cp", "Control Point maps (All)");
			GenerateConfig(ConfigPath_GameType, "cp_push", "Control Point maps (Push)");
			GenerateConfig(ConfigPath_GameType, "cp_ad",
					"Control Point maps (Attack / Defend)");
			GenerateConfig(ConfigPath_GameType, "ctf", "Capture the Flag maps");
			GenerateConfig(ConfigPath_GameType, "pl", "Payload maps");
			GenerateConfig(ConfigPath_GameType, "arena", "Arena maps");
		}
		case Engine_CSS, Engine_CSGO: {
			GenerateConfig(ConfigPath_GameType, "cs", "Hostage maps");
			GenerateConfig(ConfigPath_GameType, "de", "Defuse maps");
			GenerateConfig(ConfigPath_GameType, "as", "Assasination maps");
			GenerateConfig(ConfigPath_GameType, "es", "Escape maps");
		}
	}
}

/**
 * Creates a configuration directory.
 */
void GenerateConfigDirectory(ConfigPathType type) {
	char configDirectory[PLATFORM_MAX_PATH];
	BuildConfigPath(type, configDirectory, sizeof(configDirectory));
	Format(configDirectory, sizeof(configDirectory), "%s/%s", GAME_CONFIG_PATH,
			configDirectory);

	if (!DirExists(configDirectory, true)) {
		PrintToServer(SERVER_OUTPUT_PREFIX ... "Created directory file %s", configDirectory);
		CreateDirectory(configDirectory,  
				FPERM_U_READ + FPERM_U_WRITE + FPERM_U_EXEC + 
				FPERM_G_READ + FPERM_G_WRITE + FPERM_G_EXEC + 
				FPERM_O_READ + FPERM_O_WRITE + FPERM_O_EXEC
		);
	}
}

/**
 * Creates a "template" configuration file with a description.
 */
void GenerateConfig(ConfigPathType type, const char[] sConfigName, const char[] sDescription) {
	char configPath[PLATFORM_MAX_PATH];
	
	BuildConfigPath(type, configPath, sizeof(configPath), "%s.cfg", sConfigName);
	Format(configPath, sizeof(configPath), "%s/%s", GAME_CONFIG_PATH, configPath);
	
	if (FileExists(configPath)) {
		return;
	}
	
	File file = OpenFile(configPath, "w+");
	if (file != null) {
		PrintToServer(SERVER_OUTPUT_PREFIX ... "Created config file %s", configPath);
		file.WriteLine("// Configuration for %s", sDescription);
		file.Close();
	}
}

/**
 * Creates the path to a config file.
 */
void BuildConfigPath(ConfigPathType type, char[] buffer, int maxlen, const char[] fmt="",
		any ...) {
	char configPath[PLATFORM_MAX_PATH];
	VFormat(configPath, sizeof(configPath), fmt, 5);
	
	strcopy(buffer, maxlen, ConfigPaths[ConfigPath_Root]);
	
	// Append mapconfig subdirectories as needed.
	if (type != ConfigPath_Root) {
		StrCat(buffer, maxlen, "/");
		StrCat(buffer, maxlen, ConfigPaths[type]);
	}
	
	Format(buffer, maxlen, "%s/%s", buffer, configPath);
}

/**
 * Execute the "root" configuration file.
 */
void ExecuteGlobalConfig() {
	ExecuteConfig(ConfigPath_Root, "all.cfg");
}

/**
 * Executes a gametype config matching the map name prefix.
 * If it's TF2's Control Point mode, then we also check the currently running type of map.
 */
void ExecuteGameTypeConfig(const char[] map) {
	char mapPrefix[16];
	if (SplitString(map, "_", mapPrefix, sizeof(mapPrefix)) != -1) {
		ExecuteConfig(ConfigPath_GameType, "%s.cfg", mapPrefix);
		
		if (GetEngineVersion() == Engine_TF2 && StrEqual(mapPrefix, "cp")) {
			ExecuteExtendedCPConfig();
		}
	}
}

/**
 * Special case to differentiate between different types of Control Point maps in TF2.
 * Source: https://forums.alliedmods.net/showthread.php?p=913024
 */
void ExecuteExtendedCPConfig() {
	int iControlPoint = -1;
	while ((iControlPoint = FindEntityByClassname(iControlPoint, "team_control_point")) != -1) {
		if (view_as<TFTeam>(GetEntProp(iControlPoint, Prop_Send, "m_iTeamNum")) != TFTeam_Red) {
			// On attack / defend maps, RED owns all the control points at the start.
			// If there is any BLU CP or a neutral CP, then it's not an attack / defend map.
			ExecuteConfig(ConfigPath_GameType, "cp_push.cfg");
			return;
		}
	}
	ExecuteConfig(ConfigPath_GameType, "cp_ad.cfg");
}

/**
 * Executes configurations for a map file.  Partial map names are supported, using underscores
 * as delimiters (e.g.: "pl_" executes before "pl_pier_" before "pl_pier_b11_" before
 * "pl_pier_b11_fix", but "ctf_turbine" will not be executed before "ctf_turbine2").
 * 
 * This includes the full map name.
 */
void ExecuteMapPrefixConfigs(const char[] map) {
	char partialMapBuffer[PLATFORM_MAX_PATH];
	
	int currentSplit = 0;
	while (currentSplit < strlen(map)) {
		int subSplit = FindCharInString(map[currentSplit], '_', false);
		
		if (subSplit == -1) {
			// subsplit the remaining portion of the string
			subSplit = strlen(map[currentSplit]);
		}
		
		currentSplit += subSplit + 1; // subsplit + underscore
		strcopy(partialMapBuffer, currentSplit + 1, map); // currentsplit + null
		
		ExecuteConfig(ConfigPath_Maps, "%s.cfg", partialMapBuffer);
	}
}

/**
 * Executes the config of a Workshop map by ID.
 */
void ExecuteWorkshopConfig(int workshopid) {
	ExecuteConfig(ConfigPath_Workshop, "%d.cfg", workshopid);
}

/**
 * Executes a configuration file of the specified type, formatted as necessary.
 */
void ExecuteConfig(ConfigPathType type, const char[] sConfigFormat, any ...) {
	char fullConfigPath[PLATFORM_MAX_PATH], configExecPath[PLATFORM_MAX_PATH];
	
	VFormat(configExecPath, sizeof(configExecPath), sConfigFormat, 3);
	BuildConfigPath(type, configExecPath, sizeof(configExecPath), configExecPath);
	
	Format(fullConfigPath, sizeof(fullConfigPath), "cfg/%s", configExecPath);
	
	if (FileExists(fullConfigPath, true)) {
		PrintToServer(SERVER_OUTPUT_PREFIX ... "Executing config file %s ...", configExecPath);
		ServerCommand("exec %s", configExecPath);
	} else {
		PrintToServer(SERVER_OUTPUT_PREFIX ... "Config file %s does not exist.",
				configExecPath);
	}
}

/**
 * Returns the Workshop ID for the specified map string.
 */
int GetWorkshopID(const char[] map) {
	EngineVersion currentGame = GetEngineVersion();
	if (StrContains(map, "workshop/") == 0) {
		if (currentGame == Engine_TF2) {
			if (StrContains(map, ".ugc") > -1 ) {
				// workshop/some_map_name.ugc123456789
				return StringToInt( map[ StrContains(map, ".ugc") + 4 ] );
			} else {
				// workshop/123456789
				return StringToInt( map[ StrContains(map, "/") + 1 ] );
			}
		}
		// TODO other formats for workshop map names
		if (currentGame == Engine_CSGO) {
			// workshop/123456789/some_map_name ?
			char mapParts[3][32];
			ExplodeString(map, "/", mapParts, sizeof(mapParts), sizeof(mapParts[]));
			return StringToInt(mapParts[1]);
		}
	}
	return 0;
}
