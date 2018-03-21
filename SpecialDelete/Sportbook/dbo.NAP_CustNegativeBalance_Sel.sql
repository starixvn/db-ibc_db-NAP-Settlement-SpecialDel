/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_CustNegativeBalance_Sel] 	
	@CustIds			  VARCHAR(MAX)	= '',
    @NegativeBalanceUsers VARCHAR(MAX) OUTPUT
AS
/*
	Created: Kent
	Date: 20161111
	DB: DBTXN/bodb02

	Revisions: 		
		- 20161026@Kent: Check negative balance after recovering voided Parlay tickets [Redmine:#65531]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
*/
BEGIN
	SET NOCOUNT ON		
		
	DECLARE @CustList TABLE (
		custid			INT		
	)
	
	DECLARE @balanceCust TABLE (
		custid		INT
		,username	nvarchar(50)
		,balance	money
	)	
	
	DECLARE @BalNetPositionTmp TABLE(CustId INT, Balance MONEY)	
	
	INSERT INTO @CustList(custid)
	SELECT val FROM dbo.strSplit(@CustIds, ',')		  	
	
	;WITH CustomerList
	AS
	(
		SELECT	b.custid, b.Username, b.winlost, b.actual_stake, b.playercomm
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN dbo.translog tl WITH(NOLOCK)
				ON	b.refno = tl.translogid
					AND b.matchid = tl.eventID
		WHERE	b.custid IN (SELECT custid FROM @CustList)
				AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))
		UNION ALL 
		SELECT	tl.custid, tl.Username, 0, tl.actual_stake, 0
		FROM	dbo.translog tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM @CustList)
				AND tl.statusID IN (0, 1)	
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm
		FROM	dbo.bettransRnG WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM @CustList)
				AND IsSum=0
		UNION ALL
		SELECT	custid, Username, winlost, actual_stake ,playercomm
		FROM	dbo.bettransLC WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM @CustList) 
				AND IsSum=0	
	)
	INSERT INTO @balanceCust (custid, username, balance)
	SELECT custid, username, SUM(winlost - actual_stake + playercomm)
	FROM CustomerList
	GROUP BY custid, username	
	
	--netposition bal
	INSERT INTO @BalNetPositionTmp(CustId, Balance)
	SELECT bal.CustId, SUM(Credit - Debit) AS Balance
	FROM dbo.BalNetPosition bal WITH(NOLOCK)
		INNER JOIN @CustList d ON bal.CustId = d.CustId
	GROUP BY bal.CustId
	
	SET @NegativeBalanceUsers = ''
	SELECT @NegativeBalanceUsers = @NegativeBalanceUsers + 
								   CASE WHEN @NegativeBalanceUsers <> '' THEN ',' ELSE '' END + 
								   bal.username			
	FROM @balanceCust bal
		INNER JOIN DBCUST.custDB.dbo.custInfo c WITH(NOLOCK ) 
			ON	bal.custid = c.custid
		INNER JOIN custDB.dbo.Customer ag WITH(NOLOCK) 
			ON	ag.custid = c.recommend
		LEFT JOIN @BalNetPositionTmp tt ON bal.CustId = tt.CustId
	WHERE (c.credit + bal.balance + ISNULL(tt.Balance, 0)) < 0	
END
GO


