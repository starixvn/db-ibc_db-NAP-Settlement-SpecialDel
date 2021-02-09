ALTER PROCEDURE dbo.NAP_Settlement_MoveTicket
	@MatchId INT
	,@AdminId INT
	,@IP VARCHAR(50) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @eventdate DATETIME
			,@childMatchId INT
			,@isExistParlay				BIT = 0
			,@avaiableProcess BIT
			,@logdata VARCHAR(300) = ''
			,@Remark VARCHAR(MAX) = ''
			,@ActionID INT = 11111
			,@ResourceIds VARCHAR(MAX) = ''

	DECLARE @tmpResourceId TABLE (ResourceId VARCHAR(20))
	DECLARE @tmpBettypeResourceId TABLE (Bettype SMALLINT, BetId BIGINT, ResourceId VARCHAR(20))

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpTransIdsSingle (TransId BIGINT PRIMARY KEY)
	CREATE TABLE #tmpTransIdsParlay (TransId BIGINT PRIMARY KEY)

	SELECT	@eventdate = m.eventdate
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	SELECT	TOP 1 @childMatchId = matchid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.ParentID = @MatchId
			AND m.ChildMatchType = 200
			AND m.eventdate = @eventdate
	ORDER BY m.matchid

	INSERT INTO #tblMatchProcess(matchid, KeyID)
	VALUES (@MatchId, 1), (@childMatchId, 1)

	EXEC dbo.NAP_Admin_CheckingProcess		
		 @isExistMatch				= 1		
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		RETURN
	
	INSERT INTO @tmpResourceId(ResourceId)
	SELECT	ResourceID 
	FROM DBPRO.bodb02.dbo.ResultDetailOS WITH(NOLOCK)
	WHERE	matchid = @MatchId
			AND ResultStatusID = 5

	INSERT INTO @tmpBettypeResourceId(Bettype, BetId, ResourceId)
	SELECT	s.BetType, s.BetID, t.ResourceID
	FROM	@tmpResourceId t
		CROSS APPLY (
			SELECT	s.BetType, s.BetID
			FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			WHERE	s.SportType = 1
					AND (s.ResourceID = t.ResourceId
						OR s.RefResourceId = t.ResourceId)
		)s

	INSERT INTO #tmpTransIdsSingle(TransId)
	SELECT	b.transid
	FROM	dbo.bettrans b WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 t.Bettype, t.BetId, t.ResourceId
			FROM	@tmpBettypeResourceId t
			WHERE	t.Bettype = b.bettype
					AND (t.BetId = 0 OR t.BetId = b.betid)
		)t				
	WHERE	b.matchid = @MatchId
			
	IF @@ROWCOUNT = 0
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		  ,@IsReleased		= 1

		SELECT	@ErrCode = 1
				,@ErrMsg = 'WARNING! Cannot continue due to current has no valid ticket to move.'

		RETURN
	END

	-- move single
	UPDATE b WITH(UPDLOCK, ROWLOCK)
		SET matchid = @childMatchId
	FROM	dbo.bettrans b 
		INNER JOIN #tmpTransIdsSingle t
			ON b.transid = t.transid
	
	-- set child match completed
	 EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
        @Command            = 'NAP_Admin_Settlement_1-CAL'
        ,@MatchID            = @childMatchId
        ,@FTHome            = 0
        ,@FTAway            = 0
        ,@HTHome            = 0
        ,@HTAway            = 0
        ,@Action            = 'CAL'

	EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
		@matchid    = @childMatchId
		,@command    = 'C'

	EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			,@IsReleased		= 1

	INSERT INTO #tmpTransIdsParlay(TransId)
	SELECT	bm.transid
	FROM	dbo.bettransm bm WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 t.Bettype, t.BetId, t.ResourceId
			FROM	@tmpBettypeResourceId t
			WHERE	t.Bettype = bm.bettype
					AND (t.BetId = 0 OR CAST(t.Betid AS NVARCHAR(50)) = bm.betcheck)
		)t				
	WHERE	bm.matchid = @MatchId
			
	IF @@ROWCOUNT > 0
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess		
			 @isexistParlay				= 1		
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			RETURN
	END

	-- move parlay -- đi chung pub với settle
	UPDATE bm WITH(UPDLOCK, ROWLOCK)
		SET matchid = @childMatchId
	FROM	dbo.bettransm bm 
		INNER JOIN #tmpTransIdsParlay t
			ON bm.transid = t.transid

	-- betparlaydetail
	UPDATE d 
		SET matchid = @childMatchId
	FROM	dbo.BetParlayDetail d WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tmpTransIdsParlay t
			ON d.transid = t.TransId
	WHERE	matchid = @MatchId

	-- settle parlay
	EXEC dbo.NAP_Admin_Settlement_MP
	@matchid				= @childMatchId
	,@creator				= @AdminId
	,@action				= 'CAL'
	,@ErrCode				= @ErrCode	OUTPUT
	,@ErrMsg				= @ErrMsg	OUTPUT

	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistParlay		= 1
		,@IsReleased		= 1

	SELECT @logdata = 'Move ticket of matchid: ' + CAST(@matchid AS VARCHAR) 
				+' into child match: ' + CAST(@childMatchId AS VARCHAR)
				+ ',Result: (' + @ResourceIds + ')'
						   
						   
	SELECT @Remark =  CAST(@childMatchId AS VARCHAR) + '<br/> ' 
						+ '(' + @ResourceIds + ')'
						+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
						+ CASE WHEN @Action LIKE 'CAL%' THEN '; Recalc: ' + CAST (ISNULL(@IsReSettledTickets,0) AS VARCHAR(1)) ELSE '' END
						+ '; TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
						+ '; Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
				
				
				
	EXEC dbo.WriteLog_UserLog
				@UserID = @AdminId
				,@Doing = @logdata
				
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@userid				= @AdminId
				,@matchid			= @MatchID
				,@actionid			= @ActionID
				,@Remark			= @Remark
				,@ip				= @ip
	END TRY
	BEGIN CATCH
		SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@UserID				= @AdminId
				,@MatchID			= @matchid
				,@actionid			= @ActionID
				,@Remark			= @Remark
				,@IP				= @ip
	END CATCH

	RETURN

END