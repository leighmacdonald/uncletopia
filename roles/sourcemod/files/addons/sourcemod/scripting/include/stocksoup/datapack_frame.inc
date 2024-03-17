#if defined __stocksoup_datapack_frame_included
	#endinput
#endif

#define __stocksoup_datapack_frame_included

typedef RequestDataFrameCallback = function void (DataPack data);

/**
 * Creates a single-use next frame hook associated with a new datapack, and stores the datapack
 * in the by-ref parameter.
 * 
 * @note Unlike CreateDataTimer, the datapack is *not* automatically freed when the timer ends.
 */
stock void RequestDataFrame(RequestDataFrameCallback callback, DataPack &data) {
	data = CreateDataPack();
	
	// is this even intended
	RequestFrame(view_as<RequestFrameCallback>(callback), data);
}