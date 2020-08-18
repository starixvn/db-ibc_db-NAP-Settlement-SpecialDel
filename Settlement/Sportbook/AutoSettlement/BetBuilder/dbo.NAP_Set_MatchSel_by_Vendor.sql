/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel_by_Vendor]
	@FromDate			DATETIME
	,@ToDate			DATETIME
	,@Status			VARCHAR(200) 	
	,@MatchCode 		NVARCHAR(50) 	= ''
	,@LeagueIds 		VARCHAR(MAX) 
	,@VendorID			INT				= 34
	,@SportTypes 		VARCHAR(MAX)
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200731@July : Edit SportType&LeagueID. Get Resultdetail for BBD   [Redmine:#138475]
		
	Param's Explanation:	
		@Status: All, Running, Completed
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MatchId			INT
			,@CheckEventStatus	BIT
			,@strMatchIds		VARCHAR(MAX)
			,@remoteQuery		NVARCHAR(MAX)
			,@strResourceIds	VARCHAR(MAX)
			
	DECLARE @tblEventStatus TABLE (EventStatus VARCHAR(20))
	DECLARE @TempMatch TABLE (MatchId INT,Sporttype SMALLINT, IsCalculating INT)
	DECLARE @tmpSporttypes TABLE ( Sporttype SMALLINT)
	DECLARE @tmpLeagueIds TABLE ( LeagueId INT)
	DECLARE @tmpResultDetail TABLE (
		MatchId				INT
		,ResourceId			VARCHAR(20)
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,ResultStatusId		TINYINT
		,SettlementStatusId TINYINT
	)
	CREATE TABLE #tmpMatchIds
	(
		 matchid						INT
		,matchcode						NVARCHAR(50)
		,leagueid						INT
		,sporttype						SMALLINT
		,kickofftime					DATETIME
		,settlementstatus				TINYINT
		,homeid							INT
		,awayid							INT		
		,eventstatus					NVARCHAR(50)
		,betstatus						NVARCHAR(50)
		,autosetting					TINYINT
		,autosettingforleague			TINYINT		
		,eventdate						DATETIME
	)
	-------------------------------------------------------------------------------------------------
	IF @Status ='All'
	BEGIN
		SET @Status ='Running,Completed'
	END 	
	INSERT INTO @tblEventStatus(EventStatus)
	SELECT Val 
	FROM dbo.f_SplitString(@Status, ',')
	option (maxrecursion 0)

	INSERT INTO @tmpSporttypes(Sporttype)
	SELECT Val 
	FROM dbo.f_SplitString(@SportTypes, ',')
	option (maxrecursion 0)

	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT Val 
	FROM dbo.f_SplitString(@LeagueIds, ',')
	option (maxrecursion 0)

	IF EXISTS(SELECT 1 FROM @tblEventStatus HAVING COUNT(*) > 1)
		SET @CheckEventStatus = 0
	ELSE
		SET @CheckEventStatus = 1
		
		
	IF ISNUMERIC(@MatchCode) = 1
	BEGIN
		SET @MatchId = CAST(@MatchCode AS INT)
	END
	
	IF @MatchCode <> ''
	BEGIN 
		INSERT INTO #tmpMatchIds(
				 matchid			
				,matchcode			
				,leagueid			
				,sporttype			
				,kickofftime
				,settlementstatus	
				,homeid				
				,awayid				
				,eventstatus		
				,betstatus			
				,autosetting		
				,autosettingforleague
				,eventdate
			)
		SELECT 	m.matchid
				,m.matchcode
				,m.LeagueId
				,m.sporttype
				,m.kickofftime
				,m.settlementstatus
				,m.homeid
				,m.awayid
				,eventstatus		
				,betstatus		
				,ISNULL(m.autoSetting, l.autoSetting) AS autoSetting
				,l.autoSetting AS autoSettingForLeague
				,m.eventdate
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN @tmpSporttypes st ON m.sporttype=st.Sporttype
			INNER JOIN dbo.VendorStatus v WITH(NOLOCK) ON m.matchID = v.matchID
		WHERE	(m.matchid = @MatchId OR m.matchcode LIKE + '%' + @MatchCode + '%')
				AND m.eventdate BETWEEN @FromDate AND @ToDate
				AND v.vendorId = @VendorID 
				AND v.Opened = 1 
	END
	ELSE
	BEGIN
		INSERT INTO #tmpMatchIds(
				 matchid			
				,matchcode			
				,leagueid			
				,sporttype			
				,kickofftime
				,settlementstatus	
				,homeid				
				,awayid				
				,eventstatus		
				,betstatus			
				,autosetting		
				,autosettingforleague
				,eventdate
			)
		SELECT 	m.matchid
				,m.matchcode
				,m.LeagueId
				,m.sporttype
				,m.kickofftime
				,settlementstatus
				,m.homeid
				,m.awayid
				,m.eventstatus		
				,betstatus		
				,ISNULL(m.autoSetting, l.autoSetting) AS autoSetting
				,l.autoSetting AS autoSettingForLeague
				,m.eventdate
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN @tmpLeagueIds tl ON	m.leagueid = tl.LeagueId
			INNER JOIN dbo.League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN @tmpSporttypes st ON m.sporttype=st.Sporttype 
			INNER JOIN dbo.VendorStatus v WITH(NOLOCK) ON m.matchID = v.matchID
		WHERE  m.eventdate BETWEEN @FromDate AND @ToDate
				AND v.vendorId = @VendorID 
				AND v.Opened = 1 

	END
	
	--Get match info in queue
	;WITH SingleTicket AS (
		SELECT matchid,st.Sporttype
		FROM dbo.[match] m WITH (NOLOCK)
			INNER JOIN @tmpSporttypes st ON m.sporttype=st.Sporttype 
		WHERE m.eventdate BETWEEN @FromDate AND @ToDate
			AND (@MatchCode = '' OR m.matchid = @MatchId OR m.matchcode = @MatchCode)
	),
	QueueSingleMatch AS (
		SELECT matchid, MIN(IsCalculating)  IsCalculating
		FROM dbo.Single_Calculate_Queue_3rd s WITH(NOLOCK)
			INNER JOIN @tmpSporttypes st ON s.sporttype=st.Sporttype
		WHERE Starttime > DATEADD(MINUTE,-10,GETDATE())
			AND s.IsCalculating IN (0,1)
		GROUP BY matchid
	)	
	INSERT INTO @TempMatch(MatchId,Sporttype, IsCalculating)
	SELECT sg.matchid, sg.Sporttype, q.IsCalculating
	FROM SingleTicket sg
		INNER LOOP JOIN dbo.VendorStatus v WITH (NOLOCK) ON sg.matchID = v.matchID
		LEFT JOIN QueueSingleMatch q ON q.matchID = sg.matchID
	WHERE v.vendorId = @VendorID 
			AND v.Opened = 1 
	;
	--------------------------------------------------------------------------------
	IF EXISTS ( SELECT TOP 1 1 FROM @tmpSporttypes WHERE Sporttype IN (1,2))
	BEGIN 
		SELECT @strMatchIds = ''
			   ,@remoteQuery = ''
			   ,@strResourceIds = ''

		SELECT @strMatchIds = @strMatchIds + CAST(tempM.MatchId AS VARCHAR(20)) + ','
		FROM #tmpMatchIds tempM
		WHERE tempM.Sporttype in (1,2)

		IF @strMatchIds <> '' 
		BEGIN
			SELECT @strResourceIds = @strResourceIds + '''' + f.ResourceID + '''' + ','
			FROM (
				SELECT DISTINCT f.ResourceID
				FROM #tmpMatchIds tempM
					CROSS APPLY dbo.f_Set_MajorRound (tempM.sporttype) f
			)f
		
			SELECT @strMatchIds		=  LEFT(@strMatchIds,LEN(@strMatchIds)-1) 
				   ,@strResourceIds = CASE WHEN @strResourceIds = '' THEN @strResourceIds ELSE LEFT(@strResourceIds, LEN(@strResourceIds) - 1) END 

			SET @remoteQuery = 'SELECT	MatchId,ResourceId,HomeValue,AwayValue,ResultStatusID,SettlementStatusID
								FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK) 
								WHERE	r.MatchId IN ('+ @strMatchIds+ ')
										' + CASE WHEN @strResourceIds <> '' THEN 
										' AND r.ResourceId IN ('+ @strResourceIds +')' ELSE '' END

			INSERT INTO @tmpResultDetail (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusId, SettlementStatusId)
			EXECUTE sys.sp_executesql @remoteQuery
		END
	END
	--------------------------------------------------------------------------------
	;WITH cteBettrans AS(
		SELECT matchID
				,CASE	WHEN totalTicket = 0 			THEN 'No Ticket'
						WHEN totalTicketRunning > 0 	THEN 'Running'
						ELSE 'Completed' END AS parlayStatus
		FROM  (
				  SELECT m.matchID
						 ,COUNT (*) AS totalTicket
						 ,SUM (CASE WHEN statusID = 0 THEN 1 ELSE 0 END) AS totalTicketRunning
				  FROM @TempMatch m
				  		INNER JOIN dbo.Bettrans bt WITH (NOLOCK) ON m.MatchID = bt.MatchID
				  WHERE bt.Bettype  = 38
						AND bt.statusID NOT IN (101, 102)
				  GROUP BY m.matchID
			  ) AS tbtTicketCount
	)
	SELECT	m.matchID
			,m.matchCode
			,m.leagueID
			,m.kickOffTime
			,m.SettlementStatus 
			,m.betStatus
			,m.eventStatus
			,m.homeID
			,m.awayID
			,m.autosetting
			,m.autosetting 
			,ISNULL(cteBt.parlayStatus, 'No Ticket') AS parlayStatus
			,ISNULL(tempM.IsCalculating, 2) AS QueueStatus
			,m.sporttype
	FROM #tmpMatchIds m
		LEFT JOIN @TempMatch tempM ON m.matchid=tempM.MatchId
		LEFT JOIN cteBettrans cteBt ON cteBt.MatchID = tempM.MatchID
	WHERE 1 = CASE WHEN @CheckEventStatus = 0 THEN 1
				   WHEN @CheckEventStatus = 1 AND @MatchCode ='' AND cteBt.parlayStatus = @Status THEN 1
				   WHEN  @CheckEventStatus = 1 AND @MatchCode <>''  THEN 1
				   ELSE 0 END
	ORDER BY CASE m.eventstatus WHEN 'completed' THEN 1 WHEN 'refund' THEN 1 ELSE 0 END
		, m.eventdate
		, m.kickofftime
		, m.sporttype
		, m.leagueid
		, m.matchid
		, m.betstatus
		, m.matchcode

	SELECT	MatchId
			,ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusId
			,SettlementStatusId
	FROM	@tmpResultDetail

	DROP TABLE #tmpMatchIds;
END

