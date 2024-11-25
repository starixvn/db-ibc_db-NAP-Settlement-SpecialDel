/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_GetBetTypesHaveTickets] 
(
     @MatchId    INT 
	,@TimeRangeJson VARCHAR(MAX) = NULL
	,@IsGetCancelCashOut BIT = 0
)
AS
/*  
    Created: 20230608@Max  
    Task : [TVS] Support void Cricket when reducing over [Redmine: #185833]
    DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
      
    Revisions:      
        - 20230608@Max: Create SP - [Redmine: #185833]
		- 20231207@Max: [TVS] Not Participate - Support user select exact bet type [Redmine: #197018]
		- 20240522@Max: [TVS] Wrong Market Offered issue type [Redmine: #197051]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20240823@July: WMKO/TE - Add Details of bet list for issue types [Redmine: #208628]
		- 20240916@Max: [TVS] Support void wrong odds for Sportsbook [Redmine: #186029]
		- 20241122@July: Wrong Market Offered - Enhance the way to add request & Update 'copy' message template [Redmine: #212928]

    Param's Explanation:  

*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @SiteDBGroupID SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

    CREATE TABLE #TmpBettype (bettype SMALLINT, transdesc NVARCHAR(2000))
	DECLARE @tmpMatchId TABLE (MatchId INT)

	DECLARE @tmpConsolidatedBettypes TABLE (
        parentid        INT
        ,typeid         INT PRIMARY KEY
    )
    DECLARE @tmpTimeRange TABLE (
        MatchId			INT
		,FromDate        DATETIME
        ,ToDate         DATETIME
    )
    INSERT INTO @tmpConsolidatedBettypes (parentid, typeid)
    SELECT f.GroupTypeId AS parentid
		 , f.Bettype AS typeid
    FROM [dbo].[f_SD_GroupDisplayBettype] () f

	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM dbo.match m WITH(NOLOCK)
	WHERE 1 = CASE WHEN m.matchid = @MatchId THEN 1
				   WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 AND ParentID = @MatchId THEN 1
			       ELSE 0 END

	INSERT INTO @tmpTimeRange (MatchId, FromDate, ToDate)
	SELECT m.MatchId, d.FromDate, d.ToDate
	FROM @tmpMatchId m
	    CROSS APPLY (
				SELECT FromDate, ToDate
				FROM OPENJSON(@TimeRangeJson) 
				WITH( FromDate DATETIME
					 ,ToDate DATETIME
					) tbl
		)d

    -- Scan bettrans and bettransm to get bettype list
	-- bettrans
    INSERT INTO #TmpBettype(bettype, transdesc)
	SELECT bettype, transdesc
	FROM dbo.bettrans b WITH(NOLOCK)
		INNER JOIN @tmpMatchId m ON b.matchid = m.MatchId
		LEFT JOIN @tmpTimeRange t ON b.matchid = t.MatchId
	WHERE SiteDBGroupID = @SiteDBGroupID
		AND bettype NOT IN (10,29,38,500)
		AND bettype < 19000
		AND 1 = CASE WHEN t.FromDate IS NULL AND t.ToDate IS NULL THEN 1 
		             WHEN b.transdate BETWEEN t.FromDate AND t.ToDate THEN 1
					 ELSE 0 END
	GROUP BY bettype, transdesc

    -- bettransm
    INSERT INTO #TmpBettype(bettype, transdesc)
    SELECT bm.bettype, bm.transdesc
    FROM dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN @tmpMatchId m ON bm.matchid = m.MatchId
		LEFT JOIN @tmpTimeRange t ON bm.matchid = t.MatchId
   WHERE bm.SiteDBGroupID = @SiteDBGroupID
		AND 1 = CASE WHEN t.FromDate IS NULL AND t.ToDate IS NULL THEN 1 
					 WHEN bm.transdate BETWEEN t.FromDate AND t.ToDate THEN 1
					 ELSE 0 END
		AND NOT EXISTS(SELECT TOP 1 1
					   FROM #TmpBettype tb WHERE bm.bettype = tb.bettype)
    GROUP BY bm.bettype, bm.transdesc

	IF EXISTS( SELECT TOP 1 1 FROM @tmpTimeRange)--New issuetype WMO, Technical Error, WrongOdds SB
	BEGIN
		IF @IsGetCancelCashOut = 1
		BEGIN
			-- get ticket Cancel CO from CashOutSelling
			INSERT INTO #TmpBettype(bettype, transdesc)
			SELECT b.bettype, transdesc
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN dbo.CashOutSelling c WITH (NOLOCK) ON c.TransID = b.TransId
				INNER JOIN @tmpMatchId m ON b.matchid = m.MatchId
				INNER JOIN @tmpTimeRange t ON b.matchid = t.MatchId
			WHERE b.SiteDBGroupID = @SiteDBGroupID
				AND b.betdaqid = -2
				AND c.CheckTime BETWEEN t.FromDate AND t.ToDate
			GROUP BY b.bettype, transdesc
		END

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

		UPDATE t SET t.bettype = tb.parentid
		FROM #TmpBettype t
			INNER JOIN @tmpConsolidatedBettypes tb ON tb.typeid = t.bettype
	END
   
    SELECT t.bettype AS [Id]
		 ,CASE WHEN bt.typeid = 9604 THEN 'Over/Under'
			  WHEN bt.typeid = 9605 THEN 'Odd/Even'
		ELSE bt.typenamee END AS [Name]
		,transdesc
		,f.GroupName
    FROM #TmpBettype t
		INNER JOIN dbo.bettype bt WITH (NOLOCK) ON bt.typeid = t.bettype
		INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = t.bettype
	GROUP BY t.bettype, bt.typeid, bt.typenamee, t.transdesc, f.GroupName
	ORDER BY f.GroupName, bt.typenamee

    DROP TABLE #TmpBettype
END
GO