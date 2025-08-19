/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: DBPRO-bodb02
	
	Revisions:
		- 20250819@Hughie.Pham: Created [RedmineID: #232955]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE name = 'ResultDetailOutright')
BEGIN
	INSERT INTO RepInfo ([group],[name],active,version_key,version_type,unique_key,get_sp,put_sp,interval,back_fix,delayed_fix,batch_size) 
	SELECT 0,'ResultDetailOutright',0,'repupdatetime',0,'Orid','DR_Repl_GetResultDetailOutright_Dist','DR_Repl_PutResultDetailOutright_Dist',1000,10,60000,0
END
ELSE
BEGIN 
	SELECT 'ResultDetailOutright exists !!!'
END
GO
/***************************************************************************/
