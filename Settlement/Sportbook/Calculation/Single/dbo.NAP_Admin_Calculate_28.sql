/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_28] @matchid INT
	,@bettype SMALLINT
	,@fth SMALLMONEY = 0
	,@fta SMALLMONEY = 0
	,@hth SMALLMONEY = 0
	,@hta SMALLMONEY = 0
	,@betcount INT = 0
	,@IsReSettledTickets BIT	= 1
AS
/*
	Created by: Kathy
	Date: 20140211
	Task: Settlement 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20151209@Patrick: Database - Change datatype [Redmine: #48660]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180704@Helen: Prevent lock escalation on Bettrans [Redmine:#89132]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190626@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types [Redmine:#115232]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
*/
BEGIN
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@transInfo	XML
			
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
		,@statusId TINYINT
		,@winlost MONEY
		,@IsUpd_Void BIT = 0

	DECLARE 
		 @BatchCount			INT
		,@BatchNo				INT
		,@MinCustId				INT
		,@MaxCustId				INT
		,@MinTransId			BIGINT
		,@MaxTransId			BIGINT
		,@TransIdOfMinCust		BIGINT
		,@TransIdOfMaxCust		BIGINT
		
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
	
	DECLARE @settlementTime DATETIME

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

		UPDATE b
		SET @modds = CASE 
						-- FOR bettype 453: 1H 3-Way Handicap
						WHEN bettype IN (453, 478) THEN 
									CASE
										WHEN betteam = '1' AND ((@hth - [hdp1]) - (@hta - [hdp2])) > 0  THEN 1
										WHEN betteam = '2' AND ((@hth - [hdp1]) - (@hta - [hdp2])) < 0  THEN 1
										WHEN betteam = 'x' AND ((@hth - [hdp1]) - (@hta - [hdp2])) = 0  THEN 1
										ELSE - 1
									END		
							ELSE		
								CASE 
										WHEN betteam = '1' AND (hdp2 - hdp1 + @fth - @fta) > 0 THEN 1
										WHEN betteam = '2' AND (hdp1 - hdp2 + @fta - @fth) > 0 THEN 1
										WHEN betteam = 'x' AND ((hdp1 - hdp2) - (@fth - @fta)) = 0 THEN 1
										ELSE - 1
								END	
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
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 453, 477, 478) THEN odds - 1
											ELSE odds END
											) END
									)
							WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28,453, 477, 478) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28,453, 477, 478) THEN odds - 1
													ELSE odds END
													) END
											) * - apositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28,453, 477, 478) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28,453, 477, 478) THEN odds - 1
													ELSE odds END
													) END
											) * - mpositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28,453, 477, 478) THEN odds - 1
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
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28,453, 477, 478) THEN odds - 1
													ELSE odds END
													) END
											) * - spositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28,453, 477, 478) THEN odds - 1
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
		WHERE matchid = @matchid AND bettype = @bettype 
			AND	statusID NOT IN (101) --status NOT IN ('REJECT')	
			AND i.IsCalculated = 1
			AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
						 WHEN @IsReSettledTickets = 1 THEN 1
						 ELSE 0
					END
		
		IF OBJECT_ID('Service_Settlement_SiteDB_CalculationLog','U') IS NOT NULL 
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

			INSERT INTO dbo.Service_Settlement_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
		END	

		SET @BatchNo = @BatchNo - 1

		WAITFOR DELAY '00:00:00:010'
	END			
END
GO