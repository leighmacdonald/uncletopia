function Crasher_BlueBoss()
{
	activator.RemoveCustomAttribute("max health additive bonus");
	activator.AddCustomAttribute("max health additive bonus", 1000 - activator.GetMaxHealth(), -1);
	activator.SetHealth(1000);
}

function Crasher_RedBoss()
{
	activator.RemoveCustomAttribute("max health additive bonus");
	activator.AddCustomAttribute("max health additive bonus", 1000 - activator.GetMaxHealth(), -1);
	activator.SetHealth(1000);
	activator.SetOrigin(Vector(-100.36, 235.80, -380));
}
