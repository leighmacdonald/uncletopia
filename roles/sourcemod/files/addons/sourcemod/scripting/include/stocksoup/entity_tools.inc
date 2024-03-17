#if defined __stocksoup_entity_utils_included
	#endinput
#endif

#define __stocksoup_entity_utils_included

stock bool ParentEntity(int parent, int attachment, const char[] attachPoint = "",
		bool maintainOffset = false) {
	SetVariantString("!activator");
	AcceptEntityInput(attachment, "SetParent", parent, attachment, 0);
	
	if (strlen(attachPoint) > 0) {
		SetVariantString(attachPoint);
		AcceptEntityInput(attachment,
				maintainOffset? "SetParentAttachmentMaintainOffset" : "SetParentAttachment",
				parent, parent);
	}
}

/**
 * Copies the entity's model into the specified buffer.
 */
stock void GetEntityModelPath(int entity, char[] buffer, int maxlen) {
	GetEntPropString(entity, Prop_Data, "m_ModelName", buffer, maxlen);
}

/**
 * Attempts to retrieve a target name for an entity.
 * Returns false if a name isn't set, error implied if `m_iName` isn't available via datamaps
 * (why would you even try to get the target name of an entity that doesn't have one?).
 */
stock bool GetEntityTargetName(int entity, char[] target, int maxlen, bool generate = false) {
	GetEntPropString(entity, Prop_Data, "m_iName", target, maxlen);
	
	if (strlen(target) != 0) {
		// it has an existing targetname
		return true;
	} else if (generate) {
		// no existing targetname, generate one based on the plugin
		GeneratePluginTargetName(target, maxlen);
		SetEntPropString(entity, Prop_Data, "m_iName", target);
		
		return true;
	}
	
	// no existing target name, did not apply a new one
	return false;
}

stock void GeneratePluginTargetName(char[] target, int maxlen) {
	// A few scoped globals to prevent target naming conflicts.
	
	static int m_nEmptyTargets, m_FirstCallTime = -1;
	static char m_PluginName[PLATFORM_MAX_PATH];
	
	/**
	 * We don't want the possibility of a target name already existing, even if the plugin is
	 * restarted.  First tick count is unique enough to the game session to avoid possible
	 * conflicts.
	 */
	if (m_FirstCallTime == -1) {
		m_FirstCallTime = GetGameTickCount();
	}
	
	if (strlen(m_PluginName) == 0) {
		GetPluginFilename(INVALID_HANDLE, m_PluginName, sizeof(m_PluginName));
	}
	
	Format(target, maxlen, "__%s_pl_target_%d_%d", m_PluginName, m_FirstCallTime,
			m_nEmptyTargets++);
	
	m_nEmptyTargets %= 4096;
}

/**
 * Searches for an entity by target name. 
 */
stock int FindEntityByTargetName(int startEnt = -1, const char[] target,
		const char[] className = "*") {
	int targetmaxlen = strlen(target) + 1;
	char[] targetbuf = new char[targetmaxlen];
	while ((startEnt = FindEntityByClassname(startEnt, className)) != -1) {
		GetEntityTargetName(startEnt, targetbuf, targetmaxlen);
		
		if (StrEqual(target, targetbuf)) {
			return startEnt;
		}
	}
	return startEnt;
}
