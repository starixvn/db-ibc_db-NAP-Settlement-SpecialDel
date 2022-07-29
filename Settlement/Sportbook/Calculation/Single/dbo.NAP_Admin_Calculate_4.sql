/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_4] @matchid INT
	,@bettype						SMALLINT
	,@correctscore					NVARCHAR(10) = NULL
	,@goaldiff						SMALLMONEY	 = NULL 
	,@FGLG2							NVARCHAR(10) = NULL
	,@hth							INT = 0
	,@hta							INT = 0
	,@fth							INT = 0
	,@fta							INT = 0
	,@SelectedSet					VARCHAR(50) = NULL
	,@CorrectScoreSet1				NVARCHAR(10)= NULL 
	,@CorrectScoreSet2				NVARCHAR(10)= NULL 
	,@CorrectScoreSet3				NVARCHAR(10)= NULL 
	,@CorrectScoreSet4				NVARCHAR(10)= NULL 
	,@CorrectScoreSet5				NVARCHAR(10)= NULL 
	,@betcount						INT = 0
	,@IsSettleAbandonedMatch		BIT = 0
	,@IsSettleAbandonedMatchIBC		BIT = 0
	,@IsSettleAbandonedMatchBetFair BIT = 0
	,@IsHTCal						BIT = 0
	,@IsReSettledTickets			BIT	= 1
	
AS
/*
	Created by:Kathy
	Date: 20140211
	Task: Settlement 
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20140426@Kathy: Add 1H FGLG (127) [Redmine:#14449]
		- 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054	
		- 20140725@Kathy: Settle determined tickets for Correct Score(4,30)[Redmine:#19310]
		- 20140822@Jamie: Check @correctscore and @goaldiff NULL 
		- 20141017@Jamie: Sporting Solution for Tennis [Redmine:#23034]
		- 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20151019@Kathy: Refund HT/FT & 2nd FT bettypes in case of match 3x30 [Redmine:#45626]
		- 20151123@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160613@Patrick: Reduce escalation lock when updating large amount of data [Redmine: #56550]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160824@Bobby: #62921 - Include FGLG (14,127) bet types into settle determindable
		- 20161021@Kathy: Using new non-clustered index (match_bettype) to update BetParlayDetail [Redmine:#65990]
		- 20161025@Kathy:  Avoid deadlock issue [Redmine:#65990]
		- 20161121@Bobby: #67462 - Remove code SDT for parlay bet types 14,127 when doing refund single SDT
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180122@Kathy: Prevent lock escalation on Bettrans [Redmine:#89132]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@transInfo			XML
			,@IsCentral			BIT = 0
			
	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NULL
		SET @IsCentral = 1

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
		,@matchdate				DATETIME
		,@result				NVARCHAR(10)

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

	SET @correctscore = CASE 
							WHEN @bettype IN (14) 
								THEN CASE 
										WHEN @correctscore = 'N' THEN '0:0'
										WHEN @correctscore = 'H' THEN '1:1'
										WHEN @correctscore = 'A' THEN '2:1'
										ELSE ''
									END
								ELSE @correctscore
						END		
											
	SET @FGLG2  = CASE 
					WHEN  @bettype IN (14)  
						THEN CASE 
								WHEN @FGLG2 = 'N' THEN '0:0'
								WHEN @FGLG2 = 'H' THEN '1:2'
								WHEN @FGLG2 = 'A' THEN '2:2'
								ELSE ''
							END
					WHEN @bettype = 448 
						THEN CASE 
								WHEN @FGLG2 = 'N' THEN 'NG'
								ELSE @FGLG2
								END
					ELSE @FGLG2 
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
					AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
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

	DECLARE @settlementTime DATETIME

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
				SET @modds = CASE 
						WHEN @bettype = 399 AND betteam = 'AOS' AND CHARINDEX(CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)), transdesc) = 0 THEN 1 
						WHEN @bettype = 399 AND betteam <> 'AOS' AND (@fth > LEFT(betteam,1) OR @fta > RIGHT(betteam,1)) THEN -1

						WHEN @bettype = 392 AND betteam NOT IN ('HAOS', 'AAOS') AND (@fth > LEFT(betteam,1) OR @fta > RIGHT(betteam,1)) THEN -1
								
						WHEN (@bettype IN (14, 127) AND RIGHT(betteam, 1) IN ('0', '1' )  AND @correctscore <> '') THEN --just for betchoice FG and NG
							CASE WHEN (betteam = @correctscore OR betteam = @FGLG2)	THEN 1 ELSE -1 END
						WHEN betteam NOT IN ('0:4', '4:0') 
							AND @bettype = 30 
							AND (@hth > LEFT(betteam,1) OR @hta > RIGHT(betteam,1) ) THEN -1
						WHEN betteam NOT IN ('0:5', '5:0') 
							AND @bettype = 4 
							AND (@fth > LEFT(betteam,1) OR @fta > RIGHT(betteam,1) ) THEN -1
						WHEN betteam NOT IN ('AOS')
							AND @bettype = 405 --2H Correct Score
							AND ((@fth-@hth) > LEFT(betteam,1) OR (@fta-@hta) > RIGHT(betteam,1)) THEN -1
						WHEN betteam = 'AOS' --Any Other Scores
							AND @bettype = 405 --2H Correct Score
							AND CHARINDEX(CAST(@fth-@hth AS VARCHAR) + ':' + CAST(@fta-@hta AS VARCHAR), transdesc) = 0 THEN 1

						WHEN betteam NOT IN ('AOS')
							AND @bettype = 413 --2H Correct Score
							AND (@fth > LEFT(betteam,1) OR @fta > RIGHT(betteam,1)) THEN -1
						WHEN betteam = 'AOS'
							AND @bettype = 413
							AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), transdesc) = 0 THEN 1

						WHEN betteam NOT IN ('AOS')
							AND @bettype = 414 --2H Correct Score
							AND (@hth > LEFT(betteam,1) OR @hta > RIGHT(betteam,1)) THEN -1
						WHEN betteam = 'AOS'
							AND @bettype = 414
							AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), transdesc) = 0 THEN 1
						WHEN @bettype = 16 THEN CASE
													WHEN @IsHTCal = 1 THEN CASE
																				WHEN @hth > @hta AND LEFT(betteam,1) IN ('0','2') THEN -1
																				WHEN @hth = @hta AND LEFT(betteam,1) IN ('1','2') THEN -1
																				WHEN @hth < @hta AND LEFT(betteam,1) IN ('0','1') THEN -1
																				ELSE NULL
																			END
													ELSE NULL
													END
					
						WHEN @bettype = 448 THEN CASE WHEN (@fth + @fta > 0) AND betteam = 'NG' THEN -1 ELSE NULL END
					
						--WHEN bettype IN (14,127) AND 
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
									WHEN @modds = 0 THEN 111 --DRAW
									WHEN @modds < 0 THEN 113 --LOSE
									WHEN @modds IS NULL THEN statusID
								END
					,@winlost = CASE 
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END	) END )
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END	) END ) * 0.5
						WHEN @modds = 0 THEN actual_stake WHEN @modds = - 0.25 THEN actual_stake * 0.5
						WHEN @modds < - 0.25 THEN 0
						WHEN @modds IS NULL THEN winlost
						END
					,SettlementTime =CASE 
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
											WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking * 0.5
											WHEN @modds = 0 THEN 0
											WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
											WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
											WHEN @modds IS NULL THEN awinlost
										END
								END
						
					,mWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN mWinLost 
									ELSE CASE 
											WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30,127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking * 0.5
											WHEN @modds = 0 THEN 0
											WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
											WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
											WHEN @modds IS NULL THEN mwinlost
										END
								END
					
						
					,sWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN sWinLost 
									ELSE CASE 
											WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking * 0.5
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
								WHEN @IsUpd_Void = 0 THEN b.[status]  
								ELSE 	CASE 
											WHEN @modds > 0 THEN 'WON'
											WHEN @modds = 0 THEN 'DRAW'
											WHEN @modds < 0 THEN 'LOSE'
											WHEN @modds IS NULL THEN status
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

			IF @IsCentral = 0
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
	ELSE
	BEGIN
		SET @result = CASE @bettype 
						WHEN 16 THEN CASE
										WHEN @hth > @hta THEN '1:' + CASE
																		WHEN @fth > @fta THEN '1'
																		WHEN @fth = @fta THEN '0'
																		WHEN @fth < @fta THEN '2'
																		ELSE NULL
																	END
										WHEN @hth = @hta THEN '0:' + CASE
																		WHEN @fth > @fta THEN '1'
																		WHEN @fth = @fta THEN '0'
																		WHEN @fth < @fta THEN '2'
																		ELSE NULL
																	END
										WHEN @hth < @hta THEN '2:' + CASE
																		WHEN @fth > @fta THEN '1'
																		WHEN @fth = @fta THEN '0'
																		WHEN @fth < @fta THEN '2'
																		ELSE NULL
																	END
								END
						ELSE NULL
					END

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
					@correctscore	= CASE  WHEN bettype = 1317 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN @CorrectScoreSet1
											WHEN bettype = 1317 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN @CorrectScoreSet2
											WHEN bettype = 1317 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN @CorrectScoreSet3
											WHEN bettype = 1317 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN @CorrectScoreSet4
											WHEN bettype = 1317 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN @CorrectScoreSet5
											ELSE @correctscore END
					,@modds = CASE 
						--399: Extra Time Correct Score
						WHEN @bettype = 399 THEN
							CASE WHEN betteam <> 'AOS' AND betteam = CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)) THEN 1
								WHEN betteam = 'AOS' AND CHARINDEX(CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)), transdesc) = 0 THEN 1
								ELSE -1
							END
						--392: Penalty Shootout Correct Score
						WHEN @bettype = 392 THEN
							CASE WHEN betteam NOT IN ('HAOS', 'AAOS') AND betteam = CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)) THEN 1
								WHEN betteam IN ('HAOS') AND @fth > @fta AND CHARINDEX(CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)), transdesc) = 0 THEN 1
								WHEN betteam IN ('AAOS') AND @fth < @fta AND CHARINDEX(CAST(@fth AS VARCHAR(6)) + '-' + CAST(@fta AS VARCHAR(6)), transdesc) = 0 THEN 1
								ELSE -1
							END
						--448:	Last Team To Score
						WHEN @bettype = 448 THEN CASE WHEN betteam = @FGLG2 THEN 1 ELSE -1 END
						WHEN (betteam = @correctscore OR betteam = @FGLG2 AND bettype <> 16) THEN 1
						WHEN betteam = '4:0' AND @goaldiff >= 4 AND @bettype = 30 THEN 1 -- 4UP for 1st Correct Score
						WHEN betteam = '0:4' AND @goaldiff <= - 4 AND @bettype = 30 THEN 1 -- 4UP for 1st Correct Score
						WHEN betteam = '5:0' AND @goaldiff >= 5 THEN 1
						WHEN betteam = '0:5' AND @goaldiff <= - 5 THEN 1
						WHEN betteam = 'AOS' --Any Other Scores
							AND @bettype = 405 --2H Correct Score
							AND CHARINDEX(CAST(@fth-@hth AS VARCHAR) + ':' + CAST(@fta-@hta AS VARCHAR), transdesc) = 0 THEN 1
						WHEN betteam = 'AOS'
							AND @bettype = 413
							AND CHARINDEX(CAST(@fth AS VARCHAR) + ':' + CAST(@fta AS VARCHAR), transdesc) = 0 THEN 1
						WHEN betteam = 'AOS'
							AND @bettype = 414
							AND CHARINDEX(CAST(@hth AS VARCHAR) + ':' + CAST(@hta AS VARCHAR), transdesc) = 0 THEN 1
						WHEN bettype = 16 THEN CASE
												WHEN betteam = @result THEN 1
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
									WHEN @modds > 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END	) END )
									WHEN @modds = 0.25 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END	) END ) * 0.5
									WHEN @modds = 0 THEN actual_stake WHEN @modds = - 0.25 THEN actual_stake * 0.5
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
										WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127, 1204, 1235,165,166,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking
										WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127, 1204, 1235,165,166,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - apositiontaking * 0.5
										WHEN @modds = 0 THEN 0
										WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
										WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
									END
								END
										
					,mWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN mWinLost 
									ELSE CASE 
											WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30,127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - mpositiontaking * 0.5
											WHEN @modds = 0 THEN 0
											WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
											WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
										END
									END
					
					,sWinLost = CASE 
									WHEN @IsUpd_Void = 0 THEN sWinLost 
									ELSE CASE 
											WHEN @modds > 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking
											WHEN @modds = 0.25 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE (CASE WHEN bettype IN (4, 5, 6, 14, 15, 16, 30, 127,165,166, 1204, 1235,1302,1317,405,413,414,448,399,392) THEN odds - 1 ELSE odds END ) END ) * - spositiontaking * 0.5
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
								WHEN @IsUpd_Void = 0 THEN b.[status]  
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
				INNER JOIN dbo.bettrans b -- WITH (ROWLOCK, UPDLOCK)
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
					AND 1 = CASE 
									WHEN @bettype <> 1317  THEN 1 
									WHEN @bettype = 1317 AND @SelectedSet LIKE '%1%' AND BetID = 801 THEN 1
									WHEN @bettype = 1317 AND @SelectedSet LIKE '%2%' AND BetID = 802 THEN 1
									WHEN @bettype = 1317 AND @SelectedSet LIKE '%3%' AND BetID = 803 THEN 1
									WHEN @bettype = 1317 AND @SelectedSet LIKE '%4%' AND BetID = 804 THEN 1
									WHEN @bettype = 1317 AND @SelectedSet LIKE '%5%' AND BetID = 805 THEN 1
									ELSE 0 END
					
					AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END
					
			IF @IsCentral = 0
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