#include <tf2>

stock bool TF2_SetRoundWinner(TFTeam team) {
	int roundWinEntity = FindEntityByClassname(-1, "game_round_win");
	
	if (roundWinEntity < 1) {
		roundWinEntity = CreateEntityByName("game_round_win");
		
		if (IsValidEntity(roundWinEntity)) {
			DispatchSpawn(roundWinEntity);
		}
	}
	
	if (IsValidEntity(roundWinEntity)) {
		DispatchSpawn(roundWinEntity);
		
		if (team == TFTeam_Spectator) {
			team = TFTeam_Unassigned;
		}
		SetVariantInt(view_as<int>(team));
		AcceptEntityInput(roundWinEntity, "SetTeam");
		AcceptEntityInput(roundWinEntity, "RoundWin");
		return true;
	}
	return false;
}