function KillTheBuildPDA()
{
	local buildpda = -1
	while (buildpda = Entities.FindByClassname(buildpda, "tf_weapon_pda_engineer_build"))
	{
		local owner = (NetProps.GetPropEntity(buildpda,"m_hOwner"))
		if (owner.IsFakeClient())
		{
			buildpda.AcceptInput("Kill", null, null, null)
		}
	}
}

function KillTheDestroyPDA()
{
	local destroypda = -1
	while (destroypda = Entities.FindByClassname(destroypda, "tf_weapon_pda_engineer_destroy"))
	{
		local owner = (NetProps.GetPropEntity(destroypda,"m_hOwner"))
		if (owner.IsFakeClient())
		{
			destroypda.AcceptInput("Kill", null, null, null)
		}
	}
}

function KillTheSpellbook()
{
	local spellbook = -1
	while (spellbook = Entities.FindByClassname(spellbook, "tf_weapon_spellbook"))
	{
		local owner = (NetProps.GetPropEntity(spellbook,"m_hOwner"))
		if (owner.IsFakeClient())
		{
			spellbook.AcceptInput("Kill", null, null, null)
		}
	}
}

function KillThePistol()
{
	local pistol = -1
	while (pistol = Entities.FindByClassname(pistol, "tf_weapon_pistol"))
	{
		local owner = (NetProps.GetPropEntity(pistol,"m_hOwner"))
		if (owner.IsFakeClient())
		{
			pistol.AcceptInput("Kill", null, null, null)
		}
	}
}

function KillTheWrangler()
{
	local wrangler = -1
	while (wrangler = Entities.FindByClassname(wrangler, "tf_weapon_laser_pointer"))
	{
		local owner = (NetProps.GetPropEntity(wrangler,"m_hOwner"))
		if (owner.IsFakeClient())
		{
			wrangler.AcceptInput("Kill", null, null, null)
		}
	}
}

function KillTheShortCircuit()
{
	local shortcircuit = -1
	while (shortcircuit = Entities.FindByClassname(shortcircuit, "tf_weapon_mechanical_arm"))
	{
		local owner = (NetProps.GetPropEntity(shortcircuit,"m_hOwner"))
		if (owner.IsFakeClient())
		{
			shortcircuit.AcceptInput("Kill", null, null, null)
		}
	}
}
