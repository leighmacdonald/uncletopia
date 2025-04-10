function GiveBotsCriticals()
{
	local player = -1
	while (player = Entities.FindByClassname(player, "player"))
	{
		if (player.IsFakeClient())
		{
			player.AddCondEx(Constants.ETFCond.TF_COND_CRITBOOSTED, 0.98, null)
		}
	}
}

function GiveBotsUber()
{
	local player = -1
	while (player = Entities.FindByClassname(player, "player"))
	{
		if (player.IsFakeClient())
		{
			player.AddCondEx(Constants.ETFCond.TF_COND_CRITBOOSTED, 0.98, null)
			player.AddCondEx(Constants.ETFCond.TF_COND_INVULNERABLE, 0.98, null)
		}
	}
}
