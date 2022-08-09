/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_221] @matchid INT
	, @result VARCHAR(MAX)
	, @action VARCHAR(20)
	, @IsReSettledTickets BIT = 1
AS
/*
    Created: 20160428@Patrick
    Task: Fast Market - Calculate
    DB: DBTXN/BODB02
    Original:

    Revisions:
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
		- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200928@Helen: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
		- 20201109@Kathy: Exclude reject ticket of bettype 228 [Redmine:#145036]
		- 20201106@Kathy: Add "Water Break" Concept to Fast Markets [Readmine:#143573]
		- 20210107@Kathy: Support settle determined [Readmine:#147141]
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		- 20210428@Kathy: Allow to settle directly for bettype 228 [Redmine:#153155]
		- 20211104@Kathy: Upd RepUpdateTime [Redmine:#164184]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		
    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@AllowUndo			BIT
			,@AllowRefund		BIT
		
	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT
			,@AllowUndo			= @AllowUndo		OUTPUT
			,@AllowRefund		= @AllowRefund		OUTPUT
		
		--IF @action = 'CAL' AND @AllowCalculation = 0
		--	RETURN

		IF @action = 'UNDO' AND @AllowUndo = 0
			RETURN
		/*
			IF @action = 'REFUND' AND @AllowRefund = 0
				RETURN
		*/
	END
	    
    DECLARE @modds			MONEY
			,@commWinRate	SMALLMONEY
			,@commLostRate	SMALLMONEY
			,@xmlData		XML
			,@statusId TINYINT
			,@winlost MONEY
			,@IsUpd_Void BIT = 0
			,@maxSelectedTotalGoalBeforeReCAL INT = 0
			,@maxSelectedTotalGoal INT = 0
			,@maxSelectedPosition TINYINT = 0
			,@totalChangedScore INT = 0
			,@ActionId TINYINT
			,@IsSubDB BIT = 0
			,@transinfo XML

	DECLARE @settlementTime DATETIME
			,@RepUpdateTime DATETIME2
			
	SET @xmlData = CONVERT(XML, @result)
	SET @ActionId = CASE 
						WHEN @action = 'UNDO' THEN 0
						WHEN @action = 'CAL' THEN 1
						WHEN @action = 'REFUND' THEN 2
						ELSE 0
					END

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSubDB = 1
	
	CREATE TABLE #tblTransIds(transid BIGINT, BetOption INT, IsRefund BIT DEFAULT(0), ScoreDiff SMALLMONEY DEFAULT (0), ActionId TINYINT)	 --ActionId: 0 - Undo, 1 - CAL, 2 - Refund

	DECLARE @TmpData AS TABLE (
		bettype					SMALLINT
		,Position				TINYINT
		,BetOption				TINYINT
		,OldAccumulatedScore	INT -- 228
		,AccumulatedScore		INT -- 228
		,AccumulatedHomeScore	INT -- 229
		,AccumulatedAwayScore	INT -- 229
		,IsSettleDetermined		BIT
		,HasInjuryTime			BIT DEFAULT(0)
	)
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT
		,modds MONEY, statuswinlost VARCHAR(1),SettlementTime DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT, RepUpdateTime DATETIME2

		,bef_winlost MONEY
		,bef_statusid TINYINT
	)

	INSERT INTO @TmpData (bettype, Position, BetOption, OldAccumulatedScore, AccumulatedScore, AccumulatedHomeScore, AccumulatedAwayScore, IsSettleDetermined, HasInjuryTime)
	SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
		,X.C.value('@p','TINYINT') as Position
		,X.C.value('@r','TINYINT') as BetOption
		,X.C.value('@oa','INT') as OldAccumulatedScore
		,X.C.value('@a','INT') as AccumulatedScore
		,X.C.value('@ah','INT') as AccumulatedHomeScore
		,X.C.value('@aa','INT') as AccumulatedAwayScore
		,X.C.value('@s','BIT') as IsSettleDetermined
		,ISNULL(X.C.value('@i','BIT'), 0) AS HasInjuryTime
	FROM @xmlData.nodes('/r/b') AS T(C)
		CROSS APPLY
			C.nodes('r') AS X(C)
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )			

	IF EXISTS (SELECT TOP 1 1 FROM @TmpData WHERE bettype = 228)
	BEGIN
		SELECT TOP 1 @maxSelectedTotalGoal = AccumulatedScore
					,@maxSelectedPosition = Position
					,@maxSelectedTotalGoalBeforeReCAL = OldAccumulatedScore
		FROM  @TmpData 
		WHERE bettype = 228
		ORDER BY Position DESC

		SELECT	@totalChangedScore = SUM(BetOption)
		FROM	@TmpData
		WHERE	bettype = 228
	END

	INSERT INTO #tblTransIds (transid, BetOption, ScoreDiff, ActionId)
	SELECT	b.transid
			,CASE WHEN b.bettype = 228 THEN t.AccumulatedScore ELSE t.BetOption END AS BetOption			
			,CASE WHEN b.bettype = 229 THEN (t.AccumulatedHomeScore - t.AccumulatedAwayScore) ELSE 0 END AS ScoreDiff
			,CASE		
				WHEN @action = 'REFUND' 
					THEN CASE 
							WHEN t.IsSettleDetermined = 1 AND b.bettype BETWEEN 221 AND 227
								THEN CASE
										WHEN t.BetOption = 1 THEN @ActionId
										WHEN b.bettype BETWEEN 221 AND 222 AND (CAST(hdp2 AS INT) & t.betoption = 0) THEN @ActionId
										ELSE 1 -- CAL 
									END
							WHEN t.IsSettleDetermined = 1 AND b.oddsspread + 0.25 <= @maxSelectedTotalGoal THEN 1 -- CAL
							ELSE @ActionId
						END
				ELSE @ActionId
			END
	FROM	@TmpData t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON	b.matchid = @matchid
				AND b.bettype = t.Bettype
	WHERE	b.statusID NOT IN (101)
			AND b.SiteDBGroupID = CASE WHEN @IsSubDB = 1 THEN b.SiteDBGroupID ELSE 0 END
			AND 1 = CASE
						WHEN t.HasInjuryTime = 0
							THEN CASE 
									WHEN b.hdp1 = t.Position THEN 1
									ELSE 0
								END
						ELSE CASE
								WHEN t.Position < 45 AND b.hdp1 = t.Position THEN 1
								WHEN t.Position > 45 AND b.hdp1 = t.Position - 1 THEN 1
								ELSE 0
							END
					END
			AND 1 = CASE
						WHEN b.bettype <> 228 THEN 1
						WHEN @action = 'UNDO' AND (b.oddsspread + 0.25) < @maxSelectedTotalGoal - @totalChangedScore THEN 0
						ELSE 1
					END
			
		-- list tickets belong to selected interval
	IF @action IN ('CAL', 'UNDO') AND EXISTS (SELECT TOP 1 1 FROM @TmpData WHERE bettype = 228)  
	BEGIN
		;WITH ctePreviousSettledTransId
		AS(
			SELECT	b.transid
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsSubDB = 1 THEN b.SiteDBGroupID ELSE 0 END
					AND b.bettype = 228
					AND b.statusID NOT IN (101)
					AND @action = 'CAL'
					AND 1 = CASE
								WHEN @maxSelectedPosition < 45 AND b.hdp1 > @maxSelectedPosition THEN 1
								WHEN @maxSelectedPosition >= 45 AND b.hdp1 >= @maxSelectedPosition THEN 1
								ELSE 0
							END
					AND @maxSelectedTotalGoalBeforeReCAL > (b.oddsspread + 0.25)  
		)
		INSERT INTO #tblTransIds(transid, BetOption, ActionId)
		SELECT	ISNULL(b.transid, c.transid) AS transid
				,@maxSelectedTotalGoal
				,CASE
					WHEN b.transid IS NULL THEN 0 -- UNDO
					ELSE @ActionId
				END
		FROM ( 
			SELECT	b.transid
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = @matchid
					AND b.SiteDBGroupID = CASE WHEN @IsSubDB = 1 THEN b.SiteDBGroupID ELSE 0 END
					AND b.bettype = 228
					AND b.statusID NOT IN (101)
					AND 1 = CASE
								WHEN @maxSelectedPosition < 45 AND b.hdp1 > @maxSelectedPosition THEN 1
								WHEN @maxSelectedPosition >= 45 AND b.hdp1 >= @maxSelectedPosition THEN 1
								ELSE 0
							END
					AND 1 = CASE 
								WHEN @action = 'CAL' AND @maxSelectedTotalGoal > (b.oddsspread + 0.25)  THEN 1
								WHEN @action = 'UNDO' AND (b.oddsspread + 0.25) <= @maxSelectedTotalGoal AND (b.oddsspread + 0.25) >= @maxSelectedTotalGoal - @totalChangedScore THEN 1
								ELSE 0
							END
		) b
			FULL JOIN ctePreviousSettledTransId c
				ON b.transid = c.transid
	END

	DELETE FROM #tblTransIds WHERE BetOption IS NULL -- got error

	WHILE (1=1)
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #tblTransIds WHERE ActionId = 1) AND @AllowCalculation = 1 -- CAL
		BEGIN
			SET @settlementTime = GETDATE();

			UPDATE b
				SET @modds = CASE 
								WHEN b.bettype = 228 
									THEN CASE 
											WHEN b.betteam = 'o' THEN t.BetOption - b.oddsspread 
											WHEN b.betteam = 'u' THEN b.oddsspread  - t.BetOption
											ELSE -1
										END
								WHEN b.bettype = 229
									THEN CASE
											WHEN b.betteam = 'h' THEN b.oddsspread + t.ScoreDiff - (b.livehomescore - b.liveawayscore)
											when b.betteam = 'a' THEN - b.oddsspread - t.ScoreDiff + (b.livehomescore - b.liveawayscore)
											ELSE -1
										END
								ELSE CASE
										WHEN b.betteam > 0 AND (CAST(hdp2 AS INT) & t.betoption) > 0 THEN 1
										WHEN b.betteam = 0 AND (CAST(hdp2 AS INT) & (t.betoption ^ 65535)) > 0 THEN 1
										ELSE -1
									END
							END
				, @IsUpd_Void = CASE WHEN (statusID = 102) OR (mt.TransId IS NOT NULL) THEN 0 ELSE 1 END
				, modds = @modds
				, statuswinlost = CASE WHEN @modds > 0.25 THEN 2
									WHEN @modds = 0.25 THEN 1 
									WHEN @modds = 0 THEN 0 
									WHEN @modds = - 0.25 THEN 3
									WHEN @modds < - 0.25 THEN 4
									WHEN @modds IS NULL THEN 6
								END
							
				, @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
									WHEN '0' THEN 1
									WHEN '1' THEN 0
								ELSE 1 END
				, @commLostRate = CASE comstatus
									WHEN '0' THEN 1
									WHEN '1' THEN 2
								ELSE 1 END
				-- check winlost or status change to update SettlementTime
				,@statusId = CASE
								WHEN @modds > 0 THEN 112 --WON
								WHEN @modds = 0 THEN 111 --DRAW
								WHEN @modds < 0 THEN 113 --LOSE
							END
				,@winlost = CASE 
								WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END)
								WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END) * 0.5
								WHEN @modds = 0 THEN actual_stake
								WHEN @modds = -0.25 THEN actual_stake * 0.5
								WHEN @modds < -0.25 THEN 0
							END
				,SettlementTime = CASE 
								WHEN @IsUpd_Void = 0 THEN SettlementTime 
								ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
							END
						
				, WinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN WinLost 
								ELSE @winlost
							END
				, aWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN aWinLost 
								ELSE CASE 
										WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END) * -apositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END) * -apositiontaking * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
										WHEN @modds < -0.25 THEN actual_stake * apositiontaking
									END
							END
						
				, mWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN mWinLost 
								ELSE CASE
										WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END) * -mpositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END) * -mpositiontaking * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
										WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
									END
							END
						
				, sWinLost = CASE 
								WHEN @IsUpd_Void = 0 THEN sWinLost 
								ELSE CASE
										WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END) * -spositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (228,229) THEN odds ELSE (odds - 1) END) END) * -spositiontaking * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = -0.25 THEN actual_stake * spositiontaking * 0.5
										WHEN @modds < -0.25 THEN actual_stake * spositiontaking
									 END
							END
						
				, PlayerComm = CASE 
								WHEN @IsUpd_Void = 0 THEN PlayerComm 
								ELSE CASE
										WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
										WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = -0.25 THEN @commLostRate * playerdiscount * stake * 0.5
										WHEN @modds < -0.25 THEN @commLostRate * playerdiscount * stake
									END
							END
						
				, Comm = CASE 
								WHEN @IsUpd_Void = 0 THEN Comm 
								ELSE CASE
										WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1-apositiontaking)
										WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
										WHEN @modds < -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking)
									END
							END
						
				, aComm = CASE 
								WHEN @IsUpd_Void = 0 THEN aComm 
								ELSE CASE
										WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
										WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
										WHEN @modds < -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
									END
							END
						
				, sComm = CASE 
								WHEN @IsUpd_Void = 0 THEN sComm 
								ELSE CASE
										WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
										WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
										WHEN @modds < -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
									END
							END
						

				, Status = CASE 
								WHEN @IsUpd_Void = 0 THEN b.[status] 
								ELSE CASE
										WHEN @modds > 0 THEN N'WON'
										WHEN @modds = 0 THEN 'DRAW'
										WHEN @modds < 0 THEN N'LOSE'
									END
							END
						
				, StatusID = CASE 
								WHEN @IsUpd_Void = 0 THEN StatusID 
								ELSE @statusId
							END
						
				, ruben = CASE 
								WHEN @IsUpd_Void = 0 THEN ruben 
								ELSE 1
							END
				OUTPUT	inserted.transid
					,inserted.modds
					, CASE WHEN inserted.StatusWinlost IS NULL THEN '' ELSE CAST(Inserted.Statuswinlost AS VARCHAR(1)  ) END AS statuswinlost
					,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
					,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
					,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
					,inserted.Status,inserted.StatusID,inserted.ruben
					
					,deleted.winlost
					,deleted.statusid
				INTO @tmpTransInfo (
					transId
					,modds
					,statuswinlost
					,SettlementTime,WinLost,aWinLost
					,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
					,bef_winlost, bef_statusid
				)
				FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
					INNER JOIN #tblTransIds t
						ON b.transid = t.transid
					OUTER APPLY (
						SELECT	mt.TransId
						FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
						WHERE	mt.TransId = b.transId
					)mt
				WHERE	1 = CASE 
								WHEN b.bettype = 228 THEN 1
								WHEN @action = 'REFUND' AND t.ActionId = 1 THEN 1
								WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								WHEN @IsReSettledTickets = 1 THEN 1
								ELSE 0
							END
						AND t.ActionId = 1
			
			IF @IsSubDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'	
							,modds AS '@m'
							,statuswinlost AS '@statuswl' 
							,SettlementTime AS '@st' 
							,WinLost AS '@w' 
							,aWinLost AS '@aw' 
							,mWinLost AS '@mw' 
							,sWinLost AS '@sw' 
							,PlayerComm AS '@pc' 
							,Comm AS '@c' 
							,aComm AS '@ac' 
							,sComm AS '@sc' 							
							,Status AS '@s' 
							,StatusID AS '@sid' 
							,ruben AS '@r' 
							,bef_winlost AS '@bef_w' 
							,bef_statusid AS '@bef_sid' 
				
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateFM', 'bettrans', @MatchId, @transInfo)		
			END
		END

		IF EXISTS (SELECT TOP 1 1 FROM #tblTransIds WHERE ActionId = 2) AND @AllowRefund = 1 -- REFUND
		BEGIN
			SET @settlementTime = GETDATE()
			SET @RepUpdateTime = SYSDATETIME()

			UPDATE	b
				SET 
					@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
					,status = CASE WHEN @IsUpd_Void = 0 THEN [status] ELSE N'Refund' END
					,SettlementTime = CASE 
										WHEN @IsUpd_Void = 0 THEN SettlementTime 
										ELSE CASE WHEN winlost <> actual_stake OR statusID <> 103 THEN @settlementTime ELSE SettlementTime END
									END
								
					, statusID = CASE 
									WHEN @IsUpd_Void = 0 THEN statusID 
									ELSE 103
								END
									
					, winlost = actual_stake
					, awinlost = 0
					, mwinlost = 0
					, swinlost = 0
					, playercomm = 0
					, comm = 0
					, acomm = 0
					, scomm = 0
					, ruben = 1
					, statuswinlost = 6	
					, RepUpdateTime = CASE WHEN b.statusId = 103 THEN b.RepUpdateTime ELSE @RepUpdateTime END
			OUTPUT	inserted.transid
				,inserted.Status				
				,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,inserted.StatusID
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.ruben
				,inserted.statuswinlost
				,CASE WHEN inserted.RepUpdateTime <> deleted.RepUpdateTime THEN inserted.RepUpdateTime ELSE NULL END
	
				,deleted.winlost
				,deleted.statusid	
			INTO @tmpTransInfo (
				transId
				,Status
				,SettlementTime
				,StatusID	
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,ruben
				,statuswinlost
				,RepUpdateTime
				,bef_winlost, bef_statusid
			)
			FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #tblTransIds t
					ON	b.transid = t.transid	
			WHERE	t.ActionId = 2

			IF @IsSubDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'	
							,Status AS '@s' 
							,SettlementTime AS '@st' 
							,StatusID AS '@sid' 
							,WinLost AS '@w' 
							,aWinLost AS '@aw' 
							,mWinLost AS '@mw' 
							,sWinLost AS '@sw' 
							,PlayerComm AS '@pc' 
							,Comm AS '@c' 
							,aComm AS '@ac' 
							,sComm AS '@sc' 
							,ruben AS '@r' 
							,statuswinlost AS '@statuswl' 
							,RepUpdateTime AS '@rut'
							,bef_winlost AS '@bef_w' 
							,bef_statusid AS '@bef_sid' 
					
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'RefundFM', 'bettrans', @MatchId, @transInfo)		
			END
		END

		IF EXISTS (SELECT TOP 1 1 FROM #tblTransIds WHERE ActionId = 0) AND @AllowUndo = 1 -- UNDO
		BEGIN
			SET @RepUpdateTime = SYSDATETIME()

			UPDATE	b
				SET 
					@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
					, STATUS = CASE WHEN @IsUpd_Void = 0 THEN [status] ELSE 'running' END
					, statusID = CASE WHEN @IsUpd_Void = 0 THEN statusID ELSE 0 END
					, winlost = CASE WHEN @IsUpd_Void = 0 THEN winlost ELSE 0 END 
					, awinlost = 0
					, mwinlost = 0
					, swinlost = 0
					, playercomm = 0
					, comm = 0
					, acomm = 0
					, scomm = 0
					, ruben = CASE WHEN @IsUpd_Void= 0 THEN ruben ELSE 0 END 
					, statuswinlost = NULL
					, RepUpdateTime = CASE WHEN b.statusId = 0 THEN b.RepUpdateTime ELSE @RepUpdateTime END
			OUTPUT	inserted.transid
				,inserted.Status	
				,inserted.StatusID
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.ruben
				, CASE WHEN inserted.StatusWinlost IS NULL THEN '' ELSE CAST(Inserted.Statuswinlost AS VARCHAR(1)  ) END AS statuswinlost
				,CASE WHEN inserted.RepUpdateTime <> deleted.RepUpdateTime THEN inserted.RepUpdateTime ELSE NULL END
	
				,deleted.winlost
				,deleted.statusid	
			INTO @tmpTransInfo (
				transId
				,Status
				,StatusID	
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,ruben
				,statuswinlost
				,RepUpdateTime
				,bef_winlost, bef_statusid
			)
			FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #tblTransIds t
					ON	b.transid = t.transid
			WHERE	t.ActionId = 0

			IF @IsSubDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'	
							,Status AS '@s' 
							,StatusID AS '@sid' 
							,WinLost AS '@w' 
							,aWinLost AS '@aw' 
							,mWinLost AS '@mw' 
							,sWinLost AS '@sw' 
							,PlayerComm AS '@pc' 
							,Comm AS '@c' 
							,aComm AS '@ac' 
							,sComm AS '@sc' 
							,ruben AS '@r' 
							,statuswinlost AS '@statuswl' 
							,RepUpdateTime AS '@rut'
							,bef_winlost AS '@bef_w' 
							,bef_statusid AS '@bef_sid' 
					
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'UndoFM', 'bettrans', @MatchId, @transInfo)		
			END
		END
		
		BREAK
	END
END

GO