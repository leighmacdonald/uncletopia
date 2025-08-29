function KillTheBuildPDA()
{
	local buildpda = null
	while (buildpda = Entities.FindByClassname(buildpda, "tf_weapon_pda_engineer_build"))
	{
		local owner = (NetProps.GetPropEntity(buildpda,"m_hOwner"))
		if (owner != null && owner.IsValid() && owner.IsAlive() && owner.IsFakeClient())
		{
			buildpda.AcceptInput("Kill", null, null, null)
		}
		else continue
	}
}

function KillTheDestroyPDA()
{
	local destroypda = null
	while (destroypda = Entities.FindByClassname(destroypda, "tf_weapon_pda_engineer_destroy"))
	{
		local owner = (NetProps.GetPropEntity(destroypda,"m_hOwner"))
		if (owner != null && owner.IsValid() && owner.IsAlive() && owner.IsFakeClient())
		{
			destroypda.AcceptInput("Kill", null, null, null)
		}
		else continue
	}
}

function KillTheSpellbook()
{
	local spellbook = null
	while (spellbook = Entities.FindByClassname(spellbook, "tf_weapon_spellbook"))
	{
		local owner = (NetProps.GetPropEntity(spellbook,"m_hOwner"))
		if (owner != null && owner.IsValid() && owner.IsAlive() && owner.IsFakeClient())
		{
			spellbook.AcceptInput("Kill", null, null, null)
		}
		else continue
	}
}

function KillThePistol()
{
	local pistol = null
	while (pistol = Entities.FindByClassname(pistol, "tf_weapon_pistol"))
	{
		local owner = (NetProps.GetPropEntity(pistol,"m_hOwner"))
		if (owner != null && owner.IsValid() && owner.IsAlive() && owner.IsFakeClient())
		{
			pistol.AcceptInput("Kill", null, null, null)
		}
		else continue
	}
}

function KillTheWrangler()
{
	local wrangler = null
	while (wrangler = Entities.FindByClassname(wrangler, "tf_weapon_laser_pointer"))
	{
		local owner = (NetProps.GetPropEntity(wrangler,"m_hOwner"))
		if (owner != null && owner.IsValid() && owner.IsAlive() && owner.IsFakeClient())
		{
			wrangler.AcceptInput("Kill", null, null, null)
		}
		else continue
	}
}

function KillTheShortCircuit()
{
	local shortcircuit = null
	while (shortcircuit = Entities.FindByClassname(shortcircuit, "tf_weapon_mechanical_arm"))
	{
		local owner = (NetProps.GetPropEntity(shortcircuit,"m_hOwner"))
		if (owner != null && owner.IsValid() && owner.IsAlive() && owner.IsFakeClient())
		{
			shortcircuit.AcceptInput("Kill", null, null, null)
		}
		else continue
	}
}
