#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <morecolors>

// TODO: cvars?
#define SCRAMBLE_TIMER g_cvarScrambleTimer.FloatValue
#define RTV_TIMER g_cvarRtvTimer.FloatValue
#define WIN_LIMIT_NOMINATION_REMINDER_TRIGGER 1 // nominate reminder will pop up after this many wins on koth/5cp/ctf
#define ROUND_LIMIT_NOMINATION_REMINDER_TRIGGER 1 // nominate reminder will pop up when this many rounds remain on pl/ad

public Plugin myinfo = {
    name        = "Uncletopia Nags",
    author      = "VIORA",
    description = "Provide players with timely and relevant updates.",
    version     = "0.2.1",
    url         = "https://github.com/crescentrose/uncletopia-nags"
};

static bool g_alertToScramble, g_didAlertToNominate;
static int g_playedRounds;
Handle g_teamImbalanceTimer, g_longMapTimer;
ConVar g_cvarRtvTimer, g_cvarScrambleTimer;

public void OnPluginStart() {
    g_playedRounds = 0;
    g_alertToScramble = false;
    g_didAlertToNominate = false;

    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("teamplay_round_win", Event_RoundEnd);
    HookEvent("teamplay_win_panel", Event_WinPanel);
    HookEvent("teamplay_setup_finished", Event_SetupEnds);

    g_cvarScrambleTimer = CreateConVar(
        "ut_scramble_nag_timer",
        "300.0", // 5 minutes
        "How short a round has to be to trigger the scramble reminder (seconds)"
    );

    g_cvarRtvTimer = CreateConVar(
        "ut_rtv_nag_timer",
        "2400.0", // 40 minutes
        "How long does a map have to run for the RTV reminder to trigger (seconds)"
    );
}

public void OnMapStart() {
    g_playedRounds = 0;
    g_alertToScramble = false;
    g_didAlertToNominate = false;

    CleanupTimer(g_teamImbalanceTimer);
    CleanupTimer(g_longMapTimer);

    g_longMapTimer = CreateTimer(RTV_TIMER, LongMapAlert);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (g_alertToScramble) {
        MC_PrintToChatAll("{red}Teams may be unbalanced.{default} Remember: You can type {red}!scramble{default} in chat to vote to scramble the teams.");
    }

    if (ShouldTriggerNominationReminder()) {
        MC_PrintToChatAll("{unusual}Remember:{default} You can type {unusual}!nominate{default} in chat to propose which map to play next.");
        g_didAlertToNominate = true;
    }

    PrintToChatAll("NOTICE: Be aware there are fake Uncletopia servers");
    PrintToChatAll("Please visit uncletopia.com/servers for a list of safe servers.");

    CleanupTimer(g_teamImbalanceTimer);

    g_teamImbalanceTimer = CreateTimer(SCRAMBLE_TIMER, ResetScrambleAlert);
    g_alertToScramble = true;
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
    MC_PrintToChatAll("{green}Like our servers?{default} Please consider subscribing to our patreon to help ensure they stay open.");
    MC_PrintToChatAll("{green}https://www.patreon.com/uncletopia{default}");

    CleanupTimer(g_teamImbalanceTimer);
}

public void Event_WinPanel(Event event, const char[] name, bool dontBroadcast) {
    if (event.GetInt("round_complete") == 1 || StrEqual(name, "arena_win_panel")) {
        g_playedRounds += 1;
    }
}

public void TF2_OnWaitingForPlayersEnd() {
    MC_PrintToChatAll("{unusual}Remember:{default} If you don't want to play this map, you can type {unusual}!rtv{default} in chat to vote to change the map.");
    CleanupTimer(g_teamImbalanceTimer);
    g_alertToScramble = false;
}

public void Event_SetupEnds(Event event, const char[] name, bool dontBroadcast) {
    // reset the scramble alert timer after setup time
    // this will break if you have a 5 minute setup time. to fix, do not have a 5 minute setup time.
    CleanupTimer(g_teamImbalanceTimer);

    g_teamImbalanceTimer = CreateTimer(SCRAMBLE_TIMER, ResetScrambleAlert);
}

public Action ResetScrambleAlert(Handle timer) {
    g_alertToScramble = false;
    CleanupTimer(g_teamImbalanceTimer);

    return Plugin_Stop;
}

public Action LongMapAlert(Handle timer) {
    MC_PrintToChatAll(
        "{unusual}This match has now lasted for %d minutes.{default} Remember: You can type {unusual}!rtv{default} in chat to vote to change the map.",
        RoundFloat(RTV_TIMER / 60)
    );

    return Plugin_Stop;
}


bool ShouldTriggerNominationReminder() {
    if (g_didAlertToNominate)
        return false;

    ConVar cvarWinLimit = FindConVar("mp_winlimit");
    ConVar cvarMaxRounds = FindConVar("mp_maxrounds");
    int maxRounds = cvarMaxRounds.IntValue;
    int winLimit = cvarWinLimit.IntValue;

    // the great TF2 maxrounds/winlimit conundrum
    if (maxRounds > 0) {
        // if we're dealing with maxrounds, we have to track them manually
        int remaining = maxRounds - g_playedRounds;
        if (remaining <= ROUND_LIMIT_NOMINATION_REMINDER_TRIGGER) {
            return true;
        }
    }
    else if (winLimit > 0) {
        // for winlimit maps (koth, 5cp) we just kinda eyeball it and say that
        // we're gonna trigger the notification at a random time in the match
        // there are too many edge cases for me to think about right now
        // TODO: track that properly
        int remaining = winLimit - g_playedRounds;
        if (remaining <= WIN_LIMIT_NOMINATION_REMINDER_TRIGGER) {
            return true;
        }
    }

    // TODO: timelimit maps
    return false;
}

void CleanupTimer(Handle &timer) {
    if (timer != null) {
        KillTimer(timer);
        timer = null;
    }
}
