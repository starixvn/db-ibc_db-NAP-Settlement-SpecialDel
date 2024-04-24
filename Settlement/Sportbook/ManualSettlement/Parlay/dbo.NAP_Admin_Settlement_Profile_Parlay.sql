/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile_Parlay]
	 @creator				INT
	,@MatchID				INT
	,@Action		  		VARCHAR(20)		= 'CAL'
	,@IP	 				VARCHAR(15)		= ''
	,@SelectedResources		VARCHAR(MAX)
	,@hth					INT			= 0
	,@hta					INT			= 0
	,@fth					INT			= 0
	,@fta					INT			= 0
	,@FTHome_Inst			INT 		= 0
	,@FTAway_Inst			INT			= 0
	,@HTHome_Inst			INT			= 0
	,@HTAway_Inst			INT			= 0
	,@IsAuto				BIT			= 0
	,@IsReSettledTickets	BIT			= 1
	,@LockedByRefno			BIT			= 0
	,@IsCentral				BIT			= 0
	,@DeterminedType		TINYINT		= 0
	,@BroadcastSessionId	VARCHAR(50)	= NULL
	,@ParlayKeyId			INT			= 0
	,@ErrCode				INT				= 0	OUTPUT
	,@ErrMsg 				NVARCHAR(200)	= '' OUTPUT
AS
/*  Creator: 20210514@Kathy
	Task: Settlement Parlay for sport in profile
	DB: DBTXN/BODB02

	Revisions:
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210921@Max: Apply Max Parlay Payout [Redmine: #161037]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220527@Kathy: Wrong settle SDT for over/under [Redmine:#173286]
		- 20220512@Louisa: Auto refund Badminton [Redmine:#171676]
		- 20220709@Louisa: Fix select INTO [Redmine:#100002]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230215@Aries: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
		- 20230405@Louisa: Support resettle Parlay tickets [Redmine:#186276]
		- 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		- 20230523@Kathy: remove un-used table [Redmine:#188452]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		- 20230616@Aries: Support Direct Payout for Soccer Fantasy Matches [Redmine:#189493]
		- 20230817@Kathy: Write log [Redmine:#192311]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		- 20230816@Kathy: parlay boost [Redmine:#191873]
		- 20231213@Kathy: Enhance Recalculation and Instant Settle for Basketball [Redmine:#198283]
		- 20230131@Kathy: Support generate BetParlayDetail/BetParlayResult for voiding ticket [Redmine:#200440]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]

		
		- 20231214@Aries: Result Amendment [Redmine: #196401]

	Param's Explanation:
		* @SelectedResources= '<Resources>
									<Resource Id="M1" Home="1" Away="3" />
									<Resource Id="M2" Home="2" Away="4" />
							   </Resources>'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @start				DATETIME
			,@stop				DATETIME
			,@ActionID			INT
			
			,@avaiableProcess	BIT		
			,@Session			NVARCHAR(50)
			,@SPName			SYSNAME
						
			,@ParentMatchId		INT
			,@eventdate			DATETIME
			,@sqlCommand		VARCHAR(MAX) = ''
			,@sportType 		INT
			,@handle			INT
			,@batchNo			INT 			= 2000	
			,@totalSubParlay	INT = 0
			,@strTransIds		VARCHAR(MAX)	= ''	
			,@strMainTransIds		VARCHAR(MAX)	= ''
			,@strMainTransIdRefnos	VARCHAR(MAX) = ''			
			,@totalMainParlay		INT
			,@IsABANDONEDHT			BIT = 0
			,@IsSDT				BIT = 0
			,@subAction			VARCHAR(20) = ''
			,@ResourceRefund	VARCHAR(100) = NULL
			,@RemarkSDT			VARCHAR(500) = ''
			,@strUndoTransIds	VARCHAR(MAX) = ''
			,@strTransIdsSDT	VARCHAR(MAX) = ''
			,@SiteDBGroupId		TINYINT
			,@strSetting		VARCHAR(MAX)
			,@sqlOpenqueryCommand NVARCHAR(MAX) = ''
			,@MainTransIdVoided VARCHAR(MAX) = ''
			,@SessionId			BIGINT

			,@MessageTypePattern		VARCHAR(200) = 'parlaybet_settle_msg_type_0'
			,@MessageType				VARCHAR(200) 
			,@ExecParlayDataQueueSize	SMALLINT -- number of queue run parallel
			,@RunExecParlayDataBySSB	BIT = 0
			,@TotalBatch				INT = 0
			,@i							INT = 1
			
			,@LogData			XML
			,@ResultRemarkLog	VARCHAR(MAX) = ''
			,@Remark			VARCHAR(MAX) = ''
			,@matchLog			INT = @matchid
			,@IsAutoRefund		BIT = 0
			,@CommandMonitor	NVARCHAR(MAX)
			,@SSBStatus			TINYINT
			,@MainParlay_MaxPO	VARCHAR(MAX) = NULL

	DECLARE @tmpMainTransIdBatch TABLE (TransId BIGINT, Refno BIGINT)
	DECLARE @tmpSubTransIdBatch TABLE (Id INT IDENTITY(1,1) PRIMARY KEY, TransId BIGINT, Refno BIGINT, modds MONEY, moddsSDT SMALLMONEY, IsMarked BIT)
	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
		HomeRound TINYINT, AwayRound TINYINT,
		BetType SMALLINT, BetID BIGINT, pfID SMALLINT,SDTpfId SMALLINT
		, OddsType SMALLINT, RoundName VARCHAR(20), OrdNo SMALLINT, IsSDT BIT, SDTResourceId VARCHAR(20), DeterminedType TINYINT DEFAULT(0)
		, IsCalculated BIT
		, IsWeb BIT
		, MinusValue SMALLMONEY  DEFAULT(0)
		, IsInstHTFT BIT DEFAULT(0)
	)

	DECLARE @tmpResourceAutoRefund TABLE ( ResourceID VARCHAR(20) )
	DECLARE @tmpMarkedTicket TABLE ( MatchId INT , bettype SMALLINT ) ---use for Auto Refund

	DECLARE @tmpBoostSite TABLE(SiteId INT, srecommend INT, IsDeposit BIT DEFAULT(0))

	DECLARE @tmpBoostSetting TABLE (SiteId INT, OverOdds DECIMAL(9,4), Boost TINYINT)

	DECLARE @tmpParlayDebitPending		TVP_BalanceList
			,@tmpParlayCreditPending	TVP_BalanceList

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpParlayBalanceBefore (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #tmpParlayBalanceAfter (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #tmpParlayBalance (custid int, balance money)	
	CREATE TABLE #tmpMainTransId (Id INT IDENTITY(1,1) PRIMARY KEY, transid BIGINT, refno BIGINT, IsFinished BIT, betteam NVARCHAR(10), oddsspread MONEY, SiteID VARCHAR(7), srecommend INT, MainParlayMaxPO VARCHAR(MAX), statusId TINYINT) --ruben TINYINT, custid INT, )
	--END Balance tables

	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	CREATE TABLE #tmpsubTransID (Id BIGINT IDENTITY(1,1),TransID BIGINT, refno BIGINT, modds SMALLMONEY, moddsSDT SMALLMONEY, IsSDT BIT DEFAULT(0), isFinish BIT, IsMarked BIT
		, IsInstHTFT BIT DEFAULT(0), bettype SMALLINT, hdp1 SMALLMONEY, betteam VARCHAR(10))
	CREATE TABLE #tmpRefnos (refno BIGINT)
	----------------------------------------------------------------------------------------------------------------------

  	SELECT  @start = CURRENT_TIMESTAMP
			,@ActionID = CASE 
							WHEN @Action LIKE 'CAL%' THEN 81028 -- new action Id
							WHEN @Action LIKE 'REFUND%' THEN 81029 
							WHEN @Action LIKE 'UNDO%' THEN IIF(@Action = 'UNDO-FT', 81041,81030)
						END
			,@SPName = OBJECT_NAME(@@PROCID)
			,@session = CONVERT(NVARCHAR(50),NEWID())

  	--get info of match
  	SELECT	@sportType	= sportType
			,@eventdate	= eventdate
			,@ParentMatchId = CASE WHEN ChildMatchType = 200 AND ParentID IS NOT NULL AND sporttype = 50 THEN ParentID ELSE NULL END
			,@IsABANDONEDHT = CASE WHEN sporttype = 1 AND betstatus LIKE '%ABANDONED 1H%' THEN 1 ELSE 0 END
  	FROM	DBPRO.bodb02.dbo.match WITH (NOLOCK)
  	WHERE   matchid = @matchid
  	
	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	
	;WITH cteSelectedRID
	AS (
		SELECT	Id
				,RefResourceId AS RefResourceId
				,ISNULL(SDTResourceId,'') AS SDTResourceId
				,ISNULL(Bettype,'') AS Bettype
				,ISNULL(pfId,'') AS pfId
				,ISNULL(SDTpfId,'') AS SDTpfId
				,ISNULL(Home,'') AS HomeValue
				,ISNULL(Away,'') AS AwayValue
				,ISNULL(IsSDT,0) AS IsSDT
				,ISNULL(HomeRound,'') AS HomeRound
				,ISNULL(AwayRound,'') AS AwayRound
				,ISNULL(DeterminedType,'') AS DeterminedType
				,ISNULL(IsCalculated,'') AS IsCalculated
				,ISNULL(IsWeb,'') AS IsWeb
				,ISNULL(MinusValue,0)	AS MinusValue
				,ISNULL(IsInstHTFT,0)	AS IsInstHTFT
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,RefResourceId VARCHAR(20)
															,SDTResourceId VARCHAR(20)
															,Bettype SMALLINT
															,pfId INT		
															,SDTpfId INT
															,Home VARCHAR(50)
															,Away VARCHAR(50)
															,IsSDT BIT
															,HomeRound TINYINT
															,AwayRound TINYINT
															,DeterminedType TINYINT
															,IsCalculated BIT
															,IsWeb BIT
															,MinusValue SMALLMONEY
															,IsInstHTFT BIT
											) AS tbl
	)
	INSERT INTO @tmpSelectedRID (ResourceID, SDTResourceId, Bettype, BetId, pfId, SDTpfId, OddsType, HomeValue, AwayValue, OrdNo, RoundName, IsSDT, HomeRound, AwayRound, DeterminedType,IsCalculated,IsWeb,MinusValue, IsInstHTFT)
	SELECT	 c.Id
			,c.SDTResourceId
			,sp.Bettype
			,sp.BetId
			,sp.pfId
			,IIF(@sportType = 1,sp.SDTpfId,c.SDTpfId)
			,sp.OddsType
			,c.HomeValue
			,c.AwayValue
			,sp.OrdNo
			,sd.RoundName
			,c.IsSDT
			,c.HomeRound
			,c.AwayRound
			,c.DeterminedType
			,c.IsCalculated
			,c.IsWeb
			,c.MinusValue
			,c.IsInstHTFT
	FROM	cteSelectedRID c
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			ON	 sp.ResourceID = c.Id
					AND sp.BetType = c.Bettype
		LEFT JOIN dbo.f_Set_MajorRound(@Sporttype) sd 
			ON	ISNULL(sp.RefResourceId,sp.ResourceID) = sd.ResourceID
	WHERE	sp.SportType = @Sporttype
	
	IF @SportType != 1 AND @DeterminedType > 0
	BEGIN
		SELECT  @RemarkSDT = RemarkSDT
		FROM OPENXML(@handle,'/Resources',1) WITH(RemarkSDT	VARCHAR(500)) as tbl
	END

	EXEC sp_xml_removedocument @handle

  	--get transid
  	IF @Action LIKE 'CAL%'
  	BEGIN
		IF @sportType = 1 AND @Action <> 'CAL_EAR'
		BEGIN
			INSERT INTO #tmpsubTransID (TransID, modds, refno, IsMarked)
			SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE NULL END AS IsMarked
			FROM	dbo.bettransm bm WITH(NOLOCK)
				CROSS APPLY (
					SELECT	TOP 1 pfID, HomeValue, AwayValue
					FROM	@tmpSelectedRID t
					WHERE	t.BetType = bm.bettype
							AND (t.BetID = 0 OR t.BetID = bm.betcheck)
							AND t.DeterminedType = 0
				)sr
				CROSS APPLY dbo.f_Set_Calculate_modds_major(sr.pfID, bm.betteam, bm.hdp1, bm.hdp2, sr.HomeValue, sr.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, bm.betcheck) m
				LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
					ON	b.matchid = 29
						AND b.bettype = 29
						AND b.refno = bm.refno
				OUTER APPLY (
						SELECT TOP (1) mt.TransId
						FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						WHERE	mt.TransId = b.transId
								AND mt.MatchId = @MatchID
				) mt
			WHERE	bm.matchid = @MatchID
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
					AND bm.statusID NOT IN (101)
					AND 1 = CASE 
								WHEN @IsReSettledTickets = 0 AND bm.statusID IN (0,102) THEN 1
								WHEN @IsReSettledTickets = 1 THEN 1
								ELSE 0
							END

			SET @totalSubParlay = @@ROWCOUNT

			
			IF EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID WHERE DeterminedType > 0)
			BEGIN
				INSERT INTO #tmpsubTransID (TransID, modds, refno, IsMarked)
				SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE NULL END AS IsMarked
				FROM	dbo.bettransm bm WITH(NOLOCK)
					CROSS APPLY (
						SELECT	TOP 1 SDTpfId, HomeValue, AwayValue
						FROM	@tmpSelectedRID t
						WHERE	t.BetType = bm.bettype
								AND (t.BetID = 0 OR t.BetID = bm.betcheck)
								AND t.DeterminedType & @DeterminedType > 0
					)sr
					OUTER APPLY dbo.f_Set_SDT_modds(sr.SDTpfId, bm.betteam, bm.hdp1, bm.hdp2, @hth, @hta, @fth, @fta, sr.HomeValue, sr.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, bm.betcheck, 0) m
					LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
						ON	b.matchid = 29
							AND b.bettype = 29
							AND b.refno = bm.refno
					OUTER APPLY (
							SELECT TOP (1) mt.TransId
							FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
							WHERE	mt.TransId = b.transId
									AND mt.MatchId = @MatchID
					) mt
				WHERE	bm.matchid = @MatchID
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
							AND b.recommend <> 1688156) --exclude betdaq/betfair
						--AND bm.statusID IN (0,102)
						AND m.modds IS NOT NULL
						AND ((bm.statusId = 0 AND ISNULL(bm.SecAcceptFlag,0)=0)
							OR (bm.statusID = 0 AND bm.SecAcceptFlag=1 AND ISNULL(bm.checktime,CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
							OR bm.statusID = 102
						)
						AND 1 = CASE 
									WHEN @DeterminedType IN (1,4) AND m.modds > -0.5 AND m.modds < 0.5 THEN 0									
									ELSE 1 
								END
						and 1 = case 
								when sr.SDTpfId = 3 then case when (@fth + @fta) - 0.25 > bm.hdp1 then 1 else 0 end
								when sr.SDTpfId = 388 then case when @fta - 0.25 > bm.hdp1 then 1 else 0 end
								when sr.SDTpfId = 389 then case when @fth - 0.25 > bm.hdp1 then 1 else 0 end
								else 1
							end

				SET @totalSubParlay = @totalSubParlay + @@ROWCOUNT
			END
			
		END
		ELSE
		BEGIN
			IF @DeterminedType = 0
			BEGIN
				INSERT INTO #tmpsubTransID (TransID, modds, refno, IsMarked)
				SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE NULL END AS IsMarked
				FROM	dbo.bettransm bm WITH(NOLOCK)
					CROSS APPLY (
						SELECT	TOP 1 pfID, HomeValue, AwayValue
						FROM	@tmpSelectedRID t
						WHERE	t.BetType = bm.bettype
								AND (t.BetID = 0 OR t.BetID = bm.betcheck)
					)sr
					CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, bm.betteam, bm.hdp1, bm.hdp2, sr.HomeValue, sr.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, bm.betcheck) m
					LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
						ON	b.matchid = 29
							AND b.bettype = 29
							AND b.refno = bm.refno
					OUTER APPLY (
							SELECT TOP (1) mt.TransId
							FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
							WHERE	mt.TransId = b.transId
									AND mt.MatchId = @MatchID
					) mt
				WHERE	bm.matchid = @MatchID
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND bm.statusID NOT IN (101)
						AND 1 = CASE 
									WHEN @IsReSettledTickets = 0 AND bm.statusID IN (0,102) THEN 1
									WHEN @IsReSettledTickets = 1 THEN 1
									ELSE 0
								END

				SET @totalSubParlay = @@ROWCOUNT
			END
			ELSE IF @sportType != 1 AND  @DeterminedType > 0
			BEGIN
				INSERT INTO #tmpsubTransID (TransID, modds, refno, IsMarked, IsInstHTFT, bettype, hdp1, betteam)
				SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE NULL END AS IsMarked, sr.IsInstHTFT, bm.bettype, bm.hdp1, bm.betteam
				FROM	dbo.bettransm bm WITH(NOLOCK)
					CROSS APPLY (
						SELECT	TOP 1 SDTpfId, HomeValue, AwayValue, IsCalculated, MinusValue, IsInstHTFT
						FROM	@tmpSelectedRID t
						WHERE	t.BetType = bm.bettype AND (t.BetID = 0 OR t.BetID = bm.betcheck)
					)sr
					OUTER APPLY dbo.f_Set_SDT_OS_modds(sr.SDTpfId, bm.betteam, bm.hdp1,sr.HomeValue, sr.AwayValue, bm.transdesc,sr.MinusValue) m
					LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
						ON	b.matchid = 29
							AND b.bettype = 29
							AND b.refno = bm.refno
					OUTER APPLY (
							SELECT TOP (1) mt.TransId
							FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
							WHERE	mt.TransId = b.transId
									AND mt.MatchId = @MatchID
					) mt
				WHERE bm.matchid = @MatchID
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
					AND bm.statusID NOT IN (1,101)
					AND 1 = CASE WHEN @IsReSettledTickets = 0 AND bm.statusID IN (0,102) AND m.modds IS NOT NULL  THEN 1
								 WHEN @IsReSettledTickets = 1 AND m.modds IS NOT NULL THEN 1
								 WHEN @IsReSettledTickets = 1 AND m.modds IS NULL AND  (bm.statusID IN (111,112,113) OR  ISNULL(bm.statuswinlost,'') != '') AND sr.IsCalculated = 0 THEN 1
								 ELSE 0
							 END
							 
				SET @totalSubParlay = @@ROWCOUNT
				
				IF EXISTS (SELECT TOP 1 1 FROM #tmpsubTransID WHERE modds IS NULL AND IsInstHTFT = 1) AND (@HTHome_Inst IS NOT NULL OR @HTAway_Inst IS NOT NULL OR @FTHome_Inst IS NOT NULL OR @FTAway_Inst IS NOT NULL)
				BEGIN
					DELETE b
					FROM #tmpsubTransID AS b
						CROSS APPLY(
									SELECT TOP 1 
										   t.SDTpfId
										  ,CAST((IIF(ResourceID = '00', ISNULL(@FTHome_Inst,0), ISNULL(@HTHome_Inst,0)) +  CAST(t.HomeValue  AS INT)) AS VARCHAR(2000)) AS HomeValue
										  ,CAST((IIF(ResourceID = '00', ISNULL(@FTAway_Inst,0), ISNULL(@HTAway_Inst,0)) +  CAST(t.AwayValue  AS INT)) AS VARCHAR(2000)) AS AwayValue
										  ,6 AS MinusValue
									FROM @tmpSelectedRID AS t
									WHERE b.BetType = t.BetType AND t.BetID = 0
								) AS sr
						CROSS APPLY dbo.f_Set_SDT_OS_modds(sr.SDTpfId, b.betteam, b.hdp1, sr.HomeValue, sr.AwayValue, NULL,sr.MinusValue) AS m
					WHERE b.modds IS NULL 
						AND b.IsInstHTFT = 1
						AND m.modds IS NOT NULL
						
					SET @totalSubParlay = @totalSubParlay - @@ROWCOUNT
				END
			END
		END
	END
	ELSE IF @action LIKE 'UNDO%'
	BEGIN
		INSERT INTO #tmpsubTransID (TransID, refno, IsMarked)
		SELECT	bm.transid, bm.refno , CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE NULL END AS IsMarked 
		FROM	dbo.bettransm bm WITH(NOLOCK)
			CROSS APPLY (
				SELECT	TOP 1 pfID, HomeValue, AwayValue
				FROM	@tmpSelectedRID t
				WHERE	t.BetType = bm.bettype
						AND (t.BetID = 0 OR t.BetID = bm.betcheck)
						AND t.DeterminedType = 0
			)sr
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK) 
				ON	b.matchid = 29
					AND b.bettype = 29
					AND b.refno = bm.refno
			OUTER APPLY (
				SELECT	TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transid
						AND mt.MatchId = @MatchID
			) mt
		WHERE	bm.matchid = @MatchID
				AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				AND bm.statusID NOT IN (101)
				AND 1 = CASE WHEN bm.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
							 WHEN bm.statusID NOT IN (0, 1) THEN 1
							 ELSE 0 
						END

		SET @totalSubParlay = @@ROWCOUNT

		IF EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID WHERE DeterminedType > 0)
		BEGIN
			INSERT INTO #tmpsubTransID (TransID, refno, IsMarked)
			SELECT	bm.transid, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE NULL END AS IsMarked 
			FROM	dbo.bettransm bm WITH(NOLOCK)
				CROSS APPLY (
					SELECT	TOP 1 SDTpfId, HomeValue, AwayValue
					FROM	@tmpSelectedRID t
					WHERE	t.BetType = bm.bettype
							AND (t.BetID = 0 OR t.BetID = bm.betcheck)
							AND t.DeterminedType & @DeterminedType > 0
				)sr
				OUTER APPLY dbo.f_Set_SDT_modds(sr.SDTpfId, bm.betteam, bm.hdp1, bm.hdp2, @hth, @hta, @fth, @fta, sr.HomeValue, sr.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, bm.betcheck, 0) m
				LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
					ON	b.matchid = 29
						AND b.bettype = 29
						AND b.refno = bm.refno
				OUTER APPLY (
						SELECT TOP (1) mt.TransId
						FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						WHERE	mt.TransId = b.transId
								AND mt.MatchId = @MatchID
				) mt
			WHERE	bm.matchid = @MatchID
					AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
							AND b.recommend <> 1688156) --exclude betdaq/betfair
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
					AND 1 = CASE
								WHEN bm.statusId IN (112, 113)
									AND (bm.statusId <> CASE
													WHEN m.modds >= 0.5 THEN 112
													WHEN m.modds <= -0.5 THEN 113
													ELSE 0
												END 
									) THEN 1
								WHEN bm.statusId = 0 AND mt.TransId IS NOT NULL
									AND ISNULL(bm.statuswinlost,0) <> 0
									AND m.modds IS NULL THEN 1
								ELSE 0
							END
				
			SET @totalSubParlay = @totalSubParlay + @@ROWCOUNT
		END
	END 
	ELSE IF @action LIKE 'REFUND%' 
	BEGIN
		IF @DeterminedType = 0
		BEGIN
			INSERT INTO #tmpsubTransID (TransID, refno, modds)
			SELECT	bm.transid, bm.refno, 0
			FROM	dbo.bettransm bm WITH(NOLOCK)
				CROSS APPLY (
					SELECT	TOP 1 bettype
					FROM	@tmpSelectedRID t
					WHERE	t.BetType = bm.bettype
							AND (t.BetID = 0 OR t.BetID = bm.betcheck)
							AND t.IsSDT = 0
				)sr
			WHERE	bm.matchid = @MatchID
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
					AND bm.statusID NOT IN (101,103)
		
			SET @totalSubParlay = @@ROWCOUNT
		END
		ELSE IF @sportType != 1 AND @DeterminedType > 0
		BEGIN
			INSERT INTO #tmpsubTransID (TransID, refno, modds,moddsSDT)
			SELECT	bm.transid, bm.refno, ISNULL(m.modds,0), m.modds
			FROM	dbo.bettransm bm WITH(NOLOCK)
				CROSS APPLY (
					SELECT	TOP 1 SDTpfId, HomeValue, AwayValue, MinusValue
					FROM	@tmpSelectedRID t
					WHERE	t.BetType = bm.bettype AND (t.BetID = 0 OR t.BetID = bm.betcheck)
				)sr
				OUTER APPLY dbo.f_Set_SDT_OS_modds(sr.SDTpfId, bm.betteam, bm.hdp1, sr.HomeValue, sr.AwayValue, bm.transdesc, sr.MinusValue) m
			WHERE	bm.matchid = @MatchID
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END					
					AND bm.statusID NOT IN (101)
					AND	1 = CASE WHEN m.modds IS NOT NULL THEN 1
								 WHEN m.modds IS NULL AND statusID NOT IN (103) THEN 1
								 ELSE 0
						    END

			SET @totalSubParlay = @@ROWCOUNT
		END

		IF @sportType = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID WHERE IsSDT = 1) 
		BEGIN
			SET @IsSDT = 1
			
			IF @Action = 'REFUND_EAR'
			BEGIN
				INSERT INTO #tmpsubTransID (TransID, refno, modds, IsSDT)
	  			SELECT	bm.transid, bm.refno, ISNULL(m.modds,0), CASE WHEN m.modds IS NULL THEN 0 ELSE 1 END
	  			FROM	dbo.bettransm bm WITH (NOLOCK)					
	  				CROSS APPLY(
	  					SELECT TOP 1 pfID, HomeValue, AwayValue, t.oddstype, t.HomeRound, t.AwayRound
	  					FROM	@tmpSelectedRID t
	  					WHERE	bm.BetType = t.BetType 
								AND (t.BetID = 0 OR bm.betcheck = t.BetID) 
								AND t.IsSDT = 1
	  				) sr
	  				CROSS APPLY dbo.f_Set_SDT_CalModds_Early(sr.pfID, bm.betteam, bm.hdp1, NULL, sr.HomeValue, sr.AwayValue, NULL, NULL, sr.HomeRound, sr.AwayRound) m
	  			WHERE	bm.matchid = @MatchId
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
	  					AND bm.statusID NOT IN (101)

				SET @totalSubParlay = @totalSubParlay + @@ROWCOUNT
			END
			ELSE
			BEGIN
				IF @IsABANDONEDHT = 1
					SELECT @fth = @hth
							,@fta = @hta

				INSERT INTO #tmpsubTransID (TransID, refno, modds, IsSDT)
				SELECT	bm.transid, bm.refno, ISNULL(m.modds,0), CASE WHEN m.modds IS NULL THEN 0 ELSE 1 END
				FROM	dbo.bettransm bm WITH(NOLOCK)
					CROSS APPLY (
						SELECT	TOP 1 SDTpfId, HomeValue, AwayValue
						FROM	@tmpSelectedRID t
						WHERE	t.BetType = bm.bettype
								AND (t.BetID = 0 OR t.BetID = bm.betcheck)
								AND t.IsSDT = 1
					)sr
					CROSS APPLY dbo.f_Set_SDT_modds(sr.SDTpfId, bm.betteam, bm.hdp1, bm.hdp2, @hth, @hta, @fth, @fta, sr.HomeValue, sr.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, bm.betcheck, @IsABANDONEDHT) m
				WHERE	bm.matchid = @MatchID
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND bm.statusID NOT IN (101)
		
				SET @totalSubParlay = @totalSubParlay + @@ROWCOUNT
			END
		END
	END  
	
	IF @totalSubParlay = 0
		RETURN 

	--check settlement process
	IF @LockedByRefno = 1
	BEGIN
		INSERT INTO #tblMatchParlayProcess (matchid, RefNo) 
		SELECT	@MatchID, refno
		FROM	#tmpsubTransID
		
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefno		= 1
			,@SPName				= @SPName
			,@Session				= @Session
			, @avaiableProcess 		= @avaiableProcess OUTPUT
			, @ErrCode				= @ErrCode OUTPUT
			, @ErrMsg				= @ErrMsg OUTPUT
	END
	
	IF @ErrCode <> 0
		RETURN
	
	EXEC dbo.NAP_Set_GlobalSettingSel	
		@LockName = 'ParlaySettlementSSB'
		,@RunExecParlayDataBySSB =  @RunExecParlayDataBySSB OUTPUT
		,@ExecParlayDataQueueSize = @ExecParlayDataQueueSize OUTPUT

	INSERT INTO dbo.Settlement_SettledSession (MatchId)
	SELECT @matchid
	SET @SessionId = SCOPE_IDENTITY()
	
	-- settle main parlay			
	INSERT INTO #tmpRefnos (refno)
	SELECT	t.refno
	FROM	#tmpsubTransID t
	WHERE	NOT EXISTS (SELECT TOP 1 1 
						FROM	dbo.bettransm bm WITH(NOLOCK) 
						WHERE	bm.refno = t.refno 
								AND bm.statusID IN (1,101))
	
	INSERT INTO #tmpMainTransId (transid, refno, IsFinished, betteam, oddsspread, SiteID, srecommend, MainParlayMaxPO, statusId)
	SELECT main.transid, main.refno, main.IsFinished, main.betteam, main.oddsspread, main.BetSiteID, main.srecommend, CAST(info.MainParlayMaxPO AS VARCHAR(MAX)) AS MainParlayMaxPO, main.statusId
	FROM (
		SELECT	transid, refno, 0 AS IsFinished, custid, ruben
				,betteam -- 1: combo parlay
				,oddsspread -- 2: offer boost bonus
				,BetSiteID
				,srecommend
				,statusId
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = 29
				AND b.statusID NOT IN (101)-- 'REJECT'
				AND EXISTS (SELECT TOP 1 refno FROM #tmpRefnos t WHERE t.refno = b.refno)
	) main
		CROSS APPLY (SELECT transid '@transid', ruben '@ruben' FOR XML PATH('r')) info (MainParlayMaxPO)

	SET @totalMainParlay = @@ROWCOUNT -- number of system parlay ticket

	IF @totalMainParlay > 0  -- got system parlay tickets
	BEGIN
		INSERT INTO @tmpBoostSite(SiteId, srecommend )
		SELECT DISTINCT SiteID, srecommend
		FROM	#tmpMainTransId t
		WHERE	t.betteam = '1' -- mix parlay
				AND t.oddsspread = 2 -- offer parlay bonus

		UPDATE si 
			SET IsDeposit = 1
		FROM	@tmpBoostSite si
			INNER JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK)
				ON si.srecommend = d.custid

		SET @sqlOpenqueryCommand = 'SELECT SiteId, OverOdds, Boost FROM OPENQUERY(DBPRO,''SELECT SiteId, OverOdds, Boost FROM bodb02.dbo.ParlayOddsBoostSetting p WITH(NOLOCK) WHERE p.SiteId IN ('
										+ (SELECT  STRING_AGG(CAST(s.SiteID AS VARCHAR(MAX)),',') 
											FROM (
												SELECT SiteId
												FROM (
													SELECT SiteId
													FROM @tmpBoostSite t
													UNION
													SELECT -1
													UNION 
													SELECT -2
												) t
												GROUP BY t.SiteID
											) s 
										)
								+ ')'')'
	
		INSERT INTO @tmpBoostSetting(SiteId, OverOdds, Boost)							
		EXEC (@sqlOpenqueryCommand)
			
		SELECT @strSetting = CAST((
			SELECT	si.SiteId AS 's'
					,(SELECT t.OverOdds AS 'o', t.Boost AS 'b' -- get its own settings
						FROM (SELECT se.SiteId, se.OverOdds, se.Boost
							FROM	@tmpBoostSetting se
							WHERE	EXISTS (SELECT TOP 1 1 FROM	@tmpBoostSite si WHERE se.SiteId = si.SiteId)
							UNION
							SELECT	si.SiteId, se.OverOdds, se.Boost -- If the site ID does not have its own settings, the default value will be taken on default SiteId (-1 if it's credit, -2 if it's licensee)
							FROM	@tmpBoostSite si
								CROSS APPLY (
									SELECT	se.OverOdds, se.Boost
									FROM	@tmpBoostSetting se
									WHERE	se.SiteId = CASE WHEN si.IsDeposit = 1 THEN -2 ELSE -1 END
								) se
							WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpBoostSetting se WHERE si.SiteId = se.SiteId)
						) t
					WHERE si.SiteId = t.SiteId
					FOR JSON AUTO
					) AS v
			FROM	@tmpBoostSite si
			FOR JSON AUTO
		) AS VARCHAR(MAX))
	END

	EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchid
		,@mode = 'ParlayLockMatch'
		,@SessionId = @SessionId
		
	IF @IsCentral = 0 AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLogIns','P') IS NOT NULL 
	BEGIN
		EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns
			@SystemName		= 'Settlement'
			,@FunctionName	= 'CalculateParlay'
			,@TableName		= 'SiteDB_ParlaySettlementLock'
			,@Action		= 'I'
			,@MatchId		= @matchid
			,@SessionId		= @SessionId
			,@TicketType 	= 'p'
					,@BroadcastSessionId = @BroadcastSessionId
	END

	BEGIN TRY
		-- settle parlay
		BEGIN
			IF @IsSDT = 1
			BEGIN
				INSERT INTO dbo.ParlaySettlementProcessing(SessionId, MatchId, MessageType, Action, ActionId, subTransIds, mainTransIds, RefnoMainTransIds, EventDate, strSetting, IsReSettledTickets, MainParlayMaxPO)
				SELECT @SessionId
						,@MatchID
						,@MessageTypePattern + CAST(CASE WHEN main.batchNo%@ExecParlayDataQueueSize = 0 THEN @ExecParlayDataQueueSize ELSE main.batchNo%@ExecParlayDataQueueSize END AS VARCHAR)
						,'CAL' AS Action
						,@ActionID
						,sub.subTransIds
						,main.MainTransIds
						,main.RefnoMainTransIds
						,@EventDate AS EventDate
						,@strSetting
						,@IsReSettledTickets
						,main.MainParlayMaxPO
				FROM(
					SELECT	s1.Id/@batchNo AS batchNo
							,STRING_AGG(CAST(main.TransId AS VARCHAR(MAX)),',') AS MainTransIds 
							,STRING_AGG(CASE WHEN main.statusId = 102 THEN NULL ELSE CAST(main.Refno AS VARCHAR(MAX)) + '|' + CAST(main.TransId AS VARCHAR(MAX)) END,',') AS RefnoMainTransIds
							,('<root>' + STRING_AGG(CAST(main.MainParlayMaxPO AS VARCHAR(MAX)), '') + '</root>') AS MainParlayMaxPO
					FROM	#tmpsubTransID s1
						LEFT JOIN #tmpMainTransId main
							ON s1.refno = main.refno
					WHERE	s1.IsSDT = 1
					GROUP BY s1.id/@batchNo
				) main
					CROSS APPLY (
						SELECT CAST((SELECT	s2.transid AS 't'	
									,s2.modds AS 'm'
									,s2.refno AS 'r'
									,s2.IsMarked AS 'im'
						FROM	#tmpsubTransID s2         
						WHERE	s2.IsSDT = 1
								AND s2.id/@batchNo = main.batchNo
						FOR JSON AUTO) AS VARCHAR(MAX)) AS subTransIds
					) sub

				SET @TotalBatch = @@ROWCOUNT

				UPDATE	#tmpsubTransID
					SET isFinish = 1
				WHERE	IsSDT = 1
			END
			
			IF @Action LIKE 'CAL%' AND @sportType != 1 AND @DeterminedType > 0 AND  @IsReSettledTickets = 1
			BEGIN
				INSERT INTO dbo.ParlaySettlementProcessing(SessionId, MatchId, MessageType, Action, ActionId, subTransIds, mainTransIds, RefnoMainTransIds, EventDate, strSetting, IsReSettledTickets, MainParlayMaxPO, BroadcastSessionId)
				SELECT	@SessionId
						,@MatchID
						,@MessageTypePattern + CAST(CASE WHEN main.batchNo%@ExecParlayDataQueueSize = 0 THEN @ExecParlayDataQueueSize ELSE main.batchNo%@ExecParlayDataQueueSize END AS VARCHAR)
						,'UNDO' AS Action
						,@ActionID
						,sub.subTransIds
						,main.MainTransIds
						,main.RefnoMainTransIds
						,@EventDate AS EventDate
						,@strSetting
						,@IsReSettledTickets
						,main.MainParlayMaxPO
						,@BroadcastSessionId 
				FROM(
					SELECT	s1.Id/@batchNo AS batchNo
							,STRING_AGG(CAST(main.TransId AS VARCHAR(MAX)),',') AS MainTransIds 
							,STRING_AGG(CASE WHEN main.statusId = 102 THEN NULL ELSE CAST(main.Refno AS VARCHAR(MAX)) + '|' + CAST(main.TransId AS VARCHAR(MAX)) END,',') AS RefnoMainTransIds
							,('<root>' + STRING_AGG(CAST(main.MainParlayMaxPO AS VARCHAR(MAX)), '') + '</root>' ) AS MainParlayMaxPO
					FROM	#tmpsubTransID s1
						LEFT JOIN #tmpMainTransId main
							ON s1.refno = main.refno
					WHERE	s1.modds IS NULL
					GROUP BY s1.id/@batchNo
				) main
					CROSS APPLY (
						SELECT CAST((SELECT	s2.transid AS 't'
									,s2.refno AS 'r'
						FROM	#tmpsubTransID s2         
						WHERE	s2.modds IS NULL
								AND s2.id/@batchNo = main.batchNo
						FOR JSON AUTO) AS VARCHAR(MAX)) AS subTransIds
					) sub

				SET @TotalBatch = @TotalBatch + @@ROWCOUNT

				UPDATE	#tmpsubTransID
					SET isFinish = 1
				WHERE	modds IS NULL
			END
			ELSE IF @Action LIKE 'REFUND%' AND @sportType != 1 AND @DeterminedType > 0 
			BEGIN
				INSERT INTO dbo.ParlaySettlementProcessing(SessionId, MatchId, MessageType, Action, ActionId, subTransIds, mainTransIds, RefnoMainTransIds, EventDate, strSetting, IsReSettledTickets, MainParlayMaxPO, BroadcastSessionId)
				SELECT	@SessionId
						,@MatchID
						,@MessageTypePattern + CAST(CASE WHEN main.batchNo%@ExecParlayDataQueueSize = 0 THEN @ExecParlayDataQueueSize ELSE main.batchNo%@ExecParlayDataQueueSize END AS VARCHAR)
						,'CAL' AS Action
						,@ActionID
						,sub.subTransIds
						,main.MainTransIds
						,main.RefnoMainTransIds
						,@EventDate AS EventDate	
						,@strSetting
						,@IsReSettledTickets
						,main.MainParlayMaxPO
						,@BroadcastSessionId
				FROM(
					SELECT	s1.Id/@batchNo AS batchNo
							,STRING_AGG(CAST(main.TransId AS VARCHAR(MAX)),',') AS MainTransIds 
							,STRING_AGG(CASE WHEN main.statusId = 102 THEN NULL ELSE CAST(main.Refno AS VARCHAR(MAX)) + '|' + CAST(main.TransId AS VARCHAR(MAX)) END,',') AS RefnoMainTransIds
							,('<root>' + STRING_AGG(CAST(main.MainParlayMaxPO AS VARCHAR(MAX)), '') + '</root>' ) AS MainParlayMaxPO
					FROM	#tmpsubTransID s1
						LEFT JOIN #tmpMainTransId main
							ON s1.refno = main.refno
					WHERE	s1.moddsSDT IS NOT NULL
					GROUP BY s1.id/@batchNo
				) main
					CROSS APPLY (
						SELECT CAST((SELECT	s2.transid AS 't'
									,s2.modds AS 'm'
									,s2.refno AS 'r'
									,s2.IsMarked AS 'im'
						FROM	#tmpsubTransID s2         
						WHERE	s2.moddsSDT IS NOT NULL
								AND s2.id/@batchNo = main.batchNo
						FOR JSON AUTO) AS VARCHAR(MAX)) AS subTransIds
					) sub
				
				SET @TotalBatch = @TotalBatch + @@ROWCOUNT

				UPDATE	#tmpsubTransID
					SET isFinish = 1
				WHERE	moddsSDT IS NOT NULL
			END
			
			INSERT INTO dbo.ParlaySettlementProcessing(SessionId, MatchId, MessageType, Action, ActionId, subTransIds, mainTransIds, RefnoMainTransIds, EventDate, strSetting, IsReSettledTickets, MainParlayMaxPO, BroadcastSessionId)
			SELECT	@SessionId
					,@MatchID
					,@MessageTypePattern + CAST(CASE WHEN main.batchNo%@ExecParlayDataQueueSize = 0 THEN @ExecParlayDataQueueSize ELSE main.batchNo%@ExecParlayDataQueueSize END AS VARCHAR)
					,@Action AS Action
					,@ActionID
					,sub.subTransIds
					,main.MainTransIds
					,main.RefnoMainTransIds
					,@EventDate AS EventDate
					,@strSetting
					,@IsReSettledTickets
					,main.MainParlayMaxPO
					,@BroadcastSessionId
			FROM(
					SELECT	s1.Id/@batchNo AS batchNo
							,STRING_AGG(CAST(main.TransId AS VARCHAR(MAX)),',') AS MainTransIds 
							,STRING_AGG(CASE WHEN main.statusId = 102 THEN NULL ELSE CAST(main.Refno AS VARCHAR(MAX)) + '|' + CAST(main.TransId AS VARCHAR(MAX)) END,',') AS RefnoMainTransIds
							,('<root>' + STRING_AGG(CAST(main.MainParlayMaxPO AS VARCHAR(MAX)), '') + '</root>') AS MainParlayMaxPO
					FROM	#tmpsubTransID s1
						LEFT JOIN #tmpMainTransId main
							ON s1.refno = main.refno
					WHERE	isFinish IS NULL
					GROUP BY s1.id/@batchNo
				) main
				CROSS APPLY (
					SELECT CAST((SELECT	s2.transid AS 't'	
								,s2.modds AS 'm'
								,s2.refno AS 'r'
								,s2.IsMarked AS 'im'
					FROM	#tmpsubTransID s2         
					WHERE	s2.isFinish IS NULL
							AND s2.id/@batchNo = main.batchNo
					FOR JSON AUTO) AS VARCHAR(MAX)) AS subTransIds
				) sub

			SET @TotalBatch = @TotalBatch + @@ROWCOUNT
			
			IF @TotalBatch > 0
			BEGIN
				IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT_' OR @RunExecParlayDataBySSB = 0
				BEGIN
					SELECT @MessageType = @MessageTypePattern + '1'
		
					EXEC dbo.SSB_ParlaySettlement_UpdateData @ConversationHandle = NULL
						,@MessageType = @MessageType
						,@MessageBody = @SessionId
						,@MessageId = NULL
				END
				ELSE
				BEGIN	
					SET @i = 1
					
					WHILE(1=1)
					BEGIN
						SELECT @MessageType = @MessageTypePattern + CAST(@i AS VARCHAR)
		
						EXEC [dbo].[SSB_Send_Message] @MessageContent = @SessionId
							, @FunctionName = 'parlaysettlement'
							, @MessageType = @MessageType
			
						IF @i = CASE WHEN @TotalBatch > @ExecParlayDataQueueSize THEN @ExecParlayDataQueueSize ELSE @TotalBatch END
							BREAK					

						SET @i = @i + 1
					END
				END
			END
		
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE() 	

	END CATCH		

	IF @IsAuto = 1 AND @Action = 'REFUND' AND @Sporttype <> 1 
		SELECT @ResourceRefund = STRING_AGG(CAST(r.ResourceID AS VARCHAR(MAX)),',')
		FROM @tmpSelectedRID r
	
	IF @ParentMatchId IS NOT NULL 
	BEGIN
		DELETE FROM @tmpSelectedRID
		WHERE ResourceID NOT IN (
			SELECT sp.ResourceID 
			FROM dbo.bettransm bt WITH(NOLOCK)
				INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
					ON (sp.BetID = 0 OR sp.BetID =cast(bt.betcheck AS INT))
						AND sp.BetType = bt.bettype
			WHERE bt.matchid = @MatchID
				AND sp.SportType =50 )

		SET @matchLog = @ParentMatchId
	END
				
	SELECT @ResultRemarkLog = STRING_AGG(ISNULL(RoundName,ResourceID) + 
			CASE WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND AwayValue IS NOT NULL AND AwayValue <> '' THEN '(' + HomeValue + '-' + AwayValue + ')'
					WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND (AwayValue IS NULL OR AwayValue = '') THEN '(' + HomeValue + ')'
					WHEN HomeValue IS NULL AND AwayValue IS NULL THEN ''
					ELSE '' END,',') WITHIN GROUP (ORDER BY OrdNo)
	FROM (
			SELECT DISTINCT ResourceID, HomeValue, AwayValue, RoundName, MAX(OrdNo) AS OrdNo
		  	FROM @tmpSelectedRID sr
			WHERE 1 = CASE WHEN @SportType = 4 AND sr.ResourceId = '01' THEN 0 ELSE 1 END
				AND (sr.IsWeb = 1 OR sr.IsWeb IS NULL)
		  	GROUP BY ResourceID, HomeValue, AwayValue, RoundName
  		) AS tbl1
	
	SELECT @LogData = (
		SELECT	@sporttype	AS '@sporttype'
				,@Action	AS '@Action'
				,@IsAuto	AS '@IsAuto'
				,@start		AS '@StartTime'
				,@ResourceRefund AS '@ResourceRefund'
				,@SelectedResources AS '@SelectedResources'
				,@DeterminedType AS '@DeterminedType'
				,@ParentMatchId AS '@ParentMatchId'
				,@RemarkSDT		AS '@RemarkSDT'
				,@ResultRemarkLog AS '@ResultRemarkLog'
				,CASE WHEN @DeterminedType IN (1,2) THEN NULL ELSE @fth END AS '@fth'
				,CASE WHEN @DeterminedType IN (1,2) THEN NULL ELSE @fta END AS '@fta'
				,@hth AS '@hth'
				,@hta AS '@hta'
				,(SELECT TOP 1 1 FROM @tmpSelectedRID WHERE @sportType = 9 AND @IsAuto = 1 AND @Action = 'CAL' AND ResourceID = '00' AND HomeValue <> AwayValue) AS '@IsAutoRefund'
				,@matchLog AS '@matchLog'
				,@IsReSettledTickets AS '@IsReSettledTickets'
				,@totalSubParlay AS '@totalSubParlay'
				,@creator AS '@creator'
				,@ActionID AS '@ActionID'
				,@IP AS '@IP'
				,@BroadcastSessionId AS '@BroadcastSessionId'
		FOR	XML PATH('r'), ROOT('root'), TYPE)

	SET @CommandMonitor = 'EXEC dbo.NAP_Admin_MonitorParlayProcess @SessionId = ' + CAST(@SessionId AS VARCHAR(50))
						+ ', @MatchId = ' + CAST(@MatchId AS VARCHAR)	
						+ ', @Session = ''' + @Session + ''''
						+ ', @HasError = ' + CAST(@ErrCode AS VARCHAR)
						+ ', @LogData = ' + '''' + CAST(@LogData AS VARCHAR(MAX)) + ''''
						+ ', @IsCentral = ' + CAST(@IsCentral AS VARCHAR)	
						+ ', @LockedByRefno = ' + CAST(@LockedByRefno AS VARCHAR)	
						+ ', @ErrCode = @ErrCode OUTPUT' 
                        + ', @ErrMsg = @ErrMsg OUTPUT'
						+ ', @SSBStatus = @SSBStatus OUTPUT'

	UPDATE	dbo.Parlay_Calculate_Queue 
		SET SSBCommand = @CommandMonitor
			,SSBStatus = 1
	WHERE	keyid = @ParlayKeyId

	IF @@ROWCOUNT = 0
	BEGIN
		SET @CommandMonitor = @CommandMonitor + ', @NeedWaiting = 1' 

		EXEC sys.sp_executesql @CommandMonitor
			, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT, @SSBStatus TINYINT OUTPUT'
			, @ErrMsg	= @ErrMsg	OUTPUT
			, @ErrCode	= @ErrCode	OUTPUT
			, @SSBStatus = @SSBStatus OUTPUT
	END

	IF @ErrCode <> 0 AND @LockedByRefno = 1
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefno = 1
			,@Session	= @Session
			,@IsReleased = 1
	END
END
GO