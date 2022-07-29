/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail] 
	@MatchId	INT
	,@Bettypes	VARCHAR(MAX) = ''
	,@ResourcesOutPut	VARCHAR(MAX) = '' OUTPUT
AS
/*
	Created by: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Initial [Redmine:#175251]

	Param's Explanation:
		@ResourcesOutPut
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlData	XML

	DECLARE @tblFMBettype TABLE (BetType SMALLINT PRIMARY KEY, ResourceId VARCHAR(20))

	DECLARE @tblResultDetail TABLE (
		ResourceId			VARCHAR(20)
		,BetType			SMALLINT
		,SettlementStatusId TINYINT
		,ResultStatusId		TINYINT
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,OtherInfo			VARCHAR(50)
	)

	INSERT INTO @tblFMBettype(bettype, ResourceId)
	SELECT	BetType
			,CAST(BetType AS VARCHAR) + '__' AS ResourceId -- 22X__
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId = 9
	
	INSERT INTO @tblResultDetail (ResourceId, BetType, SettlementStatusId, ResultStatusId, HomeValue, AwayValue, OtherInfo)
	SELECT	r.ResourceId, t.BetType, r.SettlementStatusId, r.ResultStatusID,  r.HomeValue, r.AwayValue, r.OtherInfo
	FROM	dbo.ResultDetail r WITH(NOLOCK)
		INNER JOIN (
			SELECT	BetType, ResourceId
			FROM	@tblFMBettype t
			UNION ALL
			SELECT 229, '22901H'
			UNION ALL
			SELECT 229, '22901A'
			UNION ALL
			SELECT 221, '221CNT__'
			UNION ALL
			SELECT 0, '221WB__'
			UNION ALL
			SELECT 0, '221SUS'
		) t
			ON r.ResourceId LIKE t.ResourceId
	WHERE	matchid = @matchid			
	
	UPDATE d
		SET HomeValue = CASE WHEN ISNULL(HomeValue,'') = '' THEN REPLICATE('0', 50) ELSE HomeValue END
		, AwayValue = CASE WHEN ISNULL(AwayValue,'') = '' THEN REPLICATE('0', 50) ELSE AwayValue END
	FROM @tblResultDetail d
	WHERE bettype IN (228, 229) AND (ISNULL(HomeValue,'') = '' OR ISNULL(AwayValue,'') = '')
	
	-- Always shows 228, 229
	;WITH cteBetOption
	AS (
		SELECT  228 AS Bettype, CAST('22800' AS VARCHAR(50)) AS ResourceId
		UNION ALL
		SELECT  228 AS Bettype, CAST('22801' AS VARCHAR(50))
		UNION ALL
		SELECT  229 AS Bettype,  CAST('22900' AS VARCHAR(50))
		UNION ALL
		SELECT  229 AS Bettype, CAST('22901H' AS VARCHAR(50))
		UNION ALL
		SELECT  229 AS Bettype, CAST('22901A' AS VARCHAR(50))
	)
	INSERT INTO @tblResultDetail (ResourceId, BetType,  HomeValue, AwayValue)
	SELECT	c.ResourceId, c.Bettype, REPLICATE('0', 50) AS HomeValue, REPLICATE('0', 50) AS AwayValue
	FROM	cteBetOption c
		LEFT JOIN @tblResultDetail t
			ON c.ResourceId = t.ResourceId
	WHERE t.ResourceId IS NULL


	-- Event Counter
	SELECT	CAST(f.Position AS TINYINT) AS Position
			,CAST(f.Result AS VARCHAR(8)) AS Result
	FROM	(
			SELECT	CASE 
						WHEN rCNT.ResourceId = '221CNT02' THEN 'Bit2' -- Goal
						WHEN rCNT.ResourceId = '221CNT03' THEN 'Bit3' -- Corner
						WHEN rCNT.ResourceId = '221CNT04' THEN 'Bit4' -- FreeKick
						WHEN rCNT.ResourceId = '221CNT05' THEN 'Bit5' -- GoalKick
						WHEN rCNT.ResourceId = '221CNT06' THEN 'Bit6' -- ThrowIn
						WHEN rCNT.ResourceId = '221CNT08' THEN 'Bit8' -- Penalty
					END AS EventCounter 
					,rCNT.Result
			FROM(
				SELECT	def.ResourceId
						,SUBSTRING(ISNULL(rCNT.HomeValue, REPLICATE(' ',45)),1,45) 
							+ SUBSTRING(ISNULL(rCNT.AwayValue, REPLICATE(' ',45)),1,45) AS Result
				FROM (VALUES ('221CNT02'), ('221CNT03'), ('221CNT04'), ('221CNT05'), ('221CNT06'), ('221CNT08')) AS def (ResourceId)
				OUTER APPLY (
					SELECT	ResourceId
							,HomeValue
							,AwayValue
					FROM	@tblResultDetail rCNT
					WHERE	rCNT.ResourceId = def.ResourceId 
				) rCNT
			)rCNT
		)AS rCNT
	PIVOT (
		MAX(rCNT.Result)
		FOR EventCounter IN (Bit1, Bit2, Bit3, Bit4, Bit5, Bit6, Bit7, Bit8)
	) AS pvt
	CROSS APPLY (
		SELECT	init.Position AS Position
				-- only show eventcounter if the inteval has been settled, if not --> set blank
				,(CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit8.ResultStatus AS VARCHAR(1)) ELSE ' ' END  -- Penalty
					+ ' ' -- Booking
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit6.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- ThrowIn
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit5.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- GoalKick
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit4.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- FreeKick
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit3.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- Corner
					+ CASE WHEN r00.SettlementStatus > 0 THEN CAST(bit2.ResultStatus AS VARCHAR(1)) ELSE ' ' END -- Goal
					+ ' ' -- None
				) AS Result				
		FROM(
			SELECT	init.pos AS Position
					,SUBSTRING(ISNULL(r00.HomeValue,REPLICATE(' ', 45)),1,45) 
						+ SUBSTRING(ISNULL(r00.AwayValue,REPLICATE(' ',45)),1,45) AS SettlementResult
			FROM	dbo.f_Set_GetChars(REPLICATE(' ',90)) init
				CROSS APPLY (
					SELECT	HomeValue
							,AwayValue
					FROM	@tblResultDetail r
					WHERE	r.ResourceId = '22100'
				)r00
		)init
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit2) f WHERE	init.Position = f.pos) bit2
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit3) f WHERE	init.Position = f.pos) bit3
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit4) f WHERE	init.Position = f.pos) bit4
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit5) f WHERE	init.Position = f.pos) bit5
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit6) f WHERE	init.Position = f.pos) bit6
		OUTER APPLY (SELECT * FROM dbo.f_Set_GetChars(pvt.Bit8) f WHERE	init.Position = f.pos) bit8			
		OUTER APPLY (
			SELECT	f.ResultStatus AS SettlementStatus
			FROM	dbo.f_Set_GetChars(init.SettlementResult) f
			WHERE	init.Position = f.pos
		) r00
	)f

	-- Over/Under value of each situation 
	SELECT	OtherInfo AS HandicapValue
	FROM	@tblResultDetail
	WHERE	ResourceId = '22201'

	-- Water break
	SELECT	r.ResourceId, r.HomeValue, r.AwayValue, r.OtherInfo, r.ResultStatusId
	FROM	@tblResultDetail r
	WHERE	r.ResourceId LIKE '221WB__' OR r.ResourceId = '221SUS'

	SELECT @xmlData =  (	SELECT ResourceId AS '@r'
									,HomeValue AS '@h'
									,AwayValue AS '@a'
									,BetType AS '@b'
							FROM	@tblResultDetail r
							FOR XML PATH('r'),ROOT('root'), TYPE
						)

	SET @ResourcesOutPut  = CAST(@xmlData AS VARCHAR(MAX) )

END
GO
