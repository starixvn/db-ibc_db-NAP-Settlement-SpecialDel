/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_468] @matchid INT
	,@bettype						SMALLINT
	,@fth							INT = 0
	,@fta							INT = 0
	,@IsSettleAbandonedMatch		BIT = 0
	,@IsSettleAbandonedMatchIBC		BIT = 0
	,@IsSettleAbandonedMatchBetFair BIT = 0
	,@IsReSettledTickets			BIT	= 1
AS
/*
	Created by: Sol
	Date: 20190604
	Task: Settlement 
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20190603@Sol: Incorporate PHAIO 4 [Redmine:#112885]
		- 20191003@Sol: Support live score with bettype 468 [Redmine:#121337]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@transInfo	XML
			
	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN
	END

	DECLARE @modds				MONEY
		,@commWinRate			SMALLMONEY
		,@commLostRate			SMALLMONEY

		,@BatchCount			INT
		,@BatchNo				INT
		,@MinCustId				INT
		,@MaxCustId				INT
		,@MinTransId			BIGINT
		,@MaxTransId			BIGINT
		,@TransIdOfMinCust		BIGINT
		,@TransIdOfMaxCust		BIGINT
		,@statusId				TINYINT
		,@winlost				MONEY
		,@totalWinScore			VARCHAR(10)
		,@tmpTotalWinScore		VARCHAR(10)
		,@totalLiveWinScore		SMALLINT
		,@odds					MONEY
		,@posOdds				INT
		,@posComma				INT
		,@settlementTime		DATETIME
		,@IsUpd_Void BIT = 0
		
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, odds SMALLMONEY, oddsspread MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
		)
		
	DECLARE @tmpBatch AS TABLE (
		BatchNo					INT
		,CustId					INT
		,MinCustId				INT
		,MaxCustId				INT
		,MinTransId				BIGINT
		,MaxTransId				BIGINT
		,TransIdOfMinCust		BIGINT
		,TransIdOfMaxCust		BIGINT
		,UNIQUE CLUSTERED (BatchNo, CustId)
	)
		
	SET	@BatchCount = 2000

	SET @totalWinScore = CASE WHEN @bettype = 468 THEN @fth - @fta
								WHEN @bettype = 469 THEN @fth + @fta
							ELSE NULL
						END
				
	INSERT INTO @tmpBatch (BatchNo, CustId, MinCustId, MaxCustId, MinTransId, MaxTransId, TransIdOfMinCust, TransIdOfMaxCust)
	SELECT	BatchNo
			,custid
			,MAX(CASE WHEN MinRn = 0 THEN CustId ELSE 0 END) AS MinCustId
			,MAX(CASE WHEN MaxRn = 1 THEN CustId ELSE 0 END) AS MaxCustId
			,MAX(CASE WHEN TransIdAsc = 1 THEN transId ELSE 0 END ) AS MinTransId	
			,MAX(CASE WHEN TransIdDesc = 1 THEN transId ELSE 0 END ) AS MaxTransId			
			,MAX(CASE WHEN MinRn = 0 THEN transid ELSE 0 END) AS TransIdOfMinCust
			,MAX(CASE WHEN MaxRn = 1 THEN transid ELSE 0 END) AS TransIdOfMaxCust
	FROM (
		SELECT	n.BatchNo
				,b.custid
				,b.transid
				,(rn - 1)%@BatchCount AS MinRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY b.rn DESC) MaxRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid DESC) TransIdDesc
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid) TransIdAsc
		FROM	(
			SELECT	transid
					,custid
					,ROW_NUMBER() OVER (ORDER BY custid, transid) AS rn
			FROM	dbo.bettrans WITH(NOLOCK)
			WHERE	matchid = @matchid
					AND bettype = @bettype
					AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END
		)b
		CROSS APPLY (	
			SELECT	((b.rn - 1) /@BatchCount) + 1 AS BatchNo
		)n
	)b
	GROUP BY BatchNo, CustId
			
	SELECT @BatchNo = MAX(BatchNo)
	FROM @tmpBatch

	IF @IsSettleAbandonedMatchIBC = 1 OR @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1
	BEGIN
		WHILE (@BatchNo > 0)
		BEGIN
			SELECT	@MinCustId = MAX(MinCustId)
					,@MaxCustId = MAX(MaxCustId)
					,@MinTransId = MAX(MinTransId)
					,@MaxTransId = MAX(MaxTransId)
					,@TransIdOfMinCust = MAX(TransIdOfMinCust)
					,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
			FROM	@tmpBatch
			WHERE	BatchNo = @BatchNo

			SET @settlementTime = GETDATE();

			UPDATE 	b
				SET @tmpTotalWinScore = CAST(CAST(CASE WHEN @totalWinScore > b.hdp1 THEN b.hdp1
												WHEN @totalWinScore < b.hdp1 - b.hdp2 + 1 THEN b.hdp1 - b.hdp2 + 1
												ELSE @totalWinScore
											END AS INT)
										AS VARCHAR(10))
					,@posOdds = CHARINDEX(@tmpTotalWinScore + ':', b.betcheck) + LEN(@tmpTotalWinScore) + 1
					,@posComma = CHARINDEX(',', b.betcheck + ',', @posOdds)
					,@odds = SUBSTRING(b.betcheck, @posOdds, @posComma - @posOdds)
					,@modds = CASE WHEN @odds > 0 AND b.bettype = 469 AND b.betteam = 'o' THEN 1
									WHEN @odds < 0 AND b.bettype = 469 AND b.betteam = 'u' THEN -1 
									ELSE NULL
								END
					,@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
					,modds = @modds
					,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
										WHEN @modds = 0.25 THEN 1 
										WHEN @modds = 0 THEN 0 
										WHEN @modds = - 0.25 THEN 3
										WHEN @modds < - 0.25 THEN 4
										WHEN @modds IS NULL THEN 6
									END
					-- update odds, oddsspread
					,odds = CASE WHEN @modds IS NOT NULL THEN @odds ELSE odds END
					
					,oddsspread = CASE WHEN @modds IS NOT NULL THEN @tmpTotalWinScore ELSE oddsspread END
					,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
						WHEN '0' THEN 1
						WHEN '1' THEN 0
						ELSE 1
						END
					,@commLostRate = CASE comstatus
						WHEN '0' THEN 1
						WHEN '1' THEN 2
						ELSE 1
						END
					-- check winlost or status change to update SettlementTime
					,@statusId = CASE 
									WHEN @modds > 0 THEN 112 --WON
									WHEN @modds < 0 THEN 113 --LOSE
									WHEN @modds = 0 THEN 111 --Draw
									WHEN @modds IS NULL THEN statusID
								END
					,@winlost = CASE 
									WHEN @modds > 0 THEN actual_stake + stake * @odds
									WHEN @modds = 0 THEN actual_stake
									WHEN @modds < 0 THEN actual_stake + stake * @odds
									WHEN @modds IS NULL THEN winlost
								END
					,SettlementTime = CASE 
											WHEN @IsUpd_Void = 0 THEN SettlementTime 
											ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
										END
										
					,WinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN WinLost 
									ELSE @winlost
								END
					,aWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN aWinLost 
									ELSE CASE 
											WHEN @modds > 0 THEN stake * @odds * - apositiontaking
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN stake * @odds * - apositiontaking
											WHEN @modds IS NULL THEN awinlost
										END
								END
								
					,mWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN mWinLost 
									ELSE CASE 
											WHEN @modds > 0 THEN stake * @odds * - mpositiontaking
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN stake * @odds * - mpositiontaking
											WHEN @modds IS NULL THEN mwinlost
										END
								END
								
					,sWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN sWinLost 
									ELSE CASE 
											WHEN @modds > 0 THEN stake * @odds * - spositiontaking
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN stake * @odds * - spositiontaking
											WHEN @modds IS NULL THEN swinlost
										END
								END
								
					,PlayerComm = CASE 
									WHEN @IsUpd_Void = 0 THEN PlayerComm 
									ELSE CASE 
											WHEN @modds > 0 THEN @commWinRate * playerdiscount * stake
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN @commLostRate * playerdiscount * stake
											WHEN @modds IS NULL THEN playercomm
										END
								END
								
					,Comm = CASE 
								WHEN @IsUpd_Void = 0 THEN Comm 
								ELSE CASE 
										WHEN @modds > 0 THEN @commWinRate * discount * stake * (1 - apositiontaking)
										WHEN @modds = 0 THEN 0
										WHEN @modds < 0 THEN @commLostRate * discount * stake * (1 - apositiontaking)
										WHEN @modds IS NULL THEN comm
									END
							END
								
					,aComm = CASE 
								WHEN @IsUpd_Void = 0 THEN aComm 
								ELSE CASE 
										WHEN @modds > 0 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
										WHEN @modds = 0 THEN 0
										WHEN @modds < 0 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
										WHEN @modds IS NULL THEN acomm
									END
							END
								
					,sComm = CASE 
								WHEN @IsUpd_Void = 0 THEN sComm 
								ELSE CASE 
										WHEN @modds > 0 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
										WHEN @modds = 0 THEN 0
										WHEN @modds < 0 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
										WHEN @modds IS NULL THEN scomm
									END
							END
								
					,STATUS = CASE 
								WHEN @IsUpd_Void = 0 THEN b.[status] 
								ELSE CASE 
										WHEN @modds > 0 THEN 'WON'
										WHEN @modds < 0 THEN 'LOSE'
										WHEN @modds = 0 THEN 'DRAW'
										WHEN @modds IS NULL THEN status
									END
							END
								
					,StatusID = CASE 
									WHEN @IsUpd_Void = 0 THEN StatusID 
									ELSE @statusId
								END
								
					,ruben = CASE 
								WHEN @IsUpd_Void = 0 THEN ruben 
								ELSE 1
							END
			OUTPUT	inserted.transid
					,inserted.modds, inserted.odds, inserted.oddsspread, inserted.statuswinlost
					,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
					,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
					,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
					,inserted.Status,inserted.StatusID,inserted.ruben		
				INTO @tmpTransInfo (
					transId
					,modds, odds, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
					,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
				)					
			FROM	@tmpBatch c
				INNER JOIN dbo.bettrans b
					ON	c.BatchNo = @BatchNo
						AND c.CustId = b.custid
				CROSS APPLY (
					SELECT CASE
								WHEN c.CustId = @MinCustId AND transId < @TransIdOfMinCust THEN 0
								WHEN c.CustId = @MaxCustId AND transId > @TransIdOfMaxCust THEN 0
								WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
								ELSE 0
							END AS IsCalculated
				)i
			WHERE	b.matchid = @matchid 
					AND b.bettype = @bettype 
					AND	b.statusID NOT IN (101)
					AND i.IsCalculated = 1
					AND 1 = CASE WHEN @IsSettleAbandonedMatch = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR b.recommend = 1688156) THEN 1
									WHEN @IsSettleAbandonedMatchBetFair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 1
									WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND b.recommend <> 1688156) THEN 1							
									ELSE 0
							END
			
			IF OBJECT_ID('Service_SideDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,modds AS '@m'
							,odds AS '@o'
							,oddsspread AS '@os'
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
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_SideDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			END

			SET @BatchNo = @BatchNo - 1
				
			WAITFOR DELAY '00:00:00:010'
		END
	END
	ELSE
	BEGIN
		WHILE @BatchNo > 0
		BEGIN
			SELECT	@MinCustId = MAX(MinCustId)
					,@MaxCustId = MAX(MaxCustId)
					,@MinTransId = MAX(MinTransId)
					,@MaxTransId = MAX(MaxTransId)
					,@TransIdOfMinCust = MAX(TransIdOfMinCust)
					,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
			FROM	@tmpBatch
			WHERE	BatchNo = @BatchNo

			SET @settlementTime = GETDATE();

			UPDATE  b
				SET 
					@totalLiveWinScore = CASE WHEN b.bettype = 468 THEN CAST(@totalWinScore AS SMALLINT) - (b.livehomescore - b.liveawayscore) ELSE CAST(@totalWinScore AS SMALLINT) END
					,@tmpTotalWinScore = CAST(CAST(CASE WHEN @totalLiveWinScore  > b.hdp1 THEN b.hdp1
														WHEN @totalLiveWinScore < b.hdp1 - b.hdp2 + 1 THEN b.hdp1 - b.hdp2 + 1
														ELSE @totalLiveWinScore
											END AS INT)
										AS VARCHAR(10))
					,@posOdds = CHARINDEX(@tmpTotalWinScore + ':', b.betcheck) + LEN(@tmpTotalWinScore) + 1
					,@posComma = CHARINDEX(',', b.betcheck + ',', @posOdds)
					,@odds = SUBSTRING(b.betcheck, @posOdds, @posComma - @posOdds)
					,@modds = CASE WHEN @odds > 0 THEN 1
									WHEN @odds < 0 THEN -1 
									WHEN @odds = 0 THEN 0
									ELSE -1
								END
					,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
										WHEN @modds = 0.25 THEN 1 
										WHEN @modds = 0 THEN 0 
										WHEN @modds = - 0.25 THEN 3
										WHEN @modds < - 0.25 THEN 4
										WHEN @modds IS NULL THEN 6
									END
					,@IsUpd_Void = CASE WHEN (statusID = 102) OR (mt.TransId IS NOT NULL) THEN 0 ELSE 1 END
					,modds = @modds
					-- update odds, oddsspread
					,odds = @odds
					,oddsspread = @tmpTotalWinScore
					,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
						WHEN '0' THEN 1
						WHEN '1' THEN 0
						ELSE 1
						END
					,@commLostRate = CASE comstatus
						WHEN '0' THEN 1
						WHEN '1' THEN 2
						ELSE 1
						END
					-- check winlost or status change to update SettlementTime
					,@statusId = CASE 
									WHEN @modds > 0 THEN 112 --WON
									WHEN @modds < 0 THEN 113 --LOSE
									WHEN @modds = 0 THEN 111 --Draw
								END
					,@winlost = CASE 
									WHEN @modds > 0 THEN actual_stake + stake * @odds
									WHEN @modds = 0 THEN actual_stake
									WHEN @modds < 0 THEN actual_stake + stake * @odds
								END
					,SettlementTime = CASE 
											WHEN @IsUpd_Void = 0 THEN SettlementTime 
											ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
										END
								
					,WinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN WinLost 
									ELSE @winlost
								END
					,aWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN aWinLost 
									ELSE CASE 
											WHEN @modds > 0 THEN stake * @odds * - apositiontaking
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN stake * @odds * - apositiontaking
										END
								END
										
					,mWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN mWinLost 
									ELSE CASE 
											WHEN @modds > 0 THEN stake * @odds * - mpositiontaking
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN stake * @odds * - mpositiontaking
										END
								END
								
					,sWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN sWinLost 
									ELSE CASE 
											WHEN @modds > 0 THEN stake * @odds * - spositiontaking
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN stake * @odds * - spositiontaking
										END
								END
								
					,PlayerComm = CASE 
									WHEN @IsUpd_Void = 0 THEN PlayerComm 
									ELSE CASE 
											WHEN @modds > 0 THEN @commWinRate * playerdiscount * stake
											WHEN @modds = 0 THEN 0
											WHEN @modds < 0 THEN @commLostRate * playerdiscount * stake
										END
								END
								
					,Comm = CASE 
								WHEN @IsUpd_Void = 0 THEN Comm 
								ELSE CASE 
										WHEN @modds > 0 THEN @commWinRate * discount * stake * (1 - apositiontaking)
										WHEN @modds = 0 THEN 0
										WHEN @modds < 0 THEN @commLostRate * discount * stake * (1 - apositiontaking)
									END
								END
								
					,aComm = CASE 
								WHEN @IsUpd_Void = 0 THEN aComm 
								ELSE CASE 
										WHEN @modds > 0 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
										WHEN @modds = 0 THEN 0
										WHEN @modds < 0 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
									END
								END
								
					,sComm = CASE 
								WHEN @IsUpd_Void = 0 THEN sComm 
								ELSE CASE 
										WHEN @modds > 0 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
										WHEN @modds = 0 THEN 0
										WHEN @modds < 0 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
									END
								END
								
					,STATUS = CASE 
								WHEN @IsUpd_Void = 0 THEN [status] 
								ELSE CASE 
										WHEN @modds > 0 THEN 'WON'
										WHEN @modds < 0 THEN 'LOSE'
										WHEN @modds = 0 THEN 'DRAW'
									END
								END
								
					,StatusID = CASE 
									WHEN @IsUpd_Void = 0 THEN StatusID 
									ELSE @statusId
								END
								
					,ruben = CASE 
									WHEN @IsUpd_Void = 0 THEN ruben 
									ELSE 1
								END
			OUTPUT	inserted.transid
					,inserted.modds, inserted.odds, inserted.oddsspread, inserted.statuswinlost
					,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
					,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
					,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
					,inserted.Status,inserted.StatusID,inserted.ruben		
				INTO @tmpTransInfo (
					transId
					,modds, odds, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
					,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
				)					
			FROM	@tmpBatch c
				INNER JOIN dbo.bettrans b 
					ON 	c.batchNo = @batchNo
						AND c.custid = b.custId
				CROSS APPLY (
					SELECT CASE
								WHEN c.CustId = @MinCustId AND b.transId < @TransIdOfMinCust THEN 0
								WHEN c.CustId = @MaxCustId AND b.transId > @TransIdOfMaxCust THEN 0
								WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
								ELSE 0
							END As IsCalculated
				) i
				OUTER APPLY (
					SELECT	TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
							AND mt.CustId = c.custId
				) mt
			WHERE	matchid = @matchid 						
					AND bettype = @bettype						
					AND statusID NOT IN (101)
					AND i.IsCalculated = 1
					AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END
			
			IF OBJECT_ID('Service_SideDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,modds AS '@m'
							,odds AS '@o'
							,oddsspread AS '@os'
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
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.Service_SideDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			END

			SET @BatchNo = @BatchNo - 1
				
			WAITFOR DELAY '00:00:00:010'
		END
	END
END
GO
