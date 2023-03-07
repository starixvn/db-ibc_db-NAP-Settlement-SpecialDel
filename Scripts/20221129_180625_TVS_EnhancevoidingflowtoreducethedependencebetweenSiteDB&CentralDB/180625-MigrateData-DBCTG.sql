/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@Max
	Task: Migrate column IsProcessed on TicketVoiding_RequestDetailTicket_Single/SubParlay  [Redmine:#180625]  
	DB: DBCTG-bodb02
	
*/
USE bodb02
GO

--FOR SIT FIRST
UPDATE s SET s.IsProcessed = 1
FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (ROWLOCK, UPDLOCK)
	LEFT JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = s.RequestId
WHERE 1 = CASE WHEN r.RequestId IS NULL THEN 1
				WHEN r.RequestId IS NOT NULL AND r.CreatedDate <= DATEADD(DAY, -1, GETDATE()) THEN 1
			ELSE 0 END

UPDATE s SET s.IsProcessed = 1
FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (ROWLOCK, UPDLOCK)
	LEFT JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = s.RequestId
WHERE 1 = CASE WHEN r.RequestId IS NULL THEN 1
				WHEN r.RequestId IS NOT NULL AND r.CreatedDate <= DATEADD(DAY, -1, GETDATE()) THEN 1
			ELSE 0 END
