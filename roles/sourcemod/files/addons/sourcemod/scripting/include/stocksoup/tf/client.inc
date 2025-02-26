/**
 * Provides stocks for client (i.e., the game with a human controlling the character) functions.
 */

#if defined __stocksoup_tf_client_included
	#endinput
#endif

#define __stocksoup_tf_client_included

#include <stocksoup/client>
#include <tf2_stocks>

/**
 * Sets a client's overlay to the appropriate team's invulnerability overlay.
 * 
 * @param client		Client to receive the overlay.
 */
stock void TF2_SetClientUberchargeOverlay(int client) {
	TFTeam team = TF2_GetClientTeam(client);
	switch (team) {
		case TFTeam_Red: {
			SetClientScreenOverlay(client, "effects/invuln_overlay_red");
		}
		case TFTeam_Blue: {
			SetClientScreenOverlay(client, "effects/invuln_overlay_blue");
		}
	}
}

/**
 * Displays the class selection screen to a client.
 * 
 * @param client		Client to display the class selection panel on.
 */
stock void TF2_ShowClassSelectPanel(int client) {
	TFTeam team = TF2_GetClientTeam(client);
	
	ShowVGUIPanel(client, team == TFTeam_Blue ? "class_blue" : "class_red");
}

/**
 * Hides the post-round winning team panel on a given list of clients.
 * 
 * Based off of CTFWinPanel:FireGameEvent():
 * https://github.com/LestaD/SourceEngine2007/blob/master/se2007/game/client/tf/tf_hud_winpanel.cpp#L103
 * 
 * When a client receives the `teamplay_round_start` event, it hides the win panel.
 * `teamplay_game_over` and `tf_game_over` may also possibly work, though I didn't bother
 * checking since it's likely they do other stuff on the client (like showing other panels or
 * something).
 * 
 * @param clients		Array of client indices.
 * @param numClients	Number of clients in the array.
 */
stock void TF2_HideWinPanel(const int[] clients, int numClients) {
	RoundState state = GameRules_GetRoundState();
	if (state == RoundState_TeamWin && numClients) {
		Event event = CreateEvent("teamplay_round_start", true);
		
		#if SOURCEMOD_V_MAJOR > 1 || (SOURCEMOD_V_MAJOR == 1 && SOURCEMOD_V_MINOR > 8)
		// avoid broadcasting event; disabling broadcasts on 1.8 throws an error
		event.BroadcastDisabled = true;
		#endif
		
		for (int i = 0; i < numClients; i++) {
			event.FireToClient(clients[i]);
		}
		
		delete event;
	}
}
