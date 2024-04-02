/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_Bet14_29]
	@strXML	VARCHAR(MAX)
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		
	Param's Explanation:  
		
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT)
	DECLARE @minRefno BIGINT	
			
	DECLARE @xml XML
			,@statusId TINYINT
			,@winlost MONEY
			,@winlostdate SMALLDATETIME
			,@currentDate SMALLDATETIME
			,@IsSiteDB			BIT = 0
			,@transInfoJson		NVARCHAR(MAX)

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1
			
	SET @currentDate =  CONVERT(VARCHAR(10),GETDATE(),102)

	DECLARE @tmpTransInfo TABLE (transId BIGINT			
		,SettlementTime DATETIME,Status NVARCHAR(10),StatusID TINYINT
		,WinLostDate SMALLDATETIME, betdaqid BIGINT,ruben TINYINT 
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,statuswinlost TINYINT
		,ExtraInfo VARCHAR(1000)
		,bef_winlost MONEY
		,bef_statusid TINYINT
	)
	
	SET @xml = CONVERT(XML, N'<root><r rn="' + REPLACE(REPLACE(@strXML, '|', '" t="'), ',', '"/><r rn="') + '"/></root>')
	
	INSERT INTO #Refno (refno, transid)
	SELECT T.C.value('./@rn', 'bigint')
			,T.C.value('./@t', 'bigint')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	SELECT @minRefno = MIN(refno)
	FROM #Refno
	
	DECLARE @settlementTime DATETIME
	SET @settlementTime = GETDATE();
	
	CREATE TABLE #temp_source (transid BIGINT,winlostdate SMALLDATETIME,totalStake MONEY, winlost MONEY,awinlost MONEY,mwinlost MONEY,swinlost MONEY
								,playercomm MONEY,comm MONEY,acomm MONEY,scomm MONEY,ruben TINYINT, BonusAmount MONEY DEFAULT(0), xmlExtraInfo XML)
	
	INSERT INTO #temp_source (transid,winlostdate, totalStake, winlost, awinlost,mwinlost,swinlost,playercomm, comm, acomm, scomm, ruben, BonusAmount)
	SELECT transid = b.transid
		,winlostdate = MAX(pr.winlostdate)
		,totalStake = SUM(pr.stake)
		,winlost = SUM(pr.winlost) 
		,awinlost = SUM(pr.awinlost) 
		,mwinlost = SUM(pr.mwinlost) 
		,swinlost = SUM(pr.swinlost) 
		,playercomm = SUM(pr.playercomm) 
		,comm = SUM(pr.comm) 
		,acomm = SUM(pr.acomm) 
		,scomm = SUM(pr.scomm) 			
		,ruben = CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
		,ISNULL(MAX(pr.stake * (pr.mOdds - 1)/(1 + pr.ExtraValue) * pr.ExtraValue),0)
	FROM #Refno b 
		INNER JOIN dbo.BetParlayResult pr WITH(NOLOCK) ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid

	UPDATE	s
		SET xmlExtraInfo = b2.xmlExtraInfo								
	FROM	#temp_source s
		CROSS APPLY (SELECT b1.xmlExtraInfo
							,ISNULL(b1.xmlExtraInfo.value('(/p1/@bba)[1]', 'MONEY'),0) AS currentBonusAmount
					 FROM ( SELECT	CAST(ISNULL(b.ExtraInfo,'') AS XML) AS xmlExtraInfo
							FROM	dbo.bettrans14 b WITH(NOLOCK)
							WHERE	b.TransId = s.TransId
									AND	b.oddsspread = 2
						) b1
			)b2
	WHERE	b2.currentBonusAmount <> s.BonusAmount

	IF @@ROWCOUNT > 0 -- has boost
	BEGIN
		UPDATE s
			SET xmlExtraInfo.modify('replace value of (/p1/@bba)[1] with sql:column("BonusAmount")')
		FROM	#temp_source s
		WHERE	xmlExtraInfo.exist('/p1/@bba') = 1 

		UPDATE s 
			SET xmlExtraInfo.modify('insert(attribute bba {sql:column("BonusAmount")}) into (/p1)[1]')
		FROM	#temp_source s
		WHERE	BonusAmount > 0
				AND xmlExtraInfo.exist('/p1/@bba') = 0 		
	END


	UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET @statusId = CASE 
						WHEN s.ruben = 0 THEN 0
						WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
																WHEN s.winlost = b.actual_stake THEN 111
																WHEN s.winlost > b.actual_stake THEN 112
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
		,SettlementTime = CASE WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime ELSE SettlementTime END
		,statusID = @statusId
		,[status] = CASE 
						WHEN @statusId = 0 THEN 'running' 
						WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
						WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
						WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
						ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
					END
		--,actual_stake = s.totalStake 
		,betdaqid = s.totalStake							
		,ruben = s.ruben
		,winlost =   @winlost
		,awinlost = s.awinlost * s.ruben
		,mwinlost = s.mwinlost * s.ruben
		,swinlost = s.swinlost * s.ruben
		,playercomm = s.playercomm * s.ruben
		,comm = s.comm * s.ruben
		,acomm = s.acomm * s.ruben
		,scomm = s.scomm * s.ruben
		,statuswinlost = CASE 
							WHEN @statusId = 112 THEN 2							
							WHEN @statusId = 111 THEN 0 							
							WHEN @statusId = 113 THEN 4								
							WHEN @statusId = 0 THEN NULL
						END 
		,ExtraInfo = CASE WHEN s.xmlExtraInfo IS NOT NULL AND CAST(s.xmlExtraInfo AS VARCHAR(1000)) <> b.ExtraInfo THEN CAST(s.xmlExtraInfo AS VARCHAR(1000))  ELSE b.ExtraInfo END

		OUTPUT inserted.transid
			,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END

			,inserted.Status,inserted.StatusID,inserted.winlostdate,inserted.betdaqid,inserted.ruben
			,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
			,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
			,Inserted.Statuswinlost
			,inserted.ExtraInfo
			,deleted.winlost
			,deleted.statusid	
		INTO @tmpTransInfo (transId
			,SettlementTime
			,Status, StatusID, WinLostDate, betdaqid, ruben
			,WinLost,aWinLost,mWinLost,sWinLost
			,PlayerComm,Comm,aComm,sComm
			,statuswinlost
			,ExtraInfo
			,bef_winlost
			,bef_statusid
		)

	FROM dbo.bettrans14 b
		INNER JOIN #temp_source s ON b.transid = s.transid

	IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)	
	BEGIN
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
					,bef_winlost AS 'bef_w' 
					,bef_statusid AS 'bef_sid' 
					,ExtraInfo AS 'ex'
			FROM	@tmpTransInfo
			FOR JSON AUTO
		)

		IF @transinfoJson IS NOT NULL
			EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns 
				@SystemName = 'Settlement' 
				,@FunctionName = 'CalculateMainParlay'
				,@TableName = 'bettrans14'
				,@MatchId = 29
				,@TransInfoJson = @transinfoJson
				,@SettlementAction = 'CAL'
				,@TicketType = 'p'
		
	END

	
	DROP TABLE #temp_source
	DROP TABLE #Refno
					
END
GO
