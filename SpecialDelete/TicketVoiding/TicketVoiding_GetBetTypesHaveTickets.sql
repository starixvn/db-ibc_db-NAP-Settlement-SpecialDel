/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_GetBetTypesHaveTickets] 
(
    @MatchId    INT 
	,@FromTransDate DATETIME = NULL
	,@ToTransDate DATETIME = NULL
)
AS
/*  
    Created: 20230608@Max  
    Task : [TVS] Support void Cricket when reducing over [Redmine: #185833]
    DB: DBTXN/bodb02 
      
    Revisions:      
        - 20230608@Max: Create SP - [Redmine: #185833]
		- 20231207@Max: [TVS] Not Participate - Support user select exact bet type [Redmine: #197018]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]

    Param's Explanation:  

*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @SiteDBGroupID SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

    CREATE TABLE #TmpBettype (bettype SMALLINT, transdesc NVARCHAR(2000))
	DECLARE @tmpMatchId TABLE (MatchId INT)

	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM dbo.match m WITH(NOLOCK)
	WHERE 1 = CASE WHEN m.matchid = @MatchId THEN 1
				WHEN m.sporttype = 50 AND m.ChildMatchType = 200 AND ParentID = @MatchId THEN 1
			ELSE 0 END

    -- Scan bettrans and bettransm to get bettype list
	-- bettrans
    INSERT INTO #TmpBettype(bettype, transdesc)
	SELECT bettype, transdesc
	FROM dbo.bettrans WITH(NOLOCK)
	WHERE matchid IN (SELECT Matchid FROM @tmpMatchId)
		AND SiteDBGroupID = @SiteDBGroupID
		AND bettype NOT IN (10,29,38,500)
		AND bettype < 19000
		AND (transdate BETWEEN @FromTransDate AND @ToTransDate OR (@FromTransDate IS NULL AND @ToTransDate IS NULL))
	GROUP BY bettype, transdesc

    -- bettransm
    INSERT INTO #TmpBettype(bettype, transdesc)
    SELECT bt.bettype, bt.transdesc
    FROM dbo.bettransm bt WITH(NOLOCK)
    WHERE bt.matchid IN (SELECT Matchid FROM @tmpMatchId)
	AND bt.SiteDBGroupID = @SiteDBGroupID
	AND NOT EXISTS(SELECT TOP 1 1
        FROM #TmpBettype tb WHERE bt.bettype = tb.bettype)
        AND bt.bettype NOT IN (10,29,38,500)
        AND bt.bettype < 19000
		AND (transdate BETWEEN @FromTransDate AND @ToTransDate OR (@FromTransDate IS NULL AND @ToTransDate IS NULL))
    GROUP BY bt.bettype, bt.transdesc

	IF @FromTransDate IS NOT NULL AND @ToTransDate IS NOT NULL --New issuetype WMO, Technical Error
	BEGIN
		DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
			AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
			AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
			AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

		DELETE t
		FROM #TmpBettype t
			LEFT JOIN @bettype_tmp bt ON bt.bettype = t.bettype
		WHERE bt.bettype IS NULL
	END
   
    SELECT t.bettype AS [Id]
		 ,CASE WHEN bt.typeid = 9604 THEN 'Over/Under'
			  WHEN bt.typeid = 9605 THEN 'Odd/Even'
		ELSE bt.typenamee END AS [Name]
		,transdesc
		,f.GroupName
    FROM #TmpBettype t
		INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = t.bettype
		LEFT JOIN f_SD_GetGroupBettypes() f ON f.BetType = t.bettype

    DROP TABLE #TmpBettype
END
GO