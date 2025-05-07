/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

UPDATE dbo.Ticketvoiding_VoidBetAutomation_Service WITH(ROWLOCK,UPDLOCK)
SET matchID = 104645191
WHERE RequestId IN (142930) AND ID IN (140790,140791,140792)