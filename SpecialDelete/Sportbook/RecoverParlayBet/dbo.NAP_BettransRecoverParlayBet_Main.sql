/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransRecoverParlayBet_Main] 
	@BetType				VARCHAR(20)		= 'All',
	@TransIds				VARCHAR(MAX)	= '',
	@UserId					INT, 
	@IP						VARCHAR(50),

	@SettledMainTranIds		VARCHAR(MAX)	= ''	OUTPUT,
	@NegativeBalanceUsers	VARCHAR(MAX)	= ''	OUTPUT,
	@ErrCode				INT				= 0		OUTPUT,
	@ErrMsg					VARCHAR(300)	= ''	OUTPUT
AS
/*
	Created: Elodie
	Date: 20161017
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161104@Kent: Correct logic for GroupName [Redmine:#65531]
		- 20161111@Kent: Correct WinLost when for returned table [Redmine:#65531]
		- 20161221@Kathy: Release lock after recovering tickets [Redmine:#68960]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20170727@Kathy: Update statuswinlost, creator when recover [Redmine:#80135]
		- 20171106@Kent: Implement Notifications Center [Redmine:#84330]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20190719@Raymond.Le: Extend days recover ticket unlimited [#115376]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		
	Example: 
		DECLARE @ErrCode INT, @ErrMsg VARCHAR(300)
		EXEC NAP_BettransRecoverParlayBet_Main @BetType = 'All', @TransIds = '10094287060761,10094287060762,10094287060763,10094287060764', @UserID = 8, @ErrCode = @ErrCode OUTPUT, @ErrMsg = @ErrMsg OUTPUT
		SELECT ErrCode, @ErrMsg

	Param's Explanation:			
		- @BetType: 'all': All
					'Mix Parlay': Mix Parlay
					'System Parlay': System Parlay
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LogData			VARCHAR(MAX)
			,@RowNumber			INT	= 1
			,@tmp_TransIds		VARCHAR(MAX)
			,@refnos_29			VARCHAR(MAX)
			,@CustIds			VARCHAR(MAX) = ''
			,@tmp_MatchId		INT
			,@MatchDate			DATETIME
			,@IsITAdmin			BIT = 0
			,@AvaiableProcess	BIT
			,@Movebetdate		DATETIME

	DECLARE @tblTransIds TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @tblNoResettleTransIds TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @beforeDaysNum INT = 2

	CREATE TABLE #tblRecoverBet( transid		BIGINT
								,matchid		INT
								,refno			BIGINT 
								,custid			INT
								,mrecommend		INT
								,recommend		INT
								,isdeposit		BIT
								,winlostdate    SMALLDATETIME
								)
	CREATE INDEX IX_RecoverBet ON #tblRecoverBet (refno)
	
	DECLARE @tblMatchIds		TABLE ( RowNumber		INT 										
										,matchid		INT
										,transid		BIGINT
										,refno			BIGINT
								)								
											
	DECLARE @tblBeforeBalance	TABLE (custid INT, balance MONEY)
	DECLARE @tblAfterBalance	TABLE (custid INT, balance MONEY)		
	
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
		--Transid which user input
		INSERT INTO @tblTransIds
		SELECT val
		FROM dbo.strSplit(@TransIds, ',') 

		--Transid list is recovered
		INSERT INTO #tblRecoverBet (
					transid
					,matchid
					,refno
					,custid
					,mrecommend
					,recommend
					,isdeposit
					,winlostdate
		)
		SELECT	b.transid
				,b.matchid
				,b.refno
				,b.custid
				,b.mrecommend
				,b.recommend
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end AS isdeposit
				,b.winlostdate
		FROM	@tblTransIds s 
			INNER JOIN bettrans b WITH(NOLOCK) ON s.transid = b.transid
		WHERE b.matchid = 29 AND b.bettype = 29
			AND b.statusid = 102
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

		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

		IF EXISTS (SELECT TOP 1 1 FROM #tblRecoverBet WHERE winlostdate <= @Movebetdate)
		BEGIN
			------ release Parlay procesee	
			EXEC [dbo].[NAP_Admin_CheckingProcess]
					@IsExistParlay = 1			
				  , @IsReleased	= 1	

			SELECT @ErrCode = 102
				 , @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

			RETURN		  		
		END

		INSERT INTO @tblNoResettleTransIds (transid)
		SELECT t.transid
		FROM dbo.bettransm b WITH(NOLOCK) 
			INNER JOIN #tblRecoverBet t ON t.refno = b.refno
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid		
		GROUP BY t.transid
		HAVING COUNT(CASE WHEN m.eventstatus <> 'completed' THEN 1 ELSE NULL END) -- count running subs for each main ticket
			   = COUNT(*) -- count all subs for each main ticket

		-- Get match list
		SELECT	ROW_NUMBER() OVER (PARTITION BY t.transid ORDER BY m.eventdate DESC) AS RowNumber,
				b.matchid, t.transid, t.refno
		INTO #tmpMatch
		FROM	dbo.bettransm b WITH(NOLOCK) 
			INNER JOIN #tblRecoverBet t ON t.refno = b.refno	
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid			
		WHERE NOT EXISTS (SELECT 1 FROM @tblNoResettleTransIds WHERE transid = t.transid)

		-- Match list is auto settled
		INSERT INTO @tblMatchIds (RowNumber, matchid, transid, refno)
		SELECT	DENSE_RANK() OVER (ORDER BY t.matchid) AS RowNumber,
				t.matchid, t.transid, t.refno
		FROM	#tmpMatch t
		WHERE RowNumber = 1

		---- capture balance before recover
		INSERT INTO @tblBeforeBalance (custid, balance)
		SELECT	b.custid
				,SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM	bettrans b WITH (NOLOCK)
			INNER JOIN #tblRecoverBet t ON b.transid = t.transid
		GROUP BY b.CustID
		---- end capture
	
		UPDATE	b WITH(ROWLOCK, UPDLOCK)
		SET status = 'running'
			,statusID = 0
			,ruben = 0
			,modds = 0
			,winlost = 0
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0		
			,statuswinlost = NULL
			,creator = b.custid
		FROM dbo.bettrans b
			INNER JOIN #tblRecoverBet t ON b.transid = t.transid

		WHILE (1 = 1)
		BEGIN
			SELECT	TOP 1 @tmp_MatchId = matchid
			FROM	@tblMatchIds
			WHERE	RowNumber = @RowNumber
		
			IF @@rowcount = 0
				BREAK		
		
			SET @RowNumber = @RowNumber + 1
		
			SELECT  @MatchDate = eventdate
			FROM	dbo.match WITH(NOLOCK)
			WHERE	matchid = @tmp_MatchId

			SELECT @tmp_TransIds = ''
			SELECT  @tmp_TransIds = @tmp_TransIds + CONVERT(VARCHAR(20), transid) + ','
			FROM	@tblMatchIds
			WHERE	matchid = @tmp_MatchId

			SELECT @refnos_29 = ''
			SELECT 	@refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
			FROM	@tblMatchIds
			WHERE	matchid = @tmp_MatchId

			SET @refnos_29 = STUFF(@refnos_29,1,1,'')
		
			EXEC dbo.NAP_Admin_Calculate_MP_broker 
				@matchid = @tmp_MatchId
				,@mode = 'PRECAL-29'
				,@matchdate = @matchdate
				,@strXML = @tmp_TransIds

			EXEC dbo.NAP_Admin_Calculate_MP_broker
					@matchdate = @MatchDate
					,@strXML	= @refnos_29
					,@mode		= '29' 
		END

		-- capture after recover
		INSERT INTO @tblAfterBalance (custid, balance)
		SELECT	b.custid
				,SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM	bettrans b WITH (NOLOCK)
			INNER JOIN #tblRecoverBet t ON b.transid = t.transid
		GROUP BY b.CustID
	
		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
	
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
	
		-- end capture

		--> Build list of customer name with negative balance
		SET @NegativeBalanceUsers = ''
		SELECT @CustIds = @CustIds +
						  CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + 
						  CONVERT(VARCHAR(20), b.custid)
		FROM @tblBeforeBalance b
			 INNER JOIN	@tblAfterBalance a ON a.custid = b.custid 
		WHERE b.balance > a.balance				
		
		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT	
		
		DELETE	z
		FROM	dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblRecoverBet t  ON	z.custid = t.custid AND z.matchid = t.matchid AND z.transid = t.transid

		------ release Parlay procesee	
		EXEC [dbo].[NAP_Admin_CheckingProcess]
				@IsExistParlay = 1			
			  , @IsReleased	= 1	

		SELECT @LogData = 'Recover Parlay bets having transid: IP=' + @Ip + ' ' + @TransIds				
		EXEC WriteLog_UserLog 
			 @UserId = @UserId,
			 @Doing = @LogData 

		--transid is auto settled
		SELECT @SettledMainTranIds = ''
		SELECT  @SettledMainTranIds = @SettledMainTranIds + ',' + CONVERT(VARCHAR(20), b.transid) 
		FROM	bettrans b (NOLOCK)
				INNER JOIN #tblRecoverBet t
						ON b.transid = t.transid
		WHERE b.statusID IN (111, 112, 113, 103)						

		SET @SettledMainTranIds = STUFF(@SettledMainTranIds,1,1,'')
		
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
		
		SELECT	CASE WHEN c.currency <> 20 AND @IsITAdmin = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsITSupport -- Recover real tickets by IT ==> Send mail with recipient list "IT Support"
				,CASE WHEN c.currency <> 20 OR (c.currency = 20 AND @IsITAdmin = 0 )THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsCSD --Recover real tickets => send mail to CSD , Recover UUS tickets by CSD: send mail CSD
				,CASE WHEN c.currency = 20 AND @IsITAdmin = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsITQA -- Recover UUS tickets by IT => Send mail with recipient list "IT QA"
				,SUBSTRING(T1.GroupName, 3, 30) AS GroupName
				,b.transid    
				,b.Username
				,TransDate     
				,BetType    
				,b.Refno     
				,Status     
				,WinLost - stake AS WinLost    
				,betid      
				,BetTeam    
				,livehomescore    
				,liveawayscore    
				,Stake     
				,Odds     
				,hdp1     
				,hdp2     
				,NULL AS homeid      
				,NULL AS awayid      
				,NULL AS sporttype     
				,NULL AS leagueid     
				,betcheck    
				,transdesc   
				,'' AS BetFrom
				,GETDATE() AS [DateTime]
				,b.ExtraInfo
				,b.actual_stake AS ActualStake
		FROM	#tblRecoverBet t
				INNER JOIN bettrans b WITH (NOLOCK) ON b.transid = t.transid
				INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = b.srecommend
				LEFT JOIN dbo.f_GetBetDaqCustomer(1) f
					   ON t.custid = f.CustID
				CROSS APPLY (SELECT CASE
										WHEN f.CustID IS NULL
											AND b.username <> '12EU'
											AND t.IsDeposit = 0
											AND t.mrecommend NOT IN (105181, 118473, 105183) -- MHC
											AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet, 1E, 8RM
											AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
												THEN '0-Credit' --1. For Normal bets
										WHEN t.recommend = 52466
												THEN '1-8RM' ----2: For 8RM
										WHEN f.CustID IS NULL -- Betdaq
											AND b.username <> '12EU' 
											AND t.IsDeposit = 1	
											AND t.mrecommend NOT IN (105181, 118473, 105183)
											AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet: 11196380, 1E: 13423967, 8RM: 52466
											AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
												THEN '2-Deposit' ----3. For Deposit bets
										WHEN t.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
												THEN '3-BetFair' ----8: For Betfair
										ELSE NULL
									END AS GroupName) AS T1				
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
END