/**
 * Copyright Andrew Betson.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <tf2_stocks>

#include <dhooks>
#include <multicolors>

#pragma semicolon 1
#pragma newdecls required

ConVar		sv_fov_min;
ConVar		sv_fov_max;
int			g_nFOVOverride[ MAXPLAYERS + 1 ] = { -1, ... };
Handle		g_hCookie_FOV;

DHookSetup	g_hDetour_BasePlayer_SetFOV;
DHookSetup	g_hDetour_BasePlayer_SetDefaultFOV;

public Plugin myinfo =
{
	name		= "[TF2] FOV",
	author		= "Andrew \"andrewb\" Betson",
	description	= "Allow players to set their FOV beyond the arbitrary limit of the fov_desired cvar.",
	version		= "1.0.2",
	url			= "https://github.com/AndrewBetson/TF-FOV"
};

public void OnPluginStart()
{
	LoadTranslations( "common.phrases" );
	LoadTranslations( "fov.phrases" );

	sv_fov_min = CreateConVar( "sv_fov_min", "75.0", "Minimum FOV", FCVAR_NOTIFY, true, 10.0, true, 998.0 );
	sv_fov_min.AddChangeHook( ConVar_FOV_MinMax );

	sv_fov_max = CreateConVar( "sv_fov_max", "120.0", "Maximum FOV", FCVAR_NOTIFY, true, 11.0, true, 999.0 );
	sv_fov_max.AddChangeHook( ConVar_FOV_MinMax );

	RegConsoleCmd( "sm_fov", Cmd_FOV, "Set calling players FOV" );
	RegConsoleCmd( "sm_fov_clear", Cmd_FOV_Clear, "Clear calling players FOV preference" );

	AutoExecConfig( true, "fov" );

	g_hCookie_FOV = RegClientCookie( "fov_override", "FOV", CookieAccess_Public );

	Handle hGameData = LoadGameConfigFile( "fov.games" );
	if ( !hGameData )
	{
		SetFailState( "Failed to load fov gamedata." );
	}

	g_hDetour_BasePlayer_SetFOV			= DHookCreateFromConf( hGameData, "CBasePlayer::SetFOV" );
	g_hDetour_BasePlayer_SetDefaultFOV	= DHookCreateFromConf( hGameData, "CBasePlayer::SetDefaultFOV" );

	delete hGameData;

	if ( !DHookEnableDetour( g_hDetour_BasePlayer_SetFOV, false, Detour_BasePlayer_SetFOV ) )
	{
		SetFailState( "Failed to detour CBasePlayer::SetFOV, tell Andrew to update the signatures." );
	}

	if ( !DHookEnableDetour( g_hDetour_BasePlayer_SetDefaultFOV, false, Detour_BasePlayer_SetDefaultFOV ) )
	{
		SetFailState( "Failed to detour CBasePlayer::SetDefaultFOV, tell Andrew to update the signatures." );
	}

	// Late-load/reload support.
	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) )
		{
			if ( AreClientCookiesCached( i ) )
			{
				OnClientCookiesCached( i );
			}
		}
	}
}

public void OnClientCookiesCached( int nClientIdx )
{
	if ( nClientIdx <= 0 )
	{
		return;
	}

	char szFOV[ 4 ];
	GetClientCookie( nClientIdx, g_hCookie_FOV, szFOV, 4 );

	if ( szFOV[ 0 ] == EOS )
	{
		g_nFOVOverride[ nClientIdx ] = -1;
		return;
	}

	g_nFOVOverride[ nClientIdx ] = StringToInt( szFOV );
}

public void OnClientDisconnect( int nClientIdx )
{
	g_nFOVOverride[ nClientIdx ] = -1;
}

public Action Cmd_FOV( int nClientIdx, int nNumArgs )
{
	if ( nNumArgs < 1 )
	{
		CReplyToCommand( nClientIdx, "%t", "FOV_Usage" );
		return Plugin_Continue;
	}

	int nNewFOV;

#if SOURCEMOD_V_MINOR >= 11
	if ( !GetCmdArgIntEx( 1, nNewFOV ) )
	{
		CReplyToCommand( nClientIdx, "%t", "FOV_MustBeANumber" );
		return Plugin_Continue;
	}
#else
	char szSM110Hack[ 4 ];
	GetCmdArg( 1, szSM110Hack, 4 );

	nNewFOV = StringToInt( szSM110Hack );
#endif // SOURCEMOD_V_MINOR == 11

	if ( nNewFOV > sv_fov_max.IntValue || nNewFOV < sv_fov_min.IntValue )
	{
		CReplyToCommand( nClientIdx, "%t", "FOV_MustBeWithinRange", sv_fov_min.IntValue, sv_fov_max.IntValue );
		return Plugin_Continue;
	}

	g_nFOVOverride[ nClientIdx ] = nNewFOV;

	char szNewFOV[ 4 ];
	IntToString( nNewFOV, szNewFOV, 4 );

	SetClientCookie( nClientIdx, g_hCookie_FOV, szNewFOV );
	SetClientFOV( nClientIdx );

	return Plugin_Continue;
}

public Action Cmd_FOV_Clear( int nClientIdx, int nNumArgs )
{
	g_nFOVOverride[ nClientIdx ] = -1;

	char szNullFOV[ 4 ];
	IntToString( -1, szNullFOV, 4 );

	SetClientCookie( nClientIdx, g_hCookie_FOV, szNullFOV );

	return Plugin_Continue;
}

public void ConVar_FOV_MinMax( ConVar hConVar, const char[] szOldValue, const char[] szNewValue )
{
	int nNewValue = StringToInt( szNewValue );

	for ( int i = 1; i <= MaxClients; i++ )
	{
		if ( IsClientInGame( i ) )
		{
			if ( ( g_nFOVOverride[ i ] > nNewValue && hConVar == sv_fov_max ) || ( g_nFOVOverride[ i ] < nNewValue && hConVar == sv_fov_min ) )
			{
				g_nFOVOverride[ i ] = nNewValue;
				SetClientFOV( i );
			}
		}
	}
}

public MRESReturn Detour_BasePlayer_SetFOV( int pBasePlayer, DHookReturn hReturn, DHookParam hParams )
{
	if ( g_nFOVOverride[ pBasePlayer ] == -1 )
	{
		return MRES_Ignored;
	}

	RequestFrame( Frame_SetFOV, pBasePlayer );

	return MRES_Ignored;
}

public MRESReturn Detour_BasePlayer_SetDefaultFOV( int pBasePlayer, DHookParam hParams )
{
	if ( g_nFOVOverride[ pBasePlayer ] == -1 )
	{
		return MRES_Ignored;
	}

	RequestFrame( Frame_SetFOV, pBasePlayer );

	return MRES_Ignored;
}

void Frame_SetFOV( any aData )
{
	int pBasePlayer = view_as< int >( aData );

	if ( TF2_IsPlayerInCondition( pBasePlayer, TFCond_Zoomed ) )
	{
		return;
	}

	SetClientFOV( pBasePlayer );
}

void SetClientFOV( int nClientIdx )
{
	int nTargetFOV = g_nFOVOverride[ nClientIdx ];

	// Clamp the target FOV to the min-max range.
	if ( nTargetFOV > sv_fov_max.IntValue )	nTargetFOV = sv_fov_max.IntValue;
	if ( nTargetFOV < sv_fov_min.IntValue )	nTargetFOV = sv_fov_min.IntValue;

	SetEntProp( nClientIdx, Prop_Send, "m_iFOV", nTargetFOV );
	SetEntProp( nClientIdx, Prop_Send, "m_iDefaultFOV", nTargetFOV );
}
