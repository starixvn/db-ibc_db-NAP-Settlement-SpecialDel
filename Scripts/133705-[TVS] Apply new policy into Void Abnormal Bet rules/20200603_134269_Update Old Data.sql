/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20200603@Max
	Task: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
	DB: DBTXN/bodb02
		
*/
USE bodb02
GO

WHILE (1=1)
BEGIN
	UPDATE TOP (3000) r
	SET r.ActionId = 5 --Manual Void
	FROM dbo.TicketVoiding_Request r WITH (ROWLOCK, UPDLOCK)
	WHERE r.IssueTypeId IN (8,9) 
		AND r.ActionId = 1
		
	IF @@ROWCOUNT < 3000 
		BREAK
END