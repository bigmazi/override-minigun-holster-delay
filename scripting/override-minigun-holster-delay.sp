#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <dhooks>
#include <tf2_stocks>

#pragma semicolon 1

public Plugin myinfo = {
	name = "Override minigun holster delay",
	author = "bigmazi",
	description = "Overrides minigun holster delay",
	version = "1.0.0.0",
	url = "https://steamcommunity.com/id/bmazi"
}

float g_canHolsterTime[MAXPLAYERS + 1];

ConVar sm_minigun_holster_delay_override_enabled;
ConVar sm_minigun_holster_delay_override_value;

stock DHookSetup Detour(
	const char[] confName, const char[] functionName,
	DHookCallback pre = INVALID_FUNCTION, DHookCallback post = INVALID_FUNCTION)
{
	GameData conf = new GameData(confName);
	
	if (!conf)
		SetFailState("Couldn't load \"%s\" file!", confName);
	
	DHookSetup setup = DHookCreateFromConf(conf, functionName);
	
	delete conf;
	
	if (!setup)
		SetFailState("Couldn't setup detour for \"%s\"!", functionName);
	
	if (pre != INVALID_FUNCTION)
	{
		bool enabled = DHookEnableDetour(setup, false, pre);
		
		if (!enabled)
			SetFailState("Couldn't detour \"%s\" (pre)!", functionName);
	}
	
	if (post != INVALID_FUNCTION)
	{
		bool enabled = DHookEnableDetour(setup, true, post);
		
		if (!enabled)
			SetFailState("Couldn't detour \"%s\" (post)!", functionName);
	}	
	
	return setup;
}

MRESReturn CanHolsterPre(int weapon, DHookReturn ret)
{
	if (!sm_minigun_holster_delay_override_enabled.BoolValue)
		return MRES_Ignored;
	
	int owner = GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity");
	
	if (GetGameTime() > g_canHolsterTime[owner]) 
	{
		if (!TF2_IsPlayerInCondition(owner, TFCond_Slowed))
		{
			DHookSetReturn(ret, true);
			return MRES_Supercede;
		}
	}
	
	return MRES_Ignored;
}

public void OnPluginStart()
{
	sm_minigun_holster_delay_override_value = CreateConVar(
		"sm_minigun_holster_delay_override_value",
		"0.4",
		"Custom delay after which minigun may be holstered since it was spun down (in seconds)",
		0,
		true, 0.0,
		true, 10.0
	);
	
	sm_minigun_holster_delay_override_enabled = CreateConVar(
		"sm_minigun_holster_delay_override_enabled",
		"1",
		"If enabled, the default minigun holster delay is replaced with the value of ''sm_minigun_holster_delay_override_value''",
		0,
		true, 0.0,
		true, 1.0
	);
	
	Detour("tf2.override-minigun-holster-delay", "CTFMinigun::CanHolster", _, CanHolsterPre);
	
	AutoExecConfig(true, "override-minigun-holster-delay");
}

public void TF2_OnConditionRemoved(int player, TFCond cond)
{
	if (cond == TFCond_Slowed)
	{
		g_canHolsterTime[player] =
			GetGameTime() + sm_minigun_holster_delay_override_value.FloatValue;
	}
}