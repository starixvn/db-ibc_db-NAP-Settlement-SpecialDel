/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_OutrightSelInfo]
	 @FromDate			SMALLDATETIME
	,@ToDate			SMALLDATETIME = NULL
	,@LeagueIDs			VARCHAR(MAX)
	,@StatusID			INT = 0 
	,@IsIncludeTest		BIT = 0 
AS 
/**
 * Created by	: Jamie   
 * Date			: 20130808
 * Task			: Outright results 
 * DB			: DBPRO/bodb02  

 * Revisions	:
	- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
	- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
	- 20230109@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]
	- 20230317@Aries: Enhance Outright Settlement as User Feedback [Redmine:#185129]
	- 20250819@Hughie: Apply SOP for Outright [Redmine: #232955]

 * Parameters:
    @FromDate: From  date,
	@ToDate: To date ,
	@LeagueID: = 0: show info of all leagues     
	@LeagueIDs: '86,97,181,184'
	@StatusID: 0=ALL | 1=Running | 2=Completed
 */
BEGIN   
	SET NOCOUNT ON  

	DECLARE @tmpLeague AS TABLE (LeagueID INT  PRIMARY KEY, sporttype TINYINT, isTest BIT)  

	INSERT INTO @tmpLeague(LeagueID,sporttype,isTest)
	SELECT tl.value , l.sporttype, l.isTest
	FROM STRING_SPLIT(@LeagueIDs,',') AS tl
        INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = tl.value

	SELECT	o.leagueid
		,	MAX(o.eventdate) AS eventdate
		,	(SELECT TOP 1 DeadHeat 
			 FROM SettlementSetting AS st WITH(NOLOCK) 
			 WHERE  st.leagueid = o.leagueid) AS DeadHeat
	FROM dbo.outright AS o WITH (NOLOCK)
		INNER JOIN @tmpLeague AS tl  ON tl.leagueid = o.leagueid AND ISNULL(o.IsDeleted,0) = 0	 
    GROUP BY o.leagueid

	SELECT	o.orid
		,	o.leagueid
		,	o.[teamid]
		,	o.matchcode
		,	o.kickofftime
		,	o.eventdate
		,	ISNULL(o.oddsstatus, 'Running') AS oddsstatus
		,	ISNULL(o.status, 'Running') AS status
		,	tl.sporttype 
		,	o.odds
	FROM dbo.outright AS o WITH (NOLOCK)
		INNER JOIN @tmpLeague AS tl  ON tl.leagueid = o.leagueid
	WHERE ((@ToDate IS NULL AND o.eventdate >= @FromDate) 
            OR (@ToDate IS NOT NULL AND o.eventdate BETWEEN @FromDate AND @ToDate))
		AND 1 = CASE WHEN @StatusID = 0 THEN 1
					 WHEN @StatusID = 1 AND o.oddsstatus IN ('Running','Closed','Internal') THEN 1
					 WHEN @StatusID = 2 AND o.oddsstatus IN ('Completed') THEN 1
					 ELSE 0  
				END 
		AND ISNULL(o.IsDeleted,0) = 0	
		AND tl.isTest = IIF(@IsIncludeTest = 0,0,tl.isTest)			 
	ORDER BY o.leagueid
		,	 IIF(o.oddsstatus IN ('Running','Closed','Internal'),1,2)
		,	 o.kickofftime  
	
	SELECT o.leagueid, COUNT(orid) AS DeadHeatTeam 
	FROM outright o WITH (NOLOCK)
		INNER JOIN @tmpLeague AS tl ON tl.LeagueID = o.leagueid
	WHERE ((@ToDate IS NULL AND o.eventdate >= @FromDate) 
            OR (@ToDate IS NOT NULL AND o.eventdate BETWEEN @FromDate AND @ToDate))
			AND o.status = 'WON'
	GROUP BY o.leagueid
	
END