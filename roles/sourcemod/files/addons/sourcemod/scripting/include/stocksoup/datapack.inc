/**
 * A few stock functions to work with data packs.
 */

#if defined __stocksoup_datapack_included
	#endinput
#endif

#define __stocksoup_datapack_included

/**
 * Packs a client into a data pack with serial value conversion.
 */
stock void WritePackClient(DataPack pack, int client) {
	pack.WriteCell(GetClientSerial(client));
}

/**
 * Reads a client from a datapack with serial value conversion.
 */
stock int ReadPackClient(DataPack pack) {
	return GetClientFromSerial(pack.ReadCell());
}

/**
 * Packs an entity into a data pack with entity reference conversion.
 */
stock void WritePackEntity(DataPack pack, int entity) {
	pack.WriteCell(EntIndexToEntRef(entity));
}

/**
 * Reads an entity from a datapack with entity reference conversion.
 */
stock int ReadPackEntity(DataPack pack) {
	return EntRefToEntIndex(pack.ReadCell());
}

/**
 * Packs a fixed-size cell array into a data pack.
 */
stock void WritePackCellArray(DataPack pack, const any[] arr, int size) {
	for (int i = 0; i < size; i++) {
		pack.WriteCell(arr[i]);
	}
}

/**
 * Reads a fixed-size cell array from a data pack.
 */
stock void ReadPackCellArray(DataPack pack, any[] arr, int size) {
	for (int i = 0; i < size; i++) {
		arr[i] = pack.ReadCell();
	}
}

/**
 * Packs a fixed-size float array into a data pack.
 */
stock void WritePackFloatArray(DataPack pack, const float[] arr, int size) {
	for (int i = 0; i < size; i++) {
		pack.WriteFloat(arr[i]);
	}
}

/**
 * Reads a fixed-size float array from a data pack.
 */
stock void ReadPackFloatArray(DataPack pack, float[] arr, int size) {
	for (int i = 0; i < size; i++) {
		arr[i] = pack.ReadFloat();
	}
}

/**
 * Packs a vector (float[3]) into a data pack.
 */
stock void WritePackVector(DataPack pack, const float vec[3]) {
	WritePackFloatArray(pack, vec, sizeof(vec));
}

/**
 * Reads a vector (float[3]) from a data pack.
 */
stock void ReadPackVector(DataPack pack, float vec[3]) {
	ReadPackFloatArray(pack, vec, sizeof(vec));
}

/**
 * Packs a variable-length list of clients into a data pack.  Clients are added by their serial.
 */
stock void WritePackClientList(DataPack pack, const int[] clients, int nClients) {
	pack.WriteCell(nClients);
	for (int i = 0; i < nClients; i++) {
		WritePackClient(pack, clients[i]);
	}
}

/**
 * Reads a variable-length list of client indices from a data pack.  Any now-invalid clients are
 * discarded.
 * 
 * @return Number of valid clients.
 */
stock int ReadPackClientList(DataPack pack, int[] clients, int size) {
	int nPackedClients = pack.ReadCell(), nAvailableClients;
	for (int i = 0; i < nPackedClients; i++) {
		int client = ReadPackClient(pack);
		
		if (client) {
			clients[nAvailableClients++] = client;
		}
	}
	return nAvailableClients;
}
