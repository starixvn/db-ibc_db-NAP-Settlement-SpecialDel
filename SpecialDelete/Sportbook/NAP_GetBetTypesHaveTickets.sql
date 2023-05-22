/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_GetBetTypesHaveTickets] 
    @Mode        SMALLINT = 0
    ,@MatchId    INT = 0 -- defaul value for NG, VS, LC, VS Betradar
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

    Param's Explanation:  
    @Mode:   
         0: Single bet  
         1: Number game  
         2: Early Kick-Off  
         3: TicketListing  
         4: Mix Parlay   
         5: Virtual sports  
		 8: Bet Builder
         9: Mark Ticket
*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @SiteDBGroupID SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

    CREATE TABLE #TmpBettype (bettype SMALLINT)

    --0: Single bet, 2: Early kick-off, 3: Ticket listing
	IF @Mode IN (0, 2, 3)
	BEGIN
        -- Scan bettrans and bettransm to get bettype list
		-- bettrans
        IF @Mode IN (0,3)
        BEGIN
            INSERT INTO #TmpBettype(bettype)
			SELECT bettype
			FROM dbo.bettrans WITH(NOLOCK)
			WHERE matchid = @MatchId AND SiteDBGroupID = @SiteDBGroupID
				AND bettype NOT IN (10,29,38,500)
				AND bettype < 19000
			GROUP BY bettype
        END
        
        IF @Mode = 2
        BEGIN
            INSERT INTO #TmpBettype(bettype)
			SELECT bettype
			FROM dbo.bettrans WITH(NOLOCK)
			WHERE matchid = @MatchId AND SiteDBGroupID = @SiteDBGroupID
				AND bettype NOT IN (10,29,500)
				AND bettype < 19000
			GROUP BY bettype
        END

        -- bettransm
        IF @Mode IN (0, 2, 3)
        BEGIN
            INSERT INTO #TmpBettype(bettype)
            SELECT bt.bettype
            FROM dbo.bettransm bt WITH(NOLOCK)
            WHERE bt.matchid = @MatchId AND bt.SiteDBGroupID = @SiteDBGroupID
			AND NOT EXISTS(SELECT TOP 1 1
                FROM #TmpBettype tb WHERE bt.bettype = tb.bettype)
                AND bt.bettype NOT IN (10,29,38,500)
                AND bt.bettype < 19000
            GROUP BY bt.bettype
        END
	END

    --4: Mix Parlay
	IF @Mode = 4
	BEGIN
        INSERT INTO #TmpBettype(bettype)
        SELECT bettype
        FROM dbo.bettransm WITH(NOLOCK)
        WHERE matchid = @MatchId AND SiteDBGroupID = @SiteDBGroupID
            AND bettype NOT IN (10,29,38,500)
            AND bettype NOT BETWEEN 221 AND 227
            AND bettype < 19000
        GROUP BY bettype
	END

	--9: Mark Ticket
	IF @Mode IN (9)
	BEGIN
		DECLARE @tmpMatchId TABLE (MatchId INT)
		INSERT INTO @tmpMatchId (MatchId)
		SELECT MatchId
		FROM dbo.match WITH(NOLOCK)
		WHERE  1 = CASE WHEN sporttype <> 50 AND matchid = @MatchId THEN 1
						WHEN sporttype = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1 -- Get main/child matchid
						ELSE 0 END
		
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