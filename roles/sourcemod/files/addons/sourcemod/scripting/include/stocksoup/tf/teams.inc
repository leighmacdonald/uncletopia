#if defined __stocksoup_tf_teams_included
	#endinput
#endif

#define __stocksoup_tf_teams_included

#include <tf2>
#include <sdktools>

enum TFTeamRoles {
	TFTeamRole_Undefined = 0,
	TFTeamRole_Defenders,
	TFTeamRole_Attackers
};

/**
 * Returns the role associated with the given team.
 */
stock TFTeamRoles TF2_GetTeamRole(TFTeam team) {
	int teamEntity = TF2_GetTeamEntity(team);
	if (IsValidEntity(teamEntity)) {
		return view_as<TFTeamRoles>(GetEntProp(teamEntity, Prop_Send, "m_iRole"));
	}
	return TFTeamRole_Undefined;
}

/**
 * Returns the `tf_team` entity associated with a team.
 */
stock int TF2_GetTeamEntity(TFTeam team) {
	int teamEntity = -1;
	while ((teamEntity = FindEntityByClassname(teamEntity, "tf_team")) != -1) {
		if (team == view_as<TFTeam>(GetEntProp(teamEntity, Prop_Send, "m_iTeamNum"))) {
			return teamEntity;
		}
	}
	return INVALID_ENT_REFERENCE;
}