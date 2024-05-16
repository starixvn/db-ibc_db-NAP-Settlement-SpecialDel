/*<info serverAlias="SBSETTLE-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SettlementLockDel
	@SessionId BIGINT = 0
	,@Mode VARCHAR(20) = 'single'
AS
/*
	Created by: 20211111@Kathy
	Task: Delete settlement lock [Redmine:#164162]
	DB: SBSETTLE/bodb02
	
	Revisions:
		- 20211111@Kathy: Delete settlement lock [Redmine:#164162]
		- 20240514@Kathy: parlay settlement [RedmineId:#204985]

	Param's Explanation:
		@Mode = 'single', 'parlay'

*/
BEGIN
	SET NOCOUNT ON

	IF @Mode = 'single'
		DELETE 
		FROM	dbo.SettlementLock WITH(ROWLOCK, UPDLOCK)
		WHERE	sessionId = @SessionId
	ELSE IF @Mode = 'parlay'
		DELETE 
		FROM	dbo.ParlaySettlementLock WITH(ROWLOCK, UPDLOCK)
		WHERE	sessionId = @SessionId

END
GO