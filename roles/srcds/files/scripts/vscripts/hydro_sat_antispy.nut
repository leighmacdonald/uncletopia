function SatCaptureStartTouch()
{
	if (activator.GetTeam() == 3 && activator.GetPlayerClass() == Constants.ETFClass.TF_CLASS_SPY)
	{
		activator.AddCustomAttribute("increase player capture value", -1, -1)
	}
}

function SatCaptureEndTouch()
{
	activator.RemoveCustomAttribute("increase player capture value")
}
