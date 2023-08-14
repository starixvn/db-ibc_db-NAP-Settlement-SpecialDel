/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20230704@Louisa
	Task : Insert new LogAction fro Virtual Leap Gaming - VS3 [Redmine:#189854]
	DB: DBLOG/bodb_CustomerLog 

*/

---FOR SIT ONLY

USE bodb_CustomerLog
GO

	UPDATE dbo.LogAction WITH(ROWLOCK,UPDLOCK)
	SET ActionNameCS =  N'全部计算' 
		,ActionNameEN = 'Calculate All'
	WHERE ActionID =  81043 

GO

	UPDATE dbo.LogAction WITH(ROWLOCK,UPDLOCK)
	SET ActionNameCS =  N'全部退款'
		,ActionNameEN = 'Refund All'
	WHERE ActionID =  81044 
	 

GO