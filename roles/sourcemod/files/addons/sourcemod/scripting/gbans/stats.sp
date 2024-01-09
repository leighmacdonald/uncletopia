stock GetRealClientCount()
{
	int iClients = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			iClients++;
		}
	}

	return iClients;
}


stock GetAllClientCount()
{
	int iClients = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			iClients++;
		}
	}

	return iClients;
}
