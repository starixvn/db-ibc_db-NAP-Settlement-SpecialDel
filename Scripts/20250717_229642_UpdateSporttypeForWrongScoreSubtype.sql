﻿/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250227@Lani
	Task: TVS - Wrong Score - Add new sub type and related event function [Redmine: #216151]
	DB: DBCTG-bodb02
*/
USE bodb02
GO


UPDATE mts
SET mts.Sporttype =  1
FROM TicketVoiding_MessageTemplateSetting AS mts WITH (UPDLOCK, ROWLOCK)
INNER JOIN TicketVoiding_SubIssueType AS s WITH (NOLOCK) ON mts.SubIssueTypeId = s.SubIssueTypeId
WHERE s.IssueTypeId = 3


