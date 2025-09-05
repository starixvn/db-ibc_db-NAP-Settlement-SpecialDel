/*<info serverAlias="DBLOG-bodb_CustomerLog,DBTXN-bodb_CustomerLog" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[WriteLog_UserLog_SettleOutright]
(
	@UserID int
	,@MatchID int
	,@ActionID int = 0
	,@LeagueID int
	,@EventDate datetime
	,@Result VARCHAR(500) = ''
    ,@Remark VARCHAR(500) = ''
)
AS
/*
	Creator: Elodie
	Date: 2014-02-20
	DB: DBLOG/bodb_CustomerLog, DBTXN/bodb_CustomerLog
	Task: Insert LOGS for settlement outright function 

	Revision:
		- 20250805@Hughie: Apply SOP for Outright [Redmine:#232955]

*/
BEGIN

SET NOCOUNT ON

	INSERT INTO dbo.UserLog_SettleOutright
	(	
		UserID,
		MatchID,
		ActionID,
		LeagueID,
		EventDate,
		Result,
		Remark
	) 
	VALUES
	(	
		@UserID,
		@MatchID,
		@ActionID,
		@LeagueID,
		@EventDate,
		@Result,
		@Remark
	)
END
GO