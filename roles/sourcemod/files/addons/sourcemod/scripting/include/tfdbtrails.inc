#if defined _tfdbtrails_included
 #endinput
#endif
#define _tfdbtrails_included

#define ROCKET_MODEL       "models/weapons/w_models/w_rocket.mdl"
#define ROCKET_CRIT_BLU    "critical_rocket_blue"
#define ROCKET_CRIT_RED    "critical_rocket_red"
#define ROCKET_TRAIL_FIRE  "rockettrail_fire"
#define EMPTY_MODEL        "models/empty.mdl"

enum TrailFlags
{
	TrailFlag_None             = 0,
	TrailFlag_CustomTrail      = 1 << 0,
	TrailFlag_CustomSprite     = 1 << 1,
	TrailFlag_RemoveParticles  = 1 << 2,
	TrailFlag_ReplaceParticles = 1 << 3
};

/**
 * Gets the fake entity reference of a rocket.
 *
 * @note Make sure to check if the rocket has the "RocketFlag_RemoveParticles" flag.
 *
 * @param iIndex    Rocket index.
 * @return          Fake entity reference.
 * @error           Invalid index.
*/

native int TFDB_GetRocketFakeEntity(int iIndex);

/**
 * Sets the fake entity reference of a rocket.
 *
 * @note Make sure to check if the rocket has the "RocketFlag_RemoveParticles" flag.
 *
 * @param iIndex         Rocket index.
 * @param iFakeEntity    New fake entity reference.
 * @noreturn
 * @error                Invalid index.
*/

native void TFDB_SetRocketFakeEntity(int iIndex, int iFakeEntity);

/**
 * Gets the trail particle of a rocket class.
 *
 * @param iClass       Rocket class.
 * @param strBuffer    Buffer to store the trail particle of the rocket class.
 * @param iMaxLen      Size of the buffer array.
 * @noreturn
 * @error              Invalid rocket class.
*/

native void TFDB_GetRocketClassTrail(int iClass, char[] strBuffer, int iMaxLen);

/**
 * Sets the trail particle of a rocket class.
 *
 * @param iClass     Rocket class.
 * @param strPath    New rocket class trail particle.
 * @noreturn
 * @error            Invalid rocket class.
*/

native void TFDB_SetRocketClassTrail(int iClass, const char[] strPath);

/**
 * Gets the sprite trail material path of a rocket class (no extension).
 *
 * @param iClass       Rocket class.
 * @param strBuffer    Buffer to store the sprite trail material path of the rocket class.
 * @param iMaxLen      Size of the buffer array.
 * @noreturn
 * @error              Invalid rocket class.
*/

native void TFDB_GetRocketClassSprite(int iClass, char[] strBuffer, int iMaxLen);

/**
 * Sets the sprite trail material path of a rocket class (no extension).
 *
 * @param iClass     Rocket class.
 * @param strPath    New rocket class sprite trail material path.
 * @noreturn
 * @error            Invalid rocket class.
*/

native void TFDB_SetRocketClassSprite(int iClass, const char[] strPath);

/**
 * Gets the sprite trail color of a rocket class.
 *
 * @param iClass       Rocket class.
 * @param strBuffer    Buffer to store the sprite trail color of the rocket class.
 * @param iMaxLen      Size of the buffer array.
 * @noreturn
 * @error              Invalid rocket class.
*/

native void TFDB_GetRocketClassSpriteColor(int iClass, char[] strBuffer, int iMaxLen);

/**
 * Sets the sprite trail color of a rocket class.
 *
 * @param iClass       Rocket class.
 * @param strBuffer    New rocket class sprite trail color.
 * @noreturn
 * @error              Invalid rocket class.
*/

native void TFDB_SetRocketClassSpriteColor(int iClass, const char[] strBuffer);

/**
 * Gets the sprite trail lifetime of a rocket class.
 *
 * @param iClass    Rocket class.
 * @return          Rocket class sprite trail lifetime.
 * @error           Invalid rocket class.
*/

native float TFDB_GetRocketClassSpriteLifetime(int iClass);

/**
 * Sets the sprite trail lifetime of a rocket class.
 *
 * @param iClass       Rocket class.
 * @param fLifetime    New rocket class sprite trail lifetime.
 * @noreturn
 * @error              Invalid rocket class.
*/

native void TFDB_SetRocketClassSpriteLifetime(int iClass, float fLifetime);

/**
 * Gets the sprite trail start width of a rocket class.
 *
 * @param iClass    Rocket class.
 * @return          Rocket class sprite trail start width.
 * @error           Invalid rocket class.
*/

native float TFDB_GetRocketClassSpriteStartWidth(int iClass);

/**
 * Sets the sprite trail start width of a rocket class.
 *
 * @param iClass    Rocket class.
 * @param fWidth    New rocket class sprite trail start width.
 * @noreturn
 * @error           Invalid rocket class.
*/

native void TFDB_SetRocketClassSpriteStartWidth(int iClass, float fWidth);

/**
 * Gets the sprite trail end width of a rocket class.
 *
 * @param iClass    Rocket class.
 * @return          Rocket class sprite trail end width.
 * @error           Invalid rocket class.
*/

native float TFDB_GetRocketClassSpriteEndWidth(int iClass);

/**
 * Sets the sprite trail end width of a rocket class.
 *
 * @param iClass    Rocket class.
 * @param fWidth    New rocket class sprite trail end width.
 * @noreturn
 * @error           Invalid rocket class.
*/

native void TFDB_SetRocketClassSpriteEndWidth(int iClass, float fWidth);

/**
 * Gets the sprite texture resolution of a rocket class.
 *
 * @param iClass    Rocket class.
 * @return          Rocket class sprite texture resolution.
 * @error           Invalid rocket class.
*/

native float TFDB_GetRocketClassTextureRes(int iClass);

/**
 * Sets the sprite texture resolution of a rocket class.
 *
 * @param iClass         Rocket class.
 * @param fResolution    New rocket class sprite texture resolution.
 * @noreturn
 * @error                Invalid rocket class.
*/

native void TFDB_SetRocketClassTextureRes(int iClass, float fResolution);

/**
 * Gets the trail flags of a rocket class.
 *
 * @param iClass    Rocket class.
 * @return          Rocket class trail flags.
 * @error           Invalid rocket class.
*/

native TrailFlags TFDB_GetRocketClassTrailFlags(int iClass);

/**
 * Sets the trail flags of a rocket class.
 *
 * @param iClass    Rocket class.
 * @param iFlags    New rocket class trail flags.
 * @noreturn
 * @error           Invalid rocket class.
*/

native void TFDB_SetRocketClassTrailFlags(int iClass, TrailFlags iFlags);

public SharedPlugin __pl_TFDBTrails =
{
	name = "tfdbtrails",
	file = "tfdb_trails.smx",
	
	#if defined REQUIRE_PLUGIN
		required=1,
	#else
		required=0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_TFDBTrails_SetNTVOptional()
{
	MarkNativeAsOptional("TFDB_GetRocketFakeEntity");
	MarkNativeAsOptional("TFDB_SetRocketFakeEntity");
	MarkNativeAsOptional("TFDB_GetRocketClassTrail");
	MarkNativeAsOptional("TFDB_SetRocketClassTrail");
	MarkNativeAsOptional("TFDB_GetRocketClassSprite");
	MarkNativeAsOptional("TFDB_SetRocketClassSprite");
	MarkNativeAsOptional("TFDB_GetRocketClassSpriteColor");
	MarkNativeAsOptional("TFDB_SetRocketClassSpriteColor");
	MarkNativeAsOptional("TFDB_GetRocketClassSpriteLifetime");
	MarkNativeAsOptional("TFDB_SetRocketClassSpriteLifetime");
	MarkNativeAsOptional("TFDB_GetRocketClassSpriteStartWidth");
	MarkNativeAsOptional("TFDB_SetRocketClassSpriteStartWidth");
	MarkNativeAsOptional("TFDB_GetRocketClassSpriteEndWidth");
	MarkNativeAsOptional("TFDB_SetRocketClassSpriteEndWidth");
	MarkNativeAsOptional("TFDB_GetRocketClassTextureRes");
	MarkNativeAsOptional("TFDB_SetRocketClassTextureRes");
	MarkNativeAsOptional("TFDB_GetRocketClassTrailFlags");
	MarkNativeAsOptional("TFDB_SetRocketClassTrailFlags");
}
#endif
