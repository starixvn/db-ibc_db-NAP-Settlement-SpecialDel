/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayoutStatus_Sel] 
	@MatchIds	VARCHAR(MAX)
AS
/*
	Created: 20231229@Aries
	Task: Enhancement of Auto Settlement [Redmine:#199004]
	DB: DBPRO/bodb02
	
	Revision:
		- 20231229@Aries: Enhancement of Auto Settlement [Redmine:#199004]
		- 20240308@Aries: Direct Ice Hockey [Redmine:#201836]
		- 20250507@Aries: Enhance the performance for the Multi-sport Page [Redmine:#223959]
	Param's explanation:  
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpMatch (MatchId INT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON), Sporttype INT,eventstatus	NVARCHAR(100), ResultTable TINYINT,AutoPayoutStatus SMALLINT, HasAutoPayoutFail BIT, InstantStatus SMALLINT, HasInstantFail BIT)
	CREATE TABLE #tmpMatchResource (MatchId  INT,ResourceID	VARCHAR(20))

	INSERT INTO #tmpMatch(MatchId,Sporttype,eventstatus,ResultTable)
	SELECT m.MatchId
		  ,m.Sporttype
		  ,m.eventstatus
		  ,t.ResultTable
	FROM STRING_SPLIT(@MatchIds, ',') AS f
		INNER JOIN dbo.match AS m WITH (NOLOCK)  ON f.[value] = m.MatchId
		INNER JOIN SettlementResultTableSetting AS t WITH(NOLOCK) ON t.Sporttype = m.Sporttype

	IF EXISTS(SELECT TOP 1 1 FROM  #tmpMatch WHERE Sporttype = 1)
	BEGIN

		INSERT INTO #tmpMatchResource(MatchId,ResourceID)
		SELECT a.matchid,IIF(a.CalculationType = 1, '01', '00')
		FROM  #tmpMatch AS m
			INNER JOIN dbo.AutoPayoutResult AS a WITH(NOLOCK) ON m.matchid = a.matchid
			LEFT JOIN dbo.ResultDetail AS r WITH(NOLOCK) ON a.matchid = r.matchid 
															 AND r.ResultStatusID IN (2,5)
															 AND ((a.CalculationType = 1 AND r.ResourceID = '01') OR (a.CalculationType = 2 AND r.ResourceID = '00'))
		WHERE a.matchid = m.matchid 
			AND a.StatusId = 3
			AND a.CalculationType IN (1,2)
			AND r.ResultStatusID IS NULL

		UPDATE  m
		SET  m.AutoPayoutStatus = ap.StatusId
		FROM #tmpMatch AS m
			OUTER APPLY (
				SELECT TOP 1 StatusId
				FROM dbo.AutoPayoutResult AS a WITH(NOLOCK) 
				WHERE m.matchid = a.matchid 
					AND a.CalculationType IN (1,2)
					AND a.StatusId != 3
			) AS ap
		WHERE	m.Sporttype = 1 
			
		UPDATE  m
		SET  m.HasInstantFail = 1
			,m.InstantStatus = ap.StatusId
		FROM #tmpMatch AS m
			OUTER APPLY (
				SELECT TOP 1 StatusId
				FROM dbo.AutoPayoutResult AS a WITH(NOLOCK) 
				WHERE m.matchid = a.matchid 
					AND a.CalculationType IN (101,102)
					AND a.StatusId != 3
			) AS ap
		WHERE	m.Sporttype = 1 AND
				EXISTS(SELECT TOP 1 1 
					   FROM dbo.AutoPayoutResult AS a WITH(NOLOCK)  
							LEFT JOIN dbo.ResultDetail AS r WITH(NOLOCK) ON a.matchid = r.matchid 
																		AND r.ResultStatusID IN (2,5)
																		AND ((a.CalculationType = 101 AND r.ResourceID = '01') OR (a.CalculationType = 102 AND r.ResourceID = '00'))
					   WHERE a.matchid = m.matchid 
							AND a.StatusId IN (2,3)
							AND a.CalculationType IN (101,102)
							AND r.ResultStatusID IS NULL
					   GROUP BY a.CalculationType
					   HAVING MAX(IIF(a.StatusId = 3, a.ModifiedDate, '2000-01-01')) > MAX(IIF(a.StatusId = 2, a.ModifiedDate, '2000-01-01'))
				)
	END

	IF EXISTS(SELECT TOP 1 1 FROM  #tmpMatch WHERE Sporttype != 1)
	BEGIN 
		UPDATE  m
		SET  m.AutoPayoutStatus = ap.StatusId
		FROM #tmpMatch AS m
			OUTER APPLY (
				SELECT TOP 1 StatusId
				FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK) 
				WHERE m.matchid = a.matchid 
					AND ISNULL(a.SourceID,0) = 0
					AND a.StatusId != 3
			) AS ap
		WHERE m.Sporttype != 1 

		UPDATE  m
		SET  m.InstantStatus = ap.StatusId
		FROM #tmpMatch AS m
			OUTER APPLY (
				SELECT TOP 1 StatusId
				FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK) 
				WHERE m.matchid = a.matchid 
					AND a.SourceID = 98
					AND a.StatusId != 3
			) AS ap
		WHERE m.Sporttype != 1 
	END

	IF EXISTS(SELECT TOP 1 1 FROM  #tmpMatch WHERE Sporttype != 1 AND ResultTable = 0)
	BEGIN
		INSERT INTO #tmpMatchResource(MatchId,ResourceID)
		SELECT m.matchid, '00'
		FROM #tmpMatch AS m
		WHERE	m.Sporttype != 1 AND  m.ResultTable = 0  AND m.eventstatus != 'completed' AND
			 EXISTS(SELECT TOP 1 1 
					 FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)  
					 WHERE a.matchid = m.matchid 
						AND a.StatusId = 3
						AND ISNULL(a.SourceID,0) = 0
						AND a.ResourceID  = '00'
				)
	END

	IF EXISTS(SELECT TOP 1 1 FROM  #tmpMatch WHERE Sporttype != 1 AND ResultTable = 1)
	BEGIN
		INSERT INTO #tmpMatchResource(MatchId,ResourceID)
		SELECT m.matchid, r.ResourceID
		FROM #tmpMatch AS m
			CROSS APPLY (SELECT a.ResourceID
						 FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)  
							LEFT JOIN dbo.ResultDetail AS r WITH(NOLOCK) ON a.matchid = r.matchid AND r.ResourceID = a.ResourceID AND r.ResultStatusID IN (2,5)
						 WHERE a.matchid = m.matchid 
							AND a.StatusId = 3
							AND ISNULL(a.SourceID,0) = 0
							AND r.ResultStatusID IS NULL
						) AS r	
		WHERE	m.Sporttype != 1 AND  m.ResultTable = 1  

		UPDATE  m
		SET  m.HasInstantFail = 1
		FROM #tmpMatch AS m
		WHERE	m.Sporttype != 1 AND  m.ResultTable = 1 AND 
			  EXISTS (SELECT TOP 1 1 
					  FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)  
						LEFT JOIN dbo.ResultDetail AS r WITH(NOLOCK) ON a.matchid = r.matchid AND r.ResourceID = a.ResourceID AND r.ResultStatusID IN (2,5)				
					  WHERE a.matchid = m.matchid 
						AND a.StatusId IN (2,3)
						AND a.SourceID = 98
						AND r.ResultStatusID IS NULL	
					  GROUP BY a.ResourceID
					  HAVING MAX(IIF(a.StatusId = 3, a.ModifiedDate, '2000-01-01')) > MAX(IIF(a.StatusId = 2, a.ModifiedDate, '2000-01-01')) -- no other instant has been executed successfully afterward.
					) 
	END

	IF EXISTS(SELECT TOP 1 1 FROM  #tmpMatch WHERE Sporttype != 1 AND ResultTable = 2)
	BEGIN
		INSERT INTO #tmpMatchResource(MatchId,ResourceID)
		SELECT m.matchid, r.ResourceID
		FROM #tmpMatch AS m
			CROSS APPLY (SELECT a.ResourceID
						 FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)  
							LEFT JOIN dbo.ResultDetailOS AS r WITH(NOLOCK) ON a.matchid = r.matchid AND r.ResourceID = a.ResourceID AND r.ResultStatusID IN (2,5)
						 WHERE a.matchid = m.matchid 
							AND a.StatusId = 3
							AND ISNULL(a.SourceID,0) = 0
							AND r.ResultStatusID IS NULL
						) AS r	
		WHERE	m.Sporttype != 1 AND  m.ResultTable = 2 

		UPDATE  m
		SET  m.HasInstantFail = 1
		FROM #tmpMatch AS m
		WHERE	m.Sporttype != 1 AND m. ResultTable = 2 AND 
			  EXISTS (SELECT TOP 1 1 
					  FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)  
						LEFT JOIN dbo.ResultDetailOS AS r WITH(NOLOCK) ON a.matchid = r.matchid AND r.ResourceID = a.ResourceID AND r.ResultStatusID IN (2,5)
					  WHERE a.matchid = m.matchid 
						AND a.StatusId IN (2,3)
						AND a.SourceID = 98
						AND r.ResultStatusID IS NULL			
					  GROUP BY a.ResourceID
					  HAVING MAX(IIF(a.StatusId = 3, a.ModifiedDate, '2000-01-01')) > MAX(IIF(a.StatusId = 2, a.ModifiedDate, '2000-01-01')) -- no other instant has been executed successfully afterward.
					) 
	END

	IF EXISTS(SELECT TOP 1 1 FROM  #tmpMatch WHERE Sporttype != 1 AND ResultTable = 3)
	BEGIN
		INSERT INTO #tmpMatchResource(MatchId,ResourceID)
		SELECT m.matchid, r.ResourceID
		FROM #tmpMatch AS m
			CROSS APPLY (SELECT a.ResourceID
						 FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)  
							LEFT JOIN dbo.ResultDetailES AS r WITH(NOLOCK) ON a.matchid = r.matchid AND r.ResourceID = a.ResourceID AND r.ResultStatusID IN (2,5)
						 WHERE a.matchid = m.matchid 
							AND a.StatusId = 3
							AND ISNULL(a.SourceID,0) = 0
							AND r.ResultStatusID IS NULL
						) AS r	
		WHERE	m.Sporttype != 1 AND  m.ResultTable = 3 

		UPDATE  m
		SET  m.HasInstantFail = 1
		FROM #tmpMatch AS m
		WHERE	m.Sporttype != 1 AND  m.ResultTable = 3 AND 
			  EXISTS (SELECT TOP 1 1 
					  FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)  
						LEFT JOIN dbo.ResultDetailES AS r WITH(NOLOCK) ON a.matchid = r.matchid AND r.ResourceID = a.ResourceID AND r.ResultStatusID IN (2,5)
					  WHERE a.matchid = m.matchid 
						AND a.StatusId IN (2,3)
						AND a.SourceID = 98
						AND r.ResultStatusID IS NULL				
					  GROUP BY a.ResourceID
					  HAVING MAX(IIF(a.StatusId = 3, a.ModifiedDate, '2000-01-01')) > MAX(IIF(a.StatusId = 2, a.ModifiedDate, '2000-01-01')) -- no other instant has been executed successfully afterward.
				) 
	END

	UPDATE  m
	SET  m.HasAutoPayoutFail = 1
	FROM #tmpMatch AS m
	WHERE	m.MatchId IN (SELECT mr.MatchId FROM #tmpMatchResource AS mr)

	SELECT MatchId
		  ,Sporttype
		  ,AutoPayoutStatus
		  ,HasAutoPayoutFail
		  ,InstantStatus
		  ,HasInstantFail 
	FROM #tmpMatch

	SELECT MatchId, ResourceID
	FROM #tmpMatchResource
END
GO