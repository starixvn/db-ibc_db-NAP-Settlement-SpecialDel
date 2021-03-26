/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_50_MoveTicket
	@MatchId INT
	,@AdminId INT
	,@IP VARCHAR(15) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: DBTXN/BODB02

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Action VARCHAR(20)
			,@Mode VARCHAR(15) 
			,@eventdate DATETIME
			,@eventstatus NVARCHAR(100)
			,@childMatchId INT
			,@avaiableProcess BIT
			,@totalSingle INT 
			,@totalParlay INT 
			,@startRowId INT 
			,@batchNo INT 
			,@strTransIds VARCHAR(MAX) 
			,@sqlRemoteQuery NVARCHAR(MAX) 

			,@StartTime DATETIME
			,@EndTime DATETIME
			,@ActionID INT 
			,@logdata VARCHAR(300) 
			,@ResourceIds VARCHAR(MAX) = ''
			,@Remark VARCHAR(MAX)
			
	SELECT @Action = 'MoveTicket'
		,@batchNo = 2000
		,@ActionID = 81025		
		,@StartTime = GETDATE()
		
	DECLARE @tmpResourceId TABLE (ResourceId VARCHAR(20))
	DECLARE @tmpBettypeResourceId TABLE (Bettype SMALLINT, BetId BIGINT, ResourceId VARCHAR(20) )

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpTransIdsSingle (RowId INT IDENTITY(1,1) PRIMARY KEY, TransId BIGINT, statusId TINYINT, ResourceId VARCHAR(20) )
	CREATE TABLE #tmpTransIdsParlay (RowId INT IDENTITY(1,1) PRIMARY KEY, TransId BIGINT, statusId TINYINT, MainTransId BIGINT, refno BIGINT, ResourceId VARCHAR(20) )

	SELECT	@eventdate = m.eventdate
			,@eventstatus = m.eventstatus
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	IF @eventstatus = 'completed'
		BEGIN
			SELECT	@ErrCode = 1001050
					,@ErrMsg = 'WARNING! Cannot continue due to current match is completed.'
		
			RETURN
	END
	
	SELECT	TOP 1 @childMatchId = matchid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.ParentID = @MatchId
			AND m.ChildMatchType = 200
			AND m.eventdate = @eventdate
	ORDER BY m.matchid

	IF @@ROWCOUNT = 0
	BEGIN
		SELECT	@ErrCode = 1001048
				,@ErrMsg = 'WARNING! Cannot continue due to destination match not found.'
		
		RETURN
	END

	INSERT INTO #tblMatchProcess(matchid, KeyID)
	VALUES (@MatchId, 1), (@childMatchId, 1)

	EXEC dbo.NAP_Admin_CheckingProcess		
		 @isExistMatch				= 1		
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		RETURN
	
	SET @sqlRemoteQuery = ' SELECT	ResourceID 
							FROM DBPRO.bodb02.dbo.ResultDetailOS WITH(NOLOCK)
							WHERE	matchid = ' + CAST (@MatchId AS VARCHAR) + '
									AND ResultStatusID = 5'

	INSERT INTO @tmpResourceId(ResourceId)
	EXECUTE sys.sp_executesql @sqlRemoteQuery

	INSERT INTO @tmpBettypeResourceId(Bettype, BetId, ResourceId)
	SELECT	s.BetType, s.BetID, t.ResourceID
	FROM	@tmpResourceId t
		CROSS APPLY (
			SELECT	s.BetType, s.BetID
			FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			WHERE	s.SportType = 50
					AND (s.ResourceID = t.ResourceId
						OR s.RefResourceId = t.ResourceId)
		)s

	INSERT INTO #tmpTransIdsSingle(TransId, statusId, ResourceId)
	SELECT	b.transid, b.statusID, t.ResourceId
	FROM	dbo.bettrans b WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 t.Bettype, t.BetId, t.ResourceId
			FROM	@tmpBettypeResourceId t
			WHERE	t.Bettype = b.bettype
					AND (t.BetId = 0 OR t.BetId = b.betid)
		)t				
	WHERE	b.matchid = @MatchId
		
	SET @totalSingle = @@ROWCOUNT

	INSERT INTO #tmpTransIdsParlay(TransId, statusId, refno, ResourceId)
	SELECT	bm.transid, bm.statusID, bm.refno, t.ResourceId
	FROM	dbo.bettransm bm WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 t.Bettype, t.BetId, t.ResourceId
			FROM	@tmpBettypeResourceId t
			WHERE	t.Bettype = bm.bettype
					AND (t.BetId = 0 OR CAST(t.Betid AS NVARCHAR(50)) = bm.betcheck)
		)t				
	WHERE	bm.matchid = @MatchId
	
	SET @totalParlay = @@ROWCOUNT

	IF @totalSingle = 0
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		  ,@IsReleased		= 1
		
		IF @totalParlay = 0
		BEGIN
			SELECT	@ErrCode = 1001049
					,@ErrMsg = 'WARNING! Cannot continue due to current has no valid ticket to move.'
		
			RETURN
		END
	END
	
	-- move single
	IF @totalSingle > 0
	BEGIN
		SET @startRowId = 0
		SET @strTransIds = ''
		SET @Mode = 'Single'

		WHILE (1=1)
		BEGIN
			SET @strTransIds = ''

			SET @strTransIds = (
				SELECT	TOP (@batchNo) transid AS '@t'
						,CASE WHEN statusId = 102 THEN statusId ELSE NULL END AS '@s'
				FROM	#tmpTransIdsSingle 
				WHERE	RowId > @startRowId AND RowId <= @startRowId + @batchNo
				FOR XML PATH('r'), ROOT('root'))

			IF ISNULL(@strTransIds,'')  = ''
				BREAK

			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @childMatchId
				,@Action = @Action
				,@Mode = @Mode
				,@strTransIds = @strTransIds

			SET @startRowId = @startRowId + @batchNo
		END
	END
	
	-- set child match completed
	 EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update 
        @Command            = 'NAP_Admin_Settlement_1-CAL'
        ,@MatchID            = @childMatchId
        ,@FTHome            = 0
        ,@FTAway            = 0
        ,@HTHome            = 0
        ,@HTAway            = 0
        ,@Action            = 'CAL'
		,@IsMovedMatch		= 1

	EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark 
		@matchid    = @childMatchId
		,@command    = 'C'
		,@IsMovedMatch = 1

	IF @totalSingle > 0
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			,@IsReleased		= 1
	
	--move parlay
	IF @totalParlay > 0
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #tmpTransIdsParlay WHERE statusId = 102)
			UPDATE  t
				SET MainTransId = b.transid
			FROM	#tmpTransIdsParlay t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.refno = b.refno
			WHERE	b.matchid = 29
					AND t.statusId = 102
				
		EXEC dbo.NAP_Admin_CheckingProcess		
			 @isexistParlay				= 1		
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			RETURN

		-- move parlay
		SET @startRowId = 0
		SET @strTransIds = ''
		SET @Mode = 'subParlay'
		
		WHILE (1=1)
		BEGIN
			SET @strTransIds = ''

			SET @strTransIds = (
				SELECT	TOP (@batchNo) transid AS '@t'
						,CASE WHEN statusid = 102 THEN statusId ELSE NULL END AS '@s'
						,CASE WHEN statusid = 102 THEN MainTransId ELSE NULL END AS '@mt'
				FROM	#tmpTransIdsParlay 
				WHERE	RowId > @startRowId AND RowId <= @startRowId + @batchNo
				FOR XML PATH('r'), ROOT('root'))

			IF ISNULL(@strTransIds,'')  = ''
				BREAK

			EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @childMatchId
				,@Action = @Action
				,@Mode = @Mode
				,@strTransIds = @strTransIds

			SET @startRowId = @startRowId + @batchNo
		END
	END

	SELECT @ResourceIds = COALESCE( @ResourceIds + ',' + r.ResourceId, r.ResourceId)
	FROM (
			SELECT  ResourceId FROM	#tmpTransIdsSingle
			UNION ALL
			SELECT  ResourceId FROM	#tmpTransIdsParlay
		) r
		GROUP BY r.ResourceId


	SELECT @ResourceIds = STUFF(@ResourceIds, 1, 1, '')

	SET @EndTime = GETDATE()

	SELECT @Remark =  CAST(@childMatchId AS VARCHAR) + '<br/> ' 
						+ '(' + @ResourceIds + ')' + '<br/>'
						+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS NVARCHAR(50)) + ' ms' 
						+ '; TC: ' + CAST(ISNULL(@totalSingle, 0) AS VARCHAR(20))  + '/' + CAST(ISNULL(@totalParlay, 0) AS VARCHAR(20)) 				
				
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


	IF @totalParlay > 0
	BEGIN
		-- settle parlay
		EXEC dbo.NAP_Admin_Settlement_MP
		@matchid				= @childMatchId
		,@creator				= @AdminId
		,@action				= 'CAL'
		,@isAuto				= 1
		,@IP					= @IP
		,@ErrCode				= @ErrCode	OUTPUT
		,@ErrMsg				= @ErrMsg	OUTPUT

		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay		= 1
			,@IsReleased		= 1
	END

	SELECT @logdata = 'Move ticket of matchid: ' + CAST(@matchid AS VARCHAR) 
				+' into child match: ' + CAST(@childMatchId AS VARCHAR)
				+ ',Settled Results: (' + @ResourceIds + ')'
						   
	EXEC dbo.WriteLog_UserLog
				@UserID = @AdminId
				,@Doing = @logdata
									   

	RETURN

END