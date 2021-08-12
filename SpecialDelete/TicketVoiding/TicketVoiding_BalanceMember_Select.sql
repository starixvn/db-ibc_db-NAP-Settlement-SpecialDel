/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_BalanceMember_Select]
	@CustIds VARCHAR(MAX)
	,@CustBalance XML	= '' OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20210517@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
	
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpCustId TABLE(CustId INT)
	DECLARE @movebetdate SMALLDATETIME

	INSERT INTO @tmpCustId (CustId)
	SELECT	val AS CustId
	FROM	dbo.f_SplitString(@CustIds, ',')
	OPTION (maxrecursion 0)

	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
	SET @CustBalance = (
		SELECT c.custid AS '@c', SUM(c.Balance) AS '@b'
		FROM
		(
			SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS Balance				
			FROM	@tmpCustId c
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	c.CustId = b.custid
			WHERE	1 = CASE
							WHEN b.bettype BETWEEN 801 AND 806 AND b.statusID = 0 THEN 0
							WHEN b.bettype = 19999 AND b.winlostdate > @movebetdate THEN 0 --new sum
							WHEN b.bettype < 19999 AND b.winlostdate <= @movebetdate THEN 0 -- old bet
							ELSE 1
						END
			GROUP BY b.custid
		
			UNION ALL 
			SELECT	tl.custid, SUM(0 - tl.actual_stake + 0) AS Balance				
			FROM	@tmpCustId c
				INNER JOIN dbo.translog tl WITH(NOLOCK)
					ON c.CustId = tl.custid
			WHERE	tl.statusID BETWEEN 0 AND 1		
			GROUP BY tl.custid	

			UNION ALL
			SELECT	br.custid, SUM(winlost - actual_stake + playercomm) AS Balance
			FROM	@tmpCustId c
				INNER JOIN dbo.bettransRnG br WITH(NOLOCK)
					ON	c.CustId = br.custid
			WHERE	br.IsSum=0		
			GROUP BY br.custid
				
			UNION ALL
			SELECT	bl.custid, SUM(winlost - actual_stake + playercomm) AS Balance
			FROM	@tmpCustId c
				INNER JOIN dbo.bettransLC bl WITH(NOLOCK)
					ON	c.CustId = bl.custid
			WHERE	IsSum=0	
			GROUP BY bl.custid

			UNION ALL
			SELECT	bn.CustID, SUM(bn.Credit - bn.Debit) AS Balance
			FROM	@tmpCustId c
				INNER JOIN dbo.BalNetPosition bn WITH(NOLOCK)
					ON bn.CustID = c.CustId
			GROUP BY	bn.CustID

			UNION ALL
			SELECT DISTINCT ci.CustId, ci.Credit AS Balance
			FROM	@tmpCustId c
				INNER JOIN DBCUST.custDB.dbo.custInfo ci WITH(NOLOCK)						
					ON	c.CustId = ci.CustId
		) c
		GROUP BY c.custid
		FOR XML PATH('r'), ROOT('root'), TYPE
	)
END
GO

