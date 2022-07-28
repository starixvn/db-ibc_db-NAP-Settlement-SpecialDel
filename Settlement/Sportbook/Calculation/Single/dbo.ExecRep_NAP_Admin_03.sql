/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_03] 
	@transIds	VARCHAR(MAX)
	,@Mode		VARCHAR(20)
	,@MatchId	INT = 0
AS
/*
	Created: 20211130@Kathy.Nguyen	
	Task: New cashout model [Redmine:#164838]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20211130@Kathy: New cashout model [Redmine:#164838]			
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:  
		   
		@transIds = '<root>
						<r t="104730774034" w="" s=""/>
					</root>'
					t: transid
					s: statuswinlost
					w: winlost
*/ 
BEGIN
	SET NOCOUNT ON
	-----------------------CHECK SERVER-----------------------------------------
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
			,@AllowUndo			= @AllowUndo OUTPUT
			,@AllowRefund		= @AllowRefund OUTPUT

		IF @AllowCalculation = 0 AND @mode = 'CAL'
			RETURN
		
		IF @AllowUndo = 0 AND @mode = 'UNDO'
			RETURN

		IF @AllowRefund = 0 AND @mode = 'REFUND'
			RETURN

	END

	DECLARE @handle 			INT
			,@statusId			TINYINT
			,@IsUpdated			BIT		
			,@settlementTime	DATETIME
			,@commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY
			,@transinfo		XML	

	DECLARE @tempTrans TABLE (TransID BIGINT, statuswinlost TINYINT, winlost MONEY)
	DECLARE @tmpTransInfo TABLE (transId BIGINT
		,statuswinlost TINYINT
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT, RepUpdateTime DATETIME2

		,bef_winlost MONEY
		,bef_statusid TINYINT
	)

	---parse XML
	EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
	INSERT INTO @tempTrans(TransID, statuswinlost, winlost)
	SELECT t, s, w
	FROM OPENXML(@handle,'root/r',1) WITH(t   BIGINT
										 ,s   TINYINT
										 ,w	  MONEY
									) tbl
	EXEC sp_xml_removedocument @handle

	SET	@IsUpdated = 0
	SET @SettlementTime = GETDATE()

	UPDATE b
		SET @StatusId = CASE	
							WHEN b.statusID = 102 THEN 102
							WHEN t.statuswinlost = 6 THEN 103
							WHEN b.actual_stake < t.Winlost THEN 112
							WHEN b.actual_stake = t.Winlost THEN 111
							ELSE 113
						END
			,@IsUpdated = CASE WHEN b.statusID = 103 OR @StatusId = 103 THEN 1 ELSE 0 END
			,@commWinRate = CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
								WHEN '0' THEN 1
								WHEN '1' THEN 0
								ELSE 1 END
			,@commLostRate = CASE b.comstatus
								WHEN '0' THEN 1
								WHEN '1' THEN 2
								ELSE 1 END
			,statusID = CASE WHEN @IsUpdated = 1 THEN @StatusId ELSE b.statusID END
			,winlost = CASE 
							WHEN @IsUpdated = 1 
								THEN CASE WHEN @StatusId = 103 THEN b.actual_stake ELSE t.Winlost END 
							ELSE b.winlost 
						END
			,awinlost = CASE
							WHEN @IsUpdated = 0 THEN b.awinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.apositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.apositiontaking
						END
			,mwinlost = CASE
							WHEN @IsUpdated = 0 THEN b.mwinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.mpositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.mpositiontaking
						END
			,swinlost = CASE
							WHEN @IsUpdated = 0 THEN b.swinlost
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN ABS(t.Winlost - b.actual_stake) * -b.spositiontaking
							WHEN @StatusId = 111 THEN 0
							ELSE ABS(t.Winlost - b.actual_stake) * b.spositiontaking
						END
			,playercomm = CASE
							WHEN @IsUpdated = 0 THEN b.playercomm
							WHEN @StatusId = 103 THEN 0
							WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.playerdiscount
							WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.playerdiscount
							ELSE @commLostRate * b.stake * b.playerdiscount
						END
			,comm = CASE
						WHEN @IsUpdated = 0 THEN b.comm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.discount * (1-apositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.discount * (1-apositiontaking)
						ELSE @commLostRate * b.stake * b.discount * (1-apositiontaking)
					END
			,acomm = CASE
						WHEN @IsUpdated = 0 THEN b.acomm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
						ELSE @commLostRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
					END
			,scomm = CASE
						WHEN @IsUpdated = 0 THEN b.scomm
						WHEN @StatusId = 103 THEN 0
						WHEN @StatusId = 112 THEN @commWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
						WHEN @StatusId = 111 THEN @commWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
						ELSE @commLostRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
					END
			,status = CASE 
						WHEN @IsUpdated = 0 THEN b.status
						WHEN @StatusId = 103 THEN 'Refund'
						WHEN @StatusId = 112 THEN 'WON'
						WHEN @StatusId = 111 THEN 'DRAW'
						ELSE 'LOSE'
					END
			,statuswinlost = t.statuswinlost
			,SettlementTime = CASE 
								WHEN @IsUpdated = 0 THEN b.SettlementTime
								ELSE CASE WHEN b.winlost <> t.Winlost OR b.statusID <> @StatusId THEN @settlementTime ELSE SettlementTime END
								END	
			,RepUpdateTime = CASE WHEN @statusId = 103 AND b.statusID <> 103 THEN SYSDATETIME() ELSE RepUpdateTime END
		OUTPUT	inserted.transid
			,inserted.statuswinlost
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID
			,CASE WHEN inserted.RepUpdateTime <> deleted.RepUpdateTime THEN inserted.RepUpdateTime ELSE NULL END
	
			,deleted.winlost
			,deleted.statusid		
		INTO @tmpTransInfo (
			transId
			,statuswinlost,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID, RepUpdateTime

			,bef_winlost, bef_statusid
		)
	FROM	dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @tempTrans t
			ON b.transid = t.TransId

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL
	BEGIN
		SET @transInfo = (
			SELECT	transId AS '@t'	
					,statuswinlost AS '@statuswl' 					
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
					,RepUpdateTime AS '@rut' 

					,bef_winlost AS '@bef_w' 
					,bef_statusid AS '@bef_sid' 
					
			FROM	@tmpTransInfo
			FOR XML PATH('r'),ROOT('root'), TYPE
		)

		INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
		VALUES ('Settlement', 'CalculateCashout', 'bettrans', @MatchId, @transInfo)	
		
	END
END
GO
