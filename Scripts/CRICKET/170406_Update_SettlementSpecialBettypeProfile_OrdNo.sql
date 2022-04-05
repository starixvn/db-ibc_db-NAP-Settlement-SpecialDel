/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created : 20220329@Louisa
    Task: Update Cricket OrdNo for Cricket [Redmine:#170406]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220329@Louisa: Update Cricket OrdNo for Cricket [Redmine:#170406]

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

	CREATE TABLE #OrdNo_Cricket (ResourceRank INT, Ord TINYINT, ResourceID VARCHAR(20)  )

	INSERT INTO #OrdNo_Cricket ( ResourceRank ,ResourceID, Ord  )
	--- Group: Other Resources - Range 1~ 1000
			  SELECT 0 , '9401'	 , 1
	UNION ALL SELECT 0 , '9442'	 , 2
	UNION ALL SELECT 0 , '9443'	 , 3
	UNION ALL SELECT 0 , '97081' , 4
	UNION ALL SELECT 0 , '97091' , 5
	UNION ALL SELECT 0 , '97082' , 6
	UNION ALL SELECT 0 , '97092' , 7
	UNION ALL SELECT 0 , '9400'	 , 8

	--- Group: Home 1st Inns - Range 1001 ~ 10000
	UNION ALL SELECT 1000 , '94901_____' , 1
	UNION ALL SELECT 1000 , '94221_____' , 2
	UNION ALL SELECT 1000 , '96161_____' , 3
	UNION ALL SELECT 1000 , '94841___'	 , 4
	UNION ALL SELECT 1000 , '94101___'	 , 5
	UNION ALL SELECT 1000 , '94281___'	 , 6
	UNION ALL SELECT 1000 , '94341___'	 , 7
	UNION ALL SELECT 1000 , '96361___'	 , 8
	UNION ALL SELECT 1000 , '96241___'	 , 9
	UNION ALL SELECT 1000 , '96301___'	 , 10
	UNION ALL SELECT 1000 , '96621___'	 , 11
	UNION ALL SELECT 1000 , '96761___'	 , 12
	UNION ALL SELECT 1000 , '96801___'	 , 13
	UNION ALL SELECT 1000 , '97361___'	 , 14
	UNION ALL SELECT 1000 , '97301___'	 , 15
	UNION ALL SELECT 1000 , '94541'		 , 16
	UNION ALL SELECT 1000 , '94601'		 , 17
	UNION ALL SELECT 1000 , '96681'		 , 18
	UNION ALL SELECT 1000 , '96501'		 , 19
	UNION ALL SELECT 1000 , '96721'		 , 20
	UNION ALL SELECT 1000 , '96561'		 , 21

	--- Group: Away 1st Inns - Range 10001	~ 20000
	UNION ALL SELECT 10000 , '94911______' , 1
	UNION ALL SELECT 10000 , '94231______' , 2
	UNION ALL SELECT 10000 , '96171______' , 3
	UNION ALL SELECT 10000 , '94851___'	   , 4
	UNION ALL SELECT 10000 , '94111___'	   , 5
	UNION ALL SELECT 10000 , '94291___'	   , 6
	UNION ALL SELECT 10000 , '94351___'	   , 7
	UNION ALL SELECT 10000 , '96371___'	   , 8
	UNION ALL SELECT 10000 , '96251___'	   , 9
	UNION ALL SELECT 10000 , '96311___'	   , 10
	UNION ALL SELECT 10000 , '96631___'	   , 11
	UNION ALL SELECT 10000 , '96861___'	   , 12
	UNION ALL SELECT 10000 , '96901___'	   , 13
	UNION ALL SELECT 10000 , '97371___'	   , 14
	UNION ALL SELECT 10000 , '97311___'	   , 15
	UNION ALL SELECT 10000 , '94551'	   , 16
	UNION ALL SELECT 10000 , '94611'	   , 17
	UNION ALL SELECT 10000 , '96711'	   , 18
	UNION ALL SELECT 10000 , '96511'	   , 19
	UNION ALL SELECT 10000 , '96751'	   , 20
	UNION ALL SELECT 10000 , '96571'	   , 21

	--- Group: Home 2nd Inns - Range 20001 ~ 25000
	UNION ALL SELECT 20000 , '94902_____'	,1
	UNION ALL SELECT 20000 , '94222_____'	,2
	UNION ALL SELECT 20000 , '96162_____'	,3
	UNION ALL SELECT 20000 , '94842___'		,4
	UNION ALL SELECT 20000 , '94102___'		,5
	UNION ALL SELECT 20000 , '94282___'		,6
	UNION ALL SELECT 20000 , '94342___'		,7
	UNION ALL SELECT 20000 , '96362___'		,8
	UNION ALL SELECT 20000 , '96242___'		,9
	UNION ALL SELECT 20000 , '96302___'		,10
	UNION ALL SELECT 20000 , '96622___'		,11
	UNION ALL SELECT 20000 , '96762___'		,12
	UNION ALL SELECT 20000 , '96802___'		,13
	UNION ALL SELECT 20000 , '97362___'		,14
	UNION ALL SELECT 20000 , '97302___'		,15
	UNION ALL SELECT 20000 , '94542'		,16
	UNION ALL SELECT 20000 , '94602'		,17
	UNION ALL SELECT 20000 , '96682'		,18
	UNION ALL SELECT 20000 , '96502'		,19
	UNION ALL SELECT 20000 , '96722'		,20
	UNION ALL SELECT 20000 , '96562'		,21

	--- Group: Away 2nd Inns - Range 25001 ~ 30000
	UNION ALL SELECT 25000 , '94912_____'	,1
	UNION ALL SELECT 25000 , '94232_____'	,2
	UNION ALL SELECT 25000 , '96172_____'	,3
	UNION ALL SELECT 25000 , '94852___'		,4
	UNION ALL SELECT 25000 , '94112___'		,5
	UNION ALL SELECT 25000 , '94292___'		,6
	UNION ALL SELECT 25000 , '94352___'		,7
	UNION ALL SELECT 25000 , '96372___'		,8
	UNION ALL SELECT 25000 , '96252___'		,9
	UNION ALL SELECT 25000 , '96312___'		,10
	UNION ALL SELECT 25000 , '96632___'		,11
	UNION ALL SELECT 25000 , '96862___'		,12
	UNION ALL SELECT 25000 , '96902___'		,13
	UNION ALL SELECT 25000 , '97372___'		,14
	UNION ALL SELECT 25000 , '97312___'		,15
	UNION ALL SELECT 25000 , '94552'		,16
	UNION ALL SELECT 25000 , '94612'		,17
	UNION ALL SELECT 25000 , '96712'		,18
	UNION ALL SELECT 25000 , '96512'		,19
	UNION ALL SELECT 25000 , '96752'		,20
	UNION ALL SELECT 25000 , '96572'		,21

	--- Group: Final Round  - Range 30000 ~ 32,768(smallint)
	UNION ALL SELECT 30000 , '9446'	 , 1
	UNION ALL SELECT 30000 , '9447'	 , 2
	UNION ALL SELECT 30000 , '9449'	 , 3
	UNION ALL SELECT 30000 , '9450'	 , 4
	UNION ALL SELECT 30000 , '96151' , 5
	UNION ALL SELECT 30000 , '94511' , 6
	UNION ALL SELECT 30000 , '9452'	 , 7
	UNION ALL SELECT 30000 , '9453'	 , 8

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
