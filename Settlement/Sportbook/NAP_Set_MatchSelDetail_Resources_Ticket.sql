/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Resources_Ticket]
	@matchid INT
	,@SportType INT = 0
	,@SettleType VARCHAR(10) = 'MNL'
	--,@ResourcesOutPut	   VARCHAR(Max) = '' OUTPUT
AS
/*
    Created by: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/BODB02 
    
    Revisions: 
		- 20220719@Louisa: Initial- Get ResourceId and Count ticket Status [Redmine:#175251]
*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE  @BestOfMap			TINYINT = NULL
			,@IsMergedParlay	BIT = 0
			,@OpenQuery			NVARCHAR(MAX) 
			,@IsCentral			BIT = 0

    DECLARE @tmpTicketStatus TABLE	(ResourceID VARCHAR(20), BetCount INT, InWaiting INT, InRunning INT, BetSettledCount INT, BetRefundedCount INT, BetMarkedCount INT, OrdNo INT, IsSpecialBettype BIT, SettleType VARCHAR(10)	)
    DECLARE @tmpTicketStatusParlay TABLE(ResourceID VARCHAR(20), BetCount INT, InWaiting INT, InRunning INT, BetSettledCount INT, BetRefundedCount INT, BetMarkedCount INT, OrdNo INT, IsSpecialBettype BIT)
    DECLARE @tblReturnTable TABLE (	ResourceID VARCHAR(20) ,SettleType VARCHAR(10) ,BetCount INT,InWaiting INT,InRunning INT,BetMarkedCount INT,BetSettledCount INT,BetRefundedCount INT, IsSpecialBettype BIT, OrdNo INT	)

	CREATE TABLE #tmpAllParentChildMatch (MatchId INT, ParentId INT)
    ---------------------------------------------------------------------------------------------
    IF @SportType = 0
	BEGIN
        SELECT @SportType = SportType FROM Match WITH(NOLOCK) WHERE matchID = @matchid
	END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
    --Use @BestOfMap for E-sport only
	SELECT @BestOfMap = BestOfMap
	FROM [dbo].[match_remark] WITH (NOLOCK) 
	WHERE matchid = @matchid    

	SELECT @IsMergedParlay = r.IsMergedParlay
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK)
    ---------------------------------------------------------------------------------------------

    --count ticket and group by Bettype and BetID
	 IF @SportType = 50
	BEGIN
		INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId )
		SELECT	@MatchId , @MatchId
		UNION ALL
		SELECT	m.MatchId , m.ParentID
		FROM	dbo.match m WITH(NOLOCK)
		WHERE	ISNULL(ParentID,0) =  @MatchId
				AND ISNULL(m.ChildMatchType, 0) = 200
				AND m.sporttype = 50
		
		; WITH cte_bettrans AS (
			SELECT  m.ParentId, m.MatchId, bt.StatusID , bt.Bettype,  bt.BetID
			FROM #tmpAllParentChildMatch m
				INNER JOIN dbo.Bettrans bt WITH(NOLOCK)	
					ON bt.MatchID = m.MatchID 
			WHERE bt.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupId END
				AND bt.statusID NOT IN (101, 102)
		)
		INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, BetMarkedCount, OrdNo, IsSpecialBettype)
		SELECT sp.ResourceID,
				COUNT(1) AS BetCount,
				SUM(CASE WHEN bt.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting,
				SUM(CASE WHEN bt.StatusID = 0 THEN 1 ELSE 0 END) As InRunning,
				SUM(CASE WHEN bt.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount,
				SUM(CASE WHEN bt.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount,
				0 AS betMarkedCount,
				MAX(sp.OrdNo) ,
				0 AS IsSpecialBettype
		FROM cte_bettrans bt
			CROSS APPLY (
				SELECT sp.OrdNo ,  sp.ResourceID, sp.sporttype, sp.Settletype
				FROM  SettlementSpecialBettypeProfile sp WITH (NOLOCK)	
				WHERE bt.Bettype = sp.Bettype
					AND (sp.Betid = 0 OR sp.BetID = bt.BetID)
			) sp
		WHERE sp.sporttype = @SportType
			AND sp.Settletype = @SettleType
		GROUP BY bt.ParentId, sp.ResourceID
	END

	ELSE 
	BEGIN
		INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, BetMarkedCount, OrdNo, IsSpecialBettype)
		SELECT  CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					 ELSE sp.ResourceID 
				END AS ResourceID, --Convert ResourceID 70400 (using for bettype 704,705,706) to 00
				COUNT(1) AS BetCount,
				SUM(CASE WHEN bt.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting,
				SUM(CASE WHEN bt.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) As InRunning,
				SUM(CASE WHEN bt.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount,
				SUM(CASE WHEN bt.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount,
				SUM(CASE WHEN bt.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount,
				MAX(sp.OrdNo),
				MAX(CASE WHEN SP.ResourceID  = '70400' OR bt.bettype = 153 THEN 1 ELSE 0 END) AS IsSpecialBettype -- 1 = there is at least 1 ticket bet on 704/705/706
		FROM bettrans bt WITH (NOLOCK)
			INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bt.Bettype
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	bt.transid = mt.TransId
		WHERE bt.matchid = @matchid
    		AND (sp.Betid = 0 OR sp.BetID = bt.BetID)
			AND bt.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupId END
			AND bt.statusID NOT IN (101, 102) --void/reject
			AND sp.sporttype = @SportType
			AND (sp.Settletype = @SettleType)	
		GROUP BY CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END

		-- insert more result
		IF @SportType = 2
		BEGIN
			INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, BetMarkedCount, OrdNo)
			SELECT  CASE WHEN bt.bettype = 603 THEN sp.ResourceID ELSE CAST(bt.bettype AS VARCHAR(20)) END,					
					0 AS BetCount,
					0 AS InWaiting,
					0 As InRunning,
					0 AS betSettledCount,
					0 AS betRefundedCount,
					0 AS betMarkedCount,
					MAX(sp.OrdNo)
			FROM (	SELECT DISTINCT bt.bettype, bt.betid
					FROM	dbo.bettrans bt WITH (NOLOCK)
					WHERE	bt.matchid = @matchid
							AND (bt.bettype = 603 OR bt.bettype BETWEEN 627 AND 644)
							AND bt.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupId END
							AND bt.statusID NOT IN (101, 102) --void/reject
					UNION ALL
					SELECT DISTINCT btm.bettype, btm.betcheck
					FROM	dbo.bettransm btm WITH (NOLOCK)
					WHERE	btm.matchid = @matchid
							AND (btm.bettype = 603 OR btm.bettype BETWEEN 627 AND 644)
							AND btm.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE btm.SiteDBGroupId END
							AND btm.statusID	NOT IN (101, 102) --void/reject
				)bt
				INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bt.Bettype
			WHERE	(sp.Betid = 0 OR sp.BetID = bt.BetID)
				AND sp.sporttype = @SportType
				AND (sp.Settletype = @SettleType)	
			GROUP BY CASE WHEN bt.bettype = 603 THEN sp.ResourceID ELSE CAST(bt.bettype AS VARCHAR(20)) END
		END
	END
	
	IF @SportType = 50
	BEGIN
		;WITH cte_bettransm AS (
			SELECT  m.ParentId, m.MatchId, bm.StatusID , bm.Bettype,  bm.Betcheck, bm.refno
			FROM #tmpAllParentChildMatch m
				INNER JOIN dbo.Bettransm bm WITH(NOLOCK) ON bm.MatchID = m.MatchID 
			WHERE bm.statusID NOT IN (101, 102)
				AND bm.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupId END
		)
		INSERT INTO @tmpTicketStatusParlay(ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, OrdNo, BetMarkedCount, IsSpecialBettype)
		SELECT sp.ResourceID     
			,COUNT(1) AS BetCount
			,SUM(CASE WHEN bm.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting
			,SUM(CASE WHEN bm.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END)
			,SUM(CASE WHEN bm.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN bm.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount
			,MAX(sp.OrdNo)
			,SUM(CASE WHEN bm.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
			,0 AS IsSpecialBettype
		FROM cte_bettransm bm
			CROSS APPLY (
							SELECT  sp.ResourceID, sp.OrdNo , sp.sporttype, sp.Settletype
							FROM dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
							WHERE sp.Bettype = bm.Bettype
							AND (sp.Betid = 0 OR sp.BetID = bm.Betcheck)
							AND sp.sporttype = 50
							AND sp.Settletype = @Settletype
						) sp
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON	b.matchid = 29		
					AND b.bettype = 29
					AND b.refno = bm.refno
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	b.transid = mt.TransId
					AND mt.matchid = bm.matchid
		WHERE	sp.sporttype = @SportType
				AND sp.Settletype = @SettleType
				AND bm.statusID NOT IN (101, 102)
		GROUP BY bm.ParentId, sp.ResourceID
	END
	ELSE
	BEGIN
		INSERT INTO @tmpTicketStatusParlay(ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, OrdNo, BetMarkedCount, IsSpecialBettype)
		SELECT CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END     
				,COUNT(1) AS BetCount
				,SUM(CASE WHEN bm.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting
				,SUM(CASE WHEN bm.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END)
				,SUM(CASE WHEN bm.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount
				,SUM(CASE WHEN bm.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount
				,MAX(sp.OrdNo)
				,SUM(CASE WHEN bm.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
				,MAX(CASE WHEN sp.ResourceID  = '70400' OR bm.bettype = 153 THEN 1 ELSE 0 END) AS IsSpecialBettype -- 1 = there is at least 1 ticket bet on 704/705/706
		FROM    dbo.Bettransm bm WITH (NOLOCK)
			INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bm.Bettype
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON	b.matchid = 29
					AND b.bettype = 29
					AND b.refno = bm.refno
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	b.transid = mt.TransId
					AND mt.matchid = @matchid
		WHERE   bm.matchID = @MatchID
				AND b.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupId END
				AND bm.SiteDBGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupId END
	    		AND bm.statusId NOT IN (101, 102)
	    		AND (sp.Betid = 0 OR sp.BetID = bm.Betcheck)
				AND sp.sporttype = @sporttype
				AND sp.Settletype = @Settletype
		GROUP BY CASE WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END 
			
	END

	IF @SportType = 43 AND  @BestOfMap IS NOT NULL
	BEGIN
		DELETE t
		FROM @tmpTicketStatus t
		INNER JOIN dbo.f_Set_MajorRound(@Sporttype) mr ON mr.ResourceID = t.ResourceID
		WHERE mr.OrdNo > @BestOfMap AND mr.ResourceID <> '00'
	END

   
	INSERT INTO @tblReturnTable (ResourceID
			,BetCount
			,InWaiting
			,InRunning
			,BetMarkedCount
			,BetSettledCount
			,BetRefundedCount
			--,SettleType
			,IsSpecialBettype
			,OrdNo)
	SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
			,ISNULL(bt.BetCount, 0) + ISNULL(p.BetCount, 0) AS BetCount
			,ISNULL(bt.InWaiting,0) + ISNULL(p.InWaiting,0) AS InWaiting
			,ISNULL(bt.InRunning,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.InRunning,0) ELSE 0 END AS InRunning
			,ISNULL(bt.betMarkedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetMarkedCount,0) ELSE 0 END AS BetMarkedCount
			,ISNULL(bt.BetSettledCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetSettledCount,0) ELSE 0 END AS BetSettledCount
			,ISNULL(bt.BetRefundedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetRefundedCount,0) ELSE 0 END AS BetRefundedCount
			--,ISNULL(bt.SettleType, @SettleType)
			,ISNULL(bt.IsSpecialBettype, p.IsSpecialBettype)
			,ISNULL(bt.OrdNo,p.OrdNo)
	FROM @tmpTicketStatus bt
	  		FULL JOIN @tmpTicketStatusParlay p ON bt.resourceId = p.ResourceID

	
	---INSERT for Major round if not exists
	INSERT INTO @tblReturnTable (ResourceID
			,BetCount
			,InWaiting
			,InRunning
			,BetMarkedCount
			,BetSettledCount
			,BetRefundedCount
			,SettleType
			,IsSpecialBettype
			,OrdNo)
	 SELECT mr.ResourceID
			,0 AS BetCount
			,0 AS InWaiting
			,0 AS InRunning
			,0 AS betMarkedCount
			,0 AS BetSettledCount
			,0 AS BetRefundedCount
			,'MNL' AS SettleType		
			,0 AS IsSpecialBettype
			,mr.OrdNo
	 FROM dbo.f_Set_MajorRound(@Sporttype) mr
		LEFT JOIN @tblReturnTable r ON r.ResourceID = mr.ResourceID
	WHERE r.ResourceId IS NULL

	 SELECT ResourceID
			, ISNULL(IsSpecialBettype,0) AS IsSpecialBettype
			,BetCount
			,InWaiting
			,InRunning
			,betMarkedCount
			,BetSettledCount
			,BetRefundedCount
	 FROM @tblReturnTable
	 ORDER BY CASE SettleType WHEN 'MNL' THEN 0 ELSE 1 END , OrdNo

	SELECT	SUM(betRunningCount)	AS betRunningCount
			,SUM(betSettledCount)	AS betSettledCount
			,SUM(betMarkedCount)	AS betMarkedCount
	FROM (
		SELECT	SUM(InRunning) AS betRunningCount
				,SUM(betSettledCount) + SUM(BetRefundedCount) AS betSettledCount
				,SUM(betMarkedCount) AS betMarkedCount
		FROM	@tmpTicketStatus	
		UNION ALL
		SELECT	SUM(InRunning) AS betRunningCount
				,SUM(betSettledCount) + SUM(BetRefundedCount) AS betSettledCount
				,SUM(betMarkedCount) AS betMarkedCount
		FROM	@tmpTicketStatusParlay
		WHERE	@IsMergedParlay = 1
	)t

END
GO