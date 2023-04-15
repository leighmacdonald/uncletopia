#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

#include <sourcemod>

public Plugin myinfo =
{
    name = "Send player to spec",
    author = "Arkarr",
    description = "A simple spectator manager.",
    version = "1.0",
    url = "http://www.sourcemod.net"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_spec", SendPlayerAFK, ADMFLAG_GENERIC, "Send player to spec team.");
	//RegConsoleCmd("sm_afk", SendPlayerAFK, "Send player to spec team.");
	//RegAdminCmd("sm_fspec", ForceSendPlayerAFK, ADMFLAG_GENERIC, "Force a player to be in spec team.");

	LoadTranslations("common.phrases");
}

public Action SendPlayerAFK(int client, int args)
{
	SendToSpec(client, true);
	return Plugin_Handled;
}

public Action ForceSendPlayerAFK(int client, int args)
{
	if(args > 2 || args  == 0)
	{
		PrintToChat(client, "[SPEC] Usage : sm_fspec [TARGET] \'\'[optional:REASON]\'\'");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	char arg1[MAX_TARGET_LENGTH];
	char arg2[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	if(StrEqual(arg2, "", true))
	{
		Format(arg2, sizeof(arg2), "Not specified");
	}


	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	if(target_count == 1)
	{
		PrintToChatAll("[SPEC] Player %s moved to spectator, reason : '%s' !", target_name, arg2);
		SendToSpec(target_list[0], false);
	}
	else
	{
		for (int i = 0; i < target_count; i++)
		{
			SendToSpec(target_list[i], false);
		}
		

		PrintToChatAll("[SPEC] Some players as been moved to spectator, reason : '%s' !", arg2);
	}

	return Plugin_Handled;
}

stock void SendToSpec(int client, bool user_choice)
{
	if (GetClientTeam(client) != 1) {
		ChangeClientTeam(client, 1);
	} else if(user_choice == true) {
		PrintToChat(client, "[SPEC] You are already a spectator !");
	}
}
