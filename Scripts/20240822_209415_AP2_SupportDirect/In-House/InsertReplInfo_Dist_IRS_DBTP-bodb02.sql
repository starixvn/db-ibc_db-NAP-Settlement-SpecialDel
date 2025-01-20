/*<info serverAlias="IRS_DBTP-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20241010@Aries.Nguyen	
	Task: In-House
	DB: IRS_DBTP-bodb02
	
	Revisions:
		- 20241010@Aries.Nguyen: Created [RedmineID: #]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'AutoPayoutSetting')
BEGIN
	INSERT INTO RepInfo ([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size) 
	SELECT 0,'AutoPayoutSetting',0,'repupdatetime',0,'Id','Repl_GetAutoPayoutSetting','Repl_PutAutoPayoutSetting_Dist',1000,10,60000,0
END
ELSE
BEGIN  
	SELECT 'AutoPayoutSetting exists !!!'
END
GO
/***************************************************************************/



