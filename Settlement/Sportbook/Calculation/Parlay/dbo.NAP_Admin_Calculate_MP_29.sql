/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_29]
	@matchdate	SMALLDATETIME
	,@strXML	VARCHAR(MAX)
AS
/*
	Created: Kathy
	Date: 20160419
	Task : Settle bettrans (for system parlay)
	DB: DBTXN.bodb02
	
	Original: 

	Revisions:
		- 20160728@Kathy: Using non clustered index PK_bettrans to settle [Redmine:#61193]
		- 20161114@Kathy: Wrongly update winlostdate of parlay running ticket [Redmine#67084]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20220531@Kathy: performance tunning [Redmine:#173456]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @minRefno			BIGINT				
			,@xml				XML
			,@statusId			TINYINT
			,@winlost			MONEY
			,@settlementTime	DATETIME
			,@transInfo			XML
			
	DECLARE @tmpSource TABLE (TransId BIGINT PRIMARY KEY, WinlostDate SMALLDATETIME
		, totalStake MONEY, Winlost MONEY, aWinlost MONEY, mWinlost MONEY, sWinlost MONEY
		, playerComm MONEY, comm MONEY, aComm MONEY, sComm MONEY
		, ruben TINYINT, IsMarked BIT)
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT			
		,SettlementTime DATETIME,Status NVARCHAR(10),StatusID TINYINT
		,WinLostDate SMALLDATETIME, betdaqid BIGINT,ruben TINYINT 
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,statuswinlost TINYINT

		,bef_winlost MONEY
		,bef_statusid TINYINT
	)

	CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT, IsMarked BIT DEFAULT(0))
	
	SET @xml = CONVERT(XML, N'<root><r rn="' + REPLACE(REPLACE(@strXML, '|', '" t="'), ',', '"/><r rn="') + '"/></root>')
	
	INSERT INTO #Refno (refno, transid)
	SELECT T.C.value('./@rn', 'bigint')
			,T.C.value('./@t', 'bigint')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	SELECT @minRefno = MIN(refno)
	FROM #Refno
	
	UPDATE	r
		SET IsMarked = 1
	FROM	#Refno r
		INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
			ON r.transid = mt.TransId
	WHERE	mt.MatchId = 29

	SET @settlementTime = GETDATE();

	INSERT INTO @tmpSource (TransId, WinlostDate, totalStake
		,Winlost, aWinlost, mWinlost, sWinlost
		,playerComm, comm, aComm, sComm
		,ruben, IsMarked
	)
	SELECT b.transid, MAX(pr.winlostdate), SUM(pr.stake)
		,SUM(pr.winlost), SUM(pr.awinlost), SUM(pr.mwinlost),  SUM(pr.swinlost) 
		,SUM(pr.playercomm), SUM(pr.comm), SUM(pr.acomm), SUM(pr.scomm) 			
		,CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
		,b.IsMarked
	FROM #Refno b 
		INNER JOIN dbo.BetParlayResult pr WITH(NOLOCK)
			ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid, b.IsMarked
	
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusId = CASE
					WHEN s.ruben = 0 THEN 0
					WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
															WHEN s.winlost = b.actual_Stake THEN 111
															WHEN s.winlost > b.actual_Stake THEN 112
															WHEN s.winlost < b.actual_stake THEN 113 
															END
					ELSE	CASE				
							WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
							WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
							WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
							ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
							END
					END
		,@winlost = s.winlost * s.ruben
		,SettlementTime = CASE 
							WHEN s.IsMarked = 1 THEN b.SettlementTime
							WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime 
							ELSE SettlementTime 
						END
		,statusID = CASE WHEN s.IsMarked = 1 THEN b.statusID ELSE @statusId END
		,[status] = CASE 
						WHEN s.IsMarked = 1 THEN b.status 
						WHEN @statusId = 0 THEN 'running' 
						WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
						WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
						WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
						ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
					END
		,winlostdate = CASE 
							WHEN s.IsMarked = 1 THEN b.winlostdate
							WHEN @statusId <> b.statusID THEN s.winlostdate 
							ELSE b.winlostdate 
						END
		--,modds = s.modds
		---,actual_stake = s.totalStake
		,betdaqid = CASE WHEN s.IsMarked = 1 THEN b.betdaqid ELSE s.totalStake END						
		,ruben = CASE WHEN s.IsMarked = 1 THEN b.ruben ELSE s.ruben END
		,winlost =  CASE WHEN s.IsMarked = 1 THEN b.winlost ELSE @winlost END
		,awinlost = CASE WHEN s.IsMarked = 1 THEN b.awinlost ELSE s.awinlost * s.ruben END
		,mwinlost = CASE WHEN s.IsMarked = 1 THEN b.mwinlost ELSE s.mwinlost * s.ruben END
		,swinlost = CASE WHEN s.IsMarked = 1 THEN b.swinlost ELSE s.swinlost * s.ruben END
		,playercomm = CASE WHEN s.IsMarked = 1 THEN b.playercomm ELSE s.playercomm * s.ruben END
		,comm = CASE WHEN s.IsMarked = 1 THEN b.comm ELSE s.comm * s.ruben END
		,acomm = CASE WHEN s.IsMarked = 1 THEN b.acomm ELSE s.acomm * s.ruben END
		,scomm = CASE WHEN s.IsMarked = 1 THEN b.scomm ELSE s.scomm * s.ruben END
		,statuswinlost = CASE 
							WHEN @statusId = 112 THEN 2							
							WHEN @statusId = 111 THEN 0 							
							WHEN @statusId = 113 THEN 4								
							WHEN @statusId = 0 THEN NULL
						END 
	OUTPUT inserted.transid
		,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END

		,inserted.Status,inserted.StatusID,inserted.winlostdate,inserted.betdaqid,inserted.ruben
		,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
		,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
		,inserted.statuswinlost
		
		,deleted.winlost
		,deleted.statusid	
	INTO @tmpTransInfo (transId
		,SettlementTime
		,Status, StatusID, WinLostDate, betdaqid, ruben
		,WinLost,aWinLost,mWinLost,sWinLost
		,PlayerComm,Comm,aComm,sComm
		,statuswinlost

		,bef_winlost
		,bef_statusid
	)
	FROM @tmpSource s
		INNER JOIN dbo.bettrans b
			ON b.transid = s.transid

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	BEGIN
		SET @transInfo = (
			SELECT	transId AS '@t'			
					,SettlementTime AS '@st' 
					,Status AS '@s' 
					,StatusID AS '@sid'
					,WinLostDate AS '@wld'
					,betdaqid AS '@bdaq'
					,ruben AS '@r'
					,WinLost AS '@w' 
					,aWinLost AS '@aw' 
					,mWinLost AS '@mw' 
					,sWinLost AS '@sw' 
					,PlayerComm AS '@pc' 
					,Comm AS '@c' 
					,aComm AS '@ac' 
					,sComm AS '@sc' 
					,statuswinlost AS '@statuswl' 
					,bef_winlost AS '@bef_w' 
					,bef_statusid AS '@bef_sid' 
			FROM	@tmpTransInfo
			FOR XML PATH('r'),ROOT('root'), TYPE
		)

		INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
		VALUES ('Settlement', 'CalculateMainParlay', 'bettrans', 29, @transInfo)		
			
	END
END


GO
