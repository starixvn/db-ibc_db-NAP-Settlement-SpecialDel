/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBetQueue_Insert_Recover]
(
	@MatchId		INT	
	,@sporttype		SMALLINT
	,@TransidList	VARCHAR(MAX)
)
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20220317@Max: [TVS] Support Max Payout & Max Turnover for Deposit - [Redmine: #169407]
		- 20230216@Max: Max Payout - AccumTurnover / AccumPayout is Negative because of some reasons [Redmine: #183935]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xml XML = NULL
		,@TransIds VARCHAR(MAX) = NULL
		,@CustId	INT = NULL
		,@CreatedDate DATETIME = NULL

	DECLARE @CustId_tmp AS TABLE (CustId INT, IsFinish BIT)
	DECLARE @CustLimitBet_Batch AS TABLE (
		CustId INT
		, sitetype TINYINT
		, transid BIGINT
		, bettype SMALLINT
	) 
	

	CREATE TABLE #CustLimitBet_tmp (
		CustId INT
		, sitetype TINYINT
		, transid BIGINT
		, bettype SMALLINT
	)

	CREATE TABLE #CustLimitBet_Outright (
		CustId INT
		, sitetype TINYINT
		, transid BIGINT
		, bettype SMALLINT
	)

	CREATE TABLE #CustLimitBet_38 (
		CustId INT
		, sitetype TINYINT
		, transid BIGINT
		, bettype SMALLINT
	)
	
	SET @xml = CONVERT(XML, @TransidList)

	INSERT INTO #CustLimitBet_tmp(CustId, sitetype, transid, bettype)        
	SELECT DISTINCT t.c.value('@custid','int') AS custid
		,t.c.value('@sitetype','tinyint') AS sitetype
		,t.c.value('@transid','BIGINT') AS transid
		,t.c.value('@bettype','smallint') AS bettype
	FROM @xml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	DELETE t
	FROM #CustLimitBet_tmp t
	WHERE (@sporttype > 99  AND @sporttype NOT IN (164,180,186) AND @sporttype NOT BETWEEN 190 AND 197)
		OR (t.bettype IN(29, 2799) OR (t.bettype BETWEEN 801 AND 806)) 
	
	SET @CreatedDate = GETDATE()
	IF EXISTS (SELECT TOP (1) 1 FROM #CustLimitBet_tmp WHERE bettype = 10)
	BEGIN
		DELETE t
			OUTPUT DELETED.CustId
				,DELETED.sitetype
				,DELETED.transid
				,DELETED.bettype
			INTO #CustLimitBet_Outright (CustId, sitetype, transid, bettype)
		FROM #CustLimitBet_tmp t
		WHERE bettype = 10
	END

	IF EXISTS (SELECT TOP (1) 1 FROM #CustLimitBet_tmp WHERE bettype = 38)
	BEGIN
		DELETE t
			OUTPUT DELETED.CustId
				,DELETED.sitetype
				,DELETED.transid
				,DELETED.bettype
			INTO #CustLimitBet_38 (CustId, sitetype, transid, bettype)
		FROM #CustLimitBet_tmp t
		WHERE bettype = 38
	END

	INSERT INTO @CustId_tmp (CustId)
	SELECT DISTINCT t.CustId
	FROM (
		SELECT c.CustId
		FROM #CustLimitBet_tmp c
		UNION ALL
		SELECT c.Custid
		FROM #CustLimitBet_Outright c
		UNION ALL
		SELECT c.Custid
		FROM #CustLimitBet_38 c
	)t
		
	WHILE (1=1)
	BEGIN
		SET @CustId = NULL
		UPDATE TOP(1) c SET @CustId = c.CustId, c.IsFinish = 1
		FROM @CustId_tmp c
		WHERE c.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp WHERE CustId = @CustId)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @CustLimitBet_Batch
				SET @TransIds = ''

				DELETE TOP (1000) t
					OUTPUT DELETED.CustId, DELETED.sitetype, DELETED.transid, DELETED.bettype
					INTO @CustLimitBet_Batch (CustId, sitetype, transid, bettype)
				FROM #CustLimitBet_tmp t
				WHERE t.CustId = @CustId

				IF @@ROWCOUNT = 0 BREAK

				SELECT @TransIds = (SELECT t.CustId AS '@custid'
										,t.sitetype AS '@sitetype'
										,t.TransId AS '@transid'
									FROM	@CustLimitBet_Batch t
									FOR XML PATH('r'), ROOT('root')
								)
				INSERT INTO dbo.CustLimitBetQueue (MatchId, CustID, EventTypeID, Transids, ActionID, Statusid, CreatedDate)
				SELECT @MatchId, @CustId, 1, @TransIds, 3, 0, @CreatedDate
			END
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_Outright WHERE CustId = @CustId)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @CustLimitBet_Batch
				SET @TransIds = ''

				DELETE TOP (1000) t
					OUTPUT DELETED.CustId, DELETED.sitetype, DELETED.transid, DELETED.bettype
					INTO @CustLimitBet_Batch (CustId, sitetype, transid, bettype)
				FROM #CustLimitBet_Outright t
				WHERE t.CustId = @CustId

				IF @@ROWCOUNT = 0 BREAK

				SELECT @TransIds = (SELECT t.CustId AS '@custid'
										,t.sitetype AS '@sitetype'
										,t.TransId AS '@transid'
									FROM	@CustLimitBet_Batch t
									FOR XML PATH('r'), ROOT('root')
								)
				INSERT INTO dbo.CustLimitBetQueue (MatchId, CustID, EventTypeID, Transids, ActionID, Statusid, CreatedDate)
				SELECT @MatchId, @CustId, 2, @TransIds, 3, 0, @CreatedDate
			END
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_38 WHERE CustId = @CustId)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @CustLimitBet_Batch
				SET @TransIds = ''

				DELETE TOP (1000) t
					OUTPUT DELETED.CustId, DELETED.sitetype, DELETED.transid, DELETED.bettype
					INTO @CustLimitBet_Batch (CustId, sitetype, transid, bettype)
				FROM #CustLimitBet_38 t
				WHERE t.CustId = @CustId

				IF @@ROWCOUNT = 0 BREAK

				SELECT @TransIds = (SELECT t.CustId AS '@custid'
										,t.sitetype AS '@sitetype'
										,t.TransId AS '@transid'
									FROM	@CustLimitBet_Batch t
									FOR XML PATH('r'), ROOT('root')
								)
				INSERT INTO dbo.CustLimitBetQueue (MatchId, CustID, EventTypeID, Transids, ActionID, Statusid, CreatedDate)
				SELECT @MatchId, @CustId, 5, @TransIds, 3, 0, @CreatedDate
			END
		END
	END

	DROP TABLE #CustLimitBet_tmp
	DROP TABLE #CustLimitBet_Outright
END
GO
	