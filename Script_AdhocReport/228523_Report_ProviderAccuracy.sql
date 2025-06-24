/*<info serverAlias="DBARC-bodb02" executers="" isFunction="0"></info>*/

/*  Created by: 20250617@Louisa
    Task: Get Report Provider [Redmine:#228523]
    DB: DBARC-bodb02
    
    Revisions: 
		- 20250617@Louisa: create [Redmine:#228523]
*/

USE bodb02
GO

BEGIN
	DECLARE @ProviderID		INT   ---SELECT * FROM DBPRO.bodb02.dbo.ProviderInfo p WITH(NOLOCK) WHERE p.SourceID = @SourecID		
			,@ProviderName	VARCHAR(50) ='sofas'
			,@Sporttype		SMALLINT = 2
			,@fromDate		DATETIME = '2025-01-01'
			,@toDate		DATETIME = '2025-06-23 23:59:59' 

	IF @ProviderID IS NULL
	BEGIN
		SELECT TOP 1 @ProviderID = p.SourceID
					,@ProviderName = p.SourceName
		FROM DBPRO.bodb02.dbo.ProviderInfo p WITH(NOLOCK)
			INNER JOIN DBPRO.bodb02.dbo.ProviderGameTypeMapping pgm WITH(NOLOCK) ON p.SourceID = pgm.SourceID
		WHERE   pgm.Sporttype = 2	
			AND p.SourceName LIKE '%'+@ProviderName+'%'
							 
		
		Print 'ProviderID: ' +CAST(@ProviderID AS VARCHAR(20)) + ', ProviderName: '+@ProviderName
	END

	IF NOT EXISTS (	SELECT TOP 1 1 
					FROM DBPRO.bodb02.dbo.ProviderInfo p WITH(NOLOCK)
						INNER JOIN DBPRO.bodb02.dbo.ProviderGameTypeMapping pgm WITH(NOLOCK) ON p.SourceID = pgm.SourceID
					WHERE p.SourceID = @ProviderID	
						AND pgm.Sporttype = @Sporttype
					)
	BEGIN
		Print 'This Provider is not mapping with Sport!'
	END

	IF ISNULL(@Sporttype,0) NOT BETWEEN 1 AND 99
	BEGIN
		Print 'Please input Sporttype correctly!'
		RETURN
	END
	IF @ProviderID IN ( 98,99,100, 1001) OR @ProviderID > 1000
	BEGIN
		Print 'Please input ProviderID correctly!'
		RETURN
	END

-----------GET SETTING DATA----------------------------------
	DECLARE @MovebetDate	SMALLDATETIME
			,@BUDate		SMALLDATETIME
			,@ResultTable	TINYINT
			,@ProviderTable TINYINT
			,@IsApplyAP		BIT
	
	
	DECLARE @tmp_ValidResourceID TABLE (ResourceID VARCHAR(20), SettleType VARCHAR(30))

	DROP TABLE IF EXISTS #tmp_ProviderResult
	DROP TABLE IF EXISTS #tmp_Match
	DROP TABLE IF EXISTS #tmp_SettledResult
	DROP TABLE IF EXISTS #tmp_ReduntdantData

	CREATE TABLE #tmp_ProviderResult (ID INT IDENTITY(1,1), MatchID INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) , CreateDate DATETIME, rk INT)
	CREATE TABLE #tmp_Match (MatchID INT, EventDate DATE, leagueid INT, leaguename NVARCHAR(500), homeid int, awayid int, isTestMatch BIT, LeagueGroupID INT, hometeamname NVARCHAR(100), awayteamname NVARCHAR(100), range TINYINT)
	CREATE TABLE #tmp_SettledResult (ID INT IDENTITY(1,1), MatchID INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	CREATE TABLE #tmp_ReduntdantData (MatchId INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	
	CREATE INDEX idx_tmp_Match ON #tmp_Match (Matchid)
	CREATE INDEX idx_tmp_ProviderResult ON #tmp_ProviderResult (Matchid, resourceid)

	SELECT @MovebetDate = CONVERT(SMALLDATETIME, VValue)
	FROM bodb02.dbo.SystemSettings
	WHERE VName = 'MovebetDate'

	SELECT @BUDate = CONVERT(SMALLDATETIME, VValue)
	FROM DBACC.bodb02.dbo.MBUSettings  WITH(NOLOCK)
	WHERE VName like 'BalanceUpDate'

	SELECT  @ResultTable	= s.ResultTable
			,@ProviderTable = s.ExternalResultTable
			,@IsApplyAP		= CASE WHEN ISNULL(s.AP_Group,0) BETWEEN 1 AND 999 THEN 1 ELSE 0 END
	FROM DBPRO.bodb02.dbo.SettlementResultTableSetting s WITH(NOLOCK)
	WHERE s.Sporttype = @Sporttype

	INSERT INTO @tmp_ValidResourceID ( ResourceID, SettleType ) 
	SELECT DISTINCT  ISNULL(sp.ResourceID, major.ResourceID) AS ResourceID,  CASE WHEN  major.ResourceID IS NOT NULL THEN 'MNL' ELSE sp.SettleType END AS SettleType
	FROM SettlementSpecialBettypeProfile sp WITH(NOLOCK)
		OUTER APPLY ( SELECT  major.ResourceID 
					  FROM  f_Set_MajorRound(@sportype) major
					  WHERE major.ResourceID = sp.ResourceID
							) major
	WHERE   sp.SportType = @sportype 
      AND ISNULL(RefResourceID,'') = ''

	-------MATCH INFO---------------------------------------------------------------
	IF @toDate > @MovebetDate
	BEGIN
		INSERT INTO  #tmp_Match (MatchID, EventDate, leagueid, homeid, awayid, range)
		SELECT m.MatchID, m.EventDate, m.leagueid , m.homeid, m.awayid, 1 As range
		FROM match m WITH(NOLOCK) 		
		WHERE m.sporttype = @Sporttype
			AND m.eventstatus = 'completed'
			AND m.eventdate BETWEEN @fromDate AND @toDate
			AND m.IsDeleted = 0
	END

	IF @fromDate <= @MovebetDate 
	BEGIN
		INSERT INTO  #tmp_Match (MatchID, EventDate, leagueid, homeid, awayid, range)
		SELECT m.MatchID, m.EventDate, m.leagueid , m.homeid, m.awayid, 2 AS range
		FROM match14 m WITH(NOLOCK) 		
		WHERE m.sporttype = @Sporttype
			AND m.eventstatus = 'completed'
			AND m.eventdate BETWEEN @fromDate AND @toDate 
	END

	IF @fromDate <= @MovebetDate 
	BEGIN
		INSERT INTO  #tmp_Match (MatchID, EventDate, leagueid, homeid, awayid, range)
		SELECT m.MatchID, m.EventDate, m.leagueid , m.homeid, m.awayid, 3 AS range
		FROM bodb_archive.dbo.match_bk m WITH(NOLOCK) 		
		WHERE m.sporttype = @Sporttype
			AND m.eventstatus = 'completed'
			AND m.eventdate BETWEEN @fromDate AND @toDate 
	END

	UPDATE m
	SET leaguename = l.leaguename
		,hometeamname = h.teamname 
		,awayteamname = a.teamname
		,isTestMatch =l.isTest
		,LeagueGroupID = l.LeagueGroupID
	FROM  #tmp_Match m
		INNER JOIN league l WITH(NOLOCK) on m.leagueid = l.leagueid
		INNER JOIN team h WITH(NOLOCK) ON m.homeid = h.teamid
		INNER JOIN team a WITH(NOLOCK) ON m.awayid = a.teamid

	DELETE FROM #tmp_Match WHERE isTestMatch = 1 OR  LeagueGroupID IN (122,113,252,151,215)
	
	------PROVIDER DATA-------------------------------------------------------------------
	IF @ProviderTable =1
	BEGIN
		INSERT INTO #tmp_ProviderResult (MatchID, ResourceID, HomeValue, AwayValue, CreateDate, rk  )
		SELECT r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue, r.CreateDate , ROW_NUMBER() OVER( partition by r.matchid, r.ResourceId order by r.CreateDate  ) 
		FROM bodb_archive.dbo.ProviderExternalResultDetail_BK r WITH(NOLOCK)
		INNER JOIN #tmp_Match m ON r.Matchid = m.matchid
	END

	DELETE r 
	OUTPUT  deleted.MatchId  , deleted.ResourceID , deleted.HomeValue , deleted.AwayValue
	INTO #tmp_ReduntdantData (MatchId  , ResourceID , HomeValue , AwayValue )
	FROM #tmp_ProviderResult r


	------RESULT SETTLE DATA----------------------------------------------------------------
	IF EXISTS (SELECT TOP 1 1 FROM #tmp_Match WHERE range = 1)
	BEGIN
		IF @ResultTable = 1
		BEGIN
			INSERT INTO #tmp_SettledResult ( MatchID, ResourceID, HomeValue, AwayValue )
			SELECT r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
			FROM ResultDetail r wITH(NOLOCK)
			INNER JOIN #tmp_Match m ON r.MatchId = m.Matchid
			WHERE m.range =1
				AND r.ResultStatusID IN (2,5)
		END
	END
	IF EXISTS (SELECT TOP 1 1 FROM #tmp_Match WHERE range = 2)
	BEGIN
		IF @ResultTable = 1
		BEGIN
			INSERT INTO #tmp_SettledResult ( MatchID, ResourceID, HomeValue, AwayValue )
			SELECT r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
			FROM ResultDetail14 r wITH(NOLOCK)
			INNER JOIN #tmp_Match m ON r.MatchId = m.Matchid
			WHERE m.range = 2
				AND r.ResultStatusID IN (2,5)
		END
	END
	IF EXISTS (SELECT TOP 1 1 FROM #tmp_Match WHERE range = 3)
	BEGIN
		IF @ResultTable = 1
		BEGIN
			INSERT INTO #tmp_SettledResult ( MatchID, ResourceID, HomeValue, AwayValue )
			SELECT r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
			FROM bodb_archive.dbo.ResultDetail_BK r wITH(NOLOCK)
			INNER JOIN #tmp_Match m ON r.MatchId = m.Matchid
			WHERE m.range =3
				AND r.ResultStatusID IN (2,5)
		END
	END
	--------- % MATCH HAS PROVIDER----------------------------------------------------------------
	SELECT eventdate , Total_Match, Match_has_Provider, ( CAST(Match_has_Provider AS DeCIMAL(3,1))/Total_Match)*100  as rate
	FROM ( SELECT convert(varchar(10), m.eventdate, 120 ) as eventdate 
			,count(  m.matchid) as Total_Match
			,SUM( ISNULL(ExisProvider,0) ) AS Match_has_Provider
		from #tmp_Match m
		OUTER APPLY ( SELECT TOP 1 1 AS ExisProvider
						from #tmp_ProviderResult p
						WHERE p.Matchid = m.matchid
					 )p
		GROUP BY m.eventdate 
		 )m
	order by  m.eventdate 
	
	------------% RESOURCE HAS PROVIDER -----------------------------------------------------------------------------------

	DROP TABLE IF EXISTS #tmp_AllResult
	 
	 SELECT  r.MatchID
			,r.ResourceID
			, isnull(m.homevalue,'') = isnull(p.homevalue,'') or isnull(m.awayvalue,'') = isnull(p.awayvalue,'')
	FROM #tmp_SettledResult m
	FULL OUTER JOIN  #tmp_ProviderResult p
			ON p.Matchid = m.matchid
				AND p.ResourceID = m.ResourceID
	ORDER BY  m.eventdate 
	


	
	---------Return Redundant data
	SELECT MatchId  , ResourceID , HomeValue , AwayValue
	FROM #tmp_ReduntdantData r
	ORDER BY MatchID


END
GO