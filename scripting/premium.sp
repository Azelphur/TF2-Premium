#pragma semicolon 1
#include <clientprefs>
#include <sourcemod>

#define PL_VERSION "1.0"

new Handle:g_hConfig;

public Plugin:myinfo =
{
	name        = "Premium",
	author      = "Azelphur",
	description = "Gives premium members the premium flag (o)).",
	version     = PL_VERSION,
	url         = "http://www.azelphur.com"
};

public OnPluginStart()
{
	RegAdminCmd("sm_premium", Command_Premium, ADMFLAG_CUSTOM1, "Premium menu");
	g_hConfig = CreateKeyValues("Premium");
	decl String:szPath[256];
	BuildPath(Path_SM, szPath, sizeof(szPath), "configs/premium.cfg");
	if (FileExists(szPath))
	{
		FileToKeyValues(g_hConfig, szPath);
	} else
	{
		SetFailState("File Not Found: %s", szPath);
	}
}

public Action:Command_Premium(client, args)
{
	new Handle:hMenu=CreateMenu(MenuHandler_Premium);
	new Handle:hCookie;
	SetMenuTitle(hMenu, "Premium menu [premium]");
	decl String:szTitle[64], String:szCookieTitle[64], String:szCookieContents[64];
	KvGotoFirstSubKey(g_hConfig);
	do
	{
		KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
		KvGetString(g_hConfig, "cookie", szCookieTitle, sizeof(szCookieTitle), "");
		if (StrEqual(szCookieTitle, ""))
			AddMenuItem(hMenu, szTitle, szTitle);
		else
		{
			hCookie = FindClientCookie(szCookieTitle);
			if (hCookie != INVALID_HANDLE)
			{
				GetClientCookie(client, hCookie, szCookieContents, sizeof(szCookieContents));
				if (StrEqual(szCookieContents, ""))
				{
					AddMenuItem(hMenu, szTitle, szTitle);
				}
				else
				{
					AddMenuItem(hMenu, szTitle, szCookieContents);
				}
			}
			else
			{
				AddMenuItem(hMenu, szTitle, szTitle);
			}
		}
	} while (KvGotoNextKey(g_hConfig));
	KvRewind(g_hConfig);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public MenuHandler_Premium(Handle:hMenu, MenuAction:action, param1, param2)
{
	if(action==MenuAction_Select)
	{
		decl String:szTitle[64], String:szSelectedTitle[64], String:szCmd[64];
		GetMenuItem(hMenu, param2, szSelectedTitle, sizeof(szSelectedTitle));
		KvGotoFirstSubKey(g_hConfig);
		do
		{
			KvGetSectionName(g_hConfig, szTitle, sizeof(szTitle));
			if (StrEqual(szTitle, szSelectedTitle))
			{
				KvGetString(g_hConfig, "exec", szCmd, sizeof(szCmd));
				FakeClientCommandEx(param1, szCmd);
			}
		} while (KvGotoNextKey(g_hConfig));
		KvRewind(g_hConfig);
	}
}


