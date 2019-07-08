/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
						  Incorporate PHAIO 4b - 27 Corners Bet Types 

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
		
		, @ft_fg 			VARCHAR(10)
		, @ft_lg 			VARCHAR(10)
		, @ht_fg 			VARCHAR(10)
		, @ht_lg 			VARCHAR(10)
		
		,@Char				VARCHAR(1)
		,@Position			TINYINT
		,@HomeRaceTo		TINYINT
		,@AwayRaceTo		TINYINT
		,@NeitherRaceTo		TINYINT
		,@NeitherRaceTo1H	TINYINT
		,@LenGoalRecord		TINYINT
		,@ResultCornerRace	VARCHAR(200)
		,@ResultCornerRace1H VARCHAR(200)

		, @xmlResultDetail		XML
		
	CREATE TABLE #SDTBettypes (bettype SMALLINT PRIMARY KEY)
	
	SELECT @IsHT			= CASE WHEN @Mode IN ('ABANDONED-1H') THEN 1 ELSE 0 END 
		, @hScore1H 		= @hthomescore
		, @aScore1H 		= @htawayscore
		, @hScore2H			= CASE WHEN @IsHT = 0 THEN @fthomescore - @hthomescore ELSE 0 END
		, @aScore2H			= CASE WHEN @IsHT = 0 THEN @ftawayscore - @htawayscore ELSE 0 END
		, @goalRecord		= ISNULL(@goalRecord, '')								
		, @ticketCount		= 0
		
		-- for bettype 486 Corner Race, 487 1H Corner Race
		, @Position = 1
		, @HomeRaceTo = 0
		, @AwayRaceTo = 0

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
	
	-- 486 Corner Race
	BEGIN
		SELECT @LenGoalRecord = LEN(@goalRecord)
			
		WHILE (@Position <= @LenGoalRecord)
		BEGIN
			SET @Char = SUBSTRING(@goalRecord, @Position, 1)
	
			IF @Char = 'H'	
			BEGIN
				SET @HomeRaceTo = @HomeRaceTo + 1

				IF @HomeRaceTo > @AwayRaceTo
					SET  @ResultCornerRace = @ResultCornerRace + CAST(@HomeRaceTo AS VARCHAR) + @Char + ';'
			END
			ELSE IF @Char = 'A' 
			BEGIN
				SET @AwayRaceTo = @AwayRaceTo + 1

				IF @AwayRaceTo > @HomeRaceTo
					SET  @ResultCornerRace = @ResultCornerRace + CAST(@AwayRaceTo AS VARCHAR) + @Char + ';'
			END

			SET @Position = @Position + 1	 	
		END

		SET @NeitherRaceTo = CASE WHEN @HomeRaceTo > @AwayRaceTo THEN @HomeRaceTo ELSE @AwayRaceTo END + 1
	END

	-- 487 1H Corner Race
	BEGIN
		SELECT	@LenGoalRecord = 0
				,@HomeRaceTo = 0
				,@AwayRaceTo = 0
				,@Position = 1
						
		SELECT @LenGoalRecord = LEN(CASE 
										WHEN CHARINDEX(';', @goalRecord) > 0 THEN SUBSTRING(@goalRecord, 1, CHARINDEX(';',@goalRecord))
										ELSE @goalRecord
									END)
			
		WHILE (@Position <= @LenGoalRecord)
		BEGIN
			SET @Char = SUBSTRING(@goalRecord, @Position, 1)
	
			IF @Char = 'H'	
			BEGIN
				SET @HomeRaceTo = @HomeRaceTo + 1

				IF @HomeRaceTo > @AwayRaceTo
					SET  @ResultCornerRace1H = @ResultCornerRace1H + CAST(@HomeRaceTo AS VARCHAR) + @Char + ';'
			END
			ELSE IF @Char = 'A' 
			BEGIN
				SET @AwayRaceTo = @AwayRaceTo + 1

				IF @AwayRaceTo > @HomeRaceTo
					SET  @ResultCornerRace1H = @ResultCornerRace1H + CAST(@AwayRaceTo AS VARCHAR) + @Char + ';'
			END

			SET @Position = @Position + 1	 	
		END

		SET @NeitherRaceTo1H = CASE WHEN @HomeRaceTo > @AwayRaceTo THEN @HomeRaceTo ELSE @AwayRaceTo END + 1
	END
				
	INSERT INTO #SDTBettypes (bettype)
	SELECT f.BetType
	FROM dbo.f_Set_GetGroupBettypes() f
	WHERE 1 = CASE 
				WHEN @IsHT = 1 THEN 1
				WHEN @IsHT = 0 THEN  -- FT, HTFT-FGLG
					CASE 
						WHEN @IsRefundHT = 0 AND f.GroupId IN (2,4) THEN 1
						WHEN @IsRefundHT = 1 AND f.GroupId IN (2,4) AND f.Is3x30 = 0 THEN 1
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
							FROM [dbo].[f_Set_Parlay_SDT_CalModds_GoalRecord](
								b.bettype
								, b.betteam
								, @GoalRecord
								, @ht_fg
								, @ht_lg
								, @ft_fg
								, @ft_lg
								, b.hdp1
								, @ResultCornerRace
								, @NeitherRaceTo
								, @ResultCornerRace1H
								, @NeitherRaceTo1H
							)
							WHERE modds IS NOT NULL
						)  AS odds
					
					WHERE b.matchId = @matchId
				) AS b FOR XML AUTO
			) AS VARCHAR(MAX))
					
			IF(@strTicket IS NOT NULL)
			BEGIN
				EXEC dbo.NAP_Admin_Calculate_MP_broker 
					@matchid 		= @matchid
					,@matchdate		= @matchdate
					,@mode 			= 'ABANDONED'
					,@action 		= 'REFUND'
					,@strTransIds	= @strTicket
			END
		
			IF(@batchCount < @batchNo) BREAK
		
		END
		
	END	
	
	DROP TABLE #SDTBettypes
	
	RETURN
END
GO
