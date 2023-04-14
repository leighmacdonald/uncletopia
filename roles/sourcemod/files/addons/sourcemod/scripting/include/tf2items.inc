#if defined _tf2items_included
#endinput
#endif
#define _tf2items_included

#include <tf2>

// ====[ CONSTANTS ]===========================================================
#define OVERRIDE_CLASSNAME      (1 << 0)    // Item will override the entity's classname.
#define OVERRIDE_ITEM_DEF       (1 << 1)    // Item will override the item's definition index.
#define OVERRIDE_ITEM_LEVEL     (1 << 2)    // Item will override the entity's level.
#define OVERRIDE_ITEM_QUALITY   (1 << 3)    // Item will override the entity's quality.
#define OVERRIDE_ATTRIBUTES     (1 << 4)    // Item will override the attributes for the item with the given ones.
#define OVERRIDE_ALL            (0b11111)   // Magically enables all the other flags.

#define PRESERVE_ATTRIBUTES     (1 << 5)
#define FORCE_GENERATION        (1 << 6)

// ====[ NATIVES ]=============================================================

/**
 * WARNING: This is for ADVANCED users only!
 * You probably want to be using the forward instead of this.
 *
 * This native will perform a GiveNamedItem call for the specified client in
 * order to generate an object based on the specifications of the TF2Items
 * object passed to it.
 * 
 * Since the item generation requires all the information that can be passed by
 * the extensions natives, the flags will be ignored and all the given
 * information will be used.
 * 
 * Remember that if your values aren't correct, this call may end up in a crash,
 * so please make sure you fill out everything: Classname, item definition index,
 * quality, level and attributes.
 * 
 * @param client          Client that the item will be generated for.
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                Entity index of the newly created item.
 */
native int TF2Items_GiveNamedItem(int client, Handle item);

/**
 * Creates a TF2Items object, wich can be used to override the parameters of an
 * item before it's given to the client, or to create a new completely new one
 * with GiveNamedItem. Remember to free the object with CloseHandle()
 *
 * @param flags           Flags used to specify what to override.
 * @return                Handle to the TFItems object.
 */
native Handle TF2Items_CreateItem(int flags);

/**
 * Sets the flags to determine what the item will override on the GiveNamedItem.
 * Use the OVERRIDE_ defines to set what you will be changing.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @param flags           Flags used to specify what to override.
 */
native void TF2Items_SetFlags(Handle item, int flags);

/**
 * Sets the new entity classname used for the item's entity.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @param classname       New classname to use for the entity.
 */
native void TF2Items_SetClassname(Handle item, char[] classname);

/**
 * Sets the item's Definition Index, wich tells the game what item it is. Each
 * weapon/hat/item has an unique definition index. Find these out in the
 * game_items.txt
 * 
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @param itemDefIndex    New definition index.
 */
native void TF2Items_SetItemIndex(Handle item, int itemDefIndex);

/**
 * Sets the item's quality value, wich determines what color will be used for
 * the item name. Valid values are from 0 to 9.
 * 
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @param quality         New item quality.
 */
native void TF2Items_SetQuality(Handle item, int quality);

/**
 * Sets the item's level value. This value can range from 0 to 127.
 * 
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @param level           New item level.
 */
native void TF2Items_SetLevel(Handle item, int level);

/**
 * Sets the number of attributes that will be used on the item. The maximum
 * number of attributes that can be allocated ranges from 0 to 15.
 * 
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @param attributes      Number of attributes.
 */
native void TF2Items_SetNumAttributes(Handle item, int attributes);

/**
 * Setups the given attribute index to use the attribute and values specified
 * with iAttribDefIndex and flValue. Remember the iSlotIndex ranges from 0 to 15.
 * 
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @param slot            The attribute slot index, ranges from 0 to 15.
 * @param attribute       The attribute definition index, as it appears on game_items.txt.
 * @param value           The value assigned to the attribute (how much health, damage, etc.).
 */
native void TF2Items_SetAttribute(Handle item, int slot, int attribute, float value);

/**
 * Retrieves the flags used to determine what the item will override on the
 * GiveNamedItem call.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                Returns the flags used by the item.
 */
native int TF2Items_GetFlags(Handle item);

/**
 * Gets the entity classname we'll use for the item.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                Size of entity classname string
 */
native int TF2Items_GetClassname(Handle item, char[] dest, int size);

/**
 * Gets the new item definition index we'll use to override.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                New definition index.
 */
native int TF2Items_GetItemIndex(Handle item); 

/**
 * Gets the item's quality value, wich determines what color will be used for
 * the item name. Valid values are from 0 to 9. But if set to 0 and attributes
 * are also changed, this value will be overridden to 9
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                New entity quality.
 */
native int TF2Items_GetQuality(Handle item); 

/**
 * Gets the item's level value. This value can range from 0 to 127.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                New entity level.
 */
native int TF2Items_GetLevel(Handle item);

/**
 * Gets the number of attributes that will be used on the item. The maximum
 * number of attributes that can be allocated ranges from 0 to 15.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                Number of attributes.
 */
native int TF2Items_GetNumAttributes(Handle item);

/**
 * Retrieves the attribute definition index used at the specified index on the
 * item object. Remember the iSlotIndex ranges from 0 to 15.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                The attribute definition index to use.
 */
native int TF2Items_GetAttributeId(Handle item, int slot);

/**
 * Retrieves the value used for the attribute at the specified index on the item
 * object. Remember the iSlotIndex ranges from 0 to 15.
 *
 * @param item            Handle to the TF2Items object that we'll be operating with.
 * @return                The attribute value to use.
 */
native float TF2Items_GetAttributeValue(Handle item, int slot); 

// ====[ FORWARDS ]============================================================
/**
 * Called when an item is about to be given to a client.
 * Return Plugin_Changed to override the item to use the configuration of the item object.
 * Return Plugin_Continue to keep them intact.
 * Return Plugin_Handled to stop the item being given to the player.
 * Make sure the client gets atleast one weapon.
 *
 * @param client          Client Index.
 * @param classname       The classname of the entity that will be generated.
 * @param itemDefIndex    Item definition index.
 * @param item            Handle to a TF2Item object wich describes what values will be overriden.
 */
forward Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &item);

forward void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefIndex, int level, int quality, int entity);

/**
 * Do not edit below this line!
 */
public Extension __ext_tf2items = 
{
	name = "TF2Items",
	file = "tf2items.ext.2.ep2v",
	autoload = 0,
	#if defined REQUIRE_EXTENSIONS
		required = 1,
	#else
		required = 0,
	#endif
}
	
/**
* I'll just leave this here...
* 
* _(º< _(º< _(º< _(º< _(º< _(º< _(º< _(º< _(º< 
* \__) \__) \__) \__) \__) \__) \__) \__) \__) 
*                     .  .
*                    // //  __
*         __  ______||_//_.´.´
*       _/__`´            ¯ `
*      /  / _          _     \
*     /  /( · )      ( · )    |
*    /  |   ¯     __   ¯    _/\/|
*   |    \  ___.-´  `-.___  \   /
*    \    \(     ` ´      `)|   \
*     \     )              //     \
*      \/  /              | |     |
*     /   /               | |     |
*    ·   |                |  \___/
*    |    \_            _/      \  ____
*    ·      `----------´         |´    \
*     \                         /    _·´
*      \                       /  _-´ 
*        `-._               _·´-´
*        _.-´`---________--´ \ 
*       ´-.-. _--·   / .   ._ \
*            ´       `´ `·´  `´
* >º)_ >º)_ >º)_ >º)_ >º)_ >º)_ >º)_ >º)_ >º)_ 
* (__/ (__/ (__/ (__/ (__/ (__/ (__/ (__/ (__/ 
* 
*/
