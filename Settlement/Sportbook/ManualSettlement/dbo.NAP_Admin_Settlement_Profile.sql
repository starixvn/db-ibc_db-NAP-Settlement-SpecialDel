	/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Casino" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile]
	 @creator			INT
	,@MatchID			INT
	,@Action		  	VARCHAR(10)		= 'CAL'
	,@IP	 			VARCHAR(15)		= ''
	,@ErrCode			INT				= 0	OUTPUT
	,@ErrMsg 			NVARCHAR(200)	= '' OUTPUT
	,@SelectedResources VARCHAR(MAX)
	,@IsReSettledTickets BIT			= 1
	,@IsAuto			BIT				= 0
	,@BetStatus			NVARCHAR(50)	= NULL
	,@IsLeader			BIT				= 0
	,@IsDirectly		BIT				= 0 --- Apply for Basketball, Tennis, Badminton, E-Sports, Beach Volleyball
	,@ChildMatchIds		VARCHAR(500)	= NULL
	,@RefResultStatus	TINYINT			= 0
	,@BroadcastSessionId	VARCHAR(50)	= NULL
AS
/*  Creator: 20180821@Vicky
	Task: Settlement for sport in profile
	DB: DBTXN/BODB02

	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190301@Sol:  New Formula for Comm [Redmine:#109007]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20190924@Sol: Incorporate BMAIO - modified sp to add oddstype [Redmine:#120324]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Add new param @IsReSettledTickets - [Redmine:#127698]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200515@Kathy: Settlement Exclusion [Redmine:#134103]
		- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20200728@Kathy: update htscore for basketball when HT is done [Redmine:#135846]
		- 20200804@Kathy: Add new param to indicate calculation action by leader or not for Esport [Redmine:#136931]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201113@Louisa: Check Hold Result [Redmine:#135097]
		- 20210219@Louisa: Update match_remark when calculate HT for Basketball [Redmine:#150328]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20210305@Louisa: SOP for Tennis [Readmine:#150425]
		- 20210506@Louisa: SOP for Cricket [Redmine:#153915]
		- 20210514@Kathy: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20210517@Louisa: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155361]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210804@Helen: Support Cashout for Basketball [Redmine:#159617]
		- 20210811@Louisa: SOP Refund for Tennis, E-Sports [Redmine:#159270]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210922@Louisa: Remove @CutOffDate [Redmine:#159903]
		- 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
		- 20211025@Louisa: SOP Refund for Badminton, Basketball, Cricket [Redmine:#163574]
		- 20211027@Kathy: Apply all bettype for pingoal [Redmine:#163762]
		- 20211129@Kathy: Extend datatype of table SettlementBettypeResult [Redmine:#165300]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220126@Kathy: Settlement - Incorporate Saba Basketball PinGoal [Redmine:#167926]
		- 20220128@Kathy: Cricket AIO Phase 2 [Redmine:#166335]
		- 20220309@Kathy: Remove code savebet, old Cashout model [Redmine:#169643]
		- 20220309@Louisa: Auto settle Volleyball [Redmine:#168346]
		- 20220414@Louisa: write log for @RefResultStatus [Redmine:#169958]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220512@Louisa: Auto settle and Auto refund Badminton [Redmine:#171676]
		- 20220629@Louisa: Volleyball AIO [Redmineid:#173862]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20220922@Kathy: Scale Out BetTrans - fixbug [Redmine:#175251]
		- 20221006@Louisa: Always insert BroacastSessionId into TicketVoiding_AutoVoidRequest_Queue [Redmine:#178830]
		- 20221010@louisa: not insert [TicketVoiding_AutoVoidRequest_Queue] if BroacastSessionId null [Redmine:#178830]
		
	Param's Explanation:
		* @SelectedResources= '<Resources>
									<Resource Id="M1" Home="1" Away="3" />
									<Resource Id="M2" Home="2" Away="4" />
							   </Resources>'

		* @RefResultStatus ( detect by Web )
				 1: no reference result exist (result not yet confirmed or not exists Provider score)
				 2: values inconsistency
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SkipBalanceUpdate  BIT
			,@start				DATETIME
			,@stop				DATETIME
			,@fth				INT
			,@fta				INT
			,@hth				INT
			,@hta				INT
			,@ActionID			INT
			,@Remark			VARCHAR(500)
			,@LogData			NVARCHAR(300)
			,@avaiableProcess	BIT
			,@xml				XML
			,@strResourceIds	VARCHAR(MAX)
			,@sportType 		INT
			,@existsFinalRound	BIT
			,@existsHTRound		BIT
			,@ticketCount		INT				= 0
			,@handle			INT
			,@TotalAccount		INT
			,@TotalAccount_BalanceUpdate INT
			,@batchNo			INT 			= 2000
			,@batchCount		INT		
			,@strTransIds		VARCHAR(MAX)	= ''
			,@ResultRemarkLog	VARCHAR(MAX)	= ''
			,@SelectedRID		VARCHAR(MAX)	= ''
			,@TotalPointHomeValue VARCHAR(50)		= NULL
			,@TotalPointAwayValue VARCHAR(50)		= NULL
			,@DummyResourceIds		VARCHAR(MAX) = ''
			,@DummyResourceResults VARCHAR(MAX) = ''
			,@IsEarly				BIT
			,@ParentMatchId		INT
			,@procName			SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime		VARCHAR(10)
			,@IsWaiting			BIT = 0
			,@LeagueGroupID		SMALLINT = 0
			,@matchLog			INT 
			,@IsMergedParlay	BIT = 0
			,@SelectedResourceParlay VARCHAR(MAX) = ''
			,@sqlCommand VARCHAR(MAX) = ''
			-- for cashout
			,@Action_tmp	VARCHAR(10)
			,@TotalSubParlay	INT = 0
			,@ThreadHold		INT = 0
			,@LockedByRefno		BIT = 0
			,@ResourceRefund	VARCHAR(100) = ''
			,@IsCentral			BIT = 0	
			
  	--START Balance tables
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		   , @BalanceWalletAfter		TVP_BalanceWalletChange
	--END Balance tables

	DECLARE @tmpCashoutTransId AS TABLE (TransId BIGINT, winlost MONEY, statuswinlost TINYINT, currentstatuswinlost TINYINT)

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, isFinish BIT, srecommend INT, bettype SMALLINT, IsMarked	BIT, BetdaqId BIGINT, DeadHeat TINYINT, currentStatuswinlost TINYINT)

	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, srecommend INT, bettype SMALLINT, IsMarked	BIT, winlost MONEY, statuswinlost TINYINT, DeadHeat TINYINT)
	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
								  BetType SMALLINT, BetID BIGINT, pfID SMALLINT, RoundID VARCHAR(10), OrdNo SMALLINT,
								  isFinal BIT, RoundName VARCHAR(20), GroupType VARCHAR(2), OddsType SMALLINT, RefResourceId VARCHAR(20)
								  ,PRIMARY KEY (BetType,BetID))
	DECLARE @tmpResourcesWeb TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000))
	DECLARE @tmpGetLog TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000), BetType SMALLINT, BetID BIGINT, OrdNo SMALLINT, RoundName VARCHAR(20) )
	
	-- for cashout
	DECLARE @strBettypes VARCHAR(MAX) = '', @mode VARCHAR(20) = ''
	----------------------------------------------------------------------------------------------------------------------

	-- Check SP is in deployment
	IF @IsAuto = 1
	BEGIN
		EXEC dbo.NAP_Set_SPDeploymentInfo 
			@SPName = @procName
			,@WaitingTime = @WaitingTime OUTPUT
			,@IsWaiting = @IsWaiting OUTPUT

		IF @IsWaiting = 1
		BEGIN
			WAITFOR DELAY @WaitingTime
			
			SELECT	@ErrCode = 99
					,@ErrMsg = 'Failed due to system is in deployment, please wait a few seconds until the process is completed and try again.'

			RETURN
		END
	END

  	SELECT  @start = CURRENT_TIMESTAMP
		   ,@ActionID = CASE
						  WHEN @Action = 'CAL' THEN 100
						  WHEN @Action = 'UNDO' THEN 103
						  WHEN @Action = 'REFUND' THEN 109
						  WHEN @Action = 'CAL_EAR' THEN 189
						  WHEN @Action = 'UNDO_EAR' THEN 190
						  WHEN @Action = 'REFUND_EAR' THEN 191
						  ELSE 0
					   END
		   ,@SkipBalanceUpdate	 = 0
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

  	--get info of match
  	SELECT @fth			= m.finalhomescore
		  ,@fta			= m.finalawayscore
		  ,@hth			= m.hthomescore
		  ,@hta			= m.htawayscore
		  ,@sportType	= m.sportType
		  ,@ParentMatchId = CASE WHEN m.ChildMatchType = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN m.ParentID ELSE NULL END
		  ,@LeagueGroupID = ISNULL(l.LeagueGroupID, 0)
  	FROM	DBPRO.BODB02.dbo.match m WITH (NOLOCK)
		INNER JOIN DBPRO.BODB02.dbo.League l WITH(NOLOCK)  ON m.leagueid = l.leagueid
  	WHERE   m.matchid = @matchid

	SELECT @IsEarly =  CASE WHEN @Action LIKE '%EAR'  OR (@sportType = 50 AND @IsAuto = 1) THEN 1 ELSE 0 END

	SELECT	@IsMergedParlay = IsMergedParlay
	FROM	dbo.SettlementResultTableSetting ss WITH(NOLOCK)
	WHERE ss.Sporttype = @sportType

  	-- check and not allow attempt to settlement same game while it's still not finish
	-- This is used in NAP_Admin_CheckingProcess sp
  	INSERT INTO #tblMatchProcess(matchid, KeyID)
  	SELECT	@matchid AS matchid ,1 AS KeyId
  	----------------------------------------------------------------------------------------------------------------------

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @MatchId
	,@SelectedResources = @SelectedResources
	,@IsEarly	= @IsEarly
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
	    SELECT	@ErrCode
				,@ErrMsg    
	    RETURN
	END

	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch			= 1
		  , @SPName				= @procName
		  , @avaiableProcess 	= @avaiableProcess OUTPUT
		  , @ErrCode			= @ErrCode OUTPUT
		  , @ErrMsg				= @ErrMsg OUTPUT

	--check error
	IF(@ErrCode <> 0 OR @avaiableProcess = 0)
	BEGIN
		SELECT   @ErrCode   = 1000000
				,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END
  	
	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
	SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
	EXEC sp_xml_removedocument @handle

	IF @Action LIKE 'REFUND%'
	BEGIN
		DECLARE @ResourceIds VARCHAR(MAX) = ''

		SELECT @ResourceIds = @ResourceIds + ResourceID + ','
		FROM	@tmpResourcesWeb

		EXEC dbo.NAP_Set_EarlySettlement_CheckingMarkedTransaction
			@MatchID = @MatchID
			,@IsMergedParlay = @IsMergedParlay
			,@ResourceIds = @ResourceIds
			,@ErrCode = @ErrCode OUTPUT
			,@ErrMsg = @ErrMsg OUTPUT

		IF @ErrCode <> 0
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch		= 1
				, @IsReleased		= 1
			
			RETURN
		END
	END
	-------------BEGIN TRY------------------------------------------
	BEGIN TRY
		-----------------------------------------add more info-----------------------------------------
		SELECT	@DummyResourceIds = @DummyResourceIds + s.ResourceID + ','
		FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			INNER JOIN @tmpResourcesWeb t
				ON s.RefResourceId = t.ResourceID
		WHERE	s.SportType = @sportType
				AND s.RefResourceId IS NOT NULL
				AND 1 = CASE WHEN @LeagueGroupID = 113 AND @sportType = 1 THEN 0
						ELSE 1 END
		
		IF @DummyResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@WebResourceResult = @SelectedResources
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
																,Home VARCHAR(2000)
																,Away VARCHAR(2000)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END

		-- Tennis
		IF (@sportType = 5) AND Exists (SELECT 1 FROM @tmpResourcesWeb WHERE ResourceID = '00')
		BEGIN
			SELECT  @TotalPointHomeValue = CAST(SUM(CAST(HomeValue AS INT)) AS VARCHAR(50)), 
					@TotalPointAwayValue = CAST(SUM(CAST(AwayValue AS INT)) AS VARCHAR(50))
			FROM 
				(
					SELECT	ResourceID, HomeValue, AwayValue
					FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(ROWLOCK)
					WHERE	MatchID = @MatchID 
							AND ResourceID IN ('01','02','03','04','05')
							AND SettlementStatusID = 4
							AND ResultStatusID = 5
				) t
		END
		
		INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID, RoundID, OrdNo, isFinal, RoundName, GroupType, OddsType, RefResourceId)
		SELECT DISTINCT tbl.ResourceID, 
				CASE WHEN sp.BetType = 153 THEN ISNULL(@TotalPointHomeValue, '') ELSE ISNULL(HomeValue,'') END, 
				CASE WHEN sp.BetType = 153 THEN ISNULL(@TotalPointAwayValue, '') ELSE ISNULL(AwayValue,'') END, 
				sp.BetType, sp.BetID, sp.pfID, sp.RoundID, sp.OrdNo, 
				sd.isFinal, 
				sd.RoundName, 
				sp.GroupType, sp.OddsType,
				sp.RefResourceId
		FROM @tmpResourcesWeb tbl
			INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.ResourceID
			OUTER APPLY (
				SELECT	sd.RoundName, sd.isFinal
				FROM	dbo.f_Set_MajorRound(sp.SportType) sd
				WHERE	sd.ResourceID = ISNULL(sp.RefResourceId,sp.ResourceID)
			)sd
		WHERE	sp.SportType = @SportType
		-----------------------------------------------------END parse XML----------------------------------------------------------------------
		SELECT   @SelectedRID   = (SELECT Bettype   AS '@bt'
											 ,BetID	AS '@b'
									  FROM @tmpSelectedRID
									  FOR XML PATH('r'), ROOT( 'root' ))

  		--get transid
  		IF @Action LIKE 'CAL%'
  		BEGIN
			--Bettype 2,3: using match score or total point
			UPDATE t
				SET HomeValue = CASE WHEN ISNULL(@TotalPointHomeValue, '') <> '' THEN @TotalPointHomeValue ELSE HomeValue END,
					AwayValue = CASE WHEN ISNULL(@TotalPointAwayValue, '') <> '' THEN @TotalPointAwayValue ELSE AwayValue END
			FROM @tmpSelectedRID t
			WHERE t.BetType IN (2, 3) AND @sportType = 5

			IF @sportType <> 1
			BEGIN
				INSERT INTO #tmpTransID(TransID, modds, OddsType, srecommend, bettype, IsMarked, BetdaqId, DeadHeat, currentStatuswinlost)
	  			SELECT 
					b.transid, m.modds
					, sr.OddsType
					, b.srecommend, b.bettype, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
					,ISNULL(b.betdaqid,0)
					,m.DeadHeat
					,b.statuswinlost
	  			FROM bettrans b WITH (NOLOCK)
					OUTER APPLY (
									SELECT TOP (1) mt.TransId
									FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
									WHERE	mt.TransId = b.transId
					) mt
	  				CROSS APPLY(
	  								SELECT TOP 1 pfID, HomeValue, AwayValue, t.OddsType
	  								FROM @tmpSelectedRID t
	  								WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  							) sr
	  				CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, NULL) m
	  			WHERE b.matchid = @MatchId
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  				AND b.statusID NOT IN (101)
					AND 1 = CASE 
								WHEN ISNULL(b.betdaqid,0) = -2 THEN 1
								WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								WHEN @IsReSettledTickets = 1 THEN 1
								ELSE 0
							END

				DELETE 
				FROM	#tmpTransID
					OUTPUT deleted.TransID
						, CASE 
							WHEN deleted.modds > 0.25 THEN 2
							WHEN deleted.modds = 0.25 THEN 1
							WHEN deleted.modds = 0 THEN 0
							WHEN deleted.modds = -0.25 THEN 3
							ELSE 4
						END
						, deleted.currentStatuswinlost
					INTO @tmpCashoutTransId(TransId, statuswinlost, currentstatuswinlost)
				WHERE	BetdaqId = -2
			END
			ELSE
			BEGIN
				INSERT INTO #tmpTransID(TransID, modds, OddsType, srecommend, bettype, IsMarked, BetdaqId, currentStatuswinlost)
	  			SELECT 
					b.transid, m.modds
					, sr.OddsType
					, b.srecommend, b.bettype, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
					,ISNULL(b.betdaqid,0)
					,b.statuswinlost
	  			FROM bettrans b WITH (NOLOCK)
					OUTER APPLY (
									SELECT TOP (1) mt.TransId
									FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
									WHERE	mt.TransId = b.transId
					) mt
	  				CROSS APPLY(
	  								SELECT TOP 1 pfID, HomeValue, AwayValue, t.OddsType
	  								FROM @tmpSelectedRID t
	  								WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  							) sr
	  				CROSS APPLY dbo.f_Set_Calculate_modds_major(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, NULL) m
	  			WHERE b.matchid = @MatchId
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  				AND b.statusID NOT IN (101)
					AND 1 = CASE 
								WHEN ISNULL(b.betdaqid,0) = -2 THEN 1
								WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								WHEN @IsReSettledTickets = 1 THEN 1
								ELSE 0
							END
				
				DELETE 
				FROM	#tmpTransID
					OUTPUT deleted.TransID
						, CASE 
							WHEN deleted.modds > 0.25 THEN 2
							WHEN deleted.modds = 0.25 THEN 1
							WHEN deleted.modds = 0 THEN 0
							WHEN deleted.modds = -0.25 THEN 3
							ELSE 4
						END
						, deleted.currentStatuswinlost
					INTO @tmpCashoutTransId(TransId, statuswinlost, currentstatuswinlost)
				WHERE	BetdaqId = -2
			END
			
			IF @IsMergedParlay = 1
				SELECT @TotalSubParlay = COUNT(1)			
				FROM	dbo.bettransm bm WITH(NOLOCK)
				WHERE	bm.matchid = @MatchID
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND bm.statusID NOT IN (101)
						AND 1 = CASE 
									WHEN @IsReSettledTickets = 0 AND bm.statusID IN (0,102) THEN 1
									WHEN @IsReSettledTickets = 1 THEN 1
									ELSE 0
								END
						AND EXISTS (SELECT	TOP 1 1
									FROM	@tmpSelectedRID t
									WHERE	t.BetType = bm.bettype
											AND (t.BetID = 0 OR t.BetID = bm.betcheck))
		END
		ELSE IF @action LIKE 'UNDO%'
		BEGIN
			--get transid
			INSERT INTO #tmpTransID(TransID, BetdaqId, currentStatuswinlost)
	  		SELECT b.transid, ISNULL(b.betdaqid,0), b.statuswinlost
	  		FROM bettrans b WITH (NOLOCK)
	  			INNER JOIN @tmpSelectedRID t ON b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID)
				OUTER APPLY (
					SELECT	TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
				) mt
	  		WHERE b.matchid = @MatchId	
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  			AND	b.statusID NOT IN (101)
				AND 1 = CASE WHEN b.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
							 WHEN b.statusID NOT IN (0, 1) THEN 1
							 ELSE 0 
						END
			
			DELETE 
			FROM	#tmpTransID
				OUTPUT deleted.TransID, NULL, deleted.currentStatuswinlost INTO @tmpCashoutTransId(TransId, statuswinlost, currentstatuswinlost)
			WHERE	BetdaqId = -2

			IF @IsMergedParlay = 1					
				SELECT @TotalSubParlay = COUNT(1)			
				FROM	dbo.bettransm bm WITH(NOLOCK)
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
						AND EXISTS (SELECT	TOP 1 1
									FROM	@tmpSelectedRID t
									WHERE	t.BetType = bm.bettype
											AND (t.BetID = 0 OR t.BetID = bm.betcheck))
		END 
		ELSE IF @action LIKE 'REFUND%'
		BEGIN
			--get transid
			INSERT INTO #tmpTransID(TransID, BetdaqId, currentStatuswinlost)
	  		SELECT transid, ISNULL(b.betdaqid,0), b.statuswinlost
	  		FROM bettrans b WITH (NOLOCK)
	  			INNER JOIN @tmpSelectedRID t ON b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  		WHERE b.matchid = @MatchId
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  			AND	b.statusID NOT IN (103, 101)
			
			DELETE 
			FROM	#tmpTransID
				OUTPUT deleted.TransID, 6, deleted.currentStatuswinlost INTO @tmpCashoutTransId(TransId, statuswinlost, currentstatuswinlost)
			WHERE	BetdaqId = -2
			
			IF @IsMergedParlay = 1
				SELECT @TotalSubParlay = COUNT(1)			
				FROM	dbo.bettransm bm WITH(NOLOCK)
				WHERE	bm.matchid = @MatchID
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND bm.statusID NOT IN (101, 103)
						AND EXISTS (SELECT	TOP 1 1
									FROM	@tmpSelectedRID t
									WHERE	t.BetType = bm.bettype
											AND (t.BetID = 0 OR t.BetID = bm.betcheck))
		END 

		DELETE 
		FROM	@tmpCashoutTransId
		WHERE	currentstatuswinlost IS NOT NULL
				AND statuswinlost = currentstatuswinlost

		IF @sportType = 2 AND EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID WHERE ResourceID IN ('00','01'))-- BASKETBALL
		BEGIN
			SELECT	@strBettypes = @strBettypes + CAST(bettype AS VARCHAR) + ','
			FROM	@tmpSelectedRID
			GROUP BY bettype
			
		END
		-------------------------------------------------------------
		---		CAPTURE value BALANCE before settlement		---
		---------------------------VVVV------------------------------
		
		INSERT INTO @BalanceWalletBefore (matchid, custid, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
						@MatchId 				  = @matchId
						,@sportType				  = @sportType
						,@Action 				  = @Action
						,@Mode 					  = 2
						,@SelectedRID			  = @SelectedRID
						,@IsCentral				  = @IsCentral
						
		SELECT @TotalAccount = @@ROWCOUNT
						
		------START UPDATE BETTRANS---------------------------------------------------------------------------
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchNo) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds, deleted.OddsType, deleted.srecommend, deleted.bettype, deleted.IsMarked, deleted.DeadHeat
			INTO @tmpTransIDBatch(transid, modds, OddsType, srecommend, bettype, IsMarked, DeadHeat)
			FROM #tmpTransID t 
			WHERE isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
				  ,@ticketCount	+= @batchCount
			
			IF @batchCount = 0 BREAK

			--filter selectedRID by current Profile and BetType
			SET @strTransIds 		= (SELECT transid	AS '@t'
											   ,modds	AS '@m'
											   ,OddsType	AS '@ot'
											   ,srecommend AS '@sr'
											   ,bettype AS '@bt'
											   ,IsMarked AS '@im'
											   ,DeadHeat AS '@dh'
									   FROM @tmpTransIDBatch
									   FOR XML PATH('r'), ROOT( 'root' ))

			EXEC dbo.NAP_Admin_Calculate_Main
				@matchid	  		 = @matchid
			   ,@action				 = @action
			   ,@IsSettingByProfile  = 1
			   ,@strTransIds		 = @strTransIds
		END
		
		-- cashout for basketball
		IF @sportType = 2 -- BASKETBALL
		BEGIN
			IF @Action = 'UNDO'
				SELECT @Action_tmp = 'CAL', @mode = 'UNDO'
			ELSE
				SELECT @Action_tmp =  @Action, @mode = @Action

			IF EXISTS (SELECT TOP 1 1 FROM @tmpCashoutTransId)
			BEGIN
				UPDATE t 
					SET winlost = c.Winlost
				FROM	@tmpCashoutTransId t
					INNER JOIN dbo.CashOutSelling c WITH(NOLOCK)
						ON t.TransId = c.TransID

				WHILE (1=1)
				BEGIN
					DELETE @tmpTransIDBatch
					SET @strTransIds = ''

					DELETE 	TOP (2000)
					FROM	@tmpCashoutTransId
						OUTPUT deleted.TransId, deleted.statuswinlost, deleted.winlost INTO @tmpTransIDBatch(TransID, statuswinlost, winlost)

					IF @@ROWCOUNT = 0
						BREAK

					SET @strTransIds 		= (SELECT transid	AS '@t'
													   ,winlost	AS '@w'	
													   ,statuswinlost AS '@s'
											   FROM @tmpTransIDBatch
											   FOR XML PATH('r'), ROOT( 'root' ))

					EXEC dbo.NAP_Admin_Calculate_Main
						@matchid	  		 = @matchid
					   ,@action				 = @Action_tmp
					   ,@mode				 = @mode
					   ,@IsSettingByProfile  = 1
					   ,@sportType			 = @sportType
					   ,@CashoutVersion		 = 2 
					   ,@strTransIds		 = @strTransIds

				END
			END
			
		END	


		------END UPDATE BETTRANS---------------------------------------------------------------------------
			
		-------------------------------------------------------------
		---		 CAPTURE value BALANCE after settlement		---
		---------------------------VVVV------------------------------
		
		INSERT INTO @BalanceWalletAfter (matchid, custid, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
					@MatchId		  	= @matchId
					,@sportType			= @sportType
					,@Action 			= @Action
					,@Mode 			  	= 2 --Used for Manual settle process
					,@SelectedRID		= @SelectedRID
					,@IsCentral			= @IsCentral
		
		-- Compare and update pending balance with error case
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					@BalanceWalletBefore	= @BalanceWalletBefore
					,@BalanceWalletAfter	= @BalanceWalletAfter
					,@ActionId				= @ActionID
		
		------END UPDATE BETTRANS---------------------------------------------------------------------------
		IF @IsCentral = 1
		BEGIN
			IF (@IsAuto = 1 AND @sporttype IN ( 6, 9, 50 )	AND @Action = 'CAL' )
			BEGIN
				EXEC DBPRO.bodb02.dbo.NAP_Set_AutoPayoutResultOS_Update 
				  @MatchId 			 = @matchid
				, @SelectedResources = @SelectedResources
				, @StatusId 		 = 2
				, @UserId			 = @creator
			END
		END
	END TRY
	BEGIN CATCH
		  -------------------------------------------------------------
		  ---		 CAPTURE value BALANCE after settlement		---
		  ---------------------------VVVV------------------------------
		INSERT INTO @BalanceWalletAfter (matchid, custid, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
			  @MatchId 				= @matchId
			  , @sportType			= @sportType
			  , @Action 			= @Action
			  , @Mode 				= 2 --Used for Manual settle process
			  , @SelectedRID		= @SelectedRID
			  , @IsCentral			= @IsCentral
			  
		-- Compare and update pending balance with error case
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			  @BalanceWalletBefore	= @BalanceWalletBefore
			  , @BalanceWalletAfter	= @BalanceWalletAfter
			  , @ActionId			= @ActionID


		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE()

		------ releasing Settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
				  @isExistMatch		= 1
				  , @IsReleased		= 1

		RETURN
	END CATCH

	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		  ,@IsReleased		= 1

	SELECT @stop = CURRENT_TIMESTAMP
	
	SELECT @logdata = CASE WHEN @sportType IN ( 6, 9, 50 ) AND @IsAuto = 1 AND @Action ='CAL' THEN 'NAP: Auto Payout Calculate '
							ELSE 'NAP: Calculate '
							END
							+ '(' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10))
							+ ' Result: ' + @SelectedResources + '<br/> '
							+ '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
							+ ' Betstatus(' + ISNULL(@betstatus,'') + ')' 
	EXEC dbo.Logfile_V2 
		@UserID = @creator
		,@Doing = @logdata
		,@extend = @MatchId
		
	SET @matchLog = @MatchID

	IF @IsCentral = 1
	BEGIN 
		SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT a.custid)
		FROM @BalanceWalletAfter a
			INNER JOIN @BalanceWalletBefore b 
			ON	 a.matchid				= b.matchid
					AND a.custid		= b.custid
					AND a.balanceType	= b.balanceType
					AND a.walletType	= b.walletType
					AND a.bonusId		= b.bonusId
		WHERE a.balance <> b.balance
	
		-------------------------------------------------------------
		---					  WRITE LOG						---
		---------------------------VVVV------------------------------
		
		INSERT INTO @tmpGetLog (ResourceID, HomeValue, AwayValue, BetType, BetID, OrdNo, RoundName )
		SELECT ResourceID, HomeValue, AwayValue, BetType, BetID, OrdNo, RoundName
		FROM @tmpSelectedRID

		IF @ParentMatchId IS NOT NULL 
		BEGIN
			DELETE FROM @tmpGetLog
			WHERE ResourceID NOT IN (
				SELECT sp.ResourceID 
				FROM dbo.bettrans bt WITH(NOLOCK)
					INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
						ON (sp.BetID = 0 OR sp.BetID =bt.betid)
							AND sp.BetType = bt.bettype
				WHERE bt.matchid = @MatchID
					AND sp.SportType =50 )
		END

	IF @sportType = 45 ---for Log Only
		BEGIN
			INSERT INTO @tmpGetLog (ResourceID, HomeValue, AwayValue, RoundName )
			SELECT r.ResourceID, r.HomeValue, r.AwayValue, sd.RoundName
			FROM @tmpResourcesWeb r
				INNER JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON r.ResourceID = sd.ResourceID
			WHERE r.ResourceID IN ('0101','0102','0103','0104','0105')
		END

		SELECT @ResultRemarkLog = @ResultRemarkLog + ',' +  ISNULL(RoundName,ResourceID) + 
				CASE WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND AwayValue IS NOT NULL AND AwayValue <> '' THEN '(' + HomeValue + '-' + AwayValue + ')'
					 WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND (AwayValue IS NULL OR AwayValue = '') THEN '(' + HomeValue + ')'
					 WHEN HomeValue IS NULL AND AwayValue IS NULL THEN ''
					 ELSE '' END
		FROM (
				SELECT DISTINCT ResourceID, HomeValue, AwayValue, RoundName, MAX(OrdNo) AS OrdNo
		  		FROM @tmpGetLog sr
		  		GROUP BY ResourceID, HomeValue, AwayValue, RoundName
  			) AS tbl1
		ORDER BY OrdNo

		--Log Auto Refund for Badminton
	IF EXISTS ( SELECT TOP 1 1 FROM @tmpSelectedRID WHERE @sportType IN ( 6, 9 ) AND @IsAuto = 1 AND @Action = 'CAL' AND ResourceID = '00'	AND HomeValue <> AwayValue 	)
		BEGIN
			EXEC dbo.NAP_Set_GetRefundResult
				@MatchId		= @MatchID
				,@Sporttype		= @sportType
				,@CalculateResources	= @SelectedResources
				,@ResourceRefund = @ResourceRefund OUTPUT
		END

		SELECT @ResultRemarkLog =  CASE WHEN @sportType = 50 AND @ParentMatchId IS NOT NULL THEN 'child: ' + CAST(@matchid AS VARCHAR) -- Child match ( parent is Cricket TEST match)
										WHEN @IsAuto = 1 AND @Action ='CAL' THEN CASE WHEN @sportType = 50 THEN 'NAP: Auto Payout: Weverdat'
																   WHEN @sportType IN ( 6, 9 ) THEN 'NAP: Auto Payout: SBO'				
																   ELSE '' END
										ELSE ''
										END
			 
									+ CASE WHEN @Action LIKE 'CAL%' THEN ' Result:' 
										ELSE ' Selected:' 
										END 
									+ SUBSTRING(@ResultRemarkLog, 2, LEN(@ResultRemarkLog))
									+ CASE WHEN @sportType = 6 AND @ChildMatchIds IS NOT NULL  THEN ' CalcChild: ' + @ChildMatchIds
											WHEN @sportType = 9 AND @IsAuto = 1 AND @Action = 'CAL' THEN ' auto_refund:' + CASE WHEN ISNULL(@ResourceRefund,'') <> '' THEN '1' ELSE '0' END  
											ELSE '' 
											END
	
	
						   
		SELECT @Remark = @ResultRemarkLog + '<br/> '
							+ CASE
							WHEN @sportType IN ( 2, 5, 43 ) OR ( @sportType IN ( 6, 9, 50 ) AND @IsAuto = 0) THEN 'Is Leader: ' + CAST(ISNULL(@IsLeader,0) AS VARCHAR) + '; '
								ELSE ''
							END
							+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
							+ CASE WHEN @Action LIKE 'CAL%' THEN '; Recalc: ' + CAST (ISNULL(@IsReSettledTickets,0) AS VARCHAR(1)) ELSE '' END
							+ '; TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
							+ '; Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
							+ CASE @RefResultStatus WHEN 1 THEN ' confirmed/provider:no'
													WHEN 2 THEN ' value consistency:no'
													ELSE ''
													END
	
		IF @ParentMatchId IS NOT NULL ---Cricket
		BEGIN
				SELECT  @matchLog =  @ParentMatchId
					,@fth	= finalhomescore
					,@fta	= finalawayscore
  			FROM	DBPRO.BODB02.dbo.match WITH (NOLOCK)
  			WHERE   matchid = @ParentMatchId
		END

		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_MajorRound(@Sporttype) sd WHERE sd.RoundID = '01' AND sd.GroupType = 'HT')
		BEGIN
			SELECT @hth	= NULL
					,@hta = NULL
		END
				
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
					@userid				= @creator
					,@matchid			= @matchLog
					,@actionid			= @ActionID
					,@finalhomescore	= @fth
					,@finalawayscore	= @fta
					,@hthomescore		= @hth
					,@htawayscore		= @hta
					,@GoalRecord		= NULL
					,@Remark			= @Remark
					,@ip				= @ip
		END TRY
		BEGIN CATCH
			SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
					@UserID				= @creator
					,@MatchID			= @matchLog
					,@actionid			= @actionid
					,@finalhomescore	= @fth
					,@finalawayscore	= @fta
					,@hthomescore		= @hth
					,@htawayscore		= @hta
					,@GoalRecord		= NULL
					,@betstatus			= @betstatus
					,@Remark			= @Remark
					,@IP				= @ip
		END CATCH
	END		

	IF @TotalSubParlay > 0
	BEGIN		
		SELECT @SelectedResourceParlay = CAST((SELECT ResourceID AS '@Id'
											,CASE WHEN RefResourceId IS NOT NULL THEN RefResourceId ELSE NULL END AS '@RefResourceId' 
											,bettype AS '@Bettype'
											,pfid	AS '@pfId'
											,HomeValue AS '@Home'
											,AwayValue AS '@Away'
									FROM	@tmpSelectedRID
									FOR XML PATH ('Resource'), ROOT('Resources'), TYPE) AS VARCHAR(MAX))
			
		EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

		IF @TotalSubParlay <= @ThreadHold
			SET @LockedByRefno = 1
		
		SET	@sqlCommand =  'EXEC [dbo].[NAP_Admin_Settlement_Profile_Parlay] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
								+ ', @creator = ' + CONVERT(NVARCHAR(50), @creator) 												
								+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResourceParlay) + ''''
								+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 														
								+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + ''''
								+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) 								
								+ ', @IsAuto = ''' + CONVERT(CHAR(1), @IsAuto ) + ''''	
								+ ', @IsCentral = ' + CONVERT(VARCHAR(1), @IsCentral)
								+ ', @ErrCode = @ErrCode OUTPUT' 
								+ ', @ErrMsg = @ErrMsg OUTPUT'

		IF @procName LIKE '%_xtest' OR @procName LIKE '%_xpre' OR @procName LIKE '%_UAT[1-9]'
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Profile_Parlay
				@creator			= @creator
				,@MatchID			= @MatchId
				,@Action		  	= @Action
				,@IP	 			= @Ip
				,@SelectedResources = @SelectedResourceParlay
				,@IsReSettledTickets = @IsReSettledTickets
				,@LockedByRefno		= 1 -- always lock refno for testing
				,@IsAuto			= @IsAuto
				,@IsCentral			= @IsCentral
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg 			= @ErrMsg OUTPUT
		END
		ELSE
		BEGIN
			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype, LockedByRefno, BroadcastSessionId)
			SELECT @MatchID, 0, @creator, @IP, CURRENT_TIMESTAMP, @action, @sqlCommand, @sportType, @LockedByRefno, @BroadcastSessionId + '_parlay'
		END
	END

	ELSE IF @Action NOT LIKE 'UNDO%' AND ISNULL(@BroadcastSessionId,'') <> ''
	BEGIN
		INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue (RequestId, MatchId, sporttype, StatusId, UserId, Ip, starttime, action, BroadcastSessionId)
		SELECT 0, @MatchId, @sporttype, 0,10278938,'125.227.140.97', GETDATE(), 'CAL-PAR', @BroadcastSessionId + '_parlay'
	END

	IF @IsCentral = 1
	BEGIN
			IF @Action = 'REFUND'
			BEGIN
				EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefundOS_ResultUpd
						  @MatchId = @matchid
						, @StatusId = 2
						, @ResourceIds  = @ResourceIds
			END

			ELSE IF ISNULL(@ResourceRefund, '')  <> ''
			BEGIN
				EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefundOS_ResultIns
						@MatchId		 = @MatchID
						,@ResourceIds	 = @ResourceRefund
			END
	END
END
GO