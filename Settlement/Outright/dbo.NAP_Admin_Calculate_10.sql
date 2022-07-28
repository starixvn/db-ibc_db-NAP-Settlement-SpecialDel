/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_10]
	 @MatchID			INT
	,@Status			NVARCHAR(10)
	,@Deadheat			FLOAT			= 1
	,@Winlostdate		DATETIME		= NULL
	,@Action			VARCHAR(10)		= 'CAL'
AS
/*
	Created: Jamie
	Task : execRep sp for outright settlement

	DB: DBTXN/bodb02
	Original: Admin_Calculate_10

	Revisions:
		- 20140120@Lukas: insert settled command into LAS queue [Redmine:#8785]
		- 20170704@Kathy: merge code for UNDO & CAL [Redmine:#79395]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	IF @@SERVERNAME IN ('DB043', 'DB044') RETURN

	DECLARE	 @commWinRate SMALLMONEY
			,@commLostRate SMALLMONEY
			,@IsCentral	BIT = 0
			,@transInfo	XML
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY
			,statuswinlost TINYINT
			,winlostdate DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,statusID TINYINT, status TINYINT, ruben TINYINT
			)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	IF @winlostdate IS NULL
	BEGIN
		SELECT @winlostdate = CONVERT(CHAR(10),GETDATE(),111)
	END

	IF @Action='UNDO'
	BEGIN
		--Unsettle tickets
		UPDATE dbo.bettrans WITH (ROWLOCK, UPDLOCK)
		SET ruben = 0
			,STATUS = 'running'
			,statusID = 0
			,winlost = 0
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0
		OUTPUT	inserted.transid
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,inserted.Status,inserted.StatusID, inserted.ruben		
		INTO @tmpTransInfo ( transid
			,WinLost,aWinLost,mWinLost,sWinLost
			,PlayerComm,Comm,aComm,sComm
			,Status,StatusID, ruben
			)	
		WHERE matchid = @MatchID
			  AND bettype = 10 
			  AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
		BEGIN
			SET @transInfo = (
				SELECT	transId AS '@t'
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

			INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'CalculateOutright', 'bettrans', @MatchId, @transInfo)	
		END
	END 
	ELSE IF @Action = 'CAL'
	BEGIN
		IF (@status='won')
		BEGIN
			UPDATE bettrans WITH(UPDLOCK,ROWLOCK)
			SET @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
				WHEN '0' THEN 1
				WHEN '1' THEN 0 
				ELSE 1 END,
							
				[status] = 'WON',
				ruben = 1 ,
				winlostdate = @winlostdate, --convert(char(10),getdate(),111),
				statuswinlost = 2,
				Swinlost = -(odds-1) * spositiontaking * stake / @deadheat,
				mwinlost = -(odds-1) * mpositiontaking * stake / @deadheat,
				awinlost = -(odds-1) * apositiontaking * stake / @deadheat,
				winlost = (((odds-1)/@deadheat)+1) * stake ,
				Scomm = @commWinRate * (1-spositiontaking-mpositiontaking-apositiontaking) * sdiscount * stake,
				acomm = @commWinRate * (1-mpositiontaking-apositiontaking) * adiscount * stake,
				comm  = @commWinRate * (1-apositiontaking) * discount * stake,
				playercomm = @commWinRate * playerdiscount * stake,
				statusID = 112
			OUTPUT	inserted.transid
				,inserted.winlostdate
				,inserted.statuswinlost
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID	
				,inserted.ruben
			INTO @tmpTransInfo ( transid, winlostdate, statuswinlost
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID
				,ruben
			)	
			WHERE matchid = @matchid and bettype = 10 and statusID NOT IN (101, 102) -- 101:reject, 102:void
				 AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END

			IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,winlostdate AS '@wd'
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
							,ruben AS '@r'
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)
				INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOutright', 'bettrans', @MatchId, @transInfo)	
			END

		END 
		ELSE IF (@status='lose')
		BEGIN
			UPDATE bettrans WITH(UPDLOCK,ROWLOCK)
			set	@commLostRate = CASE comstatus
				WHEN '0' THEN 1
				WHEN '1' THEN 2 
				ELSE 1 END,--'s','m'
		
				[status] = 'LOSE',
				ruben = 1 ,
				winlostdate = @winlostdate,
				statuswinlost = 4,
				Swinlost = spositiontaking * stake,
				mwinlost = mpositiontaking * stake,
				awinlost = apositiontaking * stake,
				winlost =0,
				Scomm = @commLostRate * (1-spositiontaking-mpositiontaking-apositiontaking) * sdiscount * stake,
				acomm = @commLostRate * (1-mpositiontaking-apositiontaking) * adiscount * stake,
				comm  = @commLostRate * (1-apositiontaking) * discount * stake,
				playercomm = @commLostRate * playerdiscount * stake,
				statusID = 113
			OUTPUT	inserted.transid
				,inserted.winlostdate
				,inserted.statuswinlost
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID	
				,inserted.ruben
			INTO @tmpTransInfo ( transid, winlostdate, statuswinlost
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID
				,ruben
			)	
			WHERE matchid = @matchid and bettype = 10 and statusID NOT IN (101, 102) -- 101:reject, 102:void
				 AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END

			IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,winlostdate AS '@wd'
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
							,ruben AS '@r'
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)
				INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOutright', 'bettrans', @MatchId, @transInfo)	
			END

		END
		ELSE IF @status = 'Refund'
		BEGIN
			UPDATE dbo.bettrans WITH(UPDLOCK,ROWLOCK)
			SET	[status] = 'Refund',
				ruben = 1 ,
				winlostdate = @winlostdate,
				statuswinlost = 4,
				swinlost = 0, mwinlost = 0, awinlost = 0,
				winlost = actual_stake,
				scomm = 0,
				acomm = 0,
				comm  = 0,
				playercomm = 0,
				statusID = 103
			OUTPUT	inserted.transid
				,inserted.winlostdate
				,inserted.statuswinlost
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID	
				,inserted.ruben
			INTO @tmpTransInfo ( transid, winlostdate, statuswinlost
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID
				,ruben
			)	
			WHERE matchid = @matchid and bettype = 10 and statusID NOT IN (101, 102) -- 101:reject, 102:void
				 AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END

			IF OBJECT_ID('Service_SiteDB_CalculationLog','U') IS NOT NULL 
			BEGIN
				SET @transInfo = (
					SELECT	transId AS '@t'
							,winlostdate AS '@wd'
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
							,ruben AS '@r'
					FROM	@tmpTransInfo
					FOR XML PATH('r'),ROOT('root'), TYPE
				)
				INSERT INTO dbo.Service_SiteDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateOutright', 'bettrans', @MatchId, @transInfo)	
			END

		END

	END
END

GO