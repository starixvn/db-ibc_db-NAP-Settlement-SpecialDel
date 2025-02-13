/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241106@Louisa
	Task:  Result Amendment [Redmine:#209656]
	DB: DBPRO-bodb02

*/

USE bodb02
GO

BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #tmpRefResource 

	CREATE TABLE #tmpRefResource  ( RefId VARCHAR(20) ,ResourceId  VARCHAR(20), Resource_en NVARCHAR(50), Resource_ch NVARCHAR(50),	Resource_cs NVARCHAR(50), Resource_jp  NVARCHAR(50),Resource_it  NVARCHAR(50), Resource_th  NVARCHAR(50), Resource_ko  NVARCHAR(50), Resource_es  NVARCHAR(50), Resource_el  NVARCHAR(50), Resource_vn  NVARCHAR(50), Resource_pl  NVARCHAR(50), Resource_id  NVARCHAR(50))

	INSERT INTO  #tmpRefResource  ( RefId, ResourceId, Resource_en, Resource_ch, Resource_cs, Resource_jp,Resource_it, Resource_th, Resource_ko, Resource_es , Resource_el, Resource_vn, Resource_pl, Resource_id)		
	VALUES( 'ResourceBasketball'	,'00'		,'Full Time'	,N'全場'			,N'全场'		,'' ,''	,''					,''				,''	,'' ,''				,''		,''					)
		 ,( 'ResourceBasketball'	,'01'		,'First Half'	,N'上半場'		,N'上半場'	,'' ,''	,N'เต็มเวลา'			,''				,''	,'' ,N'Toàn trận'	,''		,N'Waktu Penuh'		)
		 ,( 'ResourceBasketball'	,'OT'		,'Over Time'	,N'加時'			,N'加时'		,'' ,''	,''					,''				,''	,'' ,''				,''		,''					)
		 ,( 'ResourceBasketball'	,'Q1'		,'Quarter 1'	,N'第 1 節'		,N'第 1 节'	,'' ,''	,N'การต่อเวลาพิเศษ'		,N'연장전'		,''	,'' ,N'Bù giờ'		,''		,N'Waktu Tambahan'	)
		 ,( 'ResourceBasketball'	,'Q2'		,'Quarter 2'	,N'第 2 節'		,N'第 2 节'	,'' ,''	,''					,''				,''	,'' ,''				,''		,''					)
		 ,( 'ResourceBasketball'	,'Q3'		,'Quarter 3'	,N'第 3 節'		,N'第 3 节'	,'' ,''	,''					,''				,''	,'' ,''				,''		,''					)
		 ,( 'ResourceBasketball'	,'Q4'		,'Quarter 4'	,N'第 4 節'		,N'第 4 节'	,'' ,''	,''					,''				,''	,'' ,''				,''		,''					)
		
		,('ResourceBasketball'		,'604'		,'Which Team To Score The First Basket'					,N'最先得分隊伍'					,N'最先得分队伍'				,''	,''	,''	,''	,''	,''	,''	,''	,'')
		,('ResourceBasketball'		,'605'		,'Which Team To Score The Last Basket'					,N'最後得分隊伍'					,N'最后得分队伍'				,''	,''	,''	,''	,''	,''	,''	,''	,'')
		,('ResourceBasketball'		,'606'		,'1H Race To @X Points'									,N'上半場首先獲得 @X 分'			,N'上半场首先获得 @X 分'		,''	,''	,''	,''	,''	,''	,''	,''	,'')
		,('ResourceBasketball'		,'607'		,'2H Race To @X Points'									,N'下半場首先獲得 @X 分'			,N'下半场首先获得 @X 分'		,''	,''	,''	,''	,''	,''	,''	,''	,'')
		,('ResourceBasketball'		,'613'		,'Quarter @X Race To @Y Points'							,N'第 @X 節首先獲得 @Y 分'		,N'第 @X 节首先获得 @Y 分'	,''	,''	,''	,''	,''	,''	,''	,''	,'')
		,('ResourceBasketball'		,'617'		,'Quarter @X Which Team To Score The Last Basket'		,N'第 @X 節最後得分球隊'			,N'第 @X 节最后得分球队'		,''	,''	,''	,''	,''	,''	,''	,''	,'')

		,('ResourceE-Sports'		,'00'		,'Full Time',N'全場'		,N'全场'			,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M1'		,'Map 1'	,N'地圖 1'	,N'地图 1'		,''	,''	,N'แผนที่ 1'	,''	,''	,''	,N'Bản Đồ 1'	,''	,N'Peta 1'	)
		,('ResourceE-Sports'		,'M10'		,'Map 10'	,N'地圖 10'	,N'地图 10'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M11'		,'Map 11'	,N'地圖 11'	,N'地图 11'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M12'		,'Map 12'	,N'地圖 12'	,N'地图 12'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M13'		,'Map 13'	,N'地圖 13'	,N'地图 13'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M14'		,'Map 14'	,N'地圖 14'	,N'地图 14'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M15'		,'Map 15'	,N'地圖 15'	,N'地图 15'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M16'		,'Map 16'	,N'地圖 16'	,N'地图 16'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M17'		,'Map 17'	,N'地圖 17'	,N'地图 17'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M18'		,'Map 18'	,N'地圖 18'	,N'地图 18'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M19'		,'Map 19'	,N'地圖 19'	,N'地图 19'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M2'		,'Map 2'	,N'地圖 2'	,N'地图 2'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M20'		,'Map 20'	,N'地圖 20'	,N'地图 20'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M21'		,'Map 21'	,N'地圖 21'	,N'地图 21'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M22'		,'Map 22'	,N'地圖 22'	,N'地图 22'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M23'		,'Map 23'	,N'地圖 23'	,N'地图 23'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M24'		,'Map 24'	,N'地圖 24'	,N'地图 24'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M25'		,'Map 25'	,N'地圖 25'	,N'地图 25'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M26'		,'Map 26'	,N'地圖 26'	,N'地图 26'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M27'		,'Map 27'	,N'地圖 27'	,N'地图 27'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M28'		,'Map 28'	,N'地圖 28'	,N'地图 28'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M29'		,'Map 29'	,N'地圖 29'	,N'地图 29'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M3'		,'Map 3'	,N'地圖 3'	,N'地图 3'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M30'		,'Map 30'	,N'地圖 30'	,N'地图 30'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M4'		,'Map 4'	,N'地圖 4'	,N'地图 4'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M5'		,'Map 5'	,N'地圖 5'	,N'地图 5'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M6'		,'Map 6'	,N'地圖 6'	,N'地图 6'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M7'		,'Map 7'	,N'地圖 7'	,N'地图 7'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M8'		,'Map 8'	,N'地圖 8'	,N'地图 8'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)
		,('ResourceE-Sports'		,'M9'		,'Map 9'	,N'地圖 9'	,N'地图 9'		,''	,''	,''			,''	,''	,''	,''				,''	,''	)

		,('ResourceE-Sports'		,'9028'		,'Map @X Total Dragons'														,N'地圖 @X 巨龍'							,N'地图 @X 巨龙'								,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9034'		,'Map @X Total Barons'														,N'地圖 @X 男爵'							,N'地图 @X 男爵'								,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9040'		,'Map @X Total Inhibitors'													,N'地圖 @X 水晶'							,N'地图 @X 水晶'								,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9046'		,'Map @X Total Tyrants'														,N'地圖 @X 暴君'							,N'地图 @X 暴君'								,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9052'		,'Map @X Total Overlords'													,N'地圖 @X 主宰'							,N'地图 @X 主宰'								,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9058'		,'Map @X Duration Over/Under (Mins)'										,N'地圖 @X 賽事時間(分) - 大小盤'			,N'地图 @X 赛事时间(分) - 大小盘'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9059'		,'Map @X Rounds'															,N'地圖 @X 回合獲勝'						,N'地图 @X 回合获胜'							,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9074'		,'Map @X Overtime - Yes/No'													,N'地圖 @X 加時賽 – 是/否'				,N'地图 @X 加时赛 – 是/否'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9065'		,'Map @X Total First Kill'													,N'地圖 @X 最多第一擊殺'					,N'地图 @X 最多第一击杀'						,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9002'		,'Map @X Total Kills'														,N'地圖 @X 擊殺總數' 						,N'地图 @X 击杀总数'							,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9008'		,'Map @X Total Towers'														,N'地圖 @X 防禦塔' 						,N'地图 @X 防御塔' 							,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9012'		,'Map @X Total Roshans'														,N'地圖 @X 肉山大魔王'					,N'地图 @X 肉山大魔王'					,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9018'		,'Map @X Total Barracks'													,N'地圖 @X 兵營' 						,N'地图 @X 兵营'							,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9024'		,'Map @X Total Turrets'														,N'地圖 @X 砲塔' 						,N'地图 @X 炮塔' 						,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9066'		,'Map @X Clutches'															,N'地圖 @X Clutches - 勝負盤'			,N'地图 @X Clutches - 胜负盘'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9090'		,'Map @X First Blood Time(Mins) Over/Under'									,N'地圖 @X 第一滴血時間(分) - 大小盤'		,N'地图 @X 第一滴血时间(分) - 大小盘'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9091'		,'Map @X Total Kills at 10 Mins'											,N'地圖 @X 10分鐘擊殺總數 - 讓分盤'		,N'地图 @X 10分钟击杀总数 - 让分盘'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9093'		,'Map @X Total Kills at 20 Mins'											,N'地圖 @X 20分鐘擊殺總數 - 讓分盤'		,N'地图 @X 20分钟击杀总数 - 让分盘'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9113'		,'Map @X Lane With Most Turrets Destroyed'									,N'地圖 @X 最多砲塔被摧毀路線'			,N'地图 @X 最多炮塔被摧毁路线'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9114'		,'Map @X First Turret Location'												,N'地圖 @X 第一砲塔位置'					,N'地图 @X 第一炮塔位置'						,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9115'		,'Map @X Total Gold'														,N'地圖 @X 總金錢勝負盤'					,N'地图 @X 总金钱胜负盘'						,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9121'		,'Map @X First Tyrant Time(Mins) Over/Under'								,N'地圖 @X 第一個暴君時間(分) - 大小盤'	,N'地图 @X 第一个暴君时间(分) - 大小盘'	,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9122'		,'Map @X First Dark Tyrant'													,N'地圖 @X 第一個暗影暴君'				,N'地图 @X 第一个暗影暴君'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9123'		,'Map @X First Overlord Time(Mins) Over/Under'								,N'地圖 @X 第一個主宰時間(分) - 大小盤'	,N'地图 @X 第一个主宰时间(分) - 大小盘'	,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9124'		,'Map @X Will Storm Dragon Be Killed Yes/No'								,N'地圖 @X 風暴龍王被殺 - 是/否'			,N'地图 @X 风暴龙王被杀 - 是/否'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9125'		,'Map @X First Herald'														,N'地圖 @X 第一個峽谷先鋒'					,N'地图 @X 第一个峡谷先锋'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9126'		,'Map @X First Herald Time(Mins) Over/Under'								,N'地圖 @X 第一個峽谷先鋒時間(分) - 大小盤'	,N'地图 @X 第一个峡谷先锋时间(分) - 大小盘',''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9127'		,'Map @X First Baron Time(Mins) Over/Under'									,N'地圖 @X 第一個男爵時間(分) - 大小盤'		,N'地图 @X 第一个男爵时间(分) - 大小盘'	,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9128'		,'Map @X First Baron No. Players Buff'										,N'地圖 @X 第一個男爵Buff選手總數 - 大小盤'	,N'地图 @X 第一个男爵Buff选手总数 - 大小盘',''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9129'		,'Map @X First Inhibitor Time'												,N'地圖 @X 第一個水晶時間(分) - 大小盤'		,N'地图 @X 第一个水晶时间(分) - 大小盘'	,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9130'		,'Map @X First Inhibitor Location'											,N'地圖 @X 第一個水晶位置'					,N'地图 @X 第一个水晶位置'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9131'		,'Map @X First Dragon Time(Mins) Over/Under'								,N'地圖 @X 第一個巨龍(分) - 大小盤'			,N'地图 @X 第一个巨龙(分) - 大小盘'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9132'		,'Map @X Will Elder Dragon Be Killed Yes/No'								,N'地圖 @X 遠古巨龍被殺 - 是/否'				,N'地图 @X 远古巨龙被杀 - 是/否'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9133'		,'Map @X Will Any Aegis Be Snatched Yes/No'									,N'地圖 @X 不朽守護被奪走 - 是/否'			,N'地图 @X 不朽守护被夺走 - 是/否'		,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9134'		,'Map @X First Tower Time(Mins) Over/Under'									,N'地圖 @X 第一個防禦塔時間(分) - 大小盤'		,N'地图 @X 第一个防御塔时间(分) - 大小盘'		,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9135'		,'Map @X First Tower Location'												,N'地圖 @X 第一個防禦塔位置'					,N'地图 @X 第一个防御塔位置'					,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9136'		,'Map @X First Roshan Time(Mins) Over/Under'								,N'地圖 @X 第一個肉山大魔王時間(分) - 大小盤'  ,N'地图 @X 第一个肉山大魔王时间(分) - 大小盘',''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9137'		,'Map @X First Barrack Time(Mins) Over/Under'								,N'地圖 @X 第一個兵營時間(分) - 大小盤'		,N'地图 @X 第一个兵营时间(分) - 大小盘'	,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9138'		,'Map @X First Barrack Location'											,N'地圖 @X 第一個兵營位置'					,N'地图 @X 第一个兵营位置'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9139'		,'Map @X Total Bomb Detonations (excl. OT)'									,N'地圖 @X 炸彈引爆總數(排除加時) - 大小盤'	,N'地图 @X 炸弹引爆总数(排除加时) - 大小盘',''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9140'		,'Map @X Total Bomb Defuses (excl. OT)'										,N'地圖 @X 炸彈拆除總數(排除加時) - 大小盤'	,N'地图 @X 炸弹拆除总数(排除加时) - 大小盘',''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9141'		,'Map @X Lane With Most Turrets Destroyed (KOG)'							,N'地圖 @X 最多砲塔被摧毀路線(KOG)'			,N'地图 @X 最多炮塔被摧毁路线'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9142'		,'Map @X First Turret Location (KOG)'										,N'地圖 @X 第一砲塔位置(KOG)'					,N'地图 @X 第一炮塔位置(KOG)'					,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9068'		,'Map @X Round @Y Moneyline'												,N'地圖 @X 回合 @Y 勝負盤'					,N'地图 @X 回合 @Y 胜负盘'						,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9069'		,'Map @X Round @Y Total Kills'												,N'地圖 @X 回合 @Y 擊殺總數 - 勝負盤'			,N'地图 @X 回合 @Y 击杀总数 - 胜负盘'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9089'		,'Map @X First to @Y Kills Time(Mins) Over/Under'							,N'地圖 @X 最先擊殺 @Y 數量時間(分) - 大小盤'	,N'地图 @X 最先击杀 @Y 数量时间(分) - 大小盘',''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9101'		,'Map @X @O Kill'															,N'地圖 @X @O擊殺'						,N'地图 @X @O击杀'	,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'K1'		,'1st'								,N'第一'		,N'第一'		,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'K2'		,'2nd'								,N'第二'		,N'第二'		,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'K3'		,'3rd'								,N'第三'		,N'第三'		,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'K4'		,'4th'								,N'第四'		,N'第四'		,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'K5'		,'5th'								,N'第五'		,N'第五'		,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'K6'		,'6th'								,N'第六'		,N'第六'		,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'K7'		,'7th'								,N'第七'		,N'第七'		,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'K8'		,'8th'								,N'第八'		,N'第八'		,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'K9'		,'9th'								,N'第九'		,N'第九'		,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'K10'		,'10th'								,N'第十'		,N'第十'		,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'K15'		,'15th'								,N'第十五'	,N'第十五'	,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'K20'		,'20th'								,N'第二十'	,N'第二十'	,''	,''	,''	,''	,''	,''	,''	,''	,'' )
		,('ResourceE-Sports'		,'9006'		,'Map @X First Blood'				,N'地圖 @X 第一滴血'				,N'地图 @X 第一滴血'					,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9007'		,'Map @X First to @Y Kills'			,N'地圖 @X 最先擊殺 @Y 數量'		,N'地图 @X 最先击杀 @Y 数量'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9011'		,'Map @X First Tier @Y Towers'		,N'地圖 @X 第一防禦塔 - 第 @Y 層'	,N'地图 @X 第一防御塔 - 第 @Y 层'		,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9015'		,'Map @X 1st Roshan'				,N'地圖 @X 第一肉山大魔王'		,N'地图 @X 第一肉山大魔王'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9016'		,'Map @X 2nd Roshan'				,N'地圖 @X 第二肉山大魔王'		,N'地图 @X 第二肉山大魔王'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9017'		,'Map @X 3rd Roshan'				,N'地圖 @X 第三肉山大魔王'		,N'地图 @X 第三肉山大魔王'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9021'		,'Map @X 1st Barracks'				,N'地圖 @X 第一個兵營'			,N'地图 @X 第一个兵营'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9022'		,'Map @X 2nd Barracks'				,N'地圖 @X 第二組兵營'			,N'地图 @X 第二组兵营'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9023'		,'Map @X 3rd Barracks'				,N'地圖 @X 第三組兵營'			,N'地图 @X 第三组兵营'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9027'		,'Map @X First Tier @Y Turret'		,N'地圖 @X 第一砲塔 - 第 @Y 層'	,N'地图 @X 第一炮塔 - 第 @Y 层'		,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9031'		,'Map @X 1st Dragon'				,N'地圖 @X 第一隻巨龍'			,N'地图 @X 第一只巨龙'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9032'		,'Map @X 2nd Dragon'				,N'地圖 @X 第二隻巨龍'			,N'地图 @X 第二只巨龙'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9033'		,'Map @X 3rd Dragon'				,N'地圖 @X 第三隻巨龍'			,N'地图 @X 第三只巨龙'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9037'		,'Map @X 1st Baron'					,N'地圖 @X 第一個男爵'			,N'地图 @X 第一个男爵'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9038'		,'Map @X 2nd Baron'					,N'地圖 @X 第二個男爵'			,N'地图 @X 第二个男爵'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9039'		,'Map @X 3rd Baron'					,N'地圖 @X 第三個男爵'			,N'地图 @X 第三个男爵'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9043'		,'Map @X 1st Inhibitor'				,N'地圖 @X 第一個水晶'			,N'地图 @X 第一个水晶'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9044'		,'Map @X 2nd Inhibitor'				,N'地圖 @X 第二個水晶'			,N'地图 @X 第二个水晶'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9045'		,'Map @X 3rd Inhibitor'				,N'地圖 @X 第三個水晶'			,N'地图 @X 第三个水晶'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9049'		,'Map @X 1st Tyrant'				,N'地圖 @X 第一個暴君'			,N'地图 @X 第一个暴君'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9050'		,'Map @X 2nd Tyrant'				,N'地圖 @X 第二個暴君'			,N'地图 @X 第二个暴君'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9051'		,'Map @X 3rd Tyrant'				,N'地圖 @X 第三個暴君'			,N'地图 @X 第三个暴君'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9055'		,'Map @X 1st Overlord'				,N'地圖 @X 第一個主宰'			,N'地图 @X 第一个主宰'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9056'		,'Map @X 2nd Overlord'				,N'地圖 @X 第二個主宰'			,N'地图 @X 第二个主宰'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9057'		,'Map @X 3rd Overlord'				,N'地圖 @X 第三個主宰'			,N'地图 @X 第三个主宰'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9062'		,'Map @X First to @Y Rounds'		,N'地圖 @X 最先贏得 @Y 個回合'	,N'地图 @X 最先赢得 @Y 个回合'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9063'		,'Map @X First Half'				,N'地圖 @X 上半場'				,N'地图 @X 上半场'					,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9064'		,'Map @X Second Half'				,N'地圖 @X 下半場'				,N'地图 @X 下半场'					,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9067'		,'Map @X 16th Round'				,N'地圖 @X 第 16 回合'			,N'地图 @X 第 16 回合'				,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9072'		,'Map @X Round @Y First Kill'		,N'地圖 @X 回合 @Y 最先擊殺'		,N'地图 @X 回合 @Y 最先击杀'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9073'		,'Map @X Round @Y Bomb Plant'		,N'地圖 @X 回合 @Y 炸彈安裝'		,N'地图 @X 回合 @Y 炸弹安装'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9075'		,'Map @X Final Round Bomb Plant'	,N'地圖 @X 最終回合炸彈安裝'		,N'地图 @X 最终回合炸弹安装'			,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		,('ResourceE-Sports'		,'9087'		,'Map @X Overtime'					,N'地圖 @X 加時賽'				,N'地图 @X 加时赛'					,''	,''	,''	,''	,''	,''	,''	,''	,''	)
		
		,('ResultSettlement'		,'D'		,'Draw'								,''	,''	,''	,''	,''	,''	,''	,''	,''	,''	,'')
		,('ResultSettlement'		,'T'		,'Top'								,N'上路'			,N'上路'			,''	,''	,N'บน'				,''	,''	,''	,N'Trên'			,'' ,''					)
		,('ResultSettlement'		,'MB'		,'Middle or Bottom'					,N'中路/下路'	,N'中路/下路'	,''	,''	,N'กลางหรือล่าง'		,''	,''	,''	,N'Dưới'			,'' ,N'Tengah atau Bawah'	)
		,('ResultSettlement'		,'Bottom'	,'Bottom'							,N'下路'			,N'下路'			,''	,''	,N'ล่าง'				,''	,''	,''	,N'Dưới'			,'' ,N'Bawah'	)
		,('ResultSettlement'		,'TM'		,'Top or Middle'					,N'上路/中路'	,N'上路/中路'	,''	,''	,N'บนหรือกลาง'		,''	,''	,''	,N'Trên/Giữa'		,'' ,N'Atas atau Tengah'	)
		,('ResultSettlement'		,'M'		,'Middle'							,N'中路'			,N'中路'			,''	,''	,N'กลา'				,''	,''	,''	,N'Giữa'			,'' ,N'Tenga'	)
		,('ResultSettlement'		,'TB'		,'Top or Bottom'					,N'上路/下路'	,N'上路/下路'	,''	,''	,N'บนหรือล่าง'			,''	,''	,''	,N'Trên/Dưới'		,'' ,N'Atas atau Bawah'	)
		,('ResultSettlement'		,'O'		,'Overlord'							,N'主宰'			,N'主宰'			,''	,''	,N''				,''	,''	,''	,N''				,'' ,N'Raja Penguasa'	)
		,('ResultSettlement'		,'TR'		,'Tyrant'							,N'暴君'			,N'暴君'			,''	,''	,N''				,''	,''	,''	,N''				,'' ,N'Tirani'	)
		,('ResultSettlement'		,'OM'		,'Overlord or Middle'				,N'主宰/中路'	,N'主宰/中路'	,''	,''	,N'Overlord หรือกลาง'	,''	,''	,''	,N'Overlord/Giữa'	,'' ,N'Raja Penguasa atau Tengah'	)
		,('ResultSettlement'		,'GBT5'		,'@Home min @Away sec'				,''	,''	,''	,''	,''	,''	,''	,''	,''	,''	,''		)
	
	/*
		---check existing data
		SELECT tmp.RefId
			,tmp.ResourceId
			,tmp.Resource_en, tmp.Resource_ch, tmp.Resource_cs
		FROM #tmpRefResource  tmp
			INNER JOIN RefResource r WITH(NOLOCK) 
				ON tmp.RefId = r.RefId
					AND tmp.ResourceId = r.ResourceId
					
	*/

	
	INSERT INTO RefResource
	(
		RefId
		,ResourceId
		,Resource_en, Resource_ch, Resource_cs
	)
	SELECT tmp.RefId
		,tmp.ResourceId
		,tmp.Resource_en, tmp.Resource_ch, tmp.Resource_cs
	FROM #tmpRefResource  tmp
		LEFT JOIN RefResource r WITH(NOLOCK) 
			ON tmp.RefId = r.RefId
				AND tmp.ResourceId = r.ResourceId
	WHERE r.RefId IS NULL
 
	/*
		select * from #tmpRefResource where RefId = 'ResourceE-sports'--115

		UPDATE r
		SET r.Resource_en = tmp.Resource_en
			, r.Resource_ch =tmp.Resource_ch
			, r.Resource_cs =tmp.Resource_cs
		FROM #tmpRefResource  tmp
			INNER JOIN RefResource r WITH(NOLOCK) 
				ON tmp.RefId = r.RefId
					AND tmp.ResourceId = r.ResourceId
		WHERE  tmp.RefId = 'ResourceE-sports'
	*/

	--SELECT * FROM dbo.RefResource	WHERE RefId = 'ResultSettlement' AND ResourceId = 'D'

	UPDATE dbo.RefResource	WITH(ROWLOCK, UPDLOCK)
	SET Resource_ch = N'和局'
		,Resource_cs = N'和局'
	WHERE RefId = 'ResultSettlement' 
	AND ResourceId = 'D'

	--SELECT * FROM dbo.RefResource	WHERE RefId = 'ResultSettlement' AND ResourceId = 'GBT5'

	UPDATE dbo.RefResource	WITH(ROWLOCK, UPDLOCK)
	SET Resource_ch = N'@Home分鐘@Away秒  '
		,Resource_cs = N'@Home分钟@Away秒  '
	WHERE RefId = 'ResultSettlement' 
	AND ResourceId = 'GBT5'


END
GO
