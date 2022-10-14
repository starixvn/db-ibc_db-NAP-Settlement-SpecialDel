/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Undo_TransID]
	@transIds			VARCHAR(MAX)
	,@MatchId			INT = 0
	,@EventTable		TINYINT = 1 -- match
	,@IsNonSports		BIT =  0
AS
/*
	Created by: 20180801@Vicky
	Task: Incorporate eSports 2.0
	DB: DBTRANS.BODB02

	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200428@Kathy: PHAIO 5 - Add new penalty bettype[Redmine:#132805]
		- 20211104@Kathy: Upd RepUpdateTime [Redmine:#164184]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]

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
			,@AllowUndo			BIT
			,@FcUpdateTime		DATETIME2
			,@IsSiteDB			BIT = 0

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowUndo			= @AllowUndo		OUTPUT


		IF @AllowUndo = 0
			RETURN
	END

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLogIns','P') IS NOT NULL
		SET @IsSiteDB = 1

	-----------------------CHECK SERVER-----------------------------------------
	
	DECLARE @tempTrans TABLE (TransID BIGINT)
	DECLARE @tmpTransInfo TABLE (transId BIGINT
		,odds SMALLMONEY, statuswinlost TINYINT
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT, FcUpdateTime DATETIME2

		,bef_winlost MONEY
		,bef_statusid TINYINT
	)
	DECLARE @handle			INT
			,@IsUpd_Void	BIT = 0
			,@transinfo		XML	

	---parse XML
	EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
	INSERT INTO @tempTrans(TransID)
	SELECT t
	FROM OPENXML(@handle,'root/r',1) WITH(t BIGINT ) tbl
	EXEC sp_xml_removedocument @handle
	
	SET @FcUpdateTime = SYSDATETIME()

	UPDATE	b
		SET 
			@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
			,ruben = CASE 
						WHEN @IsUpd_Void = 0 THEN ruben 
						ELSE 0
					END
						 
			,STATUS = CASE 
						WHEN @IsUpd_Void = 0 THEN b.[status] 
						ELSE 'running'
					END
						
			,statusID = CASE 
							WHEN @IsUpd_Void = 0 THEN statusID 
							ELSE 0
						END
			,winlost = CASE 
							WHEN @IsUpd_Void = 0 THEN winlost 
							ELSE 0
						END
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0
			,statuswinlost = NULL
			,odds = CASE WHEN b.bettype = 376 THEN b.oddsspread ELSE b.odds END
			,FcUpdateTime = CASE WHEN b.statusId = 0 THEN b.FcUpdateTime ELSE @FcUpdateTime END
		OUTPUT	inserted.transid
			,inserted.odds
			,Inserted.Statuswinlost
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID,inserted.ruben
			,CASE WHEN inserted.FcUpdateTime <> deleted.FcUpdateTime THEN inserted.FcUpdateTime ELSE NULL END
	
			,deleted.winlost
			,deleted.statusid		
		INTO @tmpTransInfo (
			transId
			,odds, statuswinlost,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben, FcUpdateTime

			,bef_winlost, bef_statusid
		)
	FROM @tempTrans sr
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
		
	IF @IsSiteDB = 1 AND EXISTS( SELECT TOP 1 1 FROM @tmpTransInfo )
	BEGIN
		SET @transInfo = (
			SELECT	transId AS '@t'	
					,odds AS '@o' 
					,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1) ) END AS '@statuswl' 					
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
					,FcUpdateTime AS '@rut' 

					,bef_winlost AS '@bef_w' 
					,bef_statusid AS '@bef_sid' 
					
			FROM	@tmpTransInfo
			FOR XML PATH('r'),ROOT('root'), TYPE
		)

		EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
			@SystemName = 'Settlement' 
			,@FunctionName = 'UndoOtherSport'
			,@TableName = 'bettrans'
			,@MatchId = @MatchId
			,@transinfo = @transinfo
			,@SettlementAction = 'UNDO'
			,@TicketType = 's'
			,@EventTable = @EventTable
			,@IsNonSports = @IsNonSports
			
	END
END
GO
