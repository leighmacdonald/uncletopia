#include <sdkhooks>
#include <sdktools>

ConVar gRulesRoundTime = null;

public Plugin myinfo =
{
	name = "roundtimer",
	author = "Leigh MacDonald",
	description = "Set custom round timers",
	version = "0.0.2",
	url = "https://github.com/leighmacdonald/gbans",
};

public void onPluginStart()
{
	LoadTranslations("common.phrases.txt");

	gRulesRoundTime = CreateConVar("round_time", "-1", "Set the round timer to a custom duration");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(gRulesRoundTime.IntValue >= 0 && StrEqual(classname, "team_round_timer"))
	{
		SDKHook(entity, SDKHook_SpawnPost, timer_spawn_post);
	}
}


public void timer_spawn_post(int timer)
{
	SetVariantInt(gRulesRoundTime.IntValue);
	AcceptEntityInput(timer, "SetMaxTime");

	LogMessage("Overrode round timer time to %d seconds", gRulesRoundTime.IntValue);
}
