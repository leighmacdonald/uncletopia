#pragma semicolon 1

/********** MISC CHEAT DETECTIONS / PATCHES *********/

// ban on invalid characters (newlines, carriage returns, etc)
public Action OnClientSayCommand(int cl, const char[] command, const char[] sArgs)
{
    // don't pick up console or bots
    if (!IsValidClient(cl))
    {
        return Plugin_Continue;
    }
    if
    (
        StrContains(sArgs, "\n", false) != -1
        ||
        StrContains(sArgs, "\r", false) != -1
    )
    {
        int userid = GetClientUserId(cl);
        if (stac_ban_for_misccheats.BoolValue)
        {
            char reason[128];
            Format(reason, sizeof(reason), "%t", "newlineBanMsg");
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "newlineBanAllChat", cl);
            BanUser(userid, reason, pubreason);
        }
        else
        {
            PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Blocked newline print from player %N", cl);
            StacLogSteam(userid);
        }
        StacNotify(userid, "Client tried to print a newline character", 1);
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

Action BanName(Handle timer, int userid)
{
    int cl = GetClientOfUserId(userid);
    if (!IsValidClient(cl))
    {
        // client must've left
        return Plugin_Continue;
    }

    if (stac_ban_for_misccheats.BoolValue)
    {
        char reason[128];
        Format(reason, sizeof(reason), "%t", "illegalNameBanMsg");
        char pubreason[256];
        Format(pubreason, sizeof(pubreason), "%t", "illegalNameBanAllChat", cl);
        BanUser(userid, reason, pubreason);
    }
    else
    {
        PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} Player %N has illegal chars in their name!", cl);
        StacLogSteam(userid);
        StacLog("[Detection] Player %N has illegal chars in their name!", cl);
    }
    return Plugin_Continue;
}

// block long commands - i don't know if this actually does anything but it makes me feel better
public Action OnClientCommand(int cl, int args)
{
    if (!IsValidClient(cl))
    {
        return Plugin_Continue;
    }

    // init var
    char ClientCommandChar[512];
    // gets the first command
    GetCmdArg(0, ClientCommandChar, sizeof(ClientCommandChar));
    // get length of string
    int len = strlen(ClientCommandChar);
    // is there more after this command?
    if (GetCmdArgs() > 0)
    {
        // add a space at the end of it
        ClientCommandChar[len++] = ' ';
        GetCmdArgString(ClientCommandChar[len++], sizeof(ClientCommandChar));
    }
    strcopy(lastCommandFor[cl], sizeof(lastCommandFor[]), ClientCommandChar);
    timeSinceLastCommand[cl] = engineTime[cl][0];
    // clean it up ( PROBABLY NOT NEEDED )
    // TrimString(ClientCommandChar);
    if (strlen(ClientCommandChar) > 255)
    {
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

// for achievement checking, because chook tries to be s n e a k y
// if there are upgrades to the call/response bullshit in chook i can and will make this iterate thru every single kv
public Action OnClientCommandKeyValues(int cl, KeyValues kv)
{
    if (!IsValidClient(cl))
    {
        return Plugin_Continue;
    }

    if (KvJumpToKey(kv, "achievementID", false))
    {
        if (KvGetDataType(kv, NULL_STRING) == KvData_Int)
        {
            // randomize this once on plugin load so cheaters cant do clever things by using a constant we use
            static int rand = 0;
            if (rand == 0)
            {
                rand = GetSRandomInt();
            }

            // hack because KvGetNum doesn't just return a bool with an int&
            int id = KvGetNum(kv, NULL_STRING, rand);

            // does this achiev id exist?
            if (id != rand)
            {
                // yes? check the achievement id
                int userid = GetClientUserId(cl);
                cheevCheck(userid, id);
            }
        }
    }

    return Plugin_Continue;
}


public void OnClientSettingsChanged(int cl)
{
    // ignore invalid clients
    if (!IsValidClient(cl))
    {
        return;
    }
    int userid = GetClientUserId(cl);

    // TODO: do we still need to do this?
    if
    (
        // command occured recently
        engineTime[cl][0] - 1.5 < timeSinceLastCommand[cl]
        &&
        (
            // and it's a demorestart
            StrEqual("demorestart", lastCommandFor[cl])
        )
    )
    {
        if (stac_debug.BoolValue)
        {
            StacLog("Ignoring demorestart settings change for %N", cl);
        }
        return;
    }

    if (!stac_fixpingmasking_enabled.BoolValue)
    {
        return;
    }

    if (justClamped[cl])
    {
        justClamped[cl] = false;
        return;
    }

    // We are basically FORCING clients to have sane network settings here,
    // because tf2 configs are all over the damn place, and it makes it more consistent to detect on, anyway
    // YOUD THINK since the engine already clamps this itself, that we could just be like, "ok, set sv_client_cmdrate_difference and sane min network cvars"
    // and that it would be fine and work properly with scoreboard ping, but it Absolutely Just Does Not Do That so we gotta do it ourselves here

    char cl_cmdrate     [64];
    char cl_updaterate  [64];
    char rate           [64];

    GetClientInfo( cl, "cl_cmdrate",         cl_cmdrate,         sizeof(cl_cmdrate) );
    GetClientInfo( cl, "cl_updaterate",      cl_updaterate,      sizeof(cl_updaterate) );
    GetClientInfo( cl, "rate",               rate,               sizeof(rate) );

    //LogMessage("[1] cmdrate %s / updaterate %s / rate %s", cl_cmdrate, cl_updaterate, rate);

    checkInterp(userid);

    // ban for illegal values
    if ( StringToInt(cl_cmdrate) < 10 )
    {
        oobVarsNotify(userid, "cl_cmdrate", cl_cmdrate);
        if (stac_ban_for_misccheats.BoolValue)
        {
            oobVarBan(userid);
        }
    }

    static int MAX_RATE = (1024*1024);
    static int MIN_RATE = 1000;

    // This isn't expensive. See Handle_t ConVarManager::FindConVar(const char *name):
    // https://cs.alliedmods.net/sourcemod/rev/50b4ad4e11f038ffae2f6e109cf338074e8dee97/core/ConVarManager.cpp#450-454
    // Not only is this cached by sourcemod, icvar->FindVar is fast enough anyway
    static int imincmdrate    ;
    static int imaxcmdrate    ;
    static int iminupdaterate ;
    static int imaxupdaterate ;
    static int iminrate       ;
    static int imaxrate       ;

    imincmdrate    = GetConVarInt( FindConVar("sv_mincmdrate") );
    imaxcmdrate    = GetConVarInt( FindConVar("sv_maxcmdrate") );
    iminupdaterate = GetConVarInt( FindConVar("sv_minupdaterate") );
    imaxupdaterate = GetConVarInt( FindConVar("sv_maxupdaterate") );
    iminrate       = GetConVarInt( FindConVar("sv_minrate") );
    imaxrate       = GetConVarInt( FindConVar("sv_maxrate") );

    if (iminrate <= 0)
    {
        iminrate = MIN_RATE;
    }

    if (imaxrate <= 0 || imaxrate > MAX_RATE)
    {
        imaxrate = MAX_RATE;
    }

    int clamped_cl_cmdrate      = clamp( StringToInt(cl_cmdrate),       imincmdrate,    imaxcmdrate );
    int clamped_cl_updaterate   = clamp( StringToInt(cl_updaterate),    iminupdaterate, imaxupdaterate );
    int clamped_rate            = clamp( StringToInt(rate),             iminrate,       imaxrate );

    IntToString( clamped_cl_cmdrate,    cl_cmdrate,     sizeof(cl_cmdrate) );
    IntToString( clamped_cl_updaterate, cl_updaterate,  sizeof(cl_updaterate) );
    IntToString( clamped_rate,          rate,           sizeof(rate) );


    //                                   vvvvvvvvvvvvv THIS IS NOT A TYPO, WE ARE FORCIBLY CLAMPING CMDRATE TO UPDATERATE
    SetClientInfo( cl, "cl_cmdrate",     cl_updaterate );
    SetClientInfo( cl, "cl_updaterate",  cl_updaterate );
    SetClientInfo( cl, "rate",           rate );

    GetClientInfo( cl, "cl_cmdrate",         cl_cmdrate,         sizeof(cl_cmdrate) );
    GetClientInfo( cl, "cl_updaterate",      cl_updaterate,      sizeof(cl_updaterate) );
    GetClientInfo( cl, "rate",               rate,               sizeof(rate) );


    //LogMessage("[2] cmdrate %s / updaterate %s / rate %s", cl_cmdrate, cl_updaterate, rate);

    justClamped[cl] = true;
}

// no longer just for netprops!
void MiscCheatsEtcsCheck(int userid)
{
    int cl = GetClientOfUserId(userid);

    if (IsValidClient(cl))
    {
        // there used to be an fov check here - but there's odd behavior that i don't want to work around regarding the m_iFov netprop.
        // sorry!

        checkInterp(userid);
    }
}

void checkInterp(int userid)
{
    // minterp var - clamp to -1 if 0
    int min_interp_ms           = GetConVarInt(stac_min_interp_ms);
    if (min_interp_ms == 0)
    {
        min_interp_ms = -1;
    }

    // maxterp var - clamp to -1 if 0
    int max_interp_ms           = GetConVarInt(stac_max_interp_ms);
    if (max_interp_ms == 0)
    {
        max_interp_ms = -1;
    }



    int cl = GetClientOfUserId(userid);
    // lerp check - we check the netprop
    // don't check if not default tickrate
    if (isDefaultTickrate())
    {
        float lerp = GetEntPropFloat(cl, Prop_Data, "m_fLerpTime") * 1000;
        if (stac_debug.BoolValue)
        {
            StacLog("%.2f ms interp on %N", lerp, cl);
        }

        // nolerp
        if (lerp <= 0.1)
        {
            char lerpStr[16];
            FloatToString(lerp, lerpStr, sizeof(lerpStr));
            oobVarsNotify(userid, "m_fLerpTime", lerpStr);
            if (stac_ban_for_misccheats.BoolValue)
            {
                oobVarBan(userid);
            }
        }
        else if
        (
            lerp < min_interp_ms && min_interp_ms != -1
            ||
            lerp > max_interp_ms && max_interp_ms != -1
        )
        {
            char message[256];
            Format(message, sizeof(message), "Client was kicked for attempted interp exploitation. Their interp: %.2fms", lerp);
            StacNotify(userid, message);
            KickClient(cl, "%t", "interpKickMsg", lerp, min_interp_ms, max_interp_ms);
            MC_PrintToChatAll("%t", "interpAllChat", cl, lerp);
            StacLog("%t", "interpAllChat", cl, lerp);
        }
    }
}

void cheevCheck(int userid, int achieve_id)
{
    // ent index of achievement earner
    int cl              = GetClientOfUserId(userid);

    // we can't sdkcall CAchievementMgr::GetAchievementByIndex(int) here because the server will never have a valid CAchievementMgr*
    // this is because achievements are all client side (because Valve just trusts clients fsr?)
    // we have to (use other peoples') hardcode, in this case nosoop's achievements.inc.

    // achievment number is bogus:
    if
    (
        // it's too low
        achieve_id < view_as<int>(Achievement_GetTurretKills)
        ||
        // it's too high
        achieve_id > view_as<int>(Achievement_MapsPowerhouseKillEnemyInWater)
    )
    {
        // uid for passing to GenPlayerNotify
        StacLogSteam(userid);

        if (stac_ban_for_misccheats.BoolValue)
        {
            PrintToImportant("{hotpink}[StAC] {white} User %N earned BOGUS achievement ID %i (hex %X)", cl, achieve_id, achieve_id);
            char reason[128];
            Format(reason, sizeof(reason), "%t", "bogusAchieveBanMsg");
            char pubreason[256];
            Format(pubreason, sizeof(pubreason), "%t", "bogusAchieveBanAllChat", cl);
            BanUser(userid, reason, pubreason);
        }
        else
        {
            PrintToImportant("{hotpink}[StAC] {red}[Detection]{white} User %N earned BOGUS achievement ID %i (hex %X)", cl, achieve_id, achieve_id);
        }

        char message[256];
        Format(message, sizeof(message), "Client is cheating with bogus AchievementID %i (hex %X)", achieve_id, achieve_id);
        StacNotify(userid, message, 1);
    }
}
