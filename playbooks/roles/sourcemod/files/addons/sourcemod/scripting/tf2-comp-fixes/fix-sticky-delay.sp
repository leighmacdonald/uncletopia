#define WEAPON_ID_THE_CHARGIN_TARGE   131
#define WEAPON_ID_THE_SPLENDID_SCREEN 406
#define WEAPON_ID_THE_TIDE_TURNER     1099
#define WEAPON_ID_FESTIVE_TARGE       1144

static ConVar g_convar;
static Handle g_call_CTFWeaponBase_SecondaryAttack;

void FixStickyDelay_Setup(Handle game_config) {
    StartPrepSDKCall(SDKCall_Entity);
    PrepSDKCall_SetFromConf(game_config, SDKConf_Virtual, "CTFWeaponBase::SecondaryAttack");
    if ((g_call_CTFWeaponBase_SecondaryAttack = EndPrepSDKCall()) == INVALID_HANDLE) {
        SetFailState("Failed to finalize SDK call to CTFWeaponBase::SecondaryAttack");
    }

    g_convar = CreateConVar("sm_fix_sticky_delay", "0", _, FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

void FixStickyDelay_OnPlayerRunCmd(int client, int buttons) {
    if (!(buttons & IN_ATTACK2)) {
        return;
    }

    if (!g_convar.BoolValue) {
        return;
    }

    if (!IsPlayerAlive(client)) {
        return;
    }

    if (TF2_GetPlayerClass(client) != TFClass_DemoMan) {
        return;
    }

    int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary);

    if (weapon == -1) {
        return;
    }

    int item = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");

    if (item == -1 || item == WEAPON_ID_THE_CHARGIN_TARGE || item == WEAPON_ID_THE_SPLENDID_SCREEN
        || item == WEAPON_ID_THE_TIDE_TURNER || item == WEAPON_ID_FESTIVE_TARGE) {
        return;
    }

    SDKCall(g_call_CTFWeaponBase_SecondaryAttack, weapon);
}
