/*<info serverAlias="IRS_DBTP-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250120@Aries	
	Task: In-House
	DB: IRS_DBTP-bodb02
	
	Revisions:
		- 20250120@Aries: Created [RedmineID: #214410]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'AutoRefundSetting')
BEGIN
	INSERT INTO RepInfo ([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size) 
	SELECT 21,'AutoRefundSetting',0,'repupdatetime',0,'Id','Repl_GetAutoRefundSetting','Repl_PutAutoRefundSetting_Dist',1000,10,60000,0
END
ELSE
BEGIN  
	SELECT 'AutoRefundSetting exists !!!'
END
GO
/***************************************************************************/



