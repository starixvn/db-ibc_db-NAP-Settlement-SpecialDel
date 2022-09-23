/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_MP_Ticket
(
	 @matchids		VARCHAR(4000) = ''
	,@Action		VARCHAR(10)
	,@ErrCode		INT		= 0				OUTPUT
	,@ErrMsg		NVARCHAR(500)  = ''		OUTPUT
	,@MatchIdsValid VARCHAR(500) = ''		OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before call SP MP_Push  [Redmine:#175251]

	Param's Explanation:
		@Action:  CAL, UNDO
*/

BEGIN
SET NOCOUNT ON

	DECLARE  @NotKeyScoreList VARCHAR(130) = ''
			,@NotAllowCalculating VARCHAR(200)
			,@HaveWaitingTicket	VARCHAR(200) 
			,@matchcode			NVARCHAR(50)
			,@MovingMatchIds	VARCHAR(MAX) 
			,@InvalidMatchIds	VARCHAR(MAX) = ''
				
	CREATE TABLE #tblValidMatch (matchid INT, matchcode NVARCHAR(50) ,fth SMALLINT ,fta SMALLINT ,hth SMALLINT ,hta SMALLINT ,sporttype SMALLINT ,ParentId INT )
	CREATE TABLE #tblInValidMatch (matchid INT	,matchcode NVARCHAR(50) )
	CREATE TABLE #ResultDetailOS (MatchId INT, ResourceId VARCHAR(20), ResultStatusId TINYINT, SettlementStatusId TINYINT)
	DECLARE @tblResultRunning TABLE (matchid INT, ResourceId NVARCHAR(50), OrdNo SMALLINT)

	SET @MatchIdsValid = ''

	INSERT INTO #tblValidMatch ( matchid, matchcode, fth, fta, hth, hta, sporttype, ParentId)
	SELECT matchid
			,matchcode
			,finalhomescore
			,finalawayscore
			,hthomescore
			,htawayscore
			,sporttype
			,CASE WHEN ISNULL(ChildMatchType,0) = 200 AND m.ParentId IS NOT NULL AND m.sporttype = 50 THEN m.ParentId ELSE m.MatchId END ParentId
	FROM dbo.Match m WITH (NOLOCK)
			INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , ',')) tm
				ON m.matchid = tm.value

	IF EXISTS (SELECT TOP(1) 1 FROM #tblValidMatch m WHERE m.sporttype = 50 )
	BEGIN
		INSERT INTO #ResultDetailOS (MatchId, ResourceId, ResultStatusId, SettlementStatusId)
		SELECT r.MatchId, ResourceId, ResultStatusId, SettlementStatusId
		FROM DBPRO.bodb02.dbo.ResultDetailOS r WITH (NOLOCK)
			INNER JOIN  #tblValidMatch tm
				ON r.matchid = tm.ParentId

		;WITH cteBetstatus
			AS(
				SELECT	bm.matchid
						,m.ParentId
						,bm.bettype
						,bm.betcheck
						,m.sporttype
				FROM	#tblValidMatch m
					INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.matchid = bm.matchid
				WHERE bm.statusID = 0
				GROUP BY bm.matchid, bm.bettype, bm.betcheck,m.sporttype, m.ParentId
			)
			,cteResourceID
			AS(
				SELECT c.sporttype
						,c.matchid
						,c.ParentId
						,CASE 
							WHEN f.RefResourceId IS NOT NULL THEN f.RefResourceId
							ELSE f.ResourceID 
						END AS ResourceID
						,f.SettleType
						,MAX(f.OrdNo) AS OrdNo
				FROM	cteBetstatus c
					INNER JOIN	dbo.SettlementSpecialBettypeProfile f WITH(NOLOCK) ON f.sporttype = c.sporttype AND c.bettype = f.BetType
				WHERE (f.Betid = 0 OR CAST(f.Betid AS NVARCHAR(50)) = c.Betcheck)
				GROUP BY c.sporttype, c.matchid, c.ParentId
						,CASE 
							WHEN f.RefResourceId IS NOT NULL THEN f.RefResourceId
							ELSE f.ResourceID 
						END
						,f.SettleType
			)
			INSERT INTO @tblResultRunning (matchid, ResourceId, OrdNo)
			SELECT	c.matchid, COALESCE(sd.RoundName, 'Early Settle'), MAX(c.OrdNo)
			FROM	cteResourceID c
				CROSS APPLY( SELECT ResultStatusID
	  				FROM #ResultDetailOS rd WITH (NOLOCK) 
	  				WHERE rd.ResourceID = c.ResourceID
	  					AND rd.matchid = c.ParentId
	  			) AS rs
				OUTER APPLY
				(
					SELECT RoundName FROM dbo.f_Set_MajorRound(c.sporttype)
					WHERE c.ResourceID = ResourceID
				) sd 
			WHERE ISNULL(rs.ResultStatusId,0) NOT IN ( 2, 5 )
			GROUP BY c.matchid, sd.RoundName
	END
	
	IF EXISTS ( SELECT 1
				FROM #tblValidMatch
				WHERE  MatchId = ParentId AND (fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL) ) AND @action <> 'UNDO'
					OR EXISTS (SELECT TOP 1 1 FROM @tblResultRunning	)					
	BEGIN
		
		SELECT @NotKeyScoreList = @NotKeyScoreList + matchcode + ','									
		FROM #tblValidMatch
		WHERE fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL
			
		-- exclude matches were not keyscore yet
		DELETE
		FROM #tblValidMatch
		OUTPUT deleted.matchid, deleted.matchcode
		INTO #tblInValidMatch
		WHERE (MatchId = ParentId AND (fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL))
			
		SELECT @NotKeyScoreList = @NotKeyScoreList 
								+ m.matchcode +  '(' + STUFF((SELECT ',' + ResourceId 
												FROM @tblResultRunning 
												WHERE m.matchid = matchid 
												ORDER BY OrdNo
												FOR XML PATH('')),1,1,'') + ')' 
								+ ',' 					
		FROM #tblValidMatch m
			INNER JOIN @tblResultRunning t
				ON	m.matchid = t.matchid		
		GROUP BY m.matchid, m.matchcode
		
		IF RIGHT(@NotKeyScoreList,1) = ','
			SET @NotKeyScoreList = LEFT(@NotKeyScoreList,LEN(@NotKeyScoreList)-1)
			
		DELETE m
		OUTPUT deleted.matchid, deleted.matchcode
		INTO #tblInValidMatch
		FROM #tblValidMatch m
		WHERE EXISTS (SELECT TOP 1 1 FROM @tblResultRunning WHERE matchid = m.matchid)
		
	END

	IF EXISTS (SELECT 1
			FROM #tblValidMatch
			WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1))
			OR matchid IN (SELECT matchid from Parlay_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1)) )
	BEGIN
		SELECT @NotAllowCalculating = COALESCE(@NotAllowCalculating + ',' + matchcode, matchcode)
		FROM #tblValidMatch 
		WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
		OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 

		-- exclude matches were not allow to calculate
		DELETE
		FROM #tblValidMatch
		OUTPUT deleted.matchid, deleted.matchcode
		INTO #tblInValidMatch
		WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
		OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 
	END

	-- check movebet day MP
	EXEC dbo.NAP_Admin_Settlement_CheckingMoveBetDay
		@MatchIds =  @matchids 
		,@MovingMatchIds = @InvalidMatchIds OUTPUT
	
	SELECT	@MovingMatchIds = COALESCE(@MovingMatchIds + ',' + m.matchcode, m.matchcode)
	FROM	dbo.match m WITH(NOLOCK)
				INNER JOIN (SELECT [value] FROM STRING_SPLIT(@InvalidMatchIds, ',')) tm
					ON m.matchid = tm.value 
	
	DELETE FROM #tblValidMatch
	OUTPUT deleted.matchid, deleted.matchcode
	INTO #tblInValidMatch
	WHERE	matchid IN (SELECT [value] FROM STRING_SPLIT(@InvalidMatchIds, ','))

	-- check waiting ticket
	EXEC [NAP_Admin_Settlement_Checking] 		
		@MatchIds = @MatchIds	OUTPUT
		,@Action = @Action
		,@Mode = 'MP'
	
	SELECT @HaveWaitingTicket = COALESCE(@HaveWaitingTicket + ',' + m.matchcode, m.matchcode)
	FROM dbo.match m WITH(NOLOCK)
			INNER JOIN (SELECT [value] FROM STRING_SPLIT(@MatchIds, ',')) tm
				ON m.matchid = tm.value
	
	DELETE FROM #tblValidMatch
	OUTPUT deleted.matchid, deleted.matchcode
	INTO #tblInValidMatch
	WHERE matchid IN (SELECT [value] FROM STRING_SPLIT(@MatchIds, ','))
	
	IF ( ISNULL(@NotAllowCalculating,'') <> '' OR ISNULL(@HaveWaitingTicket,'') <> '' OR ISNULL(@MovingMatchIds,'') <> '' )
	BEGIN
		SELECT   @ErrCode = 1001011
				,@ErrMsg =  CASE when ISNULL(@NotAllowCalculating,'') <> ''
									THEN  ' (being calculated by another user): ' + @NotAllowCalculating
									ELSE ''
								END 
							+ CASE WHEN ISNULL(@HaveWaitingTicket, '') <> ''
									THEN ' (existing some PENDING tickets): ' + @HaveWaitingTicket
									ELSE ''
								END			
							+ CASE WHEN ISNULL(@MovingMatchIds, '') <> ''
									THEN ' (during move-bet progress): ' + @MovingMatchIds + '. Please contact Starix IT for further support!'
									ELSE ''
								END

							
		END

	SELECT @MatchIdsValid =  @MatchIdsValid + ',' + CAST(Matchid AS VARCHAR(50) ) FROM #tblValidMatch
	SET @MatchIdsValid = SUBSTRING(@MatchIdsValid, 2, LEN(@MatchIdsValid))

END
GO
