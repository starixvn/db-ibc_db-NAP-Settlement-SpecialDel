/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_CheckNegativeBalanceCashOutTransaction]
	@TransIds VARCHAR(MAX) = '',
	@Type BIT = 0
AS
	/*
	Created by: Kent
	Date: 20170407
	Original: 
	Task: Check if a bet credit of customer is negative
	DB: DBTXN/BODB02

	Revisions:
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20190321@Alan: Do not check negative balance for CN88 [109858]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's Explanation: Special bet delete option
		@transids: All ticket of customers who need to be check negative bet credit
		@Type: 
			- 0: Void Transaction: 
			- 1: Recover Transaction
		

*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE  @BetDelete TABLE (
		 transid			BIGINT PRIMARY KEY
		,custid			INT
		,Stake			MONEY
		,winlost		MONEY
		,actual_stake	MONEY
		,playercomm		MONEY
		,matchid		INT
		,refno			BIGINT	
		,oddsspread		MONEY
		,MainStatusId	TINYINT
	)
	
	DECLARE @balanceCust TABLE (
		 custid		INT
		,username	nvarchar(50)
		,balance	money
	)
	DECLARE @balanceTrans TABLE(
		 custid		INT
		,balance	money
	)
	
	DECLARE @beforeimage TABLE (
		 custid		INT		
		,balance	money
	)
	DECLARE @afterimage TABLE (
		 custid		INT		
		,balance	money
	)
	
	CREATE TABLE #CustIdList
	(
		custid		INT PRIMARY KEY
	)	
	
	DECLARE @tblTransId TABLE (transid BIGINT PRIMARY KEY)
	
	DECLARE @yesterday		DATE
	
	SET @yesterday = CONVERT(DATE,GETDATE() - 1)
	
	INSERT INTO @tblTransId(transid)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds, ',')
	
	INSERT INTO @BetDelete(
			transid
			,custid
			,Stake
			,winlost
			,actual_stake
			,playercomm
			,matchid
			,refno
			,oddsspread
			,MainStatusId
	)
	SELECT	b.transid -- CashOut sub ticket: 911 
			,b.custid
			,b.Stake
			,b.winlost
			,b.actual_stake
			,b.playercomm
			,b.matchid
			,b.refno
			,b.oddsspread
			,main.statusID AS MainStatusId
	FROM	bettrans b WITH(NOLOCK)
		INNER JOIN @tblTransId t
			ON	b.transid = t.transid
		INNER JOIN bettrans main WITH(NOLOCK)
			ON b.refno = main.transid
			   AND b.custid = main.custid
			   AND b.matchid = main.matchid		
	WHERE	b.bettype = 911
			AND 1 = CASE 
						WHEN @Type = 0 AND b.statusID IN (111, 112, 113) THEN 1 
						WHEN @Type = 1 AND b.statusID = 102 THEN 1
						ELSE 0
						END
	
	INSERT INTO #CustIdList(custid)					
	SELECT DISTINCT custid 
	FROM @BetDelete
	
	;WITH CustomerList
	AS
	(
		SELECT	b.custid, b.Username, b.winlost, b.actual_stake, b.playercomm
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN dbo.translog tl WITH(NOLOCK)
				ON	b.refno = tl.translogid
					AND b.matchid = tl.eventID
		WHERE	b.custid IN (SELECT custid FROM #CustIdList)
				AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))
		UNION ALL 
		SELECT	tl.custid, tl.Username, 0, tl.actual_stake, 0
		FROM	dbo.translog tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM #CustIdList)
				AND tl.statusID IN (0, 1)	
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm
		FROM	dbo.bettransRnG WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM #CustIdList)
				AND IsSum=0
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm
		FROM	dbo.bettransLC WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM #CustIdList) 
				AND IsSum=0				
	)
	INSERT INTO @balanceCust (custid, username, balance)
	SELECT custid, username, SUM(winlost - actual_stake + playercomm)
	FROM CustomerList
	GROUP BY custid, username
	
	INSERT INTO @beforeimage(custid, balance)
	SELECT T.custid AS custid
		 , SUM(T.winlost - T.actual_stake + T.playercomm) AS balance
	FROM (
			-- sub 911
			SELECT custid, winlost, actual_stake, playercomm
			FROM @BetDelete
			UNION ALL
			-- main cash-out
			SELECT custid, winlost, actual_stake, playercomm
			FROM bettrans (NOLOCK)
			WHERE transid IN (SELECT refno FROM @BetDelete)						
		 ) AS T
	GROUP BY T.custid
	
	;WITH afterlist
	AS
	(
		-- sub 911
		SELECT bd.custid
			 , CASE WHEN @type = 0 THEN bd.actual_stake ELSE sub912.actual_stake END AS winlost
			 , bd.actual_stake
			 , 0 AS playercomm
		FROM @BetDelete bd
			 OUTER APPLY (SELECT actual_stake 
						  FROM bettrans sub912 (NOLOCK) 
						  WHERE sub912.refno = bd.transid 
							AND sub912.matchid = bd.matchid
						    AND sub912.bettype = 912) AS sub912
		UNION ALL
		-- main cash-out
		SELECT b.custid AS custid
			 , TCal.winlost
			 , TRef.actual_stake
			 , TCal.playercomm
		FROM bettrans (NOLOCK) b
			 OUTER APPLY (SELECT b.stake + CASE WHEN @Type = 0 THEN SUM(Stake) ELSE -SUM(Stake) END AS stake
							   , CASE
									WHEN b.odds < 0 THEN (b.stake + CASE WHEN @Type = 0 THEN SUM(Stake) ELSE -SUM(Stake) END) * abs(b.odds)
									ELSE b.stake + CASE WHEN @Type = 0 THEN SUM(Stake) ELSE -SUM(Stake) END
								 END AS actual_stake
							   
							   , CASE b.comstatus WHEN '0' THEN 1 WHEN '1' THEN 0 ELSE 1 END AS commWinRate
							   , CASE b.comstatus WHEN '0' THEN 1 WHEN '1' THEN 2 ELSE 1 END AS commLostRate --'s','m'
								 
							   , CASE 
									WHEN b.odds<0 THEN 1 
									ELSE (CASE 
											WHEN b.bettype in (SELECT f.BetType 
															   FROM [dbo].[f_Set_GetCashOutBettypes]() f 
															   WHERE f.IsDecimalOnly = 1) 
													THEN b.odds-1 
											ELSE b.odds 
										  END) 
								 END AS odds
						  FROM @BetDelete
						  WHERE refno = b.transid) AS TRef			 
			 OUTER APPLY (SELECT CASE 
									WHEN b.statusID IN (111,112,113) THEN CASE
																				WHEN b.modds >  0.25 THEN TRef.actual_stake + TRef.stake * TRef.odds
																				WHEN b.modds =  0.25 THEN TRef.actual_stake + TRef.stake * TRef.odds * 0.5
																				WHEN b.modds =  0	 THEN TRef.actual_stake	
																				WHEN b.modds = -0.25 THEN TRef.actual_stake * 0.5
																				WHEN b.modds < -0.25 THEN 0
																		  END 
									WHEN b.statusID IN (103) THEN TRef.actual_stake 
									ELSE b.winlost 
								 END AS winlost
							   , CASE 
									WHEN b.statusID IN (111,112,113) THEN CASE
																				WHEN b.modds >  0.25  THEN TRef.commWinRate * b.playerdiscount * TRef.stake
																				WHEN b.modds =  0.25  THEN TRef.commWinRate * b.playerdiscount * TRef.stake * 0.5
																				WHEN b.modds =  0	  THEN 0	
																				WHEN b.modds = -0.25  THEN TRef.commLostRate * b.playerdiscount * TRef.stake * 0.5
																				WHEN b.modds < -0.25  THEN TRef.commLostRate * b.playerdiscount * TRef.stake
																		  END 
									WHEN b.statusID IN (103) THEN 0 
									ELSE b.playercomm 
								 END AS playercomm) AS TCal
		WHERE b.transid IN (SELECT refno FROM @BetDelete)			
	)
	INSERT INTO @afterimage(custid, balance)
	SELECT custid, SUM(winlost - actual_stake + playercomm) AS balance
	FROM afterlist
	GROUP BY custid					
	
	INSERT INTO @balanceTrans (custid, balance)
	SELECT a.custid, (a.balance - b.balance) AS balance
	FROM @afterimage a
		 INNER JOIN @beforeimage b
			ON a.custid = b.custid
	
	SELECT	 bal.custid
			,bal.username
			,ag.site			
	FROM	@balanceTrans t
		INNER JOIN @balanceCust bal 
			on	t.custid = bal.custid
		INNER JOIN DBCUST.custDB.dbo.custInfo c WITH(NOLOCK ) 
			ON	bal.custid = c.custid
		INNER JOIN custDB.dbo.Customer ag WITH(NOLOCK) 
			ON	ag.custid = c.recommend AND ag.site <> 'CN88'
	WHERE	 (t.balance < 0 AND @Type = 0 AND (c.credit + bal.balance + t.balance ) < 0 )
			OR (t.balance < 0 AND @Type = 1 AND (c.credit + bal.balance + t.balance) < 0)		
	
	SET NOCOUNT OFF
END
GO