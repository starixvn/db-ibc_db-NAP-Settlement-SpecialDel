/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
	, @resultDetail_cb 	VARCHAR(MAX) = NULL
	, @resultDetail_ss 	VARCHAR(MAX) = NULL
	, @resultDetail_bb	VARCHAR(MAX) = NULL
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
		

	Param's Explanation:		
		- @Mode: ['REFUND-HT', 'REFUND-FT', 'ABANDONED-2H'] - ['CAL', 'CAL-HT', 'CAL-FT']
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE 
		-- for FGLG
		@FGLG1 				VARCHAR(10)
		, @FGLG2 			VARCHAR(10)
		, @FLString 		VARCHAR(10)
		, @HT_FGLG1 		VARCHAR(10)
		, @HT_FGLG2 		VARCHAR(10)
		, @HT_FLString 		VARCHAR(10)
		, @temp_betstatus 	NVARCHAR(50)
		-- coner bets
		,@fthCorners        INT = NULL 
		,@ftaCorners        INT = NULL 
		,@hthCorners        INT = NULL 
		,@htaCorners        INT = NULL     
		,@FTFCorner         VARCHAR(10)    = NULL 
		,@FTLCorner         VARCHAR(10)    = NULL 
		,@HTFCorner         VARCHAR(10)    = NULL 
		,@HTLCorner         VARCHAR(10)    = NULL
	
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
            
        ,@penaltyshootout        VARCHAR(10)    = NULL
        ,@matchDecidedMethod    VARCHAR(10)    = NULL
        ,@first10Min1x2            VARCHAR(10)    = NULL
        ,@firstGoalTime10Min    VARCHAR(10)    = NULL
        ,@firstGoalTime15Min    VARCHAR(10)    = NULL
        ,@WhoAdvancesNextRound    VARCHAR(10) = NULL
        ,@ExtraTimeandGoal        VARCHAR(10)    = NULL
        ,@ExtraTimeYN            VARCHAR(10) = NULL
        ,@PlayerSentOff            VARCHAR(10) = NULL
        ,@HTPlayerSentOff        VARCHAR(10) = NULL
        ,@PlayerSentOffHome        VARCHAR(10) = NULL
        ,@HTPlayerSentOffHome    VARCHAR(10) = NULL
        ,@PlayerSentOffAway        VARCHAR(10) = NULL
        ,@HTPlayerSentOffAway    VARCHAR(10) = NULL
        ,@GoalScorerFirst        VARCHAR(10) = NULL                
        ,@firstHNextGoal        VARCHAR(MAX)= NULL
        ,@NextGoal                VARCHAR(MAX)= NULL
        ,@NextGoalTime15Min        VARCHAR(MAX)= NULL
        ,@ExtraNextGoal            VARCHAR(MAX)= NULL
        ,@GoalScorerAnytime        VARCHAR(MAX)= NULL
        ,@FirstGoalMethod			VARCHAR(2) = NULL
        ,@ResourceIDsCAL        VARCHAR(MAX)= NULL
        ,@ResourceIDsREFUND        VARCHAR(MAX)= NULL
		,@SelectedQuarterCAL		VARCHAR(50) = NULL
		,@FTHighestQuarter	VARCHAR(10) = NULL
		,@FTFirstBasket		VARCHAR(10) = NULL
		,@FTLastBasket		VARCHAR(10) = NULL
		,@HTRaceTo20		VARCHAR(10) = NULL
		,@HTRaceTo25		VARCHAR(10) = NULL
		,@HTRaceTo30		VARCHAR(10) = NULL
		,@SecondRaceTo20		VARCHAR(10) = NULL
		,@SecondRaceTo25		VARCHAR(10) = NULL
		,@SecondRaceTo30		VARCHAR(10) = NULL
		,@Q1Home				INT = NULL
		,@Q2Home				INT = NULL
		,@Q3Home				INT = NULL
		,@Q4Home				INT = NULL			
		,@Q1Away				INT = NULL
		,@Q2Away				INT = NULL
		,@Q3Away				INT = NULL
		,@Q4Away				INT = NULL
		,@Q1RaceTo10			VARCHAR(10) = NULL
		,@Q1RaceTo15			VARCHAR(10) = NULL
		,@Q1RaceTo20			VARCHAR(10) = NULL
		,@Q2RaceTo10			VARCHAR(10) = NULL
		,@Q2RaceTo15			VARCHAR(10) = NULL
		,@Q2RaceTo20			VARCHAR(10) = NULL
		,@Q3RaceTo10			VARCHAR(10) = NULL
		,@Q3RaceTo15			VARCHAR(10) = NULL
		,@Q3RaceTo20			VARCHAR(10) = NULL
		,@Q4RaceTo10			VARCHAR(10) = NULL
		,@Q4RaceTo15			VARCHAR(10) = NULL
		,@Q4RaceTo20			VARCHAR(10) = NULL
		,@Q1LastBasket			VARCHAR(10) = NULL
		,@Q2LastBasket			VARCHAR(10) = NULL
		,@Q3LastBasket			VARCHAR(10) = NULL
		,@Q4LastBasket			VARCHAR(10) = NULL

	CREATE TABLE #bettypeCAL (bettype SMALLINT PRIMARY KEY, groupId SMALLINT, groupName NVARCHAR(50))
	
	SELECT @FGLG1 				= ''
			, @FGLG2 			= ''
			, @HT_FGLG1 		= ''
			, @HT_FGLG2 		= ''
			, @temp_betstatus 	= @betstatus
			, @ticketCount		= 0
	
	IF CHARINDEX('1FL:', @temp_betstatus) > 0 
	BEGIN
		SELECT @HT_FLString = SUBSTRING(@temp_betstatus, CHARINDEX('1FL:',@temp_betstatus) + 4, 3)
			, @temp_betstatus = REPLACE(@temp_betstatus, SUBSTRING(@temp_betstatus, CHARINDEX('1FL:', @temp_betstatus), 7),'')
			, @HT_FGLG1 = CASE @HT_FLString WHEN '0-0' THEN '0:0'
							ELSE LEFT(@HT_FLString, 1) + ':1' END
			, @HT_FGLG2 = CASE @HT_FLString WHEN '0-0' THEN ''
							ELSE RIGHT(@HT_FLString, 1) + ':2' END
	END
	IF CHARINDEX('FL:', @temp_betstatus) > 0
	BEGIN
		SELECT @FLString = SUBSTRING(@temp_betstatus, CHARINDEX('FL:',@temp_betstatus) + 3, 3)
			, @FGLG1 = CASE @FLString WHEN '0-0' THEN '0:0'
							ELSE LEFT(@FLString,1) + ':1' END
			, @FGLG2 = CASE @FLString WHEN '0-0' THEN ''
							ELSE RIGHT(@FLString,1) + ':2' END
	END
	DECLARE @csHTFT NVARCHAR(10) -- HT/FT correct score

	SELECT @csHTFT = CASE WHEN @hth + @hta >= 4 THEN '4+' 
						ELSE CAST(@hth AS nvarchar(10)) + ':' + CAST(@hta AS nvarchar(10))
						END 
				+ '/'
				+ CASE WHEN @fth + @fta >=4 THEN '4+'
						ELSE CAST(@fth AS nvarchar(10)) + ':' + CAST(@fta AS nvarchar(10))
						END

	DECLARE @FirstGoal NVARCHAR(50) 
	SELECT  @FirstGoal=''
	SELECT  @FirstGoal = LEFT(REPLACE(ISNULL(@GoalSequence,''),';',''),1) --172  --@GoalSequence = GoalRecord 
	
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

	INSERT INTO #bettypeCAL (bettype, groupId, groupName)
	SELECT f.bettype, f.GroupId, f.GroupName
	FROM	dbo.[f_Set_GetGroupBettypes]() AS f
	WHERE	1 = CASE 
					WHEN @Mode IN ('REFUND-HT') THEN 
						CASE 
							WHEN f.Is3x30 = 0 THEN 1
							ELSE 0
						END
					WHEN @Mode IN ('REFUND-FT', 'ABANDONED-2H') THEN 
						CASE 
							WHEN f.GroupId IN (1,3,5,7) AND @IsRefundHT = 0 THEN 1 
							ELSE 0
						END
					WHEN @Mode IN ('CAL') OR (@Mode = 'REFUND' AND @Sporttype = 2) THEN 1
					ELSE 0
				END
			AND f.IsAuto = 0 --Exclude BetRadar, FM
	
	IF @Sporttype = 1 AND @resultDetail_cb IS NOT NULL -- corners bets 
	BEGIN
		DECLARE @xmlCorner	XML
		
		SET @xmlCorner = CONVERT(XML, @resultDetail_cb)    
		
		SELECT @fthCorners = ISNULL(T.C.value('./@fthCorners[1]', 'int'), 0)
			,@ftaCorners = ISNULL(T.C.value('./@ftaCorners[1]', 'int'), 0)
			,@hthCorners = ISNULL(T.C.value('./@hthCorners[1]', 'int'), 0)
			,@htaCorners = ISNULL(T.C.value('./@htaCorners[1]', 'int'), 0)
			,@ftfCorner = ISNULL(T.C.value('./@ftfCorner[1]', 'varchar(10)'), '')
			,@htfCorner = ISNULL(T.C.value('./@htfCorner[1]', 'varchar(10)'), '')
			,@ftlCorner = ISNULL(T.C.value('./@ftlCorner[1]', 'varchar(10)'), '')
			,@htlCorner = ISNULL(T.C.value('./@htlCorner[1]', 'varchar(10)'), '')
		FROM @xmlCorner.nodes('/root/r') as [T](C) --T: table, C: column    
		OPTION ( OPTIMIZE FOR ( @xmlCorner = NULL ) )    
	
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
		
		SELECT	TOP(1) @SelectedQuarterCAL = ISNULL(T.C.value('./@SelectedQuarterCAL[1]', 'varchar(50)'), '')
				--,@FTHighestQuarter = ISNULL(T.C.value('./@FTHighestQuarter[1]', 'varchar(10)'), '')
				,@FTFirstBasket = ISNULL(T.C.value('./@FTFirstBasket[1]', 'varchar(10)'), '')
				,@FTLastBasket = ISNULL(T.C.value('./@FTLastBasket[1]', 'varchar(10)'), '')
				,@HTRaceTo20 = ISNULL(T.C.value('./@HTRaceTo20[1]', 'varchar(10)'), '')
				,@HTRaceTo25 = ISNULL(T.C.value('./@HTRaceTo25[1]', 'varchar(10)'), '')
				,@HTRaceTo30 = ISNULL(T.C.value('./@HTRaceTo30[1]', 'varchar(10)'), '')
				,@SecondRaceTo20 = ISNULL(T.C.value('./@SecondRaceTo20[1]', 'varchar(10)'), '')
				,@SecondRaceTo25 = ISNULL(T.C.value('./@SecondRaceTo25[1]', 'varchar(10)'), '')
				,@SecondRaceTo30 = ISNULL(T.C.value('./@SecondRaceTo30[1]', 'varchar(10)'), '')
				,@Q1Home = ISNULL(T.C.value('./@Q1Home[1]', 'INT'), '')
				,@Q2Home = ISNULL(T.C.value('./@Q2Home[1]', 'INT'), '')
				,@Q3Home = ISNULL(T.C.value('./@Q3Home[1]', 'INT'), '')
				,@Q4Home = ISNULL(T.C.value('./@Q4Home[1]', 'INT'), '')
				,@Q1Away = ISNULL(T.C.value('./@Q1Away[1]', 'INT'), '')
				,@Q2Away = ISNULL(T.C.value('./@Q2Away[1]', 'INT'), '')
				,@Q3Away = ISNULL(T.C.value('./@Q3Away[1]', 'INT'), '')
				,@Q4Away = ISNULL(T.C.value('./@Q4Away[1]', 'INT'), '')
				,@Q1RaceTo10 = ISNULL(T.C.value('./@Q1RaceTo10[1]', 'varchar(10)'), '')
				,@Q1RaceTo15 = ISNULL(T.C.value('./@Q1RaceTo15[1]', 'varchar(10)'), '')
				,@Q1RaceTo20 = ISNULL(T.C.value('./@Q1RaceTo20[1]', 'varchar(10)'), '')
				,@Q2RaceTo10 = ISNULL(T.C.value('./@Q2RaceTo10[1]', 'varchar(10)'), '')
				,@Q2RaceTo15 = ISNULL(T.C.value('./@Q2RaceTo15[1]', 'varchar(10)'), '')
				,@Q2RaceTo20 = ISNULL(T.C.value('./@Q2RaceTo20[1]', 'varchar(10)'), '')
				,@Q3RaceTo10 = ISNULL(T.C.value('./@Q3RaceTo10[1]', 'varchar(10)'), '')
				,@Q3RaceTo15 = ISNULL(T.C.value('./@Q3RaceTo15[1]', 'varchar(10)'), '')
				,@Q3RaceTo20 = ISNULL(T.C.value('./@Q3RaceTo20[1]', 'varchar(10)'), '')
				,@Q4RaceTo10 = ISNULL(T.C.value('./@Q4RaceTo10[1]', 'varchar(10)'), '')
				,@Q4RaceTo15 = ISNULL(T.C.value('./@Q4RaceTo15[1]', 'varchar(10)'), '')
				,@Q4RaceTo20 = ISNULL(T.C.value('./@Q4RaceTo20[1]', 'varchar(10)'), '')
				,@Q1LastBasket = ISNULL(T.C.value('./@Q1LastBasket[1]', 'varchar(10)'), '')
				,@Q2LastBasket = ISNULL(T.C.value('./@Q2LastBasket[1]', 'varchar(10)'), '')
				,@Q3LastBasket = ISNULL(T.C.value('./@Q3LastBasket[1]', 'varchar(10)'), '')
				,@Q4LastBasket = ISNULL(T.C.value('./@Q4LastBasket[1]', 'varchar(10)'), '')
        FROM	@xmlbb.nodes('/root/r') as [T](C) --T: table, C: column
        OPTION	( OPTIMIZE FOR ( @xmlbb = NULL ) )
		
		SELECT	@FTHighestQuarter = CASE 
							WHEN MAX(t.scoreH) > MAX(t.scoreA) THEN 'H'
							WHEN MAX(t.scoreH) < MAX(t.scoreA) THEN 'A'
							ELSE ''
						END	
		FROM	(VALUES(@Q1Home,@Q1Away),(@Q2Home,@Q2Away),(@Q3Home,@Q3Away),(@Q4Home,@Q4Away)) AS t(scoreH,scoreA)
	END
	
	--Start process
	DECLARE 
		@fromTransId		INT
		,@batchNo			INT
		,@batchCount		INT
		,@strTicket			VARCHAR(MAX)
	
	DECLARE @tempRefno TABLE (refno BIGINT)
	DECLARE @tempBatch TABLE (refno BIGINT)

	INSERT INTO @tempRefno (refno)
	SELECT bm.refno
	FROM dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN #bettypeCAL t ON bm.bettype = t.bettype

	WHERE bm.matchid 	= @matchid
		AND bm.statusID NOT IN (101,102)
		AND 1 = CASE
					WHEN @SelectedQuarterCAL IS NULL THEN 1
					WHEN @SelectedQuarterCAL LIKE '%' + t.GroupName + '%' THEN 1
					WHEN t.groupId = 10 AND @SelectedQuarterCAL LIKE '%' + LEFT(bm.betcheck,3) + '%' THEN 1
					ELSE 0
				END
	
	SELECT @batchNo			= 2000
		, @batchCount		= 0
		, @fromTransId		= 0
		
	WHILE (1 = 1)
	BEGIN
		
		DELETE @tempBatch
		
		DELETE TOP(@batchNo) t
		OUTPUT deleted.refno INTO @tempBatch(refno)
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
						, @HT_FGLG1
						, @HT_FGLG2
						, @FGLG1
						, @FGLG2
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
						, @fthCorners
						, @ftaCorners
						, @hthCorners
						, @htaCorners
						, @FTFCorner
						, @FTLCorner
						, @HTFCorner
						, @HTLCorner
						, @penaltyshootout
						, @matchDecidedMethod
						, @first10Min1x2
						, @firstGoalTime10Min
						, @firstGoalTime15Min
						, @WhoAdvancesNextRound
						, @ExtraTimeandGoal
						, @ExtraTimeYN
						, @PlayerSentOff
						, @HTPlayerSentOff
						, @PlayerSentOffHome
						, @HTPlayerSentOffHome
						, @PlayerSentOffAway
						, @HTPlayerSentOffAway
						, @GoalScorerFirst
						, @firstHNextGoal
						, @NextGoal
						, @NextGoalTime15Min
						, @ExtraNextGoal
						, @GoalScorerAnytime
						, @FirstGoalMethod
						, @WinFromBehind
						, @FirstGoal
						, @csHTFT
						, @home_firstteam2goals
						, @away_firstteam2goals
						, @home_firstteam3goals
						, @away_firstteam3goals
						, @FTHighestQuarter	
						, @FTFirstBasket	
						, @FTLastBasket		
						, @HTRaceTo20		
						, @HTRaceTo25		
						, @HTRaceTo30		
						, @SecondRaceTo20	
						, @SecondRaceTo25	
						, @SecondRaceTo30	
						, @Q1Home			
						, @Q2Home			
						, @Q3Home			
						, @Q4Home			
						, @Q1Away			
						, @Q2Away			
						, @Q3Away			
						, @Q4Away			
						, @Q1RaceTo10		
						, @Q1RaceTo15		
						, @Q1RaceTo20		
						, @Q2RaceTo10		
						, @Q2RaceTo15		
						, @Q2RaceTo20		
						, @Q3RaceTo10		
						, @Q3RaceTo15		
						, @Q3RaceTo20		
						, @Q4RaceTo10		
						, @Q4RaceTo15		
						, @Q4RaceTo20		
						, @Q1LastBasket		
						, @Q2LastBasket		
						, @Q3LastBasket		
						, @Q4LastBasket		
						
					) AS odds
				WHERE b.matchId = @matchId
			) AS b FOR XML AUTO
		) AS VARCHAR(MAX))
		
		/*select @matchid
			,@matchdate
			,@mode AS mode
			,'CAL' AS [action] 		
			,@strTicket AS strTransIds*/
			
		IF(@strTicket IS NOT NULL)
		BEGIN
			EXEC dbo.[NAP_Admin_Calculate_MP_broker] 
				@matchid 		= @matchid
				,@matchdate		= @matchdate
				,@mode 			= 'CAL'
				,@action 		= 'CAL'
				,@strTransIds	= @strTicket
		END
	
		--BREAK;
			
		IF(@batchCount < @batchNo) BREAK
	END
	
	DROP TABLE #bettypeCAL
	
	RETURN
END

