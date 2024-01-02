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
		,[ActionNameCS]
	)
	VALUES ( 155, 'NAP_Admin_Settlement_VS_180', N'VS Calculate All'	 , N'全部计算' , N'全部计算')
			, ( 156, 'NAP_Admin_Settlement_VS_180', N'VS Refund All'	 , N'全部退款' , N'全部退款')

END