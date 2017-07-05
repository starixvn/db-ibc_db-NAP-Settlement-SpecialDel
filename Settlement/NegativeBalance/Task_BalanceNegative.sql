/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_BalanceNegative]
AS
/*
	Created by: Viet
	Date: 2014-01-06
	Task: Add Customers together with their Negative Balance 
	DB: DBTXN/BODB02
	ORIGINAL SP: Task_BalanceNegativeHistoryIns_Cust, Task_BalanceNegativeDel_CustCredit
	
	Revision: 		
		- 20150316@Elodie: Support Negative Balance function for more licensee ('12Bet', 'asiabet88', 'mansion88', 'Mayfair') [Red:#30840]
		- 20150624@Elodie: Add Bodog Licensee (Licenseeid = 14)
		- 20150917@Elodie: Support Negative Balance function for all licensee [Red:#43705]
		- 20151126@Elodie: Remove BetTrade accounts in Negative Balance process [Red:#36480]
		- 20170604@Bobby: Remove dummy accounts from table CustDB-TradeCust [Red:#36480]
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpRecommend (custid INT PRIMARY KEY, site VARCHAR(50))
	CREATE TABLE #tmpBalanceLic (custid INT PRIMARY KEY, balance MONEY)
	DECLARE @tmpMatch TABLE (MatchID INT PRIMARY KEY)

	INSERT INTO #tmpRecommend (custid, site)
	SELECT c.custid, c.site
	FROM DBLIC.bodb_licensee.dbo.LicenseeCust lc
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = lc.custid
	--WHERE licenseeid IN (1, 2, 3, 9, 12, 14) -- '12Bet', 'asiabet88', 'mansion88', 'Mayfair', 'Haifa', 'Bodog'
					
	INSERT INTO @tmpMatch (MatchID)
	SELECT DISTINCT MatchID
	FROM dbo.BalanceNegative bn WITH (NOLOCK)
		INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON bn.CustID = c.custid
	WHERE StatusID = 0 
		AND c.roleid = 1
		AND c.recommend IN (SELECT custid FROM #tmpRecommend)																			

	IF @@ROWCOUNT > 0 -- found some matches
	BEGIN
		-- turn to use bettrans in realtime
		INSERT INTO #tmpBalanceLic (CustID, Balance)
		SELECT b.custid, SUM(winlost - actual_stake + playercomm)
		FROM bettrans b WITH (NOLOCK)
			INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON b.CustID = c.custid
		WHERE c.roleid = 1 AND c.recommend IN (SELECT custid FROM #tmpRecommend)								
		GROUP BY b.custid
		HAVING SUM(winlost - actual_stake + playercomm) < 0 -- negative balance

		IF @@ROWCOUNT <> 0 
		BEGIN
			INSERT INTO dbo.BalanceNegativeHistory(
				LogDate
				, ExecDate
				, MatchID
				, ActionID
				, GroupID
				, CustID
				, Balance
				, TotalBalance
				, StatusID
				, Site
				, Remark
			)
			
			SELECT	GETDATE()
					, bn.ExecDate
					, bn.MatchID
					, bn.ActionID
					, bn.GroupID
					, bn.CustID
					, bn.Balance
					, t.balance
					, 0
					, ag.site
					, bn.Remark 
			FROM	#tmpBalanceLic t WITH (NOLOCK)
					INNER JOIN dbo.BalanceNegative bn WITH (NOLOCK) ON t.custID = bn.CustID 
					INNER JOIN CustDB.dbo.CustInfo c WITH (NOLOCK) ON bn.CustID = c.custid
					INNER JOIN #tmpRecommend ag ON c.recommend = ag.custid
			WHERE	bn.MatchID IN (SELECT MatchID FROM @tmpMatch ) 
					AND bn.StatusID = 0 AND c.roleid = 1						
					AND NOT EXISTS (SELECT 1 FROM DBCUST.CustDB.dbo.BetTradeCust WHERE CustID = bn.CustID)	--Bettrade
					AND NOT EXISTS (SELECT 1 FROM DBCUST.CustDB.dbo.TradeCust WHERE CustID = bn.CustID)	--Others dummy
		END

		UPDATE dbo.BalanceNegative WITH(UPDLOCK,ROWLOCK)
		SET StatusID = 1
		WHERE MatchID IN (SELECT MatchID FROM @tmpMatch ) 
			AND StatusID = 0 
		
		DROP TABLE #tmpBalanceLic
	END

	-- Remove Credit Customer out BalanceNegative
	SELECT distinct CustID
	INTO #TempCustomer
	FROM dbo.BalanceNegative WITH (NOLOCK)
	
	IF @@ROWCOUNT > 0
	BEGIN
		DELETE #TempCustomer
		WHERE CustID IN (	SELECT custid
							FROM CustDB.dbo.custinfo WITH (NOLOCK)
							WHERE Recommend IN (SELECT custid FROM #tmpRecommend)
								AND roleid = 1
							)		
			
		DELETE dbo.BalanceNegative
		FROM #TempCustomer c
		WHERE dbo.BalanceNegative.CustID = c.CustID
	END
	
	DROP TABLE #TempCustomer
	DROP TABLE #tmpRecommend
END
GO
