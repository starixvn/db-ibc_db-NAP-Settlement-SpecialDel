ALTER PROCEDURE [dbo].[NAP_VoidMetricGaming_Del]
	@MatchId			INT,
	@BetTypes			VARCHAR(1000)	= '',		
	@Event801			VARCHAR(2000) 	= '',--801 
	@Event803			VARCHAR(2000) 	= '',--803 	
	@Event804			VARCHAR(2000) 	= '',--804 
	@Event805			VARCHAR(2000) 	= '',--805
	
    @UserName 			NVARCHAR(50),
    @UserPassword		NVARCHAR(50),
    @UserID				INT,
    @IP					VARCHAR(15)		= '',
    @Reason				NVARCHAR(500)	= '',	
	@SecondAcceptFlag	TINYINT			= 0 ,
    
	@TransIds			VARCHAR(MAX) 	,

	@ErrMsg				NVARCHAR(200)	= ''	OUTPUT,
    @ErrCode			INT				= 0		OUTPUT

AS
	/*
	Created by: 20150629@Dominic
	Task : Special Delete
	DB: DBTXN/bodb02
	Original:

	Revisions:
			  - 20150806@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]
			  - 20151103@Kathy: Enhance performance [Redmine:#43233]
              - 20151209@Kathy: get translog.siteid for MG API [Redmine:#49019]
			  - 20150712@Kathy: Database - Change datatype [Redmine: #48660]
			  - 20160401@Bobby: #55354 - Update changes for new message structure
			  
	Param's Explanation:


	*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @LogData	NVARCHAR(500)
			,@Remark	VARCHAR(500)		
			,@avaiableProcess BIT = 0
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
				
	-- Check password	
	IF NOT EXISTS (SELECT 1
					FROM custDB.dbo.customer WITH(NOLOCK)
					WHERE userpwd = @UserPassword
						AND custid = @UserID
						AND roleid>=5)
	BEGIN
		SELECT @LogData ='fail to void MG bet for matchid ' + CONVERT(VARCHAR(20), 
			@MatchId) 
			+ ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) 
			+ ' reason: ' + @Reason
			
		EXEC WriteLog_UserLog 
			@UserID = @UserID, 
			@Doing	= @LogData
			
		SELECT @ErrMsg = 'Sorry. You can not process void bet due to either wrong password or insufficient permission!'
			,@ErrCode  = 101   
		
		RETURN
	END
	-------------------		
	CREATE TABLE #BetDelete (
		transid				BIGINT PRIMARY KEY, 
		refno				BIGINT,
		custid				INT, 
		actual_stake		MONEY,
		recommend			INT, 
		mrecommend			INT, 
		srecommend			INT, 
		betfrom				NVARCHAR(1),
		statusID			INT, 
		status				NVARCHAR(10), 
		SecAcceptFlag		BIT, 
		username			VARCHAR(30),
		creator				INT,
		hdp1 				SMALLMONEY,  
		hdp2 				SMALLMONEY,
		bettype 			SMALLINT, 
		betteam 			NVARCHAR(10),
		betcheck			NVARCHAR(50),
		odds				MONEY, 
		OddsType			INT,
		transdate			DATETIME,
		IsLiveIndicator		BIT,
		livehomescore 		SMALLINT, 
		liveawayscore 		SMALLINT,
		Stake				MONEY,
		CurrencyName		VARCHAR(10),
		betid				BIGINT,
		transdesc			NVARCHAR(300),
		creatorName			VARCHAR(30),
		site				VARCHAR(10),
		username2			VARCHAR(50)
		)

	DECLARE @Event801Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event801Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event801, '^')
	
	DECLARE @Event803Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event803Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event803, '^')
	
	DECLARE @Event804Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event804Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event804, '^')
	
	DECLARE @Event805Tbl TABLE(Custom1 VARCHAR(50))
	INSERT @Event805Tbl(Custom1)
	SELECT val FROM dbo.strSplit(@Event805, '^')

	DECLARE @tblBettype TABLE (bettype SMALLINT)
	INSERT INTO @tblBettype(bettype)
	SELECT val FROM dbo.strSplit(@BetTypes, '^')
	
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)

	BEGIN TRY
		INSERT INTO #tblTransIds
		SELECT CONVERT(BIGINT, val) FROM dbo.strSplit(@TransIds, ',')
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 101, @ErrMsg = 'Invalid TransIds.'
		
		RETURN
	END CATCH
	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT @MatchId AS matchid
		, 3 AS KeyID
	
	-- check and not allow attempt to void tickets of this match while it's being calculated
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMG			= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		RETURN
		
	---------------***** Insert all data into #BetDelete *****------------------
	-- ticket in bettrans (<> running)
	INSERT INTO #BetDelete(
			transid			
			,refno			
			,custid			
			,actual_stake	
			,recommend		
			,mrecommend		
			,srecommend		
			,betfrom			
			,statusID		
			,status			
			,SecAcceptFlag			
			,creator			
			,hdp1 			
			,hdp2 			
			,bettype 		
			,betteam 		
			,betcheck		
			,odds			
			,OddsType		
			,transdate		
			,IsLiveIndicator	
			,livehomescore 	
			,liveawayscore 	
			,Stake			
			,CurrencyName	
			,betid			
			,transdesc		
	)
	SELECT	b.transid
			,b.refno
			,custid
			,b.actual_stake
			,recommend
			,mrecommend
			,srecommend
			,betfrom
			,statusID
			,STATUS
			,SecAcceptFlag
			,b.creator
			,b.hdp1
			,b.hdp2
			,b.bettype
			,b.betteam
			,b.betcheck
			,b.odds
			,b.oddstype
			,b.transdate
			,b.liveindicator
			,b.livehomescore
			,b.liveawayscore
			,b.stake
			,b.CurrencyName
			,b.betid
			,b.transdesc
	FROM	dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #tblTransIds t
			ON	b.refno = t.transid
	WHERE	b.matchid = @matchid
			AND b.bettype IN (SELECT bettype FROM @tblBettype)
			AND b.statusID NOT IN (0, 101,102 ) -- running, reject, void
			AND 1 = CASE WHEN b.Bettype IN (801,803,804,805) THEN CASE 
									WHEN b.Bettype = 801
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event801Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									WHEN b.Bettype = 803
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event803Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									WHEN b.Bettype = 804
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event804Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									WHEN b.Bettype = 805
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event805Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									ELSE 0
									END
						ELSE 1
						END
	
	-- running ticket in translog
	INSERT INTO #BetDelete(
			transid			
			,refno			
			,custid			
			,actual_stake	
			,recommend		
			,mrecommend		
			,srecommend		
			,betfrom			
			,statusID		
			,status			
			,SecAcceptFlag	
			,creator			
			,hdp1 			
			,hdp2 			
			,bettype 		
			,betteam 		
			,betcheck		
			,odds			
			,OddsType		
			,transdate		
			,IsLiveIndicator	
			,livehomescore 	
			,liveawayscore 	
			,Stake			
			,CurrencyName	
			,betid			
			,transdesc		
	)
	SELECT	b.translogid transid
			,b.translogid refno
			,b.custid
			,b.actual_stake
			,b.recommend
			,b.mrecommend
			,b.srecommend
			,b.betfrom
			,b.statusID
			,b.STATUS
			,NULL SecAcceptFlag		
			,b.creator
			,0 hdp1
			,0 hdp2
			,b.gameid
			,NULL betteam
			,NULL betcheck
			,b.odds
			,b.custom1 oddstype
			,b.transdate
			,b.liveindicator
			,NULL livehomescore
			,NULL liveawayscore
			,b.stake
			,b.CurrencyName
			,NULL betid
			,b.transdesc
	FROM	dbo.translog b WITH (NOLOCK)
		INNER JOIN #tblTransIds t
			ON	b.translogid = t.transid
	WHERE	b.EventID=@MatchId 
			AND b.gameID IN (SELECT bettype FROM @tblBettype)
			AND b.gameid IN (801,803,804,805,806)
			AND b.statusID = 0
			AND 1 = CASE WHEN b.GameID IN (801,803,804,805) THEN CASE 
									WHEN b.GameID = 801
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event801Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									WHEN b.GameID = 803
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event803Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									WHEN b.GameID = 804
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event804Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									WHEN b.GameID = 805
										AND EXISTS(
												SELECT TOP 1 1
												FROM @Event805Tbl rs
												WHERE ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0
											)
										THEN 1
									ELSE 0
									END
						ELSE 1
						END	 
	------------------***** End of insert all data into #BetDelete *****------------------
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)
	BEGIN
				
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'
			
	END		
	ELSE
	BEGIN
		------------------***** Begin Special Delete *****------------------
		--*****MGSL PROCESS - START
			--Insert ticket of MGSL in translog: 801,803,804,805,806
		CREATE TABLE #BeforeUpd (custid	INT, balance MONEY)		
		CREATE TABLE #AfterUpd(custid INT, balance MONEY)

		DECLARE @tblDebitPending TVP_BalanceList
		DECLARE @tblCreditPending TVP_BalanceList
		
		INSERT INTO [dbo].[bettrans]
			   ([custid]
			   ,[transdate]
			   ,[oddsid]
			   ,[hdp1]
			   ,[hdp2]
			   ,[odds]
			   ,[stake]
			   ,[status]
			   ,[winlost]
			   ,[awinlost]
			   ,[mwinlost]
			   ,[playercomm]
			   ,[comm]
			   ,[acomm]
			   ,[apositiontaking]
			   ,[mpositiontaking]
			   ,[tpositiontaking]
			   ,[playerdiscount]
			   ,[discount]
			   ,[adiscount]
			   ,[livehomescore]
			   ,[liveawayscore]
			   ,[liveindicator]
			   ,[betteam]
			   ,[creator]
			   ,[refno]
			   ,[comstatus]
			   ,[winlostdate]
			   ,[betfrom]
			   ,[betcheck]
			   ,[checktime]
			   ,[oddsspread]
			   ,[actualrate]
			   ,[matchid]
			   ,[recommend]
			   ,[mrecommend]
			   ,[ruben]
			   ,[betid]
			   ,[statuswinlost]
			   ,[modds]
			   ,[bettype]
			   ,[betdaqid]
			   ,[actual_stake]
			   ,[currency]
			   ,[ip]
			   ,[transdesc]
			   ,[sdiscount]
			   ,[scomm]
			   ,[spositiontaking]
			   ,[swinlost]
			   ,[srecommend]
			   ,[Username]
			   ,[CurrencyName]
			   ,[virtualrate]
			   ,[oddstype]
			   ,[statusID]
			   ,[currency2]
			   ,[balance]
			   ,[SecAcceptFlag]
			   ,[transid2]
			   ,[RecommDate])
		SELECT  b.[custid]
			   ,b.[transdate]
			   ,0 [oddsid]
			   ,0 [hdp1]
			   ,0 [hdp2]
			   ,b.[odds]
			   ,b.[stake]
			   ,b.[status]
			   ,0 [winlost]
			   ,0 [awinlost]
			   ,0 [mwinlost]
			   ,0 [playercomm]
			   ,0 [comm]
			   ,0 [acomm]
			   ,b.[apositiontaking]
			   ,b.[mpositiontaking]
			   ,b.[tpositiontaking]
			   ,b.[playerdiscount]
			   ,b.[discount]
			   ,b.[adiscount]
			   ,0 [livehomescore]
			   ,0 [liveawayscore]
			   ,b.[liveindicator]
			   ,SUBSTRING(b.[transdesc],11,CHARINDEX(';BettypeTime',b.[transdesc],0) - 11) [betteam]
			   ,b.[creator]
			   ,b.translogid [refno]
			   ,b.custom2 [comstatus]
			   ,b.[winlostdate]
			   ,b.[betfrom]
			   ,b.transdate [betcheck]
			   ,NULL [checktime]
			   ,0 [oddsspread]
			   ,b.[actualrate]
			   ,b.EventID
			   ,b.[recommend]
			   ,b.[mrecommend]
			   ,1 [ruben]
			   ,CASE WHEN ISNULL(b.custom3,'') = '' THEN NULL ELSE CAST(b.custom3 AS BIGINT) END [betid]
			   ,NULL [statuswinlost]
			   ,0 [modds]
			   ,b.GameID [bettype]
			   ,NULL [betdaqid]
			   ,b.[actual_stake]
			   ,b.[currency]
			   ,b.[ip]
			   ,b.[transdesc]
			   ,b.[sdiscount]
			   ,0 [scomm]
			   ,b.[spositiontaking]
			   ,0 [swinlost]
			   ,b.[srecommend]
			   ,b.[Username]
			   ,b.[CurrencyName]
			   ,b.[virtualrate]
			   ,b.custom1 [oddstype]
			   ,b.[statusID]
			   ,NULL [currency2]
			   ,b.[balance]
			   ,0 [SecAcceptFlag]
			   ,0 [transid2]
			   ,NULL [RecommDate]
		FROM	dbo.translog b WITH(NOLOCK)
			INNER JOIN #BetDelete tmp
				ON b.translogid = tmp.transid
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE refno = b.translogid AND matchid = b.eventID)
				AND b.GameID IN (801, 803, 804, 805,806)		
			
		 --Update new transid
		UPDATE	tmpmain
			SET	tmpmain.TransID = main.TransID
		FROM	#BetDelete tmpmain
			INNER JOIN dbo.bettrans main WITH(NOLOCK) 
				ON	main.refno = tmpmain.refno 
					AND main.matchid = @matchid
					AND main.Bettype IN (801, 803, 804, 805,806)
		
		-- Step 1: backup
		INSERT INTO zzzbettrans (
				transid
				,custid
				,transdate
				,oddsid
				,hdp1
				,hdp2
				,odds
				,stake
				,STATUS
				,winlost
				,livehomescore
				,liveawayscore
				,liveindicator
				,betteam
				,creator
				,refno
				,winlostdate
				,betfrom
				,betcheck
				,checktime
				,matchid
				,bettype
		)
		SELECT	b.transid
				,b.custid
				,CURRENT_TIMESTAMP
				,b.oddsid
				,b.hdp1
				,b.hdp2
				,b.odds
				,b.stake
				,b.STATUS
				,b.winlost
				,b.livehomescore
				,b.liveawayscore
				,b.liveindicator
				,b.betteam
				,b.creator
				,b.refno
				,b.winlostdate
				,b.betfrom
				,b.betcheck
				,b.checktime
				,b.matchid
				,b.bettype
		FROM	dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #BetDelete tmp
				ON b.transid = tmp.transid
			
		-- get balance	
		INSERT INTO #BeforeUpd (custid, balance)
		SELECT t.custid, SUM(t.winlost - t.actual_stake + t.playercomm) balance
		FROM(
			SELECT	b.custid, b.winlost, b.actual_stake, b.playercomm
			FROM	bettrans b WITH (NOLOCK)
				INNER JOIN #BetDelete tmp
					ON b.transid = tmp.transid
			WHERE tmp.statusID <> 0
			UNION ALL
			SELECT	tl.custid, 0, tl.actual_stake, 0
			FROM	dbo.translog tl
				INNER JOIN #BetDelete tmp
					ON	tl.translogid = tmp.refno
			WHERE	tmp.statusID = 0
			) t
		GROUP BY t.custid
			
		-- STEP 2 : Update
		UPDATE	main
			SET actual_stake = tl.actual_stake
				,winlost = tl.actual_stake
				,ruben = 1
				,statuswinlost = 6
				,creator = @UserID
				,awinlost = 0
				,mwinlost = 0
				,swinlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,statusID = 102
				,status = 'VOID'
				,betid = CASE WHEN main.Bettype IN (801,803,804,805,806) AND main.BetID IS NULL THEN (	
										SELECT rs.ResultID 
										FROM DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK) 
										WHERE (
												(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, main.transdesc,0) <> 0)
												OR
												main.bettype = 806
											)
											AND rs.GameID = main.bettype	
											AND rs.VendorID = 5		
											AND rs.MatchID = main.matchid			
								)
								ELSE main.betid
								END
		FROM	dbo.bettrans AS main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #BetDelete AS tmpmain
				ON	main.transid = tmpmain.transid
			INNER JOIN dbo.translog tl WITH(NOLOCK)
				ON	main.refno = tl.translogid
				
		-- 2.2. Update translog
		UPDATE	tl
			SET
				tl.Status = 'VOID',
				tl.StatusID = 102,
				tl.creator = @UserID,
				tl.custom3 = case 
								when ISNULL(tl.Custom3,'') = '' then 
									(SELECT rs.ResultID 
									FROM 	DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK) 
									WHERE (
											(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, tl.transdesc,0) <> 0)
											OR
											tl.GameID = 806
											)
											AND rs.GameID = tl.GameID	
											AND rs.VendorID = 5		
											AND rs.MatchID = tl.EventID			
									) 
								else tl.custom3
								end
		FROM	dbo.translog tl WITH(ROWLOCK,UPDLOCK)
			inner join #BetDelete main
				on tl.translogid = main.refno
					and tl.eventid = @matchid
					and tl.gameid in (801,803,804,805,806)
					
		--Get data after update
		INSERT INTO #AfterUpd (custid, balance)
		SELECT	b.custid, SUM (b.winlost - b.actual_stake + b.playercomm) balance
		FROM	bettrans b WITH (NOLOCK)
		WHERE	b.transid IN (SELECT transid FROM #BetDelete)
		GROUP BY b.CustID

		INSERT INTO @tblCreditPending (custID, balance)
		SELECT		a.custid, (a.balance - b.balance) as Balance
		FROM		#BeforeUpd b
		INNER JOIN	#AfterUpd a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) > 0	
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns 
				@BalancePending = @tblCreditPending
				,@Type			= 4 -- Others
		
		INSERT INTO @tblDebitPending (custID, balance)
		SELECT		a.custid, ABS(a.balance - b.balance) as Balance
		FROM		#BeforeUpd b
		INNER JOIN	#AfterUpd a 	
				ON	a.custid = b.custid
		WHERE	    (a.balance - b.balance) < 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending
				,@Type			= 4 -- Others
				
	------------------***** End of Special Delete *****------------------

		SELECT @LogData ='void MG bet for matchid ' + CONVERT(VARCHAR(20), @MatchId) 
				+ ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) 
				+ ' reason: ' + @Reason

		EXEC WriteLog_UserLog 
			@UserID = @UserID
			,@Doing = @LogData

		-- Match info
		SELECT MATCH.homeid,
			MATCH.awayid,
			MATCH.matchcode,
			MATCH.eventdate,
			MATCH.leagueid,
			GETDATE() AS DATETIME,
			ISNULL(MATCH.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			0 AS IsOutright
		FROM
			MATCH WITH (NOLOCK)
		WHERE 
			MATCH.matchid = @MatchId

		
		-- Output new message structure
		DECLARE @isITAdmin BIT 
		
		-- CHECK IT GROUP or NOT ?   
		IF EXISTS (SELECT TOP 1 1 FROM DBPOLICY.bodb02.dbo.accCustomer_1 a WHERE a.GroupID = 1 AND a.custid = @UserID) -- Check UserID in IT group
		BEGIN  
			SELECT @isITAdmin = 1   
		END  		
		
		;WITH CTE_CustIdAll AS (
			SELECT DISTINCT t.custid
			FROM #BetDelete b
			CROSS APPLY (
				VALUES (custid)
				,(creator)
				,(recommend)
				,(mrecommend)
				,(srecommend)
			) AS t (custid)
		), CTE_CustInfo AS (
			SELECT ci.custid
				, ci.username
				, ci.username2
				, ci.site
				, ci.currency
			FROM CustDB.dbo.Customer ci WITH(NOLOCK)
				INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid
			
		)
		SELECT	b.custid
			,b.actual_stake winlost
			,b.odds
			,b.OddsType
			,b.transdate
			,b.bettype
			,b.betfrom
			,b.transid
			,b.refno
			,b.betteam
			,b.betcheck
			,b.hdp1
			,b.hdp2
			,b.betfrom
			,b.isLiveIndicator
			,b.livehomescore
			,b.liveawayscore
			,b.stake
			,b.CurrencyName
			,b.STATUS
			,b.SecAcceptFlag
			,b.betid
			,b.transdesc
			,b.recommend
			,b.mrecommend
			,b.srecommend
			-----------------------------
			,ci.currency
			,ci.username
			,ci.username2
			,cr.username AS creator
			,ci.username AS CustUserName
			,ci.username2 as CustUserName2
			,ag.UserName AS AgUserName
			,ma.UserName AS MagUserName
			,su.Username AS SagUserName
			---------------------------------------
			,CASE 
				WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
				ELSE su.site 
			END AS EmailGroup
			,su.site 
			,CASE WHEN s.custid IS NOT NULL THEN 1 ELSE 0 END AS IsDeposit
			,@isITAdmin	AS IsITSupport
			
		FROM #BetDelete b WITH (NOLOCK)
			INNER JOIN CTE_CustInfo ci WITH(NOLOCK)
				ON b.custid = ci.custid
			INNER JOIN CTE_CustInfo cr WITH(NOLOCK)
				ON b.creator = cr.custid	
			INNER JOIN CTE_CustInfo ag WITH(NOLOCK)
				ON b.recommend = ag.custid
			INNER JOIN CTE_CustInfo ma WITH(NOLOCK)
				ON b.mrecommend = ma.custid
			INNER JOIN CTE_CustInfo su WITH(NOLOCK)
				ON b.srecommend = su.custid
			LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) 
				ON b.srecommend = s.custid
		
		ORDER BY b.transid
		
		 --Metric API Calling  
		SELECT	tmp.refno 
				,tmp.Bettype
				,tmp.custid
				,b.statusid
				,b.winlost
				,tmp.odds
				,tmp.oddstype
				,tmp.stake
				,tmp.transdesc
				,tl.SiteId
		FROM	#BetDelete tmp
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	tmp.transid = b.transid
			INNER JOIN dbo.translog tl WITH(NOLOCK)
				ON tl.translogid = tmp.refno
		
		DROP TABLE #BeforeUpd
		DROP TABLE #AfterUpd

	END
	
	------ releasing SD process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMG			= 1
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess
	DROP TABLE #BetDelete

	SET NOCOUNT OFF
END
GO
GRANT EXECUTE ON [dbo].[NAP_VoidMetricGaming_Del] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_VoidMetricGaming_Del] TO [vnteam] AS [dbo]