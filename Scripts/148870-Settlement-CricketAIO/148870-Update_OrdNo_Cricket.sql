/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210126@Louisa
    Task: 20210126@Louisa: Cricket AIO - Early bettype [Redmine:#148870]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210126@Louisa: Update Cricket OrdNo for SettlementSpecialBettypeProfile  [Redmine:#148870]
*/

USE bodb02
GO

CREATE TABLE #OrdNo_Cricket (Ord TINYINT, ResourceID VARCHAR(20))
GO

INSERT INTO #OrdNo_Cricket (Ord  , ResourceID )
		  SELECT 1	, '9401'		--9401		
UNION ALL SELECT 2	, '9400'		--9400		
UNION ALL SELECT 3	, '94901_____'		--94901XY	
UNION ALL SELECT 4	, '94841___'		--94841X	
UNION ALL SELECT 5	, '94221_____'      --94221XY	
UNION ALL SELECT 6	, '94101___'		--94101X	
UNION ALL SELECT 7	, '94281___'		--94281X	
UNION ALL SELECT 8	, '94341___'		--94341X	
UNION ALL SELECT 9	, '94541'	--94541		
UNION ALL SELECT 10	, '94601'		--94601		
UNION ALL SELECT 11	, '94911_____'		--94911XY	
UNION ALL SELECT 12	, '94851___'		--94851X	
UNION ALL SELECT 13	, '94231_____'		--94231XY	
UNION ALL SELECT 14	, '94111___'		--94111X	
UNION ALL SELECT 15	, '94291___'		--94291X	
UNION ALL SELECT 16	, '94351___'		--94351X	
UNION ALL SELECT 17	, '94551'		--94551		
UNION ALL SELECT 18	, '94611'		--94611		
UNION ALL SELECT 19	, '94902_____'		--94902XY	
UNION ALL SELECT 20	, '94842___'		--94842X	
UNION ALL SELECT 21	, '94222_____'		--94222XY	
UNION ALL SELECT 22	, '94102___'		--94102X	
UNION ALL SELECT 23	, '94282___'		--94282X	
UNION ALL SELECT 24	, '94342___'		--94342X	
UNION ALL SELECT 25	, '94542'
UNION ALL SELECT 26	, '94602'
UNION ALL SELECT 27	, '94912_____'
UNION ALL SELECT 28	, '94852___'
UNION ALL SELECT 29	, '94232_____'
UNION ALL SELECT 30	, '94112___'
UNION ALL SELECT 31	, '94292___'
UNION ALL SELECT 32	, '94352___'
UNION ALL SELECT 33	, '94552'
UNION ALL SELECT 34	, '94612'
UNION ALL SELECT 35	, '9446'
UNION ALL SELECT 36	, '9447'
UNION ALL SELECT 37	, '9449'
UNION ALL SELECT 38	, '9450'
UNION ALL SELECT 39	, '9452'
UNION ALL SELECT 40	, '9453'

SELECT	ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY GETDATE()	) AS NewOrd, p.ResourceID, p.BetType
INTO #NewOrd
FROM dbo.SettlementSpecialBettypeProfile p   --WHERE p.SportType = 50 and p.SettleType ='ear' --4850
	INNER JOIN #OrdNo_Cricket ord 
		ON p.ResourceID  LIKE ord.ResourceID
WHERE p.SportType = 50
	AND p.SettleType ='EAR'  
ORDER BY ord.Ord, p.ResourceID, p.BetType 

--begin tran
	UPDATE dbo.SettlementSpecialBettypeProfile 
	SET OrdNo = ord.NewOrd
	FROM SettlementSpecialBettypeProfile p
		INNER JOIN #NewOrd ord 
			ON p.ResourceID = ord.ResourceID AND p.BetType = ord.BetType
	WHERE p.SportType = 50
		AND p.SettleType = 'ear'
--rollback tran
