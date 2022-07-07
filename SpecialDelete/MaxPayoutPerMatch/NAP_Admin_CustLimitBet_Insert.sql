/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Insert]
(
	@MatchId INT
	,@Transids VARCHAR(MAX)
	,@QueueId INT
	,@EventTypeID TINYINT = NULL
	,@ActionId TINYINT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
)
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210921@Max: Apply Max Parlay Payout [Redmine: #161658]
		- 20211012@Max: Exclude deposit ticket for Reject case, remove code reject outright [Redmine: #158073]
		- 20220317@Max: [TVS] Support Max Payout & Max Turnover for Deposit - [Redmine: #169407]
		- 20220419@Max: Max Payout - Retry for Reject Action [Redmine: #171674]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @xml XML = NULL
		,@MinTransId BIGINT
		,@MaxTransId	BIGINT
		,@RejectTime	DATETIME
		,@InvalidTransIds	VARCHAR(200) = ''
		,@Creator		INT


	CREATE TABLE #CustLimitBet_tmp (
			MatchId	INT
			, CustId INT
			, sitetype TINYINT
			, transid BIGINT
			, sporttype SMALLINT
			, bettype	SMALLINT
			, BRID		BIGINT
		)

	CREATE TABLE #CustLimitBet_789 (
		MatchId	INT
			, CustId INT
			, sitetype TINYINT
			, transid BIGINT
			, BRID		BIGINT
	)

	CREATE TABLE #CustLimitBet_LIC (
		MatchId	INT
			, CustId INT
			, sitetype TINYINT
			, transid BIGINT
			, BRID		BIGINT
	)
	
	DECLARE @HistoryMissingTransId AS TABLE (transid BIGINT, sitetype TINYINT)
	

	 
	IF @ActionId IN (1,3,4,5) --VOID,RECOVER,SETTLE
	BEGIN
		
		SET @xml = CONVERT(XML, @Transids)

		INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid, BRID)        
		SELECT @MatchId AS MatchId
			, t.c.value('@custid','int') AS custid
			,t.c.value('@sitetype','tinyint') AS sitetype
			,t.c.value('@transid','BIGINT') AS transid
			,t.c.value('@brid','BIGINT') AS BRID
		FROM @xml.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@xml = NULL))
	END
	ELSE IF @ActionId = 2 --REJECT
	BEGIN
		SET @xml = CONVERT(XML, @Transids)

		SELECT @MinTransId = t.c.value('@mintransid','bigint')
			,@MaxTransId = t.c.value('@maxtransid','bigint')
			,@RejectTime = t.c.value('@rejecttime','datetime')
			,@Creator = t.c.value('@creator','int')
		FROM @xml.nodes('root/rejectTicket') t(c)
		OPTION (OPTIMIZE FOR (@xml = NULL))

		IF @MatchId <> 29 --Match, Bettype 38
		BEGIN
			INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid, sporttype, bettype, BRID)
			SELECT @MatchId
				, b.custid
				,CASE WHEN s.custid IS NOT NULL THEN 3 --deposit
						WHEN  c.site = '789y' THEN 2 --789y
					ELSE 1 END
				,b.transid
				,m.sporttype
				,b.bettype
				,b.BRID
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK) ON s.custid = b.srecommend
			WHERE b.transid BETWEEN @MinTransId AND @MaxTransId
				AND b.matchid = @MatchId
				AND b.checktime = @RejectTime
				AND b.statusID = 101
		END
		ELSE IF @MatchId = 29  --Parlay
		BEGIN
			INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid)
			SELECT @MatchId
				, b.custid
				,CASE WHEN s.custid IS NOT NULL THEN 3 --deposit
						WHEN  c.site = '789y' THEN 2 --789y
					ELSE 1 END
				,b.transid
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
				LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK) ON s.custid = b.srecommend
			WHERE b.transid BETWEEN @MinTransId AND @MaxTransId
				AND b.matchid = 29
				AND b.checktime = @RejectTime
				AND b.statusID = 101
				AND b.creator = @Creator
		END

		--Remove unsupport sporttype/bettype
		IF @MatchId <> 29
		BEGIN
			DELETE t
			FROM #CustLimitBet_tmp t
			WHERE (t.sporttype > 99  AND t.sporttype NOT IN (164,180,186) AND t.sporttype NOT BETWEEN 190 AND 197)
				OR (t.bettype IN(29, 2799) OR (t.bettype BETWEEN 801 AND 806))
		END
	END

	--Check no valid data
	IF NOT EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp)
	BEGIN
		SELECT @ErrCode = 101
		SELECT @ErrMsg = 'No valid transid found'

		RETURN
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp WHERE sitetype = 2) -- 789y
	BEGIN
		DELETE t OUTPUT
			DELETED.CustId, DELETED.sitetype, DELETED.transid, @MatchId, DELETED.BRID
			INTO #CustLimitBet_789 (CustId, sitetype, transid, MatchId, BRID)
		FROM #CustLimitBet_tmp t
		WHERE t.sitetype = 2

		INSERT INTO @HistoryMissingTransId (transid, sitetype )
		SELECT t.transid, 2
		FROM #CustLimitBet_789 t	
		OUTER APPLY (
				SELECT TOP 1 t1.Transid
				FROM dbo.CustLimitBetHistory_789 t1 WITH (NOLOCK)
				WHERE t1.Matchid = t.MatchId
					AND t1.CustID = t.CustId
					AND t1.Transid = t.transid
					AND t1.BRID = 0
			)tmp
		WHERE tmp.Transid IS NULL


	END

	IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp WHERE sitetype = 3) -- deposit
	BEGIN
		DELETE t OUTPUT
			DELETED.CustId, DELETED.sitetype, DELETED.transid, @MatchId, DELETED.BRID
			INTO #CustLimitBet_LIC (CustId, sitetype, transid, MatchId, BRID)
		FROM #CustLimitBet_tmp t
		WHERE t.sitetype = 3

		INSERT INTO @HistoryMissingTransId (transid, sitetype)
		SELECT t.transid, 3
		FROM #CustLimitBet_LIC t	
		OUTER APPLY (
				SELECT TOP 1 t1.Transid
				FROM dbo.CustLimitBetHistory_LIC t1 WITH (NOLOCK)
				WHERE t1.Matchid = t.MatchId
					AND t1.CustID = t.CustId
					AND t1.Transid = t.transid
					AND t1.BRID = 0
			)tmp
		WHERE tmp.Transid IS NULL

	END

	IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp) --MBC
	BEGIN
		INSERT INTO @HistoryMissingTransId (transid, sitetype)
		SELECT t.transid, 1
		FROM #CustLimitBet_tmp t	
		OUTER APPLY (
				SELECT TOP 1 t1.Transid
				FROM dbo.CustLimitBetHistory_MBC t1 WITH (NOLOCK)
				WHERE t1.Matchid = t.MatchId
					AND t1.CustID = t.CustId
					AND t1.Transid = t.transid
					AND t1.BRID = 0
			)tmp
		WHERE tmp.Transid IS NULL

	END

	BEGIN TRY
		IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp) --MBC
		BEGIN
			UPDATE t SET t.AccumTurnover = (t.AccumTurnover + tmp.AccumTurnover), t.AccumPayout = (t.AccumPayout + tmp.AccumPayout), t.LastQueueID = @QueueId, t.ModifiedDate = GETDATE()
			FROM dbo.CustLimitBet_MBC t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT CASE WHEN @ActionId IN (1,2,4) THEN -SUM(tmpsum.AccumTurnover) ELSE SUM(tmpsum.AccumTurnover) END AS AccumTurnover
						,CASE WHEN  @ActionId IN (1,2,4) THEN -SUM(tmpsum.AccumPayout) ELSE SUM(tmpsum.AccumPayout) END AS AccumPayout
						,tmpsum.MatchId, tmpsum.CustId
					FROM
					(
						SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t1.MatchId, t1.CustId, t1.transid, t2.EventTypeID
						FROM #CustLimitBet_tmp t1
							CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID
								FROM dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = 0 AND t2.BRID = t1.BRID THEN 1
												WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = t1.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t2
						GROUP BY t1.Matchid, t1.CustId, t1.transid, t2.EventTypeID
					)tmpsum
					WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
					GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
				)tmp

			IF @ActionId IN (1,3,4,5) 
			BEGIN
				INSERT INTO dbo.CustLimitBetHistory_MBC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, BRID)
				SELECT t.CustId, t.MatchId
					, CASE WHEN t1.Transid = 0 THEN 0 ELSE t.transid END
					, CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.TurnoverAdjust) ELSE MAX(t1.TurnoverAdjust) END
					,CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.PayoutAdjust) ELSE MAX(t1.PayoutAdjust) END
					, t1.EventTypeID
					, CASE WHEN t1.BRID = 0 THEN 0 ELSE t.BRID END
				FROM #CustLimitBet_tmp t
					CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID, t2.Transid, t2.BRID
								FROM dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t.MatchId AND t2.CustID = t.CustId AND t2.Transid = 0 AND t2.BRID = t.BRID THEN 1
												WHEN t2.Matchid = t.MatchId AND t2.CustID = t.CustId AND t2.Transid = t.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t1
				GROUP BY t.Matchid, t.CustId, CASE WHEN t1.Transid = 0 THEN 0 ELSE t.transid END, t1.EventTypeID, CASE WHEN t1.BRID = 0 THEN 0 ELSE t.BRID END
			END
			
		END
		
		IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_789) --789y
		BEGIN
			UPDATE t SET t.AccumTurnover = (t.AccumTurnover + tmp.AccumTurnover), t.AccumPayout = (t.AccumPayout + tmp.AccumPayout), t.LastQueueID = @QueueId, t.ModifiedDate = GETDATE()
			FROM dbo.CustLimitBet_789 t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT CASE WHEN @ActionId IN (1,2,4) THEN -SUM(tmpsum.AccumTurnover) ELSE SUM(tmpsum.AccumTurnover) END AS AccumTurnover
						,CASE WHEN  @ActionId IN (1,2,4) THEN -SUM(tmpsum.AccumPayout) ELSE SUM(tmpsum.AccumPayout) END AS AccumPayout
						,tmpsum.MatchId, tmpsum.CustId
					FROM
					(
						SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t1.MatchId, t1.CustId, t1.transid, t2.EventTypeID
						FROM #CustLimitBet_789 t1
							CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID
								FROM dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = 0 AND t2.BRID = t1.BRID THEN 1
												WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = t1.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t2
						GROUP BY t1.Matchid, t1.CustId, t1.transid, t2.EventTypeID
					)tmpsum
					WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
					GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
				)tmp

			IF @ActionId IN (1,3,4,5) 
			BEGIN
				INSERT INTO dbo.CustLimitBetHistory_789 (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, BRID)
				SELECT t.CustId, t.MatchId
					, CASE WHEN t1.Transid = 0 THEN 0 ELSE t.transid END
					, CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.TurnoverAdjust) ELSE MAX(t1.TurnoverAdjust) END
					,CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.PayoutAdjust) ELSE MAX(t1.PayoutAdjust) END
					, t1.EventTypeID
					, CASE WHEN t1.BRID = 0 THEN 0 ELSE t.BRID END
				FROM #CustLimitBet_789 t
					CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID, t2.Transid, t2.BRID
								FROM dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t.MatchId AND t2.CustID = t.CustId AND t2.Transid = 0 AND t2.BRID = t.BRID THEN 1
												WHEN t2.Matchid = t.MatchId AND t2.CustID = t.CustId AND t2.Transid = t.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t1
				GROUP BY t.Matchid, t.CustId, CASE WHEN t1.Transid = 0 THEN 0 ELSE t.transid END, t1.EventTypeID, CASE WHEN t1.BRID = 0 THEN 0 ELSE t.BRID END
			END
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_LIC) --Deposit
		BEGIN
			UPDATE t SET t.AccumTurnover = (t.AccumTurnover + tmp.AccumTurnover), t.AccumPayout = (t.AccumPayout + tmp.AccumPayout), t.LastQueueID = @QueueId, t.ModifiedDate = GETDATE()
			FROM dbo.CustLimitBet_LIC t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT CASE WHEN @ActionId IN (1,2,4) THEN -SUM(tmpsum.AccumTurnover) ELSE SUM(tmpsum.AccumTurnover) END AS AccumTurnover
						,CASE WHEN  @ActionId IN (1,2,4) THEN -SUM(tmpsum.AccumPayout) ELSE SUM(tmpsum.AccumPayout) END AS AccumPayout
						,tmpsum.MatchId, tmpsum.CustId
					FROM
					(
						SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t1.MatchId, t1.CustId, t1.transid, t2.EventTypeID
						FROM #CustLimitBet_LIC t1
							CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID
								FROM dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = 0 AND t2.BRID = t1.BRID THEN 1
												WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = t1.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t2
						GROUP BY t1.Matchid, t1.CustId, t1.transid, t2.EventTypeID
					)tmpsum
					WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
					GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
				)tmp

			IF @ActionId IN (1,3,4,5) 
			BEGIN
				INSERT INTO dbo.CustLimitBetHistory_LIC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, BRID)
				SELECT t.CustId, t.MatchId
					, CASE WHEN t1.Transid = 0 THEN 0 ELSE t.transid END
					, CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.TurnoverAdjust) ELSE MAX(t1.TurnoverAdjust) END
					,CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.PayoutAdjust) ELSE MAX(t1.PayoutAdjust) END
					, t1.EventTypeID
					, CASE WHEN t1.BRID = 0 THEN 0 ELSE t.BRID END
				FROM #CustLimitBet_LIC t
					CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID, t2.Transid, t2.BRID
								FROM dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t.MatchId AND t2.CustID = t.CustId AND t2.Transid = 0 AND t2.BRID = t.BRID THEN 1
												WHEN t2.Matchid = t.MatchId AND t2.CustID = t.CustId AND t2.Transid = t.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t1
				GROUP BY t.Matchid, t.CustId, CASE WHEN t1.Transid = 0 THEN 0 ELSE t.transid END, t1.EventTypeID, CASE WHEN t1.BRID = 0 THEN 0 ELSE t.BRID END
			END
			
		END
	END TRY
	BEGIN CATCH
		SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
		RETURN
	END CATCH
	
	IF EXISTS (SELECT TOP(1) 1 FROM @HistoryMissingTransId)
	BEGIN
		--Insert into CustLimitBet_QueueRetry for Retry process
		IF @ActionId = 2 
		BEGIN
			INSERT INTO dbo.CustLimitBet_QueueRetry (TransId, MainQueueId, StatusId, sitetype)
			SELECT t.transid, @QueueId, 0, t.sitetype
			FROM @HistoryMissingTransId t
		END
		ELSE
		BEGIN
			SELECT TOP (5) @InvalidTransIds = @InvalidTransIds + ',' + CAST(t.transid AS VARCHAR)
			FROM @HistoryMissingTransId t

			SELECT @ErrCode = 100
			SELECT @InvalidTransIds = SUBSTRING(@InvalidTransIds, 2, LEN(@InvalidTransIds) - 1)
			SELECT @ErrMsg = 'Some transids not found on CustLimitBetHistory. Here are top 5 example transids: ' + @InvalidTransIds
		END
	END
	
	DROP TABLE #CustLimitBet_tmp
	DROP TABLE #CustLimitBet_789
	DROP TABLE #CustLimitBet_LIC
END	
GO


