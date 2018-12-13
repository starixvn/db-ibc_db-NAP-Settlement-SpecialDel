/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Admin_VoidingTransId]
	@TransIds	VARCHAR(MAX)
	,@UserId	INT
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
		@transIds = '<root>
						<r transid="104730774034" translogid="432934573" betid="1" isMG="1"/>
						<r transid="104729373985" />
					</root>'
					isMG: metric gaming ticket
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xml XML
	DECLARE @tmpTrans TABLE (TransID BIGINT, TranslogId BIGINT, BetId BIGINT, IsMG BIT)    

	SET @xml = CONVERT(XML, @TransIds)
    
	INSERT INTO @tmpTrans(TransID, TranslogId, BetId, IsMG)
    SELECT	T.C.value('./@transid', 'bigint')
			,T.C.value('./@translogid', 'bigint')
			,T.C.value('./@betid', 'bigint')
			,T.C.value('./@isMG', 'bit')
	FROM	@xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	UPDATE	b
		SET winlost = b.actual_stake
			,ruben = 1
			,statuswinlost = 6
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
        INNER JOIN dbo.bettrans b ON  t.transid = b.transid

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

