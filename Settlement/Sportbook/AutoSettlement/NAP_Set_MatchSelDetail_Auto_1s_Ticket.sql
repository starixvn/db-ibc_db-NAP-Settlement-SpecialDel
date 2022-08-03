/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Auto_1s_Ticket]
    @MatchID        INT
AS
/*  
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
    
    Revisions:
		- 20220719@Louisa: Initial [Redmine:#175251]

    Param's Explanation:
*/
BEGIN
    SET NOCOUNT ON 
    
	DECLARE @IsCentral			BIT

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

    DECLARE @tmpTicketStatus TABLE(
         ResourceID			VARCHAR(20)
        ,BetCount			INT
        ,InRunning			INT
        ,InWaiting			INT
        ,GroupId			SMALLINT
		,betSettledCount	INT
		,betMarkedCount		INT 
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
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
    GROUP BY f.ResourceId

	-- Insert ResourceId of bettype = 382, 381 in case of No Ticket
	IF EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH(NOLOCK) WHERE matchid = @MatchID AND ChildMatchType = 202)
	BEGIN
		INSERT INTO @tmpTicketStatus(ResourceID, BetCount, InRunning,InWaiting, betSettledCount, betMarkedCount)
		SELECT t.ResourceId , NULL, NULL, NULL, NULL, NULL
		FROM @tmpAutoBettypes t
		WHERE t.bettype IN (381,382) 
			AND 1 = CASE WHEN t.ResourceId LIKE '38[12]0[12345]' AND t.ResourceId NOT IN (SELECT ResourceID FROM @tmpTicketStatus) THEN 1 
						ELSE 0 
					END
	END

	INSERT INTO @tmpTicketStatus(ResourceID, BetCount, InRunning,InWaiting, betSettledCount, betMarkedCount)
    SELECT  f.ResourceID
			,SUM(CASE WHEN bm.StatusID BETWEEN 101 AND 102 THEN 0 ELSE 1 END)
            ,SUM(CASE WHEN bm.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS InRunning  
            ,SUM(CASE WHEN bm.StatusID = 1 THEN 1 ELSE 0 END) AS InWaiting 				
			,SUM(CASE WHEN bm.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN bm.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
    FROM    dbo.Bettransm bm WITH (NOLOCK)
        INNER JOIN @tmpAutoBettypes f
            ON	bm.bettype = f.BetType
				AND (f.BetID = 0 OR f.BetID = bm.betcheck)
		LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
			ON	b.matchid = 29		
				AND b.bettype = 29
				AND b.refno = bm.refno
		LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
			ON	b.transid = mt.TransId
				AND mt.matchid = bm.matchid
    WHERE   bm.matchID = @MatchID 
			AND bm.statusID NOT IN (101,102)
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
    GROUP BY f.ResourceID
		
	-- Detail 
	SELECT	tp.ResourceID
			,InRunning
			,InWaiting
			,betMarkedCount
			,BetCount
	FROM (
			SELECT  t.ResourceID
					,ISNULL(SUM(t.InRunning),0) AS InRunning
					,ISNULL(SUM(t.InWaiting),0) AS InWaiting
					,ISNULL(SUM(t.betMarkedCount),0) AS betMarkedCount
					,ISNULL(SUM(t.BetCount),0) AS BetCount
			FROM    @tmpTicketStatus t
			GROUP BY t.ResourceID
		) tp
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