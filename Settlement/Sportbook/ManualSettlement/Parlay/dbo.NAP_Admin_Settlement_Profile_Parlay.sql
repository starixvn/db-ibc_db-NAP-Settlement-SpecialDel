/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile_Parlay]
	 @creator				INT
	,@MatchID				INT
	,@Action		  		VARCHAR(10)		= 'CAL'
	,@IP	 				VARCHAR(15)		= ''
	,@SelectedResources		VARCHAR(MAX)
	,@IsReSettledTickets	BIT			= 1
	,@BypassCheckingProcess BIT = 0

	,@ErrCode				INT				= 0	OUTPUT
	,@ErrMsg 				NVARCHAR(200)	= '' OUTPUT
AS
/*  Creator: 20210514@Kathy
	Task: Settlement Parlay for sport in profile
	DB: DBTXN/BODB02

	Revisions:
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]

	Param's Explanation:
		* @SelectedResources= '<Resources>
									<Resource Id="M1" Home="1" Away="3" />
									<Resource Id="M2" Home="2" Away="4" />
							   </Resources>'
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @start				DATETIME
			,@stop				DATETIME
			,@ActionID			INT
			,@ThreadHold		INT -- over threadhold, the parlay process will be locked in systemsetting

			,@avaiableProcess	BIT		
			,@Session			NVARCHAR(50)
			,@SPName			SYSNAME
			,@IsExistParlay		BIT = 0
						
			,@ParentMatchId		INT
			,@eventdate			DATETIME
			,@sqlCommand		VARCHAR(MAX) = ''
			,@sportType 		INT
			,@handle			INT
			,@batchNo			INT 			= 2000	
			,@totalSubParlay	INT = 0
			,@strTransIds		VARCHAR(MAX)	= ''	
			,@strMainTransIds		VARCHAR(MAX)	= ''
			,@strMainTransIdRefnos	VARCHAR(MAX) = ''			
			,@totalMainParlay		INT

	DECLARE @tmpMainTransIdBatch TABLE (TransId BIGINT, Refno BIGINT)
	DECLARE @tmpSubTransIdBatch TABLE (TransId BIGINT, Refno BIGINT, modds MONEY, IsMarked BIT DEFAULT(0))
	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),
								  BetType SMALLINT, BetID BIGINT, pfID SMALLINT, OddsType SMALLINT, RoundName VARCHAR(20), OrdNo SMALLINT)
	DECLARE @tmpRefnos TABLE (refno BIGINT)

	DECLARE @tmpParlayDebitPending		TVP_BalanceList
			,@tmpParlayCreditPending	TVP_BalanceList

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpParlayBalanceBefore (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #tmpParlayBalanceAfter (transid BIGINT PRIMARY KEY, custid INT, balance money)
	CREATE TABLE #tmpParlayBalance (custid int, balance money)
	--END Balance tables

	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	CREATE TABLE #tmpsubTransID (TransID BIGINT, refno BIGINT, modds SMALLMONEY, isFinish BIT, IsMarked BIT)
	----------------------------------------------------------------------------------------------------------------------

  	SELECT  @start = CURRENT_TIMESTAMP
			,@ActionID = CASE 
							WHEN @Action LIKE 'CAL%' THEN 81028 -- new action Id
							WHEN @Action LIKE 'REFUND%' THEN 81029
							WHEN @Action LIKE 'UNDO%' THEN 81030
			,@SPName = OBJECT_NAME(@@PROCID)
			,@session = CONVERT(NVARCHAR(50),NEWID())

  	--get info of match
  	SELECT	@sportType	= sportType
			,@eventdate	= eventdate
			,@ParentMatchId = CASE WHEN ChildMatchType = 200 AND ParentID IS NOT NULL AND sporttype = 50 THEN ParentID ELSE NULL END
  	FROM	dbo.match WITH (NOLOCK)
  	WHERE   matchid = @matchid
  	
	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	
	;WITH cteSelectedRID
	AS (
		SELECT	Id
				,RefResourceId AS RefResourceId
				,ISNULL(Bettype,'') AS Bettype
				,ISNULL(pfId,'') AS pfId
				,ISNULL(Home,'') AS HomeValue
				,ISNULL(Away,'') AS AwayValue
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,RefResourceId VARCHAR(20)
															,Bettype SMALLINT
															,pfId INT															
															,Home VARCHAR(50)
															,Away VARCHAR(50)
															
											) AS tbl
	)
	INSERT INTO @tmpSelectedRID (ResourceID, Bettype, BetId, pfId, OddsType, HomeValue, AwayValue, OrdNo, RoundName)
	SELECT	 c.Id
			,sp.Bettype
			,sp.BetId
			,sp.pfId
			,sp.OddsType
			,c.HomeValue
			,c.AwayValue
			,sp.OrdNo
			,sd.RoundName
	FROM	cteSelectedRID c
		INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
			ON	 sp.ResourceID = c.Id
					AND sp.BetType = c.Bettype
		LEFT JOIN dbo.f_Set_MajorRound(@Sporttype) sd 
			ON	ISNULL(sp.RefResourceId,sp.ResourceID) = sd.ResourceID
	WHERE	sp.SportType = @Sporttype
			
	EXEC sp_xml_removedocument @handle
	
  	--get transid
  	IF @Action LIKE 'CAL%'
  	BEGIN
		INSERT INTO #tmpsubTransID (TransID, modds, refno, IsMarked)
		SELECT	bm.transid, m.modds, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
		FROM	dbo.bettransm bm WITH(NOLOCK)
			CROSS APPLY (
				SELECT	TOP 1 pfID, HomeValue, AwayValue
				FROM	@tmpSelectedRID t
				WHERE	t.BetType = bm.bettype
						AND (t.BetID = 0 OR t.BetID = bm.betcheck)
			)sr
			CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, bm.betteam, bm.hdp1, bm.hdp2, sr.HomeValue, sr.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc, NULL) m
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON	b.matchid = 29
					AND b.bettype = 29
					AND b.refno = bm.refno
			OUTER APPLY (
					SELECT TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transId
							AND mt.MatchId = @MatchID
			) mt
		WHERE	bm.matchid = @MatchID
				AND bm.statusID NOT IN (101)
				AND 1 = CASE 
							WHEN @IsReSettledTickets = 0 AND bm.statusID IN (0,102) THEN 1
							WHEN @IsReSettledTickets = 1 THEN 1
							ELSE 0
						END

		SET @totalSubParlay = @@ROWCOUNT
	END
	ELSE IF @action LIKE 'UNDO%'
	BEGIN
		INSERT INTO #tmpsubTransID (TransID, refno, IsMarked)
		SELECT	bm.transid, bm.refno, CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked 
		FROM	dbo.bettransm bm WITH(NOLOCK)
			CROSS APPLY (
				SELECT	TOP 1 pfID, HomeValue, AwayValue
				FROM	@tmpSelectedRID t
				WHERE	t.BetType = bm.bettype
						AND (t.BetID = 0 OR t.BetID = bm.betcheck)
			)sr
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) 
				ON	b.matchid = 29
					AND b.bettype = 29
					AND b.refno = bm.refno
			OUTER APPLY (
				SELECT	TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transid
						AND mt.MatchId = @MatchID
			) mt
		WHERE	bm.matchid = @MatchID
				AND bm.statusID NOT IN (101)
				AND 1 = CASE WHEN bm.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
							 WHEN bm.statusID NOT IN (0, 1) THEN 1
							 ELSE 0 
						END

		SET @totalSubParlay = @@ROWCOUNT
	END 
	ELSE IF @action LIKE 'REFUND%'
	BEGIN
		INSERT INTO #tmpsubTransID (TransID, refno, modds)
		SELECT	bm.transid, bm.refno, 0
		FROM	dbo.bettransm bm WITH(NOLOCK)
			CROSS APPLY (
				SELECT	TOP 1 pfID, HomeValue, AwayValue
				FROM	@tmpSelectedRID t
				WHERE	t.BetType = bm.bettype
						AND (t.BetID = 0 OR t.BetID = bm.betcheck)
			)sr
		WHERE	bm.matchid = @MatchID
				AND bm.statusID NOT IN (101,103)
		
		SET @totalSubParlay = @@ROWCOUNT
	END 

	IF @totalSubParlay = 0
		RETURN 

	IF @BypassCheckingProcess = 0
	BEGIN
		EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT
		
		--check settlement process
		IF @totalSubParlay <= @ThreadHold
		BEGIN
			INSERT INTO #tblMatchParlayProcess (matchid, RefNo) 
			SELECT	@MatchID, refno
			FROM	#tmpsubTransID
		
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno		= 1
				,@SPName				= @SPName
				,@Session				= @Session
				, @avaiableProcess 		= @avaiableProcess OUTPUT
				, @ErrCode				= @ErrCode OUTPUT
				, @ErrMsg				= @ErrMsg OUTPUT
		END
		ELSE
		BEGIN
			SET @IsExistParlay = 1
		END

		--check error
		IF(@ErrCode <> 0 OR @avaiableProcess = 0) OR @IsExistParlay = 1 -- put to parlay queue and lock systemsettings
		BEGIN
			IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT[1-9]'
			BEGIN
				RETURN
			END

			SELECT	@ErrCode = 0
					,@ErrMsg = ''
					,@sqlCommand =  'EXEC [dbo].[NAP_Admin_Settlement_Profile_Parlay] @Matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
															+ ', @creator = ' + CONVERT(NVARCHAR(50), @creator) 												
															+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResources) + ''''														
															+ ', @Action = ''' + CONVERT(NVARCHAR(50), @Action) + '''' 														
															+ ', @IP = ''' + CONVERT(VARCHAR(15), @IP) + ''''
															+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) 	
															+ ', @BypassCheckingProcess = 1 ' 	
															+ ', @ErrCode = @ErrCode OUTPUT' 
															+ ', @ErrMsg = @ErrMsg OUTPUT'

			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype)
			SELECT @MatchID, 0, @creator, @IP, CURRENT_TIMESTAMP, @action, @sqlCommand, @sportType

			RETURN
		END
	END
		
	BEGIN TRY
		-- settle sub parlay
		WHILE(1=1)
		BEGIN
			DELETE @tmpSubTransIdBatch

			UPDATE TOP(@batchNo) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds, deleted.refno, deleted.IsMarked
			INTO @tmpSubTransIdBatch(transid, modds, refno, IsMarked)
			FROM #tmpsubTransID t 
			WHERE isFinish IS NULL

			IF @@ROWCOUNT = 0
				BREAK
			
			--filter selectedRID by current Profile and BetType
			SET @strTransIds 		= (SELECT transid	AS '@t'
												,modds	AS '@m'
												,refno   AS '@r'
												,IsMarked AS '@im'
										FROM @tmpSubTransIdBatch
										FOR XML PATH('b'))

			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchid	  		 = @matchid
				,@matchdate			 = @eventdate
				,@mode				 = 'profile'
				,@Action				 = @Action
				,@strTransIds		 = @strTransIds

		END
		
		-- settle main parlay			
		INSERT INTO @tmpRefnos (refno)
		SELECT	t.refno
		FROM	#tmpsubTransID t
		WHERE	NOT EXISTS (SELECT TOP 1 1 
							FROM	dbo.bettransm bm WITH(NOLOCK) 
							WHERE	bm.refno = t.refno 
									AND bm.statusID IN (1,101)
						)
	
		SELECT	transid, refno, 0 AS IsFinished
			INTO #tmpMainTransId
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = 29
				AND b.statusID NOT IN (101,102) --('VOID','REJECT')
				AND refno IN (SELECT refno FROM @tmpRefnos)
			
		SET @totalMainParlay = @@ROWCOUNT -- number of system parlay ticket

		IF @totalMainParlay > 0 -- got system parlay tickets
		BEGIN
			SET @strMainTransIds = STUFF((
				SELECT ',' + cast(transid as varchar(20))
				FROM	#tmpMainTransId
				FOR XML PATH('')
			), 1,1,'')

			INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
			VALUES (@matchid, @totalMainParlay, CURRENT_TIMESTAMP, NULL, 'Start running PRECAL-29')
			

			-- handle betParlayDetail, betParlayResult
			EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchid
				,@mode = 'PRECAL-29'
				,@matchdate = @eventdate
				,@strXML = @strMainTransIds

			INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
			VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'Start running CAL-29')

			-- update summary info back to bettrans
			WHILE (1=1)
			BEGIN
				DELETE @tmpMainTransIdBatch
				TRUNCATE TABLE #tmpParlayBalanceBefore
				TRUNCATE TABLE #tmpParlayBalanceAfter

				SET @strMainTransIdRefnos = ''

				UPDATE TOP (800) #tmpMainTransId
					SET IsFinished = 1
				OUTPUT INSERTED.refno, INSERTED.transid INTO @tmpMainTransIdBatch (refno, transid)
				WHERE IsFinished = 0

				IF @@rowcount = 0
					BREAK

				SELECT @strMainTransIdRefnos = @strMainTransIdRefnos + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
				FROM	@tmpMainTransIdBatch

				SET @strMainTransIdRefnos = STUFF(@strMainTransIdRefnos,1,1,'')

				---- CAPTURE value BALANCE before udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
				INSERT INTO #tmpParlayBalanceBefore (transid, custid, balance)
				SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	dbo.bettrans b WITH(ROWLOCK)
				WHERE	b.transid IN (SELECT transid FROM @tmpMainTransIdBatch)

				EXEC dbo.NAP_Admin_Calculate_MP_broker
					@mode = '29'
					,@matchdate = @eventdate
					,@strXML = @strMainTransIdRefnos

				---- CAPTURE value BALANCE after udpate bettrans [Redmine:#108768]: to avoid parlay settlement & movebet delete bet ticket run the same time
				INSERT INTO #tmpParlayBalanceAfter (transid, custid, balance)
				SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
				FROM	dbo.bettrans b WITH(ROWLOCK)
				WHERE	b.transid IN (SELECT transid FROM @tmpMainTransIdBatch)

				INSERT INTO #tmpParlayBalance (custid, balance)
				SELECT b.custid, SUM(a.balance - b.balance)
				FROM #tmpParlayBalanceBefore b
					INNER JOIN #tmpParlayBalanceAfter a ON b.transid = a.transid
				GROUP BY b.custid
			END
		END
	END TRY
	BEGIN CATCH
		INSERT INTO #tmpParlayBalanceAfter (transid, custid, balance)
		SELECT	b.transid, b.custid, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM	dbo.bettrans b WITH(ROWLOCK)
		WHERE	b.transid IN (SELECT transid FROM @tmpMainTransIdBatch)

		INSERT INTO #tmpParlayBalance (custid, balance)
		SELECT b.custid, SUM(a.balance - b.balance)
		FROM #tmpParlayBalanceBefore b
			INNER JOIN #tmpParlayBalanceAfter a ON b.transid = a.transid
		GROUP BY b.custid

			SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE() 

	END CATCH

	INSERT INTO @tmpParlayDebitPending (custID, balance)
	SELECT t.custid, ABS(t.balance)
	FROM (
		SELECT	custID, SUM(balance) AS balance
		FROM	#tmpParlayBalance
		GROUP BY custID
	) t
	WHERE t.balance < 0

	IF @@ROWCOUNT <> 0
		EXEC dbo.Dot_BalancePendingDebitIns
			@BalancePending = @tmpParlayDebitPending
			,@Type			= 1 -- Sports

	INSERT INTO @tmpParlayCreditPending (custID, balance)
	SELECT t.custid, ABS(t.balance)
	FROM (
		SELECT	custID, SUM(balance) AS balance
		FROM	#tmpParlayBalance
		GROUP BY custID
	) t
	WHERE t.balance > 0

	IF @@ROWCOUNT <> 0
		EXEC dbo.Dot_BalancePendingCreditIns
			@BalancePending = @tmpParlayCreditPending
			,@Type			= 1 -- Sports
			
	----
	-- Add Negative Balance into BalanceNegative table
	----
	INSERT INTO [bodb02].[dbo].[BalanceNegative] ([ExecDate], [MatchID], [ActionID], [GroupID], [CustID], [Balance], [StatusID], [Remark])
	SELECT GETDATE()
		,@MatchID
		,CASE 
			WHEN @Action LIKE 'UNDO%' THEN 105
			WHEN @Action LIKE 'REFUND%' THEN 107
			ELSE 104 -- CAL
		END
		,2 -- Sportsbook Parlay Settlement
		,t.CustID
		,t.Balance
		,0
		,@matchid
	FROM (	SELECT	custID, SUM(balance) AS balance
			FROM	#tmpParlayBalance
			GROUP BY custID) t
	WHERE t.balance < 0

	INSERT INTO dbo.ParlaySettlement_trace (matchid, runcnt, starttime, endtime, doing)
	VALUES (@matchid, NULL, CURRENT_TIMESTAMP, NULL, 'END running CAL-29')

	----------------------------------- releasing Settlement process--------------------------------------------
	IF @BypassCheckingProcess = 0
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			@IsLockingByRefno = 1
			,@Session	= @Session
			,@IsReleased = 1
	END

	IF @ErrCode > 0
		RETURN

	-- Write log
	BEGIN 
		DECLARE @ResultRemarkLog VARCHAR(MAX) = ''
				,@logdata		VARCHAR(MAX) = ''
				,@Remark		VARCHAR(MAX) = ''
				,@matchLog		INT = @matchid

		IF @ParentMatchId IS NOT NULL 
		BEGIN
			DELETE FROM @tmpSelectedRID
			WHERE ResourceID NOT IN (
				SELECT sp.ResourceID 
				FROM dbo.bettrans bt WITH(NOLOCK)
					INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
						ON (sp.BetID = 0 OR sp.BetID =bt.betid)
							AND sp.BetType = bt.bettype
				WHERE bt.matchid = @MatchID
					AND sp.SportType =50 )

			SET @matchLog = @ParentMatchId
		END

		SELECT @ResultRemarkLog = @ResultRemarkLog + ',' +  ISNULL(RoundName,ResourceID) + 
				CASE WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND AwayValue IS NOT NULL AND AwayValue <> '' THEN '(' + HomeValue + '-' + AwayValue + ')'
					 WHEN HomeValue IS NOT NULL AND HomeValue <> '' AND (AwayValue IS NULL OR AwayValue = '') THEN '(' + HomeValue + ')'
					 WHEN HomeValue IS NULL AND AwayValue IS NULL THEN ''
					 ELSE '' END
		FROM (
				SELECT DISTINCT ResourceID, HomeValue, AwayValue, RoundName, MAX(OrdNo) AS OrdNo
		  		FROM @tmpSelectedRID sr
		  		GROUP BY ResourceID, HomeValue, AwayValue, RoundName
  			) AS tbl1
		ORDER BY OrdNo

		IF @ParentMatchId IS NOT NULL -- Child match Cricket
			SELECT @ResultRemarkLog =  'child: ' + CAST(@matchid AS VARCHAR)  
										+ CASE WHEN @Action LIKE 'CAL%' THEN ' Result:' 
											ELSE ' Selected:' 
										END 
										+ SUBSTRING(@ResultRemarkLog, 2, LEN(@ResultRemarkLog))
		ELSE
			SELECT @ResultRemarkLog =  CASE WHEN @Action LIKE 'CAL%' THEN 'Result:' ELSE 'Selected:' END + SUBSTRING(@ResultRemarkLog, 2, LEN(@ResultRemarkLog))
	
		SET @stop = CURRENT_TIMESTAMP

		SELECT @logdata = 'NAP: Calculate Parlay (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10))
								+ ' Result: ' + @SelectedResources + '<br/> '
								+ '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
						   
		EXEC dbo.WriteLog_UserLog @creator, @logdata

		SELECT @Remark = @ResultRemarkLog + '<br/> ' 
							+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
							+ CASE WHEN @Action LIKE 'CAL%' THEN '; Recalc: ' + CAST (ISNULL(@IsReSettledTickets,0) AS VARCHAR(1)) ELSE '' END
							+ '; TC:' + CAST(ISNULL(@totalSubParlay, 0) AS VARCHAR(20)) 
						
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				,@Matchid = @matchLog
				,@ActionID = @ActionID				
				,@Remark = @Remark
				,@IP = @IP
		END TRY

		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + left(error_message(), 250)

			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				,@Matchid = @matchLog
				,@ActionID = @ActionID				
				,@Remark = @Remark
				,@IP = @IP
		END CATCH
	END --END: WRITE LOG ---------------------------------- 

	WAITFOR DELAY '00:00:01' -- for another parlay process request lock
END
GO