/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CustLimitBet_Insert_Credit]
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
	Created: 20230712@Max
    Task: Scale out DBTRANS for Credit market - [Redmine: #181595]
    DB: DBSIC/bodb02
    Revisions:
		- 20230712@Max: Clone from DBTRANS - [Redmine: #181595]
		- 20230905@Louisa: Support Max Payout for VS3 [Redmine:#193562]
		- 20240118@Louisa: Support Max Payout for VS4 [Redmine:#199700]
		- 20240325@Max: Max Payout - NAP_Admin_CustLimitBetQueue_Insert_Parlay Enhancement [Redmine: #202058]
		- 20250225@Max: Enhance case duplicate rejected parlay ticket in queue [Redmine: #218599]
	
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
		,@SiteDBGroupID SMALLINT

	SET @SiteDBGroupID = dbo.f_Get_SiteDBGroupID() 

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
	
	DECLARE @HistoryMissingTransId AS TABLE (transid BIGINT, sitetype TINYINT)
	DECLARE @tmpRejectTransId AS TABLE (transid BIGINT)
		 
	IF @ActionId IN (1,3) --VOID,RECOVER
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
	ELSE IF @ActionId IN (4,5) --PARLAY
	BEGIN
		SET @xml = CONVERT(XML, @Transids)

		INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid)        
		SELECT @MatchId AS MatchId
			,x_Data.custid
			,dp.sitetype
			,x_Data.transid
		FROM
		(	
			SELECT t.c.value('@custid','int') AS custid
				,t.c.value('@transid','BIGINT') AS transid
			FROM @xml.nodes('root/r') t(c)
		) x_Data
		CROSS APPLY (
				SELECT TOP 1 
				CASE 
					WHEN dp.custid IS NOT NULL THEN 3 --deposit 
					WHEN si.SiteLabel = '789y' THEN 2 --789y
					ELSE 1 
				END	AS sitetype
				FROM CustDB.dbo.Customer c WITH (NOLOCK) 
					INNER JOIN CustDB.dbo.Site si WITH(NOLOCK) ON c.site = si.site
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON c.srecommend = dp.custid
				WHERE c.custid = x_Data.custid
		) AS dp
		OPTION (OPTIMIZE FOR (@xml = NULL))
	END
	ELSE IF @ActionId = 2 --REJECT
	BEGIN
		BEGIN TRY
			SET @xml = CONVERT(XML, @Transids)

			IF @MatchId <> 29 --Match, Bettype 38
			BEGIN
				SELECT @MinTransId = t.c.value('@mintransid','bigint')
					,@MaxTransId = t.c.value('@maxtransid','bigint')
					,@RejectTime = t.c.value('@rejecttime','datetime')
				FROM @xml.nodes('root/rejectTicket') t(c)
				OPTION (OPTIMIZE FOR (@xml = NULL))

				INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid, sporttype, bettype)
				SELECT @MatchId
					, b.custid
					,CASE WHEN si.SiteLabel = '789y' THEN 2 --789y
						ELSE 1 END
					,b.transid
					,m.sporttype
					,b.bettype
				FROM dbo.bettrans b WITH (NOLOCK)
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					INNER JOIN CustDB.dbo.Site si WITH(NOLOCK) ON c.site = si.site
					INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
				WHERE b.transid BETWEEN @MinTransId AND @MaxTransId
					AND b.SiteDBGroupID = @SiteDBGroupID
					AND b.matchid = @MatchId
					AND b.checktime = @RejectTime
					AND b.statusID = 101
			END
			ELSE IF @MatchId = 29  --Parlay
			BEGIN
				IF @Transids LIKE '%rejectTicket%' --temp code for release, will remove after
				BEGIN
					SELECT @MinTransId = t.c.value('@mintransid','bigint')
						,@MaxTransId = t.c.value('@maxtransid','bigint')
						,@RejectTime = t.c.value('@rejecttime','datetime')
						,@Creator = t.c.value('@creator','int')
					FROM @xml.nodes('root/rejectTicket') t(c)
					OPTION (OPTIMIZE FOR (@xml = NULL))

					INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid)
					SELECT @MatchId
						, b.custid
						,CASE WHEN si.SiteLabel = '789y' THEN 2 --789y
							ELSE 1 END
						,b.transid
					FROM dbo.bettrans b WITH (NOLOCK)
						INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
						INNER JOIN CustDB.dbo.Site si WITH(NOLOCK) ON c.site = si.site
					WHERE b.transid BETWEEN @MinTransId AND @MaxTransId
						AND b.SiteDBGroupID = @SiteDBGroupID
						AND b.matchid = 29
						AND b.checktime = @RejectTime
						AND b.statusID = 101
						AND b.creator = @Creator
				END
				ELSE
					INSERT INTO @tmpRejectTransId (transid)
					SELECT t.c.value('@t','bigint')
					FROM @xml.nodes('root/r') t(c)
					OPTION (OPTIMIZE FOR (@xml = NULL))

					INSERT INTO #CustLimitBet_tmp(MatchId, CustId, sitetype, transid)
					SELECT @MatchId
						, b.custid
						,CASE WHEN  si.SiteLabel = '789y' THEN 2 --789y
							ELSE 1 END
						,b.transid
					FROM @tmpRejectTransId t
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.TransId				
						INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
						INNER JOIN CustDB.dbo.Site si WITH(NOLOCK) ON c.site = si.site
					WHERE b.SiteDBGroupID = @SiteDBGroupID
						AND b.matchid = 29
						AND b.statusID = 101
				END

			--Delete invalid transid in case insert queue duplicate
			DELETE t
			FROM #CustLimitBet_tmp t
			CROSS APPLY (
					SELECT SUM(l1.TurnoverAdjust) AS TurnoverAdjust
					FROM dbo.CustLimitBetHistory_MBC l1 WITH (NOLOCK)
					WHERE l1.Matchid = t.Matchid AND l1.CustID = t.CustId AND l1.Transid = t.transid
					GROUP BY l1.Matchid, l1.CustID, l1.Transid
					UNION ALL
					SELECT SUM(l2.TurnoverAdjust) AS TurnoverAdjust
					FROM dbo.CustLimitBetHistory_789 l2 WITH (NOLOCK)
					WHERE l2.Matchid = t.Matchid AND l2.CustID = t.CustId AND l2.Transid = t.transid
					GROUP BY l2.Matchid, l2.CustID, l2.Transid
			) t1
			WHERE t1.TurnoverAdjust = 0		
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
						,@ErrMsg = SUBSTRING(ERROR_MESSAGE(), 1, 300)
			RETURN
		END CATCH

		--Remove unsupport sporttype/bettype
		IF @MatchId <> 29
		BEGIN
			DELETE t
			FROM #CustLimitBet_tmp t
			WHERE (t.sporttype > 99  AND t.sporttype NOT IN (164,178,179,180,186,188) AND t.sporttype NOT BETWEEN 190 AND 197)
				OR (t.bettype IN(29, 2799,10449) OR (t.bettype BETWEEN 801 AND 806))
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

		INSERT INTO @HistoryMissingTransId (transid, sitetype )
		SELECT t.transid, 2
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
		INSERT INTO @HistoryMissingTransId (transid, sitetype)
		SELECT t.transid, 1
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

			IF @ActionId IN (1,2,3,4,5) 
			BEGIN
				INSERT INTO dbo.CustLimitBetHistory_MBC (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
				SELECT t.CustId, t.MatchId, t.transid
					, CASE WHEN @ActionId IN (1,4,2) THEN -MAX(t1.TurnoverAdjust) ELSE MAX(t1.TurnoverAdjust) END
					,CASE WHEN @ActionId IN (1,4,2) THEN -MAX(t1.PayoutAdjust) ELSE MAX(t1.PayoutAdjust) END
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

			IF @ActionId IN (1,2,3,4,5) 
			BEGIN
				INSERT INTO dbo.CustLimitBetHistory_789 (CustID, Matchid, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID)
				SELECT t.CustId, t.MatchId, t.transid
					, CASE WHEN @ActionId IN (1,4,2) THEN -MAX(t1.TurnoverAdjust) ELSE MAX(t1.TurnoverAdjust) END
					,CASE WHEN @ActionId IN (1,4,2) THEN -MAX(t1.PayoutAdjust) ELSE MAX(t1.PayoutAdjust) END
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
END	
GO


