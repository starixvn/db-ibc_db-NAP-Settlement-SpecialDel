/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210126@Louisa
    Task: 20210126@Louisa: Cricket AIO - Early bettype [Redmine:#148870]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210126@Louisa: Insert SettlementSpecialBettypeProfile for Cricket ( 43 new early bettype, 16 main bettype, total = 59 bettype ) [Redmine:#148870]
*/

USE bodb02
GO

---------------------------------------------------------
-- Step 1: Create Table for defination New ResourceID
---------------------------------------------------------

IF OBJECT_ID ('tempdb..#Cricket_Early_Bettype' ) IS NOT NULL
	BEGIN	
		DROP TABLE #Cricket_Early_Bettype 
	END

CREATE TABLE #Cricket_Early_Bettype (
	pfID SMALLINT
	, BetType SMALLINT
	, BetID VARCHAR(6)
	, ResourceID	VARCHAR(20)
	, Prefix VARCHAR(20)
	, SettleType	CHAR(3)
	, RangeID TINYINT
)
GO

---- 43 Early bettype (new bettype)
INSERT INTO  #Cricket_Early_Bettype (pfID  , BetType  , 	BetID  , 	ResourceID	 , Prefix , SettleType , RangeID)
		  SELECT 100	,9400	,'0'		,9400		,'9400'		, 'EAR'	,0		--Super Over Winner	
UNION ALL SELECT 100	,9401	,'0'		,9401		,'9401'		, 'EAR'	,0		--Toss Winner	
UNION ALL SELECT 3		,9410	,'8XXX'		,94101004	,'94101XXX'	, 'EAR'	,200	--Home Group 1-X Runs		X= {4,5,6,8,10,12,15,20,25,30,35,40,45,....200}"	
UNION ALL SELECT 3		,9411	,'8XXX'		,94111004	,'94111XXX'	, 'EAR'	,200	--Away Group 1-X Runs		X= {4,5,6,8,10,12,15,20,25,30,35,40,45,....200}"	
UNION ALL SELECT 3		,9412	,'8XXX'		,94101005	,'94101XXX'	, 'EAR'	,200	--Home 1st Inns Group 1-X Runs	 X={5,6,10,12,15,20,25,30,35,40,45,....200}"	
UNION ALL SELECT 3		,9413	,'8XXX'		,94111005	,'94111XXX'	, 'EAR'	,200	--Away 1st Inns Group 1-X Runs X={5,6,10,12,15,20,25,30,35,40,45,....200}"	
UNION ALL SELECT 3		,9414	,'8XXX'		,94102005	,'94102XXX'	, 'EAR'	,200	--Home 2nd Inns Group 1-X Runs	X={5,6,10,12,15,20,25,30,35,40,45,....200}	
UNION ALL SELECT 3		,9415	,'8XXX'		,94112005	,'94112XXX'	, 'EAR'	,200	--Away 2nd Inns Group 1-X Runs	X={5,6,10,12,15,20,25,30,35,40,45,....200}	
UNION ALL SELECT 3		,9416	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'	,200	--Home Score at End Of Over X	X={1 - 200}
UNION ALL SELECT 3		,9417	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'	,200	--Away Score at End Of Over X	X={1 - 200}
UNION ALL SELECT 3		,9418	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'	,200	--Home 1st Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9419	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'	,200	--Away 1st Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9420	,'8XXX'		,94102001	,'94102XXX'	, 'EAR'	,200	--Home 2nd Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9421	,'8XXX'		,94112001	,'94112XXX'	, 'EAR'	,200	--Away 2nd Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9422	,'8XXXYY'	,9422100101	,'94221XXXYY','EAR'	,200	--Home Score after Over X Ball Y	X = {1 - 200} Y={1,2,3,4,5,6}	
UNION ALL SELECT 3		,9423	,'8XXXYY'	,9423100101	,'94231XXXYY','EAR'	,200	--Away Score after Over X Ball Y	X = {1 - 200} Y={1,2,3,4,5,6}	
UNION ALL SELECT 3		,9428	,'8XXX'		,94281001	,'94281XXX' , 'EAR'	,10		--Home Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9429	,'8XXX'		,94291001	,'94291XXX' , 'EAR'	,10		--Away Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9430	,'8XXX'		,94281001	,'94281XXX' , 'EAR'	,10		--Home 1st Inns Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9431	,'8XXX'		,94291001	,'94291XXX' , 'EAR'	,10		--Away 1st Inns Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9432	,'8XXX'		,94282001	,'94282XXX' , 'EAR'	,10		--Home 2nd Inns Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9433	,'8XXX'		,94292001	,'94292XXX' , 'EAR'	,10		--Away 2nd Inns Fall of Wicket X	X={1 - 10}						
UNION ALL SELECT 9490	,9490	,'8XXXYY'	,9490100101	,'94901XXXYY', 'EAR',200	--Home Over X Ball Y Exact Runs	X={1 - 200} Y={1,2,3,4,5,6}  Non-Live only needs Over 1		
UNION ALL SELECT 9490	,9491	,'8XXXYY'	,9491100101	,'94911XXXYY', 'EAR',200	--Away Over X Ball Y Exact Runs	X={1 - 200} Y={1,2,3,4,5,6}  Non-Live only needs Over 1		
UNION ALL SELECT 2		,9502	,'8XXX'		,94101004	,'94101XXX'	, 'EAR'	,200	--Home Group 1-X Runs OE	  X= {4,5,6,8,10,12,15,20,25,30,35,40,45,....200}"		
UNION ALL SELECT 2		,9503	,'8XXX'		,94111004	,'94111XXX'	, 'EAR'	,200	--Away Group 1-X Runs OE	 X= {4,5,6,8,10,12,15,20,25,30,35,40,45}"		
UNION ALL SELECT 2		,9504	,'8XXX'		,94101005	,'94101XXX'	, 'EAR'	,200	--Home 1st Inns Group 1-X Runs OE	    X={5,6,10,12,15,20,25,30,35,40,45,....200}"		
UNION ALL SELECT 2		,9505	,'8XXX'		,94111005	,'94111XXX'	, 'EAR'	,200	--Away 1st Inns Group 1-X Runs OE	   X={5,6,10,12,15,20,25,30,35,40,45,....200}"		
UNION ALL SELECT 2		,9506	,'8XXX'		,94102005	,'94102XXX'	, 'EAR'	,200	--Home 2nd Inns Group 1-X Runs OE	X={5,6,10,12,15,20,25,30,35,40,45,....200}		
UNION ALL SELECT 2		,9507	,'8XXX'		,94112005	,'94112XXX'	, 'EAR'	,200	--Away 2nd Inns Group 1-X Runs OE	X={5,6,10,12,15,20,25,30,35,40,45,....200}		
UNION ALL SELECT 2		,9508	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'	,200	--Home Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9509	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'	,200	--Away Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9510	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'	,200	--Home 1st Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9511	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'	,200	--Away 1st Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9512	,'8XXX'		,94102001	,'94102XXX'	, 'EAR'	,200	--Home 2nd Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9513	,'8XXX'		,94112001	,'94112XXX'	, 'EAR'	,200	--Away 2nd Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9514	,'8XXX'		,94281001	,'94281XXX'	, 'EAR'	,10		--Home Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9515	,'8XXX'		,94291001	,'94291XXX'	, 'EAR'	,10		--Away Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9516	,'8XXX'		,94281001	,'94281XXX'	, 'EAR'	,10		--Home 1st Inns Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9517	,'8XXX'		,94291001	,'94291XXX'	, 'EAR'	,10		--Away 1st Inns Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9518	,'8XXX'		,94282001	,'94282XXX'	, 'EAR'	,10		--Home 2nd Inns Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9519	,'8XXX'		,94292001	,'94292XXX'	, 'EAR'	,10		--Away 2nd Inns Fall of Wicket X OE	X={1 - 10}	
UNION ALL SELECT 9540	,9540	,'0'		,9400		,'9400'		, 'EAR'	,0		--Super Over Winner (Back & Lay)


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
			VALUES ( 401	,50	,9404	,0		,'H1'	,'MNL'	,'SP' ,1  ,'1' ,1  )
				  ,( 401	,50	,9406	,0		,'H1'	,'MNL'	,'SP' ,1  ,'1' ,1  )
				  ,( 2		,50	,9496	,0		,'H1'	,'MNL'	,'SP' ,1  ,'1' ,1  )
				  ,( 2		,50	,9498	,0		,'H1'	,'MNL'	,'SP' ,1  ,'1' ,1  )
				  ,( 401	,50	,9405	,0		,'A1'	,'MNL'	,'SP' ,2  ,'1' ,1  )
				  ,( 401	,50	,9407	,0		,'A1'	,'MNL'	,'SP' ,2  ,'1' ,1  )
				  ,( 2		,50	,9497	,0		,'A1'	,'MNL'	,'SP' ,2  ,'1' ,1  )
				  ,( 2		,50	,9499	,0		,'A1'	,'MNL'	,'SP' ,2  ,'1' ,1  )
				  ,( 401	,50	,9408	,0		,'H2'	,'MNL'	,'SP' ,3  ,'2' ,1  )
				  ,( 2		,50	,9500	,0		,'H2'	,'MNL'	,'SP' ,3  ,'2' ,1  )	
				  ,( 401	,50	,9409	,0		,'A2'	,'MNL'	,'SP' ,4  ,'2' ,1  )
				  ,( 2		,50	,9501	,0		,'A2'	,'MNL'	,'SP' ,4  ,'2' ,1  )		
				  ,( 5		,50	,5		,0		,'00'	,'MNL'	,'FT' ,99 ,'0' ,1  )
				  ,( 501	,50	,501	,0		,'00'	,'MNL'	,'FT' ,99 ,'0' ,1  )
				  ,( 9538   ,50	,9538	,0		,'00'	,'MNL'	,'FT' ,99 ,'0' ,1  )
				  ,( 9539   ,50	,9539	,0		,'00'	,'MNL'	,'FT' ,99 ,'0' ,1  )

GO 