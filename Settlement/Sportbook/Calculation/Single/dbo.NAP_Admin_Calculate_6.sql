/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_6] @matchid INT
	,@bettype SMALLINT
	,@totalgoal INT
	,@betcount INT = 0
	,@IsHTCal	 BIT = 0
	,@IsSettleAbandonedMatch BIT = 0
	,@IsSettleAbandonedMatchIBC BIT = 0
	,@IsSettleAbandonedMatchBetFair BIT = 0
	,@IsReSettledTickets BIT = 1
AS
/*
	Created by: Kathy
	Date: 20140211
	Task: Settlement 
	DB: DBO2.BODB02
	
	Revisions:
		- 20140426@Kathy: Add 1H Total Goal (126) [Redmine:#14449]
		- 20140728@Kathy: Settle determined tickets for Total Goal (6, 126)[Redmine:#19310]
		- 20140807@Kathy: Support new 11 bettypes: 129, 130, 131, 132 [Redmine:#19667]
		- 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160322@Kathy: Change betteam of bettype 412 (3&over --> 3-over) [Redmine:#54596]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20180704@Kathy: Prevent lock escalation on Bettrans [Redmine:#89132]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

*/
BEGIN
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT

	SET @ServerName = @@SERVERNAME

    IF @betcount = 0 AND @ServerName NOT LIKE N'DBIOM%' RETURN

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN
	END
	-- END CHECK
	
	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY
		,@result NVARCHAR(10)

		,@BatchCount			INT
		,@BatchNo				INT
		,@MinCustId				INT
		,@MaxCustId				INT
		,@MinTransId			BIGINT
		,@MaxTransId			BIGINT
		,@TransIdOfMinCust		BIGINT
		,@TransIdOfMaxCust		BIGINT
		,@statusId TINYINT
		,@winlost MONEY
		,@IsUpd_Void BIT = 0
		,@transInfo	XML
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, statuswinlost TINYINT,SettlementTime DATETIME
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
	DECLARE @settlementTime DATETIME

	IF @IsSettleAbandonedMatchIBC = 1 OR @IsSettleAbandonedMatch = 1 OR @IsSettleAbandonedMatchBetFair = 1
	BEGIN
		SET @settlementTime = GETDATE();

		UPDATE bettrans WITH (ROWLOCK, UPDLOCK)
		SET @modds = CASE 
								WHEN betteam = '0-1' and @totalgoal >= 2 then -1 --6
								WHEN betteam = '2-3' and @totalgoal >= 4 then -1
								WHEN betteam = '4-6' and @totalgoal >=7  and @bettype = 6 then -1
								WHEN betteam in ('4-over', '4&over') and @totalgoal >=4 then 1 -- 126, 131, 132
								WHEN betteam = '5&over' AND @totalgoal >= 5 THEN 1 -- 129
								WHEN betteam in ('7-over', '7&over') and @totalgoal >=7 then 1		-- 6, 130
								WHEN betteam not in ('5&over') and @bettype = 129 and @totalgoal > cast(betteam as INT)  THEN -1 -- 129
								WHEN betteam not in ('7&over') and @bettype = 130 and @totalgoal > cast(betteam as INT)  THEN -1 -- 130							
								WHEN betteam NOT IN ('3-over') AND @bettype = 412 AND @totalgoal > CAST(betteam AS INT) THEN -1 --412
								WHEN betteam IN ('3-over') AND @bettype = 412 AND @totalgoal >= 3 THEN 1 --412
								WHEN bettype IN (159,406) AND betteam LIKE 'G[0-5]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype IN (159,406) AND betteam ='G6' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype = 179 AND betteam LIKE 'G[0-3]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype = 179 AND betteam ='G4' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype IN (161,162,181,182,407,409) AND betteam LIKE 'G[0-2]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype IN (161,162,181,182,407,409) AND betteam ='G3' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype = 187 AND betteam LIKE 'G[0-1]' AND @totalgoal > CAST(RIGHT(betteam,1) AS TINYINT) THEN -1 
								WHEN bettype = 187 AND betteam ='G2' AND @totalgoal >= CAST(RIGHT(betteam,1) AS TINYINT) THEN 1 
								WHEN bettype = 429 THEN CASE
															WHEN @IsHTCal = 1 AND @totalgoal > 0 THEN CASE
																										WHEN @totalgoal >= 3 AND betteam = '3-over' THEN 1
																										WHEN betteam <> '3-over' THEN CASE
																																		WHEN @totalgoal > CAST(betteam AS INT) THEN -1
																																		ELSE NULL
																																	  END
																										ELSE NULL
																									END
															ELSE NULL
														END
								-- Total Corners
								WHEN bettype = 473 THEN 
													CASE WHEN betteam = '0-5' and @totalgoal > 5 THEN -1
														WHEN betteam = '6-8' and @totalgoal > 8 THEN -1
														WHEN betteam = '9-11' and @totalgoal > 11 THEN -1
														WHEN betteam = '12-14' and @totalgoal > 14 THEN -1
														WHEN betteam = '15+' and @totalgoal >= 15 THEN 1
														ELSE NULL
													END
								-- 1H Total Corners
								WHEN bettype = 474 THEN 
													CASE WHEN betteam = '0-2' and @totalgoal > 2 THEN -1
														WHEN betteam = '3-4' and @totalgoal > 4 THEN -1
														WHEN betteam = '5-6' and @totalgoal > 6 THEN -1
														WHEN betteam = '7+' and @totalgoal >= 7 THEN 1
														ELSE NULL 
													END

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
							--WHEN @modds = 0 THEN 111 --DRAW
							WHEN @modds < 0 THEN 113 --LOSE
							WHEN @modds IS NULL THEN statusID
						END
			,@winlost = CASE 
				WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
								ELSE odds END
								) END
						) * 0.5
				WHEN @modds = 0 THEN actual_stake
				WHEN @modds = - 0.25 THEN actual_stake * 0.5
				WHEN @modds < - 0.25 THEN 0
				WHEN @modds IS NULL then winlost
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
									WHEN @modds > 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											) * - apositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											) * - apositiontaking * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
									WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
									WHEN @modds IS NULL then awinlost
								END
						END
						
			,mWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN mWinLost 
							ELSE CASE 
									WHEN @modds > 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											) * - mpositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											) * - mpositiontaking * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
									WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
									WHEN @modds IS NULL THEN mwinlost
								END
						END
						
			,sWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN sWinLost 
							ELSE CASE 
									WHEN @modds > 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											) * - spositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											) * - spositiontaking * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
									WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
									WHEN @modds IS NULL THEN swinlost
								END
						END
						
			,PlayerComm = CASE 
							WHEN @IsUpd_Void = 0 THEN PlayerComm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
									WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
									WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
									WHEN @modds IS NULL THEN playercomm
								END
						END
						
			,Comm = CASE 
							WHEN @IsUpd_Void = 0 THEN Comm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
									WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking) * 0.5
									WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
									WHEN @modds IS NULL THEN comm
								END
						END
						
			,aComm = CASE 
							WHEN @IsUpd_Void = 0 THEN aComm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
									WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
									WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
									WHEN @modds IS NULL THEN acomm
								END
						END
						
			,sComm = CASE 
							WHEN @IsUpd_Void = 0 THEN sComm 
							ELSE CASE 
									WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
									WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
									WHEN @modds = 0 THEN 0
									WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
									WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
									WHEN @modds IS NULL THEN scomm
								END
						END
						
			,STATUS = CASE 
							WHEN @IsUpd_Void = 0 THEN [status] 
							ELSE CASE 
									WHEN @modds > 0 THEN 'WON'
									--WHEN @modds = 0 THEN 'DRAW'
									WHEN @modds < 0 THEN 'LOSE'
									WHEn @modds IS NULL THEN status
								END
						END
						
			,StatusID = CASE 
							WHEN @IsUpd_Void = 0 THEN StatusID 
							ELSE @statusId
						END
						
			,ruben = CASE 
							WHEN @IsUpd_Void = 0 THEN ruben 
							ELSE CASE WHEN @modds IS NULL THEN ruben
									ELSE 1
								END
						END
		OUTPUT	inserted.transid
			,inserted.modds, inserted.statuswinlost
			,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID,inserted.ruben		
		INTO @tmpTransInfo (
			transId
			,modds, statuswinlost,SettlementTime,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
		)				
		WHERE matchid = @matchid AND bettype = @bettype 
			AND statusID NOT IN (101)
			AND 1 = CASE WHEN @bettype <> 187 THEN 1 
						 WHEN @bettype = 187 AND @IsHTCal = 1 THEN 1 
						 ELSE 0 END 
			AND 1 = CASE 
						WHEN @IsSettleAbandonedMatch = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 1
						WHEN @IsSettleAbandonedMatchBetFair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 1
						WHEN @IsSettleAbandonedMatchIBC = 1 AND (custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND recommend <> 1688156) THEN 1
						ELSE 0
					END

		IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
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
				FROM	@tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
			)

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
		END		

	END
	ELSE
	BEGIN
		SET @result = CASE @bettype
							WHEN 429 THEN CASE 
										WHEN @totalgoal >=3 THEN '3-Over'
										ELSE CAST(@totalgoal AS NVARCHAR(10)) 
									  END
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

			UPDATE	b 
				SET @modds = CASE 
						WHEN bettype = 1206 AND betteam = cast(cast(@totalgoal AS TINYINT) AS VARCHAR(5)) THEN 1
						WHEN betteam = '0-1' AND @totalgoal <= 1 THEN 1		-- + 200,201
						WHEN betteam = '2-3' AND @totalgoal IN (2, 3) THEN 1
						WHEN betteam = '4-6' AND @totalgoal IN (4, 5, 6) THEN 1
						WHEN betteam IN ('4-over', '4&over') AND @totalgoal >= 4 THEN 1		--+ 200,201 
						WHEN betteam IN ('7-over', '7&over') AND @totalgoal >= 7 THEN 1		-- 7-over(195, 196,202)			
						WHEN betteam = '5&over' and bettype = 129  AND @totalgoal >= 5 THEN 1
						WHEN betteam = '3-over' and bettype = 412  AND @totalgoal >= 3 THEN 1 --412
						WHEN ((betteam <> '5&over' and bettype = 129) 
								or (betteam <> '7&over' and bettype = 130) 
								or (betteam <> '3-over' and bettype = 412)) 
							AND @totalgoal = cast(betteam AS INT) THEN 1 --412
						WHEN bettype IN (159,406) AND betteam LIKE 'G[0-5]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
						WHEN bettype IN (159,406) AND betteam ='G6' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
						WHEN bettype = 179 AND betteam LIKE 'G[0-3]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
						WHEN bettype = 179 AND betteam ='G4' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1 
						WHEN bettype IN (161,162,181,182,407,409) AND betteam LIKE 'G[0-2]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
						WHEN bettype IN (161,162,181,182,407,409) AND betteam ='G3' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
						WHEN bettype = 187 AND betteam LIKE 'G[0-1]' AND @totalgoal = CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
						WHEN bettype = 187 AND betteam ='G2' AND @totalgoal >=CAST(RIGHT(betteam,1)AS TINYINT) THEN 1
						WHEN bettype = 429 THEN CASE
													WHEN betteam = @result THEN 1
													ELSE -1
												END
						-- Total Corners
						WHEN bettype = 473 THEN 
											CASE WHEN betteam = '0-5' and @totalgoal <= 5 THEN 1
												WHEN betteam = '6-8' and @totalgoal in (6,7,8) THEN 1
												WHEN betteam = '9-11' and @totalgoal in (9,10,11) THEN 1
												WHEN betteam = '12-14' and @totalgoal in (12,13,14) THEN 1
												WHEN betteam = '15+' and @totalgoal >= 15 THEN 1
												ELSE -1 
											END
						-- 1H Total Corners
						WHEN bettype = 474 THEN 
											CASE WHEN betteam = '0-2' and @totalgoal <= 2 THEN 1
												WHEN betteam = '3-4' and @totalgoal in (3,4) THEN 1
												WHEN betteam = '5-6' and @totalgoal in (5,6) THEN 1
												WHEN betteam = '7+' and @totalgoal >= 7 THEN 1
												ELSE -1 
											END

						ELSE - 1
						END
					,@IsUpd_Void = CASE WHEN (statusID = 102) OR (mt.TransId IS NOT NULL) THEN 0 ELSE 1 END
					,modds = @modds
					,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1 
								WHEN @modds = 0 THEN 0 
								WHEN @modds = - 0.25 THEN 3
								WHEN @modds < - 0.25 THEN 4
								WHEN @modds IS NULL THEN 6
							END
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
									WHEN @modds = 0 THEN 111 --DRAW
									WHEN @modds < 0 THEN 113 --LOSE
								END
					,@winlost = CASE 
									WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132, 159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											)
									WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
													ELSE odds END
													) END
											) * 0.5
									WHEN @modds = 0 THEN actual_stake
									WHEN @modds = - 0.25 THEN actual_stake * 0.5
									WHEN @modds < - 0.25 THEN 0
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
											WHEN @modds > 0.25 THEN stake * (CASE 
													WHEN odds < 0 THEN 1
													ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
															ELSE odds END
															) END
													) * - apositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE 
													WHEN odds < 0 THEN 1
													ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
															ELSE odds END
															) END
													) * - apositiontaking * 0.5
											WHEN @modds = 0 THEN 0
											WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
											WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
										END
								END
								
					,mWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN mWinLost 
									ELSE CASE 
											WHEN @modds > 0.25 THEN stake * (CASE 
													WHEN odds < 0 THEN 1
													ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
															ELSE odds END
															) END
													) * - mpositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE 
													WHEN odds < 0 THEN 1
													ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
															ELSE odds END
															) END
													) * - mpositiontaking * 0.5
											WHEN @modds = 0 THEN 0
											WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
											WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
										END
								END
								
					,sWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN sWinLost 
									ELSE CASE 
											WHEN @modds > 0.25 THEN stake * (CASE 
													WHEN odds < 0 THEN 1
													ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
															ELSE odds END
															) END
													) * - spositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE 
													WHEN odds < 0 THEN 1
													ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 126, 129, 130, 131, 132,159,161,162,179,181,182,187,1206,406,407,409,412,429,473,474) THEN odds - 1
															ELSE odds END
															) END
													) * - spositiontaking * 0.5
											WHEN @modds = 0 THEN 0
											WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
											WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
										END
								END
								
					,PlayerComm = CASE 
									WHEN @IsUpd_Void = 0 THEN PlayerComm 
									ELSE CASE 
											WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * stake
											WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * stake * 0.5
											WHEN @modds = 0 THEN 0
											WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * stake * 0.5
											WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * stake
										END
								END
								
					,Comm = CASE 
								WHEN @IsUpd_Void = 0 THEN Comm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking)
										WHEN @modds = 0.25 THEN @commWinRate * discount * stake * (1 - apositiontaking) * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking) * 0.5
										WHEN @modds < - 0.25 THEN @commLostRate * discount * stake * (1 - apositiontaking)
									END
								END
								
					,aComm = CASE 
								WHEN @IsUpd_Void = 0 THEN aComm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
										WHEN @modds = 0.25 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
										WHEN @modds < - 0.25 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
									END
								END
								
					,sComm = CASE 
								WHEN @IsUpd_Void = 0 THEN sComm 
								ELSE CASE 
										WHEN @modds > 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
										WHEN @modds = 0.25 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
										WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
									END
								END
								
					,STATUS = CASE 
								WHEN @IsUpd_Void = 0 THEN [status] 
								ELSE CASE 
										WHEN @modds > 0 THEN 'WON'
										WHEN @modds = 0 THEN 'DRAW'
										WHEN @modds < 0 THEN 'LOSE'
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
				,inserted.modds, inserted.statuswinlost
				,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben		
			INTO @tmpTransInfo (
				transId
				,modds, statuswinlost,SettlementTime,WinLost,aWinLost
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

			IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
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
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
			END
			
			SET @BatchNo = @BatchNo - 1

			WAITFOR DELAY '00:00:00:010'
		END
	END
END

GO
