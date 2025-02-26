#if defined __tf_voice_hook_included
	#endinput
#endif

#define __tf_voice_hook_included

#pragma semicolon 1

enum TFVoiceCommand {
	Voice_Medic = 0,
	Voice_Thanks,
	Voice_Go,
	Voice_MoveUp,
	Voice_Left,
	Voice_Right,
	Voice_Yes,
	Voice_No,
	Voice_Incoming,
	Voice_CloakedSpy,
	Voice_SentryAhead,
	Voice_TeleporterHere,
	Voice_DispenserHere,
	Voice_SentryHere,
	Voice_ActivateCharge,
	Voice_ChargeReady,
	Voice_Help,
	Voice_BattleCry,
	Voice_Cheers,
	Voice_Jeers,
	Voice_Positive,
	Voice_Negative,
	Voice_NiceShot,
	Voice_GoodJob,
	Voice_AskForBall
};

TFVoiceCommand VOICE_MENU[][] = {
	{
		Voice_Medic,
		Voice_Thanks,
		Voice_Go,
		Voice_MoveUp,
		Voice_Left,
		Voice_Right,
		Voice_Yes,
		Voice_No,
		Voice_AskForBall
	}, {
		Voice_Incoming,
		Voice_CloakedSpy,
		Voice_SentryAhead,
		Voice_TeleporterHere,
		Voice_DispenserHere,
		Voice_SentryHere,
		Voice_ActivateCharge,
		Voice_ChargeReady
	}, {
		Voice_Help,
		Voice_BattleCry,
		Voice_Cheers,
		Voice_Jeers,
		Voice_Positive,
		Voice_Negative,
		Voice_NiceShot,
		Voice_GoodJob
	}
};

// no way to use sizeof(VOICE_MENU[1]) lmao
int VOICE_MENU_ITEMS[] = { 9, 9, 8 };

/**
 * Callback for a TF2 voice command.
 * 
 * @return  Plugin_Continue to continue the forward calls, Plugin_Handled to stop the calling
 * 			chain, Plugin_Stop to block the voice command
 */
typedef TFVoiceCommandCallback = function Action(int client, TFVoiceCommand command);

static Handle g_VoiceForwards[TFVoiceCommand];

stock bool RegisterVoiceCommandCallback(TFVoiceCommand command,
		TFVoiceCommandCallback callback) {
	if (!g_VoiceForwards[command]) {
		g_VoiceForwards[command] = CreateForward(ET_Hook, Param_Cell, Param_Cell);
	}
	return AddToForward(g_VoiceForwards[command], INVALID_HANDLE, callback);
}

stock bool UnregisterVoiceCommandCallback(TFVoiceCommand command,
		TFVoiceCommandCallback callback) {
	if (g_VoiceForwards[command]) {
		RemoveFromForward(g_VoiceForwards[command], INVALID_HANDLE, callback);
		
		if (GetForwardFunctionCount(g_VoiceForwards[command]) == 0) {
			delete g_VoiceForwards[command];
			g_VoiceForwards[command] = INVALID_HANDLE;
		}
		return true;
	}
	return false;
}

public Action VoiceMenuListener(int client, const char[] command, int argc) {
	if (!StrEqual(command, "voicemenu")) {
		ThrowError("VoiceMenuListener is not listening to the correct command "
				... "(listening to command %s)", command);
	} else if (argc >= 2) {
		int voiceMenu, voiceMenuSelection;
		char buffer[8];
		
		GetCmdArg(1, buffer, sizeof(buffer));
		voiceMenu = StringToInt(buffer);
		
		GetCmdArg(2, buffer, sizeof(buffer));
		voiceMenuSelection = StringToInt(buffer);
		
		if (voiceMenu >= 0 && voiceMenu < sizeof(VOICE_MENU)
				&& voiceMenuSelection >= 0
				&& voiceMenuSelection < VOICE_MENU_ITEMS[voiceMenu]) {
			TFVoiceCommand voiceCommand = VOICE_MENU[voiceMenu][voiceMenuSelection];	
			
			if (g_VoiceForwards[voiceCommand]) {
				Action result;
				
				Call_StartForward(g_VoiceForwards[voiceCommand]);
				Call_PushCell(client);
				Call_PushCell(voiceCommand);
				Call_Finish(result);
				
				if (result == Plugin_Stop) {
					return Plugin_Handled;
				}
			}
		}
	}
	return Plugin_Continue;
}

stock void RegisterVoiceMenuListener() {
	AddCommandListener(VoiceMenuListener, "voicemenu");
}