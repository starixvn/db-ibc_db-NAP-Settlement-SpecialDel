/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBetQueue_Insert_Parlay]
(
	@MatchId		INT	
	,@TransidList	VARCHAR(MAX)
	,@Mode			VARCHAR(50) = NULL 
)
AS
/*	
	Created: 20210921@Max
    Task: Apply Max Parlay Payout [Redmine: #161037]
    DB: DBTXN/bodb02
    Revisions:
		- 20210921@Max: Apply Max Parlay Payout [Redmine: #161037]
		- 20220317@Max: [TVS] Support Max Payout & Max Turnover for Deposit - [Redmine: #169407]
		- 20220908@Helen: Performance Tuning - [Redmine: #177591]
		- 20230119@July: Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site - [Redmine: #182803]
		- 20230216@Max: Max Payout - AccumTurnover / AccumPayout is Negative because of some reasons [Redmine: #183935]
		- 20240325@Max: Max Payout - NAP_Admin_CustLimitBetQueue_Insert_Parlay Enhancement [Redmine: #202058]
		- 20250703@Max: Support re-settle when recover voided sub parlay from TVS [Redmine: #227829]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xml XML = NULL
		,@TransIds VARCHAR(MAX) = NULL
		,@CustId	INT = NULL
		,@CreatedDate DATETIME = NULL

	DECLARE @CustId_tmp AS TABLE (CustId INT, IsFinish BIT)	
	DECLARE @CustLimitBet_Batch AS TABLE (CustId INT, transid BIGINT) 	
	DECLARE @CustLimitBet_tmp AS TABLE (CustId INT, transid BIGINT, ruben TINYINT)
	DECLARE @CustLimitBet_tmp_ruben_0 AS TABLE (CustId INT, transid BIGINT)
	DECLARE @tmpParlayTransid AS TABLE (custid INT, ruben TINYINT, transid BIGINT)

	SET @xml = CONVERT(XML, @TransidList)

	INSERT INTO @tmpParlayTransid (ruben, transid)
	SELECT DISTINCT t.c.value('@ruben','tinyint') AS ruben
			,t.c.value('@transid','BIGINT') AS transid
	FROM @xml.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	INSERT INTO @CustLimitBet_tmp(CustId, transid, ruben)
	SELECT b.custid
		,tmp.transid
		,b.ruben
	FROM @tmpParlayTransid tmp
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = tmp.transid		
	WHERE tmp.ruben <> b.ruben

	IF NOT EXISTS (SELECT TOP(1) 1 FROM @CustLimitBet_tmp)
		RETURN
	
	IF EXISTS (SELECT TOP(1) 1 FROM @CustLimitBet_tmp WHERE ruben = 0)
	BEGIN
		DELETE t
			OUTPUT DELETED.CustId, deleted.transid
			INTO @CustLimitBet_tmp_ruben_0 (CustId, transid)
		FROM @CustLimitBet_tmp t
		WHERE t.ruben = 0
	END

	SET @CreatedDate = GETDATE()
	IF @Mode IS NULL
	BEGIN
		IF EXISTS (SELECT TOP(1) 1 FROM @CustLimitBet_tmp)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @CustLimitBet_Batch
				SET @TransIds = ''

				DELETE TOP (1000) t
					OUTPUT DELETED.CustId, DELETED.transid
					INTO @CustLimitBet_Batch (CustId, transid)
				FROM @CustLimitBet_tmp t

				IF @@ROWCOUNT = 0 BREAK

				SELECT @TransIds = (SELECT t.CustId AS '@custid'
										,t.TransId AS '@transid'
									FROM	@CustLimitBet_Batch t
									FOR XML PATH('r'), ROOT('root')
								)
				INSERT INTO dbo.CustLimitBetQueue (MatchId, Transids, ActionID, Statusid, CreatedDate)
				SELECT @MatchId, @TransIds, 4, 0, @CreatedDate
			END
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @CustLimitBet_tmp_ruben_0)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @CustLimitBet_Batch
				SET @TransIds = ''

				DELETE TOP (1000) t
					OUTPUT DELETED.CustId, DELETED.transid
					INTO @CustLimitBet_Batch (CustId, transid)
				FROM @CustLimitBet_tmp_ruben_0 t

				IF @@ROWCOUNT = 0 BREAK

				SELECT @TransIds = (SELECT t.CustId AS '@custid'
										,t.TransId AS '@transid'
									FROM	@CustLimitBet_Batch t
									FOR XML PATH('r'), ROOT('root')
								)
				INSERT INTO dbo.CustLimitBetQueue (MatchId, Transids, ActionID, Statusid, CreatedDate)
				SELECT @MatchId, @TransIds, 5, 0, @CreatedDate
			END
		END
	END
	ELSE IF @Mode = 'RECOVER'
	BEGIN
		IF EXISTS (SELECT TOP(1) 1 FROM @CustLimitBet_tmp_ruben_0)
		BEGIN
			INSERT INTO @CustId_tmp (CustId)
			SELECT DISTINCT t.CustId
			FROM (
				SELECT c.CustId
				FROM @CustLimitBet_tmp_ruben_0 c
			)t
			WHILE (1=1)
			BEGIN
				SET @CustId = NULL
				UPDATE TOP(1) c SET @CustId = c.CustId, c.IsFinish = 1
				FROM @CustId_tmp c
				WHERE c.IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK

				WHILE (1=1)
				BEGIN
					DELETE @CustLimitBet_Batch
					SET @TransIds = ''

					DELETE TOP (1000) t
						OUTPUT DELETED.CustId, DELETED.transid
						INTO @CustLimitBet_Batch (CustId, transid)
					FROM @CustLimitBet_tmp_ruben_0 t
					WHERE t.CustId = @CustId

					IF @@ROWCOUNT = 0 BREAK

					SELECT @TransIds = (SELECT t.CustId AS '@custid'
											,t.TransId AS '@transid'
										FROM	@CustLimitBet_Batch t
										FOR XML PATH('r'), ROOT('root')
									)
					INSERT INTO dbo.CustLimitBetQueue (MatchId, CustID, Transids, ActionID, Statusid, CreatedDate)
					SELECT @MatchId, @CustId, @TransIds, 5, 0, @CreatedDate
				END
			END	
		END

		--Support TVS Recover parlay auto cal for main transid
		IF EXISTS (SELECT TOP(1) 1 FROM @CustLimitBet_tmp)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @CustLimitBet_Batch
				SET @TransIds = ''

				DELETE TOP (1000) t
					OUTPUT DELETED.CustId, DELETED.transid
					INTO @CustLimitBet_Batch (CustId, transid)
				FROM @CustLimitBet_tmp t

				IF @@ROWCOUNT = 0 BREAK

				SELECT @TransIds = (SELECT t.CustId AS '@custid'
										,t.TransId AS '@transid'
									FROM	@CustLimitBet_Batch t
									FOR XML PATH('r'), ROOT('root')
								)
				INSERT INTO dbo.CustLimitBetQueue (MatchId, Transids, ActionID, Statusid, CreatedDate)
				SELECT @MatchId, @TransIds, 4, 0, @CreatedDate
			END
		END
	END
END
GO
	