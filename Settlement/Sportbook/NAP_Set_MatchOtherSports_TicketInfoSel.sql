/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchOtherSports_TicketInfoSel
	 @MatchInfo				VARCHAR(MAX)    = NULL
	,@ChildMatchInfo		VARCHAR(MAX)    = NULL
	,@OverStatus			VARCHAR(MAX)	= '0'
	,@MatchCode				NVARCHAR(50)	= ''
AS
/*  
	 Created by: 20240503@Louisa
	 Task: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]
	 DB: DBTXN/bodb02
	 
	 Revisions:  
			- 20240503@Louisa: Enhance-separate code DBTXN and DBPRO [Redmine:#204370]
			- 20240719@Aries: Filter Over Status = Settle with Running TIcket, Complete match with betbulder running ticket is shown [Redmine:#208511]
			- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100]
			- 20240608@Aries: Filter Over Status Table Tennis - Don't show parent match when child match has no ticket [Redmine:#208972]
			- 20250507@Aries: Enhance the performance for the Multi-sport Page [Redmine:#223959]
			- 20250701@Aries: Fix an issue that a timeout occurred when filtering a large amount of data on the Settlement Site [Redmine:#231940]


	Parameters Explanation: 
		@MatchInfo='[{"m":83541400,"s":9,"cmt":0,"e":"running","cfht":0,"cfft":4635582},{"m":83541402,"s":9,"cmt":0,"e":"running","cfht":0,"cfft":0}]'
		@OverStatus= Multiple select  '1,2,3,4' 
				     0: None
					 1: Early over 
					 	+ Match.EventStatus ＝ any & 
						+ Have at least 1 early-settle result confirmed
						+ Have at least 1  running ticket 
					 2: Main Over
					 	+ Match.EventStatus != Completed
						+ Have at least 1 main result (interval, HT, or FT) confirmed
						+ Have at least 1 ticket of any status.
					 3: Over
					 	+ Match.Event Status != Completed
						+ Have FT result confirmed
						+ Not Table Tennis have Un-confirmed FT result AND @current_time] － @KO_time > 30 minutes
						+ Is Table Tennis have Un-confirmed FT result AND @current_time] － @KO_time > 20 minutes
						+ Have at least 1 ticket of any status.
					 4: Settled with running ticket.
					 	+ Match.EventStatus = 'Completed'
						+ Have at least 1 runnng ticket.
*/
BEGIN
	SET NOCOUNT ON

	DECLARE		 @IsCentral							BIT
				,@IsOverEarly						BIT = 0
				,@IsMainOver						BIT = 0		
				,@IsOver							BIT = 0			
				,@IsCompletedWithRunningTicket		BIT = 0 
				,@SitedbGroupID_Central				SMALLINT = 0

	DECLARE @tmpQueueStatus TABLE (MatchId INT, IsCalculatingSingle TINYINT DEFAULT(0), IsCalculatingMP TINYINT DEFAULT(0))
	CREATE TABLE #tmpMatch(MatchId INT, ParentID INT, SportType SMALLINT, EventStatus NVARCHAR(100), ChildMatchType TINYINT, SuspenderHalfTime NVARCHAR(50), SuspenderFullTime NVARCHAR(50))
	
	DECLARE @__tmpMarkedTransaction TABLE (transId BIGINT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON), matchId INT, refno BIGINT)
	
	CREATE TABLE #tmpAllParentChildMatch (MatchId INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON), ParentId INT, ChildMatchType TINYINT, SportType SMALLINT, eventstatus NVARCHAR(50))
	CREATE INDEX CIX_tmp_ParentId ON #tmpAllParentChildMatch(ParentId)

	CREATE TABLE #tmpMatchCount(matchid INT, ParentId INT, ChildMatchType TINYINT, sporttype SMALLINT, EventStatus NVARCHAR(100), ResourceID VARCHAR(20), SettleType VARCHAR(10), TotalTicket INT,TotalValidTicket INT, TotalRunningTicket INT, TotalWaitingTicket INT, TotalMarkedTicket INT, IsOverFilter BIT DEFAULT(0))


	SET  @IsCentral 	= [dbo].[f_CheckServerCentral]()
	SET	 @IsOverEarly 	= IIF(CHARINDEX(',1,',',' + @OverStatus + ',') > 0, 1, 0)
	SET	 @IsMainOver 	= IIF(CHARINDEX(',2,',',' + @OverStatus + ',') > 0, 1, 0)
	SET	 @IsOver 		= IIF(CHARINDEX(',3,',',' + @OverStatus + ',') > 0, 1, 0)
	SET  @IsCompletedWithRunningTicket = IIF(CHARINDEX(',4,',',' + @OverStatus + ',') > 0, 1, 0)	

	INSERT INTO #tmpMatch(MatchId,ParentID,SportType,ChildMatchType,EventStatus,SuspenderHalfTime,SuspenderFullTime)
	SELECT tbl.m		AS MatchId
		  ,tbl.p		AS ParentID
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
		   ,p		INT
		   ,s		SMALLINT
		   ,cmt	    TINYINT		
		   ,e		NVARCHAR(100)
		   ,cfht	INT		
		   ,cfft	INT
	) AS tbl

	IF ISNULL(@ChildMatchInfo,'') <> ''
	BEGIN
		INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId,SportType, eventstatus)
		SELECT tbl.m AS MatchId ,tbl.p AS ParentId, tbl.s AS SportType, tbl.e AS EventStatus
		FROM OPENJSON(@ChildMatchInfo) WITH (m INT, p INT, s SMALLINT, e NVARCHAR(100)) AS tbl
	END

	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId,ChildMatchType, SportType, eventstatus)
	SELECT DISTINCT m.matchid, m.matchid,  m.ChildMatchType, m.SportType, m.eventstatus 
	FROM #tmpMatch m
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tmpAllParentChildMatch p WHERE p.MatchId = m.matchid)
	
	IF ISNULL(@MatchCode,'')  <> '' ---if search by matchcode, dont care another condition
	BEGIN
		SET @OverStatus = '0'
	END

	INSERT INTO @__tmpMarkedTransaction (transId, matchId, refno)
	SELECT	mt.TransId, m.matchid, IIF(p.matchid = 29,p.refno, 0)
	FROM #tmpAllParentChildMatch m
		INNER LOOP JOIN dbo.MarkedTransaction AS mt WITH(NOLOCK,INDEX(IX_MarkedTransaction_MatchId))  ON m.matchid = mt.MatchId -- INNER LOOP JOIN  &  WITH(NOLOCK,INDEX(IX_MarkedTransaction_MatchId)) 
		OUTER APPLY (
			SELECT TOP 1 refno,matchid
			FROM dbo.bettrans b WITH(NOLOCK,INDEX(PK_bettrans)) --WITH(NOLOCK,INDEX(PK_bettrans))
			WHERE b.transid = mt.transid
		) AS p
    OPTION (FORCE ORDER)

	INSERT INTO @__tmpMarkedTransaction (transId, matchId, refno)
	SELECT  bm.TransId,mt.MatchId,mt.RefNo
	FROM @__tmpMarkedTransaction AS mt
		INNER JOIN bettransm AS bm WITH(NOLOCK,INDEX(IX_refno)) ON mt.refno = bm.refno AND mt.matchid = bm.matchid --WITH(NOLOCK,INDEX(IX_refno))
	WHERE mt.refno > 0

	INSERT INTO #tmpMatchCount(matchid, ParentId, ChildMatchType, eventstatus,sporttype, ResourceID, settleType, TotalTicket, TotalValidTicket, TotalRunningTicket, TotalWaitingTicket, TotalMarkedTicket)
	SELECT m.matchid
		  ,m.ParentId
		  ,m.ChildMatchType
		  ,m.eventstatus
		  ,m.sporttype
	 	  ,sp.ResourceID
		  ,sp.SettleType
		  ,COUNT(1) AS TotalTicket
		  ,SUM(IIF(b.statusID NOT IN (101, 102), 1, 0)) AS TotalValidTicket
		  ,SUM(IIF(b.statusid = 0, 1, 0)) AS TotalRunningTicket
		  ,SUM(IIF(b.statusid = 1, 1, 0)) AS TotalWaitingTicket
		  ,SUM(IIF(mt.TransId IS NOT NULL AND b.statusid = 0, 1, 0)) AS TotalMarkedTicket
	FROM #tmpAllParentChildMatch AS m 
		INNER JOIN bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype), FORCESEEK) ON m.matchid = b.matchid --WITH(NOLOCK,INDEX(CIX_matchid_bettype))
		INNER JOIN SettlementSpecialBettypeProfile AS sp  WITH(NOLOCK) ON  sp.Sporttype = m.SportType AND sp.bettype =  b.bettype AND (sp.BetID = 0 OR b.BetID = sp.BetID) 
		LEFT JOIN @__tmpMarkedTransaction AS mt ON mt.TransId = b.transid
	WHERE b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN @SitedbGroupID_Central ELSE b.SiteDBGroupID END
	GROUP BY m.matchid,m.eventstatus, sp.ResourceID, sp.SettleType,m.ParentId,m.ChildMatchType,m.sporttype

	INSERT INTO #tmpMatchCount(matchid, ParentId, ChildMatchType, eventstatus,sporttype, ResourceID, settleType, TotalTicket, TotalValidTicket, TotalRunningTicket, TotalWaitingTicket, TotalMarkedTicket)
	SELECT m.matchid
		  ,m.ParentId
		  ,m.ChildMatchType
		  ,m.eventstatus
		  ,m.sporttype
	 	  ,sp.ResourceID
		  ,sp.SettleType
		  ,COUNT(1) AS TotalTicket
		  ,SUM(IIF(bm.statusID NOT IN (101, 102), 1, 0))  AS TotalValidTicket
		  ,SUM(IIF(bm.statusid = 0, 1, 0)) AS TotalRunningTicket
		  ,SUM(IIF(bm.statusid = 1, 1, 0)) AS TotalWaitingTicket
		  ,SUM(IIF(mt.TransId IS NOT NULL AND bm.statusid = 0, 1, 0)) AS TotalMarkedTicket
	FROM #tmpAllParentChildMatch AS m 
		INNER LOOP JOIN bettransm AS bm WITH(NOLOCK, FORCESEEK) ON m.matchid = bm.matchid -- WITH(NOLOCK,INDEX(IX_matchid))
		INNER JOIN SettlementSpecialBettypeProfile AS sp  WITH(NOLOCK) ON  sp.Sporttype = m.SportType AND sp.bettype =  bm.bettype AND (sp.BetID = 0 OR bm.betcheck = CAST(sp.BetID AS NVARCHAR(50))) 
		LEFT JOIN @__tmpMarkedTransaction AS mt ON mt.TransId = bm.transid
	WHERE bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN @SitedbGroupID_Central ELSE bm.SiteDBGroupID END
	GROUP BY m.matchid,m.eventstatus, sp.ResourceID, sp.SettleType,m.ParentId,m.ChildMatchType,m.sporttype

	IF @OverStatus != '0'
	BEGIN
		UPDATE #tmpMatchCount
		SET IsOverFilter = 1
		WHERE 1 = CASE WHEN @IsOverEarly = 1 AND SettleType = 'EAR' 			AND TotalRunningTicket > 0 	THEN 1 
					   WHEN @IsMainOver = 1  AND eventstatus != 'Completed' 	AND TotalTicket > 0			THEN 1 
					   WHEN @IsOver = 1 	 AND eventstatus != 'Completed' 	AND TotalTicket > 0			THEN 1 
					   WHEN @IsCompletedWithRunningTicket = 1 AND SettleType != 'BBD'  AND eventstatus = 'Completed' AND TotalRunningTicket > 0 THEN 1 
					   ELSE 0
				   END

		UPDATE m
		SET IsOverFilter = 1
		FROM #tmpMatchCount AS m
		WHERE m.sporttype = 18 
			AND m.ParentID = 0
			AND m.IsOverFilter = 0
			AND EXISTS (
				SELECT 1
				FROM #tmpMatchCount AS mc
				WHERE mc.ParentID = m.Matchid
					AND mc.IsOverFilter = 1
					AND mc.ChildMatchType IN (11, 12, 14, 15, 16, 17, 18, 19)
			)

		DELETE m
		FROM #tmpMatch AS m
		WHERE NOT EXISTS(SELECT mc.matchid 
						 FROM #tmpMatchCount AS mc 
						 WHERE mc.matchid =  m.matchid   
						 	AND  mc.IsOverFilter = 1)
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
	
	SELECT  m.matchid
		   ,m.ParentId
		   ,m.ChildMatchType
		   ,m.sporttype
		   ,m.ResourceID
		   ,m.IsOverFilter
		   ,IIF(m.settleType = 'EAR', 1, 0) AS IsEarly
		   ,SUM(IIF(settleType = 'EAR', TotalTicket, 0)) AS TotalEarlyTicket
	       ,SUM(IIF(settleType = 'EAR', TotalRunningTicket, 0)) AS TotalEarlyRunningTicket
		   ,SUM(TotalRunningTicket) AS TotalRunningTicket
	FROM #tmpMatchCount AS m
	GROUP BY m.matchid,m.ResourceID, m.IsOverFilter,m.ParentId,m.ChildMatchType,IIF(m.settleType = 'EAR', 1, 0) ,m.sporttype
	HAVING SUM(TotalRunningTicket) > 0
		OR SUM(IIF(settleType = 'EAR', TotalRunningTicket, 0)) > 0
		OR SUM(IIF(settleType = 'EAR', TotalTicket, 0)) > 0

	;WITH CTE_MatchCount
	AS(
		SELECT SUM(IIF(mc.settleType = 'EAR', mc.TotalValidTicket, 0)) AS TotalEarlyTicket
	      	  ,SUM(IIF(mc.settleType = 'EAR', mc.TotalRunningTicket, 0)) AS TotalEarlyRunningTicket
		      ,SUM(IIF(mc.settleType = 'EAR', mc.TotalWaitingTicket, 0)) AS TotalWaitingEarlyTicket
			  ,SUM(IIF(mc.eventstatus = 'Completed', mc.TotalRunningTicket, 0)) AS TotalRunningTicketAfterCompleted
		      ,SUM(IIF(mc.settleType != 'BBD', mc.TotalRunningTicket, 0) ) AS TotalRunningTicket
		      ,SUM(mc.TotalMarkedTicket) AS TotalMarkedTicket
			  ,mc.matchid
		FROM #tmpMatchCount AS mc
		GROUP BY mc.matchid
	)
	SELECT	 m.matchid
			,m.suspenderhalftime
			,m.suspenderfulltime
			,q.IsCalculatingSingle
			,q.IsCalculatingMP
			,IIF(cte.TotalEarlyTicket > 0, 1, 0) AS IsExistEarlyBettypes
			,IIF(cte.TotalWaitingEarlyTicket > 0, 1, 0) AS IsWaitingEarlyBettypes			
			,IIF(cte.TotalRunningTicket > 0, 1, 0) AS IsExistRunningTicket
			,IIF(cte.TotalEarlyRunningTicket > 0, 1, 0) AS IsRunningEarlyBettypes
			,IIF(cte.TotalMarkedTicket > 0, 1, 0) AS IsExistMarkedTicket
	FROM #tmpMatch AS m
		LEFT JOIN CTE_MatchCount AS cte ON	cte.matchid = m.MatchId
		LEFT JOIN @tmpQueueStatus AS q ON	q.matchid = m.MatchId


	DROP TABLE #tmpMatch
    DROP TABLE #tmpMatchCount
END


GO