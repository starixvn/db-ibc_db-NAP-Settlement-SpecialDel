/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Settlement_1_CashoutSel
	@SelectedResources VARCHAR(MAX)
	,@Action			VARCHAR(10)     = 'CAL'
	,@Markets			VARCHAR(MAX)
AS
/*
	Created by: 20250214@Louisa
	Task: get list CO ticket [Redmine:#217573]

	Revisions:
		- 20250214@Louisa: get list CO ticket [Redmine:#217573] 
		
	Param's Explanation:
		@SelectedResources= '<Resources>
									<Resource Id="01" Home= "1" Away="2"/>
									<Resource Id="00" Home= "2" Away="2"/>
							   </Resources>'

		@Markets= [
					{
						"BetType": 1,
						"GoalLine": 0.5

					 }
				  ]

		'[{"MatchId":83773433,"BetType":1,"GoalLine":-1.75},{"MatchId":83773433,"BetType":3,"GoalLine":1.75},{"MatchId":83773433,"BetType":7,"GoalLine":-1.75},{"MatchId":83773433,"BetType":8,"GoalLine":1.75}]'
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @handle		INT 
		,@hth INT
		,@hta INT
		,@fth INT
		,@fta INT	 
	 
	DECLARE @tmpResources TABLE( ResourceID VARCHAR(20),HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	DECLARE @tmpMarketDetail TABLE ( MatchId INT, BetType  SMALLINT, betteam VARCHAR(50), way INT, GoalLine  SMALLMONEY, hdp1 SMALLMONEY, hdp2 SMALLMONEY, SDTRecord TINYINT, pfId SMALLINT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	DECLARE @tmp_Settled TABLE ( bettype SMALLINT, ResourceID VARCHAR(20), hdp  SMALLMONEY, betteam VARCHAR(50), way INT, outcome TINYINT)

	---not support UNDO
	IF @Action = 'UNDO'
	BEGIN
		SELECT bettype, ResourceID, hdp , betteam, way, outcome
		FROM @tmp_Settled
		RETURN
	END

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

	INSERT INTO @tmpResources(ResourceID, HomeValue,AwayValue)
	SELECT Id, Home, Away
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id VARCHAR(20), Home VARCHAR(50), Away VARCHAR(50)) AS tbl

	EXEC sp_xml_removedocument @handle

	SELECT @hth = MAX(CASE WHEN ResourceID = '01' THEN HomeValue ELSE 0 END)
			,@hta = MAX(CASE WHEN ResourceID = '01' THEN AwayValue ELSE 0 END)
			,@fth = MAX(CASE WHEN ResourceID = '00' THEN HomeValue ELSE 0 END)
			,@fta = MAX(CASE WHEN ResourceID = '00' THEN AwayValue ELSE 0 END)
	FROM @tmpResources

	----bet option
	;WITH cte_BetOption ( BetType, betteam, way ) AS 
	(	SELECT b.bettype,bt.betteam, bt.way
		FROM ( VALUES (1),(2),(7)) AS b(bettype)
			CROSS APPLY ( SELECT * FROM ( VALUES ('h' ,1),('a' ,2) ) AS T(betteam, way) )bt
	
		UNION ALL
		SELECT b.bettype,bt.betteam, bt.way
		FROM ( VALUES (3),(8)) AS b(bettype)
			CROSS APPLY ( SELECT * FROM ( VALUES ('h' ,3),('a' ,4) ) AS T(betteam, way) )bt
	
		UNION ALL
		SELECT b.bettype,bt.betteam, bt.way
		FROM ( VALUES (5),(15)) AS b(bettype)
			CROSS APPLY ( SELECT * FROM ( VALUES ('1' ,5),('2' ,6), ('x' ,7) ) AS T(betteam, way) )bt
	)
	,cte_Market (MatchId, Bettype, GoalLine, SDTRecord) AS
	(	SELECT js.MatchId, js.BetType, js.GoalLine, CASE WHEN @Action IN ( 'REFUND', 'REFUND-FT') AND ISNULL(EventStatusReason,0) = 4 THEN 4 ELSE 0 END
		FROM OPENJSON(@Markets) WITH (MatchId INT, BetType  SMALLINT, GoalLine  SMALLMONEY ) js
			INNER JOIN match m WITH(NOLOCK) 
				ON js.Matchid = m.matchid
			INNER JOIN cte_BetOption o 
				ON js.BetType = o.BetType
	)

	INSERT INTO @tmpMarketDetail ( MatchId, BetType , betteam, way, GoalLine, hdp1, hdp2, SDTRecord, pfId, ResourceId, HomeValue, AwayValue )
	SELECT mk.MatchId, mk.BetType , o.betteam, o.way, mk.GoalLine
			,CASE WHEN mk.bettype IN (1,7) AND mk.GoalLine < 0  THEN ABS(mk.GoalLine)
				WHEN mk.bettype IN (3,8) THEN mk.GoalLine
				ELSE 0 
			    END AS hp1
			,CASE WHEN mk.bettype IN (1,7) AND mk.GoalLine > 0 THEN mk.GoalLine 
				ELSE 0 
				END AS hdp2
			, mk.SDTRecord, sp.pfId, sp.ResourceId, r.HomeValue, r.AwayValue
	FROM cte_BetOption o
		INNER JOIN cte_Market mk ON o.BetType = mk.Bettype
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) ON mk.bettype = sp.bettype AND sp.SportType = 1
		INNER JOIN @tmpResources r ON sp.ResourceID = r.ResourceID
	WHERE 1 = CASE 
						WHEN @Action IN ('CAL-HT', 'REFUND-HT') AND sp.GroupType = 'HT' THEN 1
						WHEN @Action IN ('CAL-FT', 'REFUND-FT') AND sp.GroupType = 'FT' THEN 1
						WHEN @Action IN ('CAL', 'REFUND') THEN 1
						ELSE 0
					END
	
	IF @Action IN ( 'CAL','CAL-HT','CAL-FT')
	BEGIN
		INSERT INTO @tmp_Settled  (bettype, ResourceID, hdp , betteam, way, outcome )
		SELECT mk.bettype, mk.ResourceID, mk.GoalLine as hpd , mk.betteam, mk.way
				,CASE WHEN o.modds = 0.25  THEN 2 ---'HAFT_WON'
					  WHEN o.modds > 0.25  THEN 0 ---'WON'
					  WHEN o.modds = 0	   THEN 5 ---'CASH_BACK'
					  WHEN o.modds = -0.25  THEN 3 ---'HAFT_LOSE'
					  WHEN o.modds < -0.25  THEN 1 ---'LOSE'
					END AS outcome
		FROM	@tmpMarketDetail mk
			CROSS APPLY dbo.f_Set_Calculate_modds_major(mk.pfID, mk.betteam, mk.hdp1, mk.hdp2, mk.HomeValue, mk.AwayValue, 0, 0, NULL, NULL) o
				

	END
	IF @Action LIKE 'REFUND%'
	BEGIN
		INSERT INTO @tmp_Settled  ( bettype, ResourceID, hdp , betteam, way, outcome )
		SELECT mk.bettype, mk.ResourceID, mk.GoalLine as hpd , mk.betteam, mk.way
			,CASE 
				WHEN mk.SDTRecord & 4 > 0 THEN CASE 
												WHEN m.modds > 0.25 THEN 0 ---'WON'
												WHEN m.modds = 0.25 THEN 2 ---'HAFT_WON'
												WHEN m.modds = 0 THEN 5 ---'CASH_BACK'
												WHEN m.modds = -0.25 THEN 3 ---'HAFT_LOSE'
												WHEN m.modds < -0.25 THEN 1 ---'LOSE'
												ELSE 5 ---'CASH_BACK'
											END
				ELSE 5 ---'CASH_BACK'
				END
		FROM	@tmpMarketDetail mk
			OUTER APPLY dbo.f_Set_SDT_modds(mk.pfId, mk.betteam, mk.hdp1, mk.hdp2, @hth, @hta, @fth, @fta, NULL, NULL, NULL, NULL, NULL, NULL, NULL) m
	END
 
	SELECT DISTINCT tmp.bettype, tmp.ResourceID, tmp.hdp, tmp.betteam, tmp.way ,tmp.outcome
	FROM @tmp_Settled tmp
	ORDER BY bettype

END
GO