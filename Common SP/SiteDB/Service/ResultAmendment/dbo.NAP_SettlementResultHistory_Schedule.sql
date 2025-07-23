/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementResultHistory_Schedule]
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]
		- 20240425@Aries: Fix IsCalculating = 99 [Redmine: #201480]
		- 20241206@Aries: Integration - Result Amendment for Basketball and eSports [Redmine:#209656]

	Param's Explanation:  
		- @WrongResult: '<root><r Id="96801004" Home="20" Away="" RefBettypeID ="9680" G="1" OtherInfo="16776" Action="CAL" LogDate="2023-11-24 03:25:22.243" /></root>'	 
		- @ActualResult: '<root><r Id="96801004" Home="20" Away="" RefBettypeID ="9680" G="1" OtherInfo="16776"/></root>'
*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @tblMatch TABLE(MatchId INT, sportType SMALLINT)
	DECLARE @tblParentMatch TABLE(MatchId INT, ParentId INT)

	DECLARE @DateCheck		DATETIME	= DATEADD(MINUTE,-5 ,GETDATE())

	INSERT INTO @tblMatch(MatchId,sportType)
	SELECT DISTINCT h.matchId,h.sportType
	FROM SettlementResultHistory AS h WITH(NOLOCK)
	WHERE h.StatusID IN (0,1)

	IF EXISTS(SELECT TOP 1 1 FROM @tblMatch WHERE Sporttype = 50)
	BEGIN
		INSERT INTO @tblParentMatch (MatchId, ParentId)
		SELECT m.matchid, m.ParentId
		FROM @tblMatch AS t
			CROSS APPLY (
				SELECT	m.matchid, m.ParentId
				FROM	dbo.match m WITH(NOLOCK)
				WHERE	m.sporttype = 50
						AND m.ChildMatchType = 200
						AND m.ParentID = t.matchid
			) AS m
	END 

	INSERT INTO @tblParentMatch (MatchId, ParentId)
	SELECT m.matchid, m.matchid
	FROM @tblMatch AS m
	
	IF NOT EXISTS(SELECT 1 FROM @tblParentMatch)
	BEGIN
		RETURN
	END

	IF OBJECT_ID('BalanceNegative','U') IS NOT NULL 
	BEGIN
		SELECT	 h.matchid
				,m.leagueid
				,h.SessionID
				,h.sportType
				,h.ActionType
				,h.ActualResult
				,h.StatusID
				,h.CreatedDate
				,h.ExtraInfo
				,CASE WHEN h.StatusID = 0 THEN 1
					  WHEN h.StatusID = 1 AND s.MinCalculating IS NOT NULL AND s.MinCalculating > 1 AND (p.MinCalculating IS NULL OR p.MinCalculating > 1) THEN 1
					  ELSE 0
				 END AS IsCalculated
                ,IIF(b.StatusID IS NULL,1,0) AS IsDoneBalNeg
				,IIF(s.MaxCalculating = 3 OR p.MaxCalculating = 3,1,0) AS HasError
		FROM SettlementResultHistory AS h WITH(NOLOCK)
			LEFT JOIN match AS m WITH(NOLOCK) ON m.matchid = h.matchid
			OUTER APPLY (SELECT TOP 1 MIN(IIF(qs.IsCalculating NOT IN(2,3),0,qs.IsCalculating)) AS  MinCalculating, MAX(IIF(qs.IsCalculating NOT IN(2,3),0,qs.IsCalculating)) AS  MaxCalculating
						 FROM @tblParentMatch AS m
							INNER JOIN Single_Calculate_Queue AS qs WITH(NOLOCK)  ON  qs.matchid = m.matchid 
						 WHERE m.ParentId = h.matchid
							AND qs.BroadcastSessionId = h.SessionID
			) AS s
			OUTER APPLY (SELECT TOP 1 MIN(IIF(qp.IsCalculating NOT IN(2,3),0,qp.IsCalculating)) AS  MinCalculating, MAX(IIF(qp.IsCalculating NOT IN(2,3),0,qp.IsCalculating)) AS  MaxCalculating
						 FROM @tblParentMatch AS m 
							INNER JOIN Parlay_Calculate_Queue AS qp WITH(NOLOCK) ON  qp.matchid = m.matchid 
						 WHERE m.ParentId = h.matchid
							AND qp.BroadcastSessionId = h.SessionID
			) AS p
			OUTER APPLY (SELECT TOP 1 statusid
					 FROM  @tblParentMatch AS m 
						INNER JOIN [dbo].[BalanceNegative] AS b WITH(NOLOCK)  ON  b.matchid = m.matchid 
					 WHERE m.ParentId = h.matchid
						AND b.SessionID = h.SessionID
						AND b.statusid = 0
			) AS b
		WHERE h.StatusID IN (0,1)	
			AND 1 = CASE WHEN h.StatusID = 0 AND b.StatusID IS NULL  THEN 1
						 WHEN h.StatusID = 1 AND s.MinCalculating IS NOT NULL AND s.MinCalculating > 1 AND (p.MinCalculating IS NULL OR p.MinCalculating > 1) AND b.StatusID IS NULL  THEN 1
						 WHEN s.MaxCalculating = 3 OR p.MaxCalculating = 3 THEN 1
						 WHEN h.CreatedDate <= @DateCheck THEN 1
						 ELSE 0
					 END
	END
	ELSE
	BEGIN
		SELECT	 h.matchid
				,m.leagueid
				,h.SessionID
				,h.sportType
				,h.ActionType
				,h.ActualResult
				,h.StatusID
				,h.CreatedDate
				,h.ExtraInfo
				,CASE WHEN h.StatusID = 0 THEN 1
					  WHEN h.StatusID = 1 AND s.MinCalculating IS NOT NULL AND s.MinCalculating > 1 AND (p.MinCalculating IS NULL OR p.MinCalculating > 1) THEN 1
					  ELSE 0
				 END AS IsCalculated
				,1 AS IsDoneBalNeg
				,IIF(s.MaxCalculating = 3 OR p.MaxCalculating = 3,1,0) AS HasError
		FROM SettlementResultHistory AS h WITH(NOLOCK)
			LEFT JOIN match AS m WITH(NOLOCK) ON m.matchid = h.matchid
			OUTER APPLY (SELECT TOP 1 MIN(IIF(qs.IsCalculating NOT IN(2,3),0,qs.IsCalculating)) AS  MinCalculating,  MAX(IIF(qs.IsCalculating NOT IN(2,3),0,qs.IsCalculating))  AS  MaxCalculating
						 FROM @tblParentMatch AS m
							INNER JOIN Single_Calculate_Queue AS qs WITH(NOLOCK)  ON  qs.matchid = m.matchid 
						 WHERE m.ParentId = h.matchid
							AND qs.BroadcastSessionId = h.SessionID
			) AS s
			OUTER APPLY (SELECT TOP 1 MIN(IIF(qp.IsCalculating NOT IN(2,3),0,qp.IsCalculating)) AS  MinCalculating, MAX(IIF(qp.IsCalculating NOT IN(2,3),0,qp.IsCalculating)) AS  MaxCalculating
						 FROM @tblParentMatch AS m 
							INNER JOIN Parlay_Calculate_Queue AS qp WITH(NOLOCK) ON  qp.matchid = m.matchid 
						 WHERE m.ParentId = h.matchid
							AND qp.BroadcastSessionId = h.SessionID
			) AS p
		WHERE h.StatusID IN (0,1)
			AND 1 = CASE WHEN h.StatusID = 0 THEN 1
						 WHEN h.StatusID = 1 AND s.MinCalculating IS NOT NULL AND s.MinCalculating > 1 AND (p.MinCalculating IS NULL OR p.MinCalculating > 1) THEN 1
						 WHEN h.CreatedDate <= @DateCheck THEN 1
						 ELSE 0
					END
	END
END