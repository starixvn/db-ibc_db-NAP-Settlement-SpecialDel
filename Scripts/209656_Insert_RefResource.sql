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

	CREATE TABLE #tmpRefResource  ( RefId VARCHAR(20) ,ResourceId  VARCHAR(20), Resource_en NVARCHAR(50), Resource_ch NVARCHAR(50),	Resource_cs NVARCHAR(50) )

	INSERT INTO  #tmpRefResource  ( RefId, ResourceId, Resource_en, Resource_ch, Resource_cs)		
	VALUES( 'ResourceBasketball'	,'00'		,'Full Time'										,'' ,''	)
		 ,( 'ResourceBasketball'	,'01'		,'Half Time'										,'' ,''	)
		 ,( 'ResourceBasketball'	,'OT'		,'Over Time'										,'' ,''	)
		 ,( 'ResourceBasketball'	,'Q1'		,'Quarter 1'										,'' ,''	)
		 ,( 'ResourceBasketball'	,'Q2'		,'Quarter 2'										,'' ,''	)
		 ,( 'ResourceBasketball'	,'Q3'		,'Quarter 3'										,'' ,''	)
		 ,( 'ResourceBasketball'	,'Q4'		,'Quarter 4'										,'' ,''	)
		
		,('ResourceBasketball'		,'604'		,'Which Team To Score The First Basket'				,''	,''	)
		,('ResourceBasketball'		,'605'		,'Which Team To Score The Last Basket'				,''	,''	)
		,('ResourceBasketball'		,'606'		,'1H Race To @X Points'								,''	,''	)
		,('ResourceBasketball'		,'607'		,'2H Race To @X Points'								,''	,''	)
		,('ResourceBasketball'		,'613'		,'Quarter @X Race To @Y Points'						,''	,''	)
		,('ResourceBasketball'		,'617'		,'Quarter @X Which Team To Score The Last Basket'	,''	,''	)

		,('ResourceE-sports'		,'00'		,'Full Time'										,''	,''	)
		,('ResourceE-sports'		,'M1'		,'Map 1'											,''	,''	)
		,('ResourceE-sports'		,'M10'		,'Map 10'											,''	,''	)
		,('ResourceE-sports'		,'M11'		,'Map 11'											,''	,''	)
		,('ResourceE-sports'		,'M12'		,'Map 12'											,''	,''	)
		,('ResourceE-sports'		,'M13'		,'Map 13'											,''	,''	)
		,('ResourceE-sports'		,'M14'		,'Map 14'											,''	,''	)
		,('ResourceE-sports'		,'M15'		,'Map 15'											,''	,''	)
		,('ResourceE-sports'		,'M16'		,'Map 16'											,''	,''	)
		,('ResourceE-sports'		,'M17'		,'Map 17'											,''	,''	)
		,('ResourceE-sports'		,'M18'		,'Map 18'											,''	,''	)
		,('ResourceE-sports'		,'M19'		,'Map 19'											,''	,''	)
		,('ResourceE-sports'		,'M2'		,'Map 2'											,''	,''	)
		,('ResourceE-sports'		,'M20'		,'Map 20'											,''	,''	)
		,('ResourceE-sports'		,'M21'		,'Map 21'											,''	,''	)
		,('ResourceE-sports'		,'M22'		,'Map 22'											,''	,''	)
		,('ResourceE-sports'		,'M23'		,'Map 23'											,''	,''	)
		,('ResourceE-sports'		,'M24'		,'Map 24'											,''	,''	)
		,('ResourceE-sports'		,'M25'		,'Map 25'											,''	,''	)
		,('ResourceE-sports'		,'M26'		,'Map 26'											,''	,''	)
		,('ResourceE-sports'		,'M27'		,'Map 27'											,''	,''	)
		,('ResourceE-sports'		,'M28'		,'Map 28'											,''	,''	)
		,('ResourceE-sports'		,'M29'		,'Map 29'											,''	,''	)
		,('ResourceE-sports'		,'M3'		,'Map 3'											,''	,''	)
		,('ResourceE-sports'		,'M30'		,'Map 30'											,''	,''	)
		,('ResourceE-sports'		,'M4'		,'Map 4'											,''	,''	)
		,('ResourceE-sports'		,'M5'		,'Map 5'											,''	,''	)
		,('ResourceE-sports'		,'M6'		,'Map 6'											,''	,''	)
		,('ResourceE-sports'		,'M7'		,'Map 7'											,''	,''	)
		,('ResourceE-sports'		,'M8'		,'Map 8'											,''	,''	)
		,('ResourceE-sports'		,'M9'		,'Map 9'											,''	,''	)

		,('ResourceE-sports'		,'9028'		,'Map @X Total Dragons'								,''	,''	)
		,('ResourceE-sports'		,'9034'		,'Map @X Total Barons'								,''	,''	)
		,('ResourceE-sports'		,'9040'		,'Map @X Total Inhibitors'							,''	,''	)
		,('ResourceE-sports'		,'9046'		,'Map @X Total Tyrants'								,''	,''	)
		,('ResourceE-sports'		,'9052'		,'Map @X Total Overlords'							,''	,''	)
		,('ResourceE-sports'		,'9058'		,'Map @X Duration Over/Under (Mins)'				,''	,''	)
		,('ResourceE-sports'		,'9059'		,'Map @X Rounds'									,''	,''	)
		,('ResourceE-sports'		,'9074'		,'Map @X Overtime - Yes/No'							,''	,''	)
		,('ResourceE-sports'		,'9065'		,'Map @X Total First Kill'							,''	,''	)
		,('ResourceE-sports'		,'9002'		,'Map @X Total Kills'								,''	,''	)
		,('ResourceE-sports'		,'9008'		,'Map @X Total Towers'								,''	,''	)
		,('ResourceE-sports'		,'9012'		,'Map @X Total Roshans'								,''	,''	)
		,('ResourceE-sports'		,'9018'		,'Map @X Total Barracks'							,''	,''	)
		,('ResourceE-sports'		,'9024'		,'Map @X Total Turrets'								,''	,''	)
		,('ResourceE-sports'		,'9066'		,'Map @X Clutches'									,''	,''	)
		,('ResourceE-sports'		,'9090'		,'Map @X First Blood Time(Mins) Over/Under'			,''	,''	)
		,('ResourceE-sports'		,'9091'		,'Map @X Total Kills at 10 Mins'					,''	,''	)
		,('ResourceE-sports'		,'9093'		,'Map @X Total Kills at 20 Mins'					,''	,''	)
		,('ResourceE-sports'		,'9113'		,'Map @X Lane With Most Turrets Destroyed'			,''	,''	)
		,('ResourceE-sports'		,'9114'		,'Map @X First Turret Location'						,''	,''	)
		,('ResourceE-sports'		,'9115'		,'Map @X Total Gold'								,''	,''	)
		,('ResourceE-sports'		,'9121'		,'Map @X First Tyrant Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-sports'		,'9122'		,'Map @X First Dark Tyrant'							,''	,''	)
		,('ResourceE-sports'		,'9123'		,'Map @X First Overlord Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-sports'		,'9124'		,'Map @X Will Storm Dragon Be Killed Yes/No'		,''	,''	)
		,('ResourceE-sports'		,'9125'		,'Map @X First Herald'								,''	,''	)
		,('ResourceE-sports'		,'9126'		,'Map @X First Herald Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-sports'		,'9127'		,'Map @X First Baron Time(Mins) Over/Under'			,''	,''	)
		,('ResourceE-sports'		,'9128'		,'Map @X First Baron No. Players Buff'				,''	,''	)
		,('ResourceE-sports'		,'9129'		,'Map @X First Inhibitor Time'						,''	,''	)
		,('ResourceE-sports'		,'9130'		,'Map @X First Inhibitor Location'					,''	,''	)
		,('ResourceE-sports'		,'9131'		,'Map @X First Dragon Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-sports'		,'9132'		,'Map @X Will Elder Dragon Be Killed Yes/No'		,''	,''	)
		,('ResourceE-sports'		,'9133'		,'Map @X Will Any Aegis Be Snatched Yes/No'			,''	,''	)
		,('ResourceE-sports'		,'9134'		,'Map @X First Tower Time(Mins) Over/Under'			,''	,''	)
		,('ResourceE-sports'		,'9135'		,'Map @X First Tower Location'						,''	,''	)
		,('ResourceE-sports'		,'9136'		,'Map @X First Roshan Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-sports'		,'9137'		,'Map @X First Barrack Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-sports'		,'9138'		,'Map @X First Barrack Location'					,''	,''	)
		,('ResourceE-sports'		,'9139'		,'Map @X Total Bomb Detonations (excl. OT)'			,''	,''	)
		,('ResourceE-sports'		,'9140'		,'Map @X Total Bomb Defuses (excl. OT)'				,''	,''	)
		,('ResourceE-sports'		,'9141'		,'Map @X Lane With Most Turrets Destroyed (KOG)'	,''	,''	)
		,('ResourceE-sports'		,'9142'		,'Map @X First Turret Location (KOG)'				,''	,''	)
		,('ResourceE-sports'		,'9068'		,'Map @X Round @Y Moneyline'						,''	,''	)
		,('ResourceE-sports'		,'9069'		,'Map @X Round @Y Total Kills'						,''	,''	)
		,('ResourceE-sports'		,'9089'		,'Map @X First to @Y Kills Time(Mins) Over/Under'	,''	,''	)
		,('ResourceE-sports'		,'9101'		,'Map @X @K Kill'									,''	,''	)
		,('ResourceE-sports'		,'K1'		,'st'												,''	,''	)
		,('ResourceE-sports'		,'K2'		,'nd'												,''	,''	)
		,('ResourceE-sports'		,'K3'		,'rd'												,''	,''	)
		,('ResourceE-sports'		,'K4'		,'th'												,''	,''	)
		,('ResourceE-sports'		,'N'		,'No'												,''	,''	)
		,('ResourceE-sports'		,'NONE'		,'NONE'												,''	,''	)
		,('ResourceE-sports'		,'9006'		,'Map @X First Blood'								,''	,''	)
		,('ResourceE-sports'		,'9007'		,'Map @X First to @Y Kills'							,''	,''	)
		,('ResourceE-sports'		,'9011'		,'Map @X First Tier @Y Towers'						,''	,''	)
		,('ResourceE-sports'		,'9015'		,'Map @X 1st Roshan'								,''	,''	)
		,('ResourceE-sports'		,'9016'		,'Map @X 2nd Roshan'								,''	,''	)
		,('ResourceE-sports'		,'9017'		,'Map @X 3rd Roshan'								,''	,''	)
		,('ResourceE-sports'		,'9021'		,'Map @X 1st Barracks'								,''	,''	)
		,('ResourceE-sports'		,'9022'		,'Map @X 2nd Barracks'								,''	,''	)
		,('ResourceE-sports'		,'9023'		,'Map @X 3rd Barracks'								,''	,''	)
		,('ResourceE-sports'		,'9027'		,'Map @X First Tier @Y Turret'						,''	,''	)
		,('ResourceE-sports'		,'9031'		,'Map @X 1st Dragon'								,''	,''	)
		,('ResourceE-sports'		,'9032'		,'Map @X 2nd Dragon'								,''	,''	)
		,('ResourceE-sports'		,'9033'		,'Map @X 3rd Dragon'								,''	,''	)
		,('ResourceE-sports'		,'9037'		,'Map @X 1st Baron'									,''	,''	)
		,('ResourceE-sports'		,'9038'		,'Map @X 2nd Baron'									,''	,''	)
		,('ResourceE-sports'		,'9039'		,'Map @X 3rd Baron'									,''	,''	)
		,('ResourceE-sports'		,'9043'		,'Map @X 1st Inhibitor'								,''	,''	)
		,('ResourceE-sports'		,'9044'		,'Map @X 2nd Inhibitor'								,''	,''	)
		,('ResourceE-sports'		,'9045'		,'Map @X 3rd Inhibitor'								,''	,''	)
		,('ResourceE-sports'		,'9049'		,'Map @X 1st Tyrant'								,''	,''	)
		,('ResourceE-sports'		,'9050'		,'Map @X 2nd Tyrant'								,''	,''	)
		,('ResourceE-sports'		,'9051'		,'Map @X 3rd Tyrant'								,''	,''	)
		,('ResourceE-sports'		,'9055'		,'Map @X 1st Overlord'								,''	,''	)
		,('ResourceE-sports'		,'9056'		,'Map @X 2nd Overlord'								,''	,''	)
		,('ResourceE-sports'		,'9057'		,'Map @X 3rd Overlord'								,''	,''	)
		,('ResourceE-sports'		,'9062'		,'Map @X First to @Y Rounds'						,''	,''	)
		,('ResourceE-sports'		,'9063'		,'Map @X First Half'								,''	,''	)
		,('ResourceE-sports'		,'9064'		,'Map @X Second Half'								,''	,''	)
		,('ResourceE-sports'		,'9067'		,'Map @X 16th Round'								,''	,''	)
		,('ResourceE-sports'		,'9072'		,'Map @X Round @Y First Kill'						,''	,''	)
		,('ResourceE-sports'		,'9073'		,'Map @X Round @Y Bomb Plant'						,''	,''	)
		,('ResourceE-sports'		,'9075'		,'Map @X Final Round Bomb Plant'					,''	,''	)
		,('ResourceE-sports'		,'9087'		,'Map @X Overtime'									,''	,''	)
		
		,('ResultSettlement'		,'None'		,'None'												,''	,''	)
		,('ResultSettlement'		,'Y'		,'Yes'												,''	,''	)
		,('ResultSettlement'		,'N'		,'No'												,''	,''	)
		,('ResultSettlement'		,'D'		,'Draw'												,''	,''	)
		,('ResultSettlement'		,'T'		,'Top'												,''	,''	)
		,('ResultSettlement'		,'MB'		,'Middle or Bottom'									,''	,''	)
		,('ResultSettlement'		,'B'		,'Bottom'											,''	,''	)
		,('ResultSettlement'		,'TM'		,'Top or Middle'									,''	,''	)
		,('ResultSettlement'		,'M'		,'Middle'											,''	,''	)
		,('ResultSettlement'		,'TB'		,'Top or Bottom'									,''	,''	)
		,('ResultSettlement'		,'O'		,'Overlord'											,''	,''	)
		,('ResultSettlement'		,'TR'		,'Tyrant'											,''	,''	)
		,('ResultSettlement'		,'OM'		,'Overlord or Middle'								,''	,''	)
		,('ResultSettlement'		,'GBT5'		,'@Home min @Away sec'								,''	,''	)
	
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
 
 


END
GO
