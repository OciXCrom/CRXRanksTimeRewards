#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <crxranks>
#include <nvault>

#if !defined client_disconnected
	#define client_disconnected client_disconnect
#endif

#if !defined MAX_PLAYERS
	const MAX_PLAYERS = 32
#endif

#if !defined MAX_NAME_LENGTH
	const MAX_NAME_LENGTH = 32
#endif

#if !defined MAX_IP_LENGTH
	const MAX_IP_LENGTH = 16
#endif

const MAX_NUM_LENGTH = 8
const Float:TIME_FREQ = 60.0
new const PLUGIN_VERSION[] = "1.0"

new Trie:g_tTimeRewards, g_pTimeout
new g_szIP[MAX_PLAYERS + 1][MAX_IP_LENGTH], g_iPlayedTime[MAX_PLAYERS + 1], g_iVault

public plugin_init()
{
	register_plugin("CRXRanks: Time Rewards", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXRanksTimeRewards", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("RankSystemTimeRewards.txt")

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
	new szPlayedTime[MAX_NUM_LENGTH], iTimeStamp
	get_user_ip(id, g_szIP[id], charsmax(g_szIP[]), 1)
	nvault_lookup(g_iVault, g_szIP[id], szPlayedTime, charsmax(szPlayedTime), iTimeStamp)

	g_iPlayedTime[id] = get_systime() - iTimeStamp > get_pcvar_float(g_pTimeout) ? 0 : str_to_num(szPlayedTime)
	set_task(TIME_FREQ, "increase_played_time", id, .flags = "b")
}

public client_disconnected(id)
{
	new szPlayedTime[MAX_NUM_LENGTH]
	num_to_str(g_iPlayedTime[id], szPlayedTime, charsmax(szPlayedTime))
	nvault_set(g_iVault, g_szIP[id], szPlayedTime)
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