/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SyncService_NotExecRep] 	
	@TransInfo	XML
	,@TableName VARCHAR(128)
	,@Action	VARCHAR(1)	= 'I'
AS
/*
	Created by: 20220728@Kathy
	Task: Settlement  

	Revisions:
		- 20220920@Max: Scale Out BetTrans [Redmine:#175412]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RequestID INT

	DECLARE @tmpTransId TABLE (
		refno BIGINT
		,winlostdate DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,StatusID TINYINT, creator INT		
		,custid INT, bettype SMALLINT , CreatedDate DATETIME		
		,transdate	 DATETIME,checktime	DATETIME	
		,actualrate	FLOAT,recommend	INT	,mrecommend	INT	,srecommend	INT
		,stake MONEY,actual_stake MONEY,currency	TINYINT	
		,Username	NVARCHAR(100),CurrencyName	NVARCHAR(100)
		,RequestId INT, StepNo TINYINT, [Action] VARCHAR(100), AffectedList VARCHAR(MAX), ExecuteType TINYINT
	)

	/* Sync for some tables when void bettrans14: bettrans14, Transfer, TicketVoiding_RoutineTasks */
	IF @TableName = 'Transfer'
	BEGIN
		IF @Action = 'I'
		BEGIN
			INSERT INTO @tmpTransId (statusID, bettype, creator, transdate,
							custid, currency, recommend, mrecommend, srecommend,
							winlostdate, stake, winlost, awinlost, mwinlost, swinlost,
							actual_stake, playercomm, comm, acomm, scomm, 
							actualrate, Username, CurrencyName, checktime, refno
						)
			SELECT T.C.value('./@sid', 'TINYINT') AS StatusID
				,T.C.value('./@btype', 'SMALLINT') AS bettype
				,T.C.value('./@cr', 'INT') AS creator
				,T.C.value('./@td', 'DATETIME') AS transdate
				,T.C.value('./@cust', 'INT') AS custid
				,T.C.value('./@cur','TINYINT')  AS currency
				,T.C.value('./@rc' , 'INT') AS recommend
				,T.C.value('./@mrc', 'INT')  AS mrecommend
				,T.C.value('./@src', 'INT')  AS srecommend
				,T.C.value('./@wld', 'SMALLDATETIME') AS Winlostdate
				,T.C.value('./@stake', 'MONEY') AS stake
				,T.C.value('./@w', 'MONEY') AS WinLost
				,T.C.value('./@aw', 'MONEY') AS aWinLost
				,T.C.value('./@mw', 'MONEY') AS mWinLost
				,T.C.value('./@sw', 'MONEY') AS sWinLost
				,T.C.value('./@astake', 'MONEY') AS actual_stake
				,T.C.value('./@pc', 'MONEY') AS PlayerComm
				,T.C.value('./@c', 'MONEY') AS Comm 
				,T.C.value('./@ac', 'MONEY') AS aComm
				,T.C.value('./@sc', 'MONEY') AS sComm
				,T.C.value('./@ar', 'FLOAT')   AS actualrate
				,T.C.value('./@uname', 'NVARCHAR(100)') AS Username
				,T.C.value('./@curname', 'NVARCHAR(100)') AS CurrencyName
				,T.C.value('./@ct','DATETIME') AS checktime
				,T.C.value('./@ref', 'BIGINT') AS refno
			FROM	@transInfo.nodes('/root/r') AS T(C)	
			OPTION (OPTIMIZE FOR (@transInfo = NULL ))

			INSERT INTO dbo.Transfer (statusID, bettype, creator, transdate,
							custid, currency, recommend, mrecommend, srecommend,
							winlostdate, stake, winlost, awinlost, mwinlost, swinlost,
							actual_stake, playercomm, comm, acomm, scomm, 
							actualrate, Username, CurrencyName, checktime, refno
						)
			SELECT statusID, bettype, creator, transdate,
							custid, currency, recommend, mrecommend, srecommend,
							winlostdate, stake, winlost, awinlost, mwinlost, swinlost,
							actual_stake, playercomm, comm, acomm, scomm, 
							actualrate, Username, CurrencyName, checktime, refno 
			FROM @tmpTransId
		END
	END
	ELSE IF @TableName = 'TicketVoiding_RoutineTasks'
	BEGIN
		IF @Action = 'I'
		BEGIN
			INSERT INTO @tmpTransId (RequestId, StepNo, [Action], StatusID, CreatedDate, AffectedList, ExecuteType)
			SELECT T.C.value('./@req', 'INT') AS RequestId
				,T.C.value('./@stn', 'TINYINT') AS StepNo 
				,T.C.value('./@act', 'VARCHAR(100)') AS [Action] 
				,T.C.value('./@sid', 'TINYINT') AS StatusID
				,T.C.value('./@crdate', 'DATETIME') AS createddate
				,T.C.value('./@affs', 'VARCHAR(MAX)') AS AffectedList
				,T.C.value('./@exect', 'TINYINT') AS ExecuteType 
			FROM	@transInfo.nodes('/root/r') AS T(C)	
			OPTION (OPTIMIZE FOR (@transInfo = NULL ))

			SET @RequestID = ISNULL((SELECT MAX(RequestID) 
							FROM dbo.TicketVoiding_RoutineTasks WITH (NOLOCK)) + 1, 1)

			INSERT INTO dbo.TicketVoiding_RoutineTasks (RequestID, StepNo, [Action], [Status], CreatedDate, AffectedList, ExecuteType)
			SELECT @RequestID, StepNo, [Action], StatusID, CreatedDate, AffectedList, ExecuteType
			FROM @tmpTransId
		END
	END
END
GO