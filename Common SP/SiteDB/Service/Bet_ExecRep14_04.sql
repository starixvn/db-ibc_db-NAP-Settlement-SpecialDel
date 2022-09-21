/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Bet_ExecRep14_04] 
	@TransInfo	XML
	,@TableName VARCHAR(128)
	,@Action	VARCHAR(1)	= 'U'
	,@RunOnServer VARCHAR(100)= NULL
	,@CalledByBrokerService	BIT = 0
AS
/*
 	Creator: 20210323@Patrick
	Task: Bet_ExecRep14_04
	DB: DBCTG/bodb02
	Revisions:
		- 20210323@Patrick: Initial [Redmine: #149927] 
		- 20220920@Max: Scale Out BetTrans [Redmine:#175412]
 */

BEGIN
	SET NOCOUNT ON
	
	DECLARE @batchNo		INT			
			,@sMessage		NVARCHAR(MAX)
			,@IsEnableServiceBroker BIT
			,@ServerName	SYSNAME

	DECLARE @tmpTransId TABLE (
		transId BIGINT
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT, creator INT
		,betid VARCHAR(50), ExtraInfo VARCHAR(1000)
	)

	SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)

	IF @RunOnServer <> @@SERVERNAME
	BEGIN
		PRINT 'This command was skipped because run wrong server'
		RETURN
	END

	EXEC dbo.NAP_Set_ServerInfo 
		@IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT

	IF @IsEnableServiceBroker = 1 AND @CalledByBrokerService = 0
    BEGIN
		SET @sMessage = 'EXEC dbo.Bet_ExecRep14_04 @TransInfo = ' +  '''' + CONVERT(NVARCHAR(MAX), @TransInfo) + ''''
							+ ',@TableName = ' + CASE
													WHEN @TableName IS NULL THEN 'NULL'
													ELSE '''' + @TableName + ''''
													END 
							+ ',@Action = ' + CASE
													WHEN @Action IS NULL THEN 'NULL'
													ELSE '''' + @Action + ''''
													END 
							+ ',@RunOnServer = ' + CASE
													WHEN @RunOnServer IS NULL THEN 'NULL'
													ELSE '''' + @RunOnServer + ''''
													END 
							+ ',@CalledByBrokerService = 1'
		
		EXEC dbo.SSB_Send_Message 
			@MessageContent = @sMessage
			,@FunctionName = 'settlement'
			,@MessageType = 'bet_SiteDB_msg_type_01'
	END
	ELSE
	BEGIN
		/* Sync for some tables when void bettrans14: bettrans14, Transfer, TicketVoiding_RoutineTasks */
		IF @TableName = 'bettrans14'
		BEGIN
			IF @Action = 'U'
			BEGIN
				INSERT INTO @tmpTransId (TransID, WinLost, ruben, creator, aWinLost, mWinLost, sWinLost
										, PlayerComm, Comm, aComm, sComm, StatusID, Status, betid, ExtraInfo
									)
				SELECT	T.C.value('./@t', 'bigint') AS transid
					,T.C.value('./@w', 'MONEY') AS WinLost
					,T.C.value('./@r', 'TINYINT')	AS ruben
					,T.C.value('./@cr', 'INT') AS creator
					,T.C.value('./@aw', 'MONEY') AS aWinLost
					,T.C.value('./@mw', 'MONEY') AS mWinLost
					,T.C.value('./@sw', 'MONEY') AS sWinLost
					,T.C.value('./@pc', 'MONEY') AS PlayerComm
					,T.C.value('./@c', 'MONEY') AS Comm 
					,T.C.value('./@ac', 'MONEY') AS aComm
					,T.C.value('./@sc', 'MONEY') AS sComm
					,T.C.value('./@sid', 'TINYINT')		AS StatusID
					,T.C.value('./@s', 'NVARCHAR(10)')	AS [Status]
					,T.C.value('./@bid', 'VARCHAR(50)') AS betid
					,T.C.value('./@ex', 'VARCHAR(1000)') AS ExtraInfo
				FROM	@transInfo.nodes('/root/r') AS T(C)	
				OPTION (OPTIMIZE FOR (@transInfo = NULL ))		

				SET @batchNo = @@ROWCOUNT

				UPDATE TOP (@batchNo)  b
					SET	WinLost = CASE WHEN t.WinLost IS NULL THEN b.winlost ELSE t.WinLost END
						,aWinLost = CASE WHEN t.aWinLost IS NULL THEN b.awinlost ELSE t.aWinLost END			
						,mWinLost = CASE WHEN t.mWinLost IS NULL THEN b.mwinlost ELSE t.mWinLost END
						,sWinLost = CASE WHEN t.sWinLost IS NULL THEN b.swinlost ELSE t.sWinLost END
						,PlayerComm = CASE WHEN t.PlayerComm IS NULL THEN b.playercomm ELSE t.PlayerComm END
						,Comm = CASE WHEN t.Comm IS NULL THEN b.comm ELSE t.Comm END					
						,aComm = CASE WHEN t.aComm IS NULL THEN b.acomm  ELSE t.aComm END					
						,sComm = CASE WHEN t.sComm IS NULL THEN b.scomm ELSE t.sComm END					
						,Status = CASE WHEN t.Status IS NULL THEN b.status ELSE t.Status END
						,StatusID = CASE WHEN t.StatusID IS NULL THEN b.statusID ELSE t.StatusID END
						,ruben= CASE WHEN t.ruben IS NULL THEN b.ruben ELSE t.ruben END									
						,creator = CASE WHEN t.creator IS NULL THEN b.creator ELSE t.creator END
						,betid = CASE WHEN t.betid IS NULL THEN b.betid ELSE CAST(t.betid AS BIGINT) END
						,ExtraInfo = CASE WHEN t.ExtraInfo IS NULL THEN b.ExtraInfo ELSE t.ExtraInfo END
				FROM	@tmptransid t
					INNER JOIN dbo.bettrans14 b WITH (ROWLOCK, UPDLOCK)
						ON	b.transid = t.transid
			END
		END
	END
END
GO

