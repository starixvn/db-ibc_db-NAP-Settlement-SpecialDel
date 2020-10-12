/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20201012@July
	Task: TVS - Migrate Data for IssueDetail - [Redmine: #141579]
	DB: DBTXN-bodb02
*/
UPDATE d 
SET d.IssueDetail = CAST (d.LiveHomeScore as VARCHAR(10) ) + ' - ' + CAST (d.LiveAwayScore as VARCHAR(10) )
FROM dbo.TicketVoiding_RequestDetail d WITH(NOLOCK)
	INNER JOIN dbo.TicketVoiding_request r WITH(NOLOCK) ON d.RequestId = r.RequestId  
WHERE r.IssueTypeId = 1 AND LiveHomeScore IS NOT NULL AND LiveAwayScore IS NOT NULL
AND d.IssueDetail IS NULL



