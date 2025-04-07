function CarrierBossHealthChange()
{
	boss <- Entities.FindByName(null, "carrier");
	boss.RemoveCustomAttribute("max health additive bonus");
	boss.AddCustomAttribute("max health additive bonus", 1000 - boss.GetMaxHealth(), -1);
	boss.SetHealth(1000);
	boss.RemoveCond(TF_COND_CRITBOOSTED_ON_KILL);
	boss.AddCond(TF_COND_OFFENSEBUFF);
}