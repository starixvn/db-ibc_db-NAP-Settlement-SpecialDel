/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Auto_1s]
    @MatchID        INT
AS
/*    Creator: Jamie
    Date: 20150202
    Task: BetRadar - Auto settlement detail for manual calculation 
    DB: DBTXN/BODB02
    Original: 
    
    Revisions:
        - 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
        - 20161118@Kathy: Changes on Auto Settlement [Redmine:#67328]
		- 20160505@Patrick: Move code select match info to another SP [RedmineId: #56587]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]

    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON 
   
    DECLARE @tmpTicketStatus TABLE(
         ResourceID			VARCHAR(20)
        ,BetCount			INT
        ,InRunning			INT
        ,InWaiting			INT
        ,GroupId			SMALLINT
		,betSettledCount	INT
		,betMarkedCount		INT 
    )

    DECLARE @tmpTicketStatusParlay TABLE(
         ResourceID			VARCHAR(20)
        ,BetCount			INT
        ,InRunning			INT
        ,InWaiting			INT
        ,GroupId			SMALLINT
    )

	DECLARE @tmpAutoBettypes TABLE (
		bettype		SMALLINT
		,ResourceId VARCHAR(20)
		,BetId		BIGINT
		,OrdNo		SMALLINT
	)
	
	INSERT INTO @tmpAutoBettypes (bettype, ResourceId, BetId, OrdNo)
	SELECT	f.bettype, s.ResourceID, s.BetID, s.OrdNo
	FROM	dbo.f_Set_GetGroupBettypes() f
		INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			ON	f.BetType = s.BetType
	WHERE	f.GroupId = 8
			AND s.SportType = 1
			AND s.SettleType = 'EAR'
	
    INSERT INTO @tmpTicketStatus(ResourceID, BetCount, InRunning,InWaiting, betSettledCount, betMarkedCount)
    SELECT  f.ResourceId            
            ,SUM(CASE WHEN StatusID BETWEEN 101 AND 102 THEN 0 ELSE 1 END) AS BetCount       
            ,SUM(CASE WHEN StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS InRunning  
            ,SUM(CASE WHEN StatusID = 1 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS InWaiting 
			,SUM(CASE WHEN b.statusID BETWEEN 111 AND 113 OR b.statusID = 103 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN b.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
    FROM	dbo.bettrans b WITH(NOLOCK)
		INNER JOIN @tmpAutoBettypes f
			ON	b.bettype = f.bettype
				AND (f.BetId = 0 OR f.BetId = b.betid)
		LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
			ON	b.transid = mt.TransId
	WHERE	b.matchid = @MatchID
			AND b.statusID NOT IN (101, 102)
    GROUP BY f.ResourceId

	INSERT INTO @tmpTicketStatusParlay( ResourceID, BetCount, InRunning, InWaiting)
    SELECT  f.ResourceID
			,SUM(CASE WHEN bm.StatusID BETWEEN 101 AND 102 THEN 0 ELSE 1 END)
            ,SUM(CASE WHEN bm.StatusID = 0 THEN 1 ELSE 0 END) AS InRunning  
            ,SUM(CASE WHEN bm.StatusID = 1 THEN 1 ELSE 0 END) AS InWaiting 						             
    FROM    dbo.Bettransm bm WITH (NOLOCK)
        INNER JOIN @tmpAutoBettypes f
            ON	bm.bettype = f.BetType
				AND (f.BetID = 0 OR f.BetID = bm.betcheck)
    WHERE   matchID = @MatchID 
			AND bm.statusID NOT IN (101,102)
    GROUP BY f.ResourceID
		
	-- Detail 
	SELECT	tp.ResourceID
			,tp.TicketStatus
			,r.HomeValue
			,r.AwayValue
			,r.ResultStatusID
			,r.SettlementStatusID
	FROM (
		SELECT  COALESCE(t.ResourceID,p.ResourceID) AS ResourceID
				,CASE 
					WHEN t.InRunning > 0 THEN 'Running'
					WHEN t.InWaiting > 0 AND t.InWaiting = t.BetCount THEN 'Waiting'
					WHEN t.betMarkedCount > 0 THEN 'Marked'
					WHEN ISNULL(t.BetCount,0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
					WHEN ISNULL(t.BetCount,0) = 0 AND p.InWaiting > 0 AND p.BetCount = p.InWaiting THEN 'Parlay Waiting'
					ELSE 'Calculated'
				END AS TicketStatus
		FROM    @tmpTicketStatus t
			FULL JOIN @tmpTicketStatusParlay p	
				ON	t.resourceId = p.ResourceID
	) tp
        OUTER APPLY( 
			SELECT  r.ResourceId
					,r.HomeValue
					,r.AwayValue
					,r.ResultStatusID
					,r.SettlementStatusID                      
			FROM    DBPRO.bodb02.dbo.ResultDetail r WITH (NOLOCK)
			WHERE	r.ResourceID = tp.ResourceID
					AND r.MatchId =  @MatchID
			) AS r
		CROSS APPLY (
			SELECT	DISTINCT OrdNo
			FROM	@tmpAutoBettypes 
			WHERE	ResourceId = tp.ResourceID
		)o
	ORDER BY o.OrdNo

	-- number of ticket
	SELECT	8 AS GroupId 
			,SUM(InRunning) AS betRunningCount
			,SUM(betSettledCount) AS betSettledCount
			,SUM(betMarkedCount) AS betMarkedCount
	FROM	@tmpTicketStatus
END
GO