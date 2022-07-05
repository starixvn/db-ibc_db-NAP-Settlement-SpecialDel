/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Dot_Member_CustLimitBet_Select]
(
	@MatchId		INT = NULL
	,@custid		INT
	,@sitetype		TINYINT
	,@EventTypeID	TINYINT
	,@LeagueID		INT = NULL
	,@AccumTurnover MONEY = 0 OUTPUT
	,@AccumPayout	MONEY = 0 OUTPUT
)
AS
/*	
	Created: 20210726@Max
    Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20210726@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20220317@Max: Support Max Payout & Max Turnover for Deposit - [Redmine: #167898]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LastQueueID INT = 0
		,@AccumTurnover_InQueue MONEY = 0
		,@AccumPayout_InQueue MONEY = 0
		
	CREATE TABLE #CustLimitBet_tmp (
			MatchId	INT
			, CustId INT
			, transid BIGINT
			, BRID BIGINT
		)

	--For outright will be sum up to League
	IF @EventTypeID = 2 AND @LeagueID IS NOT NULL
	BEGIN
		IF @sitetype = 1
		BEGIN
			SELECT @AccumTurnover = SUM(c.AccumTurnover), @AccumPayout = SUM(c.AccumPayout), @LastQueueID = MAX(c.LastQueueID)
			FROM dbo.CustLimitBet_MBC c WITH (NOLOCK)
				INNER JOIN dbo.outright o WITH (NOLOCK) ON o.orid = c.Matchid
			WHERE c.CustID = @custid
				AND c.EventTypeID = @EventTypeID
				AND o.oddsstatus <> 'Completed'
				AND o.leagueid = @LeagueID
		END
		ELSE IF @sitetype = 2
		BEGIN
			SELECT @AccumTurnover = SUM(c.AccumTurnover), @AccumPayout = SUM(c.AccumPayout), @LastQueueID = MAX(c.LastQueueID)
			FROM dbo.CustLimitBet_789 c WITH (NOLOCK)
				INNER JOIN dbo.outright o WITH (NOLOCK) ON o.orid = c.Matchid
			WHERE c.CustID = @custid
				AND c.EventTypeID = @EventTypeID
				AND o.oddsstatus <> 'Completed'
				AND o.leagueid = @LeagueID
		END
		ELSE IF @sitetype = 3
		BEGIN
			SELECT @AccumTurnover = SUM(c.AccumTurnover), @AccumPayout = SUM(c.AccumPayout), @LastQueueID = MAX(c.LastQueueID)
			FROM dbo.CustLimitBet_LIC c WITH (NOLOCK)
				INNER JOIN dbo.outright o WITH (NOLOCK) ON o.orid = c.Matchid
			WHERE c.CustID = @custid
				AND c.EventTypeID = @EventTypeID
				AND o.oddsstatus <> 'Completed'
				AND o.leagueid = @LeagueID
		END
	
		--get bonus data from queue
		IF EXISTS ( SELECT TOP(1) 1 FROM dbo.CustLimitBetQueue q WITH (NOLOCK)
							INNER JOIN outright o WITH (NOLOCK) ON o.orid = q.Matchid
				WHERE q.QueueID > @LastQueueID 
					AND q.ActionID = 3 
					AND q.CustID = @custid  
					AND q.EventTypeID = @EventTypeID 
					AND o.leagueid = @LeagueID
					AND o.oddsstatus <> 'Completed' )
		BEGIN
			INSERT INTO #CustLimitBet_tmp(MatchId, CustId, transid)
			SELECT q.Matchid, @custid, xTrans.transid
			FROM dbo.CustLimitBetQueue q WITH (NOLOCK)
				INNER JOIN outright o WITH (NOLOCK) ON o.orid = q.Matchid
				CROSS APPLY (
						SELECT CONVERT(XML, q.Transids)
					)AS t(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@transid','BIGINT') AS transid
						FROM t.xDATA.nodes('root/r') t(c)
					)xTrans
			WHERE q.QueueID > @LastQueueID 
				AND q.ActionID = 3 
				AND q.CustID = @custid
				AND q.EventTypeID = @EventTypeID 
				AND o.leagueid = @LeagueID
				AND o.oddsstatus <> 'Completed'
		END
	END
	
	--For match normal, Bettype 38
	IF @EventTypeID IN (1,5) AND @LeagueID IS NULL
	BEGIN
		IF @sitetype = 1
		BEGIN
			SELECT @AccumTurnover = c.AccumTurnover, @AccumPayout = c.AccumPayout, @LastQueueID = c.LastQueueID
			FROM dbo.CustLimitBet_MBC c WITH (NOLOCK)
			WHERE c.Matchid = @MatchId
				AND c.CustID = @custid
				AND c.EventTypeID = @EventTypeID
		END
		ELSE IF @sitetype = 2
		BEGIN
			SELECT @AccumTurnover = c.AccumTurnover, @AccumPayout = c.AccumPayout, @LastQueueID = c.LastQueueID
			FROM dbo.CustLimitBet_789 c WITH (NOLOCK)
			WHERE c.Matchid = @MatchId
				AND c.CustID = @custid
				AND c.EventTypeID = @EventTypeID
		END
		ELSE IF @sitetype = 3
		BEGIN
			SELECT @AccumTurnover = c.AccumTurnover, @AccumPayout = c.AccumPayout, @LastQueueID = c.LastQueueID
			FROM dbo.CustLimitBet_LIC c WITH (NOLOCK)
			WHERE c.Matchid = @MatchId
				AND c.CustID = @custid
				AND c.EventTypeID = @EventTypeID
		END
	
		--get bonus data from queue
		IF EXISTS ( SELECT TOP(1) 1 FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
				WHERE q.QueueID > @LastQueueID 
					AND q.ActionID = 3 
					AND q.Matchid = @MatchId 
					AND q.CustID = @custid 
					AND q.EventTypeID = @EventTypeID )
		BEGIN
			INSERT INTO #CustLimitBet_tmp(MatchId, CustId, transid, BRID)
			SELECT @MatchId AS MatchId
				, @custid AS custid
				, xTrans.transid
				, xTrans.BRID
			FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
				CROSS APPLY (
						SELECT CONVERT(XML, q.Transids)
					)AS t(xDATA)
				CROSS APPLY (
						SELECT t.c.value('@transid','BIGINT') AS transid
							,t.c.value('@brid','BIGINT') AS BRID
						FROM t.xDATA.nodes('root/r') t(c)
					)xTrans
			WHERE q.QueueID > @LastQueueID 
				AND q.ActionID = 3 
				AND q.Matchid = @MatchId 
				AND q.CustID = @custid
				AND q.EventTypeID = @EventTypeID
		END
	END

	--For Parlay
	IF @EventTypeID IN (3,4) AND @MatchId = 29
	BEGIN
		IF @sitetype = 1
		BEGIN
			SELECT @AccumTurnover = c.AccumTurnover, @AccumPayout = c.AccumPayout, @LastQueueID = c.LastQueueID
			FROM dbo.CustLimitBet_MBC c WITH (NOLOCK)
			WHERE c.Matchid = @MatchId
				AND c.CustID = @custid
				AND c.EventTypeID = @EventTypeID
			
			--get bonus data from queue
			IF EXISTS ( SELECT TOP(1) 1 FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
					WHERE q.QueueID > @LastQueueID 
						AND q.ActionID = 3 
						AND q.Matchid = @MatchId 
						AND q.CustID = @custid )
			BEGIN
				INSERT INTO #CustLimitBet_tmp(MatchId, CustId, transid)
				SELECT @MatchId AS MatchId
					, @custid AS custid
					, xTrans.transid
				FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
					CROSS APPLY (
							SELECT CONVERT(XML, q.Transids)
						)AS t(xDATA)
					CROSS APPLY (
							SELECT t.c.value('@transid','BIGINT') AS transid
							FROM t.xDATA.nodes('root/r') t(c)
						)xTrans
					INNER JOIN dbo.CustLimitBetHistory_MBC ch WITH (NOLOCK) ON ch.Matchid = @MatchId AND ch.CustID = @custid AND ch.Transid = xTrans.transid
				WHERE q.QueueID > @LastQueueID 
					AND q.ActionID = 3 
					AND q.Matchid = @MatchId 
					AND q.CustID = @custid
					AND ch.EventTypeID = @EventTypeID
			END
		END
		ELSE IF @sitetype = 2
		BEGIN
			SELECT @AccumTurnover = c.AccumTurnover, @AccumPayout = c.AccumPayout, @LastQueueID = c.LastQueueID
			FROM dbo.CustLimitBet_789 c WITH (NOLOCK)
			WHERE c.Matchid = @MatchId
				AND c.CustID = @custid
				AND c.EventTypeID = @EventTypeID

			--get bonus data from queue
			IF EXISTS ( SELECT TOP(1) 1 FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
					WHERE q.QueueID > @LastQueueID 
						AND q.ActionID = 3 
						AND q.Matchid = @MatchId 
						AND q.CustID = @custid )
			BEGIN
				INSERT INTO #CustLimitBet_tmp(MatchId, CustId, transid)
				SELECT @MatchId AS MatchId
					, @custid AS custid
					, xTrans.transid
				FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
					CROSS APPLY (
							SELECT CONVERT(XML, q.Transids)
						)AS t(xDATA)
					CROSS APPLY (
							SELECT t.c.value('@transid','BIGINT') AS transid
							FROM t.xDATA.nodes('root/r') t(c)
						)xTrans
					INNER JOIN dbo.CustLimitBetHistory_789 ch WITH (NOLOCK) ON ch.Matchid = @MatchId AND ch.CustID = @custid AND ch.Transid = xTrans.transid
				WHERE q.QueueID > @LastQueueID 
					AND q.ActionID = 3 
					AND q.Matchid = @MatchId 
					AND q.CustID = @custid
					AND ch.EventTypeID = @EventTypeID
			END
		END
		ELSE IF @sitetype = 3
		BEGIN
			SELECT @AccumTurnover = c.AccumTurnover, @AccumPayout = c.AccumPayout, @LastQueueID = c.LastQueueID
			FROM dbo.CustLimitBet_LIC c WITH (NOLOCK)
			WHERE c.Matchid = @MatchId
				AND c.CustID = @custid
				AND c.EventTypeID = @EventTypeID

			--get bonus data from queue
			IF EXISTS ( SELECT TOP(1) 1 FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
					WHERE q.QueueID > @LastQueueID 
						AND q.ActionID = 3 
						AND q.Matchid = @MatchId 
						AND q.CustID = @custid )
			BEGIN
				INSERT INTO #CustLimitBet_tmp(MatchId, CustId, transid)
				SELECT @MatchId AS MatchId
					, @custid AS custid
					, xTrans.transid
				FROM dbo.CustLimitBetQueue q WITH (NOLOCK) 
					CROSS APPLY (
							SELECT CONVERT(XML, q.Transids)
						)AS t(xDATA)
					CROSS APPLY (
							SELECT t.c.value('@transid','BIGINT') AS transid
							FROM t.xDATA.nodes('root/r') t(c)
						)xTrans
					INNER JOIN dbo.CustLimitBetHistory_LIC ch WITH (NOLOCK) ON ch.Matchid = @MatchId AND ch.CustID = @custid AND ch.Transid = xTrans.transid
				WHERE q.QueueID > @LastQueueID 
					AND q.ActionID = 3 
					AND q.Matchid = @MatchId 
					AND q.CustID = @custid
					AND ch.EventTypeID = @EventTypeID
			END
		END
	END

	IF EXISTS (SELECT TOP 1 1 FROM #CustLimitBet_tmp)
	BEGIN
		IF @sitetype = 1
		BEGIN
			SELECT @AccumTurnover_InQueue = SUM(tmpsum.AccumTurnover)
				,@AccumPayout_InQueue = SUM(tmpsum.AccumPayout)
			FROM
			(
				SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
				FROM #CustLimitBet_tmp t1
					CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID
								FROM dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = 0 AND t2.BRID = t1.BRID THEN 1
												WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = t1.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t2
				GROUP BY t1.Matchid, t1.CustId, t1.transid, t1.BRID
			)tmpsum	
		END
		ELSE IF @sitetype = 2
		BEGIN
			SELECT @AccumTurnover_InQueue = SUM(tmpsum.AccumTurnover)
				,@AccumPayout_InQueue = SUM(tmpsum.AccumPayout)
			FROM
			(
				SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
				FROM #CustLimitBet_tmp t1
					CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID
								FROM dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = 0 AND t2.BRID = t1.BRID THEN 1
												WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = t1.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t2
				GROUP BY t1.Matchid, t1.CustId, t1.transid, t1.BRID
			)tmpsum	
		END
		ELSE IF @sitetype = 3
		BEGIN
			SELECT @AccumTurnover_InQueue = SUM(tmpsum.AccumTurnover)
				,@AccumPayout_InQueue = SUM(tmpsum.AccumPayout)
			FROM
			(
				SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
				FROM #CustLimitBet_tmp t1
					CROSS APPLY (
								SELECT t2.TurnoverAdjust, t2.PayoutAdjust, t2.EventTypeID
								FROM dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK)
								WHERE 1 = CASE WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = 0 AND t2.BRID = t1.BRID THEN 1
												WHEN t2.Matchid = t1.MatchId AND t2.CustID = t1.CustId AND t2.Transid = t1.transid AND t2.BRID = 0 THEN 1
											ELSE 0 END
							)t2
				GROUP BY t1.Matchid, t1.CustId, t1.transid, t1.BRID
			)tmpsum	
		END
	END

	SET @AccumTurnover = ISNULL(@AccumTurnover,0) + ISNULL(@AccumTurnover_InQueue,0)
	SET @AccumPayout = ISNULL(@AccumPayout,0) + ISNULL(@AccumPayout_InQueue,0)

	DROP TABLE #CustLimitBet_tmp
END	
GO


