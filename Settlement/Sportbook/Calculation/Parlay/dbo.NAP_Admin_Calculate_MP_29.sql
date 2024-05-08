/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_29]
	@matchdate				SMALLDATETIME
	,@strXML				VARCHAR(MAX)
	,@BroadcastSessionId VARCHAR(50) = ''
	,@ServerAlias 			VARCHAR(50) = ''
	,@MatchId				INT 		= 0
	,@ActionId 				INT 		= 0
	,@IsCalculateBalance 	BIT 		= 0
	,@SessionId				BIGINT 		= NULL
	,@IsParallel 			BIT 		= 0
	,@ParlaySettlementProcessingId BIGINT = NULL
	,@ServerName SYSNAME = ''
	,@AffectedTicket 		INT 		= 0 OUTPUT
	,@AffectedTransIds		VARCHAR(MAX) = NULL OUTPUT
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
		- 20221011@Kathy: Using Json [Redmine:#178694]
		- 20230816@Kathy: parlay boost [Redmine:#191873]
		- 20231214@Aries: Result Amendment [Redmine: #196401]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
		- 20240425@Kathy: enhance MaxPayout [Redmine:#199518]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @minRefno			BIGINT				
			,@xml				XML
			,@statusId			TINYINT
			,@winlost			MONEY
			,@settlementTime	DATETIME
			,@transInfoJson		NVARCHAR(MAX)
			,@IsSiteDB			BIT = 0
			,@CurrentBonusAmount MONEY
		
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1
			
	DECLARE @tmpSource TABLE (TransId BIGINT PRIMARY KEY, WinlostDate SMALLDATETIME
		, totalStake MONEY, Winlost MONEY, aWinlost MONEY, mWinlost MONEY, sWinlost MONEY
		, playerComm MONEY, comm MONEY, aComm MONEY, sComm MONEY
		, ruben TINYINT, IsMarked BIT
		, BonusAmount MONEY DEFAULT(0), xmlExtraInfo XML
	)
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT, custid INT, balancechanged MONEY			
		,SettlementTime DATETIME,Status NVARCHAR(10),StatusID TINYINT
		,WinLostDate SMALLDATETIME, betdaqid BIGINT,ruben TINYINT 
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,statuswinlost TINYINT
		,ExtraInfo VARCHAR(1000)
		,bef_winlost MONEY
		,bef_statusid TINYINT
		,bef_ruben TINYINT
		,bettype SMALLINT,refno BIGINT
	)

	DECLARE @tmpRefno TABLE (refno BIGINT  PRIMARY KEY, transid BIGINT, IsMarked BIT DEFAULT(0))

	SET @ServerName = CASE WHEN ISNULL(@ServerName,'') = '' THEN @@SERVERNAME ELSE @ServerName END
	
	IF @ServerName <> @@SERVERNAME
        RETURN
		
	INSERT INTO @tmpRefno (refno, transid)
	SELECT SUBSTRING(value,0,CHARINDEX('|', value)) as refno ,SUBSTRING(value,CHARINDEX('|', value) + 1, len(value)) as transid
	FROM STRING_SPLIT(@strxml,',')
	
	SELECT @minRefno = MIN(refno)
	FROM @tmpRefno
	
	UPDATE	r
		SET IsMarked = 1
	FROM	@tmpRefno r
		INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
			ON r.transid = mt.TransId
	WHERE	mt.MatchId = 29

	SET @settlementTime = GETDATE();

	INSERT INTO @tmpSource (TransId, WinlostDate, totalStake
		,Winlost, aWinlost, mWinlost, sWinlost
		,playerComm, comm, aComm, sComm
		,ruben, IsMarked, BonusAmount)
	SELECT b.transid, MAX(pr.winlostdate), SUM(pr.stake)
		,SUM(pr.winlost), SUM(pr.awinlost), SUM(pr.mwinlost),  SUM(pr.swinlost) 
		,SUM(pr.playercomm), SUM(pr.comm), SUM(pr.acomm), SUM(pr.scomm) 			
		,CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
		,b.IsMarked
		,ISNULL(MAX(pr.stake * (pr.mOdds - 1)/(1 + pr.ExtraValue) * pr.ExtraValue),0)
	FROM @tmpRefno b 
		INNER JOIN dbo.BetParlayResult pr WITH(NOLOCK)
			ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid, b.IsMarked

	UPDATE	s
		SET xmlExtraInfo = b2.xmlExtraInfo								
	FROM	@tmpSource s
		CROSS APPLY (SELECT b1.xmlExtraInfo
							,ISNULL(b1.xmlExtraInfo.value('(/p1/@bba)[1]', 'MONEY'),0) AS currentBonusAmount
					 FROM ( SELECT	CAST(ISNULL(b.ExtraInfo,'') AS XML) AS xmlExtraInfo
							FROM	dbo.bettrans b WITH(NOLOCK)
							WHERE	b.TransId = s.TransId
									AND	b.oddsspread = 2
						) b1
			)b2
	WHERE	b2.currentBonusAmount <> s.BonusAmount
			AND s.IsMarked = 0

	IF @@ROWCOUNT > 0 -- has boost
	BEGIN
		UPDATE s
			SET xmlExtraInfo.modify('replace value of (/p1/@bba)[1] with sql:column("BonusAmount")')
		FROM	@tmpSource s
		WHERE	xmlExtraInfo.exist('/p1/@bba') = 1 

		UPDATE s 
			SET xmlExtraInfo.modify('insert(attribute bba {sql:column("BonusAmount")}) into (/p1)[1]')
		FROM	@tmpSource s
		WHERE	BonusAmount > 0
				AND xmlExtraInfo.exist('/p1/@bba') = 0 		
	END
	
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
		,ExtraInfo = CASE WHEN s.xmlExtraInfo IS NOT NULL AND CAST(s.xmlExtraInfo AS VARCHAR(1000)) <> b.ExtraInfo THEN CAST(s.xmlExtraInfo AS VARCHAR(1000))  ELSE b.ExtraInfo END
	OUTPUT inserted.transid, inserted.custid
		 ,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
		,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END

		,inserted.Status,inserted.StatusID,inserted.winlostdate,inserted.betdaqid,inserted.ruben
		,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
		,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
		,Inserted.Statuswinlost
		,inserted.ExtraInfo

		,deleted.winlost
		,deleted.statusid
		,deleted.ruben
		,deleted.bettype,deleted.refno
	INTO @tmpTransInfo (transId, custid
		,balancechanged
		,SettlementTime
		,Status, StatusID, WinLostDate, betdaqid, ruben
		,WinLost,aWinLost,mWinLost,sWinLost
		,PlayerComm,Comm,aComm,sComm
		,statuswinlost
		,ExtraInfo

		,bef_winlost
		,bef_statusid
		,bef_ruben
		,bettype,refno
	)
	FROM @tmpSource s
		INNER JOIN dbo.bettrans b
			ON b.transid = s.transid
	
	SELECT @AffectedTicket = COUNT(1)
	FROM 	@tmpTransInfo
	
	IF @IsCalculateBalance = 1 AND (@IsSiteDB = 1 OR @ServerAlias = 'DBTXN')
	BEGIN
		INSERT INTO dbo.BalCreditSportsPending(custid, balance)
		SELECT	custid, SUM(balancechanged)
		FROM	@tmpTransInfo
		GROUP BY custid
		HAVING SUM(balancechanged) > 0

		INSERT INTO dbo.BalDebitSportsPending(custid, balance)
		SELECT	custid, ABS(SUM(balancechanged))
		FROM	@tmpTransInfo
		GROUP BY custid
		HAVING SUM(balancechanged) < 0

		IF OBJECT_ID('BalanceNegative','U') IS NOT NULL
		BEGIN
			INSERT INTO [dbo].[BalanceNegative] ([ExecDate], [MatchID], [ActionID], [GroupID], [CustID], [Balance], [StatusID], [Remark])
			SELECT GETDATE()
				,@MatchID
				,@ActionId
				,2 -- Sportsbook Parlay Settlement
				,CustID
				,SUM(balancechanged)
				,0
				,@matchid
			FROM	@tmpTransInfo
			GROUP BY custid
			HAVING SUM(balancechanged) < 0
		END

		SELECT @AffectedTransIds = (SELECT	transId AS '@transid'
											,custid AS '@custid'
											,ruben AS '@ruben'
									FROM	@tmpTransInfo
									WHERE	ruben <> bef_ruben
									FOR XML PATH('r'), ROOT('root')
							)
	END

	IF @IsSiteDB = 1 --AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)	
	BEGIN
		IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			INSERT INTO @tmpTransInfo (settlementTime) VALUES (GETDATE())
		END
		
		SET @transInfoJson = (
			SELECT	transId AS 't'			
					,SettlementTime AS 'st' 
					,Status AS 's' 
					,StatusID AS 'sid'
					,WinLostDate AS 'wld'
					,betdaqid AS 'bdaq'
					,ruben AS 'r'
					,WinLost AS 'w' 
					,aWinLost AS 'aw' 
					,mWinLost AS 'mw' 
					,sWinLost AS 'sw' 
					,PlayerComm AS 'pc' 
					,Comm AS 'c' 
					,aComm AS 'ac' 
					,sComm AS 'sc' 
					,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl' 
					,ExtraInfo AS 'ex'
					,bef_winlost AS 'bef_w' 
					,bef_statusid AS 'bef_sid' 

					,bettype AS 'bt' 
					,refno AS 'rf' 
			FROM	@tmpTransInfo
			FOR JSON AUTO
		)
	
		IF @transinfoJson IS NOT NULL
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateMainParlay'
				,@TableName = 'bettrans'
				,@MatchId = 29
				,@TransInfoJson = @transinfoJson
				,@SettlementAction = 'CAL'
				,@TicketType = 'p'
				,@BroadcastSessionId = @BroadcastSessionId
				,@SessionId     = @SessionId
                ,@IsParallel    = @IsParallel
				,@ParlaySettlementProcessingId = @ParlaySettlementProcessingId
		
		
	END
END


GO
