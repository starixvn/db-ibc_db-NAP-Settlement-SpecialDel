/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[DBA_BalanceMemberSel] @custID INT
	,@MatchId	INT
AS
/*
	Created: 20171010@Kathy
	Task: Get balance for testing: CASH + Bonus of member [Redmine:#66797]
	DB: DBTXN/bodb02
	
	Revisions:   
		- 20180409@Kathy: Get balance for testing [Redmine:#66797]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @adjustmentBettype SMALLINT = 22201
	
	--Balance
	BEGIN
		--General Wallet
		SELECT ct.Balance AS BalCreditTransfer
			,dt.Balance AS BalDebitTransfer
			,cs.Balance AS BalCreditSports
			,ds.Balance AS BalDebitSports
			,co.Balance AS BalCreditOthers
			,do.Balance AS BalDebitOthers
			,cc.Balance AS BalCreditCasino
			,dc.Balance AS BalDebitCasino
			,(np.Credit - np.Debit) AS BalNetPosition
			,(cs.Balance + cc.Balance + co.Balance + ct.Balance + ISNULL(np.Credit, 0)) - (ds.Balance + dc.Balance + do.Balance + dt.Balance + ISNULL(np.Debit, 0)) AS GeneralBal
		FROM dbo.BalCreditSports cs WITH (NOLOCK)
			INNER JOIN dbo.BalCreditCasino cc WITH (NOLOCK) 
				ON	cs.custid = cc.custid
			INNER JOIN dbo.BalCreditOthers co WITH (NOLOCK) 
				ON	cs.custid = co.custid
			INNER JOIN dbo.BalCreditTransfer ct WITH (NOLOCK) 
				ON	cs.custid = ct.custid
			INNER JOIN dbo.BalDebitSports ds  WITH (NOLOCK)
				ON	cs.custid = ds.custid
			INNER JOIN dbo.BalDebitCasino dc  WITH (NOLOCK)
				ON	cs.custid = dc.custid
			INNER JOIN dbo.BalDebitOthers do  WITH (NOLOCK)
				ON	cs.custid = do.custid
			INNER JOIN dbo.BalDebitTransfer dt  WITH (NOLOCK)
				ON	cs.custid = dt.custid
			OUTER APPLY 
				(SELECT SUM(np.Credit) AS Credit, SUM(np.Debit) AS Debit
						FROM	dbo.BalNetPosition np  WITH (NOLOCK)
						WHERE	np.CustID = cs.custid
				) np
		WHERE cs.custid = @custID
		
		--BONUS Wallet
		SELECT bc.CustID
			,bc.BonusID
			,bc.StatusID
			,CAST(CASE 
				WHEN bc.StatusID = 0 THEN 'Completed'
				WHEN bc.StatusID = 1 THEN 'Expired'
				WHEN bc.StatusID = 2 THEN 'Closed'
				WHEN bc.StatusID = 3 THEN 'Cancelled'
				WHEN bc.StatusID = 4 THEN 'Running'
				WHEN bc.StatusID = 5 THEN 'Rejected'
				WHEN bc.StatusID = 6 THEN 'Approved'
				ELSE 'Wrong StatusId'
				END AS VARCHAR(20)) AS [Status]
			,bc.initBonus
			,bc.LockedAmt
			,bc.Amount AS CreditBonus
			,bd.Amount AS DebitBonus
			,ISNULL(bc.initBonus, 0) + ISNULL(bc.Amount, 0) + ISNULL(bc.LockedAmt, 0) - ISNULL(bd.Amount, 0) AS BonusBal
		FROM dbo.BonusWalletCredit bc WITH (NOLOCK)
			INNER JOIN dbo.BonusWalletDebit bd WITH (NOLOCK)
				ON	bd.custID = bc.custID
					AND bd.bonusId = bc.bonusId
		WHERE bc.custID = @custID
		ORDER BY bc.CustId, bc.BonusID
	END
	
	-- Bonus Adjustment Transfer
	DECLARE @DummyUserName VARCHAR(50)
			,@UserName VARCHAR(50)
			,@DummyCustId INT
	
	SELECT	@UserName = ci.username
			,@DummyCustId = sdummy.custid
			,@DummyUserName = sdummy.username
	FROM	CustDB.dbo.Customer ci WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer srec WITH(NOLOCK)
			ON ci.srecommend = srec.custid
		CROSS APPLY (
			SELECT REPLACE(srec.username,'Super','Bonus02') AS dummyUsername
		) AS dummy
		INNER JOIN CustDB.dbo.Customer sdummy WITH(NOLOCK)
			ON dummy.dummyUsername = sdummy.username
	WHERE	ci.custid = @CustId
		
	SELECT	TOP 100 ba.ExecID, ba.LogDate, ba.ExecDate, ba.CustID, @UserName AS UserName, @DummyUserName AS dummyUsername
			,ba.BonusID, ba.StatusID, ba.Amount, ba.isTransferred
	FROM	dbo.BonusAdjustmentTransfer ba WITH(NOLOCK)
	WHERE	ba.MatchID = @MatchId
			AND ba.CustID = @CustId
	ORDER BY ba.ExecID DESC
	
	;WITH cteAdjustment
	AS(
		SELECT	b.refno
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	matchid = 0
				AND custid = @CustId
				AND b.bettype = @adjustmentBettype
				AND transdesc LIKE '%' + CAST(@MatchId AS VARCHAR) + '%'
	)
	SELECT	TOP 100 b.transid, b.transdate, b.custid, b.Username
			,b.matchid, b.bettype, b.actual_stake, b.winlost
			,b.refno, b.winlostdate, b.actualrate, b.transdesc, b.statusID, b.status
			,b.WalletType, b.BonusID, b.currency
	FROM	dbo.bettrans b WITH (NOLOCK)
		INNER JOIN (
			SELECT t.custid
			FROM (VALUES (@CustId), (@DummyCustId)) t(custid)
		)t
			ON b.custid = t.custid
	WHERE	b.matchid = 0
			AND b.bettype = @adjustmentBettype
			AND transdesc LIKE '%' + CAST(@MatchId AS VARCHAR) + '%'
			AND EXISTS (SELECT TOP 1 1 FROM cteAdjustment c WHERE c.refno = b.refno)
	ORDER BY b.transdate DESC, b.refno
END
GO