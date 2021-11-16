/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MoveTicketChecking] 
	@MatchId 				INT 
	,@DestinationMatchId	INT
	,@ErrCode 				INT = 0 OUTPUT
	,@ErrMsg 				NVARCHAR(200)	= '' OUTPUT
AS
/*
	Creator: Louisa
	Date: 20210930
	Task: Move ticket
	DB: DBTXN/bodb02

	Revisions:
		- 20210930@Louisa: Move running single tickets for E-Sports [Redmine:#159271]

*/
BEGIN

SET NOCOUNT ON
	
	DECLARE @Sporttype SMALLINT
			,@remoteQuery NVARCHAR(MAX)

	SET @Sporttype = 43 -- Currently, apply for ESports only

	DECLARE @tmpMatchInfo TABLE ( matchid INT, matchcode NVARCHAR(100), leagueid INT, homeid INT, awayid INT, eventdate DATETIME, eventstatus NVARCHAR(100) )

	IF OBJECT_ID('tempdb..#tmpTransIds') IS NULL
	CREATE TABLE #tmpTransIds	( RowId INT IDENTITY(1,1) PRIMARY KEY, custid INT, transid BIGINT, oddsid INT,  bettype SMALLINT, BetId INT, liveindicator BIT, StatusId TINYINT)
	
	IF OBJECT_ID('tempdb..#tmpNewOdds') IS NULL
	CREATE TABLE #tmpNewOdds	( oddsid INT, bettype SMALLINT, liveindicator BIT, ResourceId VARCHAR(20) )

	INSERT INTO @tmpMatchInfo (  matchid, matchcode, leagueid, homeid, awayid, eventdate, eventstatus  )
	SELECT  m.matchid, m.matchcode, m.leagueid, m.homeid, m.awayid, m.eventdate, m.eventstatus
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @MatchId
		AND m.sporttype = @Sporttype
		AND ISNULL(m.IsDeleted,0) = 0

	INSERT INTO @tmpMatchInfo (  matchid, leagueid, homeid, awayid, eventdate, eventstatus  )
	SELECT  m.matchid, m.leagueid, m.homeid, m.awayid, m.eventdate, m.eventstatus
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @DestinationMatchId
		AND m.sporttype = @Sporttype
		AND ISNULL(m.IsDeleted,0) = 0

	IF ( SELECT COUNT(1) FROM @tmpMatchInfo ) < 2
		OR EXISTS (SELECT TOP 1 1 FROM @tmpMatchInfo WHERE matchcode LIKE 'betdaq%') -- Do not allow move 2 times
	BEGIN
		SELECT @ErrCode = 1001001
				, @ErrMsg  = 'Match does not exist!'
		RETURN
	END

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpMatchInfo WHERE matchid = @MatchId AND eventstatus IN ('closed','postponed','internal') )
	BEGIN
		SELECT @ErrCode = 1001058
				, @ErrMsg = 'WARNING! Cannot continue due to: Status of source match should be closed, postponed or internal'
		RETURN
	END

	SELECT	@ErrCode = CASE WHEN tmp1.leagueid <> tmp2.leagueid THEN 1001059
							WHEN tmp1.homeid <> tmp2.homeid OR tmp1.awayid <> tmp2.awayid THEN 1001060
							WHEN tmp1.eventdate <> tmp2.eventdate THEN 1001061
							ELSE 0
							END
			,@ErrMsg = CASE WHEN tmp1.leagueid <> tmp2.leagueid THEN 'WARNING! Cannot continue due to: Matches should be in same league'
							WHEN tmp1.homeid <> tmp2.homeid OR tmp1.awayid <> tmp2.awayid THEN 'WARNING! Cannot continue due to: Team names of matches should be the same'
							WHEN tmp1.eventdate <> tmp2.eventdate THEN 'WARNING! Cannot continue due to: Eventdate of matches should be the same'
							ELSE NULL
							END
	FROM @tmpMatchInfo tmp1 
		OUTER APPLY  ( SELECT leagueid, homeid, awayid, eventdate FROM @tmpMatchInfo WHERE matchid = @DestinationMatchId) tmp2
	WHERE tmp1.matchid = @MatchId 
			
	IF @ErrCode > 0
	RETURN

	IF EXISTS (SELECT TOP 1 1 FROM dbo.match m WITH(NOLOCK) WHERE m.ParentID IS NOT NULL AND m.ParentID = @MatchId AND ISNULL(m.IsDeleted,0)  = 0 )
	BEGIN
		SELECT @ErrCode = 1001062
				, @ErrMsg = 'WARNING! Cannot continue due to: Source Match is having child match'
		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM dbo.bettrans b WITH(NOLOCK) WHERE b.matchid =  @DestinationMatchid AND b.statusID NOT IN ( 101, 102)  )
	BEGIN
		SELECT @ErrCode = 1001063
				,@ErrMsg = 'WARNING! Cannot continue due to: Target Match is having running or settled tickets'
		RETURN
	END

	INSERT INTO #tmpTransIds ( custid, transid, oddsid,  bettype, BetId, liveindicator, StatusId )
	SELECT b.custid, b.transid, b.oddsid,  b.bettype, b.BetId, b.liveindicator, b.statusID
	FROM dbo.bettrans b WITH(NOLOCK)
		LEFT JOIN dbo.MarkedTransaction mk WITH(NOLOCK)
			ON b.transid = mk.TransId
	WHERE b.matchid = @MatchId
		AND b.statusID IN ( 0, 1 ) --running, waitting
		AND mk.TransId IS NULL

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 1001063
				,@ErrMsg = 'WARNING! Cannot continue due to: Current has no valid ticket to move'
		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransIds WHERE StatusId = 1 )
	BEGIN
		SELECT @ErrCode = 1001067
				,@ErrMsg = 'WARNING! Cannot continue due to Source Match is having waiting tickets'
		RETURN
	END

	SET @remoteQuery = 'SELECT oddsid, bettype, liveindicator, ResourceId 
						FROM DBPRO.bodb02.dbo.OddsES o WITH(NOLOCK)
						WHERE o.matchid = ' + CAST (@DestinationMatchId AS NVARCHAR(20) )
						+' AND ISNULL(o.IsDeleted,0) = 0 '
		
	INSERT INTO #tmpNewOdds ( oddsid, bettype, liveindicator, ResourceId )
	EXEC sys.sp_executesql @remoteQuery

	IF ( SELECT COUNT(1) FROM #tmpNewOdds ) = 0
	BEGIN
		SELECT @ErrCode = 1001064
				,@ErrMsg = 'WARNING! Cannot continue due to: No having Corresponding Oddsid'
		RETURN
	END
	
	
	IF EXISTS (
				SELECT TOP 1 1
				FROM #tmpTransIds tr
					LEFT JOIN #tmpNewOdds o 
						ON tr.bettype = o.bettype
						AND tr.liveindicator = o.liveindicator
						AND ( tr.BetId = 0 OR CHARINDEX(o.ResourceId, CAST(tr.betid AS VARCHAR)) > 0 )
				WHERE o.oddsid IS NULL
			)
	BEGIN
		SELECT @ErrCode = 1001065
				, @ErrMsg = 'WARNING! Cannot continue due to: No having Corresponding Oddsid'
		RETURN
	END

END
GO