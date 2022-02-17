/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/    
/* 
	Created by: 20220128@Louisa
    Task: 20220128@Louisa: Cricket AIO Phase 2 [Redmine:#166335]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220128@Louisa: Insert SettlementSpecialBettypeProfile for Cricket Phase 2.0 ( 174 bettypes) [Redmine:#166335]
*/

USE bodb02
GO


---STEP 1: insert fomular
	IF OBJECT_ID ('tempdb..#Cricket_2' ) IS NOT NULL
	DROP TABLE #Cricket_2

	CREATE TABLE #Cricket_2 (  pfID	SMALLINT, BetType SMALLINT, Prefix VARCHAR(20) , RangeID SMALLINT )

	IF OBJECT_ID ('tempdb..#Temp_ResourceID' ) IS NOT NULL	
	DROP TABLE #Temp_ResourceID

	CREATE TABLE #Temp_ResourceID (
		  pfID		SMALLINT
		, BetType	SMALLINT
		, BetID		VARCHAR(7)
		, ResourceID VARCHAR(20)
		, Num		INT
	)

	IF OBJECT_ID ('tempdb..#Number' ) IS NOT NULL	
	DROP TABLE #Number 

	CREATE TABLE #Number ( Num INT PRIMARY KEY , Suffix VARCHAR(10)	)

	INSERT INTO  #Number  ( Num, Suffix)
	SELECT p.number ,RIGHT('00' + CAST(number AS VARCHAR(3) ), 3) 
	FROM master.dbo.spt_values p 
	WHERE p.type  = 'p' and p.number BETWEEN 1 AND 200
	ORDER BY p.number

-------------------------------------------------------	----------------------------------------------------------
	INSERT INTO #Cricket_2 (pfID , BetType , Prefix, RangeID )
 
			  SELECT 9541	,9541	,'H1'		,0	 --Home Inns Runs Fancy 												
	UNION ALL SELECT 9541	,9542	,'A1'		,0	 --Away Inns Runs Fancy 													
	UNION ALL SELECT 9541	,9543	,'H1'		,0	 --Home 1st Inns Runs Fancy 													
	UNION ALL SELECT 9541	,9544	,'A1'		,0	 --Away 1st Inns Runs Fancy 													
	UNION ALL SELECT 9541	,9545	,'H2'		,0	 --Home 2nd Inns Runs Fancy 													
	UNION ALL SELECT 9541	,9546	,'A2'		,0	 --Away 2nd Inns Runs Fancy 									  
	UNION ALL SELECT 9606	,9606	,'00'		,0	 --Fancy --Child match													
	UNION ALL SELECT 5		,9440	,'9446'		,0	 --Most Fours 											
	UNION ALL SELECT 5		,9441	,'9447'		,0	 --Most Sixes 											
	UNION ALL SELECT 5		,9615	,'96151'	,0	 --Most Run Outs 											
	UNION ALL SELECT 9448	,9448	,'96151'	,0	 --Match Run Outs 										
	UNION ALL SELECT 2		,9529	,'96151'	,0	 --Match Run Outs OE 								
	UNION ALL SELECT 9448	,9451	,'94511'	,0	 --Match Dot Balls 									
	UNION ALL SELECT 2		,9531	,'94511'	,0	 --Match Dot Balls OE 												
	UNION ALL SELECT 7901	,9616	,'96161'	,50	 --Home Over X Delivery Y Runs	 
	UNION ALL SELECT 7901	,9617	,'96171'	,50	 --Away Over X Delivery Y Runs	 
	UNION ALL SELECT 8102	,9618	,'94841'	,50	 --Home Over X Runs OE			 
	UNION ALL SELECT 8102	,9619	,'94851'	,50	 --Away Over X Runs OE			 
	UNION ALL SELECT 8102	,9620	,'94841'	,200 --Home 1st Inns Over X Runs OE	 
	UNION ALL SELECT 8102	,9621	,'94851'	,200 --Away 1st Inns Over X Runs OE	 
	UNION ALL SELECT 8102	,9622	,'94842'	,200 --Home 2nd Inns Over X Runs OE	 			
	UNION ALL SELECT 8102	,9623	,'94852'	,200 --Away 2nd Inns Over X Runs OE	 			
	UNION ALL SELECT 102	,9624	,'96241'	,50	 --Will there be a Boundary Fours in Home Over X? 						
	UNION ALL SELECT 102	,9625	,'96251'	,50	 --Will there be a Boundary Fours in Away Over X? 						
	UNION ALL SELECT 102	,9626	,'96241'	,200 --Will there be a Boundary Fours in Home 1st Inns Over X?  			
	UNION ALL SELECT 102	,9627	,'96251'	,200 --Will there be a Boundary Fours in Away1st Inns Over X?	 				
	UNION ALL SELECT 102	,9628	,'96242'	,200 --Will there be a Boundary Fours in Home 2nd Inns Over X?  							
	UNION ALL SELECT 102	,9629	,'96252'	,200 --Will there be a Boundary Fours in Away 2nd Inns Over X?  							
	UNION ALL SELECT 102	,9630	,'96301'	,50  --Will there be a Boundary Sixes in Home Over X?			 			
	UNION ALL SELECT 102	,9631	,'96311'	,50  --Will there be a Boundary Sixes in Away Over X?			 			
	UNION ALL SELECT 102	,9632	,'96301'	,200 --Will there be a Boundary Sixes in Home 1st Inns Over X?	 			
	UNION ALL SELECT 102	,9633	,'96311'	,200 --Will there be a Boundary Sixes in Away 1st Inns Over X?	 			
	UNION ALL SELECT 102	,9634	,'96302'	,200 --Will there be a Boundary Sixes in Home 2nd Inns Over X?	 					
	UNION ALL SELECT 102	,9635	,'96312'	,200 --Will there be a Boundary Sixes in Away 2nd Inns Over X?	 					
	UNION ALL SELECT 9484	,9484	,'94841'	,50	 --Home Over X Exact Runs			 				
	UNION ALL SELECT 9484	,9485	,'94851'	,50	 --Away Over X Exact Runs			 				
	UNION ALL SELECT 9486	,9486	,'94841'	,200 --Home 1st Inns Over X Exact Runs	 										
	UNION ALL SELECT 9486	,9487	,'94851'	,200 --Away 1st Inns Over X Exact Runs	 										
	UNION ALL SELECT 9486	,9488	,'94842'	,200 --Home 2nd Inns Over X Exact Runs	 										
	UNION ALL SELECT 9486	,9489	,'94852'	,200 --Away 2nd Inns Over X Exact Runs	 										
	UNION ALL SELECT 9636	,9636	,'96361'	,10	 --Home Wicket X Method of Dismissal (6 Way) 
	UNION ALL SELECT 9636	,9637	,'96371'	,10	 --Away Wicket X Method of Dismissal (6 Way) 
	UNION ALL SELECT 9636	,9638	,'96361'	,10	 --Home 1st Inns Wicket X Method of Dismissal (6 Way) 
	UNION ALL SELECT 9636	,9639	,'96371'	,10	 --Away 1st Inns Wicket X Method of Dismissal (6 Way) 
	UNION ALL SELECT 9636	,9640	,'96362'	,10	 --Home 2nd Inns Wicket X Method of Dismissal (6 Way)   
	UNION ALL SELECT 9636	,9641	,'96372'	,10	 --Away 2nd Inns Wicket X Method of Dismissal (6 Way)   
	UNION ALL SELECT 9541	,9547	,'94101'	,45	 --Home Group 1-X Runs Fancy--X={5,6,10}Live: X={4,5,6,8,10,12,15,20,25,30,35,40,45}  
	UNION ALL SELECT 9541	,9548	,'94111'	,45	 --Away Group 1-X Runs Fancy--X={5,6,10}Live: X={4,5,6,8,10,12,15,20,25,30,35,40,45}  
	UNION ALL SELECT 9541	,9549	,'94101'	,200 --Home 1st Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,....200}	  	 
	UNION ALL SELECT 9541	,9550	,'94111'	,200 --Away 1st Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,....200}	  	 																			
	UNION ALL SELECT 9541	,9551	,'94102'	,200 --Home 2nd Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,35,40,45,....200}	 
	UNION ALL SELECT 9541	,9552	,'94112'	,200 --Away 2nd Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,35,40,45,....200}	  	 
	UNION ALL SELECT 9541	,9559	,'94281'	,10	 --Home Fall of Wicket X Fancy  										 
	UNION ALL SELECT 9541	,9560	,'94291'	,10	 --Away Fall of Wicket X Fancy  									 
	UNION ALL SELECT 9541	,9561	,'94281'	,10	 --Home 1st Inns Fall of Wicket X Fancy 									 
	UNION ALL SELECT 9541	,9562	,'94291'	,10	 --Away 1st Inns Fall of Wicket X Fancy 									 
	UNION ALL SELECT 9541	,9563	,'94282'	,10	 --Home 2nd Inns Fall of Wicket X Fancy 									 
	UNION ALL SELECT 9541	,9564	,'94292'	,10	 --Away 2nd Inns Fall of Wicket X Fancy 
	UNION ALL SELECT 9606	,9566	,'9446'		,0	 --Match Fours Fancy	 
	UNION ALL SELECT 9606	,9567	,'9447'		,0	 --Match Sixes Fancy	 
	UNION ALL SELECT 9606	,9569	,'9449'		,0	 --Match Wickets Fancy	 
	UNION ALL SELECT 9606	,9570	,'9450'		,0	 --Match Extras Fancy	 
	UNION ALL SELECT 9541	,9572	,'9452'		,0	 --Highest Individual Score Fancy  
	UNION ALL SELECT 9541	,9573	,'9453'		,0	 --Highest Over Score Fancy		  
	UNION ALL SELECT 9541	,9574	,'94541'	,0	 --Home Inns Fours Fancy		  
	UNION ALL SELECT 9541	,9575	,'94551'	,0	 --Away Inns Fours Fancy		  
	UNION ALL SELECT 9541	,9580	,'94601'	,0	 --Home Inns Sixes Fancy		  
	UNION ALL SELECT 9541	,9581	,'94611'	,0	 --Away Inns Sixes Fancy		  
	UNION ALL SELECT 9541	,9582	,'94601'	,0	 --Home 1st Inns Sixes Fancy			 
	UNION ALL SELECT 9541	,9583	,'94611'	,0	 --Away 1st Inns Sixes Fancy			 
	UNION ALL SELECT 9541	,9584	,'94602'	,0	 --Home 2nd Inns Sixes Fancy			 
	UNION ALL SELECT 9541	,9585	,'94612'	,0	 --Away 2nd Inns Sixes Fancy			 
	UNION ALL SELECT 9541	,9576	,'94541'	,0	 --Home 1st Inns Fours Fancy			 
	UNION ALL SELECT 9541	,9577	,'94551'	,0	 --Away 1st Inns Fours Fancy			 
	UNION ALL SELECT 9541	,9578	,'94542'	,0	 --Home 2nd Inns Fours Fancy			 
	UNION ALL SELECT 9541	,9579	,'94552'	,0	 --Away 2nd Inns Fours Fancy		 
	UNION ALL SELECT 9650	,9650	,'96501'	,0	 --Home Top Batsman										 
	UNION ALL SELECT 9650	,9651	,'96511'	,0	 --Away Top Batsman										 
	UNION ALL SELECT 9650	,9652	,'96501'	,0	 --Home 1st Inns Top Batsman								 
	UNION ALL SELECT 9650	,9653	,'96511'	,0	 --Away 1st Inns Top Batsman								 
	UNION ALL SELECT 9650	,9654	,'96502'	,0	 --Home 2nd Inns Top Batsman								 
	UNION ALL SELECT 9650	,9655	,'96512'	,0	 --Away 2nd Inns Top Batsman								 
	UNION ALL SELECT 9650	,9656	,'96561'	,0	 --Home Top Bowler										 
	UNION ALL SELECT 9650	,9657	,'96571'	,0	 --Away Top Bowler										 
	UNION ALL SELECT 9650	,9658	,'96561'	,0	 --Home 1st Inns Top Bowler								 
	UNION ALL SELECT 9650	,9659	,'96571'	,0	 --Away 1st Inns Top Bowler								 
	UNION ALL SELECT 9650	,9660	,'96562'	,0	 --Home 2nd Inns Top Bowler								 
	UNION ALL SELECT 9650	,9661	,'96572'	,0	 --Away 2nd Inns Top Bowler								 
	UNION ALL SELECT 9662	,9662	,'96621'	,45	 ---Home Next Man Out							 
	UNION ALL SELECT 9662	,9663	,'96631'	,45	 ---Away Next Man Out							 
	UNION ALL SELECT 9662	,9664	,'96621'	,45	 ---Home 1st Inns Next Man Out				 
	UNION ALL SELECT 9662	,9665	,'96631'	,45	 ---Away 1st Inns Next Man Out				 
	UNION ALL SELECT 9662	,9666	,'96622'	,45	 ---Home 2nd Inns Next Man Out				 
	UNION ALL SELECT 9662	,9667	,'96632'	,45	 ---Away 2nd Inns Next Man Out				 
	UNION ALL SELECT 9650	,9668	,'96681'	,0	 --Home Prematch Top Batsman									 
	UNION ALL SELECT 9650	,9669	,'96711'	,0	 --Away Prematch Top Batsman									 
	UNION ALL SELECT 9650	,9670	,'96681'	,0	 --Home 1st Inns Prematch Top Batsman						 
	UNION ALL SELECT 9650	,9671	,'96711'	,0	 --Away 1st Inns Prematch Top Batsman						 
	UNION ALL SELECT 9650	,9672	,'96721'	,0	 --Home Prematch Top Bowler									 
	UNION ALL SELECT 9650	,9673	,'96751'	,0	 --Away Prematch Top Bowler									 
	UNION ALL SELECT 9650	,9674	,'96721'	,0	 --Home 1st Inns Prematch Top Bowler							 
	UNION ALL SELECT 9650	,9675	,'96751'	,0	 --Away 1st Inns Prematch Top Bowler							 
	UNION ALL SELECT 7901	,9676	,'96761'	,5	 --Home Player Runs				
	UNION ALL SELECT 8102	,9677	,'96761'	,5	 --Home Player Runs OE				
	UNION ALL SELECT 7901	,9678	,'96761'	,5	 --Home 1st Inns Player Runs		
	UNION ALL SELECT 8102	,9679	,'96761'	,5	 --Home 1st Inns Player Runs OE	
	UNION ALL SELECT 7901	,9680	,'96801'	,10	 --Home Batsman Runs				
	UNION ALL SELECT 8102	,9681	,'96801'	,10	 --Home Batsman Runs OE			
	UNION ALL SELECT 7901	,9682	,'96801'	,10	 --Home 1st Inns Batsman Runs		
	UNION ALL SELECT 8102	,9683	,'96801'	,10	 --Home 1st Inns Batsman Runs OE	
	UNION ALL SELECT 7901	,9684	,'96802'	,10	 --Home 2nd Inns Batsman Runs		
	UNION ALL SELECT 8102	,9685	,'96802'	,10	 --Home 2nd Inns Batsman Runs OE	
	UNION ALL SELECT 7901	,9686	,'96861'	,5	 --Away Player Runs				
	UNION ALL SELECT 8102	,9687	,'96861'	,5	 --Away Player Runs OE				
	UNION ALL SELECT 7901	,9688	,'96861'	,5	 --Away 1st Inns Player Runs		
	UNION ALL SELECT 8102	,9689	,'96861'	,5	 --Away 1st Inns Player Runs OE	
	UNION ALL SELECT 7901	,9690	,'96901'	,10	 --Away Batsman Runs				
	UNION ALL SELECT 8102	,9691	,'96901'	,10	 --Away Batsman Runs OE			
	UNION ALL SELECT 7901	,9692	,'96901'	,10	 --Away 1st Inns Batsman Runs		
	UNION ALL SELECT 8102	,9693	,'96901'	,10	 --Away 1st Inns Batsman Runs OE	
	UNION ALL SELECT 7901	,9694	,'96902'	,10	 --Away 2nd Inns Batsman Runs		
	UNION ALL SELECT 8102	,9695	,'96902'	,10	 --Away 2nd Inns Batsman Runs OE	
	UNION ALL SELECT 7901	,9462	,'94601'	,0	 --Home 1st Inns Sixes															 	
	UNION ALL SELECT 7901	,9463	,'94611'	,0	 --Away 1st Inns Sixes															 	
	UNION ALL SELECT 7901	,9456	,'94541'	,0	 --Home 1st Inns Fours															 	
	UNION ALL SELECT 7901	,9457	,'94551'	,0	 --Away 1st Inns Fours															 	
	UNION ALL SELECT 8102	,9534	,'94541'	,0	 --Home 1st Inns Fours OE														 	
	UNION ALL SELECT 8102	,9535	,'94551'	,0	 --Away 1st Inns Fours OE														 	
	UNION ALL SELECT 7901	,9464	,'94602'	,0	 --Home 2nd Inns Sixes															 	
	UNION ALL SELECT 7901	,9465	,'94612'	,0	 --Away 2nd Inns Sixes															 	
	UNION ALL SELECT 7901	,9458	,'94542'	,0	 --Home 2nd Inns Fours															 	
	UNION ALL SELECT 7901	,9459	,'94552'	,0	 --Away 2nd Inns Fours															 	
	UNION ALL SELECT 8102	,9536	,'94542'	,0	 --Home 2nd Inns Fours OE														 	
	UNION ALL SELECT 8102	,9537	,'94552'	,0	 --Away 2nd Inns Fours OE														 	
	UNION ALL SELECT 7901	,9708	,'97081'	,0	 --1st Inns Highest Individual Score									 
	UNION ALL SELECT 7901	,9709	,'97091'	,0	 --1st Inns Highest Over Score										 
	UNION ALL SELECT 100	,9710	,'9442'		,0	 --1st Inns Highest Opening Partnership								 
	UNION ALL SELECT 100	,9711	,'9443'		,0	 --1st Inns Highest Score in Over 1									 
	UNION ALL SELECT 9541	,9712	,'96761'	,5	 --Home Player Runs Fancy										 
	UNION ALL SELECT 9541	,9713	,'96761'	,5	 --Home 1st Inns Player Runs Fancy								 
	UNION ALL SELECT 9541	,9714	,'96801'	,10	 --Home Batsman Runs Fancy										 
	UNION ALL SELECT 9541	,9715	,'96801'	,10	 --Home 1st Inns Batsman Runs Fancy							 
	UNION ALL SELECT 9541	,9716	,'96802'	,10	 --Home 2nd Inns Batsman Runs Fancy							 
	UNION ALL SELECT 9541	,9717	,'96861'	,5	 --Away Player Runs Fancy									 
	UNION ALL SELECT 9541	,9718	,'96861'	,5	 --Away 1st Inns Player Runs Fancy							 
	UNION ALL SELECT 9541	,9719	,'96901'	,10	 --Away Batsman Runs Fancy									 
	UNION ALL SELECT 9541	,9720	,'96901'	,10	 --Away 1st Inns Batsman Runs Fancy							 
	UNION ALL SELECT 9541	,9721	,'96902'	,10	 --Away 2nd Inns Batsman Runs Fancy							 
	UNION ALL SELECT 9541	,9722	,'94841'	,50	 --Home Over X Runs Fancy				 			 
	UNION ALL SELECT 9541	,9723	,'94851'	,50	 --Away Over X Runs Fancy				 			 
	UNION ALL SELECT 9541	,9724	,'94841'	,200 --Home 1st Inns Over X Runs Fancy		 			 
	UNION ALL SELECT 9541	,9725	,'94851'	,200 --Away 1st Inns Over X Runs Fancy		 			 
	UNION ALL SELECT 9541	,9726	,'94842'	,200 --Home 2nd Inns Over X Runs Fancy		 			 
	UNION ALL SELECT 9541	,9727	,'94852'	,200 --Away 2nd Inns Over X Runs Fancy		 			 
	UNION ALL SELECT 9541	,9728	,'97091'	,0	 --1st Inns Highest Over Score Fancy							 
	UNION ALL SELECT 9541	,9729	,'97081'	,0	 --1st Inns Highest Individual Score Fancy					 
	UNION ALL SELECT 7901	,9730	,'97301'	,10	 --Home Batsman Sixes						  
	UNION ALL SELECT 7901	,9731	,'97311'	,10	 --Away Batsman Sixes						  
	UNION ALL SELECT 7901	,9732	,'97301'	,10	 --Home 1st Inns Batsman Sixes				  
	UNION ALL SELECT 7901	,9733	,'97311'	,10	 --Away 1st Inns Batsman Sixes				  
	UNION ALL SELECT 7901	,9734	,'97302'	,10	 --Home 2nd Inns Batsman Sixes				  
	UNION ALL SELECT 7901	,9735	,'97312'	,10	 --Away 2nd Inns Batsman Sixes				  
	UNION ALL SELECT 7901	,9736	,'97361'	,10	 --Home Batsman Fours						  
	UNION ALL SELECT 7901	,9737	,'97371'	,10	 --Away Batsman Fours						  
	UNION ALL SELECT 7901	,9738	,'97361'	,10	 --Home 1st Inns Batsman Fours				  
	UNION ALL SELECT 7901	,9739	,'97371'	,10	 --Away 1st Inns Batsman Fours				  
	UNION ALL SELECT 7901	,9696	,'97362'	,10	 --Home 2nd Inns Batsman Fours				  
	UNION ALL SELECT 7901	,9697	,'97372'	,10	 --Away 2nd Inns Batsman Fours				  
	UNION ALL SELECT 7901	,9698	,'96801'	,10	 --Home Batsman Milestones					  
	UNION ALL SELECT 7901	,9699	,'96901'	,10	 --Away Batsman Milestones					  
	UNION ALL SELECT 7901	,9702	,'96801'	,10	 --Home 1st Inns Batsman Milestones							 
	UNION ALL SELECT 7901	,9703	,'96901'	,10	 --Away 1st Inns Batsman Milestones							 
	UNION ALL SELECT 7901	,9704	,'96802'	,10	 --Home 2nd Inns Batsman Milestones							 
	UNION ALL SELECT 7901	,9705	,'96902'	,10	 --Away 2nd Inns Batsman Milestones

	--- STEP 2: Generate ResourceId - SettleType = 'MNL'
	INSERT INTO #Temp_ResourceID (  pfID, BetType, BetID, ResourceID )
	SELECT cr.pfID ,cr.BetType ,'0'	, cr.Prefix
	FROM #Cricket_2 cr
	WHERE cr.Prefix IN ( 'A1','H1', 'A2','H2',  '00' )

	--- STEP 3:  INSERT INTO dbo.SettlementSpecialBettypeProfile: SettleType = 'EAR'
	--- Bettype use ResourceID format G
	INSERT INTO #Temp_ResourceID (  pfID, BetType, BetID, ResourceID  )
	SELECT cr.pfID   ,cr.BetType , '0' ,cr.Prefix
	FROM #Cricket_2 cr
	WHERE  cr.RangeID = 0
		AND cr.Prefix NOT IN ( 'A1','H1', 'A2','H2',  '00' )

	--- Bettype use ResourceID format GXXX
	INSERT INTO #Temp_ResourceID (  pfID, BetType, BetID, ResourceID, Num  )
	SELECT cr.pfID  
			,cr.BetType
			,'8' + n.Suffix
			, cr.Prefix + n.Suffix  AS ResourceID
			, n.Num
	FROM #Cricket_2 cr
		CROSS APPLY (
						SELECT n.Num, n.Suffix FROM #Number n 
						WHERE n.Num <= cr.RangeID
					) n
	WHERE cr.BetType NOT IN (9616, 9617)
	
	DELETE  
	FROM #Temp_ResourceID
	WHERE Bettype IN (9547 ,9548) AND Num NOT IN (4, 5, 6, 8, 10, 12) AND Num % 5 > 0 	 

	DELETE 	
	FROM #Temp_ResourceID
	WHERE Bettype IN (9549, 9550, 9551, 9552) AND Num NOT IN ( 5, 6, 10, 12 ) AND Num % 5 > 0  
	
	--- Bettype use ResourceID format GXXXYY
	INSERT INTO #Temp_ResourceID (  pfID, BetType, BetID, ResourceID )
	SELECT cr.pfID   
			,cr.BetType  
			, '8' + n.Suffix + YY.Run AS BetID
			, cr.Prefix + n.Suffix + YY.Run AS ResourceID
	FROM #Cricket_2 cr
		CROSS APPLY (
						SELECT n.Suffix FROM #Number n 
						WHERE n.Num <= cr.RangeID
					) n
		CROSS APPLY ( SELECT Run FROM (VALUES('01'),('02'),('03'), ('04'),('05'),('06'),('07'),('08'),('09'),('10'),('11'),('12') ) yy (Run) ) YY
	WHERE cr.BetType IN (9616, 9617)


	INSERT INTO dbo.SettlementSpecialBettypeProfile	(pfID ,SportType ,BetType ,BetID ,ResourceID ,SettleType ,GroupType ,RoundID ,OddsType ,OrdNo)
	SELECT pfID ,50 ,BetType , CAST (BetID AS BIGINT) ,ResourceID 
		,CASE WHEN ResourceID IN ('A1','H1', 'A2','H2', '00') THEN 'MNL' 
				ELSE 'EAR' 
				END AS SettleType 
		, CASE WHEN ResourceID = '00' THEN 'FT'
				ELSE 'SP'
				END AS GroupType 
		, CASE WHEN ResourceID IN ( 'A1','H1' ) THEN '1'
				WHEN ResourceID IN ( 'A2','H2' ) THEN '2'
				WHEN ResourceID = '00' THEN '0'
				ELSE NULL
				END AS RoundID
		, 1 AS OddsType,
		CASE ResourceID WHEN 'H1'  THEN 1
						WHEN 'A1' THEN 2
						WHEN 'H2' THEN 3
						WHEN 'A2' THEN 4
						WHEN '00' THEN 99
						ELSE NULL
			END AS OrdNo
	FROM #Temp_ResourceID

GO



 

