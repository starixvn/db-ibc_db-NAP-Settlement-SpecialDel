/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210521@Louisa
    Task: 20210521@Louisa: Cricket AIO - Phase 1.2 [Redmine:#154811]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210521@Louisa: Insert SettlementSpecialBettypeProfile for Cricket Phase 1.2 ( 33 bettypes- 31 early + 2 main) [Redmine:#154811]
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
		, Prefix VARCHAR(25)
		, SettleType	CHAR(3)
		, RangeID SMALLINT
	)
	GO

---- 31 rows
	INSERT INTO  #Cricket_Early_Bettype
					(pfID ,BetType ,BetID  ,ResourceID	 ,Prefix	,SettleType ,RangeID)
				 								
			  SELECT 100  ,9434	   ,'8XXX'	 ,94341001	 ,'94341'	,'EAR'	,10		--Home Wicket X Method of Dismissal			--[001-010]				
	UNION ALL SELECT 100  ,9435	   ,'8XXX'	 ,94351001	 ,'94351'	,'EAR'	,10		--Away Wicket X Method of Dismissal			--[001-010]		
	UNION ALL SELECT 100  ,9436	   ,'8XXX'	 ,94341001	 ,'94341'	,'EAR'	,10		--Home 1st Inns Wicket X Method of Dismissa	--[001-010]			
	UNION ALL SELECT 100  ,9437	   ,'8XXX'	 ,94351001	 ,'94351'	,'EAR'	,10		--Away 1st Inns Wicket X Method of Dismissa	--[001-010]			
	UNION ALL SELECT 100  ,9438	   ,'8XXX'	 ,94342001	 ,'94342'	,'EAR'	,10		--Home 2nd Inns Wicket X Method of Dismissa	--[001-010]			
	UNION ALL SELECT 100  ,9439	   ,'8XXX'	 ,94352001	 ,'94352'	,'EAR'	,10		--Away 2nd Inns Wicket X Method of Dismissa --[001-010]				
	UNION ALL SELECT 100  ,9442	   ,'0'		 ,9442		 ,'9442'	,'EAR' ,0		--Highest Opening Partnership							
	UNION ALL SELECT 100  ,9443	   ,'0'		 ,9443		 ,'9443'	,'EAR' ,0		--Highest Score in Over 1								
	UNION ALL SELECT 3	  ,9446	   ,'0'		 ,9446		 ,'9446'	,'EAR' ,0		--Match Fours											
	UNION ALL SELECT 3	  ,9447	   ,'0'		 ,9447		 ,'9447'	,'EAR' ,0		--Match Sixes											
	UNION ALL SELECT 3	  ,9449	   ,'0'		 ,9449		 ,'9449'	,'EAR' ,0		--Match Wickets										
	UNION ALL SELECT 3	  ,9450	   ,'0'		 ,9450		 ,'9450'	,'EAR' ,0		--Match Extras										
	UNION ALL SELECT 3	  ,9452	   ,'0'		 ,9452		 ,'9452'	,'EAR' ,0		--Highest Individual Score							
	UNION ALL SELECT 3	  ,9453	   ,'0'		 ,9453		 ,'9453'	,'EAR' ,0		--Highest Over Score									
	UNION ALL SELECT 3	  ,9454	   ,'0'		 ,94541		 ,'94541'	,'EAR' ,0		--Home Inns Fours										
	UNION ALL SELECT 3	  ,9455	   ,'0'		 ,94551		 ,'94551'	,'EAR' ,0		--Away Inns Fours										
	UNION ALL SELECT 3	  ,9460	   ,'0'		 ,94601		 ,'94601'	,'EAR' ,0		--Home Inns Sixes										
	UNION ALL SELECT 3	  ,9461	   ,'0'		 ,94611		 ,'94611'	,'EAR' ,0		--Away Inns Sixes										
	UNION ALL SELECT 2	  ,9527	   ,'0'		 ,9446		 ,'9446'	,'EAR' ,0		--Match Fours OE										
	UNION ALL SELECT 2	  ,9528	   ,'0'		 ,9447		 ,'9447'	,'EAR' ,0		--Match Sixes OE										
	UNION ALL SELECT 2	  ,9530	   ,'0'		 ,9450		 ,'9450'	,'EAR' ,0		--Match Extras OE										
	UNION ALL SELECT 2	  ,9532	   ,'0'		 ,94541		 ,'94541'	,'EAR' ,0		--Home Inns Fours OE									
	UNION ALL SELECT 2	  ,9533	   ,'0'		 ,94551		 ,'94551'	,'EAR' ,0		--Away Inns Fours OE										
	UNION ALL SELECT 3	  ,9607	   ,'8XXX'	 ,94841001	 ,'94841'	,'EAR' ,200	--Home Over X Runs			--[001-200]									
	UNION ALL SELECT 3	  ,9608	   ,'8XXX'	 ,94851001	 ,'94851'	,'EAR' ,200	--Away Over X Runs			--[001-200]							
	UNION ALL SELECT 3	  ,9609	   ,'8XXX'	 ,94841001	 ,'94841'	,'EAR' ,200	--Home 1st Inns Over X Runs	--[001-200]							
	UNION ALL SELECT 3	  ,9610	   ,'8XXX'	 ,94851001	 ,'94851'	,'EAR' ,200	--Away 1st Inns Over X Runs	--[001-200]							
	UNION ALL SELECT 3	  ,9611	   ,'8XXX'	 ,94842001	 ,'94842'	,'EAR' ,200	--Home 2nd Inns Over X Runs	--[001-200]							
	UNION ALL SELECT 3	  ,9612	   ,'8XXX'	 ,94852001	 ,'94852'	,'EAR' ,200	--Away 2nd Inns Over X Runs	--[001-200]							
	UNION ALL SELECT 3	  ,9613	   ,'8XXXYY' ,9490100101 ,'94901'	,'EAR' ,20006--Home Over X Ball Y Runs --[001-200][01-06]											
	UNION ALL SELECT 3	  ,9614	   ,'8XXXYY' ,9491100101 ,'94911'	,'EAR' ,20006	--Away Over X Ball Y Runs --[001-200][01-06]											

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
		GO 200
GO

	UPDATE #Number SET Suffix =  RIGHT ( '00' + CAST(  Num AS VARCHAR), 3)
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
	--- 17 bettype-17 rows
	INSERT INTO #Generate_ResourceID 
		(  pfID  , BetType  , 	BetID  , 	ResourceID	 , SettleType	 )
	SELECT pfID  , BetType  , 	BetID  , 	ResourceID	 , SettleType 
	FROM   #Cricket_Early_Bettype 
	WHERE  RangeID = 0

GO
	 
	--- Bettype on Wicket XXX
	--- 6 bettype - 60 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID, SettleType	  )	
	SELECT pfID	
			,BetType 	
			, '8' + b.Suffix AS Betid
			,Prefix + b.Suffix as ResourceId
			, SettleType
		FROM	#Cricket_Early_Bettype a, #Number b
		WHERE a.RangeID = 10
			AND b.Num <= 10

GO
	--- Bettype on Over XXX
	--- 6 bettype - 1200 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID, SettleType	  )	
	SELECT pfID	
			,BetType 	
			, '8' + b.Suffix AS Betid
			,Prefix + b.Suffix AS ResourceId
			, SettleType
		FROM	#Cricket_Early_Bettype a, #Number b
		WHERE a.RangeID = 200 --001-200
GO

	--- Bettype on Over XXX Ball YY
	--- 2 bettype - 2400 rows
	INSERT INTO #Generate_ResourceID  (pfID,	BetType,	BetID,	ResourceID, SettleType	  )	
	SELECT pfID	
			,BetType 	
			, '8' + b.Suffix + v.BallYY AS Betid
			,Prefix + b.Suffix +  v.BallYY AS ResourceId
			, SettleType
		FROM	#Cricket_Early_Bettype a
			, #Number b
			, ( VALUES	 ('01' ),('02'), ('3'),('4'),('5'),('6') ) v (BallYY)
		WHERE a.RangeID = 20006

------------------------------------------------------------------------------------------------------------------
-- Step 3: Insert new generated ResourceID into dbo.SettlementSpecialBettypeProfile (Early bettype)
------------------------------------------------------------------------------------------------------------------
	
	---1200 + 2400 + 60 + 17 = 3677 rows
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

	--- 2 main bettype - 2 rows
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
	 ( 3	 ,50	,9604	,0		,'00'	,'MNL'	,'FT', 99 ,'0' , 1 ) --Over/Under (dec)
	,( 2	 ,50	,9605	,0		,'00'	,'MNL'	,'FT', 99 ,'0' , 1 ) --Odd/Even (dec)

GO 