/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

DELETE FROM TicketVoiding_Queue WITH(ROWLOCK)
WHERE RequestId in (142930) 
AND VoidingTypeId = 2 
AND ErrMsg = 'No parlay ticket found.'