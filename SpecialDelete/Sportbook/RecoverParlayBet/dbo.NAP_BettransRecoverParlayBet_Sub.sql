/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverParlayBet_Sub] 
	@UserId				INT,	
	@IP					VARCHAR(50),
	@BetType			VARCHAR(20)		= 'All',
	@MainTransIds		VARCHAR(MAX)	= '',
	@MatchId			INT	
AS
/*
	Created: Kent
	Date: 20161111
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161019@Kent: Recover sub voided Parlay tickets [Redmine:#65531]
		- 20161221@Kathy: Release lock after recovering tickets [Redmine:#68960]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20190719@Raymond.Le: Extend days recover ticket unlimited [#115376]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210720@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210801@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220906@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185238]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230526@Max: [TVS] Check invalid when inputting cricket's child matchID for all functions of Special Delete [Redmine: #188374]
		
	Param's Explanation:			
			- @BetType:
			'all': All
			'Mix Parlay': Mix Parlay
			'System Parlay': System Parlay
*/
BEGIN
	SET NOCOUNT ON
	
	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_BettransRecoverParlayBet_Sub '
				+ CASE WHEN @UserId IS NULL THEN '' ELSE '@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
				+ CASE WHEN @BetType IS NULL THEN '' ELSE ',@BetType = ''' + CONVERT(NVARCHAR(20), @BetType) + '''' END
				+ CASE WHEN @MainTransIds IS NULL THEN '' ELSE ',@MainTransIds = ''' + CONVERT(NVARCHAR(MAX), @MainTransIds) + '''' END
				+ CASE WHEN @MatchId IS NULL THEN '' ELSE ',@MatchId = ''' + CONVERT(NVARCHAR(50), @MatchId) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @RecoverPatchSize		INT = 100
		   ,@Movebetdate			DATETIME 
		   ,@ErrCode				INT = 0
	       ,@ErrMsg					NVARCHAR(200) = ''
		   ,@SettledMainTranIds		VARCHAR(MAX) = '' 
		   ,@NegativeBalanceUsers	VARCHAR(MAX) = '' 
		   ,@TransInfo				VARBINARY(MAX) = NULL
		   ,@SiteDBGroupID			SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MatchDate			DATETIME
		   ,@Eventstatus		NVARCHAR(100) = ''
		   ,@transids_29		VARCHAR(MAX) = ''
		   ,@refnos_29			VARCHAR(MAX) = ''
		   ,@SubTransIds		VARCHAR(MAX) = ''
		   ,@CustIds			VARCHAR(MAX) = ''
		   ,@AvaiableProcess	BIT
		   ,@RowNumber			BIGINT
		   ,@sporttype			SMALLINT = NULL
	
	DECLARE @Session			NVARCHAR(50)
		   ,@ThreadHold			INT -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalSubParlay		INT = 0 
	SET @Session = CONVERT(NVARCHAR(50),NEWID())

	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL

	DECLARE @tblRecoverBet TABLE (
		 RowNumber				BIGINT IDENTITY(1, 1) PRIMARY KEY
		,SubTransID				BIGINT		 
		,SubBetCheck			NVARCHAR(50)
		,SubOdds				SMALLMONEY   
		,SubBetTeam				NVARCHAR(20)  
		,SubBetType				INT  
		,SubHdp1				SMALLMONEY   
		,SubHdp2				SMALLMONEY
		,matchid				INT	
		,SubTransDesc			NVARCHAR(1000)
		,SubLivehomescore		SMALLINT 
		,SubLiveawayscore		SMALLINT 
		,SubLiveindicator		BIT
		,SubHomeID				INT 
		,SubAwayID				INT 
		,SubSportType			SMALLINT 
		,SubLeagueID			INT			
		,balance				MONEY					
		,custid					INT
		,isdeposit				BIT
		,mrecommend				INT
		,recommend				INT
		,srecommend				INT
		,transid				BIGINT
		,UserName				VARCHAR(30)
		,TransDate				DATETIME 
		,BetType				SMALLINT
		,Refno					BIGINT
		,Status					NVARCHAR(10)
		,StatusId				TINYINT
		,WinLost				MONEY
		,betid					BIGINT 
		,BetTeam				NVARCHAR(20)		 
		,Stake					MONEY
		,Odds					SMALLMONEY		
		,hdp1					SMALLMONEY
		,hdp2					SMALLMONEY
		,betfrom				NVARCHAR(4)		
		,betcheck				NVARCHAR(50)
		,ExtraInfo				VARCHAR(1000)
		,ActualStake			MONEY
		,ruben					TINYINT
		,IsFinish				BIT
	)	
	
	CREATE TABLE #tblMainTicket 
	(
		transid		BIGINT
	   ,refno		BIGINT	   
	   ,StatusId	TINYINT	   
	   ,custid		INT
	   ,balance		MONEY	 
	   ,ruben		TINYINT
	   ,matchid		INT
	)
	CREATE CLUSTERED INDEX IDX_tblMainTicket_custid_transid ON #tblMainTicket(custid, transid)
	
	DECLARE @tblMainTransIds TABLE (transid BIGINT)
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, transdate DATETIME, comstatus NVARCHAR(40))
	DECLARE @tblSettledBeforeRecoveredMainTicket TABLE (transid	BIGINT)
	DECLARE @tmpMatchId TABLE (MatchId INT, matchdate DATETIME, IsFinish BIT)
								
	DECLARE @tblBeforeBalance TABLE (custid INT PRIMARY KEY, balance MONEY)
	DECLARE @tblAfterBalance TABLE (custid INT PRIMARY KEY, balance MONEY)
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList					
	
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	SELECT  @MatchDate = eventdate
		  , @Eventstatus = eventstatus
		  , @sporttype =  sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchId	

	INSERT INTO @tmpMatchId (MatchId, matchdate)
	SELECT MatchId, m.eventdate
	FROM dbo.match m WITH(NOLOCK)
	WHERE  1 = CASE WHEN @sporttype <> 50 AND matchid = @MatchId THEN 1
					WHEN @sporttype = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END

	IF @MatchDate <= @Movebetdate
	BEGIN
		SELECT @ErrCode = 112, @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg 
		RETURN	
	END
	
	--> parse @MainTransIds
	INSERT INTO @tblMainTransIds(transid)
	SELECT ss.value AS transid
	FROM STRING_SPLIT(@MainTransIds, ',') ss
	
	IF @@ROWCOUNT = 0
	BEGIN		
		SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'				
		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg 
		RETURN
	END		  
	
	-- Apply new way to lock parlay tickets	
	INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
	SELECT bm.matchid, bm.refno
	FROM @tblMainTransIds t
		  INNER JOIN dbo.bettrans b WITH (NOLOCK)
		  		ON t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
		  INNER JOIN bettransm bm WITH (NOLOCK)
		  		ON bm.refno	= b.refno AND bm.SiteDBGroupID = b.SiteDBGroupID	   							
	WHERE bm.matchid IN (SELECT matchid FROM @tmpMatchId)
		AND b.bettype = 29	
		AND bm.statusid = 102

	SET @totalSubParlay = @@ROWCOUNT

	EXEC dbo.NAP_Set_GlobalSettingSel 
		 @LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	IF 	@totalSubParlay <= @ThreadHold 
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
            @IsLockingByRefno   = 1
           ,@spName             = @spName
           ,@Session            = @Session
           ,@avaiableProcess    = @avaiableProcess OUTPUT
           ,@ErrCode            = @ErrCode OUTPUT
           ,@ErrMsg             = @ErrMsg OUTPUT
	END
	ELSE
	BEGIN
		--- Check for concurrent running
		EXEC dbo.NAP_Admin_CheckingProcess
		    @IsExistParlay = 1			
		   ,@IsReleased	= 0
		   ,@AvaiableProcess = @AvaiableProcess OUTPUT
		   ,@ErrCode = @ErrCode OUTPUT
		   ,@ErrMsg	= @ErrMsg OUTPUT
	END
	
	IF (@ErrCode <> 0 OR @avaiableProcess = 0)
	BEGIN		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg 
		RETURN		 
	END 
	
	BEGIN TRY									
		--> query all sub tickets to recover
		INSERT INTO @tblRecoverBet(
				 SubTransID			 
				,SubBetCheck	
				,SubOdds
				,SubBetTeam	
				,SubBetType
				,SubHdp1		
				,SubHdp2
				,matchid
				,SubTransDesc
				,SubLivehomescore 
				,SubLiveawayscore 
				,SubLiveindicator
				,SubHomeID
				,SubAwayID
				,SubSportType 
				,SubLeagueID				
				,balance										
				,custid
				,isdeposit
				,mrecommend				
				,recommend	
				,srecommend			
				,transid
				,UserName
				,TransDate	
				,BetType	
				,Refno	
				,Status
				,StatusId
				,WinLost
				,betid	
				,BetTeam				
				,Stake	
				,Odds				
				,hdp1
				,hdp2
				,betfrom				
				,betcheck
				,ExtraInfo
				,ActualStake
				,ruben)
		SELECT  bm.transid AS SubTransID			 
				,bm.betcheck AS SubBetCheck	
				,bm.odds AS SubOdds
				,bm.betteam AS SubBetTeam	
				,bm.bettype AS SubBetType
				,bm.hdp1 AS SubHdp1		
				,bm.hdp2 AS SubHdp2	
				,bm.matchid AS matchid
				,bm.transdesc AS SubTransDesc
				,bm.livehomescore AS SubLivehomescore 
				,bm.liveawayscore AS SubLiveawayscore
				,bm.liveindicator AS SubLiveindicator	
				,m.homeid AS SubHomeID
				,m.awayid AS SubAwayID
				,m.sporttype AS SubSportType 
				,m.leagueid AS SubLeagueID				
				,b.winlost - b.actual_stake + b.playercomm AS balance								
				,b.custid AS custid
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end AS isdeposit
				,b.mrecommend AS mrecommend
				,b.recommend AS recommend
				,b.srecommend AS srecommend
				,b.transid AS transid
				,b.Username AS UserName
				,b.transdate AS TransDate	
				,b.bettype AS BetType	
				,b.refno AS Refno	
				,b.[status] AS [Status]
				,b.statusID AS StatusId
				,b.winlost-b.actual_stake AS WinLost
				,b.betid AS betid	
				,b.betteam AS BetTeam				 
				,b.stake AS Stake	
				,b.odds AS Odds				
				,b.hdp1 AS hdp1
				,b.hdp2 AS hdp2
				,b.betfrom AS betfrom				 
				,b.betcheck AS betcheck
				,b.ExtraInfo
				,b.actual_stake AS ActualStake
				,b.ruben
		FROM @tblMainTransIds t
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
					ON t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
			INNER JOIN bettransm bm WITH (NOLOCK)
					ON bm.refno	= b.refno AND bm.SiteDBGroupID = b.SiteDBGroupID	   							
			INNER JOIN dbo.match m WITH(NOLOCK)
					ON	bm.matchid = m.matchid
		WHERE bm.matchid IN (SELECT matchid FROM @tmpMatchId)
		  AND b.bettype = 29	
		  AND bm.statusid = 102
		  AND (b.betfrom IS NULL OR b.betfrom <> 'p')
		  AND (m.sporttype BETWEEN 1 AND 99)
		  AND CASE
					WHEN @BetType = 'all' THEN 1
					WHEN @BetType = 'Mix Parlay' THEN CASE WHEN b.betteam = 1 THEN 1 ELSE 0 END
					WHEN @BetType = 'System Parlay' THEN CASE WHEN b.betteam = 1 THEN 0 ELSE 1 END
					ELSE 0
			  END	= 1	
				
		IF @@ROWCOUNT = 0
		BEGIN
			IF @totalSubParlay <= @ThreadHold
			BEGIN
				 EXEC dbo.NAP_Admin_CheckingProcess
                    @IsLockingByRefno = 1
                   ,@Session = @Session
                   ,@IsReleased = 1
			END
			ELSE
			BEGIN
				------ release Parlay procesee	
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsExistParlay = 1			
				   ,@IsReleased	= 1		
			END	  			
			
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'
			
			SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg 
			RETURN
		END										
	
		--> get list of MainTranIds	
		INSERT INTO #tblMainTicket(transid, refno, StatusId, custid, balance, ruben, matchid)
		SELECT t.transid
			 , t.refno			 
			 , t.StatusId			 
			 , t.custid
			 , t.balance
			 , t.ruben
			 , t.matchid
		FROM @tblRecoverBet t		
		
		--> capture list of settled main transIDs before do recover
		INSERT INTO @tblSettledBeforeRecoveredMainTicket(transid)
		SELECT transid
		FROM #tblMainTicket
		WHERE StatusId IN (111, 112, 113) -- 'DRAW', 'WON', 'LOSE'
								
		--> capture @tblBeforeBalance
		INSERT INTO @tblBeforeBalance (custid, balance)
		SELECT	t.custid
				,SUM(t.balance) balance
		FROM #tblMainTicket t					
		GROUP BY t.CustID
				  
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
									,t.ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #tblMainTicket t
								GROUP BY custid, ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)
		--> Do recover
		-- for bettransM
		DECLARE @tmpTransIDBatch TABLE (transid BIGINT)

		WHILE (1=1)
		BEGIN
			UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId, @MatchDate = p.matchdate
			FROM @tmpMatchId p
			WHERE p.IsFinish IS NULL
		
			IF @@ROWCOUNT = 0 BREAK

			WHILE (1 = 1)
			BEGIN
				DELETE @tmpTransIDBatch
				SET @SubTransIds = ''
		
				UPDATE TOP(@RecoverPatchSize) t
				SET isFinish = 1
					OUTPUT deleted.transid
					INTO @tmpTransIDBatch(transid)
				FROM @tblRecoverBet t
				WHERE isFinish IS NULL 
					AND t.MatchId = @MatchId

				IF @@ROWCOUNT = 0 BREAK

				SELECT	@SubTransIds = @SubTransIds + CONVERT(VARCHAR(50), TransId) + ','
				FROM	@tmpTransIDBatch				
			
				EXEC dbo.NAP_Admin_Calculate_MP_broker
					@matchid = @matchid
					,@matchdate = @MatchDate
					,@mode = 'RECOVER' -- update bettransM + BetParlayDetail
					,@VoidTransID = @SubTransIds
				
				SET @RowNumber = @RowNumber + @RecoverPatchSize				
			END				
		
			SELECT @transids_29 = @transids_29 + CONVERT(VARCHAR(50), transid) + ','
			FROM #tblMainTicket	
			WHERE matchid = @MatchId
			
			-- call pre-cal: betparlaydetail/betparlayresult		
			EXEC dbo.NAP_Admin_Calculate_MP_broker 
				@matchid	= @MatchId
				,@matchdate = @MatchDate
				,@strXML	= @transids_29
				,@mode		= 'PRECAL-29'
		END

		SELECT @refnos_29 = @refnos_29 + CONVERT(VARCHAR(50), refno) + '|' + CONVERT(VARCHAR(50), transid) + ','
		FROM #tblMainTicket	
				
		-- call cal_29: re-settle for main ticket
		EXEC dbo.NAP_Admin_Calculate_MP_broker
			@matchdate = @MatchDate
			,@strXML	= @refnos_29  -- main transid + refno: refno|transid,refno|transid...
			,@mode		= '29' 
		
		--Insert Max Payout Queue
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
			,@Mode = 'RECOVER'
		
		--> capture @tblAfterBalance
		INSERT INTO @tblAfterBalance (custid, balance)
		SELECT	t.custid
				,SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM #tblMainTicket t	
			INNER JOIN bettrans b WITH (NOLOCK) 
				ON t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID		
		GROUP BY t.CustID
		
		--> update credit balance of cust
		INSERT INTO @tblCreditPending (custID, balance)
		SELECT		a.custid, (a.balance - b.balance) AS Balance
		FROM		@tblBeforeBalance b
		INNER JOIN	@tblAfterBalance a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) > 0
				
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 1 -- Sports		

		--> update dedit balance of cust
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT		a.custid, ABS(a.balance - b.balance) AS Balance
		FROM		@tblBeforeBalance b
		INNER JOIN	@tblAfterBalance a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) < 0	
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 1 -- Sports
		
		DELETE	z
			OUTPUT deleted.matchid, deleted.transid, deleted.transdate, deleted.comstatus
			INTO @tmpTransInfo (matchid, transid, transdate, comstatus)
		FROM	dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tblRecoverBet t 
				ON	z.custid = t.custid
					AND z.matchid = t.matchid
					AND z.transid = t.SubTransID
		WHERE z.SiteDBGroupID = @SiteDBGroupID
		
		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			DELETE @tmpMatchId
			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT matchid
			FROM @tmpTransInfo

			WHILE (1=1)
			BEGIN
				UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
				FROM @tmpMatchId p
				WHERE p.IsFinish IS NULL
		
				IF @@ROWCOUNT = 0 BREAK

				SET @TransInfo = COMPRESS((
				SELECT	matchid AS 'mid'
					  , transId AS 't'
					  , transdate AS 'td'
						, comstatus AS 'cst'
				FROM	@tmpTransInfo
				WHERE matchid = @MatchId
				FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverSubParlay', 'zzzbettrans', 'D', @matchid, @TransInfo, 'p' 

				SET @TransInfo = ''
			END
			
			DELETE FROM @tmpTransInfo
		END

		DELETE	zm
			OUTPUT deleted.matchid, deleted.transid
			INTO @tmpTransInfo (matchid, transid)
		FROM dbo.zzzbettransm zm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tblRecoverBet t 
				ON	zm.custid = t.custid
					AND zm.matchid = t.matchid
					AND zm.transid = t.SubTransID
		WHERE zm.SiteDBGroupID = @SiteDBGroupID
			
		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			DELETE @tmpMatchId
			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT matchid
			FROM @tmpTransInfo

			WHILE (1=1)
			BEGIN
				UPDATE TOP (1) p SET p.IsFinish = 1, @MatchId = p.MatchId
				FROM @tmpMatchId p
				WHERE p.IsFinish IS NULL
		
				IF @@ROWCOUNT = 0 BREAK

				SET @TransInfo = COMPRESS((
				SELECT	matchid AS 'mid'
					  , transId AS 't'
				FROM	@tmpTransInfo
				WHERE matchid = @MatchId
				FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverSubParlay', 'zzzbettransm', 'D', @matchid, @TransInfo, 'p' 

				SET @TransInfo = ''
			END

			DELETE FROM @tmpTransInfo
		END

		--> Build list of changed status main transids that corresponding match needs to re-settle
		IF @Eventstatus = 'completed'
		BEGIN				   
			SELECT @SettledMainTranIds += CASE WHEN @SettledMainTranIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(50), t.transid)
			FROM @tblSettledBeforeRecoveredMainTicket t			 
				 INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid	 
			WHERE b.statusID = 0 AND b.SiteDBGroupID = @SiteDBGroupID
		END
		
		--> Build list of customer name with negative balance
		SELECT @CustIds = @CustIds + CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20), b.custid)
		FROM @tblBeforeBalance b
			 INNER JOIN	@tblAfterBalance a 	
					 ON a.custid = b.custid
		WHERE b.balance > a.balance				
		
		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT				
		
		IF @totalSubParlay <= @ThreadHold
		BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
                @IsLockingByRefno = 1
                ,@Session = @Session
                ,@IsReleased = 1
		END
		ELSE
		BEGIN
			------ release Parlay procesee	
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsExistParlay = 1			
				,@IsReleased	= 1		
		END	
			
		--1. Table return error code/ msg
		SELECT @ErrCode AS ErrorCode
			  ,@ErrMsg AS ErrorMsg
		      ,@SettledMainTranIds AS SettledMainTranIds
			  ,@NegativeBalanceUsers AS NegativeBalanceUsers

		--> Data for sending mail: Rule R1 + Rule R2 + Rule R3 + Rule R4
		DECLARE @IsITAdmin BIT = 0
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
			
		SELECT	t.SubTransID     
				 ,t.SubBetCheck  
				 ,t.SubOdds      
				 ,t.SubBetTeam  
				 ,t.SubBetType     
				 ,t.SubHdp1       
				 ,t.SubHdp2 
				 ,t.SubTransDesc 
				 ,t.SubLivehomescore   
				 ,t.SubLiveawayscore 
				 ,t.SubLiveindicator
				 ,t.SubHomeID
				 ,t.SubAwayID
				 ,t.SubSportType 
				 ,t.SubLeagueID     			 
				 ,SUBSTRING(T1.GroupName, 3, 30) AS GroupName			 
				 ,t.transid    
				 ,t.UserName    
				 ,t.TransDate     
				 ,t.BetType    
				 ,t.Refno     
				 ,t.[Status]     
				 ,t.WinLost    
				 ,t.betid     
				 ,t.BetTeam    			 
				 ,t.Stake     
				 ,t.Odds     			   
				 ,t.hdp1     
				 ,t.hdp2			     
				 ,t.betcheck
				 ,t.ExtraInfo
				 ,t.ActualStake    			   
				 ,CASE WHEN T2.a IS NOT NULL OR (T3.a IS NOT NULL AND @IsITAdmin = 0) THEN CAST(1 AS BIT) -- Check UserID not in IT group
					ELSE CAST(0 AS BIT)
				  END AS IsCsd
				 ,CASE WHEN T3.a IS NOT NULL AND @IsITAdmin = 1 THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				  END AS IsItQa
				 ,CASE WHEN T2.a IS NOT NULL AND @IsITAdmin = 1 THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)							
				  END AS IsItSupport
				 ,t.betfrom AS BetFrom
				 ,CURRENT_TIMESTAMP AS [DateTime]
				 ,t.matchid
		FROM @tblRecoverBet t
			LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
				   ON t.custid = f.CustID
			CROSS APPLY (SELECT CASE
									WHEN f.CustID IS NULL
										AND t.username <> '12EU'
										AND t.IsDeposit = 0
										AND t.mrecommend NOT IN (105181, 118473, 105183) -- MHC
										AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet, 1E, 8RM
										AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
											THEN '0-Credit' --1. For Normal bets
									WHEN t.recommend = 52466
											THEN '1-8RM' ----2: For 8RM
									WHEN f.CustID IS NULL -- Betdaq
										AND t.username <> '12EU' 
										AND t.IsDeposit = 1	
										AND t.mrecommend NOT IN (105181, 118473, 105183)
										AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet: 11196380, 1E: 13423967, 8RM: 52466
										AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
											THEN '2-Deposit' ----3. For Deposit bets
									WHEN t.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
											THEN '3-BetFair' ----8: For Betfair
									ELSE NULL
							    END AS GroupName) AS T1	
			OUTER APPLY (SELECT TOP 1 1 AS a
						 FROM CustDB.dbo.Customer c WITH(NOLOCK) 
						 WHERE c.currency <> 20 
						   AND c.roleid = 4 
						   AND c.custid = t.srecommend) AS T2
			OUTER APPLY (SELECT TOP 1 1 AS a
						 FROM CustDB.dbo.Customer c WITH(NOLOCK) 
						 WHERE c.currency = 20 
						   AND c.roleid = 4 
						   AND c.custid = t.srecommend) AS T3						   							    							
		WHERE T1.GroupName IS NOT NULL
		ORDER BY T1.GroupName, t.transid			 
	END TRY
	BEGIN CATCH
		IF @totalSubParlay <= @ThreadHold
		BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
                @IsLockingByRefno = 1
                ,@Session = @Session
                ,@IsReleased = 1
		END
		ELSE
		BEGIN
			------ release Parlay procesee	
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsExistParlay = 1			
				,@IsReleased	= 1		
		END		  
	
		SELECT @ErrCode = 100,@ErrMsg = 'Unable to recover these parlay bets'						
		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg 					
		RETURN				
	END CATCH		  		  	  
	
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN     
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END      
	END TRY
	BEGIN CATCH
	END CATCH

	DROP TABLE #tblMainTicket
	DROP TABLE #tblMatchParlayProcess
END
