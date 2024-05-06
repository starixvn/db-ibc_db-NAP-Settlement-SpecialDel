/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchOtherSports_TicketInfoSel
	 @MatchInfo			VARCHAR(MAX)    = NULL
	,@MatchOverStatus	VARCHAR(MAX)	= NULL

AS
/*  
	 Created by: 20240503@Louisa
	 Task: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]
	 DB: DBTXN/bodb02
	 
	 Revisions:  
			- 20240503@Louisa: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]

	Parameters Explanation:        				
*/
BEGIN
	SET NOCOUNT ON
	DECLARE		 @IsCentral							BIT
				,@n									INT 
				,@minBettype						SMALLINT
				,@maxBettype						SMALLINT
				,@IsOverEarly						BIT = 0
				,@IsMainOver						BIT = 0
				,@IsOver							BIT = 0		
				,@IsCompletedWithRunningTicket		BIT = 0 


	DECLARE  @tmpMatchOverStatus TABLE(MatchId INT, Bettype INT DEFAULT(0),BetId INT DEFAULT(0), OverStatus INT DEFAULT(0) )
	DECLARE @tmpEarlyBettypes TABLE (Bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpEarlyBettypeStatus TABLE(MatchId INT,bettype SMALLINT,isExistSingle BIT DEFAULT(0),isRunningSingle	BIT DEFAULT(0),isWaitingSingle	BIT DEFAULT(0))	
	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsDisplay BIT DEFAULT(0),PRIMARY KEY (MatchId) )
	DECLARE @tmpQueueStatus TABLE (MatchId INT, IsCalculatingSingle TINYINT DEFAULT(0), IsCalculatingMP TINYINT DEFAULT(0))
	CREATE TABLE #tmpMatch(
		 MatchId							INT
		,SportType							SMALLINT
		,EventStatus						NVARCHAR(100)
		,ChildMatchType						TINYINT

		,SuspenderHalfTime					NVARCHAR(50)
		,SuspenderFullTime					NVARCHAR(50)

		,IsExistMarkedTicket				BIT DEFAULT (0)
		,IsExistsConfirmedEarly				BIT DEFAULT (0)
		,IsExistEarlyBettypes				BIT DEFAULT (0)
		,IsRunningEarlyBettypes				BIT DEFAULT (0)
		,IsWaitingEarlyBettypes				BIT DEFAULT (0)
		,IsExistRunningTicketAfterCompleted	BIT DEFAULT (0) 
	)
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)
	CREATE TABLE #temp_match_parlay (ParentID INT, transid BIGINT, matchid INT, refno BIGINT)
	CREATE TABLE #tmpAllParentChildMatch (MatchId INT PRIMARY KEY, ParentId INT, eventstatus NVARCHAR(50))
	CREATE INDEX CIX_tmp_ParentId ON #tmpAllParentChildMatch(ParentId)

	DECLARE @CheckingDisplay TABLE (matchid INT)

	SET @n = 2147483647

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO #tmpMatch(MatchId,SportType,ChildMatchType,EventStatus,SuspenderHalfTime,SuspenderFullTime)
	SELECT tbl.m		AS MatchId
		  ,tbl.s		AS SportType
		  ,tbl.cmt	    AS ChildMatchType 		
		  ,tbl.e		AS EventStatus
		  ,CASE tbl.cfht 
				WHEN 0 THEN ''
				ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = tbl.cfht )
			END
		  ,CASE tbl.cfft
				WHEN 0 THEN ''
				ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = tbl.cfft)
			END
	FROM OPENJSON(@MatchInfo) WITH (
			m		INT
		   ,s		SMALLINT
		   ,cmt	    TINYINT		
		   ,e		NVARCHAR(100)
		   ,cfht	INT		
		   ,cfFt	INT
	) AS tbl

	IF EXISTS ( SELECT TOP 1 1 FROM #tmpMatch WHERE Sporttype = 50 AND ISNULL(childmatchtype,0) <> 200 )
	BEGIN
		INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, eventstatus)
		SELECT	DISTINCT m.matchid, m.ParentId,  t.eventstatus
		FROM	#tmpMatch t
			CROSS APPLY (
				SELECT	m.matchid, m.ParentId
				FROM	dbo.match m WITH(NOLOCK)
				WHERE	m.sporttype = 50
						AND m.ChildMatchType = 200
						AND m.ParentID = t.matchid
			)m
	END

	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, eventstatus)
	SELECT DISTINCT m.matchid, m.matchid,  m.eventstatus 
	FROM #tmpMatch m
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tmpAllParentChildMatch p WHERE p.MatchId = m.matchid)


	/***********************Filter by OverStatus******************************/
	INSERT INTO @tmpMatchOverStatus (matchid, bettype, betid, OverStatus)
	SELECT tbl.m AS matchid, tbl.b AS bettype, tbl.bid AS bettype, tbl.o AS OverStatus
	FROM OPENJSON(@MatchOverStatus) WITH (
			m		INT
		   ,b		INT
		   ,bid		INT
		   ,o		INT		
	) AS tbl

	SELECT	 @IsOverEarly	=  MAX(CASE WHEN s.OverStatus = 1 THEN 1 ELSE 0 END)
			,@IsMainOver	=  MAX(CASE WHEN s.OverStatus = 2 THEN 1 ELSE 0 END)
			,@IsOver		=  MAX(CASE WHEN s.OverStatus = 3 THEN 1 ELSE 0 END)
			,@IsCompletedWithRunningTicket = MAX(CASE WHEN s.OverStatus = 4 THEN 1 ELSE 0 END)
	FROM @tmpMatchOverStatus s

	
	IF @IsOverEarly = 1
	BEGIN
		INSERT INTO @CheckingDisplay (matchid)
		SELECT DISTINCT m1.matchid
		FROM (SELECT DISTINCT matchid FROM @tmpMatchOverStatus  WHERE OverStatus = 1) m1	
				CROSS APPLY (SELECT TOP 1 1 valid
							 FROM bettrans b WITH (nolock)
								INNER JOIN @tmpMatchOverStatus m 
									ON m.matchid = b.matchid
							 WHERE m1.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
								AND b.statusId = 0
								AND b.bettype = m.bettype AND (b.betID = 0 OR b.betid = m.betid ) 
								AND m.OverStatus = 1 
							 ) AS tmp

		DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

		INSERT INTO @CheckingDisplay ( matchid)
		SELECT DISTINCT m1.matchid
		FROM (	SELECT DISTINCT matchid FROM @tmpMatchOverStatus  WHERE OverStatus = 1) m1	
				CROSS APPLY (	SELECT TOP 1 1 valid
								FROM bettransm b WITH (nolock)
									INNER JOIN @tmpMatchOverStatus m ON m.matchid = b.matchid
								WHERE m1.matchid = b.matchid
									AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
									AND b.statusId = 0
									AND b.bettype = m.bettype AND (b.betcheck = 0 OR b.betcheck = m.betid ) 
									AND m.OverStatus = 1 
								) AS tmp

		DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

		UPDATE #tmpMatch  SET IsExistsConfirmedEarly = 1 WHERE matchid IN (SELECT DISTINCT matchid FROM @CheckingDisplay)
	END 

	IF @IsOver = 1 OR @IsMainOver = 1
	BEGIN
		INSERT INTO @CheckingDisplay ( matchid)
		SELECT m.matchid
		FROM @tmpMatchOverStatus m
			CROSS APPLY (	SELECT TOP 1 1 valid
							FROM bettrans b with (nolock)
							WHERE m.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
							) AS tmp
		WHERE m.OverStatus IN (2,3) 

		DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

		INSERT INTO @CheckingDisplay ( matchid)
		SELECT m.matchid
		FROM @tmpMatchOverStatus m
			CROSS APPLY (	SELECT TOP 1 1 valid
							FROM bettransm b with (nolock)
							WHERE m.matchid = b.matchid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
							) AS tmp
		WHERE m.OverStatus IN (2,3) 
	
		DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

	END

	IF @IsCompletedWithRunningTicket = 1
	BEGIN
		INSERT INTO @CheckingDisplay ( matchid)
		SELECT m.matchid
		FROM @tmpMatchOverStatus m
			CROSS APPLY (	SELECT TOP 1 1 valid
							FROM bettrans b with (nolock)
							WHERE b.matchid IN (SELECT t.MatchId FROM #tmpAllParentChildMatch t WHERE t.ParentId = m.MatchId)
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
								AND b.statusId = 0
							) AS tmp
		WHERE m.OverStatus = 4

		DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (	SELECT matchid FROM @CheckingDisplay)

		INSERT INTO @CheckingDisplay ( matchid)
		SELECT m.matchid
		FROM @tmpMatchOverStatus m
			CROSS APPLY (	SELECT TOP 1 1 valid
							FROM bettransm b with (nolock)
							WHERE b.matchid IN (SELECT t.MatchId FROM #tmpAllParentChildMatch t WHERE t.ParentId = m.MatchId)
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
								AND b.statusId = 0
							) AS tmp
		WHERE m.OverStatus = 4

		DELETE FROM @tmpMatchOverStatus  WHERE Matchid IN (SELECT matchid FROM @CheckingDisplay)
	END

	IF @IsOverEarly = 1 OR @IsOver = 1 OR @IsMainOver = 1 OR @IsCompletedWithRunningTicket = 1
	BEGIN
		DELETE FROM #tmpMatchId WHERE matchid NOT IN (SELECT matchid FROM @CheckingDisplay)
	END

	;WITH singlequeue 
	AS(
		SELECT	s.matchid
				,MIN(s.IsCalculating) AS IsCalculatingSingle
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	s.IsCalculating IN (0, 1)
				AND s.SportType <> 1
		GROUP BY s.matchid
	)
	,parlayqueue
	AS(
		SELECT	p.matchid
				,MAX(p.IsCalculating) AS IsCalculatingMP
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE	p.IsCalculating IN (0,1)
		GROUP BY p.matchid
	)
	INSERT INTO @tmpQueueStatus(MatchId, IsCalculatingSingle, IsCalculatingMP)
	SELECT	ISNULL(s.matchid, p.matchid) AS matchid
			,s.IsCalculatingSingle
			,p.IsCalculatingMP
	FROM	singlequeue s
		FULL OUTER JOIN parlayqueue p ON s.matchid = p.matchid
	
	INSERT INTO @tmpEarlyBettypes(Bettype)
	SELECT	DISTINCT bettype
	FROM	dbo.SettlementSpecialBettypeProfile WITH(NOLOCK)
	WHERE	SettleType = 'EAR'
			AND SportType <> 1

	SELECT	@minBettype = MIN(bettype)
			,@maxBettype = MAX(bettype)
	FROM	@tmpEarlyBettypes

	INSERT INTO @tmpEarlyBettypeStatus(MatchId, isExistSingle, isRunningSingle, isWaitingSingle)
	SELECT	m.ParentId
			,MAX(b.isExistSingle)
			,MAX(b.IsRunningSingle)
			,MAX(b.IsWaitingSingle)
	FROM	(
		SELECT TOP(@n) matchid, ParentId FROM #tmpAllParentChildMatch
	)m
		CROSS APPLY (
			SELECT	b.bettype
					,MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) AS IsRunningSingle
					,MAX(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS IsWaitingSingle
					,1 AS isExistSingle
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = m.matchid
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
					AND b.statusID NOT IN(101, 102)
					AND b.bettype BETWEEN @minBettype AND @maxBettype
			GROUP BY b.matchid, b.bettype
			UNION ALL
			SELECT	bm.bettype
					,MAX(CASE WHEN bm.statusID = 0 THEN 1 ELSE 0 END) AS IsRunningSingle
					,MAX(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) AS IsWaitingSingle					
					,1 AS isExistSingle
			FROM	dbo.bettransm bm WITH(NOLOCK)
			WHERE	bm.matchid = m.matchid
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE bm.SiteDBGroupID END
					AND bm.statusID NOT IN (101, 102)
					AND bm.bettype BETWEEN @minBettype AND @maxBettype
			GROUP BY bm.matchid, bm.bettype
		)b
	WHERE	EXISTS (SELECT TOP 1 1 FROM @tmpEarlyBettypes bt WHERE bt.Bettype = b.bettype)
	GROUP BY m.ParentId
	OPTION(OPTIMIZE FOR (@n = 1))

	UPDATE m
		SET  IsExistEarlyBettypes = b.isExistSingle
			,IsRunningEarlyBettypes = b.isRunningSingle
			,IsWaitingEarlyBettypes = b.isWaitingSingle
	FROM	#tmpMatch m 
		INNER JOIN @tmpEarlyBettypeStatus b
			ON m.matchid = b.MatchId

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, m.matchid
	FROM	#tmpAllParentChildMatch m
		CROSS APPLY (
			SELECT	mt.TransId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = m.HasMarkedSingle
		FROM	@tmpMatchMarked mk
			INNER JOIN (
				SELECT	mt.matchId
						,CASE WHEN COUNT(1) > 0 THEN 1 ELSE 0 END AS HasMarkedSingle
				FROM	#tmpMarkedTransaction mt
					CROSS APPLY (
						SELECT	TOP (1) b.transid
								,b.refno
								,b.matchid
								,b.statusID
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	mt.transid = b.transid
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
					) b
					OUTER APPLY (
						SELECT TOP 1 1 IsParlay
						FROM	dbo.bettransm bm WITH(NOLOCK)
						WHERE	bm.refno = b.refno
								AND bm.statusid = 0
								AND b.matchid = 29
								AND bm.matchid = mt.matchId
					)bm
				WHERE	1 = CASE
								WHEN b.matchid <> 29 AND b.statusID = 0 THEN 1
								WHEN b.matchid = 29 AND bm.IsParlay = 1 THEN 1
								ELSE 0
							END
				GROUP BY mt.matchid
			) m
				ON m.matchId = mk.MatchId
		
		UPDATE m 
			SET IsExistMarkedTicket = 1
		FROM	#tmpMatch m
        WHERE EXISTS (SELECT TOP 1 1 
                      FROM #tmpAllParentChildMatch AS p 
                        INNER JOIN @tmpMatchMarked AS mm ON p.matchid = mm.matchid
                      WHERE m.matchid = p.ParentId
						AND mm.IsExistMarkedTicket = 1)
	END
	
	DECLARE @tmpMatchCompleted TABLE (MatchId INT PRIMARY KEY, IsExistRunningTicket BIT DEFAULT (0))
	DECLARE @tmpTransIdRunning TABLE (MatchId INT, TransId BIGINT)

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	DISTINCT m.matchid
	FROM	#tmpMatch AS m
	WHERE	m.eventstatus = 'completed'

	IF @@ROWCOUNT <> 0
	BEGIN
		-- single
		INSERT INTO @tmpTransIdRunning(MatchId, TransId)
		SELECT	tmp.ParentId, b.transid 
 		FROM	#tmpAllParentChildMatch tmp
 			INNER LOOP JOIN dbo.bettrans b WITH (NOLOCK)	
				ON	tmp.MatchId = b.matchid 
		WHERE	tmp.eventstatus = 'completed'
				AND b.statusID = 0
 				AND b.bettype NOT BETWEEN 801 AND 806 -- Metric Gaming
 				AND b.bettype <> 38 -- BetBuilder
 				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END

		IF @@ROWCOUNT <> 0
		BEGIN
			;WITH cteTransIdRunning
			AS (
				SELECT	t.MatchId
				FROM	@tmpTransIdRunning t
					LEFT JOIN #tmpMarkedTransaction mt
						ON mt.transid = t.transid
				WHERE	mt.transid IS NULL
				GROUP BY t.MatchId
			)
			UPDATE m
 				SET IsExistRunningTicket = 1
 			FROM	@tmpMatchCompleted m
				INNER JOIN cteTransIdRunning c
					ON c.MatchId = m.MatchId 					
		END

		-- parlay
		INSERT INTO #temp_match_parlay (ParentID, transid, matchid, refno)
		SELECT	tmp.ParentId, 0, tmp.MatchId, bm.refno
		FROM @tmpMatchCompleted m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.MatchId = bm.matchid
			INNER JOIN #tmpAllParentChildMatch tmp	ON	bm.matchid = tmp.MatchId
		WHERE	bm.statusID = 0
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE bm.SiteDBGroupID END
			AND m.IsExistRunningTicket = 0
		
		IF EXISTS (SELECT TOP 1 1 FROM #temp_match_parlay)
		BEGIN
			UPDATE   t
				SET transid = b.transid
			FROM   #temp_match_parlay  t
				INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
			
			UPDATE m 
				SET IsExistRunningTicket = CASE WHEN m.IsExistRunningTicket = 0 THEN t.IsExistRunningTicketParlay ELSE m.IsExistRunningTicket END
			FROM	@tmpMatchCompleted m
					CROSS APPLY (
								SELECT 1 AS IsExistRunningTicketParlay
								FROM (
										SELECT	ParentId, transid, MatchId
										FROM	#temp_match_parlay p
										WHERE p.matchid = m.MatchId
									) b
									OUTER APPLY (
										SELECT TOP 1 mt.transId
										FROM	#tmpMarkedTransaction mt 
										WHERE	b.transid = mt.TransId
												AND b.MatchId = mt.matchId
									)mt
									WHERE	mt.transId IS NULL
									GROUP BY b.ParentId
								) t
		END
				
		UPDATE m 
		SET IsExistRunningTicketAfterCompleted = t.IsExistRunningTicket
		FROM	#tmpMatch m
			INNER JOIN @tmpMatchCompleted t ON	m.matchid = t.MatchId
	END

	IF EXISTS(SELECT 1 FROM @tmpMatchOverStatus WHERE  OverStatus = 4 )
	BEGIN
		DELETE 
		FROM	#tmpMatch
		WHERE	1 = CASE WHEN ISNULL(IsExistRunningTicketAfterCompleted,0) > 0 THEN 0 ELSE 1 END
			AND eventstatus = 'completed'
	END

	SELECT	 m.matchid
			,m.suspenderhalftime
			,m.suspenderfulltime
			,q.IsCalculatingSingle
			,q.IsCalculatingMP
			,m.IsExistEarlyBettypes
			,m.IsWaitingEarlyBettypes			
			,m.IsExistRunningTicketAfterCompleted AS IsExistRunningTicket
			,m.IsRunningEarlyBettypes
			,m.IsExistMarkedTicket
			,m.IsExistsConfirmedEarly
	FROM	#tmpMatch AS m
		LEFT JOIN @tmpQueueStatus AS q ON	m.matchid = q.MatchId


	DROP TABLE #temp_match_parlay
	DROP TABLE #tmpAllParentChildMatch
	DROP TABLE #tmpMarkedTransaction
	DROP TABLE #tmpMatch
END

GO