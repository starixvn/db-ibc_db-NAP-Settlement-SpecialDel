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
		- 20210514@Kathy: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20210517@Louisa: Incorporate Saba Soccer PinGoal [Redmine:#155052]

	Param's Explanation:
		* @SelectedResources= '<Resources>
									<Resource Id="M1" Home="1" Away="3" />
									<Resource Id="M2" Home="2" Away="4" />
							   </Resources>'
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
			,@ActionID		  INT
			,@Remark			VARCHAR(500)
			,@LogData		   NVARCHAR(300)
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
			,@SelectedQuarter 	VARCHAR(50) = NULL
			,@ParentMatchId		INT
			,@CutOffDate		DATETIME = '2021-04-08 00:00:00.000'
			,@procName			SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime		VARCHAR(10)
			,@IsWaiting			BIT = 0
			,@LeagueGroupID		SMALLINT = 0

  	--START Balance tables
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		   , @BalanceWalletAfter		TVP_BalanceWalletChange
	--END Balance tables

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	--DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20), bettype SMALLINT, betid BIGINT)
	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, isFinish BIT, srecommend INT, bettype SMALLINT, IsMarked	BIT)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, srecommend INT, bettype SMALLINT, IsMarked	BIT)
	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),
								  BetType SMALLINT, BetID BIGINT, pfID SMALLINT, RoundID VARCHAR(10), OrdNo SMALLINT,
								  isFinal BIT, RoundName VARCHAR(20), GroupType VARCHAR(2), OddsType SMALLINT
								  ,PRIMARY KEY (BetType,BetID))
	DECLARE @tmpResourcesWeb TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))

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
		   ,@IsEarly =  CASE 
						 WHEN @Action LIKE '%EAR' THEN 1 
						 ELSE 0 
						END

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

		IF @Action LIKE 'CAL%'
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_9001
						@action					= 'CAL'
						,@MatchID				= @MatchID
						,@creator				= @creator
						,@Sporttype				= @Sporttype
						,@SelectedRID   		= @SelectedResources
		END

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
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
																,Home VARCHAR(50)
																,Away VARCHAR(50)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END

		-- badminton
		IF (@sportType = 9) AND Exists (SELECT 1 FROM @tmpResourcesWeb WHERE ResourceID = '00')
		BEGIN
			IF @Action LIKE 'CAL%'
			BEGIN
				--Insert data for internal ResourceId 70400
				INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
				SELECT '70400' AS ResourceID, CAST(SUM(CAST(HomeValue AS INT)) AS VARCHAR(50)) AS HomeValue, CAST(SUM(CAST(AwayValue AS INT)) AS VARCHAR(50)) AS AwayValue
							FROM DBPRO.bodb02.dbo.ResultDetailOS WITH(ROWLOCK)
							WHERE MatchID = @MatchID AND ResourceID IN ('0101','0102','0103','0104','0105')
									AND SettlementStatusID = 4
									AND ResultStatusID = 5

				--Get total home value/total away value of ResourceId = '70400' 
				SELECT TOP 1 @TotalPointHomeValue = HomeValue, @TotalPointAwayValue = AwayValue
				FROM @tmpResourcesWeb
				WHERE ResourceID = '70400'

			END
			ELSE
			BEGIN

				INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
				SELECT '70400' AS ResourceID, '' AS HomeValue, '' AS AwayValue

			END
		END
		-- Tennis
		ELSE IF (@sportType = 5) AND Exists (SELECT 1 FROM @tmpResourcesWeb WHERE ResourceID = '00')
		BEGIN
			SELECT  @TotalPointHomeValue = CAST(SUM(CAST(HomeValue AS INT)) AS VARCHAR(50)), 
					@TotalPointAwayValue = CAST(SUM(CAST(AwayValue AS INT)) AS VARCHAR(50))
			FROM DBPRO.bodb02.dbo.ResultDetail WITH(ROWLOCK)
			WHERE MatchID = @MatchID AND ResourceID IN ('01','02','03','04','05')
					AND SettlementStatusID = 4
					AND ResultStatusID = 5
		END

		INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID, RoundID, OrdNo, isFinal, RoundName, GroupType, OddsType)
		SELECT DISTINCT CASE WHEN tbl.ResourceID = '70400' THEN '00' ELSE tbl.ResourceID END, 
				CASE WHEN sp.BetType = 153 THEN ISNULL(@TotalPointHomeValue, '') ELSE ISNULL(HomeValue,'') END, 
				CASE WHEN sp.BetType = 153 THEN ISNULL(@TotalPointAwayValue, '') ELSE ISNULL(AwayValue,'') END, 
				sp.BetType, sp.BetID, sp.pfID, sp.RoundID, sp.OrdNo, 
				CASE WHEN tbl.ResourceID = '70400' THEN 1 ELSE sd.isFinal END, 
				CASE WHEN tbl.ResourceID = '70400' THEN 'FT' ELSE sd.RoundName END, 
				sp.GroupType, sp.OddsType
		FROM @tmpResourcesWeb tbl
			INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.ResourceID
			LEFT JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON sp.ResourceID = sd.ResourceID
		WHERE sp.SportType = @SportType
		-----------------------------------------------------END parse XML----------------------------------------------------------------------

		SELECT   @SelectedRID   = (SELECT Bettype   AS '@bt'
											 ,BetID	AS '@b'
									  FROM @tmpSelectedRID
									  FOR XML PATH('r'), ROOT( 'root' ))

  		--get transid
  		IF @Action LIKE 'CAL%'
  		BEGIN

			--Bettype 2,3: using match score or total point, badminton only
			UPDATE t
				SET HomeValue = CASE WHEN ISNULL(@TotalPointHomeValue, '') <> '' THEN @TotalPointHomeValue ELSE HomeValue END,
					AwayValue = CASE WHEN ISNULL(@TotalPointAwayValue, '') <> '' THEN @TotalPointAwayValue ELSE AwayValue END
			FROM @tmpSelectedRID t
			WHERE t.BetType IN (2, 3) AND t.ResourceID = '00' AND @sportType IN (5, 9) 

			INSERT INTO #tmpTransID(TransID, modds, OddsType, srecommend, bettype, IsMarked)
	  		SELECT 
				b.transid, m.modds
				, CASE WHEN b.bettype = 501 AND b.transdate < @CutOffDate THEN 0
						ELSE sr.OddsType
					END AS OddsType
				, b.srecommend, b.bettype, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
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
	  			AND b.statusID NOT IN (101)
				AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END

		END
		ELSE IF @action LIKE 'UNDO%'
		BEGIN
			--get transid
			INSERT INTO #tmpTransID(TransID)
	  		SELECT b.transid
	  		FROM bettrans b WITH (NOLOCK)
	  			INNER JOIN @tmpSelectedRID t ON b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID)
				OUTER APPLY (
					SELECT	TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
				) mt
	  		WHERE b.matchid = @MatchId
	  			AND	b.statusID NOT IN (101)
				AND 1 = CASE WHEN b.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
							 WHEN b.statusID NOT IN (0, 1) THEN 1
							 ELSE 0 
						END
		END 
		ELSE IF @action LIKE 'REFUND%'
		BEGIN
			--get transid
			INSERT INTO #tmpTransID(TransID)
	  		SELECT transid
	  		FROM bettrans b WITH (NOLOCK)
	  			INNER JOIN @tmpSelectedRID t ON b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  		WHERE b.matchid = @MatchId
	  			AND	b.statusID NOT IN (103, 101)
		END 
	
		---check FT round
		SET @existsFinalRound = 0
  		SELECT TOP 1 @existsFinalRound = 1
					,@fth = sr.HomeValue
					,@fta = sr.AwayValue
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '00'
  	
  		---check HT round
  		SET @existsHTRound = 0
  		SELECT TOP 1 @existsHTRound = 1
					,@hth = sr.HomeValue
					,@hta = sr.AwayValue
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '01' 
			AND 1 = CASE WHEN @sportType = 2 THEN 1
						 WHEN @sportType = 1 AND @LeagueGroupID = 113 THEN 1---PinGoal
						 ELSE 0
						 END

		IF @existsHTRound = 1
		BEGIN
			SELECT  @hth	= COALESCE (@hth, 0)
					,@hta   = COALESCE (@hta, 0)
					,@SelectedQuarter = '1H'
		END
			
  		IF @existsFinalRound = 1
  		BEGIN
	  		IF @Action LIKE 'CAL%'
	  		BEGIN
				SELECT  @hth	= COALESCE (@hth, 0)
						,@hta   = COALESCE (@hta, 0)
						,@fth   = COALESCE (@fth, 0)
						,@fta   = COALESCE (@fta, 0)
			END
		
			IF @Action LIKE 'REFUND%'
	  		BEGIN
				SELECT  @hth	= COALESCE (@hth, 0)
						,@hta   = COALESCE (@hta, 0)
						,@fth   = COALESCE (@fth, 0)
						,@fta   = COALESCE (@fta, 0)
			END
		
			IF @Action LIKE 'UNDO%'
	  		BEGIN
				SELECT  @hth	= NULL
						,@hta   = NULL
						,@fth	= NULL
						,@fta	= NULL
			END

			SELECT @SelectedQuarter = CASE WHEN @existsHTRound = 1 THEN '1H' ELSE 'FT' END WHERE @sportType = 2
		END

		IF @Action LIKE 'CAL%'
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update
						@Command				= 'profile'
						,@Action				= 'CAL'
						,@MatchID				= @matchid
						,@FTHome				= @fth
						,@FTAway				= @fta
						,@HTHome				= @hth
						,@HTAway				= @hta
						,@creator				= @creator
						,@IsFinalRound			= @existsFinalRound
						,@IsHTRound				= @existsHTRound
						,@BetStatus				= @BetStatus
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
		SELECT @TotalAccount = @@ROWCOUNT
		

		------START UPDATE BETTRANS---------------------------------------------------------------------------
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchNo) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds, deleted.OddsType, deleted.srecommend, deleted.bettype, deleted.IsMarked
			INTO @tmpTransIDBatch(transid, modds, OddsType, srecommend, bettype, IsMarked)
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
									   FROM @tmpTransIDBatch
									   FOR XML PATH('r'), ROOT( 'root' ))

			EXEC dbo.NAP_Admin_Calculate_Main
				@matchid	  		 = @matchid
			   ,@action				 = @action
			   ,@IsSettingByProfile  = 1
			   ,@strTransIds		 = @strTransIds

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
	
		-- Compare and update pending balance with error case
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					@BalanceWalletBefore	= @BalanceWalletBefore
					,@BalanceWalletAfter	= @BalanceWalletAfter
					,@ActionId				= @ActionID
		------END UPDATE BETTRANS---------------------------------------------------------------------------
		
					
		IF @Action LIKE 'CAL%'
		BEGIN

			IF  @existsFinalRound = 1
			BEGIN				 
				EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark
							@matchid				= @matchid
							,@command				= 'C'
			END

			ELSE IF @existsHTRound = 1
			BEGIN				 
				EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
						@matchid    = @matchid
						,@command    = 'H'
			END

		END-------------------end CAL
		ELSE IF @action LIKE 'UNDO%'
		BEGIN

			--update ResultDetail before settle Parlay
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_9001
							@action  			= 'UNDO'
							,@matchid 			= @MatchId
							,@SelectedRID   	= @SelectedResources
							,@Sporttype			= @Sporttype
							,@creator 			= @creator
							
			EXEC dbo.NAP_Admin_Settlement_MP
							@matchid			= @matchid
							,@creator			= @creator
							,@action			= 'UNDO'
							,@SelectedResources = @SelectedResources
							,@IP				= @IP
			IF @existsFinalRound = 1
			BEGIN
				EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark
							@matchid			= @matchid
							,@command			= 'U'
							,@IsFinalRound		= @existsFinalRound
							,@SelectedQuarter   = @SelectedQuarter
			END
			ELSE IF @existsHTRound = 1
			BEGIN
				EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark
							@matchid			= @matchid
							,@command			= 'U'
							, @SelectedQuarter  = @SelectedQuarter
			END
			
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update
							@Command			='profile'
							,@Action			='UNDO'
							,@MatchID			= @matchid
							,@creator			= @creator
							,@IsFinalRound		= @existsFinalRound
							,@IsHTRound			= @existsHTRound
							,@BetStatus			= @BetStatus
														
			IF @existsFinalRound = 1
			BEGIN
				EXEC DBACC.bodb02.dbo.NAP_Admin_Match_UpdateSaveBet
							@action				= 'UNDO'
							,@matchid			= @matchid
							,@IsFinalRound		= @existsFinalRound
			END
		END-------------------end UNDO
		ELSE IF @Action LIKE 'REFUND%'
		BEGIN
			
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update
							@matchid			= @matchid
							,@command			= 'profile'
							,@Action			= 'REFUND'
							,@FTHome			= @fth
							,@FTAway			= @fta
							,@HTHome			= @hth
							,@HTAway			= @hta
							,@IsFinalRound  	= @existsFinalRound
							,@IsHTRound			= @existsHTRound
							,@BetStatus			= @BetStatus
							
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_9001
							@action				= 'REFUND'
							,@MatchID			= @MatchID
							,@creator			= @creator
							,@Sporttype			= @Sporttype
							,@SelectedRID   	= @SelectedResources
							
			IF  @existsFinalRound = 1 OR @existsHTRound = 1
			BEGIN
				  EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark
							@matchid			= @matchid
							,@command			= 'F'
							,@IsFinalRound		= @existsFinalRound
							,@SelectedQuarter   = @SelectedQuarter

			END
		END------------end REFUND

		
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
	SELECT @stop = CURRENT_TIMESTAMP
	
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
	END

	SELECT @ResultRemarkLog = @ResultRemarkLog + ',' +  ISNULL(RoundName,ResourceID) + 
			CASE WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND AwayValue IS NOT NULL AND AwayValue <> '' THEN '(' + HomeValue + '-' + AwayValue + ')'
				 WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND (AwayValue IS NULL OR AwayValue = '') THEN '(' + HomeValue + ')'
				 WHEN HomeValue IS NULL AND AwayValue IS NULL THEN ''
				 ELSE '' END
	FROM (
			SELECT DISTINCT ResourceID, HomeValue, AwayValue, RoundName, MAX(OrdNo) AS OrdNo
		  	FROM @tmpSelectedRID sr
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
	 
	
	SELECT @logdata = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10))
							+ ' Result: ' + @SelectedResources + '<br/> '
							+ '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
							+ ' Betstatus(' + @betstatus + ')' 
						   
						   
	SELECT @Remark = @ResultRemarkLog + '<br/> ' 
						+ CASE
							WHEN @sportType IN (43, 5 ) THEN 'Is Leader: ' + CAST(ISNULL(@IsLeader,0) AS VARCHAR) + '; '
							ELSE ''
						END
						+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
						+ CASE WHEN @Action LIKE 'CAL%' THEN '; Recalc: ' + CAST (ISNULL(@IsReSettledTickets,0) AS VARCHAR(1)) ELSE '' END
						+ '; TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
						+ '; Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
				
				
				
	EXEC dbo.WriteLog_UserLog
				@UserID = @creator
				,@Doing = @logdata
	
	IF @sportType = 50
	BEGIN
		SELECT @hth	= NULL
				,@hta = NULL

		IF @ParentMatchId IS NOT NULL
		BEGIN
			SELECT  @MatchId =  @ParentMatchId
					,@fth	= finalhomescore
					,@fta	= finalawayscore
  			FROM	DBPRO.BODB02.dbo.match WITH (NOLOCK)
  			WHERE   matchid = @ParentMatchId
		END
	END
				
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@userid				= @creator
				,@matchid			= @MatchID
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
				,@MatchID			= @matchid
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
 

	----------------------------------- releasing Settlement process--------------------------------------------
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		  ,@IsReleased		= 1
END
GO