/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221012@July
	Task: TVS - Wrong HDP/ 1H HDP - Migrate old data TicketVoiding_RequestDetail_bk - [Redmine:#172486]  
	DB: DBARC-bodb_Archive
*/

USE bodb_Archive
GO

UPDATE rd WITH (ROWLOCK,UPDLOCK)
SET rd.IssueDetail = rd.IssueDetail + ';LiveGameEarlySingleCount:' +  CAST(rd.SingleCount AS VARCHAR(20)) + ';PoolHouseSingleCount:0;PoolHouseMainParlayCount:' +  CAST(rd.MainParlayCount AS VARCHAR(20))
   ,rd.TransIds = SUBSTRING(rd.TransIds,0, LEN(rd.TransIds) - 1) +'LiveIndicator ="0" IsLinkGroup1X2="0" IsLinkGroupAIO="0"  PoolHouseCheckedBetTypes=""  />'
FROM dbo.TicketVoiding_RequestDetail_bk rd
	INNER JOIN dbo.TicketVoiding_Request_bk r WITH(NOLOCK) ON rd.RequestId = r.RequestId
WHERE r.IssueTypeId IN (4,5)