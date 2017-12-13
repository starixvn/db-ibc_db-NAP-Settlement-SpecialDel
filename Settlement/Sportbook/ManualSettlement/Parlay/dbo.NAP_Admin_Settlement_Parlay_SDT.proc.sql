/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
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
	, @resultDetail		VARCHAR(MAX) = NULL
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
		- 20170719@Kathy: add metadata
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]

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
		
		, @ft_fg 			VARCHAR(10)
		, @ft_lg 			VARCHAR(10)
		, @ht_fg 			VARCHAR(10)
		, @ht_lg 			VARCHAR(10)
		
		, @xmlResultDetail		XML
		
	DECLARE @rsQuery			NVARCHAR(MAX)
	
	CREATE TABLE #SDTBettypes (bettype SMALLINT PRIMARY KEY)
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
		
	
	SET @xmlResultDetail = CONVERT(XML,@resultDetail)
	
	;WITH cteResult
	AS(
		SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
				,T.c.value('./@home','VARCHAR(50)') AS HomeValue
				,T.c.value('./@away','VARCHAR(50)') AS AwayValue
				,T.c.value('./@ssId','TINYINT') AS SettlementStatusID
		FROM	@xmlResultDetail.nodes('/root/r') AS T(c)
	)
	SELECT	
			-- for bettype 127 only: 1H
			@ht_fg = ISNULL(MAX(CASE 
									WHEN ResourceID ='127F' 
										THEN CASE 
												WHEN HomeValue = 'N' THEN '0:0'
												WHEN HomeValue = 'H' THEN '1:1'
												WHEN HomeValue = 'A' THEN '2:1'
												ELSE ''
											END
										ELSE '' 
								END),'')		
			,@ht_lg = ISNULL(MAX(CASE 
									WHEN ResourceID ='127L' 
										THEN CASE 
												WHEN HomeValue = 'N' THEN '0:0'
												WHEN HomeValue = 'H' THEN '1:2'
												WHEN HomeValue = 'A' THEN '2:2'
												ELSE ''
											END
										ELSE '' 
								END),'')			
			-- for bettype 14 (FT) , 448, 454: 
			,@ft_fg = ISNULL(MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END),'')
			,@ft_lg = ISNULL(MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END),'')	
						
	FROM	cteResult r
	WHERE r.SettlementStatusID = 4
	OPTION ( OPTIMIZE FOR ( @xmlResultDetail = NULL ) )
		
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
	
	INSERT INTO #SDTBettypes (bettype)
	SELECT f.BetType
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
								, @ht_fg
								, @ht_lg
								, @ft_fg
								, @ft_lg
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
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_Parlay_SDT] TO [bodbAdminNet]
GO
