#pragma semicolon 1
#pragma tabsize 4
#pragma newdecls required

any Native_GB_BanClient(Handle plugin, int numParams)
{
	int adminId = GetNativeCell(1);
	if(adminId <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid adminId index (%d)", adminId);
	}
	int targetId = GetNativeCell(2);
	if(targetId <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid targetId index (%d)", targetId);
	}
	int reason = GetNativeCell(3);
	if(reason <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid reason index (%d)", reason);
	}
	GB_BanReason reasonValue = view_as<GB_BanReason>(reason);
	char duration[32];
	if(GetNativeString(4, duration, sizeof duration) != SP_ERROR_NONE)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid duration, but must be positive integer or 0 for permanent");
	}
	int banType = GetNativeCell(5);
	if(banType != BSBanned && banType != BSNoComm)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid banType, but must be 1: mute/gag  or 2: ban");
	}
	char demoName[128];
	if(GetNativeString(6, demoName, sizeof demoName) != SP_ERROR_NONE)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid demoName");
	}
	int tick = GetNativeCell(7);
	if(StrEqual(demoName, "") && tick <= 0)
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Invalid tick, but must be positive integer");
	}
	if(!ban(adminId, targetId, reasonValue, duration, banType, demoName, tick))
	{
		return ThrowNativeError(SP_ERROR_NATIVE, "Ban error ");
	}
	return true;
}
/**
 * ban performs the actual work of sending the ban request to the gbans server
 *
 * NOTE: There is currently no way to set a custom ban reason string
 */
public bool ban(int sourceId, int targetId, GB_BanReason reason, const char[] duration, int banType, const char[] demoName, int tick)
{
	char sourceSid[50];
	if(!GetClientAuthId(sourceId, AuthId_Steam3, sourceSid, sizeof sourceSid, true))
	{
		ReplyToCommand(sourceId, "Failed to get sourceId of user: %d", sourceId);
		return false;
	}
	char targetSid[50];
	if(!GetClientAuthId(targetId, AuthId_Steam3, targetSid, sizeof targetSid, true))
	{
		ReplyToCommand(sourceId, "Failed to get targetId of user: %d", targetId);
		return false;
	}

	JSON_Object obj = new JSON_Object();
	obj.SetString("source_id", sourceSid);
	obj.SetString("target_id", targetSid);
	obj.SetString("note", "");
	obj.SetString("reason_text", "");
	obj.SetInt("ban_type", banType);
	obj.SetInt("reason", view_as<int>(reason));
	obj.SetString("duration", duration);
	obj.SetInt("report_id", 0);
	obj.SetString("demo_name", demoName);
	obj.SetInt("demo_tick", tick);

	char encoded[1024];
	obj.Encode(encoded, sizeof encoded);
	json_cleanup_and_delete(obj);
	System2HTTPRequest req = newReq(onBanRespReceived, "/api/sm/bans/steam/create");
	req.SetData(encoded);
	req.POST();
	delete req;

	gReplyToClientId = sourceId;

	return true;
}


void onBanRespReceived(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method)
{
	if(!success)
	{
		gbLog("Ban request did not complete successfully");
		return ;
	}

	if(response.StatusCode != HTTP_STATUS_OK)
	{
		if(response.StatusCode == HTTP_STATUS_CONFLICT)
		{
			ReplyToCommand(gReplyToClientId, "Duplicate ban");
			return ;
		}
		ReplyToCommand(gReplyToClientId, "Unhandled error response");
		return ;
	}

	char[] content = new char[response.ContentLength + 1];

	response.GetContent(content, response.ContentLength + 1);

	JSON_Object banResult = json_decode(content);

	int banId = banResult.GetInt("ban_id");
	ReplyToCommand(gReplyToClientId, "User banned (#%d)", banId);
	gReplyToClientId = -1;
	json_cleanup_and_delete(banResult);
}
