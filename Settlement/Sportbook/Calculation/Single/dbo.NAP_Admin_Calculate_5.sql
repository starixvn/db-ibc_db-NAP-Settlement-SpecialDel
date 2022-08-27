/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_5] @matchid INT
	,@bettype SMALLINT
	,@whowin SMALLMONEY = 0
	,@hth SMALLMONEY = 0
	,@hta SMALLMONEY = 0
	,@fth SMALLMONEY = 0
	,@fta SMALLMONEY = 0
	,@betcount INT = 0
	,@IsReSettledTickets BIT	= 1
AS
/*
	Created by: Kathy
	Date: 20140211
	Task: Settlement 
	DB: DBO2.BODB02
	
	Revisions:
		- 20140610@Kathy: Using clustered index(CIX_recommend_matchid_bettype) in DB052, DB053, DB054		
		- 20150413@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160613@Patrick: Reduce escalation lock when updating large amount of data [Redmine: #56550]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
*/
BEGIN
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@transInfo			XML
			,@IsSiteDB			BIT = 0
			
	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

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
		
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
			,bef_winlost MONEY ,bef_statusid TINYINT
		)
		
	CREATE TABLE #tempCust(custid INT PRIMARY KEY)

	IF @IsReSettledTickets = 0
	BEGIN
		INSERT INTO #tempCust (custid)
		SELECT	b.custid
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchid
				AND b.bettype = @bettype
				AND b.statusID IN (0,102)
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
		GROUP BY b.custid
	END
	ELSE
	BEGIN
		INSERT INTO #tempCust(custid)
		SELECT	custid
		FROM	dbo.bettrans WITH(NOLOCK) 
		WHERE	matchid = @matchid 
				AND bettype = @bettype
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
		GROUP BY custid
	END
     
	CREATE TABLE #currList (custid INT PRIMARY KEY)
	DECLARE @MinCustId INT
	DECLARE @settlementTime DATETIME

	WHILE 1 = 1
	BEGIN
		DELETE FROM #currList

		DELETE TOP (800)
		FROM #tempCust OUTPUT DELETED.custid INTO #currList
		IF @@ROWCOUNT = 0 BREAK

		SELECT @MinCustId = MIN(CustId) FROM #currList
		SET @settlementTime = GETDATE();

		UPDATE b
		SET @modds = CASE 
						WHEN bettype = 459 THEN CASE
													WHEN betteam = '1' AND @hth - livehomescore > @hta - liveawayscore THEN 1
													WHEN betteam = '2' AND @hth - livehomescore < @hta - liveawayscore THEN 1
													WHEN betteam = 'X' AND @hth - livehomescore = @hta - liveawayscore THEN 1
													ELSE -1
												END
							WHEN bettype = 458 THEN CASE
													WHEN betteam = '1' AND @fth - livehomescore > @fta - liveawayscore THEN 1
													WHEN betteam = '2' AND @fth - livehomescore < @fta - liveawayscore THEN 1
													WHEN betteam = 'X' AND @fth - livehomescore = @fta - liveawayscore THEN 1
													ELSE -1
												END
							ELSE 	
							CASE
								WHEN betteam = '1' AND @whowin > 0 THEN 1
								WHEN betteam = '2' AND @whowin < 0 THEN 1
								WHEN betteam = 'X' AND @whowin = 0 THEN 1
								ELSE -1
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
											WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
											ELSE odds END
											) END
									)
							WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
									WHEN odds < 0 THEN 1
									ELSE (CASE 
											WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
													WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
													ELSE odds END
													) END
											) * - apositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
													WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
													ELSE odds END
													) END
											) * - mpositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
													WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
													ELSE odds END
													) END
											) * - spositiontaking
									WHEN @modds = 0.25 THEN stake * (CASE 
											WHEN odds < 0 THEN 1
											ELSE (CASE 
													WHEN bettype IN (4, 5, 6, 15, 16,167,177, 1205,430,459,458) THEN odds - 1
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
							WHEN @IsUpd_Void = 0 THEN STATUS 
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
			,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID,inserted.ruben
			,deleted.winlost ,deleted.statusid		
		INTO @tmpTransInfo (
			transId
			,modds, statuswinlost,SettlementTime,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
			,bef_winlost ,bef_statusid 
		)				
		FROM	#currList t 
			INNER JOIN dbo.bettrans b WITH (ROWLOCK, UPDLOCK) 
				ON	t.custid = b.custid
			OUTER APPLY (
					SELECT	TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
							AND mt.CustId = t.custId
				) mt
		WHERE	matchid = @matchid 
				AND b.custid >= @MinCustId
				AND bettype = @bettype 
				AND statusID NOT IN (101)
				AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END 
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
				
		OPTION (FORCE ORDER)

		IF @IsSiteDB  = 1 AND EXISTS(SELECT TOP 1 1 FROM @tmpTransInfo)
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

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
			VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo, 'CAL', 's')	
			
			DELETE FROM @tmpTransInfo
		END	

		WAITFOR DELAY '00:00:00:010'
	END

	DROP TABLE #currList
	DROP TABLE #tempCust
END
GO