/**
 * [TF2] Econ Data
 * 
 * Functions to read item information from game memory.
 */
#pragma semicolon 1
#include <sourcemod>

#include <sdktools>

#pragma newdecls required

#include <stocksoup/handles>
#include <stocksoup/memory>

#define PLUGIN_VERSION "0.19.1"
public Plugin myinfo = {
	name = "[TF2] Econ Data",
	author = "nosoop",
	description = "A library to read item data straight from the game's memory.",
	version = PLUGIN_VERSION,
	url = "https://github.com/nosoop/SM-TFEconData"
}

Address offs_CEconItemSchema_ItemQualities,
		offs_CEconItemSchema_ItemList,
		offs_CEconItemSchema_nItemCount,
		offs_CEconItemSchema_AttributeMap;

#define ATTRDEF_MAP_OFFSET (view_as<Address>(0x14))
Address sizeof_CEconItemAttributeDefinition;

#include "tf_econ_data/attached_particle_systems.sp"
#include "tf_econ_data/loadout_slot.sp"
#include "tf_econ_data/item_definition.sp"
#include "tf_econ_data/equip_regions.sp"
#include "tf_econ_data/attribute_definition.sp"
#include "tf_econ_data/paintkit_definition.sp"
#include "tf_econ_data/quality_definition.sp"
#include "tf_econ_data/rarity_definition.sp"
#include "tf_econ_data/map_definition.sp"
#include "tf_econ_data/keyvalues.sp"

#define TF_ITEMDEF_DEFAULT -1

Handle g_SDKCallGetEconItemSchema;
Handle g_SDKCallSchemaGetItemDefinition;
Handle g_SDKCallSchemaGetAttributeDefinition;
Handle g_SDKCallSchemaGetAttributeDefinitionByName;
Handle g_SDKCallTranslateWeaponEntForClass;
Handle g_SDKCallGetProtoDefManager;
Handle g_SDKCallGetProtoDefIndex;
Handle g_SDKCallGetMasterMapDefByName;

public APLRes AskPluginLoad2(Handle self, bool late, char[] error, int maxlen) {
	RegPluginLibrary("tf_econ_data");
	
	// item information
	CreateNative("TF2Econ_IsValidItemDefinition", Native_IsValidItemDefinition);
	CreateNative("TF2Econ_IsItemInBaseSet", Native_IsItemInBaseSet);
	CreateNative("TF2Econ_GetItemName", Native_GetItemName);
	CreateNative("TF2Econ_GetLocalizedItemName", Native_GetLocalizedItemName);
	CreateNative("TF2Econ_GetItemClassName", Native_GetItemClassName);
	CreateNative("TF2Econ_GetItemLoadoutSlot", Native_GetItemSlot);
	CreateNative("TF2Econ_GetItemDefaultLoadoutSlot", Native_GetItemDefaultSlot);
	CreateNative("TF2Econ_GetItemEquipRegionMask", Native_GetItemEquipRegionMask);
	CreateNative("TF2Econ_GetItemEquipRegionGroupBits", Native_GetItemEquipRegionGroupBits);
	CreateNative("TF2Econ_GetItemLevelRange", Native_GetItemLevelRange);
	CreateNative("TF2Econ_GetItemQuality", Native_GetItemQuality);
	CreateNative("TF2Econ_GetItemRarity", Native_GetItemRarity);
	CreateNative("TF2Econ_GetItemStaticAttributes", Native_GetItemStaticAttributes);
	CreateNative("TF2Econ_GetItemDefinitionString", Native_GetItemDefinitionString);
	
	// global items
	CreateNative("TF2Econ_GetItemList", Native_GetItemList);
	
	// other useful functions for items
	CreateNative("TF2Econ_TranslateWeaponEntForClass", Native_TranslateWeaponEntForClass);
	
	// loadout slot information
	CreateNative("TF2Econ_TranslateLoadoutSlotNameToIndex",
			Native_TranslateLoadoutSlotNameToIndex);
	CreateNative("TF2Econ_TranslateLoadoutSlotIndexToName",
			Native_TranslateLoadoutSlotIndexToName);
	CreateNative("TF2Econ_GetLoadoutSlotCount", Native_GetLoadoutSlotCount);
	
	// attribute information
	CreateNative("TF2Econ_IsValidAttributeDefinition", Native_IsValidAttributeDefinition);
	CreateNative("TF2Econ_IsAttributeHidden", Native_IsAttributeHidden);
	CreateNative("TF2Econ_IsAttributeStoredAsInteger", Native_IsAttributeStoredAsInteger);
	CreateNative("TF2Econ_GetAttributeName", Native_GetAttributeName);
	CreateNative("TF2Econ_GetAttributeClassName", Native_GetAttributeClassName);
	CreateNative("TF2Econ_GetAttributeDefinitionString", Native_GetAttributeDefinitionString);
	CreateNative("TF2Econ_TranslateAttributeNameToDefinitionIndex",
			Native_TranslateAttributeNameToDefinitionIndex);
	
	// global attributes
	CreateNative("TF2Econ_GetAttributeList", Native_GetAttributeList);
	
	// quality information
	CreateNative("TF2Econ_GetQualityName", Native_GetQualityName);
	CreateNative("TF2Econ_TranslateQualityNameToValue", Native_TranslateQualityNameToValue);
	CreateNative("TF2Econ_GetQualityList", Native_GetQualityList);
	
	// rarity information
	CreateNative("TF2Econ_GetRarityName", Native_GetRarityName);
	CreateNative("TF2Econ_TranslateRarityNameToValue", Native_TranslateRarityNameToValue);
	CreateNative("TF2Econ_GetRarityList", Native_GetRarityList);
	
	// equip region information
	CreateNative("TF2Econ_GetEquipRegionGroups", Native_GetEquipRegionGroups);
	CreateNative("TF2Econ_GetEquipRegionMask", Native_GetEquipRegionMask);
	
	// particle attribute information
	CreateNative("TF2Econ_GetParticleAttributeSystemName",
			Native_GetParticleAttributeSystemName);
	CreateNative("TF2Econ_GetParticleAttributeList", Native_GetParticleAttributeList);
	
	// paintkit / weapon skin information
	CreateNative("TF2Econ_GetPaintKitDefinitionList", Native_GetPaintKitList);

	// map information
	CreateNative("TF2Econ_GetMapDefinitionIndexByName", Native_GetMapDefinitionIndex);
	
	// low-level stuff
	CreateNative("TF2Econ_GetItemSchemaAddress", Native_GetItemSchemaAddress);
	CreateNative("TF2Econ_GetProtoDefManagerAddress", Native_GetProtoDefManagerAddress);
	CreateNative("TF2Econ_GetItemDefinitionAddress", Native_GetItemDefinitionAddress);
	CreateNative("TF2Econ_GetAttributeDefinitionAddress", Native_GetAttributeDefinitionAddress);
	CreateNative("TF2Econ_GetRarityDefinitionAddress", Native_GetRarityDefinitionAddress);
	CreateNative("TF2Econ_GetParticleAttributeAddress", Native_GetParticleAttributeAddress);
	CreateNative("TF2Econ_GetPaintKitDefinitionAddress", Native_GetPaintKitDefinitionAddress);
	
	// backwards-compatibile
	CreateNative("TF2Econ_IsValidDefinitionIndex", Native_IsValidItemDefinition);
	CreateNative("TF2Econ_GetItemSlot", Native_GetItemSlot);
	
	return APLRes_Success;
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.econ_data");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.econ_data).");
	}
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GEconItemSchema()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetEconItemSchema = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CEconItemSchema::GetItemDefinition()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallSchemaGetItemDefinition = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CEconItemSchema::GetAttributeDefinition()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallSchemaGetAttributeDefinition = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CEconItemSchema::GetAttributeDefinitionByName()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_SDKCallSchemaGetAttributeDefinitionByName = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"CTFItemSchema::GetMasterMapDefByName()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	g_SDKCallGetMasterMapDefByName = EndPrepSDKCall();

	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TranslateWeaponEntForClass()");
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallTranslateWeaponEntForClass = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "KeyValues::GetString()");
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetKeyValuesString = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "KeyValues::FindKey()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	g_SDKCallGetKeyValuesFindKey = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Static);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "GetProtoScriptObjDefManager()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetProtoDefManager = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Raw);
	PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature,
			"IProtoBufScriptObjectDefinition::GetDefIndex()");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	g_SDKCallGetProtoDefIndex = EndPrepSDKCall();

	offs_CEconItemDefinition_pKeyValues =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pKeyValues");
	offs_CEconItemDefinition_u8MinLevel =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_u8MinLevel");
	offs_CEconItemDefinition_u8MaxLevel =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_u8MaxLevel");
	offs_CEconItemDefinition_u8ItemQuality =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_u8ItemQuality");
	offs_CEconItemDefinition_si8ItemRarity =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_si8ItemRarity");
	offs_CEconItemDefinition_AttributeList =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_AttributeList");
	offs_CEconItemDefinition_pszLocalizedItemName =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pszLocalizedItemName");
	offs_CEconItemDefinition_pszItemClassname =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pszItemClassname");
	offs_CEconItemDefinition_pszItemName =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_pszItemName");
	offs_CEconItemDefinition_bBaseItem =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_bBaseItem");
	offs_CEconItemDefinition_bitsEquipRegionGroups =
			GameConfGetAddressOffset(hGameConf, "CEconItemDefinition::m_bitsEquipRegionGroups");
	offs_CEconItemDefinition_bitsEquipRegionConflicts =
			GameConfGetAddressOffset(hGameConf,
			"CEconItemDefinition::m_bitsEquipRegionConflicts");
	
	offs_CTFItemDefinition_iDefaultItemSlot =
			GameConfGetAddressOffset(hGameConf, "CTFItemDefinition::m_iDefaultItemSlot");
	offs_CEconItemDefinition_aiItemSlot =
			GameConfGetAddressOffset(hGameConf, "CTFItemDefinition::m_aiItemSlot");
	
	offs_CEconItemSchema_ItemRarities =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_ItemRarities");
	offs_CEconItemSchema_iLastValidRarity =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_iLastValidRarity");
	offs_CEconItemSchema_ItemQualities =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_ItemQualities");
	offs_CEconItemSchema_ItemList =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_ItemList");
	offs_CEconItemSchema_nItemCount =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_nItemCount");
	offs_CEconItemSchema_AttributeMap =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_AttributeMap");
	offs_CEconItemSchema_EquipRegions =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_EquipRegions");
	offs_CEconItemSchema_ParticleSystemTree =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_ParticleSystemTree");
	
	offs_CEconItemSchema_CosmeticUnusualEffectList =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_CosmeticUnusualEffectList");
	offs_CEconItemSchema_WeaponUnusualEffectList =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_WeaponUnusualEffectList");
	offs_CEconItemSchema_TauntUnusualEffectList =
			GameConfGetAddressOffset(hGameConf, "CEconItemSchema::m_TauntUnusualEffectList");
	
	offs_CTFItemSchema_ItemSlotNames =
			GameConfGetAddressOffset(hGameConf, "CTFItemSchema::m_ItemSlotNames");
	
	offs_CEconItemAttributeDefinition_pKeyValues =
			GameConfGetAddressOffset(hGameConf, "CEconItemAttributeDefinition::m_pKeyValues");
	offs_CEconItemAttributeDefinition_iAttributeDefinitionIndex =
			GameConfGetAddressOffset(hGameConf,
			"CEconItemAttributeDefinition::m_iAttributeDefinitionIndex");
	offs_CEconItemAttributeDefinition_bHidden =
			GameConfGetAddressOffset(hGameConf, "CEconItemAttributeDefinition::m_bHidden");
	offs_CEconItemAttributeDefinition_bIsInteger =
			GameConfGetAddressOffset(hGameConf, "CEconItemAttributeDefinition::m_bIsInteger");
	offs_CEconItemAttributeDefinition_pszAttributeName =
			GameConfGetAddressOffset(hGameConf,
			"CEconItemAttributeDefinition::m_pszAttributeName");
	offs_CEconItemAttributeDefinition_pszAttributeClass =
			GameConfGetAddressOffset(hGameConf,
			"CEconItemAttributeDefinition::m_pszAttributeClass");
	
	offs_CEconItemQualityDefinition_iValue =
			GameConfGetAddressOffset(hGameConf, "CEconItemQualityDefinition::m_iValue");
	offs_CEconItemQualityDefinition_pszName =
			GameConfGetAddressOffset(hGameConf, "CEconItemQualityDefinition::m_pszName");
	
	offs_CEconItemRarityDefinition_iValue =
			GameConfGetAddressOffset(hGameConf, "CEconItemRarityDefinition::m_iValue");
	offs_CEconItemRarityDefinition_pszName =
			GameConfGetAddressOffset(hGameConf, "CEconItemRarityDefinition::m_pszName");
	
	offs_attachedparticlesystem_pszParticleSystem =
			GameConfGetAddressOffset(hGameConf,
			"attachedparticlesystem_t::m_pszParticleSystem");
	offs_attachedparticlesystem_iAttributeValue =
			GameConfGetAddressOffset(hGameConf,
			"attachedparticlesystem_t::m_iAttributeValue");
	
	offs_CProtoBufScriptObjectDefinitionManager_PaintList =
			GameConfGetAddressOffset(hGameConf,
			"CProtoBufScriptObjectDefinitionManager::m_PaintList");
	
	sizeof_static_attrib_t = GameConfGetAddressOffset(hGameConf, "sizeof(static_attrib_t)");
	sizeof_CEconItemAttributeDefinition = GameConfGetAddressOffset(hGameConf,
			"sizeof(CEconItemAttributeDefinition)");
	
	delete hGameConf;
	
	CreateConVar("tfecondata_version", PLUGIN_VERSION,
			"Version for TF2 Econ Data, to gauge popularity.", FCVAR_NOTIFY);
}

int Native_TranslateWeaponEntForClass(Handle hPlugin, int nParams) {
	char weaponClass[64];
	GetNativeString(1, weaponClass, sizeof(weaponClass));
	int maxlen = GetNativeCell(2);
	int playerClass = GetNativeCell(3);
	
	if (TranslateWeaponEntForClass(weaponClass, maxlen, playerClass)) {
		SetNativeString(1, weaponClass, maxlen, true);
		return true;
	}
	return false;
}

int Native_GetItemList(Handle hPlugin, int nParams) {
	Function func = GetNativeFunction(1);
	any data = GetNativeCell(2);
	
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return 0;
	}
	
	ArrayList itemList = new ArrayList();
	
	// CEconItemSchema.field_0xE8 is a CUtlVector of some struct size 0x0C
	// (int defindex, CEconItemDefinition*, int m_Unknown)
	
	int nItemDefs = LoadFromAddress(pSchema + offs_CEconItemSchema_nItemCount,
			NumberType_Int32);
	for (int i = 0; i < nItemDefs; i++) {
		Address entry = DereferencePointer(pSchema + offs_CEconItemSchema_ItemList)
				+ view_as<Address>(i * 0x0C);
		
		// I have no idea how this check works but it's also in
		// CEconItemSchema::GetItemDefinitionByName
		if (LoadFromAddress(entry + view_as<Address>(0x08), NumberType_Int32) < -1) {
			continue;
		}
		
		int defindex = LoadFromAddress(entry, NumberType_Int32);
		
		if (func == INVALID_FUNCTION) {
			itemList.Push(defindex);
			continue;
		}
		
		bool result;
		Call_StartFunction(hPlugin, func);
		Call_PushCell(defindex);
		Call_PushCell(data);
		Call_Finish(result);
		
		if (result) {
			itemList.Push(defindex);
		}
	}
	
	return MoveHandle(itemList, hPlugin);
}

int Native_GetAttributeList(Handle hPlugin, int nParams) {
	Function func = GetNativeFunction(1);
	any data = GetNativeCell(2);
	
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return 0;
	}
	
	ArrayList attributeList = new ArrayList();
	
	// this implements FOR_EACH_MAP_FAST
	int nAttributeCapacity = LoadFromAddress(
			pSchema + offs_CEconItemSchema_AttributeMap + view_as<Address>(0x4),
			NumberType_Int32);
	
	Address pAttributeData = DereferencePointer(pSchema + offs_CEconItemSchema_AttributeMap);
	for (int i; i < nAttributeCapacity; i++) {
		Address pAttributeDataItem = pAttributeData
				+ view_as<Address>(i) * (sizeof_CEconItemAttributeDefinition + ATTRDEF_MAP_OFFSET);
		
		// the struct has 0x14 bytes (ATTRDEF_MAP_OFFSET) preceding the definition
		// some internal map data
		int index = LoadFromAddress(pAttributeDataItem, NumberType_Int32);
		if (index == i) {
			continue;
		}
		
		Address pAttributeDefinition = pAttributeDataItem + ATTRDEF_MAP_OFFSET;
		int attrdef = LoadFromAddress(
				pAttributeDefinition + offs_CEconItemAttributeDefinition_iAttributeDefinitionIndex,
				NumberType_Int16);
		if (!attrdef) {
			continue;
		}
		
		if (func == INVALID_FUNCTION) {
			attributeList.Push(attrdef);
			continue;
		}
		
		bool result;
		Call_StartFunction(hPlugin, func);
		Call_PushCell(attrdef);
		Call_PushCell(data);
		Call_Finish(result);
		
		if (result) {
			attributeList.Push(attrdef);
		}
	}
	
	return MoveHandle(attributeList, hPlugin);
}

int Native_GetItemSchemaAddress(Handle hPlugin, int nParams) {
	return view_as<int>(GetEconItemSchema());
}

int Native_GetItemDefinitionAddress(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	return view_as<int>(GetEconItemDefinition(defindex));
}

bool ValidItemDefIndex(int defindex) {
	// special case: return false on TF_ITEMDEF_DEFAULT
	return defindex != TF_ITEMDEF_DEFAULT && !!GetEconItemDefinition(defindex);
}

Address GetEconItemDefinition(int defindex) {
	Address pSchema = GetEconItemSchema();
	if (!pSchema) {
		return Address_Null;
	}
	
	Address pItemDefinition = SDKCall(g_SDKCallSchemaGetItemDefinition, pSchema, defindex);
	
	// special case: return default item definition on TF_ITEMDEF_DEFAULT (-1)
	// otherwise return a valid definition iff not the default
	if (defindex == TF_ITEMDEF_DEFAULT || pItemDefinition != GetEconDefaultItemDefinition()) {
		return pItemDefinition;
	}
	return Address_Null;
}

static Address GetEconDefaultItemDefinition() {
	return GetEconItemDefinition(TF_ITEMDEF_DEFAULT);
}

int Native_GetAttributeDefinitionAddress(Handle hPlugin, int nParams) {
	int defindex = GetNativeCell(1);
	return view_as<int>(GetEconAttributeDefinition(defindex));
}

Address GetEconAttributeDefinition(int defindex) {
	Address pSchema = GetEconItemSchema();
	return pSchema?
			SDKCall(g_SDKCallSchemaGetAttributeDefinition, pSchema, defindex) : Address_Null;
}

int Native_TranslateAttributeNameToDefinitionIndex(Handle hPlugin, int nParams) {
	int maxlen;
	GetNativeStringLength(1, maxlen);
	maxlen++;
	char[] attrName = new char[maxlen];
	GetNativeString(1, attrName, maxlen);
	
	Address pAttribute = GetEconAttributeDefinitionByName(attrName);
	if (pAttribute) {
		Address pOffs =
				pAttribute + offs_CEconItemAttributeDefinition_iAttributeDefinitionIndex;
		return LoadFromAddress(pOffs, NumberType_Int16);
	}
	return -1;
}

Address GetEconAttributeDefinitionByName(const char[] name) {
	Address pSchema = GetEconItemSchema();
	return pSchema?
			SDKCall(g_SDKCallSchemaGetAttributeDefinitionByName, pSchema, name) : Address_Null;
}

Address GetMapDefinitionByName(const char[] name) {
	Address pSchema = GetEconItemSchema();
	return pSchema?
			SDKCall(g_SDKCallGetMasterMapDefByName, pSchema, name) : Address_Null;
}

Address GetEconItemSchema() {
	return SDKCall(g_SDKCallGetEconItemSchema);
}

Address GetProtoScriptObjDefManager() {
	return SDKCall(g_SDKCallGetProtoDefManager);
}

int Native_GetProtoDefManagerAddress(Handle hPlugin, int nParams) {
	return view_as<int>(GetProtoScriptObjDefManager());
}

int GetProtoDefIndex(Address pProtoDefinition) {
	return SDKCall(g_SDKCallGetProtoDefIndex, pProtoDefinition);
}

static bool TranslateWeaponEntForClass(char[] buffer, int maxlen, int playerClass) {
	return SDKCall(g_SDKCallTranslateWeaponEntForClass, buffer, maxlen, buffer, playerClass) > 0;
}

static Address GameConfGetAddressOffset(Handle gamedata, const char[] key) {
	Address offs = view_as<Address>(GameConfGetOffset(gamedata, key));
	if (offs == view_as<Address>(-1)) {
		SetFailState("Failed to get member offset %s", key);
	}
	return offs;
}
