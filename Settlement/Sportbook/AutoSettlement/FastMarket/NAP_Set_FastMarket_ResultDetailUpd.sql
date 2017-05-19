USE bodb02
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId INT
	,@Results		VARCHAR(MAX)
	,@Action		VARCHAR(20) = 'CAL'
	,@IsAuto		BIT = 0
	,@AdminId		INT = 0
AS
/*
	Created: 20160427@Patrick
	Task: Fast market - Select match detail
	DB: DBPRO.BODB02
	Original:
	
	Revisions:
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]

	Param's Explanation:
		
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @xmlData XML
			,@ResultStatus TINYINT
			
	SET @xmlData = CONVERT(XML, @Results)
	SET @ResultStatus = CASE 
							WHEN @Action = 'CAL' AND @IsAuto = 0 THEN 5
							WHEN @Action = 'CAL' AND @IsAuto = 1 THEN 4
							WHEN @Action = 'REFUND' THEN 6
							WHEN @Action = 'UNDO' THEN 3
							ELSE 0
						END	
	
	DECLARE @tblData TABLE (
		ResourceId				VARCHAR(20) -- 22X00
		,ResourceId_BetOption	VARCHAR(20) -- 22X01
		,position				TINYINT
		,betOption				TINYINT
	)
	
	DECLARE @tblPosition TABLE(
		ResourceId	VARCHAR(20)
		,strPosHome	VARCHAR(200)
		,strPosAway VARCHAR(200)
		,strBetOptionHome	VARCHAR(1000)
		,strBetOptionAway	VARCHAR(1000)
	)
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
			,X.C.value('@r','TINYINT') as BetOption
		FROM @xmlData.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
	)
	INSERT INTO @tblData (ResourceId, ResourceId_BetOption, position, betOption)
	SELECT	CAST(bettype * 100 AS VARCHAR(20)) ResourceId -- 22X00
			,CAST(bettype * 100 + 1 AS VARCHAR(20)) ResourceId -- 22X01
			,Position
			,ISNULL(betOption,0)
	FROM	TmpData
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )
	
	-- result status
	INSERT INTO dbo.ResultDetail (MatchId, ResourceId, HomeValue, AwayValue, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
	SELECT	@matchId, t.ResourceId, REPLICATE('0', 50), REPLICATE('0', 50), @AdminId, GETDATE(), @AdminId, GETDATE()
	FROM	@tblData t
	WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail WITH(NOLOCK) WHERE MatchId = @matchid AND t.ResourceId = ResourceId)
	GROUP BY t.ResourceId
	
	-- betoption
	INSERT INTO dbo.ResultDetail (MatchId, ResourceId, HomeValue, AwayValue, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
	SELECT	@matchId, t.ResourceId_BetOption, REPLICATE(CHAR('0'), 50), REPLICATE(CHAR('0'), 50), @AdminId, GETDATE(), @AdminId, GETDATE()
	FROM	@tblData t
	WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.ResultDetail WITH(NOLOCK) WHERE MatchId = @matchid AND t.ResourceId_BetOption = ResourceId)
	GROUP BY t.ResourceId_BetOption
	
	INSERT INTO @tblPosition (ResourceId, strPosHome, strPosAway, strBetOptionHome, strBetOptionAway)
	SELECT	t.ResourceId
			,STUFF ((SELECT	',' + CAST(position AS VARCHAR(200))
						FROM	@tblData	
						WHERE	(ResourceId = t.ResourceId OR ResourceId_BetOption = t.ResourceId)
								AND position <=44
						FOR XML PATH ('')
				),1,1,'') strPosHome
			,STUFF ((SELECT	',' + CAST(position - 45 AS VARCHAR(200))
						FROM	@tblData	
						WHERE	(ResourceId = t.ResourceId OR ResourceId_BetOption = t.ResourceId)
								AND position >=45
						FOR XML PATH ('')
				),1,1,'') strPosAway
			,STUFF ((SELECT	',' + CAST(position AS VARCHAR(200)) + '|' + CAST(betOption AS VARCHAR(200))
						FROM	@tblData	
						WHERE	(ResourceId = t.ResourceId OR ResourceId_BetOption = t.ResourceId)
								AND position <=44
						FOR XML PATH ('')
				),1,1,'') strBetOptionHome
			,STUFF ((SELECT	',' + CAST(position - 45 AS VARCHAR(200)) + '|' + CAST(betOption AS VARCHAR(200))
						FROM	@tblData	
						WHERE	(ResourceId = t.ResourceId OR ResourceId_BetOption = t.ResourceId)
								AND position >=45
						FOR XML PATH ('')
				),1,1,'') strBetOptionAway
	FROM	dbo.ResultDetail t WITH(NOLOCK)
	WHERE	t.MatchId = @matchid
			AND t.ResourceId LIKE '22_0_'
	
	UPDATE	r 
		SET	HomeValue = CASE WHEN ISNULL(p.strPosHome,'') <> '' THEN dbo.f_Set_SetChars(r.HomeValue, p.strPosHome, @ResultStatus) ELSE r.HomeValue END 
			,AwayValue = CASE WHEN ISNULL(p.strPosAway,'') <> '' THEN dbo.f_Set_SetChars(r.AwayValue, p.strPosAway, @ResultStatus) ELSE r.AwayValue END
			,LastModifyBy = @AdminId
			,LastModifyDate = GETDATE()
	FROM	dbo.ResultDetail r  WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @tblPosition p 
			ON	r.MatchId = @matchid
				AND r.ResourceId = p.ResourceId
	WHERE	r.ResourceId LIKE '22_00'
	
	IF @Action IN ('CAL', 'UNDO') AND @IsAuto = 0
		UPDATE r 
			SET HomeValue = CASE WHEN ISNULL(p.strPosHome,'') <> '' THEN dbo.f_Set_SetBytes(r.HomeValue, p.strBetOptionHome) ELSE r.HomeValue END
				,AwayValue = CASE WHEN ISNULL(p.strPosAway,'') <> '' THEN dbo.f_Set_SetBytes(r.AwayValue, p.strBetOptionAway) ELSE r.AwayValue END
				,LastModifyBy = @AdminId
				,LastModifyDate = GETDATE()
		FROM	dbo.ResultDetail r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tblPosition p 
				ON	r.MatchId = @matchid
					AND r.ResourceId = p.ResourceId
		WHERE	r.ResourceId LIKE '22_01'
END

GO

GRANT EXECUTE ON [NAP_Set_FastMarket_ResultDetailUpd] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Set_FastMarket_ResultDetailUpd] TO [vnteam] AS [dbo]
GO