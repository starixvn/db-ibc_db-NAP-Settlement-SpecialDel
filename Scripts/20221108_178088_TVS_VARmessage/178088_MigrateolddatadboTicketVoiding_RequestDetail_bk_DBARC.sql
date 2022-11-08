/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221111@July
	Task: TVS - Create new message template for VAR situation - [Redmine:#178088]  
	DB: DBARC-bodb_Archive
*/

USE bodb_Archive
GO

UPDATE rd WITH (ROWLOCK,UPDLOCK)
SET rd.TransIds = SUBSTRING(rd.TransIds,0, LEN(rd.TransIds) - 1) + 'IsCheckedVar="0" />'
FROM dbo.TicketVoiding_RequestDetail_bk rd
	INNER JOIN dbo.TicketVoiding_Request_bk r WITH(NOLOCK) ON rd.RequestId = r.RequestId
WHERE r.IssueTypeId IN (1,3,10) AND rd.TransIds NOT LIKE '%IsCheckedVar%'
AND rd.TransIds IS NOT NULL

