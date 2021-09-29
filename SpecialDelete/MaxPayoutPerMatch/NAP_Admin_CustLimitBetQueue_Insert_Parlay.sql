/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBetQueue_Insert_Parlay]
(
	@MatchId		INT	
	,@ActionId		TINYINT
	,@TransidList	VARCHAR(MAX)
)
AS
/*	
	Created: 20210921@Max
    Task: Apply Max Parlay Payout [Redmine: #161037]
    DB: DBTXN/bodb02
    Revisions:
		- 20210921@Max: Apply Max Parlay Payout [Redmine: #161037]
	
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
	) 
	
	CREATE TABLE #CustLimitBet_tmp (
		CustId INT
		, sitetype TINYINT
		, transid BIGINT
		,  ruben TINYINT
	)

	
	SET @xml = CONVERT(XML, @TransidList)

	INSERT INTO #CustLimitBet_tmp(CustId, sitetype, transid)
	SELECT tmp.custid
		,CASE 
			WHEN dp.custid IS NOT NULL THEN 3 --deposit 
			WHEN c.site = '789y' THEN 2 --789y
			ELSE 1 END
		,tmp.transid
	FROM (
			SELECT t.c.value('@custid','int') AS custid
				,t.c.value('@ruben','tinyint') AS ruben
				,t.c.value('@transid','BIGINT') AS transid
			FROM @xml.nodes('root/r') t(c)
	)tmp
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = tmp.transid
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = tmp.custid
		LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON c.srecommend = dp.custid
	WHERE tmp.ruben <> b.ruben 
	OPTION (OPTIMIZE FOR (@xml = NULL ))

	INSERT INTO @CustId_tmp (CustId)
	SELECT DISTINCT t.CustId
	FROM (
		SELECT c.CustId
		FROM #CustLimitBet_tmp c
	)t
	
	SET @CreatedDate = GETDATE()
	IF @ActionId <> 3 --Recover
	BEGIN
		IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @CustLimitBet_Batch
				SET @TransIds = ''

				DELETE TOP (1000) t
					OUTPUT DELETED.CustId, DELETED.sitetype, DELETED.transid
					INTO @CustLimitBet_Batch (CustId, sitetype, transid)
				FROM #CustLimitBet_tmp t

				IF @@ROWCOUNT = 0 BREAK

				SELECT @TransIds = (SELECT t.CustId AS '@custid'
										,t.sitetype AS '@sitetype'
										,t.TransId AS '@transid'
									FROM	@CustLimitBet_Batch t
									FOR XML PATH('r'), ROOT('root')
								)
				INSERT INTO dbo.CustLimitBetQueue (MatchId, Transids, ActionID, Statusid, CreatedDate)
				SELECT @MatchId, @TransIds, @ActionId, 0, @CreatedDate
			END
		END
	END
	ELSE
	BEGIN
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
						OUTPUT DELETED.CustId, DELETED.sitetype, DELETED.transid
						INTO @CustLimitBet_Batch (CustId, sitetype, transid)
					FROM #CustLimitBet_tmp t
					WHERE t.CustId = @CustId

					IF @@ROWCOUNT = 0 BREAK

					SELECT @TransIds = (SELECT t.CustId AS '@custid'
											,t.sitetype AS '@sitetype'
											,t.TransId AS '@transid'
										FROM	@CustLimitBet_Batch t
										FOR XML PATH('r'), ROOT('root')
									)
					INSERT INTO dbo.CustLimitBetQueue (MatchId, CustID, Transids, ActionID, Statusid, CreatedDate)
					SELECT @MatchId, @CustId, @TransIds, 3, 0, @CreatedDate
				END
			END
		END	
	END
	
	DROP TABLE #CustLimitBet_tmp
END
GO
	