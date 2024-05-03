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
			- 20240503@Louisa: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]

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
		@AutoSetting : '': not select or select All; 1-Auto Payout (bit[1]); 16: Direct (bit[5]); 0: Turn off Autopayout  | Ex: @AutoSetting = '16,0'
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
	DECLARE @tmpSporttypes  TABLE (Sporttype SMALLINT, ResultTable TINYINT, AP_RetryTime  INT)
	DECLARE @tmpMatchStatus TABLE (MatchStatus TINYINT)
	DECLARE @tmpOverStatus  TABLE (OverStatus TINYINT)
	DECLARE @tmpHoldStatus  TABLE (HoldStatus TINYINT)
	DECLARE @tmpMatchOverStatus	TABLE (MatchId INT, Bettype INT DEFAULT(0),BetId INT DEFAULT(0), OverStatus INT DEFAULT(0) )

	CREATE TABLE #ConfirmedResources ( MatchId INT,sporttype SMALLINT, ResourceId VARCHAR(20))

	CREATE TABLE #tmpMatchIds (
		 matchid						INT
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
		,AP_RetryTime					INT
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

	INSERT INTO @tmpSporttypes( Sporttype, ResultTable,AP_RetryTime )
	SELECT	DISTINCT f.[value], s.ResultTable, s.AP_Main_WaitingTime
	FROM	STRING_SPLIT(@Sporttypes, ',') f
		INNER JOIN dbo.SettlementResultTableSetting s WITH(NOLOCK) 
			ON f.[value] = s.sporttype

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
			,AP_RetryTime
		)
		SELECT	 m.matchid
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
				,s.AP_RetryTime
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
				ON	m.matchid = mr.matchid
			INNER JOIN @tmpSporttypes s
				ON m.sporttype = s.Sporttype	
		WHERE	(m.matchid = @MatchId OR m.matchcode LIKE + '%' + @MatchCode + '%')
				AND m.eventdate BETWEEN @FromDate AND @ToDate
				AND 1 = CASE m.sporttype WHEN 50 THEN CASE  WHEN ( ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL ) THEN 0
															WHEN @Page = 1 AND  ISNULL(l.LeagueGroupID,0) = 42 THEN 0
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
			,AP_RetryTime
		)
		SELECT	 m.matchid
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
				,s.AP_RetryTime
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
				AND 1 = CASE m.sporttype WHEN 50 THEN CASE  WHEN ( ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL ) THEN 0
															WHEN @Page = 1 AND  ISNULL(l.LeagueGroupID,0) = 42 THEN 0
															ELSE 1 END
									ELSE 1 END		
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
		WHERE 1 = CASE WHEN @AutoValue = 0 THEN CASE when  m.AutoSetting & 17 > 0 THEN 1  ELSE 0 END
				   		WHEN @minValue = 0 
				   			AND m.AutoSetting & (@AutoValue ^17) > 0  
				   			AND m.AutoSetting & @AutoValue = 0
				   			THEN 1
				   		WHEN @minValue > 0 AND m.AutoSetting & @AutoValue = 0 THEN 1
				   		ELSE 0
				   	END

	END	

	IF @IsOver = 1
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

	IF (@IsOverEarly = 1 OR @IsMainOver = 1 )
	BEGIN
		INSERT INTO #ConfirmedResources ( MatchId,sporttype, ResourceId )
		SELECT m.MatchId,m.sporttype, r.ResourceId 
		FROM #tmpMatchIds AS m
			INNER JOIN dbo.ResultDetail AS r WITH(NOLOCK) ON r.matchid = m.matchid AND r.SettlementStatusID = 0 AND r.ResultStatusID = 3		
		WHERE m.ResultTable  = 1
		UNION
		SELECT m.MatchId,m.sporttype, ro.ResourceId 
		FROM #tmpMatchIds AS m
			INNER JOIN dbo.ResultDetailOS AS ro WITH(NOLOCK) ON ro.matchid = m.matchid AND ro.SettlementStatusID = 0 AND ro.ResultStatusID = 3		
		WHERE m.ResultTable  = 2
		UNION
		SELECT m.MatchId,m.sporttype, rs.ResourceId 
		FROM #tmpMatchIds AS m
			INNER JOIN dbo.ResultDetailES AS rs WITH(NOLOCK) ON rs.matchid = m.matchid AND rs.SettlementStatusID = 0 AND rs.ResultStatusID = 3		
		WHERE m.ResultTable  = 3

		DELETE c
		FROM #ConfirmedResources AS c
			CROSS APPLY(SELECT TOP  1 1 AS IsMain 
						FROM dbo.f_Set_MajorRound (c.sporttype) as f
						WHERE c.ResourceId = f.ResourceId
			) AS mr
		WHERE 1 = CASE WHEN @IsOverEarly = 1 AND mr.IsMain IS NULL THEN 1
					   WHEN @IsMainOver = 1 AND mr.IsMain = 1 THEN 1
					   ELSE 0
				  END

		INSERT INTO @tmpMatchOverStatus (matchid, bettype, betid, OverStatus)
		SELECT m.matchid,sp.bettype, sp.betid, 1
		FROM #tmpMatchIds m
			INNER JOIN #ConfirmedResources r ON r.matchId = m.matchid
				INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)	ON r.resourceid = sp.resourceid
		WHERE sp.sporttype = m.sporttype
				AND sp.SettleType = 'EAR'

		INSERT INTO @tmpMatchOverStatus (matchid, OverStatus)
		SELECT DISTINCT r.matchid , 2
		FROM #tmpMatchIds m
			INNER JOIN #ConfirmedResources r ON r.matchId = m.matchid
			INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)	ON r.resourceid = sp.resourceid
		WHERE sp.sporttype = m.sporttype
			AND sp.SettleType = 'MNL'
			AND m.eventstatus <> 'Completed'

		IF @IsMainOver = 1
		BEGIN
			INSERT INTO @tmpMatchOverStatus (matchid,  OverStatus)
			SELECT m.MatchId, 2
			FROM #tmpMatchIds m
				CROSS APPLY (	SELECT gb.BetType 
								FROM [dbo].[f_Set_GetGroupBettypes]() gb
								WHERE  (gb.GroupId = 1 AND m.ConfirmHT > 0)
									OR (gb.GroupId = 2 AND m.ConfirmFT > 0) 
							) gb
			WHERE m.matchid NOT IN (SELECT matchid FROM @tmpMatchOverStatus)
				AND 1 = CASE WHEN m.eventstatus <> 'Completed'
							 THEN CASE  WHEN m.ConfirmFT > 0 THEN 1
										WHEN m.ConfirmHT > 0 AND ISNULL(m.IsHalfTimeCal,0) = 0 THEN 1
										END
							ELSE 0
							END
				AND m.ResultTable = 0
		END
	END

	IF @IsCompletedWithRunningTicket = 1
	BEGIN
		INSERT INTO @tmpMatchOverStatus (matchid, OverStatus)
		SELECT m.MatchId, 4
		FROM #tmpMatchIds m
		WHERE 	m.eventstatus = 'Completed'
	END

	IF @OverStatus <> '0'
	BEGIN
		DELETE m
		FROM #tmpMatchIds m
			WHERE m.matchid NOT IN (SELECT DISTINCT matchid FROM @tmpMatchOverStatus)
	END

	SELECT	 m.matchid 
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
			,ISNULL(s2.RetryTime, AP_RetryTime) AS AutoRetryTime
	FROM	#tmpMatchIds m
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	bodb02.dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND AutoType IN (1,5)					
		)s
		OUTER APPLY (
			SELECT TOP 1 s1.RetryTime
			FROM	bodb02.dbo.SettlementSetting s1 WITH (NOLOCK)
			WHERE	s1.LeagueId = m.leagueid
					AND AutoType = 6			
		)s2

	SELECT matchid, bettype, betid, OverStatus
	FROM @tmpMatchOverStatus 

	DROP TABLE #ConfirmedResources
	DROP TABLE #tmpMatchIds

END

GO