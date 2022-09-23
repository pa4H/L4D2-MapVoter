#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

char txtBufer[256]; // Буферная переменная для хранения текста
char mapRealName[64];
Menu g_MapMenu = null; // Для работы меню
int winner = 0; // Номер карты, которая победила в голосовании. индекс 0 = mapSequence[0]
int clientVotes[MAXPLAYERS + 1][14]; // В массиве содержатся все игроки и их голоса за каждую карту
bool canVote = true;

native void L4D2_ChangeLevel(const char[] sMap); // changelevel.smx

public Plugin myinfo =  {
	name = "MapVoter", 
	author = "pa4H", 
	description = "", 
	version = "1.0", 
	url = "vk.com/pa4h1337"
};

char mapSequence[][32] =  {  // Последовательность карт
	"c8m1_apartment", "c2m1_highway", "c1m1_hotel", "c11m1_greenhouse", "c5m1_waterfront", "c3m1_plankcountry", "c4m1_milltown_a", 
	"c6m1_riverbank", "c7m1_docks", "c9m1_alleys", "c10m1_caves", 
	"c12m1_hilltop", "c13m1_alpinecreek", "c14m1_junkyard"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_mapvote", mapVote);
	RegConsoleCmd("sm_votemap", mapVote);
	RegConsoleCmd("sm_mv", mapVote);
	RegConsoleCmd("sm_rtv", mapVote);
	
	RegAdminCmd("sm_mapresult", mapVoteResult, ADMFLAG_BAN);
	
	HookEvent("versus_round_start", Event_VersusRoundStart, EventHookMode_Pre); // Начало раунда
	HookEvent("versus_match_finished", Event_VersusMatchFinished, EventHookMode_Pre); // Конец раунда
	
	LoadTranslations("pa4HMapVoter.phrases");
}

public void Event_VersusRoundStart(Event hEvent, const char[] sEvName, bool bDontBroadcast) // Срабатывает после выхода из saferoom
{
	if (L4D_IsMissionFinalMap() && GameRules_GetProp("m_bInSecondHalfOfRound") == 0) // Если играем последную карту и идёт первая половина карты
	{
		canVote = true;
		CreateTimer(15.0, Timer_EndVote, _, TIMER_FLAG_NO_MAPCHANGE); // Создаем таймер после которого закончится голосование
		
		PrecacheSound("ui/beep_synthtone01.wav");
		EmitSoundToAll("ui/beep_synthtone01.wav");
		
		g_MapMenu = BuildMapMenu(); // Генерируем пункты меню
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
			{
				clearClientVotes(i); // Очищаем все голоса
				g_MapMenu.Display(i, 15); // Показываем меню всем настоящим игрокам
			}
		}
	}
}

public Action Timer_EndVote(Handle hTimer, any UserId)
{
	canVote = false;
	
	int buf = 0;
	for (int c = 1; c < sizeof(clientVotes); c++)
	{
		for (int i = 0; i < 14; i++)
		{
			if (clientVotes[c][i] >= buf && clientVotes[c][i] != 0) { buf = clientVotes[c][i]; winner = i; } // Узнаем победившую карту
		}
	}
	
	FormatEx(mapRealName, sizeof(mapRealName), "%t", mapSequence[winner]);
	FormatEx(txtBufer, sizeof(txtBufer), "%t", "VoteWinner", mapRealName);
	CPrintToChatAll(txtBufer); // Выводим в чат победившую карту
	
	return Plugin_Handled;
}

public void Event_VersusMatchFinished(Event hEvent, const char[] sEvName, bool bDontBroadcast) // Версус закончился
{
	FormatEx(mapRealName, sizeof(mapRealName), "%t", mapSequence[winner]);
	FormatEx(txtBufer, sizeof(txtBufer), "%t", "NextMap", mapRealName);
	CPrintToChatAll(txtBufer); // "Следующая карта Нет милосердию"
	CreateTimer(10.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE); // Через 10 секунд меняем карту
}

public Action Timer_ChangeMap(Handle hTimer, any UserId)
{
	L4D2_ChangeLevel(mapSequence[winner]); // Меняем карту
	return Plugin_Stop;
}

Menu BuildMapMenu() // Здесь строится меню
{
	Menu menu = new Menu(Menu_VotePoll); // Внутри скобок обработчик нажатий меню
	FormatEx(txtBufer, sizeof(txtBufer), "%t", "SelectMap");
	menu.SetTitle(txtBufer); // Заголовок меню
	
	GetCurrentMap(mapRealName, sizeof(mapRealName)); // Получаем текущую карту
	
	for (int i = 0; i < sizeof(mapSequence); i++) // Выводим все карты из массива mapSequence
	{
		if (StrEqual(substr(mapSequence[i], 0, 3), substr(mapRealName, 0, 3), false) == false) // Пропускаем текущую карту
		{
			FormatEx(txtBufer, sizeof(txtBufer), "%t", mapSequence[i]); // Даём: "c1m1_hotel", получаем: "Вымерший центр"
			menu.AddItem(mapSequence[i], txtBufer); // Добавляем в меню "Вымерший центр"
		}
	}
	
	return menu;
}
public Menu_VotePoll(Menu menu, MenuAction action, int client, int selectedItem) // Обработчик нажатия кнопок в меню
{
	if (action == MenuAction_Select) // Если нажали кнопку от 1 до 7 включительно
	{
		clearClientVotes(client); // Чистим голоса человека который нажал кнопку в меню
		clientVotes[client][selectedItem] += 1; // Добавляем голос за карту человеку, нажавшиму на кнопку
		
		//CPrintToChatAll("Client %i selected item: %d ", client, selectedItem); // debug
	}
}

void clearClientVotes(int client) // Очищаем голоса конкретного игрока
{
	for (int i = 0; i < 14; i++)
	{
		clientVotes[client][i] = 0;
	}
}

public Action mapVote(int client, int args) // !mapvote
{
	if (canVote == true)
	{
		if (L4D_IsMissionFinalMap() == true)
		{
			g_MapMenu = BuildMapMenu();
			g_MapMenu.Display(client, 15);
		}
		else // Если играем не последнюю карту
		{
			FormatEx(txtBufer, sizeof(txtBufer), "%t", "VoteOnlyOnFinal");
			CPrintToChat(client, txtBufer);
		}
	}
	else
	{
		FormatEx(mapRealName, sizeof(mapRealName), "%t", mapSequence[winner]);
		FormatEx(txtBufer, sizeof(txtBufer), "%t", "VoteStoped", mapRealName);
		CPrintToChat(client, txtBufer);
	}
	return Plugin_Handled;
}

public Action mapVoteResult(int client, int args)
{
	GetCurrentMap(mapRealName, sizeof(mapRealName));
	PrintToChatAll("%s", substr(mapRealName, 0, 3));
	
	FormatEx(txtBufer, sizeof(txtBufer), "%t", "VoteWinner", "Хуй");
	CPrintToChatAll(txtBufer);
	return Plugin_Handled;
}

stock char substr(char[] inpstr, int startpos, int len = -1)
{
	char outstr[MAX_MESSAGE_LENGTH];
	
	if (len == -1)
	{
		strcopy(outstr, sizeof(outstr), inpstr[startpos]);
	}
	else
	{
		strcopy(outstr, len, inpstr[startpos]);
		outstr[len] = 0;
	}
	return outstr;
} 