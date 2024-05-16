/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SettlementProcessingDel
	@SessionId BIGINT = 0
	,@Mode VARCHAR(20) = 'single'
AS
/*
	Created by: 20211111@Kathy
	Task: Delete settlement processing [Redmine:#164162]
	DB: DBTXN,SBSETTLE/bodb02
	
	Revisions:
		- 20211111@Kathy: Delete settlement processing [Redmine:#164162]
		- 20240514@Kathy: parlay settlement [RedmineId:#204985]

	Param's Explanation:
		@Mode = 'single', 'parlay'

*/
BEGIN
	SET NOCOUNT ON

	IF @Mode = 'single'
		DELETE 
		FROM	dbo.SettlementProcessing WITH(ROWLOCK, UPDLOCK)
		WHERE	sessionId = @SessionId
	
	ELSE IF @Mode = 'parlay'
		DELETE 
		FROM	dbo.ParlaySettlementProcessing WITH(ROWLOCK, UPDLOCK)
		WHERE	sessionId = @SessionId

END
GO