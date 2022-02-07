    
/* 
	Created by: 20220128@Louisa
    Task: 20220128@Louisa: Cricket AIO Phase 2 [Redmine:#166335]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220128@Louisa: Insert SettlementSpecialBettypeProfile for Cricket Phase 2.0 ( 167 bettypes) [Redmine:#166335]
*/

USE bodb02
GO


---STEP 1: insert fomular
IF OBJECT_ID ('tempdb..#Cricket_2' ) IS NOT NULL
		BEGIN	
			DROP TABLE #Cricket_2
		END

	CREATE TABLE #Cricket_2 (
		  Num		INT
		, pfID		SMALLINT
		, BetType	SMALLINT
		, BetID		VARCHAR(6)
		, Prefix	VARCHAR(50)
		, Suffix	VARCHAR(50)
		, RangeID	SMALLINT
		, SettleType VARCHAR(3)
		, ResourceID VARCHAR(20)
	)
	GO
--Change old bettype : 9006
--No, pfID  , BetType  , 	BetID  , 	Prefix, Suffix , SettleType , HomeValue, AwayValue
-------------------------------------------------------	----------------------------------------------------------
INSERT INTO #Cricket_2 (Num, pfID , BetType , BetID , Prefix, Suffix, RangeID, SettleType )
 
		  SELECT 1	,9541	,9541	,'0'		,'H1'		,''					 , 0	,'MNL'	--Home Inns Runs Fancy	--NORMAL match												
UNION ALL SELECT 2	,9541	,9542	,'0'		,'A1'		,''					 , 0	,'MNL'	--Away Inns Runs Fancy	--NORMAL match													
UNION ALL SELECT 3	,9541	,9543	,'0'		,'H1'		,''					 , 0	,'MNL'	--Home 1st Inns Runs Fancy --Test match													
UNION ALL SELECT 4	,9541	,9544	,'0'		,'A1'		,''					 , 0	,'MNL'	--Away 1st Inns Runs Fancy --Test match													
UNION ALL SELECT 5	,9541	,9545	,'0'		,'H2'		,''					 , 0	,'MNL'	--Home 2nd Inns Runs Fancy --Test match													
UNION ALL SELECT 6	,9541	,9546	,'0'		,'A2'		,''					 , 0	,'MNL'	--Away 2nd Inns Runs Fancy --Test match
									  
UNION ALL SELECT 7	,9606	,9606	,'0'		,'00'		,''					 ,0		,'MNL'	--Fancy		--Child													
UNION ALL SELECT 1	,5		,9440	,'0'		,'9446'		,''					 ,0		,'EAR'	 --Most Fours		--Both match												
UNION ALL SELECT 2	,5		,9441	,'0'		,'9447'		,''					 ,0		,'EAR'	 --Most Sixes		--Both match												
UNION ALL SELECT 3	,5		,9615	,'0'		,'96151'	,''					 ,0		,'EAR'	 --Most Run Outs		--Both match												
UNION ALL SELECT 4	,9448	,9448	,'0'		,'96151'	,''					 ,0		,'EAR'	--Match Run Outs	--Both match										
UNION ALL SELECT 5	,2		,9529	,'0'		,'96151'	,''					 ,0		,'EAR'	--Match Run Outs OE	--Both match									
UNION ALL SELECT 6	,9448	,9451	,'0'		,'94511'	,''					 ,0		,'EAR'	 --Match Dot Balls	--Both match										
UNION ALL SELECT 7	,2		,9531	,'0'		,'94511'	,''					 ,0		,'EAR'	 --Match Dot Balls OE--Both match													
UNION ALL SELECT 8	,9616	,9616	,'8XXXYY'	,'96161'	,'0[0-5][1-9][0-1][0-2]'	,5012	,'EAR'	--Home Over X Delivery Y Runs	--X={1-50} Y={1-12}--NORMAL		
UNION ALL SELECT 9	,9616	,9617	,'8XXXYY'	,'96171'	,'0[0-5][1-9][0-1][0-2]'	,5012	,'EAR'	--Away Over X Delivery Y Runs	--X={1-50} Y={1-12}--NORMAL		
UNION ALL SELECT 10	,8102	,9618	,'8XXX'	,'94841'	,'0[0-5][0-9]'		 ,50	,'EAR'	--Home Over X Runs OE			--X={1-50}--NORMAL					
UNION ALL SELECT 11	,8102	,9619	,'8XXX'	,'94851'	,'0[0-5][0-9]'		 ,50	,'EAR'	--Away Over X Runs OE			--X={1-50}--NORMAL				
UNION ALL SELECT 12	,8102	,9620	,'8XXX'	,'94841'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Home 1st Inns Over X Runs OE	--X={1-200}						
UNION ALL SELECT 13	,8102	,9621	,'8XXX'	,'94851'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Away 1st Inns Over X Runs OE	--X={1-200}						
UNION ALL SELECT 14	,8102	,9622	,'8XXX'	,'94842'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Home 2nd Inns Over X Runs OE	--X={1-200}										
UNION ALL SELECT 15	,8102	,9623	,'8XXX'	,'94852'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Away 2nd Inns Over X Runs OE	--X={1-200}										
UNION ALL SELECT 16	,102	,9624	,'8XXX'	,'96241'	,'0[0-5][0-9]'		 ,50	,'EAR'	--Will there be a Boundary Fours in Home Over X?	--Deadball: X={1-50}--NORMAL						
UNION ALL SELECT 17	,102	,9625	,'8XXX'	,'96251'	,'0[0-5][0-9]'		 ,50	,'EAR'	--Will there be a Boundary Fours in Away Over X?	--Deadball: X={1-50}--NORMAL						
UNION ALL SELECT 18	,102	,9626	,'8XXX'	,'96241'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Fours in Home 1st Inns Over X? --X={1-200}						
UNION ALL SELECT 19	,102	,9627	,'8XXX' 	,'96251'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Fours in Away1st Inns Over X?	-- X={1-200}						
UNION ALL SELECT 20	,102	,9628	,'8XXX'	,'96242'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Fours in Home 2nd Inns Over X? --X={1-200}										
UNION ALL SELECT 21	,102	,9629	,'8XXX'	,'96252'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Fours in Away 2nd Inns Over X? --X={1-200}										
UNION ALL SELECT 22	,102	,9630	,'8XXX'	,'96301'	,'0[0-5][0-9]'		 ,50	,'EAR'	--Will there be a Boundary Sixes in Home Over X?			--X={1-50}--NORMAL						
UNION ALL SELECT 23	,102	,9631	,'8XXX'	,'96311'	,'0[0-5][0-9]'		 ,50	,'EAR'	--Will there be a Boundary Sixes in Away Over X?			--X={1-50}--NORMAL						
UNION ALL SELECT 24	,102	,9632	,'8XXX'	,'96301'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Sixes in Home 1st Inns Over X?	--X={1-200}						
UNION ALL SELECT 25	,102	,9633	,'8XXX'	,'96311'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Sixes in Away 1st Inns Over X?	--X={1-200}						
UNION ALL SELECT 26	,102	,9634	,'8XXX'	,'96302'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Sixes in Home 2nd Inns Over X?	--X={1-200}								
UNION ALL SELECT 27	,102	,9635	,'8XXX'	,'96312'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Will there be a Boundary Sixes in Away 2nd Inns Over X?	--X={1-200}								
UNION ALL SELECT 28	,9484	,9484	,'8XXX'	,'94841'	,'0[0-5][0-9]'		 ,50	,'EAR'	 --Home Over X Exact Runs				--X={1-50}--NORMAL						
UNION ALL SELECT 29	,9484	,9485	,'8XXX'	,'94851'	,'0[0-5][0-9]'		 ,50	,'EAR'	 --Away Over X Exact Runs				--X={1-50}--NORMAL						
UNION ALL SELECT 30	,9486	,9486	,'8XXX'	,'94841'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	 --Home 1st Inns Over X Exact Runs		--X={1-200}											
UNION ALL SELECT 31	,9486	,9487	,'8XXX'	,'94851'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	 --Away 1st Inns Over X Exact Runs		--X={1-200}											
UNION ALL SELECT 32	,9486	,9488	,'8XXX'	,'94842'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	 --Home 2nd Inns Over X Exact Runs		--X={1-200}											
UNION ALL SELECT 33	,9486	,9489	,'8XXX'	,'94852'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	 --Away 2nd Inns Over X Exact Runs		--X={1-200}											
UNION ALL SELECT 34	,9636	,9636	,'8XXX'	,'96361'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Home Wicket X Method of Dismissal (6 Way)				--X={1-10}--NORMAL 
UNION ALL SELECT 35	,9636	,9637	,'8XXX'	,'96371'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Away Wicket X Method of Dismissal (6 Way)				--X={1-10}--NORMAL 
UNION ALL SELECT 36	,9636	,9638	,'8XXX'	,'96361'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Home 1st Inns Wicket X Method of Dismissal (6 Way)	--X={1-10} 
UNION ALL SELECT 37	,9636	,9639	,'8XXX'	,'96371'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Away 1st Inns Wicket X Method of Dismissal (6 Way)	--X={1-10} 
UNION ALL SELECT 38	,9636	,9640	,'8XXX'	,'96362'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Home 2nd Inns Wicket X Method of Dismissal (6 Way)	--X={1-10}	  
UNION ALL SELECT 39	,9636	,9641	,'8XXX'	,'96372'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Away 2nd Inns Wicket X Method of Dismissal (6 Way)	--X={1-10}	  
UNION ALL SELECT 40	,9541	,9547	,'8XXX'	,'94101'	,'0[0-5][0-9]'		 ,45	,'EAR'--Home Group 1-X Runs Fancy--X={5,6,10}Live: X={4,5,6,8,10,12,15,20,25,30,35,40,45}--NORMAL	 
UNION ALL SELECT 41	,9541	,9548	,'8XXX'	,'94111'	,'0[0-5][0-9]'		 ,45	,'EAR'--Away Group 1-X Runs Fancy--X={5,6,10}Live: X={4,5,6,8,10,12,15,20,25,30,35,40,45}--NORMAL	 
 
UNION ALL SELECT 42	,9541	,9549	,'8XXX'	,'94101'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Home 1st Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,....200}	  	 
UNION ALL SELECT 43	,9541	,9550	,'8XXX'	,'94111'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Away 1st Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,....200}	  	 
  																			
UNION ALL SELECT 44	,9541	,9551	,'8XXX'	,'94102'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Home 2nd Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,35,40,45,....200}	 
UNION ALL SELECT 45	,9541	,9552	,'8XXX'	,'94112'	,'[0-2][0-9][0-9]'	 ,200	,'EAR'	--Away 2nd Inns Group 1-X Runs Fancy--X={5,6,10,12,15,20,25,30,35,40,45,....200}	  	 
UNION ALL SELECT 46	,9541	,9559	,'8XXX'	,'94281'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Home Fall of Wicket X Fancy			--X={1-10}--NORMAL										 
UNION ALL SELECT 47	,9541	,9560	,'8XXX'	,'94291'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Away Fall of Wicket X Fancy			--X={1-10}--NORMAL										 
UNION ALL SELECT 48	,9541	,9561	,'8XXX'	,'94281'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Home 1st Inns Fall of Wicket X Fancy--X={1-10}										 
UNION ALL SELECT 49	,9541	,9562	,'8XXX'	,'94291'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Away 1st Inns Fall of Wicket X Fancy--X={1-10}										 
UNION ALL SELECT 50	,9541	,9563	,'8XXX'	,'94282'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Home 2nd Inns Fall of Wicket X Fancy--X={1-10}										 
UNION ALL SELECT 51	,9541	,9564	,'8XXX'	,'94292'	,'0[0-1][0-9]'		 ,10	,'EAR'	--Away 2nd Inns Fall of Wicket X Fancy--X={1-10}	

UNION ALL SELECT 52	,9606	,9566	,'0'		,'9446'		,''					 ,0		,'EAR'	--Match Fours Fancy		--null	--BOTH	 
UNION ALL SELECT 53	,9606	,9567	,'0'		,'9447'		,''					 ,0		,'EAR'	--Match Sixes Fancy		--null	--BOTH	 
UNION ALL SELECT 54	,9606	,9569	,'0'		,'9449'		,''					 ,0		,'EAR'	--Match Wickets Fancy	--Both match	 
UNION ALL SELECT 55	,9606	,9570	,'0'		,'9450'		,''					 ,0		,'EAR'	--Match Extras Fancy	--Both match	

UNION ALL SELECT 56	,9541	,9572	,'0'		,'9452'		,''					 ,0		,'EAR'	--Highest Individual Score Fancy--Both match	 
UNION ALL SELECT 57	,9541	,9573	,'0'		,'9453'		,''					 ,0		,'EAR'	--Highest Over Score Fancy		--Both match	 
UNION ALL SELECT 58	,9541	,9574	,'0'		,'9454[1]'	,''					 ,0		,'EAR'	--Home Inns Fours Fancy			--NORMAL	 
UNION ALL SELECT 59	,9541	,9575	,'0'		,'9455[1]'	,''					 ,0		,'EAR'	--Away Inns Fours Fancy			--NORMAL	 
UNION ALL SELECT 60	,9541	,9580	,'0'		,'9460[1]'	,''					 ,0		,'EAR'	--Home Inns Sixes Fancy			--NORMAL	 
UNION ALL SELECT 61	,9541	,9581	,'0'		,'9461[1]'	,''					 ,0		,'EAR'	--Away Inns Sixes Fancy			--NORMAL	 
UNION ALL SELECT 62	,9541	,9582	,'0'		,'9460[1]'	,''					 ,0		,'EAR'	--Home 1st Inns Sixes Fancy			 
UNION ALL SELECT 63	,9541	,9583	,'0'		,'9461[1]'	,''					 ,0		,'EAR'	--Away 1st Inns Sixes Fancy			 
UNION ALL SELECT 64	,9541	,9584	,'0'		,'9460[2]'	,''					 ,0		,'EAR'	--Home 2nd Inns Sixes Fancy			 
UNION ALL SELECT 65	,9541	,9585	,'0'		,'9461[2]'	,''					 ,0		,'EAR'	--Away 2nd Inns Sixes Fancy			 
UNION ALL SELECT 66	,9541	,9576	,'0'		,'9454[1]'	,''					 ,0		,'EAR'	--Home 1st Inns Fours Fancy			 
UNION ALL SELECT 67	,9541	,9577	,'0'		,'9455[1]'	,''					 ,0		,'EAR'	--Away 1st Inns Fours Fancy			 
UNION ALL SELECT 68	,9541	,9578	,'0'		,'9454[2]'	,''					 ,0		,'EAR'	--Home 2nd Inns Fours Fancy			 
UNION ALL SELECT 69	,9541	,9579	,'0'		,'9455[2]'	,''					 ,0		,'EAR'	--Away 2nd Inns Fours Fancy		 
------------------------------------------------------------------------------------------------------
----			No, pfID , BetType, BetID, Prefix		, Suffix			,Range	, SettleType
UNION ALL SELECT 70	,100	,9650	,'0'		,'96501'	,''					,0		,'EAR'	--Home Top Batsman										 
UNION ALL SELECT 71	,100	,9651	,'0'		,'96511'	,''					,0		,'EAR'	--Away Top Batsman										 
UNION ALL SELECT 72	,100	,9652	,'0'		,'96501'	,''					,0		,'EAR'	--Home 1st Inns Top Batsman								 
UNION ALL SELECT 73	,100	,9653	,'0'		,'96511'	,''					,0		,'EAR'	--Away 1st Inns Top Batsman								 
UNION ALL SELECT 74	,100	,9654	,'0'		,'96501'	,''					,0		,'EAR'	--Home 2nd Inns Top Batsman								 
UNION ALL SELECT 75	,100	,9655	,'0'		,'96511'	,''					,0		,'EAR'	--Away 2nd Inns Top Batsman								 
UNION ALL SELECT 76	,100	,9656	,'0'		,'96561'	,''					,0		,'EAR'	--Home Top Bowler										 
UNION ALL SELECT 77	,100	,9657	,'0'		,'96571'	,''					,0		,'EAR'	--Away Top Bowler										 
UNION ALL SELECT 78	,100	,9658	,'0'		,'96561'	,''					,0		,'EAR'	--Home 1st Inns Top Bowler								 
UNION ALL SELECT 79	,100	,9659	,'0'		,'96571'	,''					,0		,'EAR'	--Away 1st Inns Top Bowler								 
UNION ALL SELECT 80	,100	,9660	,'0'		,'96562'	,''					,0		,'EAR'	--Home 2nd Inns Top Bowler								 
UNION ALL SELECT 81	,100	,9661	,'0'		,'96572'	,''					,0		,'EAR'	--Away 2nd Inns Top Bowler								 
UNION ALL SELECT 82	,100	,9662	,'0'		,'9662[1]'	,'0[0-1][1-9]'		,10		,'EAR'	---Home Next Man Out							 
UNION ALL SELECT 83	,100	,9663	,'0'		,'9663[1]'	,'0[0-1][1-9]'		,10		,'EAR'	---Away Next Man Out							 
UNION ALL SELECT 84	,100	,9664	,'0'		,'9662[1]'	,'0[0-1][1-9]'		,10		,'EAR'	---Home 1st Inns Next Man Out				 
UNION ALL SELECT 85	,100	,9665	,'0'		,'9663[1]'	,'0[0-1][1-9]'		,10		,'EAR'	---Away 1st Inns Next Man Out				 
UNION ALL SELECT 86	,100	,9666	,'0'		,'9662[2]'	,'0[0-1][1-9]'		,10		,'EAR'	---Home 2nd Inns Next Man Out				 
UNION ALL SELECT 87	,100	,9667	,'0'		,'9663[2]'	,'0[0-1][1-9]'		,10		,'EAR'	---Away 2nd Inns Next Man Out				 
UNION ALL SELECT 88	,100	,9668	,'0'		,'96681'	,''					,0		,'EAR'	--Home Prematch Top Batsman									 
UNION ALL SELECT 89	,100	,9669	,'0'		,'96711'	,''					,0		,'EAR'	--Away Prematch Top Batsman									 
UNION ALL SELECT 90	,100	,9670	,'0'		,'96681'	,''					,0		,'EAR'	--Home 1st Inns Prematch Top Batsman						 
UNION ALL SELECT 91	,100	,9671	,'0'		,'96711'	,''					,0		,'EAR'	--Away 1st Inns Prematch Top Batsman						 
UNION ALL SELECT 92	,100	,9672	,'0'		,'96721'	,''					,0		,'EAR'	--Home Prematch Top Bowler									 
UNION ALL SELECT 93	,100	,9673	,'0'		,'96751'	,''					,0		,'EAR'	--Away Prematch Top Bowler									 
UNION ALL SELECT 94	,100	,9674	,'0'		,'96721'	,''					,0		,'EAR'	--Home 1st Inns Prematch Top Bowler							 
UNION ALL SELECT 95	,100	,9675	,'0'		,'96751'	,''					,0		,'EAR'	--Away 1st Inns Prematch Top Bowler							 
UNION ALL SELECT 96	,9616	,9676	,'0'		,'9676[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Player Runs				
UNION ALL SELECT 97	,8102	,9677	,'0'		,'9676[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Player Runs OE				
UNION ALL SELECT 98	,9616	,9678	,'0'		,'9676[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Player Runs		
UNION ALL SELECT 99	,8102	,9679	,'0'		,'9676[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Player Runs OE	
UNION ALL SELECT 100,9616	,9680	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Batsman Runs				
UNION ALL SELECT 101,8102	,9681	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Batsman Runs OE			
UNION ALL SELECT 102,9616	,9682	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Batsman Runs		
UNION ALL SELECT 103,8102	,9683	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Batsman Runs OE	
UNION ALL SELECT 104,9616	,9684	,'0'		,'9680[2]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 2nd Inns Batsman Runs		
UNION ALL SELECT 105,8102	,9685	,'0'		,'9680[2]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 2nd Inns Batsman Runs OE	
UNION ALL SELECT 106,9616	,9686	,'0'		,'9686[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Player Runs				
UNION ALL SELECT 107,8102	,9687	,'0'		,'9686[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Player Runs OE				
UNION ALL SELECT 108,9616	,9688	,'0'		,'9686[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Player Runs		
UNION ALL SELECT 109,8102	,9689	,'0'		,'9686[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Player Runs OE	
UNION ALL SELECT 110,9616	,9690	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Batsman Runs				
UNION ALL SELECT 111,8102	,9691	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Batsman Runs OE			
UNION ALL SELECT 112,9616	,9692	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Batsman Runs		
UNION ALL SELECT 113,8102	,9693	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Batsman Runs OE	
UNION ALL SELECT 114,9616	,9694	,'0'		,'9690[2]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 2nd Inns Batsman Runs		
UNION ALL SELECT 115,8102	,9695	,'0'		,'9690[2]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 2nd Inns Batsman Runs OE	
UNION ALL SELECT 116,3		,9462	,'0'		,'94601'	,''					,0		,'EAR'	--Home 1st Inns Sixes															 	
UNION ALL SELECT 117,3		,9463	,'0'		,'94611'	,''					,0		,'EAR'	--Away 1st Inns Sixes															 	
UNION ALL SELECT 118,3		,9456	,'0'		,'94541'	,''					,0		,'EAR'	--Home 1st Inns Fours															 	
UNION ALL SELECT 119,3		,9457	,'0'		,'94551'	,''					,0		,'EAR'	--Away 1st Inns Fours															 	
UNION ALL SELECT 120,2		,9534	,'0'		,'94541'	,''					,0		,'EAR'	--Home 1st Inns Fours OE														 	
UNION ALL SELECT 121,2		,9701	,'0'		,'94551'	,''					,0		,'EAR'	--Away 1st Inns Fours OE														 	
UNION ALL SELECT 122,3		,9464	,'0'		,'94602'	,''					,0		,'EAR'	--Home 2nd Inns Sixes															 	
UNION ALL SELECT 123,3		,9465	,'0'		,'94612'	,''					,0		,'EAR'	--Away 2nd Inns Sixes															 	
UNION ALL SELECT 124,3		,9458	,'0'		,'94542'	,''					,0		,'EAR'	--Home 2nd Inns Fours															 	
UNION ALL SELECT 125,3		,9459	,'0'		,'94552'	,''					,0		,'EAR'	--Away 2nd Inns Fours															 	
UNION ALL SELECT 126,2		,9706	,'0'		,'94541'	,''					,0		,'EAR'	--Home 2nd Inns Fours OE														 	
UNION ALL SELECT 127,2		,9707	,'0'		,'94551'	,''					,0		,'EAR'	--Away 2nd Inns Fours OE														 	
UNION ALL SELECT 128,3		,9708	,'0'		,'97081'	,''					,0		,'EAR'	--1st Inns Highest Individual Score									 
UNION ALL SELECT 129,3		,9709	,'0'		,'97091'	,''					,0		,'EAR'	--1st Inns Highest Over Score										 
UNION ALL SELECT 130,100	,9710	,'0'		,'9442'		,''					,0		,'EAR'	--1st Inns Highest Opening Partnership								 
UNION ALL SELECT 131,100	,9711	,'0'		,'9443'		,''					,0		,'EAR'	--1st Inns Highest Score in Over 1									 
UNION ALL SELECT 132,9541	,9712	,'0'		,'9676[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Player Runs Fancy										 
UNION ALL SELECT 133,9541	,9713	,'0'		,'9676[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Player Runs Fancy								 
UNION ALL SELECT 134,9541	,9714	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Batsman Runs Fancy										 
UNION ALL SELECT 135,9541	,9715	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Batsman Runs Fancy							 
UNION ALL SELECT 136,9541	,9716	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 2nd Inns Batsman Runs Fancy							 
UNION ALL SELECT 137,9541	,9717	,'0'		,'9686[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Player Runs Fancy									 
UNION ALL SELECT 138,9541	,9718	,'0'		,'9686[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Player Runs Fancy							 
UNION ALL SELECT 139,9541	,9719	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Batsman Runs Fancy									 
UNION ALL SELECT 140,9541	,9720	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Batsman Runs Fancy							 
UNION ALL SELECT 141,9541	,9721	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 2nd Inns Batsman Runs Fancy							 
UNION ALL SELECT 142,9541	,9722	,'8XXX'	,'9484[1]'	,'[0-2][0-9][0-9]'  ,200	,'EAR'	--Home Over X Runs Fancy					8XXX				 
UNION ALL SELECT 143,9541	,9723	,'8XXX'	,'9485[1]'	,'[0-2][0-9][0-9]'  ,200	,'EAR'	--Away Over X Runs Fancy					8XXX				 
UNION ALL SELECT 144,9541	,9724	,'8XXX'	,'9484[1]'	,'[0-2][0-9][0-9]'  ,200	,'EAR'	--Home 1st Inns Over X Runs Fancy			8XXX				 
UNION ALL SELECT 145,9541	,9725	,'8XXX'	,'9485[1]'	,'[0-2][0-9][0-9]'  ,200	,'EAR'	--Away 1st Inns Over X Runs Fancy			8XXX				 
UNION ALL SELECT 146,9541	,9726	,'8XXX'	,'9484[1]'	,'[0-2][0-9][0-9]'  ,200	,'EAR'	--Home 2nd Inns Over X Runs Fancy			8XXX				 
UNION ALL SELECT 147,9541	,9727	,'8XXX'	,'9485[1]'	,'[0-2][0-9][0-9]'  ,200	,'EAR'	--Away 2nd Inns Over X Runs Fancy			8XXX				 
UNION ALL SELECT 148,9541	,9728	,'0'		,'97091'	,''					,0		,'EAR'	--1st Inns Highest Over Score Fancy							 
UNION ALL SELECT 149,9541	,9729	,'0'		,'97081'	,''					,0		,'EAR'	--1st Inns Highest Individual Score Fancy					 
UNION ALL SELECT 150,3		,9730	,'0'		,'9730[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Batsman Sixes						  
UNION ALL SELECT 151,3		,9731	,'0'		,'9731[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Batsman Sixes						  
UNION ALL SELECT 152,3		,9732	,'0'		,'9730[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Batsman Sixes				  
UNION ALL SELECT 153,3		,9733	,'0'		,'9731[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Batsman Sixes				  
UNION ALL SELECT 154,3		,9734	,'0'		,'9730[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 2nd Inns Batsman Sixes				  
UNION ALL SELECT 155,3		,9735	,'0'		,'9731[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 2nd Inns Batsman Sixes				  
UNION ALL SELECT 156,3		,9736	,'0'		,'9736[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Batsman Fours						  
UNION ALL SELECT 157,3		,9737	,'0'		,'9737[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Batsman Fours						  
UNION ALL SELECT 158,3		,9738	,'0'		,'9736[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Batsman Fours				  
UNION ALL SELECT 159,3		,9739	,'0'		,'9737[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Batsman Fours				  
UNION ALL SELECT 160,9616	,9696	,'0'		,'9736[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 2nd Inns Batsman Fours				  
UNION ALL SELECT 161,9616	,9697	,'0'		,'9737[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 2nd Inns Batsman Fours				  
UNION ALL SELECT 162,9616	,9698	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home Batsman Milestones					  
UNION ALL SELECT 163,9616	,9699	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away Batsman Milestones					  
UNION ALL SELECT 164,9616	,9702	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 1st Inns Batsman Milestones							 
UNION ALL SELECT 165,9616	,9703	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 1st Inns Batsman Milestones							 
UNION ALL SELECT 166,9616	,9704	,'0'		,'9680[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Home 2nd Inns Batsman Milestones							 
UNION ALL SELECT 167,9616	,9705	,'0'		,'9690[1]'	,'0[0-1][0-9]'		,11		,'EAR'	--Away 2nd Inns Batsman Milestones


----STEP 2: Generate Resources
IF OBJECT_ID ('tempdb..#Number' ) IS NOT NULL
BEGIN	
	DROP TABLE #Number 
END

CREATE TABLE #Number ( Num INT IDENTITY(1,1) PRIMARY KEY , Suffix VARCHAR(10)	)
GO

INSERT INTO  #Number  ( Suffix)
SELECT RIGHT( '00' + CAST(number AS VARCHAR(3) ), 3)  FROM master.dbo.spt_values p 
WHERE p.type  = 'p' and p.number BETWEEN 1 AND 200
ORDER BY p.number


--select * from #Number

SELECT cr.pfID  ,50 AS SportType ,cr.BetType  
		, CASE WHEN cr.BetID <> '0' THEN + '8' + RIGHT(n.Suffix, 3)
				ELSE cr.BetID
			END AS BetID
		, cr.Prefix + RIGHT(n.Suffix, 3)  AS ResourceID
		, SettleType
		, CASE WHEN cr.Prefix = '00' THEN 'FT'
				ELSE 'SP'
			END AS GroupType
		, CASE WHEN cr.Prefix IN ( 'A1','H1' ) THEN '1'
			   WHEN cr.Prefix IN ( 'A2','H2' ) THEN '2'
			   WHEN cr.Prefix = '00' THEN '0'
			   ELSE NULL
			 END AS RoundID
		, 1 AS OddsType
		, cr.Num, cr.BetID, cr.Suffix, cr.RangeID, n.Suffix
FROM #Cricket_2 cr
	CROSS APPLY (
				SELECT n.Suffix FROM #Number n 
				WHERE n.Suffix LIKE cr.Suffix
					AND n.Num <= cr.RangeID 
				) n
WHERE cr.Bettype NOT IN (9616, 9617, 9547, 9548, 9549, 9550, 9551, 9552)
	AND bettype = 9484
ORDER BY cr.BetType
		,  CASE WHEN cr.BetID <> '0' THEN + '8' + RIGHT(n.Suffix, 3)
				ELSE cr.BetID
			END


			select * from #Cricket_2 
			where RangeID = 0




 

