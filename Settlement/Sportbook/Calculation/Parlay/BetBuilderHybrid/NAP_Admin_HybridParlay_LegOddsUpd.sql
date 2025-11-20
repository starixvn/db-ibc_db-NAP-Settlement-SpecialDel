/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_HybridParlay_LegOddsUpd]
	@MatchId		INT
	,@LegOddsJSON	NVARCHAR(MAX)
	,@creator		INT
	,@IP			VARCHAR(15) = ''
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = NULL OUTPUT
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
		@LegOddsJSON:  [{"MatchId": 987456,"TransId": 12,"Odds": 2.5},
						{ "MatchId": 123456,"TransId": 13,"Odds": 1.5}]        

*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @LogData			VARCHAR(MAX)
			,@Session			NVARCHAR(50)
		    ,@ThreadHold		INT = 0 -- over threadhold, the parlay process will be locked in systemsetting 
		    ,@SPName			VARCHAR(500) = OBJECT_NAME(@@PROCID)			 
			,@avaiableProcess	BIT
			,@totalRefNo		INT = 0
			,@strLegOdds		VARCHAR(MAX)
	
	DECLARE @AffectedTransIds	VARCHAR(MAX) = ''
		   ,@InvalidTransIds	VARCHAR(MAX) = ''
		   ,@WrongOddsTransIds	VARCHAR(MAX) = ''

	CREATE TABLE #tmpMainTransId (MatchId INT, TransId BIGINT, Odds SMALLMONEY, RefNo BIGINT, transdesc NVARCHAR(2000))
	CREATE TABLE #tmpMaxTransIdUpdateLeg(TransId BIGINT, Refno BIGINT, MatchId INT, Odds SMALLMONEY, IsFinish BIT, OrgOdds SMALLMONEY, MainTransId BIGINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #tmpMaxTransIdProcessBatch (TransId BIGINT, Refno BIGINT, MatchId INT, Odds SMALLMONEY)

	DECLARE @tmpLegOddsInfo TABLE (MatchId INT, TransId BIGINT, Odds SMALLMONEY)

	SET @Session = CONVERT(NVARCHAR(50),NEWID())

	DECLARE @IsCentral BIT = 0	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO @tmpLegOddsInfo (MatchId, TransId, Odds)
	SELECT js.MatchId AS MatchId, js.TransId AS TransId, js.Odds AS Odds
	FROM OPENJSON(@LegOddsJSON) WITH (MatchId INT, TransId BIGINT, Odds SMALLMONEY) js

	INSERT INTO #tmpMainTransId (MatchId, TransId, Odds, RefNo, transdesc)
	SELECT j.MatchId, j.TransId, j.Odds, b.refno, b.transdesc
	FROM @tmpLegOddsInfo j
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = j.TransId
	WHERE b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

	BEGIN TRY
		INSERT INTO #tmpMaxTransIdUpdateLeg (Refno, MatchId, Odds, TransId, OrgOdds, MainTransId)
		SELECT t.RefNo, t.MatchId, t.Odds, bm.MaxSubTransId, j.OrgOdds, t.TransId AS MainTransId
		FROM #tmpMainTransId t
		CROSS APPLY (
				SELECT 
					m AS OrgMatch,
					o AS OrgOdds
				FROM OPENJSON(t.transdesc, '$.legOdds')
				WITH (
					m INT '$.m',
					o SMALLMONEY '$.o'
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
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()

		SELECT  @AffectedTransIds AS AffectedTransIds
		         ,@WrongOddsTransIds AS WrongOddsTransIds
		         ,@InvalidTransIds AS InvalidTransIds
		RETURN
	END CATCH

	IF @totalRefNo = 0
	BEGIN
		SELECT @ErrCode = 99  
				,@ErrMsg = 'No parlay ticket found.'  

		SELECT  @AffectedTransIds AS AffectedTransIds
		         ,@WrongOddsTransIds AS WrongOddsTransIds
		         ,@InvalidTransIds AS InvalidTransIds
		RETURN
	END
	
	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
	   ,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
	SELECT DISTINCT MatchId, refno
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
			SELECT  @AffectedTransIds AS AffectedTransIds
		             ,@WrongOddsTransIds AS WrongOddsTransIds
		             ,@InvalidTransIds AS InvalidTransIds
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
			INSERT INTO dbo.BetBuilderLegOddsHistory (MatchId, RefNo, TransId, Odds)
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

	SET @AffectedTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( m.MainTransId AS VARCHAR(20))
								FROM #tmpMaxTransIdUpdateLeg m
								WHERE m.Odds <= m.OrgOdds
								FOR XML PATH ('')
							),1,1,'')) 

	SET @WrongOddsTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( m.MainTransId AS VARCHAR(20))
								FROM #tmpMaxTransIdUpdateLeg m
								WHERE m.Odds > m.OrgOdds
								FOR XML PATH ('')
							),1,1,'')) 

	SET @InvalidTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( l.TransId AS VARCHAR(20))
								FROM @tmpLegOddsInfo l
								WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tmpMaxTransIdUpdateLeg m WHERE m.MainTransId = l.TransId)
								FOR XML PATH ('')
							),1,1,'')) 

	--Return table 
	SELECT  @AffectedTransIds AS AffectedTransIds
		   ,@WrongOddsTransIds AS WrongOddsTransIds
		   ,@InvalidTransIds AS InvalidTransIds

	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tmpMainTransId
	DROP TABLE #tmpMaxTransIdProcessBatch
	DROP TABLE #tmpMaxTransIdUpdateLeg
END