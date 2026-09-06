#if defined _tfdb_clientcheck_included
 #endinput
#endif
#define _tfdb_clientcheck_included

/**
 * tfdb_clientcheck.inc — single source of truth for client-state predicates.
 *
 * The plugin tree had ~131 IsClientInGame, 75 team-checks, 66 IsFakeClient,
 * and 4 BROKEN IsClientObserver calls scattered across 14 files. This include
 * collapses them to 6 named intents.
 *
 * IMPORTANT: do NOT use the SourceMod stdlib's `IsClientObserver(c)` to detect
 * spectators. It checks `m_iObserverMode != 0`, which returns TRUE for dead
 * pregame players on RED/BLU (TF2 puts them in freeze-cam observer mode while
 * they're not yet alive). That confused multiple branches in PvB before
 * 2026-04-24. Use `TFDB_IsSpectator(c)` here, which checks team explicitly.
 *
 * All helpers are `stock` — they inline at compile time; zero runtime cost.
 */

#include <sourcemod>
#include <tf2>

/**
 * In-game and not a bot/replay/SourceTV.
 *
 * Use for: menu/print/HUD targets where team and alive-state don't matter.
 * Replaces: `IsClientInGame(c) && !IsFakeClient(c)` (~66 sites).
 */
stock bool TFDB_IsRealHuman(int client)
{
	return IsClientInGame(client) && !IsFakeClient(client)
	    && !IsClientReplay(client) && !IsClientSourceTV(client);
}

/**
 * Real human, on RED or BLU (excludes spectator and team-select / unassigned).
 *
 * Use for: vote eligibility, gameplay-state mutators, anything that should
 * exclude specs.
 * Replaces: the 3-clause `!IsClientInGame || IsFakeClient || GetClientTeam <= 1`
 * pattern that appears 25+ times across PvB / DeathMatch / FFA / Votes /
 * Guardian.
 */
stock bool TFDB_IsRealHumanPlaying(int client)
{
	if (!TFDB_IsRealHuman(client)) return false;
	int team = GetClientTeam(client);
	return team == view_as<int>(TFTeam_Red) || team == view_as<int>(TFTeam_Blue);
}

/**
 * Real human, on a play team, currently alive.
 *
 * Use for: damage / rocket / movement / aim work that should only run on
 * actually-alive players.
 */
stock bool TFDB_IsRealHumanAlive(int client)
{
	return TFDB_IsRealHumanPlaying(client) && IsPlayerAlive(client);
}

/**
 * True spectator — team-based check, NOT observer-mode based.
 *
 * Use for: "is this client on the spectator team?" THE CORRECT CHECK.
 * Replaces: `IsClientObserver(c)` everywhere it was being misused
 * (4 sites in PvB before 2026-04-24 that incorrectly skipped dead pregame
 * players on a real team).
 */
stock bool TFDB_IsSpectator(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) <= view_as<int>(TFTeam_Spectator);
}

/**
 * In-game bot (fake client) that's actually playable — excludes replay/SourceTV.
 *
 * Use for: PvB bot targeting, training mode bot iteration, any code that
 * needs to find "the bot" rather than just "any non-human client."
 */
stock bool TFDB_IsLiveBot(int client)
{
	return IsClientInGame(client) && IsFakeClient(client)
	    && !IsClientReplay(client) && !IsClientSourceTV(client);
}

/**
 * Hot-loop variant of TFDB_IsRealHumanPlaying. Skips IsClientReplay and
 * IsClientSourceTV checks — use ONLY inside per-tick OnGameFrame loops where
 * you can guarantee replay/SourceTV bots can't reach the code path.
 *
 * Saves two function calls per client per tick. Negligible per-call but
 * adds up to ~thousands of natives/sec at 24 clients × 66 ticks. Don't
 * micro-optimize unless profiling shows it.
 */
stock bool TFDB_IsHumanPlayingFast(int client)
{
	return IsClientInGame(client) && !IsFakeClient(client)
	    && GetClientTeam(client) > view_as<int>(TFTeam_Spectator);
}
