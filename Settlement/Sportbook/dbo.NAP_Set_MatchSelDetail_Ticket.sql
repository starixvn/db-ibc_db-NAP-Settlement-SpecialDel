/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Ticket]
	@matchid 				INT
    ,@IsRefundPage 		BIT = 0
AS
/*
    Created by: 20220719
    Task: get ticket info of match 
 
    Revisions:            
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

*/
BEGIN
    SET NOCOUNT ON

    DECLARE @IsExistFGLG			BIT       
        ,@IsLive					BIT		
        ,@sporttype					SMALLINT
        ,@IsExistHTFGLG				BIT
		,@IsExistFGNG				BIT
        ,@FTStatus					NVARCHAR(50)
        ,@HTStatus					NVARCHAR(50)
        ,@2HStatus					NVARCHAR(50)
        ,@FGLGStatus				NVARCHAR(50)
        ,@HTFGLGStatus				NVARCHAR(50)      
        ,@isExistResultandFirstTeamScore    BIT				
		,@IsEnabledGoalRecordHT		BIT
		,@IsEnabledGoalRecordFT		BIT
		
		
		,@LeagueGroupID				SMALLINT
		,@IsMergedParlay			BIT 
		,@IsCentral					BIT
	
	DECLARE @tmpBettypes TABLE (bettype SMALLINT, GroupId TINYINT, IsUsedGoalRecordValue BIT, IsDetermined BIT, GroupName VARCHAR(50), IsFGLG BIT)

	DECLARE @status TABLE (GroupId TINYINT
		,betCount INT, betWaitingCount INT, betRunningCount INT, betSettledCount INT, betMarkedCount INT
		,betParlayCount INT, betParlayWaitingCount INT, betParlayRunningCount INT
	)

	CREATE TABLE #Data (
		bettype			SMALLINT 
		,isParlay		BIT 
		,betRunningCount INT DEFAULT(0)
		,betWaitingCount	INT DEFAULT(0)
		,betSettledCount INT DEFAULT(0)
		,betMarkedCount INT DEFAULT(0) 
		,betCount	INT DEFAULT(0)		
		
		,betParlayRunningCount INT DEFAULT (0)
		,betParlayWaitingCount INT DEFAULT(0)
		,betParlaySettledCount INT DEFAULT(0)
		,betParlayMarkedCount INT DEFAULT(0)
		,betParlayCount	INT DEFAULT(0)

		,ExistLG		BIT
		,ExistHTLG		BIT
		,IsLive			BIT
		, PRIMARY KEY (bettype,isParlay)
	)
	INSERT INTO @tmpBettypes (bettype, GroupId, IsUsedGoalRecordValue, IsDetermined, GroupName, IsFGLG)
	SELECT	BetType, GroupId, IsUsedGoalRecordValue, IsDetermined, GroupName, IsFGLG
	FROM	dbo.[f_Set_GetGroupBettypes]()
	WHERE	IsAuto = 0

    SELECT	@IsExistFGLG = 0
			,@IsExistFGNG = 0
			,@IsLive = 0		
			,@IsExistHTFGLG = 0
			,@isExistResultandFirstTeamScore = 0 		
			,@IsEnabledGoalRecordHT = 0
			,@IsEnabledGoalRecordFT = 0
			,@IsMergedParlay	 = 0

    SELECT	@sporttype 	= m.sporttype
			,@LeagueGroupID = ISNULL(l.LeagueGroupID,0)
    FROM  dbo.match m WITH (NOLOCK)
		INNER JOIN  dbo.League l WITH(NOLOCK) 
			ON	m.leagueid = l.leagueid
    WHERE  m.matchid = @matchid
	
	SELECT	@IsMergedParlay = IsMergedParlay
	FROM	dbo.SettlementResultTableSetting ss WITH(NOLOCK)
	WHERE	ss.Sporttype = @sportType

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	INSERT INTO #Data (bettype, isParlay
			,betRunningCount, betWaitingCount, betSettledCount, betMarkedCount, betCount
			, IsLive		
		)
	SELECT	b.bettype, 0 isParlay
			,SUM(CASE WHEN b.statusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS betRunningCount
			,SUM(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS betWaitingCount
			,SUM(CASE WHEN b.statusID BETWEEN 111 AND 113 OR b.statusID = 103 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN b.statusID BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
			,COUNT(1) AS betCount			
			,MAX(CASE WHEN b.liveindicator = 1 THEN 1 ELSE 0 END) AS IsLive	
	FROM	dbo.bettrans b WITH(NOLOCK)
				OUTER APPLY (
					SELECT TOP 1 mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transId
				)mt
	WHERE	b.matchid = @matchid
			AND b.SiteGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteGroupId END
			AND b.statusID NOT IN (101, 102)
	GROUP BY b.bettype	
	
	IF @IsMergedParlay = 0
	BEGIN
		INSERT INTO #Data (bettype, isParlay
			,betParlayRunningCount, betParlayWaitingCount, betParlayCount
			, IsLive				
		)
		SELECT	bm.bettype, 1 isParlay
				,SUM(CASE WHEN statusID = 0 THEN 1 ELSE 0 END) betParlayRunningCount
				,SUM(CASE WHEN statusID = 1 THEN 1 ELSE 0 END) betParlayWaitingCount
				,COUNT(1) betParlayCount
				,MAX(CASE WHEN liveindicator = 1 THEN 1 ELSE 0 END) AS IsLive
		FROM	dbo.bettransm bm WITH(NOLOCK)
		WHERE	matchid = @matchid
				AND bm.SiteGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteGroupId END
				AND statusID NOT IN (101, 102)
		GROUP BY bm.bettype
	END
	ELSE
	BEGIN
		INSERT INTO #Data (bettype, isParlay
			,betRunningCount, betWaitingCount, betSettledCount, betMarkedCount, betCount
			, IsLive			
		)
		SELECT	bm.bettype, 1 isParlay			
				,SUM(CASE WHEN bm.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) betRunningCount
				,SUM(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) betWaitingCount
				,SUM(CASE WHEN bm.statusID BETWEEN 111 AND 113 OR bm.statusId = 103 THEN 1 ELSE 0 END) AS betSettledCount
				,SUM(CASE WHEN bm.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
				,COUNT(1) betCount
				,MAX(CASE WHEN bm.liveindicator = 1 THEN 1 ELSE 0 END) AS IsLive
		FROM	dbo.bettransm bm WITH(NOLOCK)
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON	b.matchid = 29		
					AND b.bettype = 29
					AND b.refno = bm.refno
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	b.transid = mt.TransId
					AND mt.matchid = bm.matchid
		WHERE	bm.matchid = @matchid
				AND bm.SiteGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteGroupId END
				AND bm.statusID NOT IN (101, 102)
		GROUP BY bm.bettype
	END

	SELECT	
			 -- 14F, 14L; GroupID = 4: bettype 14; -- 127F, 127L; GroupID = 3: bettype 127
			 @IsExistFGLG =  MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsFGLG = 1 THEN 1 ELSE 0 END)
			,@IsExistHTFGLG = MAX(CASE WHEN f.GroupId IN (1,3) AND f.IsFGLG = 1 THEN 1 ELSE 0 END)
			,@IsExistFGNG =  MAX(CASE WHEN f.IsFGLG = 1 THEN 1 ELSE 0 END)
			
			,@isExistResultandFirstTeamScore = MAX(CASE WHEN f.BetType = 172 THEN 1 ELSE 0 END)
		
			,@IsEnabledGoalRecordHT = MAX(CASE WHEN f.GroupId IN (1,3) AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END)
			,@IsEnabledGoalRecordFT = MAX(CASE WHEN f.GroupId IN (2,4) AND f.IsUsedGoalRecordValue = 1 THEN 1 ELSE 0 END) 
			
			,@IsLive = MAX(CASE WHEN b.IsLive = 1 THEN 1 ELSE 0 END)
			
	FROM	#Data b
		LEFT JOIN @tmpBettypes f
			ON b.bettype = f.BetType

    IF @IsRefundPage = 0 -- Calculate page
    BEGIN			
        -- check match status
		INSERT INTO @status (GroupId, betCount, betRunningCount, betSettledCount, betMarkedCount, betWaitingCount
				, betParlayCount, betParlayRunningCount, betParlayWaitingCount
		)
		SELECT	CASE 
					WHEN g.groupId IN (1,3) THEN 1 -- HT, HT FGLG
					WHEN g.groupId = 4 OR (g.GroupId = 2 AND g.IsUsedGoalRecordValue =1) THEN 2 -- FGLG
					ELSE 0
				END AS GroupId
			,SUM(b.betCount) AS betCount
			,SUM(b.betRunningCount) AS betRunningCount
			,SUM(b.betSettledCount) AS betSettledCount
			,SUM(b.betMarkedCount) AS betMarkedCount
			,SUM(b.betWaitingCount) AS betWaitingCount	
			
			,SUM(b.betParlayCount) AS betParlayCount
			,MAX(b.betParlayRunningCount) AS betParlayRunningCount
			,SUM(b.betParlayWaitingCount) AS betParlayWaitingCount		
		FROM	#Data b
			INNER JOIN @tmpBettypes g
				ON	b.bettype = g.BetType
		GROUP BY CASE 
					WHEN g.groupId IN (1,3) THEN 1 -- HT, HT FGLG
					WHEN g.groupId = 4 OR (g.GroupId = 2 AND g.IsUsedGoalRecordValue =1) THEN 2 -- FT FGLG
					ELSE 0
				END

		INSERT INTO @status (GroupId, betCount, betRunningCount, betWaitingCount, betParlayCount, betParlayRunningCount, betParlayWaitingCount)
		SELECT t.GroupId, 0, 0, 0, 0, 0, 0
		FROM (VALUES (0),(1),(2),(3)) AS t (GroupId)
		WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @status s WHERE s.GroupId = t.GroupId)

    END

    SELECT	ISNULL(@IsExistFGLG,0) AS IsExistFGLG
			,ISNULL(@IsExistFGNG,0) AS IsExistFGNG
			,ISNULL(@IsExistHTFGLG,0) AS IsExistHTFGLG
			,ISNULL(@IsEnabledGoalRecordHT,0) AS IsEnabledGoalRecordHT
			,ISNULL(@IsEnabledGoalRecordFT,0) AS IsEnabledGoalRecordFT
			,ISNULL(@IsLive,0) AS IsLive
			,ISNULL(@isExistResultandFirstTeamScore,0) AS isExistResultandFirstTeamScore
   
	-- Get number of ticket	
	SELECT t.GroupId
			,SUM(t.betCount) AS betCount
			,SUM(t.betWaitingCount) AS betWaitingCount
			,SUM(t.betRunningCount) AS betRunningCount
			,SUM(t.betSettledCount) AS betSettledCount
			,SUM(t.betMarkedCount) AS betMarkedCount

			,SUM(t.betParlayCount) AS betParlayCount
			,SUM(t.betParlayWaitingCount) AS betParlayWaitingCount
			,SUM(t.betParlayRunningCount) AS betParlayRunningCount
	FROM(
		SELECT	CASE 
					WHEN @sporttype = 1 THEN GroupId
					ELSE 0
				END AS GroupId
				,betCount
				,betWaitingCount
				,betRunningCount
				,betSettledCount
				,betMarkedCount

				,betParlayCount
				,betParlayWaitingCount
				,betParlayRunningCount
		FROM	@status
		WHERE	GroupId IN (0,1,2)
				AND 1 = CASE WHEN @sporttype <= 99 AND @sporttype NOT IN (27,46,1,2,5,9,43) THEN 1 ELSE 0 END
						
	) t
	GROUP BY t.GroupId
	ORDER BY t.GroupId
	
	SELECT	m.matchid				
			,MAX(CASE WHEN b.statusID = 0 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS IsExistMarkedTicket
			,MAX(CASE WHEN b.statusID BETWEEN 0 AND 1 AND mt.TransId IS NULL THEN 1 ELSE 0 END) AS IsExistRunningTicket		
	FROM	dbo.match m WITH(NOLOCK)
		LEFT JOIN dbo.bettrans b WITH(NOLOCK)
			ON b.matchid = m.matchid
		OUTER APPLY ( 
			SELECT TOP 1 TransId 
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	b.transID = mt.TransId 
					AND b.statusID = 0
		) mt
	WHERE   m.ParentID = @matchid  
		AND b.SiteGroupId = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteGroupId END
		AND m.ChildMatchType IN ( 201,202,203)
		AND ISNULL(m.IsDeleted,0) = 0
		AND @sporttype = 1 AND @LeagueGroupID IN (42,74,108)
END
GO