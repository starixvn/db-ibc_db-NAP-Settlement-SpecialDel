/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [sb].[TicketVoiding_WriteLog]
	@LogData XML
AS
/*
	Create By: Kathy
	Created Date: 20181212
	Task: Apply Service Broker for Writing Log - [Redmine: 90155]
	DB: DBLOG/bodb_CustomerLog
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190422@Kathy: Add requestId = 0 for other functions [Redmine:#108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @CurrentSessionId INT;

	SELECT @CurrentSessionId = CHECKSUM(GETDATE());

	INSERT INTO dbo.TicketVoiding_Log (LogActionId, RequestId, LogData, UserId, IP, SessionId, MatchId)
	SELECT	T.c.value('@LogActionId', 'INT')
			,ISNULL(T.c.value('@RequestId', 'INT'), 0)
			,T.c.value('@LogData', 'VARCHAR(MAX)')
			,T.c.value('@UserId', 'INT')
			,T.c.value('@IP', 'VARCHAR(50)')
			,@CurrentSessionId
			,ISNULL(T.c.value('@MatchId', 'VARCHAR(100)'), 0)
	FROM	@LogData.nodes('root/r') AS T(c)
END

