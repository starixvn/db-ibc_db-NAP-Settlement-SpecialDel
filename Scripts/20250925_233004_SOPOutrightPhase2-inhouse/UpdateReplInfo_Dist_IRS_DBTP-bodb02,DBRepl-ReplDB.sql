/*<info serverAlias="IRS_DBTP-bodb02,DBRepl-ReplDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: IRS_DBTP-bodb02,DBRepl-ReplDB
	
	Revisions:
		- 20250819@Hughie.Pham: Created [RedmineID: #232955]

	Example:			
*/
IF EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'ResultDetailOutright')
BEGIN
	UPDATE RepInfo
	SET active = 0 -- 1
	WHERE [group] = 20
		AND [name] =  'ResultDetailOutright'
END
ELSE
BEGIN  
	SELECT 'ResultDetailOutright not exists !!!'
END
GO
/***************************************************************************/



