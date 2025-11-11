/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_HybridParlay_LegOddsUpd]
	@MatchId		INT
	,@LegOddsJSON	NVARCHAR(MAX)
	,@creator		INT
	,@IP			VARCHAR(15) = ''
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = NULL OUTPUT
	,@AffectedTransIds	VARCHAR(MAX) = NULL OUTPUT
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
		@LegOddsJSON:  [{"MatchId": 987456,"TransId": 12,"Odds": 2.5},
						{ "MatchId": 123456,"TransId": 13,"Odds": 1.5}]        

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@Session			NVARCHAR(50)
		    ,@ThreadHold		INT = 0 -- over threadhold, the parlay process will be locked in systemsetting 
		    ,@SPName			VARCHAR(500) = OBJECT_NAME(@@PROCID)			
			,@SitedbgroupId		SMALLINT 
			,@avaiableProcess	BIT
			,@totalRefNo		INT = 0
			,@strLegOdds		VARCHAR(MAX)
			,@StartTime			DATETIME
			,@EndTime			DATETIME
			,@ActionID			INT = 81067

	CREATE TABLE #tmpLegOddsInfo (MatchId INT, TransId BIGINT, Odds MONEY, RefNo BIGINT, transdesc NVARCHAR(2000))
	CREATE TABLE #tmpMaxTransIdUpdateLeg(TransId BIGINT, Refno BIGINT, MatchId INT, Odds MONEY, IsFinish BIT, OrgOdds MONEY)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #tmpMaxTransIdProcessBatch (TransId BIGINT, Refno BIGINT, MatchId INT, Odds MONEY)

	SET @Session = CONVERT(NVARCHAR(50),NEWID())
	SET @StartTime = GETDATE()
	SET @SB_Error = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @IsCentral BIT = 0	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO #tmpLegOddsInfo (MatchId, TransId, Odds, RefNo, transdesc)
	SELECT j.MatchId, j.TransId, j.Odds, b.refno, b.transdesc
	FROM (
			SELECT js.MatchId AS MatchId, js.TransId AS TransId, js.Odds AS Odds
			FROM OPENJSON(@LegOddsJSON) WITH (MatchId INT, TransId BIGINT, Odds MONEY) js
	)j
	INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = j.TransId
	WHERE b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		AND b.bettype = 29
		AND b.matchid = 29
		AND b.oddsspread = 3

	INSERT INTO #tmpMaxTransIdUpdateLeg (Refno, MatchId, Odds, TransId, OrgOdds)
	SELECT t.RefNo, t.MatchId, t.Odds, bm.MaxSubTransId, j.OrgOdds
	FROM #tmpLegOddsInfo t
	CROSS APPLY (
			SELECT 
				m AS OrgMatch,
				o AS OrgOdds
			FROM OPENJSON(t.transdesc)
			WITH (
				m BIGINT '$.m',
				o MONEY '$.o'
			)
			WHERE m = @MatchId
		 )j
		CROSS APPLY (
				SELECT MAX(bm.transID) AS MaxSubTransId
				FROM dbo.bettransm bm WITH (NOLOCK)
				WHERE bm.refno = t.RefNo
					AND bm.matchid = t.MatchId
		)bm
	
	SET @totalRefNo = @@ROWCOUNT

	IF @totalRefNo = 0
	BEGIN
		SELECT @ErrCode = 99  
				,@ErrMsg = 'No parlay ticket found.'  

		RETURN
	END
	
	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
	   ,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
	SELECT MatchId, refno
	FROM #tmpMaxTransIdUpdateLeg

	BEGIN TRY
		-- Apply new way to lock parlay tickets	
		IF @totalRefNo <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno		= 1
				,@SPName				= @SPName
				,@Session				= @Session
				,@avaiableProcess 		= @avaiableProcess OUTPUT
				,@ErrCode				= @ErrCode OUTPUT
				,@ErrMsg				= @ErrMsg OUTPUT
		END
		ELSE --@totalSubParlay > 10K
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay		= 1  
				,@avaiableProcess	= @avaiableProcess OUTPUT  
				,@ErrCode			= @ErrCode OUTPUT  
				,@ErrMsg			= @ErrMsg OUTPUT  
		END

		IF @avaiableProcess = 0 OR @ErrCode <> 0
		BEGIN 
			RETURN
		END

		WHILE(1=1)
		BEGIN
			TRUNCATE TABLE #tmpMaxTransIdProcessBatch

			UPDATE TOP(2000) t SET t.IsFinish = 1 
				OUTPUT inserted.TransId, inserted.MatchId, inserted.Refno, inserted.Odds
				INTO #tmpMaxTransIdProcessBatch (TransId, MatchId, Refno, Odds)
			FROM #tmpMaxTransIdUpdateLeg t
			WHERE t.IsFinish IS NULL

			IF @@ROWCOUNT = 0 
			BEGIN
				BREAK
			END

			SELECT @strLegOdds = (
				SELECT b.TransId AS 'TransId'
					,b.MatchId AS 'MatchId'
					,b.Refno AS 'Refno'
					,b.Odds AS 'Odds'
				FROM #tmpMaxTransIdProcessBatch b
				FOR JSON AUTO)
		
			EXEC dbo.NAP_Admin_Calculate_MP_broker   
				@MatchId	= @MatchId
				,@strXML = @strLegOdds  
				,@mode  = 'updateleg'

			--Insert history
			INSERT INTO dbo.BetBuilderLegOddsHistory (MatchId, RefNo, TransId, Oddds)
			SELECT t.MatchId, t.Refno, t.TransId, Odds
			FROM #tmpMaxTransIdProcessBatch t
		END

		IF @totalRefNo <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
						@IsLockingByRefno = 1
					   ,@Session	= @Session
					   ,@IsReleased = 1
		END
		ELSE 
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess  
					@isExistParlay  = 1  
					,@IsReleased  = 1 
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		IF @totalRefNo <= @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
						@IsLockingByRefno = 1
					   ,@Session	= @Session
					   ,@IsReleased = 1
		END
		ELSE 
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess  
					@isExistParlay  = 1  
					,@IsReleased  = 1 
		END
	END CATCH

	SET @AffectedTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( m.TransId AS VARCHAR(20))
								FROM #tmpMaxTransIdUpdateLeg m
								WHERE m.Odds <= m.OrgOdds
								FOR XML PATH ('')
							),1,1,'')) 

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' AffectedTransIds: ' + @AffectedTransIds
								+ ' ErrMsg: ' + @ErrMsg
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle
			@userid				= @creator
			,@matchid			= @MatchId
			,@actionid			= @ActionID
			,@Remark			= @LogData
			,@ip				= @ip

	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tmpLegOddsInfo
	DROP TABLE #tmpMaxTransIdProcessBatch
	DROP TABLE #tmpMaxTransIdUpdateLeg
END