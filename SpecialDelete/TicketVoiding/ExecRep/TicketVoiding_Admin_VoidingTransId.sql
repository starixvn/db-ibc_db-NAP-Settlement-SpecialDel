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
/*	Created by: Kathy
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

	Param's explanation:
		Version 1: Only use for Void Ticket via TVS
			- @transIds = '<root>
							<r transid="104730774034" translogid="432934573" betid="1" isMG="1" actual_stake="100"/>
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
			,@RepUpdateTime DATETIME2
		SET @IsSiteDB = 1
	
	DECLARE @tmpTrans TABLE (TransID BIGINT, TranslogId BIGINT, BetId BIGINT, IsMG BIT, actual_stake MONEY, betdaqid BIGINT) 
	DECLARE @tmpTrans_SB TABLE (TransId BIGINT, MatchId INT, Bettype SMALLINT, CustId INT, MarkType TINYINT) 
	DECLARE @tmpTrans_beforeUpd AS TABLE (transid BIGINT,custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, betdaqid BIGINT, Bonusid INT, WalletType TINYINT, status VARCHAR(20))


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
			SELECT	T.C.value('./@id', 'bigint')
					,T.C.value('./@match', 'int')
					,T.C.value('./@bettype', 'smallint')
					,T.C.value('./@cust', 'int')
					,T.C.value('./@type', 'tinyint')
			FROM	@xml.nodes('/root/r') AS T(C)
			OPTION (OPTIMIZE FOR (@xml = NULL ))

			IF @ActionType = 1
			BEGIN
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
					CURRENT_TIMESTAMP,
					t.MarkType
				FROM @tmpTrans_SB t;
			END
			ELSE IF @ActionType = 2
			BEGIN
				DELETE m 
				FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
					INNER JOIN @tmpTrans_SB t ON t.TransId = m.TransId AND t.MatchId = m.MatchId;
			END
		END
	END
    ELSE
	BEGIN
		INSERT INTO @tmpTrans(TransID, TranslogId, BetId, IsMG, actual_stake, betdaqid)
		SELECT	T.C.value('./@transid', 'bigint')
				,T.C.value('./@translogid', 'bigint')
				,T.C.value('./@betid', 'bigint')
				,T.C.value('./@isMG', 'bit')
				,T.C.value('./@actual_stake', 'money')
				,T.C.value('./@betdaqid', 'bigint')
		FROM	@xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
	
		IF @IssueTypeId IN (11,13,15)
		BEGIN
			SET @transid = (SELECT TOP 1 transid FROM @tmpTrans)
			SET @matchid = (SELECT TOP 1 matchid FROM bettrans WITH (NOLOCK) WHERE transid = @transid)
			SET @Sporttype = (SELECT TOP 1 sporttype FROM dbo.match m WITH (NOLOCK) WHERE m.matchid = @matchid)
			SET @RepUpdateTime = SYSDATETIME()

			UPDATE	b
			SET @actual_stake = CASE WHEN t.IsMG = 1 THEN t.actual_stake ELSE  b.actual_stake END
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
				,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(CASE WHEN @IsAbnormalMixParlay = 0 THEN 1 ELSE 2 END,'VOID',b.ExtraInfo,@Sporttype,b.bettype)
				,RepUpdateTime  = @RepUpdateTime
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
			FROM	@tmpTrans t
				INNER JOIN dbo.bettrans b  WITH(ROWLOCK, UPDLOCK)
					ON  t.transid = b.transid
			WHERE b.statusID NOT IN (102)	

			IF @IsSiteDB = 1 AND @transInfo IS NOT NULL
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
												WHERE 	b.betdaqid = -2
													AND ISNULL(t.betdaqid, 0) <> -2
												FOR XML AUTO) AS VARCHAR(MAX)
										),'')
			
		END
		ELSE
		BEGIN
			SET @RepUpdateTime = SYSDATETIME()
			UPDATE	b
			SET @actual_stake = CASE WHEN t.IsMG = 1 THEN t.actual_stake ELSE  b.actual_stake END
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
				,RepUpdateTime  = @RepUpdateTime
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
			FROM	@tmpTrans t
				INNER JOIN dbo.bettrans b  WITH(ROWLOCK, UPDLOCK)
					ON  t.transid = b.transid
			WHERE b.statusID NOT IN (102)	
			
			IF @IsSiteDB = 1 AND @transInfo IS NOT NULL AND @IssueTypeId <> 0
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
												WHERE 	b.betdaqid = -2
													AND ISNULL(t.betdaqid, 0) <> -2
												FOR XML AUTO) AS VARCHAR(MAX)
										),'')
			
		END
				
		IF EXISTS (SELECT TOP 1 1 FROM @tmpTrans t WHERE t.IsMG = 1)
		BEGIN
			UPDATE	tl 
				SET status = 'VOID'
					,statusID = 102
					,creator = @UserId
					,custom3 = ISNULL(tl.custom3, t.betid)
			FROM	@tmpTrans t	
				INNER JOIN dbo.translog tl WITH(ROWLOCK, UPDLOCK)
					ON	t.TranslogId = tl.translogid
			WHERE tl.statusID NOT IN (102)	
			
		END
	END
END
GO

