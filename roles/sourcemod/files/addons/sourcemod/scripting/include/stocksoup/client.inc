#if defined __stocksoup_client_included
	#endinput
#endif

#define __stocksoup_client_included

/**
 * Sets a client's overlay to the specified VMT file.  Blank to remove the overlay.
 * 
 * @param client		Client to receive the overlay.
 * @param overlay		Material to use as the overlay, specified relative to the "materials/"
 * 						directory.
 */
stock void SetClientScreenOverlay(int client, const char[] overlay = "") {
	ClientCommand(client, "r_screenoverlay \"%s\"", overlay);
}