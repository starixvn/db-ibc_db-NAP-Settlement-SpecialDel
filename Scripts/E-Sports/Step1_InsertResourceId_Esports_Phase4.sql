/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20220111@Louisa
    Task: 20220111@Louisa: ESports Phase 4 [Redmine:#166330]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220111@Louisa: Insert SettlementSpecialBettypeProfile for ESports Phase 4 ( 54 early bettypes) [Redmine:#166330]
*/

USE bodb02
GO

	IF OBJECT_ID ('tempdb..#ESports_EAR_Bettype' ) IS NOT NULL
		BEGIN	
			DROP TABLE #ESports_EAR_Bettype
		END

	CREATE TABLE #ESports_EAR_Bettype (
		pfID SMALLINT
		, BetType SMALLINT
		, BetID VARCHAR(6)
		, Prefix VARCHAR(20)
		, Suffix	VARCHAR(20)
		, ResourceID	VARCHAR(20)
	)
	GO


INSERT INTO #ESports_EAR_Bettype (pfID , BetType , BetID , Prefix, Suffix )
 
		  SELECT 9090	,9090	,'80X'	,'90900'	,'[1-7]'		
UNION ALL SELECT 101	,9089	,'80X0Y','90890'	,'[1-7]05'		
UNION ALL SELECT 101	,9089	,'80X0Y','90890'	,'[1-7]10'		
UNION ALL SELECT 10		,9091	,'80X'	,'90910'	,'[1-7]'		
UNION ALL SELECT 3		,9092	,'80X'	,'90910'	,'[1-7]'		
UNION ALL SELECT 9128	,9095	,'80X'	,'90910'	,'[1-7]'		
UNION ALL SELECT 9096	,9096	,'80X'	,'90910'	,'[1-7]'		
UNION ALL SELECT 10		,9093	,'80X'	,'90930'	,'[1-7]'		
UNION ALL SELECT 3		,9094	,'80X'	,'90930'	,'[1-7]'		
UNION ALL SELECT 9128	,9097	,'80X'	,'90930'	,'[1-7]'		
UNION ALL SELECT 9096	,9098	,'80X'	,'90930'	,'[1-7]'		
UNION ALL SELECT 9128	,9099	,'80X'	,'90020'	,'[1-7]'		
UNION ALL SELECT 9096	,9100	,'80X'	,'90020'	,'[1-7]'		
UNION ALL SELECT 100	,9101	,'80X'	,'91010'	,'[1-7]01'		
UNION ALL SELECT 100	,9102	,'80X'	,'91010'	,'[1-7]02'		
UNION ALL SELECT 100	,9103	,'80X'	,'91010'	,'[1-7]03'		
UNION ALL SELECT 100	,9104	,'80X'	,'91010'	,'[1-7]04'		
UNION ALL SELECT 100	,9105	,'80X'	,'91010'	,'[1-7]05'		
UNION ALL SELECT 100	,9106	,'80X'	,'91010'	,'[1-7]06'		
UNION ALL SELECT 100	,9107	,'80X'	,'91010'	,'[1-7]07'		
UNION ALL SELECT 100	,9108	,'80X'	,'91010'	,'[1-7]08'		
UNION ALL SELECT 100	,9109	,'80X'	,'91010'	,'[1-7]09'		
UNION ALL SELECT 100	,9110	,'80X'	,'91010'	,'[1-7]10'		
UNION ALL SELECT 100	,9111	,'80X'	,'91010'	,'[1-7]15'		
UNION ALL SELECT 100	,9112	,'80X'	,'91010'	,'[1-7]20'		
UNION ALL SELECT 100	,9113	,'80X'	,'91130'	,'[1-5]'		
UNION ALL SELECT 100	,9114	,'80X'	,'91140'	,'[1-5]'		
UNION ALL SELECT 20		,9115	,'80X'	,'91150'	,'[1-7]'		
UNION ALL SELECT 9116	,9116	,'80X'	,'91150'	,'[1-7]'		
UNION ALL SELECT 9117	,9117	,'80X'	,'91150'	,'[1-7]'		
UNION ALL SELECT 9118	,9118	,'80X'	,'91150'	,'[1-7]'		
UNION ALL SELECT 9119	,9119	,'80X'	,'91150'	,'[1-7]'		
UNION ALL SELECT 2		,9120	,'80X'	,'91150'	,'[1-7]'		
UNION ALL SELECT 101	,9121	,'80X'	,'91210'	,'[1-7]'		
UNION ALL SELECT 100	,9122	,'80X'	,'91220'	,'[1-7]'		
UNION ALL SELECT 101	,9123	,'80X'	,'91230'	,'[1-7]'		
UNION ALL SELECT 102	,9124	,'80X'	,'91240'	,'[1-7]'		
UNION ALL SELECT 100	,9125	,'80X'	,'91250'	,'[1-5]'		
UNION ALL SELECT 101	,9126	,'80X'	,'91260'	,'[1-5]'		
UNION ALL SELECT 101	,9127	,'80X'	,'91270'	,'[1-5]'		
UNION ALL SELECT 9128	,9128	,'80X'	,'91280'	,'[1-5]'		
UNION ALL SELECT 101	,9129	,'80X'	,'91290'	,'[1-5]'		
UNION ALL SELECT 100	,9130	,'80X'	,'91300'	,'[1-5]'		
UNION ALL SELECT 101	,9131	,'80X'	,'91310'	,'[1-5]'		
UNION ALL SELECT 102	,9132	,'80X'	,'91320'	,'[1-5]'			
UNION ALL SELECT 102	,9133	,'80X'	,'91330'	,'[1-5]'		
UNION ALL SELECT 101	,9134	,'80X'	,'91340'	,'[1-5]'		
UNION ALL SELECT 100	,9135	,'80X'	,'91350'	,'[1-5]'		
UNION ALL SELECT 101	,9136	,'80X'	,'91360'	,'[1-5]'		
UNION ALL SELECT 101	,9137	,'80X'	,'91370'	,'[1-5]'		
UNION ALL SELECT 100	,9138	,'80X'	,'91380'	,'[1-5]'		
UNION ALL SELECT 3		,9139	,'80X'	,'91390'	,'[1-5]'		
UNION ALL SELECT 3		,9140	,'80X'	,'91400'	,'[1-5]'
UNION ALL SELECT 100	,9141	,'80X'	,'91410'	,'[1-7]'
UNION ALL SELECT 100	,9142	,'80X'	,'91420'	,'[1-7]'

IF OBJECT_ID ('tempdb..#Number' ) IS NOT NULL
BEGIN	
	DROP TABLE #Number 
END

CREATE TABLE #Number ( Num INT IDENTITY(1,1) PRIMARY KEY , Suffix VARCHAR(10)	)
GO
INSERT INTO  #Number  ( Suffix)
SELECT CAST(number AS VARCHAR(3) ) FROM master.dbo.spt_values p 
WHERE p.type  = 'p' and p.number BETWEEN 1 AND 720
ORDER BY p.number
 

INSERT INTO dbo.SettlementSpecialBettypeProfile (pfID	,SportType	,BetType ,BetID	,ResourceID	,SettleType	,GroupType ,RoundID	,OddsType	)
SELECT DISTINCT b.pfID
		, 43					AS SportType
		, b.BetType
		, CASE WHEN b.BetType BETWEEN 9101 AND 9112 THEN  '80'+ LEFT(n.Suffix,1)	
				ELSE '80'+ n.Suffix		
				END AS BetID
		, b.Prefix +  n.Suffix	AS ResourceID
		, 'EAR'					AS SettleType
		, ''					AS GroupType
		, '80' + LEFT(n.Suffix, 1) AS RoundID
		, NULL					AS OddsType
FROM #ESports_EAR_Bettype b
	CROSS APPLY (SELECT n.Suffix FROM #Number n WHERE n.Suffix LIKE b.Suffix) n
WHERE b.BetType NOT IN (SELECT bettype FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) WHERE sp.sporttype = 43 AND sp.BetType = b.Bettype)



