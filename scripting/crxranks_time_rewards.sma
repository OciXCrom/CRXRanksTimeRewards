#include <amxmodx>
#include <amxmisc>
#include <nvault>

#tryinclude <cromchat>

#if !defined _cromchat_included
	#error "cromchat.inc" is missing in your "scripting/include" folder. Download it from: "https://amxx-bg.info/inc/"
#endif

#tryinclude <crxranks>

#if !defined _crxranks_included
	#error This plugin requires OciXCrom's Rank System: "crxranks.inc" was not found in your "scripting/include" folder.
#endif

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32
#endif

#if !defined MAX_NAME_LENGTH
	const MAX_NAME_LENGTH = 32
#endif

#if !defined MAX_AUTHID_LENGTH
	const MAX_AUTHID_LENGTH = 64
#endif

const MAX_NUM_LENGTH = 8
const Float:TIME_FREQ = 60.0
new const PLUGIN_VERSION[] = "2.0"

new CRXRanks_SaveTypes:g_iSaveType, Trie:g_tTimeRewards, g_pTimeout
new g_szInfo[MAX_PLAYERS + 1][MAX_AUTHID_LENGTH], g_iPlayedTime[MAX_PLAYERS + 1], g_iVault

public plugin_init()
{
	register_plugin("CRXRanks: Time Rewards", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXRanksTimeRewards", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("RankSystemTimeRewards.txt")

	g_iSaveType = crxranks_get_save_type()
	g_pTimeout = register_cvar("crxranks_tr_timeout", "300")
	g_iVault = nvault_open("CRXRanksTimeRewards")
	g_tTimeRewards = TrieCreate()

	crxranks_get_chat_prefix(CC_PREFIX, charsmax(CC_PREFIX))
	ReadFile()
}

public plugin_end()
{
	nvault_close(g_iVault)
	TrieDestroy(g_tTimeRewards)
}

ReadFile()
{
	new szFilename[256]
	get_configsdir(szFilename, charsmax(szFilename))
	add(szFilename, charsmax(szFilename), "/RankSystemTimeRewards.ini")

	new iFilePointer = fopen(szFilename, "rt")

	if(iFilePointer)
	{
		new szData[MAX_NUM_LENGTH * 2], szValue[MAX_NUM_LENGTH], szKey[MAX_NUM_LENGTH]

		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)

			switch(szData[0])
			{
				case EOS, ';', '#': continue
				default:
				{
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)

					if(!szValue[0])
					{
						continue
					}

					TrieSetCell(g_tTimeRewards, szKey, str_to_num(szValue))
				}
			}
		}

		fclose(iFilePointer)
	}
}

public client_connect(id)
{
	new szPlayedTime[MAX_NUM_LENGTH], iTimeout = get_pcvar_num(g_pTimeout), iTimeStamp

	switch(g_iSaveType)
	{
		case CRXRANKS_ST_NICKNAME, CRXRANKS_ST_IP: get_user_ip(id, g_szInfo[id], charsmax(g_szInfo[]), 1)
		case CRXRANKS_ST_STEAMID: get_user_authid(id, g_szInfo[id], charsmax(g_szInfo[]))
	}

	nvault_lookup(g_iVault, g_szInfo[id], szPlayedTime, charsmax(szPlayedTime), iTimeStamp)

	if(iTimeout)
	{
		g_iPlayedTime[id] = get_systime() - iTimeStamp > iTimeout ? 0 : str_to_num(szPlayedTime)
	}
	else
	{
		g_iPlayedTime[id] = str_to_num(szPlayedTime)
	}

	set_task(TIME_FREQ, "increase_played_time", id, .flags = "b")
}

public client_disconnected(id)
{
	new szPlayedTime[MAX_NUM_LENGTH]
	num_to_str(g_iPlayedTime[id], szPlayedTime, charsmax(szPlayedTime))
	nvault_set(g_iVault, g_szInfo[id], szPlayedTime)
	remove_task(id)
}

public increase_played_time(id)
{
	new szPlayedTime[MAX_NUM_LENGTH], iXP
	num_to_str(++g_iPlayedTime[id], szPlayedTime, charsmax(szPlayedTime))

	if(TrieGetCell(g_tTimeRewards, szPlayedTime, iXP))
	{
		new szName[MAX_NAME_LENGTH]
		get_user_name(id, szName, charsmax(szName))
		CC_SendMessage(0, "%L", LANG_PLAYER, "CRXRANKS_TIME_REWARD", szName, iXP, g_iPlayedTime[id])
		crxranks_give_user_xp(id, iXP)
	}
}