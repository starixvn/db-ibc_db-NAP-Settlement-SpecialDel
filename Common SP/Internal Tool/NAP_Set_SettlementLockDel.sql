/*<info serverAlias="SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SettlementLockDel
	@SessionId BIGINT = 0
AS
/*
	Created by: 20211111@Kathy
	Task: Delete settlement lock [Redmine:#164162]
	DB: SBSETTLE/bodb02
	
	Revisions:
		- 20211111@Kathy: Delete settlement lock [Redmine:#164162]

*/
BEGIN
	SET NOCOUNT ON

	DELETE 
	FROM	dbo.SettlementLock WITH(ROWLOCK, UPDLOCK)
	WHERE	sessionId = @SessionId

END
GO