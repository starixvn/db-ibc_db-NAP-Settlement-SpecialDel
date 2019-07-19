/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverParlayBet_Sub] 
	@UserId				INT,	
	@IP					VARCHAR(50),
	@BetType			VARCHAR(20)		= 'All',
	@MainTransIds		VARCHAR(MAX)	= '',
	@matchid			BIGINT,
	
	@SettledMainTranIds	VARCHAR(MAX) = '' OUTPUT,
	@NegativeBalanceUsers VARCHAR(MAX) = '' OUTPUT,
	@ErrCode			INT = 0	OUTPUT,
	@ErrMsg				NVARCHAR(200) = '' OUTPUT
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

	Param's Explanation:			
			- @BetType:
			'all': All
			'Mix Parlay': Mix Parlay
			'System Parlay': System Parlay
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RecoverPatchSize INT = 100
	
	DECLARE @MatchDate			DATETIME
		   ,@transids_29		VARCHAR(MAX) = ''
		   ,@refnos_29			VARCHAR(MAX) = ''
		   ,@LogData			NVARCHAR(500)
		   ,@SubTransIds		VARCHAR(MAX) = ''
		   ,@CustIds			VARCHAR(MAX) = ''
		   ,@AvaiableProcess	BIT
		   ,@RowNumber			BIGINT
	
	DECLARE @tblRecoverBet TABLE (
		 RowNumber				BIGINT IDENTITY(1, 1) PRIMARY KEY
		 
		,SubTransID				BIGINT		 
		,SubBetCheck			NVARCHAR(50)
		,SubOdds				MONEY   
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
		,Odds					MONEY		
		,hdp1					SMALLMONEY
		,hdp2					SMALLMONEY
		,betfrom				NVARCHAR(1)		
		,betcheck				NVARCHAR(50)		
	)	
	
	CREATE TABLE #tblMainTicket 
	(
		transid		BIGINT
	   ,refno		BIGINT	   
	   ,StatusId	TINYINT	   
	   ,custid		INT
	   ,balance		MONEY	   
	)
	CREATE CLUSTERED INDEX IDX_tblMainTicket_custid_transid ON #tblMainTicket(custid, transid)
	
	DECLARE @tblMainTransIds TABLE (transid BIGINT)
	
	DECLARE @tblSettledBeforeRecoveredMainTicket TABLE (transid	BIGINT)
								
	DECLARE @tblBeforeBalance TABLE (custid INT PRIMARY KEY, balance MONEY)
	
	DECLARE @tblAfterBalance TABLE (custid INT PRIMARY KEY, balance MONEY)
	
	DECLARE @tblDebitPending TVP_BalanceList
	
	DECLARE @tblCreditPending TVP_BalanceList					
	
	SELECT @ErrCode = 0
		  ,@ErrMsg = ''
		  
	--> parse @MainTransIds
	INSERT INTO @tblMainTransIds(transid)
	SELECT ss.val AS transid
	FROM dbo.strSplit(@MainTransIds, ',') ss
	
	IF @@ROWCOUNT = 0
	BEGIN		
		SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'				
		
		RETURN
	END		  
		  
	--- Check for concurrent running
	EXEC [dbo].[NAP_Admin_CheckingProcess]
			@IsExistParlay = 1			
		  , @IsReleased	= 0
		  , @AvaiableProcess = @AvaiableProcess OUTPUT
		  , @ErrCode = @ErrCode OUTPUT
		  , @ErrMsg	= @ErrMsg OUTPUT
	
	IF (@ErrCode <> 0 OR @avaiableProcess = 0)
	BEGIN					 
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
				,betcheck)
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
		FROM @tblMainTransIds t
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
					ON t.transid = b.transid
			INNER JOIN bettransm bm WITH (NOLOCK)
					ON bm.refno	= b.refno	   							
			INNER JOIN dbo.match m WITH(NOLOCK)
					ON	bm.matchid = m.matchid
		WHERE bm.matchid = @MatchId
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
			------ release Parlay procesee	
			EXEC [dbo].[NAP_Admin_CheckingProcess]
				@IsExistParlay = 1			
			  , @IsReleased	= 1			  			
			
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'						
		
			RETURN
		END										
	
		--> get list of MainTranIds	
		INSERT INTO #tblMainTicket(transid
								 , refno								 
								 , StatusId								 
								 , custid
								 , balance)
		SELECT t.transid
			 , t.refno			 
			 , t.StatusId			 
			 , t.custid
			 , t.balance			 
		FROM @tblRecoverBet t		
		
		--> capture list of settled main transIDs before do recover
		INSERT INTO @tblSettledBeforeRecoveredMainTicket(transid)
		SELECT transid
		FROM #tblMainTicket
		WHERE StatusId IN (111, 112, 113) -- 'DRAW', 'WON', 'LOSE'
				
		SELECT  @MatchDate = eventdate
		FROM	dbo.match WITH(NOLOCK)
		WHERE	matchid = @matchid				
			
		--> capture @tblBeforeBalance
		INSERT INTO @tblBeforeBalance (custid, balance)
		SELECT	t.custid
				,SUM(t.balance) balance
		FROM #tblMainTicket t					
		GROUP BY t.CustID
				  
		--> Do recover
		-- for bettransM
		SET @RowNumber = 0
		WHILE (1 = 1)
		BEGIN
			SET @SubTransIds = ''
			SELECT @SubTransIds = @SubTransIds + 
								  CASE WHEN @SubTransIds <> '' THEN ',' ELSE '' END +
								  CONVERT(VARCHAR(20), SubTransID)
			FROM @tblRecoverBet
			WHERE RowNumber BETWEEN (@RowNumber + 1) AND (@RowNumber + @RecoverPatchSize)						
			
			IF @SubTransIds = ''
				BREAK
			
			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchid = @matchid
				,@matchdate = @MatchDate
				,@mode = 'RECOVER' -- update bettransM + BetParlayDetail
				,@VoidTransID = @SubTransIds
				
			SET @RowNumber = @RowNumber + @RecoverPatchSize				
		END				
		
		SELECT @transids_29 = @transids_29 + CONVERT(VARCHAR(20), transid) + ','
			 , @refnos_29 = @refnos_29 + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid) + ','
		FROM #tblMainTicket				
			
		-- call pre-cal: betparlaydetail/betparlayresult		
		EXEC dbo.NAP_Admin_Calculate_MP_broker 
			@matchid	= @MatchId
			,@matchdate = @MatchDate
			,@strXML	= @transids_29
			,@mode		= 'PRECAL-29'
				
		-- call cal_29: re-settle for main ticket
		EXEC dbo.NAP_Admin_Calculate_MP_broker
			@matchdate = @MatchDate
			,@strXML	= @refnos_29  -- main transid + refno: refno|transid,refno|transid...
			,@mode		= '29' 
		
		--> capture @tblAfterBalance
		INSERT INTO @tblAfterBalance (custid, balance)
		SELECT	t.custid
				,SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM #tblMainTicket t	
			INNER JOIN bettrans b WITH (NOLOCK) 
				ON t.transid = b.transid		
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
		FROM	dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tblRecoverBet t 
				ON	z.custid = t.custid
					AND z.matchid = t.matchid
					AND z.transid = t.SubTransID
		
		DELETE	zm
		FROM	dbo.zzzbettransm zm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tblRecoverBet t 
				ON	zm.custid = t.custid
					AND zm.matchid = t.matchid
					AND zm.transid = t.SubTransID				
				
		--> Build list of changed status main transids that corresponding match needs to re-settle
		SET @SettledMainTranIds = ''
		IF EXISTS (SELECT TOP 1 1
				   FROM dbo.match WITH(NOLOCK)
				   WHERE matchid = @matchid
				     AND eventstatus = 'completed')
		BEGIN				   
			SELECT @SettledMainTranIds = @SettledMainTranIds + 
										 CASE WHEN @SettledMainTranIds <> '' THEN ',' ELSE '' END +
										 CONVERT(VARCHAR(20), t.transid)
			FROM @tblSettledBeforeRecoveredMainTicket t			 
				 INNER JOIN dbo.bettrans b WITH(NOLOCK)
						 ON t.transid = b.transid			 
			WHERE b.statusID = 0
		END
		
		--> Build list of customer name with negative balance
		SET @NegativeBalanceUsers = ''
		SELECT @CustIds = @CustIds +
						  CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + 
						  CONVERT(VARCHAR(20), b.custid)
		FROM @tblBeforeBalance b
			 INNER JOIN	@tblAfterBalance a 	
					 ON a.custid = b.custid
		WHERE b.balance > a.balance				
		
		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT				
		
		------ release Parlay procesee	
		EXEC [dbo].[NAP_Admin_CheckingProcess]
				@IsExistParlay = 1			
			  , @IsReleased	= 1	

		--> write log		
		SELECT @LogData = 'Recover Parlay bets having transid: IP=' + @Ip + ' ' + @transids_29
		EXEC WriteLog_UserLog 
			 @UserId = @UserId,
			 @Doing = @LogData 
			 
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
				 ,CASE
					WHEN T2.a IS NOT NULL 
						 OR (T3.a IS NOT NULL 
							 AND @IsITAdmin = 0  -- Check UserID not in IT group
							)
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				  END AS IsCsd
				 ,CASE
					WHEN T3.a IS NOT NULL 
						 AND @IsITAdmin = 1 
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				  END AS IsItQa
				 ,CASE
					WHEN T2.a IS NOT NULL 
						 AND @IsITAdmin = 1 
								THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)							
				  END AS IsItSupport
				 ,t.betfrom AS BetFrom
				 ,CURRENT_TIMESTAMP AS [DateTime]
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
		------ release Parlay procesee	
		EXEC [dbo].[NAP_Admin_CheckingProcess]
			@IsExistParlay = 1			
		  , @IsReleased	= 1		  
	
		SELECT @ErrCode = 100,
				@ErrMsg = 'Unable to recover these parlay bets'						
							
		RETURN				
	END CATCH		  		  	  
		
	RETURN;							
END