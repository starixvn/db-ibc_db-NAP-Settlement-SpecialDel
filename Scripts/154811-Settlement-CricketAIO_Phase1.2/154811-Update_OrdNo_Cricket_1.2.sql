/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210521@Louisa
    Task: 20210521@Louisa: Cricket AIO - Phase 1.2 [Redmine:#154811]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210521@Louisa: Update Cricket OrdNo for Early Bettype [Redmine:#154811]
	

*/

USE bodb02
GO


---------------------------------------------------------
----STEP 1: Define the order of Resources
---------------------------------------------------------
	IF OBJECT_ID ('tempdb..#OrdNo_Cricket' ) IS NOT NULL
		BEGIN	
			DROP TABLE #OrdNo_Cricket
		END

	CREATE TABLE #OrdNo_Cricket (ResourceRank INT, Ord TINYINT, ResourceID VARCHAR(20))

	INSERT INTO #OrdNo_Cricket ( ResourceRank, Ord , ResourceID )
	--- Group: Other Resources - Range 1~ 1000
			  SELECT 0, 1	, '9401'	
	UNION ALL SELECT 0, 2	, '9442' --Phase 1.2
	UNION ALL SELECT 0, 3	, '9443' --Phase 1.2	
	UNION ALL SELECT 0, 4	, '9400'
	
	--- Group: Home 1st Inns - Range 1001 ~ 10000	
	UNION ALL SELECT 1000, 1	, '94901_____'		
	UNION ALL SELECT 1000, 2	, '94221_____' 
	UNION ALL SELECT 1000, 3	, '94841___'   --Phase 1.2
	UNION ALL SELECT 1000, 4	, '94101___'	
	UNION ALL SELECT 1000, 5	, '94281___'	
	UNION ALL SELECT 1000, 6	, '94341___'	
	UNION ALL SELECT 1000, 7	, '94541'		
	UNION ALL SELECT 1000, 8	, '94601'
	
	--- Group: Away 1st Inns - Range 10001	~ 20000	
	UNION ALL SELECT 10000, 1	, '94911_____'		
	UNION ALL SELECT 10000, 2	, '94231_____'	
	UNION ALL SELECT 10000, 3	, '94851___'  --Phase 1.2
	UNION ALL SELECT 10000, 4	, '94111___'	
	UNION ALL SELECT 10000, 5	, '94291___'	
	UNION ALL SELECT 10000, 6	, '94351___'	
	UNION ALL SELECT 10000, 7	, '94551'		
	UNION ALL SELECT 10000, 8	, '94611'
	
	--- Group: Home 2nd Inns - Range 20001 ~ 25000	
	UNION ALL SELECT 20000, 1	, '94902_____'	
	UNION ALL SELECT 20000, 2	, '94222_____'
	UNION ALL SELECT 20000, 3	, '94842___'  --Phase 1.2	
	UNION ALL SELECT 20000, 4	, '94102___'	
	UNION ALL SELECT 20000, 5	, '94282___'	
	UNION ALL SELECT 20000, 6	, '94342___'	
	UNION ALL SELECT 20000, 7	, '94542'
	UNION ALL SELECT 20000, 8	, '94602'

	--- Group: Away 2nd Inns - Range 25000 ~ 30000
	UNION ALL SELECT 25000, 1	, '94912_____'
	UNION ALL SELECT 25000, 2	, '94232_____'
	UNION ALL SELECT 25000, 3	, '94852___'  --Phase 1.2
	UNION ALL SELECT 25000, 4	, '94112___'
	UNION ALL SELECT 25000, 5	, '94292___'
	UNION ALL SELECT 25000, 6	, '94352___'
	UNION ALL SELECT 25000, 7	, '94552'
	UNION ALL SELECT 25000, 8	, '94612'

	--- Group: Final Round  - Range 30000 ~ 32,768(smallint)
	UNION ALL SELECT 30000, 1	, '9446'
	UNION ALL SELECT 30000, 2	, '9447'
	UNION ALL SELECT 30000, 3	, '9449'
	UNION ALL SELECT 30000, 4	, '9450'
	UNION ALL SELECT 30000, 5	, '9452'
	UNION ALL SELECT 30000, 6	, '9453'

---------------------------------------------------------
---- STEP 2: Re-order
---------------------------------------------------------
	
	IF OBJECT_ID ('tempdb..#NewOrd' ) IS NOT NULL
		BEGIN	
			DROP TABLE #NewOrd
		END
	
	CREATE TABLE #NewOrd (NewOrd SMALLINT, ResourceID VARCHAR(50), BetType SMALLINT )

	INSERT INTO #NewOrd (NewOrd, ResourceID, BetType )
	SELECT	ROW_NUMBER() OVER(PARTITION BY ord.ResourceRank ORDER BY ord.ResourceRank, ord.Ord, p.betid, ord.ResourceID, p.BetType 	) + ord.ResourceRank AS NewOrd
			, p.ResourceID
			, p.BetType
	FROM dbo.SettlementSpecialBettypeProfile p WITH(NOLOCK)
		INNER JOIN #OrdNo_Cricket ord 
			ON p.ResourceID  LIKE ord.ResourceID
	WHERE p.SportType = 50
		AND p.SettleType ='EAR'

---------------------------------------------------------
---- STEP 3: Update table
---------------------------------------------------------

	UPDATE dbo.SettlementSpecialBettypeProfile
	SET OrdNo = new.NewOrd
	FROM SettlementSpecialBettypeProfile p
		INNER JOIN #NewOrd new 
			ON p.ResourceID = new.ResourceID AND p.BetType = new.BetType
	WHERE p.SportType = 50
		AND p.SettleType = 'EAR'

GO
