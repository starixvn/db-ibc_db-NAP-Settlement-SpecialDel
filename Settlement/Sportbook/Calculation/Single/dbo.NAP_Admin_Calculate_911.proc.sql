/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_911] 
	@MatchId		INT 
	,@Action		VARCHAR(20) = 'CAL'
	,@Mode			VARCHAR(20) = ''
	,@strBettypes	VARCHAR(MAX)
	,@ResourceIDs 	VARCHAR(MAX)=NULL
	,@Sporttype		SMALLINT = NULL
	
AS
/*
	Created: 20170315@Bobby.Nguyen	
	Task: #73404 - Integrate CashOut bettypes
	DB: DBTXN/bodb02
	
	Revisions:
		- 20170614@Kathy: Remove table BetTradeSellingCancelled on server DBLicAPI, SITDBLicAPI [Redmine:#77991]
		- 20190315@Kathy: Add 2 new servers DB061, DB062 [Redmine:#110276]
		- 20200825@Kathy: Migrate DB06 to cluster [Redmine:#140045]
		- 20210414@Kathy: Add New DB Server Name for AWS [Redmine:#149852]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		
	Parameter's Explanation:
		- @Action: CAL, Refund
		- @Mode: HT, FT, ALL
								
*/ 
BEGIN
	SET NOCOUNT ON
	
	IF(@Action NOT IN ('CAL', 'UNDO', 'REFUND')) RETURN
	
	DECLARE @xml XML	
			,@ServerAlias VARCHAR(50) = ''
			
	DECLARE @tblBettypes TABLE (bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpBalanceChanged TABLE (CustId INT, Balance MONEY)
			
	CREATE TABLE #tempCashOutTrans (
		transid			BIGINT PRIMARY KEY
		,bettype		SMALLINT
		,refno			BIGINT
		,actual_stake	MONEY
		,winlost		MONEY
		,awinlost		MONEY
		,[status]		VARCHAR(20)
		,statusId		TINYINT
		,odds			SMALLMONEY
		,oddsspread		MONEY
		,ticketId		BIGINT
		,IsBA			BIT
	)
	
	IF(CHARINDEX('root', @strBettypes) > 0)  --new formation
	BEGIN
		SET @xml = CONVERT(XML, @strBettypes)
	END
	ELSE --old formation
	BEGIN
		SET @xml = CONVERT(XML, N'<root><r t="' + REPLACE(REPLACE(@strBettypes, '|', '" g="'), ',', '"/><r t="') + '"/></root>')
	END
	
	INSERT INTO @tblBettypes(bettype)
	SELECT	T.c.value('./@t','SMALLINT')
	FROM @xml.nodes('/root/r') AS T(c)
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) )
	
	INSERT INTO #tempCashOutTrans(transid, bettype, refno, actual_stake, winlost, odds,oddsspread,ticketId, IsBA)
	SELECT DISTINCT t.transid
		, t.bettype
		, t.refno
		, t.actual_stake
		, t.winlost
		, t.odds
		, t.oddsspread
		, org.transid AS ticketId
		, CASE WHEN org.transid2 > 0 THEN 1 ELSE 0 END AS IsBA
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN dbo.bettrans org WITH(NOLOCK)
			ON b.matchid 	= org.matchid 
			AND b.custid 	= org.custid 
			AND b.refno 	= org.transid
		INNER JOIN dbo.bettrans ct WITH(NOLOCK)
			ON b.matchid 	= ct.matchid 
			AND ct.refno 	= b.transid 
			AND ct.bettype 	IN (912,913)
		CROSS APPLY (
			VALUES 
			(b.transid,b.bettype, b.transid, b.actual_stake,b.winlost,b.odds,b.oddsspread)
			,(ct.transid,ct.bettype, ct.refno, ct.actual_stake, ct.winlost,ct.odds,ct.oddsspread)
		) AS t(transid, bettype, refno,actual_stake, winlost,odds,oddsspread)
	WHERE b.matchid = @matchid
		AND b.bettype = 911 
		AND org.betdaqid = 0 
		AND org.ExtraInfo IS NOT NULL
		AND 1 = CASE 
					WHEN @mode = 'UNDO' THEN 
						CASE 
							WHEN (@ResourceIDs IS NULL) THEN 1							
							WHEN (@ResourceIDs IS NOT NULL 
								AND CHARINDEX(',' +CAST(org.bettype AS VARCHAR(10)) + ',', ',' + @ResourceIDs + ',') > 0) THEN 1
							ELSE 0
						END
					WHEN @mode <> 'UNDO' AND org.bettype IN (SELECT bettype FROM @tblBettypes) THEN 1
					ELSE 0
				END
		AND 1 = CASE 
					WHEN @Action = 'CAL' AND b.statusId = 103 THEN 1 --RE-CAL and refunding tickets 
					WHEN @Action = 'REFUND' AND org.statusId = 103 AND b.statusId NOT IN (101,102) THEN 1 --refund tickets and still valid CashOut Trans 911
					ELSE 0
				END

	/*SELECT transid, bettype, refno, actual_stake, winlost, odds,oddsspread,awinlost, status, statusId
	from #tempCashOutTrans
	ORDER BY transid*/

	EXEC dbo.NAP_Set_ServerInfo @ServerAlias = @ServerAlias OUTPUT

	IF(@Action IN ('CAL', 'UNDO') )
	BEGIN
		--Recover selling data
		UPDATE b911
		SET winlost = b912.actual_stake
			,awinlost = b911.actual_stake - b912.actual_stake
			,[status] = CASE 
							WHEN b912.actual_stake - b911.actual_stake > 0 THEN 'WON'
							WHEN b912.actual_stake - b911.actual_stake = 0 THEN 'DRAW'
							WHEN b912.actual_stake - b911.actual_stake < 0 THEN 'LOSE'
						END
			,[statusId] = CASE 
							WHEN b912.actual_stake - b911.actual_stake > 0 THEN 112
							WHEN b912.actual_stake - b911.actual_stake = 0 THEN 111
							WHEN b912.actual_stake - b911.actual_stake < 0 THEN 113
						END
		FROM #tempCashOutTrans b911
			INNER JOIN #tempCashOutTrans b912 ON b911.transid = b912.refno 
		WHERE b911.bettype = 911
			AND b912.bettype = 912

		--Recover buying  data
		UPDATE b912
		SET winlost = b911.actual_stake
			,awinlost = b912.actual_stake - b911.actual_stake
			,[status] = CASE 
							WHEN b911.actual_stake - b912.actual_stake > 0 THEN 'WON'
							WHEN b911.actual_stake - b912.actual_stake = 0 THEN 'DRAW'
							WHEN b911.actual_stake - b912.actual_stake < 0 THEN 'LOSE'
						END

			,[statusId] = CASE 
							WHEN b911.actual_stake - b912.actual_stake > 0 THEN 112
							WHEN b911.actual_stake - b912.actual_stake = 0 THEN 111
							WHEN b911.actual_stake - b912.actual_stake < 0 THEN 113
						END
		FROM #tempCashOutTrans b912
			INNER JOIN #tempCashOutTrans b911 ON b912.refno = b911.transid
		WHERE b912.bettype = 912
			AND b911.bettype = 911


		--Recover commission data
		UPDATE b913
		SET winlost = b913.odds * b912.actual_stake
			,awinlost = CASE WHEN b913.IsBA = 1 THEN 0 ELSE b913.oddsspread * b912.actual_stake END
			,[status] = 'LOSE'
			,[statusId] = 113
		FROM #tempCashOutTrans b913
			INNER JOIN #tempCashOutTrans b912 ON b912.refno = b913.refno
		WHERE b913.bettype = 913
			AND b912.bettype = 912
		
		--UPDATE back to bettrans
		UPDATE b
		SET winlost = t.winlost
			,awinlost = t.awinlost
			,[status] = t.[status]
			,statusId = t.statusId
		OUTPUT	deleted.custid
				,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
		INTO @tmpBalanceChanged (CustId, Balance)	
		FROM dbo.bettrans b WITH(ROWLOCK,UPDLOCK)
			INNER JOIN #tempCashOutTrans t 
			ON b.transid = t.transid
			
		IF @ServerAlias = 'DBTXN' AND @Action ='CAL' AND @Sporttype = 1
		BEGIN
			INSERT INTO dbo.BalCreditSportsPending (custid, balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@tmpBalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) > 0
		
			INSERT INTO dbo.BalDebitSportsPending(custid, balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@tmpBalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) < 0
		END

		--RECOVER BetTradeSellingCancelled
		IF @@SERVERNAME IN ('DB230' -- local dev
			,'DB206' -- local test
			,'SITDBTRANS', 'SITDBBAL','SITDBAWS' -- SIT
			,'DBBAL' -- cloud
			,'DBTRANS','DBTP','DB061', 'DB062' -- prod
		) OR @ServerAlias = 'DBACC'
		BEGIN		
			WITH CTE_BetSelling AS (
				SELECT bs.TradeID
				FROM #tempCashOutTrans t 
					INNER JOIN dbo.BetTradeSelling bs WITH(NOLOCK) 
					ON t.ticketId	= bs.TicketID 
					AND t.transid 	= bs.SoldTicketID
				WHERE t.bettype 	= 911
					AND bs.matchid 	= @matchid
			)
			UPDATE bt
			SET Remark 			= 'SB recover ticket'
				, BTBuyback 	= -(bt.BTBuyback)
				, AfterBalance 	= 0
				, Cancelled 	= 0
				, ChangeDate 	= CURRENT_TIMESTAMP
			FROM dbo.BetTradeSellingCancelled bt WITH(ROWLOCK,UPDLOCK)
				INNER JOIN CTE_BetSelling sel
				ON bt.TradeID = sel.TradeID
		END
	END
	
	IF(@Action = 'REFUND')
	BEGIN
		---Zeroize data
		UPDATE b
		SET winlost = t.actual_stake
			,awinlost = 0
			,[status] = 'Refund'
			,statusId = 103
			
		FROM dbo.bettrans b WITH(ROWLOCK,UPDLOCK)
			INNER JOIN #tempCashOutTrans t 
			ON b.transid = t.transid

		--REFUND CashOut transaction
		IF @@SERVERNAME IN ('DB230' -- local dev
			,'DB206' -- local test
			,'SITDBTRANS', 'SITDBBAL','SITDBAWS' -- SIT
			,'DBBAL' -- cloud
			,'DBTRANS','DBTP','DB061', 'DB062' -- prod
		) OR @ServerAlias = 'DBACC'
		BEGIN	
			WITH CTE_BetSelling AS (
				SELECT bs.TradeID
					, bs.TicketID
					, 'SB refund ticket' AS Remark
					--, (bs.StakeSold - bs.PaidAmt) AS BTBuyback
					, (t.actual_stake - b912.actual_stake) AS BTBuyback
					, 0 AS BTComission
					, 0 AS AfterBalance
					, 'SB' AS Owner
					, 1 AS Cancelled
					, CURRENT_TIMESTAMP AS CreateDate
					, CURRENT_TIMESTAMP AS ChangeDate
				FROM #tempCashOutTrans t 
					INNER JOIN dbo.BetTradeSelling bs WITH(NOLOCK) 
						ON t.ticketId = bs.TicketID 
						AND t.transid = bs.SoldTicketID
					INNER JOIN #tempCashOutTrans b912 
						ON t.transid = b912.refno 
						AND b912.bettype = 912
						
				WHERE t.bettype 	= 911
					AND bs.matchid 	= @matchid
			)	
			MERGE dbo.BetTradeSellingCancelled AS t
			USING CTE_BetSelling AS s
				ON t.TradeID = s.TradeID 
			WHEN MATCHED THEN UPDATE
				SET Remark 				= s.Remark
					, BTBuyback			= s.BTBuyback
					, BTComission		= s.BTComission
					, AfterBalance		= s.AfterBalance
					, Owner				= s.Owner
					, Cancelled			= s.Cancelled
					, ChangeDate		= s.ChangeDate
			WHEN NOT MATCHED BY TARGET THEN INSERT 
				([TradeID]
				   ,[TicketID]
				   ,[Remark]
				   ,[BTBuyBack]
				   ,[BTComission]
				   ,[AfterBalance]
				   ,[Owner]
				   ,[Cancelled]
				   ,[ChangeDate]
				   ,[CreateDate]
				)
				VALUES(
					s.TradeID
				   ,s.TicketID
				   ,s.Remark
				   ,s.BTBuyBack
				   ,s.BTComission
				   ,s.AfterBalance
				   ,s.Owner
				   ,s.Cancelled
				   ,s.ChangeDate
				   ,s.CreateDate
				);
		END
	END
	
	
	DROP TABLE #tempCashOutTrans
	RETURN
END
GO
