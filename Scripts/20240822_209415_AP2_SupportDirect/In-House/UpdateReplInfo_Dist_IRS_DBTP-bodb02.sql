/*<info serverAlias="IRS_DBTP-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20241010@Aries.Nguyen	
	Task: In-House
	DB: IRS_DBTP-bodb02
	
	Revisions:
		- 20241010@Aries.Nguyen: Created [RedmineID: #]

	Example:			
*/
IF EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'AutoPayoutSetting')
BEGIN
	UPDATE RepInfo
	SET active = 1
	WHERE [group] = 0
		AND [name] =  'AutoPayoutSetting'
END
ELSE
BEGIN  
	SELECT 'AutoPayoutSetting not exists !!!'
END
GO
/***************************************************************************/



