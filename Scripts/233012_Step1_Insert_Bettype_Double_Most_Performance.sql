/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20250822@Louisa: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250822@Louisa: Basketball Player Prop - Bettype Performance/Other/Most [Redmine:#233012]
*/

USE bodb02
GO

IF OBJECT_ID ('tempdb..#Generate' ) IS NOT NULL
	DROP TABLE #Generate

IF OBJECT_ID ('tempdb..#Number' ) IS NOT NULL	
	DROP TABLE #Number 

IF OBJECT_ID('tempdb..#tmpBettype') IS NOT NULL
	DROP TABLE #tmpBettype
	
CREATE TABLE #Generate (  pfID	SMALLINT, BetType SMALLINT, Prefix VARCHAR(20) , RangeID SMALLINT )
CREATE TABLE #Number ( Num INT PRIMARY KEY , Suffix VARCHAR(10)	)
CREATE TABLE #tmpBettype ( pfID SMALLINT, BetType SMALLINT, BetID BIGINT, ResourceID VARCHAR(20), RoundID VARCHAR(10), GroupType CHAR(2), Num INT)

---------------------------------------------	
INSERT INTO  #Number  ( Num, Suffix)
SELECT p.number ,RIGHT('0' + CAST(number AS VARCHAR(3) ), 3) 
FROM master.dbo.spt_values p 
WHERE p.type  = 'p' and p.number BETWEEN 1 AND 99
ORDER BY p.number	
--select * from #Number

 
/*
	Bettype: Player Double Double/Player Triple Double, Most X
	pfid = 102, Resource = bettype + [01~50]
	EX: 67701
*/
	;WITH cte_PlayerDouble_Most ( pfID, bettype, betid, ResourceID, Num) AS 
	(
		 SELECT 102, b.Bettype, 800+ num, CAST(b.bettype AS VARCHAR(3) ) + n.Suffix,  Num
		 FROM (VALUES(677),(679),(680),(681), (682),(683),(684) ) b (Bettype)
			CROSS APPLY (SELECT Num, Suffix FROM #Number WHERE Num <= 50 )n
	)

	INSERT INTO dbo.SettlementSpecialBettypeProfile 
					( pfID
					  ,SportType
					  ,BetType
					  ,BetID
					  ,ResourceID
					  ,SettleType
					  ,GroupType
					  ,OddsType
					)
	SELECT tmp.pfID, 2, tmp.BetType, tmp.BetID, tmp.ResourceID, 'EAR', 'SP', NULL
	FROM cte_PlayerDouble_Most tmp 
		LEFT JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON sp.SportType = 2
				AND sp.BetType  = tmp.BetType
				AND sp.pfID		= tmp.pfID
	WHERE sp.BetType IS NULL


/*
	Bettype: Player Performance
	pfid = 9963, Resource = bettype + [01~50] + [01~99]
	EX: 6750199
*/

	;WITH cte_PlayerPerformance ( pfID, bettype, betid, ResourceID, num ) AS 
	(
		 SELECT 9963, b.Bettype, 800 + XX.num, CAST(b.bettype AS VARCHAR(3) ) + XX.Suffix + YY.Suffix, XX.num
		 FROM (VALUES(675), (676), (678) ) b (Bettype)
			CROSS APPLY (SELECT Num, Suffix FROM #Number WHERE Num <=50 )XX
			CROSS APPLY (SELECT Num, Suffix FROM #Number )YY
	)

		INSERT INTO dbo.SettlementSpecialBettypeProfile 
					( pfID
					  ,SportType
					  ,BetType
					  ,BetID
					  ,ResourceID
					  ,SettleType
					  ,GroupType
					  ,OddsType
					)
	SELECT tmp.pfID, 2, tmp.BetType, tmp.BetID, tmp.ResourceID, 'EAR', 'SP', 1
	FROM cte_PlayerPerformance tmp 
		LEFT JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON sp.SportType = 2
				AND sp.BetType  = tmp.BetType
				AND sp.pfID		= tmp.pfID
	WHERE sp.BetType IS NULL

