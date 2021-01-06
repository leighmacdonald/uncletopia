#include <sourcemod>
#include <morecolors>

public Plugin:myinfo =
{
    name = "Send player to spec",
    author = "Arkarr",
    description = "A simple spectator manager.",
    version = "1.0",
    url = "http://www.sourcemod.net"
};

public OnPluginStart()
{
	RegAdminCmd("sm_spec", SendPlayerAFK, ADMFLAG_GENERIC, "Send player to spec team.");
	//RegConsoleCmd("sm_afk", SendPlayerAFK, "Send player to spec team.");
	//RegAdminCmd("sm_fspec", ForceSendPlayerAFK, ADMFLAG_GENERIC, "Force a player to be in spec team.");

	LoadTranslations("common.phrases");
}

public Action:SendPlayerAFK(client, args)
{
	SendToSpec(client, true);
	return Plugin_Handled;
}

public Action:ForceSendPlayerAFK(client, args)
{
	if(args > 2 || args  == 0)
	{
		CPrintToChat(client, "{green}[SPEC]{default} Usage : sm_fspec [TARGET] \'\'[optional:REASON]\'\'");
		return Plugin_Handled;
	}

	new String:target_name[MAX_TARGET_LENGTH], String:arg1[MAX_TARGET_LENGTH], String:arg2[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;

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
		CPrintToChatAll("{green}[SPEC]{default} Player %s moved to spectator, reason : '%s' !", target_name, arg2);
		SendToSpec(target_list[0], false);
	}
	else
	{
		for (new i = 0; i < target_count; i++)
		{
			SendToSpec(target_list[i], false);
		}

		CPrintToChatAll("{green}[SPEC]{default} Some players as been moved to spectator, reason : '%s' !", arg2);
	}

	return Plugin_Handled;
}

stock SendToSpec(client, bool:user_choice)
{
	if(GetClientTeam(client) != 1)
	{
		ChangeClientTeam(client, 1);
	}
	else if(user_choice == true)
	{
		CPrintToChat(client, "{green}[SPEC]{default} You are already a spectator !");
	}
}