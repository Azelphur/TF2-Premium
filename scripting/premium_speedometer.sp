#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <premium>

public Plugin:myinfo = 
{
	name = "Speedometer",
	author = "Azelphur",
	description = "Shows a speedometer",
	version = "1.0",
	url = "http://www.azelphur.com"
};

new GetVelocityOffset_0;
new GetVelocityOffset_1;
new GetVelocityOffset_2;

new Handle:g_hSpeedoState;

new bool:g_bIsPremium[MAXPLAYERS+1];
new bool:g_bSpeedoEnabled[MAXPLAYERS+1];

public OnPluginStart()
{
	GetVelocityOffset_0=FindSendPropOffs("CBasePlayer","m_vecVelocity[0]");
	GetVelocityOffset_1=FindSendPropOffs("CBasePlayer","m_vecVelocity[1]");
	GetVelocityOffset_2=FindSendPropOffs("CBasePlayer","m_vecVelocity[2]");
	RegAdminCmd("sm_speedo", Command_Speedometer, ADMFLAG_CUSTOM1, "Toggle speedometer");
	g_hSpeedoState = RegClientCookie("speedo", "Turns speedometer on/off", CookieAccess_Public);
}

public OnClientPostAdminCheck(client)
{
	new AdminId:iId = GetUserAdmin(client);
	if (iId != INVALID_ADMIN_ID)
	{
		new iFlags = GetAdminFlags(iId, Access_Effective);
		if (iFlags & ADMFLAG_CUSTOM1 || iFlags & ADMFLAG_ROOT)
		{
			g_bIsPremium[client] = true;
			return;
		}
	}
	g_bIsPremium[client] = false;
}

public OnClientCookiesCached(client)
{
	decl String:szCookie[64];
	GetClientCookie(client, g_hSpeedoState, szCookie, sizeof(szCookie));
	if (StrEqual(szCookie, "Turn speedo on [speedo on]"))
	{
		g_bSpeedoEnabled[client] = false;
	}
	else
	{
		g_bSpeedoEnabled[client] = true;
	}
}

public Action:Command_Speedometer(client, args)
{
	decl String:szChatString[64];
	GetClientCookie(client, g_hSpeedoState, szChatString, sizeof(szChatString));
	if (StrEqual(szChatString, "Turn speedo on [speedo on]"))
	{
		SetClientCookie(client, g_hSpeedoState, "Turn speedo off [speedo off]");
		g_bSpeedoEnabled[client] = true;
	}
	else
	{
		SetClientCookie(client, g_hSpeedoState, "Turn speedo on [speedo on]");
		g_bSpeedoEnabled[client] = false;
	}
	return Plugin_Handled;
}

public OnGameFrame()
{
	new Float:speed;
	new Float:x;
	new Float:y;
	new Float:z;
	new clientCount = GetMaxClients();
	for (new client = 1;client <= clientCount;client++)
	{
		if (IsClientConnected(client))
		{
			if (IsClientInGame(client))
			{
				if (g_bSpeedoEnabled[client] && g_bIsPremium[client])
				{
					x=GetEntDataFloat(client,GetVelocityOffset_0);
					y=GetEntDataFloat(client,GetVelocityOffset_1);
					z=GetEntDataFloat(client,GetVelocityOffset_2);
					speed = SquareRoot(x*x + y*y + z*z)/20.0;
					PrintToClientCenter(client, 0.0, 0.0, 1.0, "Speed: %dmph", RoundToNearest(speed));
				}
			}
		}
	}
}

stock PrintToClientCenter(client, Float:fadeInTime, Float:fadeOutTime, Float:holdTime, const String:msg[], any:...)
{
	decl String:fmsg[221];
	VFormat(fmsg, sizeof(fmsg), msg, 6);
	
	new r = 255;
	new g = 255;
	new b = 255;

	new Handle:hBf = StartMessageOne("HudMsg", client);
	
	if (hBf == INVALID_HANDLE)
	{
		return;
	}
	
	// Position
	BfWriteByte(hBf, 1);				// channel
	BfWriteFloat(hBf, -1.0);			// X
	BfWriteFloat(hBf, 0.2);				// Y
	
	// Second Color
	BfWriteByte(hBf, r); 				// r
	BfWriteByte(hBf, g);				// g
	BfWriteByte(hBf, b);				// b
	BfWriteByte(hBf, 255);				// a
	
	// First Color
	BfWriteByte(hBf, r);				// r
	BfWriteByte(hBf, g);				// g
	BfWriteByte(hBf, b);				// b
	BfWriteByte(hBf, 255);				// a
	
	// Effect
	BfWriteByte(hBf, 0);				// effect (0 is fade in/fade out; 1 is flickery credits; 2 is write out)
	BfWriteFloat(hBf, fadeInTime);		// fadeinTime (message fade in time - per character in effect 2)
	BfWriteFloat(hBf, fadeOutTime);		// fadeoutTime
	BfWriteFloat(hBf, holdTime);		// holdtime
	BfWriteFloat(hBf, 0.0);				// fxtime (effect type(2) used)
	
	// Message
	BfWriteString(hBf, fmsg);			// message
	
	EndMessage();
	
	return;
}
