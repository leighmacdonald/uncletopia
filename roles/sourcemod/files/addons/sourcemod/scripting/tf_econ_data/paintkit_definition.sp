Address offs_CProtoBufScriptObjectDefinitionManager_PaintList;

int Native_GetPaintKitList(Handle hPlugin, int nParams) {
	return MoveHandleImmediate(GetValidPaintKitProtoDefs(), hPlugin);
}

static ArrayList GetValidPaintKitProtoDefs() {
	ArrayList list = new ArrayList();
	
	int nPaintsAllocated = GetNumPaintKitsAllocated();
	for (int i; i < nPaintsAllocated; i++) {
		Address pPaintKitDefinition = GetPaintKitArrayEntry(i);
		if (!pPaintKitDefinition) {
			break;
		}
		
		int protoDefIndex = GetProtoDefIndex(pPaintKitDefinition);
		list.Push(protoDefIndex);
	}
	return list;
}

int Native_GetPaintKitDefinitionAddress(Handle hPlugin, int nParams) {
	int protoDefIndex = GetNativeCell(1);
	
	int nPaintsAllocated = GetNumPaintKitsAllocated();
	for (int i; i < nPaintsAllocated; i++) {
		Address pPaintKitDefinition = GetPaintKitArrayEntry(i);
		if (!pPaintKitDefinition) {
			return view_as<int>(Address_Null);
		}
		
		if (protoDefIndex == GetProtoDefIndex(pPaintKitDefinition)) {
			return view_as<int>(pPaintKitDefinition);
		}
	}
	return view_as<int>(Address_Null);
}

/**
 * Returns address of a CPaintKitDefinition within the CProtoDefMgr's list, or nullptr if
 * invalid.
 */
static Address GetPaintKitArrayEntry(int index) {
	Address pPaintKitData = DereferencePointer(GetProtoScriptObjDefManager()
			+ offs_CProtoBufScriptObjectDefinitionManager_PaintList);
	
	// array is some sort of struct size 0x10, CPaintKitDefinition* is at offset 0x0C
	Address pPaintKitEntry = pPaintKitData + view_as<Address>(index * 0x10);
	
	// tested in GetValidPaintKits() to be non-zero
	int unknown = LoadFromAddress(pPaintKitEntry, NumberType_Int32);
	if (!unknown) {
		return Address_Null;
	}
	
	return DereferencePointer(pPaintKitEntry + view_as<Address>(0x0C));
}

static int GetNumPaintKitsAllocated() {
	// offset after GetProtoScriptObjDefManager() in CTFItemDefinition::GetValidPaintkits()
	return LoadFromAddress(GetProtoScriptObjDefManager()
			+ offs_CProtoBufScriptObjectDefinitionManager_PaintList 
			+ view_as<Address>(0xE), NumberType_Int16);
}
