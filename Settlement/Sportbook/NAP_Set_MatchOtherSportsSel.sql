/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchOtherSportsSel
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@MatchStatus	VARCHAR(MAX)	= '0'
	,@OverStatus	VARCHAR(MAX)	= '0'
	,@HoldStatus	VARCHAR(50)		= '0'
	,@MatchCode		NVARCHAR(50)	= ''
	,@Sporttypes	VARCHAR(MAX)	
	,@LeagueIds		VARCHAR(MAX)    = '0'
	,@IsIncludeTest BIT				= 0
	,@AutoSetting	VARCHAR(10)		= ''
	,@Page			TINYINT			= 0
	,@MatchType		VARCHAR(MAX)	= '0'
AS
/*  
	 Created by: Kathy
	 Date: 20200528
	 Task: Match results for other sports [Redmine:#134843] 
	 DB: DBTXN/bodb02
	 
	 Revisions:     
			- 20200528@Kathy: Match results for other sports [Redmine:#134843] 
			- 20200827@Louisa: get external result to compare [Redmine:#139979]
			- 20201027@Louisa: Add new settlement status - Hold Key bit[7] - [Redmine:#143441]
			- 20210205@Louisa: Cricket AIO [Redmine:#148870]
			- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
			- 20210324@Louisa: Enhancement MultiSports page [Redmine:#151545]
			- 20210428@Louisa: Filter for Interval Over [Redmine: #143442]
			- 20210628@Louisa: Include new Filter [Redmine: #157541]
			- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
			- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
			- 20210906@Louisa: Get configuration from table SettlementResultTableSetting [Redmine:#160478]
			- 20211005@Louisa: Enhancement [Redmine:#162624]
			- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
			- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
			- 20211214@Louisa: Enhancemant Table Tennis [Redmine:#166070]			
			- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
			- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
			- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
			- 20220309@Louisa: Get latest status in AutoPayoutResult [Redmine:#168346]
			- 20220512@Louisa: Auto settle for Badminton [Redmine:#171676]
			- 20220620@Louisa: Extend Best Of Map Esports from M9 up to M30 [Redmine:#174252]
			- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
			- 20221021@Louisa: Enhancement [Redmine:#180306]
			- 20221021@Louisa: hint index [Redmine:#1181002]
			- 20221201@Louisa: Pingoal Esports [Redmine:#180808]
			- 20221205@Louisa: Auto Payout Real Cricket [Redmine:#181137]
			- 20221129@Louisa: Change Filter OverStatus and Tuning SP [Redmine:#181002]
			- 20221226@Louisa: Fix bug [Redmine:#182009]
			- 20230104@Kathy: duplicate matchid in #tmpAllParentChildMatch
			- 20230206@Kathy: duplicate transid in #tmpMarkedTransaction [Redmine:#183427]
			- 20221223@Kathy: Support Direct Payout for Early Results. [Redmine:#181718]
			- 20230315@Aries: Support Direct Payout for Child Tennis Matches [Redmine:#182330]
			- 20230215@Aries: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
			- 20230215@Aries: Apply Settlement by Profile for Remaining Sports - Fix issue [Redmine: #182677]
			- 20230406@Louisa: Include marked ticket flow [Redmine:#186140]
			- 20230328@Aries: Support Auto Payout for Main Tennis Matches [Redmine: #182329]
			- 20230801@Aries: Support Instant Settlement for Basketball [Redmine:#189662]
			- 20230920@Aries: Remove remote query [Redmine:#194359]
			- 20231114@Kathy: Enhance performance [Redmine:#196821]
			- 20231219@Louisa: RedCat88 [Redmine:#198365]
			- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
			- 20231229@Aries: Enhancement of Auto Settlement [Redmine:#199004]
			- 20240311@Helen: SP Tuning [Redmine:#202131]
			- 20240408@Aries: Cannot insert duplicate key in object dbo.#tmpAllParentChildMatch [Redmine:#203558]
			- 20240503@Louisa: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]
			- 20240621@Aries: Enhance Auto Refund to add waiting time [Redmine:#206153]
			- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100]
			- 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]
			- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]
			- 20241114@Aries: Support to add a new Live columns for Provider Tables [Redmine:#213217]
			- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
			- 20241111@Aries: Apply AutoPayout2 for Badminton and Table Tennis [Redmine:#214409]
			- 20250507@Aries: Sportsbook - Enhance UI on theCalculation Page, Multi - Sports page and change the Over Status filter on the Calculation Pop-up [Redmine:#225098]
			- 20250528@Aries: Fix an issue due to showing "Provider Ready" at the HT and FT columns after settlement [Redmine:#228964]
	Parameters Explanation:        
		@LeagueIDs  : '0' :none
		@MatchStatus: 0:none,  1:close, 2:running 3:internal, 4:posponed, 5:Completed, 6:refund
					multiple select: '1,2,3'
		@OverStatus : 0:none, 1: Early over, 2: Main Over, 3: Over, 4:settled with running ticket
					multiple select: '1,2,3'
		@HoldStatus :  '0': none
						87 - Not on hold 
						1 - Result Pending
						2 - Undecided
						4 - Under Settlement
						16- MTD Hold
						64- Hold Key
						Check all: '87,1,2,4,16,64'
					multiple select: '1,2'
		@MatchType  : 0: all, 1: normal/real, 2:Virtual
		@IsIncludeTest: 1: include test matches, 0: exclude test matches
		@AutoSetting : '': not select or select All; 33-Auto Payout (bit[1]bit[6]); 16: Direct (bit[5]); 0: Turn off Autopayout  | Ex: @AutoSetting = '16,0'
					multiple select: @AutoSetting = '1,0'
		@Page:		0 - Multisports Page
					1 - Move Ticket Page



					
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @MatchId							INT
			,@IsOverEarly						BIT = 0
			,@IsMainOver						BIT = 0
			,@IsOver							BIT = 0		
			,@AutoValue							TINYINT
			,@IsCompletedWithRunningTicket		BIT = 0 

	DECLARE @tmpLeagueIds   TABLE (LeagueId INT)
	DECLARE @tmpSporttypes  TABLE (Sporttype SMALLINT, ResultTable TINYINT, ExternalResultTable TINYINT, AP_RetryTime  INT)
	DECLARE @tmpMatchStatus TABLE (MatchStatus TINYINT)
	DECLARE @tmpOverStatus  TABLE (OverStatus TINYINT)
	DECLARE @tmpHoldStatus  TABLE (HoldStatus TINYINT)
	DECLARE @tmpMatchOverStatus	TABLE (MatchId INT, ResourceID VARCHAR(20), OverStatus INT DEFAULT(0) )
	DECLARE @tmpMainResult TABLE ( ResourceID VARCHAR(20) )
	DECLARE @tmpAllParentChildMatch TABLE(MatchId INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON), ParentId INT, eventstatus NVARCHAR(50))

	CREATE TABLE #ConfirmedResources ( MatchId INT, ResourceId VARCHAR(20), ResultStatusID TINYINT, OverStatus TINYINT )

	CREATE TABLE #tmpMatchIds (
		 matchid						INT
		,ParentID						INT
		,matchcode						NVARCHAR(50)
		,leagueid						INT
		,sporttype						SMALLINT
		,kickofftime					DATETIME
		,homeid							INT
		,awayid							INT		
		,halftimehomescore 				INT
		,halftimeawayscore 				INT
		,finalhomescore					INT
		,finalawayscore					INT
		,eventstatus					NVARCHAR(50)
		,IsNeutral						BIT
		,betstatus						NVARCHAR(50)
		,autosetting					TINYINT
		,autosettingforleague			TINYINT
		,settlementstatus				TINYINT
		,childmatchtype					TINYINT
		,IsCalculated					BIT
		,IsMultiCaled					BIT
		,IsRefund						BIT
		,IsCalRefund					BIT
		,IsHalfTimeCal					BIT
		,ConfirmFT						INT DEFAULT (0)
		,ConfirmHT						INT DEFAULT (0)
		,IsPending						BIT DEFAULT (0)
		,BestOfMap						TINYINT
		,OfferLive						BIT
		,ResultTable					TINYINT
		,ExternalResultTable			TINYINT	
		,AP_RetryTime					INT
		,GameType 						TINYINT
	)

	BEGIN TRY
	IF ISNUMERIC(@MatchCode) = 1
	BEGIN
		SET @MatchId = CAST(@MatchCode AS INT)
	END
	END TRY
	BEGIN CATCH
		SET @MatchId = NULL
	END CATCH

	IF ( ISNULL(@AutoSetting,'') <> '')
	BEGIN
		DECLARE @minValue TINYINT

		;WITH cte_AutoSetting (AutoSetting) AS 
		( 
			SELECT CAST([value] AS TINYINT) FROM STRING_SPLIT(@AutoSetting, ',')
		)

		SELECT  @AutoValue = SUM(AutoSetting) 
				,@minValue = MIN(AutoSetting)
		FROM cte_AutoSetting
	END

	IF @Page = 1
	BEGIN
		SET @HoldStatus = '0'
		SET @OverStatus = '0'
	END

	INSERT INTO @tmpSporttypes( Sporttype, ResultTable, ExternalResultTable, AP_RetryTime )
	SELECT	DISTINCT f.[value], s.ResultTable, s.ExternalResultTable, s.AP_Main_WaitingTime
	FROM	STRING_SPLIT(@Sporttypes, ',') f
		INNER JOIN dbo.SettlementResultTableSetting s WITH(NOLOCK) 
			ON f.[value] = s.sporttype
	
	INSERT INTO @tmpMainResult ( ResourceID )
	SELECT DISTINCT f.ResourceId
		FROM @tmpSporttypes s
			CROSS APPLY ( SELECT f.ResourceId FROM dbo.f_Set_MajorRound (s.sporttype) as f ) f

	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT	DISTINCT [value]
	FROM	STRING_SPLIT(@LeagueIds, ',')

	INSERT INTO @tmpMatchStatus( MatchStatus )
	SELECT	[value]
	FROM	STRING_SPLIT(@MatchStatus, ',')

	INSERT INTO @tmpOverStatus ( OverStatus )
	SELECT CAST ([value]  AS TINYINT)
	FROM STRING_SPLIT(@OverStatus, ',')
	
	INSERT INTO @tmpHoldStatus ( HoldStatus ) 
	SELECT CAST([value] AS TINYINT) FROM STRING_SPLIT(@HoldStatus, ',')

	SELECT	@IsOverEarly =  MAX(CASE WHEN s.OverStatus = 1 THEN 1 ELSE 0 END)
			,@IsMainOver =  MAX(CASE WHEN s.OverStatus = 2 THEN 1 ELSE 0 END)
			,@IsOver	 =  MAX(CASE WHEN s.OverStatus = 3 THEN 1 ELSE 0 END)
			,@IsCompletedWithRunningTicket = MAX(CASE WHEN s.OverStatus = 4 THEN 1 ELSE 0 END)
	FROM @tmpOverStatus s

	IF @MatchCode <> ''
	BEGIN
		SET @OverStatus = '0'
		SET @IsCompletedWithRunningTicket = 0

		INSERT INTO #tmpMatchIds(
			 matchid
			,ParentID
			,matchcode
			,leagueid
			,sporttype
			,kickofftime
			,homeid
			,awayid
			,halftimehomescore
			,halftimeawayscore
			,finalhomescore
			,finalawayscore
			,ConfirmHT
			,ConfirmFT
			,eventstatus
			,IsNeutral
			,betstatus
			,autosetting
			,autosettingforleague
			,settlementstatus
			,childmatchtype
			,IsCalculated
			,IsMultiCaled
			,IsRefund
			,IsCalRefund
			,IsHalfTimeCal
			,IsPending
			,BestOfMap
			,OfferLive
			,ResultTable
			,ExternalResultTable
			,AP_RetryTime
			,GameType
		)
		SELECT	 m.matchid
				,m.ParentID
				,m.matchcode
				,m.LeagueId
				,m.sporttype
				,m.kickofftime
				,m.homeid
				,m.awayid
				,m.hthomescore
				,m.htawayscore
				,m.finalhomescore
				,m.finalawayscore
				,ISNULL(mr.ConfirmHT,0)
				,ISNULL(mr.ConfirmFT,0)			
				,m.eventstatus
				,m.IsNeutral
				,m.betstatus
				,ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AutoSetting
				,ISNULL(l.AutoSetting,0) AS AutoSettingForLeague
				,m.SettlementStatus
				,m.ChildMatchType
				,mr.calculate
				,mr.multiple
				,mr.refund
				,mr.calrefund
				,mr.IsHTCal
				,mr.isPending
				,mr.BestOfMap
				,mr.OfferLive
				,s.ResultTable
				,s.ExternalResultTable
				,s.AP_RetryTime
				,CASE WHEN l.Sporttype= 43 THEN l.OverTimeSession ELSE 0 END AS GameType
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
				ON	m.matchid = mr.matchid
			INNER JOIN @tmpSporttypes s
				ON m.sporttype = s.Sporttype	
		WHERE	(m.matchid = @MatchId OR m.matchcode LIKE + '%' + @MatchCode + '%')
				AND m.eventdate BETWEEN @FromDate AND @ToDate
				AND 1 = CASE 
							WHEN m.sporttype IN (8, 50) THEN 
								CASE  
									WHEN ( ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL ) THEN 0
									WHEN @Page = 1 THEN CASE 
															WHEN ISNULL(l.LeagueGroupID,0) = 42 THEN 0
															WHEN m.sporttype = 8 AND ISNULL(l.SessionTime,0) <> 1 THEN 0 -- show Series match only: SessionTime = 1
															ELSE 1 END
									ELSE 1 
									END
							ELSE 1 
						END
				AND ISNULL(m.IsDeleted,0) = 0
	END
	ELSE
	BEGIN
		INSERT INTO #tmpMatchIds(
		     matchid
			,ParentID
			,matchcode
			,leagueid
			,sporttype
			,kickofftime
			,homeid
			,awayid
			,halftimehomescore
			,halftimeawayscore
			,finalhomescore
			,finalawayscore
			,eventstatus
			,IsNeutral
			,betstatus
			,autosetting
			,autosettingforleague
			,settlementstatus
			,childmatchtype
			,IsCalculated
			,IsMultiCaled
			,IsRefund
			,IsCalRefund
			,IsHalfTimeCal
			,ConfirmFT
			,ConfirmHT
			,IsPending
			,BestOfMap
			,OfferLive
			,ResultTable
			,ExternalResultTable
			,AP_RetryTime
			,GameType
		)
		SELECT	 m.matchid
				,m.ParentID
				,m.matchcode
				,m.LeagueId
				,m.sporttype
				,m.kickofftime
				,m.homeid
				,m.awayid
				,m.hthomescore
				,m.htawayscore
				,m.finalhomescore
				,m.finalawayscore	
				,m.eventstatus
				,m.IsNeutral
				,m.betstatus
				,ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AutoSetting
				,ISNULL(l.AutoSetting, 0) AS autosettingforleague
				,m.SettlementStatus
				,m.ChildMatchType
				,mr.calculate
				,mr.multiple
				,mr.refund
				,mr.calrefund
				,mr.IsHTCal
				,ISNULL(mr.ConfirmFT,0)
				,ISNULL(mr.ConfirmHT,0)
				,mr.isPending
				,mr.BestOfMap
				,mr.OfferLive
				,s.ResultTable
				,s.ExternalResultTable
				,s.AP_RetryTime
				,CASE WHEN l.Sporttype= 43 THEN l.OverTimeSession ELSE 0 END AS GameType
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN @tmpSporttypes s
				ON m.sporttype = s.Sporttype
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON	m.leagueid = l.LeagueId
			CROSS APPLY (	SELECT TOP 1 l.LeagueID FROM @tmpLeagueIds tmp 
								WHERE @LeagueIDs = '0' OR tmp.LeagueId = l.leagueid 
							 ) tmp

			LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
				ON	m.matchid = mr.matchid
		WHERE	m.eventdate BETWEEN @FromDate AND @ToDate	
				AND 1 = CASE WHEN  m.sporttype = 2 AND ISNULL(l.LeagueGroupID,0) = 122 THEN 0 -- Pingoal basketball
							 WHEN  m.sporttype = 43 AND ISNULL(l.LeagueGroupID,0) IN (151,215) THEN 0 -- Pingoal ESports, RedCat
							ELSE 1 
							END
				AND ISNULL(m.IsDeleted,0) = 0
				AND l.isTest = CASE WHEN @IsIncludeTest = 0 THEN 0 ELSE l.isTest END
				AND 1 = CASE WHEN @MatchType = 0 THEN 1
								WHEN @MatchType = 1 AND ISNULL(l.LeagueGroupID,0) NOT IN (42,74,108) THEN 1 --normal match
								WHEN @MatchType = 2 AND ISNULL(l.LeagueGroupID,0) IN (42,74,108) THEN 1 --Virtual
								ELSE 0 
						END
				AND EXISTS (	SELECT TOP 1 1 
								FROM @tmpMatchStatus ms
								WHERE  CASE WHEN ms.MatchStatus	= 0 THEN 1
											WHEN ms.MatchStatus = 1 AND m.eventstatus = 'closed' THEN 1
											WHEN ms.MatchStatus = 2 AND m.eventstatus = 'running' THEN 1
											WHEN ms.MatchStatus = 3 AND m.eventstatus = 'Internal' THEN 1
											WHEN ms.MatchStatus = 4 AND m.eventstatus = 'Postponed' THEN 1
											WHEN ms.MatchStatus = 5 AND m.eventstatus = 'Completed' AND m.betstatus NOT LIKE 'Refund%' THEN 1
											WHEN ms.MatchStatus = 6 AND m.betstatus LIKE 'Refund%' THEN 1
											ELSE 0
										END > 0
								)
				AND 1 = CASE 
							WHEN m.sporttype IN (8, 50) THEN 
								CASE  
									WHEN ( ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL ) THEN 0
									WHEN @Page = 1 THEN CASE 
															WHEN ISNULL(l.LeagueGroupID,0) = 42 THEN 0
															WHEN m.sporttype = 8 AND ISNULL(l.SessionTime,0) <> 1 THEN 0 -- show Series match only: SessionTime = 1
															ELSE 1 END
									ELSE 1 
									END
							ELSE 1 
						END
				AND EXISTS (	SELECT TOP 1 1 FROM @tmpHoldStatus h
								WHERE  CASE WHEN h.HoldStatus = 0 THEN 1
										WHEN h.HoldStatus = 87 THEN  
																CASE WHEN h.HoldStatus &  m.SettlementStatus = 0 THEN 1
																ELSE 0 END
										ELSE h.HoldStatus & m.SettlementStatus
									END > 0 
							)

		DELETE m
		FROM #tmpMatchIds m
		WHERE 1 = CASE WHEN @AutoValue = 0 THEN CASE when  m.AutoSetting & 49 > 0 THEN 1  ELSE 0 END
				   		WHEN @minValue = 0 
				   			AND m.AutoSetting & (@AutoValue ^49) > 0  
				   			AND m.AutoSetting & @AutoValue = 0
				   			THEN 1
				   		WHEN @minValue > 0 AND m.AutoSetting & @AutoValue = 0 THEN 1
				   		ELSE 0
				   	END

	END	

	IF EXISTS ( SELECT TOP 1 1 FROM #tmpMatchIds WHERE Sporttype IN (50, 8) AND ISNULL(childmatchtype,0) <> 200 )
	BEGIN
		INSERT INTO @tmpAllParentChildMatch (MatchId, ParentId, eventstatus)
		SELECT	DISTINCT m.matchid, m.ParentId,  t.eventstatus
		FROM	#tmpMatchIds AS t
			CROSS APPLY (
				SELECT	m.matchid, m.ParentId
				FROM	dbo.match m WITH(NOLOCK)
				WHERE	m.sporttype IN (8, 50)
						AND m.ChildMatchType = 200
						AND m.ParentID = t.matchid
			)m
	END

	IF @IsOver = 1 AND ISNULL(@MatchCode,'') = ''
	BEGIN
		INSERT INTO @tmpMatchOverStatus (matchid, OverStatus)
		SELECT m.MatchId, 3
		FROM #tmpMatchIds m
		WHERE 	ISNULL(m.IsCalculated,0) = 0 
				AND ISNULL(m.IsCalRefund,0) = 0
				AND m.eventstatus <> 'Completed'
				AND 1 = CASE WHEN ISNULL(m.ConfirmFT,0) > 0 THEN 1
							WHEN m.sporttype = 18 AND DATEDIFF (MINUTE,  m.kickofftime, GETDATE() ) > 20 THEN 1
							WHEN DATEDIFF (MINUTE,  m.kickofftime, GETDATE() ) > 30 THEN 1
							ELSE 0
						END		
	END

	IF (@IsOverEarly = 1 OR @IsMainOver = 1 ) AND ISNULL(@MatchCode,'') = ''
	BEGIN
		INSERT INTO @tmpMatchOverStatus ( MatchId, ResourceId, OverStatus)
		SELECT m.MatchId, r.ResourceId, r.OverStatus
		FROM #tmpMatchIds AS m
			CROSS APPLY ( SELECT  r.ResourceId, CASE WHEN mr.ResourceID IS NULL THEN 1 ELSE 2 END AS OverStatus
						  FROM dbo.ResultDetail AS r WITH(NOLOCK)
							LEFT JOIN @tmpMainResult mr ON r.ResourceId = mr.ResourceID
						  WHERE r.matchid = m.matchid
							AND r.ResultStatusID = 3
							AND 1 = CASE WHEN @IsOverEarly = 1 AND  mr.ResourceID IS NULL THEN 1 
										 WHEN @IsMainOver = 1 AND m.eventstatus <> 'Completed' THEN 1									 
										 ELSE 0
										 END
						) r
		WHERE m.ResultTable  = 1		
		UNION ALL
		SELECT m.MatchId, r.ResourceId, r.OverStatus 
		FROM #tmpMatchIds AS m
			CROSS APPLY ( SELECT  r.ResourceId, CASE WHEN mr.ResourceID IS NULL THEN 1 ELSE 2 END AS OverStatus
						  FROM dbo.ResultDetailOS AS r WITH(NOLOCK)
							LEFT JOIN @tmpMainResult mr ON r.ResourceId = mr.ResourceID
						  WHERE r.matchid = m.matchid
							AND r.ResultStatusID = 3
							AND 1 = CASE WHEN @IsOverEarly = 1 AND  mr.ResourceID IS NULL THEN 1 
										 WHEN @IsMainOver = 1 AND m.eventstatus <> 'Completed' THEN 1									 
										 ELSE 0
										 END
						) r
		WHERE m.ResultTable  = 2

		;WITH cte_matchMainOver AS ( SELECT DISTINCT MatchId FROM @tmpMatchOverStatus WHERE OverStatus = 2)
		DELETE 
		FROM @tmpMatchOverStatus
		WHERE @IsMainOver = 1  AND @IsOverEarly = 0
			AND MatchId NOT IN (SELECT MatchId FROM cte_matchMainOver)
			AND OverStatus = 1
		---for sport not use ResultDetailX
		IF @IsMainOver = 1
		BEGIN
			INSERT INTO @tmpMatchOverStatus (matchid, ResourceID, OverStatus)
			SELECT m.MatchId, r.ResourceID, 2
			FROM #tmpMatchIds m
				CROSS APPLY (	SELECT r.ResourceID FROM  ( VALUES('00'),('01')) r(ResourceID)
								WHERE (	
										r.ResourceID = '00' AND m.ConfirmHT > 0)
										OR (r.ResourceID = '01' AND m.ConfirmFT > 0
									   ) 
							) r
			WHERE 1 = CASE WHEN m.eventstatus <> 'Completed'
								THEN CASE  WHEN m.ConfirmFT > 0 THEN 1
										WHEN m.ConfirmHT > 0 AND ISNULL(m.IsHalfTimeCal,0) = 0 THEN 1
										END
							ELSE 0
							END
				AND m.ResultTable = 0
		END
	END

	IF @IsCompletedWithRunningTicket = 1 AND ISNULL(@MatchCode,'') = ''
	BEGIN
		INSERT INTO @tmpMatchOverStatus (matchid, OverStatus)
		SELECT m.MatchId, 4
		FROM #tmpMatchIds m
		WHERE 	m.eventstatus = 'Completed'
	END

	--ESports: special behavior for filter Over #204370
	IF  ISNULL(@MatchCode,'') = ''  AND (@OverStatus = '0' OR ((@IsOverEarly = 1 OR @IsMainOver = 1)  AND EXISTS (SELECT TOP 1 1 FROM #tmpMatchIds WHERE sporttype = 43) ))
	BEGIN
		DECLARE @MatchInvalid TABLE(MatchId INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON))


		TRUNCATE TABLE #ConfirmedResources
		INSERT INTO #ConfirmedResources ( MatchId, ResourceId, ResultStatusID, OverStatus )
		SELECT m.MatchId, r.ResourceId, r.ResultStatusID, CASE WHEN mr.ResourceID IS NULL THEN 1 ELSE 2 END
		FROM #tmpMatchIds AS m
			INNER JOIN dbo.ResultDetailES AS r WITH(NOLOCK) ON m.matchid = r.MatchId
			LEFT JOIN @tmpMainResult mr ON r.ResourceId = mr.ResourceID
		WHERE m.sporttype = 43
			AND 1 =  CASE WHEN ( @IsOverEarly = 1 OR @OverStatus = '0' ) AND  mr.ResourceID IS NULL THEN 1 
						  WHEN @IsMainOver = 1 AND m.eventstatus <> 'Completed' THEN 1
						  ELSE 0
						  END
			AND r.ResultStatusID IN ( 2,3,5 )	
		
		;WITH cte_matchMainOver AS ( SELECT DISTINCT MatchId FROM #ConfirmedResources WHERE OverStatus = 2 AND ResultStatusID = 3 )
		DELETE m
		OUTPUT deleted.matchid
		INTO  @MatchInvalid (matchid)
		FROM #ConfirmedResources AS m
		WHERE @IsMainOver = 1  AND @IsOverEarly = 0
			AND MatchId NOT IN (SELECT MatchId FROM cte_matchMainOver)
		
		INSERT INTO #ConfirmedResources ( MatchId, ResourceId, ResultStatusID , OverStatus)
		SELECT DISTINCT m.MatchId, p.ResourceID, 3, 1
		FROM dbo.ProviderExternalResultDetailES AS p WITH(NOLOCK)
			INNER JOIN #tmpMatchIds AS m ON m.matchid = p.matchid
			LEFT JOIN #ConfirmedResources c ON p.MatchId = c.MatchId AND p.ResourceId = c.ResourceId
			LEFT JOIN @tmpMainResult mr ON c.ResourceId = mr.ResourceID
			LEFT JOIN @MatchInvalid  as mi ON mi.MatchId = p.MatchId
		WHERE  m.sporttype = 43
			AND p.SourceId < 1001
			AND p.SourceId NOT IN (98, 99)
			AND ISNULL(p.IsLive,0) = 0
			AND c.ResourceId IS NULL
			AND mr.ResourceId IS NULL
			AND mi.MatchId IS NULL

		DELETE FROM #ConfirmedResources WHERE ResultStatusID IN (2,5)

		INSERT INTO @tmpMatchOverStatus (matchid,ResourceID, OverStatus)
		SELECT r.matchid,ResourceID, OverStatus
		FROM #ConfirmedResources r

	END

	IF @OverStatus <> '0'
	BEGIN
		DELETE m
		FROM #tmpMatchIds m
			WHERE m.matchid NOT IN (SELECT DISTINCT matchid FROM @tmpMatchOverStatus)
	END

	SELECT	 m.matchid
			,m.ParentID
			,m.ChildMatchType
			,m.matchcode
			,m.leagueid 
			,m.sporttype 
			,m.kickofftime 
			,m.homeid
			,m.awayid
			,m.halftimehomescore
			,m.halftimeawayscore
			,m.finalhomescore
			,m.finalawayscore
			,ISNULL(m.ConfirmHT,0)  AS  ConfirmHT
			,ISNULL(m.ConfirmFT,0)  AS  ConfirmFT
			,m.eventstatus 
			,m.IsNeutral
			,m.betstatus
			,m.autosetting
			,m.autosettingforleague
			,m.settlementstatus
			,m.IsCalculated
			,m.IsMultiCaled
			,m.IsRefund
			,m.IsCalRefund
			,m.IsPending
			,m.IsHalfTimeCal
			,m.BestOfMap
			,m.OfferLive
			,ISNULL(s.WaitingTime, 300) AS AutoWaitingTime
			,ISNULL(s2.WaitingTime, AP_RetryTime) AS AutoMainWaitingTime
			,ISNULL(s2.EAR_WaitingTime, AP_RetryTime) AS AutoEarlyWaitingTime
			,ISNULL(s4.WaitingTime, 0) AS RefundWaitingTime
			,pr.HasProviderHT
			,pr.HasProviderFT
	FROM	#tmpMatchIds m
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	bodb02.dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND AutoType IN (1,5)					
		)s
		OUTER APPLY (
			SELECT TOP 1 s1.WaitingTime,s1.EAR_WaitingTime
			FROM	bodb02.dbo.SettlementSetting s1 WITH (NOLOCK)
			WHERE	s1.LeagueId = m.leagueid
					AND AutoType = 6			
		)s2
		OUTER APPLY (
			SELECT TOP 1 s3.WaitingTime
			FROM	bodb02.dbo.SettlementSetting s3 WITH (NOLOCK)
			WHERE	s3.LeagueId = m.leagueid
					AND AutoType = 7			
		)s4
		OUTER APPLY (
			SELECT TOP 1 HasProviderHT,HasProviderFT
			FROM (
				SELECT MAX(IIF(p.ResourceId = '01',1,0)) AS HasProviderHT,MAX(IIF(p.ResourceId = '00',1,0)) HasProviderFT
				FROM ProviderExternalResultDetail AS p  WITH(NOLOCK)
					INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK) ON p.SourceId  = pgm.SourceId AND pgm.Sporttype = m.sporttype AND pgm.isActive = 1
				WHERE p.matchID = m.matchID
					AND p.ResourceId in ('00','01')
					AND p.SourceID < 1001 
					AND p.SourceID NOT IN (97,98,99,100)
					AND ISNULL(p.IsLive,0) = 0
				GROUP BY p.matchID
				UNION ALL 
				SELECT MAX(IIF(p.ResourceId = '01',1,0)) AS HasProviderHT,MAX(IIF(p.ResourceId = '00',1,0)) HasProviderFT
				FROM ProviderExternalResultDetailOS AS p  WITH(NOLOCK)
					INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK) ON p.SourceId  = pgm.SourceId AND pgm.Sporttype = m.sporttype AND pgm.isActive = 1
				WHERE p.matchID = m.matchID				 
					AND p.SourceID < 1001 
					AND p.SourceID NOT IN (97,98,99,100)
					AND ISNULL(p.IsLive,0) = 0
					AND 1 = CASE WHEN m.sporttype != 5 AND p.ResourceId = '01' THEN 1
							     WHEN p.ResourceId = '00' THEN 1
								 ELSE 0
								 END
				GROUP BY p.matchID
				UNION ALL 
				SELECT MAX(IIF(p.ResourceId = '01',1,0)) AS HasProviderHT,MAX(IIF(p.ResourceId = '00',1,0)) HasProviderFT
				FROM ProviderExternalResultDetailES AS p  WITH(NOLOCK)
					INNER JOIN ProviderGameTypeMapping pgm WITH(NOLOCK) ON p.SourceId  = pgm.SourceId AND pgm.Sporttype = m.sporttype AND pgm.isActive = 1 AND pgm.GameType = m.GameType
				WHERE p.matchID = m.matchID
					AND p.ResourceId in ('00','01')
					AND p.SourceID < 1001 
					AND p.SourceID NOT IN (97,98,99,100)
					AND ISNULL(p.IsLive,0) = 0
				GROUP BY p.matchID
			) AS tbl
 		) AS pr

	SELECT matchid, ResourceID, OverStatus
	FROM @tmpMatchOverStatus 

	SELECT MatchId, ParentId, eventstatus
	FROM @tmpAllParentChildMatch

	DROP TABLE #ConfirmedResources
	DROP TABLE #tmpMatchIds

END

GO