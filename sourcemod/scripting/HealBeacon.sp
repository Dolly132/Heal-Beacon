#pragma semicolon 1
#pragma newdecls required


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <multicolors>
#include <zombiereloaded>
#include <adminmenu>
#include <Healbeacon>
#include <commandfilters>

#define PLUGIN_DESCRIPTION "Sets beacon to 2 random players and damage whoever is far from them"
#define PLUGIN_PREFIX "{fullred}[Heal Beacon] {white}"

int g_LaserSprite = -1;
int g_HaloSprite = -1;

int g_BeaconPlayer[MAXPLAYERS+1] =  { 0, ... };

int g_iRandom1 = -1;
int g_iRandom2 = -1;

int EntityPointHurt = -1;
int g_iNeon[MAXPLAYERS+1] = {-1, ...};
int g_iClientBeaconColor[MAXPLAYERS+1][4];
int g_iClientNeonColor[MAXPLAYERS+1][4];
int g_iHealth[MAXPLAYERS+1] = -1;


float g_iClientDistance[MAXPLAYERS+1] = {1.0, ...};


int iCount[MAXPLAYERS+1] = {0, ...};
int iCountdown = 10;


int g_BeaconColor[4] =  {255, 56, 31, 255};

int g_ColorWhite[4] =  {255, 255, 255, 255};
int g_ColorRed[4] =  {255, 0, 0, 255};
int g_ColorLime[4] =  {0, 255, 0, 255};
int g_ColorBlue[4] =  {0, 0, 255, 255};
int g_ColorYellow[4] =  {255, 255, 0, 255};
int g_ColorCyan[4] =  {0, 255, 255, 255};
int g_ColorGold[4] =  {255, 215, 0, 255};


bool g_bRoundStart;
bool g_bIsDone;
bool g_bHasNeon[MAXPLAYERS+1];
bool g_bModeIsEnabled;
bool g_bMaxHealth[MAXPLAYERS+1];
bool g_bNoBeacon;

ConVar g_cvEnabled;
ConVar g_cvTimer;
ConVar g_cvDamage;
ConVar g_cvLifeTime;

Handle BeaconTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
Handle DistanceTimerHandle[MAXPLAYERS + 1] =  {INVALID_HANDLE, ...};
Handle g_HudMsg = INVALID_HANDLE;
Handle g_hRoundStart_Timer = INVALID_HANDLE;
Handle g_hHudTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
Handle g_hDistanceTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
Handle g_hRoundEndTimer = INVALID_HANDLE;


public Plugin myinfo = 
{
	name = "HealBeacon",
	author = "Dolly, Thanks to Ire",
	description = PLUGIN_DESCRIPTION,
	version = "1.102",
	url = "https://nide.gg"
};

public void OnPluginStart()
{
	g_cvEnabled = CreateConVar("sm_enable_healbeacon", "0", PLUGIN_DESCRIPTION);
	g_cvTimer = CreateConVar("sm_beacon_timer", "20.0", "The time that will start picking random players at round start");
	g_cvDamage = CreateConVar("sm_beacon_damage", "5", "The damage that the heal beacon will give");
	g_cvLifeTime = CreateConVar("sm_beacon_lifetime", "1.0", "Life time of the beacon");
	
	g_cvEnabled.AddChangeHook(OnConVarChange);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_team", Event_PlayerTeam);
	
	RegAdminCmd("sm_healbeacon", Command_Menu, ADMFLAG_BAN, "Shows healbeacon menu");
	RegAdminCmd("sm_beacon_distance", Command_Distance, ADMFLAG_CONVARS, "Change beacon distance");
	RegAdminCmd("sm_sethealbeacon", Command_SetHealBeacon, ADMFLAG_BAN, "Set a heal beacon player to someone else");
	
	g_HudMsg = CreateHudSynchronizer();
	SetHudTextParams(-1.0, 0.2, 1.0, 0, 255, 255, 255);
	
	AutoExecConfig();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("IsBeaconPlayer1", Native_Player1);
	CreateNative("IsBeaconPlayer2", Native_Player2);
	
	RegPluginLibrary("HealBeacon");
	
	return APLRes_Success;
}

public int Native_Player1(Handle plugin, int numParams)
{
	return g_iRandom1;
}

public int Native_Player2(Handle plugin, int numParams)
{
	return g_iRandom2;
}

public void OnConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if (StringToInt(newValue) >= 1 && StringToInt(oldValue) < 1)
	{
		CPrintToChatAll("%sHeal Beacon has been {yellow}enabled for the next round.", PLUGIN_PREFIX);
	}
	if (StringToInt(newValue) < 1 && StringToInt(oldValue) >= 1)
	{
		CPrintToChatAll("%sHeal beacon has been disabled", PLUGIN_PREFIX);
	}
}

public void OnMapStart()
{
	g_LaserSprite = PrecacheModel("sprites/laser.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/halo.vtf");
}

public void OnClientPostAdminCheck(int client)
{
	g_iHealth[client] = 0;
	ResetValues(client);
}

public void OnClientDisconnect(int client)
{
	if(client == g_iRandom1)
	{
		if(g_iRandom2 == -1)
		{
			CPrintToChatAll("%sPlayer %N has disconnected with the heal beacon.", PLUGIN_PREFIX, g_iRandom1);
			g_iRandom1 = -1;
			EndRound();
		}
		else
		{
			CPrintToChatAll("%sPlayer %N has disconnected with the heal beacon.", PLUGIN_PREFIX, g_iRandom1);
			g_iRandom1 = -1;
		}
	}
	else if(client == g_iRandom2)
	{
		if(g_iRandom1 == -1)
		{
			CPrintToChatAll("%sPlayer %N has disconnected with the heal beacon.", PLUGIN_PREFIX, g_iRandom2);
			g_iRandom2 = -1;
			EndRound();
		}
		else
		{
			CPrintToChatAll("%sPlayer %N has disconnected with the heal beacon.", PLUGIN_PREFIX, g_iRandom2);
			g_iRandom2 = -1;
		}
	}
	
	g_iHealth[client] = 0;
	
	DeleteAllHandles(client);
	
	ResetValues(client);
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bRoundStart = true;
		
	g_bIsDone = false;
		
	g_bModeIsEnabled = false;
	
	g_bNoBeacon = false;
		
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			DeleteAllHandles(i);
			RemoveNeon(i);
			ResetValues(i);
			g_iClientDistance[i] = 400.0;
			g_BeaconPlayer[i] = 0;
			g_iClientBeaconColor[i] = g_BeaconColor;
			g_iHealth[i] = 0;
			g_bMaxHealth[i] = true;
			g_bHasNeon[i] = false;
			SetEntProp(i, Prop_Data, "m_iMaxHealth", 120);
			
		}
	}
	
	g_hRoundStart_Timer = CreateTimer(GetConVarFloat(g_cvTimer), RoundStart_Timer);
	
	return Plugin_Continue;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(g_bRoundStart)
	{
		if(g_iRandom1 != -1)
		{
			g_BeaconPlayer[g_iRandom1] = 0;
			g_iRandom1 = -1;
		}
			
		if(g_iRandom2 != -1)
		{
			g_BeaconPlayer[g_iRandom2] = 0;
			g_iRandom2 = -1;
		}	
			
		g_bRoundStart = false;
					
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i))
				DeleteAllHandles(i);
		}
			
		
		g_hRoundStart_Timer = null;
		
		
		if(g_hRoundStart_Timer != INVALID_HANDLE)
			delete g_hRoundStart_Timer;
	
	
		g_hRoundEndTimer = null;
		
		if(g_hRoundEndTimer != INVALID_HANDLE)
			delete g_hRoundEndTimer;
			
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client))
	{
		if(client == g_iRandom1)
		{
			if(g_iRandom2 == -1)
			{
				CPrintToChatAll("%s%N has died with the heal beacon", PLUGIN_PREFIX, g_iRandom1);
				g_iRandom1 = -1;
				EndRound();
			}
			else
			{			
				CPrintToChatAll("%s%N has died with the heal beacon", PLUGIN_PREFIX, g_iRandom1);
				g_iRandom1 = -1;
			}
		}
		else if(client == g_iRandom2)
		{
			if(g_iRandom1 == -1)
			{
				CPrintToChatAll("%s%N has died with the heal beacon", PLUGIN_PREFIX, g_iRandom2);
				g_iRandom2 = -1;
				EndRound();
			}
			else
			{			
				CPrintToChatAll("%s%N has died with the heal beacon", PLUGIN_PREFIX, g_iRandom2);
				g_iRandom2 = -1;
			}
		}
		
		RemoveNeon(client);
		
		if(BeaconTimer[client] != INVALID_HANDLE)
			delete BeaconTimer[client];
			
		BeaconTimer[client] = null;
	}
	
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int newteam = GetEventInt(event, "team");
	
	if(IsValidClient(client) && client == g_iRandom1 && newteam == 1)
	{
		if(g_iRandom2 == -1)
		{
			CPrintToChatAll("%s%N has moved to the Spec team with the heal beacon", PLUGIN_PREFIX, g_iRandom1);
			g_iRandom1 = -1;
			EndRound();
		}
		else
		{
			CPrintToChatAll("%s%N has moved to the Spec team with the heal beacon", PLUGIN_PREFIX, g_iRandom1);
			g_iRandom1 = -1;
		}
	}

	else if(IsValidClient(client) && client == g_iRandom2 && newteam == 1)
	{
		if(g_iRandom1 == -1)
		{
			CPrintToChatAll("%s%N has moved to the Spec team with the heal beacon", PLUGIN_PREFIX, g_iRandom2);
			g_iRandom2 = -1;
			EndRound();
		}
		else
		{
			CPrintToChatAll("%s%N has moved to the Spec team with the heal beacon", PLUGIN_PREFIX, g_iRandom2);
			g_iRandom2 = -1;
		}
	}

	
	return Plugin_Continue;
}
	
public Action RoundStart_Timer(Handle timer)
{
	if(GetConVarBool(g_cvEnabled))
	{
		GetFirstRandom();
		
		GetSecondRandom();
		

		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && GetClientTeam(i) == 3)
			{
				g_hHudTimer[i] = CreateTimer(1.0, Hud_Counter, GetClientSerial(i), TIMER_REPEAT);
				g_hDistanceTimer[i] = CreateTimer(10.0, Distance_Timer, GetClientSerial(i));
			}
		}	
	}
	
	return Plugin_Continue;
}

public Action RoundEnd_Timer(Handle timer)
{
	CS_TerminateRound(3.0, CSRoundEnd_TerroristWin, false);
	
	return Plugin_Handled;
}

public Action Hud_Counter(Handle timer, int clientserial)
{
	int client = GetClientFromSerial(clientserial);
	
	if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)
		ShowSyncHudText(client, g_HudMsg, "WARNING: DON'T BE FAR AWAY FROM THE BEACONED PLAYERS OR ELSE YOU WILL GET DAMAGED IN %d", iCountdown - iCount[client]);
	
	iCount[client]++;
	
	if(iCount[client] >= 10)
	{
		g_hHudTimer[client] = null;
		return Plugin_Stop;
	}
		
	return Plugin_Continue;
}

public Action Distance_Timer(Handle timer, int clientserial)
{
	int client = GetClientFromSerial(clientserial);
	
	if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)
		DistanceTimerHandle[client] = CreateTimer(1.0, DistanceChecker_Timer, GetClientSerial(client), TIMER_REPEAT);
		
	return Plugin_Handled;
}

public Action DistanceChecker_Timer(Handle timer, int clientserial)
{
	int client = GetClientFromSerial(clientserial);
	
	if(client == g_iRandom1)
		return Plugin_Handled;
		
	if(client == g_iRandom2)
		return Plugin_Handled;
		
	
	if(!g_bModeIsEnabled)
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)
		{
			if(g_iRandom1 != -1 && g_iRandom2 == -1)
			{
				if(GetDistanceBetween(client, g_iRandom1) > g_iClientDistance[g_iRandom1] - 155.0)
				{
					g_iHealth[client] = GetEntProp(client, Prop_Send, "m_iHealth");
					ShowSyncHudText(client, g_HudMsg, "WARNING: YOU ARE TOO FAR AWAY FROM THE BEACONED PLAYERS PLEASE GET CLOSER TO THEM");
					DealDamage(client, g_cvDamage.IntValue, DMG_GENERIC);
					g_bMaxHealth[client] = false;
				}
				else if(GetDistanceBetween(client, g_iRandom1) < g_iClientDistance[g_iRandom1] - 155.0000)
				{
					if(!g_bMaxHealth[client])
					{
						if(GetEntProp(client, Prop_Send, "m_iHealth") < GetEntProp(client, Prop_Data, "m_iMaxHealth"))
						{
							SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iHealth") + 1);
						
							if(GetEntProp(client, Prop_Send, "m_iHealth") == GetEntProp(client, Prop_Data, "m_iMaxHealth"))
							{
								g_bMaxHealth[client] = true;
							}
						}
						
					}
				}
			}
			else if(g_iRandom1 == -1 && g_iRandom2 != -1)
			{
				if(GetDistanceBetween(client, g_iRandom2) > g_iClientDistance[g_iRandom2] - 155.0000)
				{
					g_iHealth[client] = GetEntProp(client, Prop_Send, "m_iHealth");
					
					ShowSyncHudText(client, g_HudMsg, "WARNING: YOU ARE TOO FAR AWAY FROM THE BEACONED PLAYERS PLEASE GET CLOSER TO THEM");
					DealDamage(client, g_cvDamage.IntValue, DMG_GENERIC);
					g_bMaxHealth[client] = false;
				}
				else if(GetDistanceBetween(client, g_iRandom2) < g_iClientDistance[g_iRandom2] - 155.0000)
				{
					if(!g_bMaxHealth[client])
					{
						if(GetEntProp(client, Prop_Send, "m_iHealth") < GetEntProp(client, Prop_Data, "m_iMaxHealth"))
						{
							SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iHealth") + 1);
							
							if(GetEntProp(client, Prop_Send, "m_iHealth") == GetEntProp(client, Prop_Data, "m_iMaxHealth"))
							{
								g_bMaxHealth[client] = true;
							}
						}
					}
				}				
			}
			else if(g_iRandom1 != -1 && g_iRandom2 != -1)
			{
				if(GetDistanceBetween(client, g_iRandom1) > g_iClientDistance[g_iRandom1] - 155.0000 && GetDistanceBetween(client, g_iRandom2) > g_iClientDistance[g_iRandom2] - 155.0000)
				{
					g_iHealth[client] = GetEntProp(client, Prop_Send, "m_iHealth");
					ShowSyncHudText(client, g_HudMsg, "WARNING: YOU ARE TOO FAR AWAY FROM THE BEACONED PLAYERS PLEASE GET CLOSER TO THEM");
					DealDamage(client, g_cvDamage.IntValue, DMG_GENERIC);
					g_bMaxHealth[client] = false;
				}
				else if(GetDistanceBetween(client, g_iRandom1) < g_iClientDistance[g_iRandom1] - 155.0000 || GetDistanceBetween(client, g_iRandom2) < g_iClientDistance[g_iRandom2] - 155.0000)
				{
					if(!g_bMaxHealth[client])
					{
						if(GetEntProp(client, Prop_Send, "m_iHealth") < GetEntProp(client, Prop_Data, "m_iMaxHealth"))
						{
							SetEntProp(client, Prop_Send, "m_iHealth", GetEntProp(client, Prop_Send, "m_iHealth") + 1);
						
							if(GetEntProp(client, Prop_Send, "m_iHealth") == GetEntProp(client, Prop_Data, "m_iMaxHealth"))
							{
								g_bMaxHealth[client] = true;
							}
						}
					}
				}
			}
			else if(g_iRandom1 == -1 && g_iRandom2 == -1)
			{
				DistanceTimerHandle[client] = null;
				return Plugin_Stop;
			}
		}
	}
	else
	{
		if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)
		{
			if(g_iRandom1 != -1 && g_iRandom2 == -1)
			{
				if(GetDistanceBetween(client, g_iRandom1) > g_iClientDistance[g_iRandom1] - 155.0000)
				{
					ShowSyncHudText(client, g_HudMsg, "WARNING: YOU ARE TOO FAR AWAY FROM THE BEACONED PLAYERS PLEASE GET CLOSER TO THEM");
					DealDamage(client, g_cvDamage.IntValue, DMG_GENERIC);
				}
			}
			else if(g_iRandom1 == -1 && g_iRandom2 != -1)
			{
				if(GetDistanceBetween(client, g_iRandom2) > g_iClientDistance[g_iRandom2] - 155.0000)
				{
					ShowSyncHudText(client, g_HudMsg, "WARNING: YOU ARE TOO FAR AWAY FROM THE BEACONED PLAYERS PLEASE GET CLOSER TO THEM");
					DealDamage(client, g_cvDamage.IntValue, DMG_GENERIC);
				}			
			}
			else if(g_iRandom1 != -1 && g_iRandom2 != -1)
			{
				if(GetDistanceBetween(client, g_iRandom1) > g_iClientDistance[g_iRandom1] - 155.0000 && GetDistanceBetween(client, g_iRandom2) > g_iClientDistance[g_iRandom2] - 155.0000)
				{
					ShowSyncHudText(client, g_HudMsg, "WARNING: YOU ARE TOO FAR AWAY FROM THE BEACONED PLAYERS PLEASE GET CLOSER TO THEM");
					DealDamage(client, g_cvDamage.IntValue, DMG_GENERIC);
				}
			}
			else if(g_iRandom1 == -1 && g_iRandom2 == -1)
			{
				DistanceTimerHandle[client] = null;
				return Plugin_Stop;
			}
		}
	}
	
	if(!IsValidClient(client))
	{
		DistanceTimerHandle[client] = null;
		return Plugin_Stop;
	}
		
	return Plugin_Continue;
}

public Action Beacon_Timer(Handle timer, int clientserial)
{
	int client = GetClientFromSerial(clientserial);
	
	if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)
		BeaconPlayer(client);
		
	return Plugin_Handled;
}

public Action Command_Menu(int client, int args)
{
	if(GetConVarBool(g_cvEnabled))
	{
		if(!g_bNoBeacon)
		{
			if(!client)
			{
				ReplyToCommand(client, "%sCannot use this commnad from server rcon", PLUGIN_PREFIX);
				return Plugin_Handled;
			}
			
			if(g_bIsDone)
			{
				
				if(args < 1)
				{
					DisplayBeaconMenu(client);
					return Plugin_Handled;
				}
				
				char buffer[14];
				GetCmdArg(1, buffer, sizeof(buffer));
				
				int arg1 = StringToInt(buffer);
				
				if(arg1 == 1 && g_iRandom1 != -1)
				{
					DisplayMenuForFirst(client);
					return Plugin_Handled;
				}
				else if(arg1 == 2 && g_iRandom2 != -1)
				{
					DisplayMenuForSecond(client);
					return Plugin_Handled;
				}
				else
				{
					CReplyToCommand(client, "%sInvalid number or arguement, Accepted numbers are only 1 and 2.", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
			}
			else if(!g_bIsDone)
			{
				CReplyToCommand(client, "%sNo one has become the beaconed player yet", PLUGIN_PREFIX);
				return Plugin_Handled;
			}
		}
		else
		{
			CReplyToCommand(client, "%sRound is about to end because there is no beaconed player alive", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
	}
	else
	{
		CReplyToCommand(client, "%sHeal beacon is disabled.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_Distance(int client, int args)
{
	if(GetConVarBool(g_cvEnabled))
	{
		if(!g_bNoBeacon)
		{
			if(g_bIsDone)
			{
				if(!client)
				{
					ReplyToCommand(client, "%sCannot use this command from server rcon", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
				
				if(args < 2)
				{
					CReplyToCommand(client, "%sUsage: sm_beacon_distance <1|2> <number>", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
				
				char arg1[64], arg2[64];
				
				GetCmdArg(1, arg1, sizeof(arg1));
				GetCmdArg(2, arg2, sizeof(arg2));
				
				int num1 = StringToInt(arg1);
				float num2 = StringToFloat(arg2);
				
				if(num1 == 1)
				{	
					if(g_iRandom1 != -1)
					{
						g_iClientDistance[g_iRandom1] = num2;
						CReplyToCommand(client, "%sSuccessfully changed {yellow}%N distance to {white}%f.", PLUGIN_PREFIX, g_iRandom1, num2);
						return Plugin_Handled;
					}
					else
					{
						CReplyToCommand(client, "%sPlayer is dead or left the game", PLUGIN_PREFIX);
						return Plugin_Handled;
					}
				}
				else if(num1 == 2)
				{
					if(g_iRandom2 != -1)
					{
						g_iClientDistance[g_iRandom2] = num2;
						CReplyToCommand(client, "%sSuccessfully changed {yellow}%N distance to {white}%f.", PLUGIN_PREFIX, g_iRandom2, num2);
						return Plugin_Handled;
					}
					else
					{
						CReplyToCommand(client, "%sPlayer is dead or left the game", PLUGIN_PREFIX);
						return Plugin_Handled;
					}
				}
				else
				{
					CReplyToCommand(client, "%sUsage: sm_beacon_distance <1|2> <number>", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
			}
			else
			{
				CReplyToCommand(client, "%sNone has been detected as the beaconed player yet", PLUGIN_PREFIX);
				return Plugin_Handled;
			}
		}
		else
		{
			CReplyToCommand(client, "%sRound is about to end because there is no beaconed player alive", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
	}
	else
	{
		CReplyToCommand(client, "%sHeal beacon is not enabled.", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
}

public Action Command_SetHealBeacon(int client, int args)
{
	if(GetConVarBool(g_cvEnabled))
	{
		if(!g_bNoBeacon)
		{
			if(g_bIsDone)
			{
				if(args < 2)
				{
					CReplyToCommand(client, "%sUsage: sm_sethealbeacon 1|2 <Player>", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
				
				
				char sArg1[20];
				char sArg2[60];
				
				GetCmdArg(1, sArg1, 20);
				GetCmdArg(2, sArg2, 60);
				
				int num = StringToInt(sArg1);
				int g_iTarget = FindTarget(client, sArg2, false, false);
				
				if(g_iTarget == -1)
				{
					return Plugin_Handled;
				}
				
				if(g_iTarget == g_iRandom1 || g_iTarget == g_iRandom2)
				{
					CReplyToCommand(client, "%sThe given player is already a beaconed player", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
				
				if(GetClientUserId(g_iTarget) == 0)
				{
					CReplyToCommand(client, "%sPlayer no longer available", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
				
				if(num == 1)
				{
					if(IsValidClient(g_iTarget) && IsPlayerAlive(g_iTarget) && GetClientTeam(g_iTarget) == 3)
					{
						ApplyHealBeacon(g_iTarget, g_iRandom1);
						return Plugin_Handled;
					}
					else if(IsValidClient(g_iTarget) && !IsPlayerAlive(g_iTarget) || GetClientTeam(g_iTarget) < 3)
					{
						CReplyToCommand(client, "%sCannot choose a dead player or zombie", PLUGIN_PREFIX);
						return Plugin_Handled;
					}
				}
				else if(num == 2)
				{
					if(IsValidClient(g_iTarget) && IsPlayerAlive(g_iTarget) && GetClientTeam(g_iTarget) == 3)
					{
						ApplyHealBeacon(g_iTarget, g_iRandom2);
						return Plugin_Handled;
					}
					else if(IsValidClient(g_iTarget) && !IsPlayerAlive(g_iTarget) || GetClientTeam(g_iTarget) < 3)
					{
						CReplyToCommand(client, "%sCannot choose a dead player or zombie", PLUGIN_PREFIX);
						return Plugin_Handled;
					}
				}
				else
				{
					CReplyToCommand(client, "%sUsage: sm_sethealbeacon 1|2 <Player>", PLUGIN_PREFIX);
					return Plugin_Handled;
				}
			}
			else
			{
				CReplyToCommand(client, "%sNo one has become a beaconed player yet", PLUGIN_PREFIX);
				return Plugin_Handled;
			}
		}
		else
		{
			CReplyToCommand(client, "%sRound is about to end because there is no beaconed player alive", PLUGIN_PREFIX);
			return Plugin_Handled;
		}
	}
	else
	{
		CReplyToCommand(client, "%sHeal beacon is currently disabled", PLUGIN_PREFIX);
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}
				
public int Menu_MainCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char buf[64];
		menu.GetItem(param2, buf, sizeof(buf));
		
		if(StrEqual(buf, "option1"))
		{
			DisplayMenuForFirst(param1);
		}
		else if(StrEqual(buf, "option2"))
		{
			DisplayMenuForSecond(param1);
		}
		else if(StrEqual(buf, "option3"))
		{
			DisplaySetBeaconNumsMenu(param1);
		}
		else if(StrEqual(buf, "option4"))
		{
			DisplaySettingsMenu(param1);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}


public int Menu_FirstCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(IsValidClient(g_iRandom1) && g_iRandom1 != -1)
		{
			switch(param2)
			{
				case 0:
				{
					RePickRandom(param1, g_iRandom1);
					CPrintToChat(param1, "%sSuccessfully repicked a random player.", PLUGIN_PREFIX);
					LogAction(param1, -1, "[Heal Beacon] \"%L\" has Repicked a random player.", param1);
					DisplayMenuForFirst(param1);
				}
			
				case 1:
				{
					DisplayBeaconColorsMenuForFirst(param1);
				}

				case 2:
				{
					DisplayBeaconRadiusMenuForFirst(param1);
				}
		
				case 3:
				{
					if(!g_bHasNeon[g_iRandom1])
					{
						SetClientNeon(g_iRandom1);
						CPrintToChat(param1, "%sSuccessfully Enabled light on %N.", PLUGIN_PREFIX, g_iRandom1);
						LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has Enabled Light on \"%L\".", param1, g_iRandom1);
						DisplayMenuForFirst(param1);
					}
					else if(g_bHasNeon[g_iRandom1])
					{
						RemoveNeon(g_iRandom1);
						CPrintToChat(param1, "%sSuccessfully Disabled light on %N.", PLUGIN_PREFIX, g_iRandom1);
						LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has Disabled Light on \"%L\".", param1, g_iRandom1);
						DisplayMenuForFirst(param1);
					}
				}

				case 4:
				{
					DisplayNeonColorsMenuForFirst(param1);
				}

				case 5:
				{
					TeleportToRandom(param1, g_iRandom1);
					CPrintToChat(param1, "%sSuccessfully Teleported to %N.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" Teleported to \"%L\".", param1, g_iRandom1);
					DisplayMenuForFirst(param1);
				}
				case 6:
				{
					TeleportToRandom(g_iRandom1, param1);
					CPrintToChat(param1, "%sSuccessfully Brought %N.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" Brought \"%L\".", param1, g_iRandom1);
					DisplayMenuForFirst(param1);
				}
				case 7:
				{
					CPrintToChat(param1, "%sSuccessfully Slayed %N.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has slayed \"%L\".", param1, g_iRandom1);
					ForcePlayerSuicide(g_iRandom1);
				}
			}
		}
		
		else 
		{
				CPrintToChat(param1, "%sThe player is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayBeaconMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_BeaconColorsFirstCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(g_iRandom1 != -1)
		{
			switch(param2)
			{
				case 0:
				{
					DoProgressBeaconColor(g_iRandom1, g_ColorWhite);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {white}White.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to White.", param1, g_iRandom1);
					DisplayBeaconColorsMenuForFirst(param1);
				}
				case 1:
				{
					DoProgressBeaconColor(g_iRandom1, g_ColorRed);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {fullred}Red.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Red.", param1, g_iRandom1);
					DisplayBeaconColorsMenuForFirst(param1);
				}
				case 2:
				{
					DoProgressBeaconColor(g_iRandom1, g_ColorLime);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {lime}Lime.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Lime.", param1, g_iRandom1);
					DisplayBeaconColorsMenuForFirst(param1);
				}
				case 3:
				{
					DoProgressBeaconColor(g_iRandom1, g_ColorBlue);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {blue}Blue.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Blue.", param1, g_iRandom1);
					DisplayBeaconColorsMenuForFirst(param1);
				}
				case 4:
				{
					DoProgressBeaconColor(g_iRandom1, g_ColorYellow);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {yellow}Yellow.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Yellow.", param1, g_iRandom1);
					DisplayBeaconColorsMenuForFirst(param1);
				}
				case 5:
				{
					DoProgressBeaconColor(g_iRandom1, g_ColorCyan);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {cyan}Cyan.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Cyan.", param1, g_iRandom1);
					DisplayBeaconColorsMenuForFirst(param1);
				}
				case 6:
				{
					DoProgressBeaconColor(g_iRandom1, g_ColorGold);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {gold}Gold.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Gold.", param1, g_iRandom1);
					DisplayBeaconColorsMenuForFirst(param1);
				}
			}
		}
		else
		{
			CPrintToChat(param1, "%sThe player is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenuForFirst(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_NeonColorsFirstCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(g_iRandom1 != -1)
		{
			switch(param2)
			{
				case 0:
				{
					DoProgressNeonColor(g_iRandom1, g_ColorWhite);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {white}White.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to White.", param1, g_iRandom1);
					DisplayNeonColorsMenuForFirst(param1);
				}
				case 1:
				{
					DoProgressNeonColor(g_iRandom1, g_ColorRed);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {fullred}Red.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Red.", param1, g_iRandom1);
					DisplayNeonColorsMenuForFirst(param1);
				}
				case 2:
				{
					DoProgressNeonColor(g_iRandom1, g_ColorLime);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {lime}Lime.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Lime.", param1, g_iRandom1);
					DisplayNeonColorsMenuForFirst(param1);
				}
				case 3:
				{
					DoProgressNeonColor(g_iRandom1, g_ColorBlue);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {blue}Blue.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Blue.", param1, g_iRandom1);
					DisplayNeonColorsMenuForFirst(param1);
				}
				case 4:
				{
					DoProgressNeonColor(g_iRandom1, g_ColorYellow);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {yellow}yellow.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Yellow.", param1, g_iRandom1);
					DisplayNeonColorsMenuForFirst(param1);
				}
				case 5:
				{
					DoProgressNeonColor(g_iRandom1, g_ColorCyan);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {cyan}Cyan.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Cyan.", param1, g_iRandom1);
					DisplayNeonColorsMenuForFirst(param1);
				}
				case 6:
				{
					DoProgressNeonColor(g_iRandom1, g_ColorGold);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {gold}Gold.", PLUGIN_PREFIX, g_iRandom1);
					LogAction(param1, g_iRandom1, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Gold.", param1, g_iRandom1);
					DisplayNeonColorsMenuForFirst(param1);
				}
			}
		}
		else
		{
			CPrintToChat(param1, "%sThe player is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenuForFirst(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_BeaconRadiusFirstCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(g_iRandom1 != -1)
		{
			char buf[64];
			menu.GetItem(param2, buf, sizeof(buf));
			g_iClientDistance[g_iRandom1] = StringToFloat(buf);
			DisplayBeaconRadiusMenuForFirst(param1);
		}
		else
		{
			PrintToChat(param1, "%sPlayer is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenuForFirst(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_SecondCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(g_iRandom2 != -1)
		{
			switch(param2)
			{
				case 0:
				{
					RePickRandom(param1, g_iRandom2);
					CPrintToChat(param1, "%sSuccessfully repicked a random player.", PLUGIN_PREFIX);
					LogAction(param1, -1, "[Heal Beacon] \"%L\" has Repicked a random player.", param1);
					DisplayMenuForSecond(param1);
				}
			
				case 1:
				{
					DisplayBeaconColorsMenuForSecond(param1);
				}

				case 2:
				{
					DisplayBeaconRadiusMenuForSecond(param1);
				}
		
				case 3:
				{
					if(!g_bHasNeon[g_iRandom2])
					{
						SetClientNeon(g_iRandom2);
						CPrintToChat(param1, "%sSuccessfully Enabled light on %N.", PLUGIN_PREFIX, g_iRandom2);
						LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has Enabled Light on \"%L\".", param1, g_iRandom2);
						DisplayMenuForSecond(param1);
					}
					else if(g_bHasNeon[g_iRandom2])
					{
						RemoveNeon(g_iRandom2);
						CPrintToChat(param1, "%sSuccessfully Disabled light on %N.", PLUGIN_PREFIX, g_iRandom2);
						LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has Disabled Light on \"%L\".", param1, g_iRandom2);
						DisplayMenuForSecond(param1);
					}
				}

				case 4:
				{
					DisplayNeonColorsMenuForSecond(param1);
				}

				case 5:
				{
					TeleportToRandom(param1, g_iRandom2);
					CPrintToChat(param1, "%sSuccessfully Teleported to %N.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" Teleported to \"%L\".", param1, g_iRandom2);
					DisplayMenuForSecond(param1);
				}
				case 6:
				{
					TeleportToRandom(g_iRandom2, param1);
					CPrintToChat(param1, "%sSuccessfully Brought %N.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" Brought \"%L\".", param1, g_iRandom2);
					DisplayMenuForSecond(param1);
				}
				case 7:
				{
					CPrintToChat(param1, "%sSuccessfully Slayed %N.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has slayed \"%L\".", param1, g_iRandom2);
					ForcePlayerSuicide(g_iRandom2);
				}
			}
		}
		else 
		{
			CPrintToChat(param1, "%sThe player is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayBeaconMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_BeaconColorsSecondCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(g_iRandom2 != -1)
		{
			switch(param2)
			{
				case 0:
				{
					DoProgressBeaconColor(g_iRandom2, g_ColorWhite);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {white}White.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to White.", param1, g_iRandom2);
					DisplayBeaconColorsMenuForSecond(param1);
				}
				case 1:
				{
					DoProgressBeaconColor(g_iRandom2, g_ColorRed);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {fullred}Red.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Red.", param1, g_iRandom2);
					DisplayBeaconColorsMenuForSecond(param1);
				}
				case 2:
				{
					DoProgressBeaconColor(g_iRandom2, g_ColorLime);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {lime}Lime.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Lime.", param1, g_iRandom2);
					DisplayBeaconColorsMenuForSecond(param1);
				}
				case 3:
				{
					DoProgressBeaconColor(g_iRandom2, g_ColorBlue);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {blue}Blue.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Blue.", param1, g_iRandom2);
					DisplayBeaconColorsMenuForSecond(param1);
				}
				case 4:
				{
					DoProgressBeaconColor(g_iRandom2, g_ColorYellow);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {yellow}Yellow.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Yellow.", param1, g_iRandom2);
					DisplayBeaconColorsMenuForSecond(param1);
				}
				case 5:
				{
					DoProgressBeaconColor(g_iRandom2, g_ColorCyan);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {cyan}Cyan.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Cyan.", param1, g_iRandom2);
					DisplayBeaconColorsMenuForSecond(param1);
				}
				case 6:
				{
					DoProgressBeaconColor(g_iRandom2, g_ColorGold);
					CPrintToChat(param1, "%sSuccessfully changed beacon color on %N to {gold}Gold.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed beacon color on \"%L\" to Gold.", param1, g_iRandom2);
					DisplayBeaconColorsMenuForSecond(param1);
				}
			}
		}
		else
		{
			CPrintToChat(param1, "%sThe player is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenuForSecond(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_NeonColorsSecondCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(g_iRandom2 != -1)
		{
			switch(param2)
			{
				case 0:
				{
					DoProgressNeonColor(g_iRandom2, g_ColorWhite);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {white}White.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to White.", param1, g_iRandom2);
					DisplayNeonColorsMenuForSecond(param1);
				}
				case 1:
				{
					DoProgressNeonColor(g_iRandom2, g_ColorRed);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {fullred}Red.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Red.", param1, g_iRandom2);
					DisplayNeonColorsMenuForSecond(param1);
				}
				case 2:
				{
					DoProgressNeonColor(g_iRandom2, g_ColorLime);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {lime}Lime.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Lime.", param1, g_iRandom2);
					DisplayNeonColorsMenuForSecond(param1);
				}
				case 3:
				{
					DoProgressNeonColor(g_iRandom2, g_ColorBlue);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {blue}Blue.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Blue.", param1, g_iRandom2);
					DisplayNeonColorsMenuForSecond(param1);
				}
				case 4:
				{
					DoProgressNeonColor(g_iRandom2, g_ColorYellow);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {yellow}yellow.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Yellow.", param1, g_iRandom2);
					DisplayNeonColorsMenuForSecond(param1);
				}
				case 5:
				{
					DoProgressNeonColor(g_iRandom2, g_ColorCyan);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {cyan}Cyan.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Cyan.", param1, g_iRandom2);
					DisplayNeonColorsMenuForSecond(param1);
				}
				case 6:
				{
					DoProgressNeonColor(g_iRandom2, g_ColorGold);
					CPrintToChat(param1, "%sSuccessfully changed Light color on %N to {gold}Gold.", PLUGIN_PREFIX, g_iRandom2);
					LogAction(param1, g_iRandom2, "[Heal Beacon] \"%L\" has changed Light color on \"%L\" to Gold.", param1, g_iRandom2);
					DisplayNeonColorsMenuForSecond(param1);
				}
			}
		}
		else
		{
			CPrintToChat(param1, "%sThe player is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenuForSecond(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_BeaconRadiusSecondCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		if(g_iRandom2 != -1)
		{
			char buf[64];
			menu.GetItem(param2, buf, sizeof(buf));
			g_iClientDistance[g_iRandom2] = StringToFloat(buf);
			DisplayBeaconRadiusMenuForSecond(param1);
			CPrintToChat(param1, "%sBeacon distance on %N has been changed to %f", PLUGIN_PREFIX, g_iRandom2, g_iClientDistance[g_iRandom2]);
		}
		else
		{
			PrintToChat(param1, "%sPlayer is dead or left the game", PLUGIN_PREFIX);
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			DisplayMenuForSecond(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_SetBeaconNumsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				DisplaySetBeaconFirstMenu(param1);
			}
			case 1:
			{
				DisplaySetBeaconSecondMenu(param1);
			}
		}
	}
	else if(action == MenuAction_End)
		delete menu;

	return 0;
}

public int Menu_SetBeaconFirstMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char buf[32];
		int userid, target;
		
		menu.GetItem(param2, buf, sizeof(buf));
		userid = StringToInt(buf);
		target = GetClientOfUserId(userid);
		
		if ((GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "%sPlayer no longer available", PLUGIN_PREFIX);
		}
		else
		{
			if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target) == 3)
			{
				if(target == g_iRandom1 || target == g_iRandom2)
				{
					CPrintToChat(param1, "%sThe player is already a beaconed player", PLUGIN_PREFIX);
				}
				else
				{
					ApplyHealBeacon(target, g_iRandom1);
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && menu)
		{
			DisplaySetBeaconNumsMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_SetBeaconSecondMenu(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char buf[32];
		int userid, target;
		
		menu.GetItem(param2, buf, sizeof(buf));
		userid = StringToInt(buf);
		target = GetClientOfUserId(userid);
		
		if ((GetClientOfUserId(userid)) == 0)
		{
			CPrintToChat(param1, "%sPlayer no longer available", PLUGIN_PREFIX);
		}
		else
		{
			if(IsValidClient(target) && IsPlayerAlive(target) && GetClientTeam(target) == 3)
			{
				if(target == g_iRandom1 || target == g_iRandom2)
				{
					CPrintToChat(param1, "%sThe player is already a beaconed player", PLUGIN_PREFIX);
				}
				else
				{
					ApplyHealBeacon(target, g_iRandom2);
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && menu)
		{
			DisplaySetBeaconNumsMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
}

public int Menu_SettingsCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		switch(param2)
		{
			case 0:
			{
				DisplayBeaconDamageMenu(param1);
			}
			case 1:
			{
				DisplayBeaconTimerMenu(param1);
			}
			case 2:
			{
				DisplayBeaconLifeTimeMenu(param1);
			}
			case 3:
			{
				if(!g_bModeIsEnabled)
				{
					CPrintToChat(param1, "%sBetter Damage Mode has been {yellow}enabled!", PLUGIN_PREFIX);
					g_bModeIsEnabled = true;
				}
					
				else if(g_bModeIsEnabled)
				{	
					CPrintToChat(param1, "%sBetter Damage Mode has been {yellow}disabled!", PLUGIN_PREFIX);
					g_bModeIsEnabled = false;
				}
					
				DisplaySettingsMenu(param1);
			}
		}
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			DisplayBeaconMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
		
	return 0;
		
}

public int Menu_BeaconDamageCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char buf[32];
		menu.GetItem(param2, buf, 32);
		
		int num = StringToInt(buf);
		
		g_cvDamage.IntValue = num;
		
		CPrintToChat(param1, "%sBeacon Damage has been changed to %d", PLUGIN_PREFIX, num);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			DisplaySettingsMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
	
}

public int Menu_BeaconTimerCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char buf[32];
		menu.GetItem(param2, buf, 32);
		
		float num = StringToFloat(buf);
		
		g_cvTimer.FloatValue = num;
		
		CPrintToChat(param1, "%sBeacon First PickRandom Timer has been changed to %f", PLUGIN_PREFIX, num);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			DisplaySettingsMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
	
}

public int Menu_BeaconLifeTimeCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if(action == MenuAction_Select)
	{
		char buf[32];
		menu.GetItem(param2, buf, 32);
		
		float num = StringToFloat(buf);
		
		g_cvLifeTime.FloatValue = num;
		
		CPrintToChat(param1, "%sBeacon Life Time has been changed to %f", PLUGIN_PREFIX, num);
	}
	else if(action == MenuAction_Cancel)
	{
		if(param2 == MenuCancel_ExitBack)
		{
			DisplaySettingsMenu(param1);
		}
	}
	else if(action == MenuAction_End)
		delete menu;
		
	return 0;
	
}
		
void BeaconPlayerTimer(int client)
{	
		if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3)		
			BeaconTimer[client] = CreateTimer(1.0, Beacon_Timer, GetClientSerial(client), TIMER_REPEAT);
}

void BeaconPlayer(int client)
{
	if(IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3 && g_BeaconPlayer[client] != 0)
	{
		float fvec[3];
		GetClientAbsOrigin(client, fvec);
		fvec[2] += 10;
		
		TE_SetupBeamRingPoint(fvec, g_iClientDistance[client] - 1.0, g_iClientDistance[client], g_LaserSprite, g_HaloSprite, 0, 10, g_cvLifeTime.FloatValue, 10.0, 0.5, g_iClientBeaconColor[client], 10, 0);
	
		TE_SendToAll();
			
		GetClientEyePosition(client, fvec);
		//EmitAmbientSound(Beacon_Sound, fvec, client, SNDLEVEL_RAIDSIREN);
	}
	else
	{
		return;
	}
}

float GetDistanceBetween(int origin, int target)
{
	float fOrigin[3], fTarget[3];
	
	GetEntPropVector(origin, Prop_Data, "m_vecOrigin", fOrigin);
	GetEntPropVector(target, Prop_Data, "m_vecOrigin", fTarget);
	
	return GetVectorDistance(fOrigin, fTarget);
}

void GetFirstRandom()
{
	int g_iClients[MAXPLAYERS+1];
	int g_iCount = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3)
		{
			g_iClients[g_iCount++] = i;
		}
	}
	
	if(g_iCount >= 2)
	{
		g_bIsDone = true;
		g_iRandom1 = g_iClients[GetRandomInt(0, g_iCount - 1)];
		CPrintToChatAll("%sPlayer %N is the first beaconed player.", PLUGIN_PREFIX, g_iRandom1);
		g_BeaconPlayer[g_iRandom1] = 1;
		BeaconPlayerTimer(g_iRandom1);		
	}
	else
	{
		return;
	}
}

void GetSecondRandom()
{
	int g_iClients[MAXPLAYERS+1];
	int g_iCount = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3 && i != g_iRandom1)
		{
			g_iClients[g_iCount++] = i;
		}
	}
	
	if(g_iCount >= 2)
	{
		g_iRandom2 = g_iClients[GetRandomInt(0, g_iCount - 1)];
		CPrintToChatAll("%sPlayer %N is the second beaconed player.", PLUGIN_PREFIX, g_iRandom2);
		g_BeaconPlayer[g_iRandom2] = 1;
		BeaconPlayerTimer(g_iRandom2);		
	}
}

void RePickRandom(int client, int remove)
{
	int g_iClients[MAXPLAYERS+1];
	int g_iCount = 0;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == 3 && i != g_iRandom1 && i != g_iRandom2)
		{
			g_iClients[g_iCount++] = i;
		}
	}
	
	if(g_iCount >= 2)
	{
		if(remove == g_iRandom1 && g_iRandom1 != -1)
		{
			char sName[64];
			GetClientName(g_iRandom1, sName, 64);
			
			g_BeaconPlayer[g_iRandom1] = 0;
			delete BeaconTimer[g_iRandom1];
			RemoveNeon(g_iRandom1);
			
			g_iRandom1 = -1;
		
			g_iRandom1 = g_iClients[GetRandomInt(0, g_iCount - 1)];
			
			g_BeaconPlayer[g_iRandom1] = 1;
			
			BeaconPlayerTimer(g_iRandom1);
			CPrintToChatAll("%s{yellow}%N {white}is the new beaconed player instead of {yellow}%s {white}repicked by {yellow}%N", PLUGIN_PREFIX, g_iRandom1, sName, client);
		}
		else if(remove == g_iRandom2 && g_iRandom2 != -1)
		{
			char sName[64];
			GetClientName(g_iRandom2, sName, 64);
			
			g_BeaconPlayer[g_iRandom2] = 0;
			delete BeaconTimer[g_iRandom2];
			RemoveNeon(g_iRandom2);
			
			g_iRandom2 = -1;
		
			g_iRandom2 = g_iClients[GetRandomInt(0, g_iCount - 1)];
			
			g_BeaconPlayer[g_iRandom2] = 2;
			
			BeaconPlayerTimer(g_iRandom2);
			CPrintToChatAll("%s{yellow}%N {white}is the new beaconed player instead of {yellow}%s {white}repicked by {yellow}%N", PLUGIN_PREFIX, g_iRandom2, sName, client);
		}
	}
}

void ApplyHealBeacon(client, int random)
{
	if(random == g_iRandom1 && g_iRandom1 == -1)
	{
		g_iRandom1 = client;
		g_BeaconPlayer[client] = 1;
		
		BeaconPlayerTimer(client);
		CPrintToChatAll("%s%N has been a beaconed player", PLUGIN_PREFIX, client);
	}
	else if(random == g_iRandom1 && g_iRandom1 != -1)
	{
		char sName[64];
		GetClientName(g_iRandom1, sName, 64);
		
		g_BeaconPlayer[g_iRandom1] = 0;
		delete BeaconTimer[g_iRandom1];
		RemoveNeon(g_iRandom1);
		g_iRandom1 = -1;
		
			
		g_iRandom1 = client;
		g_BeaconPlayer[client] = 1;
		
		BeaconPlayerTimer(client);
		
		CPrintToChatAll("%s%N has been a beaconed player as a replacement of {yellow}%s.", PLUGIN_PREFIX, client, sName);
	}
	else if(random == g_iRandom2 && g_iRandom2 == -1)
	{
		g_iRandom2 = client;
		g_BeaconPlayer[client] = 2;
		
		BeaconPlayerTimer(client);
		CPrintToChatAll("%s%N has been a beaconed player", PLUGIN_PREFIX, client);
	}
	else if(random == g_iRandom2 && g_iRandom2 != -1)
	{
		char sName[64];
		GetClientName(g_iRandom2, sName, 64);
		
		g_BeaconPlayer[g_iRandom2] = 0;
		RemoveNeon(g_iRandom2);
		delete BeaconTimer[g_iRandom2];
		g_iRandom2 = -1;
		
			
		g_iRandom2 = client;
		g_BeaconPlayer[client] = 2;
		
		BeaconPlayerTimer(client);
		
		CPrintToChatAll("%s%N has been a beaconed player as a replacement of {yellow}%s.", PLUGIN_PREFIX, client, sName);
	}
}
		
void DealDamage(int client, int nDamage, int nDamageType = DMG_GENERIC)
{
	if(IsValidClient(client) && IsPlayerAlive(client) && nDamage > 0)
    {
        EntityPointHurt = CreateEntityByName("point_hurt");
        if(EntityPointHurt != 0)
        {
            char sDamage[16];
            IntToString(nDamage, sDamage, sizeof(sDamage));

            char sDamageType[32];
            IntToString(nDamageType, sDamageType, sizeof(sDamageType));

            DispatchKeyValue(client,			"targetname",		"war3_hurtme");
            DispatchKeyValue(EntityPointHurt,		"DamageTarget",	"war3_hurtme");
            DispatchKeyValue(EntityPointHurt,		"Damage",				sDamage);
            DispatchKeyValue(EntityPointHurt,		"DamageType",		sDamageType);
            DispatchSpawn(EntityPointHurt);
            AcceptEntityInput(EntityPointHurt, "Hurt");
            DispatchKeyValue(EntityPointHurt,		"classname",		"point_hurt");
            DispatchKeyValue(client,			"targetname",		"war3_donthurtme");
            
            RemoveEdict(EntityPointHurt);
        }
        return;
    }
}

void DeleteAllHandles(int client)
{
	BeaconTimer[client] = null;
	g_hHudTimer[client] = null;
	g_hDistanceTimer[client] = null;
	DistanceTimerHandle[client] = null;
	
	
	if(BeaconTimer[client] != INVALID_HANDLE)
		delete BeaconTimer[client];
					
	if(g_hHudTimer[client] != INVALID_HANDLE)
		delete g_hHudTimer[client];
					
	if(g_hDistanceTimer[client] != INVALID_HANDLE)
		delete g_hDistanceTimer[client];
						
	if(DistanceTimerHandle[client] != INVALID_HANDLE)
		delete DistanceTimerHandle[client];
}


void DisplayBeaconMenu(int client)
{
	Menu menu = new Menu(Menu_MainCallback);
	
	char title[64];
	Format(title, sizeof(title), "Do an Action on the heal beaconed players");
	menu.SetTitle(title);
	
	char buffer1[64], buffer2[64];
	
	if(g_iRandom1 != -1)
	{
		Format(buffer1, sizeof(buffer1), "Do Actions on %N", g_iRandom1);
		menu.AddItem("option1", buffer1, (g_iRandom1 == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	if(g_iRandom2 != -1)
	{
		Format(buffer2, sizeof(buffer2), "Do Actions on %N", g_iRandom2);
		menu.AddItem("option2", buffer2, (g_iRandom2 == -1) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	menu.AddItem("empty1", "", ITEMDRAW_SPACER);
	menu.AddItem("empty2", "", ITEMDRAW_SPACER);
	
	menu.AddItem("option3", "Set Heal Beacon on a Player");
	menu.AddItem("option4", "Change Heal Beacon Settings");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplaySettingsMenu(int client)
{
	Menu menu = new Menu(Menu_SettingsCallback);
	char title[64];
	Format(title, sizeof(title), "Change Heal Beacon Settings");
	menu.SetTitle(title);
	
	menu.AddItem("0", "Change Heal Beacon Damage");
	menu.AddItem("1", "Change The first pick timer");
	menu.AddItem("2", "Change Heal Beacon lifetime");
	menu.AddItem("4", "Toggle better damage mode");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBeaconDamageMenu(int client)
{
	Menu menu = new Menu(Menu_BeaconDamageCallback);
	char title[64];
	Format(title, sizeof(title), "Change Heal Beacon Settings");
	menu.SetTitle(title);
	
	menu.AddItem("1", "1");
	menu.AddItem("2", "2");
	menu.AddItem("5", "5");
	menu.AddItem("7", "7");
	menu.AddItem("8", "8");
	menu.AddItem("10", "10");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBeaconTimerMenu(int client)
{
	Menu menu = new Menu(Menu_BeaconTimerCallback);
	char title[64];
	Format(title, sizeof(title), "Change Heal Beacon Settings");
	menu.SetTitle(title);
	
	menu.AddItem("10", "10");
	menu.AddItem("20", "20");
	menu.AddItem("25", "25");
	menu.AddItem("30", "30");
	menu.AddItem("40", "40");
	menu.AddItem("60", "60");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBeaconLifeTimeMenu(int client)
{
	Menu menu = new Menu(Menu_BeaconLifeTimeCallback);
	char title[64];
	Format(title, sizeof(title), "Change Heal Beacon Settings");
	menu.SetTitle(title);
	
	menu.AddItem("0.2", "0.2");
	menu.AddItem("0.4", "0.4");
	menu.AddItem("0.6", "0.6");
	menu.AddItem("0.8", "0.8");
	menu.AddItem("1.0", "1.0");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}
		
void DisplayMenuForFirst(int client)
{
	Menu menu = new Menu(Menu_FirstCallback);
	
	char title[64];
	Format(title, sizeof(title), "Do an Action on %N", g_iRandom1);
	menu.SetTitle(title);
	
	menu.AddItem("0", "Repick randomly");
	menu.AddItem("1", "Change Beacon Color");
	menu.AddItem("2", "Change beacon radius and distance");
	menu.AddItem("3", "Toggle Light on the player");
	menu.AddItem("4", "Change light color on the player", (g_bHasNeon[g_iRandom1] == true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem("5", "Teleport to player");
	menu.AddItem("6", "Bring Player");
	menu.AddItem("7", "Slay Player");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayMenuForSecond(int client)
{
	Menu menu = new Menu(Menu_SecondCallback);
	
	char title[64];
	Format(title, sizeof(title), "Do an Action on %N", g_iRandom2);
	menu.SetTitle(title);
	
	menu.AddItem("0", "Repick randomly");
	menu.AddItem("1", "Change Beacon Color");
	menu.AddItem("2", "Change beacon radius and distance");
	menu.AddItem("3", "Toggle Light on the player");
	menu.AddItem("4", "Change light color on the player", (g_bHasNeon[g_iRandom2] == true) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	menu.AddItem("5", "Teleport to player");
	menu.AddItem("6", "Bring Player");
	menu.AddItem("7", "Slay Player");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBeaconColorsMenuForFirst(int client)
{
	Menu menu = new Menu(Menu_BeaconColorsFirstCallback);
	
	char title[64];
	Format(title, sizeof(title), "Change beacon color on %N", g_iRandom1);
	menu.SetTitle(title);
	
	menu.AddItem("0", "White");
	menu.AddItem("1", "Red");
	menu.AddItem("2", "Lime");
	menu.AddItem("3", "Blue");
	menu.AddItem("4", "Yellow");
	menu.AddItem("5", "Cyan");
	menu.AddItem("6", "Gold");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBeaconColorsMenuForSecond(int client)
{
	Menu menu = new Menu(Menu_BeaconColorsSecondCallback);
	
	char title[64];
	Format(title, sizeof(title), "Change beacon color on %N", g_iRandom2);
	menu.SetTitle(title);
	
	menu.AddItem("0", "White");
	menu.AddItem("1", "Red");
	menu.AddItem("2", "Lime");
	menu.AddItem("3", "Blue");
	menu.AddItem("4", "Yellow");
	menu.AddItem("5", "Cyan");
	menu.AddItem("6", "Gold");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayNeonColorsMenuForFirst(int client)
{
	Menu menu = new Menu(Menu_NeonColorsFirstCallback);
	
	char title[64];
	Format(title, sizeof(title), "Change beacon color on", g_iRandom1);
	menu.SetTitle(title);
	
	menu.AddItem("0", "White");
	menu.AddItem("1", "Red");
	menu.AddItem("2", "Lime");
	menu.AddItem("3", "Blue");
	menu.AddItem("4", "Yellow");
	menu.AddItem("5", "Cyan");
	menu.AddItem("6", "Gold");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayNeonColorsMenuForSecond(int client)
{
	Menu menu = new Menu(Menu_NeonColorsSecondCallback);
	
	char title[64];
	Format(title, sizeof(title), "Change beacon color on %N", g_iRandom2);
	menu.SetTitle(title);
	
	menu.AddItem("0", "White");
	menu.AddItem("1", "Red");
	menu.AddItem("2", "Lime");
	menu.AddItem("3", "Blue");
	menu.AddItem("4", "Yellow");
	menu.AddItem("5", "Cyan");
	menu.AddItem("6", "Gold");
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBeaconRadiusMenuForFirst(int client)
{
	Menu menu = new Menu(Menu_BeaconRadiusFirstCallback);
	
	char title[64];
	Format(title, sizeof(title), "Change beacon radius and distance on %N", g_iRandom1);
	menu.SetTitle(title);

	char buf00[64], buf10[64];
	char buf01[64], buf20[64];
	char buf02[64], buf30[64];
	char buf03[64], buf40[64];
	char buf04[64], buf50[64];
	char buf05[64], buf60[64];
	
	for (int i = 0; i <= 1500; i++)
	{
		if(i == 200)
		{
			IntToString(i, buf00, sizeof(buf00));
			Format(buf10, sizeof(buf10), "%d", i);
			menu.AddItem(buf00, buf10);
		}
		if(i == 400)
		{
			IntToString(i, buf01, sizeof(buf01));
			Format(buf20, sizeof(buf20), "%d", i);
			menu.AddItem(buf01, buf20);
		}
		if(i == 600)
		{
			IntToString(i, buf02, sizeof(buf02));
			Format(buf30, sizeof(buf30), "%d", i);
			menu.AddItem(buf02, buf30);
		}
		if(i == 800)
		{
			IntToString(i, buf03, sizeof(buf03));
			Format(buf40, sizeof(buf40), "%d", i);
			menu.AddItem(buf03, buf40);
		}
		if(i == 1000)
		{
			IntToString(i, buf04, sizeof(buf04));
			Format(buf50, sizeof(buf50), "%d", i);
			menu.AddItem(buf04, buf50);
		}
		if(i == 1500)
		{
			IntToString(i, buf05, sizeof(buf05));
			Format(buf60, sizeof(buf60), "%d", i);
			menu.AddItem(buf05, buf60);
		}
	}
	
	menu.AddItem("Empty", "These are the available distances please type sm_beacon_distance <1|2> <your number> instead", ITEMDRAW_DISABLED);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayBeaconRadiusMenuForSecond(int client)
{
	Menu menu = new Menu(Menu_BeaconRadiusSecondCallback);
	
	char title[64];
	Format(title, sizeof(title), "Change beacon radius and distance on %N", g_iRandom2);
	menu.SetTitle(title);

	char buf00[64], buf10[64];
	char buf01[64], buf20[64];
	char buf02[64], buf30[64];
	char buf03[64], buf40[64];
	char buf04[64], buf50[64];
	char buf05[64], buf60[64];
	
	for (int i = 0; i <= 1500; i++)
	{
		if(i == 200)
		{
			IntToString(i, buf00, sizeof(buf00));
			Format(buf10, sizeof(buf10), "%d", i);
			menu.AddItem(buf00, buf10);
		}
		if(i == 400)
		{
			IntToString(i, buf01, sizeof(buf01));
			Format(buf20, sizeof(buf20), "%d", i);
			menu.AddItem(buf01, buf20);
		}
		if(i == 600)
		{
			IntToString(i, buf02, sizeof(buf02));
			Format(buf30, sizeof(buf30), "%d", i);
			menu.AddItem(buf02, buf30);
		}
		if(i == 800)
		{
			IntToString(i, buf03, sizeof(buf03));
			Format(buf40, sizeof(buf40), "%d", i);
			menu.AddItem(buf03, buf40);
		}
		if(i == 1000)
		{
			IntToString(i, buf04, sizeof(buf04));
			Format(buf50, sizeof(buf50), "%d", i);
			menu.AddItem(buf04, buf50);
		}
		if(i == 1500)
		{
			IntToString(i, buf05, sizeof(buf05));
			Format(buf60, sizeof(buf60), "%d", i);
			menu.AddItem(buf05, buf60);
		}
	}
	
	menu.AddItem("Empty", "These are the available distances please type sm_beacon_distance <1|2> <your number> instead", ITEMDRAW_DISABLED);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplaySetBeaconNumsMenu(int client)
{
	Menu menu = new Menu(Menu_SetBeaconNumsMenu);
	
	char title[64];
	Format(title, sizeof(title), "Choose one index");
	menu.SetTitle(title);
	
	menu.AddItem("0", "1");
	menu.AddItem("1", "2");
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplaySetBeaconFirstMenu(int client)
{
	Menu menu = new Menu(Menu_SetBeaconFirstMenu);
	
	char title[64];
	Format(title, sizeof(title), "Choose a player");
	menu.SetTitle(title);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_ALIVE | COMMAND_FILTER_CONNECTED);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplaySetBeaconSecondMenu(int client)
{
	Menu menu = new Menu(Menu_SetBeaconSecondMenu);
	
	char title[64];
	Format(title, sizeof(title), "Choose a player");
	menu.SetTitle(title);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_ALIVE | COMMAND_FILTER_CONNECTED);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

void SetClientNeon(int client)
{
	RemoveNeon(client);
	
	g_iNeon[client] = CreateEntityByName("light_dynamic");
	
	if(!IsValidEntity(g_iNeon[client]))
	{
		return;
	}
	
	g_bHasNeon[client] = true;
	
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	fOrigin[2] += 5;
	
	char sColor[64];
	Format(sColor, sizeof(sColor), "%i %i %i %i", g_iClientNeonColor[client][0], g_iClientNeonColor[client][1], g_iClientNeonColor[client][2], g_iClientNeonColor[client][3]);
	
	DispatchKeyValue(g_iNeon[client], "_light", sColor);
	DispatchKeyValue(g_iNeon[client], "brightness", "5");
	DispatchKeyValue(g_iNeon[client], "distance", "150");
	DispatchKeyValue(g_iNeon[client], "spotlight_radius", "50");
	DispatchKeyValue(g_iNeon[client], "style", "0");
	DispatchSpawn(g_iNeon[client]);
	AcceptEntityInput(g_iNeon[client], "TurnOn");
	
	TeleportEntity(g_iNeon[client], fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(g_iNeon[client], "SetParent", client);
}

void RemoveNeon(int client)
{
	if(g_iNeon[client] && IsValidEntity(g_iNeon[client]))
	{
		AcceptEntityInput(g_iNeon[client], "KillHierarchy");
	}
	
	g_bHasNeon[client] = false;
	
	g_iNeon[client] = -1;
}

void TeleportToRandom(int client, int random)
{
	float fOrigin[3];
	GetClientAbsOrigin(random, fOrigin);
	fOrigin[2] += 5;
	
	TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR);
}

void ResetValues(int client)
{
	iCount[client] = 0;
	g_BeaconPlayer[client] = 0;
}

void DoProgressBeaconColor(int random, int color[4])
{
	if(random != -1)
	{
		g_iClientBeaconColor[random][0] = color[0];
		g_iClientBeaconColor[random][1] = color[1];
		g_iClientBeaconColor[random][2] = color[2];
		g_iClientBeaconColor[random][3] = color[3];
	}
	else
	{
		return;
	}
}

void DoProgressNeonColor(int random, int color[4])
{
	if(random != -1)
	{
		g_iClientNeonColor[random][0] = color[0];
		g_iClientNeonColor[random][1] = color[1];
		g_iClientNeonColor[random][2] = color[2];
		g_iClientNeonColor[random][3] = color[3];
	
		SetClientNeon(random);
	}
	else
	{
		return;
	}
}

void EndRound()
{
	g_hRoundEndTimer = CreateTimer(2.0, RoundEnd_Timer);
	CPrintToChatAll("%sNo beaconed players found, round ending in 2 seconds and will be considered as a Zombies Win", PLUGIN_PREFIX);
	g_bNoBeacon = true;
}

bool IsValidClient(int client)
{
	return (1 <= client <= MaxClients && IsClientInGame(client) && !IsClientSourceTV(client));
}
