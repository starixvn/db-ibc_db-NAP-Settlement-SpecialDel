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

IF OBJECT_ID ('tempdb..#OrdNo_Cricket' ) IS NOT NULL
	BEGIN	
		DROP TABLE #OrdNo_Cricket
	END

CREATE TABLE #OrdNo_Cricket (Ord TINYINT, ResourceID VARCHAR(20))

GO

	INSERT INTO #OrdNo_Cricket (Ord  , ResourceID )
			  SELECT 1	, '9401'		
	UNION ALL SELECT 2	, '9400'		
	UNION ALL SELECT 3	, '94901_____'	
	UNION ALL SELECT 4	, '94841___'	
	UNION ALL SELECT 5	, '94221_____'  
	UNION ALL SELECT 6	, '94101___'	
	UNION ALL SELECT 7	, '94281___'	
	UNION ALL SELECT 8	, '94341___'	
	UNION ALL SELECT 9	, '94541'		
	UNION ALL SELECT 10	, '94601'		
	UNION ALL SELECT 11	, '94911_____'	
	UNION ALL SELECT 12	, '94851___'	
	UNION ALL SELECT 13	, '94231_____'	
	UNION ALL SELECT 14	, '94111___'	
	UNION ALL SELECT 15	, '94291___'	
	UNION ALL SELECT 16	, '94351___'	
	UNION ALL SELECT 17	, '94551'		
	UNION ALL SELECT 18	, '94611'		
	UNION ALL SELECT 19	, '94902_____'	
	UNION ALL SELECT 20	, '94842___'	
	UNION ALL SELECT 21	, '94222_____'	
	UNION ALL SELECT 22	, '94102___'	
	UNION ALL SELECT 23	, '94282___'	
	UNION ALL SELECT 24	, '94342___'	
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

GO

	SELECT	ROW_NUMBER() OVER(PARTITION BY 1 ORDER BY ord.Ord, p.ResourceID, p.BetType 	) AS NewOrd, p.ResourceID, p.BetType
	INTO #NewOrd
	FROM dbo.SettlementSpecialBettypeProfile p   --WHERE p.SportType = 50 and p.SettleType ='ear' --4850
		INNER JOIN #OrdNo_Cricket ord 
			ON p.ResourceID  LIKE ord.ResourceID
	WHERE p.SportType = 50
		AND p.SettleType ='EAR'

--begin tran
	UPDATE dbo.SettlementSpecialBettypeProfile 
	SET OrdNo = ord.NewOrd
	FROM SettlementSpecialBettypeProfile p
		INNER JOIN #NewOrd ord 
			ON p.ResourceID = ord.ResourceID AND p.BetType = ord.BetType
	WHERE p.SportType = 50
		AND p.SettleType = 'EAR'
--rollback tran
