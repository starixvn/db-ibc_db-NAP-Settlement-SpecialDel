/*<info serverAlias="DBARC-bodb_archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210531@Max
	Task: TVS - Danger Accept Enhancement - Phase 9 - [Redmine: #153216]
	DB: DBARC-bodb_archive
*/

USE bodb_Archive
GO

WHILE (1=1)
BEGIN
	UPDATE TOP(3000) rd WITH (ROWLOCK, UPDLOCK)
		SET rd.SubIssueTypeId = r.SubIssueTypeId
			, rd.TransIds = CASE WHEN r.IssueTypeId = 1 AND rd.TransIds IS NOT NULL AND rd.TransIds NOT LIKE '%IsMainMatch%' THEN REPLACE(rd.TransIds, '/>', ' IsMainMatch="true" />') ELSE rd.TransIds END
	FROM dbo.TicketVoiding_RequestDetail_bk rd
		INNER JOIN dbo.TicketVoiding_Request_bk r WITH (NOLOCK) ON r.RequestId = rd.RequestId
	WHERE rd.SubIssueTypeId IS NULL

	IF @@ROWCOUNT < 3000 
		BREAK
END


