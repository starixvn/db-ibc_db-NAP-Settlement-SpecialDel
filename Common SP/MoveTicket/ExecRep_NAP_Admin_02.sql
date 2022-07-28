/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.ExecRep_NAP_Admin_02
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
	,@EventDate DATETIME = NULL
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: DBTXN/BODB02

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]
		- 20210930@Louisa: Move running single tickets for E-Sports [Redmine:#159271]
		- 20220110@Kathy: Update winlostdate = eventdate if these values are different [Redmine:#167246]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
		@matchid: child matchid
		@Mode: single
				subparlay
				SingleRunning

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xml XML
			,@transInfo	XML

	DECLARE @tmpTrans TABLE (TransID BIGINT PRIMARY KEY, StatusId TINYINT, MainTransId BIGINT, oddsid INT)
	DECLARE @tmpTransInfo TABLE (transId BIGINT
		,winlostdate SMALLDATETIME
		,matchid INT
		,oddsid INT
	)

	SET @xml = CAST(@strTransIds AS XML)

	IF @Mode IN ('Single', 'subParlay' ) -- move ticket for Cricket Test match
	BEGIN
		INSERT INTO @tmpTrans (TransID, StatusId, MainTransId)
		SELECT	T.C.value('./@t', 'bigint') AS transid
				,T.C.value('./@s', 'tinyint') AS statusId
				,T.C.value('./@mt', 'bigint') AS maintransid
		FROM	@xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))

		IF @Mode = 'Single'
		BEGIN
			-- bettrans
			DELETE @tmpTransInfo

			UPDATE	b WITH(ROWLOCK, UPDLOCK)
				SET matchid = @MatchId
					,winlostdate = CASE WHEN @EventDate IS NOT NULL AND winlostdate <> @EventDate THEN @EventDate ELSE winlostdate END
				OUTPUT	inserted.transid
					,inserted.matchid
					,inserted.winlostdate
				INTO @tmpTransInfo (
					transId
					,matchid
					,winlostdate
				)
			FROM	@tmpTrans t
				INNER JOIN dbo.bettrans b
					ON	t.TransID = b.transid

			IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,matchid AS '@mid'
							,winlostdate AS '@wld'
					
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'MoveEvent', 'bettrans', @MatchId, @transInfo)	
				
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
			BEGIN
				IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				BEGIN
					DELETE @tmpTransInfo
					
					UPDATE	zb WITH(ROWLOCK, UPDLOCK)
						SET matchid = @MatchId
						OUTPUT	inserted.transid
							,inserted.matchid
						INTO @tmpTransInfo (
							transId
							,matchid
						)
					FROM	@tmpTrans t
						INNER JOIN dbo.zzzbettrans zb
							ON	t.TransID = zb.transId
					WHERE	t.StatusId = 102

					IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
					BEGIN
						SET @transInfo = (
							SELECT	transId AS '@t'
									,matchid AS '@mid'
									,winlostdate AS '@wld'
					
							FROM	@tmpTransInfo
							FOR XML PATH('r'),ROOT('root'), TYPE
						)

						INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
						VALUES ('Settlement', 'MoveEvent', 'zzzbettrans', @MatchId, @transInfo)	
					
					END
				END
			END
		END

		ELSE IF @Mode = 'subParlay'
		BEGIN
			-- bettransM
			DELETE @tmpTransInfo

			UPDATE	bm WITH(UPDLOCK, ROWLOCK)
				SET matchid = @MatchId
					,winlostdate = CASE 
										WHEN winlostdate IS NULL THEN winlostdate
										WHEN @EventDate IS NOT NULL AND winlostdate <> @EventDate THEN @EventDate 
										ELSE winlostdate 
									END
				OUTPUT	inserted.transid
					,inserted.matchid
					,inserted.winlostdate
				INTO @tmpTransInfo (
					transId
					,matchid
					,winlostdate
				)
			FROM	@tmpTrans t
				INNER JOIN dbo.bettransm bm 
					ON	bm.transid = t.transid
			
			IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,matchid AS '@mid'
							,winlostdate AS '@wld'
					
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'MoveEvent', 'bettransm', @MatchId, @transInfo)	
						
			END

			-- BetParlayDetail
			IF OBJECT_ID('BetParlayDetail','U') IS NOT NULL 
			BEGIN
				DELETE @tmpTransInfo

				UPDATE	d  WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
					OUTPUT	inserted.transid
						,inserted.matchid
					INTO @tmpTransInfo (
						transId
						,matchid
					)
				FROM	@tmpTrans t
					INNER JOIN dbo.BetParlayDetail d
						ON	d.transid = t.TransId

				IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
				BEGIN
					SET @transInfo = (
						SELECT	transId AS '@t'
								,matchid AS '@mid'
								
						FROM	@tmpTransInfo
						FOR XML PATH('r'),ROOT('root'), TYPE
					)

					INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
					VALUES ('Settlement', 'MoveEvent', 'BetParlayDetail', @MatchId, @transInfo)	
						
				END
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
			BEGIN
				IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				BEGIN
					DELETE @tmpTransInfo

					UPDATE	zb WITH(ROWLOCK, UPDLOCK)
						SET matchid = @MatchId
						OUTPUT	inserted.transid
							,inserted.matchid
						INTO @tmpTransInfo (
							transId
							,matchid
						)
					FROM	@tmpTrans t
						INNER JOIN dbo.zzzbettrans zb
							ON	t.TransID = zb.transId
					WHERE	t.StatusId = 102

					IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
					BEGIN
						SET @transInfo = (
							SELECT	transId AS '@t'
									,matchid AS '@mid'
								
							FROM	@tmpTransInfo
							FOR XML PATH('r'),ROOT('root'), TYPE
						)

						INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
						VALUES ('Settlement', 'MoveEvent', 'zzzbettrans', @MatchId, @transInfo)	
						
					END
				END

				IF OBJECT_ID('zzzbettransm','U') IS NOT NULL 
				BEGIN
					DELETE @tmpTransInfo

					UPDATE zbm WITH(ROWLOCK, UPDLOCK)
						SET matchid = @MatchId
						OUTPUT	inserted.transid
							,inserted.matchid
						INTO @tmpTransInfo (
							transId
							,matchid
						)
					FROM	@tmpTrans t
						INNER JOIN dbo.zzzbettransm zbm
							ON	t.TransID = zbm.transId
					WHERE	t.StatusId = 102

					IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
					BEGIN
						SET @transInfo = (
							SELECT	transId AS '@t'
									,matchid AS '@mid'
								
							FROM	@tmpTransInfo
							FOR XML PATH('r'),ROOT('root'), TYPE
						)

						INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
						VALUES ('Settlement', 'MoveEvent', 'zzzbettransm', @MatchId, @transInfo)	
							
					END
				END

				IF OBJECT_ID('TicketVoiding_VoidedTransaction','U') IS NOT NULL 
				BEGIN
					DELETE @tmpTransInfo

					UPDATE	vt WITH(ROWLOCK, UPDLOCK)
						SET matchid = @MatchId
						OUTPUT	inserted.transid
							,inserted.matchid
						INTO @tmpTransInfo (
							transId
							,matchid
						)
					FROM	@tmpTrans t
						INNER JOIN dbo.TicketVoiding_VoidedTransaction vt
							ON	t.MainTransId = vt.transId
					WHERE	t.StatusId = 102

					IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
					BEGIN
						SET @transInfo = (
							SELECT	transId AS '@t'
									,matchid AS '@mid'
								
							FROM	@tmpTransInfo
							FOR XML PATH('r'),ROOT('root'), TYPE
						)
						INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
						VALUES ('Settlement', 'MoveEvent', 'TicketVoiding_VoidedTransaction', @MatchId, @transInfo)		
								
					END
				END
			END
		END
	END

	ELSE IF @Mode = 'SingleRunning' -- Move single running ticket for E-SPorts
	BEGIN
		INSERT INTO @tmpTrans (TransID, oddsid)
		SELECT	T.C.value('./@t', 'bigint') AS transid
				,T.C.value('./@o', 'int') AS oddsid
		FROM	@xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))

		UPDATE	b WITH(ROWLOCK, UPDLOCK)
			SET matchid = @MatchId
				,oddsid = t.oddsid
			OUTPUT	inserted.transid
				,inserted.matchid
				,inserted.oddsid
			INTO @tmpTransInfo (
				transId
				,matchid
				,oddsid
			)
		FROM	@tmpTrans t
			INNER JOIN dbo.bettrans b
				ON	t.TransID = b.transid

		IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
		BEGIN		
			SET @transInfo = (
				SELECT	transId AS '@t'
						,matchid AS '@mid'
						,oddsid AS '@oid'
									
				FROM	@tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
			)

			INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'MoveOdds', 'bettrans', @MatchId, @transInfo)							
		END
	END
	
END