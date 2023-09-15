/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230915@Louisa
	Task: Correct column DeterminedType for Soccer [Redmine: #194049]
	DB: DBPRO-bodb02
*/
 

USE bodb02
GO

IF OBJECT_ID('tempdb..#tmp_DeterminedType') IS NOT NULL
DROP TABLE #tmp_DeterminedType

---11 rows different - column DeterminedType
SELECT Bettype, BetId, ResourceId, DeterminedType
INTO #tmp_DeterminedType
FROM dbo.SettlementSpecialBettypeProfile site WITH(NOLOCK) WHERE sporttype = 1 
EXCEPT
SELECT Bettype, BetId, ResourceId, DeterminedType
FROM DBTXN.bodb02.dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) WHERE sporttype =  1

UPDATE sp
SET DeterminedType = 1 
FROM dbo.SettlementSpecialBettypeProfile sp WITH(ROWLOCK,UPDLOCK)
	INNER JOIN #tmp_DeterminedType tmp
		ON tmp.betid		= sp.betid
		 AND tmp.bettype	= sp.bettype
		 AND tmp.ResourceId = sp.ResourceId
WHERE sp.SportType = 1
