function DisableMedieval()
{
    local ent = null
	while (ent = Entities.FindByClassname(ent, "tf_gamerules"))
	{
        NetProps.SetPropBool(ent, "m_bPlayingMedieval", false)
	}
}

DisableMedieval();
