/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidOutright_Update]
	  @OutrightID			INT
	, @FromTransId			BIGINT
	, @ToTransId			BIGINT
	
    , @UserName 			NVARCHAR(50)
    , @UserPassword			NVARCHAR(50)
    , @UserID				INT
    , @IP					VARCHAR(15)		= ''
    , @Reason				NVARCHAR(500)	= ''	
    
	, @TransIds				VARCHAR(MAX)	= ''	 
		
	, @ErrMsg				NVARCHAR(200)	= ''	OUTPUT
    , @ErrCode				INT				= 0		OUTPUT    

AS
	/*
	Created by: Kent
	Task : Special Delete
	DB: DBTXN/bodb02
	Original:

	Revisions:		
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]

	Param's Explanation: Special bet delete option		
	*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE  @isITAdmin			BIT = 0					
			,@avaiableProcess	BIT = 0						
	
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)		
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)		
	
	CREATE TABLE #BetDelete 
	(
		transid bigint,
		custid int,
		username varchar(30),
		username2 varchar(50),
		odds MONEY,
		transdate datetime, 
		creator varchar(30),
		Stake money,
		currency tinyint,
		IsDeposit bit,
		site varchar(10),
		status nvarchar(10),
		srecommend int, 
		mrecommend int, 
		recommend int, 
		SagUserName varchar(30),
		MagUserName varchar(30),
		AgUserName varchar(30),
		CurrencyName nvarchar(30), 
		betfrom nvarchar(1)
	)							
	
	DECLARE  @KeyID			INT			
			,@LogData		NVARCHAR(500)
			,@CountTransId	INT
	
	SELECT @ErrCode = 0
		 , @ErrMsg = ''		 		
			
	-- Check password	
	IF NOT EXISTS (SELECT 1
					FROM custDB.dbo.customer WITH(NOLOCK)
					WHERE userpwd = @UserPassword
						AND custid = @UserID
						AND roleid>=5)
	BEGIN
		SELECT @LogData ='fail to void bet for matchid ' + CONVERT(VARCHAR(20), 
			@OutrightID) + ' from ' + CONVERT(VARCHAR(20), @FromTransId) + ' to ' + CONVERT(VARCHAR(20), @ToTransId) + ' reason: ' + @Reason
			
		EXEC WriteLog_UserLog 
			@UserID = @UserID, 
			@Doing	= @LogData
			
		SELECT @ErrMsg = 'Sorry. You can not process void bet due to either wrong password or insufficient permission!'
			,@ErrCode  = 101								  
		
		RETURN
	END	
			
	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds,',')	
		OPTION (maxrecursion 0)
		
		SET @CountTransId = @@ROWCOUNT				
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 101
				,@ErrMsg = 'Invalid TransIds.'										
		
		RETURN
	END CATCH		
	
	-- check and not allow attempt to void tickets of this match while it's being calculated
	---------------------------------------------------------------------------
	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @OutrightID AS matchid
		 , 2 		   AS KeyID
		
	-- checking SD proccess
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistOutright 	= 1		
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN	
		RETURN		
	END		

	------------------***** Insert all data into #BetDelete *****------------------				 	
	INSERT INTO #BetDelete
		(transid,
		 custid, 
		 username,
		 username2,
		 odds,
		 transdate,	
		 creator,
		 stake,
		 currency, 
		 IsDeposit,
		 site,
		 status,
		 srecommend,
		 mrecommend,
		 recommend,
		 SagUserName,
		 MagUserName,
		 AgUserName,
		 CurrencyName,
		 betfrom)
	SELECT 
		b.transid,
		b.custid, 
		b.username,
		c.username2,
		b.odds,
		b.transdate,	
		cr.username as creator,
		stake,
		b.currency, 
		CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
		ag.site,
		b.status,
		b.srecommend,
		b.mrecommend,
		b.recommend,		
		sa.Username AS SagUserName,
		ma.UserName AS MagUserName,
		ag.UserName AS AgUserName,				
		b.CurrencyName,
		b.betfrom	
	FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
		 INNER JOIN bettrans b WITH (NOLOCK) ON t.transid = b.transid
		 INNER JOIN custDB.dbo.customer sa WITH (NOLOCK) ON b.srecommend = sa.custid			
		 INNER JOIN custDB.dbo.customer ma WITH (NOLOCK) ON b.mrecommend = ma.custid
		 INNER JOIN custDB.dbo.customer ag WITH (NOLOCK) ON b.recommend = ag.custid		 		 
		 INNER JOIN custDB.dbo.customer cr WITH (NOLOCK) ON cr.custid = b.creator	
		 INNER JOIN outright o WITH(NOLOCK) ON b.matchid = o.orid
		 INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = b.custid		 		
	WHERE	
		b.bettype = 10
		and b.statusID NOT IN (101,102)
		and b.transid between @FromTransId and @ToTransId 
		and o.orid = case when @OutrightID = 0 then o.orid else @OutrightID end 
		and b.betfrom <> 'p'
	OPTION (OPTIMIZE FOR (@CountTransId = 1))					
	------------------***** End of insert all data into #BetDelete *****------------------
	--------------------------------------------------------------------------------------												
		
	 --check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)
	BEGIN				
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistOutright 	= 1			
			, @IsReleased		= 1												
	END
	ELSE
	BEGIN		
		------------------***** Begin Special Delete *****------------------		                                                                                                                                               
		DECLARE @BeforeUpd 	TVP_BalanceChange
		DECLARE @AfterUpd 	TVP_BalanceChange				
		
		-- Step 1: Backup into zzzbettrans
		-- 1.1. Backup normal, main bettrade, main cash-out, cash-out member bet ticket
		INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
					winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
					winlostdate,betfrom,betcheck,checktime,matchid, bettype)
		SELECT  main.transid, main.custid, CURRENT_TIMESTAMP, main.oddsid, main.hdp1, main.hdp2, main.odds, main.stake, main.status, 
				main.winlost, main.livehomescore, main.liveawayscore, main.liveindicator, main.betteam, main.creator , main.refno, 
				main.winlostdate, main.betfrom, 
				main.betcheck,
				main.checktime, main.matchid, main.bettype
		FROM	dbo.bettrans main WITH (nolock)
			INNER JOIN #BetDelete tmpmain 
				ON	main.transid = tmpmain.transid 					
					AND main.matchid = @OutrightID																	
			
		-- Capture balance before updating Bettrans
		INSERT INTO @BeforeUpd (custid, balance, balanceType)
		SELECT custid
			 , SUM (winlost - actual_stake + playercomm) balance
			 , 1 AS balanceType
		FROM (			
			SELECT	main.custid, main.winlost, main.actual_stake, main.playercomm
			FROM	bettrans main WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain
					ON	main.transid = tmpmain.transid						
						AND main.matchid = @OutrightID			
		) tmp
		GROUP BY custid
		
		-- Step 2: Update bettrans
		-- 2.1. Update normal, main bettrade, main cash-out, cash-out member bet ticket
		UPDATE	main
			SET winlost			= main.actual_stake
				,ruben			= 1
				,statuswinlost	= 6
				,creator		= @UserID
				,awinlost		= 0
				,mwinlost		= 0
				,swinlost		= 0
				,playercomm		= 0
				,comm			= 0
				,acomm			= 0
				,scomm			= 0
				,statusID		= 102       
				,status			= 'VOID'
		FROM	dbo.bettrans main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	main.transid = tmpmain.transid 					
					AND main.matchid = @OutrightID							
		
		-- Capture balance after updating Bettrans
		INSERT INTO @AfterUpd (custid, balance, balanceType)
		SELECT custid
			 , SUM (winlost - actual_stake + playercomm) balance
			 , 1 AS balanceType
		FROM (
			SELECT	main.custid, main.winlost, main.actual_stake, main.playercomm
			FROM	bettrans main WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain
					ON	main.transid = tmpmain.transid						
						AND main.matchid = @OutrightID
		) tmp
		GROUP BY custid

		---INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePendingIns]
			@BeforeUpd	 = @beforeUpd
			, @AfterUpd	 = @afterUpd																	
					   
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistOutright 	= 1			
			, @IsReleased		= 1					

	------------------***** End of Special Delete *****------------------
		SELECT @LogData ='void bet for matchid ' + CONVERT(VARCHAR(20), @OutrightID) 
				+ ' from ' + CONVERT(VARCHAR(20), @FromTransId) + ' to ' 
				+ CONVERT(VARCHAR(20), @ToTransId) + ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) 
				+ ' reason: ' + @Reason
				
		EXEC WriteLog_UserLog 
			@UserID = @UserID
			,@Doing = @LogData	
		
		-- Match info	
		SELECT MATCH.teamid AS homeid,
			0 AS awayid,
			MATCH.matchcode,
			MATCH.eventdate,
			MATCH.leagueid,
			GETDATE() AS DATETIME,
			CONVERT(BIT,0) AS IsNeutral,
			CAST(1 AS BIT) AS IsOutright
		FROM
			Outright AS MATCH WITH (NOLOCK)
		WHERE 
			MATCH.orid = @OutrightID															
		
		-- CHECK IT GROUP or NOT ?   
		IF EXISTS (SELECT TOP 1 1 FROM DBPOLICY.bodb02.dbo.accCustomer_1 a WHERE a.GroupID = 1 AND a.custid = @UserID) -- Check UserID in IT group
		BEGIN  
			SELECT @isITAdmin = 1   
		END  		
		
		;WITH CTE_OriginResult AS 
		(
			--0.For Credit bets
			SELECT *, 'Credit' AS GroupName 
			FROM #BetDelete with (NOLOCK)
			WHERE 	custid not in ( Select CustID from  [f_GetBetDaqCustomer] (1))
			and username <> '12EU'
			AND IsDeposit = 0
			AND mrecommend not in (105181, 118473, 105183)
			AND recommend NOT IN (11196380, 13423967) -- Foobet, 1E
			AND custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
			UNION	
			--1.For Deposit bets
			SELECT *, 'Deposit' AS GroupName 
			FROM #BetDelete with (NOLOCK)
			WHERE 	custid not in ( Select CustID from  [f_GetBetDaqCustomer] (1))
			and	username <> '12EU'
			AND IsDeposit = 1	
			AND mrecommend not in (105181, 118473, 105183)
			AND recommend NOT IN (11196380, 13423967) -- Foobet, 1E
			AND custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102	, BF3
			UNION	
			-- 6.For Betfair
			SELECT *, 'Betfair' AS GroupName 
			FROM #BetDelete
			WHERE custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
		)
		SELECT s.*			 
			 , @isITAdmin AS IsITSupport
			 , CASE 
					WHEN s.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
					ELSE s.site 
			   END AS EmailGroup
		FROM CTE_OriginResult s
		ORDER BY CASE
					WHEN s.GroupName = 'Credit'  THEN 1				
					WHEN s.GroupName = 'Deposit' THEN 2
					WHEN s.GroupName = 'Betfair' THEN 3
				 END			
	END		
		
	DROP TABLE #tblTransIds	
	DROP TABLE #tblMatchProcess
	DROP TABLE #BetDelete
	
	RETURN
END
GO