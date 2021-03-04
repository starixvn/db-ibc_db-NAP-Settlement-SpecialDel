/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE bodb02
GO

ALTER PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT1
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: DBTXN/BODB02

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]

	Param's Explanation:
		@matchid: child matchid
		@Mode: single
				subparlay
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @xml XML

	DECLARE @tmpTrans TABLE (TransID BIGINT PRIMARY KEY, StatusId TINYINT, MainTransId BIGINT)
	
	SET @xml = CAST(@strTransIds AS XML)

	INSERT INTO @tmpTrans (TransID, StatusId, MainTransId)
	SELECT	T.C.value('./@t', 'bigint') AS transid
			,T.C.value('./@s', 'tinyint') AS statusId
			,T.C.value('./@mt', 'bigint') AS maintransid
	FROM	@xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	IF @Mode = 'Single'
	BEGIN
		-- bettrans
		UPDATE	b WITH(ROWLOCK, UPDLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettrans b
				ON	t.TransID = b.transid

		IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
		BEGIN
			IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				UPDATE	zb WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettrans zb
						ON	t.TransID = zb.transId
				WHERE	t.StatusId = 102
		END
	END
	ELSE IF @Mode = 'subParlay'
	BEGIN
		-- bettransM
		UPDATE	bm WITH(UPDLOCK, ROWLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettransm bm 
				ON	bm.transid = t.transid

		-- BetParlayDetail
		IF OBJECT_ID('BetParlayDetail','U') IS NOT NULL 
			UPDATE	d  WITH(ROWLOCK, UPDLOCK)
				SET matchid = @MatchId
			FROM	@tmpTrans t
				INNER JOIN dbo.BetParlayDetail d
					ON	d.transid = t.TransId

		IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
		BEGIN
			IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				UPDATE	zb WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettrans zb
						ON	t.TransID = zb.transId
				WHERE	t.StatusId = 102

			IF OBJECT_ID('zzzbettransm','U') IS NOT NULL 
				UPDATE zbm WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettransm zbm
						ON	t.TransID = zbm.transId
				WHERE	t.StatusId = 102

			IF OBJECT_ID('TicketVoiding_VoidedTransaction','U') IS NOT NULL 
			BEGIN
				UPDATE	vt WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.TicketVoiding_VoidedTransaction vt
						ON	t.MainTransId = vt.transId
				WHERE	t.StatusId = 102

			END
		END
	END
END
GO

ALTER PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT2
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: DBTXN/BODB02

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]

	Param's Explanation:
		@matchid: child matchid
		@Mode: single
				subparlay
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @xml XML

	DECLARE @tmpTrans TABLE (TransID BIGINT PRIMARY KEY, StatusId TINYINT, MainTransId BIGINT)
	
	SET @xml = CAST(@strTransIds AS XML)

	INSERT INTO @tmpTrans (TransID, StatusId, MainTransId)
	SELECT	T.C.value('./@t', 'bigint') AS transid
			,T.C.value('./@s', 'tinyint') AS statusId
			,T.C.value('./@mt', 'bigint') AS maintransid
	FROM	@xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	IF @Mode = 'Single'
	BEGIN
		-- bettrans
		UPDATE	b WITH(ROWLOCK, UPDLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettrans b
				ON	t.TransID = b.transid

		IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
		BEGIN
			IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				UPDATE	zb WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettrans zb
						ON	t.TransID = zb.transId
				WHERE	t.StatusId = 102
		END
	END
	ELSE IF @Mode = 'subParlay'
	BEGIN
		-- bettransM
		UPDATE	bm WITH(UPDLOCK, ROWLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettransm bm 
				ON	bm.transid = t.transid

		-- BetParlayDetail
		IF OBJECT_ID('BetParlayDetail','U') IS NOT NULL 
			UPDATE	d  WITH(ROWLOCK, UPDLOCK)
				SET matchid = @MatchId
			FROM	@tmpTrans t
				INNER JOIN dbo.BetParlayDetail d
					ON	d.transid = t.TransId

		IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
		BEGIN
			IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				UPDATE	zb WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettrans zb
						ON	t.TransID = zb.transId
				WHERE	t.StatusId = 102

			IF OBJECT_ID('zzzbettransm','U') IS NOT NULL 
				UPDATE zbm WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettransm zbm
						ON	t.TransID = zbm.transId
				WHERE	t.StatusId = 102

			IF OBJECT_ID('TicketVoiding_VoidedTransaction','U') IS NOT NULL 
			BEGIN
				UPDATE	vt WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.TicketVoiding_VoidedTransaction vt
						ON	t.MainTransId = vt.transId
				WHERE	t.StatusId = 102

			END
		END
	END
END
GO

ALTER PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT3
	@MatchId INT
	,@Mode VARCHAR(15)
	,@strTransIds VARCHAR(MAX)
AS
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket
	DB: DBTXN/BODB02

	Revisions:
		- 20210218@Kathy: Move Tickets of Settled Results Functions [Redmine:#148870]

	Param's Explanation:
		@matchid: child matchid
		@Mode: single
				subparlay
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @xml XML

	DECLARE @tmpTrans TABLE (TransID BIGINT PRIMARY KEY, StatusId TINYINT, MainTransId BIGINT)
	
	SET @xml = CAST(@strTransIds AS XML)

	INSERT INTO @tmpTrans (TransID, StatusId, MainTransId)
	SELECT	T.C.value('./@t', 'bigint') AS transid
			,T.C.value('./@s', 'tinyint') AS statusId
			,T.C.value('./@mt', 'bigint') AS maintransid
	FROM	@xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	IF @Mode = 'Single'
	BEGIN
		-- bettrans
		UPDATE	b WITH(ROWLOCK, UPDLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettrans b
				ON	t.TransID = b.transid

		IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
		BEGIN
			IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				UPDATE	zb WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettrans zb
						ON	t.TransID = zb.transId
				WHERE	t.StatusId = 102
		END
	END
	ELSE IF @Mode = 'subParlay'
	BEGIN
		-- bettransM
		UPDATE	bm WITH(UPDLOCK, ROWLOCK)
			SET matchid = @MatchId
		FROM	@tmpTrans t
			INNER JOIN dbo.bettransm bm 
				ON	bm.transid = t.transid

		-- BetParlayDetail
		IF OBJECT_ID('BetParlayDetail','U') IS NOT NULL 
			UPDATE	d  WITH(ROWLOCK, UPDLOCK)
				SET matchid = @MatchId
			FROM	@tmpTrans t
				INNER JOIN dbo.BetParlayDetail d
					ON	d.transid = t.TransId

		IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans WHERE StatusId = 102)
		BEGIN
			IF OBJECT_ID('zzzbettrans','U') IS NOT NULL 
				UPDATE	zb WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettrans zb
						ON	t.TransID = zb.transId
				WHERE	t.StatusId = 102

			IF OBJECT_ID('zzzbettransm','U') IS NOT NULL 
				UPDATE zbm WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.zzzbettransm zbm
						ON	t.TransID = zbm.transId
				WHERE	t.StatusId = 102

			IF OBJECT_ID('TicketVoiding_VoidedTransaction','U') IS NOT NULL 
			BEGIN
				UPDATE	vt WITH(ROWLOCK, UPDLOCK)
					SET matchid = @MatchId
				FROM	@tmpTrans t
					INNER JOIN dbo.TicketVoiding_VoidedTransaction vt
						ON	t.MainTransId = vt.transId
				WHERE	t.StatusId = 102

			END
		END
	END
END
GO