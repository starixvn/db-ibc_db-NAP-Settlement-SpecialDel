/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20231215@Louisa
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 20231215@Louisa:  Insert LogAction for VS1 [Redmine:#195536]

*/
USE bodb_CustomerLog
GO

BEGIN

	INSERT INTO LogAction
	(
			[ActionID]		
		,[SPName]		
		,[ActionNameEN]
		,[ActionNameCH]
	)
	VALUES ( 155, 'NAP_Set_ExternalResultDetailESIns', N'VS Calculate All'	  , N'全部计算' )
			, ( 156, 'NAP_Set_ExternalResultDetailESIns', N'VS Refund All'		 , N'全部退款' )

END
