/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_MP] 
	@AdminId			INT
	,@MatchId			INT
	,@Action			VARCHAR(10)		= 'CAL'
	,@CALBettypes		VARCHAR(MAX)
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170106@Bobby
	Task: 77720 - Implement BetRadar VS League & Nation for Parlay
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		
	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlBettype	 	XML
	DECLARE @tempBettype TABLE (bettype SMALLINT)
	
	--CONVERT bettype
	SET @xmlBettype = CONVERT(XML, @CALBettypes)
	
	INSERT INTO @tempBettype (bettype)
	SELECT T.C.value('./@t', 'SMALLINT') AS bettype
	FROM @xmlBettype.nodes('/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlBettype = NULL ))
	
	IF (@@ROWCOUNT = 0) RETURN
	
	
	--BEGIN CAL sub-tickets mix-parlay
	/*BEGIN
	
	CREATE TABLE #tempRefno9 (
		refno		BIGINT PRIMARY KEY
		,transid	BIGINT
		,statusId	TINYINT
		,winlost	MONEY
		,stake		MONEY
	)
	
	INSERT INTO #tempRefno2799 (refno, transid, statusId, winlost, stake)
	SELECT	b.refno, b.transid, b.statusID, b.winlost, b.stake
	FROM	dbo.bettrans b WITH(NOLOCK)
		INNER JOIN @refnos r
			ON	b.refno = r.refno
				AND b.matchid = 9
				AND b.bettype = 9
				AND b.statusID NOT IN (101,102) --('VOID','REJECT')	
			
	IF @@rowcount > 0
	BEGIN --BEGIN: calculate 9 ----------------------------------
	
		DECLARE @statusID tinyint, @winlostdate smalldatetime		
		declare @tstime datetime, @duration int, @runcnt int = 0	
		
		CREATE TABLE #tempResult2799 (
			refno			BIGINT PRIMARY KEY
			,winlostdate	SMALLDATETIME
			,statusId		TINYINT
			,modds			MONEY
			,rate			MONEY
		)
			
		INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
		VALUES (@matchid, @runcnt, CURRENT_TIMESTAMP, NULL, 'Start running SP 9_cal')	
		
		;WITH p AS (
			SELECT parlay.refno as refno
				,SUM(CASE WHEN parlay.statusID IN (121, 103) THEN 0 ELSE 1 END) as NoRefund
				,SUM(CASE WHEN parlay.statuswinlost = 4 THEN 1 ELSE 0 END) as loseCnt
				,SUM(CASE WHEN parlay.statusID IN (0, 1) THEN 1 ELSE 0 END) as runningCnt
				,MAX(winlostdate) as matchdate_max
				,CAST(EXP(SUM(CAST(LOG(
					case parlay.statuswinlost
						when 0 then 1 -- draw 
						when 1 then 1+((parlay.odds-1)/2) -- half won
						when 2 then parlay.odds -- won
						when 3 then 0.5 -- half lose
						when 4 then 0.000000000001 -- lose
						else 1 -- void/reject
					end
					) AS DECIMAL(38, 20)))) as MONEY) as modds
			FROM #tempRefno2799 t
				CROSS APPLY(
					SELECT	bm.transid, bm.odds, bm.refno, bm.statuswinlost, bm.statusID, bm.winlostdate
					FROM	dbo.bettransm bm WITH(rowlock)	
						INNER JOIN dbo.match m WITH (NOLOCK)
							ON	bm.matchid = m.matchid
					WHERE	bm.refno = t.refno
							AND m.sporttype BETWEEN 1 AND 99											
					UNION
					SELECT	bm14.transid, bm14.odds, bm14.refno, bm14.statuswinlost, bm14.statusID, bm14.winlostdate 
					FROM	dbo.bettransm14 bm14 WITH(rowlock)			
						INNER JOIN dbo.match14 m14 WITH(NOLOCK)
							ON bm14.matchid = m14.matchid
					WHERE	bm14.refno = t.refno
							AND m14.sporttype BETWEEN 1 AND 99
				) parlay 
			GROUP BY parlay.refno
		)	
		INSERT INTO #tempResult2799(refno, winlostdate, StatusId, modds, rate)
		SELECT refno
				,CASE
					WHEN loseCnt > 0 THEN @matchdate --lose
					WHEN runningCnt > 0 THEN p.matchdate_max -- running
					WHEN NoRefund = 0 THEN p.matchdate_max-- Refund
					WHEN p.modds < 1 THEN @matchdate -- Lose
					WHEN p.modds = 1 THEN p.matchdate_max -- Draw
					ELSE p.matchdate_max -- Won
					END as winlostdate			
				,CASE
					WHEN loseCnt > 0 THEN 113 -- Lose
					WHEN runningCnt > 0 THEN 0 -- running
					WHEN NoRefund = 0 THEN 103 -- Refund
					WHEN p.modds < 1 THEN 113 -- Lose
					WHEN p.modds = 1 THEN 111 -- Draw
					ELSE 112 -- Won
					END as statusID	
				,p.modds
				,CASE WHEN loseCnt > 0 OR runningCnt > 0 THEN 0 ELSE p.modds END AS rate
		FROM p
		
		SELECT b.transid as transid					
			,r.winlostdate			
			,r.statusID	
			,r.modds
			,0 AS IsFinished
		INTO  #temp_bettrans_9			
		FROM #tempRefno2799 b
			INNER JOIN #tempResult2799 r ON b.refno = r.refno
		WHERE (b.statusID <> r.statusId OR b.winlost <> r.rate * b.stake)
		
		SET @runcnt = @@rowcount
		INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
		VALUES (@matchid, @runcnt, CURRENT_TIMESTAMP, NULL, 'start updating bettrans')		
				
		--
		DECLARE @tempStatus as TABLE (statusID tinyint, winlostdate smalldatetime, isfinished bit)
		CREATE TABLE #tempTransID (transID bigint, modds MONEY)

		CREATE INDEX IX_temp_bettrans_9 ON #temp_bettrans_9 (statusid, winlostdate)
		
			-- CAPTURE value BALANCE before udpate bettrans
		INSERT INTO #BalanceBefore_9
		SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM	dbo.bettrans b with (rowlock)
		WHERE	transid IN (SELECT transid FROM #temp_bettrans_9)
				AND b.matchid = 9
				AND b.bettype = 9
		GROUP BY b.custid	
		
		INSERT INTO @tempStatus (statusID, winlostdate, isfinished)
		SELECT distinct statusID, winlostdate, 0
		FROM #temp_bettrans_9			
	
		WHILE (1 = 1)
		BEGIN
			UPDATE TOP (1) @tempStatus
			SET isfinished = 1
				,@statusID = statusID
				,@winlostdate = winlostdate
			WHERE isfinished = 0

			IF @@ROWCOUNT = 0 BREAK -- no more to do

			WHILE (1 = 1)
			BEGIN
			
				TRUNCATE TABLE #tempTransID

				UPDATE TOP (2000) #temp_bettrans_9
				SET isFinished = 1
				OUTPUT	INSERTED.transID, INSERTED.modds into #tempTransID(transid, modds)
				WHERE	statusID = @statusID 
						AND winlostdate = @winlostdate
						AND isFinished = 0

				SET @runcnt = @@ROWCOUNT
				IF @runcnt = 0 BREAK
				
				 SET @strTransIds = CONVERT(varchar(max),(  
				   SELECT  
						transid '@t'  
						,NULLIF(modds,0) '@m'  
				   FROM #tempTransID	
				   FOR XML PATH('r'), ROOT('root'), TYPE  
				  ))     
			  
				SET @strTransIds = REPLACE(REPLACE(@strTransIds, '<root><r t="', ''), '"/></root>', '')
				SET @strTransIds = REPLACE(REPLACE(@strTransIds, '" m="', '|'), '"/><r t="', ',')
  								
				--------------------------------------------------------------	
				SET @tstime = CURRENT_TIMESTAMP			
				 
																																																																EXEC dbo.NAP_Admin_Calculate_MP_broker @mode = '9'
					,@strXML = @strTransIds 
					,@statusID = @statusID
					,@winlostdate = @winlostdate 
				
				SET @duration = datediff(s, @tstime, CURRENT_TIMESTAMP)				
				INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, strXML, statusID)
				VALUES (@matchid, @runcnt, @tstime, CURRENT_TIMESTAMP, @strTransIds, @statusID)
			
			END -- end while		
		END --end while		
		
		-- CAPTURE value BALANCE after udpate bettrans
		INSERT INTO #BalanceAfter_9
		SELECT	b.custid, SUM(b.winlost-b.actual_stake+b.playercomm)
		FROM	dbo.bettrans b with(rowlock)
		WHERE	transid IN (SELECT transid FROM #temp_bettrans_9)
				AND b.matchid = 9
				AND b.bettype = 9
		GROUP BY b.custid
		
		-- compare balance
		INSERT INTO #Balance_9
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM #BalanceBefore_9 b
			INNER JOIN #BalanceAfter_9 a ON b.custid = a.custid
		WHERE b.balance <> a.balance
		
		INSERT INTO @tblDebitPending_9 (custID, balance)
		SELECT	custid, ABS(balance)
		FROM	#Balance_9
		WHERE	Increased = 0
		
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingDebitIns 
				@BalancePending = @tblDebitPending_9
				,@Type			= 1 -- Sports

		INSERT INTO @tblCreditPending_9 (custid, balance)
		SELECT custid, balance
		FROM #Balance_9
		WHERE Increased = 1
			
		IF @@rowcount <> 0
			EXEC dbo.Dot_BalancePendingCreditIns
				@BalancePending = @tblCreditPending_9
				,@Type			= 1 -- Sports
		----
		-- Add Negative Balance into BalanceNegative table 
		----
		INSERT INTO [bodb02].[dbo].[BalanceNegative] (
			[ExecDate]
			,[MatchID]
			,[ActionID]
			,[GroupID]
			,[CustID]
			,[Balance]
			,[StatusID]
			,[Remark]
			)
		SELECT GETDATE()
			,@MatchID
			,134 --Task_Calculate_Parlay
			,2 -- Sportsbook Parlay Settlement 
			,CustID
			,Balance
			,0
			,NULL
		FROM #Balance_9 WITH (NOLOCK)
		WHERE Increased = 0								
	END --END: calculate 9 ----------------------------------
	END*/

	RETURN
END
GO