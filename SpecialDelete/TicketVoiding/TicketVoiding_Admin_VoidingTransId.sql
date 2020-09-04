/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Admin_VoidingTransId]
(
	@TransIds					VARCHAR(MAX)
	,@UserId					INT
	,@IssueTypeId				INT = 0
	,@CalledByBrokerService     BIT         = 0
	,@IsUseServiceBroker		BIT = 0
	,@ActionType				TINYINT = NULL
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

	DECLARE @tmpTrans TABLE (TransID BIGINT, TranslogId BIGINT, BetId BIGINT, IsMG BIT, actual_stake MONEY, IsCashOutMember BIT) 
	DECLARE @tmpTrans_SB TABLE (TransId BIGINT, MatchId INT, Bettype SMALLINT, CustId INT, MarkType TINYINT) 

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
		INSERT INTO @tmpTrans(TransID, TranslogId, BetId, IsMG, actual_stake, IsCashOutMember)
		SELECT	T.C.value('./@transid', 'bigint')
				,T.C.value('./@translogid', 'bigint')
				,T.C.value('./@betid', 'bigint')
				,T.C.value('./@isMG', 'bit')
				,T.C.value('./@actual_stake', 'money')
				,T.C.value('./@IsCashOutMember', 'bit')
		FROM	@xml.nodes('/root/r') AS T(C)
		OPTION (OPTIMIZE FOR (@xml = NULL ))
	
		IF @IssueTypeId = 11
		BEGIN
			SET @transid = (SELECT TOP 1 transid FROM @tmpTrans)
			SET @matchid = (SELECT TOP 1 matchid FROM bettrans WITH (NOLOCK) WHERE transid = @transid)
			SET @Sporttype = (SELECT TOP 1 sporttype FROM dbo.match m WITH (NOLOCK) WHERE m.matchid = @matchid)
		
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
				,ExtraInfo = CASE WHEN t.IsCashOutMember = 0 THEN dbo.f_SD_SetExtraInfoAbnormalBet(1,'VOID',b.ExtraInfo,@Sporttype,b.bettype)
									ELSE b.ExtraInfo 
							END
						
			FROM	@tmpTrans t
				INNER JOIN dbo.bettrans b  WITH(ROWLOCK, UPDLOCK)
					ON  t.transid = b.transid
			WHERE b.statusID NOT IN (102)	
			
		END
		ELSE
		BEGIN
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
						
			FROM	@tmpTrans t
				INNER JOIN dbo.bettrans b  WITH(ROWLOCK, UPDLOCK)
					ON  t.transid = b.transid
			WHERE b.statusID NOT IN (102)		
			
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

