/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_501] 
	@MatchId	INT
	,@bettype	SMALLINT 
	,@betcount	INT
	,@ScoreDiff INT
	,@IsReSettledTickets BIT = 1
AS
/*
	Created: Kathy
	Date: 20160112
	Task: Calculating Match Winner bettype
	DB: DBTXN/bodb02
	
	Revisions:
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Void - Recover tickets in Bet 14 [Redmine:115377]
		- 20200417@Sol: Ticket Exclusion for Other Sports - Phase 4: Remaining Sports of Other Sports [Redmine:#131765]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Parameter's Explanation:
								
*/ 
BEGIN
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@IsCentral			BIT = 0

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN
	END

	EXEC dbo.NAP_Set_ServerInfo
 		@IsCentral = @IsCentral OUTPUT
	
	IF @betcount = 0
	RETURN
	-- END CHECK
		
	DECLARE @modds			MONEY
			,@commRate		TINYINT	
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
		
	DECLARE @settlementTime DATETIME
	SET @settlementTime = GETDATE();

	UPDATE b
		SET @modds = CASE 
					WHEN (betteam = 'h' AND @ScoreDiff > 0) OR (betteam = 'a' AND @ScoreDiff < 0) THEN 1
					WHEN @ScoreDiff = 0 THEN 0
					ELSE -1
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
							
			,@commRate = CASE -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
							WHEN playerdiscount < 0 THEN 0
							WHEN comstatus = '0' THEN 1	
							WHEN @modds = 1 AND comstatus = '1' THEN 0							
							WHEN @modds = -1 AND comstatus = '1' THEN 2
							ELSE 1
							END
			-- check winlost or status change to update SettlementTime
			,@statusId = CASE 
							WHEN @modds > 0 THEN 112
							WHEN @modds = 0 THEN 111
							ELSE 113
						END
			,@winlost = CASE 
							WHEN @modds > 0.5 THEN actual_stake + stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END)
							WHEN @modds = 0 THEN actual_stake
							ELSE 0 
						END
			,SettlementTime = CASE 
								WHEN @IsUpd_Void = 0 THEN SettlementTime 
								ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
							END
					
			,winlost =CASE 
						WHEN @IsUpd_Void = 0 THEN winlost 
						ELSE @winlost
					END
			,awinlost = CASE 
							WHEN @IsUpd_Void = 0 THEN awinlost 
							ELSE CASE 
								WHEN @modds > 0.5 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -apositiontaking
								WHEN @modds = 0 THEN 0
								ELSE actual_stake * apositiontaking
							END
						END
					
			,mwinlost =  CASE 
							WHEN @IsUpd_Void = 0 THEN mwinlost 
							ELSE CASE
									WHEN @modds > 0.5 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * - mpositiontaking
									WHEN @modds = 0 THEN 0
									ELSE actual_stake * mpositiontaking
								END
						END
					
			,swinlost = CASE 
							WHEN @IsUpd_Void = 0 THEN swinlost 
							ELSE CASE
									WHEN @modds > 0.5 THEN stake * (CASE WHEN odds < 0 THEN 1 ELSE odds END) * -spositiontaking
									WHEN @modds = 0 THEN 0
									ELSE actual_stake * spositiontaking
								END
						END
					
			,playercomm = CASE 
							WHEN @IsUpd_Void = 0 THEN playercomm 
							ELSE CASE 
									WHEN @modds = 0 THEN 0
									ELSE @commRate * playerdiscount * stake								
								END
						END
					
			,comm = CASE 
						WHEN @IsUpd_Void = 0 THEN comm 
						ELSE CASE 
								WHEN @modds = 0 THEN 0
								ELSE @commRate * discount * stake * (1 - apositiontaking)
							END
					END
					
			,acomm = CASE 
						WHEN @IsUpd_Void = 0 THEN acomm 
						ELSE CASE 
								WHEN @modds = 0 THEN 0
								ELSE @commRate * adiscount * stake * (1 - (apositiontaking + mpositiontaking))
							END
					END
					
			,scomm = CASE 
						WHEN @IsUpd_Void = 0 THEN scomm 
						ELSE CASE
								WHEN @modds = 0 THEN 0
								ELSE @commRate * sdiscount * stake * (1 - (apositiontaking + mpositiontaking + spositiontaking))
							END
					END
					
			,[status] = CASE 
							WHEN @IsUpd_Void = 0 THEN [status] 
							ELSE CASE 
									WHEN @modds > 0 THEN 'WON'
									WHEN @modds = 0 THEN 'DRAW'
									ELSE 'LOSE'
								END
						END
					
			,statusID = CASE 
							WHEN @IsUpd_Void = 0 THEN statusID 
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
	FROM dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
		OUTER APPLY (
				SELECT TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transId
						AND mt.CustId = b.custid
			)mt
	WHERE	matchid = @MatchId
			AND bettype = @bettype
			AND statusID NOT IN (101) -- REJECT
			AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
						 WHEN @IsReSettledTickets = 1 THEN 1
						 ELSE 0
					END
		AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
 	

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


GO