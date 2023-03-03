/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Bet_ExecRep14_04] 
	@TransInfoJson VARBINARY(MAX)
	,@TableName VARCHAR(128)
	,@Action	VARCHAR(1)	= 'U'
	,@RunOnServer VARCHAR(100)= NULL
	,@CalledByBrokerService	BIT = 0
	,@MessageType VARCHAR(200) = ''
AS
/*
 	Creator: 20210323@Patrick
	Task: Bet_ExecRep14_04
	DB: DBCTG/bodb02
	Revisions:
		- 20210323@Patrick: Initial [Redmine: #149927] 
		- 20220920@Max: Scale Out BetTrans [Redmine:#175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
 */

BEGIN
	SET NOCOUNT ON
	
	DECLARE @batchNo		INT			
			,@sMessage		NVARCHAR(MAX)
			,@IsEnableServiceBroker BIT
			,@ServerName	SYSNAME
			,@Decompress_TransInfoJson NVARCHAR(MAX)

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
		SET @sMessage = 'EXEC dbo.Bet_ExecRep14_04 @TransInfoJson = ' + CONVERT(NVARCHAR(MAX), @TransInfoJson, 1)
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
			,@MessageType = @MessageType
	END
	ELSE
	BEGIN
		/* Sync for some tables when void bettrans14: bettrans14, Transfer, TicketVoiding_RoutineTasks */
		IF @TableName = 'bettrans14'
		BEGIN
			IF @Action = 'U'
			BEGIN
				SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

				INSERT INTO @tmpTransId (TransID, WinLost, ruben, creator, aWinLost, mWinLost, sWinLost
										, PlayerComm, Comm, aComm, sComm, StatusID, Status, betid, ExtraInfo
									)
				SELECT *
				FROM OPENJSON(@Decompress_TransInfoJson)
				WITH (
						 t bigint 
						,w MONEY 
						,r TINYINT 
						,cr INT 
						,aw MONEY
						,mw MONEY 
						,sw MONEY 
						,pc MONEY 
						,c MONEY 
						,ac MONEY 
						,sc MONEY 
						,sid TINYINT 
						,s NVARCHAR(10) 
						,bid VARCHAR(50) 
						,ex VARCHAR(1000) 
					)		

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

