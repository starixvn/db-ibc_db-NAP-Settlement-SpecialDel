/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SettlementProcessingDel
	@SessionId BIGINT = 0
AS
/*
	Created by: 20211111@Kathy
	Task: Delete settlement processing [Redmine:#164162]
	DB: DBTXN,SBSETTLE/bodb02
	
	Revisions:
		- 20211111@Kathy: Delete settlement processing [Redmine:#164162]

*/
BEGIN
	SET NOCOUNT ON

	DELETE 
	FROM	dbo.SettlementProcessing WITH(ROWLOCK, UPDLOCK)
	WHERE	sessionId = @SessionId

END
GO