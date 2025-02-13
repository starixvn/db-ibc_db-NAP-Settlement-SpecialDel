/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241106@Louisa
	Task:  Result Amendment [Redmine:#209656]
	DB: DBPRO-bodb02

*/
---run ON SIT only

USE bodb02
GO

BEGIN
	UPDATE RefResource WITH(ROWLOCK, UPDLOCK)
	SET RefId = 'ResourceE-Sports'
	WHERE RefId = 'ResourceE-sports'

END
GO