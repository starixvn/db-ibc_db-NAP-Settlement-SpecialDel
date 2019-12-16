/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Admin_VoidingTransId]
	@TransIds	VARCHAR(MAX)
	,@UserId	INT
	,@IssueTypeId	INT = 0
AS
/*	Created by: Kathy
	Date 20181212
	Task: void ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190909@Kathy: Do not update statuswinlost when voiding ticket [Redmine:#115376]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
	
	Param's explanation:	
		@transIds = '<root>
						<r transid="104730774034" translogid="432934573" betid="1" isMG="1" actual_stake="100"/>
						<r transid="104729373985" />
					</root>'
					isMG: metric gaming ticket
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
	END
END
GO

