/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/* 
	Created by: 20241004@Helen
	Task: Void invalid ticket - [211859]
	DB: SITEDB01/bodb02 & DBTRANS/bodb02
	
*/
BEGIN
	SET NOCOUNT ON	
	
	DECLARE	@TransIds	VARCHAR(MAX) = '305468974722711571, 305473703481704505, 305513522123505695, 305471126501326892'
	DECLARE @beforeUpd 	TVP_BalanceWalletChange
		  , @afterUpd 	TVP_BalanceWalletChange
		
	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	
	
	CREATE TABLE #BetDelete (
		GroupTransId	BIGINT -- parent Id (translog.traslogid | bettrans.transid)
		,transid		BIGINT PRIMARY KEY --bettrans.transid
		,matchid		INT
		,Bettype		SMALLINT
		,betid			BIGINT
		,stake			MONEY
		,odds			MONEY
		,refno			BIGINT -- translog.traslogid | bettrans.transid
		,betfrom		NVARCHAR(10)
		,statusid		TINYINT
		,betdaqid		BIGINT		
		,winlostdate	SMALLDATETIME
		,status			VARCHAR(10)
		,oddstype		TINYINT
		,transdate		DATETIME
		,betteam		NVARCHAR(10)
		,betcheck		NVARCHAR(50)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,winlost		MONEY
		,playercomm		MONEY
		,currency		TINYINT
		,transdesc		NVARCHAR(1000)
		,custid			INT
		,creator		INT
		,homeid			INT DEFAULT (0)
		,awayid			INT DEFAULT (0)
		,matchcode		NVARCHAR(50)
		,eventdate		DATETIME
		,leagueid		INT DEFAULT (0)
		,isNeutral		BIT
		,showtime		NVARCHAR(50)
		,username		VARCHAR(30)
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,sporttype		SMALLINT
		,IsHideComm		BIT DEFAULT(0)
		,oddsid			INT
		,ExtraInfo		VARCHAR(1000)
		,awinlost		MONEY
		,SiteId			VARCHAR(7)
		,CurrencyName	NVARCHAR(50)
		,IsMetricGaming	BIT
		,modds			SMALLMONEY
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT
		,MainTransId	BIGINT
		,IsFinish		BIT
		,actual_stake   MONEY
	)
	
	BEGIN TRY
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT value 
		FROM STRING_SPLIT(@TransIds,',')		
		
	END TRY
	BEGIN CATCH
		SELECT 'Invalid TransIds.'										
		
		RETURN
	END CATCH		
		
	INSERT INTO #BetDelete(
		GroupTransId	
		,transid			
		,matchid		
		,Bettype		
		,betid			
		,stake			
		,odds	
		,refno			
		,betfrom		
		,statusid				
		,betdaqid		
		,winlostdate
		,status		
		,oddstype		
		,transdate		
		,betteam		
		,betcheck		
		,hdp1			
		,hdp2			
		,livehomescore	
		,liveawayscore	
		,liveindicator	
		,winlost		
		,playercomm		
		,currency	
		,transdesc		
		,custid			
		,creator	
		,recommend
		,mrecommend
		,srecommend
		,IsHideComm
		,eventdate
		,oddsid
		,ExtraInfo
		,awinlost
		,SiteId
		,CurrencyName
		,IsMetricGaming
		,modds
		,WalletType
		,RefCode
		,BonusID
		,actual_stake
	)
	SELECT	
		b.transid AS groupTransId
		,b.transid
		,b.matchid
		,b.bettype
		,b.betid
		,b.stake
		,b.odds
		,b.refno
		,b.betfrom
		,b.statusID
		,b.betdaqid
		,b.winlostdate
		,b.status
		,b.oddstype
		,b.transdate
		,b.betteam
		,b.betcheck
		,b.hdp1
		,b.hdp2
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.winlost - b.actual_stake
		,b.playercomm
		,b.currency
		,b.transdesc
		,b.custid
		,b.creator
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,CASE 
			WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1 			 
			ELSE 0 
		 END AS IsHideComm
		,b.winlostdate
		,b.oddsid
		,b.ExtraInfo
		,b.awinlost
		,NULL AS SiteId
		,b.CurrencyName
		,0 AS IsMetricGaming
		,b.modds
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,b.actual_stake
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransIds t
			ON b.transid = t.transid
	WHERE b.statusID NOT IN (101, 102)	
	
	--check no data
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)
	BEGIN
 			SELECT 'No ticket found.' 									
		
		RETURN
	END
	
	--capture balance before
	INSERT INTO @BeforeUpd (
		 matchid
		,custid
		,balanceType
		,BonusID
		,WalletType
		,balance
	)
	SELECT matchid
		 , custid
		 , 4  -- Others
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) AS balance
	FROM
	(
		-- normal ticket
		SELECT tmpmain.custid
			 , main.BonusID
			 , main.WalletType
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	main.transid = tmpmain.transid
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
		     END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets


	/**********************************************   *************************************************************/
	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT)

	-- STEP 2 : Update bettrans/translog
	-- 2.1. Update bettrans	for normal ticket
	WHILE (1=1)
	BEGIN
		DELETE @tmpTransIDBatch

		UPDATE TOP(2000) t
			SET IsFinish = 1
		OUTPUT  DELETED.transid
		INTO @tmpTransIDBatch (TransId)
		FROM #BetDelete t
		WHERE IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		UPDATE	main
			SET winlost		= main.actual_stake
				,ruben			= 1
				--,statuswinlost	= 6
				,creator		= 10278938
				,awinlost		= 0
				,mwinlost		= 0
				,swinlost		= 0
				,playercomm		= 0
				,comm			= 0
				,acomm			= 0
				,scomm			= 0
				,statusID		= 102       
				,status			= 'VOID'
				,FcUpdateTime  = SYSDATETIME()
				,RepUpdateTime = SYSDATETIME()
		FROM	dbo.bettrans main WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpTransIDBatch tmpmain 
				ON	main.transid = tmpmain.transid 
	END	

	--capture balance after
	INSERT INTO @AfterUpd (
			 matchid
			,custid
			,balanceType
			,BonusID
			,WalletType
			,balance
		)
	SELECT matchid	
		 , custid
		 , 4  -- Others
		 , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		 , ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(winlost - actual_stake + playercomm) balance
	FROM
	(
		-- normal ticket
		SELECT tmpmain.custid
			 , main.BonusID
			 , main.WalletType
			 , main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
		FROM dbo.bettrans main WITH (NOLOCK)
			INNER JOIN #BetDelete tmpmain
				ON	main.transid = tmpmain.transid
	) tmp
	GROUP BY matchid
		   , CustID
		   , CASE 
				WHEN ((tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) AND tmp.bettype NOT BETWEEN 801 AND 806) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
				WHEN tmp.sporttype = 162 THEN 3 -- Casino
				ELSE 4  -- Others
			 END
		   , CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		   , ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets
	
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @BeforeUpd
		, @BalanceWalletAfter	= @AfterUpd
		, @ActionId				= 0	 
		
	DROP TABLE #tblTransIds
	DROP TABLE #BetDelete

	RETURN
END
GO
