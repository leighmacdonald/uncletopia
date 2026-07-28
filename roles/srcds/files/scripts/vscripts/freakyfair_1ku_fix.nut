::BotHealthBoost <- 115;
::BotBuildingHealthBoost <- 2.315;
::BotBuildingSpeedBoost <- 0.55;
::CurrentCapPosition <- 1;

// BuildingSpeedBoost attribute is inverted, so 0.55 means 45% faster speed.

// CurrentCapPosition is where the players are at. If they are at the first point, then it is 1.

::BotPrimaryWeapons <- [
    "tf_weapon_shotgun_primary",
    "tf_weapon_sentry_revenge" ,
    "tf_weapon_drg_pomson"
];

::SpawnEntities <- [
    "func_respawnroom",
    "info_player_teamspawn"
];

function Delay(funcName, delay)
{
    EntFire("freakyfair_vscript", "RunScriptCode", funcName, delay);
}

function RaiseSpawn()
{
    foreach (classname in SpawnEntities)
    {
        local ent = null
        while (ent = Entities.FindByClassname(ent, classname))
        {
            local team = ent.GetTeam();
            if (team == 3)
            {
                local origin = ent.GetOrigin();
                origin.z += 55;                 // Raise by 55 hammer units
                ent.SetOrigin(origin);
            }
        }
    }
}

function RaiseNobuilds()
{
    local ent = null
    while (ent = Entities.FindByClassname(ent, "func_nobuild"))
    {
        local origin = ent.GetOrigin();
        origin.z += 1000;                 // Raise by 1000 hammer units
        ent.SetOrigin(origin);
    }
}

function LowerNobuilds()
{
    local ent = null
    while (ent = Entities.FindByClassname(ent, "func_nobuild"))
    {
        local origin = ent.GetOrigin();
        origin.z -= 1000;                 // Lower by 1000 hammer units
        ent.SetOrigin(origin);
    }
}

function LowerSpawn()
{
    foreach (classname in SpawnEntities)
    {
        local ent = null
        while (ent = Entities.FindByClassname(ent, classname))
        {
            local team = ent.GetTeam();
            if (team == 3)
            {
                local origin = ent.GetOrigin();
                origin.z -= 55;                 // Lower by 55 hammer units
                ent.SetOrigin(origin);
            }
        }
    }
}

function OnGameEvent_teamplay_round_start(params)
{
    Delay("RaiseSpawn()", 5.5);
    Delay("LowerNobuilds()", 5.5);
}

function OnGameEvent_teamplay_win_panel(params)
{
    LowerSpawn();
    RaiseNobuilds();
}

function OnGameEvent_player_used_powerup_bottle(params)
{
    local player = PlayerInstanceFromIndex(params.player);
    if (player.GetSolid() == SOLID_BBOX)
    {
        player.AddCustomAttribute("increase player capture value", -2, 10);
    }
}
// fixes ghost potion capping issue

function OnGameEvent_player_spawn(params)
{
    local player = GetPlayerFromUserID(params.userid);
    if (player == null || !player.IsValid() || !player.IsAlive())
        return;

    local weapon = player.GetActiveWeapon();
    if (weapon != null && weapon.IsValid() && player.IsAlive() && player.IsFakeClient())
    {
        weapon.AddAttribute("maxammo metal increased", 500, -1);
        weapon.AddAttribute("metal regen", 500, -1);
        weapon.AddAttribute("engy building health bonus", BotBuildingHealthBoost, -1);
        weapon.AddAttribute("max health additive bonus", BotHealthBoost, -1);
        weapon.AddAttribute("build rate bonus", BotBuildingSpeedBoost, -1);
        player.AddCondEx(Constants.ETFCond.TF_COND_SPEED_BOOST, 30, null);
        if (CurrentCapPosition >= 2)
        {
            weapon.AddAttribute("dmg taken from crit reduced", 0.50, -1);
            weapon.AddAttribute("dmg taken from blast reduced", 0.50, -1);
        }
    }
}

function UpgradeBotBuffs()
{
    BotHealthBoost = (BotHealthBoost + 100);
    BotBuildingHealthBoost = (BotBuildingHealthBoost + 1.1575);
    BotBuildingSpeedBoost = (BotBuildingSpeedBoost - 0.25);
    CurrentCapPosition = (CurrentCapPosition + 1);

	foreach (classname in BotPrimaryWeapons)
	{
        local weapon = null
        while (weapon = Entities.FindByClassname(weapon, classname))
        {
            local owner = (NetProps.GetPropEntity(weapon,"m_hOwner"))
            if (owner != null && owner.IsValid() && owner.IsAlive() && owner.IsFakeClient())
            {
                weapon.RemoveAttribute("engy building health bonus");
                weapon.RemoveAttribute("max health additive bonus");
                weapon.RemoveAttribute("build rate bonus");
                weapon.AddAttribute("engy building health bonus", BotBuildingHealthBoost, -1);
                weapon.AddAttribute("max health additive bonus", BotHealthBoost, -1);
                weapon.AddAttribute("build rate bonus", BotBuildingSpeedBoost, -1);
                local maxhealth = owner.GetMaxHealth();
                owner.SetHealth(maxhealth);
                if (CurrentCapPosition >= 2)
                {
                    weapon.AddAttribute("dmg taken from crit reduced", 0.50, -1);
                    weapon.AddAttribute("dmg taken from blast reduced", 0.50, -1);
                }
            }
            else continue
        }
    }
}

// UpgradeBotBuffs function increases the buffs for the bots, and applies it to the bots who have NOT been respawned yet! Those who will respawn will get the new buffs still. EXECUTED FROM STRIPPER CFG

// Fixes issue with bots having incorrect amount of metal for freaky fair, plus buff them up since they cannot upgrade at the stations. Metal issue only occurs on this map for some reason??? Adding the attributes to the player does NOT work for some reason?? So, applying to the primary weapon instead...

__CollectGameEventCallbacks(this);
