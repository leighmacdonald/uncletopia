/**
 * Function stocks that wrap SourceMod's plugin handling commands.
 * I wrote this only to use in a plugin that batch enables / disables multiple plugins.
 * 
 * This is intended for interactive management utilities.  Stuff like the following:
 * https://forums.alliedmods.net/showthread.php?t=182086
 * 
 * So before you use this, ask yourself:  *Do I really need to use this?*
 * 
 * If you're using these stocks for some automated scheduled process because someone can't code
 * properly and would rather shit up the server console with plugin unload messages, let me know
 * so I can start not liking said someone.
 * 
 * I am not liable for any damage caused by other authors using these function stocks.
 */

#if defined __stocksoup_plugin_utils_included
	#endinput
#endif

#define __stocksoup_plugin_utils_included

#include <stocksoup/files>

/**
 * Unloads a plugin by file name.
 */
stock bool UnloadPluginFile(const char[] fileName) {
	// TODO make sure plugin is currently in memory
	// file might not exist anymore but still can be unloaded
	return PerformPluginCommand("unload", fileName);
}

/**
 * Loads a plugin by file name.  Plugins in `disabled/` can be enabled temporarily if you add
 * the `disabled/` prefix to the file name.
 */
stock bool LoadPluginFile(const char[] fileName) {
	return PerformPluginCommand("load", fileName);
}

/**
 * Reloads a plugin by file name.
 */
stock bool ReloadPluginFile(const char[] fileName) {
	// TODO make sure plugin is currently loaded?
	return PerformPluginCommand("reload", fileName);
}

/**
 * Moves a plugin from the `disabled/` directory and optionally loads it after.
 * Plugin file name should not include the `disabled/` prefix.
 */
stock bool EnablePluginFile(const char[] fileName, bool load = true) {
	char currentPath[PLATFORM_MAX_PATH];
	BuildPluginFilePath(fileName, currentPath, sizeof(currentPath), true);
	
	if (FileExists(currentPath)) {
		char enabledPath[PLATFORM_MAX_PATH];
		BuildPluginFilePath(fileName, enabledPath, sizeof(enabledPath));
		
		if (RenameFile(enabledPath, currentPath)) {
			if (load) {
				return LoadPluginFile(fileName);
			}
			return true;
		}
	}
	return false;
}

/**
 * Moves a plugin into the `disabled/` directory, optionally unloading it right before.
 * 
 * Returns true if the plugin was moved (and if requested, unloaded).
 */
stock bool DisablePluginFile(const char[] fileName, bool unload = true) {
	if ((unload && UnloadPluginFile(fileName)) || PluginFileExists(fileName)) {
		char currentPath[PLATFORM_MAX_PATH], disabledPath[PLATFORM_MAX_PATH];
		
		BuildPluginFilePath(fileName, currentPath, sizeof(currentPath));
		BuildPluginFilePath(fileName, disabledPath, sizeof(disabledPath), true);
		
		char directories[PLATFORM_MAX_PATH];
		strcopy(directories, FindCharInString(disabledPath, '/', true) + 1, disabledPath);
		
		return CreateDirectories(directories, 0b111101101)
				&& RenameFile(disabledPath, currentPath);
	}
	return false;
}

/**
 * Unloads a plugin given its handle.
 */
stock void UnloadPlugin(Handle plugin = INVALID_HANDLE) {
	char fileName[PLATFORM_MAX_PATH];
	
	GetPluginFilename(plugin, fileName, sizeof(fileName));
	UnloadPluginFile(fileName);
}

/**
 * Reloads a plugin given its handle.
 */
stock void ReloadPlugin(Handle plugin = INVALID_HANDLE) {
	char fileName[PLATFORM_MAX_PATH];
	
	GetPluginFilename(plugin, fileName, sizeof(fileName));
	ReloadPluginFile(fileName);
}

/**
 * Disables a plugin given its handle.
 */
stock void DisablePlugin(Handle plugin = INVALID_HANDLE, bool unload = true) {
	char fileName[PLATFORM_MAX_PATH];
	
	GetPluginFilename(plugin, fileName, sizeof(fileName));
	DisablePluginFile(fileName, unload);
}

// There are no load / enable plugin functions because you can't get a handle to one, obviously.

/**
 * Check that the plugin name corresponds to an actual file.
 */
static stock bool PluginFileExists(const char[] fileName) {
	char filePath[PLATFORM_MAX_PATH];
	BuildPluginFilePath(fileName, filePath, sizeof(filePath));
	
	return FileExists(filePath, false);
}

/**
 * Wrapper for SourceMod's plugins subcommand.
 * 
 * Returns true if the plugin file existed and the action was performed, false if not.
 * This does not mean the plugin was successfully loaded / reloaded / unloaded.
 */
stock bool PerformPluginCommand(const char[] action, const char[] fileName) {
	if (FindCharInString(fileName, '"') != -1 || FindCharInString(fileName, ';') != -1) {
		// just, no, we're not dealing with these characters in a file name
		return false;
	} else if (PluginFileExists(fileName)) {
		ServerCommand("sm plugins %s \"%s\"", action, fileName);
		return true;
	}
	return false;
}

/**
 * Builds the path to a plugin file relative to the game directory, optionally inserting the
 * `disabled/` subdirectory.
 */
stock void BuildPluginFilePath(const char[] fileName, char[] filePath, int maxlen,
		bool disabled = false) {
	// could use a ternary here but it just doesn't sit right with me
	if (disabled) {
		BuildPath(Path_SM, filePath, maxlen, "plugins/disabled/%s", fileName);
	} else {
		BuildPath(Path_SM, filePath, maxlen, "plugins/%s", fileName);
	}
	
	// if no extension or does not end in ".smx"
	int ext = FindCharInString(filePath, '.', true);
	if (ext == -1 || StrContains(filePath[ext], ".smx", false) != 0) {
		StrCat(filePath, maxlen, ".smx");
	}
}
