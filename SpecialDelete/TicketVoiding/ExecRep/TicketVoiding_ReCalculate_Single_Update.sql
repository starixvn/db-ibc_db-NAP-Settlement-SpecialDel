/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ReCalculate_Single_Update]
(
	@TransIds					VARCHAR(MAX)
	,@CalledByBrokerService     BIT         = 0
	,@RunOnServer				VARCHAR(100) = NULL
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