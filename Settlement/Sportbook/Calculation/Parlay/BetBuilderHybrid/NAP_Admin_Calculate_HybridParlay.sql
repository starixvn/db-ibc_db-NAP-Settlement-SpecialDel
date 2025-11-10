/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_HybridParlay] 
(
	@MatchId		INT
	,@Action		VARCHAR(20) = 'CAL'
	,@creator		INT
	,@IP			VARCHAR(15) = ''
	,@TransIds		VARCHAR(MAX) = ''
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = NULL OUTPUT
)
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation: 

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @refnos_29				VARCHAR(MAX) = ''
			,@MatchDate				DATETIME
			,@Sporttype				SMALLINT = NULL
			,@AvailableProcess		BIT
			,@SiteDBGroupId			SMALLINT = 0
			,@StartTime				DATETIME
			,@EndTime				DATETIME
			,@LogData				VARCHAR(MAX)
			,@SB_Error				BIT
			,@SpName				VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@MainParlay_MaxPO		VARCHAR(MAX) = NULL
			,@Session				NVARCHAR(50)
			,@ThreadHold			INT --over threadhold, the parlay process will be locked in systemsetting
			,@TotalSubParlay		INT = 0 
			,@SubTransIds			VARCHAR(MAX) = ''
			,@Transids_29			VARCHAR(MAX) = ''
			,@MoveBetDate			DATETIME
			,@ActionID				INT

	CREATE TABLE #tblMatchParlayProcess (MatchId INT, RefNo BIGINT)
	CREATE TABLE #tblHybridBet (
			MainTransId		BIGINT
			,TransId		BIGINT
			,MatchId		INT
			,RefNo			BIGINT
			,CustId			INT
			,Winlostdate	SMALLDATETIME
			,Ruben			TINYINT
			,Oddspread		MONEY
			,IsFinish		BIT
	)
	CREATE INDEX IX_RecoverBet ON #tblHybridBet (refno)

	CREATE TABLE #tblMainTicket
	(
		TransId		BIGINT
		,Refno		BIGINT
		,CustId		INT
		,Balance	MONEY
		,Ruben		TINYINT
	)

	DECLARE @tmpMainTransId TABLE (TransId BIGINT) 
	DECLARE @tmpTransIdBatch TABLE (TransId BIGINT)
	DECLARE @tmpMatchId TABLE (MatchId INT, MatchDate DATETIME, IsFinish BIT)

	SELECT @SiteDBGroupId = dbo.f_Get_SiteDBGroupID()

	SET @Session = CONVERT(NVARCHAR(50),NEWID())
	SET @StartTime = GETDATE()
	SET @SB_Error = 0

	SELECT @ActionID = CASE 
							WHEN @Action LIKE 'CAL%' THEN 81028 -- new action Id
							WHEN @Action LIKE 'REFUND%' THEN 81029 
							WHEN @Action LIKE 'UNDO%' THEN IIF(@Action = 'UNDO-FT', 81041,81030)
						END

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MoveBetDate OUTPUT

	SELECT @MatchDate = eventdate
		  ,@Sporttype = sporttype
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId

	IF @MatchDate <= @MoveBetDate
	BEGIN
		SELECT @ErrCode = 99, @ErrMsg = 'Could not calculate some tickets due to Movebet process. Please try search again.'
		RETURN
	END

	IF @TransIds <> ''
	BEGIN
		DECLARE @tmp_TransId TABLE (TransId BIGINT)
		INSERT INTO @tmp_TransId (TransId)
		SELECT DISTINCT j.TransId
		FROM (
				SELECT js.MatchId AS MatchId, js.TransId AS TransId, js.Odds AS Odds
				FROM OPENJSON(@LegOddsJSON) WITH (MatchId INT, TransId BIGINT, Odds MONEY) js
		)j

		INSERT INTO #tblHybridBet
		(
			TransId
			,MatchId
			,RefNo
			,CustId
			,Winlostdate
			,Ruben
			,Oddspread
			,MainTransId
		)
		SELECT 
			bm.TransId
			,bm.matchid
			,bm.refno
			,b.custid
			,bm.winlostdate
			,b.ruben
			,b.oddsspread
			,b.TransId
		FROM @tmp_TransId t
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.TransId = t.TransId
		INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.refno
		LEFT JOIN dbo.MarkedTransaction mt WITH (NOLOCK) ON bm.TransId = mt.TransId AND mt.MatchId = @MatchId
		WHERE bm.matchid = @MatchId
			AND bm.SiteDBGroupID = @SiteDBGroupId
			AND b.bettype = 29
			AND b.oddsspread = 3
			AND bm.statuswinlost IS NOT NULL
			AND mt.TransId IS NULL

		SET @TotalSubParlay = @@ROWCOUNT
	END
	ELSE
	BEGIN
		INSERT INTO #tblHybridBet
		(
			TransId
			,MatchId
			,RefNo
			,CustId
			,Winlostdate
			,Ruben
			,Oddspread
			,MainTransId
		)
		SELECT 
			bm.TransId
			,bm.matchid
			,bm.refno
			,b.custid
			,bm.winlostdate
			,b.ruben
			,b.oddsspread
			,b.TransId
		FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
		LEFT JOIN dbo.MarkedTransaction mt WITH (NOLOCK) ON bm.TransId = mt.TransId AND mt.MatchId = @MatchId
		WHERE bm.matchid = @MatchId
			AND bm.SiteDBGroupID = @SiteDBGroupId
			AND b.bettype = 29
			AND b.oddsspread = 3
			AND bm.statuswinlost IS NOT NULL
			AND mt.TransId IS NULL

		SET @TotalSubParlay = @@ROWCOUNT
	END

	INSERT INTO @tmpMainTransId (TransId)
	SELECT DISTINCT MainTransId
	FROM #tblHybridBet

	INSERT INTO #tblMainTicket(TransId, Refno, CustId, Balance, Ruben)
	SELECT b.TransId
		,b.refno
		,b.custid
		,b.winlost - b.actual_stake + b.playercomm AS balance
		,b.ruben
	FROM @tmpMainTransId AS t
	INNER JOIN bettrans AS b WITH (NOLOCK) ON b.TransId = t.TransId
	
	INSERT INTO #tblMatchParlayProcess(MatchId, RefNo)
	SELECT DISTINCT t.matchid, t.refno
	FROM #tblHybridBet AS t

	EXEC dbo.NAP_Set_GlobalSettingSel
		@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	-- Apply new way to lock parlay tickets	
	IF @TotalSubParlay <= @ThreadHold
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefno		= 1
			,@SPName				= @SPName
			,@Session				= @Session
			,@avaiableProcess 		= @AvailableProcess OUTPUT
			,@ErrCode				= @ErrCode OUTPUT
			,@ErrMsg				= @ErrMsg OUTPUT
	END
	ELSE --@totalSubParlay > 10K
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess  
			@isExistParlay		= 1  
			,@avaiableProcess	= @AvailableProcess OUTPUT  
			,@ErrCode			= @ErrCode OUTPUT  
			,@ErrMsg			= @ErrMsg OUTPUT  
	END

	IF @AvailableProcess = 0 OR @ErrCode <> 0
	BEGIN
		RETURN
	END

	BEGIN TRY
		--For BettransM
		WHILE (1 = 1)
		BEGIN
			DELETE @tmpTransIdBatch
			SET @SubTransIds = ''

			UPDATE TOP (2000) t
			SET t.IsFinish = 1
				OUTPUT deleted.TransId
				INTO @tmpTransIdBatch(TransId)
			FROM #tblHybridBet AS t
			WHERE t.IsFinish IS NULL AND t.MatchId = @MatchId

			IF @@ROWCOUNT = 0 BREAK

			SELECT @SubTransIds = @SubTransIds + CONVERT(VARCHAR(50),TransId) + ','
			FROM @tmpTransIdBatch

			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchid = @MatchId
				,@matchdate = @MatchDate
				,@mode = 'Hybrid_m' --Update bettransm + betparlaydetail
				,@strTransIds = @SubTransIds
		END

		SELECT @Transids_29 = @Transids_29 + CONVERT(VARCHAR(50), transid) + ','
		FROM #tblMainTicket

		--Call pre-cal: betparlaydetail/betparlayresult
		EXEC dbo.NAP_Admin_Calculate_MP_Broker
			@matchid	 = @MatchId
			,@matchdate  = @MatchDate
			,@strXML	 = @Transids_29
			,@mode		 = 'PRECAL-29'

		SELECT @refnos_29 = @refnos_29 + CONVERT(VARCHAR(50),refno) + '|' + CONVERT(VARCHAR(50),transid) + ','
		FROM #tblMainTicket

		--Call cal_29: resettle for main ticket
		EXEC dbo.NAP_Admin_Calculate_MP_broker
			@matchdate = @MatchDate -- main transid + refno: refno|transid,refno|transid...
		   , @strXML	   = @refnos_29
		   , @mode	   = '29'
		   , @ActionId = @ActionId
		   , @IsCalculateBalance = 1
		   , @AffectedTransIds = @MainParlay_MaxPO OUTPUT
		
		--Insert max payout queue
		EXEC dbo.NAP_Set_CustLimitBetQueue_Insert_Parlay
			@TransIds = @MainParlay_MaxPO
		
		--Release lock
		IF @TotalSubParlay <= @ThreadHold
		BEGIN 
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
			   ,@Session		  = @Session
			   ,@IsReleased		  = 1
		END
		ELSE
		BEGIN
			--release parlay process
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsExistParlay = 1
			   ,@IsReleased    = 1
		END
	END TRY
	BEGIN CATCH
		IF @TotalSubParlay <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefnO = 1
			   ,@Session		  = @Session
			   ,@IsReleased       = 1
		END
		ELSE
		BEGIN
			--release parlay process
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsExistParlay = 1
			   ,@IsReleased    = 1
		END

		SELECT @ErrCode = 100, @ErrMsg = 'Unable to calculate these parlay bets'

		RETURN
	END CATCH

	--Write useraction log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	/*Comming soon*/

	DROP TABLE #tblHybridBet
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tblMainTicket

END