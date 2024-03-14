/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet,wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BetTypeSel] 
    @Mode        SMALLINT = 0
    ,@MatchId    INT = 0 -- defaul value for NG
    ,@BetTypes   VARCHAR(MAX) = NULL
    ,@ErrMsg	 NVARCHAR(200) = '' OUTPUT
    ,@ErrCode    INT = 0 OUTPUT
AS
/*  
    Created: 20130610@Elodie  
    Task : Select bettypes for NAP's special delete  
    DB: DBPRO/bodb02  
    Original: Acc_BetTypeSel  
      
    Revisions:      
        - 20130813@Elodie: Add new bettype Live Bacarat and Live Roulette (1103,1104)  
        - 20141015@Kathy: exclude the testing bettypes (Sportting Solution & BetRadar) [Redmine:#24391]
        - 20140926@Kathy: Get list bettype belong to matchid [Redmine:#23129]
        - 20150401@Dominic: Add new parent-child bettypes [Redmine:#27214]
        - 20150626@Dominic: Add metric gaming bettype bettypes [Redmine:#38200]
        - 20151110@Kathy: Move SP to DBPRO 
        - 20150401@Kathy: Add new parent-child bettypes for PH [Redmine:#48110]
        - 20150119@Kathy: Changes parent-child for phase 1.2 of PH All in One:  [Redmine:#50932]	  
        - 20160427@Bobby: #56641 - Integrate Fast Market bettypes
		- 20160721@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
        - 20160920@Kent: Add logic for grouping bettypes [Redmine:#63202]
		- 20161101@Elodie: #56641 - Integrate Fast Market new bettypes
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20170718@Paul: Integrate Lucky 3 [Redmine:#77175]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
		- 20171215@Kent: Number Game Ball Sequence [Redmine:#54346]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
		- 20180301@Benjamin: Add bettype 226,227 add GroupName for bettype 805,806 in Mode:2 [Redmine:#90667]
		- 20180816@Alan: Incorporate ESports 2.0 [99448]
		- 20181119@Alan: Incorporate Happy 5 into Number Game [102845]
		- 20190228@Alan: Implement Bet Builder, remove Live Casino - [106898]
        - 20191004@Charles: Badminton AIO - [120325]
        - 20191202@Raymond.Le: Separate function Group Bettype from Report team [124675]
        - 20200811@Charles: Implement Next R/B bet type for NG Color Ball - [128215]
		- 20210302@Max: TVS - Integrate Cricket AIO [Redmine: #150075] 
		- 20210331@July: Check logic mark ticket for cricket [Redmine: #150522]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]
		- 20230427@July: Support sport Cricket for all functions [Redmine: #188374]
		- 20230717@July: [SD] Integrate Virtual Sports 3 (Leap Gaming) [Redmine: #189556]
		- 20240220@July: Merge VS1, VS2, VS3 into Virtual Sports - Remove code unused [Redmine: #200317]

    Param's Explanation:  
    @Mode:   
         0: Single bet  
         3: TicketListing  
         9: Mark Ticket
*/
BEGIN
    SET NOCOUNT ON

    IF @mode in (0, 9) OR (@matchid <> 0 AND @mode = 3) 
    BEGIN    
        DECLARE @Sporttype INT    
        
        SET @Sporttype = 0
        
		SELECT @Sporttype = m.sporttype
        FROM ( 
			SELECT sporttype
			FROM dbo.match WITH (NOLOCK)
			WHERE matchid = @MatchID
				AND 1 = CASE WHEN Sporttype = 50 AND ChildMatchType = 200 THEN 0 --Exclude child match Cricket
							 ELSE 1 END 
			UNION
			SELECT sporttype
			FROM dbo.match3rd WITH (NOLOCK)
			WHERE match3rdId = @MatchID
		)m
        
        IF (@Sporttype NOT BETWEEN 1 AND 99) AND @Sporttype IN (175) --Bitcoin
        BEGIN 
            SET @ErrCode = 100
            SET @ErrMsg ='Invalid MatchId.' 
            RETURN
        END 
    END
    
    CREATE TABLE #TmpBettype (
        typeid            INT
        ,type             INT -- 0: Sport Book, 1:Number Game, 3: Bet Builder, 4: Bitcoin
        ,liveindicator    BIT
        ,GroupName	      VARCHAR(50) 
        )
        
    DECLARE @tmpConsolidatedBettypes TABLE (
        parentid        INT
        ,typeid         INT PRIMARY KEY
    )
    
    INSERT INTO @tmpConsolidatedBettypes (parentid, typeid)
    SELECT f.GroupTypeId AS parentid
		 , f.Bettype AS typeid
    FROM [dbo].[f_SD_GroupDisplayBettype] () f

    CREATE TABLE #betTypesTemp (bettype SMALLINT PRIMARY KEY)

    INSERT INTO #betTypesTemp (bettype)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@BetTypes, ',')
	WHERE value <> ''
		
    -- Get bettype list
    INSERT INTO #TmpBettype (
        typeid
        ,type
        ,liveindicator
        ,GroupName
        )
    SELECT ISNULL( tb.parentid, b.typeid)
        , 0                    
        , 0 
        , f.GroupName 
    FROM dbo.bettype b WITH(NOLOCK)
    INNER JOIN #betTypesTemp bt ON b.typeid = bt.bettype
    INNER JOIN dbo.f_SD_GetGroupBettypes() f ON f.BetType = b.typeid
    LEFT JOIN @tmpConsolidatedBettypes tb ON tb.typeid = b.typeid
    WHERE EXISTS (SELECT TOP 1 1 FROM dbo.match m WHERE m.matchid = @MatchId)
    GROUP BY tb.parentid, b.typeid, f.GroupName

     -- 3: TicketListing  
    IF @Mode = 3
    BEGIN
		IF (EXISTS(SELECT TOP 1 1 FROM #TmpBettype)) --type: 0 - Sportbook - Mix parlay 29
		BEGIN
			INSERT INTO #TmpBettype (
				typeid
				,type
				,liveindicator
				,GroupName
				)
			SELECT 29, 0, 0, 'Special' AS GroupName           
		END
		
		INSERT INTO #TmpBettype (  
            typeid  
            ,type  
            ,liveindicator              
            )  
        SELECT typeid  
            , CASE WHEN (typeid BETWEEN 85 AND 91 OR typeid BETWEEN 8101 AND 8105) THEN 1 --type = 1: Number Game
				   WHEN typeid = 38 THEN 3 -- type = 3: Bet Builder
				   WHEN typeid = 7901 THEN 4 -- type = 4: Bitcoin
				   ELSE 0 END AS type 
            ,CASE WHEN (typeid BETWEEN 85 AND 91 OR typeid BETWEEN 8101 AND 8105) THEN 1 ELSE 0 END AS liveindicator              
        FROM dbo.bettype WITH (NOLOCK)  
        WHERE @matchid = 0 
			AND 1 = CASE WHEN (typeid BETWEEN 85 AND 91 OR typeid BETWEEN 8101 AND 8105) THEN 1 
						 WHEN typeid = 38 THEN 1
						 WHEN typeid = 7901 THEN 1
						 ELSE 0 END
    END
    
    SELECT tb.typeid
        ,CASE WHEN tb.typeid = 9604 THEN 'Over/Under'
			  WHEN tb.typeid = 9605 THEN 'Odd/Even'
			 ELSE b.typenamee END AS bettypename
        ,tb.type
        ,tb.liveindicator
        ,tb.GroupName
    FROM #TmpBettype tb
		INNER JOIN bettype b WITH(NOLOCK) ON tb.typeid = b.typeid    
    GROUP BY tb.typeid, b.typenamee, type, liveindicator, tb.GroupName
    ORDER BY tb.GroupName,b.typenamee

    DROP TABLE #betTypesTemp
    DROP TABLE #TmpBettype
END
GO