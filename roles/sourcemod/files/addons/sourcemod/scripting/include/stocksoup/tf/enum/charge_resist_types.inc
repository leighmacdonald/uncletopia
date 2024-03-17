#if defined __stocksoup_tf_enum_charge_resist_types_included
	#endinput
#endif

#define __stocksoup_tf_enum_charge_resist_types_included

enum TFChargeResistType {
	/**
	 * Not a valid resistance value; use in user-defined functions that may not have an
	 * applicable resistance type (e.g., melee, generic damage).
	 */
	Resist_None = -1,
	
	Resist_Bullet = 0,
	Resist_Blast,
	Resist_Fire
};