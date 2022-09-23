/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_1324] 
     @matchid						INT
	,@bettype						SMALLINT
	,@SelectedSet					VARCHAR(50)  = NULL 
	,@SelectedSettleFinishedGame	VARCHAR(50)  = NULL 
	,@SetxGameyHomeWON				VARCHAR(MAX) = NULL
	,@SetxGameyAwayWON				VARCHAR(MAX) = NULL
	,@SetxGameyDRAW					VARCHAR(MAX) = NULL 
	,@SetxGameyREFUND				VARCHAR(MAX) = NULL 
	,@SetxGameyFinishedGame			VARCHAR(MAX) = NULL 
	,@betcount						INT = 0
	-- add any params, please modify script in 'special section'
AS
/*
	Created by: Jamie
	Date:20141020
	Task: Settlement Tennis 
	DB: DBTXN/BODB02
		
	Revisions:
		- 20151208@Patrick: Database - Change datatype [Redmine: #48660]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
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
			,@IsSiteDB		BIT = 0
	
	SET @ServerName = @@SERVERNAME

    IF @betcount = 0 AND @ServerName NOT LIKE N'DBIOM%' 
		RETURN

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN
	END
	-- END CHECK

	DECLARE @modds			MONEY
		,@commWinRate		SMALLMONEY
		,@commLostRate		SMALLMONEY
		,@RemoteCount		INT
		,@isAutoRefundGame	BIT
		,@statusId TINYINT
		,@winlost MONEY
		,@IsUpd_Void BIT = 0
		
	DECLARE @settlementTime DATETIME
	SET @settlementTime = GETDATE();

	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
			,bef_winlost MONEY ,bef_statusid TINYINT
		)
		
	UPDATE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
	SET 
		
		@isAutoRefundGame	= CASE WHEN  CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 1 ELSE 0 END -- Refund: Game no score 
			
		,@modds = CASE	WHEN betteam =N'h' AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyHomeWON)>0 THEN 1 
								WHEN betteam =N'a' AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyAwayWON)>0 THEN 1   
								WHEN CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyDRAW)>0 THEN 0 
								WHEN CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyREFUND)>0 THEN 0
								ELSE -1 END
		,@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
		,modds = @modds
		,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1 
								WHEN @modds = 0 AND @isAutoRefundGame =0 THEN 0 --DRAW
								WHEN @modds = 0 AND @isAutoRefundGame =1 THEN 6 --REFUND
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
						WHEN @modds = 0 AND @isAutoRefundGame =0 THEN 111 --DRAW
						WHEN @modds = 0 AND @isAutoRefundGame =1 THEN 103 --REFUND
						WHEN @modds < 0 THEN 113 --LOSE
					END
		,@winlost = CASE 
						WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
										ELSE odds END
										) END
								)
						WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
								WHEN odds < 0 THEN 1
								ELSE (CASE 
										WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
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
												WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
												ELSE odds END
												) END
										) * - apositiontaking
								WHEN @modds = 0.25 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE (CASE 
												WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
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
												WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
												ELSE odds END
												) END
										) * - mpositiontaking
								WHEN @modds = 0.25 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE (CASE 
												WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
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
												WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
												ELSE odds END
												) END
										) * - spositiontaking
								WHEN @modds = 0.25 THEN stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE (CASE 
												WHEN bettype IN (4, 5, 6, 1201) THEN odds - 1
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
					
		,Status = CASE 
						WHEN @IsUpd_Void = 0 THEN [status]
						ELSE CASE
								WHEN @modds > 0 THEN N'WON'
								WHEN @modds = 0 AND @isAutoRefundGame=0 THEN N'DRAW'
								WHEN @modds = 0 AND @isAutoRefundGame=1 THEN N'Refund'
								WHEN @modds < 0 THEN N'LOSE'
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
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID
			,ruben,bef_winlost ,bef_statusid 
		)
	WHERE	matchid = @matchid 
			AND bettype = @bettype 
			AND statusID NOT IN (101)
			AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
			AND 1 = CASE WHEN @SelectedSet LIKE '%1%' AND BetID BETWEEN 80101 AND 80199 THEN 1  -- CAL Set x Game y Winner 
							WHEN @SelectedSet LIKE '%2%' AND BetID BETWEEN 80201 AND 80299 THEN 1 
							WHEN @SelectedSet LIKE '%3%' AND BetID BETWEEN 80301 AND 80399 THEN 1 
							WHEN @SelectedSet LIKE '%4%' AND BetID BETWEEN 80401 AND 80499 THEN 1 
							WHEN @SelectedSet LIKE '%5%' AND BetID BETWEEN 80501 AND 80599 THEN 1 
							ELSE 0 END 
			AND 1 = CASE WHEN @SelectedSettleFinishedGame IS NULL THEN 1 
							WHEN @SelectedSettleFinishedGame LIKE '%1%' AND BetID BETWEEN 80101 AND 80199 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1 
							WHEN @SelectedSettleFinishedGame LIKE '%2%' AND BetID BETWEEN 80201 AND 80299 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1   
							WHEN @SelectedSettleFinishedGame LIKE '%3%' AND BetID BETWEEN 80301 AND 80399 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1
							WHEN @SelectedSettleFinishedGame LIKE '%4%' AND BetID BETWEEN 80401 AND 80499 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1  
							WHEN @SelectedSettleFinishedGame LIKE '%5%' AND BetID BETWEEN 80501 AND 80599 AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(10)),2,4),@SetxGameyFinishedGame)>0 THEN 1   
							ELSE 0 END 	
							
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
	END	
END
GO