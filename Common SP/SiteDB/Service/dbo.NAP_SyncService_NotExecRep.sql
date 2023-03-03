/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SyncService_NotExecRep] 	
	@TransInfoJson VARBINARY(MAX)
	,@TableName VARCHAR(128)
	,@Action	VARCHAR(1)	= 'I'
AS
/*
	Created by: 20220728@Kathy
	Task: Settlement  

	Revisions:
		- 20220920@Max: Scale Out BetTrans [Redmine:#175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		
	Param's Explanation:  
		   
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @RequestID INT
		,@Decompress_TransInfoJson NVARCHAR(MAX)

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
			SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

			INSERT INTO @tmpTransId (statusID, bettype, creator, transdate,
							custid, currency, recommend, mrecommend, srecommend,
							winlostdate, stake, winlost, awinlost, mwinlost, swinlost,
							actual_stake, playercomm, comm, acomm, scomm, 
							actualrate, Username, CurrencyName, checktime, refno
						)
			SELECT * 
			FROM OPENJSON(@Decompress_TransInfoJson)
			WITH (
					sid TINYINT
					,btype SMALLINT 
					,cr INT 
					,td DATETIME 
					,cust INT 
					,cur TINYINT 
					,rc INT 
					,mrc INT 
					,src INT 
					,wld SMALLDATETIME 
					,stake MONEY 
					,w MONEY 
					,aw MONEY 
					,mw MONEY 
					,sw MONEY 
					,astake MONEY 
					,pc MONEY 
					,c MONEY 
					,ac MONEY 
					,sc MONEY 
					,ar FLOAT 
					,uname NVARCHAR(100) 
					,curname NVARCHAR(100) 
					,ct DATETIME 
					,ref BIGINT 
				)

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
			SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

			INSERT INTO @tmpTransId (RequestId, StepNo, [Action], StatusID, CreatedDate, AffectedList, ExecuteType)
			SELECT *
			FROM OPENJSON(@Decompress_TransInfoJson)
			WITH (
					req INT 
					,stn TINYINT 
					,act VARCHAR(100) 
					,sid TINYINT 
					,crdate DATETIME 
					,affs VARCHAR(MAX) 
					,exect TINYINT 
				)

			SET @RequestID = ISNULL((SELECT MAX(RequestID) 
							FROM dbo.TicketVoiding_RoutineTasks WITH (NOLOCK)) + 1, 1)

			INSERT INTO dbo.TicketVoiding_RoutineTasks (RequestID, StepNo, [Action], [Status], CreatedDate, AffectedList, ExecuteType)
			SELECT @RequestID, StepNo, [Action], StatusID, CreatedDate, AffectedList, ExecuteType
			FROM @tmpTransId
		END
	END
END
GO