/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Auto_1s_ReCal]
(
    @MatchID        INT
)
AS
/*
    Created by: 20201211@Max
    Task: Support to Re-calculate Settled Tickets
    DB: DBTXN/BODB02 
    
    Revisions:            
		- 20201211@Max: Support to Re-calculate Settled Tickets [Redmine: #145669]
		
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

	-- Insert ResourceId of bettype = 382, 381 in case of No Ticket
	IF EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH(NOLOCK) WHERE matchid = @MatchID AND ChildMatchType = 202)
	BEGIN
		INSERT INTO @tmpTicketStatus(ResourceID, BetCount, InRunning,InWaiting, betSettledCount, betMarkedCount)
		SELECT t.ResourceId , NULL, NULL, NULL, NULL, NULL
		FROM @tmpAutoBettypes t
			LEFT JOIN (SELECT r.ResourceId FROM DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK) WHERE matchid = @MatchID) r
				on t.ResourceId = r.ResourceId
		WHERE t.bettype IN (381,382) 
			AND 1 = CASE WHEN t.ResourceId LIKE '38[12]0[12345]' AND t.ResourceId NOT IN (SELECT ResourceID FROM @tmpTicketStatus) THEN 1 
						WHEN t.ResourceId NOT LIKE '38[12]0[12345]' AND r.ResourceId IS NOT NULL THEN 1
						ELSE 0 
					END
	END

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
	FROM (
		SELECT  COALESCE(t.ResourceID,p.ResourceID) AS ResourceID
				,CASE 
					WHEN t.InRunning > 0 AND t.betSettledCount = 0 THEN 'Running'
					WHEN t.InWaiting > 0 AND t.InWaiting = t.BetCount AND t.betSettledCount = 0 THEN 'Waiting'
					WHEN t.betMarkedCount > 0 AND t.betSettledCount = 0 THEN 'Marked'
					WHEN ISNULL(t.BetCount,0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
					WHEN ISNULL(t.BetCount,0) = 0 AND p.InWaiting > 0 AND p.BetCount = p.InWaiting THEN 'Parlay Waiting'
					WHEN t.BetCount IS NULL AND t.ResourceID LIKE '38[12]%' THEN 'No Ticket'
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
END
GO