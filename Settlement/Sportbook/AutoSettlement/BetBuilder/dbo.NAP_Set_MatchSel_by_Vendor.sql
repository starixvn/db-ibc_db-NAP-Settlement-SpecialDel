/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel_by_Vendor]
	@FromDate			DATETIME
	,@ToDate			DATETIME
	,@Status			VARCHAR(200) 	= ''
	,@MatchCode 		NVARCHAR(50) 	= ''
	,@LeagueIds 		VARCHAR(MAX) 
	,@VendorID			INT				= 34
	,@SportTypes 		VARCHAR(MAX)	
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBPRO.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200731@July : Edit SportType&LeagueID. Get Resultdetail for BBD   [Redmine:#138475]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]					
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
		- 20220719@Kathy: Scale Out BetTrans: split code, move sp to DBPRO [Redmine:#175251]
		- 20241205@Louisa: fix issue convert matchcode [Redmine:#214853]

	Param's Explanation:	
		@Status: All, Running, Completed
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MatchId			INT
			,@CheckEventStatus	SMALLINT
			
	DECLARE @tblEventStatus TABLE (EventStatus VARCHAR(20))
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
	INSERT INTO @tblEventStatus(EventStatus)
	SELECT [Value] 
	FROM STRING_SPLIT(@Status, ',')

	INSERT INTO @tmpSporttypes(Sporttype)
	SELECT [Value] 
	FROM STRING_SPLIT(@SportTypes, ',')

	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT [Value] 
	FROM STRING_SPLIT(@LeagueIds, ',')


	SET @CheckEventStatus =(SELECT COUNT(EventStatus) FROM @tblEventStatus)
	
	IF TRY_CONVERT(INT, @matchcode) IS NOT NULL
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
				AND ISNULL(m.IsDeleted,0) = 0
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
				AND ISNULL(m.IsDeleted,0) = 0
	END
	
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
			,m.autosettingforleague 
			,m.sporttype
	FROM #tmpMatchIds m		
	ORDER BY CASE m.eventstatus WHEN 'completed' THEN 1 WHEN 'refund' THEN 1 ELSE 0 END
		, m.eventdate
		, m.kickofftime
		, m.sporttype
		, m.leagueid
		, m.matchid
		, m.betstatus
		, m.matchcode
END

