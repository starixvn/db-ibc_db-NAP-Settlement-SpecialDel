/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Refund_TransID]
	@transIds			VARCHAR(MAX)
	,@MatchId			INT = 0

AS
/*  Created by: Vicky
	Date: 20180801
	Task: Refund for esport
	DB: DBTXN/BODB02
	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200428@Kathy: PHAIO 5 - Add new penalty bettype[Redmine:#132805]
		- 20211104@Kathy: Upd RepUpdateTime [Redmine:#164184]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
			@transIds = '<root>
						<r t="104730774034"/>
						<r t="104729373985"/>
					</root>'
*/
BEGIN
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowRefund		BIT
			,@IsUpd_Void BIT = 0
	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowRefund		= @AllowRefund		OUTPUT

		IF @AllowRefund = 0
			RETURN
	END
	-----------------------CHECK SERVER-----------------------------------------
	
	DECLARE @tempTrans TABLE (TransID BIGINT)
	DECLARE @tmpTransInfo TABLE (transId BIGINT
		,odds SMALLMONEY, statuswinlost TINYINT,SettlementTime DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT, RepUpdateTime DATETIME2

		,bef_winlost MONEY
		,bef_statusid TINYINT
	)
	DECLARE @handle INT
			,@transinfo XML

	---parse XML
	EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
	INSERT INTO @tempTrans(TransID)
	SELECT t
	FROM OPENXML(@handle,'root/r',1) WITH(t BIGINT) tbl
	EXEC sp_xml_removedocument @handle  
	
	DECLARE @settlementTime DATETIME
			,@RepUpdateTime DATETIME2

	SET @settlementTime = GETDATE();
	SET @RepUpdateTime = SYSDATETIME()

	UPDATE	b
		SET				
			@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
			,[status] = CASE 
							WHEN @IsUpd_Void = 0 THEN [status] 
							ELSE N'Refund'
						END
					
			,SettlementTime = CASE WHEN @IsUpd_Void = 0 THEN SettlementTime
									ELSE CASE WHEN winlost <> actual_stake OR statusID <> 103 THEN @settlementTime ELSE SettlementTime END
							 END
			,statusID = CASE 
							WHEN @IsUpd_Void = 0 THEN statusID 
							ELSE 103
						END
			,winlost = actual_stake
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0
			,ruben = 1
			,statuswinlost = 6
			,odds = CASE WHEN b.bettype = 376 THEN b.oddsspread ELSE b.odds END
			,RepUpdateTime = CASE WHEN b.statusId = 103 THEN b.RepUpdateTime ELSE @RepUpdateTime END
		OUTPUT	inserted.transid
			,inserted.odds
			,inserted.statuswinlost
			,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID,inserted.ruben
			,CASE WHEN inserted.RepUpdateTime <> deleted.RepUpdateTime THEN inserted.RepUpdateTime ELSE NULL END
	
			,deleted.winlost
			,deleted.statusid		
		INTO @tmpTransInfo (
			transId
			,odds, statuswinlost,SettlementTime,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben, RepUpdateTime

			,bef_winlost, bef_statusid
		)
	FROM @tempTrans sr
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid

	IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
	BEGIN
		SET @transInfo = (
			SELECT	transId AS '@t'		
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

		INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
		VALUES ('Settlement', 'RefundOtherSport', 'bettrans', @MatchId, @transInfo)		
	END
END
GO
