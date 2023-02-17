/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Transfer_ExecRep_04] 	
	@TransInfoJson VARBINARY(MAX)
	,@TableName VARCHAR(128)
	,@Action	VARCHAR(1)	= 'U'
	,@RunOnServer VARCHAR(100)= NULL
	,@CalledByBrokerService	BIT = 0
AS
/*
	Created by: 20211227@Kathy
    Task: transfer SP 
    DB: DBCTG/BODB02 

	Revisions:
		- 20220920@Max: Scale Out BetTrans [Redmine:#175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @batchNo		INT			
			,@sMessage		NVARCHAR(MAX)
			,@IsEnableServiceBroker BIT
			,@ServerName	SYSNAME
			,@Decompress_TransInfoJson NVARCHAR(MAX)

	DECLARE @tmpTransId TABLE (
		winlostdate DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,custid INT, stake MONEY,actual_stake MONEY
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
		SET @sMessage = 'EXEC dbo.Transfer_ExecRep_04 @TransInfoJson = ' +  '''' + CONVERT(NVARCHAR(MAX), @TransInfoJson, 1) + ''''
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
		IF @TableName = 'Transfer'
		BEGIN
			IF @Action = 'U'
			BEGIN
				SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

				INSERT INTO @tmpTransId (custid, stake, actual_stake, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, winlostdate)
				SELECT *
				FROM OPENJSON(@Decompress_TransInfoJson)
				WITH (
						 cust INT  
						,stake MONEY 
						,astake MONEY 
						,w MONEY 
						,aw MONEY 
						,mw MONEY 
						,sw MONEY 
						,pc MONEY 
						,c MONEY 
						,ac MONEY 
						,sc MONEY 
						,wld SMALLDATETIME 
					)

				SET @batchNo = @@ROWCOUNT

				UPDATE TOP (@batchNo)  b
					SET	Stake = CASE WHEN t.stake IS NULL THEN b.Stake ELSE t.stake END
						,Actual_Stake = CASE WHEN t.actual_stake IS NULL THEN b.Actual_Stake ELSE t.actual_stake END
						,WinLost = CASE WHEN t.WinLost IS NULL THEN b.winlost ELSE t.WinLost END
						,aWinLost = CASE WHEN t.aWinLost IS NULL THEN b.awinlost ELSE t.aWinLost END			
						,mWinLost = CASE WHEN t.mWinLost IS NULL THEN b.mwinlost ELSE t.mWinLost END
						,sWinLost = CASE WHEN t.sWinLost IS NULL THEN b.swinlost ELSE t.sWinLost END
						,PlayerComm = CASE WHEN t.PlayerComm IS NULL THEN b.playercomm ELSE t.PlayerComm END
						,Comm = CASE WHEN t.Comm IS NULL THEN b.comm ELSE t.Comm END					
						,aComm = CASE WHEN t.aComm IS NULL THEN b.acomm  ELSE t.aComm END					
						,sComm = CASE WHEN t.sComm IS NULL THEN b.scomm ELSE t.sComm END					
				FROM	@tmptransid t
					INNER JOIN dbo.Transfer b WITH (ROWLOCK, UPDLOCK)
						ON	b.CustId = t.custid AND t.winlostdate = b.WinlostDate AND b.Bettype = 19999 
			END
		END
	END
END
GO