/**
 * Provides stocks that deal with user messages.
 */

#if defined __stocksoup_tf_hud_notify_included
	#endinput
#endif

#define __stocksoup_tf_hud_notify_included

#include <tf2>

stock void TF_HudNotifyCustom(int client, const char[] icon, TFTeam team, const char[] format,
		any ...) {
	if (client <= 0 || client > MaxClients) {
		ThrowError("Invalid client index %d", client);
	} else if (!IsClientInGame(client)) {
		ThrowError("Client %d is not in game", client);
	}
	
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 5);
	
	TF_HudNotifyCustomParams(view_as<BfWrite>(StartMessageOne("HudNotifyCustom", client)),
			buffer, icon, team);
}

stock void TF_HudNotifyCustomParams(BfWrite bitbuf, const char[] message, const char[] icon,
		TFTeam team) {
	bitbuf.WriteString(message);
	bitbuf.WriteString(icon);
	bitbuf.WriteByte(view_as<int>(team));
	
	EndMessage();
}