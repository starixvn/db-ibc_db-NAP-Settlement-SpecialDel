/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created By : 20211125@Louisa
	Task: Delete Match no ticket [Redmine:#163469]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81036 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCH	)
	VALUES ( 81036, '', 'Delete No Ticket Match'	  , 'Delete No Ticket Match' )

GO



