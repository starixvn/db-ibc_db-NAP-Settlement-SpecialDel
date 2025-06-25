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
	DECLARE @tmp_MajorRound TABLE (ResourceID VARCHAR(20), Sporttype SMALLINT,RoundID VARCHAR(3),RoundName VARCHAR(5),GroupType VARCHAR(2),isFinal BIT,OrdNo SMALLINT,AllowDirectly BIT,IntervalNo  SMALLINT)

	DROP TABLE IF EXISTS #tmp_ProviderResult
	DROP TABLE IF EXISTS #tmp_Match
	DROP TABLE IF EXISTS #tmp_SettledResult
	DROP TABLE IF EXISTS #tmp_ReduntdantData

	CREATE TABLE #tmp_ProviderResult (ID INT IDENTITY(1,1), MatchID INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) , CreateDate DATETIME, rk INT, IsLive BIT )
	CREATE TABLE #tmp_Match (MatchID INT, EventDate DATE, leagueid INT, leaguename NVARCHAR(500), homeid int, awayid int, isTestMatch BIT, LeagueGroupID INT, hometeamname NVARCHAR(100), awayteamname NVARCHAR(100), range TINYINT)
	CREATE TABLE #tmp_SettledResult (ID INT IDENTITY(1,1), MatchID INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	CREATE TABLE #tmp_ReduntdantData (MatchId INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50) )
	
	CREATE INDEX idx_tmp_Match ON #tmp_Match (Matchid)
	CREATE INDEX idx_tmp_ProviderResult_Matchid_ResourceID ON #tmp_ProviderResult (Matchid, resourceid)
	CREATE INDEX idx_tmp_SettledResult_Matchid_ResourceID ON #tmp_ProviderResult (Matchid, resourceid)

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

	/*
		INSERT INTO @tmp_MajorRound ( Sporttype,RoundID,RoundName,ResourceID,GroupType,isFinal,OrdNo,AllowDirectly,IntervalNo )
		EXEC DBPRO.bodb02.dbo.NAP_Admin_MajorRound_Sel	@Sporttype
	*/

	INSERT INTO @tmp_MajorRound ( Sporttype,ResourceID)
	select 43	AS Sporttype ,'M1' AS ResourceID UNION ALL SELECT 
		43	,'M2' UNION ALL SELECT 
		43	,'M3' UNION ALL SELECT 
		43	,'M4' UNION ALL SELECT 
		43	,'M5' UNION ALL SELECT 
		43	,'M6' UNION ALL SELECT 
		43	,'M7' UNION ALL SELECT 
		43	,'M8' UNION ALL SELECT 
		43	,'M9' UNION ALL SELECT 
		43	,'M10' UNION ALL SELECT 
		43	,'M11' UNION ALL SELECT 
		43	,'M12' UNION ALL SELECT 
		43	,'M13' UNION ALL SELECT 
		43	,'M14' UNION ALL SELECT 
		43	,'M15' UNION ALL SELECT 
		43	,'M16' UNION ALL SELECT 
		43	,'M17' UNION ALL SELECT 
		43	,'M18' UNION ALL SELECT 
		43	,'M19' UNION ALL SELECT 
		43	,'M20' UNION ALL SELECT 
		43	,'M21' UNION ALL SELECT 
		43	,'M22' UNION ALL SELECT 
		43	,'M23' UNION ALL SELECT 
		43	,'M24' UNION ALL SELECT 
		43	,'M25' UNION ALL SELECT 
		43	,'M26' UNION ALL SELECT 
		43	,'M27' UNION ALL SELECT 
		43	,'M28' UNION ALL SELECT 
		43	,'M29' UNION ALL SELECT 
		43	,'M30' UNION ALL SELECT 
		43	,'00' UNION ALL SELECT 
		9	,'0101' UNION ALL SELECT 
		9	,'0102' UNION ALL SELECT 
		9	,'0103' UNION ALL SELECT 
		9	,'0104' UNION ALL SELECT 
		9	,'0105' UNION ALL SELECT 
		9	,'00' UNION ALL SELECT 
		5	,'01' UNION ALL SELECT 
		5	,'02' UNION ALL SELECT 
		5	,'03' UNION ALL SELECT 
		5	,'04' UNION ALL SELECT 
		5	,'05' UNION ALL SELECT 
		5	,'00' UNION ALL SELECT 
		2	,'Q1' UNION ALL SELECT 
		2	,'Q2' UNION ALL SELECT 
		2	,'01' UNION ALL SELECT 
		2	,'Q3' UNION ALL SELECT 
		2	,'Q4' UNION ALL SELECT 
		2	,'OT' UNION ALL SELECT 
		2	,'00' UNION ALL SELECT 
		1	,'01' UNION ALL SELECT 
		1	,'09' UNION ALL SELECT 
		1	,'08' UNION ALL SELECT 
		1	,'00' UNION ALL SELECT 
		50	,'H1' UNION ALL SELECT 
		50	,'A1' UNION ALL SELECT 
		50	,'H2' UNION ALL SELECT 
		50	,'A2' UNION ALL SELECT 
		50	,'00' UNION ALL SELECT 
		45	,'0101' UNION ALL SELECT 
		45	,'0102' UNION ALL SELECT 
		45	,'0103' UNION ALL SELECT 
		45	,'00' UNION ALL SELECT 
		6	,'0101' UNION ALL SELECT 
		6	,'0102' UNION ALL SELECT 
		6	,'0103' UNION ALL SELECT 
		6	,'0104' UNION ALL SELECT 
		6	,'0105' UNION ALL SELECT 
		6	,'00' UNION ALL SELECT 
		58	,'01' UNION ALL SELECT 
		58	,'0001' UNION ALL SELECT 
		58	,'ET' UNION ALL SELECT 
		58	,'PEN' UNION ALL SELECT 
		58	,'00' UNION ALL SELECT 
		18	,'0101' UNION ALL SELECT 
		18	,'0102' UNION ALL SELECT 
		18	,'0103' UNION ALL SELECT 
		18	,'0104' UNION ALL SELECT 
		18	,'0105' UNION ALL SELECT 
		18	,'0106' UNION ALL SELECT 
		18	,'0107' UNION ALL SELECT 
		18	,'00' UNION ALL SELECT 
		8	,'0101' UNION ALL SELECT 
		8	,'0102' UNION ALL SELECT 
		8	,'0103' UNION ALL SELECT 
		8	,'0104' UNION ALL SELECT 
		8	,'0105' UNION ALL SELECT 
		8	,'0106' UNION ALL SELECT 
		8	,'0107' UNION ALL SELECT 
		8	,'0108' UNION ALL SELECT 
		8	,'0109' UNION ALL SELECT 
		8	,'EI' UNION ALL SELECT 
		8	,'00' UNION ALL SELECT 
		3	,'00' UNION ALL SELECT 
		4	,'00' UNION ALL SELECT 
		5	,'00' UNION ALL SELECT 
		7	,'00' UNION ALL SELECT 
		10	,'00' UNION ALL SELECT 
		11	,'00' UNION ALL SELECT 
		12	,'00' UNION ALL SELECT 
		13	,'00' UNION ALL SELECT 
		14	,'00' UNION ALL SELECT 
		15	,'00' UNION ALL SELECT 
		16	,'00' UNION ALL SELECT 
		17	,'00' UNION ALL SELECT 
		19	,'00' UNION ALL SELECT 
		20	,'00' UNION ALL SELECT 
		21	,'00' UNION ALL SELECT 
		22	,'00' UNION ALL SELECT 
		23	,'00' UNION ALL SELECT 
		24	,'00' UNION ALL SELECT 
		25	,'00' UNION ALL SELECT 
		26	,'00' UNION ALL SELECT 
		27	,'00' UNION ALL SELECT 
		28	,'00' UNION ALL SELECT 
		29	,'00' UNION ALL SELECT 
		30	,'00' UNION ALL SELECT 
		31	,'00' UNION ALL SELECT 
		32	,'00' UNION ALL SELECT 
		33	,'00' UNION ALL SELECT 
		34	,'00' UNION ALL SELECT 
		35	,'00' UNION ALL SELECT 
		36	,'00' UNION ALL SELECT 
		37	,'00' UNION ALL SELECT 
		38	,'00' UNION ALL SELECT 
		39	,'00' UNION ALL SELECT 
		40	,'00' UNION ALL SELECT 
		41	,'00' UNION ALL SELECT 
		42	,'00' UNION ALL SELECT 
		44	,'00' UNION ALL SELECT 
		46	,'00' UNION ALL SELECT 
		47	,'00' UNION ALL SELECT 
		48	,'00' UNION ALL SELECT 
		49	,'00' UNION ALL SELECT 
		51	,'00' UNION ALL SELECT 
		52	,'00' UNION ALL SELECT 
		53	,'00' UNION ALL SELECT 
		54	,'00' UNION ALL SELECT 
		55	,'00' UNION ALL SELECT 
		56	,'00' UNION ALL SELECT 
		57	,'00' UNION ALL SELECT 
		59	,'00' UNION ALL SELECT 
		60	,'00' UNION ALL SELECT 
		61	,'00' UNION ALL SELECT 
		62	,'00' UNION ALL SELECT 
		63	,'00' UNION ALL SELECT 
		64	,'00' UNION ALL SELECT 
		65	,'00' UNION ALL SELECT 
		66	,'00' UNION ALL SELECT 
		67	,'00' UNION ALL SELECT 
		98	,'00' UNION ALL SELECT 
		99	,'00' UNION ALL SELECT 
		3	,'01' UNION ALL SELECT 
		26	,'01' UNION ALL SELECT 
		32	,'01' UNION ALL SELECT 
		47	,'01' UNION ALL SELECT 
		49	,'01' UNION ALL SELECT 
		56	,'01'

	INSERT INTO @tmp_ValidResourceID ( ResourceID, SettleType ) 
	SELECT DISTINCT  ISNULL(sp.ResourceID, major.ResourceID) AS ResourceID,  CASE WHEN  major.ResourceID IS NOT NULL THEN 'MNL' ELSE sp.SettleType END AS SettleType
	FROM DBPRO.bodb02.dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
		OUTER APPLY ( SELECT  major.ResourceID 
					  FROM  @tmp_MajorRound major
					  WHERE major.ResourceID = sp.ResourceID
							) major
	WHERE   sp.SportType = @sporttype 
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
		WHERE ISNULL(r.IsLive,0) = 0
	END

	DELETE r 
	OUTPUT  deleted.MatchId  , deleted.ResourceID , deleted.HomeValue , deleted.AwayValue
	INTO #tmp_ReduntdantData (MatchId  , ResourceID , HomeValue , AwayValue )
	FROM #tmp_ProviderResult r
		RIGHT JOIN  @tmp_ValidResourceID valid ON r.ResourceID = valid.ResourceID
	WHERE r.ResourceID IS NULL


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

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmp_ProviderResult p 
					INNER JOIN @tmp_ValidResourceID valid ON p.ResourceID = valid.ResourceID
					WHERE valid.SettleType = 'EAR')
	BEGIN
		DELETE r
		FROM #tmp_SettledResult r
			INNER JOIN @tmp_ValidResourceID valid ON r.ResourceID = valid.ResourceID
		WHERE valid.SettleType = 'EAR'

	END

	---------RETURN % MATCH HAS PROVIDER----------------------------------------------------------------
	SELECT eventdate , Total_Match, Match_has_Provider, ( CAST(Match_has_Provider AS DeCIMAL(5,1))/Total_Match)*100  as rate
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
	ORDER BY  m.eventdate 
	
	------------RETURN % RESOURCE HAS PROVIDER -----------------------------------------------------------------------------------	 
	SELECT m.matchid
			--,m.eventdate
			,m.ResourceID 
			,count(ProviderResourceID) AS cntSendData
			,sum(cntHasData) AS cntHasData
			,sum(CASE WHEN cntCorrect = 1 THEN 1 ELSE 0 END ) AS cntCorrect
			,sum(CASE WHEN cntCorrect = 2 THEN 1 ELSE 0 END ) AS cntWrong
			,DATEDIFF(SeCOND,MIN(m.CreateDate) ,  MAX(m.CreateDate) ) AS DurationSendData
	FROM (	SELECT  r.MatchID
					,r.ResourceID
					,p.ResourceID AS ProviderResourceID
					,p.CreateDate
					,CASE WHEN p.resourceID IS NULL THEN 0 ELSE 1 END AS cntHasData
					,CASE WHEN p.resourceID IS NOT NULL THEN CASE WHEN (isnull(r.homevalue,'') = isnull(p.homevalue,'') or isnull(r.awayvalue,'') = isnull(p.awayvalue,'') ) THEN 1 
																	ELSE 2
																	END
							ELSE 0
					 END AS cntCorrect
					-- ,r.eventdate 
			FROM #tmp_SettledResult r
			LEFT JOIN  #tmp_ProviderResult p
					ON p.Matchid = r.matchid
						AND p.ResourceID = r.ResourceID
		)m
	GROUP BY m.matchid, m.ResourceID
	--ORDER BY  m.eventdate 
	


	
	---------RETURN REDUNDANT DATA -----------------------------------------------------------------------------------
	SELECT MatchId  , ResourceID , HomeValue , AwayValue
	FROM #tmp_ReduntdantData r
	ORDER BY MatchID


END
GO