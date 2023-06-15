/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_GetBetTypesHaveTickets] 
(
    @MatchId    INT 
)
AS
/*  
    Created: 20230608@Max  
    Task : [TVS] Support void Cricket when reducing over [Redmine: #185833]
    DB: DBTXN/bodb02 
      
    Revisions:      
        - 20230608@Max: Create SP - [Redmine: #185833]

    Param's Explanation:  

*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @SiteDBGroupID SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

    CREATE TABLE #TmpBettype (bettype SMALLINT)

    -- Scan bettrans and bettransm to get bettype list
	-- bettrans
    INSERT INTO #TmpBettype(bettype)
	SELECT bettype
	FROM dbo.bettrans WITH(NOLOCK)
	WHERE matchid = @MatchId AND SiteDBGroupID = @SiteDBGroupID
		AND bettype NOT IN (10,29,38,500)
		AND bettype < 19000
	GROUP BY bettype

    -- bettransm
    INSERT INTO #TmpBettype(bettype)
    SELECT bt.bettype
    FROM dbo.bettransm bt WITH(NOLOCK)
    WHERE bt.matchid = @MatchId AND bt.SiteDBGroupID = @SiteDBGroupID
	AND NOT EXISTS(SELECT TOP 1 1
        FROM #TmpBettype tb WHERE bt.bettype = tb.bettype)
        AND bt.bettype NOT IN (10,29,38,500)
        AND bt.bettype < 19000
    GROUP BY bt.bettype
   
    SELECT t.bettype AS [Id]
		 ,CASE WHEN bt.typeid = 9604 THEN 'Over/Under'
			  WHEN bt.typeid = 9605 THEN 'Odd/Even'
		ELSE bt.typenamee END AS [Name]
    FROM #TmpBettype t
		INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = t.bettype

    DROP TABLE #TmpBettype
END
GO