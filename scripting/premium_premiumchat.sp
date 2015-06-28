#pragma semicolon 1
#include <clientprefs>
#undef REQUIRE_PLUGIN
#include <sourceirc>

#define PL_VERSION "1.0"

new Handle:g_hChatCookie;
new bool:g_bChatState[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name        = "Premium Chat",
	author      = "Azelphur",
	description = "Gives premium members premium chat.",
	version     = PL_VERSION,
	url         = "http://www.azelphur.com"
};

public OnPluginStart()
{
	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say2", Command_Say);
	RegConsoleCmd("say_team", Command_SayTeam);
	RegAdminCmd("sm_pchat", Command_PremiumChat, ADMFLAG_CUSTOM1, "Toggle premium chat");
	g_hChatCookie = RegClientCookie("premiumchat", "Premium chat on or off", CookieAccess_Public);
	MarkNativeAsOptional("IRC_MsgFlaggedChannels"); 
}

public OnClientConnected(client)
{
	g_bChatState[client] = false;
}

public Action:Command_PremiumChat(client, args)
{
	decl String:szChatString[64];
	GetClientCookie(client, g_hChatCookie, szChatString, sizeof(szChatString));
	if (StrEqual(szChatString, "Turn premium chat on [pchat on]"))
	{
		SetClientCookie(client, g_hChatCookie, "Turn premium chat off [pchat off]");
	}
	else
	{
		SetClientCookie(client, g_hChatCookie, "Turn premium chat on [pchat on]");
	}
	return Plugin_Handled;
}

IsEnabled(client)
{
	new AdminId:iId = GetUserAdmin(client);
	if (iId != INVALID_ADMIN_ID)
	{
		new iFlags = GetAdminFlags(iId, Access_Effective);
		if (iFlags & ADMFLAG_CUSTOM1 || iFlags & ADMFLAG_ROOT)
		{
			decl String:szChatString[64];
			GetClientCookie(client, g_hChatCookie, szChatString, sizeof(szChatString));
			if (StrEqual(szChatString, "Turn premium chat on [pchat on]"))
			{
				return false;
			}
			else
			{
				return true;
			}
		}
	}
	return false;
}	

public Action:Command_Say(client, args) {
	if (IsChatTrigger() || !IsEnabled(client))
		return Plugin_Continue;
	new String:text[192];
	GetCmdArgString(text, sizeof(text));
	new startidx = 0;
	if (text[0] == '"')
	{
		startidx = 1;
		new len = strlen(text);
		if (text[len-1] == '"')
			text[len-1] = '\0';
	}
	
	decl String:name[64], String:str[512];
	GetClientName(client, name, sizeof(name));
	Format(str, sizeof(str), "\x03(Premium) %s :  %s", name, text[startidx]);
	SayText2All(client, str);
	new team = IRC_GetTeamColor(GetClientTeam(client));
	if (team == -1)
		IRC_MsgFlaggedChannels("relay", "(Premium) %s: %s", name, text[startidx]);
	else
		IRC_MsgFlaggedChannels("relay", "\x03%02d(Premium) %s: %s\x03", team, name, text[startidx]);
	return Plugin_Handled;
}

public Action:Command_SayTeam(client, args) {
	if (IsChatTrigger() || !IsEnabled(client))
		return Plugin_Continue;
	new String:text[192];
	GetCmdArgString(text, sizeof(text));
	new startidx = 0;
	if (text[0] == '"')
	{
		startidx = 1;
		new len = strlen(text);
		if (text[len-1] == '"')
			text[len-1] = '\0';
	}
	
	decl String:name[64], String:str[512];
	GetClientName(client, name, sizeof(name));
	Format(str, sizeof(str), "\x03(Premium) (TEAM) %s :  %s", name, text[startidx]);
	SayText2Team(client, str);
	new team = IRC_GetTeamColor(GetClientTeam(client));
	if (team == -1)
		IRC_MsgFlaggedChannels("relay", "(Premium) (TEAM) %s: %s", name, text[startidx]);
	else
		IRC_MsgFlaggedChannels("relay", "\x03%02d(Premium) (TEAM) %s: %s\x03", team, name, text[startidx]);
	return Plugin_Handled;
}

stock SayText2(client, author, const String:message[])
{
	new Handle:buffer = StartMessageOne("SayText2", client); 
	if (buffer != INVALID_HANDLE)
	{
		BfWriteByte(buffer, author); 
		BfWriteByte(buffer, true); 
		BfWriteString(buffer, message); 
		EndMessage(); 
	} 
}

stock SayText2Team(author_index, const String:message[])
{
	new authorteam = GetClientTeam(author_index);

	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			new clientteam = GetClientTeam(i);

			if(clientteam == authorteam)
			{
				SayText2(i, author_index, message);
			}
		}
	}
}

stock SayText2All(author_index, const String:message[])
{
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientInGame(i))
		{
			SayText2(i, author_index, message);
		}
	}
}
