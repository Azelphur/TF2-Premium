#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <clientprefs>

#define NO_ATTACH 0
#define ATTACH_NORMAL 1
#define ATTACH_HEAD 2

new Handle:g_hParticles[MAXPLAYERS+1]; // List of particle edicts so we can remove them at appropriate times
new Handle:g_hParticleNames[MAXPLAYERS+1]; // List of particle names so we can remove them at appropriate times
new Handle:g_hParticleTrie[MAXPLAYERS+1];
new Handle:g_hEffects[MAXPLAYERS+1]; // List of enabled effect titles so we can re-enable the particles at appropriate times

new Handle:g_hConfig;

new bool:g_bIsStealth[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name        = "Particles",
	author      = "Azelphur",
	description = "Place cool particle effects on players.",
	version     = "1.0",
	url         = "http://www.azelphur.com"
};

public OnPluginStart() {
	RegAdminCmd("sm_particle", Command_Particle, ADMFLAG_CUSTOM1, "Get a glow!");
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	g_hConfig = CreateKeyValues("Particles");
	decl String:szPath[256];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/particles.cfg");
	if (FileExists(szPath))
	{
		FileToKeyValues(g_hConfig, szPath);
	} else
	{
		SetFailState("File Not Found: %s", szPath);
	}
	for (new i = 0; i < MAXPLAYERS; i++)
	{
		g_hParticles[i] = CreateArray();
		g_hParticleNames[i] = CreateArray(256);
		g_hParticleTrie[i] = CreateTrie();
		g_hEffects[i] = CreateArray(256);
	}
	
	new Handle:hCookie;
	decl String:szTitle[64];
	KvGotoFirstSubKey(g_hConfig);
	do
	{
		KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
		hCookie = RegClientCookie(szTitle, szTitle, CookieAccess_Public);
		CloseHandle(hCookie);
	} while (KvGotoNextKey(g_hConfig));
	KvRewind(g_hConfig);
}

public OnClientConnected(client)
{
	ClearArray(g_hParticles[client]);
	ClearArray(g_hParticleNames[client]);
	ClearTrie(g_hParticleTrie[client]);
	ClearArray(g_hEffects[client]);
}

public OnClientCookiesCached(client)
{
	KvGotoFirstSubKey(g_hConfig);
	new Handle:hCookie;
	decl String:szTitle[64], String:szCookie[64];
	do
	{
		KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
		hCookie = FindClientCookie(szTitle);
		if (hCookie != INVALID_HANDLE) {
			GetClientCookie(client, hCookie, szCookie, sizeof(szCookie));
			if (StrEqual(szCookie, "1"))
			{
			    SetTrieValue(g_hParticleTrie[client], szTitle, 1);
			    PushArrayString(g_hEffects[client], szTitle);
			}
			CloseHandle(hCookie);
		}
	} while (KvGotoNextKey(g_hConfig));
	KvRewind(g_hConfig);
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	RemoveAllParticles(client);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new userid = GetEventInt(event, "userid");
	CreateTimer(0.0, SpawnPost, userid);
}

public Action:SpawnPost(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client)
	{
		RemoveAllParticles(client);
		AddAllParticles(client);
	}
}

public Action:Command_Particle(client, args)
{
	decl String:szCmdArgString[256];
	GetCmdArgString(szCmdArgString, sizeof(szCmdArgString));
	
	if (StrEqual(szCmdArgString, ""))
	{
		ShowParticleMenu(client);
		return Plugin_Handled;
	}
	new iEnabled = 0;
	GetTrieValue(g_hParticleTrie[client], szCmdArgString, iEnabled);
	if (iEnabled)
		DisableParticle(client, szCmdArgString);
	else
		Particle(client, szCmdArgString);
	return Plugin_Handled;
}

ShowParticleMenu(client, slot=0)
{
	decl String:szTitle[256], String:szMenuItem[256];
	new Handle:hMenu = CreateMenu(ParticleMenuHandler);
	SetMenuTitle(hMenu, "Visual effects [/particle]");
	KvGotoFirstSubKey(g_hConfig);
	do
	{
		KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
		new iEnabled = 0;
		GetTrieValue(g_hParticleTrie[client], szTitle, iEnabled);
		if (iEnabled)
			Format(szMenuItem, sizeof(szMenuItem), "Turn off %s", szTitle);
		else
			Format(szMenuItem, sizeof(szMenuItem), "Turn on %s", szTitle);
		AddMenuItem(hMenu, szTitle, szMenuItem);
	} while (KvGotoNextKey(g_hConfig));
	KvRewind(g_hConfig);
	DisplayMenuAtItem(hMenu, client, slot, MENU_TIME_FOREVER);
}

public ParticleMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
	/* If an option was selected, tell the client about the item. */
	if (action == MenuAction_Select)
	{
		new String:info[256];
		GetMenuItem(menu, param2, info, sizeof(info));
		new iEnabled = 0;
		GetTrieValue(g_hParticleTrie[param1], info, iEnabled);
		if (iEnabled)
			DisableParticle(param1, info);
		else
			Particle(param1, info);
		ShowParticleMenu(param1, (param2/7)*7);
	}
	/* If the menu was cancelled, print a message to the server about it. */
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

DisableParticle(client, const String:effect[])
{
	decl String:szTitle[256], String:szClassName[256];
	new iParticle;
	for (new i = 0; i < GetArraySize(g_hParticles[client]); i++)
	{
		GetArrayString(g_hParticleNames[client], i, szTitle, sizeof(szTitle));
		if (StrEqual(effect, szTitle))
		{
			iParticle = GetArrayCell(g_hParticles[client], i);
			if (IsValidEdict(iParticle))
			{
				GetEdictClassname(iParticle, szClassName, sizeof(szClassName));
				if (StrEqual(szClassName, "info_particle_system", false))
					RemoveEdict(iParticle);
			}
			RemoveFromArray(g_hParticles[client], i);
			RemoveFromArray(g_hParticleNames[client], i);
			i--;
		}
	}
	new Handle:hCookie;
	for (new i = 0; i < GetArraySize(g_hEffects[client]); i++)
	{
		GetArrayString(g_hEffects[client], i, szTitle, sizeof(szTitle));
		if (StrEqual(effect, szTitle))
		{
			RemoveFromArray(g_hEffects[client], i);
			hCookie = FindClientCookie(szTitle);
			SetClientCookie(client, hCookie, "0");
			CloseHandle(hCookie);
		}
	}

	RemoveFromTrie(g_hParticleTrie[client], effect);
}

Particle(client, const String:effect[], bool:update=true) {
	new flags = GetUserFlagBits(client);
	if ((flags & ADMFLAG_CUSTOM1) != ADMFLAG_CUSTOM1 && (flags & ADMFLAG_ROOT) != ADMFLAG_ROOT)
		return;
	decl String:szTitle[256], String:szAttach[32];
	new Handle:hCookie;
	KvGotoFirstSubKey(g_hConfig);
	do
	{
		KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
		if (StrEqual(szTitle, effect, false))
		{
			if (update)
				PushArrayString(g_hEffects[client], effect);
			SetTrieValue(g_hParticleTrie[client], szTitle, 1);
			hCookie = FindClientCookie(szTitle);
			SetClientCookie(client, hCookie, "1");
			CloseHandle(hCookie);
			KvGotoFirstSubKey(g_hConfig);
			do
			{
				KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
				KvGetString(g_hConfig, "attach", szAttach, sizeof(szAttach));
				if (StrEqual(szAttach, "NORMAL", false))
					CreateParticle(szTitle, 300.0, client, ATTACH_NORMAL, KvGetFloat(g_hConfig, "x", 0.0), KvGetFloat(g_hConfig, "y", 0.0), KvGetFloat(g_hConfig, "z", 0.0), effect);
			} while (KvGotoNextKey(g_hConfig));
			KvGoBack(g_hConfig);
		}
	} while (KvGotoNextKey(g_hConfig));
	KvRewind(g_hConfig);
}

RemoveAllParticles(client)
{
	new iParticle;
	decl String:szClassName[64];
	for (new i = 0; i < GetArraySize(g_hParticles[client]); i++)
	{
		iParticle = GetArrayCell(g_hParticles[client], i);
		if (IsValidEdict(iParticle))
		{
			GetEdictClassname(iParticle, szClassName, sizeof(szClassName));
			if (StrEqual(szClassName, "info_particle_system", false))
				RemoveEdict(iParticle);
		}
	}
	ClearArray(g_hParticles[client]);
}

AddAllParticles(client)
{
	decl String:szTitle[256];
	for (new i = 0; i < GetArraySize(g_hEffects[client]); i++)
	{
		GetArrayString(g_hEffects[client], i, szTitle, sizeof(szTitle));
		Particle(client, szTitle, false);
	}
}


stock CreateParticle(String:type[], Float:time, entity, attach=NO_ATTACH, Float:xOffs=0.0, Float:yOffs=0.0, Float:zOffs=0.0, const String:effect[])
{
	new particle = CreateEntityByName("info_particle_system");
	
	if (IsValidEdict(particle) && IsPlayerAlive(entity)) {
		decl Float:pos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
		pos[0] += xOffs;
		pos[1] += yOffs;
		pos[2] += zOffs;
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", type);

		if (attach != NO_ATTACH) {
			SetVariantString("!activator");
			AcceptEntityInput(particle, "SetParent", entity, particle, 0);
		
			if (attach == ATTACH_HEAD) {
				SetVariantString("head");
				AcceptEntityInput(particle, "SetParentAttachmentMaintainOffset", particle, particle, 0);
			}
		}
		DispatchKeyValue(particle, "targetname", "present");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "Start");
		PushArrayCell(g_hParticles[entity], particle);
		PushArrayString(g_hParticleNames[entity], effect);
		return particle;
	} else {
		LogError("Presents (CreateParticle): Could not create info_particle_system");
	}
	
	return -1;
}

public OnGameFrame()
{
	new maxclients = GetMaxClients();
	for (new i = 1; i < maxclients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			if (TF2_GetPlayerConditionFlags(i) & TF_CONDFLAG_CLOAKED)
			{
				if (g_bIsStealth[i] == false)
				{
					g_bIsStealth[i] = true;
					OnCloak(i);
				}
			}
			else
			{
				if (g_bIsStealth[i] == true)
				{
					g_bIsStealth[i] = false;
					OnUnCloak(i);
				}
			}
		}
	}
}

OnCloak(client)
{
	RemoveAllParticles(client);
}

OnUnCloak(client)
{
	AddAllParticles(client);
}

public OnPluginEnd()
{
	for (new i = 1; i < GetMaxClients(); i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
			RemoveAllParticles(i);
	}
}
