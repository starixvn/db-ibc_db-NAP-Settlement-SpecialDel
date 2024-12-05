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

		,('ResourceE-Sports'		,'00'		,'Full Time'										,''	,''	)
		,('ResourceE-Sports'		,'M1'		,'Map 1'											,''	,''	)
		,('ResourceE-Sports'		,'M10'		,'Map 10'											,''	,''	)
		,('ResourceE-Sports'		,'M11'		,'Map 11'											,''	,''	)
		,('ResourceE-Sports'		,'M12'		,'Map 12'											,''	,''	)
		,('ResourceE-Sports'		,'M13'		,'Map 13'											,''	,''	)
		,('ResourceE-Sports'		,'M14'		,'Map 14'											,''	,''	)
		,('ResourceE-Sports'		,'M15'		,'Map 15'											,''	,''	)
		,('ResourceE-Sports'		,'M16'		,'Map 16'											,''	,''	)
		,('ResourceE-Sports'		,'M17'		,'Map 17'											,''	,''	)
		,('ResourceE-Sports'		,'M18'		,'Map 18'											,''	,''	)
		,('ResourceE-Sports'		,'M19'		,'Map 19'											,''	,''	)
		,('ResourceE-Sports'		,'M2'		,'Map 2'											,''	,''	)
		,('ResourceE-Sports'		,'M20'		,'Map 20'											,''	,''	)
		,('ResourceE-Sports'		,'M21'		,'Map 21'											,''	,''	)
		,('ResourceE-Sports'		,'M22'		,'Map 22'											,''	,''	)
		,('ResourceE-Sports'		,'M23'		,'Map 23'											,''	,''	)
		,('ResourceE-Sports'		,'M24'		,'Map 24'											,''	,''	)
		,('ResourceE-Sports'		,'M25'		,'Map 25'											,''	,''	)
		,('ResourceE-Sports'		,'M26'		,'Map 26'											,''	,''	)
		,('ResourceE-Sports'		,'M27'		,'Map 27'											,''	,''	)
		,('ResourceE-Sports'		,'M28'		,'Map 28'											,''	,''	)
		,('ResourceE-Sports'		,'M29'		,'Map 29'											,''	,''	)
		,('ResourceE-Sports'		,'M3'		,'Map 3'											,''	,''	)
		,('ResourceE-Sports'		,'M30'		,'Map 30'											,''	,''	)
		,('ResourceE-Sports'		,'M4'		,'Map 4'											,''	,''	)
		,('ResourceE-Sports'		,'M5'		,'Map 5'											,''	,''	)
		,('ResourceE-Sports'		,'M6'		,'Map 6'											,''	,''	)
		,('ResourceE-Sports'		,'M7'		,'Map 7'											,''	,''	)
		,('ResourceE-Sports'		,'M8'		,'Map 8'											,''	,''	)
		,('ResourceE-Sports'		,'M9'		,'Map 9'											,''	,''	)

		,('ResourceE-Sports'		,'9028'		,'Map @X Total Dragons'								,''	,''	)
		,('ResourceE-Sports'		,'9034'		,'Map @X Total Barons'								,''	,''	)
		,('ResourceE-Sports'		,'9040'		,'Map @X Total Inhibitors'							,''	,''	)
		,('ResourceE-Sports'		,'9046'		,'Map @X Total Tyrants'								,''	,''	)
		,('ResourceE-Sports'		,'9052'		,'Map @X Total Overlords'							,''	,''	)
		,('ResourceE-Sports'		,'9058'		,'Map @X Duration Over/Under (Mins)'				,''	,''	)
		,('ResourceE-Sports'		,'9059'		,'Map @X Rounds'									,''	,''	)
		,('ResourceE-Sports'		,'9074'		,'Map @X Overtime - Yes/No'							,''	,''	)
		,('ResourceE-Sports'		,'9065'		,'Map @X Total First Kill'							,''	,''	)
		,('ResourceE-Sports'		,'9002'		,'Map @X Total Kills'								,''	,''	)
		,('ResourceE-Sports'		,'9008'		,'Map @X Total Towers'								,''	,''	)
		,('ResourceE-Sports'		,'9012'		,'Map @X Total Roshans'								,''	,''	)
		,('ResourceE-Sports'		,'9018'		,'Map @X Total Barracks'							,''	,''	)
		,('ResourceE-Sports'		,'9024'		,'Map @X Total Turrets'								,''	,''	)
		,('ResourceE-Sports'		,'9066'		,'Map @X Clutches'									,''	,''	)
		,('ResourceE-Sports'		,'9090'		,'Map @X First Blood Time(Mins) Over/Under'			,''	,''	)
		,('ResourceE-Sports'		,'9091'		,'Map @X Total Kills at 10 Mins'					,''	,''	)
		,('ResourceE-Sports'		,'9093'		,'Map @X Total Kills at 20 Mins'					,''	,''	)
		,('ResourceE-Sports'		,'9113'		,'Map @X Lane With Most Turrets Destroyed'			,''	,''	)
		,('ResourceE-Sports'		,'9114'		,'Map @X First Turret Location'						,''	,''	)
		,('ResourceE-Sports'		,'9115'		,'Map @X Total Gold'								,''	,''	)
		,('ResourceE-Sports'		,'9121'		,'Map @X First Tyrant Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-Sports'		,'9122'		,'Map @X First Dark Tyrant'							,''	,''	)
		,('ResourceE-Sports'		,'9123'		,'Map @X First Overlord Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-Sports'		,'9124'		,'Map @X Will Storm Dragon Be Killed Yes/No'		,''	,''	)
		,('ResourceE-Sports'		,'9125'		,'Map @X First Herald'								,''	,''	)
		,('ResourceE-Sports'		,'9126'		,'Map @X First Herald Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-Sports'		,'9127'		,'Map @X First Baron Time(Mins) Over/Under'			,''	,''	)
		,('ResourceE-Sports'		,'9128'		,'Map @X First Baron No. Players Buff'				,''	,''	)
		,('ResourceE-Sports'		,'9129'		,'Map @X First Inhibitor Time'						,''	,''	)
		,('ResourceE-Sports'		,'9130'		,'Map @X First Inhibitor Location'					,''	,''	)
		,('ResourceE-Sports'		,'9131'		,'Map @X First Dragon Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-Sports'		,'9132'		,'Map @X Will Elder Dragon Be Killed Yes/No'		,''	,''	)
		,('ResourceE-Sports'		,'9133'		,'Map @X Will Any Aegis Be Snatched Yes/No'			,''	,''	)
		,('ResourceE-Sports'		,'9134'		,'Map @X First Tower Time(Mins) Over/Under'			,''	,''	)
		,('ResourceE-Sports'		,'9135'		,'Map @X First Tower Location'						,''	,''	)
		,('ResourceE-Sports'		,'9136'		,'Map @X First Roshan Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-Sports'		,'9137'		,'Map @X First Barrack Time(Mins) Over/Under'		,''	,''	)
		,('ResourceE-Sports'		,'9138'		,'Map @X First Barrack Location'					,''	,''	)
		,('ResourceE-Sports'		,'9139'		,'Map @X Total Bomb Detonations (excl. OT)'			,''	,''	)
		,('ResourceE-Sports'		,'9140'		,'Map @X Total Bomb Defuses (excl. OT)'				,''	,''	)
		,('ResourceE-Sports'		,'9141'		,'Map @X Lane With Most Turrets Destroyed (KOG)'	,''	,''	)
		,('ResourceE-Sports'		,'9142'		,'Map @X First Turret Location (KOG)'				,''	,''	)
		,('ResourceE-Sports'		,'9068'		,'Map @X Round @Y Moneyline'						,''	,''	)
		,('ResourceE-Sports'		,'9069'		,'Map @X Round @Y Total Kills'						,''	,''	)
		,('ResourceE-Sports'		,'9089'		,'Map @X First to @Y Kills Time(Mins) Over/Under'	,''	,''	)
		,('ResourceE-Sports'		,'9101'		,'Map @X @Y@O Kill'									,''	,''	)
		,('ResourceE-Sports'		,'K1'		,'st'												,''	,''	)
		,('ResourceE-Sports'		,'K2'		,'nd'												,''	,''	)
		,('ResourceE-Sports'		,'K3'		,'rd'												,''	,''	)
		,('ResourceE-Sports'		,'K4'		,'th'												,''	,''	)
		,('ResourceE-Sports'		,'N'		,'No'												,''	,''	)
		,('ResourceE-Sports'		,'NONE'		,'NONE'												,''	,''	)
		,('ResourceE-Sports'		,'9006'		,'Map @X First Blood'								,''	,''	)
		,('ResourceE-Sports'		,'9007'		,'Map @X First to @Y Kills'							,''	,''	)
		,('ResourceE-Sports'		,'9011'		,'Map @X First Tier @Y Towers'						,''	,''	)
		,('ResourceE-Sports'		,'9015'		,'Map @X 1st Roshan'								,''	,''	)
		,('ResourceE-Sports'		,'9016'		,'Map @X 2nd Roshan'								,''	,''	)
		,('ResourceE-Sports'		,'9017'		,'Map @X 3rd Roshan'								,''	,''	)
		,('ResourceE-Sports'		,'9021'		,'Map @X 1st Barracks'								,''	,''	)
		,('ResourceE-Sports'		,'9022'		,'Map @X 2nd Barracks'								,''	,''	)
		,('ResourceE-Sports'		,'9023'		,'Map @X 3rd Barracks'								,''	,''	)
		,('ResourceE-Sports'		,'9027'		,'Map @X First Tier @Y Turret'						,''	,''	)
		,('ResourceE-Sports'		,'9031'		,'Map @X 1st Dragon'								,''	,''	)
		,('ResourceE-Sports'		,'9032'		,'Map @X 2nd Dragon'								,''	,''	)
		,('ResourceE-Sports'		,'9033'		,'Map @X 3rd Dragon'								,''	,''	)
		,('ResourceE-Sports'		,'9037'		,'Map @X 1st Baron'									,''	,''	)
		,('ResourceE-Sports'		,'9038'		,'Map @X 2nd Baron'									,''	,''	)
		,('ResourceE-Sports'		,'9039'		,'Map @X 3rd Baron'									,''	,''	)
		,('ResourceE-Sports'		,'9043'		,'Map @X 1st Inhibitor'								,''	,''	)
		,('ResourceE-Sports'		,'9044'		,'Map @X 2nd Inhibitor'								,''	,''	)
		,('ResourceE-Sports'		,'9045'		,'Map @X 3rd Inhibitor'								,''	,''	)
		,('ResourceE-Sports'		,'9049'		,'Map @X 1st Tyrant'								,''	,''	)
		,('ResourceE-Sports'		,'9050'		,'Map @X 2nd Tyrant'								,''	,''	)
		,('ResourceE-Sports'		,'9051'		,'Map @X 3rd Tyrant'								,''	,''	)
		,('ResourceE-Sports'		,'9055'		,'Map @X 1st Overlord'								,''	,''	)
		,('ResourceE-Sports'		,'9056'		,'Map @X 2nd Overlord'								,''	,''	)
		,('ResourceE-Sports'		,'9057'		,'Map @X 3rd Overlord'								,''	,''	)
		,('ResourceE-Sports'		,'9062'		,'Map @X First to @Y Rounds'						,''	,''	)
		,('ResourceE-Sports'		,'9063'		,'Map @X First Half'								,''	,''	)
		,('ResourceE-Sports'		,'9064'		,'Map @X Second Half'								,''	,''	)
		,('ResourceE-Sports'		,'9067'		,'Map @X 16th Round'								,''	,''	)
		,('ResourceE-Sports'		,'9072'		,'Map @X Round @Y First Kill'						,''	,''	)
		,('ResourceE-Sports'		,'9073'		,'Map @X Round @Y Bomb Plant'						,''	,''	)
		,('ResourceE-Sports'		,'9075'		,'Map @X Final Round Bomb Plant'					,''	,''	)
		,('ResourceE-Sports'		,'9087'		,'Map @X Overtime'									,''	,''	)
		
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
