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
		)

	CREATE TABLE #CustLimitBet_789 (
		MatchId	INT
			, CustId INT
			, sitetype TINYINT
			, transid BIGINT
	)


	IF @ActionId IN (1,3,4,5) --VOID,RECOVER,SETTLE
	BEGIN
		
		SET @xml = CONVERT(XML, @Transids)

		INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid)        
		SELECT @MatchId AS MatchId
			, t.c.value('@custid','int') AS custid
			,t.c.value('@sitetype','tinyint') AS sitetype
			,t.c.value('@transid','BIGINT') AS transid
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
			INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid, sporttype, bettype)
			SELECT @MatchId
				, b.custid
				,CASE WHEN c.site = '789y' THEN 2 ELSE 1 END
				,b.transid
				,m.sporttype
				,b.bettype
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
				LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK) ON s.custid = b.srecommend
			WHERE b.transid BETWEEN @MinTransId AND @MaxTransId
				AND b.matchid = @MatchId
				AND b.checktime = @RejectTime
				AND b.statusID = 101
				AND s.custid IS NULL
		END
		ELSE IF @MatchId = 29  --Parlay
		BEGIN
			INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid)
			SELECT @MatchId
				, b.custid
				,CASE WHEN c.site = '789y' THEN 2 ELSE 1 END
				,b.transid
			FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
				LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK) ON s.custid = b.srecommend
			WHERE b.transid BETWEEN @MinTransId AND @MaxTransId
				AND b.matchid = 29
				AND b.checktime = @RejectTime
				AND b.statusID = 101
				AND s.custid IS NULL
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
			DELETED.CustId, DELETED.sitetype, DELETED.transid, @MatchId
			INTO #CustLimitBet_789 (CustId, sitetype, transid, MatchId)
		FROM #CustLimitBet_tmp t
		WHERE t.sitetype = 2

		SELECT TOP (5) @InvalidTransIds = @InvalidTransIds + ',' + CAST(t.transid AS VARCHAR)
		FROM #CustLimitBet_789 t	
		OUTER APPLY (
				SELECT TOP 1 t1.Transid
				FROM dbo.CustLimitBetHistory_789 t1 WITH (NOLOCK)
				WHERE t1.Matchid = t.MatchId
					AND t1.CustID = t.CustId
					AND t1.Transid = t.transid
			)tmp
		WHERE tmp.Transid IS NULL

	END

	IF EXISTS (SELECT TOP(1) 1 FROM #CustLimitBet_tmp) --MBC
	BEGIN
		--Not support deposit in this phase
		DELETE t 
		FROM #CustLimitBet_tmp t
		WHERE t.sitetype = 3

		SELECT TOP (5) @InvalidTransIds = @InvalidTransIds + ',' + CAST(t.transid AS VARCHAR)
		FROM #CustLimitBet_tmp t	
		OUTER APPLY (
				SELECT TOP 1 t1.Transid
				FROM dbo.CustLimitBetHistory_MBC t1 WITH (NOLOCK)
				WHERE t1.Matchid = t.MatchId
					AND t1.CustID = t.CustId
					AND t1.Transid = t.transid
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
							INNER JOIN dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = t1.CustId and t2.Transid = t1.transid
						GROUP BY t1.Matchid, t1.CustId, t1.transid, t2.EventTypeID
					)tmpsum
					WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
					GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
				)tmp

			IF @ActionId IN (1,3,4,5) 
			BEGIN
				INSERT INTO dbo.CustLimitBetHistory_MBC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
				SELECT t.CustId, t.MatchId, t.transid
					, CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.TurnoverAdjust) ELSE MAX(t1.TurnoverAdjust) END
					,CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.PayoutAdjust) ELSE MAX(t1.PayoutAdjust) END
					, t1.EventTypeID
				FROM #CustLimitBet_tmp t
					INNER JOIN dbo.CustLimitBetHistory_MBC t1 WITH (NOLOCK) ON t1.Matchid = t.MatchId and t1.CustID = t.CustId and t1.Transid = t.transid
				GROUP BY t.Matchid, t.CustId, t.transid, t1.EventTypeID
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
							INNER JOIN dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = t1.CustId and t2.Transid = t1.transid
						GROUP BY t1.Matchid, t1.CustId, t1.transid, t2.EventTypeID
					)tmpsum
					WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
					GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
				)tmp

			IF @ActionId IN (1,3,4,5) 
			BEGIN
				INSERT INTO dbo.CustLimitBetHistory_789 (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
				SELECT t.CustId, t.MatchId, t.transid
					, CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.TurnoverAdjust) ELSE MAX(t1.TurnoverAdjust) END
					,CASE WHEN @ActionId IN (1,4) THEN -MAX(t1.PayoutAdjust) ELSE MAX(t1.PayoutAdjust) END
					, t1.EventTypeID
				FROM #CustLimitBet_789 t
					INNER JOIN dbo.CustLimitBetHistory_789 t1 WITH (NOLOCK) ON t1.Matchid = t.MatchId and t1.CustID = t.CustId and t1.Transid = t.transid
				GROUP BY t.Matchid, t.CustId, t.transid, t1.EventTypeID
			END
		END
	END TRY
	BEGIN CATCH
		SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
		RETURN
	END CATCH

	IF @InvalidTransIds <> ''
	BEGIN
		SELECT @ErrCode = 100
		SELECT @InvalidTransIds = SUBSTRING(@InvalidTransIds, 2, LEN(@InvalidTransIds) - 1)
		SELECT @ErrMsg = 'Some transids not found on CustLimitBetHistory. Here are top 5 example transids: ' + @InvalidTransIds
	END

	DROP TABLE #CustLimitBet_tmp
	DROP TABLE #CustLimitBet_789
END	
GO


