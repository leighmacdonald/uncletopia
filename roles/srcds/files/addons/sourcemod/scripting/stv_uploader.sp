/** 
Based on the uploader for https://demos.tf/about
*/
#pragma semicolon 1
#include <sourcemod>
#include <cURL>

public Plugin:myinfo =
{
	name = "uncletopia stv uploader",
	author = "Leigh MacDonald",
	description = "Auto-upload match stv to uncletopia",
	version = "0.1",
	url = "https://uncletopia.com/"
};

new CURL_Default_opt[][2] = {
	{_:CURLOPT_NOSIGNAL,1},
	{_:CURLOPT_NOPROGRESS,1},
	{_:CURLOPT_TIMEOUT,600},
	{_:CURLOPT_CONNECTTIMEOUT,600},
	{_:CURLOPT_USE_SSL,CURLUSESSL_TRY},
	{_:CURLOPT_SSL_VERIFYPEER,0},
	{_:CURLOPT_SSL_VERIFYHOST,0},
	{_:CURLOPT_VERBOSE,0}
};

/**
 * Converts a string to lowercase
 *
 * @param buffer		String to convert
 * @noreturn
 */
public CStrToLower(String:buffer[]) {
	new len = strlen(buffer);
	for(new i = 0; i < len; i++) {
		buffer[i] = CharToLower(buffer[i]);
	}
}

#define CURL_DEFAULT_OPT(%1) curl_easy_setopt_int_array(%1, CURL_Default_opt, sizeof(CURL_Default_opt))

new String:g_sDemoName[256] = "";
new String:g_sLastDemoName[256] = "";

new Handle:g_hCvarAPIKey = INVALID_HANDLE;
new Handle:g_hCvarUrl = INVALID_HANDLE;
new Handle:output_file = INVALID_HANDLE;
new Handle:postForm = INVALID_HANDLE;

public OnPluginStart()
{
	g_hCvarAPIKey = CreateConVar("sm_stv_apikey", "", "API key for demos.tf", FCVAR_PROTECTED);
	g_hCvarUrl = CreateConVar("sm_demostf_url", "https://demos.tf", "demos.tf url", FCVAR_PROTECTED);
	
	RegServerCmd("tv_record", Command_StartRecord);
	RegServerCmd("tv_stoprecord", Command_StopRecord);
}

public Action:Command_StartRecord(args)
{
	if (strlen(g_sDemoName) == 0) {
		GetCmdArgString(g_sDemoName, sizeof(g_sDemoName));
		StripQuotes(g_sDemoName);
		CStrToLower(g_sDemoName);
	}
	return Plugin_Continue;
}

public Action:Command_StopRecord(args)
{
	TrimString(g_sDemoName);
	if (strlen(g_sDemoName) != 0) {
		PrintToChatAll("[demos.tf]: Demo recording completed");
		g_sLastDemoName = g_sDemoName;
		g_sDemoName = "";
		CreateTimer(3.0, StartDemoUpload);
	}
	return Plugin_Continue;
}

public Action:StartDemoUpload(Handle:timer)
{
	decl String:fullPath[128];
	Format(fullPath, sizeof(fullPath), "%s.dem", g_sLastDemoName);
	UploadDemo(fullPath);
}

UploadDemo(const String:fullPath[])
{
	decl String:APIKey[128];
	GetConVarString(g_hCvarAPIKey, APIKey, sizeof(APIKey));
	decl String:BaseUrl[64];
	GetConVarString(g_hCvarUrl, BaseUrl, sizeof(BaseUrl));
	new String:Map[64];
	GetCurrentMap(Map, sizeof(Map));
	PrintToChatAll("Uploading demo %s", fullPath);
	new Handle:curl = curl_easy_init();
	CURL_DEFAULT_OPT(curl);
	
	postForm = curl_httppost();
	curl_formadd(postForm, CURLFORM_COPYNAME, "demo", CURLFORM_FILE, fullPath, CURLFORM_END);
	curl_formadd(postForm, CURLFORM_COPYNAME, "name", CURLFORM_COPYCONTENTS, fullPath, CURLFORM_END);
 	curl_formadd(postForm, CURLFORM_COPYNAME, "key", CURLFORM_COPYCONTENTS, APIKey, CURLFORM_END);
	curl_easy_setopt_handle(curl, CURLOPT_HTTPPOST, postForm);

	output_file = curl_OpenFile("output_demo.json", "w");
	curl_easy_setopt_handle(curl, CURLOPT_WRITEDATA, output_file);
	decl String:fullUrl[128];
	Format(fullUrl, sizeof(fullUrl), "%s/upload", BaseUrl);
	curl_easy_setopt_string(curl, CURLOPT_URL, fullUrl);
	curl_easy_perform_thread(curl, onComplete);
}

public onComplete(Handle:hndl, CURLcode:code)
{
	if(code != CURLE_OK)
	{
		new String:error_buffer[256];
		curl_easy_strerror(code, error_buffer, sizeof(error_buffer));
		CloseHandle(output_file);
		CloseHandle(hndl);
		PrintToChatAll("cURLCode error: %d", code);
	}
	else
	{
		CloseHandle(output_file);
		CloseHandle(hndl);
		ShowResponse();
	}
	CloseHandle(postForm);
	return;
}

public ShowResponse()
{
	new Handle:resultFile = OpenFile("output_demo.json", "r");
	new String:output[512];
	ReadFileString(resultFile, output, sizeof(output));
	PrintToChatAll("[demos.tf]: %s", output);
    LogToGame("[demos.tf]: %s", output);
	return;
}
