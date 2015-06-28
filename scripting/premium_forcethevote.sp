#include <clientprefs>

new Handle:g_hVoteMapCookie;
new g_iMapStartTime;

public Plugin:myinfo = {
	name        = "Premium vote map",
	author      = "Azelphur",
	description = "Allows premiums to vote for a map.",
	version     = "1.0",
	url         = "http://www.azelphur.com"
};

public OnPluginStart() {
	g_hVoteMapCookie = RegClientCookie("votemaptime", "Last time client used force the vote", CookieAccess_Protected)
	RegAdminCmd("sm_pvotemap", Command_VoteMap, ADMFLAG_CUSTOM1, "Start a votemap");
}

public OnMapStart()
{
	g_iMapStartTime = GetTime();
}

public Action:Command_VoteMap(client, args) {
	new iSeconds = (GetTime() - g_iMapStartTime);
	if (iSeconds < 300) {
		new remaining = 300-iSeconds;
		PrintToChat(client, "You cannot use vote map within 5 minutes of the map starting. You must wait %d:%02d to use vote map.", remaining / 60, remaining % 60);
		return Plugin_Handled;
	}
	if (AreClientCookiesCached(client))
	{
		decl String:szTime[32];
		GetClientCookie(client, g_hVoteMapCookie, szTime, sizeof(szTime));
		iSeconds = (GetTime() - StringToInt(szTime))
		if (iSeconds < 3600) {
			new remaining = 3600-iSeconds;
			PrintToChat(client, "You must wait %d:%02d to use vote map again", remaining / 60, remaining % 60);
			return Plugin_Handled;
		}
		new Handle:hMapList = CreateArray(64);
		ReadMapList(hMapList);
		new Handle:hMenu = CreateMenu(MenuHandler_MapList);
		decl String:szMap[64];
		SetMenuTitle(hMenu, "Select a map [pvotemap]");
		for (new i = 0; i < GetArraySize(hMapList); i++)
		{
			GetArrayString(hMapList, i, szMap, sizeof(szMap));
			AddMenuItem(hMenu, szMap, szMap);
		}
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public MenuHandler_MapList(Handle:hMenu, MenuAction:action, param1, param2)
{
	if(action==MenuAction_Select)
	{
		decl String:szMap[64], String:szTime[32];
		Format(szTime, sizeof(szTime), "%d", GetTime());
		GetMenuItem(hMenu, param2, szMap, sizeof(szMap));
		SetClientCookie(param1, g_hVoteMapCookie, szTime);
		ShowActivity(param1, "Used premium vote map to start a map vote");
		DoVoteMenu(szMap);
	}
}

public Handle_VoteMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		/* This is called after VoteEnd */
		CloseHandle(menu);
	} else if (action == MenuAction_VoteEnd) {
		/* 0=yes, 1=no */
		if (param1 == 0)
		{
			new String:map[64];
			GetMenuItem(menu, param1, map, sizeof(map));
			ServerCommand("wait 500;changelevel %s", map);
		}
	}
}
 
DoVoteMenu(const String:map[])
{
	if (IsVoteInProgress())
	{
		return;
	}
 
	new Handle:menu = CreateMenu(Handle_VoteMenu);
	SetMenuTitle(menu, "Change map to: %s?", map);
	AddMenuItem(menu, map, "Yes");
	AddMenuItem(menu, "no", "No");
	SetMenuExitButton(menu, false);
	VoteMenuToAll(menu, 20);
}

/*	decl String:time[32];
	GetClientCookie(client, ftvcookie, time, sizeof(time));
	new seconds = (GetTime() - StringToInt(time))
	if (seconds < 3600) {
		new remaining = 3600-seconds;
		PrintToChat(client, "You must wait %d:%d to use force the vote again", remaining / 60, remaining % 60);
	}
	else {
		Format(time, sizeof(time), "%d", GetTime());
		SetClientCookie(client, ftvcookie, time);
		InitiateMapChooserVote(MapChange:0);
		PrintToChatAll("[Premium] %N Forced the vote!", client);
	}*/
