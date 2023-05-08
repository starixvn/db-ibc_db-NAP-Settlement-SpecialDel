/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile_Parlay]
	 @creator				INT
	,@MatchID				INT
	,@Action		  		VARCHAR(10)		= 'CAL'
	,@IP	 				VARCHAR(15)		= ''
	,@SelectedResources		VARCHAR(MAX)
	,@hth					INT			= 0
	,@hta					INT			= 0
	,@fth					INT			= 0
	,@fta					INT			= 0
	,@IsAuto				BIT			= 0
	,@IsReSettledTickets	BIT			= 1
	,@LockedByRefno			BIT			= 0
	,@IsCentral				BIT			= 0
	,@DeterminedType		TINYINT		= 2
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
			,@ResourceRefund	VARCHAR(100) = ''
						
	DECLARE @MainParlay_MaxPO	VARCHAR(MAX) = NULL

	DECLARE @tmpMainTransIdBatch TABLE (TransId BIGINT, Refno BIGINT)
	DECLARE @tmpSubTransIdBatch TABLE (TransId BIGINT, Refno BIGINT, modds MONEY, IsMarked BIT DEFAULT(0))
	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
		HomeRound TINYINT, AwayRound TINYINT,
		BetType SMALLINT, BetID BIGINT, pfID SMALLINT,SDTpfId SMALLINT
		, OddsType SMALLINT, RoundName VARCHAR(20), OrdNo SMALLINT, IsSDT BIT, SDTResourceId VARCHAR(20), DeterminedType TINYINT DEFAULT(0)
	)

	DECLARE @tmpRefnos TABLE (refno BIGINT)
	DECLARE @tmpResourceAutoRefund TABLE ( ResourceID VARCHAR(20) )
	DECLARE @tmpMarkedTicket TABLE ( MatchId INT , bettype SMALLINT ) ---use for Auto Refund

	DECLARE @tmpParlayDebitPending		TVP_BalanceList
			,@tmpParlayCreditPending	TVP_BalanceList

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpParlayBalanceBefore (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #tmpParlayBalanceAfter (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #tmpParlayBalance (custid int, balance money)	
	CREATE TABLE #tmpMainTransId ( transid BIGINT, refno BIGINT, IsFinished BIT, ruben TINYINT, custid INT)
	DECLARE @tmpValidResources TABLE (ResourceID VARCHAR(20))
	--END Balance tables

	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	CREATE TABLE #tmpsubTransID (TransID BIGINT, refno BIGINT, modds SMALLMONEY, IsSDT BIT DEFAULT(0), isFinish BIT, IsMarked BIT DEFAULT(0))
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
				,ISNULL(Home,'') AS HomeValue
				,ISNULL(Away,'') AS AwayValue
				,ISNULL(IsSDT,0) AS IsSDT
				,ISNULL(HomeRound,'') AS HomeRound
				,ISNULL(AwayRound,'') AS AwayRound
				,ISNULL(DeterminedType,'') AS DeterminedType
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,RefResourceId VARCHAR(20)
															,SDTResourceId VARCHAR(20)
															,Bettype SMALLINT
															,pfId INT															
															,Home VARCHAR(50)
															,Away VARCHAR(50)
															,IsSDT BIT
															,HomeRound TINYINT
															,AwayRound TINYINT
															,DeterminedType TINYINT
											) AS tbl
	)
	INSERT INTO @tmpSelectedRID (ResourceID, SDTResourceId, Bettype, BetId, pfId, SDTpfId, OddsType, HomeValue, AwayValue, OrdNo, RoundName, IsSDT, HomeRound, AwayRound, DeterminedType)
	SELECT	 c.Id
			,c.SDTResourceId
			,sp.Bettype
			,sp.BetId
			,sp.pfId
			,sp.SDTpfId
			,sp.OddsType
			,c.HomeValue
			,c.AwayValue
			,sp.OrdNo
			,sd.RoundName
			,c.IsSDT
			,c.HomeRound
			,c.AwayRound
			,c.DeterminedType
	FROM	cteSelectedRID c
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			ON	 sp.ResourceID = c.Id
					AND sp.BetType = c.Bettype
		LEFT JOIN dbo.f_Set_MajorRound(@Sporttype) sd 
			ON	ISNULL(sp.RefResourceId,sp.ResourceID) = sd.ResourceID
	WHERE	sp.SportType = @Sporttype
			
	EXEC sp_xml_removedocument @handle

  	--get transid
  	IF @Action LIKE 'CAL%'
  	BEGIN
		IF @sportType = 1 AND @Action <> 'CAL_EAR'
		BEGIN
			INSERT INTO #tmpsubTransID (TransID, modds, refno, IsMarked)
			SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
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
				SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
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
						--AND bm.statusID IN (0,102)
						AND m.modds IS NOT NULL
						AND ((bm.statusId = 0 AND ISNULL(bm.SecAcceptFlag,0)=0)
							OR (bm.statusID = 0 AND bm.SecAcceptFlag=1 AND ISNULL(bm.checktime,CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
							OR bm.statusID = 102
						)
						and 1 = case 
								when sr.SDTpfId = 3 then case when (@hth + @hta) - 0.25 > bm.hdp1 then 1 else 0 end
								when sr.SDTpfId = 388 then case when @fta - 0.25 > bm.hdp1 then 1 else 0 end
								when sr.SDTpfId = 389 then case when @fth - 0.25 > bm.hdp1 then 1 else 0 end
								else 1
							end

				SET @totalSubParlay = @totalSubParlay + @@ROWCOUNT
			END
			
		END
		ELSE
		BEGIN
			INSERT INTO #tmpsubTransID (TransID, modds, refno, IsMarked)
			SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
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
	END
	ELSE IF @action LIKE 'UNDO%'
	BEGIN
		INSERT INTO #tmpsubTransID (TransID, refno, IsMarked)
		SELECT	bm.transid, bm.refno , CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked 
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
			SELECT	bm.transid, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked 
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
					AND bm.statusId IN (112, 113)
					AND (m.modds IS NULL 
						OR bm.statusId <> CASE
											WHEN m.modds >= 0.5 THEN 112
											WHEN m.modds <= -0.5 THEN 113
											ELSE NULL
										END 
						)

			SET @totalSubParlay = @totalSubParlay + @@ROWCOUNT
		END
	END 
	ELSE IF @action LIKE 'REFUND%' 
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
	
		IF EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID WHERE IsSDT = 1) 
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
	
	BEGIN TRY
		-- settle sub parlay
		WHILE(1=1)
		BEGIN
			SET @subAction = @Action
			DELETE @tmpSubTransIdBatch
			
			IF @IsSDT = 1
			BEGIN
				UPDATE TOP(@batchNo) t
					SET isFinish = 1
				OUTPUT	deleted.transid, deleted.modds, deleted.refno, deleted.IsMarked
					INTO @tmpSubTransIdBatch(transid, modds, refno, IsMarked)
				FROM	#tmpsubTransID t
				WHERE	IsSDT = 1
						AND isFinish IS NULL

				IF @@ROWCOUNT = 0
				BEGIN
					SET @IsSDT = 0

					CONTINUE 
				END
				
				SET @subAction = 'CAL'
			END
			ELSE
			BEGIN
				
				UPDATE TOP(@batchNo) t
					SET isFinish = 1
				OUTPUT	deleted.transid, deleted.modds, deleted.refno, deleted.IsMarked
					INTO @tmpSubTransIdBatch(transid, modds, refno, IsMarked)
				FROM	#tmpsubTransID t
				WHERE	isFinish IS NULL
				
				IF @@ROWCOUNT = 0
					BREAK
					
			END
		
			--filter selectedRID by current Profile and BetType
			SET @strTransIds 		= (SELECT transid	AS '@t'
												,modds	AS '@m'
												,refno   AS '@r'
												,IsMarked AS '@im'
										FROM @tmpSubTransIdBatch
										FOR XML PATH('b'))
		
			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchid	  		 = @matchid
				,@matchdate			 = @eventdate
				,@mode				 = 'profile'
				,@Action			 = @subAction
				,@strTransIds		 = @strTransIds

		END
		
		-- settle main parlay			
		INSERT INTO @tmpRefnos (refno)
		SELECT	t.refno
		FROM	#tmpsubTransID t
		WHERE	NOT EXISTS (SELECT TOP 1 1 
							FROM	dbo.bettransm bm WITH(NOLOCK) 
							WHERE	bm.refno = t.refno 
									AND bm.statusID IN (1,101)
						)
		
		INSERT INTO #tmpMainTransId (transid, refno, IsFinished, ruben, custid)
		SELECT	transid, refno, 0 AS IsFinished, ruben, custid
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = 29
				AND b.statusID NOT IN (101,102) --('VOID','REJECT')
				AND refno IN (SELECT refno FROM @tmpRefnos)
			
		SET @totalMainParlay = @@ROWCOUNT -- number of system parlay ticket

		IF @totalMainParlay > 0 -- got system parlay tickets
		BEGIN
			SET @strMainTransIds = STUFF((
				SELECT ',' + cast(transid as varchar(20))
				FROM	#tmpMainTransId
				FOR XML PATH('')
			), 1,1,'')

			INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
			VALUES (@matchid, @totalMainParlay, CURRENT_TIMESTAMP, NULL, 'Start running PRECAL-29')
			

			-- handle betParlayDetail, betParlayResult
			EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchid
				,@mode = 'PRECAL-29'
				,@matchdate = @eventdate
				,@strXML = @strMainTransIds
				,@IsReSettledTickets = @IsReSettledTickets

			INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
			VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'Start running CAL-29')

			
			--Prepare for Max Payout
			SELECT @MainParlay_MaxPO = (SELECT t.CustId AS '@custid'
										,t.ruben AS '@ruben'
										,t.TransId AS '@transid'
									FROM #tmpMainTransId t
									FOR XML PATH('r'), ROOT('root')
								)
			-- update summary info back to bettrans
			WHILE (1=1)
			BEGIN
				DELETE @tmpMainTransIdBatch
				TRUNCATE TABLE #tmpParlayBalanceBefore
				TRUNCATE TABLE #tmpParlayBalanceAfter

				SET @strMainTransIdRefnos = ''

				UPDATE TOP (800) #tmpMainTransId
					SET IsFinished = 1
				OUTPUT INSERTED.refno, INSERTED.transid INTO @tmpMainTransIdBatch (refno, transid)
				WHERE IsFinished = 0

				IF @@rowcount = 0
					BREAK

				SELECT @strMainTransIdRefnos = @strMainTransIdRefnos + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
				FROM	@tmpMainTransIdBatch

				SET @strMainTransIdRefnos = STUFF(@strMainTransIdRefnos,1,1,'')

				---- CAPTURE value BALANCE before udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
				INSERT INTO #tmpParlayBalanceBefore (transid, custid, balance)
				SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	dbo.bettrans b WITH(ROWLOCK)
				WHERE	b.transid IN (SELECT transid FROM @tmpMainTransIdBatch)

				EXEC dbo.NAP_Admin_Calculate_MP_broker
					@mode = '29'
					,@matchdate = @eventdate
					,@strXML = @strMainTransIdRefnos

				---- CAPTURE value BALANCE after udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
				INSERT INTO #tmpParlayBalanceAfter (transid, custid, balance)
				SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	dbo.bettrans b WITH(ROWLOCK)
				WHERE	b.transid IN (SELECT transid FROM @tmpMainTransIdBatch)

				INSERT INTO #tmpParlayBalance (custid, balance)
				SELECT b.custid, SUM(a.balance - b.balance)
				FROM #tmpParlayBalanceBefore b
					INNER JOIN #tmpParlayBalanceAfter a ON b.transid = a.transid
				GROUP BY b.custid
			END

			--Insert Max Payout Queue
			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
				@MatchId= 29
				,@TransidList = @MainParlay_MaxPO
		END
	END TRY
	BEGIN CATCH
		INSERT INTO #tmpParlayBalanceAfter (transid, custid, balance)
		SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM	dbo.bettrans b WITH(ROWLOCK)
		WHERE	b.transid IN (SELECT transid FROM @tmpMainTransIdBatch)

		INSERT INTO #tmpParlayBalance (custid, balance)
		SELECT b.custid, SUM(a.balance - b.balance)
		FROM #tmpParlayBalanceBefore b
			INNER JOIN #tmpParlayBalanceAfter a ON b.transid = a.transid
		GROUP BY b.custid

		--Insert Max Payout Queue
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
		
		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE() 

	END CATCH

	INSERT INTO @tmpParlayDebitPending (custID, balance)
	SELECT t.custid, ABS(t.balance)
	FROM (
		SELECT	custID, SUM(balance) AS balance
		FROM	#tmpParlayBalance
		GROUP BY custID
	) t
	WHERE t.balance < 0

	IF @@ROWCOUNT <> 0
		EXEC dbo.Dot_BalancePendingDebitIns
			@BalancePending = @tmpParlayDebitPending
			,@Type			= 1 -- Sports

	INSERT INTO @tmpParlayCreditPending (custID, balance)
	SELECT t.custid, ABS(t.balance)
	FROM (
		SELECT	custID, SUM(balance) AS balance
		FROM	#tmpParlayBalance
		GROUP BY custID
	) t
	WHERE t.balance > 0

	IF @@ROWCOUNT <> 0
		EXEC dbo.Dot_BalancePendingCreditIns
			@BalancePending = @tmpParlayCreditPending
			,@Type			= 1 -- Sports
			
	----
	-- Add Negative Balance into BalanceNegative table
	----
	INSERT INTO [bodb02].[dbo].[BalanceNegative] ([ExecDate], [MatchID], [ActionID], [GroupID], [CustID], [Balance], [StatusID], [Remark])
	SELECT GETDATE()
		,@MatchID
		,CASE 
			WHEN @Action LIKE 'UNDO%' THEN 105
			WHEN @Action = 'REFUND-HT' THEN 120
			WHEN @Action = 'REFUND-FT' THEN 106
			WHEN @Action LIKE 'REFUND%' THEN 107
			ELSE 104 -- CAL
		END
		,2 -- Sportsbook Parlay Settlement
		,t.CustID
		,t.Balance
		,0
		,@matchid
	FROM (	SELECT	custID, SUM(balance) AS balance
			FROM	#tmpParlayBalance
			GROUP BY custID) t
	WHERE t.balance < 0

	INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
	VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'END running CAL-29')

	----------------------------------- releasing Settlement process--------------------------------------------
	IF @LockedByRefno = 1
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefno = 1
			,@Session	= @Session
			,@IsReleased = 1
	END

	IF @ErrCode <> 0
		RETURN
	
	
	IF @IsAuto = 1 AND @Action = 'REFUND'
	BEGIN
		IF  @sportType = 1
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefund_ResultUpd
				@MatchId = @matchid 
				, @TypeId  = 10
				, @StatusId = 2
		END
		
		ELSE
		BEGIN
			SELECT @ResourceRefund = @ResourceRefund + ',' + r.ResourceID FROM @tmpSelectedRID r
			
			EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefundOS_ResultUpd
					@MatchId = @matchid
					, @StatusId = 2
					, @ResourceIds  = @ResourceRefund
		END
	END

	--Auto refund Badminton after calculate parlay by Auto Service
	IF EXISTS ( SELECT TOP 1 1 FROM @tmpSelectedRID WHERE @sportType = 9 AND @IsAuto = 1 AND @Action = 'CAL' AND ResourceID = '00' AND HomeValue <> AwayValue )
	BEGIN
		EXEC dbo.NAP_Set_GetRefundResult
				@MatchId		= @MatchID
				,@Sporttype		= @sportType
				,@CalculateResources= @SelectedResources
				,@ResourceRefund = @ResourceRefund OUTPUT

		IF ISNULL(@ResourceRefund, '')  <> ''
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefundOS_ResultIns
				@MatchId		 = @MatchID
				,@ResourceIds	 = @ResourceRefund
		END
END
	
	-- Write log
	DECLARE @ResultRemarkLog VARCHAR(MAX) = ''
			,@logdata		VARCHAR(MAX) = ''
			,@Remark		VARCHAR(MAX) = ''
			,@matchLog		INT = @matchid

	IF @ParentMatchId IS NOT NULL 
	BEGIN
		DELETE FROM @tmpSelectedRID
		WHERE ResourceID NOT IN (
			SELECT sp.ResourceID 
			FROM dbo.bettrans bt WITH(NOLOCK)
				INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
					ON (sp.BetID = 0 OR sp.BetID =bt.betid)
						AND sp.BetType = bt.bettype
			WHERE bt.matchid = @MatchID
				AND sp.SportType =50 )

		SET @matchLog = @ParentMatchId
	END

	INSERT INTO @tmpValidResources(ResourceID)
	SELECT DISTINCT ResourceID 
	FROM SettlementSpecialBettypeProfile AS p WITH(NOLOCK)
	WHERE p.SportType = @sportType
		AND EXISTS (SELECT 1 
					FROM SportBettypeMatrix AS m WITH(NOLOCK) 
					WHERE p.SportType = m.SportType 
						AND p.BetType = m.BetType  
						AND m.Enabled = 1)

	SELECT @ResultRemarkLog = @ResultRemarkLog + ',' +  ISNULL(RoundName,ResourceID) + 
			CASE WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND AwayValue IS NOT NULL AND AwayValue <> '' THEN '(' + HomeValue + '-' + AwayValue + ')'
					WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND (AwayValue IS NULL OR AwayValue = '') THEN '(' + HomeValue + ')'
					WHEN HomeValue IS NULL AND AwayValue IS NULL THEN ''
					ELSE '' END
	FROM (
			SELECT DISTINCT ResourceID, HomeValue, AwayValue, RoundName, MAX(OrdNo) AS OrdNo
		  	FROM @tmpSelectedRID sr
			WHERE sr.ResourceID	IN (SELECT vr.ResourceID FROM @tmpValidResources AS vr)
		  	GROUP BY ResourceID, HomeValue, AwayValue, RoundName
  		) AS tbl1
	ORDER BY OrdNo

	IF @ParentMatchId IS NOT NULL -- Child match Cricket
		SELECT @ResultRemarkLog =  'child: ' + CAST(@matchid AS VARCHAR)  
									+ CASE WHEN @Action LIKE 'CAL%' THEN ' Result:' 
										ELSE ' Selected:' 
									END 
									+ SUBSTRING(@ResultRemarkLog, 2, LEN(@ResultRemarkLog))
	ELSE
		SELECT @ResultRemarkLog =  CASE WHEN @Action LIKE 'CAL%' THEN 'Result:' ELSE 'Selected:' END + SUBSTRING(@ResultRemarkLog, 2, LEN(@ResultRemarkLog))
	
	SET @stop = CURRENT_TIMESTAMP

	SELECT @logdata = 'NAP: Calculate Parlay (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10))
							+ CASE WHEN @DeterminedType = 2 THEN ' SDT-FT:1' ELSE '' END
							+ CASE WHEN @sportType <> 1 THEN ' Result: ' + @SelectedResources + '<br/> ' ELSE '' END
							+ '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
						   
	EXEC dbo.Logfile_V2 
		@UserID = @creator
		,@Doing = @logdata
		,@extend = @MatchId
	
	IF @IsCentral = 1
	BEGIN
		SELECT @Remark = CASE WHEN @sportType <> 1 THEN @ResultRemarkLog + '<br/> '  ELSE '' END
							+ CASE WHEN @DeterminedType = 2 THEN 'SDT-FT:1' ELSE '' END
							+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
							+ CASE WHEN @Action LIKE 'CAL%' THEN '; Recalc: ' + CAST (ISNULL(@IsReSettledTickets,0) AS VARCHAR(1)) ELSE '' END
							+ '; TC:' + CAST(ISNULL(@totalSubParlay, 0) AS VARCHAR(20)) 
						
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				,@Matchid = @matchLog
				,@ActionID = @ActionID				
				,@Remark = @Remark
				,@IP = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				,@Matchid = @matchLog
				,@ActionID = @ActionID				
				,@Remark = @Remark
				,@IP = @IP
		END CATCH
	END

	--END: WRITE LOG ---------------------------------- 
END
GO