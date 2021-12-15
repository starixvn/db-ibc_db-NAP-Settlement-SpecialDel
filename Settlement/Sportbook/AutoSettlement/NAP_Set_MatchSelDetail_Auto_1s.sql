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
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20201113@Louisa: Check Hold Result [Redmine:#135097]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]

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

  --  DECLARE @tmpTicketStatusParlay TABLE(
  --       ResourceID			VARCHAR(20)
  --      ,BetCount			INT
  --      ,InRunning			INT
  --      ,InWaiting			INT
  --      ,GroupId			SMALLINT
		--,betSettledCount	INT
		--,betMarkedCount		INT 
  --  )

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
    GROUP BY f.ResourceID
		
	-- Detail 
	SELECT	tp.ResourceID
			,CASE 
				WHEN tp.InRunning > 0 THEN 'Running'
				WHEN tp.InWaiting > 0 AND tp.InWaiting = tp.BetCount THEN 'Waiting'
				WHEN tp.betMarkedCount > 0 THEN 'Marked'
				WHEN tp.BetCount = 0 AND tp.ResourceID LIKE '38[12]%' THEN 'No Ticket'
				ELSE 'Calculated'
			END AS TicketStatus
			,r.HomeValue
			,r.AwayValue
			,r.ResultStatusID
			,r.SettlementStatusID
			, ISNULL( r.ResultSetting, 0) AS ResultSetting
	FROM (
		SELECT  t.ResourceID
				,ISNULL(SUM(t.InRunning),0) AS InRunning
				,ISNULL(SUM(t.InWaiting),0) AS InWaiting
				,ISNULL(SUM(t.betMarkedCount),0) AS betMarkedCount
				,ISNULL(SUM(t.BetCount),0) AS BetCount
		FROM    @tmpTicketStatus t
		GROUP BY t.ResourceID
	) tp
        OUTER APPLY( 
			SELECT  r.ResourceId
					,r.HomeValue
					,r.AwayValue
					,r.ResultStatusID
					,r.SettlementStatusID
					,ISNULL( r.ResultSetting, 0) AS ResultSetting                      
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