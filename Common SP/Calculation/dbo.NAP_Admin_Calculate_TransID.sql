/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_TransID]
	@transIds		   VARCHAR(MAX)	
	,@MatchId			INT = 0
	
AS
/*
	Created by: 20180801@Vicky
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		- 20190225@Sol:  New Formula for Comm [Redmine:#109007]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200428@Kathy: PHAIO 5 - Add new penalty bettype[Redmine:#132805]
		- 202103186@Louisa: Cricket AIO [Redmine:#148870]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220128@Kathy: Cricket AIO Phase 2 [Redmine:#166335]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:  
		   
		@transIds = '<root>
						<r t="104730774034" m="1"/>
						<r t="104729373985" m="0" ot="1"/>
					</root>'
					t:  transid
					m:  modds
					ot: oddstype: 1: DECIMAL ONLY
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@IsSiteDB			BIT = 0

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN

	END
	
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1
		
	-----------------------CHECK SERVER-----------------------------------------
	
	DECLARE @tempTrans TABLE (TransID BIGINT, modds SMALLMONEY, oddstype TINYINT, srecommend INT, bettype SMALLINT, isCN88 BIT, isMajorGroup BIT, IsMarked BIT, finalodds SMALLMONEY, DeadHeat TINYINT)
	DECLARE @tmpTransInfo TABLE (transId BIGINT
		,modds MONEY, odds SMALLMONEY, statuswinlost TINYINT,SettlementTime DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT

		,bef_winlost MONEY
		,bef_statusid TINYINT
	)

	DECLARE @handle 			INT
			,@modds 			SMALLMONEY
			,@commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@commHalfWLRate	SMALLMONEY
			,@odds				SMALLMONEY
			,@winlost			MONEY
			,@stake				MONEY
			,@statusId			TINYINT
			,@IsUpd_Void		BIT = 0
			,@transInfo			XML
			
	DECLARE @settlementTime DATETIME

	---parse XML
	EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
	INSERT INTO @tempTrans(TransID, modds, oddstype, srecommend, bettype, IsMarked, DeadHeat)
	SELECT t, m, ot, sr, bt,im, dh
	FROM OPENXML(@handle,'root/r',1) WITH(t   BIGINT
										 ,m   SMALLMONEY
										 ,ot  TINYINT
										 ,sr  INT
										 ,bt  SMALLINT
										 ,im  BIT	
										 ,dh  TINYINT
									) tbl
	EXEC sp_xml_removedocument @handle

	-- update if bettype belongs to the CN88 site or not
	UPDATE tmp
	  SET	isCN88 = CASE WHEN cs.CustId IS NULL THEN 0 ELSE 1 END,
			isMajorGroup = CASE WHEN f.CommBettypeGroupId IS NOT NULL AND f.CommBettypeGroupId = 1 THEN 1 ELSE 0 END,
			finalodds = CASE WHEN f.BetType = 376 THEN tmp.modds ELSE NULL END,
			modds = CASE 
						WHEN f.BetType = 376 
							THEN CASE 
									WHEN tmp.modds = 1 THEN 0
									WHEN tmp.modds > 1 THEN 1
									ELSE -1
								END
						ELSE tmp.modds
					END
	FROM   @tempTrans tmp
			   LEFT JOIN dbo.CS_CustSuper cs WITH(NOLOCK)
				   ON tmp.srecommend = cs.CustId
				LEFT JOIN dbo.f_Set_GetGroupBettypes() AS f
					ON tmp.bettype = f.BetType

	
	SET @settlementTime = GETDATE();

	UPDATE  b
	SET @modds = sr.modds
	   ,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
							WHEN '0' THEN 1
							WHEN '1' THEN 0
							ELSE 1 END
	   ,@commLostRate = CASE comstatus
							WHEN '0' THEN 1
							WHEN '1' THEN 2
							ELSE 1 END
	   ,@commHalfWLRate = CASE WHEN sr.isCN88 = 1 AND sr.isMajorGroup = 1 THEN 1
							ELSE 0.5
						END
	   ,@odds = (CASE WHEN b.odds < 0 THEN 1 
	   				 WHEN sr.oddstype = 1 THEN CASE 
													WHEN b.bettype = 376 THEN sr.finalodds - 1
													WHEN sr.modds > 0.25 AND b.bettype IN (9538,9539,9540) AND b.betteam LIKE '%l' THEN 1
													ELSE b.odds - 1 END ----/*DECIMAL ONLY*/
					 ELSE b.odds END)
		,odds = CASE 
					WHEN b.bettype = 376 
						THEN CASE 
								WHEN @modds IN(0, 1) THEN sr.finalodds
								ELSE b.oddsspread
							END
					ELSE b.odds
				END
		----------------------------------------------------------------------------------------------------------------
		,@IsUpd_Void = CASE WHEN statusID = 102 OR sr.IsMarked = 1 THEN 0 ELSE 1 END
		,modds = @modds
		,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1 
								WHEN @modds = 0 THEN 0 
								WHEN @modds = - 0.25 THEN 3
								WHEN @modds < - 0.25 THEN 4
								WHEN @modds IS NULL THEN 6
							END 			   	
		,@winlost = CASE
				WHEN @modds >  0.25 THEN CASE WHEN ISNULL(sr.DeadHeat,0) > 0 THEN (@odds/sr.DeadHeat + 1) * stake ELSE actual_stake + stake * @odds END
				WHEN @modds =  0.25 THEN actual_stake + stake * @odds * 0.5
				WHEN @modds =  0	THEN actual_stake
				WHEN @modds = -0.25 THEN actual_stake * 0.5
				WHEN @modds < -0.25 THEN 0
				END 	
		-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
		,@stake = CASE WHEN sr.isCN88 = 1 AND sr.isMajorGroup = 1 THEN ABS(@winlost - actual_stake)
						ELSE stake 
					END
		-- check winlost or status change to update SettlementTime
		,@statusId = CASE
						WHEN @modds > 0 THEN 112 --WON
						WHEN @modds = 0 THEN 111 --DRAW
						WHEN @modds < 0 THEN 113 --LOSE
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
								WHEN @modds >  0.25 THEN stake * @odds * -apositiontaking/ISNULL(sr.DeadHeat,1)
								WHEN @modds =  0.25 THEN stake * @odds * -apositiontaking * 0.5
								WHEN @modds =  0	THEN 0
								WHEN @modds = -0.25 THEN actual_stake * apositiontaking * 0.5
								WHEN @modds < -0.25 THEN actual_stake * apositiontaking
							END
					END
							
		,mWinLost = CASE 
						WHEN @IsUpd_Void = 0 THEN mWinLost 
						ELSE CASE
								WHEN @modds >  0.25 THEN stake * @odds * -mpositiontaking/ISNULL(sr.DeadHeat,1)
								WHEN @modds =  0.25 THEN stake * @odds * -mpositiontaking * 0.5
								WHEN @modds =  0	THEN 0
								WHEN @modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
								WHEN @modds < -0.25 THEN actual_stake * mpositiontaking
							END
					END
					
		,sWinLost = CASE 
						WHEN @IsUpd_Void = 0 THEN sWinLost 
						ELSE CASE
								WHEN @modds >  0.25 THEN stake * @odds * -spositiontaking/ISNULL(sr.DeadHeat,1)
								WHEN @modds =  0.25 THEN stake * @odds * -spositiontaking * 0.5
								WHEN @modds =  0	THEN 0
								WHEN @modds = -0.25 THEN actual_stake * spositiontaking * 0.5
								WHEN @modds < -0.25 THEN actual_stake * spositiontaking
							END
					END

		,PlayerComm = CASE 
						WHEN @IsUpd_Void = 0 THEN PlayerComm 
						ELSE CASE
								WHEN @modds >  0.25 THEN @commWinRate * playerdiscount * @stake
								WHEN @modds =  0.25 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
								WHEN @modds =  0	THEN 0
								WHEN @modds = -0.25 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
								WHEN @modds < -0.25 THEN @commLostRate * playerdiscount * @stake
							END
					END
					
		,Comm = CASE 
					WHEN @IsUpd_Void = 0 THEN Comm 
					ELSE CASE
							WHEN @modds >  0.25 THEN @commWinRate * discount * @stake * (1-apositiontaking)
							WHEN @modds =  0.25 THEN @commWinRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
							WHEN @modds =  0	THEN 0
							WHEN @modds = -0.25 THEN @commLostRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
							WHEN @modds < -0.25 THEN @commLostRate * discount * @stake * (1-apositiontaking)
						END
				END
					
		,aComm = CASE 
					WHEN @IsUpd_Void = 0 THEN aComm 
					ELSE CASE
							WHEN @modds >  0.25 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
							WHEN @modds =  0.25 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN @modds =  0	THEN 0
							WHEN @modds = -0.25 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN @modds < -0.25 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
						END
				END
					
		,sComm = CASE 
					WHEN @IsUpd_Void = 0 THEN sComm 
					ELSE CASE
							WHEN @modds >  0.25 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
							WHEN @modds =  0.25 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN @modds =  0	THEN 0
							WHEN @modds = -0.25 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
							WHEN @modds < -0.25 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
						END
				END
					
		,Status = CASE 
					WHEN @IsUpd_Void = 0 THEN Status 
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
		,ruben=CASE 
					WHEN @IsUpd_Void = 0 THEN ruben 
					ELSE 1
				END
		OUTPUT	inserted.transid
			,inserted.modds, inserted.odds, inserted.statuswinlost
			,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID,inserted.ruben
	
			,deleted.winlost
			,deleted.statusid		
		INTO @tmpTransInfo (
			transId
			,modds, odds, statuswinlost,SettlementTime,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben

			,bef_winlost, bef_statusid
		)
	FROM @tempTrans sr
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
	WHERE ISNULL(b.betdaqid,0) <> -2

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		SET @transInfo = (
			SELECT	transId AS '@t'
					,modds AS '@m'
					,odds AS '@o'				
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

	RETURN
	
END
GO