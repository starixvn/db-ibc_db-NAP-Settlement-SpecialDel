/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Admin_VoidingTransId]
(
	@TransIds					VARCHAR(MAX)
	,@UserId					INT
	,@IssueTypeId				INT = 0
	,@CalledByBrokerService     BIT         = 0
	,@IsUseServiceBroker		BIT = 0
	,@ActionType				TINYINT = NULL
	,@RunOnServer				VARCHAR(100) = NULL
	,@IsAbnormalMixParlay		BIT = 0
	,@strTransCashout			VARCHAR(MAX) = '' OUTPUT
)
AS
/*  Created by: Kathy
    Date 20181212
    Task: void ticket [Redmine:#90155]
    DB: DBTXN/bodb02
    
    Revisions: 
        - 20181212@Kathy: Create new SP [Redmine:#90155]
        - 20190909@Kathy: Do not update statuswinlost when voiding ticket [Redmine:#115376]
        - 20191118@Max: AdnormalBet TVS [Redmine:#123691]
        - 20200212@Helen: update if <> void status [Redmine:#127398]
        - 20200820@Max: Add Mark/Unmark process to servicebroker [Redmine: #139340]
        - 20200825@Kathy: Check server is using service broker by new SP instead of servername [Redmine:#140045]
        - 20210416@Kathy: Do not run replicated commands on servers which setup service broker [Redmine:#145127]
        - 20210422@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
        - 20210508@Helen: TVS - Hotfix - Wrong ticket status displayed on bet list for voided Abnormal Bet tickets[Redmine: #154762]
        - 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
        - 20211124@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]
        - 20211214@July: Remove code CashOut [Redmine: #165097]
        - 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20220926@Max: Hot fix - void by bet id not Rep to Central DB [Redmine: #178197]
		- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]

    Param's explanation:
        Version 1: Only use for Void Ticket via TVS
            - @transIds = '<root>
                            <r transid="104730774034" match="432934573" betid="1" isMG="1" betdaqid="100"/>
                            <r transid="104729373985" />
                        </root>'
                        isMG: metric gaming ticket
        
        Version 2: Include some function use ExecRep SP and ServiceBroker
            - @IsUseServiceBroker = 1:
                + @TransIds = '<root>
                                    <r id="104730774034" match="432934573" bettype="1" cust="1" type="0"/>
                                    <r id="104729373985" match="432934573"/>
                                </root>'
            - @ActionType:
                1: Mark
                2: Unmark           
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @xml XML
            ,@actual_stake MONEY
            ,@Sporttype SMALLINT = 1
            ,@transid BIGINT
            ,@matchid INT
            ,@IsEnableServiceBroker BIT -- server is using service broker or not
            ,@FcUpdateTime   DATETIME2
            ,@IsSiteDB  BIT 
            ,@transInfo XML
			,@transInfo3rd XML
            ,@CreatedDate DATETIME 

    IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
        SET @IsSiteDB = 1

    DECLARE @tmpTrans TABLE (TransID BIGINT, BetId BIGINT, betdaqid BIGINT) 
    DECLARE @tmpTrans_SB TABLE (TransId BIGINT, MatchId INT, Bettype SMALLINT, CustId INT, MarkType TINYINT) 
    DECLARE @tmpTrans_beforeUpd AS TABLE (transid BIGINT,custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, betdaqid BIGINT, Bonusid INT, WalletType TINYINT, status VARCHAR(20), matchid INT)
    DECLARE @tmpMatchId TABLE (matchId INT, Sporttype SMALLINT, IsFinish BIT)


    SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)

    IF @RunOnServer <> @@SERVERNAME
    BEGIN
        PRINT 'This command was skipped because run wrong server'
        RETURN
    END
    
    SET @xml = CONVERT(XML, @TransIds)

    EXEC dbo.NAP_Set_ServerInfo 
        @IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT

    IF @IsUseServiceBroker = 1 
    BEGIN
         IF (@@SERVERNAME IN ('DB052', 'DB053', 'DB054','DBTP', 'DB061', 'DB062', 'DB055') OR @IsEnableServiceBroker = 1)
                AND @CalledByBrokerService = 0
        BEGIN
            -- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
            DECLARE @sMessage NVARCHAR(MAX)

            SET @sMessage = 'EXEC dbo.TicketVoiding_Admin_VoidingTransId 
                    @TransIds = ''' + @TransIds + ''''
                    + ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId)
                    + ',@CalledByBrokerService = 1'
                    + ',@IsUseServiceBroker = 1'
                    + ',@ActionType = ' + CONVERT(NVARCHAR(10), @ActionType)
                    + CASE WHEN @RunOnServer IS NULL THEN '' ELSE ',@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END

            EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
                ,@toService = N'//Service/Calculation_receive'
                ,@onContract = N'//Contract/Calculation'
                ,@messageType = N'//Message/Calculation'
                ,@messageBody = @sMessage

            RETURN
        END
        ELSE
        BEGIN
            INSERT INTO @tmpTrans_SB(TransId, MatchId, Bettype, CustId, MarkType)
            SELECT  T.C.value('./@id', 'bigint')
                    ,T.C.value('./@match', 'int')
                    ,T.C.value('./@bettype', 'smallint')
                    ,T.C.value('./@cust', 'int')
                    ,T.C.value('./@type', 'tinyint')
            FROM    @xml.nodes('/root/r') AS T(C)
            OPTION (OPTIMIZE FOR (@xml = NULL ))

            INSERT INTO @tmpMatchId (matchId)
            SELECT DISTINCT MatchId
            FROM @tmpTrans_SB

            IF @ActionType = 1
            BEGIN
                 SET @CreatedDate =  CURRENT_TIMESTAMP
                INSERT INTO dbo.MarkedTransaction
                    (TransId,
                        MatchId,
                        BetType,
                        CustId,
                        UserId,
                        CreatedDate,
                        MarkType 
                    )
                SELECT t.TransId,
                    t.MatchId,
                    t.BetType,
                    t.CustId,
                    @UserId,
                    @CreatedDate,
                    t.MarkType
                FROM @tmpTrans_SB t;

                IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTrans_SB)
                BEGIN
                    WHILE (1=1)
                    BEGIN
                        UPDATE TOP(1)m
                        SET IsFinish = 1, @matchid = MatchId 
                        FROM @tmpMatchId m
                        WHERE IsFinish IS NULL

                        IF @@ROWCOUNT = 0 BREAK;
                        SET @transInfo = (
                        SELECT  transId AS '@t'
                                , matchid AS '@mid'
                                , custid AS '@cust'
                                , bettype AS '@btype'
                                , @UserId AS '@us'
                                , @CreatedDate AS '@crdate'
                                , MarkType AS '@mt'
                        FROM    @tmpTrans_SB WHERE matchid = @MatchId 
                        FOR XML PATH('r'),ROOT('root'), TYPE)

                        INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
                        SELECT 'TVS', 'Mark', 'MarkedTransaction', 'I', @matchid, @transInfo 
                    END
                END
        
            END
            ELSE IF @ActionType = 2
            BEGIN
                DELETE m 
                FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
                    INNER JOIN @tmpTrans_SB t ON t.TransId = m.TransId AND t.MatchId = m.MatchId;

                IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTrans_SB)
                BEGIN
                    WHILE (1=1)
                    BEGIN
                        UPDATE TOP(1)m
                        SET IsFinish = 1, @matchid = MatchId 
                        FROM @tmpMatchId m
                        WHERE IsFinish IS NULL

                        IF @@ROWCOUNT = 0 BREAK;
                        SET @transInfo = (
                        SELECT  transId AS '@t'
                                , matchid AS '@mid'
                        FROM    @tmpTrans_SB WHERE matchid = @MatchId 
                        FOR XML PATH('r'),ROOT('root'), TYPE)

                        INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
                        SELECT 'TVS', 'UnMark', 'MarkedTransaction', 'D', @matchid, @transInfo 
                    END
                END
            END
        END
    END
    ELSE
    BEGIN
        INSERT INTO @tmpTrans(TransID, BetId, betdaqid)
        SELECT  T.C.value('./@transid', 'bigint')
                ,T.C.value('./@betid', 'bigint')
                ,T.C.value('./@betdaqid', 'bigint')
        FROM    @xml.nodes('/root/r') AS T(C)
        OPTION (OPTIMIZE FOR (@xml = NULL ))
    
        IF @IssueTypeId IN (11,13,15)
        BEGIN
            SET @transid = (SELECT TOP 1 transid FROM @tmpTrans)
            SET @matchid = (SELECT TOP 1 matchid FROM bettrans WITH (NOLOCK) WHERE transid = @transid)
            SET @Sporttype = (SELECT TOP 1 sporttype FROM dbo.match m WITH (NOLOCK) WHERE m.matchid = @matchid)
            SET @FcUpdateTime = SYSDATETIME()

            UPDATE  b
            SET @actual_stake = b.actual_stake
                ,winlost = @actual_stake
                ,ruben = 1
                ,creator = @UserId
                ,awinlost = 0
                ,mwinlost = 0
                ,swinlost = 0
                ,playercomm = 0
                ,comm = 0 
                ,acomm = 0
                ,scomm = 0
                ,statusID = 102
                ,status = 'VOID'
                ,betid = t.BetId
                ,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(CASE WHEN @IsAbnormalMixParlay = 0 THEN 1 ELSE 2 END,'VOID',b.ExtraInfo,@Sporttype,b.bettype)
                ,FcUpdateTime  = @FcUpdateTime
                    OUTPUT deleted.Transid,
                        deleted.custid,  
                        deleted.winlost,  
                        deleted.actual_stake, 
                        deleted.playercomm,
                        deleted.betdaqid ,
                        deleted.BonusID,
                        deleted.WalletType,
                        deleted.status
                INTO @tmpTrans_beforeUpd (transid,custid, winlost, actual_stake, playercomm, betdaqid, Bonusid, WalletType, status)
            FROM    @tmpTrans t
                INNER JOIN dbo.bettrans b  WITH(ROWLOCK, UPDLOCK)
                    ON  t.transid = b.transid
            WHERE b.statusID NOT IN (102)

            SET @transInfo = (
            SELECT  t.transId AS '@t'
                    , b.winlost AS '@w'
                    , b.ruben AS '@r'
                    , b.creator AS '@cr'
                    , b.awinlost AS '@aw'
                    , b.mwinlost AS '@mw'
                    , b.swinlost AS '@sw'
                    , b.playercomm AS '@pc'
                    , b.comm AS '@c'
                    , b.acomm AS '@ac'
                    , b.scomm AS '@sc'
                    , b.statusID AS '@sid'
                    , b.status AS '@s'
                    , b.betid AS '@bid'
                    , b.ExtraInfo AS '@ex'
                    , b.FcUpdateTime AS '@rut'
            FROM    @tmpTrans t 
                INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
                INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
			WHERE b.bettype NOT IN (10, 38)
            FOR XML PATH('r'),ROOT('root'), TYPE)

			SET @transInfo3rd = (
            SELECT  t.transId AS '@t'
                    , b.winlost AS '@w'
                    , b.ruben AS '@r'
                    , b.creator AS '@cr'
                    , b.awinlost AS '@aw'
                    , b.mwinlost AS '@mw'
                    , b.swinlost AS '@sw'
                    , b.playercomm AS '@pc'
                    , b.comm AS '@c'
                    , b.acomm AS '@ac'
                    , b.scomm AS '@sc'
                    , b.statusID AS '@sid'
                    , b.status AS '@s'
                    , b.betid AS '@bid'
                    , b.ExtraInfo AS '@ex'
                    , b.FcUpdateTime AS '@rut'
            FROM    @tmpTrans t 
                INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
                INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
			WHERE b.bettype IN (10, 38)
            FOR XML PATH('r'),ROOT('root'), TYPE)

            IF @IsSiteDB = 1 AND @transInfo IS NOT NULL
            BEGIN
                INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
                SELECT 'TVS', 'Void', 'bettrans', 'U', @matchid, @transInfo
            END

			IF @IsSiteDB = 1 AND @transInfo3rd IS NOT NULL
            BEGIN
                INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfo, TicketType, EventTable)
                SELECT 'TVS', 'Void', 'bettrans', 'U', @matchid, @transInfo3rd, 's', 1
            END


            -- Process for cashout tickets make change Balance before
            SET @strTransCashout = ISNULL(CAST((SELECT b.transid AS t
                                                        , b.custid AS c
                                                        , b.winlost AS wl
                                                        , b.actual_stake AS al
                                                        , b.playercomm as pl
                                                        , CASE 
                                                                WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
                                                                ELSE 0 END AS bn
                                                        , ISNULL(b.WalletType, 2) AS w
                                                        , b.status AS st
                                                FROM @tmpTrans_beforeUpd b
                                                    INNER JOIN @tmpTrans t ON t.TransID = b.transid
                                                WHERE   b.betdaqid = -2
                                                    AND ISNULL(t.betdaqid, 0) <> -2
                                                FOR XML AUTO) AS VARCHAR(MAX)
                                        ),'')
            
        END
        ELSE
        BEGIN
            SET @transid = (SELECT TOP 1 transid FROM @tmpTrans)
            SET @matchid = (SELECT TOP 1 matchid FROM bettrans WITH (NOLOCK) WHERE transid = @transid)
            SET @FcUpdateTime = SYSDATETIME()

            UPDATE  b
            SET @actual_stake = b.actual_stake
                ,winlost = @actual_stake
                ,actual_stake = @actual_stake
                ,ruben = 1
                ,creator = @UserId
                ,awinlost = 0
                ,mwinlost = 0
                ,swinlost = 0
                ,playercomm = 0
                ,comm = 0 
                ,acomm = 0
                ,scomm = 0
                ,statusID = 102
                ,status = 'VOID'
                ,betid = t.BetId
                ,FcUpdateTime  = @FcUpdateTime
                    OUTPUT deleted.Transid,
                        deleted.custid,  
                        deleted.winlost,  
                        deleted.actual_stake, 
                        deleted.playercomm,
                        deleted.betdaqid ,
                        deleted.BonusID,
                        deleted.WalletType,
                        deleted.status
                INTO @tmpTrans_beforeUpd (transid, custid, winlost, actual_stake, playercomm, betdaqid, Bonusid, WalletType, status)
            FROM    @tmpTrans t
                INNER JOIN dbo.bettrans b  WITH(ROWLOCK, UPDLOCK)
                    ON  t.transid = b.transid
            WHERE b.statusID NOT IN (102)   

            INSERT INTO @tmpMatchId (MatchId, Sporttype)
			SELECT DISTINCT b.MatchId 
			FROM @tmpTrans_beforeUpd b
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid

			WHILE (1=1)
			BEGIN
				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId, @Sporttype = m.Sporttype
				FROM @tmpMatchId m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;

				SET @transInfo = (
				SELECT  t.transId AS '@t'
						, b.winlost AS '@w'
						, b.ruben AS '@r'
						, b.creator AS '@cr'
						, b.awinlost AS '@aw'
						, b.mwinlost AS '@mw'
						, b.swinlost AS '@sw'
						, b.playercomm AS '@pc'
						, b.comm AS '@c'
						, b.acomm AS '@ac'
						, b.scomm AS '@sc'
						, b.statusID AS '@sid'
						, b.status AS '@s'
						, b.betid AS '@bid'
						, b.FcUpdateTime AS '@rut'
				FROM    @tmpTrans t 
					INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
					INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
				WHERE tp.matchid = @matchid
					AND 1 = CASE WHEN (b.bettype IN (10, 38)
									OR @Sporttype BETWEEN 180 AND 186 
									OR @Sporttype BETWEEN 190 AND 197
									OR @Sporttype IN (175, 161, 199)
									)
								THEN 0 ELSE 1 END
				FOR XML PATH('r'),ROOT('root'), TYPE)

				SET @transInfo3rd = (
				SELECT  t.transId AS '@t'
						, b.winlost AS '@w'
						, b.ruben AS '@r'
						, b.creator AS '@cr'
						, b.awinlost AS '@aw'
						, b.mwinlost AS '@mw'
						, b.swinlost AS '@sw'
						, b.playercomm AS '@pc'
						, b.comm AS '@c'
						, b.acomm AS '@ac'
						, b.scomm AS '@sc'
						, b.statusID AS '@sid'
						, b.status AS '@s'
						, b.betid AS '@bid'
						, b.FcUpdateTime AS '@rut'
				FROM    @tmpTrans t 
					INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
					INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
				WHERE tp.matchid = @matchid
					AND 1 = CASE WHEN (b.bettype IN (10, 38)
									OR @Sporttype BETWEEN 180 AND 186 
									OR @Sporttype BETWEEN 190 AND 197
									OR @Sporttype IN (175, 161, 199)
									)
								THEN 1 ELSE 0 END
				FOR XML PATH('r'),ROOT('root'), TYPE)

				IF @IsSiteDB = 1 AND @transInfo IS NOT NULL AND @IssueTypeId <> -1 --Case void UUS ticket by move bet process
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
					SELECT 'TVS', 'Void', 'bettrans', 'U', @matchid, @transInfo
				END

				IF @IsSiteDB = 1 AND @transInfo3rd IS NOT NULL AND @IssueTypeId <> -1 --Case void UUS ticket by move bet process
				BEGIN
					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd(SystemName, FunctionName, TableName, Action, MatchId, TransInfo, TicketType, EventTable)
					SELECT 'TVS', 'Void', 'bettrans', 'U', @matchid, @transInfo3rd, 's', 1
				END
			END

			DELETE FROM @tmpMatchId
			SET @TransInfo = ''
			SET @TransInfo3rd = ''
			
            -- Process for cashout tickets make change Balance before
            SET @strTransCashout = ISNULL(CAST((SELECT b.transid AS t
                                                        , b.custid AS c
                                                        , b.winlost AS wl
                                                        , b.actual_stake AS al
                                                        , b.playercomm as pl
                                                        , CASE 
                                                                WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
                                                                ELSE 0 END AS bn
                                                        , ISNULL(b.WalletType, 2) AS w
                                                        , b.status AS st
                                                FROM @tmpTrans_beforeUpd b
                                                    INNER JOIN @tmpTrans t ON t.TransID = b.transid
                                                WHERE   b.betdaqid = -2
                                                    AND ISNULL(t.betdaqid, 0) <> -2
                                                FOR XML AUTO) AS VARCHAR(MAX)
                                        ),'')
            
        END
    END
END
GO

