/*<info serverAlias="DBARC-bodb_archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210817@Max
	Task: TVS -Wrong Score Enhancement Phase 2 - [Redmine: #157096]
	DB: DBARC-bodb_archive
*/

USE bodb_Archive
GO

WHILE (1=1)
BEGIN
	UPDATE TOP(3000) rd WITH (ROWLOCK, UPDLOCK)
		SET rd.TransIds = '<r ScoreId="' + rd.TransIds + '" />'
	FROM dbo.TicketVoiding_RequestDetail_bk rd
		INNER JOIN dbo.TicketVoiding_Request_bk r WITH (NOLOCK) ON r.RequestId = rd.RequestId
	WHERE r.IssueTypeId = 3 
		AND rd.TransIds IS NOT NULL

	IF @@ROWCOUNT < 3000 
		BREAK
END


