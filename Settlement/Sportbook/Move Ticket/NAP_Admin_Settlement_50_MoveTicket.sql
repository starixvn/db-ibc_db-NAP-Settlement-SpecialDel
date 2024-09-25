/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_50_MoveTicket
	@MatchId		INT
	,@AdminId		INT
	,@eventdate		DATETIME
	,@ChildMatchId  INT
	,@Resources		VARCHAR(MAX) = ''
	,@IP			VARCHAR(15) = ''
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
	,@TicketCount INT = 0 OUTPUT
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: DBTXN/BODB02

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20220110@Kathy: Update winlostdate = eventdate if these values are different [Redmine:#167246]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Louisa: Scale out DBTRANS [Redmine:#175251]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		- 20230920@Kathy: remove write log on SP [Redmine:#194268]
		- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Action VARCHAR(20)
			,@Mode VARCHAR(15)
			,@avaiableProcess BIT
			,@Threshold INT = 0 -- over @Threshold, the parlay process will be locked in systemsetting
			
			,@IsExistParlay		BIT = 0
			,@IsLockingByRefno	BIT = 0
			,@totalSingle INT 
			,@totalParlay INT 
			,@startRowId INT 
			,@batchNo INT 
			,@strTransIds VARCHAR(MAX) 
			,@IsCentral	BIT = 0
			
	SELECT @Action = 'MoveTicket'
		,@batchNo = 2000

	DECLARE @tmpResourceId TABLE (ResourceId VARCHAR(20))
	DECLARE @tmpBettypeResourceId TABLE (Bettype SMALLINT, BetId BIGINT, ResourceId VARCHAR(20) )

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	CREATE TABLE #tmpTransIdsSingle (
		 RowId			INT IDENTITY(1,1) PRIMARY KEY
		,TransId		BIGINT
		,statusId		TINYINT
		,ResourceId		VARCHAR(20)
		,IsMarked		BIT DEFAULT(0) 
		,MainMatchId	INT
	)
	CREATE TABLE #tmpTransIdsParlay (
		 RowId			INT IDENTITY(1,1) PRIMARY KEY
		,TransId		BIGINT
		,statusId		TINYINT
		,MainTransId	BIGINT
		,refno			BIGINT
		,ResourceId		VARCHAR(20)
		,IsMarked		BIT DEFAULT(0)
		,MainMatchId	INT
	)
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

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
	SELECT [value] FROM STRING_SPLIT(@Resources, ',') tm

	INSERT INTO @tmpBettypeResourceId(Bettype, BetId, ResourceId)
	SELECT	s.BetType, s.BetID, t.ResourceID
	FROM	@tmpResourceId t
		CROSS APPLY (
			SELECT	s.BetType, s.BetID
			FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			WHERE	s.SportType IN (8, 50)
					AND 1 = CASE 
								WHEN s.sporttype = 8 AND s.bettype IN (8832, 8833, 8834, 8835) THEN 1
								WHEN s.sporttype = 50 THEN 1
								ELSE 0
							END
					AND (s.ResourceID = t.ResourceId
						OR s.RefResourceId = t.ResourceId)
		)s

	INSERT INTO #tmpTransIdsSingle(TransId, statusId, ResourceId, IsMarked, MainMatchId)
	SELECT	b.transid, b.statusID, t.ResourceId
	, CASE WHEN m.TransId IS NOT NULL THEN 1 ELSE NULL END AS IsMarked
	, CASE WHEN (m.TransId IS NOT NULL) OR (b.statusID = 102) THEN @MatchId ELSE NULL END --marked or voided
	FROM	dbo.bettrans b WITH(NOLOCK)
		CROSS APPLY (
			SELECT TOP 1 t.Bettype, t.BetId, t.ResourceId
			FROM	@tmpBettypeResourceId t
			WHERE	t.Bettype = b.bettype
					AND (t.BetId = 0 OR t.BetId = b.betid)
		)t	
		LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.TransId = m.TransId
	WHERE	b.matchid = @MatchId
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		
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
		AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
	
	SET @totalParlay = @@ROWCOUNT
	SET @TicketCount = @totalSingle + @totalParlay

	IF @totalSingle = 0
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		  ,@IsReleased		= 1
		
		IF @totalParlay = 0
		BEGIN		
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
						,IsMarked AS '@im'
						,MainMatchId AS '@m_mid'
				FROM	#tmpTransIdsSingle 
				WHERE	RowId > @startRowId AND RowId <= @startRowId + @batchNo
				FOR XML PATH('r'), ROOT('root'))

			IF ISNULL(@strTransIds,'')  = ''
				BREAK

			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @childMatchId
				,@Action = @Action
				,@Mode = @Mode
				,@eventdate = @eventdate
				,@strTransIds = @strTransIds

			SET @startRowId = @startRowId + @batchNo
		END
	END

	IF @totalSingle > 0
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			,@IsReleased		= 1
	
	--move parlay
	IF @totalParlay > 0
	BEGIN
		UPDATE  t
			SET MainTransId = b.transid
			   ,IsMarked = CASE WHEN m.TransId IS NOT NULL THEN 1 ELSE 0 END
			   ,MainMatchId = @MatchId
		FROM	#tmpTransIdsParlay t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.refno = b.refno
			LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) 
				ON b.TransId = m.TransId AND m.MatchId = @MatchId
		WHERE	b.matchid = 29
			AND	1 = CASE WHEN t.statusId = 102 THEN 1
					     WHEN m.TransId IS NOT NULL THEN 1
						 ELSE 0 END

		EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @Threshold OUTPUT

		IF @totalParlay > @Threshold
			SET @isexistParlay = 1
		ELSE
		BEGIN
			INSERT INTO #tblMatchParlayProcess(matchId, RefNo)
			SELECT @MatchId, refno
			FROM #tmpTransIdsParlay
			GROUP BY refno

			SET @IsLockingByRefno = 1
		END

		EXEC dbo.NAP_Admin_CheckingProcess		
			 @isexistParlay				= @isexistParlay
			,@IsLockingByRefno			= @IsLockingByRefno
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
						,CASE WHEN (statusid = 102 OR IsMarked = 1) THEN MainTransId ELSE NULL END AS '@mt'
						,IsMarked AS '@im'
						,MainMatchId AS '@m_mid'
				FROM	#tmpTransIdsParlay 
				WHERE	RowId > @startRowId AND RowId <= @startRowId + @batchNo
				FOR XML PATH('r'), ROOT('root'))

			IF ISNULL(@strTransIds,'')  = ''
				BREAK

			EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @childMatchId
				,@Action = @Action
				,@Mode = @Mode
				,@strTransIds = @strTransIds
				,@matchdate = @eventdate

			SET @startRowId = @startRowId + @batchNo
		END

		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay		= @IsExistParlay
			,@IsLockingByRefno  = @IsLockingByRefno
			,@IsReleased		= 1

	END

	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpTransIdsSingle
	DROP TABLE #tmpTransIdsParlay

	RETURN

END