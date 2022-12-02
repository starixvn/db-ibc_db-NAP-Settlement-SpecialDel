/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
		@AutoSetting : '': not select; 1-Auto Payout bit[1] ; 0: Turn off Autopayout
					multiple select: @AutoSetting = '1,0'
		@Page:		0 - Multisports Page
					1 - Move Ticket Page



					
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @MatchId			INT
			,@n					INT 
			,@minBettype		SMALLINT
			,@maxBettype		SMALLINT
			,@remoteQuery		NVARCHAR(MAX)
			,@strMatchIds		VARCHAR(MAX)
			,@strEarlyBettypes	VARCHAR(MAX)
			,@strResourceId		VARCHAR(MAX)
			,@matchidList		VARCHAR(MAX) = ''
			,@IsOverEarly		BIT = 0
			,@IsMainOver		BIT = 0
			,@IsOver			BIT = 0
			,@IsCompletedWithRunningTicket	BIT = 0 --match completed but exists running ticket
			,@AutoValue			TINYINT
			,@IsCentral			BIT

	DECLARE @tmpLeagueIds   TABLE (LeagueId INT)
	DECLARE @tmpSporttypes  TABLE (Sporttype SMALLINT, IsMergedParlay BIT)
	DECLARE @tmpMatchStatus TABLE ( MatchStatus TINYINT )
	DECLARE @tmpOverStatus  TABLE ( OverStatus TINYINT)
	DECLARE @tmpHoldStatus  TABLE (HoldStatus TINYINT)
	DECLARE @tmpQueueStatus TABLE (MatchId INT, IsCalculatingSingle TINYINT DEFAULT(0), IsCalculatingMP TINYINT DEFAULT(0))
	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsExistMarkedTicketParlay BIT DEFAULT(0), IsDisplay BIT DEFAULT(0) )
	DECLARE @tmpMatchEsport TABLE (MatchId INT)
	DECLARE @tmpMatchOverStatus	TABLE (MatchId INT, sporttype SMALLINT, Bettype INT DEFAULT(0),BetId INT DEFAULT(0), IsEarly INT DEFAULT(0) )
	DECLARE @tmpMatchConfirmed TABLE (	matchid	INT, sporttype SMALLINT, Bettype INT DEFAULT(0),BetId INT DEFAULT(0), IsEarly INT DEFAULT(0) )
	DECLARE @CheckingDisplay TABLE ( matchid INT, IsPassEarly INT )

	DECLARE @tmpEarlyBettypeStatus TABLE(
		MatchId				INT
		,bettype			SMALLINT
		,isExistSingle		BIT DEFAULT(0)
		,isExistParlay		BIT DEFAULT(0)
		,isRunningSingle	BIT DEFAULT(0)
		,isWaitingSingle	BIT DEFAULT(0)
		,isRunningParlay	BIT DEFAULT(0)
		,isWaitingParlay	BIT DEFAULT(0)
	)	
	DECLARE @tmpResultDetail TABLE (
		MatchId				INT
		,ResourceId			VARCHAR(20)
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,ResultStatusId		TINYINT
		,SettlementStatusId TINYINT
	)
	
	CREATE TABLE #temp_match_parlay (ParentID INT, transid BIGINT, matchid INT, refno BIGINT, IsMergedParlay BIT)
	
	CREATE TABLE #ConfirmedResources ( MatchId INT, ResourceId VARCHAR(20))

	CREATE TABLE #tmpMatchIds (
		matchid							INT
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
		,suspenderhalftime				NVARCHAR(50)
		,suspenderfulltime				NVARCHAR(50)
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
		,IsExistEarlyBettypes			BIT DEFAULT (0)
		,IsExistEarlyBettypesParlay		BIT DEFAULT (0)
		,IsRunningEarlyBettypes			BIT DEFAULT (0)
		,IsRunningEarlyBettypesParlay	BIT DEFAULT (0)
		,IsWaitingEarlyBettypes			BIT DEFAULT (0)
		,IsWaitingEarlyBettypesParlay	BIT DEFAULT (0)

		,IsExistMarkedTicket			BIT DEFAULT (0)
		,IsExistMarkedTicketParlay		BIT DEFAULT (0)
		,IsExistRunningBettypeSingle	BIT DEFAULT (0) -- exclude early bettype
		,IsExistRunningTicketAfterCompleted	BIT DEFAULT (0) -- after match completed
		,IsExistRunningTicketParlay		BIT DEFAULT (0)-- after match completed

		,AutoPayoutStatus				TINYINT
		,IsExistsConfirmedEarly			BIT DEFAULT (0)
		,IsPending						BIT DEFAULT (0)
		,IsMergedParlay					BIT DEFAULT(0)
		,BestOfMap						TINYINT
		,OfferLive						BIT
	)

	CREATE TABLE #tmpMarkedTransaction (transId BIGINT PRIMARY KEY, matchId INT)
	
	CREATE TABLE #tmpAllParentChildMatch (MatchId INT PRIMARY KEY, ParentId INT, IsMergedParlay	BIT DEFAULT(0), eventstatus NVARCHAR(50))
	CREATE INDEX CIX_tmp_ParentId ON #tmpAllParentChildMatch(ParentId)

	SET @n = 2147483647
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
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

	INSERT INTO @tmpSporttypes( Sporttype, IsMergedParlay )
	SELECT	DISTINCT [value], ISNULL(ss.IsMergedParlay,0) 
	FROM	STRING_SPLIT(@Sporttypes, ',') f
		CROSS APPLY(
				SELECT	ss.IsMergedParlay
				FROM	dbo.SettlementResultTableSetting ss WITH(NOLOCK)
				WHERE ss.Sporttype = f.[value]
			)ss

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

		INSERT INTO #tmpMatchIds(matchid
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
			,suspenderhalftime
			,suspenderfulltime
			,autosetting
			,autosettingforleague
			,settlementstatus
			,childmatchtype
			,IsCalculated
			,IsMultiCaled
			,IsRefund
			,IsCalRefund
			,IsHalfTimeCal
			,AutoPayoutStatus
			,IsPending
			,IsMergedParlay
			,BestOfMap
			,OfferLive
		)
		SELECT	m.matchid
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
				,CASE mr.ConfirmHT 
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmHT)
				END
				,CASE mr.ConfirmFT
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmFT)
				END
				,ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AutoSetting
				,ISNULL(l.AutoSetting,0) AS AutoSettingForLeague
				,m.SettlementStatus
				,m.ChildMatchType
				,mr.calculate
				,mr.multiple
				,mr.refund
				,mr.calrefund
				,mr.IsHTCal
				,ap.StatusId
				,mr.isPending
				,s.IsMergedParlay
				,mr.BestOfMap
				,mr.OfferLive
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
				ON	m.matchid = mr.matchid
			INNER JOIN @tmpSporttypes s
				ON m.sporttype = s.Sporttype
			OUTER APPLY (
					SELECT r.MatchId, r.StatusId
						FROM (
							SELECT ROW_NUMBER() OVER(PARTITION BY ap.matchid ORDER BY ap.CreatedDate DESC) AS rn, ap.MatchId, ap.StatusId
							FROM DBPRO.bodb02.dbo.AutoPayoutResult ap WITH (NOLOCK)
							WHERE ap.matchid = m.matchid
								AND m.sporttype NOT IN ( 6, 9, 50 )
							) r
						WHERE r.rn = 1
				)ap			
		WHERE	(m.matchid = @MatchId OR m.matchcode LIKE + '%' + @MatchCode + '%')
				AND m.eventdate BETWEEN @FromDate AND @ToDate
				AND 1 = CASE m.sporttype WHEN 50 THEN CASE  WHEN ( ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL ) THEN 0
															WHEN @Page = 1 AND  ISNULL(l.LeagueGroupID,0) = 42 THEN 0
															ELSE 1 
															END
						ELSE 1 
						END
				AND ISNULL(m.IsDeleted,0) = 0

		UPDATE m
		SET AutoPayoutStatus = ISNULL(m.AutoPayoutStatus, os.StatusId)
		from #tmpMatchIds m
			CROSS APPLY (
						SELECT TOP 1 r.matchid, r.StatusId
						FROM DBPRO.bodb02.dbo.AutoPayoutResultOS r WITH (NOLOCK)
						WHERE r.matchid = m.matchid
						ORDER BY r.StatusId DESC
					)os
		WHERE sporttype in ( 6, 9, 50 )

	END
	ELSE
	BEGIN
		INSERT INTO #tmpMatchIds(matchid
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
			,suspenderhalftime
			,suspenderfulltime
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
			,AutoPayoutStatus
			,IsPending
			,IsMergedParlay
			,BestOfMap
			,OfferLive
		)
		SELECT	m.matchid
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
				,CASE mr.ConfirmHT 
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmHT)
				END
				,CASE mr.ConfirmFT
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmFT)
				END
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
				,ap.StatusId
				,mr.isPending
				,s.IsMergedParlay
				,mr.BestOfMap
				,mr.OfferLive
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
			OUTER APPLY (
					SELECT r.MatchId, r.StatusId
					FROM (
						SELECT ROW_NUMBER() OVER(PARTITION BY ap.matchid ORDER BY ap.CreatedDate DESC) AS rn, ap.MatchId, ap.StatusId
						FROM DBPRO.bodb02.dbo.AutoPayoutResult ap WITH (NOLOCK)
						WHERE ap.matchid = m.matchid
						) r
					WHERE r.rn = 1
				)ap
		WHERE	m.eventdate BETWEEN @FromDate AND @ToDate	
				AND 1 = CASE WHEN  m.sporttype = 2 AND ISNULL(l.LeagueGroupID,0) = 122 THEN 0 -- Pingoal basketball
							 WHEN  m.sporttype = 43 AND ISNULL(l.LeagueGroupID,0) = 151 THEN 0 -- Pingoal ESports
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
				AND 1 = CASE WHEN @AutoSetting = '' THEN 1
							 WHEN @minValue = 0 AND ISNULL(m.AutoSetting, ISNULL(l.AutoSetting,0)) & (@AutoValue ^ 1) = 0  THEN 1
							 WHEN ISNULL(m.AutoSetting, ISNULL(l.AutoSetting,0))  & @AutoValue > 0 THEN 1
				   			ELSE 0 END
				AND EXISTS (	SELECT TOP 1 1 FROM @tmpHoldStatus h
								WHERE  CASE WHEN h.HoldStatus = 0 THEN 1
										WHEN h.HoldStatus = 87 THEN  
																CASE WHEN h.HoldStatus &  m.SettlementStatus = 0 THEN 1
																ELSE 0 END
										ELSE h.HoldStatus & m.SettlementStatus
									END > 0 
							)

		UPDATE m
		SET AutoPayoutStatus = ISNULL(m.AutoPayoutStatus, os.StatusId)
		from #tmpMatchIds m
			CROSS APPLY (
						SELECT TOP 1 r.matchid, r.StatusId
						FROM DBPRO.bodb02.dbo.AutoPayoutResultOS r WITH (NOLOCK)
						WHERE r.matchid = m.matchid
						ORDER BY r.StatusId DESC
					)os
		WHERE sporttype in ( 6, 9, 50 )

	END	
	
	--- Filter by Over Status
	IF @OverStatus <> '0'
	BEGIN
		
		IF @IsOver = 1
		BEGIN
			INSERT INTO @tmpMatchOverStatus (matchid, IsEarly)
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

		--- Matches have ResourceIds were confirmed
		IF ( @IsOverEarly = 1 OR @IsMainOver = 1 )
		BEGIN

			--confirmed Interval, confirmed Early ResouresId
			SELECT @strMatchIds = '', @strResourceId = ''

			SELECT @strMatchIds = @strMatchIds + CAST(m.MatchId AS VARCHAR(20)) + ','
			FROM	#tmpMatchIds m

			SELECT @strResourceId = @strResourceId + '''' + f.ResourceID + '''' + ','
			FROM (	SELECT DISTINCT f.ResourceID
					FROM #tmpMatchIds m
						CROSS APPLY dbo.f_Set_MajorRound (m.sporttype) f
					WHERE m.sporttype <> 1
						AND f.Sporttype = m.sporttype
					)f

			SELECT @strMatchIds = CASE WHEN ISNULL(@strResourceId,'') = '' OR ISNULL(@strMatchIds,'') = '' THEN '0' ELSE LEFT(@strMatchIds, LEN(@strMatchIds) - 1) END
					,@strResourceId = CASE WHEN ISNULL(@strResourceId,'') = '' THEN '''''' ELSE LEFT(@strResourceId, LEN(@strResourceId) - 1) END 

			SET	@remoteQuery = N'SELECT r.MatchId, r.ResourceId 
							FROM 
								( SELECT  r.MatchId, r.ResourceId 
								FROM DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
								WHERE r.SettlementStatusID = 0
									AND r.ResultStatusID = 3				
								UNION ALL
								SELECT r.MatchId, r.ResourceId 
								FROM DBPRO.bodb02.dbo.ResultDetailES r WITH(NOLOCK)
								WHERE r.SettlementStatusID = 0
									AND r.ResultStatusID = 3			
								UNION ALL
								SELECT r.MatchId, r.ResourceId 
								FROM DBPRO.bodb02.dbo.ResultDetailOS r WITH(NOLOCK)
								WHERE r.SettlementStatusID = 0
									AND r.ResultStatusID = 3
								) r 
							WHERE r.MatchId IN ('+@strMatchIds+')'
							+ CASE  WHEN @IsOverEarly = 1 AND @IsMainOver = 1 THEN ''
									WHEN @IsOverEarly = 1				  THEN 'AND r.ResourceId NOT IN ('+@strResourceId+')'
									ELSE 'AND r.ResourceId IN ('+@strResourceId+')'
								END

			INSERT INTO #ConfirmedResources ( MatchId, ResourceId )
			EXECUTE	sys.sp_executesql @remoteQuery

			INSERT INTO @tmpMatchOverStatus (matchid, bettype, betid, IsEarly)
			SELECT m.matchid,sp.bettype, sp.betid
				 , CASE sp.SettleType WHEN 'EAR' THEN 1 ELSE 2 END
			FROM #tmpMatchIds m
				INNER JOIN #ConfirmedResources r ON r.matchId = m.matchid
				INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)	ON r.resourceid = sp.resourceid
			WHERE sp.sporttype = m.sporttype

			INSERT INTO @tmpMatchOverStatus (matchid, bettype, betid, IsEarly)
			SELECT m.matchid, sp.bettype, sp.betid
				 , CASE sp.SettleType WHEN 'EAR' THEN 1 ELSE 2 END
			FROM #tmpMatchIds m
				INNER JOIN #ConfirmedResources r ON r.matchId = m.matchid
				INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)	ON r.ResourceId =  sp.RefResourceId
			WHERE sp.sporttype = m.sporttype
				AND sp.RefResourceId IS NOT NULL

			--confirmed HT, FT on sportype not settle by Profile
			IF @IsMainOver = 1
			BEGIN
				INSERT INTO @tmpMatchOverStatus (matchid, bettype, betid, IsEarly)
				SELECT m.MatchId, gb.Bettype, 0, 2
				FROM #tmpMatchIds m
					CROSS APPLY (	SELECT gb.BetType 
									FROM [dbo].[f_Set_GetGroupBettypes]() gb
									WHERE  (gb.GroupId = 1 AND m.ConfirmHT > 0)
										OR (gb.GroupId = 2 AND m.ConfirmFT > 0) 
								) gb
				WHERE m.matchid NOT IN (SELECT matchid FROM @tmpMatchOverStatus)
					AND 1 = CASE WHEN m.eventstatus IN ( 'running', 'closed')
								 THEN CASE  WHEN m.ConfirmFT > 0 THEN 1
											WHEN m.ConfirmHT > 0 AND ISNULL(m.IsHalfTimeCal,0) = 0 THEN 1
											END
								ELSE 0
								END
					AND NOT EXISTS (SELECT TOP 1 1 FROM [dbo].[f_Set_SettingByProfile] (m.sporttype)	)
			END

		END

		IF @IsCompletedWithRunningTicket = 1
		BEGIN
			INSERT INTO @tmpMatchOverStatus (matchid, IsEarly)
			SELECT m.MatchId, 4
			FROM #tmpMatchIds m
			WHERE 	m.eventstatus = 'Completed'
		END

		DELETE m
		FROM #tmpMatchIds m
			WHERE m.matchid NOT IN (SELECT DISTINCT matchid FROM @tmpMatchOverStatus)

		IF @IsOverEarly = 1
		BEGIN
			INSERT INTO @CheckingDisplay ( matchid)
			SELECT DISTINCT m1.matchid
			FROM (SELECT DISTINCT matchid FROM @tmpMatchOverStatus  WHERE IsEarly = 1) m1	
				CROSS APPLY (SELECT TOP 1 1 valid
							FROM bettrans b with (nolock)
								INNER JOIN @tmpMatchOverStatus m ON m.matchid = b.matchid
							WHERE m1.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusId = 0
								AND b.bettype = m.bettype AND (b.betID = 0 OR b.betid = m.betid ) 
								AND m.IsEarly = 1 
							) AS tmp

			DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

			INSERT INTO @CheckingDisplay ( matchid)
			SELECT DISTINCT m1.matchid
			FROM (SELECT DISTINCT matchid FROM @tmpMatchOverStatus  WHERE IsEarly = 1) m1	
				CROSS APPLY (SELECT TOP 1 1 valid
							FROM bettransm b with (nolock)
								INNER JOIN @tmpMatchOverStatus m ON m.matchid = b.matchid
							WHERE m1.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusId = 0
								AND b.bettype = m.bettype AND (b.betcheck = 0 OR b.betcheck = m.betid ) 
								AND m.IsEarly = 1 
							) AS tmp

			DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

			UPDATE #tmpMatchIds SET IsExistsConfirmedEarly = 1 WHERE matchid IN (SELECT DISTINCT matchid FROM @CheckingDisplay)
		END

		IF (@IsOver = 1 OR @IsCompletedWithRunningTicket = 1)
		BEGIN
			INSERT INTO @CheckingDisplay ( matchid, IsPassEarly)
			SELECT m.matchid, 0
			FROM @tmpMatchOverStatus m
				CROSS APPLY (SELECT TOP 1 1 valid
							FROM bettrans b with (nolock)
							WHERE m.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusId IN ( 0, 101, 102)
								and (IsEarly = 3 OR (IsEarly = 4 AND b.statusid = 0))
							) AS tmp
			WHERE m.IsEarly IN (3,4)	

			DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

			INSERT INTO @CheckingDisplay ( matchid, IsPassEarly)
			SELECT m.matchid, 0
			FROM @tmpMatchOverStatus m
				CROSS APPLY (SELECT TOP 1 1 valid
							FROM bettransm b with (nolock)
							WHERE m.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusId IN ( 0, 101, 102)
								and (IsEarly = 3 OR (IsEarly = 4 AND b.statusid = 0))
							) AS tmp
			WHERE m.IsEarly IN (3,4)

			DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

		END

		IF @IsMainOver = 1
		BEGIN
			INSERT INTO @CheckingDisplay ( matchid)
			SELECT DISTINCT m1.matchid
			FROM (SELECT DISTINCT matchid FROM @tmpMatchOverStatus  WHERE IsEarly = 2) m1	
				CROSS APPLY (SELECT TOP 1 1 valid
							FROM bettrans b with (nolock)
								INNER JOIN @tmpMatchOverStatus m ON m.matchid = b.matchid
							WHERE m1.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusId IN ( 0, 101, 102)
								AND b.bettype = m.bettype AND (b.betID = 0 OR b.betid = m.betid ) 
								AND m.IsEarly = 2 
							) AS tmp

			DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

			INSERT INTO @CheckingDisplay ( matchid)
			SELECT DISTINCT m1.matchid
			FROM (SELECT DISTINCT matchid FROM @tmpMatchOverStatus  WHERE IsEarly = 2) m1	
				CROSS APPLY (SELECT TOP 1 1 valid
							FROM bettransm b with (nolock)
								INNER JOIN @tmpMatchOverStatus m ON m.matchid = b.matchid
							WHERE m1.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusId IN ( 0, 101, 102)
								AND b.bettype = m.bettype AND (b.betcheck = 0 OR b.betcheck = m.betid ) 
								AND m.IsEarly = 2 
							) AS tmp
			
			DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

		END

		DELETE FROM #tmpMatchIds WHERE matchid NOT IN (SELECT matchid FROM @CheckingDisplay)
	END

	;WITH singlequeue 
	AS(
		SELECT	s.matchid
				,MIN(s.IsCalculating) AS IsCalculatingSingle
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	s.IsCalculating IN (0, 1)
				AND s.SportType <> 1
		GROUP BY s.matchid
	)
	,parlayqueue
	AS(
		SELECT	p.matchid
				,MAX(p.IsCalculating) AS IsCalculatingMP
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE	p.IsCalculating IN (0,1)
		GROUP BY p.matchid
	)
	INSERT INTO @tmpQueueStatus(MatchId, IsCalculatingSingle, IsCalculatingMP)
	SELECT	ISNULL(s.matchid, p.matchid) AS matchid
			,s.IsCalculatingSingle
			,p.IsCalculatingMP
	FROM	singlequeue s
		FULL OUTER JOIN parlayqueue p
			ON	s.matchid = p.matchid
	
	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, IsMergedParlay, eventstatus)
	SELECT m.matchid, m.matchid, m.IsMergedParlay, m.eventstatus FROM #tmpMatchIds m

	IF EXISTS ( SELECT TOP 1 1 FROM #tmpMatchIds WHERE Sporttype = 50 AND ISNULL(childmatchtype,0) <> 200 )
	BEGIN
		INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, IsMergedParlay, eventstatus)
		SELECT	m.matchid, m.ParentId, t.IsMergedParlay, t.eventstatus
		FROM	#tmpMatchIds t
			CROSS APPLY (
				SELECT	m.matchid, m.ParentId
				FROM	dbo.match m WITH(NOLOCK)
				WHERE	m.sporttype = 50
						AND m.ChildMatchType = 200
						AND m.ParentID = t.matchid
			)m
	END

	SELECT	@minBettype = MIN(bettype)
			,@maxBettype = MAX(bettype)
	FROM	dbo.f_Set_GetEarlyBettypes()

	INSERT INTO @tmpEarlyBettypeStatus(MatchId, isExistSingle, isRunningSingle, isWaitingSingle, isExistParlay, isRunningParlay, isWaitingParlay)
	SELECT	m.ParentId
			,MAX(b.isExistSingle)
			,MAX(b.IsRunningSingle)
			,MAX(b.IsWaitingSingle)
			,MAX(b.isExistParlay)
			,MAX(b.isRunningParlay)
			,MAX(b.isWaitingParlay)
	FROM	(
		SELECT TOP(@n) matchid, ParentId FROM #tmpAllParentChildMatch
	)m
		CROSS APPLY (
			SELECT	b.bettype
					,MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) AS IsRunningSingle
					,MAX(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS IsWaitingSingle
					,1 AS isExistSingle
					,0 AS isRunningParlay
					,0 AS isWaitingParlay					
					,0 AS isExistParlay
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = m.matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND b.statusID NOT IN(101, 102)
					AND b.bettype BETWEEN @minBettype AND @maxBettype
			GROUP BY b.matchid, b.bettype
			UNION ALL
			SELECT	bm.bettype
					,0 AS IsRunningSingle
					,0 AS IsWaitingSingle
					,0 AS isExistSingle
					,MAX(CASE WHEN bm.statusID = 0 THEN 1 ELSE 0 END) AS IsRunningParlay
					,MAX(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) AS IsWaitingParlay					
					,1 AS isExistParlay
			FROM	dbo.bettransm bm WITH(NOLOCK)
			WHERE	bm.matchid = m.matchid
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
					AND bm.statusID NOT IN (101, 102)
					AND bm.bettype BETWEEN @minBettype AND @maxBettype
			GROUP BY bm.matchid, bm.bettype
		)b
		INNER JOIN dbo.f_Set_GetEarlyBettypes() f
			ON b.bettype = f.bettype
	GROUP BY m.ParentId
	OPTION(OPTIMIZE FOR (@n = 1))

	UPDATE m
		SET  IsExistEarlyBettypes = b.isExistSingle
			,IsExistEarlyBettypesParlay = b.isExistParlay
			,IsRunningEarlyBettypes = b.isRunningSingle
			,IsRunningEarlyBettypesParlay = b.isRunningParlay
			,IsWaitingEarlyBettypes = b.isWaitingSingle
			,IsWaitingEarlyBettypesParlay = b.isWaitingParlay
	FROM	#tmpMatchIds m 
		INNER JOIN @tmpEarlyBettypeStatus b
			ON m.matchid = b.MatchId
	
	UPDATE m
		SET IsExistRunningBettypeSingle = 1
	FROM	#tmpMatchIds m
		CROSS APPLY (
						SELECT	TOP 1 1 AS IsRunningBettypeSingle
						FROM  #tmpAllParentChildMatch tmp
							INNER JOIN dbo.bettrans b WITH (NOLOCK)	ON tmp.MatchId = b.matchid
							LEFT JOIN dbo.f_Set_GetEarlyBettypes() e ON	b.bettype = e.bettype 
							WHERE	m.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND statusID = 0
								AND e.bettype IS NULL
								AND tmp.ParentId = m.MatchId 
						) b 	

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, m.matchid
	FROM	#tmpMatchIds m
		CROSS APPLY (
			SELECT	mt.TransId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt
	WHERE m.sporttype <> 50

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = m.HasMarkedSingle
				,IsExistMarkedTicketParlay = m.HasMarkedParlay
		FROM	@tmpMatchMarked mk
			INNER JOIN (
				SELECT	mt.matchId
						,CASE WHEN MIN(ISNULL(bm.IsParlay,0)) = 0 THEN 1 ELSE 0 END AS HasMarkedSingle
						,CASE WHEN MAX(ISNULL(bm.IsParlay,0)) = 1 THEN 1 ELSE 0 END AS HasMarkedParlay
				FROM	#tmpMarkedTransaction mt
					CROSS APPLY (
						SELECT	TOP (1) b.transid
								,b.refno
								,b.matchid
								,b.statusID
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	mt.transid = b.transid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					) b
					OUTER APPLY (
						SELECT TOP 1 1 IsParlay
						FROM	dbo.bettransm bm WITH(NOLOCK)
						WHERE	bm.refno = b.refno
								AND bm.statusid = 0
								AND b.matchid = 29
								AND bm.matchid = mt.matchId
					)bm
				WHERE	1 = CASE
								WHEN b.matchid <> 29 AND b.statusID = 0 THEN 1
								WHEN b.matchid = 29 AND bm.IsParlay = 1 THEN 1
								ELSE 0
							END
				GROUP BY mt.matchid
			) m
				ON m.matchId = mk.MatchId

		UPDATE m 
			SET IsExistMarkedTicket = t.IsExistMarkedTicket
				,IsExistMarkedTicketParlay = t.IsExistMarkedTicketParlay
		FROM	#tmpMatchIds m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId
	END
	
	DECLARE @tmpMatchCompleted TABLE (MatchId INT PRIMARY KEY, IsExistRunningTicket BIT DEFAULT (0), IsExistRunningTicketParlay BIT DEFAULT(0))

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	m.matchid
	FROM	#tmpMatchIds m
	WHERE	m.eventstatus = 'completed'

	IF @@ROWCOUNT <> 0
	BEGIN
		-- single
		UPDATE m
			SET IsExistRunningTicket = 1
		FROM	@tmpMatchCompleted m
					CROSS APPLY (
								SELECT	TOP 1 1 AS IsExistRunningTicket
								FROM	#tmpAllParentChildMatch tmp
									INNER LOOP JOIN dbo.bettrans b WITH (NOLOCK)	ON tmp.MatchId = b.matchid AND eventstatus = 'completed'
									OUTER APPLY (
													SELECT TOP 1 mt.transId
													FROM	#tmpMarkedTransaction mt 
													WHERE	b.transid = mt.TransId
															AND b.MatchId  = mt.matchId
		 										)mt
								WHERE tmp.ParentId = m.MatchId
									AND b.statusID = 0
									AND b.bettype NOT BETWEEN 801 AND 806 -- Metric Gaming
									AND b.bettype <> 38 -- BetBuilder
									AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
									AND mt.transId IS NULL
										
								) b 

		-- parlay
		INSERT INTO #temp_match_parlay (ParentID, transid, matchid, refno, IsMergedParlay)
		SELECT	tmp.ParentId, 0, tmp.MatchId, bm.refno, tmp.IsMergedParlay
		FROM @tmpMatchCompleted m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.MatchId = bm.matchid
			INNER JOIN #tmpAllParentChildMatch tmp	ON	bm.matchid = tmp.MatchId
		WHERE	bm.statusID = 0
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND 1 = CASE 
						WHEN m.IsExistRunningTicket = 0
								AND tmp.IsMergedParlay = 1 THEN 1
						WHEN tmp.IsMergedParlay = 0 THEN 1
					END
		
		IF EXISTS (SELECT TOP 1 1 FROM #temp_match_parlay)
		BEGIN
			UPDATE   t
				SET transid = b.transid
			FROM   #temp_match_parlay  t
				INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
			
			UPDATE m 
				SET IsExistRunningTicket = CASE WHEN t.IsMergedParlay = 1 AND m.IsExistRunningTicket = 0 THEN t.IsExistRunningTicketParlay ELSE m.IsExistRunningTicket END
					,IsExistRunningTicketParlay = t.IsExistRunningTicketParlay
			FROM	@tmpMatchCompleted m
					CROSS APPLY (
								SELECT 1 AS IsExistRunningTicketParlay
										,MAX(CASE WHEN b.IsMergedParlay = 1 THEN 1 ELSE 0 END) AS IsMergedParlay
								FROM (
										SELECT	ParentId, transid, MatchId, p.IsMergedParlay
										FROM	#temp_match_parlay p
										WHERE p.matchid = m.MatchId
									) b
									OUTER APPLY (
										SELECT TOP 1 mt.transId
										FROM	#tmpMarkedTransaction mt 
										WHERE	b.transid = mt.TransId
												AND b.MatchId = mt.matchId
									)mt
									WHERE	mt.transId IS NULL
									GROUP BY b.ParentId
								) t
		END
				
		UPDATE m 
			SET IsExistRunningTicketAfterCompleted = t.IsExistRunningTicket
				,IsExistRunningTicketParlay = t.IsExistRunningTicketParlay
		FROM	#tmpMatchIds m
			INNER JOIN @tmpMatchCompleted t
				ON	m.matchid = t.MatchId
	END

	IF @IsCompletedWithRunningTicket  = 1
	BEGIN
		DELETE 
		FROM	#tmpMatchIds
		WHERE	1 = CASE WHEN ISNULL(IsExistRunningTicketAfterCompleted,0) > 0 OR ISNULL(IsExistRunningTicketParlay,0) > 0 THEN 0 ELSE 1 END
			AND eventstatus = 'completed'
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpMatchIds WHERE sporttype = 43)
	BEGIN
		SELECT @strMatchIds = ''
				,@strEarlyBettypes = ''
				,@remoteQuery = ''

		SELECT @strEarlyBettypes = @strEarlyBettypes + CAST(bettype AS VARCHAR(20)) + ','
		FROM	dbo.f_Set_GetEarlyBettypes()

		SELECT @strMatchIds = @strMatchIds + CAST(MatchId AS VARCHAR(20)) + ','
		FROM	#tmpMatchIds
		WHERE	sporttype = 43

		SELECT	@strEarlyBettypes = LEFT(@strEarlyBettypes,LEN(@strEarlyBettypes) - 1)
				,@strMatchIds = LEFT(@strMatchIds, LEN(@strMatchIds) - 1)
		
		SET @remoteQuery = 'SELECT	DISTINCT o.matchid 
							FROM	DBPRO.bodb02.dbo.oddsES o WITH(NOLOCK)
							WHERE	o.matchid IN (' + @strMatchIds + ')
									AND bettype IN (' + @strEarlyBettypes + ')
									AND o.sporttype = 43
									AND ISNULL(o.IsDeleted,0) = 0'

		INSERT INTO @tmpMatchEsport (MatchId)
		EXECUTE sys.sp_executesql @remoteQuery
	END

	SELECT	m.matchid
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
			,m.eventstatus
			,m.IsNeutral
			,m.betstatus
			,m.suspenderhalftime
			,m.suspenderfulltime
			,m.autosetting
			,m.autosettingforleague
			,m.settlementstatus
			,q.IsCalculatingSingle
			,q.IsCalculatingMP
			,m.IsCalculated
			,m.IsMultiCaled
			,m.IsRefund
			,m.IsCalRefund
			,m.IsPending
			,m.IsHalfTimeCal
			,m.IsExistEarlyBettypes
			,m.IsExistEarlyBettypesParlay
			,CASE WHEN me.matchid IS NOT NULL THEN 1 ELSE 0 END AS IsOpenOdds 
			,m.IsMergedParlay
			,m.IsRunningEarlyBettypes
			,m.IsRunningEarlyBettypesParlay
			,m.IsWaitingEarlyBettypes
			,m.IsWaitingEarlyBettypesParlay			
			,m.IsExistRunningTicketAfterCompleted AS IsExistRunningTicket
			,m.IsExistRunningTicketParlay
			,m.IsExistMarkedTicket
			,m.IsExistMarkedTicketParlay
			,m.IsExistsConfirmedEarly
			,m.AutoPayoutStatus
			,m.BestOfMap
			,m.OfferLive
			,ISNULL(s.WaitingTime, 30) AS AutoWaitingTime
	FROM	#tmpMatchIds m
		LEFT JOIN @tmpQueueStatus q
			ON	m.matchid = q.MatchId
		LEFT JOIN @tmpMatchEsport me
			ON	m.matchid = me.MatchId
		OUTER APPLY (
			SELECT TOP 1 ss.WaitingTime
			FROM	DBPRO.bodb02.dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND AutoType = 1
					AND m.sporttype = 50
		)s
	
	drop table #ConfirmedResources
	drop table #temp_match_parlay
	drop table #tmpAllParentChildMatch
	drop table #tmpMarkedTransaction
	drop table #tmpMatchIds

END

GO