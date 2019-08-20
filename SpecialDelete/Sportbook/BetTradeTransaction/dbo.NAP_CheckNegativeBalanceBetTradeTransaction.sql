/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CheckNegativeBalanceBetTradeTransaction]
	@TransIds VARCHAR(MAX) = '',
	@Type BIT = 0
AS
	/*
	Created by: 20151127@Kathy
	Task : Check if a bet credit of customer is negative
	DB: DBTXN.bodb02

	Revisions:   
		- 20160118@Kathy: get balance from bettransRNG & bettransLC [Redmine:#50674]
		- 20160120@Kathy: check negative balance when recover [Redmine:#51042]
		- 20160226@Kathy: do not check balance when recover REFUND ticket [Redmine:#51747]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20190321@Alan: Do not check negative balance for CN88 [109858]
	
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
		,winlost		MONEY
		,actual_stake	MONEY
		,playercomm		MONEY
		,matchid		INT
		,refno			BIGINT	
		,oddsspread		MONEY
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
	
	DECLARE @tblTransId TABLE (transid BIGINT PRIMARY KEY)
	
	DECLARE @yesterday		DATE
	
	SET @yesterday = CONVERT(DATE,GETDATE() - 1)
	
	INSERT INTO @tblTransId(transid)
	SELECT DISTINCT val FROM dbo.strSplit(@TransIds, ',')
	
	INSERT INTO @BetDelete(
			transid
			,custid
			,winlost
			,actual_stake
			,playercomm
			,matchid
			,refno
			,oddsspread
	)
	SELECT	b.transid -- BT sub ticket: 901 
			,b.custid
			,b.winlost
			,b.actual_stake
			,b.playercomm
			,b.matchid
			,b.refno
			,b.oddsspread
	FROM	bettrans b WITH(NOLOCK)
		INNER JOIN @tblTransId t
			ON	b.transid = t.transid		
	WHERE	b.bettype = 901
			AND 1 = CASE 
						WHEN @Type = 0 AND b.statusID IN (111, 112, 113) THEN 1 
						WHEN @Type = 1 AND b.statusID = 102 THEN 1
						ELSE 0
						END
	
	;WITH CustomerList
	AS
	(
		SELECT	b.custid, b.Username, b.winlost, b.actual_stake, b.playercomm
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN dbo.translog tl WITH(NOLOCK)
				ON	b.refno = tl.translogid
					AND b.matchid = tl.eventID
		WHERE	b.custid IN (SELECT custid FROM @BetDelete)
				AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))
		UNION ALL 
		SELECT	tl.custid, tl.Username, 0, tl.actual_stake, 0
		FROM	dbo.translog tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM @BetDelete)
				AND tl.statusID IN (0, 1)	
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm
		FROM	dbo.bettransRnG WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM @BetDelete)
				AND IsSum=0
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm
		FROM	dbo.bettransLC WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM @BetDelete) 
				AND IsSum=0				
	)
	INSERT INTO @balanceCust (custid, username, balance)
	SELECT custid, username, SUM(winlost - actual_stake + playercomm)
	FROM CustomerList
	GROUP BY custid, username 

	IF(@Type = 0)
	BEGIN
		;WITH main
		AS(
			SELECT bd.custid, SUM(main.winlost - main.actual_stake + CASE 
																		WHEN main.statusID IN (112, 113) THEN CASE 
																		WHEN main.modds > 0.25 THEN CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
																									WHEN '0' THEN 1
																									WHEN '1' THEN 0 
																									ELSE 1 
																									END * bd.oddsspread *main.stake
																		WHEN main.modds = 0.25 THEN CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
																									WHEN '0' THEN 1
																									WHEN '1' THEN 0 
																									ELSE 1 
																									END * bd.oddsspread * main.stake * 0.5
																		WHEN main.modds = 0 THEN 0
																		WHEN main.modds = -0.25 THEN CASE comstatus
																									WHEN '0' THEN 1
																									WHEN '1' THEN 2 
																									ELSE 1 
																									END * bd.oddsspread * main.stake * 0.5
																		WHEN main.modds < -0.25 THEN CASE comstatus
																									WHEN '0' THEN 1
																									WHEN '1' THEN 2 
																									ELSE 1 
																									END * bd.oddsspread * main.stake
																		ELSE main.playercomm
																		END
																		ELSE main.playercomm
																		END
																) balance
			FROM dbo.bettrans main WITH(NOLOCK)
				INNER JOIN @BetDelete bd 
					ON	main.transid = bd.refno
						AND main.matchid = bd.matchid
			GROUP BY bd.custid
		)
		,sub
		AS(
			SELECT b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM @BetDelete b
			GROUP BY b.custid
		)
		INSERT INTO @balanceTrans (custid, balance)
		SELECT sub.custid, (main.balance - sub.balance) AS balance
		FROM	main
			INNER JOIN sub
				ON main.custid = sub.custid
	END
	ELSE
	BEGIN
		;WITH sub
		AS(
			SELECT  sub901.custid, SUM(sub902.winlost  - sub901.actual_stake) AS balance
			FROM	@BetDelete sub901
				INNER JOIN dbo.bettrans sub902 WITH(NOLOCK)
					ON	sub901.matchid = sub902.matchid
						AND sub901.refno = sub902.refno
						AND sub902.bettype = 902
			GROUP BY sub901.custid
		)
		,main
		AS(
			SELECT	sub901.custid, SUM(main.winlost - main.actual_stake + main.playercomm) AS balance
			FROM	@BetDelete sub901
				INNER JOIN dbo.bettrans main WITH(NOLOCK)
					ON	sub901.matchid = main.matchid
						AND sub901.refno = main.transid
						AND main.statusID <> 103 -- REFUND
			GROUP BY sub901.custid
		)
		INSERT INTO @balanceTrans (custid, balance)
		SELECT	sub.custid, (sub.balance - main.balance) AS balance
		FROM	sub
			INNER JOIN main
				ON sub.custid = main.custid
		
	END
	
	SELECT	bal.custid
			,bal.username
			,ag.site	
			,c.credit		
			,bal.balance
			,t.balance
	FROM	@balanceTrans t
		INNER JOIN @balanceCust bal 
			on	t.custid = bal.custid
		INNER JOIN DBCUST.custDB.dbo.custInfo c WITH(NOLOCK ) 
			ON	bal.custid = c.custid
		INNER JOIN custDB.dbo.Customer ag WITH(NOLOCK) 
			ON	ag.custid = c.recommend AND ag.site <> 'CN88'
	WHERE	 (t.balance < 0 AND @Type = 0 AND (c.credit + bal.balance + t.balance ) < 0 )
			OR (t.balance < 0 AND @Type = 1 AND (c.credit + bal.balance + t.balance) < 0)
END
GO