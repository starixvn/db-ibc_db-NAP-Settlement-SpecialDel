/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Parlay_Calculate] (
	@matchId 			INT
	, @matchdate		SMALLDATETIME
	, @Mode 			VARCHAR(20)
	, @fth				SMALLINT
	, @fta				SMALLINT
	, @hth				SMALLINT
	, @hta				SMALLINT
	, @sportType		SMALLINT
	, @betstatus		NVARCHAR(50)
	, @GoalSequence		VARCHAR(50)
	, @TennisTotal 		INT = NULL
	, @TotalGameHomeMatch INT = NULL
	, @TotalGameAwayMatch INT = NULL
	, @resultDetail_ss 	VARCHAR(MAX) = NULL
	, @resultDetail_bb	VARCHAR(MAX) = NULL
	, @resultDetail		VARCHAR(MAX) = NULL
	, @IsRefundHT		BIT  = 0
	, @ticketCount		INT = 0 OUTPUT
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) = '' OUTPUT
)
AS
/*	Creator: 20161206@Bobby
	Task: #61352 - Apply settle determined for parlay bet types
	DB: DBTXN/BODB02
	ORIGINAL: 

	Revisions:		
			- 20170613@Kathy: Early Settlement [Redmine:#77835] 
			- 20170901@Kathy: Settle parlay tickets of tennis in case of they have result [Redmine:#82122]
			- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
			- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
			- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]

	Param's Explanation:		
		- @Mode: ['REFUND-HT', 'REFUND-FT', 'ABANDONED-2H'] - ['CAL', 'CAL-HT', 'CAL-FT']
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE 
		-- for FGLG
		@ft_fg 				VARCHAR(10)
		, @ft_lg 			VARCHAR(10)
		, @ht_fg 			VARCHAR(10)
		, @ht_lg 			VARCHAR(10)
		
	DECLARE
		@homeScoreSet1         tinyint
        ,@homeScoreSet2         tinyint
        ,@homeScoreSet3         tinyint
        ,@homeScoreSet4         tinyint
        ,@homeScoreSet5         tinyint
        ,@awayScoreSet1         tinyint
        ,@awayScoreSet2         tinyint
        ,@awayScoreSet3         tinyint
        ,@awayScoreSet4         tinyint
        ,@awayScoreSet5         tinyint
        ,@SetxGameyHomeWON        VARCHAR(MAX) = NULL 
        ,@SetxGameyAwayWON        VARCHAR(MAX) = NULL 
        ,@SetxGameyDRAW            VARCHAR(MAX) = NULL 
        ,@SetxGameyREFUND        VARCHAR(MAX) = NULL
        ,@SelectedSetCAL        VARCHAR(50)  = NULL
        ,@SelectedSetREFUND        VARCHAR(50)  = NULL 
        ,@scorediff			SMALLINT = 0
		,@totalgoal			SMALLINT = 0
		,@oddeven			SMALLINT = 0
		,@totalht			SMALLINT = 0
		,@totalgoal_2H		SMALLINT = 0
        ,@ResourceIDsCAL        VARCHAR(MAX)= NULL
        ,@ResourceIDsREFUND        VARCHAR(MAX)= NULL
        
		,@FTHighestQuarter	VARCHAR(10) = NULL
		,@Q1Home				INT = NULL
		,@Q2Home				INT = NULL
		,@Q3Home				INT = NULL
		,@Q4Home				INT = NULL			
		,@Q1Away				INT = NULL
		,@Q2Away				INT = NULL
		,@Q3Away				INT = NULL
		,@Q4Away				INT = NULL
		,@basketball_ResourceIdsCAL VARCHAR(MAX)

	DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	CREATE TABLE #bettypeCAL (bettype SMALLINT PRIMARY KEY, groupId SMALLINT, groupName NVARCHAR(50), isEarly BIT)
	
	SELECT @ticketCount		= 0
	
	DECLARE @csHTFT NVARCHAR(10) -- HT/FT correct score

	SELECT @csHTFT = CASE WHEN @hth + @hta >= 4 THEN '4+' 
						ELSE CAST(@hth AS nvarchar(10)) + ':' + CAST(@hta AS nvarchar(10))
						END 
				+ '/'
				+ CASE WHEN @fth + @fta >=4 THEN '4+'
						ELSE CAST(@fth AS nvarchar(10)) + ':' + CAST(@fta AS nvarchar(10))
						END

	DECLARE @FirstGoal NVARCHAR(50) 
			,@FirstGoal2H	VARCHAR(1)
			,@LastGoal		VARCHAR(1)
			,@LastGoal1H	VARCHAR(1)

			,@Char			VARCHAR(1)
			,@Position		TINYINT
			,@HomeRaceTo	TINYINT
			,@AwayRaceTo	TINYINT
			,@NeitherRaceTo TINYINT
			,@NeitherRaceTo1H TINYINT
			,@LenGoalSequence TINYINT
			,@ResultCornerRace VARCHAR(200)
			,@ResultCornerRace1H VARCHAR(200)

	SELECT  @FirstGoal=''
			,@GoalSequence = ISNULL(@GoalSequence, '')
			,@FirstGoal2H = ''
			,@LastGoal = ''
			,@LastGoal1H = ''

			-- for bettype 486 Corner Race, 487 1H Corner Race
			,@Position = 0
			,@HomeRaceTo = 0
			,@AwayRaceTo = 0

	SELECT   @FirstGoal = LEFT(REPLACE(@GoalSequence,';',''),1) --172  --@GoalSequence = GoalRecord 
			,@FirstGoal2h = CASE 
						WHEN CHARINDEX(';', @GoalSequence) > 0 THEN SUBSTRING(@GoalSequence, CHARINDEX(';', @GoalSequence)+1,1) 
						ELSE '' 
					END
			,@LastGoal = RIGHT(REPLACE(@GoalSequence,';',''),1)
			,@LastGoal1H = CASE 
								WHEN CHARINDEX(';', @GoalSequence) > 0 THEN SUBSTRING(@GoalSequence, CHARINDEX(';', @GoalSequence) - 1,1) 
								ELSE '' 
							END
	-- 486 Corner Race
	BEGIN
		SELECT @LenGoalSequence = LEN(@GoalSequence)
			
		WHILE (@Position < @LenGoalSequence)
		BEGIN
			SET @Char = SUBSTRING(@GoalSequence, @Position, 1)
	
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
		SELECT	@LenGoalSequence = 0
				,@HomeRaceTo = 0
				,@AwayRaceTo = 0
				,@Position = 0
						
		SELECT @LenGoalSequence = LEN(SUBSTRING(@GoalSequence, 1, CHARINDEX(';',@GoalSequence)))
			
		WHILE (@Position < @LenGoalSequence)
		BEGIN
			SET @Char = SUBSTRING(@GoalSequence, @Position, 1)
	
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
	
	DECLARE    
		@home_firstteam2goals    INT
		,@away_firstteam2goals    INT
		,@home_firstteam3goals    INT
		,@away_firstteam3goals    INT
	
	SET @home_firstteam2goals = CHARINDEX('H',@GoalSequence,(CHARINDEX('H',@GoalSequence)+1))
	SET @away_firstteam2goals = CHARINDEX('A',@GoalSequence,(CHARINDEX('A',@GoalSequence)+1))    
	SET @home_firstteam3goals = CASE WHEN @home_firstteam2goals > 0 THEN CHARINDEX('H',@GoalSequence, @home_firstteam2goals + 1) ELSE 0 END
	SET @away_firstteam3goals = CASE WHEN @away_firstteam2goals > 0 THEN CHARINDEX('A',@GoalSequence, @away_firstteam2goals + 1) ELSE 0 END    
	
	
	DECLARE @WinFromBehind NVARCHAR(1)
			,@curHome INT = 0
			,@curAway INT = 0
			,@index INT = 1
			
	SET @totalgoal = @fth + @fta
    SET @scorediff = @fth - @fta
    SET @oddeven = (@fth + @fta) % 2
    SET @totalht = (@hth + @hta)
    SET @totalgoal_2H = (@fth + @fta) - (@hth + @hta)
            
	IF (@fth <> @fta) AND (@fth + @fta) > 2
	BEGIN
		WHILE (@index <= LEN(REPLACE(@GoalSequence,';','')))
		BEGIN
			IF SUBSTRING(REPLACE(@GoalSequence,';',''),@index, 1) = 'H'
				SET @curHome = @curHome + 1
				
			IF SUBSTRING(REPLACE(@GoalSequence,';',''),@index, 1) = 'A' 
				SET @curAway = @curAway + 1                
			
			IF @fth > @fta AND @curHome < @curAway 
			BEGIN
				SET @WinFromBehind = 'H' 
				BREAK
			END
			IF @fta > @fth AND @curAway < @curHome
			BEGIN
				SET @WinFromBehind = 'A'
				BREAK
			END
			
			SET @index = @index + 1
		END
	END

	INSERT INTO #bettypeCAL (bettype, groupId, groupName, isEarly)
	SELECT f.bettype, f.GroupId, f.GroupName
			,(SELECT 1 FROM dbo.f_Set_GetEarlyBettypes() WHERE bettype = f.BetType) AS isEarly
	FROM	dbo.[f_Set_GetGroupBettypes]() AS f
	WHERE	1 = CASE 
					WHEN @Mode IN ('REFUND-HT') THEN 
						CASE 
							WHEN f.Is3x30 = 0 THEN 1
							ELSE 0
						END
					WHEN @Mode IN ('REFUND-FT', 'ABANDONED-2H') THEN 
						CASE 
							WHEN f.GroupId IN (1,3,7) AND @IsRefundHT = 0 THEN 1 
							ELSE 0
						END
					WHEN @Mode IN ('CAL') OR (@Mode = 'REFUND' AND @Sporttype IN (2,5)) THEN 1
					ELSE 0
				END
			AND f.GroupId NOT IN (8,9) --Exclude BetRadar, FM
	
	IF @sportType = 1 AND @resultDetail IS NOT NULL
	BEGIN
		DECLARE @xmlResultDetail XML
		
		SET @xmlResultDetail = CONVERT(XML,@resultDetail)
		
		;WITH cteResult
		AS(
			SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
					,T.c.value('./@home','VARCHAR(50)') AS HomeValue
					,T.c.value('./@away','VARCHAR(50)') AS AwayValue
			FROM	@xmlResultDetail.nodes('/root/r') AS T(c)
		)
		SELECT	@ht_fg = ISNULL(MAX(CASE 
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
				
				,@ft_fg = ISNULL(MAX(CASE WHEN ResourceId = '14F' THEN HomeValue ELSE '' END),'')
				,@ft_lg = ISNULL(MAX(CASE WHEN ResourceId = '14L' THEN HomeValue ELSE '' END),'')	
							
		FROM	cteResult r
		OPTION ( OPTIMIZE FOR ( @xmlResultDetail = NULL ) )
		
	END
	
	IF @Sporttype = 5 AND @resultDetail_ss IS NOT NULL -- sportting solution
	BEGIN
		DECLARE @xmlSS XML

		SET @xmlSS = CONVERT(XML, @resultDetail_ss)    
		
		SELECT TOP(1) 
			@homeScoreSet1 = ISNULL(T.C.value('./@homeScoreSet1[1]', 'tinyint'), 0)
			,@homeScoreSet2 = ISNULL(T.C.value('./@homeScoreSet2[1]', 'tinyint'), 0)
			,@homeScoreSet3 = ISNULL(T.C.value('./@homeScoreSet3[1]', 'tinyint'), 0)
			,@homeScoreSet4 = ISNULL(T.C.value('./@homeScoreSet4[1]', 'tinyint'), 0)
			,@homeScoreSet5 = ISNULL(T.C.value('./@homeScoreSet5[1]', 'tinyint'), 0)
			,@awayScoreSet1 = ISNULL(T.C.value('./@awayScoreSet1[1]', 'tinyint'), 0)
			,@awayScoreSet2 = ISNULL(T.C.value('./@awayScoreSet2[1]', 'tinyint'), 0)
			,@awayScoreSet3 = ISNULL(T.C.value('./@awayScoreSet3[1]', 'tinyint'), 0)
			,@awayScoreSet4 = ISNULL(T.C.value('./@awayScoreSet4[1]', 'tinyint'), 0)
			,@awayScoreSet5 = ISNULL(T.C.value('./@awayScoreSet5[1]', 'tinyint'), 0)
			,@SetxGameyHomeWON = ISNULL(T.C.value('./@SetxGameyHomeWON[1]', 'varchar(max)'), '')
			,@SetxGameyAwayWON = ISNULL(T.C.value('./@SetxGameyAwayWON[1]', 'varchar(max)'), '')
			,@SetxGameyDRAW = ISNULL(T.C.value('./@SetxGameyDRAW[1]', 'varchar(max)'), '')
			,@SetxGameyREFUND = ISNULL(T.C.value('./@SetxGameyREFUND[1]', 'varchar(max)'), '')
			,@SelectedSetCAL = ISNULL(T.C.value('./@SelectedSetCAL[1]', 'varchar(50)'), '')
			,@SelectedSetREFUND = ISNULL(T.C.value('./@SelectedSetREFUND[1]', 'varchar(50)'), '')
		FROM @xmlSS.nodes('/root/r') as [T](C) --T: table, C: column    
		OPTION ( OPTIMIZE FOR ( @xmlSS = NULL ) )
	
	END
	
	IF @Sporttype = 2 AND @resultDetail_bb IS NOT NULL -- Basketball
	BEGIN
		DECLARE	@xmlbb XML
	
		SET @xmlbb = CONVERT(XML, @resultDetail_bb)    
		
		;WITH cteResultDetail
		AS(
			SELECT	T.c.value('./@rid','VARCHAR(20)') AS ResourceId
					,T.c.value('./@home','VARCHAR(50)') AS HomeValue
					,T.c.value('./@away','VARCHAR(50)') AS AwayValue
					,T.c.value('./@ssId','TINYINT') AS SettlementStatusId
			FROM	@xmlbb.nodes('/root/r') AS T(c)
		)
		INSERT INTO @tmpResultDetail(ResourceId, HomeValue, AwayValue)
		SELECT	ResourceId, HomeValue, AwayValue
		FROM	cteResultDetail r
		WHERE	SettlementStatusId = 4
		OPTION ( OPTIMIZE FOR ( @xmlbb = NULL ) )
		
		SELECT	@FTHighestQuarter = CASE
											WHEN MAX(result.HomeValue) > MAX(result.AwayValue) THEN 'H'
											WHEN MAX(result.HomeValue) < MAX(result.AwayValue) THEN 'A'
											ELSE 'N'
										END
		FROM	@tmpResultDetail t
			CROSS APPLY (
				SELECT CAST(t.HomeValue AS INT) HomeValue
					,CAST(t.AwayValue AS INT) AwayValue
			)result
		WHERE	ResourceId LIKE 'Q[1-4]'
		
		SELECT	@Q1Home = HomeValue
				,@Q1Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q1'
		
		SELECT	@Q2Home = HomeValue
				,@Q2Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q2'
		
		SELECT	@Q3Home = HomeValue
				,@Q3Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q3'
		
		SELECT	@Q4Home = HomeValue
				,@Q4Away = AwayValue
		FROM	@tmpResultDetail
		WHERE	ResourceId = 'Q4'
		
		SELECT @basketball_ResourceIdsCAL = COALESCE(@basketball_ResourceIdsCAL + ',' + r.ResourceId , r.ResourceId)	 
				FROM	@tmpResultDetail t
					CROSS APPLY (
						SELECT CASE
									WHEN t.ResourceId = '00' THEN 'FT'
									WHEN t.ResourceId = '01' THEN '1H'
									WHEN t.ResourceId = '02' THEN '2H'
									ELSE t.ResourceId
								END AS ResourceId
					) r
	END
	
	--Start process
	DECLARE 
		@fromTransId		INT
		,@batchNo			INT
		,@batchCount		INT
		,@strTicket			VARCHAR(MAX)
	
	DECLARE @tempRefno TABLE (refno BIGINT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), QXHome INT, QXAway INT, QuarterX VARCHAR(20))
	DECLARE @tempBatch TABLE (refno BIGINT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), QXHome INT, QXAway INT, QuarterX VARCHAR(20))

	INSERT INTO @tempRefno (refno, ResourceId, HomeValue, QXHome, QXAway, QuarterX)
	SELECT bm.refno, r.ResourceId, rd.HomeValue, res.QXHome, res.QXAway, res.QuarterX
	FROM dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN #bettypeCAL t ON bm.bettype = t.bettype
		CROSS APPLY (
			SELECT CAST(bm.bettype AS VARCHAR) + ISNULL(SUBSTRING(bm.betcheck, 2, LEN(bm.betcheck)), '') AS ResourceId
		) r
		CROSS APPLY ( -- basketball
			SELECT 
				CASE
						WHEN bm.betcheck = '801' THEN @Q1Home
						WHEN bm.betcheck = '802' THEN @Q2Home
						WHEN bm.betcheck = '803' THEN @Q3Home
						WHEN bm.betcheck = '804' THEN @Q4Home
						ELSE 0
					END AS QXHome
					,CASE
						WHEN bm.betcheck = '801' THEN @Q1Away
						WHEN bm.betcheck = '802' THEN @Q2Away
						WHEN bm.betcheck = '803' THEN @Q3Away
						WHEN bm.betcheck = '804' THEN @Q4Away
						ELSE 0
					END AS QXAway
					,CASE 
						WHEN t.groupId = 10 
							THEN CASE 
									WHEN bm.betcheck = '801' THEN 'Q1'
									WHEN bm.betcheck = '802' THEN 'Q2'
									WHEN bm.betcheck = '803' THEN 'Q3'
									WHEN bm.betcheck = '804' THEN 'Q4'
									ELSE ''
								END
						ELSE ''
					END AS QuarterX
		) res
		LEFT JOIN @tmpResultDetail rd
			ON r.ResourceId = rd.ResourceId
	WHERE bm.matchid 	= @matchid
		AND bm.statusID NOT IN (101,102)
		AND 1 = CASE
					WHEN @resultDetail_bb IS NULL THEN 1
					WHEN t.isEarly = 1 THEN CASE
												WHEN CHARINDEX(',' + r.ResourceId + ',', ',' + @basketball_ResourceIdsCAL + ',') > 0 THEN 1
												ELSE 0
												END
					WHEN t.groupId = 10 THEN CASE
												WHEN CHARINDEX(',' + res.QuarterX + ',', ',' + @basketball_ResourceIdsCAL + ',') > 0 THEN 1
												ELSE 0
											END
					WHEN CHARINDEX(',' + t.groupName + ',', ',' + @basketball_ResourceIdsCAL + ',') > 0 THEN 1
					ELSE 0
					END	
		AND 1 = CASE
					WHEN @resultDetail_ss IS NULL THEN 1
					WHEN @SelectedSetCAL LIKE '%1%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '801%' THEN 1 
					WHEN @SelectedSetCAL LIKE '%2%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '802%' THEN 1 
					WHEN @SelectedSetCAL LIKE '%3%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '803%' THEN 1 
					WHEN @SelectedSetCAL LIKE '%4%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '804%' THEN 1 
					WHEN @SelectedSetCAL LIKE '%5%' AND bm.Bettype IN (154,155,156,1311,1312,1316,1317,1318,1324) AND betcheck LIKE '805%' THEN 1 
					WHEN @SelectedSetCAL LIKE '%6%' AND bm.Bettype IN (1,2,3,20,153,1301,1302,1303,1305,1306,1308) THEN 1
					WHEN @SelectedSetREFUND LIKE '%1%' AND bm.Bettype = 1324 AND betcheck LIKE '801%' THEN 1 
					WHEN @SelectedSetREFUND LIKE '%2%' AND bm.Bettype = 1324 AND betcheck LIKE '802%' THEN 1 
					WHEN @SelectedSetREFUND LIKE '%3%' AND bm.Bettype = 1324 AND betcheck LIKE '803%' THEN 1 
					WHEN @SelectedSetREFUND LIKE '%4%' AND bm.Bettype = 1324 AND betcheck LIKE '804%' THEN 1 
					WHEN @SelectedSetREFUND LIKE '%5%' AND bm.Bettype = 1324 AND betcheck LIKE '805%' THEN 1  
					ELSE 0 
				END 	
	
	SELECT @batchNo			= 2000
		, @batchCount		= 0
		, @fromTransId		= 0
		
	WHILE (1 = 1)
	BEGIN
		
		DELETE @tempBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.refno, DELETED.resourceId, DELETED.homevalue, DELETED.QXHome, DELETED.QXAway, DELETED.QuarterX
		INTO @tempBatch(refno, ResourceId, HomeValue, QXHome, QXAway, QuarterX)
		FROM @tempRefno t	

		SELECT @batchCount 	= @@ROWCOUNT
			, @ticketCount	+= @batchCount

		--INSERT INTO @tempBatch(transid, refno, modds, IsRefundGame)
		SELECT @strTicket = CAST(
		(
			SELECT *
			FROM (
				SELECT TOP(@batchNo) 
					b.transid AS t
					,b.refno AS r
					,odds.modds AS m
					,odds.IsRefundGame AS i
				FROM @tempBatch ref
					INNER JOIN dbo.bettransm b WITH(NOLOCK) ON ref.refno = b.refno
					OUTER APPLY dbo.f_Set_Parlay_CalModds(
						b.bettype
						, b.betteam
						, b.betcheck
						, b.livehomescore
						, b.liveawayscore
						, b.hdp1
						, b.hdp2
						, b.transdesc
						, @fth
						, @fta
						, @hth
						, @hta
						, @ht_fg
						, @ht_lg
						, @ft_fg
						, @ft_lg
						, @TennisTotal
						, @TotalGameHomeMatch
						, @TotalGameAwayMatch
						, @homeScoreSet1
						, @homeScoreSet2
						, @homeScoreSet3
						, @homeScoreSet4
						, @homeScoreSet5
						, @awayScoreSet1
						, @awayScoreSet2
						, @awayScoreSet3
						, @awayScoreSet4
						, @awayScoreSet5
						, @SetxGameyHomeWON
						, @SetxGameyAwayWON
						, @SetxGameyDRAW
						, @SetxGameyREFUND
						, @SelectedSetCAL
						, @SelectedSetREFUND										
						, @WinFromBehind
						, @FirstGoal
						, @FirstGoal2H
						, @LastGoal
						, @LastGoal1H
						, @csHTFT
						, @home_firstteam2goals
						, @away_firstteam2goals
						, @home_firstteam3goals
						, @away_firstteam3goals
						, @FTHighestQuarter	
						, ref.HomeValue
						, ref.QXHome					
						, ref.QXAway
						, @totalgoal
						, @scorediff
						, @oddeven
						, @totalht
						, @totalgoal_2H
						, @ResultCornerRace
						, @NeitherRaceTo
						, @ResultCornerRace1H
						, @NeitherRaceTo1H
					) AS odds
				WHERE b.matchId = @matchId
			) AS b FOR XML AUTO
		) AS VARCHAR(MAX))
		
		IF(@strTicket IS NOT NULL)
		BEGIN
			EXEC dbo.[NAP_Admin_Calculate_MP_broker] 
				@matchid 		= @matchid
				,@matchdate		= @matchdate
				,@mode 			= 'CAL'
				,@action 		= 'CAL'
				,@strTransIds	= @strTicket
		END
	
		IF(@batchCount < @batchNo) BREAK
	END
	
	DROP TABLE #bettypeCAL
	
	RETURN
END
GO