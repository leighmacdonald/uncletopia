#pragma semicolon 1
#pragma newdecls required

#include <tf_econ_data>

public Plugin myinfo =
{
	name		= "[TF2] Econ Data Test",
	author		= "Malifox",
	description = "Automated tests for [TF2] Econ Data",
	version		= "1.0.0",
	url			= ""
}

#define LOG_PREFIX "[TFEconData Test] "
#define LOG_PREFIX_START LOG_PREFIX ... "Starting: "
#define LOG_PREFIX_PASS LOG_PREFIX ... "Passed: "
#define LOG_PREFIX_FAIL LOG_PREFIX ... "***FAILED*** "
#define LOG_PREFIX_WARN LOG_PREFIX ... "**WARNING** "
#define LOG_PREFIX_INFO LOG_PREFIX ... "--- "
#define LOG_MAX_PRINT_PARTICLE_NAMES 5
#define LOG_MAX_PRINT_PAINTKIT_INDEXES 5

#define TF2_LOADOUT_SLOT_COUNT 19

#define DEF_INDEX_THE_THERMAL_THRUSTER 1179	// The Thermal Thruster
#define DEF_INDEX_THE_HEAD_PRIZE 30838		// The Head Prize
#define DEF_INDEX_THE_CAUTERIZERS_CAUDAL_APPENDAGE 30225 // The Cauterizer's Caudal Appendage
#define DEF_INDEX_TF_WEAPON_SHOTGUN_PYRO 12	// TF_WEAPON_SHOTGUN_PYRO

#define ATTR_MAJOR_MOVE_SPEED_BONUS 442 // "major move speed bonus"
#define ATTR_DISABLE_WEAPON_SWITCH 698 // "disable weapon switch"

enum LogType
{
	LogType_Start = 0,
	LogType_Passed,
	LogType_Failed,
	LogType_Warn,
	LogType_Info
}

enum TF2ItemQuality {
	TF2ItemQuality_Undefined = -1,
	TF2ItemQuality_Normal = 0,
	TF2ItemQuality_Rarity1 = 1,
	TF2ItemQuality_Genuine = TF2ItemQuality_Rarity1,
	TF2ItemQuality_Rarity2 = 2,
	TF2ItemQuality_Vintage = 3,
	TF2ItemQuality_Rarity3 = 4,
	TF2ItemQuality_Rarity4 = 5,
	TF2ItemQuality_Unusual = TF2ItemQuality_Rarity4,
	TF2ItemQuality_Unique = 6,
	TF2ItemQuality_Community = 7,
	TF2ItemQuality_Developer = 8,
	TF2ItemQuality_Selfmade = 9,
	TF2ItemQuality_Customized = 10,
	TF2ItemQuality_Strange = 11,
	TF2ItemQuality_Completed = 12,
	TF2ItemQuality_Haunted = 13,
	TF2ItemQuality_Collectors = 14,
	TF2ItemQuality_PaintkitWeapon = 15
}

enum TF2ItemRarity
{
	TF2ItemRarity_Undefined = -1,
	TF2ItemRarity_Common = 1,
	TF2ItemRarity_Uncommon = 2,
	TF2ItemRarity_Rare = 3,
	TF2ItemRarity_Mythical = 4,
	TF2ItemRarity_Legendary = 5,
	TF2ItemRarity_Ancient = 6,
	TF2ItemRarity_Immortal = 7,
	TF2ItemRarity_Unusual = 99
}

/* "equip_conflicts"
{
	"glasses"
	{
		"face"			"1"
		"lenses"		"1"
	}
	"whole_head"
	{
		"hat"			"1"
		"face"			"1"
		"glasses"		"1"
	}
} */
#define TF2EQUIPREGION_WHOLE_HEAD (1 << 0)
#define TF2EQUIPREGION_HAT (1 << 1)
#define TF2EQUIPREGION_FACE (1 << 2)
#define TF2EQUIPREGION_GLASSES (1 << 3)
#define TF2EQUIPREGION_LENSES (1 << 4)

enum TF2EquipRegion
{
	TF2EquipRegion_WholeHead = (1 << 0) | TF2EQUIPREGION_HAT | TF2EQUIPREGION_FACE | TF2EQUIPREGION_GLASSES, // whole_head
	TF2EquipRegion_Hat = (1 << 1) | TF2EQUIPREGION_WHOLE_HEAD, // hat
	TF2EquipRegion_Face = (1 << 2) | TF2EQUIPREGION_WHOLE_HEAD | TF2EQUIPREGION_GLASSES, // face
	TF2EquipRegion_Glasses = (1 << 3) | TF2EQUIPREGION_WHOLE_HEAD | TF2EQUIPREGION_FACE | TF2EQUIPREGION_LENSES, // glasses
	TF2EquipRegion_Lenses = (1 << 4) | TF2EQUIPREGION_GLASSES,	// lenses
	TF2EquipRegion_Pants = (1 << 5),	// pants
	TF2EquipRegion_Beard = (1 << 6),	// beard
	TF2EquipRegion_Shirt = (1 << 7),	// shirt
	TF2EquipRegion_Medal = (1 << 8),	// medal
	TF2EquipRegion_Arms = (1 << 9),		// arms
	TF2EquipRegion_Back = (1 << 10),	// back
	TF2EquipRegion_Feet = (1 << 11),	// feet
	TF2EquipRegion_Necklace = (1 << 12),// necklace
	TF2EquipRegion_Grenades = (1 << 13),// grenades
	TF2EquipRegion_ArmTattoos = (1 << 14),// arm_tattoos
	TF2EquipRegion_Flair = (1 << 15),	// flair
	TF2EquipRegion_HeadSkin = (1 << 16),// head_skin
	TF2EquipRegion_Ears = (1 << 17),	// ears
	TF2EquipRegion_LeftShoulder = (1 << 18),// left_shoulder
	TF2EquipRegion_BeltMisc = (1 << 19),	// belt_misc
	TF2EquipRegion_DisconnectedFloatingItem = (1 << 20), // disconnected_floating_item
	TF2EquipRegion_ZombieBody = (1 << 21),	// zombie_body
	TF2EquipRegion_Sleeves = (1 << 22),		// sleeves
	TF2EquipRegion_RightShoulder = (1 << 23), // right_shoulder
	TF2EquipRegion_Shared1 = (1 << 24),
	TF2EquipRegion_Shared2 = (1 << 25),
	TF2EquipRegion_Shared3 = (1 << 26),
	TF2EquipRegion_Shared4 = (1 << 27),
	TF2EquipRegion_Shared5 = (1 << 28),
	TF2EquipRegion_Shared6 = (1 << 29),
	TF2EquipRegion_Shared7 = (1 << 30),
	TF2EquipRegion_PyroSpikes = TF2EquipRegion_Shared1,		// pyro_spikes
	TF2EquipRegion_ScoutBandages = TF2EquipRegion_Shared1,	// scout_bandages
	TF2EquipRegion_EngineerPocket = TF2EquipRegion_Shared1,	// engineer_pocket
	TF2EquipRegion_HeavyBeltBack = TF2EquipRegion_Shared1,	// heavy_belt_back
	TF2EquipRegion_DemoEyepatch = TF2EquipRegion_Shared1,	// demo_eyepatch
	TF2EquipRegion_SoldierGloves = TF2EquipRegion_Shared1,	// soldier_gloves
	TF2EquipRegion_SpyGloves = TF2EquipRegion_Shared1,		// spy_gloves
	TF2EquipRegion_ScoutBackpack = TF2EquipRegion_Shared2,	// scout_backpack
	TF2EquipRegion_HeavyPocket = TF2EquipRegion_Shared2,	// heavy_pocket
	TF2EquipRegion_EngineerBelt = TF2EquipRegion_Shared2,	// engineer_belt
	TF2EquipRegion_SoldierPocket = TF2EquipRegion_Shared2,	// soldier_pocket
	TF2EquipRegion_DemoBelt = TF2EquipRegion_Shared2,		// demo_belt
	TF2EquipRegion_SniperQuiver = TF2EquipRegion_Shared2,	// sniper_quiver
	TF2EquipRegion_PyroWings = TF2EquipRegion_Shared3,		// pyro_wings
	TF2EquipRegion_SniperBullets = TF2EquipRegion_Shared3,	// sniper_bullets
	TF2EquipRegion_MedigunAccessories = TF2EquipRegion_Shared3,// medigun_accessories
	TF2EquipRegion_SoldierCoat = TF2EquipRegion_Shared3,	// soldier_coat
	TF2EquipRegion_HeavyBelt = TF2EquipRegion_Shared3,		// heavy_belt
	TF2EquipRegion_ScoutHands = TF2EquipRegion_Shared3,		// scout_hands
	TF2EquipRegion_EngineerLeftArm = TF2EquipRegion_Shared4,// engineer_left_arm
	TF2EquipRegion_PyroTail = TF2EquipRegion_Shared4,		// pyro_tail
	TF2EquipRegion_SniperLegs = TF2EquipRegion_Shared4,		// sniper_legs
	TF2EquipRegion_MedicGloves = TF2EquipRegion_Shared4,	// medic_gloves
	TF2EquipRegion_SoldierCigar = TF2EquipRegion_Shared4,	// soldier_cigar
	TF2EquipRegion_DemomanCollar = TF2EquipRegion_Shared4,	// demoman_collar
	TF2EquipRegion_HeavyTowel = TF2EquipRegion_Shared4,		// heavy_towel
	TF2EquipRegion_EngineerWings = TF2EquipRegion_Shared5,	// engineer_wings
	TF2EquipRegion_PyroHeadReplacement = TF2EquipRegion_Shared5,// pyro_head_replacement
	TF2EquipRegion_ScoutWings = TF2EquipRegion_Shared5,		// scout_wings
	TF2EquipRegion_HeavyHair = TF2EquipRegion_Shared5,		// heavy_hair
	TF2EquipRegion_MedicPipe = TF2EquipRegion_Shared5,		// medic_pipe
	TF2EquipRegion_SoldierLegs = TF2EquipRegion_Shared5,	// soldier_legs
	TF2EquipRegion_DemoHeadReplacement = TF2EquipRegion_Shared5,// demo_head_replacement
	TF2EquipRegion_SniperHeadband = TF2EquipRegion_Shared5,	// sniper_headband
	TF2EquipRegion_ScoutPants = TF2EquipRegion_Shared6,		// scout_pants
	TF2EquipRegion_HeavyBullets = TF2EquipRegion_Shared6,	// heavy_bullets
	TF2EquipRegion_EngineerHair = TF2EquipRegion_Shared6,	// engineer_hair
	TF2EquipRegion_SniperVest = TF2EquipRegion_Shared6,		// sniper_vest
	TF2EquipRegion_MedigunBackpack = TF2EquipRegion_Shared6,// medigun_backpack
	TF2EquipRegion_SniperPocketLeft = TF2EquipRegion_Shared6,// sniper_pocket_left
	TF2EquipRegion_SniperPocket = TF2EquipRegion_Shared7,	// sniper_pocket
	TF2EquipRegion_HeavyHip = TF2EquipRegion_Shared7,		// heavy_hip
	TF2EquipRegion_SpyCoat = TF2EquipRegion_Shared7,		// spy_coat
	TF2EquipRegion_MedicHip = TF2EquipRegion_Shared7		// medic_hip
}

int g_iTestsTotal;
int g_iTestsPassed;
int g_iTestWarnings;

const int g_iTestBaseItem = DEF_INDEX_TF_WEAPON_SHOTGUN_PYRO; // items_game.txt: "baseitem" "1"
const int g_iTestRarityLegendary = DEF_INDEX_THE_HEAD_PRIZE; // items_game.txt: Winter2016_Cosmetics_collection
const int g_iTestRegionGroup4 = DEF_INDEX_THE_CAUTERIZERS_CAUDAL_APPENDAGE; // "pyro_tail" items_game.txt: "shared" subkey in "equip_regions_list"

// items_game.txt: "stored_as_integer"	"1" "hidden"	"1"
static const char g_sTestAttribNameInt[] = "disable weapon switch";
static const char g_sTestAttribClassInt[] = "disable_weapon_switch";
const int g_iTestAttribDefIndexInt = ATTR_DISABLE_WEAPON_SWITCH;

// items_game.txt: "stored_as_integer"	"0"
const int g_iTestAttribDefIndexFloat = ATTR_MAJOR_MOVE_SPEED_BONUS;

// Based on items_game.txt
enum struct TestItem
{
	int iDefIndex;
	TFClassType tfClassType;
	char sName[64];					// "name"
	char sItemClass[64];			// "item_class"
	char sItemName[64];				// "item_name" (Localized name)
	int iItemLoadoutSlot;			// "item_slot"
	int iItemDefaultLoadoutSlot;
	TF2EquipRegion tf2EquipRegion;	// "equip_region"
	int iMinLevel;					// "min_ilevel"
	int iMaxLevel;					// "max_ilevel"
	TF2ItemQuality tf2ItemQuality;	// "item_quality"
	TF2ItemRarity tf2ItemRarity;

	void Init()
	{
		this.iDefIndex = DEF_INDEX_THE_THERMAL_THRUSTER;
		this.tfClassType = TFClass_Pyro;
		this.sName = "The Thermal Thruster";
		this.sItemClass = "tf_weapon_rocketpack";
		this.sItemName = "#TF_ThermalThruster";
		this.iItemLoadoutSlot = 1; // Secondary
		this.iItemDefaultLoadoutSlot = 1; // Secondary
		this.tf2EquipRegion = TF2EquipRegion_Back;
		this.iMinLevel = 1;
		this.iMaxLevel = 100;
		this.tf2ItemQuality = TF2ItemQuality_Unique;
		this.tf2ItemRarity = TF2ItemRarity_Undefined;
	}

	void Test_TF2Econ_IsValidItemDefinition(int client)
	{
		char sTest[] = "TF2Econ_IsValidItemDefinition";
		LogTest(client, LogType_Start, sTest);

		if (TF2Econ_IsValidItemDefinition(this.iDefIndex))
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_IsValidItemDefinition(%d) returned false, expected true.", this.iDefIndex);
	}

	void Test_TF2Econ_GetItemName(int client)
	{
		char sTest[] = "TF2Econ_GetItemName";
		LogTest(client, LogType_Start, sTest);

		char sName[sizeof(TestItem::sName)];

		if (!TF2Econ_GetItemName(this.iDefIndex, sName, sizeof(sName)))
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetItemName(%d) returned false.", this.iDefIndex);
			return;
		}

		if (StrEqual(sName, this.sName))
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_GetItemName(%d) returned '%s', expected '%s'.",
				this.iDefIndex, sName, this.sName);
	}

	void Test_TF2Econ_GetLocalizedItemName(int client)
	{
		char sTest[] = "TF2Econ_GetLocalizedItemName";
		LogTest(client, LogType_Start, sTest);

		char sItemName[sizeof(TestItem::sItemName)];

		if (!TF2Econ_GetLocalizedItemName(this.iDefIndex, sItemName, sizeof(sItemName)))
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetLocalizedItemName(%d) returned false.", this.iDefIndex);
			return;
		}

		if (StrEqual(sItemName, this.sItemName))
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_GetLocalizedItemName(%d) returned '%s', expected '%s'.",
				this.iDefIndex, sItemName, this.sItemName);
	}

	void Test_TF2Econ_GetItemClassName(int client)
	{
		char sTest[] = "TF2Econ_GetItemClassName";
		LogTest(client, LogType_Start, sTest);

		char sItemClass[sizeof(TestItem::sItemClass)];

		if (!TF2Econ_GetItemClassName(this.iDefIndex, sItemClass, sizeof(sItemClass)))
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetItemClassName(%d) returned false.", this.iDefIndex);
			return;
		}

		if (StrEqual(sItemClass, this.sItemClass))
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_GetItemClassName(%d) returned '%s', expected '%s'.",
				this.iDefIndex, sItemClass, this.sItemClass);
	}

	void Test_TF2Econ_GetItemLoadoutSlot(int client)
	{
		char sTest[] = "TF2Econ_GetItemLoadoutSlot";
		LogTest(client, LogType_Start, sTest);

		int iLoadoutSlot = TF2Econ_GetItemLoadoutSlot(this.iDefIndex, this.tfClassType);

		if (iLoadoutSlot == this.iItemLoadoutSlot)
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_GetItemLoadoutSlot(%d) returned %d, expected %d.",
				this.iDefIndex, iLoadoutSlot, this.iItemLoadoutSlot);
	}

	void Test_TF2Econ_GetItemDefaultLoadoutSlot(int client)
	{
		char sTest[] = "TF2Econ_GetItemDefaultLoadoutSlot";
		LogTest(client, LogType_Start, sTest);

		int iDefaultLoadoutSlot = TF2Econ_GetItemDefaultLoadoutSlot(this.iDefIndex);

		if (iDefaultLoadoutSlot == this.iItemDefaultLoadoutSlot)
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_GetItemDefaultLoadoutSlot(%d) returned %d, expected %d.",
				this.iDefIndex, iDefaultLoadoutSlot, this.iItemDefaultLoadoutSlot);
	}

	void Test_TF2Econ_GetItemEquipRegionMask(int client)
	{
		char sTest[] = "TF2Econ_GetItemEquipRegionMask";
		LogTest(client, LogType_Start, sTest);

		TF2EquipRegion tf2EquipRegion = view_as<TF2EquipRegion>(TF2Econ_GetItemEquipRegionMask(this.iDefIndex));

		if (tf2EquipRegion == this.tf2EquipRegion)
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_GetItemEquipRegionMask(%d) returned %d, expected %d.",
				this.iDefIndex, tf2EquipRegion, this.tf2EquipRegion);
	}

	void Test_TF2Econ_GetItemEquipRegionGroupBits(int client)
	{
		char sTest[] = "TF2Econ_GetItemEquipRegionGroupBits";
		LogTest(client, LogType_Start, sTest);

		TF2EquipRegion tf2EquipRegionGroupBits = view_as<TF2EquipRegion>(TF2Econ_GetItemEquipRegionGroupBits(this.iDefIndex));
		TF2EquipRegion tf2EquipRegionGroup4Bits = view_as<TF2EquipRegion>(TF2Econ_GetItemEquipRegionGroupBits(g_iTestRegionGroup4));

		if (tf2EquipRegionGroupBits != this.tf2EquipRegion || tf2EquipRegionGroup4Bits != TF2EquipRegion_PyroTail)
		{
			if (tf2EquipRegionGroupBits != this.tf2EquipRegion)
				LogTest(client, LogType_Failed, "TF2Econ_GetItemEquipRegionGroupBits(%d) returned %d, expected %d.",
					this.iDefIndex, tf2EquipRegionGroupBits, this.tf2EquipRegion);

			if (tf2EquipRegionGroup4Bits != TF2EquipRegion_PyroTail)
				LogTest(client, LogType_Failed, "TF2Econ_GetItemEquipRegionGroupBits(%d) returned %d, expected %d.",
					g_iTestRegionGroup4, tf2EquipRegionGroup4Bits, TF2EquipRegion_PyroTail);

			return;
		}

		LogTest(client, LogType_Passed, sTest);
	}

	void Test_TF2Econ_GetItemLevelRange(int client)
	{
		char sTest[] = "TF2Econ_GetItemLevelRange";
		LogTest(client, LogType_Start, sTest);

		int iMinLevel;
		int iMaxLevel;

		if (!TF2Econ_GetItemLevelRange(this.iDefIndex, iMinLevel, iMaxLevel))
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetItemLevelRange(%d) returned false.", this.iDefIndex);
			return;
		}

		if (iMinLevel != this.iMinLevel || iMaxLevel != this.iMaxLevel)
		{
			if (iMinLevel != this.iMinLevel)
				LogTest(client, LogType_Failed, "TF2Econ_GetItemLevelRange(%d) returned min level %d, expected %d.",
					this.iDefIndex, iMinLevel, this.iMinLevel);

			if (iMaxLevel != this.iMaxLevel)
				LogTest(client, LogType_Failed, "TF2Econ_GetItemLevelRange(%d) returned max level %d, expected %d.",
					this.iDefIndex, iMaxLevel, this.iMaxLevel);

			return;
		}

		LogTest(client, LogType_Passed, sTest);
	}

	void Test_TF2Econ_GetItemQuality(int client)
	{
		char sTest[] = "TF2Econ_GetItemQuality";
		LogTest(client, LogType_Start, sTest);

		TF2ItemQuality iQuality = view_as<TF2ItemQuality>(TF2Econ_GetItemQuality(this.iDefIndex));

		if (iQuality == this.tf2ItemQuality)
			LogTest(client, LogType_Passed, sTest);
		else
			LogTest(client, LogType_Failed, "TF2Econ_GetItemQuality(%d) returned %d, expected %d.",
				this.iDefIndex, iQuality, this.tf2ItemQuality);
	}

	void Test_TF2Econ_GetItemRarity(int client)
	{
		char sTest[] = "TF2Econ_GetItemRarity";
		LogTest(client, LogType_Start, sTest);

		TF2ItemRarity iRarity = view_as<TF2ItemRarity>(TF2Econ_GetItemRarity(this.iDefIndex));
		TF2ItemRarity iRarityLegendary = view_as<TF2ItemRarity>(TF2Econ_GetItemRarity(g_iTestRarityLegendary));

		if (iRarity != this.tf2ItemRarity || iRarityLegendary != TF2ItemRarity_Legendary)
		{
			if (iRarity != this.tf2ItemRarity)
				LogTest(client, LogType_Failed, "TF2Econ_GetItemRarity(%d) returned %d, expected %d.",
					this.iDefIndex, iRarity, this.tf2ItemRarity);

			if (iRarityLegendary != TF2ItemRarity_Legendary)
				LogTest(client, LogType_Failed, "TF2Econ_GetItemRarity(%d) returned %d, expected %d.",
					g_iTestRarityLegendary, iRarityLegendary, TF2ItemRarity_Legendary);

			return;
		}

		LogTest(client, LogType_Passed, sTest);
	}

	void Test_TF2Econ_GetItemStaticAttributes(int client)
	{
		char sTest[] = "TF2Econ_GetItemStaticAttributes";
		LogTest(client, LogType_Start, sTest);

		ArrayList attrs = TF2Econ_GetItemStaticAttributes(this.iDefIndex);

		if (!attrs)
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetItemStaticAttributes(%d) returned null.", this.iDefIndex);
			return;
		}

		int iNumAttr = attrs.Length;

		if (!iNumAttr)
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetItemStaticAttributes(%d) returned empty list.", this.iDefIndex);

			delete attrs;
			return;
		}

		for (int i = 0; i < iNumAttr; i++)
		{
			LogTest(client, LogType_Info, "TF2Econ_GetItemStaticAttributes(%d) Attrib %d: %d = %f",
				this.iDefIndex, i, attrs.Get(i), attrs.Get(i, 1));
		}

		delete attrs;
		LogTest(client, LogType_Passed, sTest);
	}
}
TestItem g_TestItem;

public void OnPluginStart()
{
	g_TestItem.Init();

	RegAdminCmd("sm_test_tf2econdata", Command_TestTF2EconData, ADMFLAG_ROOT, "Automated test of every TF2Econ native.");
}

Action Command_TestTF2EconData(int client, int argc)
{
	g_iTestsTotal = g_iTestsPassed = g_iTestWarnings = 0;

	g_TestItem.Test_TF2Econ_IsValidItemDefinition(client);
	Test_TF2Econ_IsItemInBaseSet(client);
	g_TestItem.Test_TF2Econ_GetItemName(client);
	g_TestItem.Test_TF2Econ_GetLocalizedItemName(client);
	g_TestItem.Test_TF2Econ_GetItemClassName(client);
	g_TestItem.Test_TF2Econ_GetItemLoadoutSlot(client);
	g_TestItem.Test_TF2Econ_GetItemDefaultLoadoutSlot(client);
	g_TestItem.Test_TF2Econ_GetItemEquipRegionMask(client);
	g_TestItem.Test_TF2Econ_GetItemEquipRegionGroupBits(client);
	g_TestItem.Test_TF2Econ_GetItemLevelRange(client);
	g_TestItem.Test_TF2Econ_GetItemQuality(client);
	g_TestItem.Test_TF2Econ_GetItemRarity(client);
	g_TestItem.Test_TF2Econ_GetItemStaticAttributes(client);
	Test_TF2Econ_TranslateWeaponEntForClass(client);
	Test_TF2Econ_TranslateLoadoutSlotIndexToName(client);
	Test_TF2Econ_TranslateLoadoutSlotNameToIndex(client);
	Test_TF2Econ_GetLoadoutSlotCount(client);
	Test_TF2Econ_IsValidAttributeDefinition(client);
	Test_TF2Econ_IsAttributeHidden(client);
	Test_TF2Econ_IsAttributeStoredAsInteger(client);
	Test_TF2Econ_GetAttributeName(client);
	Test_TF2Econ_GetAttributeClassName(client);
	Test_TF2Econ_GetAttributeDefinitionString(client);
	Test_TF2Econ_TranslateAttributeNameToDefinitionIndex(client);
	Test_TF2Econ_GetAttributeList(client); // AttributeFilterCriteria not tested
	Test_TF2Econ_GetQualityName(client);
	Test_TF2Econ_TranslateQualityNameToValue(client);
	Test_TF2Econ_GetQualityList(client);
	Test_TF2Econ_GetRarityName(client);
	Test_TF2Econ_TranslateRarityNameToValue(client);
	Test_TF2Econ_GetRarityList(client);
	Test_TF2Econ_GetEquipRegionGroups(client);
	Test_TF2Econ_GetEquipRegionMask(client);
	Test_TF2Econ_GetParticleAttributeList(client); // TF2Econ_GetParticleAttributeList, TF2Econ_GetParticleAttributeSystemName
	Test_TF2Econ_GetPaintKitDefinitionList(client);
	Test_TF2Econ_GetMapDefinitionIndexByName(client);
	// Address natives, only testing they don't crash and null checks
	Test_TF2Econ_GetItemSchemaAddress(client);
	Test_TF2Econ_GetProtoDefManagerAddress(client);
	Test_TF2Econ_GetItemDefinitionAddress(client);
	Test_TF2Econ_GetAttributeDefinitionAddress(client);
	Test_TF2Econ_GetRarityDefinitionAddress(client);
	Test_TF2Econ_GetParticleAttributeAddress(client);
	Test_TF2Econ_GetPaintKitDefinitionAddress(client);

	char sSummaryFormat[] = LOG_PREFIX ... "Summary: Passed: %d/%d, Warnings: %d";
	char sSummary[sizeof(sSummaryFormat) + 32];
	FormatEx(sSummary, sizeof(sSummary), sSummaryFormat, g_iTestsPassed, g_iTestsTotal, g_iTestWarnings);

	if (client)
		LogToGame(sSummary);

	PrintToConsole(client, sSummary);
	return Plugin_Handled;
}

void Test_TF2Econ_IsItemInBaseSet(int client)
{
	char sTest[] = "TF2Econ_IsItemInBaseSet";
	LogTest(client, LogType_Start, sTest);

	if (TF2Econ_IsItemInBaseSet(g_iTestBaseItem))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_IsItemInBaseSet(%d) returned false, expected true.", g_iTestBaseItem);
}

void Test_TF2Econ_TranslateWeaponEntForClass(int client)
{
	char sTest[] = "TF2Econ_TranslateWeaponEntForClass";
	LogTest(client, LogType_Start, sTest);

	char sExpectedClassName[] = "tf_weapon_shotgun_pyro";
	char sClassName[sizeof(sExpectedClassName)] = "tf_weapon_shotgun";

	if (!TF2Econ_TranslateWeaponEntForClass(sClassName, sizeof(sClassName), TFClass_Pyro))
	{
		LogTest(client, LogType_Failed, "TF2Econ_TranslateWeaponEntForClass returned false.");
		return;
	}

	if (StrEqual(sClassName, sExpectedClassName))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_TranslateWeaponEntForClass returned '%s', expected '%s'.",
			sClassName, sExpectedClassName);
}

void Test_TF2Econ_TranslateLoadoutSlotIndexToName(int client)
{
	char sTest[] = "TF2Econ_TranslateLoadoutSlotIndexToName";
	LogTest(client, LogType_Start, sTest);

	char sExpectedSlotName[] = "secondary";
	char sSlotName[32];

	if (!TF2Econ_TranslateLoadoutSlotIndexToName(1, sSlotName, sizeof(sSlotName)))
	{
		LogTest(client, LogType_Failed, "TF2Econ_TranslateLoadoutSlotIndexToName returned false.");
		return;
	}

	if (StrEqual(sSlotName, sExpectedSlotName))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_TranslateLoadoutSlotIndexToName returned '%s', expected '%s'.",
			sSlotName, sExpectedSlotName);
}

void Test_TF2Econ_TranslateLoadoutSlotNameToIndex(int client)
{
	char sTest[] = "TF2Econ_TranslateLoadoutSlotNameToIndex";
	LogTest(client, LogType_Start, sTest);

	int iExpectedIndex = 1;
	int iIndex = TF2Econ_TranslateLoadoutSlotNameToIndex("secondary");

	if (iIndex == iExpectedIndex)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_TranslateLoadoutSlotNameToIndex returned %d, expected %d.",
			iIndex, iExpectedIndex);
}

void Test_TF2Econ_GetLoadoutSlotCount(int client)
{
	char sTest[] = "TF2Econ_GetLoadoutSlotCount";
	LogTest(client, LogType_Start, sTest);

	int iCount = TF2Econ_GetLoadoutSlotCount();

	if (iCount == TF2_LOADOUT_SLOT_COUNT)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetLoadoutSlotCount returned %d, expected %d.",
			iCount, TF2_LOADOUT_SLOT_COUNT);
}

void Test_TF2Econ_IsValidAttributeDefinition(int client)
{
	char sTest[] = "TF2Econ_IsValidAttributeDefinition";
	LogTest(client, LogType_Start, sTest);

	if (TF2Econ_IsValidAttributeDefinition(g_iTestAttribDefIndexInt))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_IsValidAttributeDefinition(%d) returned false, expected true.",
			g_iTestAttribDefIndexInt);
}

void Test_TF2Econ_IsAttributeHidden(int client)
{
	char sTest[] = "TF2Econ_IsAttributeHidden";
	LogTest(client, LogType_Start, sTest);

	if (TF2Econ_IsAttributeHidden(g_iTestAttribDefIndexInt))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_IsAttributeHidden(%d) returned false, expected true.",
			g_iTestAttribDefIndexInt);
}

void Test_TF2Econ_IsAttributeStoredAsInteger(int client)
{
	char sTest[] = "TF2Econ_IsAttributeStoredAsInteger";
	LogTest(client, LogType_Start, sTest);

	bool bIsIntegerInt = TF2Econ_IsAttributeStoredAsInteger(g_iTestAttribDefIndexInt);
	bool bIsIntegerFloat = TF2Econ_IsAttributeStoredAsInteger(g_iTestAttribDefIndexFloat);

	if (!bIsIntegerInt || bIsIntegerFloat)
	{
		if (!bIsIntegerInt)
			LogTest(client, LogType_Failed, "TF2Econ_IsAttributeStoredAsInteger(%d) returned false, expected true.",
				g_iTestAttribDefIndexInt);

		if (bIsIntegerFloat)
			LogTest(client, LogType_Failed, "TF2Econ_IsAttributeStoredAsInteger(%d) returned true, expected false.",
				g_iTestAttribDefIndexFloat);

		return;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Econ_GetAttributeName(int client)
{
	char sTest[] = "TF2Econ_GetAttributeName";
	LogTest(client, LogType_Start, sTest);

	char sName[sizeof(g_sTestAttribNameInt)];

	if (!TF2Econ_GetAttributeName(g_iTestAttribDefIndexInt, sName, sizeof(sName)))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeName(%d) returned false.", g_iTestAttribDefIndexInt);
		return;
	}

	if (StrEqual(sName, g_sTestAttribNameInt))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeName(%d) returned '%s', expected '%s'.",
			g_iTestAttribDefIndexInt, sName, g_sTestAttribNameInt);
}

void Test_TF2Econ_GetAttributeClassName(int client)
{
	char sTest[] = "TF2Econ_GetAttributeClassName";
	LogTest(client, LogType_Start, sTest);

	char sClassName[sizeof(g_sTestAttribClassInt)];

	if (!TF2Econ_GetAttributeClassName(g_iTestAttribDefIndexInt, sClassName, sizeof(sClassName)))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeClassName(%d) returned false.", g_iTestAttribDefIndexInt);
		return;
	}

	if (StrEqual(sClassName, g_sTestAttribClassInt))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeClassName(%d) returned '%s', expected '%s'.",
			g_iTestAttribDefIndexInt, sClassName, g_sTestAttribClassInt);
}

void Test_TF2Econ_GetAttributeDefinitionString(int client)
{
	char sTest[] = "TF2Econ_GetAttributeDefinitionString";
	LogTest(client, LogType_Start, sTest);

	char sExpectedValue[] = "1";
	char sDefault[] = " Yip!";
	char sValue[64];

	if (!TF2Econ_GetAttributeDefinitionString(g_iTestAttribDefIndexInt, "Invalid Key Test", sValue, sizeof(sValue), sDefault))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeDefinitionString(%d) returned false.", g_iTestAttribDefIndexInt);
		return;
	}

	if (!StrEqual(sValue, sDefault))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeDefinitionString(%d) for invalid key returned '%s', expected default '%s'.",
			g_iTestAttribDefIndexInt, sValue, sDefault);
		return;
	}

	TF2Econ_GetAttributeDefinitionString(g_iTestAttribDefIndexInt, "stored_as_integer", sValue, sizeof(sValue), sDefault);

	if (StrEqual(sValue, sExpectedValue))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeDefinitionString(%d) returned '%s', expected '%s'.",
			g_iTestAttribDefIndexInt, sValue, sExpectedValue);
}

void Test_TF2Econ_TranslateAttributeNameToDefinitionIndex(int client)
{
	char sTest[] = "TF2Econ_TranslateAttributeNameToDefinitionIndex";
	LogTest(client, LogType_Start, sTest);

	int iDefIndex = TF2Econ_TranslateAttributeNameToDefinitionIndex(g_sTestAttribNameInt);

	if (iDefIndex == g_iTestAttribDefIndexInt)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_TranslateAttributeNameToDefinitionIndex('%s') returned %d, expected %d.",
			g_sTestAttribNameInt, iDefIndex, g_iTestAttribDefIndexInt);
}

void Test_TF2Econ_GetAttributeList(int client)
{
	char sTest[] = "TF2Econ_GetAttributeList";
	LogTest(client, LogType_Start, sTest);

	ArrayList attrs = TF2Econ_GetAttributeList();

	if (!attrs)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeList returned null.");
		return;
	}

	int iNumAttr = attrs.Length;

	if (!iNumAttr)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeList returned empty list.");

		delete attrs;
		return;
	}

	LogTest(client, LogType_Info, "TF2Econ_GetAttributeList returned %d attributes.", iNumAttr);

	if (attrs.FindValue(g_iTestAttribDefIndexInt) == -1)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeList did not contain expected attribute def index %d.",
			g_iTestAttribDefIndexInt);

		delete attrs;
		return;
	}

	delete attrs;
	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Econ_GetQualityName(int client)
{
	char sTest[] = "TF2Econ_GetQualityName";
	LogTest(client, LogType_Start, sTest);

	char sExpectedName[] = "unique";
	char sName[sizeof(sExpectedName)];

	if (!TF2Econ_GetQualityName(TF2ItemQuality_Unique, sName, sizeof(sName)))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetQualityName(%d) returned false.", TF2ItemQuality_Unique);
		return;
	}

	if (StrEqual(sName, sExpectedName))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetQualityName(%d) returned '%s', expected '%s'.",
			TF2ItemQuality_Unique, sName, sExpectedName);
}

void Test_TF2Econ_TranslateQualityNameToValue(int client)
{
	char sTest[] = "TF2Econ_TranslateQualityNameToValue";
	LogTest(client, LogType_Start, sTest);

	char sQualityName[] = "unique";
	int iExpectedValue = TF2ItemQuality_Unique;
	int iValue = TF2Econ_TranslateQualityNameToValue(sQualityName);

	if (iValue == iExpectedValue)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_TranslateQualityNameToValue('%s') returned %d, expected %d.",
			sQualityName, iValue, iExpectedValue);
}

void Test_TF2Econ_GetQualityList(int client)
{
	char sTest[] = "TF2Econ_GetQualityList";
	LogTest(client, LogType_Start, sTest);

	ArrayList qualities = TF2Econ_GetQualityList();

	if (!qualities)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetQualityList returned null.");
		return;
	}

	int iNumQualities = qualities.Length;

	if (!iNumQualities)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetQualityList returned empty list.");

		delete qualities;
		return;
	}

	LogTest(client, LogType_Info, "TF2Econ_GetQualityList returned %d qualities.", iNumQualities);

	if (qualities.FindValue(TF2ItemQuality_Unique) == -1)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetQualityList did not contain expected quality %d.",
			TF2ItemQuality_Unique);

		delete qualities;
		return;
	}

	delete qualities;
	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Econ_GetRarityName(int client)
{
	char sTest[] = "TF2Econ_GetRarityName";
	LogTest(client, LogType_Start, sTest);

	char sExpectedName[] = "uncommon";
	char sName[64];

	if (!TF2Econ_GetRarityName(TF2ItemRarity_Uncommon, sName, sizeof(sName)))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetRarityName(%d) returned false.", TF2ItemRarity_Uncommon);
		return;
	}

	if (StrEqual(sName, sExpectedName))
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetRarityName(%d) returned '%s', expected '%s'.",
			TF2ItemRarity_Uncommon, sName, sExpectedName);
}

void Test_TF2Econ_TranslateRarityNameToValue(int client)
{
	char sTest[] = "TF2Econ_TranslateRarityNameToValue";
	LogTest(client, LogType_Start, sTest);

	char sRarityName[] = "uncommon";
	int iExpectedValue = TF2ItemRarity_Uncommon;
	int iValue = TF2Econ_TranslateRarityNameToValue(sRarityName);

	if (iValue == iExpectedValue)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_TranslateRarityNameToValue('%s') returned %d, expected %d.",
			sRarityName, iValue, iExpectedValue);
}

void Test_TF2Econ_GetRarityList(int client)
{
	char sTest[] = "TF2Econ_GetRarityList";
	LogTest(client, LogType_Start, sTest);

	ArrayList rarities = TF2Econ_GetRarityList();

	if (!rarities)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetRarityList returned null.");
		return;
	}

	int iNumRarities = rarities.Length;

	if (!iNumRarities)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetRarityList returned empty list.");

		delete rarities;
		return;
	}

	LogTest(client, LogType_Info, "TF2Econ_GetRarityList returned %d rarities.", iNumRarities);

	if (rarities.FindValue(TF2ItemRarity_Uncommon) == -1)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetRarityList did not contain expected rarity %d.",
			TF2ItemRarity_Uncommon);

		delete rarities;
		return;
	}

	delete rarities;
	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Econ_GetEquipRegionGroups(int client)
{
	char sTest[] = "TF2Econ_GetEquipRegionGroups";
	LogTest(client, LogType_Start, sTest);

	StringMap equipRegions = TF2Econ_GetEquipRegionGroups();

	if (!equipRegions)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetEquipRegionGroups returned null.");
		return;
	}

	int iNumRegions = equipRegions.Size;

	if (!iNumRegions)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetEquipRegionGroups returned empty map.");

		delete equipRegions;
		return;
	}

	LogTest(client, LogType_Info, "TF2Econ_GetEquipRegionGroups returned %d equip regions.", iNumRegions);

	char sRegion[] = "hat";

	if (!equipRegions.ContainsKey(sRegion))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetEquipRegionGroups did not contain expected equip region '%s'.", sRegion);

		delete equipRegions;
		return;
	}

	delete equipRegions;
	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Econ_GetEquipRegionMask(int client)
{
	char sTest[] = "TF2Econ_GetEquipRegionMask";
	LogTest(client, LogType_Start, sTest);

	char sRegion[] = "right_shoulder";
	TF2EquipRegion iExpectedMask = TF2EquipRegion_RightShoulder;
	TF2EquipRegion iMask;

	if (!TF2Econ_GetEquipRegionMask(sRegion, iMask))
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetEquipRegionMask('%s') returned false.", sRegion);
		return;
	}

	if (iMask == iExpectedMask)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetEquipRegionMask('%s') returned %d, expected %d.",
			sRegion, iMask, iExpectedMask);
}

void Test_TF2Econ_GetParticleAttributeList(int client)
{
	char sTest[] = "TF2Econ_GetParticleAttributeList";
	LogTest(client, LogType_Start, sTest);

	char sParticleSets[TFEconParticleSet][] =
	{
		"ParticleSet_All",
		"ParticleSet_CosmeticUnusualEffects",
		"ParticleSet_WeaponUnusualEffects",
		"ParticleSet_TauntUnusualEffects"
	};

	ArrayList particles;
	int iNumParticles;
	int iParticleIndex;
	int iNumPrint;
	char sParticleName[128];

	for (TFEconParticleSet i = ParticleSet_All; i < view_as<TFEconParticleSet>(sizeof(sParticleSets)); i++)
	{
		particles = TF2Econ_GetParticleAttributeList(i);

		if (!particles)
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetParticleAttributeList(%s) returned null.", sParticleSets[i]);
			return;
		}

		iNumParticles = particles.Length;

		if (!iNumParticles)
		{
			LogTest(client, LogType_Failed, "TF2Econ_GetParticleAttributeList(%s) returned empty list.", sParticleSets[i]);

			delete particles;
			return;
		}

		iNumPrint = iNumParticles < LOG_MAX_PRINT_PARTICLE_NAMES ? iNumParticles : LOG_MAX_PRINT_PARTICLE_NAMES;

		LogTest(client, LogType_Info, "TF2Econ_GetParticleAttributeList(%s) returned %d particles, printing first %d:",
			sParticleSets[i], iNumParticles, iNumPrint);

		for (int j = 0; j < iNumPrint; j++)
		{
			iParticleIndex = particles.Get(j);

			if (!TF2Econ_GetParticleAttributeSystemName(iParticleIndex, sParticleName, sizeof(sParticleName)))
			{
				LogTest(client, LogType_Failed, "TF2Econ_GetParticleAttributeSystemName(%d) returned false from %s", iParticleIndex, sParticleSets[i]);

				delete particles;
				return;
			}

			LogTest(client, LogType_Info, "%s %d: %d = %s", sParticleSets[i], j, iParticleIndex, sParticleName);
		}

		delete particles;
	}

	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Econ_GetPaintKitDefinitionList(int client)
{
	char sTest[] = "TF2Econ_GetPaintKitDefinitionList";
	LogTest(client, LogType_Start, sTest);

	ArrayList paintKits = TF2Econ_GetPaintKitDefinitionList();

	if (!paintKits)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetPaintKitDefinitionList returned null.");
		return;
	}

	int iNumPaintKits = paintKits.Length;

	if (!iNumPaintKits)
	{
		LogTest(client, LogType_Failed, "TF2Econ_GetPaintKitDefinitionList returned empty list.");

		delete paintKits;
		return;
	}

	int iNumPrint = iNumPaintKits < LOG_MAX_PRINT_PAINTKIT_INDEXES ? iNumPaintKits : LOG_MAX_PRINT_PAINTKIT_INDEXES;
	int iPaintKitIndex;

	LogTest(client, LogType_Info, "TF2Econ_GetPaintKitDefinitionList returned %d paint kits, printing first %d indexes:",
		iNumPaintKits, iNumPrint);

	for (int i = 0; i < iNumPrint; i++)
	{
		iPaintKitIndex = paintKits.Get(i);
		LogTest(client, LogType_Info, "Paint Kit %d: %d", i, iPaintKitIndex);
	}

	delete paintKits;
	LogTest(client, LogType_Passed, sTest);
}

void Test_TF2Econ_GetItemSchemaAddress(int client)
{
	char sTest[] = "TF2Econ_GetItemSchemaAddress";
	LogTest(client, LogType_Start, sTest);

	Address addr = TF2Econ_GetItemSchemaAddress();

	if (addr)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetItemSchemaAddress returned null.");
}

void Test_TF2Econ_GetProtoDefManagerAddress(int client)
{
	char sTest[] = "TF2Econ_GetProtoDefManagerAddress";
	LogTest(client, LogType_Start, sTest);

	Address addr = TF2Econ_GetProtoDefManagerAddress();

	if (addr)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetProtoDefManagerAddress returned null.");
}

void Test_TF2Econ_GetItemDefinitionAddress(int client)
{
	char sTest[] = "TF2Econ_GetItemDefinitionAddress";
	LogTest(client, LogType_Start, sTest);

	Address addr = TF2Econ_GetItemDefinitionAddress(g_TestItem.iDefIndex);

	if (addr)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetItemDefinitionAddress(%d) returned null.", g_TestItem.iDefIndex);
}

void Test_TF2Econ_GetAttributeDefinitionAddress(int client)
{
	char sTest[] = "TF2Econ_GetAttributeDefinitionAddress";
	LogTest(client, LogType_Start, sTest);

	Address addr = TF2Econ_GetAttributeDefinitionAddress(g_iTestAttribDefIndexInt);

	if (addr)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetAttributeDefinitionAddress(%d) returned null.", g_iTestAttribDefIndexInt);
}

void Test_TF2Econ_GetRarityDefinitionAddress(int client)
{
	char sTest[] = "TF2Econ_GetRarityDefinitionAddress";
	LogTest(client, LogType_Start, sTest);

	Address addr = TF2Econ_GetRarityDefinitionAddress(TF2ItemRarity_Unusual);

	if (addr)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetRarityDefinitionAddress(%d) returned null.", TF2ItemRarity_Unusual);
}

void Test_TF2Econ_GetParticleAttributeAddress(int client)
{
	char sTest[] = "TF2Econ_GetParticleAttributeAddress";
	LogTest(client, LogType_Start, sTest);

	int iTestParticleIndex = 4; //community_sparkle

	Address addr = TF2Econ_GetParticleAttributeAddress(iTestParticleIndex);

	if (addr)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetParticleAttributeAddress(%d) returned null.", iTestParticleIndex);
}

void Test_TF2Econ_GetPaintKitDefinitionAddress(int client)
{
	char sTest[] = "TF2Econ_GetPaintKitDefinitionAddress";
	LogTest(client, LogType_Start, sTest);

	int iTestPaintKitIndex = 102; // random choice

	Address addr = TF2Econ_GetPaintKitDefinitionAddress(iTestPaintKitIndex);

	if (addr)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetPaintKitDefinitionAddress(%d) returned null.", iTestPaintKitIndex);
}

void Test_TF2Econ_GetMapDefinitionIndexByName(int client)
{
	char sTest[] = "TF2Econ_GetMapDefinitionIndexByName";
	LogTest(client, LogType_Start, sTest);

	char sMapName[] = "ctf_2fort";
	int iExpectedDefIndex = 12; // items_game.txt: "name"		"ctf_2fort"
	int iDefIndex = TF2Econ_GetMapDefinitionIndexByName(sMapName);

	if (iDefIndex == iExpectedDefIndex)
		LogTest(client, LogType_Passed, sTest);
	else
		LogTest(client, LogType_Failed, "TF2Econ_GetMapDefinitionIndexByName('%s') returned %d, expected %d.",
			sMapName, iDefIndex, iExpectedDefIndex);
}

void LogTest(int client, LogType logType, const char[] sFormat, any ...)
{
	static const char sLogPrefix[LogType][] =
	{
		LOG_PREFIX_START,
		LOG_PREFIX_PASS,
		LOG_PREFIX_FAIL,
		LOG_PREFIX_WARN,
		LOG_PREFIX_INFO
	};

	static char sBuffer[256];
	VFormat(sBuffer, sizeof(sBuffer), sFormat, 4);

	if (client)
		LogToGame("%s%s", sLogPrefix[logType], sBuffer);

	PrintToConsole(client, "%s%s", sLogPrefix[logType], sBuffer);

	switch (logType)
	{
		case LogType_Start:
			++g_iTestsTotal;
		case LogType_Passed:
			++g_iTestsPassed;
		case LogType_Warn:
			++g_iTestWarnings;
	}
}