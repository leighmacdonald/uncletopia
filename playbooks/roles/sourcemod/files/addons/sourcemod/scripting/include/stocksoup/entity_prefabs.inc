#if defined __stocksoup_entity_prefabs_included
	#endinput
#endif

#define __stocksoup_entity_prefabs_included

stock int CreateParticle(const char[] effectName) {
	int particle = CreateEntityByName("info_particle_system");
	
	if (IsValidEdict(particle)) {
		DispatchKeyValue(particle, "effect_name", effectName);
		DispatchSpawn(particle);
		
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
	}
	return particle;
}

