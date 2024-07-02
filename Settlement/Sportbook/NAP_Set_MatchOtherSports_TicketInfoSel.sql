/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchOtherSports_TicketInfoSel
	 @MatchInfo				VARCHAR(MAX)    = NULL
	,@ChildMatchInfo		VARCHAR(MAX)    = NULL
	,@MatchOverStatus		VARCHAR(MAX)	= NULL
	,@OverStatus			VARCHAR(MAX)	= '0'
	,@MatchCode				NVARCHAR(50)	= ''
AS
/*  
	 Created by: 20240503@Louisa
	 Task: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]
	 DB: DBTXN/bodb02
	 
	 Revisions:  
			- 20240503@Louisa: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]

	Parameters Explanation: 
		@MatchInfo='[{"m":83541400,"s":9,"cmt":0,"e":"running","cfht":0,"cfft":4635582},{"m":83541402,"s":9,"cmt":0,"e":"running","cfht":0,"cfft":0}]'
		@MatchOverStatus='[{"m":83541402,"r":"0101","o":1}]'
*/
BEGIN
	SET NOCOUNT ON
	DECLARE		 @IsCentral							BIT
				,@n									INT 
				,@minBettype						SMALLINT
				,@maxBettype						SMALLINT

	DECLARE @tmpMatchOverStatus TABLE(MatchId INT, sporttype SMALLINT, ResourceID VARCHAR(20), OverStatus INT DEFAULT(0) )
	DECLARE @tmpSettlementtProfile  TABLE(MatchId INT, bettype INT, betid BIGINT, OverStatus INT )
	DECLARE @tmpEarlyBettypes TABLE (Bettype SMALLINT PRIMARY KEY)
	DECLARE @tmpEarlyBettypeStatus TABLE(MatchId INT,bettype SMALLINT,isExistSingle BIT DEFAULT(0),isRunningSingle	BIT DEFAULT(0),isWaitingSingle	BIT DEFAULT(0))	
	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsDisplay BIT DEFAULT(0),PRIMARY KEY (MatchId) )
	DECLARE @tmpQueueStatus TABLE (MatchId INT, IsCalculatingSingle TINYINT DEFAULT(0), IsCalculatingMP TINYINT DEFAULT(0))
	CREATE TABLE #tmpMatch
	(
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
	CREATE TABLE #tmpAllParentChildMatch (MatchId INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON), ParentId INT, eventstatus NVARCHAR(50))
	CREATE INDEX CIX_tmp_ParentId ON #tmpAllParentChildMatch(ParentId)

	DECLARE @CheckingDisplay TABLE (matchid INT, IsEarly BIT)

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
		   ,cfft	INT
	) AS tbl

	IF ISNULL(@ChildMatchInfo,'') <> ''
	BEGIN
		INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, eventstatus)
		SELECT tbl.m		AS MatchId
			  ,tbl.p		AS ParentId	
			  ,tbl.e		AS EventStatus
		FROM OPENJSON(@ChildMatchInfo) WITH (
				m		INT
			   ,p		INT	
			   ,e		NVARCHAR(100)
		) AS tbl
	END



	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, eventstatus)
	SELECT DISTINCT m.matchid, m.matchid,  m.eventstatus 
	FROM #tmpMatch m
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tmpAllParentChildMatch p WHERE p.MatchId = m.matchid)
	
	/***********************Filter by OverStatus******************************/

	IF ISNULL(@MatchOverStatus,'') <> ''
	BEGIN
		INSERT INTO @tmpMatchOverStatus (matchid,  ResourceID, OverStatus)
		SELECT tbl.m AS matchid,  tbl.r AS r, tbl.o AS o
		FROM OPENJSON(@MatchOverStatus) WITH (
				m		INT
			   ,r		VARCHAR(20)
			   ,o		INT
		) AS tbl

		INSERT INTO @tmpSettlementtProfile (MatchId, bettype, betid , Overstatus)
		SELECT o.MatchId, sp.bettype, sp.BetID, o.OverStatus 
		FROM @tmpMatchOverStatus o
			OUTER APPLY ( SELECT bettype, betid  
							FROM settlementSpecialBettypeProfile sp 
							WHERE o.ResourceID = sp.ResourceID
								AND sp.SettleType = 'EAR'
								AND o.OverStatus  = 1
						) sp  
	END

	IF ISNULL(@MatchCode,'')  <> '' ---if search by matchcode, dont care another condition
	SET @OverStatus = '0'

	IF ISNULL(@MatchOverStatus,'') <> '' AND @OverStatus <> '0'
	BEGIN
		INSERT INTO @CheckingDisplay ( matchid, IsEarly)
		SELECT DISTINCT m.matchid, IsEarly
		FROM @tmpSettlementtProfile m	
		CROSS APPLY (	SELECT TOP 1 b.matchid, CASE WHEN m.OverStatus = 1 THEN 1 ELSE 0 END AS IsEarly
						FROM bettrans b WITH (nolock)
						WHERE m.matchid = b.matchid
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
							AND 1 = CASE 	WHEN OverStatus = 1 AND b.bettype = m.bettype AND (b.betid = 0 OR b.betid = m.betid ) THEN 1
											WHEN m.OverStatus = 2 OR OverStatus = 3 THEN 1
											WHEN OverStatus = 4 AND b.statusId = 0 THEN 1
									ELSE 0
									END
						) AS tmp

		DELETE FROM @tmpSettlementtProfile WHERE MatchId IN ( SELECT MatchId FROM @CheckingDisplay)
		
		INSERT INTO @CheckingDisplay ( matchid, IsEarly)
		SELECT DISTINCT m.matchid, IsEarly
		FROM @tmpSettlementtProfile m	
		CROSS APPLY (	SELECT TOP 1 b.matchid
									, CASE WHEN m.OverStatus = 1 THEN 1 ELSE 0 END AS IsEarly
						FROM bettransm b WITH (nolock)
						WHERE m.matchid = b.matchid
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN CAST(0 AS SMALLINT) ELSE b.SiteDBGroupID END
							AND 1 = CASE	WHEN m.OverStatus = 1 AND b.bettype = m.bettype AND (b.betcheck = 0 OR b.betcheck = m.betid ) THEN 1
											WHEN m.OverStatus = 2 OR OverStatus = 3  THEN 1
											WHEN m.OverStatus = 4 AND b.statusId = 0 THEN 1
									ELSE 0
									END
						) AS tmp

		DELETE FROM #tmpMatch WHERE matchid NOT IN (SELECT DISTINCT matchid FROM @CheckingDisplay)

		UPDATE #tmpMatch  SET IsExistsConfirmedEarly = 1 WHERE matchid IN (SELECT DISTINCT matchid FROM @CheckingDisplay WHERE IsEarly = 1)

	END

	IF @OverStatus = '0' OR EXISTS (SELECT TOP 1 1 FROM @tmpMatchOverStatus WHERE OverStatus = 1)
	BEGIN
		UPDATE tmp
		SET IsExistsConfirmedEarly = 1 
		FROM  #tmpMatch tmp
		INNER JOIN @tmpSettlementtProfile m	ON tmp.MatchId = m.MatchId
		CROSS APPLY (	SELECT TOP 1 1 AS IsEarly
						FROM bettrans b WITH (NOLOCK)
						WHERE b.bettype = m.bettype AND (b.betid = 0 OR b.betid = m.betid)
						) AS b
		WHERE IsExistsConfirmedEarly = 0

		UPDATE tmp
		SET IsExistsConfirmedEarly = 1 
		FROM  #tmpMatch tmp
		INNER JOIN @tmpSettlementtProfile m	ON tmp.MatchId = m.MatchId
		CROSS APPLY (	SELECT TOP 1 1 AS IsEarly
						FROM bettransm b WITH (NOLOCK)
						WHERE b.bettype = m.bettype AND (b.betcheck = 0 OR b.betcheck = m.betid)
						) AS b
		WHERE IsExistsConfirmedEarly = 0
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