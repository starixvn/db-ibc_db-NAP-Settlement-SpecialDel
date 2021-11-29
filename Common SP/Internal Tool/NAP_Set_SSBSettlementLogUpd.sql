/*<info serverAlias="DBTXN-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SSBSettlementLogUpd
	@SessionId BIGINT = 0
	,@Starttime DATETIME2
AS
/*
	Created by: 20211111@Kathy
	Task: update SSBSettlementLogs [Redmine:#164162]
	DB: DBTXN,SBSETTLE/bodb02
	
	Revisions:
		- 20211111@Kathy: Update SSBSettlementLogs [Redmine:#164162]

*/
BEGIN
	SET NOCOUNT ON

	UPDATE s 
		SET Resolved = 1
	FROM	dbo.SSB_SettlementLogs s WITH(ROWLOCK, UPDLOCK)
	WHERE	s.sessionId = @SessionId
			AND s.starttime >= @Starttime
			AND ISNULL(ErrorMessage,'') <> ''
			AND Resolved = 0

END
GO