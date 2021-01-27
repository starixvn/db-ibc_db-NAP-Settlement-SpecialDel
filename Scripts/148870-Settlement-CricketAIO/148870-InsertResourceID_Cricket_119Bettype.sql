/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210126@Louisa
    Task: 20210126@Louisa: Cricket AIO - Early bettype [Redmine:#148870]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210126@Louisa: Insert SettlementSpecialBettypeProfile for Cricket [Redmine:#148870]
*/

USE bodb02
GO

---------------------------------------------------------
-- Step 1: Create Table for defination New ResourceID
---------------------------------------------------------

--94 early bettypes
CREATE TABLE #Cricket_Early_Bettype (
	pfID SMALLINT
	, BetType SMALLINT
	, BetID VARCHAR(6)
	, ResourceID	VARCHAR(20)
	, Prefix VARCHAR(20)
	, SettleType	CHAR(3)
)
GO

INSERT INTO  #Cricket_Early_Bettype (pfID  , BetType  , 	BetID  , 	ResourceID	 , Prefix , SettleType )
		  SELECT 100	,9400	,'0'		,9400		,'9400'		, 'EAR'		--9400	Super Over Winner	
UNION ALL SELECT 100	,9401	,'0'		,9401		,'9401'		, 'EAR'		--9401	Toss Winner	
UNION ALL SELECT 3		,9410	,'8XXX'		,94101004	,'94101XXX'	, 'EAR'		--9410	Home Group 1-X Runs		X= {4,5,6,8,10,12,15,20,25,30,35,40,45}"	
UNION ALL SELECT 3		,9411	,'8XXX'		,94111004	,'94111XXX'	, 'EAR'		--9411	Away Group 1-X Runs		X= {4,5,6,8,10,12,15,20,25,30,35,40,45}"	
UNION ALL SELECT 3		,9412	,'8XXX'		,94101005	,'94101XXX'	, 'EAR'		--9412	Home 1st Inns Group 1-X Runs	 X={5,6,10,12,15,20,25,30,35,40,45,....200}"	
UNION ALL SELECT 3		,9413	,'8XXX'		,94111005	,'94111XXX'	, 'EAR'		--9413	Away 1st Inns Group 1-X Runs X={5,6,10,12,15,20,25,30,35,40,45,....200}"	
UNION ALL SELECT 3		,9414	,'8XXX'		,94102005	,'94102XXX'	, 'EAR'		--9414	Home 2nd Inns Group 1-X Runs	X={5,6,10,12,15,20,25,30,35,40,45,....200}	
UNION ALL SELECT 3		,9415	,'8XXX'		,94112005	,'94112XXX'	, 'EAR'		--9415	Away 2nd Inns Group 1-X Runs	X={5,6,10,12,15,20,25,30,35,40,45,....200}	
UNION ALL SELECT 3		,9416	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'		--9416	Home Score at End Of Over X	X={1 - 50}
UNION ALL SELECT 3		,9417	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'		--9417	Away Score at End Of Over X	X={1 - 50}
UNION ALL SELECT 3		,9418	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'		--9418	Home 1st Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9419	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'		--9419	Away 1st Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9420	,'8XXX'		,94102001	,'94102XXX'	, 'EAR'		--9420	Home 2nd Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9421	,'8XXX'		,94112001	,'94112XXX'	, 'EAR'		--9421	Away 2nd Inns Score at End Of Over X	X={1 - 200}	
UNION ALL SELECT 3		,9422	,'8XXXYY'	,9422100101	,'94221XXXYY',	'EAR'	--9422	Home Score after Over X Ball Y	X = {1 - 50} Y={1,2,3,4,5,6}	
UNION ALL SELECT 3		,9423	,'8XXXYY'	,9423100101	,'94231XXXYY',	'EAR'	--9423	Away Score after Over X Ball Y	X = {1 - 50} Y={1,2,3,4,5,6}	
UNION ALL SELECT 3		,9428	,'8XXX'		,94281001	,'94281XXX' , 'EAR'		--9428	Home Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9429	,'8XXX'		,94291001	,'94291XXX' , 'EAR'		--9429	Away Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9430	,'8XXX'		,94281001	,'94281XXX' , 'EAR'		--9430	Home 1st Inns Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9431	,'8XXX'		,94291001	,'94291XXX' , 'EAR'		--9431	Away 1st Inns Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9432	,'8XXX'		,94282001	,'94282XXX' , 'EAR'		--9432	Home 2nd Inns Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 3		,9433	,'8XXX'		,94292001	,'94292XXX' , 'EAR'		--9433	Away 2nd Inns Fall of Wicket X	X={1 - 10}	
UNION ALL SELECT 100	,9434	,'8XXX'		,94341001	,'94341XXX' , 'EAR'		--9434	Home Wicket X Method of Dismissal	X={1 - 10}	
UNION ALL SELECT 100	,9435	,'8XXX'		,94351001	,'94351XXX' , 'EAR'		--9435	Away Wicket X Method of Dismissal	X={1 - 10}	
UNION ALL SELECT 100	,9436	,'8XXX'		,94341001	,'94341XXX' , 'EAR'		--9436	Home 1st Inns Wicket X Method of Dismissal	X={1 - 10}	
UNION ALL SELECT 100	,9437	,'8XXX'		,94351001	,'94351XXX' , 'EAR'		--9437	Away 1st Inns Wicket X Method of Dismissal 	X={1 - 10}	
UNION ALL SELECT 100	,9438	,'8XXX'		,94342001	,'94342XXX' , 'EAR'		--9438	Home 2nd Inns Wicket X Method of Dismissal 	X={1 - 10}	
UNION ALL SELECT 100	,9439	,'8XXX'		,94352001	,'94352XXX' , 'EAR'		--9439	Away 2nd Inns Wicket X Method of Dismissal 	X={1 - 10}	
UNION ALL SELECT 3		,9446	,'0'		,9446		,'9446'		, 'EAR'		--9446	Match Fours		
UNION ALL SELECT 3		,9447	,'0'		,9447		,'9447'		, 'EAR'		--9447	Match Sixes		
UNION ALL SELECT 3		,9449	,'0'		,9449		,'9449'		, 'EAR'		--9449	Match Wickets		
UNION ALL SELECT 3		,9450	,'0'		,9450		,'9450'		, 'EAR'		--9450	Match Extras		
UNION ALL SELECT 3		,9452	,'0'		,9452		,'9452'		, 'EAR'		--9452	Highest Individual Score		
UNION ALL SELECT 3		,9453	,'0'		,9453		,'9453'		, 'EAR'		--9453	Highest Over Score		
UNION ALL SELECT 3		,9454	,'0'		,94541		,'94541'	, 'EAR'		--9454	Home Inns Fours		
UNION ALL SELECT 3		,9455	,'0'		,94551		,'94551'	, 'EAR'		--9455	Away Inns Fours		
UNION ALL SELECT 3		,9460	,'0'		,94601		,'94601'	, 'EAR'		--9460	Home Inns Sixes		
UNION ALL SELECT 3		,9461	,'0'		,94611		,'94611'	, 'EAR'		--9461	Away Inns Sixes		
UNION ALL SELECT 9484	,9484	,'8XXX'		,94841001	,'94841XXX'	, 'EAR'		--9484	Home Over X Exact Runs	X={1 - 50} Non-Live only needs Over 1		
UNION ALL SELECT 9484	,9485	,'8XXX'		,94851001	,'94851XXX'	, 'EAR'		--9485	Away Over X Exact Runs	X={1 - 50} Non-Live only needs Over 1		
UNION ALL SELECT 9484	,9490	,'8XXXYY'	,9490100101	,'94901XXXYY', 'EAR'	--9490	Home Over X Ball Y Exact Runs	X={1 - 50} Y={1,2,3,4,5,6}  Non-Live only needs Over 1		
UNION ALL SELECT 9484	,9491	,'8XXXYY'	,9491100101	,'94911XXXYY', 'EAR'	--9491	Away Over X Ball Y Exact Runs	X={1 - 50} Y={1,2,3,4,5,6}  Non-Live only needs Over 1		
UNION ALL SELECT 2		,9502	,'8XXX'		,94101004	,'94101XXX'	, 'EAR'		--9502	Home Group 1-X Runs OE	  X= {4,5,6,8,10,12,15,20,25,30,35,40,45}"		
UNION ALL SELECT 2		,9503	,'8XXX'		,94111004	,'94111XXX'	, 'EAR'		--9503	Away Group 1-X Runs OE	 X= {4,5,6,8,10,12,15,20,25,30,35,40,45}"		
UNION ALL SELECT 2		,9504	,'8XXX'		,94101005	,'94101XXX'	, 'EAR'		--9504	Home 1st Inns Group 1-X Runs OE	    X={5,6,10,12,15,20,25,30,35,40,45,....200}"		
UNION ALL SELECT 2		,9505	,'8XXX'		,94111005	,'94111XXX'	, 'EAR'		--9505	Away 1st Inns Group 1-X Runs OE	   X={5,6,10,12,15,20,25,30,35,40,45,....200}"		
UNION ALL SELECT 2		,9506	,'8XXX'		,94102005	,'94102XXX'	, 'EAR'		--9506	Home 2nd Inns Group 1-X Runs OE	X={5,6,10,12,15,20,25,30,35,40,45,....200}		
UNION ALL SELECT 2		,9507	,'8XXX'		,94112005	,'94112XXX'	, 'EAR'		--9507	Away 2nd Inns Group 1-X Runs OE	X={5,6,10,12,15,20,25,30,35,40,45,....200}		
UNION ALL SELECT 2		,9508	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'		--9508	Home Score at End Of Over X OE	X={1 - 50}		
UNION ALL SELECT 2		,9509	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'		--9509	Away Score at End Of Over X OE	X={1 - 50}		
UNION ALL SELECT 2		,9510	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'		--9510	Home 1st Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9511	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'		--9511	Away 1st Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9512	,'8XXX'		,94102001	,'94102XXX'	, 'EAR'		--9512	Home 2nd Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9513	,'8XXX'		,94112001	,'94112XXX'	, 'EAR'		--9513	Away 2nd Inns Score at End Of Over X OE	X={1 - 200}		
UNION ALL SELECT 2		,9514	,'8XXX'		,94281001	,'94281XXX'	, 'EAR'		--9514	Home Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9515	,'8XXX'		,94291001	,'94291XXX'	, 'EAR'		--9515	Away Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9516	,'8XXX'		,94281001	,'94281XXX'	, 'EAR'		--9516	Home 1st Inns Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9517	,'8XXX'		,94291001	,'94291XXX'	, 'EAR'		--9517	Away 1st Inns Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9518	,'8XXX'		,94282001	,'94282XXX'	, 'EAR'		--9518	Home 2nd Inns Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9519	,'8XXX'		,94292001	,'94292XXX'	, 'EAR'		--9519	Away 2nd Inns Fall of Wicket X OE	X={1 - 10}		
UNION ALL SELECT 2		,9527	,'0'		,9446		,'9446'		, 'EAR'		--9527	Match Fours OE			
UNION ALL SELECT 2		,9528	,'0'		,9447		,'9447'		, 'EAR'		--9528	Match Sixes OE			
UNION ALL SELECT 2		,9530	,'0'		,9450		,'9450'		, 'EAR'		--9530	Match Extras OE			
UNION ALL SELECT 2		,9532	,'0'		,94541		,'94541'	, 'EAR'		--9532	Home Inns Fours OE			
UNION ALL SELECT 2		,9533	,'0'		,94551		,'94551'	, 'EAR'		--9533	Away Inns Fours OE			
UNION ALL SELECT 9539	,9540	,'0'		,9400		,'9400'		, 'EAR'		--9540	Super Over Winner (Back & Lay)			
UNION ALL SELECT 9541	,9547	,'8XXX'		,94101004	,'94101XXX'	, 'EAR'		--9547	Home Group 1-X Runs Fancy	 X= {4,5,6,8,10,12,15,20,25,30,35,40,45}"		
UNION ALL SELECT 9541	,9548	,'8XXX'		,94111004	,'94111XXX'	, 'EAR'		--9548	Away Group 1-X Runs Fancy	 X= {4,5,6,8,10,12,15,20,25,30,35,40,45}"		
UNION ALL SELECT 9541	,9549	,'8XXX'		,94101005	,'94101XXX'	, 'EAR'		--9549	Home 1st Inns Group 1-X Runs Fancy	 X={5,6,10,12,15,20,25,30,35,40,45,....200}"		
UNION ALL SELECT 9541	,9550	,'8XXX'		,94111005	,'94111XXX'	, 'EAR'		--9550	Away 1st Inns Group 1-X Runs Fancy	 X={5,6,10,12,15,20,25,30,35,40,45,....200}"		
UNION ALL SELECT 9541	,9551	,'8XXX'		,94102005	,'94102XXX'	, 'EAR'		--9551	Home 2nd Inns Group 1-X Runs Fancy	X={5,6,10,12,15,20,25,30,35,40,45,....200}		
UNION ALL SELECT 9541	,9552	,'8XXX'		,94112005	,'94112XXX'	, 'EAR'		--9552	Away 2nd Inns Group 1-X Runs Fancy	X={5,6,10,12,15,20,25,30,35,40,45,....200}		
UNION ALL SELECT 9541	,9553	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'		--9553	Home Score at End Of Over X Fancy	X={1 - 50}		
UNION ALL SELECT 9541	,9554	,'8XXX'		,94111001	,'94111XXX'	, 'EAR'		--9554	Away Score at End Of Over X Fancy	X={1 - 50}		
UNION ALL SELECT 9541	,9555	,'8XXX'		,94101001	,'94101XXX'	, 'EAR'		--9555	Home 1st Inns Score at End Of Over X Fancy	X={1 - 200}		
UNION ALL SELECT 9541	,9556	,'8XXX'		,94111200	,'94111XXX'	, 'EAR'		--9556	Away 1st Inns Score at End Of Over X Fancy	X={1 - 200}		
UNION ALL SELECT 9541	,9557	,'8XXX'		,94102001	,'94102XXX'	, 'EAR'		--9557	Home 2nd Inns Score at End Of Over X Fancy	X={1 - 200}		
UNION ALL SELECT 9541	,9558	,'8XXX'		,94112001	,'94112XXX'	, 'EAR'		--9558	Away 2nd Inns Score at End Of Over X Fancy	X={1 - 200}		
UNION ALL SELECT 9541	,9559	,'8XXX'		,94281001	,'94281XXX'	, 'EAR'		--9559	Home Fall of Wicket X Fancy	X={1 - 10}		
UNION ALL SELECT 9541	,9560	,'8XXX'		,94291001	,'94291XXX'	, 'EAR'		--9560	Away Fall of Wicket X Fancy	X={1 - 10}		
UNION ALL SELECT 9541	,9561	,'8XXX'		,94281001	,'94281XXX'	, 'EAR'		--9561	Home 1st Inns Fall of Wicket X Fancy	X={1 - 10}		
UNION ALL SELECT 9541	,9562	,'8XXX'		,94291001	,'94291XXX'	, 'EAR'		--9562	Away 1st Inns Fall of Wicket X Fancy	X={1 - 10}		
UNION ALL SELECT 9541	,9563	,'8XXX'		,94282001	,'94282XXX'	, 'EAR'		--9563	Home 2nd Inns Fall of Wicket X Fancy	X={1 - 10}		
UNION ALL SELECT 9541	,9564	,'8XXX'		,94292001	,'94292XXX'	, 'EAR'		--9564	Away 2nd Inns Fall of Wicket X Fancy	X={1 - 10}		
UNION ALL SELECT 9541	,9566	,'0'		,9446		,'9446'		, 'EAR'		--9566	Match Fours Fancy			
UNION ALL SELECT 9541	,9567	,'0'		,9447		,'9447'		, 'EAR'		--9567	Match Sixes Fancy			
UNION ALL SELECT 9541	,9569	,'0'		,9449		,'9449'		, 'EAR'		--9569	Match Wickets Fancy			
UNION ALL SELECT 9541	,9570	,'0'		,9450		,'9450'		, 'EAR'		--9570	Match Extras Fancy			
UNION ALL SELECT 9541	,9572	,'0'		,9452		,'9452'		, 'EAR'		--9572	Highest Individual Score Fancy			
UNION ALL SELECT 9541	,9573	,'0'		,9453		,'9453'		, 'EAR'		--9573	Highest Over Score Fancy			
UNION ALL SELECT 9541	,9574	,'0'		,94541		,'94541'	, 'EAR'		--9574	Home Inns Fours Fancy			
UNION ALL SELECT 9541	,9575	,'0'		,94551		,'94551'	, 'EAR'		--9575	Away Inns Fours Fancy			
UNION ALL SELECT 9541	,9580	,'0'		,94601		,'94601'	, 'EAR'		--9580	Home Inns Sixes Fancy			
UNION ALL SELECT 9541	,9581	,'0'		,94611		,'94611'	, 'EAR'		--9581	Away Inns Sixes Fancy			

---------------------------------------------------------
-- Step 2: Generate ResourceID
---------------------------------------------------------

	CREATE TABLE #Number ( Num INT IDENTITY (1,1) , Suffix VARCHAR(10)	)
	SET IDENTITY_INSERT  #Number OFF
GO
	INSERT INTO  #Number   DEFAULT VALUES
	GO 5006
GO
	UPDATE #Number SET Suffix =  RIGHT ( '0000' + CAST(  Num AS VARCHAR), 5)
GO

	CREATE TABLE #Generate_ResourceID (
	 pfID		SMALLINT
	,BetType	SMALLINT 	
	,BetID		VARCHAR(6) 	
	,ResourceID	VARCHAR(20)
	,SettleType	CHAR(3)
	--,GroupType	CHAR(2)
	--,OrdNo		SMALLINT
	--,RoundID	VARCHAR(10)
	--,OddsType	SMALLINT
	--,RefResourceId	VARCHAR(20)
	)
GO

	--28 rows
	INSERT INTO #Generate_ResourceID (	pfID  , BetType  , 	BetID  , 	ResourceID	 , SettleType	 )
						SELECT pfID  , BetType  , 	BetID  , 	ResourceID	 , SettleType 
						FROM  #Cricket_Early_Bettype 
						WHERE prefix NOT LIKE '%XXX%' 
GO
	
	--2400 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID, SettleType	  )
	SELECT pfID  , BetType 	
			, '8' + RIGHT(b.Suffix, 3) 
			, LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3) 
			, SettleType
	FROM	#Cricket_Early_Bettype a, #Number b
	WHERE a.bettype IN (9418 ,9419,9420 ,9421,9510,9511,9512,9513,9555,9556,9557,9558) 
		AND b.Num <= 200

GO

	-- 240 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
			, 	'8' + RIGHT(b.Suffix, 3)  
			, 	LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3)   
			,SettleType
	FROM #Cricket_Early_Bettype a, #Number b
	WHERE a.bettype IN (9428,9429,9430,9431,9432,9433,9434,9435,9436,9437,9438,9439,9514,9515,9516,9517,9518,9519,9559,9560,9561,9562,9563,9564) 
		AND b.Num <= 10

GO

	-- 400 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
			, 	'8' + right(b.Suffix, 3)  
			, LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3)  
			, SettleType
	FROM	#Cricket_Early_Bettype a, #Number b
	WHERE a.bettype IN (9416,9417,9508,9509,9553,9554,9484,9485) 
		AND b.Num <= 50

GO

	-- 78 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
		, 	'8' + RIGHT(b.Suffix, 3)  
		, 	LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3) 	
		, SettleType
	FROM #Cricket_Early_Bettype a, #Number b
	WHERE a.bettype IN (9410,9411,9502,9503,9547,9548) 
		AND b.Num IN (4,5,6,8,10,12,15,20,25,30,35,40,45)

GO

	-- 1200 rows
	INSERT INTO  #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
		, '8' + RIGHT(b.Suffix, 5)  
		, LEFT(a.Prefix,5) + RIGHT(b.Suffix, 5) 
		, SettleType
	FROM #Cricket_Early_Bettype a, #Number b
	WHERE a.bettype in (9422,9423,9490,9491) 
		AND b.Suffix LIKE '_[0-5][0-9][0][1-6]'
		AND b.Suffix NOT IN (  00001, 00002, 00003, 00004, 00005, 00006)

GO
	--48 rows
	INSERT INTO  #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
		, 	'8' + right(b.Suffix, 3)  
		, 	LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3) 
		, SettleType
	FROM #Cricket_Early_Bettype a, #Number b
	WHERE a.bettype IN (9412,9413,9414,9415,9504,9505,9506,9507,9549,9550,9551,9552)
		AND b.Num IN ( 5,6,10,12 )  
GO
	--456 rows
	INSERT INTO  #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID,	SettleType	)
	SELECT pfID  , BetType  
	, 	'8' + right(b.Suffix, 3)  
	, 	LEFT(a.Prefix,5) + RIGHT(b.Suffix, 3) 
	, SettleType
	FROM #Cricket_Early_Bettype a, #Number b
	WHERE a.bettype IN (9412,9413,9414,9415,9504,9505,9506,9507,9549,9550,9551,9552)
		AND b.Num BETWEEN 15 AND 200
		AND b.Num % 5 = 0	  
GO

------------------------------------------------------------------------------------------------------------------
-- Step 3: Insert new generated ResourceID into dbo.SettlementSpecialBettypeProfile (Early bettype)
------------------------------------------------------------------------------------------------------------------

	INSERT INTO dbo.SettlementSpecialBettypeProfile (
	pfID
	,SportType
	,BetType
	,BetID
	,ResourceID
	,SettleType
	,GroupType
	,OrdNo
	--,RoundID
	,OddsType
	)
	SELECT 
	g.pfID
	,50
	,g.BetType
	,g.BetID
	,g.ResourceID
	,g.SettleType
	,'SP'
	,99
	--,0
	,1
	FROM #Generate_ResourceID g


---------------------------------------------------------
-- Step 4: Insert Main ResourceID
---------------------------------------------------------
	INSERT INTO dbo.SettlementSpecialBettypeProfile (
	pfID
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
	 ( 401	 ,50 ,9404		,0		,'H1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 401	 ,50 ,9405		,0		,'A1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 401	 ,50 ,9406		,0		,'H1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 401	 ,50 ,9407		,0		,'A1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 401	 ,50 ,9408		,0		,'H2'		,'MNL'		,'SP' ,99  ,'2' , 1 )
	,( 401	 ,50 ,9409		,0		,'A2'		,'MNL'		,'SP' ,99  ,'2' , 1 )
	,( 2	 ,50 ,9496		,0		,'H1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 2	 ,50 ,9497		,0		,'A1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 2	 ,50 ,9498		,0		,'H1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 2	 ,50 ,9499		,0		,'A1'		,'MNL'		,'SP' ,99  ,'1' , 1 )
	,( 2	 ,50 ,9500		,0		,'H2'		,'MNL'		,'SP' ,99  ,'2' , 1 )
	,( 2	 ,50 ,9501		,0		,'A2'		,'MNL'		,'SP' ,99  ,'2' , 1 )
	,( 9538	 ,50 ,9538		,0		,'00'		,'MNL'		,'FT' ,99  ,'0'	, 1 )
	,( 9539	 ,50 ,9539		,0		,'00'		,'MNL'		,'FT' ,99  ,'0'	, 1 )
	,( 9541	 ,50 ,9541		,0		,'H1'		,'MNL'		,'SP' ,99  ,'1' , 1 )	
	,( 9541	 ,50 ,9542		,0		,'A1'		,'MNL'		,'SP' ,99  ,'1' , 1 )	
	,( 9541	 ,50 ,9543		,0		,'H1'		,'MNL'		,'SP' ,99  ,'1' , 1 )	
	,( 9541	 ,50 ,9544		,0		,'A1'		,'MNL'		,'SP' ,99  ,'1' , 1 )	
	,( 9541	 ,50 ,9545		,0		,'H2'		,'MNL'		,'SP' ,99  ,'2' , 1 )	
	,( 9541	 ,50 ,9546		,0		,'A2'		,'MNL'		,'SP' ,99  ,'2' , 1 )	
	,( 5	 ,50 ,5			,0		,'00'		,'MNL'		,'FT' ,99  ,'0'	, 1  )
	,( 501	 ,50 ,501		,0		,'00'		,'MNL'		,'FT' ,99  ,'0'	, 2  )
	 							 