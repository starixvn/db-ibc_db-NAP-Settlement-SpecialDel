/*<info serverAlias="DBTXN-bodb02" executers="svc_tig" isFunction="0"></info>*/
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
		- 20240318@Max: Enhance temp table [Redmine: #199517]
		- 20240923@Max: Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing [Redmine: #211145]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @LastQueueID INT = 0
		,@AccumTurnover_InQueue MONEY = 0
		,@AccumPayout_InQueue MONEY = 0

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
			IF @sitetype = 1
			BEGIN
				;WITH cte AS
				(
					SELECT q.Matchid, @custid AS CustId, xTrans.transid
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
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
			END
			
			IF @sitetype = 2
			BEGIN
				;WITH cte AS
				(
					SELECT q.Matchid, @custid AS CustId, xTrans.transid
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
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
			END

			IF @sitetype = 3
			BEGIN
				;WITH cte AS
				(
					SELECT q.Matchid, @custid AS CustId, xTrans.transid
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
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
			END
		END
	END
	
	--For match normal, Bettype 38
	IF @EventTypeID IN (1,5,6) AND @LeagueID IS NULL
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
			IF @sitetype = 1
			BEGIN
				;WITH cte AS
				(
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
					WHERE q.QueueID > @LastQueueID 
						AND q.ActionID = 3 
						AND q.Matchid = @MatchId 
						AND q.CustID = @custid
						AND q.EventTypeID = @EventTypeID
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
			END

			IF @sitetype = 2
			BEGIN
				;WITH cte AS
				(
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
					WHERE q.QueueID > @LastQueueID 
						AND q.ActionID = 3 
						AND q.Matchid = @MatchId 
						AND q.CustID = @custid
						AND q.EventTypeID = @EventTypeID
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
			END

			IF @sitetype = 3
			BEGIN
				;WITH cte AS
				(
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
					WHERE q.QueueID > @LastQueueID 
						AND q.ActionID = 3 
						AND q.Matchid = @MatchId 
						AND q.CustID = @custid
						AND q.EventTypeID = @EventTypeID
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
			END
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
				;WITH cte AS
				(
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
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
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
				;WITH cte AS
				(
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
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
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
				;WITH cte AS
				(
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
				)
				SELECT @AccumTurnover_InQueue += SUM(tmpsum.AccumTurnover)
					,@AccumPayout_InQueue += SUM(tmpsum.AccumPayout)
				FROM
				(
					SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout
					FROM cte t1
						INNER JOIN dbo.CustLimitBetHistory_LIC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = @custid and t2.Transid = t1.transid
					GROUP BY t1.Matchid, t1.CustId, t1.transid
				)tmpsum	
			END
		END
	END

	SET @AccumTurnover = ISNULL(@AccumTurnover,0) + ISNULL(@AccumTurnover_InQueue,0)
	SET @AccumPayout = ISNULL(@AccumPayout,0) + ISNULL(@AccumPayout_InQueue,0)

END	
GO


