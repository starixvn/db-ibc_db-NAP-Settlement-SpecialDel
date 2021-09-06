/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20210904@Kathy
	Task : delete data on Settled_Message [Redmine:#161175]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

SET NOCOUNT ON

-- delete error "match does not exists"
WHILE(1=1)
BEGIN
	DELETE TOP (5000)
	FROM dbo.Settled_Message WITH(ROWLOCK, UPDLOCK)
	WHERE Message = 'Match does not exist!'

	IF @@ROWCOUNT = 0
		BREAK
END

