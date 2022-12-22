#include <sdkhooks>
#include <sdktools>

public
void onPluginStartRules() {
    // Game rules
    gRulesRoundTime = CreateConVar("gb_rules_round_time", "-1", "Set the round timer to a custom duration");
}

public
void OnEntityCreated(int entity, const char[] classname) {
    if (gRulesRoundTime.IntValue >= 0 && StrEqual(classname, "team_round_timer")) {
        SDKHook(entity, SDKHook_SpawnPost, timer_spawn_post);
    }
}

public
void timer_spawn_post(int timer) {
    SetVariantInt(gRulesRoundTime.IntValue);
    AcceptEntityInput(timer, "SetMaxTime");
    gbLog("Overrode round timer time to %d seconds", gRulesRoundTime.IntValue);
}
