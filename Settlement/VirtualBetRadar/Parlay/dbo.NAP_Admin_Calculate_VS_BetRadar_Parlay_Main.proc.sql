/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Main] 
	@matchid		INT
	,@strRefnos		VARCHAR(MAX)
	,@matchdate 	SMALLDATETIME 	= NULL
	,@ActionID		INT				= 0
	,@IsBalance		BIT 			= 1
	,@CWLBettype	SMALLINT 		= 1201
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(200)	= ''	OUTPUT
AS
/*	
	Creator: 20170106@Bobby
	Task: 77721 - Implement parlay bettype for BetRadar VS
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		- 20180214@Helen: Integrate VSBR 2 - Basketball - [Redmine:90154]
		- 20190604@Helen: User-Defined Aggregate SQL Function for Parlay Calculation [Redmine:#114391]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
	
	Notes: Below is used to calculate odds before CLR Function used 
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
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @parlayBettype		SMALLINT
		, @xmlRefno	 			XML
		, @strTransIds			VARCHAR(MAX)
		, @batchCount			INT
		, @balanceUpd			VARCHAR(MAX)
		, @BalanceType			TINYINT
		, @balanceAcc 			VARCHAR(MAX)
		, @GroupID			INT
	
	DECLARE @odds 				MONEY
		, @commWinRate 			MONEY 
		, @commLostRate 		MONEY
	
	
	DECLARE @tempRefno 			TABLE (refno BIGINT)
	DECLARE @BetTickets			TVP_Settlement_BetTicket
	
	CREATE TABLE #tempRefno2799 ( 
		[refno] 			[BIGINT]
		, [recommend] 		[INT]
		, [matchid] 		[INT]
		, [custid] 			[INT]
		, [bettype] 		[SMALLINT]
		, [transid] 		[BIGINT]
		, [actual_stake] 	[MONEY]
		, [stake] 			[MONEY]
		, [odds] 			[SMALLMONEY]
		, [comstatus] 		[NVARCHAR](20)
		, [apositiontaking] [SMALLMONEY]
		, [mpositiontaking] [SMALLMONEY]
		, [spositiontaking] [SMALLMONEY]
		, [playerdiscount] 	[DECIMAL](9, 8)
		, [discount] 		[DECIMAL](9, 8)
		, [adiscount] 		[DECIMAL](9, 8)
		, [sdiscount] 		[DECIMAL](9, 8)
		, [WinLost] 		[MONEY]
		, [aWinLost] 		[MONEY]
		, [mWinLost] 		[MONEY]
		, [sWinLost] 		[MONEY]
		, [PlayerComm] 		[MONEY]
		, [comm] 			[MONEY]
		, [acomm] 			[MONEY]
		, [scomm] 			[MONEY]
		, [StatusID] 		[TINYINT]
		, [modds] 			[SMALLMONEY]
		, [winlostdate] 	[SMALLDATETIME]
		, [isChanged]		[BIT]
	)
	
	SELECT @parlayBettype 		= 2799
		, @ErrCode				= 0
		, @ErrMsg				= ''
		, @balanceType			= 4
		, @batchCount			= 2000
		, @balanceAcc			= ''
		, @GroupID				= 7 --VS Betradar
	
	--CONVERT refno
	SET @xmlRefno = CONVERT(XML, @strRefnos)
	
	INSERT INTO @tempRefno (refno)
	SELECT T.C.value('./@rn', 'BIGINT') AS refno
	FROM @xmlRefno.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlRefno = NULL ))
	
	IF (@@ROWCOUNT = 0) RETURN
	
	--SELECT main ticket info
	INSERT INTO #tempRefno2799 (refno, recommend, matchid, custid, bettype
		,transid, actual_stake, stake, odds
		,apositiontaking, mpositiontaking, spositiontaking 
		,playerdiscount,discount, adiscount, sdiscount
		,WinLost, aWinLost, mWinLost, sWinLost
		,PlayerComm, comm, acomm, scomm
		,StatusID, modds, winlostdate)
	SELECT refno
		, recommend
		, matchid
		, custid
		, bettype
		, transid, actual_stake, stake, odds
		, apositiontaking, mpositiontaking, spositiontaking
		, playerdiscount,discount, adiscount, sdiscount
		, WinLost, aWinLost, mWinLost, sWinLost
		, PlayerComm, comm, acomm, scomm
		, StatusID, modds, winlostdate
		
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.matchid = @parlayBettype
		AND b.bettype = @parlayBettype
		AND b.statusID NOT IN (101,102) --('VOID','REJECT')	
		AND EXISTS (SELECT 1 FROM @tempRefno WHERE refno = b.refno)
			
	IF @@ROWCOUNT = 0 RETURN
	
	--BEGIN: calculate 2799 ----------------------------------
	DECLARE @tstime 	DATETIME
		, @duration 	INT
		, @runcnt 		INT = 0	
	
	CREATE TABLE #tempResult2799 (
		refno			BIGINT PRIMARY KEY
		,winlostdate	SMALLDATETIME
		,statusId		TINYINT
		,modds			MONEY
		,rate			MONEY
	)
		
	;WITH subParlay AS (
		SELECT parlay.refno as refno
			,SUM(CASE WHEN parlay.statusID IN (121, 103) THEN 0 ELSE 1 END) as NoRefund
			,SUM(CASE WHEN parlay.statuswinlost = 4 THEN 1 ELSE 0 END) as loseCnt
			,SUM(CASE WHEN parlay.statusID IN (0, 1) THEN 1 ELSE 0 END) as runningCnt
			,MAX(parlay.winlostdate) as matchdate_max
			,CAST(dbo.PRODUCT(
				CASE parlay.statuswinlost
					WHEN 0 THEN 1 -- draw 
					WHEN 1 THEN 1+((parlay.odds-1)/2) -- half won
					WHEN 2 THEN parlay.odds -- won
					WHEN 3 THEN 0.5 -- half lose
					WHEN 4 THEN 0.000000000001 -- lose
					ELSE 1 -- void/reject
				END
				) AS MONEY) AS modds
		FROM #tempRefno2799 t
			CROSS APPLY(
				SELECT	bm.transid, bm.odds, bm.refno, bm.statuswinlost, bm.statusID, bm.winlostdate
				FROM	dbo.bettransm bm WITH(rowlock)	
					INNER JOIN dbo.match m WITH (NOLOCK)
						ON	bm.matchid = m.matchid
				WHERE	bm.refno = t.refno
						AND m.sporttype BETWEEN 190 AND 199											
				UNION
				SELECT	bm14.transid, bm14.odds, bm14.refno, bm14.statuswinlost, bm14.statusID, bm14.winlostdate
				FROM	dbo.bettransm14 bm14 WITH(rowlock)			
					INNER JOIN dbo.match14 m14 WITH(NOLOCK)
						ON bm14.matchid = m14.matchid
				WHERE	bm14.refno = t.refno
						AND m14.sporttype BETWEEN 190 AND 199
			) AS parlay 
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
	FROM subParlay AS p
	
	--Pre-calculate parlay main ticket
	UPDATE b
	SET isChanged 		= 1
		, statusID 		= r.statusID
		, winlostdate 	= r.winlostdate
		, modds			= r.modds
		, @odds = CASE WHEN r.statusID = 0 THEN 0 ELSE r.modds END
		, @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
			WHEN '0' THEN 1
			WHEN '1' THEN 0
			ELSE 1
			END
		, @commLostRate = CASE comstatus
			WHEN '0' THEN 1
			WHEN '1' THEN 2
			ELSE 1
			END
		,winlost = stake * @odds
		,awinlost = CASE 
			WHEN r.statusID = 113 AND @odds = 0 THEN stake * apositiontaking
			WHEN r.statusID IN (112, 113) THEN - stake * apositiontaking * (@odds - 1)
			ELSE 0
			END
		,mwinlost = CASE 
			WHEN r.statusID = 113 AND @odds = 0 THEN stake * mpositiontaking
			WHEN r.statusID IN (112, 113) THEN - stake * mpositiontaking * (@odds - 1)
			ELSE 0
			END
		,swinlost = CASE 
			WHEN r.statusID = 113 AND @odds = 0 THEN stake * spositiontaking
			WHEN r.statusID IN (112, 113) THEN - stake * spositiontaking * (@odds - 1)
			ELSE 0
			END
		,playercomm = CASE r.statusID
			WHEN 112 THEN @commWinRate * stake * playerdiscount
			WHEN 113 THEN @commLostRate * stake * playerdiscount
			ELSE 0
			END
		,comm = CASE r.statusID
			WHEN 112 THEN @commWinRate * discount * stake * (1 - apositiontaking)
			WHEN 113 THEN @commLostRate * discount * stake * (1 - apositiontaking)
			ELSE 0
			END
		,acomm = CASE r.statusID
			WHEN 112 THEN @commWinRate * adiscount * stake * (1 - apositiontaking - mpositiontaking)
			WHEN 113 THEN @commLostRate * adiscount * stake * (1 - apositiontaking - mpositiontaking)
			ELSE 0
			END
		,scomm = CASE r.statusID
			WHEN 112 THEN @commWinRate * sdiscount * stake * (1 - apositiontaking - mpositiontaking - spositiontaking)
			WHEN 113 THEN @commLostRate * sdiscount * stake * (1 - apositiontaking - mpositiontaking - spositiontaking)
			ELSE 0
			END
	FROM #tempRefno2799 b
		INNER JOIN #tempResult2799 r 
		ON b.refno = r.refno
	WHERE (b.statusID <> r.statusId OR b.winlost <> r.rate * b.stake)
		
	SET @runcnt = @@ROWCOUNT
	
	IF(@runcnt = 0) RETURN
	
	INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
	VALUES (@matchid, @runcnt, CURRENT_TIMESTAMP, NULL, 'start updating bettrans 2799_cal')		
	
	SET @tstime = CURRENT_TIMESTAMP					
	BEGIN TRY
		SET @strTransIds = CONVERT(varchar(max),(  
				   SELECT  
						transid AS '@t'  
						,NULLIF(modds,0) AS '@m'
				   FROM #tempRefno2799 AS r	
				   FOR XML PATH('r'), ROOT('root'), TYPE  
				  ))     
		WHILE (1 = 1)
		BEGIN
		
			DELETE @BetTickets
			--------------------------------------------------------------					
				
			DELETE TOP (@batchCount) #tempRefno2799
			OUTPUT deleted.recommend, deleted.matchid, deleted.custid, deleted.bettype, deleted.transid
				, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost
				, deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm
				, deleted.statusid, deleted.modds, deleted.actual_stake, deleted.winlostdate
			INTO @BetTickets(recommend, matchid, custid, bettype, transid
				, winlost, awinlost, mwinlost, swinlost
				, playercomm, comm, acomm, scomm
				, statusid, modds, actual_stake, winlostdate
			)	
			WHERE isChanged = 1
							
			IF @@ROWCOUNT = 0 BREAK
			
			EXEC dbo.NAP_Admin_Calculate_Bettrans
				@BetTickets		= @BetTickets
				,@Action		= 'CAL'
				,@CWLBettype	= @CWLBettype
				,@balanceUpd 	= @balanceUpd OUTPUT
				,@ErrCode 		= @ErrCode OUTPUT
				,@ErrMsg 		= @ErrMsg OUTPUT
			
			--tracing updated balance ACC
			IF(@balanceUpd IS NOT NULL)
			BEGIN
				SET @balanceAcc += @balanceUpd
			END		
						
			IF (@ErrCode > 0 ) BREAK
	
		END --end while		
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
	END CATCH
	--END: calculate 2799 ----------------------------------				
	
	SET @duration = datediff(s, @tstime, CURRENT_TIMESTAMP)				
	INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, strXML,  doing)
	VALUES (@matchid, @runcnt, @tstime, CURRENT_TIMESTAMP, @strTransIds, 'end updating bettrans 2799_cal')
	
	-- Settlement balance process
	IF(@IsBalance = 1)
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_BalanceProcess
			@BalanceAcc				= @balanceAcc
			, @BalanceType			= @BalanceType
			, @actionId				= @actionId
			, @MatchID				= @MatchID
			, @GroupID				= @GroupID		
	END
	
	DROP TABLE #tempRefno2799
	DROP TABLE #tempResult2799
	
END
GO