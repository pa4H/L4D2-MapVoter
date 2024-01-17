#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

char mapRealName[64];
int winner = 0; // Номер карты, которая победила в голосовании. индекс 0 = mapSequence[0]
int clientVotes[14]; // В массиве содержатся голоса за каждую карту
bool canPlayerVote[MAXPLAYERS + 1]; // В массиве содержатся игроки которым можно\нельзя голосовать
bool canVote = true;
int loadedPlayers = 0;

native void L4D2_ChangeLevel(const char[] sMap); // changelevel.smx

//char DropLP[PLATFORM_MAX_PATH]; // debug

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
	//RegAdminCmd("sm_mapresult", mapVoteResult, ADMFLAG_BAN);
	//RegConsoleCmd("sm_test", testFunc, "");
	RegConsoleCmd("sm_mapvote", mapVote);
	RegConsoleCmd("sm_votemap", mapVote);
	RegConsoleCmd("sm_mv", mapVote);
	RegConsoleCmd("sm_rtv", mapVote);
	
	//HookEvent("versus_round_start", Event_VersusRoundStart, EventHookMode_Pre); // Открыли дверь
	HookEvent("versus_match_finished", Event_VersusMatchFinished, EventHookMode_Pre); // Конец финальной карты
	
	LoadTranslations("pa4HMapVoter.phrases");
	//BuildPath(Path_SM, DropLP, sizeof(DropLP), "logs/MapVoter.log"); // debug
}
stock Action testFunc(int client, int args) // DEBUG
{
	return Plugin_Handled;
}
public OnClientPostAdminCheck(client)
{
	if (IsValidClient(client)) {
		loadedPlayers++;
		//LogToFileEx(DropLP, "Cliconnect: %i online: %i", loadedPlayers, GetOnlineClients());
	}
	
	if (loadedPlayers >= GetOnlineClients() && L4D_IsMissionFinalMap() && GameRules_GetProp("m_bInSecondHalfOfRound") == 0) // Если играем последную карту и идёт первая половина карты
	{
		loadedPlayers = 0;
		canVote = true;
		CreateTimer(30.0, Timer_EndVote); // Создаем таймер после которого закончится голосование
		
		PrecacheSound("ui/beep_synthtone01.wav");
		EmitSoundToAll("ui/beep_synthtone01.wav");
		
		clearVotes(); // Очищаем все голоса
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				showMenu(i); // Показываем меню всем
			}
		}
	}
}
public void OnMapEnd() // Требуется, поскольку принудительная смена карты не вызывает событие "round_end"
{
	loadedPlayers = 0;
}
stock int GetOnlineClients()
{
	int cl;
	for (int i = 1; i <= MaxClients; i++) {
		if (i > 0 && i <= MaxClients && IsClientConnected(i) && !IsFakeClient(i)) { cl++; }
	}
	return cl;
}
/*public void Event_VersusRoundStart(Event hEvent, const char[] sEvName, bool bDontBroadcast) // Срабатывает после выхода из saferoom
{
	if (L4D_IsMissionFinalMap() && GameRules_GetProp("m_bInSecondHalfOfRound") == 0) // Если играем последную карту и идёт первая половина карты
	{
		canVote = true;
		CreateTimer(30.0, Timer_EndVote); // Создаем таймер после которого закончится голосование
		
		PrecacheSound("ui/beep_synthtone01.wav");
		EmitSoundToAll("ui/beep_synthtone01.wav");
		
		clearVotes(); // Очищаем все голоса
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i))
			{
				showMenu(i); // Показываем меню всем настоящим игрокам
			}
		}
	}
}
*/
public Action Timer_EndVote(Handle hTimer, any UserId)
{
	canVote = false;
	loadedPlayers = 0;
	
	int buf = 0;
	winner = 0;
	for (int map = 0; map < 14; map++)
	{
		if (clientVotes[map] >= buf && clientVotes[map] != 0) { buf = clientVotes[map]; winner = map; } // Узнаем победившую карту
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			FormatEx(mapRealName, sizeof(mapRealName), "%T", mapSequence[winner], i);
			CPrintToChat(i, "%t", "VoteWinner", mapRealName); // Выводим в чат победившую карту
			//LogToFileEx(DropLP, "VoteWinner: %s", mapRealName); // debug
		}
	}
	resultsToConsole();
	return Plugin_Stop;
}

public void Event_VersusMatchFinished(Event hEvent, const char[] sEvName, bool bDontBroadcast) // Версус закончился
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			FormatEx(mapRealName, sizeof(mapRealName), "%T", mapSequence[winner], i);
			CPrintToChat(i, "%t", "NextMap", mapRealName); // "Следующая карта Нет милосердию"
		}
	}
	CreateTimer(10.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE); // Через 10 секунд меняем карту
	//LogToFileEx(DropLP, "Timer started"); // debug
}

public Action Timer_ChangeMap(Handle hTimer, any UserId)
{
	//LogToFileEx(DropLP, "ChangeLevel"); // debug
	L4D2_ChangeLevel(mapSequence[winner]); // Меняем карту
	return Plugin_Stop;
}

void showMenu(int client)
{
	Menu menu = new Menu(Menu_VotePoll); // Внутри скобок обработчик нажатий меню
	menu.SetTitle("%T", "SelectMap", client); // Заголовок меню
	
	char mapName[32]; char mapSeq[32];
	GetCurrentMap(mapName, sizeof(mapName)); // Получаем название карты
	strcopy(mapName, 4, mapName[0]);
	
	for (int i = 0; i < sizeof(mapSequence); i++) // Выводим все карты из массива mapSequence
	{
		strcopy(mapSeq, 4, mapSequence[i][0]);
		if (StrEqual(mapSeq, mapName) == false) // Добавляем все карты кроме текущей
		{
			FormatEx(mapRealName, sizeof(mapRealName), "%T", mapSequence[i], client);
			menu.AddItem(mapSequence[i], mapRealName); // Добавляем в меню "c8m1_apartment" "Нет Милосердию"
		}
	}
	menu.Display(client, 15);
}

public Menu_VotePoll(Menu menu, MenuAction action, int client, int param2) // Обработчик нажатия кнопок в меню
{
	if (action == MenuAction_Select) // Если нажали кнопку от 1 до 7 включительно
	{
		char szInfo[32];
		menu.GetItem(param2, szInfo, sizeof(szInfo)); // Получаем описание пункта по которому нажал игрок
		int sel = 0;
		if (StrEqual(szInfo, "c8m1_apartment") == true) // Добавляем все карты кроме текущей
		{
			sel = 0;
		}
		else if (StrEqual(szInfo, "c2m1_highway") == true) {
			sel = 1;
		}
		else if (StrEqual(szInfo, "c1m1_hotel") == true) {
			sel = 2;
		}
		else if (StrEqual(szInfo, "c11m1_greenhouse") == true) {
			sel = 3;
		}
		else if (StrEqual(szInfo, "c5m1_waterfront") == true) {
			sel = 4;
		}
		else if (StrEqual(szInfo, "c3m1_plankcountry") == true) {
			sel = 5;
		}
		else if (StrEqual(szInfo, "c4m1_milltown_a") == true) {
			sel = 6;
		}
		else if (StrEqual(szInfo, "c6m1_riverbank") == true) {
			sel = 7;
		}
		else if (StrEqual(szInfo, "c7m1_docks") == true) {
			sel = 8;
		}
		else if (StrEqual(szInfo, "c9m1_alleys") == true) {
			sel = 9;
		}
		else if (StrEqual(szInfo, "c10m1_caves") == true) {
			sel = 10;
		}
		else if (StrEqual(szInfo, "c12m1_hilltop") == true) {
			sel = 11;
		}
		else if (StrEqual(szInfo, "c13m1_alpinecreek") == true) {
			sel = 12;
		}
		else if (StrEqual(szInfo, "c14m1_junkyard") == true) {
			sel = 13;
		}
		clientVotes[sel] += 1;
		canPlayerVote[client] = false;
		FormatEx(mapRealName, sizeof(mapRealName), "%T", mapSequence[sel], client);
		CPrintToChat(client, "%t", "VotedFor", mapRealName);
		//LogToFileEx(DropLP, "Cl: %i; indx: %d; mapName: %s", client, param2, szInfo); // debug
	}
	else if (action == MenuAction_Cancel && param2 == -3) // Если нажали Выход
	{
		CPrintToChat(client, "%t", "VoteCancel");
	}
}

void clearVotes() // Очищаем голоса за все карты
{
	for (int i = 0; i < 14; i++)
	{
		clientVotes[i] = 0;
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		canPlayerVote[i] = true;
	}
}

public Action mapVote(int client, int args) // !mapvote
{
	if (canVote == true)
	{
		if (L4D_IsMissionFinalMap() == true)
		{
			if (canPlayerVote[client] == false) // Игрок уже проголосовал
			{
				CPrintToChat(client, "%t", "PlayerCantVote");
			}
			else
			{
				showMenu(client);
			}
		}
		else // Если играем не последнюю карту
		{
			CPrintToChat(client, "%t", "VoteOnlyOnFinal");
		}
	}
	else
	{
		FormatEx(mapRealName, sizeof(mapRealName), "%T", mapSequence[winner], client);
		CPrintToChat(client, "%t", "VoteStoped", mapRealName);
	}
	return Plugin_Handled;
}

void resultsToConsole()
{
	PrintToConsoleAll("Map Winner: %s", mapSequence[winner]);
	for (int i = 0; i < 14; i++)
	{
		PrintToConsoleAll("%s: %i", mapSequence[i], clientVotes[i]);	
	}
}

stock Action mapVoteResult(int client, int args)
{
	FormatEx(mapRealName, sizeof(mapRealName), "%T", mapSequence[winner], client);
	CPrintToChat(client, "%t", "VoteStoped", mapRealName);
	return Plugin_Handled;
}

bool IsValidClient(client)
{
	if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsClientConnected(client) && !IsFakeClient(client)) {
		return true;
	}
	return false;
} 