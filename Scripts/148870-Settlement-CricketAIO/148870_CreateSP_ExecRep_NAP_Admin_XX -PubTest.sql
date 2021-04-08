/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE dbo.ExecRep_NAP_Admin_01_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_01_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_01_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO
---------------------------------------------------------------------------
CREATE PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT1
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

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT2
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

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_02_UAT3
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
---------------------------------------------------------------------------
CREATE PROCEDURE dbo.ExecRep_NAP_Admin_03_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_03_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_03_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO
---------------------------------------------------------------------------
CREATE PROCEDURE dbo.ExecRep_NAP_Admin_04_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/	
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_04_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/	
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_04_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/	
AS
BEGIN
	SET NOCOUNT ON
END
GO
---------------------------------------------------------------------------

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_05_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/	
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_05_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/	
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_05_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/	
AS
BEGIN
	SET NOCOUNT ON
END
GO
----------------------------------------------------------------------

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_06_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_06_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_06_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO
-----------------------------------------------------

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_07_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_07_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_07_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO
--------------------------------------------------------------

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_08_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_08_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_08_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO
----------------------------------------------------------------

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_09_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_09_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_09_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO
-----------------------------------------------------------------

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_10_UAT1
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_10_UAT2
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO

CREATE PROCEDURE dbo.ExecRep_NAP_Admin_10_UAT3
/*
	Created by: 20210303@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: add SPs into Pub Test [Redmine:#140452]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep_UAT
*/
AS
BEGIN
	SET NOCOUNT ON
END
GO