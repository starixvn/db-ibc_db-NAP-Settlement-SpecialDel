/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE dbo.TicketVoiding_Request_CheckingProcess
	@VoidingHistoryId INT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
AS
/*	Created by: Kathy
	Date 20210402
	Task: Lock all process off match in queue of 1 request [Redmine:#152581]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20210402@Kathy: Create new SP [Redmine:#152581]
		- 20210524@July: Lock TempVariableNumber due to duplicate voiding requestid inserted from web special delete [Redmine:#155575]
		
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @limitsecond		INT	= 180
			,@isExistParlay		BIT = 0
			,@isExistMG			BIT = 0
			,@isExistFM			BIT = 0
			,@isExistMatch		BIT = 0
			,@isExistBB			BIT = 0
			,@isExistFM2		BIT = 0

			,@availableProcess	BIT  = 0
			,@starttime			DATETIME

	DECLARE @tmpMatchTransIds TABLE (MatchId INT, TransIds VARCHAR(MAX))
	DECLARE @tmpMatchTransIdsParlay TABLE (MatchId INT, TransIds VARCHAR(MAX))
	DECLARE @tmpInputTransId TABLE (MatchId INT, TransId BIGINT)
	DECLARE @tmpInputTransIdParlay TABLE (MatchId INT, TransId BIGINT)

	DECLARE @tmpKeyId TABLE (
		MatchId	INT
		,KeyId		TINYINT
		,IsLocked	BIT DEFAULT(0)
		,TryCount	INT DEFAULT(0)
	)

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	INSERT INTO @tmpMatchTransIds (MatchId, TransIds)
	SELECT	q.MatchId, q.TransIds
	FROM	dbo.TicketVoiding_Queue q WITH (NOLOCK)	
	WHERE	q.VoidingHistoryId = @VoidingHistoryId 
			AND q.voidingtypeId = 1 -- single

	INSERT INTO @tmpMatchTransIdsParlay (MatchId, TransIds)
	SELECT	q.MatchId, q.TransIds
	FROM	dbo.TicketVoiding_Queue q WITH (NOLOCK)	
	WHERE	q.VoidingHistoryId = @VoidingHistoryId 
			AND q.voidingtypeId = 2 -- parlay

	INSERT INTO @tmpInputTransId (MatchId, TransId)
	SELECT	t.MatchId, f.TransId AS TransId
	FROM	@tmpMatchTransIds t 
		CROSS APPLY (
				SELECT	val AS TransId
				FROM	dbo.f_SplitString(t.TransIds, ',')
			)f
	OPTION (maxrecursion 0)

	INSERT INTO @tmpInputTransIdParlay (MatchId, TransId)
	SELECT	t.MatchId, f.TransId AS TransId
	FROM	@tmpMatchTransIdsParlay t 
		CROSS APPLY (
				SELECT	val AS TransId
				FROM	dbo.f_SplitString(t.TransIds, ',')
			)f
	OPTION (maxrecursion 0)


	INSERT INTO @tmpKeyId (MatchId, KeyID)
	SELECT	t.matchid
			,CASE 
				WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
				WHEN Bettype = 38 THEN 5 -- Bet Builder
				WHEN f.GroupId = 1 THEN 6 -- FM
				WHEN f.GroupId = 2 THEN 7 -- FM 228
				WHEN Bettype NOT IN (9, 10, 29, 2799) THEN 1 --SB,NG,LC
				ELSE 0
			END AS KeyID
	FROM	@tmpInputTransId t
		LEFT JOIN dbo.bettrans b WITH(NOLOCK)
			ON	t.TransId = b.transid
		OUTER APPLY (
				SELECT	GroupId
				FROM	dbo.f_TVS_CheckingProcessGroupBettypes() f
				WHERE	f.Bettype = b.bettype
			)f
	WHERE statusId <> 102
	GROUP BY t.matchid
			,CASE 
				WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
				WHEN Bettype = 38 THEN 5 -- Bet Builder
				WHEN f.GroupId = 1 THEN 6 -- FM
				WHEN f.GroupId = 2 THEN 7 -- FM 228
				WHEN Bettype NOT IN (9, 10, 29, 2799) THEN 1 --SB,NG,LC
				ELSE 0
			END

	DELETE FROM @tmpKeyId WHERE KeyId = 0

	IF EXISTS (SELECT * FROM dbo.TicketVoiding_Queue WITH(NOLOCK) WHERE VoidingHistoryId = @VoidingHistoryId AND VoidingTypeId = 2)
				OR EXISTS (SELECT TOP 1 1 FROM @tmpKeyId WHERE MatchId = 29)
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM @tmpInputTransIdParlay p
								  INNER JOIN dbo.bettrans b WITH(NOLOCK) ON p.TransId = b.transid
								  INNER HASH JOIN dbo.bettransm bm WITH(NOLOCK) ON b.refno = bm.refno
								WHERE  b.MatchId = 29 AND bm.statusID <> 102
				  )
		BEGIN
			SET @isExistParlay = 1
		END
	END
	
	SET @starttime = getdate()
	WHILE (1 =1)
	BEGIN	
		SELECT	@ErrCode = 0
				,@ErrMsg = ''

		TRUNCATE TABLE  #tblMatchProcess

		IF DATEDIFF(SECOND, @starttime, getdate()) > @limitsecond
		BEGIN
			SELECT	@ErrCode = 1000000
					,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
			
			INSERT INTO #tblMatchProcess (matchid, KeyID)
			SELECT	MatchId, KeyId
			FROM	@tmpKeyId
			WHERE	IsLocked = 1

			EXEC dbo.NAP_Admin_CheckingProcess
				 @isExistMG		= @isExistMG
				, @isExistFM	= @isExistFM
				, @isExistMatch	= @isExistMatch
				, @isExistBB	= @isExistBB
				, @isExistFM2	= @isExistFM2
				, @IsReleased	= 1

			BREAK
		END
		
		INSERT INTO #tblMatchProcess (KeyID, matchid)
		SELECT TOP 1 t.KeyId, t.MatchId
		FROM	@tmpKeyId t
		WHERE	IsLocked = 0
		ORDER BY TryCount
		
		IF @@ROWCOUNT = 0
		BEGIN
			IF @isExistParlay = 1
			BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 				= @isExistParlay
					,@avaiableProcess 			= @availableProcess OUTPUT
					,@ErrCode					= @ErrCode OUTPUT
					,@ErrMsg					= @ErrMsg OUTPUT

				IF @availableProcess = 0 OR @ErrCode <> 0
					CONTINUE
				ELSE 
					BREAK
			END
			ELSE
				BREAK
		END
		
		SELECT	@isExistMatch = CASE WHEN KeyID = 1 THEN 1 ELSE 0 END
				,@isExistMG = CASE WHEN KeyID = 3 THEN 1 ELSE 0 END
				,@isExistMG = CASE WHEN KeyID = 3 THEN 1 ELSE 0 END
				,@isExistBB = CASE WHEN KeyID = 5 THEN 1 ELSE 0 END
				,@isExistFM = CASE WHEN KeyID = 6 THEN 1 ELSE 0 END
				,@isExistFM2 = CASE WHEN KeyID = 7 THEN 1 ELSE 0 END
		FROM	#tblMatchProcess

		EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistMG				= @isExistMG
			, @isExistFM				= @isExistFM
			, @isExistMatch				= @isExistMatch
			, @isExistBB				= @isExistBB
			, @isExistFM2				= @isExistFM2
			, @avaiableProcess 			= @availableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		
		IF @availableProcess = 0 OR @ErrCode <> 0
		BEGIN
			UPDATE	@tmpKeyId
				SET TryCount = TryCount + 1
			FROM	@tmpKeyId t
				INNER JOIN #tblMatchProcess m
					ON	t.MatchId = m.matchid
						AND t.KeyId = m.KeyID

			CONTINUE
		END
		
		UPDATE t
			SET IsLocked = 1
		FROM	@tmpKeyId t
			INNER JOIN #tblMatchProcess m
				ON	t.MatchId = m.matchid
					AND t.KeyId = m.KeyID	
	END

	DROP TABLE #tblMatchProcess
END