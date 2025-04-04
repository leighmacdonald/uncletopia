function GiveBotsCriticals()
{
	local MAX_CLIENTS = MaxClients().tointeger()
	for (local i = 1; i <= MAX_CLIENTS; i++)
	{
		local player = PlayerInstanceFromIndex(i)
		if (player.IsFakeClient())
		{
			player.AddCondEx(Constants.ETFCond.TF_COND_CRITBOOSTED, 0.98, null)
		}
	}
}

function GiveBotsUber()
{
	local MAX_CLIENTS = MaxClients().tointeger()
	for (local i = 1; i <= MAX_CLIENTS; i++)
	{
		local player = PlayerInstanceFromIndex(i)
		if (player.IsFakeClient())
		{
			player.AddCondEx(Constants.ETFCond.TF_COND_CRITBOOSTED, 0.98, null)
			player.AddCondEx(Constants.ETFCond.TF_COND_INVULNERABLE, 0.98, null)
		}
	}
}