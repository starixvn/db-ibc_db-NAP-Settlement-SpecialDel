/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: Max
	Date: 20220923
	Task : Udpate CustLimitBet_QueueRetry 
	DB: DBCTG/bodb02
*/
USE bodb02
GO

UPDATE q WITH (ROWLOCK, UPDLOCK)
	SET q.StatusId = 2
FROM dbo.CustLimitBet_QueueRetry q 
WHERE q.MainQueueId IN (14117061, 14117072)

GO



