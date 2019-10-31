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
		
    Param's Explanation:  
    @Mode:   
         0: Single bet  
         1: Number game  
         2: Early Kick-Off  
         3: TicketListing  
         4: Mix Parlay   
         5: Virtual sports  
		 6: Lucky 3
		 7: Bull fighting
		 8: Bet Builder
         9: Mark Ticket
*/
BEGIN
    SET NOCOUNT ON
	
    CREATE TABLE #TmpBettype (
        bettype     SMALLINT
    )

    -- @mode = 0: Single bet, 2: Early kick-off, 3: Ticket listing , 9: Mark Ticket  
    IF @Mode IN (0, 2, 3, 9)
    BEGIN
        -- Scan bettrans and bettransm to get bettype list
        -- bettrans
        INSERT INTO #TmpBettype(bettype)
        SELECT bettype
        FROM dbo.bettrans WITH(NOLOCK)
        WHERE matchid = @MatchId
            AND bettype NOT IN (10,29,38,500)
            AND bettype NOT BETWEEN 801 AND 806
            AND bettype < 19000
            AND bettype NOT BETWEEN 901 AND 904
        GROUP BY bettype
        -- bettransm
        IF @Mode IN (0, 2, 3)
        BEGIN
            INSERT INTO #TmpBettype(bettype)
            SELECT bt.bettype
            FROM dbo.bettransm bt WITH(NOLOCK)
            WHERE bt.matchid = @MatchId AND NOT EXISTS(SELECT TOP 1 1
                FROM #TmpBettype tb WHERE bt.bettype = tb.bettype)
                AND bt.bettype NOT IN (10,29,38,500)
                AND bt.bettype NOT BETWEEN 801 AND 806
                AND bt.bettype < 19000
                AND bt.bettype NOT BETWEEN 901 AND 904
            GROUP BY bt.bettype
        END

    END
    
    --4: Mix Parlay
	IF @Mode = 4
	BEGIN
        INSERT INTO #TmpBettype(bettype)
        SELECT bettype
        FROM dbo.bettransm WITH(NOLOCK)
        WHERE matchid = @MatchId
            AND bettype NOT IN (10,29,38,500)
            AND bettype NOT BETWEEN 221 AND 227
            AND bettype NOT BETWEEN 801 AND 806
            AND bettype < 19000
            AND bettype NOT BETWEEN 901 AND 904
        GROUP BY bettype
	END

    SELECT bettype
    FROM #TmpBettype

    DROP TABLE #TmpBettype
END
GO