/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Admin_Settlement_Parlay_SDT]    Script Date: 1/6/2017 3:31:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Parlay_SDT] (
	@matchId 			INT
	, @matchdate		SMALLDATETIME
	, @Mode				VARCHAR(20)
	, @fthomescore		SMALLINT
	, @ftawayscore		SMALLINT
	, @hthomescore		SMALLINT
	, @htawayscore		SMALLINT
	, @sportType		SMALLINT
	, @betstatus		NVARCHAR(50)
	, @goalRecord		VARCHAR(50)	
	, @ticketCount		INT = 0 OUTPUT
	, @IsRefundHT		BIT  = 0
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) = '' OUTPUT
)
AS
/*	Creator: 20161206@Bobby
	Task: #61352 - Apply settle determined for parlay bet types
	DB: DBTXN/BODB02
	ORIGINAL: 

	Revisions:		
		

	Param's Explanation:		
		- @Mode: ['ABANDONED-1H', 'ABANDONED-2H']
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @IsHT 			BIT
		, @hScore1H			TINYINT
		, @aScore1H			TINYINT
		, @hScore2H			TINYINT
		, @aScore2H			TINYINT
		
	--conners result
		, @hthCorners		TINYINT
		, @htaCorners		TINYINT
		, @fthCorners		TINYINT
		, @ftaCorners		TINYINT
		, @ftFCorner		VARCHAR(1)
		, @htFCorner		VARCHAR(1)
		
		, @totalConner		TINYINT
		, @totalConner1H 	TINYINT
	
	DECLARE @rsQuery			NVARCHAR(MAX)
	
	CREATE TABLE #SDTBettypes (bettype SMALLINT PRIMARY KEY, IsDetermined BIT)
	CREATE TABLE #tmpResultDetail (
		ResourceID 			VARCHAR(20)
		, HomeValue 		VARCHAR(50)
		, AwayValue 		VARCHAR(50)
	)	
	
	SELECT @IsHT			= CASE WHEN @Mode IN ('ABANDONED-1H') THEN 1 ELSE 0 END 
		, @hScore1H 		= @hthomescore
		, @aScore1H 		= @htawayscore
		, @hScore2H			= CASE WHEN @IsHT = 0 THEN @fthomescore - @hthomescore ELSE 0 END
		, @aScore2H			= CASE WHEN @IsHT = 0 THEN @ftawayscore - @htawayscore ELSE 0 END
								
		--conners--------------
		, @hthCorners		= 0
		, @htaCorners		= 0
		, @fthCorners		= 0
		, @ftaCorners		= 0
		, @ftFCorner		= ''
		, @htFCorner		= ''
		, @ticketCount		= 0
	
	SET @rsQuery = '
		INSERT INTO #tmpResultDetail(ResourceID, HomeValue, AwayValue)	
		SELECT ResourceID, HomeValue, AwayValue
		FROM OPENQUERY([DBPRO],''SELECT ResourceID, HomeValue, AwayValue
		FROM bodb02.dbo.ResultDetail rs WITH(NOLOCK)
		WHERE matchid = '+CAST(@matchid AS VARCHAR(10))+' 
			AND SettlementStatusID = ' + 
			CASE WHEN @IsHT = 1 THEN '5' ELSE '6' END
			+ ''') AS rs'
	
	EXEC sp_executesql @rsQuery
	
	IF(@@ROWCOUNT > 0)
	BEGIN
		SELECT @hthCorners		= CASE WHEN ResourceID = '05' THEN CAST(HomeValue AS TINYINT) ELSE @hthCorners END
			, @htaCorners		= CASE WHEN ResourceID = '05' THEN CAST(AwayValue AS TINYINT) ELSE @htaCorners END
			, @fthCorners		= CASE WHEN ResourceID = '04' THEN CAST(HomeValue AS TINYINT) ELSE @fthCorners END
			, @ftaCorners		= CASE WHEN ResourceID = '04' THEN CAST(AwayValue AS TINYINT) ELSE @ftaCorners END
			, @ftFCorner		= CASE WHEN ResourceID = '206' THEN HomeValue ELSE @ftFCorner END
			, @htFCorner		= CASE WHEN ResourceID = '207' THEN HomeValue ELSE @htFCorner END
			
		FROM #tmpResultDetail
	END
	
	SELECT @totalConner			= CASE WHEN @IsHT = 1 THEN (@hthCorners + @htaCorners) ELSE (@fthCorners + @ftaCorners) END
		, @totalConner1H 		= (@hthCorners + @htaCorners)
		--------reset FT conners results
		, @fthCorners			= CASE WHEN @IsHT = 1 THEN @hthCorners 	ELSE @fthCorners END
		, @ftaCorners			= CASE WHEN @IsHT = 1 THEN @htaCorners 	ELSE @ftaCorners END
		, @ftFCorner			= CASE WHEN @IsHT = 1 THEN @htFCorner 	ELSE @ftFCorner END
	
	INSERT INTO #SDTBettypes (bettype, IsDetermined)
	SELECT f.BetType
		, f.IsDetermined
	FROM dbo.f_Set_GetGroupBettypes() f
	WHERE 1 = CASE 
				WHEN @IsHT = 1 THEN 1
				WHEN @IsHT = 0 THEN  -- FT, FT corner, HTFT-FGLG
					CASE 
						WHEN @IsRefundHT = 0 AND f.GroupId IN (2,4,6) THEN 1
						WHEN @IsRefundHT = 1 AND f.GroupId IN (2,4,6) AND f.Is3x30 = 0 THEN 1
						ELSE 0
					END
				ELSE 0
			END
		AND f.IsAuto = 0 --Exclude BetRadar, FM
	
	BEGIN --SDT Process
		DECLARE @tempBatch TABLE (refno BIGINT)
		DECLARE @tempRefno TABLE (refno BIGINT)

		DECLARE @fromTransId		BIGINT
			,@batchNo			INT
			,@batchCount		INT
			,@strTicket			VARCHAR(MAX)
	
		INSERT INTO @tempRefno (refno)
		SELECT bm.refno
		FROM dbo.bettransm bm WITH(NOLOCK)
			INNER JOIN #SDTBettypes t ON bm.bettype = t.bettype

		WHERE bm.matchid 	= @matchid
			AND bm.statusID NOT IN (101,102)
		
		SELECT @batchNo			= 2000
			, @batchCount		= 0
			, @fromTransId		= 0
			, @ticketCount		= 0
		
		WHILE (1 = 1)
		BEGIN
		
			DELETE @tempBatch
			
			DELETE TOP(@batchNo) t
			OUTPUT deleted.refno INTO @tempBatch(refno)
			FROM @tempRefno t	
		
			SELECT @batchCount	= @@ROWCOUNT
				,@ticketCount	+= @batchCount

			--INSERT INTO @tempBatch(transid, refno, StatusId)
			SELECT @strTicket =  CAST(
			(
				SELECT *
				FROM (
					SELECT TOP(@batchNo) 
						b.transid AS t
						, b.refno AS r
						, ISNULL(odds.modds, 0) AS m
					FROM @tempBatch ref 
						INNER JOIN dbo.bettransm b WITH(NOLOCK) ON ref.refno = b.refno
						OUTER APPLY
						(
							SELECT modds, StatusId 
							FROM [dbo].[f_Set_Parlay_SDT_CalModds](
								b.bettype
								, b.betteam
								, b.hdp1
								, b.hdp2
								, @hScore1H
								, @aScore1H
								, @hScore2H
								, @aScore2H
								, b.transdesc
								, @IsHT
							)
							WHERE modds IS NOT NULL
							UNION ALL
							SELECT modds, StatusId 
							FROM [dbo].[f_Set_Parlay_SDT_CalModds_Corner](
								b.bettype
								, b.betteam
								, b.hdp1
								, b.hdp2
								, @totalConner
								, @totalConner1H
								, @ftFCorner
								, @htFCorner
								, @hthCorners
								, @htaCorners
								, @fthCorners
								, @ftaCorners
								, @IsHT
							)
							WHERE modds IS NOT NULL
							UNION ALL
							SELECT modds, StatusId 
							FROM [dbo].[f_Set_Parlay_SDT_CalModds_GoalRecord](
								b.bettype
								, b.betteam
								, @GoalRecord
								, @IsHT
							)
							WHERE modds IS NOT NULL
						)  AS odds
					
					WHERE b.matchId = @matchId
				) AS b FOR XML AUTO
			) AS VARCHAR(MAX))
					
			--select @matchid
			--	,@matchdate
			--	,@mode AS mode
			--	,'REFUND' AS [action] 		
			--	,@strTicket AS strTransIds
			
			IF(@strTicket IS NOT NULL)
			BEGIN
				EXEC dbo.NAP_Admin_Calculate_MP_broker 
					@matchid 		= @matchid
					,@matchdate		= @matchdate
					,@mode 			= 'ABANDONED'
					,@action 		= 'REFUND'
					,@strTransIds	= @strTicket
			END
			
			--BREAK;
			
			IF(@batchCount < @batchNo) BREAK
		
		END
		
	END
	
	
	DROP TABLE #SDTBettypes
	DROP TABLE #tmpResultDetail
	
	RETURN
END
