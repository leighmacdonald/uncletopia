/*
AnyHttp
By F2


Features:
- Download the response of a GET request to memory
- Download the response of a POST request (multipart data) to memory  

Public functions:
- bool AnyHttp.Init(): Returns false if no HTTP extension is loaded 
- void AnyHttp.Require(): Calls ThrowError if no HTTP extension is loaded
- void AnyHttp.Get(const char[] url, AnyHttp_Result callback, int metadata = 0)
- AnyHttpForm form = AnyHttp.CreatePost(const char[] url)
- form.PutFile(const char[] name, const char[] filepath)
- form.PutString(const char[] name, const char[] value)
- form.Send(AnyHttp_Result callback)

Callbacks:
- AnyHttp_Result: public void HttpRequestDone(bool success, const char[] contents, int metadata) { }


TODO:
- Expose functions that can download to a file
*/

#if defined _anyhttp_included
 #endinput
#endif
#define _anyhttp_included

#if defined REQUIRE_EXTENSIONS
	#define ANYHTTP_REQUIRE_EXTENSIONS
#endif

#undef REQUIRE_EXTENSIONS
#include <cURL>
#include <steamtools>
#include <SteamWorks>
#if defined ANYHTTP_REQUIRE_EXTENSIONS
	#define REQUIRE_EXTENSIONS
#endif

#include <kvizzle>

#define ANYHTTP_VERSION		"1.1.0"

#pragma dynamic 20971520 // Make sure we can allocate enough space for uploading files. Here's 20MB.

enum AnyHttp_Extension {
	AnyHttpUnknown,
	UseCURL,
	UseSteamTools,
	UseSteamWorks,
};


//typedef AnyHttp_Result = function void (bool success, const char[] contents);
typedef AnyHttp_Result = function void (bool success, const char[] contents, int httpCode, int metadata);


methodmap AnyHttpForm < Handle {
	public AnyHttpForm(const char[] url) {
		return AnyHttp_CreatePostForm(url);
	}
	
	public void PutFile(const char[] name, const char[] filepath) {
		AnyHttp_PutFile(this, name, filepath);
	}
	
	public void PutString(const char[] name, const char[] value) {
		AnyHttp_PutString(this, name, value);
	}
	
	public bool Send(AnyHttp_Result callback) {
		return AnyHttp_SendPostForm(this, callback);
	}
};

AnyHttp_Extension AnyHttp_CurrentExtension = AnyHttpUnknown;

methodmap AnyHttpClass {
	public bool Init() {
		return AnyHttp_Initialize();
	}
	
	public void Require() {
		if (!AnyHttp_Initialize())
			ThrowError("Missing HTTP extension");
	}
	
	public bool Get(const char[] url, AnyHttp_Result callback, int metadata = 0) {
		return AnyHttp_Get(url, callback, metadata);
	}
	
	public AnyHttpForm CreatePost(const char[] url) {
		return AnyHttp_CreatePostForm(url);
	}
	
	property AnyHttp_Extension Extension {
		public get() { return AnyHttp_CurrentExtension; }
		public set(AnyHttp_Extension value) { AnyHttp_CurrentExtension = value; }
	}
};
stock AnyHttpClass AnyHttp;

Handle AnyHttp_kvData = null;
AnyHttp_Result AnyHttp_callbacks[64];
bool AnyHttp_hasCallback[64];
float AnyHttp_callbacks_time[sizeof(AnyHttp_callbacks)];


bool AnyHttp_isInitialized = false;

char AnyHttp_MultiPartBoundary[] = "--------------------AnyHttp--AnyHttp--h7doWqx7m--";


// Public functions

stock bool AnyHttp_Initialize() {
	if (AnyHttp_isInitialized)
		return true;
	
	if (AnyHttp_kvData == INVALID_HANDLE) {
		AnyHttp_kvData = KvizCreate("Data");
	}
	
	if (AnyHttp_CurrentExtension == AnyHttpUnknown) {
		if (LibraryExists("SteamWorks")) {
			AnyHttp_CurrentExtension = UseSteamWorks;
		} else if (GetFeatureStatus(FeatureType_Native, "curl_easy_init") == FeatureStatus_Available) {
			AnyHttp_CurrentExtension = UseCURL;
		} else if (LibraryExists("SteamTools")) {
			AnyHttp_CurrentExtension = UseSteamTools;
		} else
			return false;
	}
	
	for (int i = 0; i < sizeof(AnyHttp_callbacks); i++) {
		AnyHttp_hasCallback[i] = false;
	}
	
	AnyHttp_isInitialized = true;
	return true;
}

stock bool AnyHttp_Get(const char[] url, AnyHttp_Result:callback, int metadata = 0) {
	if (!AnyHttp_Initialize())
		return false;
	
	if (AnyHttp_CurrentExtension == UseSteamWorks) {
		return AnyHttp_SteamWorks_Get(url, callback, metadata);
	} else if (AnyHttp_CurrentExtension == UseCURL) {
		return AnyHttp_cURL_Get(url, callback, metadata);
	} else if (AnyHttp_CurrentExtension == UseSteamTools) {
		return AnyHttp_SteamTools_Get(url, callback, metadata);
	} else {
		ThrowError("Unknown extension");
		return false; // Avoid compiler warning
	}
}

stock AnyHttpForm AnyHttp_CreatePostForm(const char[] url) {
	if (!AnyHttp_Initialize())
		return null;
	
	if (AnyHttp_CurrentExtension == UseSteamWorks) {
		return view_as<AnyHttpForm>(AnyHttp_SteamWorks_CreatePostForm(url));
	} else if (AnyHttp_CurrentExtension == UseCURL) {
		return view_as<AnyHttpForm>(AnyHttp_cURL_CreatePostForm(url));
	} else if (AnyHttp_CurrentExtension == UseSteamTools) {
		return view_as<AnyHttpForm>(AnyHttp_SteamTools_CreatePostForm(url));
	} else {
		ThrowError("Unknown extension");
		return null; // Avoid compiler warning
	}
}

stock void AnyHttp_PutString(AnyHttpForm handle, const char[] name, const char[] value) {
	if (handle == null)
		ThrowError("Invalid handle");
	
	int id = KvizGetNum(AnyHttp_kvData, 0, "%i.fields:count", _:handle) + 1;
	KvizSetString(AnyHttp_kvData, name, "%i.fields.%i.name", _:handle, id);
	KvizSetString(AnyHttp_kvData, "string", "%i.fields.%i.type", _:handle, id);
	KvizSetString(AnyHttp_kvData, value, "%i.fields.%i.value", _:handle, id);
}

stock void AnyHttp_PutFile(AnyHttpForm handle, const char[] name, const char[] filepath) {
	if (handle == null)
		ThrowError("Invalid handle");
	
	int id = KvizGetNum(AnyHttp_kvData, 0, "%i.fields:count", _:handle) + 1;
	KvizSetString(AnyHttp_kvData, name, "%i.fields.%i.name", _:handle, id);
	KvizSetString(AnyHttp_kvData, "file", "%i.fields.%i.type", _:handle, id);
	KvizSetString(AnyHttp_kvData, filepath, "%i.fields.%i.value", _:handle, id);
}

stock bool AnyHttp_SendPostForm(AnyHttpForm handle, AnyHttp_Result callback) {
	if (handle == null)
		ThrowError("Invalid handle");
	
	if (AnyHttp_CurrentExtension == UseSteamWorks) {
		return AnyHttp_SteamWorks_SendPostForm(handle, callback);
	} else if (AnyHttp_CurrentExtension == UseCURL) {
		return AnyHttp_cURL_SendPostForm(handle, callback);
	} else if (AnyHttp_CurrentExtension == UseSteamTools) {
		return AnyHttp_SteamTools_SendPostForm(handle, callback);
	} else {
		ThrowError("Unknown extension");
		return false; // Avoid compiler warning
	}
}



// Common private functions

stock void AnyHttp_CleanUp(Handle handle) {
	int callbackID;
	if (KvizGetNumExact(AnyHttp_kvData, callbackID, "%i.callback", _:handle)) {
		AnyHttp_RetrieveCallback(callbackID);
	}
	int filehandle_num;
	if (KvizGetNumExact(AnyHttp_kvData, filehandle_num, "%i.filehandle", _:handle)) {
		CloseHandle(view_as<File>(filehandle_num));
	}
	KvizDelete(AnyHttp_kvData, "%i", _:handle);
	if (AnyHttp_CurrentExtension == UseSteamWorks)
		CloseHandle(handle);
	else if (AnyHttp_CurrentExtension == UseCURL)
		CloseHandle(handle);
	else if (AnyHttp_CurrentExtension == UseSteamTools)
		Steam_ReleaseHTTPRequest(view_as<HTTPRequestHandle>(handle));
}


stock int AnyHttp_StoreCallback(AnyHttp_Result callback) {
	int minimumID = 0;
	for (int i = 0; i < sizeof(AnyHttp_callbacks); i++) {
		if (AnyHttp_hasCallback[i] == false) {
			AnyHttp_callbacks[i] = callback;
			AnyHttp_callbacks_time[i] = GetTickedTime();
			AnyHttp_hasCallback[i] = true;
			return i;
		} else {
			if (AnyHttp_callbacks_time[i] < AnyHttp_callbacks_time[minimumID])
				minimumID = i;
		}
	}
	
	// There are no free spots. Remove the oldest one.
	LogError("No callback storage");
	int handle_num;
	if (!KvizGetNumExact(AnyHttp_kvData, handle_num, ":any-child.callback:has-value(%i):parent:section-name", minimumID))
		ThrowError("Could not find handle");
	
	AnyHttp_CleanUp(view_as<Handle>(handle_num));
	
	AnyHttp_callbacks[minimumID] = callback;
	AnyHttp_callbacks_time[minimumID] = GetTickedTime();
	AnyHttp_hasCallback[minimumID] = true;
	
	return minimumID;
}

stock AnyHttp_Result AnyHttp_RetrieveCallback(int id) {
	if (!AnyHttp_hasCallback[id])
		ThrowError("AnyHttp: Could not find callback");
	
	AnyHttp_Result callback = AnyHttp_callbacks[id];
	AnyHttp_hasCallback[id] = false;
	return callback;
}

stock void AnyHttp_GetFileName(char[] filename, int maxsize, const char[] filepath) {
	int lastBackSlash = FindCharInString(filepath, '\\', true);
	int lastForwardSlash = FindCharInString(filepath, '/', true);
	if (lastBackSlash == -1 && lastForwardSlash == -1) {
		strcopy(filename, maxsize, filepath);
	} else {
		int pos = lastBackSlash > lastForwardSlash ? lastBackSlash : lastForwardSlash;
		strcopy(filename, maxsize, filepath[pos + 1]);
	}
}

stock void AnyHttp_AppendMultipartString(char[] buffer, int &bufferPos, int maxsize, const char[] name, const char[] contents, bool computeLength) {
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "--", bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, AnyHttp_MultiPartBoundary, bufferPos, 0, computeLength);
	
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "\nContent-Disposition: form-data; name=\"", bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, name, bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "\"\n\n", bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, contents, bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "\n", bufferPos, 0, computeLength);
}

stock bool AnyHttp_AppendMultipartFile(char[] buffer, int &bufferPos, int maxsize, const char[] name, const char[] filepath, bool computeLength) {
	char filename[PLATFORM_MAX_PATH];
	AnyHttp_GetFileName(filename, sizeof(filename), filepath);
		
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "--", bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, AnyHttp_MultiPartBoundary, bufferPos, 0, computeLength);
	
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "\nContent-Disposition: form-data; name=\"", bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, name, bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "\"; filename=\"", bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, filename, bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "\"\n\n", bufferPos, 0, computeLength);
	
	int filesize = FileSize(filepath);
	if (computeLength) {
		bufferPos += filesize;
	} else {
		File filehandle = OpenFile(filepath, "rb");
		if (filehandle == null)
			return false;
		for (int i = 0; i < filesize; i++) {
			int byte;
			if (!filehandle.ReadUint8(byte))
				return false;
			buffer[bufferPos++] = view_as<char>(byte);
		}
		filehandle.Close();
	}
	
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "\n", bufferPos, 0, computeLength);
	return true;
}

stock void AppendMultipartEnd(char[] buffer, int &bufferPos, int maxsize, bool computeLength) {
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "--", bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, AnyHttp_MultiPartBoundary, bufferPos, 0, computeLength);
	bufferPos += AnyHttp_CopyBytes(buffer, maxsize, "--", bufferPos, 0, computeLength);
}

stock int AnyHttp_CopyBytes(char[] dest, int destSize, const char[] src, int destPos, int srcPos, bool computeLength, int bytes = -1) {
	int bytesCopied = 0;
	if (bytes == -1)
		bytes = strlen(src);
	if (computeLength)
		return bytes;
	while (destPos < destSize && bytesCopied < bytes) {
		dest[destPos++] = src[srcPos++];
		bytesCopied++;
	}
	if (bytesCopied < bytes)
		ThrowError("AnyHttp: Not enough space allocated");
	return bytesCopied;
}

stock void AnyHttp_GenerateUniqueFilename(char[] filename, int maxsize) {
	GetPluginFilename(GetMyHandle(), filename, maxsize);
	Format(filename, maxsize, "%s.%i.%i.txt", filename, GetSysTickCount(), GetRandomInt(0, 100000));
}






// =========== SteamWorks ============

stock bool AnyHttp_SteamWorks_Get(const String:url[], AnyHttp_Result callback, int metadata = 0) {
	Handle handle = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, url);
	
	KvizSetNum(AnyHttp_kvData, AnyHttp_StoreCallback(callback), "%i.callback", _:handle);
	KvizSetNum(AnyHttp_kvData, metadata, "%i.metadata", _:handle);
	
	if (!SteamWorks_SetHTTPCallbacks(handle, AnyHttp_SteamWorks_Done) || !SteamWorks_SendHTTPRequest(handle)) {
		CloseHandle(handle);
		return false;
	}

	return true;
}


stock Handle AnyHttp_SteamWorks_CreatePostForm(const char[] url) {
	return SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
}

stock bool AnyHttp_SteamWorks_SendPostForm(Handle handle, AnyHttp_Result callback) {
	KvizSetNum(AnyHttp_kvData, AnyHttp_StoreCallback(callback), "%i.callback", _:handle);
	
	int length = AnyHttp_SteamWorks_SendPostForm_Internal(handle, 0);
	if (length < 0 || AnyHttp_SteamWorks_SendPostForm_Internal(handle, length) < 0) { 
		AnyHttp_CleanUp(handle);
		return false;
	}
	return true;
}

stock int AnyHttp_SteamWorks_SendPostForm_Internal(Handle handle, int bufferSize) {
	char type[64];
	
	char[] buffer = new char[bufferSize];
	
	int bufferPos = 0;
	
	for (int i = 1; KvizGetStringExact(AnyHttp_kvData, type, sizeof(type), "%i.fields:nth-child(%i).type", _:handle, i); i++) {
		if (StrEqual(type, "string")) {
			char name[1024];
			KvizGetStringExact(AnyHttp_kvData, name, sizeof(name), "%i.fields:nth-child(%i).name", _:handle, i);
			char contents[1024];
			KvizGetStringExact(AnyHttp_kvData, contents, sizeof(contents), "%i.fields:nth-child(%i).value", _:handle, i);
			AnyHttp_AppendMultipartString(buffer, bufferPos, bufferSize, name, contents, bufferSize == 0);
		} else if (StrEqual(type, "file")) {
			char name[1024];
			KvizGetStringExact(AnyHttp_kvData, name, sizeof(name), "%i.fields:nth-child(%i).name", _:handle, i);
			char filepath[1024];
			KvizGetStringExact(AnyHttp_kvData, filepath, sizeof(filepath), "%i.fields:nth-child(%i).value", _:handle, i);
			if (!AnyHttp_AppendMultipartFile(buffer, bufferPos, bufferSize, name, filepath, bufferSize == 0))
				return -1;
		} else {
			ThrowError("Unknown type");
		}
	}
	AppendMultipartEnd(buffer, bufferPos, bufferSize, bufferSize == 0);
	
	if (bufferSize == 0) {
		return bufferPos;
	}
	
	char contentType[256] = "multipart/form-data; boundary=";
	StrCat(contentType, sizeof(contentType), AnyHttp_MultiPartBoundary);
	
	SteamWorks_SetHTTPRequestRawPostBody(handle, contentType, buffer, bufferPos);
	
	if (!SteamWorks_SetHTTPCallbacks(handle, AnyHttp_SteamWorks_Done) || !SteamWorks_SendHTTPRequest(handle)) {
		return -1;
	}
	
	return bufferPos;
}

public void AnyHttp_SteamWorks_Done(Handle HTTPRequest, bool bFailure, bool requestSuccessful, EHTTPStatusCode statusCode) {
	int callbackID = KvizGetNum(AnyHttp_kvData, -1, "%i.callback", _:HTTPRequest);
	if (callbackID == -1)
		return; // The call was cancelled.
	int metadata = KvizGetNum(AnyHttp_kvData, 0, "%i.metadata", _:HTTPRequest);
	AnyHttp_Result callback = AnyHttp_RetrieveCallback(callbackID);
	KvizDelete(AnyHttp_kvData, "%i", _:HTTPRequest);
	
	int size = 0;
	if (requestSuccessful)
		SteamWorks_GetHTTPResponseBodySize(HTTPRequest, size);
	
	char[] buffer = new char[size];
	
	Call_StartFunction(null, callback);
	Call_PushCell(_:requestSuccessful);
	
	if (requestSuccessful) {
		SteamWorks_GetHTTPResponseBodyData(HTTPRequest, buffer, size);
		Call_PushString(buffer);
	} else {
		Call_PushString("");
	}

	Call_PushCell(statusCode);
	Call_PushCell(metadata);
	CloseHandle(HTTPRequest);
	Call_Finish();
}







// =========== SteamTools ============

stock bool AnyHttp_SteamTools_Get(const String:url[], AnyHttp_Result callback, int metadata = 0) {
	HTTPRequestHandle handle = Steam_CreateHTTPRequest(HTTPMethod_GET, url);
	
	KvizSetNum(AnyHttp_kvData, AnyHttp_StoreCallback(callback), "%i.callback", _:handle);
	KvizSetNum(AnyHttp_kvData, metadata, "%i.metadata", _:handle);
	
	if (!Steam_SendHTTPRequest(handle, AnyHttp_SteamTools_Done)) {
		// It seems to always return false. :(
		//AnyHttp_SteamTools_Done(handle, false, HTTPStatusCode_Invalid);
	}
	
	return true;
}


stock Handle AnyHttp_SteamTools_CreatePostForm(const char[] url) {
	HTTPRequestHandle handle = Steam_CreateHTTPRequest(HTTPMethod_POST, url);
	return view_as<Handle>(handle);
}

stock bool AnyHttp_SteamTools_SendPostForm(Handle handle, AnyHttp_Result callback) {
	KvizSetNum(AnyHttp_kvData, AnyHttp_StoreCallback(callback), "%i.callback", _:handle);
	
	int length = AnyHttp_SteamTools_SendPostForm_Internal(view_as<HTTPRequestHandle>(handle), 0);
	if (length < 0 || AnyHttp_SteamTools_SendPostForm_Internal(view_as<HTTPRequestHandle>(handle), length) < 0) { 
		AnyHttp_CleanUp(handle);
		return false;
	}
	return true;
}

stock int AnyHttp_SteamTools_SendPostForm_Internal(HTTPRequestHandle handle, int bufferSize) {
	char type[64];
	
	char[] buffer = new char[bufferSize];
	
	int bufferPos = 0;
	
	for (int i = 1; KvizGetStringExact(AnyHttp_kvData, type, sizeof(type), "%i.fields:nth-child(%i).type", _:handle, i); i++) {
		if (StrEqual(type, "string")) {
			char name[1024];
			KvizGetStringExact(AnyHttp_kvData, name, sizeof(name), "%i.fields:nth-child(%i).name", _:handle, i);
			char contents[1024];
			KvizGetStringExact(AnyHttp_kvData, contents, sizeof(contents), "%i.fields:nth-child(%i).value", _:handle, i);
			AnyHttp_AppendMultipartString(buffer, bufferPos, bufferSize, name, contents, bufferSize == 0);
		} else if (StrEqual(type, "file")) {
			char name[1024];
			KvizGetStringExact(AnyHttp_kvData, name, sizeof(name), "%i.fields:nth-child(%i).name", _:handle, i);
			char filepath[1024];
			KvizGetStringExact(AnyHttp_kvData, filepath, sizeof(filepath), "%i.fields:nth-child(%i).value", _:handle, i);
			if (!AnyHttp_AppendMultipartFile(buffer, bufferPos, bufferSize, name, filepath, bufferSize == 0))
				return -1;
		} else {
			ThrowError("Unknown type");
		}
	}
	AppendMultipartEnd(buffer, bufferPos, bufferSize, bufferSize == 0);
	
	if (bufferSize == 0) {
		return bufferPos;
	}
	
	char contentType[256] = "multipart/form-data; boundary=";
	StrCat(contentType, sizeof(contentType), AnyHttp_MultiPartBoundary);
	
	Steam_SetHTTPRequestRawPostBody(handle, buffer, bufferPos, contentType);
	
	if (!Steam_SendHTTPRequest(handle, AnyHttp_SteamTools_Done)) {
		// It seems to always return false. :(
		//AnyHttp_SteamTools_Done(handle, false, HTTPStatusCode_Invalid);
	}
	
	return bufferPos;
}

public AnyHttp_SteamTools_Done(HTTPRequestHandle HTTPRequest, bool requestSuccessful, HTTPStatusCode statusCode) {
	int callbackID = KvizGetNum(AnyHttp_kvData, -1, "%i.callback", _:HTTPRequest);
	if (callbackID == -1)
		return; // The call was cancelled.
	int metadata = KvizGetNum(AnyHttp_kvData, 0, "%i.metadata", _:HTTPRequest);
	AnyHttp_Result callback = AnyHttp_RetrieveCallback(callbackID);
	KvizDelete(AnyHttp_kvData, "%i", _:HTTPRequest);
	
	int size = 0;
	if (requestSuccessful)
		size = Steam_GetHTTPResponseBodySize(HTTPRequest);
	
	char[] buffer = new char[size];
	
	Call_StartFunction(null, callback);
	Call_PushCell(_:requestSuccessful);
	
	if (requestSuccessful) {
		Steam_GetHTTPResponseBodyData(HTTPRequest, buffer, size);
		Call_PushString(buffer);
	} else {
		Call_PushString("");
	}
	
	Call_PushCell(statusCode);
	Call_PushCell(metadata);
	Steam_ReleaseHTTPRequest(HTTPRequest);
	Call_Finish();
}








// =========== CURL ============

int AnyHttp_CURL_Default_Opts[][2] = {
	{_:CURLOPT_NOSIGNAL,1},
	{_:CURLOPT_NOPROGRESS,1},
	{_:CURLOPT_TIMEOUT,30},
	{_:CURLOPT_CONNECTTIMEOUT,60},
	{_:CURLOPT_USE_SSL,CURLUSESSL_TRY},
	{_:CURLOPT_SSL_VERIFYPEER,0},
	{_:CURLOPT_SSL_VERIFYHOST,0},
	{_:CURLOPT_VERBOSE,0}
};


stock bool AnyHttp_cURL_Get(const char[] url, AnyHttp_Result callback, int metadata = 0) {
	Handle curl = curl_easy_init();
	if (curl == null)
		return false;
	if (!curl_easy_setopt_int_array(curl, AnyHttp_CURL_Default_Opts, sizeof(AnyHttp_CURL_Default_Opts))) {
		CloseHandle(curl);
		return false;
	}
	
	KvizSetNum(AnyHttp_kvData, AnyHttp_StoreCallback(callback), "%i.callback", _:curl);
	KvizSetNum(AnyHttp_kvData, metadata, "%i.metadata", _:curl);
	
	char filename[128];
	AnyHttp_GenerateUniqueFilename(filename, sizeof(filename));
	KvizSetString(AnyHttp_kvData, filename, "%i.filename", _:curl);
	
	Handle filehandle = curl_OpenFile(filename, "wb");
	if (filehandle == null) {
		AnyHttp_CleanUp(curl);
		return false;
	}
	if (!curl_easy_setopt_handle(curl, CURLOPT_WRITEDATA, filehandle)) {
		AnyHttp_CleanUp(curl);
		return false;
	}
	KvizSetNum(AnyHttp_kvData, _:filehandle, "%i.filehandle", _:curl);
	if (!curl_easy_setopt_string(curl, CURLOPT_URL, url)) {
		AnyHttp_CleanUp(curl);
		return false;
	}
	curl_easy_perform_thread(curl, AnyHttp_cURL_Done);
	
	return true;
}



stock Handle AnyHttp_cURL_CreatePostForm(const char[] url) {
	Handle handle = curl_easy_init();
	if (handle == null)
		return null;
	if (!curl_easy_setopt_int_array(handle, AnyHttp_CURL_Default_Opts, sizeof(AnyHttp_CURL_Default_Opts))) {
		CloseHandle(handle);
		return null;
	}
	if (!curl_easy_setopt_string(handle, CURLOPT_URL, url)) {
		CloseHandle(handle);
		return null;
	}
	
	return handle;
}

stock bool AnyHttp_cURL_SendPostForm(Handle handle, AnyHttp_Result callback) {
	KvizSetNum(AnyHttp_kvData, AnyHttp_StoreCallback(callback), "%i.callback", _:handle);
	
	Handle hCurlForm = curl_httppost();
	char type[64];
	
	for (int i = 1; KvizGetStringExact(AnyHttp_kvData, type, sizeof(type), "%i.fields:nth-child(%i).type", _:handle, i); i++) {
		if (StrEqual(type, "string")) {
			char name[1024];
			KvizGetStringExact(AnyHttp_kvData, name, sizeof(name), "%i.fields:nth-child(%i).name", _:handle, i);
			char contents[1024];
			KvizGetStringExact(AnyHttp_kvData, contents, sizeof(contents), "%i.fields:nth-child(%i).value", _:handle, i);
			if (curl_formadd(hCurlForm, CURLFORM_COPYNAME, name, CURLFORM_COPYCONTENTS, contents, CURLFORM_END) != CURL_FORMADD_OK) {
				AnyHttp_CleanUp(handle);
				return false;
			}
		} else if (StrEqual(type, "file")) {
			char name[1024];
			KvizGetStringExact(AnyHttp_kvData, name, sizeof(name), "%i.fields:nth-child(%i).name", _:handle, i);
			char filepath[PLATFORM_MAX_PATH];
			KvizGetStringExact(AnyHttp_kvData, filepath, sizeof(filepath), "%i.fields:nth-child(%i).value", _:handle, i);
			if (curl_formadd(hCurlForm, CURLFORM_COPYNAME, name, CURLFORM_FILE, filepath, CURLFORM_END) != CURL_FORMADD_OK) {
				AnyHttp_CleanUp(handle);
				return false;
			}
		} else {
			ThrowError("Unknown type");
		}
	}
	
	if (!curl_easy_setopt_handle(handle, CURLOPT_HTTPPOST, hCurlForm)) {
		AnyHttp_CleanUp(handle);
		return false;
	}
	
	char filename[128];
	AnyHttp_GenerateUniqueFilename(filename, sizeof(filename));
	KvizSetString(AnyHttp_kvData, filename, "%i.filename", _:handle);
	
	Handle hCurlOutput = curl_OpenFile(filename, "w");
	if (hCurlOutput == null) {
		AnyHttp_CleanUp(handle);
		return false;
	}
	if (!curl_easy_setopt_handle(handle, CURLOPT_WRITEDATA, hCurlOutput)) {
		AnyHttp_CleanUp(handle);
		return false;
	}
	KvizSetNum(AnyHttp_kvData, _:hCurlOutput, "%i.filehandle", _:handle);
	curl_easy_perform_thread(handle, AnyHttp_cURL_Done);
	
	return true;
}

public AnyHttp_cURL_Done(Handle hndl, CURLcode code) {
	int callbackID = KvizGetNum(AnyHttp_kvData, -1, "%i.callback", _:hndl);
	if (callbackID == -1)
		return; // The call was cancelled.
	int metadata = KvizGetNum(AnyHttp_kvData, 0, "%i.metadata", _:hndl);
	AnyHttp_Result callback = AnyHttp_RetrieveCallback(callbackID);
	Handle filehandle = view_as<Handle>(KvizGetNum(AnyHttp_kvData, 0, "%i.filehandle", _:hndl));
	char filename[128];
	KvizGetString(AnyHttp_kvData, filename, sizeof(filename), "", "%i.filename", _:hndl);
	KvizDelete(AnyHttp_kvData, "%i", _:hndl);
	
	int responseCode = 0;
	bool success;
	int size = 0;
	if (code != CURLE_OK) {
		char error_buffer[256];
		curl_easy_strerror(code, error_buffer, sizeof(error_buffer));
		CloseHandle(filehandle);
		
		// We are currently not doing anything with the error. Perhaps we could expose it somehow.
		
		success = false;
 	} else {
		CloseHandle(filehandle); // Must be closed so it is flushed.

		curl_easy_getinfo_int(hndl, CURLINFO_RESPONSE_CODE, responseCode);

		success = true;
		size = FileSize(filename);
	}
	CloseHandle(hndl);
	
	char[] buffer = new char[size + 1];
	buffer[0] = '\0';
	
	Call_StartFunction(null, callback);
	Call_PushCell(_:success);
	
	if (success) {
		File fileHandle = OpenFile(filename, "r");
		if (fileHandle != null) { 
			ReadFileString(fileHandle, buffer, size + 1);
			CloseHandle(fileHandle);
		}
		
		Call_PushString(buffer);
	} else {
		Call_PushString("");
	}
	DeleteFile(filename);
	
	Call_PushCell(responseCode);
	Call_PushCell(metadata);
	Call_Finish();
}


// Mark HTTP extensions as optional

public __ext_curl_SetNTVOptional()
{
	MarkNativeAsOptional("curl_easy_init");
	MarkNativeAsOptional("curl_easy_setopt_string");
	MarkNativeAsOptional("curl_easy_setopt_int");
	MarkNativeAsOptional("curl_easy_setopt_int_array");
	MarkNativeAsOptional("curl_easy_setopt_int64");
	MarkNativeAsOptional("curl_easy_setopt_handle");
	MarkNativeAsOptional("curl_easy_setopt_function");
	MarkNativeAsOptional("curl_load_opt");
	MarkNativeAsOptional("curl_easy_perform");
	MarkNativeAsOptional("curl_easy_perform_thread");
	MarkNativeAsOptional("curl_easy_send_recv");
	MarkNativeAsOptional("curl_send_recv_Signal");
	MarkNativeAsOptional("curl_send_recv_IsWaiting");
	MarkNativeAsOptional("curl_set_send_buffer");
	MarkNativeAsOptional("curl_set_receive_size");
	MarkNativeAsOptional("curl_set_send_timeout");
	MarkNativeAsOptional("curl_set_recv_timeout");
	MarkNativeAsOptional("curl_get_error_buffer");
	MarkNativeAsOptional("curl_easy_getinfo_string");
	MarkNativeAsOptional("curl_easy_getinfo_int");
	MarkNativeAsOptional("curl_easy_escape");
	MarkNativeAsOptional("curl_easy_unescape");
	MarkNativeAsOptional("curl_easy_strerror");
	MarkNativeAsOptional("curl_version");
	MarkNativeAsOptional("curl_protocols");
	MarkNativeAsOptional("curl_features");
	MarkNativeAsOptional("curl_OpenFile");
	MarkNativeAsOptional("curl_httppost");
	MarkNativeAsOptional("curl_formadd");
	MarkNativeAsOptional("curl_slist");
	MarkNativeAsOptional("curl_slist_append");
	MarkNativeAsOptional("curl_hash_file");
	MarkNativeAsOptional("curl_hash_string");
}
/*
public __ext_SteamTools_SetNTVOptional()
{
    MarkNativeAsOptional("Steam_IsVACEnabled");
    MarkNativeAsOptional("Steam_GetPublicIP");
    MarkNativeAsOptional("Steam_RequestGroupStatus");
    MarkNativeAsOptional("Steam_RequestGameplayStats");
    MarkNativeAsOptional("Steam_RequestServerReputation");
    MarkNativeAsOptional("Steam_IsConnected");
    MarkNativeAsOptional("Steam_SetRule");
    MarkNativeAsOptional("Steam_ClearRules");
    MarkNativeAsOptional("Steam_ForceHeartbeat");
    MarkNativeAsOptional("Steam_SetGameDescription");
    MarkNativeAsOptional("Steam_RequestStats");
    MarkNativeAsOptional("Steam_GetStat");
    MarkNativeAsOptional("Steam_GetStatFloat");
    MarkNativeAsOptional("Steam_IsAchieved");
    MarkNativeAsOptional("Steam_GetNumClientSubscriptions");
    MarkNativeAsOptional("Steam_GetClientSubscription");
    MarkNativeAsOptional("Steam_GetNumClientDLCs");
    MarkNativeAsOptional("Steam_GetClientDLC");
    MarkNativeAsOptional("Steam_GetCSteamIDForClient");
    MarkNativeAsOptional("Steam_SetCustomSteamID");
    MarkNativeAsOptional("Steam_GetCustomSteamID");
    MarkNativeAsOptional("Steam_RenderedIDToCSteamID");
    MarkNativeAsOptional("Steam_CSteamIDToRenderedID");
    MarkNativeAsOptional("Steam_GroupIDToCSteamID");
    MarkNativeAsOptional("Steam_CSteamIDToGroupID");

    // HTTP functions
    MarkNativeAsOptional("Steam_CreateHTTPRequest");
    MarkNativeAsOptional("Steam_SetHTTPRequestNetworkActivityTimeout");
    MarkNativeAsOptional("Steam_SetHTTPRequestHeaderValue");
    MarkNativeAsOptional("Steam_SetHTTPRequestGetOrPostParameter");
    MarkNativeAsOptional("Steam_SetHTTPRequestRawPostBody");
    MarkNativeAsOptional("Steam_SendHTTPRequest");
    MarkNativeAsOptional("Steam_DeferHTTPRequest");
    MarkNativeAsOptional("Steam_PrioritizeHTTPRequest");
    MarkNativeAsOptional("Steam_GetHTTPResponseHeaderSize");
    MarkNativeAsOptional("Steam_GetHTTPResponseHeaderValue");
    MarkNativeAsOptional("Steam_GetHTTPResponseBodySize");
    MarkNativeAsOptional("Steam_GetHTTPResponseBodyData");
    MarkNativeAsOptional("Steam_WriteHTTPResponseBody");
    MarkNativeAsOptional("Steam_ReleaseHTTPRequest");
    MarkNativeAsOptional("Steam_GetHTTPDownloadProgressPercent");

    // deprecated functions
    MarkNativeAsOptional("Steam_AddMasterServer");
    MarkNativeAsOptional("Steam_RemoveMasterServer");
    MarkNativeAsOptional("Steam_GetNumMasterServers");
    MarkNativeAsOptional("Steam_GetMasterServerAddress");
}
*/
