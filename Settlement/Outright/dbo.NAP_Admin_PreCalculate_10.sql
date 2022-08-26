/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_PreCalculate_10]
	 @MatchID			INT
	,@Status			NVARCHAR(10)
	,@Deadheat			FLOAT			= 1
	,@Winlostdate		DATETIME		= NULL
	,@Action			VARCHAR(10)		= 'CAL'
AS
/*
	Created: 20180802@Helen
	Task : Using Bet Publication for outright settlement
	DB: DBTXN/bodb02
	Original: Admin_Calculate_10

	Revisions:
		- 20180702@Helen: Using Bet Publication for outright settlement [Redmine:#97670]
		- 20190221@Kathy: Do not settle ticket on DB04x [Redmine:#108362]
		- 20191129@Helen: Not settle on db054 [Redmine:#123963]
        - 20200114@Sol: Server replacement - DB042 to DB055 [Redmine:#127173]
		- 20210118@Louisa: Change Instant Name of DB054 - DB054C2\DB054 [Redmine:#148785]
		- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE	 @commWinRate SMALLMONEY
			,@commLostRate SMALLMONEY
			,@IsCentral	BIT = 0
	
	DECLARE @IgnoreList VARCHAR(200)
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @Action='UNDO'
		SET @IgnoreList = 'DB04,DB043,DB044,SITDB04,SITDB043,SITDB044,DB04ADMIN1,DB04ADMIN2'
	ELSE
		SET @IgnoreList = 'DB054,DB054C2\DB054,DB04,DB042,DB043,DB044,DB04ADMIN1,DB04ADMIN2,DB233\SQLSERVER2008R2,TESTDB055,DB232\SQLSERVER2008R2,SITDB04,SITDB042,SITDB043,SITDB044,SITDB055,DB055'
	
	DECLARE @_xml XML, @_sXML VARCHAR(MAX)
		,@createdDate DATETIME

	DECLARE @subtable TABLE(transid BIGINT, winlost MONEY, awinlost MONEY, mwinlost MONEY, swinlost MONEY
							, playercomm MONEY, comm MONEY, acomm MONEY, scomm MONEY, statusid TINYINT
							, status NVARCHAR(10), winlostdate SMALLDATETIME, statuswinlost TINYINT, ruben TINYINT)
		
	IF @winlostdate IS NULL
	BEGIN
		SELECT @winlostdate = CONVERT(CHAR(10),GETDATE(),111)
	END
	
	CREATE TABLE #Outright_TempData(transid BIGINT, actual_stake MONEY, stake MONEY, odds SMALLMONEY, comstatus NVARCHAR(20), modds SMALLMONEY
		, apositiontaking SMALLMONEY, mpositiontaking SMALLMONEY, spositiontaking SMALLMONEY, playerdiscount DECIMAL(9,8),discount DECIMAL(9,8), adiscount DECIMAL(9,8), sdiscount DECIMAL(9,8)
		, WinLost MONEY, aWinLost MONEY, mWinLost MONEY, sWinLost MONEY, PlayerComm MONEY, comm MONEY, acomm MONEY, scomm MONEY, StatusID TINYINT
		, ruben TINYINT, STATUS NVARCHAR(10), winlostdate SMALLDATETIME, statuswinlost TINYINT)

	INSERT INTO #Outright_TempData(transid, actual_stake, stake, odds, comstatus, modds
		, apositiontaking, mpositiontaking, spositiontaking, playerdiscount,discount, adiscount, sdiscount
		, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm, StatusID
		, ruben, STATUS, winlostdate, statuswinlost)
	SELECT transid, actual_stake, stake, odds, comstatus, modds
		, apositiontaking, mpositiontaking, spositiontaking, playerdiscount,discount, adiscount, sdiscount
		, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm, StatusID
		, ruben, STATUS, winlostdate, statuswinlost				
	FROM dbo.bettrans WITH(ROWLOCK)	
	WHERE matchid = @matchid 
		AND bettype = 10
		AND statusID NOT IN (101, 102)
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		
	IF @Action='UNDO'
	BEGIN
		--Unsettle tickets
		UPDATE #Outright_TempData
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
		
	END 
	ELSE IF @Action = 'CAL'
	BEGIN
		IF (@status='won')
		BEGIN
			UPDATE #Outright_TempData
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
		END 
		ELSE IF (@status='lose')
		BEGIN
			UPDATE #Outright_TempData
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
			
		END
		ELSE IF @status = 'Refund'
		BEGIN
			UPDATE #Outright_TempData
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
		END
	END
	
	WHILE (1 = 1)
	BEGIN
		DELETE @subtable

		DELETE TOP (20) #Outright_TempData
		OUTPUT deleted.transid, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost
			, deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm
			, deleted.statusid, deleted.status, deleted.statuswinlost
			, deleted.winlostdate, deleted.ruben	
		INTO @subtable(transid, winlost, awinlost, mwinlost, swinlost
			, playercomm, comm, acomm, scomm
			, statusid, status,statuswinlost, winlostdate,ruben)	

		IF @@ROWCOUNT = 0 BREAK

		SET @_xml = (
					SELECT transid '@t'
						,NULLIF(winlost, 0) '@w'
						,NULLIF(awinlost, 0) '@aw'
						,NULLIF(mwinlost, 0) '@mw'
						,NULLIF(swinlost, 0) '@sw'
						,NULLIF(playercomm, 0) '@p'
						,NULLIF(comm, 0) '@c'
						,NULLIF(acomm, 0) '@ac'
						,NULLIF(scomm, 0) '@sc'
						,statusid '@sid'
						,status '@s'
						,winlostdate '@wld'
						,statuswinlost '@swd'
						,ruben '@r' 
					FROM @subtable
					FOR XML PATH('r'), ROOT('root'), TYPE
				)

		SELECT @_sXML = CONVERT(VARCHAR(max), @_xml)

		EXEC dbo.Bet_ExecRep_05 @IgnoreList = @IgnoreList
			,@updatetype	= 7 --outright mode
			,@matchid		= @matchid
			,@_sXML			= @_sXML		
	END

	DROP TABLE #Outright_TempData
	
END

GO