/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ReCalculate_Single_Update]
(
	@TransIds					VARCHAR(MAX)
	,@CalledByBrokerService     BIT         = 0
	,@RunOnServer				VARCHAR(100) = NULL
	,@Mode						VARCHAR(50) = ''
	,@NegativeBalanceUsers		VARCHAR(MAX) = '' OUTPUT
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]
		- 20200924@Louisa: Implement for Myanmar odds - bettype 1,3,7,8 [Redmine:#142220]
		- 20201023@Louisa: Change commission formula of MMR odds [Redmine:#144046]
		- 20220110@Kathy: Apply service broker when calculate ticket [Redmine:#167251]
		- 20220808@Max: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20220922@Helen: fix issue [Redmine: #175412]
		- 20220926@Max: Enhance code logic [Redmine: #175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20250220@Max: [TVS] Recover ticket of Virtual Sports 2 [Redmine: #212323]
		
	Param's explanation:	
		
*/
BEGIN
    SET NOCOUNT ON

    -----------------------CHECK SERVER-----------------------------------------
    DECLARE @ServerName             SYSNAME 
            ,@AllowCalculation      BIT
            ,@xml                   XML
            ,@IsEnableServiceBroker BIT -- server is using service broker or not
            ,@sMessage              NVARCHAR(MAX)
            ,@transInfo             VARBINARY(MAX)
            ,@IsSiteDB              BIT
            ,@matchId               INT

    SET @ServerName = @@SERVERNAME

    IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
    BEGIN
        EXEC [dbo].[NAP_Set_ServerAction]
            @ServerName         = @ServerName
            ,@AllowCalculation  = @AllowCalculation OUTPUT

        IF @AllowCalculation = 0
            RETURN

    END
    DECLARE @tmpTransInfo TABLE (transId BIGINT, matchId INT
        ,statuswinlost TINYINT
        ,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
        ,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
        ,Status NVARCHAR(10),StatusID TINYINT, ruben TINYINT
        ,SettlementTime DATETIME, FcUpdateTime DATETIME2
		,creator INT, ExtraInfo VARCHAR(MAX)
    )

    IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
    BEGIN
        SET @IsSiteDB = 1
    END
    -----------------------CHECK SERVER-----------------------------------------

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
        SET @sMessage = 'EXEC dbo.TicketVoiding_ReCalculate_Single_Update 
                @TransIds = ''' + @TransIds + ''''
                + ',@CalledByBrokerService = 1'
                + CASE WHEN @RunOnServer IS NULL THEN '' ELSE ',@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END

        EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
            ,@toService = N'//Service/Calculation_receive'
            ,@onContract = N'//Contract/Calculation'
            ,@messageType = N'//Message/Calculation'
            ,@messageBody = @sMessage

        RETURN
    END

	IF @Mode = ''
	BEGIN
		SET @xml = CONVERT(XML, @TransIds)
		DECLARE @tbl_transIDs AS TABLE(transid BIGINT, sporttype SMALLINT, creator INT)
    
		INSERT INTO @tbl_transIDs (transid, sporttype, creator )
		SELECT  T.C.value('./@transid', 'bigint')
			, T.C.value('./@sporttype', 'smallint')
			, T.C.value('./@creator', 'int')
		FROM    @xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
    
		DECLARE @tempTrans TABLE (TransID BIGINT, isDecimalOdd BIT, srecommend INT, bettype SMALLINT, isCN88 BIT, isMajorGroup BIT, sporttype SMALLINT, creator INT)
		DECLARE  @commWinRate       SMALLMONEY
				,@commLostRate      SMALLMONEY
				,@commHalfWLRate    SMALLMONEY
				,@odds              SMALLMONEY
				,@winlost           MONEY
				,@stake             MONEY
				,@statusId          TINYINT
            
            
		DECLARE @settlementTime DATETIME
		---parse XML
		INSERT INTO @tempTrans(TransID, isDecimalOdd, srecommend, bettype, sporttype, creator)
		SELECT t.TransID, CASE WHEN (ot.oddstype = 1 OR b.bettype = 38) THEN 1 ELSE 0 END AS isDecimalOdd, srecommend, b.bettype, t.sporttype, t.creator
		FROM @tbl_transIDs t
			INNER LOOP JOIN dbo.bettrans b  WITH (NOLOCK) ON b.transid = t.transid
			LEFT JOIN dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b.bettype
		WHERE b.statuswinlost IS NOT NULL
			AND b.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN b.SiteDBGroupID ELSE 0 END
         
		-- update if bettype belongs to the CN88 site or not
		UPDATE tmp
		  SET   isCN88 = CASE WHEN cs.CustId IS NULL THEN 0 ELSE 1 END,
				isMajorGroup = CASE WHEN f.CommBettypeGroupId IS NOT NULL AND f.CommBettypeGroupId = 1 THEN 1 ELSE 0 END
		FROM   @tempTrans tmp
				   LEFT JOIN dbo.CS_CustSuper cs WITH(NOLOCK)
					   ON tmp.srecommend = cs.CustId
					LEFT JOIN dbo.f_Set_GetGroupBettypes() AS f
						ON tmp.bettype = f.BetType
    
		SET @settlementTime = GETDATE();

		UPDATE  b
			SET 
			   @commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
									WHEN '0' THEN 1
									WHEN '1' THEN 0
									ELSE 1 END
			   ,@commLostRate = CASE comstatus
									WHEN '0' THEN 1
									WHEN '1' THEN 2
									ELSE 1 END
			   ,@commHalfWLRate = CASE WHEN sr.isCN88 = 1 AND sr.isMajorGroup = 1 THEN 1
									ELSE 0.5
								END
			   ,@odds = CASE WHEN b.bettype IN (468,469) THEN b.odds
								 ELSE (CASE WHEN b.odds < 0 THEN 1 
											WHEN sr.isDecimalOdd = 1 THEN b.odds - 1 ----/*DECIMAL ONLY*/
											ELSE b.odds 
										END)
						END
				----------------------------------------------------------------------------------------------------------------
				,@winlost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN actual_stake + stake * @odds
																	WHEN statuswinlost IN (0,6) THEN actual_stake 
																  END   
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN actual_stake + stake * odds * (oddsspread/100) -- oddsspread > 0: WON
																ELSE actual_stake + stake * @odds
																END
									WHEN statuswinlost = 1 THEN actual_stake + stake * @odds * 0.5
									WHEN statuswinlost IN (0,6) THEN actual_stake
									WHEN statuswinlost = 3 THEN actual_stake * 0.5
									WHEN statuswinlost = 4 THEN  CASE WHEN b.oddstype = 6  AND b.modds = 0 THEN actual_stake * (1 - ABS(oddsspread/100))
																 ELSE 0
																 END
								END
							END     
				-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
				,@stake = CASE WHEN sr.isCN88 = 1 AND sr.isMajorGroup = 1 THEN ABS(@winlost - actual_stake)
								ELSE stake 
						  END
				-- check winlost or status change to update SettlementTime
				,@statusId = CASE
								WHEN statuswinlost IN (1,2) THEN 112 --WON
								WHEN statuswinlost = 0 THEN 111 --DRAW
								WHEN statuswinlost IN (3,4) THEN 113 --LOSE
								WHEN statuswinlost = 6 THEN 103
							END
				,SettlementTime = @settlementTime
				,WinLost = @winlost
				,@matchId = b.matchid
				,aWinLost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN stake * @odds * -apositiontaking
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END   
								ELSE 
								CASE
									WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN stake * odds * (oddsspread/100) * -apositiontaking
																ELSE stake * @odds * -apositiontaking
																END
									WHEN statuswinlost = 1 THEN stake * @odds * -apositiontaking * 0.5
									WHEN statuswinlost IN (0,6) THEN 0
									WHEN statuswinlost = 3 THEN actual_stake * apositiontaking * 0.5
									WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN actual_stake * ABS(oddsspread/100) * apositiontaking
																ELSE actual_stake * apositiontaking
																END
								END
							END
                                
				,mWinLost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN stake * @odds * -mpositiontaking
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END   
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN  stake * odds * (oddsspread/100) * -mpositiontaking
																ELSE stake * @odds * -mpositiontaking
																END
									WHEN statuswinlost = 1 THEN stake * @odds * -mpositiontaking * 0.5
									WHEN statuswinlost IN (0,6) THEN 0
									WHEN statuswinlost = 3 THEN actual_stake * mpositiontaking * 0.5
									WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN actual_stake * ABS(oddsspread/100) * mpositiontaking
																ELSE actual_stake * mpositiontaking
																END
								END
							END
                        
				,sWinLost = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost IN (2,4) THEN stake * @odds * -spositiontaking
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END   
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN stake * odds * (oddsspread/100) * -spositiontaking
																ELSE stake * @odds * -spositiontaking
																END
									WHEN statuswinlost = 1 THEN stake * @odds * -spositiontaking * 0.5
									WHEN statuswinlost IN (0,6) THEN 0
									WHEN statuswinlost = 3 THEN actual_stake * spositiontaking * 0.5
									WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN actual_stake * ABS(oddsspread/100) * spositiontaking
																ELSE actual_stake * spositiontaking
																END
								END
							END

				,PlayerComm = CASE 
								WHEN b.bettype IN (468,469) THEN CASE 
																	WHEN statuswinlost = 2 THEN @commWinRate * playerdiscount * @stake
																	WHEN statuswinlost = 4 THEN @commLostRate * playerdiscount * @stake
																	WHEN statuswinlost IN (0,6) THEN 0 
																  END   
								ELSE
								CASE
									WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN @commWinRate * playerdiscount * stake * (oddsspread/100)
																ELSE @commWinRate * playerdiscount * @stake
																END
									WHEN statuswinlost = 1 THEN @commWinRate * playerdiscount * @stake * @commHalfWLRate
									WHEN statuswinlost IN (0,6) THEN 0
									WHEN statuswinlost = 3 THEN @commLostRate * playerdiscount * @stake * @commHalfWLRate
									WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN @commLostRate * playerdiscount * stake * ABS(oddsspread/100)
																ELSE @commLostRate * playerdiscount * @stake
																END
								END
							END
				,Comm = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost = 2 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
																WHEN statuswinlost = 4 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
																WHEN statuswinlost IN (0,6) THEN 0 
															  END   
							ELSE
							CASE
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN  @commWinRate * discount * stake * (oddsspread/100) * (1-apositiontaking)
															ELSE @commWinRate * discount * @stake * (1-apositiontaking)
															END
								WHEN statuswinlost = 1 THEN @commWinRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
								WHEN statuswinlost IN (0,6) THEN 0
								WHEN statuswinlost = 3 THEN @commLostRate * discount * @stake * (1-apositiontaking) * @commHalfWLRate
								WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN @commLostRate * discount * stake * ABS(oddsspread/100) * (1-apositiontaking)
															ELSE @commLostRate * discount * @stake * (1-apositiontaking)
															END
							END
						END 
				,aComm = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost = 2 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
																WHEN statuswinlost = 4 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
																WHEN statuswinlost IN (0,6) THEN 0 
															  END   
							ELSE 
							CASE
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN @commWinRate * adiscount * stake * (oddsspread/100) * (1-(mpositiontaking+apositiontaking))
															ELSE @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
															END
								WHEN statuswinlost = 1 THEN @commWinRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost IN (0,6) THEN 0
								WHEN statuswinlost = 3 THEN @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN @commLostRate * adiscount * stake * ABS(oddsspread/100) * (1-(mpositiontaking+apositiontaking))
															ELSE @commLostRate * adiscount * @stake * (1-(mpositiontaking+apositiontaking))
															END
							END
						END     
				,sComm = CASE 
							WHEN b.bettype IN (468,469) THEN CASE 
																WHEN statuswinlost = 2 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
																WHEN statuswinlost = 4 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
																WHEN statuswinlost IN (0,6) THEN 0 
															  END   
							ELSE 
							CASE
								WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN @commWinRate * sdiscount * stake * (oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
															ELSE @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
															END
								WHEN statuswinlost = 1 THEN @commWinRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost IN (0,6) THEN 0
								WHEN statuswinlost = 3 THEN @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * @commHalfWLRate
								WHEN statuswinlost = 4 THEN CASE WHEN b.oddstype =6 AND b.modds = 0 THEN @commLostRate * sdiscount * stake * ABS(oddsspread/100) * (1-(spositiontaking+mpositiontaking+apositiontaking))
															ELSE @commLostRate * sdiscount * @stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
															END
							END
						END 
				,Status = CASE
							WHEN @statusId = 112  THEN 'WON'
							WHEN @statusId = 111 THEN 'DRAW'
							WHEN @statusId = 113 THEN 'LOSE'
							WHEN @statusId = 103 THEN 'Refund'
						END
				,StatusID = @statusId
				,ruben= 1
				,FcUpdateTime = CASE WHEN @statusId = 103 THEN SYSDATETIME() ELSE b.FcUpdateTime END
				,creator = ISNULL(sr.creator, b.creator)
				,ExtraInfo = CASE WHEN sr.SportType IS NOT NULL THEN dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',b.ExtraInfo,sr.SportType, b.bettype) ELSE b.ExtraInfo END
			OUTPUT  inserted.transid
				,inserted.statuswinlost
				,@settlementTime
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID, inserted.ruben
				,inserted.FcUpdateTime
				,inserted.creator
				,inserted.ExtraInfo
			INTO @tmpTransInfo (
				transId
				,statuswinlost
				,SettlementTime
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID, ruben, FcUpdateTime
				,creator, ExtraInfo
			)
		FROM @tempTrans sr
			INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
		WHERE b.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN b.SiteDBGroupID ELSE 0 END

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @transInfo = COMPRESS((
				SELECT  transId AS 't' 
						,statuswinlost AS 'statuswl'                   
						,SettlementTime AS 'st'
						,WinLost AS 'w' 
						,aWinLost AS 'aw' 
						,mWinLost AS 'mw' 
						,sWinLost AS 'sw' 
						,PlayerComm AS 'pc' 
						,Comm AS 'c' 
						,aComm AS 'ac' 
						,sComm AS 'sc' 
						,Status AS 's' 
						,StatusID AS 'sid' 
						,ruben AS 'r' 
						,FcUpdateTime AS 'rut'
						,creator AS 'cr'
						,ExtraInfo AS 'ex'
				FROM    @tmpTransInfo
				FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfoJson, TicketType)
			VALUES ('TVS', 'Re-cal', 'bettrans', @matchId, @transInfo, 's')  
        
		END
	END
	ELSE IF @Mode = 'RECOVER-VS2'
	BEGIN
		DECLARE @StartTime DATETIME
			,@FcUpdateTime DATETIME
			,@EndTime DATETIME
			,@transInfoJson VARBINARY(MAX)
			,@IsCentral		BIT
			,@CustIds VARCHAR(MAX)
			,@status VARCHAR(50) = NULL
			
		DECLARE @BeforeUpd		TVP_BalanceWalletChange
			,@AfterUpd			TVP_BalanceWalletChange
		
		EXEC dbo.NAP_Set_ServerInfo
			@IsCentral = @IsCentral OUTPUT	

		CREATE TABLE #tmpTrans  (
					transId				BIGINT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON)
				   ,odds				SMALLMONEY
				   ,modds				SMALLMONEY
				   ,statuswinlost		TINYINT
				   ,WinLost				MONEY
				   ,aWinLost			MONEY
				   ,mWinLost			MONEY
				   ,sWinLost			MONEY
				   ,PlayerComm			MONEY
				   ,Comm				MONEY
				   ,aComm				MONEY
				   ,sComm				MONEY
				   ,Status				NVARCHAR(20)
				   ,StatusID			TINYINT
				   ,ruben				TINYINT
				   ,ExtraInfo			VARCHAR(1000)
				   ,IsUpdateTime		BIT
				   ,creator				INT
		)

		CREATE TABLE #tmpTransOutput (  transId BIGINT PRIMARY KEY WITH (IGNORE_DUP_KEY = ON)
										,CustId INT, Balance MONEY
										,modds MONEY, odds SMALLMONEY, statuswinlost TINYINT,SettlementTime DATETIME
										,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
										,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
										,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT, before_ruben TINYINT, extrainfo VARCHAR(1000)
										,bef_winlost MONEY,bef_statusid TINYINT, bettype SMALLINT, winlostdate	SMALLDATETIME
										,actual_stake MONEY
										,betid BIGINT,refno BIGINT
										,FcUpdateTime DATETIME2
										,creator INT
										,bef_PlayerComm MONEY)
	
		INSERT INTO #tmpTrans(transId,odds,modds,statuswinlost,WinLost,aWinLost,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,ExtraInfo,IsUpdateTime,creator)
		SELECT   t.t		AS transId
				,t.o		AS odds
				,t.mo	    AS modds 	
				,t.sw	    AS statuswinlost 
				,t.wi	    AS WinLost 
				,t.awi	    AS aWinLost 
				,t.mwi	    AS mWinLost 
				,t.swi	    AS sWinLost 
				,t.pco	    AS PlayerComm 
				,t.co	    AS Comm 
				,t.aco	    AS aComm 
				,t.sco	    AS sComm
				,t.stn	    AS Status
				,t.sti	    AS StatusID
				,t.r	    AS ruben
				,t.e	    AS ExtraInfo
				,t.tm		AS IsUpdateTime
				,t.cr		AS creator
		FROM OPENJSON(@TransIds) WITH (
					t		BIGINT
				   ,o		SMALLMONEY
				   ,mo		SMALLMONEY
				   ,sw		TINYINT
				   ,wi		MONEY
				   ,awi		MONEY
				   ,mwi		MONEY
				   ,swi		MONEY
				   ,pco		MONEY
				   ,co		MONEY
				   ,aco		MONEY
				   ,sco		MONEY
				   ,stn		NVARCHAR(20)
				   ,sti		TINYINT
				   ,r		TINYINT
				   ,e		VARCHAR(1000)
				   ,tm		BIT
				   ,cr		INT
		) AS t

		SET @StartTime = SYSDATETIME()
		SET @settlementTime = GETDATE()
		SET @FcUpdateTime = SYSDATETIME()

		UPDATE  b
		SET  @status			= t.status
			,b.odds				= t.odds
			,b.modds			= CASE WHEN @status IN ('Refund', 'running') THEN b.modds ELSE t.modds END
			,b.statuswinlost	= t.statuswinlost
			,b.SettlementTime	= IIF(t.IsUpdateTime = 1, @SettlementTime, b.SettlementTime)
			,b.WinLost			= t.WinLost
			,b.aWinLost			= t.aWinLost				
			,b.mWinLost			= t.mWinLost		
			,b.sWinLost			= t.sWinLost
			,b.PlayerComm		= t.PlayerComm	
			,b.Comm				= t.Comm	
			,b.aComm			= t.aComm	
			,b.sComm			= t.sComm	
			,b.Status			= t.Status
			,b.StatusID			= t.StatusID
			,b.ruben			= t.ruben
			,b.ExtraInfo		= CASE WHEN @status IN ('Refund', 'running') THEN b.ExtraInfo ELSE t.ExtraInfo END
			,b.FcUpdateTime		= CASE WHEN @status = 'Refund' THEN @FcUpdateTime ELSE b.FcUpdateTime END
			,b.creator			= t.creator
			,@matchId			= b.matchid
		OUTPUT	 inserted.transid
				,deleted.custid, (inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
				,inserted.modds, inserted.odds, inserted.statuswinlost
				,CASE WHEN inserted.SettlementTime <> ISNULL(deleted.SettlementTime,'') THEN inserted.SettlementTime ELSE NULL END
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben, deleted.ruben, inserted.ExtraInfo
				,deleted.winlost,deleted.statusid	
				,deleted.bettype,deleted.betid,deleted.refno
				,deleted.winlostdate
				,deleted.actual_stake
				,CASE WHEN inserted.FcUpdateTime <> deleted.FcUpdateTime THEN inserted.FcUpdateTime ELSE NULL END
				,inserted.creator
				,deleted.playercomm
		INTO #tmpTransOutput (
				transId
				,custid, Balance
				,modds, odds, statuswinlost
				,SettlementTime
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,Status,StatusID,ruben, before_ruben, extrainfo
				,bef_winlost, bef_statusid	
				,bettype,betid,refno
				,winlostdate
				,actual_stake
				,FcUpdateTime
				,creator
				,bef_PlayerComm
			)
		FROM dbo.bettrans AS b WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #tmpTrans AS t ON  t.transid = b.transid

		SET @EndTime = SYSDATETIME()

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM #tmpTransOutput)
		BEGIN
			SET @transInfoJson = COMPRESS((
					SELECT	transId AS 't'
							,modds AS 'm'
							,odds AS 'o'				
							,statuswinlost AS 'statuswl' 
							,SettlementTime AS 'st' 
							,WinLost AS 'w' 
							,aWinLost AS 'aw' 
							,mWinLost AS 'mw' 
							,sWinLost AS 'sw' 
							,PlayerComm AS 'pc' 
							,Comm AS 'c' 
							,aComm AS 'ac' 
							,sComm AS 'sc' 
							,Status AS 's' 
							,StatusID AS 'sid' 
							,ruben AS 'r' 
							,extrainfo AS 'ex'
							,bef_winlost AS 'bef_w' 
							,bef_statusid AS 'bef_sid' 
							,bettype AS 'bt'
							,betid AS 'bi' 
							,refno AS 'rf' 
							,creator AS 'cr'
				
				FROM	#tmpTransOutput
				FOR JSON AUTO
			))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd(SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
			SELECT 'TVS', 'Recover-VS2', 'bettrans', 'U', @matchid, @transInfoJson, 's', 1
		END
		
		IF (@IsCentral = 1 OR @IsSiteDB = 1)
		BEGIN
			DECLARE @BalanceCWL  TABLE (custid INT, bef_winlost MONEY, after_winlost MONEY,winlostdate SMALLDATETIME, gametypeid SMALLINT)	

			INSERT INTO @BeforeUpd(
				matchid
				,custid
				,balanceType
				,walletType
				,bonusId
				,balance
			)
			SELECT	@matchId AS Matchid
				,t.custid
				,4 AS balanceType
				,2 AS WalletType -- sub tickets always bet from cash wallet
				,0 AS BonusID			
				,SUM(t.bef_winlost - t.actual_stake + t.bef_PlayerComm) AS balance
			FROM	#tmpTransOutput t
			GROUP BY custid

			INSERT INTO @AfterUpd(
				matchid
				,custid
				,balanceType
				,walletType
				,bonusId
				,balance
			)
			SELECT	@matchId AS Matchid
				,t.custid
				,4 AS balanceType
				,2 AS WalletType -- sub tickets always bet from cash wallet
				,0 AS BonusID
				,SUM(t.WinLost - t.actual_stake + t.PlayerComm) AS balance
			FROM	#tmpTransOutput t
			GROUP BY custid

			---INSERT data into pending balance table   
			EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				  @BalanceWalletBefore	= @BeforeUpd
				, @BalanceWalletAfter	= @AfterUpd
				, @ActionId				= 0

			-- get negative balance user list
			SET @CustIds = ''
			SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
			FROM	(
				SELECT DISTINCT b.custid
				FROM @BeforeUpd b
					INNER JOIN @AfterUpd a
						ON b.custid = a.custid
							AND b.matchid = a.matchid
							AND b.balanceType = a.balanceType
							AND b.bonusId = a.bonusId
							AND b.walletType = a.walletType
				WHERE	b.balance > a.balance
			)t

			EXEC dbo.NAP_CustNegativeBalance_Sel
				@CustIds = @CustIds
				,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

			--Insert Pending balance game change
			INSERT INTO @BalanceCWL (custid, bef_winlost, after_winlost, winlostdate, gametypeid)
			SELECT custid
				,SUM(IIF(before_ruben = 1,t.bef_winlost - actual_stake,0)) AS bef_winlost
				,SUM(IIF(t.ruben = 1,t.winlost - actual_stake,0)) AS after_winlost
				,winlostdate
				,bettype AS gametypeid
			FROM #tmpTransOutput t
			GROUP BY custid, winlostdate, bettype

			INSERT INTO dbo.BalancePendingCreditGame (custid,winlostdate,bettype,GameTypeID,balance,RefID)
			SELECT custid
				,winlostdate
				,1201
				,GameTypeID
				,(after_winlost - bef_winlost) AS Balance
				,@MatchId
			FROM @BalanceCWL t
			WHERE (after_winlost - bef_winlost) > 0
			
			INSERT INTO dbo.BalancePendingDebitGame (custid,winlostdate,bettype,GameTypeID,balance,RefID)
			SELECT custid
				,winlostdate
				,1201
				,GameTypeID
				,ABS(after_winlost - bef_winlost) AS Balance
				,@MatchId
			FROM @BalanceCWL
			WHERE (after_winlost - bef_winlost) < 0
		END
	END
END