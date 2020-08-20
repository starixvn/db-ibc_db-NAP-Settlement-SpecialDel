/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Admin_VoidingTransId]
(
	@TransIds	VARCHAR(MAX)
	,@UserId	INT
	,@IssueTypeId	INT = 0
	,@CalledByBrokerService      BIT         = 0
	,@IsCallByMarkUnmark BIT = 0
	,@MarkType		  TINYINT		= 0
	,@ActionType TINYINT = NULL
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
	
	Param's explanation:	
		- @transIds = '<root>
						<r transid="104730774034" translogid="432934573" betid="1" isMG="1" actual_stake="100"/>
						<r transid="104729373985" />
					</root>'
					isMG: metric gaming ticket
		
		- IF @IsCallByMarkUnmark = true then @TransIds = '109631388136,109631388137,...'
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

	DECLARE @tmpTrans TABLE (TransID BIGINT, TranslogId BIGINT, BetId BIGINT, IsMG BIT, actual_stake MONEY, IsCashOutMember BIT)    

	SET @xml = CONVERT(XML, @TransIds)

	IF @IsCallByMarkUnmark = 1
	BEGIN
		 IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB06', 'DBTP', 'DB042', 'DB061', 'DB062'
				, 'DB231', 'DB231\SQLSERVER2008R2', 'DB232', 'DB232\SQLSERVER2008R2'
				, 'DB215', 'DB215\SQLSERVER2008R2', 'DB234', 'DB233\SQLSERVER2008R2'
				, 'SITDB052', 'SITDB053','SITDB06', 'SITDB055'
				, 'DBLicAPI', 'SITDBLicAPI', 'DBLicAPI02', 'DB055')
			AND @CalledByBrokerService = 0
		BEGIN
			-- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
			DECLARE @sMessage NVARCHAR(MAX)

			SET @sMessage = 'EXEC dbo.TicketVoiding_Admin_VoidingTransId 
				@TransIds = ' + CASE
					WHEN @TransIds IS NULL THEN 'NULL'
					ELSE '''' + CONVERT(NVARCHAR(MAX), @TransIds) + ''''
					END + '
				,@UserId = ' + CASE
					WHEN @UserId = 0 THEN '0'
					ELSE '''' + CONVERT(NVARCHAR(50), @UserId) + ''''
					END
				+ ',@CalledByBrokerService = 1'
				+ ',@CalledByBrokerService = 1'

			EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
				,@toService = N'//Service/Calculation_receive'
				,@onContract = N'//Contract/Calculation'
				,@messageType = N'//Message/Calculation'
				,@messageBody = @sMessage

			RETURN
		END
		ELSE
		BEGIN
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
					@MarkType
				FROM #Tickets t;
			END
			ELSE IF @ActionType = 2
			BEGIN
				-- Delete Transaction
				WHILE (0=0)
				BEGIN
					DELETE TOP (2000) m 
					OUTPUT DELETED.TransId
						,DELETED.MatchId
					INTO #MarkedTransactionDeleted (TransId, MatchId)
					FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
					INNER JOIN #Tickets t ON t.TransId = m.TransId AND t.MatchId = m.MatchId;

					IF @@ROWCOUNT = 0 BREAK	  
				END 
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

