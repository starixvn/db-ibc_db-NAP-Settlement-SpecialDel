/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210521@Louisa
    Task: 20210521@Louisa: Cricket AIO - Phase 1.2 [Redmine:#154811]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210521@Louisa: Insert SettlementSpecialBettypeProfile for Cricket Phase 1.2 ( 33 bettypes) [Redmine:#154811]
*/

USE bodb02
GO

---------------------------------------------------------
-- Step 1: Create Table for defination New ResourceID
---------------------------------------------------------

IF OBJECT_ID ('tempdb..#Cricket_Early_Bettype' ) IS NOT NULL
	BEGIN	
		DROP TABLE #Cricket_Bettypes 
	END

CREATE TABLE #Cricket_Bettypes (
	pfID SMALLINT
	, BetType SMALLINT
	, BetID VARCHAR(6)
	, ResourceID	VARCHAR(20)
	, Prefix VARCHAR(20)
	, SettleType	CHAR(3)
	, RangeID TINYINT
)
GO

---- 
INSERT INTO  #Cricket_Bettypes (pfID  , BetType  , 	BetID  , 	ResourceID	 , Prefix , SettleType , RangeID)

		  SELECT 100	,9434	,'8XXX'		,94341001	,'94341XXX' , 'EAR'	,10		--Home Wicket X Method of Dismissal	X={1 - 10}	
UNION ALL SELECT 100	,9435	,'8XXX'		,94351001	,'94351XXX' , 'EAR'	,10		--Away Wicket X Method of Dismissal	X={1 - 10}	
UNION ALL SELECT 100	,9436	,'8XXX'		,94341001	,'94341XXX' , 'EAR'	,10		--Home 1st Inns Wicket X Method of Dismissal	X={1 - 10}	
UNION ALL SELECT 100	,9437	,'8XXX'		,94351001	,'94351XXX' , 'EAR'	,10		--Away 1st Inns Wicket X Method of Dismissal 	X={1 - 10}	
UNION ALL SELECT 100	,9438	,'8XXX'		,94342001	,'94342XXX' , 'EAR'	,10		--Home 2nd Inns Wicket X Method of Dismissal 	X={1 - 10}	
UNION ALL SELECT 100	,9439	,'8XXX'		,94352001	,'94352XXX' , 'EAR'	,10		--Away 2nd Inns Wicket X Method of Dismissal 	X={1 - 10}	
UNION ALL SELECT 3		,9446	,'0'		,9446		,'9446'		, 'EAR'	,0		--Match Fours		
UNION ALL SELECT 3		,9447	,'0'		,9447		,'9447'		, 'EAR'	,0		--Match Sixes		
UNION ALL SELECT 3		,9449	,'0'		,9449		,'9449'		, 'EAR'	,0		--Match Wickets		
UNION ALL SELECT 3		,9450	,'0'		,9450		,'9450'		, 'EAR'	,0		--Match Extras		
UNION ALL SELECT 3		,9452	,'0'		,9452		,'9452'		, 'EAR'	,0		--Highest Individual Score		
UNION ALL SELECT 3		,9453	,'0'		,9453		,'9453'		, 'EAR'	,0		--Highest Over Score		
UNION ALL SELECT 3		,9454	,'0'		,94541		,'94541'	, 'EAR'	,0		--Home Inns Fours		
UNION ALL SELECT 3		,9455	,'0'		,94551		,'94551'	, 'EAR'	,0		--Away Inns Fours		
UNION ALL SELECT 3		,9460	,'0'		,94601		,'94601'	, 'EAR'	,0		--Home Inns Sixes		
UNION ALL SELECT 3		,9461	,'0'		,94611		,'94611'	, 'EAR'	,0		--Away Inns Sixes

UNION ALL SELECT 2		,9527	,'0'		,9446		,'9446'		, 'EAR'	,0		--Match Fours OE			
UNION ALL SELECT 2		,9528	,'0'		,9447		,'9447'		, 'EAR'	,0		--Match Sixes OE			
UNION ALL SELECT 2		,9530	,'0'		,9450		,'9450'		, 'EAR'	,0		--Match Extras OE			
UNION ALL SELECT 2		,9532	,'0'		,94541		,'94541'	, 'EAR'	,0		--Home Inns Fours OE			
UNION ALL SELECT 2		,9533	,'0'		,94551		,'94551'	, 'EAR'	,0		--Away Inns Fours OE

UNION ALL SELECT ?		,9442	,'0'		,9442		,'9442'		,'EAR'	,0		--Highest Opening Partnership
UNION ALL SELECT ?		,9443	,'0'		,9443		,'9443'		,'EAR'	,0		--Highest Score in Over 1

UNION ALL SELECT ?		,9607	,'94841X'		,?		,'94841X'	, 'EAR'	,0		--Home Over X Runs
UNION ALL SELECT ?		,9608	,'94851X'		,?		,'94851X'	, 'EAR'	,0		--Away Over X Runs
UNION ALL SELECT ?		,9609	,'94901XY'		,?		,'94901XY'	, 'EAR'	,0		--Home 1st Inns Over X Runs
UNION ALL SELECT ?		,9610	,'94911XY'		,?		,'94911XY'	, 'EAR'	,0		--Away 1st Inns Over X Runs
UNION ALL SELECT ?		,9611	,'94902XY'		,?		,'94902XY'	, 'EAR'	,0		--Home 2nd Inns Over X Runs
UNION ALL SELECT ?		,9612	,'94912XY'		,?		,'94912XY'	, 'EAR'	,0		--Away 2nd Inns Over X Runs
UNION ALL SELECT ?		,9613	,'94901XY'		,?		,'94901XY'	, 'EAR'	,0		--Home Over X Ball Y Runs
UNION ALL SELECT ?		,9614	,'94911XY'		,?		,'94911XY'	, 'EAR'	,0		--Away Over X Ball Y Runs





GO
---------------------------------------------------------
-- Step 2: Generate ResourceID
---------------------------------------------------------

IF OBJECT_ID ('tempdb..#Number' ) IS NOT NULL
	BEGIN	
		DROP TABLE #Number 
	END

	CREATE TABLE #Number ( Num INT IDENTITY (1,1) , Suffix VARCHAR(10)	)
	SET IDENTITY_INSERT  #Number OFF
GO
	INSERT INTO  #Number   DEFAULT VALUES
	GO 20006
GO

	UPDATE #Number SET Suffix =  RIGHT ( '0000' + CAST(  Num AS VARCHAR), 5)
GO


IF OBJECT_ID ('tempdb..#Generate_ResourceID' ) IS NOT NULL
	BEGIN	
		DROP TABLE #Generate_ResourceID 
	END

	CREATE TABLE #Generate_ResourceID (
	 pfID		SMALLINT
	,BetType	SMALLINT 	
	,BetID		VARCHAR(6) 	
	,ResourceID	VARCHAR(20)
	,SettleType	CHAR(3)
	)
GO

	--- Bettypes do not belong to Over XXX
	--- 3 rows
	INSERT INTO #Generate_ResourceID 
		(  pfID  , BetType  , 	BetID  , 	ResourceID	 , SettleType	 )
	SELECT pfID  , BetType  , 	BetID  , 	ResourceID	 , SettleType 
	FROM   #Cricket_Early_Bettype 
	WHERE  RangeID = 0

GO
	 
	--- Bettype on Over XXX
	--- 4800 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID, SettleType	  )
		SELECT pfID,	BetType 	
				, '8' + RIGHT(b.Suffix, 3) 
				, LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3) 
				, SettleType
		FROM	#Cricket_Early_Bettype a, #Number b
		WHERE a.RangeID = 200 
			AND Prefix LIKE '%XXX'
			AND b.Num <= 200

GO

	-- Bettype on Wicket XX
	--- 120 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
			, '8' + RIGHT(b.Suffix, 3)  
			, LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3)   
			, SettleType
	FROM #Cricket_Early_Bettype a, #Number b
	WHERE a.RangeID = 10 
		AND Prefix LIKE '%XXX'
		AND b.Num <= 10

GO

	-- Bettype on Over XXX Ball YY
	-- 4800 rows
	INSERT INTO  #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
		, '8' + RIGHT(b.Suffix, 5)  
		, LEFT(a.Prefix,5) + RIGHT(b.Suffix, 5) 
		, SettleType
	FROM #Cricket_Early_Bettype a, #Number b
	WHERE a.RangeID = 200
		AND a.Prefix LIKE '%YY'
		AND b.Suffix LIKE '[0-2][0-9][0-9][0][1-6]'
		AND b.Suffix NOT IN (  00001, 00002, 00003, 00004, 00005, 00006)

GO

------------------------------------------------------------------------------------------------------------------
-- Step 3: Insert new generated ResourceID into dbo.SettlementSpecialBettypeProfile (Early bettype)
------------------------------------------------------------------------------------------------------------------

	--- 9723 rows
	INSERT INTO dbo.SettlementSpecialBettypeProfile
			(pfID
			,SportType
			,BetType
			,BetID
			,ResourceID
			,SettleType
			,GroupType
			,OddsType
			)
	SELECT	g.pfID
			,50
			,g.BetType
			,g.BetID
			,g.ResourceID
			,g.SettleType
			,'SP'
			,1
	FROM #Generate_ResourceID g


---------------------------------------------------------
-- Step 4: Insert Main ResourceID
---------------------------------------------------------

	--- 16 main bettype
	--- 16 rowsndID
	INSERT INTO dbo.SettlementSpecialBettypeProfile
				( pfID
				  ,SportType
				  ,BetType
				  ,BetID
				  ,ResourceID
				  ,SettleType
				  ,GroupType
				  ,OrdNo
				  ,RoundID
				  ,OddsType
				)
			VALUES 
	 ( 3	 ,50	,9604		,0		,'00'		,'MNL'		,'FT', 99 ,'0' , 1 )
	,( 2	 ,50	,9605		,0		,'00'		,'MNL'		,'FT', 99 ,'0' , 1 )

GO 