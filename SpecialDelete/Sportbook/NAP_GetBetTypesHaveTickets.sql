/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GetBetTypesHaveTickets] 
    @Mode        SMALLINT = 0
    ,@MatchId    INT = 0 -- defaul value for NG
AS
/*  
    Created: 20191029@Charles  
    Task : Select bettypes have tickets for NAP's special delete  
    DB: DBTXN/bodb02 
      
    Revisions:      
        - 20191029@Charles: Badminton AIO - [120325]
        - 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]
		- 20230522@July: Support sport Cricket for all functions [Redmine: #188374]
		- 20240220@July: Merge VS1, VS2, VS3 into Virtual Sports - Remove code unused [Redmine: #200317]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]

    Param's Explanation:  
    @Mode:   
         0: Single bet  
         3: TicketListing  
         9: Mark Ticket
*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @SiteDBGroupID SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

    CREATE TABLE #TmpBettype (bettype SMALLINT)
	DECLARE @tmpMatchId TABLE (MatchId INT)
    
	IF @Mode IN (0,3,9)
	BEGIN	
		INSERT INTO @tmpMatchId (MatchId)
		SELECT MatchId
		FROM dbo.match WITH(NOLOCK)
		WHERE  1 = CASE WHEN sporttype NOT IN (50,8) AND matchid = @MatchId THEN 1
						WHEN sporttype IN (50,8) AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1 -- Get main/child matchid
						ELSE 0 END
		UNION --VS5
		SELECT Match3rdId
		FROM dbo.Match3rd WITH(NOLOCK)
		WHERE  Match3rdId = @MatchId
		
		INSERT INTO #TmpBettype(bettype)
		SELECT b.bettype
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN @tmpMatchId m ON b.matchid = m.MatchId
		WHERE SiteDBGroupID = @SiteDBGroupID
			AND bettype NOT IN (10,29,38,500)
			AND bettype < 19000
		GROUP BY bettype
		
		INSERT INTO #TmpBettype(bettype)
        SELECT bm.bettype
        FROM dbo.bettransm bm WITH(NOLOCK)
			INNER JOIN @tmpMatchId m ON bm.matchid = m.MatchId
        WHERE bm.SiteDBGroupID = @SiteDBGroupID
            AND bm.bettype NOT IN (10,29,38,500)
            AND bm.bettype < 19000
			AND NOT EXISTS(SELECT TOP 1 1 FROM #TmpBettype tb WHERE bm.bettype = tb.bettype)
        GROUP BY bm.bettype
	END

    SELECT bettype
    FROM #TmpBettype

    DROP TABLE #TmpBettype
END
GO