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

	DECLARE  @matchcode NVARCHAR(100), @leagueid INT, @homeid INT, @awayid INT, @eventdate DATETIME, @eventstatus NVARCHAR(100)
			 ,@des_leagueid INT, @des_homeid INT, @des_awayid INT, @des_eventdate DATETIME, @des_eventstatus NVARCHAR(100)

	IF OBJECT_ID('tempdb..#tmpTransIds') IS NULL
	CREATE TABLE #tmpTransIds	( RowId INT IDENTITY(1,1) PRIMARY KEY, custid INT, transid BIGINT, oddsid INT,  bettype SMALLINT, BetId INT, liveindicator BIT, StatusId TINYINT, srecommend INT)
	
	IF OBJECT_ID('tempdb..#tmpNewOdds') IS NULL
	CREATE TABLE #tmpNewOdds	( oddsid INT, bettype SMALLINT, liveindicator BIT, ResourceId VARCHAR(20) )

	SELECT	 @matchcode		= m.matchcode		 
			, @leagueid		= m.leagueid
			, @homeid		= m.homeid
			, @awayid		= m.awayid
			, @eventdate	= m.eventdate
			, @eventstatus	= m.eventstatus
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @MatchId
		AND m.sporttype = @Sporttype
		AND ISNULL(m.IsDeleted,0) = 0

	SELECT	 @des_leagueid		= m.leagueid
			, @des_homeid		= m.homeid
			, @des_awayid		= m.awayid
			, @des_eventdate	= m.eventdate
	FROM dbo.match m WITH(NOLOCK)
	WHERE m.matchid = @DestinationMatchId
		AND m.sporttype = @Sporttype
		AND ISNULL(m.IsDeleted,0) = 0 
	
	SELECT	@ErrCode = CASE WHEN @matchcode IS NULL OR @matchcode LIKE 'betdaq%' OR @des_leagueid IS NULL THEN 1001001
							WHEN @eventstatus NOT IN ('closed','postponed','internal') THEN 1001058
							WHEN @leagueid <> @des_leagueid THEN 1001059
							WHEN @homeid <> @des_homeid OR @awayid <> @des_awayid THEN 1001060
							WHEN @eventdate <> @des_eventdate THEN 1001061
						ELSE NULL
						END
			,@ErrMsg = CASE WHEN @matchcode IS NULL OR @matchcode LIKE 'betdaq%' OR @des_leagueid IS NULL THEN 'Match does not exist!'
							WHEN @eventstatus NOT IN ('closed','postponed','internal') THEN 'WARNING! Cannot continue due to: Status of source match should be closed, postponed or internal'
							WHEN @leagueid <> @des_leagueid THEN  'WARNING! Cannot continue due to: Matches should be in same league'
							WHEN @homeid <> @des_homeid OR @awayid <> @des_awayid THEN 'WARNING! Cannot continue due to: Team names of matches should be the same'
							WHEN @eventdate <> @des_eventdate THEN  'WARNING! Cannot continue due to: Eventdate of matches should be the same'
						ELSE NULL
						END
			
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

	IF EXISTS ( SELECT TOP 1 1 FROM dbo.bettrans b WITH(NOLOCK) 
				WHERE b.matchid = @MatchId
					AND 1 =  CASE WHEN b.statusID = 1 THEN 1
								  WHEN b.statusID = 0 AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 1
							ELSE 0
							END				
				)
	BEGIN
		SELECT @ErrCode = 1001067
				,@ErrMsg = 'WARNING! Cannot continue due to Source Match is having waiting tickets'
		RETURN
	END

	INSERT INTO #tmpTransIds ( custid, transid, oddsid,  bettype, BetId, liveindicator, StatusId, srecommend )
	SELECT b.custid, b.transid, b.oddsid,  b.bettype, b.BetId, b.liveindicator, b.statusID, b.srecommend
	FROM dbo.bettrans b WITH(NOLOCK)
		LEFT JOIN dbo.MarkedTransaction mk WITH(NOLOCK)
			ON b.transid = mk.TransId
	WHERE b.matchid = @MatchId
		AND b.statusID = 0
		AND mk.TransId IS NULL

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT @ErrCode = 1001063
				,@ErrMsg = 'WARNING! Cannot continue due to: Current has no valid ticket to move'
		RETURN
	END

	SET @remoteQuery = 'SELECT oddsid, bettype, liveindicator, ResourceId 
						FROM DBPRO.bodb02.dbo.OddsES o WITH(NOLOCK)
						WHERE o.matchid = ' + CAST (@DestinationMatchId AS NVARCHAR(20) )
						+' AND ISNULL(o.IsDeleted,0) = 0 '
		
	INSERT INTO #tmpNewOdds ( oddsid, bettype, liveindicator, ResourceId )
	EXEC sys.sp_executesql @remoteQuery
	
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