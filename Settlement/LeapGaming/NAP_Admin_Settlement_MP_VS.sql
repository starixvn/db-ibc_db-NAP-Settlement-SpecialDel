/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_MP_VS 
	@AdminId			INT
	,@MatchId			INT
	,@SportType			INT
	,@ResourcesJson		VARCHAR(MAX)
	,@Action			VARCHAR(10)
	,@ActionID			INT			
	,@MatchDate			SMALLDATETIME
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	
	Created: 20240118@Louisa
	Task: VS4-Cock Fighting Redmine: #199700
	DB: DBPRO/bodb02
	
	Revisions:
		- 20240118@Louisa: Initial
		
	Param's Explanation:
 
*/
BEGIN
	DECLARE @avaiableProcess		BIT
			,@SiteDBGroupId			SMALLINT
			,@IsCentral				BIT
			,@batchNo				INT = 1000
			,@IgnoreList 			VARCHAR(200) = 'DB04,DB042,DB043,DB044' --list server ignore settle
			,@strSubParlay			VARCHAR(MAX) = '' 
			,@BetTicketJson			VARCHAR(MAX) = ''
			,@GroupNegativeBalance	TINYINT		= 7
			,@CWLBettype			SMALLINT	= 1201 
			,@runcnt				INT			= 0
			,@odds 					MONEY
			,@commWinRate 			MONEY 
			,@commLostRate 			MONEY
			,@TotalTransMaxPO		INT
			,@actualPO				MONEY
			,@batchPO				SMALLINT = 500
			,@TransInfoMaxPO		VARCHAR(MAX)
			,@SPName			SYSNAME

	DECLARE @tmpRefnos TABLE (refno BIGINT)
	DECLARE @subtable TABLE(transid BIGINT, statuswinlost TINYINT, statusID TINYINT)
	DECLARE @MainTickets	TABLE (	recommend  INT, matchid INT, custid INT, bettype SMALLINT, transid BIGINT
								,winlost MONEY, awinlost MONEY, mwinlost MONEY, swinlost MONEY
								,playercomm MONEY, comm  MONEY, acomm MONEY, scomm MONEY
								,statusid TINYINT, modds SMALLMONEY, actual_stake MONEY, winlostdate SMALLDATETIME
								,actualPO MONEY
							  )
	DECLARE @tmpResult TABLE (HomeValue VARCHAR(20), AwayValue VARCHAR(20), BetType SMALLINT, BetID BIGINT, pfID SMALLINT)
	
	DECLARE @tmpTransMPO TABLE (custid INT, winlost MONEY, actualPO MONEY, transdate DATETIME, bettype SMALLINT, transid BIGINT)
	DECLARE @tmpTransMPOBatch TABLE (TransID BIGINT,custid INT, actualPO MONEY, MaxWinLimit MONEY, winlost MONEY,transdate DATETIME, bettype SMALLINT)
	DECLARE @tmpMaxWinLimit	TABLE( CustId INT, MaxWinLimit MONEY)

	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #tmpsubTransID (refno BIGINT, transid BIGINT, statuswinlost TINYINT, statusID TINYINT)
	CREATE TABLE #tempMainParlay ( 
		refno 		BIGINT
		,recommend 	INT
		,matchid 	INT
		,custid 	INT
		,bettype 	SMALLINT
		,transid 	BIGINT
		,actual_stake 	MONEY
		,stake 			MONEY
		,odds 			SMALLMONEY
		,comstatus 			NVARCHAR(20)
		,apositiontaking	SMALLMONEY
		,mpositiontaking	SMALLMONEY
		,spositiontaking	SMALLMONEY
		,playerdiscount	DECIMAL(9, 8)
		,discount 		DECIMAL(9, 8)
		,adiscount 		DECIMAL(9, 8)
		,sdiscount 		DECIMAL(9, 8)
		,WinLost 		MONEY
		,aWinLost 		MONEY
		,mWinLost 		MONEY
		,sWinLost 		MONEY
		,PlayerComm 	MONEY
		,comm 			MONEY
		,acomm 			MONEY
		,scomm 			MONEY
		,StatusID 		TINYINT
		,modds 			SMALLMONEY
		,winlostdate 	SMALLDATETIME 
		,isChanged		BIT
		,currency		TINYINT
		,transdate		DATETIME
		,actualPO		MONEY
	)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	CREATE TABLE #tempMainParlay_Pre ( 
		recommend 		INT
		, matchid 		INT
		, custid 		INT
		, bettype 		SMALLINT
		, transid 		BIGINT
		, actual_stake 	MONEY  
		, WinLost 		MONEY
		, aWinLost 		MONEY
		, mWinLost 		MONEY
		, sWinLost 		MONEY
		, PlayerComm 	MONEY
		, comm 			MONEY
		, acomm 		MONEY
		, scomm 		MONEY
		, StatusID 		TINYINT
		, modds 		SMALLMONEY
		, winlostdate 	SMALLDATETIME
		, currency		TINYINT
		, transdate		DATETIME
	)

	SELECT @SiteDBGroupId	  = (SELECT dbo.f_Get_SiteDBGroupID())
		 ,@SPName			  = OBJECT_NAME(@@PROCID)
	
	---get result, bettype, fomular
	INSERT INTO @tmpResult (HomeValue, AwayValue, BetType, BetID, pfID )
	SELECT ISNULL(h,''), ISNULL(a,''), bt, bid, pfid
	FROM OPENJSON (@ResourcesJson)WITH ( h VARCHAR(20), a VARCHAR(20), bt SMALLINT, bid BIGINT, pfid SMALLINT )

	IF @Action = 'CAL'
	BEGIN
		INSERT INTO #tmpsubTransID (refno, transid, statuswinlost, statusID)
		SELECT bm.refno
			 ,bm.transid
			 ,CASE  WHEN m.modds > 0.25 THEN 2
					WHEN m.modds = 0.25 THEN 1
					WHEN m.modds = 0 THEN 0
					WHEN m.modds = -0.25 THEN 3 
					WHEN m.modds < -0.25 THEN 4
					ELSE bm.statuswinlost
					END AS statuswinlost
			,CASE 	WHEN m.modds = 0 THEN 111
					WHEN m.modds > 0 THEN 112
					WHEN m.modds < 0 THEN 113
					ELSE bm.statusID
					END AS statusID
		FROM dbo.bettransm bm WITH(ROWLOCK)
		CROSS APPLY (	SELECT	TOP 1 r.pfID, r.HomeValue, r.AwayValue
						FROM @tmpResult r
						WHERE r.BetType = bm.bettype
							AND (r.BetID = 0 OR r.BetID = bm.betcheck)
					)sr
		CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, bm.betteam, bm.hdp1, bm.hdp2, sr.HomeValue, sr.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, bm.betcheck) m				
		WHERE bm.matchid = @matchid
			AND bm.statusID NOT IN(1, 101)
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
	END
	IF @Action = 'REFUND'
	BEGIN
		INSERT INTO #tmpsubTransID (refno, transid, statuswinlost, statusID)
		SELECT bm.refno, bm.transid, 0, 103
		FROM dbo.bettransm bm WITH(ROWLOCK)
		WHERE bm.matchid = @matchid
			AND bm.statusID <> 101
	END

	INSERT INTO @tmpRefnos (refno)
	SELECT	t.refno
	FROM	#tmpsubTransID t
	WHERE	NOT EXISTS ( SELECT TOP 1 1 
						 FROM dbo.bettransm bm WITH(NOLOCK) 
						 WHERE bm.refno = t.refno 
							 AND bm.statusID IN (1,101)
						)
	
	INSERT INTO #tblMatchParlayProcess (matchid, RefNo) 
	SELECT	@MatchID, refno
	FROM	@tmpRefnos
		
	EXEC dbo.NAP_Admin_CheckingProcess
		@IsLockingByRefnoVS		= 1
		,@SPName				= @SPName
		, @avaiableProcess 		= @avaiableProcess OUTPUT
		, @ErrCode				= @ErrCode OUTPUT
		, @ErrMsg				= @ErrMsg OUTPUT
	
	IF @ErrCode <> 0
	RETURN

	---settle subparlay
	BEGIN TRY
		WHILE ( 1=1)
		BEGIN
			DELETE @subtable
			
			DELETE TOP(@batchNo) #tmpsubTransID
			OUTPUT deleted.transid, deleted.statuswinlost, deleted.statusID
			INTO @subtable(transid, statuswinlost, statusID)	
			
			IF @@ROWCOUNT = 0 
			BREAK

			SET @strSubParlay = CAST((SELECT transid '@t'
										,@matchdate '@d'
										,statuswinlost '@w'
										,statusID '@s'				
									 FROM @subtable
									 FOR XML PATH('r'), ROOT('root'), TYPE
									) AS VARCHAR(MAX) )

			EXEC dbo.Bet_ExecRep_05 
						@IgnoreList 	= @IgnoreList
						, @updatetype 	= 5
						, @_sXML 		= @strSubParlay
						, @Action		= @Action
						, @MatchId		= @MatchId
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			 ,@ErrMsg 	= ERROR_MESSAGE()

		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefnoVS = 1
			,@IsReleased		= 1

		RETURN
	END CATCH

	--settle main parlay
	INSERT INTO #tempMainParlay 
	(	refno, recommend, matchid, custid, bettype,transid, actual_stake, stake, odds, comstatus
		,apositiontaking, mpositiontaking, spositiontaking 
		,playerdiscount,discount, adiscount, sdiscount
		,WinLost, aWinLost, mWinLost, sWinLost
		,PlayerComm, comm, acomm, scomm
		,StatusID, modds, winlostdate,currency,transdate
	)
	OUTPUT INSERTED.recommend , INSERTED.matchid, INSERTED.custid, INSERTED.bettype, INSERTED.transid , INSERTED.actual_stake	
		, INSERTED.WinLost, INSERTED.aWinLost , INSERTED.mWinLost , INSERTED.sWinLost 		
		, INSERTED.PlayerComm, INSERTED.comm , INSERTED.acomm , INSERTED.scomm 			
		, INSERTED.StatusID	, INSERTED.modds , INSERTED.winlostdate, INSERTED.currency, INSERTED.transdate
	INTO  #tempMainParlay_Pre 
	(	recommend , matchid, custid, bettype, transid , actual_stake	
		, WinLost, aWinLost, mWinLost, sWinLost 		
		, PlayerComm , comm, acomm, scomm 			
		, StatusID, modds, winlostdate, currency, transdate
	)
	SELECT refno
		, recommend
		, matchid
		, custid
		, bettype
		, transid, actual_stake, stake, odds, comstatus
		, apositiontaking, mpositiontaking, spositiontaking
		, playerdiscount,discount, adiscount, sdiscount
		, WinLost, aWinLost, mWinLost, sWinLost
		, PlayerComm, comm, acomm, scomm
		, StatusID, modds, winlostdate
		, currency, transdate
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.matchid = 10449
		AND b.statusID NOT IN (101,102) --('VOID','REJECT')	
		AND EXISTS (SELECT 1 FROM @tmpRefnos WHERE refno = b.refno)

	IF @@ROWCOUNT = 0
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefnoVS = 1
			,@IsReleased		= 1 
		
		RETURN
	END
		
	;WITH cte_cntStatus (refno, NoRefund, loseCnt, runningCnt, matchdate_max, modds) AS 
	(	SELECT parlay.refno as refno
				,SUM(CASE WHEN parlay.statusID IN (121, 103) THEN 0 ELSE 1 END) as NoRefund
				,SUM(CASE WHEN parlay.statuswinlost = 4 THEN 1 ELSE 0 END) as loseCnt
				,SUM(CASE WHEN parlay.statusID IN (0, 1) THEN 1 ELSE 0 END) as runningCnt
				,MAX(parlay.winlostdate) as matchdate_max
				,CAST(dbo.PRODUCT( CASE parlay.statuswinlost
										WHEN 0 THEN 1 -- draw 
										WHEN 1 THEN 1+((parlay.odds-1)/2) -- half won
										WHEN 2 THEN parlay.odds -- won
										WHEN 3 THEN 0.5 -- half lose
										WHEN 4 THEN 0.000000000001 -- lose
										ELSE 1 -- void/reject
									END
								) AS MONEY) AS modds
		FROM #tempMainParlay t
			CROSS APPLY(	SELECT bm.transid, bm.odds, bm.refno, bm.statuswinlost, bm.statusID, bm.winlostdate
							FROM dbo.bettransm bm WITH(rowlock)	
								INNER JOIN dbo.match m WITH (NOLOCK)
									ON bm.matchid = m.matchid
							WHERE bm.refno = t.refno									
							UNION
							SELECT bm14.transid, bm14.odds, bm14.refno, bm14.statuswinlost, bm14.statusID, bm14.winlostdate
							FROM dbo.bettransm14 bm14 WITH(rowlock)			
								INNER JOIN dbo.match14 m14 WITH(NOLOCK)
									ON bm14.matchid = m14.matchid
							WHERE bm14.refno = t.refno
					) AS parlay 
		GROUP BY parlay.refno
	)
	, cte_Result (refno, winlostdate, StatusId, modds, rate) AS
	(	SELECT refno
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
	FROM cte_cntStatus AS p
	)
	--Pre-calculate parlay main ticket
	UPDATE b
	SET statusID 		= r.statusID
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
	FROM #tempMainParlay b
		INNER JOIN cte_Result r 
			ON b.refno = r.refno
	
	UPDATE b
	SET isChanged =  1
	FROM #tempMainParlay b
	INNER JOIN #tempMainParlay_Pre t
		ON b.transid = t.transid	
	WHERE b.statusID	<> t.statusId 
		OR b.winlost	<> t.winlost
		OR b.awinlost	<> t.awinlost
		OR b.mwinlost	<> t.mwinlost
		OR b.swinlost 	<> t.swinlost 
		OR b.playercomm	<> t.playercomm
		OR b.comm		<> t.comm
		OR b.acomm 		<> t.acomm 
		OR b.scomm 		<> t.scomm 
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
	BEGIN
		;WITH cteCustIds
		AS(
			SELECT DISTINCT custid, currency
			FROM	#tempMainParlay t
			WHERE	statusID IN (111,112)
				AND isChanged = 1
		)
		INSERT INTO @tmpMaxWinLimit (CustId, MaxWinLimit)
		SELECT	t.custid, fc.MaxWinLimit
		FROM	CustDB.dbo.Customer c WITH(NOLOCK)
			INNER JOIN cteCustIds t
				ON t.custid = c.custid
			INNER JOIN CustDB.dbo.Site s WITH(NOLOCK)
				ON s.site = c.site
			INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs
				ON s.siteid = fs.siteid
			INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc
				ON	t.currency = fc.ExchangeId
					AND fc.SiteDBGroupId = @SiteDBGroupId	
					
		IF @@ROWCOUNT > 0
		BEGIN					
			UPDATE t 
			SET @actualPO	= t.winlost,
				t.winlost	= m.MaxWinLimit,
				t.aWinLost = CASE WHEN t.modds >= 0.25 THEN (m.MaxWinLimit - t.actual_stake) * - apositiontaking
								  ELSE 0
							 END,
				t.mWinLost = CASE WHEN t.modds >= 0.25 THEN (m.MaxWinLimit - t.actual_stake) * - mpositiontaking
								  ELSE 0
							 END,
				t.sWinLost = CASE WHEN t.modds >= 0.25 THEN (m.MaxWinLimit - t.actual_stake) * - spositiontaking
								  ELSE 0
							 END,
				actualPO = @actualPO
			OUTPUT  deleted.transid , deleted.custid, inserted.actualPO, inserted.winlost, deleted.transdate, deleted.bettype
			INTO @tmpTransMPO (TransID, custid, actualPO, winlost, transdate, bettype)
			FROM  #tempMainParlay AS t
				INNER JOIN @tmpMaxWinLimit AS m ON m.custid = t.custid AND t.winlost > m.MaxWinLimit
			WHERE t.statusID IN (111,112)
				AND isChanged = 1

			SET @TotalTransMaxPO = @@ROWCOUNT
		END
	END

	BEGIN TRY
		WHILE (1 = 1)
		BEGIN
			DELETE @MainTickets

			DELETE TOP (@batchNo) #tempMainParlay
			OUTPUT deleted.recommend, deleted.matchid, deleted.custid, deleted.bettype, deleted.transid
				, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost
				, deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm
				, deleted.statusid, deleted.modds, deleted.actual_stake, deleted.winlostdate
				, deleted.actualPO
			INTO @MainTickets(recommend, matchid, custid, bettype, transid
				,winlost, awinlost, mwinlost, swinlost
				,playercomm, comm, acomm, scomm
				,statusid, modds, actual_stake, winlostdate
				,actualPO
			)	
			WHERE isChanged = 1

			IF @@ROWCOUNT = 0 BREAK

			SELECT @BetTicketJson = CONVERT(VARCHAR(MAX)
									,(SELECT b.matchid 							AS 'mi'
											,b.transid 							AS 'ti'
											,b.winlost 							AS 'wl'
											,b.awinlost 						AS 'awl'
											,b.mwinlost 						AS 'mwl'				
											,b.swinlost 						AS 'swl'
											,b.playercomm 						AS 'pcomm'
											,b.comm 							AS 'comm'
											,b.acomm 							AS 'acomm'
											,b.scomm 							AS 'scomm'	
											,b.statusid 						AS 'st'	
											,b.modds 							AS 'mo'
											,b.winlostdate						AS 'wd'		
											,b.actualPO							AS 'apo'	
										FROM @MainTickets AS b
										FOR JSON AUTO
									) 
								)
			EXEC dbo.Bet_ExecRep_NAP_Admin_02  
					@BetTicketJson		= @BetTicketJson
					,@Action			= @Action
					,@ActionID			= @ActionID
					,@CWLBettype		= @CWLBettype
					,@IsCalBalance		= 1
					,@matchid			= @MatchId
					,@ErrCode			= @ErrCode	OUTPUT
					,@ErrMsg			= @ErrMsg	OUTPUT
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefnoVS = 1
			,@IsReleased		= 1  

	WHILE (@TotalTransMaxPO > 0)
	BEGIN
		IF @TotalTransMaxPO > @batchPO
		BEGIN
			DELETE @tmpTransMPOBatch

			DELETE TOP (@batchPO) t
			OUTPUT deleted.custid, deleted.winlost, deleted.actualPO, deleted.transdate, deleted.bettype, deleted.transid 
			INTO @tmpTransMPOBatch(custid, winlost, actualPO, transdate, bettype, transid)
			FROM @tmpTransMPO t
			WHERE ISNULL(t.actualPO,0) > 0

			SET @TransInfoMaxPO = CAST((
									SELECT	TOP (@batchPO) CustId AS a1
											,@sporttype AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,NULL AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	@tmpTransMPOBatch
									FOR XML PATH('r'), ROOT('root')
							) AS VARCHAR(MAX))
		END
		ELSE
		BEGIN
			SET @TransInfoMaxPO = CAST((
									SELECT	CustId AS a1
											,@sporttype AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,NULL AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	@tmpTransMPO
									FOR XML PATH('r'), ROOT('root')
							) AS VARCHAR(MAX))
		END

		SET @TotalTransMaxPO = @TotalTransMaxPO - @batchPO
		BEGIN TRY
			EXEC DBCUST.CustDB.dbo.Task_Winlimit_InsertHistoryData
				@XmlData = @TransInfoMaxPO
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = ERROR_MESSAGE()				
		END CATCH
	END
END
GO
