/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MainParlay14] (@transIds VARCHAR(MAX))
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240416@Max: [TVS] Recover Ticket - Recover full range of archived tickets [Redmine: #203754]
		
	Param's Explanation:  
		   
		@transIds = '104730774034,104729373985'
					
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@TransInfo			VARBINARY(MAX) = NULL
			,@MatchId			INT
			,@IsSiteDB			BIT 

    IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
        SET @IsSiteDB = 1

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN

	END
	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @xml XML
		   
	DECLARE @tbl_transIDs AS TABLE(transid BIGINT)

	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10) , statusID TINYINT, ruben TINYINT, modds SMALLMONEY
			, winlost MONEY, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, statuswinlost TINYINT, creator INT, ExtraInfo VARCHAR(1000), FcUpdateTime DATETIME2
			, transdate DATETIME, comstatus NVARCHAR(40)
			)

	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
	
	DECLARE @tblMatchIds TABLE ( RowNumber		INT 	IDENTITY (1,1)									
								,matchid		INT
								,eventdate		DATETIME
								,transid		BIGINT
								,refno			BIGINT
								)							
								
		
	SET @XML = N'<root><r>' + REPLACE(@transIds, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO @tbl_transIDs (transid)
	SELECT r.value('.','BIGINT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	-- Reset main to running
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
		SET status = 'running'
			,statusID = 0
			,ruben = 0
			--,modds = 0
			,winlost = 0
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0		
			,statuswinlost = NULL
			,creator = b.custid
			,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(2,'recover',b.ExtraInfo,NULL, b.bettype)
		OUTPUT deleted.matchid, deleted.TransId, inserted.status, inserted.statusID, inserted.ruben
			, inserted.winlost, inserted.awinlost, inserted.mwinlost, inserted.swinlost
			, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm
			, inserted.statuswinlost, inserted.creator, inserted.ExtraInfo
		INTO @tmpTransInfo(matchid, transid, status, statusID, ruben, winlost, aWinLost, mWinLost, sWinLost
							,PlayerComm, Comm, aComm, sComm, statuswinlost, creator, ExtraInfo)
	FROM dbo.bettrans14 b
		INNER JOIN @tbl_transIDs t ON b.transid = t.transid

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		INSERT INTO @tmpMatchidInfo (MatchId)
		SELECT DISTINCT MatchId FROM @tmpTransInfo

		WHILE (1=1)
		BEGIN
			UPDATE TOP(1)m
			SET IsFinish = 1, @matchid = MatchId 
			FROM @tmpMatchidInfo m
			WHERE IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, statusID AS 'sid'
					, ruben AS 'r'
					, winlost AS 'w'
					, awinlost AS 'aw'
					, mwinlost AS 'mw'
					, swinlost AS 'sw'
					, playercomm AS 'pc'
					, comm AS 'c'
					, acomm AS 'ac'
					, scomm AS 'sc'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, creator AS 'cr'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'RecoverMainParlay', 'bettrans14', 'U', @MatchId, @TransInfo, 'p'
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
	END	
	
END
GO