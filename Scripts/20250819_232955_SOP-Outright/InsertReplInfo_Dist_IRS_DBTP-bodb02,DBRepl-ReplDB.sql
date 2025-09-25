/*<info serverAlias="IRS_DBTP-bodb02,DBRepl-ReplDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: IRS_DBTP-bodb02,DBRepl-ReplDB
	
	Revisions:
		- 20250819@Hughie.Pham: Created [RedmineID: #232955]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'ResultDetailOutright')
BEGIN
	INSERT INTO RepInfo ([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size) 
	SELECT 20,'ResultDetailOutright',0,'repupdatetime',0,'Orid','Repl_GetResultDetailOutright','Repl_PutResultDetailOutright_Dist',1000,10,60000,0
END
ELSE
BEGIN  
	SELECT 'ResultDetailOutright exists !!!'
END
GO
/***************************************************************************/



