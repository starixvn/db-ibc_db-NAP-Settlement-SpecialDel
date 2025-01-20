/*<info serverAlias="IRS_DBTP-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250120@Aries	
	Task: In-House
	DB: IRS_DBTP-bodb02
	
	Revisions:
		- 20250120@Aries: Created [RedmineID: #214410]

	Example:			
*/
IF EXISTS (SELECT * FROM dbo.RepInfo WITH (NOLOCK) WHERE [name] = 'AutoRefundSetting')
BEGIN
	UPDATE RepInfo
	SET active = 1
	WHERE [group] = 21
		AND [name] =  'AutoRefundSetting'
END
ELSE
BEGIN  
	SELECT 'AutoRefundSetting not exists !!!'
END
GO
/***************************************************************************/



