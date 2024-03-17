/** 
 * A list of bot difficulties in Team Fortress 2, as well as getters and setters for them.
 */

#if defined __stocksoup_tf_enum_bot_skills_included
	#endinput
#endif

#define __stocksoup_tf_enum_bot_skills_included

enum TFBotSkill {
	Skill_Easy = 0,
	Skill_Normal,
	Skill_Hard,
	Skill_Expert
};

/**
 * Returns the bot's current skill level.
 */
stock TFBotSkill TF2_GetBotSkill(int client) {
	return view_as<TFBotSkill>(GetEntProp(client, Prop_Send, "m_nBotSkill"));
}

/**
 * @deprecated Function doesn't actually work.
 * As it turns out, the `m_nBotSkill` netprop is seemingly only visual -- the underlying skill
 * value is not a net / data prop and cannot be set the same way.
 * 
 * Actual possibly consistent offset value is available at CTFBotMainAction::Dodge()+E or
 * CTFBotVision::GetMinRecognizeTime()+2B (among other areas).
 */
#pragma deprecated Function does not actually work.
stock void TF2_SetBotSkill(int client, TFBotSkill skill) {
	SetEntProp(client, Prop_Send, "m_nBotSkill", view_as<int>(skill));
}
